import AppKit

/// Parses a pragmatic subset of GitHub-flavored Markdown into Blink's rich
/// text model: headings, quotes, lists, tasks, and common inline styles.
enum MarkdownImporter {
    static func attributedString(
        from markdown: String,
        fontSize: CGFloat = 16,
        family: EditorFontFamily = .system
    ) -> NSAttributedString {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var lines = normalized.components(separatedBy: "\n")
        if lines.last == "" {
            lines.removeLast()
        }

        let result = NSMutableAttributedString()
        var sharedList: NSTextList?
        var sharedListKind: ListStyle?
        var sharedListLevel = 0

        for (index, line) in lines.enumerated() {
            let block = Block(line: line)
            let lineStart = result.length
            let base = baseAttributes(for: block, fontSize: fontSize, family: family)

            let list: NSTextList?
            if let kind = block.list {
                if kind == .ordered || kind == .bullet {
                    if sharedListKind == kind, sharedListLevel == block.level {
                        list = sharedList
                    } else {
                        list = NSTextList(
                            markerFormat: kind == .ordered ? .decimal : .disc,
                            options: 0
                        )
                        sharedList = list
                        sharedListKind = kind
                        sharedListLevel = block.level
                    }
                } else {
                    list = NSTextList(
                        markerFormat: block.isChecked ? .check : .box,
                        options: 0
                    )
                    sharedList = nil
                    sharedListKind = nil
                }
            } else {
                list = nil
                sharedList = nil
                sharedListKind = nil
            }

            for run in inlineRuns(in: block.content) {
                var attributes = base
                let size = block.heading?.size(base: fontSize) ?? fontSize
                let isBold = run.styles.contains(.bold) || block.heading != nil
                let isItalic = run.styles.contains(.italic)
                let isCode = run.styles.contains(.code)

                if isBold || isItalic || isCode {
                    attributes[.font] = RichTextFont.make(
                        size: size,
                        bold: isBold,
                        italic: isItalic,
                        code: isCode,
                        family: family
                    )
                }
                if isCode {
                    attributes[.backgroundColor] = RichTextStyle.codeBackground
                    attributes[.blinkCode] = true
                }
                if run.styles.contains(.strikeThrough) {
                    attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                }
                if run.styles.contains(.underline) {
                    attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                }
                if let link = run.link {
                    attributes[.link] = link
                }

                result.append(NSAttributedString(string: run.text, attributes: attributes))
            }

            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: base))
            }

            if result.length > lineStart {
                let range = NSRange(location: lineStart, length: result.length - lineStart)
                result.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle(for: block, list: list),
                    range: range
                )
                if block.isQuote {
                    result.addAttribute(.blinkBlockquote, value: true, range: range)
                }
                if let level = block.heading {
                    result.addAttribute(.blinkHeading, value: level.rawValue, range: range)
                }
            }
        }

        return result
    }

    // MARK: - Blocks

    private struct Block {
        var content: String = ""
        var heading: HeadingLevel?
        var list: ListStyle?
        var isChecked = false
        var isQuote = false
        var level = 0

        init(line: String) {
            var text = line
            while text.hasPrefix(">") {
                isQuote = true
                text = String(text.dropFirst())
                if text.hasPrefix(" ") {
                    text = String(text.dropFirst())
                }
            }

            let leadingSpaces = text.prefix { $0 == " " || $0 == "\t" }.count
            level = min(3, leadingSpaces / 2)
            text = String(text.dropFirst(leadingSpaces))

            if let captures = Self.captures(#"^(#{1,3})\s+(.*)$"#, in: text),
               let level = HeadingLevel(rawValue: captures[0].count) {
                heading = level
                content = captures[1]
                return
            }

            if let captures = Self.captures(#"^[-*+]\s+\[([ xX])\]\s*(.*)$"#, in: text) {
                list = .task
                isChecked = captures[0].lowercased() == "x"
                content = captures[1]
                return
            }

            if let captures = Self.captures(#"^[-*+]\s+(.*)$"#, in: text) {
                list = .bullet
                content = captures[0]
                return
            }

            if let captures = Self.captures(#"^\d+[.)]\s+(.*)$"#, in: text) {
                list = .ordered
                content = captures[0]
                return
            }

            content = text
        }

        private static func captures(_ pattern: String, in string: String) -> [String]? {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let range = NSRange(string.startIndex..., in: string)
            guard let match = regex.firstMatch(in: string, range: range),
                  match.numberOfRanges > 1 else {
                return nil
            }
            return (1..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: string) else { return "" }
                return String(string[range])
            }
        }
    }

    private static func baseAttributes(
        for block: Block,
        fontSize: CGFloat,
        family: EditorFontFamily
    ) -> [NSAttributedString.Key: Any] {
        let size = block.heading?.size(base: fontSize) ?? fontSize
        var attributes: [NSAttributedString.Key: Any] = [
            .font: RichTextFont.make(
                size: size,
                bold: block.heading != nil,
                italic: false,
                code: false,
                family: family
            ),
            .foregroundColor: block.isQuote
                ? RichTextStyle.quoteColor
                : NSColor.labelColor,
        ]
        if block.isQuote {
            attributes[.blinkBlockquote] = true
        }
        if let level = block.heading {
            attributes[.blinkHeading] = level.rawValue
        }
        return attributes
    }

    private static func paragraphStyle(
        for block: Block,
        list: NSTextList?
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = NotesTextEditor.lineSpacing
        style.paragraphSpacingBefore = block.heading?.paragraphSpacingBefore ?? 0
        style.paragraphSpacing = block.heading?.paragraphSpacing ?? 0

        let quoteIndent: CGFloat = block.isQuote ? 16 : 0
        if let list {
            style.textLists = [list]

            let baseIndent = CGFloat(block.level) * 22
            style.firstLineHeadIndent = baseIndent + quoteIndent
            style.headIndent = baseIndent + 22 + quoteIndent
            style.tabStops = [
                NSTextTab(
                    textAlignment: .left,
                    location: baseIndent + 22 + quoteIndent
                )
            ]
        } else if block.isQuote {
            style.headIndent = quoteIndent
            style.firstLineHeadIndent = quoteIndent
        }

        return style
    }

    // MARK: - Inline

    private struct InlineStyles: OptionSet {
        let rawValue: Int

        static let bold = InlineStyles(rawValue: 1 << 0)
        static let italic = InlineStyles(rawValue: 1 << 1)
        static let code = InlineStyles(rawValue: 1 << 2)
        static let strikeThrough = InlineStyles(rawValue: 1 << 3)
        static let underline = InlineStyles(rawValue: 1 << 4)
    }

    private struct InlineRun {
        var text: String
        var styles: InlineStyles = []
        var link: String?
    }

    private static func inlineRuns(in string: String) -> [InlineRun] {
        let pattern = #"(\*\*|__)(.+?)\1|(\*|_)(.+?)\3|`([^`]+)`|~~(.+?)~~|\[([^\]]+)\]\(([^)]+)\)|<u>(.+?)</u>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [InlineRun(text: unescaped(string))]
        }

        let nsString = string as NSString
        var runs: [InlineRun] = []
        var cursor = 0

        for match in regex.matches(
            in: string,
            range: NSRange(location: 0, length: nsString.length)
        ) {
            if match.range.location > cursor {
                runs.append(InlineRun(
                    text: unescaped(nsString.substring(
                        with: NSRange(location: cursor, length: match.range.location - cursor)
                    ))
                ))
            }

            if match.range(at: 2).location != NSNotFound {
                runs.append(InlineRun(
                    text: unescaped(nsString.substring(with: match.range(at: 2))),
                    styles: .bold
                ))
            } else if match.range(at: 4).location != NSNotFound {
                runs.append(InlineRun(
                    text: unescaped(nsString.substring(with: match.range(at: 4))),
                    styles: .italic
                ))
            } else if match.range(at: 5).location != NSNotFound {
                runs.append(InlineRun(
                    text: nsString.substring(with: match.range(at: 5)),
                    styles: .code
                ))
            } else if match.range(at: 6).location != NSNotFound {
                runs.append(InlineRun(
                    text: unescaped(nsString.substring(with: match.range(at: 6))),
                    styles: .strikeThrough
                ))
            } else if match.range(at: 7).location != NSNotFound {
                runs.append(InlineRun(
                    text: unescaped(nsString.substring(with: match.range(at: 7))),
                    link: nsString.substring(with: match.range(at: 8))
                ))
            } else if match.range(at: 9).location != NSNotFound {
                runs.append(InlineRun(
                    text: unescaped(nsString.substring(with: match.range(at: 9))),
                    styles: .underline
                ))
            }

            cursor = NSMaxRange(match.range)
        }

        if cursor < nsString.length {
            runs.append(InlineRun(text: unescaped(nsString.substring(from: cursor))))
        }
        return runs
    }

    private static func unescaped(_ value: String) -> String {
        var result = ""
        var escaping = false
        for character in value {
            if escaping {
                result.append(character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}

import AppKit

/// Converts Blink's attributed notes to Markdown for copying and export.
enum MarkdownConverter {
    static func markdown(for note: Note) -> String {
        guard let data = note.richTextData,
              let attributed = RichTextCoding.attributedString(from: data),
              attributed.length > 0 else {
            return note.content
        }
        return markdown(from: attributed)
    }

    static func markdown(from attributed: NSAttributedString) -> String {
        guard attributed.length > 0 else { return "" }

        let text = attributed.string as NSString
        var blocks: [String] = []
        var location = 0
        var orderedItem = 0

        while location < text.length {
            let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraph.length > 0 else { break }

            let attributes = attributed.attributes(at: paragraph.location, effectiveRange: nil)
            let style = attributes[.paragraphStyle] as? NSParagraphStyle
            let level = (attributes[.blinkHeading] as? Int).flatMap(HeadingLevel.init(rawValue:))
            let isQuote = attributes[.blinkBlockquote] != nil
            let list = style?.textLists.first

            var contentRange = paragraph
            while contentRange.length > 0 {
                let last = text.character(at: NSMaxRange(contentRange) - 1)
                guard last == 10 || last == 13 else { break }
                contentRange.length -= 1
            }

            let content = inlineMarkdown(
                in: attributed,
                range: contentRange,
                suppressBold: level != nil
            )

            var prefix = ""
            if let level {
                prefix = String(repeating: "#", count: level.rawValue) + " "
                orderedItem = 0
            } else if let list {
                switch list.markerFormat {
                case .decimal:
                    orderedItem += 1
                    prefix = "\(orderedItem). "
                case .box:
                    prefix = "- [ ] "
                    orderedItem = 0
                case .check:
                    prefix = "- [x] "
                    orderedItem = 0
                default:
                    prefix = "- "
                    orderedItem = 0
                }

                let extraIndent = max(0, Int(((style?.headIndent ?? 22) - 22) / 22))
                prefix = String(repeating: "    ", count: extraIndent) + prefix
            } else {
                orderedItem = 0
            }

            if isQuote {
                prefix = "> " + prefix
            }

            var line = prefix + content
            if prefix.isEmpty {
                line = escapingLeadingBlockMarker(line)
            }
            blocks.append(line)
            location = NSMaxRange(paragraph)
        }

        return blocks.joined(separator: "\n\n")
    }

    private static func inlineMarkdown(
        in attributed: NSAttributedString,
        range: NSRange,
        suppressBold: Bool
    ) -> String {
        guard range.length > 0 else { return "" }

        let text = attributed.string as NSString
        var pieces: [String] = []

        attributed.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            let raw = text.substring(with: subrange)
            let traits = (attributes[.font] as? NSFont).map {
                NSFontManager.shared.traits(of: $0)
            } ?? []
            let isCode = attributes[.blinkCode] != nil

            var value: String
            if isCode {
                let fence = raw.contains("`") ? "``" : "`"
                let padded = raw.contains("`") ? " \(raw) " : raw
                value = "\(fence)\(padded)\(fence)"
            } else {
                value = escapeInline(raw)
                if traits.contains(.italicFontMask) {
                    value = "*\(value)*"
                }
                if !suppressBold, traits.contains(.boldFontMask) {
                    value = "**\(value)**"
                }
            }

            if (attributes[.strikethroughStyle] as? Int ?? 0) != 0 {
                value = "~~\(value)~~"
            }
            if (attributes[.underlineStyle] as? Int ?? 0) != 0 {
                value = "<u>\(value)</u>"
            }

            if let link = attributes[.link] as? URL {
                value = "[\(value)](\(link.absoluteString))"
            } else if let link = attributes[.link] as? String {
                value = "[\(value)](\(link))"
            }

            pieces.append(value)
        }

        return pieces.joined()
    }

    private static func escapeInline(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for character in value {
            switch character {
            case "\\", "`", "*", "_", "[", "]", "~":
                result.append("\\")
                result.append(character)
            default:
                result.append(character)
            }
        }
        return result
    }

    private static func escapingLeadingBlockMarker(_ line: String) -> String {
        guard let first = line.first else { return line }
        if ["#", ">", "-", "+"].contains(first) {
            return "\\" + line
        }
        if line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
            guard let dot = line.firstIndex(of: ".") else { return line }
            var copy = line
            copy.insert("\\", at: dot)
            return copy
        }
        return line
    }
}

extension Note {
    var markdown: String {
        MarkdownConverter.markdown(for: self)
    }
}

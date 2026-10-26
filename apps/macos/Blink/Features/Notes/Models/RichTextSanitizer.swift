import AppKit

extension NSPasteboard.PasteboardType {
    /// Blink's native rich-text payload, so headings, lists, and code survive
    /// copy/paste inside the app even though RTF drops custom attributes.
    static let blinkRichText = NSPasteboard.PasteboardType("com.hectortorrez.blink.richtext")
}

/// Normalizes external rich text to the attributes Blink actually supports.
/// This keeps pasted notes readable on the glass background and prevents
/// foreign font sizes, colors, and paragraph spacing from leaking into a note.
enum RichTextSanitizer {
    static func richText(
        from pasteboard: NSPasteboard,
        fontSize: CGFloat,
        family: EditorFontFamily
    ) -> NSAttributedString? {
        if let data = pasteboard.data(forType: .blinkRichText),
           let attributed = RichTextCoding.attributedString(from: data) {
            return sanitize(attributed, fontSize: fontSize, family: family)
        }

        if let data = pasteboard.data(forType: .rtf),
           let attributed = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            return sanitize(attributed, fontSize: fontSize, family: family)
        }

        if let data = pasteboard.data(forType: .html),
           let attributed = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.html],
               documentAttributes: nil
           ) {
            return sanitize(attributed, fontSize: fontSize, family: family)
        }

        return nil
    }

    static func sanitize(
        _ source: NSAttributedString,
        fontSize: CGFloat,
        family: EditorFontFamily
    ) -> NSAttributedString {
        guard source.length > 0 else { return source }

        let result = NSMutableAttributedString()
        source.enumerateAttributes(
            in: NSRange(location: 0, length: source.length),
            options: []
        ) { attributes, range, _ in
            // Images and file attachments are not supported by the editor.
            guard attributes[.attachment] == nil else { return }
            let text = (source.string as NSString).substring(with: range)
            guard !text.isEmpty else { return }

            let piece = NSMutableAttributedString(string: text)
            piece.addAttributes(
                sanitizedAttributes(attributes, fontSize: fontSize, family: family),
                range: NSRange(location: 0, length: piece.length)
            )
            result.append(piece)
        }
        return result
    }

    private static func sanitizedAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        fontSize: CGFloat,
        family: EditorFontFamily
    ) -> [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [:]

        let sourceFont = attributes[.font] as? NSFont
        let traits = sourceFont.map { NSFontManager.shared.traits(of: $0) } ?? []
        let level = (attributes[.blinkHeading] as? Int).flatMap(HeadingLevel.init(rawValue:))
        let isCode = attributes[.blinkCode] != nil
        let isQuote = attributes[.blinkBlockquote] != nil

        result[.font] = RichTextFont.make(
            size: level?.size(base: fontSize) ?? fontSize,
            bold: level != nil || traits.contains(.boldFontMask),
            italic: traits.contains(.italicFontMask),
            code: isCode,
            family: family
        )
        result[.foregroundColor] = NSColor.labelColor

        if let underline = attributes[.underlineStyle] as? Int, underline != 0 {
            result[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if let strikethrough = attributes[.strikethroughStyle] as? Int, strikethrough != 0 {
            result[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let level {
            result[.blinkHeading] = level.rawValue
        }
        if isCode {
            result[.blinkCode] = true
        }
        if isQuote {
            result[.blinkBlockquote] = true
        }
        if let link = attributes[.link] as? URL {
            result[.link] = RichTextLink.normalized(link.absoluteString)
        } else if let link = attributes[.link] as? String {
            result[.link] = RichTextLink.normalized(link)
        }

        result[.paragraphStyle] = sanitizedParagraphStyle(
            attributes[.paragraphStyle] as? NSParagraphStyle,
            isQuote: isQuote
        )
        return result
    }

    private static func sanitizedParagraphStyle(
        _ existing: NSParagraphStyle?,
        isQuote: Bool
    ) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        if let existing {
            style.setParagraphStyle(existing)
        }

        style.lineSpacing = NotesTextEditor.lineSpacing
        style.lineHeightMultiple = 1
        style.paragraphSpacing = 0
        style.paragraphSpacingBefore = 0

        let hasList = !style.textLists.isEmpty
        let listIndent: CGFloat = hasList ? 22 : 0
        let quoteIndent: CGFloat = isQuote ? 16 : 0
        style.headIndent = listIndent + quoteIndent
        style.firstLineHeadIndent = quoteIndent
        style.tabStops = hasList
            ? [NSTextTab(textAlignment: .left, location: listIndent + quoteIndent)]
            : []

        return style
    }
}

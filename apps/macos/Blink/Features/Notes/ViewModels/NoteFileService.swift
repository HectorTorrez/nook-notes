import AppKit
import UniformTypeIdentifiers

enum NoteFileError: LocalizedError {
    case noNotes
    case unreadableFile(String)

    var errorDescription: String? {
        switch self {
        case .noNotes:
            "There are no notes to export or import."
        case .unreadableFile(let name):
            "“\(name)” could not be read as a note."
        }
    }
}

/// Pure file conversion/export/import used by the menu commands and tests.
@MainActor
enum NoteFileService {
    static func export(note: Note, to url: URL) throws {
        switch url.pathExtension.lowercased() {
        case "rtf":
            let attributed = attributedString(for: note)
            let data = try attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            try data.write(to: url, options: .atomic)
        case "html", "htm":
            let attributed = attributedString(for: note)
            let data = try attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
            )
            try data.write(to: url, options: .atomic)
        default:
            try note.markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    @discardableResult
    static func exportAll(store: NotesStore, to directory: URL) throws -> Int {
        let fileManager = FileManager.default
        var count = 0

        for workspace in store.workspaces {
            let notes = workspace.notes.filter { !$0.isEmpty }
            guard !notes.isEmpty else { continue }

            let folder = directory.appendingPathComponent(
                sanitizedFilename(workspace.name, fallback: "Workspace"),
                isDirectory: true
            )
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

            for note in notes {
                let url = uniqueURL(
                    in: folder,
                    base: sanitizedFilename(note.title),
                    extension: "md"
                )
                try note.markdown.write(to: url, atomically: true, encoding: .utf8)
                count += 1
            }
        }

        guard count > 0 else { throw NoteFileError.noNotes }
        return count
    }

    static func importNotes(
        from urls: [URL],
        now: Date = Date(),
        fontSize: CGFloat = 16,
        family: EditorFontFamily = .system
    ) throws -> [Note] {
        var notes: [Note] = []

        for (index, url) in urls.enumerated() {
            let extensionName = url.pathExtension.lowercased()
            let attributed: NSAttributedString

            switch extensionName {
            case "rtf":
                let data = try Data(contentsOf: url)
                guard let parsed = try? NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                ) else {
                    throw NoteFileError.unreadableFile(url.lastPathComponent)
                }
                attributed = RichTextSanitizer.sanitize(
                    parsed,
                    fontSize: fontSize,
                    family: family
                )
            case "html", "htm":
                let data = try Data(contentsOf: url)
                guard let parsed = try? NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.html],
                    documentAttributes: nil
                ) else {
                    throw NoteFileError.unreadableFile(url.lastPathComponent)
                }
                attributed = RichTextSanitizer.sanitize(
                    parsed,
                    fontSize: fontSize,
                    family: family
                )
            case "md", "markdown":
                let source = try String(contentsOf: url, encoding: .utf8)
                let parsed = MarkdownImporter.attributedString(
                    from: source,
                    fontSize: fontSize,
                    family: family
                )
                attributed = RichTextSanitizer.sanitize(
                    parsed,
                    fontSize: fontSize,
                    family: family
                )
            default:
                let source = try String(contentsOf: url, encoding: .utf8)
                attributed = NSAttributedString(
                    string: source,
                    attributes: NotesTextEditor.baseAttributes(
                        fontSize: fontSize,
                        family: family
                    )
                )
            }

            let content = attributed.string
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            notes.append(Note(
                content: content,
                richTextData: RichTextCoding.data(from: attributed),
                createdAt: now.addingTimeInterval(-Double(index) * 0.001)
            ))
        }

        guard !notes.isEmpty else { throw NoteFileError.noNotes }
        return notes
    }

    static func sanitizedFilename(_ value: String, fallback: String = "Untitled") -> String {
        let cleaned = value
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .components(separatedBy: .controlCharacters)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return fallback }
        let limited = String(cleaned.prefix(80))
        return limited.hasPrefix(".") ? "_\(limited)" : limited
    }

    private static func attributedString(for note: Note) -> NSAttributedString {
        if let data = note.richTextData,
           let attributed = RichTextCoding.attributedString(from: data),
           attributed.length > 0 {
            return attributed
        }
        return NSAttributedString(
            string: note.content,
            attributes: NotesTextEditor.baseAttributes(fontSize: 16)
        )
    }

    private static func uniqueURL(
        in folder: URL,
        base: String,
        extension fileExtension: String
    ) -> URL {
        var candidate = folder.appendingPathComponent("\(base).\(fileExtension)")
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(index).\(fileExtension)")
            index += 1
        }
        return candidate
    }
}

/// Menu-driven panels and error presentation.
@MainActor
enum NoteFileActions {
    static func exportSelected(from store: NotesStore) {
        let note = store.selectedNote
        guard !note.isEmpty else {
            NSSound.beep()
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Note"
        panel.prompt = "Export"
        panel.nameFieldStringValue = NoteFileService.sanitizedFilename(note.title) + ".md"
        panel.allowedContentTypes = [markdownType, .rtf, .html]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try NoteFileService.export(note: note, to: url)
        } catch {
            present(error)
        }
    }

    static func exportAll(from store: NotesStore) {
        let panel = NSOpenPanel()
        panel.title = "Export All Notes"
        panel.message = "Choose a folder for the exported Markdown files."
        panel.prompt = "Export"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let directory = panel.url else { return }
        do {
            let count = try NoteFileService.exportAll(store: store, to: directory)
            let alert = NSAlert()
            alert.messageText = "Exported \(count) note\(count == 1 ? "" : "s")"
            alert.informativeText = directory.path
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            present(error)
        }
    }

    static func importNotes(into store: NotesStore) {
        let panel = NSOpenPanel()
        panel.title = "Import Notes"
        panel.message = "Choose Markdown, text, RTF, or HTML files."
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [markdownType, .plainText, .rtf, .html]

        guard panel.runModal() == .OK else { return }
        do {
            let notes = try NoteFileService.importNotes(from: panel.urls)
            store.importNotes(notes)
            let alert = NSAlert()
            alert.messageText = "Imported \(notes.count) note\(notes.count == 1 ? "" : "s")"
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            present(error)
        }
    }

    private static var markdownType: UTType {
        UTType(filenameExtension: "md") ?? .plainText
    }

    private static func present(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t complete the operation"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}

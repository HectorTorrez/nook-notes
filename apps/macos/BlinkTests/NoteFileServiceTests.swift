import AppKit
import Foundation
import Testing

@testable import Blink

@MainActor
struct NoteFileServiceTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func exportsMarkdownAndRTF() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let attributed = NSMutableAttributedString(string: "Title\nBody", attributes: [
            .font: NSFont.systemFont(ofSize: 16),
        ])
        attributed.addAttribute(
            .blinkHeading,
            value: HeadingLevel.heading1.rawValue,
            range: NSRange(location: 0, length: 5)
        )
        let note = Note(
            content: "Title\nBody",
            richTextData: RichTextCoding.data(from: attributed),
            createdAt: epoch
        )

        let markdownURL = directory.appendingPathComponent("note.md")
        try NoteFileService.export(note: note, to: markdownURL)
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("# Title"))
        #expect(markdown.contains("Body"))

        let rtfURL = directory.appendingPathComponent("note.rtf")
        try NoteFileService.export(note: note, to: rtfURL)
        let rtf = try Data(contentsOf: rtfURL)
        #expect(rtf.isEmpty == false)
    }

    @Test
    func exportsOneMarkdownFilePerNonEmptyNote() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NotesStore(now: { self.epoch })

        store.updateSelectedContent("Note one", richTextData: nil)
        store.createNote()
        store.updateSelectedContent("Note two", richTextData: nil)

        let output = directory.appendingPathComponent("export", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let count = try NoteFileService.exportAll(store: store, to: output)
        #expect(count == 2)

        let workspaceFolder = output.appendingPathComponent(Workspace.defaultName)
        let files = try FileManager.default.contentsOfDirectory(atPath: workspaceFolder.path)
        #expect(files.filter { $0.hasSuffix(".md") }.count == 2)
    }

    @Test
    func importsMarkdownIntoRichText() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("import.md")
        try """
        # Imported

        - One
        - [x] Done
        """.write(to: url, atomically: true, encoding: .utf8)

        let notes = try NoteFileService.importNotes(from: [url], now: epoch)
        #expect(notes.count == 1)
        #expect(notes[0].content.contains("Imported"))
        #expect(notes[0].content.contains("Done"))

        let data = try #require(notes[0].richTextData)
        let attributed = try #require(RichTextCoding.attributedString(from: data))
        let text = attributed.string as NSString
        let titleIndex = text.range(of: "Imported").location
        #expect(attributed.attribute(.blinkHeading, at: titleIndex, effectiveRange: nil) as? Int == 1)
    }

    @Test
    func importsPlainTextAndRTF() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let textURL = directory.appendingPathComponent("note.txt")
        try "Plain notes".write(to: textURL, atomically: true, encoding: .utf8)

        let rich = NSAttributedString(
            string: "Rich notes",
            attributes: [.font: NSFont.systemFont(ofSize: 16)]
        )
        let rtfData = try rich.data(
            from: NSRange(location: 0, length: rich.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        let rtfURL = directory.appendingPathComponent("note.rtf")
        try rtfData.write(to: rtfURL)

        let notes = try NoteFileService.importNotes(from: [textURL, rtfURL], now: epoch)
        #expect(notes.count == 2)
        #expect(notes[0].content.contains("Plain notes"))
        #expect(notes[1].content.contains("Rich notes"))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlinkFileTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

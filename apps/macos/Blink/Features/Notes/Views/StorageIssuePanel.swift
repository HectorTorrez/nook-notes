import AppKit
import SwiftUI

struct StorageIssuePanel: View {
    let store: NotesStore
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Notes Storage")
                    .font(.system(size: 13, weight: .semibold))
            }

            Text(store.storageIssueMessage)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let url = store.storageIssueURL {
                Text(url.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            HStack(spacing: 8) {
                if let url = store.storageIssueURL {
                    Button("Reveal in Finder") {
                        reveal(url)
                    }
                }

                Spacer()

                if store.saveError != nil, !store.savesBlocked {
                    Button("Retry Save") {
                        store.retrySave()
                    }
                }

                if store.savesBlocked {
                    Button("Close", action: onClose)
                } else {
                    Button("Dismiss") {
                        store.dismissStorageIssue()
                        onClose()
                    }
                }
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 380)
    }

    private func reveal(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }
}

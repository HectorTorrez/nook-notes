import SwiftUI

struct AppearancePanel: View {
    @Binding var backgroundOpacity: Double
    @Binding var fontSize: Double

    static let fontSizes: [(label: String, size: Double)] = [("S", 14), ("M", 16), ("L", 18), ("XL", 21)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Background")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Slider(value: $backgroundOpacity, in: 0...1)
                    .controlSize(.small)
                    .accessibilityLabel("Background opacity")
                HStack {
                    Text("Glass")
                    Spacer()
                    Text("Solid")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Text Size")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("Text Size", selection: $fontSize) {
                    ForEach(Self.fontSizes, id: \.size) { option in
                        Text(option.label).tag(option.size)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .padding(16)
        .frame(width: 250)
    }
}

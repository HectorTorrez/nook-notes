import SwiftUI

struct AppearancePanel: View {
    @Binding var backgroundOpacity: Double
    @Binding var fontSize: Double

    @AppStorage(Theme.accentPaletteKey) private var accentPalette: AccentPalette = Theme.defaultAccentPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentPalette.color)
                Text("Appearance")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                accentPicker
                backgroundPicker
                TextSizeSlider(fontSize: $fontSize)
            }
            .padding(16)
        }
        .frame(width: 280)
    }

    private var accentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            AccentSwatches(selection: $accentPalette)
        }
    }

    private var backgroundPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Background")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(backgroundOpacity * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
            }
            Slider(value: $backgroundOpacity, in: 0...1)
                .controlSize(.small)
                .accessibilityLabel("Background opacity")
            HStack {
                Text("Glass")
                Spacer()
                Text("Solid")
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
    }
}

import SwiftUI

struct AppearancePanel: View {
    @Binding var backgroundOpacity: Double
    @Binding var fontSize: Double

    @AppStorage(Theme.accentPaletteKey) private var accentPalette: AccentPalette = Theme.defaultAccentPalette

    static let fontSizes: [(label: String, size: Double)] = [("S", 14), ("M", 16), ("L", 18), ("XL", 21)]

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

                VStack(alignment: .leading, spacing: 8) {
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
        }
        .frame(width: 260)
    }

    private var accentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(AccentPalette.allCases) { palette in
                    Button {
                        accentPalette = palette
                    } label: {
                        ZStack {
                            Circle()
                                .fill(palette.color)
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.6), lineWidth: 2)
                                .opacity(accentPalette == palette ? 1 : 0)
                        }
                        .frame(width: 16, height: 16)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                        }
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(palette.title)
                    .accessibilityLabel(palette.title)
                    .accessibilityAddTraits(accentPalette == palette ? .isSelected : [])
                }
            }
        }
    }
}

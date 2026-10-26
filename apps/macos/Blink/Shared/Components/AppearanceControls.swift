import SwiftUI

/// The accent colour swatches shared by the format bar and Settings.
struct AccentSwatches: View {
    @Binding var selection: AccentPalette

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AccentPalette.allCases) { palette in
                Button {
                    selection = palette
                } label: {
                    ZStack {
                        Circle()
                            .fill(palette.color)
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.6), lineWidth: 2)
                            .opacity(selection == palette ? 1 : 0)
                    }
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(PointerButtonStyle())
                .help(palette.title)
                .accessibilityLabel(palette.title)
                .accessibilityAddTraits(selection == palette ? .isSelected : [])
            }
        }
    }
}

/// A compact text-size control used in both appearance surfaces.
struct TextSizeSlider: View {
    @Binding var fontSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Text Size")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(fontSize)) pt")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())
            }
            Slider(value: $fontSize, in: 12...28, step: 1)
                .controlSize(.small)
                .accessibilityLabel("Text size")
            HStack {
                Text("A")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("A")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

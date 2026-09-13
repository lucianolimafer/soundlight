import AppKit
import SwiftUI

struct ControlPanel: View {
    @EnvironmentObject private var controls: SystemControls
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                CapsuleSlider(
                    value: $controls.volume,
                    symbol: SystemControlKind.volume.symbol(value: controls.volume),
                    tint: SystemControlKind.volume.tint(
                        colorScheme: colorScheme,
                        contrast: colorSchemeContrast
                    ),
                    accessibilityLabel: SystemControlKind.volume.accessibilityLabel
                )
                CapsuleSlider(
                    value: $controls.brightness,
                    symbol: SystemControlKind.brightness.symbol(value: controls.brightness),
                    tint: SystemControlKind.brightness.tint(
                        colorScheme: colorScheme,
                        contrast: colorSchemeContrast
                    ),
                    accessibilityLabel: SystemControlKind.brightness.accessibilityLabel
                )
            }

            HStack {
                Text("SoundLight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Exit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 220)
        .background(.ultraThinMaterial)
        .onAppear { controls.refresh() }
    }
}

struct CapsuleSlider: View {
    @Binding var value: Double
    let symbol: String
    let tint: Color
    let accessibilityLabel: String

    var body: some View {
        GeometryReader { proxy in
            let normalizedValue = min(1, max(0, value))
            let fillHeight = proxy.size.height * normalizedValue

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule().stroke(.white.opacity(0.18), lineWidth: 1)
                    }

                Rectangle()
                    .fill(Color.white.opacity(0.94))
                    .frame(height: fillHeight)
                    .animation(.easeInOut(duration: 0.14), value: normalizedValue)

                Image(systemName: symbol)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(height: PillMetrics.width)
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let verticalFraction = Double(gesture.location.y / proxy.size.height)
                        value = min(1, max(0, 1 - verticalFraction))
                    }
            )
        }
        .frame(width: PillMetrics.width, height: PillMetrics.height)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.05)
            case .decrement: value = max(0, value - 0.05)
            @unknown default: break
            }
        }
    }
}

enum PillMetrics {
    static let width: CGFloat = 78
    static let height: CGFloat = 210
}

extension SystemControlKind {
    func tint(colorScheme: ColorScheme, contrast: ColorSchemeContrast) -> Color {
        if contrast == .increased {
            return .primary
        }

        return switch (self, colorScheme) {
        case (.volume, .light): Color(red: 0.04, green: 0.52, blue: 0.76)
        case (.volume, .dark): Color(red: 0.32, green: 0.78, blue: 0.98)
        case (.brightness, .light): Color(red: 0.90, green: 0.56, blue: 0.02)
        case (.brightness, .dark): Color(red: 1.00, green: 0.82, blue: 0.18)
        @unknown default: Color.primary
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .volume: "Volume"
        case .brightness: "Brightness"
        }
    }

    func symbol(value: Double) -> String {
        switch self {
        case .volume: value == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill"
        case .brightness: "sun.max.fill"
        }
    }
}

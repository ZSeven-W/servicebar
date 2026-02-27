import SwiftUI

struct RefreshButton: View {
    let isScanning: Bool
    let action: () -> Void

    @State private var rotation: Double = 0

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .medium))
                .rotationEffect(.degrees(rotation))
                .animation(
                    isScanning
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: isScanning
                )
        }
        .buttonStyle(.borderless)
        .disabled(isScanning)
        .onChange(of: isScanning) { newValue in
            if newValue {
                rotation = 360
            } else {
                rotation = 0
            }
        }
    }
}

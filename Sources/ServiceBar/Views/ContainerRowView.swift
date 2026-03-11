import SwiftUI

struct ContainerRowView: View {
    let container: DockerContainer
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void

    private var statusColor: Color {
        if container.isRunning {
            return .green
        } else if container.isPaused {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 4) {
                // Container name
                Text(container.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                // Status badge
                HStack(spacing: 3) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(container.status)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Port mappings
                if !container.ports.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "network")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(container.ports.prefix(2).joined(separator: ", "))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }

                // Action buttons
                HStack(spacing: 2) {
                    if container.isRunning {
                        Button(action: onRestart) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.borderless)
                        .help("Restart container")

                        Button(action: onStop) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.red)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.borderless)
                        .help("Stop container")
                    } else if container.isExited || container.status == "created" {
                        Button(action: onStart) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.borderless)
                        .help("Start container")
                    }
                }
            }

            // Image name
            HStack(spacing: 4) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(container.image)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.5))
        )
    }
}

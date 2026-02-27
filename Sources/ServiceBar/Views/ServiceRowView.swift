import SwiftUI

struct ServiceRowView: View {
    let service: ServiceInfo
    var isStopped: Bool = false
    let onStop: () -> Void
    let onRestart: () -> Void
    let onHide: (() -> Void)?
    var isHidden: Bool = false
    var onStart: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    @State private var copiedField: CopiedField?
    @State private var isHoveringCommand = false
    @State private var hoverTimer: DispatchWorkItem?
    @State private var confirmingStop = false

    private enum CopiedField: Equatable {
        case pid, port, command
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 4) {
                // Process name
                Text(service.processName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                // Port number — click to copy
                Button {
                    copyToClipboard("\(service.port)", field: .port)
                } label: {
                    if copiedField == .port {
                        Text("Copied!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                    } else {
                        Text(verbatim: ":\(service.port)")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(isStopped ? Color.secondary : Color.orange)
                    }
                }
                .buttonStyle(.borderless)
                .help("Copy port number")

                if isStopped {
                    Text("Stopped")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.red.opacity(0.7))
                } else {
                    // PID — click to copy
                    Button {
                        copyToClipboard("\(service.pid)", field: .pid)
                    } label: {
                        if copiedField == .pid {
                            Text("Copied!")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.green)
                        } else {
                            Text(verbatim: "PID \(service.pid)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                // Action buttons
                HStack(spacing: 2) {
                    if isStopped {
                        Button { onStart?() } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.borderless)
                        .help("Start service")

                        Button { onRemove?() } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove from list")
                    } else {
                        if let onHide = onHide {
                            Button(action: onHide) {
                                Image(systemName: isHidden ? "eye" : "eye.slash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(isHidden ? .blue : .secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.borderless)
                            .help(isHidden ? "Show this service" : "Hide this service")
                        }

                        Button(action: onRestart) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.borderless)
                        .help("Restart service")

                        if confirmingStop {
                            HStack(spacing: 2) {
                                Button {
                                    confirmingStop = false
                                    onStop()
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .help("Confirm stop")

                                Button {
                                    confirmingStop = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("Cancel")
                            }
                        } else {
                            Button {
                                confirmingStop = true
                            } label: {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.red)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.borderless)
                            .help("Stop service")
                        }
                    }
                }
            }

            // Command line — click to copy, hover to see full path
            Button {
                copyToClipboard(service.command, field: .command)
            } label: {
                if copiedField == .command {
                    Text("Path copied!")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                } else {
                    Text(service.command)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.borderless)
            .help("Copy command path")
            .onHover { hovering in
                hoverTimer?.cancel()
                if hovering {
                    let task = DispatchWorkItem {
                        isHoveringCommand = true
                    }
                    hoverTimer = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: task)
                } else {
                    isHoveringCommand = false
                }
            }
            .popover(isPresented: $isHoveringCommand, arrowEdge: .bottom) {
                Text(service.command)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 500)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.5))
        )
        .opacity(isStopped ? 0.7 : 1.0)
    }

    private func copyToClipboard(_ text: String, field: CopiedField) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedField = field
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedField == field {
                copiedField = nil
            }
        }
    }
}

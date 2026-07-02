import ServiceManagement
import SwiftUI

struct SettingsView: View {
    // Launch at Login
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    // Auto-refresh
    @AppStorage("AutoRefreshInterval") private var refreshInterval: Double = 300

    // Port range filter
    @AppStorage("PortFilterMin") private var portMin: Int = 0
    @AppStorage("PortFilterMax") private var portMax: Int = 0
    @State private var portMinText: String = ""
    @State private var portMaxText: String = ""

    // Icon style
    @AppStorage("ShowCountBadge") private var showCountBadge: Bool = true

    // Hidden items
    @ObservedObject private var hiddenManager = HiddenItemsManager.shared

    var body: some View {
        Form {
            generalSection
            refreshSection
            portFilterSection
            iconStyleSection
            hiddenItemsSection

            Section {
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
                Text("ServiceBar v\(version) (\(build))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 480)
        .onAppear {
            portMinText = portMin > 0 ? "\(portMin)" : ""
            portMaxText = portMax > 0 ? "\(portMax)" : ""
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(newValue)
                }
        }
    }

    private var refreshSection: some View {
        Section {
            Picker("Refresh interval", selection: $refreshInterval) {
                Text("30 seconds").tag(30.0)
                Text("1 minute").tag(60.0)
                Text("2 minutes").tag(120.0)
                Text("5 minutes").tag(300.0)
                Text("10 minutes").tag(600.0)
            }
            .onChange(of: refreshInterval) { _ in
                NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
            }
        }
    }

    private var portFilterSection: some View {
        Section {
            HStack(spacing: 8) {
                Text("Port range")
                    .font(.body)

                Spacer()

                TextField("min", text: $portMinText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12, design: .monospaced))
                    .onChange(of: portMinText) { val in
                        portMin = Int(val) ?? 0
                    }

                Text("–")
                    .foregroundStyle(.tertiary)

                TextField("max", text: $portMaxText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12, design: .monospaced))
                    .onChange(of: portMaxText) { val in
                        portMax = Int(val) ?? 0
                    }

                if portMin > 0 || portMax > 0 {
                    Button {
                        portMin = 0
                        portMax = 0
                        portMinText = ""
                        portMaxText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear filter")
                }
            }
        }
    }

    private var iconStyleSection: some View {
        Section {
            Picker("Icon style", selection: $showCountBadge) {
                Text("⚙ 5  Gear + count").tag(true)
                Text("⚙    Gear only").tag(false)
            }
            .pickerStyle(.radioGroup)
            .onChange(of: showCountBadge) { _ in
                NotificationCenter.default.post(name: .iconStyleChanged, object: nil)
            }
        } header: {
            Text("Menu Bar Icon")
        }
    }

    private var hiddenItemsSection: some View {
        Section {
            if hiddenManager.hiddenApps.isEmpty && hiddenManager.hiddenServices.isEmpty {
                HStack {
                    Spacer()
                    Text("No hidden items")
                        .foregroundStyle(.tertiary)
                        .font(.callout)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                ForEach(hiddenManager.hiddenApps.sorted(), id: \.self) { app in
                    HStack {
                        Image(systemName: "app.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                        Text(app)
                        Spacer()
                        Button("Show") {
                            hiddenManager.toggleApp(app)
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    }
                }

                ForEach(hiddenManager.hiddenServices.sorted(), id: \.self) { key in
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 6))
                        Text(key)
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Button("Show") {
                            hiddenManager.unhideServiceByKey(key)
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                    }
                }

                HStack {
                    Spacer()
                    Button("Reset All", role: .destructive) {
                        hiddenManager.resetAll()
                    }
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }
        } header: {
            HStack {
                Text("Hidden Items")
                if !hiddenManager.hiddenApps.isEmpty || !hiddenManager.hiddenServices.isEmpty {
                    Text("\(hiddenManager.hiddenApps.count + hiddenManager.hiddenServices.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.secondary))
                }
            }
        }
    }

    // MARK: - Helpers

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let refreshIntervalChanged = Notification.Name("RefreshIntervalChanged")
    static let iconStyleChanged = Notification.Name("IconStyleChanged")
    static let openSettings = Notification.Name("OpenSettings")
    static let closePopover = Notification.Name("ClosePopover")
}

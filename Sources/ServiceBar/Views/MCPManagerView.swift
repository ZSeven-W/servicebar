import SwiftUI

struct MCPManagerView: View {
    @ObservedObject var scanner: MCPScanner
    @ObservedObject var installer: MCPInstaller
    let onClose: () -> Void
    @State private var selectedAgentType: MCPAgentType = .claudeCode
    @State private var expandedAgents: Set<MCPAgentType> = Set(MCPAgentType.allCases)
    @State private var installingServerId: String?
    @State private var showInstallSheet = false
    @State private var pendingServer: MCPServer?
    @State private var installOutput: String = ""
    @State private var showInstallResult = false
    @State private var installSuccess = false
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.purple)
                
                Text("MCP Servers")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Button {
                    scanner.scan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .disabled(scanner.isScanning)
                .help("Refresh MCP servers")

                Button {
                    onClose()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Services")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.borderless)
                .help("Back to services")

                Button {
                    onClose()
                    NotificationCenter.default.post(name: .closePopover, object: nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Close ServiceBar")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()

            searchBar
            
            if scanner.isScanning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Scanning...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                let agentTypes = filteredAgentTypes
                if agentTypes.isEmpty {
                    emptySearchState
                } else {
                    ForEach(agentTypes, id: \.self) { agentType in
                        agentSection(agentType)
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Search servers…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var filteredAgentTypes: [MCPAgentType] {
        MCPAgentType.allCases.filter { !filteredServers(for: $0).isEmpty }
    }

    private var emptySearchState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Text("No matching servers")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    @ViewBuilder
    private func agentSection(_ agentType: MCPAgentType) -> some View {
        let servers = filteredServers(for: agentType)
        let installedCount = servers.filter { $0.status == .installed }.count
        
        VStack(spacing: 0) {
            Button {
                if expandedAgents.contains(agentType) {
                    expandedAgents.remove(agentType)
                } else {
                    expandedAgents.insert(agentType)
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(expandedAgents.contains(agentType) ? 90 : 0))
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: agentIcon(for: agentType))
                        .font(.system(size: 12))
                        .foregroundStyle(agentColor(for: agentType))
                    
                    Text(agentType.displayName)
                        .font(.system(size: 12, weight: .medium))
                    
                    Text("\(installedCount)/\(servers.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(Color.primary.opacity(0.02))
            
            if expandedAgents.contains(agentType) {
                VStack(spacing: 2) {
                    ForEach(servers) { server in
                        MCPServerRowView(
                            server: server,
                            isInstalling: installingServerId == server.id,
                            onInstall: { installServer(server) },
                            onUninstall: { uninstallServer(server) },
                            onConfigure: { configureServer(server) }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
    }

    private func filteredServers(for agentType: MCPAgentType) -> [MCPServer] {
        let servers = scanner.servers(for: agentType)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return servers }

        return servers.filter { server in
            server.name.lowercased().contains(query) ||
            server.description.lowercased().contains(query) ||
            server.packageName.lowercased().contains(query) ||
            server.id.lowercased().contains(query)
        }
    }
    
    private func installServer(_ server: MCPServer) {
        installingServerId = server.id
        installOutput = ""
        
        installer.install(server) { [self] success, configEntry in
            installingServerId = nil
            
            if success {
                if let config = configEntry {
                    installOutput = "✅ Installed!\n\nAdd to \(server.agentType.configFileName):\n\n\(config)"
                } else {
                    installOutput = "✅ Installed successfully!"
                }
                installSuccess = true
            } else {
                installOutput = "❌ \(configEntry ?? "Installation failed")"
                installSuccess = false
            }
            
            showInstallResult = true
            scanner.scan()
        }
    }
    
    private func uninstallServer(_ server: MCPServer) {
        installingServerId = server.id
        
        installer.removeFromConfig(server) { [self] _, _ in
            installer.uninstall(server) { success, error in
                installingServerId = nil
                scanner.scan()
            }
        }
    }
    
    private func configureServer(_ server: MCPServer) {
        if installer.isConfigured(server) {
            installer.removeFromConfig(server) { success, _ in
                scanner.scan()
            }
        } else {
            installer.addToConfig(server) { success, _ in
                scanner.scan()
            }
        }
    }
    
    private func agentIcon(for agentType: MCPAgentType) -> String {
        switch agentType {
        case .claudeCode: return "sparkles"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .opencode: return "curlybraces"
        }
    }
    
    private func agentColor(for agentType: MCPAgentType) -> Color {
        switch agentType {
        case .claudeCode: return .purple
        case .codex: return .blue
        case .opencode: return .orange
        }
    }
}

struct MCPServerRowView: View {
    let server: MCPServer
    let isInstalling: Bool
    let onInstall: () -> Void
    let onUninstall: () -> Void
    let onConfigure: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(server.name)
                    .font(.system(size: 11, weight: .medium))
                
                Text(server.description)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isInstalling {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                // Configure button
                Button {
                    onConfigure()
                } label: {
                    Image(systemName: server.status == .installed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(server.status == .installed ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                .help(server.status == .installed ? "Remove from config" : "Add to config")
                
                // Install/Uninstall button
                if server.status == .installed {
                    Button {
                        onUninstall()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Uninstall")
                } else {
                    Button {
                        onInstall()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.borderless)
                    .help(server.installCommand)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var statusColor: Color {
        switch server.status {
        case .installed: return .green
        case .notInstalled: return .secondary.opacity(0.3)
        case .error: return .red
        }
    }
}

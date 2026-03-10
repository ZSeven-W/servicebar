import Foundation
import Combine

final class MCPScanner: ObservableObject {
    @Published var servers: [MCPServer] = []
    @Published var isScanning = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        scan()
    }
    
    func scan() {
        guard !isScanning else { return }
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var scannedServers: [MCPServer] = []
            
            // Check installed npm packages for each agent type
            for agentType in MCPAgentType.allCases {
                let installedPackages = self.getInstalledNPMPackages(for: agentType)
                let configServers = self.getConfiguredServers(for: agentType)
                
                for var server in MCPServerRegistry.servers(for: agentType) {
                    // Check if the npm package is installed
                    if installedPackages.contains(server.packageName) {
                        server.status = .installed
                    }
                    // Check if it's configured (even if not installed via npm)
                    else if configServers.contains(server.packageName) {
                        server.status = .installed
                    }
                    // Check if there's an error state
                    else if self.hasError(server: server, agentType: agentType) {
                        server.status = .error
                    }
                    else {
                        server.status = .notInstalled
                    }
                    scannedServers.append(server)
                }
            }
            
            DispatchQueue.main.async {
                self.servers = scannedServers
                self.isScanning = false
            }
        }
    }
    
    func servers(for agentType: MCPAgentType) -> [MCPServer] {
        return servers.filter { $0.agentType == agentType }
    }
    
    func installedServers(for agentType: MCPAgentType) -> [MCPServer] {
        return servers.filter { $0.agentType == agentType && $0.status == .installed }
    }
    
    func updateServerStatus(_ serverId: String, status: MCPStatus) {
        if let index = servers.firstIndex(where: { $0.id == serverId }) {
            servers[index].status = status
        }
    }
    
    // MARK: - Private
    
    private func getInstalledNPMPackages(for agentType: MCPAgentType) -> Set<String> {
        let output = Self.shell("/usr/local/bin/npm", arguments: ["list", "-g", "--depth=0", "--json"])
        
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dependencies = json["dependencies"] as? [String: Any] else {
            // Try alternative path for Node
            return getInstalledNPMPackagesAlt()
        }
        
        return Set(dependencies.keys)
    }
    
    private func getInstalledNPMPackagesAlt() -> Set<String> {
        // Try using npx to list global packages
        let output = Self.shell("/usr/bin/env", arguments: ["npx", "npm", "list", "-g", "--depth=0", "--json"])
        
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dependencies = json["dependencies"] as? [String: Any] else {
            return []
        }
        
        return Set(dependencies.keys)
    }
    
    private func getConfiguredServers(for agentType: MCPAgentType) -> Set<String> {
        let configPath = agentType.configPath
        
        guard FileManager.default.fileExists(atPath: configPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        
        var configuredPackages = Set<String>()
        
        // Look for mcpServers configuration
        if let mcpServers = json["mcpServers"] as? [String: Any] {
            for (_, serverConfig) in mcpServers {
                if let config = serverConfig as? [String: Any],
                   let command = config["command"] as? String {
                    // Extract package name from command
                    // e.g., "npx" or "/path/to/node" -> extract package
                    let parts = command.components(separatedBy: " ")
                    if let package = parts.last {
                        configuredPackages.insert(package)
                    }
                }
            }
        }
        
        return configuredPackages
    }
    
    private func hasError(server: MCPServer, agentType: MCPAgentType) -> Bool {
        // Check if package exists but has issues
        // This is a placeholder - could be expanded to check for specific error states
        return false
    }
    
    private static func shell(_ path: String, arguments: [String]) -> String {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

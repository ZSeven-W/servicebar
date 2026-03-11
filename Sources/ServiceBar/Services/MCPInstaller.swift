import Foundation
import Combine

final class MCPInstaller: ObservableObject {
    @Published var isInstalling = false
    @Published var installProgress: String = ""
    @Published var lastError: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    func install(_ server: MCPServer, completion: @escaping (Bool, String?) -> Void) {
        guard !isInstalling else {
            completion(false, "Installation already in progress")
            return
        }
        
        isInstalling = true
        installProgress = "Installing \(server.packageName)..."
        lastError = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Run the install command
            let output = Self.runCommand("/usr/local/bin/npm", arguments: ["install", "-g", server.packageName])
            
            DispatchQueue.main.async {
                self?.isInstalling = false
                
                if output.exitCode == 0 {
                    self?.installProgress = "Installed \(server.packageName)"
                    
                    // Now generate the config entry
                    let configEntry = self?.generateConfigEntry(for: server)
                    completion(true, configEntry)
                } else {
                    self?.lastError = output.errorOutput.isEmpty ? "Installation failed" : output.errorOutput
                    self?.installProgress = "Failed to install"
                    completion(false, self?.lastError)
                }
            }
        }
    }
    
    func uninstall(_ server: MCPServer, completion: @escaping (Bool, String?) -> Void) {
        guard !isInstalling else {
            completion(false, "Uninstallation already in progress")
            return
        }
        
        isInstalling = true
        installProgress = "Uninstalling \(server.packageName)..."
        lastError = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Run the uninstall command
            let output = Self.runCommand("/usr/local/bin/npm", arguments: ["uninstall", "-g", server.packageName])
            
            DispatchQueue.main.async {
                self?.isInstalling = false
                
                if output.exitCode == 0 {
                    self?.installProgress = "Uninstalled \(server.packageName)"
                    completion(true, nil)
                } else {
                    self?.lastError = output.errorOutput.isEmpty ? "Uninstallation failed" : output.errorOutput
                    self?.installProgress = "Failed to uninstall"
                    completion(false, self?.lastError)
                }
            }
        }
    }
    
    func generateConfigEntry(for server: MCPServer) -> String {
        let command: String
        let args: [String]
        
        // Determine the command based on package type
        if server.packageName.contains("filesystem") {
            // filesystem server requires a directory argument
            let allowedDir = NSHomeDirectory()
            command = "npx"
            args = ["-y", server.packageName, allowedDir]
        } else {
            command = "npx"
            args = ["-y", server.packageName]
        }
        
        // Generate JSON config entry
        let configJson: [String: Any] = [
            server.name: [
                "command": command,
                "args": args
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: configJson, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "// Add this to \(server.agentType.configFileName) under mcpServers:\n\(server.name): {\n  \"command\": \"\(command)\",\n  \"args\": \(args)\n}"
    }
    
    func addToConfig(_ server: MCPServer, completion: @escaping (Bool, String?) -> Void) {
        let configPath = server.agentType.configPath
        var existingConfig: [String: Any] = [:]
        
        // Read existing config
        if FileManager.default.fileExists(atPath: configPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            existingConfig = json
        }
        
        // Ensure mcpServers exists
        if existingConfig["mcpServers"] == nil {
            existingConfig["mcpServers"] = [String: Any]()
        }
        
        guard var mcpServers = existingConfig["mcpServers"] as? [String: Any] else {
            completion(false, "Failed to update config")
            return
        }
        
        // Build server config
        let command: String
        let args: [String]
        
        if server.packageName.contains("filesystem") {
            let allowedDir = NSHomeDirectory()
            command = "npx"
            args = ["-y", server.packageName, allowedDir]
        } else {
            command = "npx"
            args = ["-y", server.packageName]
        }
        
        mcpServers[server.name] = [
            "command": command,
            "args": args
        ]
        
        existingConfig["mcpServers"] = mcpServers
        
        // Write back
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: existingConfig, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: configPath))
            completion(true, "Added to \(server.agentType.configFileName)")
        } catch {
            completion(false, "Failed to write config: \(error.localizedDescription)")
        }
    }
    
    func removeFromConfig(_ server: MCPServer, completion: @escaping (Bool, String?) -> Void) {
        let configPath = server.agentType.configPath
        
        guard FileManager.default.fileExists(atPath: configPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var mcpServers = json["mcpServers"] as? [String: Any] else {
            completion(true, "No config to remove from")
            return
        }
        
        // Remove the server
        mcpServers.removeValue(forKey: server.name)
        json["mcpServers"] = mcpServers
        
        // Write back
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: configPath))
            completion(true, "Removed from \(server.agentType.configFileName)")
        } catch {
            completion(false, "Failed to write config: \(error.localizedDescription)")
        }
    }
    
    func isConfigured(_ server: MCPServer) -> Bool {
        let configPath = server.agentType.configPath
        
        guard FileManager.default.fileExists(atPath: configPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mcpServers = json["mcpServers"] as? [String: Any] else {
            return false
        }
        
        return mcpServers[server.name] != nil
    }
    
    // MARK: - Private
    
    private static func runCommand(_ path: String, arguments: [String]) -> (exitCode: Int32, output: String, errorOutput: String) {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            return (task.terminationStatus, output, errorOutput)
        } catch {
            return (-1, "", error.localizedDescription)
        }
    }
}

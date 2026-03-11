import Foundation

final class ProcessScanner {
    private let excludedProcesses: Set<String>
    private let devKeywords: Set<String>

    init(
        excludedProcesses: Set<String> = [
            "rapportd", "sharingd", "WiFiAgent", "airportd",
            "bluetoothd", "controlce", "mDNSResponder", "systemsta"
        ],
        devKeywords: Set<String> = [
            "node", "go", "python", "python3", "ruby", "java", "php", "rust", "cargo"
        ]
    ) {
        self.excludedProcesses = excludedProcesses
        self.devKeywords = devKeywords
    }

    func scan(containers: [DockerContainer]) -> [ServiceInfo] {
        let lsofOutput = Self.shell("/usr/sbin/lsof", arguments: ["-iTCP", "-sTCP:LISTEN", "-n", "-P", "-F", "pcn"])
        let psOutput = Self.shell("/bin/ps", arguments: ["-Ax", "-o", "pid,tty,command"])
        let psMap = parsePsOutput(psOutput)

        let resourceOutput = Self.shell("/bin/ps", arguments: ["-Ax", "-o", "pid,pcpu,rss"])
        let resourceMap = parseResourceOutput(resourceOutput)

        return parseLsofOutput(
            lsofOutput,
            psMap: psMap,
            resourceMap: resourceMap,
            containers: containers
        )
    }

    private func parsePsOutput(_ output: String) -> [Int32: (tty: String, command: String)] {
        var map: [Int32: (tty: String, command: String)] = [:]

        for line in output.components(separatedBy: "\n").dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 3 else { continue }

            if let pid = Int32(components[0]) {
                let tty = components[1]
                let command = components[2...].joined(separator: " ")
                map[pid] = (tty, command)
            }
        }

        return map
    }

    private func parseResourceOutput(_ output: String) -> [Int32: (cpu: Double, rss: Int)] {
        var map: [Int32: (cpu: Double, rss: Int)] = [:]

        for line in output.components(separatedBy: "\n").dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 3 else { continue }

            if let pid = Int32(components[0]),
               let cpu = Double(components[1]),
               let rss = Int(components[2]) {
                map[pid] = (cpu, rss)
            }
        }

        return map
    }

    private func parseLsofOutput(
        _ output: String,
        psMap: [Int32: (tty: String, command: String)],
        resourceMap: [Int32: (cpu: Double, rss: Int)],
        containers: [DockerContainer]
    ) -> [ServiceInfo] {
        var results: [ServiceInfo] = []
        var seenIds: Set<String> = []

        var currentPID: Int32?
        var currentName: String?

        for line in output.components(separatedBy: "\n") {
            guard !line.isEmpty else { continue }

            let prefix = line.first!
            let value = String(line.dropFirst())

            switch prefix {
            case "p":
                currentPID = Int32(value)
                currentName = nil
            case "c":
                currentName = value
            case "n":
                guard let pid = currentPID, let name = currentName else { continue }
                guard let port = extractPort(from: value) else { continue }
                guard port >= 1024 else { continue }
                guard !excludedProcesses.contains(name) else { continue }

                let id = "\(pid)-\(port)"
                guard !seenIds.contains(id) else { continue }
                seenIds.insert(id)

                let psInfo = psMap[pid]
                let command = psInfo?.command ?? name
                let hasTTY = (psInfo?.tty ?? "??") != "??"

                let resource = resourceMap[pid]
                let cpuPercent = resource?.cpu ?? 0
                let rssPages = resource?.rss ?? 0
                let memoryMB = (rssPages * 4096) / 1024 / 1024

                let isSystem = command.hasPrefix("/System/") ||
                               command.hasPrefix("/usr/libexec/") ||
                               command.hasPrefix("/usr/sbin/") ||
                               command.hasPrefix("/sbin/")

                var isContainer = false
                var containerId: String?

                if command.contains("docker-proxy") || command.contains("containerd-shim") {
                    for container in containers {
                        if command.contains(container.id.prefix(12)) {
                            isContainer = true
                            containerId = container.id
                            break
                        }
                    }
                }

                var smartName = name
                var version: String?

                if let appPath = findAppBundlePath(in: command) {
                    let appURL = URL(fileURLWithPath: appPath)
                    let appName = appURL.deletingPathExtension().lastPathComponent
                    version = getAppVersion(at: appPath)
                    smartName = appName
                    if let version {
                        smartName += " \(version)"
                    }
                } else if devKeywords.contains(where: { name.lowercased().contains($0) }) {
                    if let project = findProjectName(in: command) {
                        smartName = project
                    } else if let script = findScriptName(in: command, process: name) {
                        smartName = script
                    }
                }

                if smartName == name,
                   name.range(of: #"^\d+[\.\d]*$"#, options: .regularExpression) != nil {
                    let parts = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if let execPath = parts.first {
                        let execName = URL(fileURLWithPath: execPath).lastPathComponent
                        if !execName.isEmpty && execName != name {
                            smartName = "\(execName) \(name)"
                        }
                    }
                }

                let lowerName = name.lowercased()
                let isDevTool = !isSystem && hasTTY && devKeywords.contains { lowerName.contains($0) }

                results.append(
                    ServiceInfo(
                        processName: name,
                        pid: pid,
                        port: port,
                        command: command.isEmpty ? name : command,
                        isSystem: isSystem,
                        hasTTY: hasTTY,
                        version: version,
                        isDevTool: isDevTool,
                        smartName: smartName,
                        cpuPercent: cpuPercent,
                        memoryMB: memoryMB,
                        memoryPercent: 0,
                        isContainer: isContainer,
                        containerId: containerId
                    )
                )
            default:
                break
            }
        }

        return results
    }

    private func findAppBundlePath(in command: String) -> String? {
        if let range = command.range(of: ".app/") {
            let endIndex = range.upperBound
            let pathUpToApp = String(command[..<endIndex])

            if let rootRange = pathUpToApp.range(of: "/Applications/") ?? pathUpToApp.range(of: "/Users/") ?? pathUpToApp.range(of: "/System/") {
                return String(pathUpToApp[rootRange.lowerBound...].dropLast(1))
            }

            if pathUpToApp.hasPrefix("/") {
                return String(pathUpToApp.dropLast(1))
            }
        }

        return nil
    }

    private func findProjectName(in command: String) -> String? {
        let triggers = ["/workspace/", "/Sites/", "/Projects/", "/dev/"]
        for trigger in triggers {
            if let range = command.range(of: trigger) {
                let suffix = command[range.upperBound...]
                let components = suffix.split(separator: "/")
                if let project = components.first {
                    return String(project)
                }
            }
        }
        return nil
    }

    private func findScriptName(in command: String, process: String) -> String? {
        let parts = command.components(separatedBy: .whitespaces)
        for part in parts {
            if part.hasSuffix("/" + process) || part == process { continue }
            if part.hasPrefix("-") { continue }

            let lower = part.lowercased()
            if lower.hasSuffix(".js") || lower.hasSuffix(".mjs") || lower.hasSuffix(".ts") ||
               lower.hasSuffix(".py") || lower.hasSuffix(".go") || lower.hasSuffix(".rb") ||
               lower.hasSuffix(".php") || lower.hasSuffix(".java") || lower.hasSuffix(".jar") {
                if lower.contains("node_modules") { continue }
                return URL(fileURLWithPath: part).lastPathComponent
            }
        }
        return nil
    }

    private func getAppVersion(at path: String) -> String? {
        let infoPlistPath = path + "/Contents/Info.plist"
        guard FileManager.default.fileExists(atPath: infoPlistPath) else { return nil }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: infoPlistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        return plist["CFBundleShortVersionString"] as? String
    }

    private func extractPort(from name: String) -> UInt16? {
        guard let colonIndex = name.lastIndex(of: ":") else { return nil }
        let portString = String(name[name.index(after: colonIndex)...])
        return UInt16(portString)
    }

    private static func shell(_ path: String, arguments: [String], timeout: TimeInterval = 10) -> String {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return ""
        }

        let killTimer = DispatchWorkItem { [weak task] in
            guard let task = task, task.isRunning else { return }
            task.terminate()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killTimer)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        killTimer.cancel()

        return String(data: data, encoding: .utf8) ?? ""
    }
}

import Foundation

struct DockerScanResult {
    let isAvailable: Bool
    let containers: [DockerContainer]
}

final class DockerScanner {
    private let dockerPath: String

    init(dockerPath: String = "/usr/local/bin/docker") {
        self.dockerPath = dockerPath
    }

    func scan() -> DockerScanResult {
        let dockerInfo = Self.shell(dockerPath, arguments: ["info"])
        let isAvailable = !dockerInfo.isEmpty && !dockerInfo.contains("Cannot connect")

        guard isAvailable else {
            return DockerScanResult(isAvailable: false, containers: [])
        }

        let containerOutput = Self.shell(dockerPath, arguments: ["ps", "-a", "--format", "json"])

        guard !containerOutput.isEmpty else {
            return DockerScanResult(isAvailable: true, containers: [])
        }

        var containers: [DockerContainer] = []
        let lines = containerOutput.components(separatedBy: "\n").filter { !$0.isEmpty }

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let id = json["ID"] as? String ?? ""
            let names = json["Names"] as? String ?? ""
            let image = json["Image"] as? String ?? ""
            let status = json["Status"] as? String ?? ""
            let portsStr = json["Ports"] as? String ?? ""
            let createdAt = json["CreatedAt"] as? String ?? json["Created"] as? String ?? ""

            let ports = portsStr.isEmpty ? [] : portsStr.components(separatedBy: ", ")
            let created = parseCreatedDate(createdAt)
            let name = names.hasPrefix("/") ? String(names.dropFirst()) : names

            containers.append(
                DockerContainer(
                    id: id,
                    name: name,
                    image: image,
                    status: status,
                    ports: ports,
                    created: created
                )
            )
        }

        return DockerScanResult(isAvailable: true, containers: containers)
    }

    func startContainer(_ container: DockerContainer) -> Bool {
        Self.shellExitCode(dockerPath, arguments: ["start", container.id]) == 0
    }

    func stopContainer(_ container: DockerContainer) -> Bool {
        Self.shellExitCode(dockerPath, arguments: ["stop", container.id]) == 0
    }

    func restartContainer(_ container: DockerContainer) -> Bool {
        Self.shellExitCode(dockerPath, arguments: ["restart", container.id]) == 0
    }

    private func parseCreatedDate(_ dateStr: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                return formatter
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
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

    private static func shellExitCode(_ path: String, arguments: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return -1
        }
    }
}

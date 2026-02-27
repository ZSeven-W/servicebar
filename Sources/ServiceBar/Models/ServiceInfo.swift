import Foundation

struct ServiceInfo: Identifiable, Equatable {
    let id: String
    let processName: String
    let pid: Int32
    let port: UInt16
    let command: String
    let isSystem: Bool
    let hasTTY: Bool
    let smartName: String
    let isDevTool: Bool

    init(
        processName: String,
        pid: Int32,
        port: UInt16,
        command: String,
        isSystem: Bool = false,
        hasTTY: Bool = false,
        version: String? = nil,
        isDevTool: Bool = false,
        smartName: String? = nil
    ) {
        self.processName = processName
        self.pid = pid
        self.port = port
        self.command = command
        self.isSystem = isSystem
        self.hasTTY = hasTTY
        self.id = "\(pid)-\(port)"
        self.isDevTool = isDevTool
        
        if let smartName = smartName {
            self.smartName = smartName
        } else if let version = version {
            self.smartName = "\(processName) \(version)"
        } else {
            self.smartName = processName
        }
    }
}

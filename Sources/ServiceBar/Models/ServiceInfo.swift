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
    var cpuPercent: Double
    var memoryMB: Int
    var memoryPercent: Double
    var isContainer: Bool
    var containerId: String?

    init(
        processName: String,
        pid: Int32,
        port: UInt16,
        command: String,
        isSystem: Bool = false,
        hasTTY: Bool = false,
        version: String? = nil,
        isDevTool: Bool = false,
        smartName: String? = nil,
        cpuPercent: Double = 0,
        memoryMB: Int = 0,
        memoryPercent: Double = 0,
        isContainer: Bool = false,
        containerId: String? = nil
    ) {
        self.processName = processName
        self.pid = pid
        self.port = port
        self.command = command
        self.isSystem = isSystem
        self.hasTTY = hasTTY
        self.id = "\(pid)-\(port)"
        self.isDevTool = isDevTool
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.memoryPercent = memoryPercent
        self.isContainer = isContainer
        self.containerId = containerId
        
        if let smartName = smartName {
            self.smartName = smartName
        } else if let version = version {
            self.smartName = "\(processName) \(version)"
        } else {
            self.smartName = processName
        }
    }
}

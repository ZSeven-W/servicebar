import Foundation

struct DockerContainer: Identifiable, Equatable {
    let id: String
    let name: String
    let image: String
    let status: String
    let ports: [String]
    let created: Date?

    var isRunning: Bool {
        status.lowercased().contains("up")
    }

    var isPaused: Bool {
        status.lowercased().contains("paused")
    }

    var isExited: Bool {
        status.lowercased().contains("exited")
    }


    static func parseContainerStatus(_ status: String) -> String {
        let lower = status.lowercased()
        if lower.contains("up") { return "running" }
        if lower.contains("paused") { return "paused" }
        if lower.contains("exited") { return "exited" }
        if lower.contains("created") { return "created" }
        if lower.contains("restarting") { return "restarting" }
        if lower.contains("dead") { return "dead" }
        return status
    }
}

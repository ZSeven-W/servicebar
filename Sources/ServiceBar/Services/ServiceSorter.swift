import Foundation

enum ServiceSortOrder: String, CaseIterable {
    case port = "Port"
    case cpu = "CPU"
    case memory = "Memory"
}

enum ServiceSorter {
    static func sort(_ services: [ServiceInfo], by order: ServiceSortOrder) -> [ServiceInfo] {
        switch order {
        case .port:
            return services.sorted { $0.port < $1.port }
        case .cpu:
            return services.sorted { $0.cpuPercent > $1.cpuPercent }
        case .memory:
            return services.sorted { $0.memoryMB > $1.memoryMB }
        }
    }
}

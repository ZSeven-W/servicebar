import Foundation

class HiddenItemsManager: ObservableObject {
    static let shared = HiddenItemsManager()

    @Published var hiddenApps: Set<String> = []
    @Published var hiddenServices: Set<String> = [] // Format: "ProcessName:Port"

    private let appsKey = "HiddenApps"
    private let servicesKey = "HiddenServices"

    init() {
        if let apps = UserDefaults.standard.array(forKey: appsKey) as? [String] {
            hiddenApps = Set(apps)
        }
        if let services = UserDefaults.standard.array(forKey: servicesKey) as? [String] {
            hiddenServices = Set(services)
        }
    }

    func toggleApp(_ name: String) {
        if hiddenApps.contains(name) {
            hiddenApps.remove(name)
        } else {
            hiddenApps.insert(name)
        }
        save()
    }

    func toggleService(_ service: ServiceInfo) {
        let key = serviceKey(for: service)
        if hiddenServices.contains(key) {
            hiddenServices.remove(key)
        } else {
            hiddenServices.insert(key)
        }
        save()
    }

    func isAppHidden(_ name: String) -> Bool {
        hiddenApps.contains(name)
    }

    func isServiceHidden(_ service: ServiceInfo) -> Bool {
        hiddenServices.contains(serviceKey(for: service))
    }

    private func serviceKey(for service: ServiceInfo) -> String {
        "\(service.processName):\(service.port)"
    }

    func unhideServiceByKey(_ key: String) {
        hiddenServices.remove(key)
        save()
    }

    func resetAll() {
        hiddenApps.removeAll()
        hiddenServices.removeAll()
        save()
    }

    private func save() {
        UserDefaults.standard.set(Array(hiddenApps), forKey: appsKey)
        UserDefaults.standard.set(Array(hiddenServices), forKey: servicesKey)
    }
}

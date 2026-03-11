import Foundation

final class ServiceScanner: ObservableObject {
    @Published var services: [ServiceInfo] = []
    @Published var containers: [DockerContainer] = []
    @Published var isDockerAvailable: Bool = false
    @Published var isScanning = false
    @Published var sortOrder: ServiceSortOrder = .port

    private var lastScanTime: Date?
    private var autoRefreshTimer: Timer?
    private let processScanner: ProcessScanner
    private let dockerScanner: DockerScanner

    init(
        processScanner: ProcessScanner = ProcessScanner(),
        dockerScanner: DockerScanner = DockerScanner()
    ) {
        self.processScanner = processScanner
        self.dockerScanner = dockerScanner
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let dockerResult = self.dockerScanner.scan()
            let rawServices = self.processScanner.scan(containers: dockerResult.containers)
            let sortedServices = ServiceSorter.sort(rawServices, by: self.sortOrder)

            DispatchQueue.main.async {
                self.services = sortedServices
                self.containers = dockerResult.containers
                self.isDockerAvailable = dockerResult.isAvailable
                self.isScanning = false
                self.lastScanTime = Date()
            }
        }
    }

    func applySort() {
        services = ServiceSorter.sort(services, by: sortOrder)
    }

    /// Only scan if data is older than maxAge seconds (default 30s).
    func scanIfStale(maxAge: TimeInterval = 30) {
        if let lastScan = lastScanTime, Date().timeIntervalSince(lastScan) < maxAge {
            return
        }
        scan()
    }

    /// Start periodic auto-refresh (default every 300 seconds).
    func startAutoRefresh(interval: TimeInterval = 300) {
        stopAutoRefresh()
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    func stopService(pid: Int32, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = Self.shellExitCode("/bin/kill", arguments: ["\(pid)"]) == 0
            usleep(500_000)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    func restartService(_ service: ServiceInfo, completion: @escaping (Bool) -> Void) {
        let command = service.command
        let pid = service.pid

        DispatchQueue.global(qos: .userInitiated).async {
            _ = Self.shellExitCode("/bin/kill", arguments: ["\(pid)"])
            usleep(1_000_000)

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            let pathFix = "export PATH=$PATH:/opt/homebrew/bin:/usr/local/bin;"
            task.arguments = ["-lc", "\(pathFix) nohup \(command) &>/dev/null &"]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            let success: Bool
            do {
                try task.run()
                task.waitUntilExit()
                success = true
            } catch {
                success = false
            }

            usleep(1_000_000)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    func startService(command: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            let pathFix = "export PATH=$PATH:/opt/homebrew/bin:/usr/local/bin;"
            task.arguments = ["-lc", "\(pathFix) nohup \(command) &>/dev/null &"]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            let success: Bool
            do {
                try task.run()
                task.waitUntilExit()
                success = true
            } catch {
                success = false
            }

            usleep(1_000_000)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    // MARK: - Docker Container Actions

    func startContainer(_ container: DockerContainer, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.dockerScanner.startContainer(container)
            usleep(1_000_000)
            DispatchQueue.main.async {
                if success {
                    self.scan()
                }
                completion(success)
            }
        }
    }

    func stopContainer(_ container: DockerContainer, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.dockerScanner.stopContainer(container)
            usleep(1_000_000)
            DispatchQueue.main.async {
                if success {
                    self.scan()
                }
                completion(success)
            }
        }
    }

    func restartContainer(_ container: DockerContainer, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.dockerScanner.restartContainer(container)
            usleep(1_000_000)
            DispatchQueue.main.async {
                if success {
                    self.scan()
                }
                completion(success)
            }
        }
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

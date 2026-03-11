import Combine
import SwiftUI

@main
struct ServiceBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let scanner = ServiceScanner()
    private let mcpScanner = MCPScanner()
    private let mcpInstaller = MCPInstaller()
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[ServiceBar] applicationDidFinishLaunching started")
        setupApplicationStyle()
        setupPopover()
        setupStatusItem()
        setupObservers()

        NSLog("[ServiceBar] setup complete")
        setupInitialScan()
    }

    private func setupApplicationStyle() {
        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: StatusBarView(scanner: scanner, mcpScanner: mcpScanner, mcpInstaller: mcpInstaller)
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "⚙ 0"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        updateBadge()
    }

    private func setupObservers() {
        scanner.$services
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateBadge() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .iconStyleChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateBadge() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .refreshIntervalChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.restartAutoRefresh() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Notification.Name.openSettings)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.openSettings() }
            .store(in: &cancellables)
    }

    private func setupInitialScan() {
        scanner.scan()
        restartAutoRefresh()
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
            scanner.scan()

            // Monitor clicks outside the popover to dismiss it
            eventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func updateBadge() {
        guard let button = statusItem.button else { return }
        let showCount = UserDefaults.standard.object(forKey: "ShowCountBadge") as? Bool ?? true
        if showCount {
            let count = scanner.services.count
            button.title = "⚙ \(count)"
        } else {
            button.title = "⚙"
        }
    }

    private func openSettings() {
        // Close the popover first
        popover.performClose(nil)

        // Reuse existing window if it's still around
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create a new settings window manually
        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ServiceBar Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 450, height: 350))
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restartAutoRefresh() {
        let interval = UserDefaults.standard.double(forKey: "AutoRefreshInterval")
        scanner.startAutoRefresh(interval: interval > 0 ? interval : 300)
    }
}

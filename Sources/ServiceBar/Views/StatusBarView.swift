import SwiftUI

// MARK: - Data model for grouped display
private struct AppGroup: Identifiable {
    let id: String  // = name
    let name: String
    let services: [ServiceInfo]
    let isDev: Bool
}

private struct GroupedData {
    let visible: [AppGroup]
    let hidden: [ServiceInfo]
    let system: [ServiceInfo]
}

struct StatusBarView: View {
    @ObservedObject var scanner: ServiceScanner
    @ObservedObject var mcpScanner: MCPScanner
    @ObservedObject var mcpInstaller: MCPInstaller
    @ObservedObject private var hiddenManager = HiddenItemsManager.shared
    @AppStorage("PortFilterMin") private var portMin: Int = 0
    @AppStorage("PortFilterMax") private var portMax: Int = 0
    @State private var confirmAction: ConfirmAction?
    @State private var searchText: String = ""
    @State private var showHiddenUserItems = false
    @State private var showSystemServices = false
    @State private var showDockerContainers = true
    @State private var showMCPServers = false
    @State private var collapsedApps: Set<String> = []
    @State private var allExpanded = true
    @State private var groupOrder: [String] = []
    @State private var draggingGroup: String?
    @State private var collapsedBeforeDrag: Set<String>?
    @State private var stoppedServices: [String: ServiceInfo] = [:]
    @State private var startingServiceIds: Set<String> = []
    @State private var stoppingServiceIds: Set<String> = []
    @ObservedObject private var aliasManager = GroupAliasManager.shared
    @State private var selectedTagFilters: Set<GroupTag> = []
    @State private var showStartError = false

    var body: some View {
        VStack(spacing: 0) {
            if showMCPServers {
                MCPManagerView(scanner: mcpScanner, installer: mcpInstaller)
            } else {
                mainContent
            }
        }
        .frame(width: 400)
        .frame(maxHeight: 600)
        .onAppear {
            syncGroupOrder()
            scanner.scanIfStale()
        }
        .onChange(of: scanner.services) { _ in
            // Clean up stopped services whose port is now active again
            let livePorts = Set(scanner.services.map(\.port))
            stoppedServices = stoppedServices.filter { !livePorts.contains($0.value.port) }
            syncGroupOrder()
        }
        .alert(
            confirmAction?.title ?? "",
            isPresented: Binding(
                get: { confirmAction != nil },
                set: { if !$0 { confirmAction = nil } }
            ),
            presenting: confirmAction
        ) { action in
            Button("Cancel", role: .cancel) {}
            Button(action.buttonLabel, role: .destructive) {
                action.perform()
            }
        } message: { action in
            Text(action.message)
        }
        .alert("Unable to Start", isPresented: $showStartError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The service could not be started. The original command may no longer be valid.")
        }
    }
    
    // MARK: - Main Content (Services Tab)
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            if scanner.services.isEmpty && !scanner.isScanning && scanner.containers.isEmpty {
                emptyState
            } else {
                serviceList
            }

            Divider()

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Data

    /// Rebuild visible groups, hidden, system from current scanner data.
    /// Uses `groupOrder` for sorting but does NOT mutate it (that happens in syncGroupOrder).
    private func getGroupedData() -> GroupedData {
        var visibleGroups: [String: [ServiceInfo]] = [:]
        var groupIsDev: [String: Bool] = [:]
        var hiddenItems: [ServiceInfo] = []
        var systemItems: [ServiceInfo] = []

        let filterMin = portMin > 0 ? UInt16(clamping: portMin) : nil
        let filterMax = portMax > 0 ? UInt16(clamping: portMax) : nil
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()

        for service in scanner.services {
            // Apply port range filter (from Settings)
            if let min = filterMin, service.port < min { continue }
            if let max = filterMax, service.port > max { continue }

            // Apply search filter
            if !query.isEmpty {
                let portStr = String(service.port)
                let nameMatch = service.smartName.lowercased().contains(query)
                    || service.processName.lowercased().contains(query)
                let portMatch = portStr.contains(query)
                if !nameMatch && !portMatch { continue }
            }

            if service.isSystem {
                systemItems.append(service)
                continue
            }
            let key = service.smartName
            if hiddenManager.isAppHidden(key) || hiddenManager.isServiceHidden(service) {
                hiddenItems.append(service)
            } else {
                visibleGroups[key, default: []].append(service)
                if service.isDevTool { groupIsDev[key] = true }
            }
        }

        // Merge stopped services into their groups
        for (_, service) in stoppedServices {
            if let min = filterMin, service.port < min { continue }
            if let max = filterMax, service.port > max { continue }
            if !query.isEmpty {
                let portStr = String(service.port)
                let nameMatch = service.smartName.lowercased().contains(query)
                    || service.processName.lowercased().contains(query)
                let portMatch = portStr.contains(query)
                if !nameMatch && !portMatch { continue }
            }
            if service.isSystem { continue }
            let key = service.smartName
            if hiddenManager.isAppHidden(key) || hiddenManager.isServiceHidden(service) { continue }
            visibleGroups[key, default: []].append(service)
            if service.isDevTool { groupIsDev[key] = true }
        }

        // Build ordered list: known order first, then any new names sorted at end
        let currentNames = Set(visibleGroups.keys)
        let knownOrdered = groupOrder.filter { currentNames.contains($0) }
        let knownSet = Set(knownOrdered)
        let newNames = currentNames.subtracting(knownSet).sorted { a, b in
            let devA = groupIsDev[a] ?? false
            let devB = groupIsDev[b] ?? false
            if devA != devB { return devA }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
        let finalOrder = knownOrdered + newNames

        var visible = finalOrder.compactMap { name -> AppGroup? in
            guard let services = visibleGroups[name] else { return nil }
            return AppGroup(id: name, name: name, services: services, isDev: groupIsDev[name] ?? false)
        }

        // Apply tag filter
        if !selectedTagFilters.isEmpty {
            visible = visible.filter { group in
                let tag = aliasManager.tag(for: group.name, autoIsDev: group.isDev)
                return selectedTagFilters.contains(tag)
            }
        }

        return GroupedData(visible: visible, hidden: hiddenItems, system: systemItems)
    }

    /// Same as getGroupedData but without tag filtering (used to discover available tags).
    private func getGroupedDataUnfiltered() -> GroupedData {
        // Replicate grouping logic without the tag filter step
        var visibleGroups: [String: [ServiceInfo]] = [:]
        var groupIsDev: [String: Bool] = [:]

        let filterMin = portMin > 0 ? UInt16(clamping: portMin) : nil
        let filterMax = portMax > 0 ? UInt16(clamping: portMax) : nil
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()

        for service in scanner.services {
            if let min = filterMin, service.port < min { continue }
            if let max = filterMax, service.port > max { continue }
            if !query.isEmpty {
                let portStr = String(service.port)
                let nameMatch = service.smartName.lowercased().contains(query)
                    || service.processName.lowercased().contains(query)
                let portMatch = portStr.contains(query)
                if !nameMatch && !portMatch { continue }
            }
            if service.isSystem { continue }
            let key = service.smartName
            if hiddenManager.isAppHidden(key) || hiddenManager.isServiceHidden(service) { continue }
            visibleGroups[key, default: []].append(service)
            if service.isDevTool { groupIsDev[key] = true }
        }

        let visible = visibleGroups.map { name, services in
            AppGroup(id: name, name: name, services: services, isDev: groupIsDev[name] ?? false)
        }
        return GroupedData(visible: visible, hidden: [], system: [])
    }

    /// Sync groupOrder state in response to data changes (called outside body computation).
    private func syncGroupOrder() {
        var visibleGroups: [String: [ServiceInfo]] = [:]
        var groupIsDev: [String: Bool] = [:]

        for service in scanner.services {
            if service.isSystem { continue }
            let key = service.smartName
            if !hiddenManager.isAppHidden(key) && !hiddenManager.isServiceHidden(service) {
                visibleGroups[key, default: []].append(service)
                if service.isDevTool { groupIsDev[key] = true }
            }
        }
        for (_, service) in stoppedServices {
            if service.isSystem { continue }
            let key = service.smartName
            if !hiddenManager.isAppHidden(key) && !hiddenManager.isServiceHidden(service) {
                visibleGroups[key, default: []].append(service)
                if service.isDevTool { groupIsDev[key] = true }
            }
        }

        let currentNames = Set(visibleGroups.keys)
        var newOrder = groupOrder.filter { currentNames.contains($0) }
        let knownSet = Set(newOrder)
        let added = currentNames.subtracting(knownSet).sorted { a, b in
            let devA = groupIsDev[a] ?? false
            let devB = groupIsDev[b] ?? false
            if devA != devB { return devA }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
        newOrder.append(contentsOf: added)
        groupOrder = newOrder
    }

    // MARK: - Views

    private var header: some View {
        HStack(spacing: 8) {
            let total = scanner.services.count
            let containerCount = scanner.containers.count
            HStack(spacing: 3) {
                Image(systemName: total == 0 && containerCount == 0 ? "bolt.slash.fill" : "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(total == 0 && containerCount == 0 ? Color.secondary : Color.green)
                Text("\(total)")
                    .font(.system(size: 16, weight: .bold).monospacedDigit())
                    .foregroundStyle(total == 0 && containerCount == 0 ? .secondary : .primary)
                if containerCount > 0 {
                    Text("|")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text("\(containerCount)")
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }

            // Search bar (always visible)
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search port or name…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))

            // Tag filter
            tagFilterButton

            // Expand / Collapse all
            Button {
                let data = getGroupedData()
                let allNames = Set(data.visible.map(\.name))
                if allExpanded {
                    collapsedApps = allNames
                    allExpanded = false
                } else {
                    collapsedApps.removeAll()
                    allExpanded = true
                }
            } label: {
                Image(systemName: allExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help(allExpanded ? "Collapse all" : "Expand all")

            Picker("Sort", selection: $scanner.sortOrder) {
                ForEach(ServiceSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .onChange(of: scanner.sortOrder) { _ in
                scanner.applySort()
            }

            RefreshButton(isScanning: scanner.isScanning) {
                scanner.scan()
            }
        }
    }

    /// Selectable tags for filtering (only tags that are actually in use)
    private var activeTags: [GroupTag] {
        let data = getGroupedDataUnfiltered()
        var usedTags: Set<GroupTag> = []
        for group in data.visible {
            let tag = aliasManager.tag(for: group.name, autoIsDev: group.isDev)
            if tag != .none { usedTags.insert(tag) }
        }
        return GroupTag.allCases.filter { $0 != .auto && $0 != .none && usedTags.contains($0) }
    }

    @ViewBuilder
    private var tagFilterButton: some View {
        let tags = activeTags
        if !tags.isEmpty || !selectedTagFilters.isEmpty {
            Group {
                if selectedTagFilters.isEmpty {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 18)
                } else {
                    HStack(spacing: 3) {
                        ForEach(selectedTagFilters.sorted { $0.rawValue < $1.rawValue }, id: \.self) { tag in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(tag.color)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .frame(minHeight: 18)
                }
            }
            // Invisible menu overlay to capture clicks
            .overlay {
                Menu {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            if selectedTagFilters.contains(tag) {
                                selectedTagFilters.remove(tag)
                            } else {
                                selectedTagFilters.insert(tag)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedTagFilters.contains(tag) ? "checkmark.circle.fill" : "circle")
                                Text(tag.rawValue)
                            }
                        }
                    }
                    if !selectedTagFilters.isEmpty {
                        Divider()
                        Button("Clear All") {
                            selectedTagFilters.removeAll()
                        }
                    }
                } label: {
                    Color.clear
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            .fixedSize()
            .help("Filter by tag")
        }
    }

    private var serviceList: some View {
        let data = getGroupedData()

        return ScrollView {
            VStack(spacing: 0) {
                // Docker Containers section
                if !scanner.containers.isEmpty {
                    Button {
                        showDockerContainers.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.right")
                                .rotationEffect(.degrees(showDockerContainers ? 90 : 0))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)
                            Text("Containers")
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(scanner.containers.count)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.secondary.opacity(0.1)))
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.03))

                    if showDockerContainers {
                        VStack(spacing: 2) {
                            ForEach(scanner.containers) { container in
                                ContainerRowView(
                                    container: container,
                                    onStart: { startContainer(container) },
                                    onStop: { stopContainer(container) },
                                    onRestart: { restartContainer(container) }
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }

                // Visible groups — drag to reorder
                ForEach(data.visible) { group in
                    AppGroupView(
                        appName: group.name,
                        services: group.services,
                        isDev: group.isDev,
                        isExpanded: !collapsedApps.contains(group.name),
                        isDragging: draggingGroup == group.name,
                        stoppedServiceIds: Set(stoppedServices.keys),
                        startingServiceIds: startingServiceIds,
                        stoppingServiceIds: stoppingServiceIds,
                        onToggleExpand: {
                            if collapsedApps.contains(group.name) {
                                collapsedApps.remove(group.name)
                            } else {
                                collapsedApps.insert(group.name)
                            }
                            // Sync allExpanded state
                            let allNames = Set(data.visible.map(\.name))
                            allExpanded = collapsedApps.isDisjoint(with: allNames)
                        },
                        onHideApp: {
                            hiddenManager.toggleApp(group.name)
                        },
                        onHideService: { service in
                            hiddenManager.toggleService(service)
                        },
                        onStop: { s in stopService(s) },
                        onRestart: { s in promptRestart(s) },
                        onStart: { s in startStoppedService(s) },
                        onRemove: { s in removeStoppedService(s) }
                    )
                    .onDrag {
                        // Save current collapsed state & collapse all
                        if collapsedBeforeDrag == nil {
                            collapsedBeforeDrag = collapsedApps
                            let allNames = Set(data.visible.map(\.name))
                            collapsedApps = allNames
                        }
                        draggingGroup = group.name
                        return NSItemProvider(object: group.name as NSString)
                    } preview: {
                        GroupDragPreview(
                            appName: group.name,
                            count: group.services.count,
                            isDev: group.isDev
                        )
                    }
                    .onDrop(of: [.text], delegate: GroupDropDelegate(
                        targetName: group.name,
                        groupOrder: $groupOrder,
                        draggingGroup: $draggingGroup,
                        collapsedApps: $collapsedApps,
                        collapsedBeforeDrag: $collapsedBeforeDrag
                    ))
                }

                // Hidden User Services
                if !data.hidden.isEmpty {
                    Divider().padding(.vertical, 8)
                    collapsibleSection(
                        title: "Hidden User Services",
                        count: data.hidden.count,
                        isExpanded: $showHiddenUserItems
                    ) {
                        ForEach(data.hidden) { service in
                            ServiceRowView(
                                service: service,
                                isStarting: startingServiceIds.contains(service.id),
                                isStopping: stoppingServiceIds.contains(service.id),
                                onStop: { stopService(service) },
                                onRestart: { promptRestart(service) },
                                onHide: {
                                    if hiddenManager.isAppHidden(service.smartName) {
                                        hiddenManager.toggleApp(service.smartName)
                                    } else {
                                        hiddenManager.toggleService(service)
                                    }
                                },
                                isHidden: true
                            )
                            .padding(.vertical, 2)
                        }
                    }
                }

                // System Services
                if !data.system.isEmpty {
                    Divider().padding(.vertical, 8)
                    collapsibleSection(
                        title: "System Services",
                        count: data.system.count,
                        isExpanded: $showSystemServices
                    ) {
                        ForEach(data.system) { service in
                            ServiceRowView(
                                service: service,
                                isStarting: startingServiceIds.contains(service.id),
                                isStopping: stoppingServiceIds.contains(service.id),
                                onStop: { stopService(service) },
                                onRestart: { promptRestart(service) },
                                onHide: nil
                            )
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func collapsibleSection<Content: View>(
        title: String,
        count: Int,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("\(title) (\(count))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
            }
        }
        .padding(.horizontal, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "network.slash")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No running services detected")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var footer: some View {
        HStack {
            // MCP Servers toggle
            Button {
                showMCPServers.toggle()
                if showMCPServers {
                    mcpScanner.scan()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showMCPServers ? "puzzlepiece.extension.fill" : "puzzlepiece.extension")
                        .font(.system(size: 11))
                    Text(showMCPServers ? "Services" : "MCP")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(showMCPServers ? .purple : .secondary)
            .help("Toggle MCP Servers")

            Button {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Settings")

            Spacer()

            if !showMCPServers {
                Button("Quit ServiceBar") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            }
        }
    }

    // MARK: - Actions

    private func stopService(_ service: ServiceInfo) {
        if stoppingServiceIds.contains(service.id) { return }
        stoppingServiceIds.insert(service.id)
        scanner.stopService(pid: service.pid) { success in
            DispatchQueue.main.async {
                self.stoppingServiceIds.remove(service.id)
                if success {
                    self.stoppedServices[service.id] = service
                }
            }
        }
    }

    private func startStoppedService(_ service: ServiceInfo) {
        if startingServiceIds.contains(service.id) { return }
        startingServiceIds.insert(service.id)
        scanner.startService(command: service.command) { success in
            DispatchQueue.main.async {
                self.startingServiceIds.remove(service.id)
                if success {
                    self.stoppedServices.removeValue(forKey: service.id)
                    self.scanner.scan()
                } else {
                    self.showStartError = true
                }
            }
        }
    }

    private func removeStoppedService(_ service: ServiceInfo) {
        stoppedServices.removeValue(forKey: service.id)
    }

    private func promptRestart(_ service: ServiceInfo) {
        confirmAction = ConfirmAction(
            title: "Restart Service",
            message: "Restart \(service.processName)?",
            buttonLabel: "Restart",
            perform: {
                scanner.restartService(service) { _ in scanner.scan() }
            }
        )
    }

    // MARK: - Docker Container Actions

    private func startContainer(_ container: DockerContainer) {
        scanner.startContainer(container) { _ in }
    }

    private func stopContainer(_ container: DockerContainer) {
        scanner.stopContainer(container) { _ in }
    }

    private func restartContainer(_ container: DockerContainer) {
        scanner.restartContainer(container) { _ in }
    }
}

// MARK: - Drop Delegate for group reordering

private struct GroupDropDelegate: DropDelegate {
    let targetName: String
    @Binding var groupOrder: [String]
    @Binding var draggingGroup: String?
    @Binding var collapsedApps: Set<String>
    @Binding var collapsedBeforeDrag: Set<String>?

    func dropEntered(info: DropInfo) {
        guard let source = draggingGroup, source != targetName else { return }
        guard let fromIndex = groupOrder.firstIndex(of: source),
              let toIndex = groupOrder.firstIndex(of: targetName) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            groupOrder.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingGroup = nil
        // Restore collapsed state from before drag
        if let saved = collapsedBeforeDrag {
            collapsedApps = saved
            collapsedBeforeDrag = nil
        }
        return true
    }
}

// MARK: - AppGroupView

struct AppGroupView: View {
    let appName: String
    let services: [ServiceInfo]
    let isDev: Bool
    let isExpanded: Bool
    let isDragging: Bool
    var stoppedServiceIds: Set<String> = []
    var startingServiceIds: Set<String> = []
    var stoppingServiceIds: Set<String> = []
    let onToggleExpand: () -> Void
    let onHideApp: () -> Void
    let onHideService: (ServiceInfo) -> Void
    let onStop: (ServiceInfo) -> Void
    let onRestart: (ServiceInfo) -> Void
    var onStart: ((ServiceInfo) -> Void)? = nil
    var onRemove: ((ServiceInfo) -> Void)? = nil

    @ObservedObject private var aliasManager = GroupAliasManager.shared
    @State private var isEditing = false
    @State private var editText = ""

    private var displayName: String {
        aliasManager.displayName(for: appName)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            HStack {
                if isEditing {
                    // Inline edit field
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)

                        TextField("Group name", text: $editText, onCommit: {
                            aliasManager.setAlias(editText, for: appName)
                            isEditing = false
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: 200)

                        Button {
                            aliasManager.setAlias(editText, for: appName)
                            isEditing = false
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            isEditing = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button(action: onToggleExpand) {
                        HStack {
                            Image(systemName: "chevron.right")
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)

                            Text(displayName)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)

                    // Tag picker
                    groupTagView

                    Button(action: onToggleExpand) {
                        Text("\(services.count)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.secondary.opacity(0.1)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        editText = displayName
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.borderless)
                    .help("Rename group")
                }

                Spacer()

                Button(action: onHideApp) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Hide all services for \(appName)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.03))

            // Services list (force collapsed while dragging)
            if isExpanded && !isDragging {
                VStack(spacing: 2) {
                    ForEach(services) { service in
                        let isStopped = stoppedServiceIds.contains(service.id)
                        ServiceRowView(
                            service: service,
                            isStopped: isStopped,
                            isStarting: startingServiceIds.contains(service.id),
                            isStopping: stoppingServiceIds.contains(service.id),
                            onStop: { onStop(service) },
                            onRestart: { onRestart(service) },
                            onHide: isStopped ? nil : { onHideService(service) },
                            onStart: { onStart?(service) },
                            onRemove: { onRemove?(service) }
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(.bottom, 4)
        .opacity(isDragging ? 0.5 : 1.0)
    }

    @ViewBuilder
    private var groupTagView: some View {
        let currentTag = aliasManager.tag(for: appName, autoIsDev: isDev)
        if currentTag != .none {
            Text(currentTag.rawValue)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 3).fill(currentTag.color))
                .overlay { tagMenuOverlay }
        } else {
            Image(systemName: "tag")
                .font(.system(size: 9))
                .foregroundStyle(.secondary.opacity(0.4))
                .overlay { tagMenuOverlay }
        }
    }

    private var tagMenuOverlay: some View {
        Menu {
            ForEach(GroupTag.allCases, id: \.self) { tag in
                Button {
                    aliasManager.setTag(tag, for: appName)
                } label: {
                    let isSelected = tag == .auto
                        ? !aliasManager.hasCustomTag(for: appName)
                        : aliasManager.hasCustomTag(for: appName) && aliasManager.tag(for: appName, autoIsDev: isDev) == tag
                    HStack {
                        Text(tag.label)
                        if isSelected {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Color.clear
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - Drag Preview (collapsed header only)

private struct GroupDragPreview: View {
    let appName: String
    let count: Int
    let isDev: Bool

    var body: some View {
        HStack {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            Text(appName)
                .font(.system(size: 13, weight: .semibold))

            if isDev {
                Text("DEV")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.orange))
            }

            Text("\(count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(width: 380)
        .background(Color.primary.opacity(0.03))
        .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ConfirmAction: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let buttonLabel: String
    let perform: () -> Void
}

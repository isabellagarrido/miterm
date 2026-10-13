import AppKit
import Combine

struct WorkspaceSessionSnapshot: Identifiable {
    let id: ObjectIdentifier
    let windowReference: Weak<NSWindow>
    let groupID: ObjectIdentifier?
    let title: String
    let isSelected: Bool
    let isKeyWindow: Bool
    let hasActiveBell: Bool

    var window: NSWindow? { windowReference.value }

    init(window: NSWindow, controller: TerminalController?) {
        id = ObjectIdentifier(window)
        windowReference = Weak(window)
        groupID = window.tabGroup.map(ObjectIdentifier.init)
        title = window.title.isEmpty ? "Terminal" : window.title
        isSelected = window.tabGroup?.selectedWindow === window || window.isKeyWindow
        isKeyWindow = window.isKeyWindow
        hasActiveBell = controller?.bell ?? false
    }

    var activityDescription: String {
        hasActiveBell ? "Bell active" : "No activity signal"
    }
}

@MainActor
final class WorkspaceSessionStore: ObservableObject {
    static let shared = WorkspaceSessionStore()

    @Published private(set) var sessions: [WorkspaceSessionSnapshot] = []

    private var notificationObservers: [NSObjectProtocol] = []
    private var tabGroupObservations: [ObjectIdentifier: [NSKeyValueObservation]] = [:]
    private var controllerObservations: [ObjectIdentifier: AnyCancellable] = [:]

    private init() {
        let center = NotificationCenter.default
        for name in [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.willCloseNotification,
            TerminalWindow.terminalDidAwake,
        ] {
            notificationObservers.append(center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            })
        }

        refresh()
    }

    deinit {
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
    }

    func refresh() {
        let controllers = TerminalController.all
        let windows = controllers.compactMap(\.window)
        observeTabGroups(windows.compactMap(\.tabGroup))
        observeControllers(controllers)

        sessions = controllers.compactMap { controller in
            guard let window = controller.window else { return nil }
            return WorkspaceSessionSnapshot(window: window, controller: controller)
        }

        WorkspaceCustomizationStore.shared.applyTabBarVisibility()
    }

    func tabItems(in window: NSWindow) -> [WorkspaceTabItem] {
        let windows = window.tabGroup?.windows ?? [window]
        return windows.map { target in
            let snapshot = sessions.first { $0.id == ObjectIdentifier(target) }
                ?? WorkspaceSessionSnapshot(
                    window: target,
                    controller: target.windowController as? TerminalController
                )
            return WorkspaceTabItem(
                id: String(describing: snapshot.id),
                title: snapshot.title,
                isSelected: snapshot.isSelected
            ) { [weak self] in
                self?.selectSession(snapshot.id)
            }
        }
    }

    func selectSession(_ id: ObjectIdentifier) {
        guard let targetWindow = sessions.first(where: { $0.id == id })?.window else { return }
        if let group = targetWindow.tabGroup,
           group.windows.contains(where: { $0 === targetWindow }) {
            group.selectedWindow = targetWindow
        }
        targetWindow.makeKeyAndOrderFront(nil)
        refresh()
    }

    private func observeTabGroups(_ groups: [NSWindowTabGroup]) {
        var activeGroupIDs = Set<ObjectIdentifier>()
        for group in groups {
            let id = ObjectIdentifier(group)
            activeGroupIDs.insert(id)
            guard tabGroupObservations[id] == nil else { continue }

            let windowsObservation = group.observe(\.windows, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            let selectedObservation = group.observe(\.selectedWindow, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            tabGroupObservations[id] = [windowsObservation, selectedObservation]
        }

        tabGroupObservations = tabGroupObservations.filter { activeGroupIDs.contains($0.key) }
    }

    private func observeControllers(_ controllers: [TerminalController]) {
        let activeIDs = Set(controllers.compactMap { $0.window.map(ObjectIdentifier.init) })
        controllerObservations = controllerObservations.filter { activeIDs.contains($0.key) }

        for controller in controllers {
            guard let window = controller.window else { continue }
            let id = ObjectIdentifier(window)
            guard controllerObservations[id] == nil else { continue }
            controllerObservations[id] = controller.$bell
                .dropFirst()
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in self?.refresh() }
                }
        }
    }
}

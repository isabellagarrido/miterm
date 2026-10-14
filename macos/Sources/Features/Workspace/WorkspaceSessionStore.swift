import AppKit
import Combine
import SwiftUI

struct WorkspaceSessionSnapshot: Identifiable {
    let id: ObjectIdentifier
    /// The first Ghostty surface UUID survives Ghostty's window-state restoration,
    /// so icon preferences can distinguish tabs (even when their titles match).
    let iconStorageKey: String
    let windowReference: Weak<NSWindow>
    let groupID: ObjectIdentifier?
    let title: String
    let isSelected: Bool
    let isKeyWindow: Bool
    let hasActiveBell: Bool
    let runningStackID: UUID?
    let stackName: String?

    var window: NSWindow? { windowReference.value }

    init(window: NSWindow, controller: TerminalController?, stack: RunningStack? = nil) {
        id = ObjectIdentifier(window)
        iconStorageKey = controller?.surfaceTree.first.map { "session:\($0.id.uuidString)" }
            ?? "title:\(window.title)"
        windowReference = Weak(window)
        groupID = window.tabGroup.map(ObjectIdentifier.init)
        title = window.title.isEmpty ? "Terminal" : window.title
        isSelected = window.tabGroup?.selectedWindow === window || window.isKeyWindow
        isKeyWindow = window.isKeyWindow
        hasActiveBell = controller?.bell ?? false
        runningStackID = stack?.id
        stackName = stack?.definition.name
    }

    var activityDescription: String {
        hasActiveBell ? "Bell active" : "No activity signal"
    }
}

@MainActor
final class WorkspaceSessionIconStore: ObservableObject {
    static let shared = WorkspaceSessionIconStore()
    private static let defaultsKey = "WorkspaceSessionIconsByTitle"

    @Published private var icons: [String: String] {
        didSet { UserDefaults.ghostty.set(icons, forKey: Self.defaultsKey) }
    }

    private init() {
        icons = UserDefaults.ghostty.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
    }

    func icon(for session: WorkspaceSessionSnapshot) -> WorkspaceSessionIcon {
        WorkspaceSessionIcon(
            storedValue: icons[session.iconStorageKey] ?? icons["title:\(session.title)"]
                ?? icons[session.title] ?? "terminal"
        )
    }

    func setIcon(_ symbol: String, for session: WorkspaceSessionSnapshot) {
        icons[session.iconStorageKey] = symbol
    }

    func setEmoji(_ emoji: String, for session: WorkspaceSessionSnapshot) {
        let value = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count == 1, value.unicodeScalars.contains(where: { $0.properties.isEmoji }) else {
            return
        }
        icons[session.iconStorageKey] = "emoji:\(value)"
    }
}

enum WorkspaceSessionIcon: Equatable {
    case systemSymbol(String)
    case emoji(String)

    init(storedValue: String) {
        if storedValue.hasPrefix("emoji:") {
            self = .emoji(String(storedValue.dropFirst("emoji:".count)))
        } else {
            // Existing saved SF Symbol names remain valid without a migration.
            self = .systemSymbol(storedValue)
        }
    }
}

struct WorkspaceSessionIconView: View {
    let icon: WorkspaceSessionIcon
    var size: CGFloat = 14

    var body: some View {
        Group {
            switch icon {
            case .systemSymbol(let symbol):
                Image(systemName: symbol)
            case .emoji(let value):
                Text(value)
                    .font(.system(size: size))
            }
        }
        .frame(width: size + 4, height: size + 4)
        .accessibilityHidden(true)
    }
}

/// A small editor backed by macOS's native character palette. The palette inserts
/// directly into the focused field, so no bundled emoji catalog is required.
struct WorkspaceSessionEmojiPickerContent: View {
    @ObservedObject private var iconStore = WorkspaceSessionIconStore.shared
    @FocusState private var emojiFieldIsFocused: Bool
    @State private var emojiDraft = ""

    let session: WorkspaceSessionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session emoji")
                .font(.headline)
            TextField("Type an emoji or pick one", text: $emojiDraft)
                .textFieldStyle(.roundedBorder)
                .focused($emojiFieldIsFocused)
                .onChange(of: emojiDraft) { value in
                    guard value.count == 1,
                        value.unicodeScalars.contains(where: { $0.properties.isEmoji })
                    else { return }
                    iconStore.setEmoji(value, for: session)
                    emojiDraft = ""
                }
            Button {
                emojiFieldIsFocused = true
                DispatchQueue.main.async {
                    NSApp.orderFrontCharacterPalette(self)
                }
            } label: {
                Label("Open macOS Emoji & Symbols", systemImage: "face.smiling")
            }
            .buttonStyle(.bordered)
            Text("The selected emoji is saved for this terminal tab.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 280)
        .onAppear {
            DispatchQueue.main.async { emojiFieldIsFocused = true }
        }
    }
}

@MainActor
final class WorkspaceSessionStore: ObservableObject {
    static let shared = WorkspaceSessionStore()

    @Published private(set) var sessions: [WorkspaceSessionSnapshot] = []
    @Published private(set) var runningStacks: [RunningStack] = []

    private let closedWindows = NSHashTable<NSWindow>.weakObjects()
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
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    if let window = notification.object as? NSWindow {
                        if name == NSWindow.willCloseNotification {
                            self?.closedWindows.add(window)
                        } else if name == NSWindow.didBecomeKeyNotification {
                            self?.closedWindows.remove(window)
                        }
                    }
                }
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

    func registerStack(_ instance: RunningStack) {
        runningStacks.append(instance)
        refresh()
    }

    func closeSession(_ id: ObjectIdentifier) {
        guard let controller = sessions.first(where: { $0.id == id })?.window?.windowController as? TerminalController else { return }
        controller.closeTab(nil)
    }

    private func stack(for controller: TerminalController?) -> RunningStack? {
        guard let controller else { return nil }
        let ids = Set(controller.surfaceTree.map(\.id))
        return runningStacks.first { !$0.surfaceIDs.isDisjoint(with: ids) }
    }

    func refresh() {
        let controllers = TerminalController.all.filter { controller in
            guard let window = controller.window else { return false }
            return !closedWindows.contains(window)
        }
        let liveSurfaceIDs = Set(controllers.flatMap { $0.surfaceTree.map(\.id) })
        runningStacks = runningStacks.compactMap { instance in
            var instance = instance
            instance.surfaceIDs.formIntersection(liveSurfaceIDs)
            return instance.surfaceIDs.isEmpty ? nil : instance
        }
        let windows = controllers.compactMap(\.window)
        observeTabGroups(windows.compactMap(\.tabGroup))
        observeControllers(controllers)

        sessions = controllers.compactMap { controller in
            guard let window = controller.window else { return nil }
            return WorkspaceSessionSnapshot(window: window, controller: controller, stack: stack(for: controller))
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
                isSelected: snapshot.isSelected,
                session: snapshot
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
            // AppKit can recreate its titlebar tab bar after a tab change or restore.
            // Keep the native bar in sync with MiTerm's Native/MiTerm strip preference.
            let visibilityObservation = group.observe(\.isTabBarVisible, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard self != nil else { return }
                    WorkspaceCustomizationStore.shared.applyTabBarVisibility()
                }
            }
            tabGroupObservations[id] = [
                windowsObservation,
                selectedObservation,
                visibilityObservation,
            ]
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

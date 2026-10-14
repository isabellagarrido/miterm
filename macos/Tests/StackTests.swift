import AppKit
import Darwin
import GhosttyKit
import Testing
@testable import Ghostty

@Suite
struct StackModelTests {
    @Test func roundTripsVersionedDefinitions() throws {
        let stack = SavedStack(name: "Project", icon: "📚", accent: WorkspaceColor(hex: 0x336699), tabs: [
            StackTabDefinition(name: "Claude", directory: "/tmp", startupCommand: "claude"),
            StackTabDefinition(name: "Shell", directory: "/tmp"),
        ])
        let library = StackLibrary(stacks: [stack])
        #expect(try StackLibrary.decode(JSONEncoder().encode(library)) == library)
    }

    @Test func duplicatesWithIndependentIDs() {
        let original = SavedStack(name: "Project", tabs: [StackTabDefinition(name: "One"), StackTabDefinition(name: "Two")])
        var copy = original.duplicated()
        #expect(copy.id != original.id)
        #expect(Set(copy.tabs.map(\.id)).isDisjoint(with: Set(original.tabs.map(\.id))))
        copy.tabs[0].directory = "/somewhere/else"
        #expect(original.tabs[0].directory != copy.tabs[0].directory)
    }

    @Test func reordersWithoutLosingConfiguration() {
        var stack = SavedStack(name: "Project", tabs: [
            StackTabDefinition(name: "One", directory: "/tmp", startupCommand: "echo one"),
            StackTabDefinition(name: "Two", directory: "/tmp"),
            StackTabDefinition(name: "Three", directory: "/tmp"),
        ])
        let first = stack.tabs[0]
        stack.moveTab(first.id, before: stack.tabs[2].id)
        #expect(stack.tabs.map(\.name) == ["Two", "One", "Three"])
        #expect(stack.tabs[1] == first)
        stack.moveTab(stack.tabs[2].id, before: stack.tabs[0].id)
        #expect(stack.tabs.map(\.name) == ["Three", "Two", "One"])
    }

    @Test func rejectsUnsafeAndInvalidDefinitions() throws {
        let valid = SavedStack(name: "Project", tabs: [StackTabDefinition(name: "Shell", directory: "/tmp")])
        var invalid = valid
        invalid.tabs[0].directory = "relative/path"
        #expect(throws: StackError.self) { try invalid.validate() }
        invalid = valid
        invalid.tabs[0].startupCommand = "echo ok\u{0}unexpected"
        #expect(throws: StackError.self) { try invalid.validate() }
        invalid = valid
        invalid.tabs.append(invalid.tabs[0])
        #expect(throws: StackError.self) { try invalid.validate() }
        invalid = valid
        invalid.tabs = []
        #expect(throws: StackError.self) { try invalid.validate() }
        invalid = valid
        invalid.name = " "
        #expect(throws: StackError.self) { try invalid.validate() }
        invalid = valid
        invalid.icon = "two words"
        #expect(throws: StackError.self) { try invalid.validate() }
    }

    @Test func resolvesHomeAndLiteralPathsWithoutShellExpansion() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let stack = SavedStack(name: "Project", tabs: [
            StackTabDefinition(name: "Home", directory: "~"),
            StackTabDefinition(name: "Literal", directory: "/tmp/project $(touch unwanted)"),
        ])
        let plan = try StackLaunchPlan(stack, directoryIsAccessible: { _ in true })
        #expect(plan.tabs[0].directory == home)
        #expect(plan.tabs[1].surfaceConfiguration.workingDirectory == "/tmp/project $(touch unwanted)")
        #expect(plan.tabs[1].surfaceConfiguration.initialInput == nil)
    }

    @Test func commandsUseSurfaceConfigurationAndEmptyCommandsUseDefaultShell() throws {
        let stack = SavedStack(name: "Project", tabs: [
            StackTabDefinition(name: "Command", directory: "/tmp", startupCommand: "printf '%s' 'hello world'"),
            StackTabDefinition(name: "Shell", directory: "/tmp"),
            StackTabDefinition(name: "Blank", directory: "/tmp", startupCommand: "   "),
        ])
        let plan = try StackLaunchPlan(stack)
        #expect(plan.tabs[0].surfaceConfiguration.command == stack.tabs[0].startupCommand)
        #expect(plan.tabs[0].surfaceConfiguration.waitAfterCommand)
        #expect(plan.tabs.allSatisfy { $0.surfaceConfiguration.initialInput == nil })
        #expect(plan.tabs[1].surfaceConfiguration.command == nil)
        #expect(plan.tabs[2].surfaceConfiguration.command == nil)
        #expect(Ghostty.SurfaceConfiguration().command == nil)
    }

    @Test func rejectsInaccessibleDirectories() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: directory.path)
        if getuid() != 0 { #expect(!StackLaunchPlan.directoryIsAccessible(directory.path)) }
    }

    @Test func rejectsFilesAndMissingDirectories() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: root)
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(!StackLaunchPlan.directoryIsAccessible(root.path))
        #expect(!StackLaunchPlan.directoryIsAccessible(root.appendingPathComponent("missing").path))
        let stack = SavedStack(name: "Project", tabs: [StackTabDefinition(name: "File", directory: root.path)])
        #expect(throws: StackError.self) { try StackLaunchPlan(stack) }
    }
}

@Suite @MainActor
struct StackPersistenceTests {
    private func libraryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Stacks.json")
    }

    @Test func savesReloadsDuplicatesAndDeletes() throws {
        let url = libraryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = StackDefinitionStore(fileURL: url)
        #expect(store.loadError == nil)
        var stack = SavedStack(name: "Project", tabs: [StackTabDefinition(name: "Shell")])
        try store.save(stack)
        stack.name = "Updated"
        try store.save(stack)
        let copy = try store.duplicate(stack)
        #expect(store.stacks.count == 2)
        let reloaded = StackDefinitionStore(fileURL: url)
        #expect(reloaded.stacks == store.stacks)
        #expect(reloaded.stacks.first?.id == stack.id)
        try reloaded.delete(stack.id)
        #expect(reloaded.stacks.map(\.id) == [copy.id])
        #expect(StackDefinitionStore(fileURL: url).stacks == [copy])
    }

    @Test(arguments: ["not json", "{\"version\":99,\"stacks\":[]}", "{\"version\":0,\"stacks\":[]}"])
    func unreadableLibraryIsNeverOverwritten(contents: String) throws {
        let url = libraryURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data(contents.utf8)
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = StackDefinitionStore(fileURL: url)
        #expect(store.loadError != nil)
        #expect(throws: StackError.self) {
            try store.save(SavedStack(name: "Project", tabs: [StackTabDefinition(name: "Shell")]))
        }
        #expect(try Data(contentsOf: url) == data)
        try JSONEncoder().encode(StackLibrary()).write(to: url)
        store.reload()
        #expect(store.loadError == nil)
        #expect(store.stacks.isEmpty)
    }

    @Test func editingOrDeletingSavedStackDoesNotChangeRunningSnapshot() throws {
        let url = libraryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = StackDefinitionStore(fileURL: url)
        var saved = SavedStack(name: "Project", tabs: [StackTabDefinition(name: "Shell")])
        try store.save(saved)
        let running = RunningStack(definition: saved, surfaceIDs: [UUID()])
        saved.tabs[0].directory = "/tmp"
        try store.save(saved)
        try store.delete(saved.id)
        #expect(running.definition.tabs[0].directory != saved.tabs[0].directory)
        #expect(running.surfaceIDs.count == 1)
    }
}

@MainActor
private final class RecordingStackDriver: StackTerminalCreating {
    var configurations: [Ghostty.SurfaceConfiguration] = []
    var terminals: [StackTerminal] = []
    var titles: [String] = []
    var selected: UUID?
    var failAtTab: Int?

    var parent: StackTerminal?
    func currentTerminal() throws -> StackTerminal? { parent }
    func validate(tabCount: Int) throws {}

    func newWindow(configuration: Ghostty.SurfaceConfiguration) async throws -> StackTerminal {
        makeTerminal(configuration)
    }

    func newTab(configuration: Ghostty.SurfaceConfiguration, after: StackTerminal) throws -> StackTerminal {
        if configurations.count == failAtTab { throw StackError.terminalCreation("Test failure") }
        #expect(after.surfaceID == (terminals.last?.surfaceID ?? parent?.surfaceID))
        return makeTerminal(configuration)
    }

    private func makeTerminal(_ configuration: Ghostty.SurfaceConfiguration) -> StackTerminal {
        configurations.append(configuration)
        let terminal = StackTerminal(surfaceID: UUID(), window: nil)
        terminals.append(terminal)
        return terminal
    }

    func select(_ terminal: StackTerminal) { selected = terminal.surfaceID }
    func setTitle(_ title: String, for terminal: StackTerminal) { titles.append(title) }
}

@Suite @MainActor
struct StackLaunchTests {
    @Test func opensOrderedTabsInSameDirectoryAndCreatesIndependentInstances() async throws {
        let stack = SavedStack(name: "Project", tabs: [
            StackTabDefinition(name: "Claude A", directory: "/tmp", startupCommand: "claude"),
            StackTabDefinition(name: "Claude B", directory: "/tmp", startupCommand: "claude"),
            StackTabDefinition(name: "Shell", directory: "/tmp"),
        ])
        let driver = RecordingStackDriver()
        var instances: [RunningStack] = []
        let first = try await StackLauncher.open(stack, using: driver) { instances.append($0) }
        let second = try await StackLauncher.open(stack, using: driver) { instances.append($0) }
        #expect(first.id != second.id)
        #expect(first.surfaceIDs.isDisjoint(with: second.surfaceIDs))
        #expect(instances.count == 2)
        #expect(driver.titles == ["Claude A", "Claude B", "Shell", "Claude A", "Claude B", "Shell"])
        #expect(driver.configurations.allSatisfy { $0.workingDirectory == "/tmp" })
        #expect(driver.configurations[0].context == GHOSTTY_SURFACE_CONTEXT_WINDOW)
        #expect(driver.configurations[1].context == GHOSTTY_SURFACE_CONTEXT_TAB)
        #expect(driver.configurations[2].command == nil)
        #expect(driver.selected == driver.terminals[3].surfaceID)
    }

    @Test func currentWindowPreferenceAttachesTabsToExistingTerminal() async throws {
        let driver = RecordingStackDriver()
        driver.parent = StackTerminal(surfaceID: UUID(), window: nil)
        let stack = SavedStack(name: "Attached", tabs: [StackTabDefinition(name: "Tab", directory: "/tmp")], launchLocation: .currentWindow)
        try await StackLauncher.open(stack, using: driver) { _ in }
        #expect(driver.configurations.first?.context == GHOSTTY_SURFACE_CONTEXT_TAB)
        #expect(driver.parent?.surfaceID != driver.terminals.first?.surfaceID)
    }

    @Test func validatesAllDirectoriesBeforeCreatingTerminals() async throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        let stack = SavedStack(name: "Project", tabs: [
            StackTabDefinition(name: "Valid", directory: "/tmp", startupCommand: "echo test"),
            StackTabDefinition(name: "Missing", directory: missing),
        ])
        let driver = RecordingStackDriver()
        do {
            try await StackLauncher.open(stack, using: driver) { _ in Issue.record("Registered invalid Stack") }
            Issue.record("Launch should fail")
        } catch StackError.unavailableDirectory(let tab, let path) {
            #expect(tab == "Missing")
            #expect(path == missing)
        }
        #expect(driver.configurations.isEmpty)
    }

    @Test func partialFailureKeepsAndRegistersOpenedSessions() async throws {
        let stack = SavedStack(name: "Project", tabs: [
            StackTabDefinition(name: "One", directory: "/tmp"),
            StackTabDefinition(name: "Two", directory: "/tmp"),
        ])
        let driver = RecordingStackDriver()
        driver.failAtTab = 1
        var registered: RunningStack?
        do {
            try await StackLauncher.open(stack, using: driver) { registered = $0 }
            Issue.record("Launch should fail")
        } catch StackError.partialLaunch(let message) {
            #expect(message.contains("1 of 2"))
        }
        #expect(registered?.surfaceIDs == Set(driver.terminals.map(\.surfaceID)))
        #expect(driver.configurations.count == 1)
    }
}

/// Exercises the real Ghostty/AppKit adapter inside Xcode's isolated test host.
/// Commands only write to this test's temporary directory.
@Suite(.serialized) @MainActor
struct StackNativeIntegrationTests {
    @Test func launchesRealTabsAndKeepsOrdinaryTabsIndependent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let directory = root.appendingPathComponent("project with spaces", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("directories.txt")
        let config = try TemporaryConfig("""
        command = /bin/sh
        macos-titlebar-style = transparent
        window-new-tab-position = current
        window-fullscreen = false
        confirm-close-surface = false
        undo-timeout = 0
        """)
        let app = Ghostty.App(configPath: config.temporaryFile.path)
        #expect(app.readiness == .ready)
        defer {
            for controller in TerminalController.all where controller.ghostty === app {
                controller.window?.close()
            }
        }
        let command = "pwd >> \(Ghostty.Shell.quote(output.path))"
        let stack = SavedStack(name: "Integration", tabs: [
            StackTabDefinition(name: "First", directory: directory.path, startupCommand: command),
            StackTabDefinition(name: "Second", directory: directory.path, startupCommand: command),
            StackTabDefinition(name: "Default shell", directory: directory.path),
        ])
        let driver = GhosttyStackTerminalDriver(ghostty: app)
        var instances: [RunningStack] = []
        let first = try await StackLauncher.open(stack, using: driver) {
            instances.append($0)
            WorkspaceSessionStore.shared.registerStack($0)
        }
        let second = try await StackLauncher.open(stack, using: driver) {
            instances.append($0)
            WorkspaceSessionStore.shared.registerStack($0)
        }
        #expect(first.id != second.id)
        #expect(first.surfaceIDs.isDisjoint(with: second.surfaceIDs))
        let sessions = WorkspaceSessionStore.shared.sessions.filter { $0.runningStackID == first.id || $0.runningStackID == second.id }
        #expect(sessions.count == 6)
        #expect(sessions.allSatisfy { $0.stackName == stack.name })
        let controllers = TerminalController.all.filter { $0.ghostty === app }
        #expect(controllers.count == 6)
        let firstController = try #require(controllers.first { $0.surfaceTree.first.map { first.surfaceIDs.contains($0.id) } == true })
        let secondController = try #require(controllers.first { $0.surfaceTree.first.map { second.surfaceIDs.contains($0.id) } == true })
        let firstGroup = try #require(firstController.window?.tabGroup)
        let secondGroup = try #require(secondController.window?.tabGroup)
        #expect(firstGroup !== secondGroup)
        #expect(firstGroup.windows.map(\.title) == stack.tabs.map(\.name))
        #expect(secondGroup.windows.map(\.title) == stack.tabs.map(\.name))

        let firstItems = WorkspaceSessionStore.shared.tabItems(in: try #require(firstController.window))
        let secondItems = WorkspaceSessionStore.shared.tabItems(in: try #require(secondController.window))
        #expect(firstItems.map(\.title) == stack.tabs.map(\.name))
        #expect(Set(firstItems.map(\.id)).isDisjoint(with: Set(secondItems.map(\.id))))

        var lines: [String] = []
        for _ in 0..<100 {
            lines = (try? String(contentsOf: output, encoding: .utf8))?.split(separator: "\n").map(String.init) ?? []
            if lines.count == 4 { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(lines.count == 4)
        #expect(lines.allSatisfy { $0 == directory.resolvingSymlinksInPath().path })

        // The same inherited config used by Ghostty's normal New Tab action must
        // not replay a Stack command when the user opens an ordinary tab.
        let commandSurface = try #require(firstController.surfaceTree.first?.surface)
        let inherited = Ghostty.SurfaceConfiguration(from: ghostty_surface_inherited_config(commandSurface, GHOSTTY_SURFACE_CONTEXT_TAB))
        #expect(inherited.command == nil)
        #expect(inherited.initialInput == nil)
        let ordinary = try #require(TerminalController.newTab(app, from: firstController.window, withBaseConfig: inherited))
        #expect(ordinary.surfaceTree.first?.surface != nil)
        #expect(!instances.flatMap { Array($0.surfaceIDs) }.contains(ordinary.surfaceTree.first!.id))
        #expect(firstGroup.windows.count == 4)
        WorkspaceSessionStore.shared.refresh()
        let ordinarySession = try #require(WorkspaceSessionStore.shared.sessions.first { $0.window === ordinary.window })
        #expect(ordinarySession.runningStackID == nil)

        ordinary.window?.makeKeyAndOrderFront(nil)
        var attached = stack
        attached.id = UUID()
        attached.name = "Attached Stack"
        attached.tabs = [StackTabDefinition(name: "Attached tab", directory: directory.path)]
        attached.launchLocation = .currentWindow
        let third = try await StackLauncher.open(attached, using: driver) {
            WorkspaceSessionStore.shared.registerStack($0)
        }
        #expect(firstGroup.windows.count == 5)
        for controller in controllers where controller.surfaceTree.first.map({ first.surfaceIDs.contains($0.id) }) == true {
            if let window = controller.window { WorkspaceSessionStore.shared.closeSession(ObjectIdentifier(window)) }
        }
        #expect(firstGroup.windows.contains { $0 === ordinary.window })
        #expect(firstGroup.windows.count == 2)
        #expect(WorkspaceSessionStore.shared.runningStacks.contains { $0.id == third.id })
        #expect(secondGroup.windows.count == 3)
        #expect(WorkspaceSessionStore.shared.runningStacks.contains { $0.id == second.id })
        #expect(!WorkspaceSessionStore.shared.runningStacks.contains { $0.id == first.id })
        let attachedSession = try #require(WorkspaceSessionStore.shared.sessions.first { $0.runningStackID == third.id })
        WorkspaceSessionStore.shared.closeSession(attachedSession.id)
        #expect(firstGroup.windows.count == 1)
        #expect(firstGroup.windows.first === ordinary.window)
        WorkspaceSessionStore.shared.closeSession(ordinarySession.id)
        #expect(ordinary.window?.isVisible != true)
    }
}

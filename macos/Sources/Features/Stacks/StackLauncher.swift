import AppKit
import Darwin
import GhosttyKit

struct StackLaunchTab {
    let definition: StackTabDefinition
    let directory: String

    var surfaceConfiguration: Ghostty.SurfaceConfiguration {
        var configuration = Ghostty.SurfaceConfiguration()
        configuration.workingDirectory = directory
        if let command = definition.startupCommand, !command.trimmingCharacters(in: .whitespaces).isEmpty {
            // The embedded Ghostty API executes this via its shell command mechanism.
            // No keyboard input or initial-input injection is involved.
            configuration.command = command
            configuration.waitAfterCommand = true
        }
        return configuration
    }
}

struct StackLaunchPlan {
    let definition: SavedStack
    let tabs: [StackLaunchTab]

    init(_ definition: SavedStack, directoryIsAccessible: (String) -> Bool = Self.directoryIsAccessible) throws {
        try definition.validate()
        self.definition = definition
        tabs = try definition.tabs.map { tab in
            let path = URL(fileURLWithPath: (tab.directory as NSString).expandingTildeInPath)
                .standardizedFileURL.path
            guard directoryIsAccessible(path) else {
                throw StackError.unavailableDirectory(tab: tab.name, path: path)
            }
            return StackLaunchTab(definition: tab, directory: path)
        }
    }

    static func directoryIsAccessible(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
            && path.withCString { access($0, R_OK | X_OK) == 0 }
    }
}

struct StackTerminal {
    let surfaceID: UUID
    let window: NSWindow?
}

@MainActor
protocol StackTerminalCreating {
    func validate(tabCount: Int) throws
    func newWindow(configuration: Ghostty.SurfaceConfiguration) async throws -> StackTerminal
    func newTab(configuration: Ghostty.SurfaceConfiguration, after: StackTerminal) throws -> StackTerminal
    func select(_ terminal: StackTerminal)
    func setTitle(_ title: String, for terminal: StackTerminal)
}

@MainActor
enum StackLauncher {
    @discardableResult
    static func open(
        _ definition: SavedStack,
        using driver: any StackTerminalCreating,
        register: (RunningStack) -> Void
    ) async throws -> RunningStack {
        // Validate every directory before creating any process or window.
        let plan = try StackLaunchPlan(definition)
        try driver.validate(tabCount: plan.tabs.count)
        var terminals: [StackTerminal] = []
        do {
            for tab in plan.tabs {
                var configuration = tab.surfaceConfiguration
                let terminal: StackTerminal
                if let previous = terminals.last {
                    configuration.context = GHOSTTY_SURFACE_CONTEXT_TAB
                    terminal = try driver.newTab(configuration: configuration, after: previous)
                } else {
                    terminal = try await driver.newWindow(configuration: configuration)
                }
                driver.setTitle(tab.definition.name, for: terminal)
                terminals.append(terminal)
            }
        } catch {
            if !terminals.isEmpty {
                register(RunningStack(definition: definition, surfaceIDs: Set(terminals.map(\.surfaceID))))
                throw StackError.partialLaunch("Only \(terminals.count) of \(plan.tabs.count) tabs opened. The opened terminals are still running. \(error.localizedDescription)")
            }
            throw error
        }
        let instance = RunningStack(definition: definition, surfaceIDs: Set(terminals.map(\.surfaceID)))
        register(instance)
        if let first = terminals.first { driver.select(first) }
        return instance
    }
}

@MainActor
struct GhosttyStackTerminalDriver: StackTerminalCreating {
    let ghostty: Ghostty.App

    func validate(tabCount: Int) throws {
        guard tabCount > 1 else { return }
        if !ghostty.config.windowDecorations {
            throw StackError.terminalCreation("Stacks with multiple tabs need window decorations enabled. Change window-decoration and try again.")
        }
        if ghostty.config.macosTitlebarStyle == .hidden {
            throw StackError.terminalCreation("Stacks with multiple tabs need a tab-capable titlebar. Change macos-titlebar-style from hidden and try again.")
        }
        if let fullscreen = ghostty.config.windowFullscreen, fullscreen != .native {
            throw StackError.terminalCreation("Stacks with multiple tabs cannot open in non-native fullscreen. Change window-fullscreen and try again.")
        }
    }

    func newWindow(configuration: Ghostty.SurfaceConfiguration) async throws -> StackTerminal {
        try await withCheckedThrowingContinuation { continuation in
            _ = TerminalController.newWindow(
                ghostty,
                withBaseConfig: configuration,
                inheritingParentFullscreen: false,
                onPresented: { controller, presented in
                    do {
                        guard presented else {
                            throw StackError.terminalCreation("MiTerm could not present the Stack window.")
                        }
                        continuation.resume(returning: try terminal(for: controller))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            )
        }
    }

    func newTab(configuration: Ghostty.SurfaceConfiguration, after previous: StackTerminal) throws -> StackTerminal {
        guard let parent = previous.window,
              let controller = TerminalController.newTab(ghostty, from: parent, withBaseConfig: configuration) else {
            throw StackError.terminalCreation("MiTerm could not create the next Stack tab.")
        }
        let next = try terminal(for: controller)
        guard next.window?.tabGroup === parent.tabGroup else {
            throw StackError.terminalCreation("MiTerm could not attach the next tab to the Stack window.")
        }
        return next
    }

    func select(_ terminal: StackTerminal) {
        terminal.window?.tabGroup?.selectedWindow = terminal.window
        terminal.window?.makeKeyAndOrderFront(nil)
    }

    func setTitle(_ title: String, for terminal: StackTerminal) {
        (terminal.window?.windowController as? TerminalController)?.titleOverride = title
    }

    private func terminal(for controller: TerminalController) throws -> StackTerminal {
        guard let window = controller.window,
              let surface = controller.surfaceTree.first,
              surface.surface != nil else {
            throw StackError.terminalCreation("Ghostty could not create a terminal surface.")
        }
        return StackTerminal(surfaceID: surface.id, window: window)
    }
}

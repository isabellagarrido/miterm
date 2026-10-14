import Foundation

/// Launch configuration only. Live directories and processes never write back here.
struct SavedStack: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var icon: String?
    var accent: WorkspaceColor?
    var tabs: [StackTabDefinition]
    /// Missing in older libraries: retain the original separate-window behavior.
    var launchLocation: StackLaunchLocation?

    static func new() -> SavedStack {
        SavedStack(name: "", tabs: [StackTabDefinition(name: "Terminal")])
    }

    func duplicated() -> SavedStack {
        var copy = self
        copy.id = UUID()
        copy.name = "\(name) Copy"
        copy.tabs = tabs.map { tab in
            var copy = tab
            copy.id = UUID()
            return copy
        }
        return copy
    }

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StackError.invalidDefinition("Give the Stack a name.")
        }
        guard !tabs.isEmpty else {
            throw StackError.invalidDefinition("Add at least one tab.")
        }
        guard Set(tabs.map(\.id)).count == tabs.count else {
            throw StackError.invalidDefinition("The Stack contains duplicate tab identifiers.")
        }
        if let icon, !icon.isEmpty {
            guard icon.count == 1, icon.unicodeScalars.contains(where: { $0.properties.isEmoji }) else {
                throw StackError.invalidDefinition("Choose a single emoji for the Stack icon.")
            }
        }
        for tab in tabs {
            guard !tab.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StackError.invalidDefinition("Give each tab a name.")
            }
            guard !tab.directory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !Ghostty.Shell.containsControlCharacters(tab.directory) else {
                throw StackError.invalidDefinition("Choose a starting directory for \(tab.name).")
            }
            let expanded = (tab.directory as NSString).expandingTildeInPath
            guard expanded.hasPrefix("/") else {
                throw StackError.invalidDefinition("Use an absolute path or ~/ path for \(tab.name).")
            }
            if let command = tab.startupCommand, Ghostty.Shell.containsControlCharacters(command) {
                throw StackError.invalidDefinition("The command for \(tab.name) must be a single line without control characters.")
            }
        }
    }

    mutating func moveTab(_ sourceID: UUID, before targetID: UUID) {
        guard sourceID != targetID,
              let source = tabs.firstIndex(where: { $0.id == sourceID }),
              tabs.contains(where: { $0.id == targetID }) else { return }
        let tab = tabs.remove(at: source)
        guard let target = tabs.firstIndex(where: { $0.id == targetID }) else { return }
        tabs.insert(tab, at: target)
    }
}

struct StackTabDefinition: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var directory: String = FileManager.default.homeDirectoryForCurrentUser.path
    var startupCommand: String?
}

/// An immutable launch snapshot, independent of subsequent edits or deletion.
/// Surface IDs keep membership stable if a tab moves to another window.
struct RunningStack: Identifiable, Equatable {
    let id: UUID
    let definition: SavedStack
    let launchedAt: Date
    var surfaceIDs: Set<UUID>

    init(definition: SavedStack, surfaceIDs: Set<UUID>) {
        id = UUID()
        self.definition = definition
        launchedAt = Date()
        self.surfaceIDs = surfaceIDs
    }
}

enum StackError: LocalizedError {
    case invalidDefinition(String)
    case unsupportedVersion(Int)
    case unavailableDirectory(tab: String, path: String)
    case terminalCreation(String)
    case partialLaunch(String)

    var errorDescription: String? {
        switch self {
        case .invalidDefinition(let message), .terminalCreation(let message), .partialLaunch(let message):
            return message
        case .unsupportedVersion(let version):
            return "This Stack library uses format version \(version), which this version of MiTerm cannot read. The saved file has been left untouched."
        case .unavailableDirectory(let tab, let path):
            return "The starting directory for \(tab) is missing, inaccessible, or not a directory:\n\(path)\nChoose an accessible directory and try again."
        }
    }
}

enum StackLaunchLocation: String, Codable, CaseIterable, Identifiable {
    case newWindow
    case currentWindow

    var id: String { rawValue }
    var title: String { self == .newWindow ? "New window" : "Current window" }
}

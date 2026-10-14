import Combine
import Foundation

struct StackLibrary: Codable, Equatable {
    static let currentVersion = 1
    var version: Int = currentVersion
    var stacks: [SavedStack] = []

    static func decode(_ data: Data) throws -> StackLibrary {
        let library = try JSONDecoder().decode(StackLibrary.self, from: data)
        guard library.version == currentVersion else { throw StackError.unsupportedVersion(library.version) }
        guard Set(library.stacks.map(\.id)).count == library.stacks.count else {
            throw StackError.invalidDefinition("The Stack library contains duplicate Stack identifiers.")
        }
        try library.stacks.forEach { try $0.validate() }
        return library
    }
}

@MainActor
final class StackDefinitionStore: ObservableObject {
    static let shared = StackDefinitionStore()

    @Published private(set) var stacks: [SavedStack] = []
    @Published private(set) var loadError: String?
    let fileURL: URL

    init(fileURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MiTerm", isDirectory: true)
        .appendingPathComponent("Stacks.json")) {
        self.fileURL = fileURL
        reload()
    }

    /// A damaged or newer library is never replaced with an empty one.
    func reload() {
        do {
            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                stacks = []
                loadError = nil
                return
            }
            stacks = try StackLibrary.decode(data).stacks
            loadError = nil
        } catch {
            loadError = "Could not load saved Stacks. \(error.localizedDescription)"
        }
    }

    func save(_ stack: SavedStack) throws {
        try stack.validate()
        var updated = stacks
        if let index = updated.firstIndex(where: { $0.id == stack.id }) {
            updated[index] = stack
        } else {
            updated.append(stack)
        }
        try persist(updated)
    }

    @discardableResult
    func duplicate(_ stack: SavedStack) throws -> SavedStack {
        let copy = stack.duplicated()
        try save(copy)
        return copy
    }

    func delete(_ id: UUID) throws {
        try persist(stacks.filter { $0.id != id })
    }

    private func persist(_ updated: [SavedStack]) throws {
        guard loadError == nil else {
            throw StackError.invalidDefinition("The Stack library cannot be changed until its load error is resolved. Reveal the saved file to inspect it, then reload.")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(StackLibrary(stacks: updated))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        stacks = updated
    }
}

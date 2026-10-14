import AppKit
import SwiftUI

private struct StackUIError: Identifiable {
    let id = UUID()
    let message: String
}

struct StackManagerView: View {
    @EnvironmentObject private var app: AppDelegate
    @ObservedObject private var store = StackDefinitionStore.shared
    @State private var editing: SavedStack?
    @State private var deleting: SavedStack?
    @State private var failure: StackUIError?
    @State private var isLaunching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Stacks")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Your terminal setup, ready to open.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { editing = .new() } label: {
                    Label("New Stack", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.loadError != nil)
            }

            if let loadError = store.loadError {
                VStack(alignment: .leading, spacing: 10) {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                    HStack {
                        Button("Reveal saved file") {
                            NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                        }
                        Button("Reload") { store.reload() }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            if store.stacks.isEmpty && store.loadError == nil {
                VStack(spacing: 14) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Start with the terminals you open together")
                        .font(.title3.weight(.medium))
                    Text("Save a few tabs, their starting directories, and optional commands.\nOpen a Stack whenever you need it — ordinary terminals work as always.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Create a Stack") { editing = .new() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 18)], spacing: 18) {
                        ForEach(store.stacks) { stack in
                            stackCard(stack)
                        }
                    }
                    .padding(2)
                }
            }

            HStack {
                Text("Each Open starts an independent window. Saved changes apply to future launches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isLaunching { ProgressView().controlSize(.small) }
            }
        }
        .padding(28)
        .frame(minWidth: 720, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editing) { stack in
            StackEditorView(original: stack) { draft in try store.save(draft) }
        }
        .alert(item: $failure) { failure in
            Alert(title: Text("Could not complete Stack action"), message: Text(failure.message))
        }
        .alert("Delete saved Stack?", isPresented: Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) {
                guard let stack = deleting else { return }
                perform { try store.delete(stack.id) }
                deleting = nil
            }
        } message: {
            Text("This removes the saved configuration. Its running terminals will stay open.")
        }
    }

    private func stackCard(_ stack: SavedStack) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                StackIconView(stack: stack)
                VStack(alignment: .leading, spacing: 3) {
                    Text(stack.name).font(.headline).lineLimit(2)
                    Text("\(stack.tabs.count) \(stack.tabs.count == 1 ? "tab" : "tabs")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Edit…") { editing = stack }
                    Button("Duplicate") { perform { _ = try store.duplicate(stack) } }
                    Divider()
                    Button("Delete…", role: .destructive) { deleting = stack }
                } label: {
                    Image(systemName: "ellipsis")
                        .padding(4)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Actions for \(stack.name)")
                .disabled(store.loadError != nil)
            }
            ForEach(stack.tabs.prefix(3)) { tab in
                VStack(alignment: .leading, spacing: 3) {
                    Text(tab.name).font(.system(size: 12, weight: .medium))
                    Text(tab.directory).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    if let command = tab.startupCommand, !command.isEmpty {
                        Text("› \(command)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            if stack.tabs.count > 3 {
                Text("+\(stack.tabs.count - 3) more tabs").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Edit") { editing = stack }
                    .disabled(store.loadError != nil)
                Spacer()
                Button { open(stack) } label: {
                    Label("Open Stack", systemImage: "arrow.up.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLaunching || store.loadError != nil)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5))
        }
    }

    private func open(_ stack: SavedStack) {
        isLaunching = true
        Task { @MainActor in
            defer { isLaunching = false }
            do {
                try await StackLauncher.open(stack, using: GhosttyStackTerminalDriver(ghostty: app.ghostty)) {
                    WorkspaceSessionStore.shared.registerStack($0)
                }
            } catch {
                failure = StackUIError(message: error.localizedDescription)
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { failure = StackUIError(message: error.localizedDescription) }
    }
}

private struct StackIconView: View {
    let stack: SavedStack

    var body: some View {
        Group {
            if let icon = stack.icon, !icon.isEmpty {
                Text(icon).font(.system(size: 22))
            } else {
                Image(systemName: "square.stack.3d.up").font(.system(size: 22))
            }
        }
        .frame(width: 44, height: 44)
        .foregroundStyle(stack.accent?.color ?? Color.accentColor)
        .background((stack.accent?.color ?? Color.accentColor).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
    }
}

private struct StackEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let original: SavedStack
    let save: (SavedStack) throws -> Void
    @State private var draft: SavedStack
    @State private var failure: StackUIError?
    @State private var discardConfirmation = false
    @State private var dropTarget: UUID?

    init(original: SavedStack, save: @escaping (SavedStack) throws -> Void) {
        self.original = original
        self.save = save
        _draft = State(initialValue: original)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(original.name.isEmpty ? "New Stack" : "Edit Stack").font(.title2.weight(.semibold))
                    Text("Arrange your starting point. Running sessions keep their own state.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                StackIconView(stack: draft)
            }
            HStack(spacing: 14) {
                TextField("Stack name", text: $draft.name)
                    .font(.title3)
                    .accessibilityLabel("Stack name")
                StackEmojiPicker(emoji: $draft.icon)
                    .frame(width: 120, height: 28)
                if draft.icon != nil {
                    Button { draft.icon = nil } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove Stack emoji")
                    .accessibilityLabel("Remove Stack emoji")
                }
                if draft.accent != nil {
                    ColorPicker("Accent", selection: Binding(
                        get: { draft.accent?.color ?? .accentColor },
                        set: { draft.accent = WorkspaceColor(color: $0) }
                    ), supportsOpacity: false)
                    Button("Clear accent") { draft.accent = nil }
                        .font(.caption)
                } else {
                    Button("Add accent") { draft.accent = WorkspaceColor(hex: 0x5B80CC) }
                }
            }
            .textFieldStyle(.roundedBorder)

            HStack {
                Text("Tabs").font(.headline)
                Text("Drag the handle to reorder").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { draft.tabs.append(StackTabDefinition(name: "Terminal \(draft.tabs.count + 1)")) } label: {
                    Label("Add tab", systemImage: "plus")
                }
            }
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($draft.tabs) { $tab in
                        StackTabEditorRow(
                            tab: $tab,
                            canMoveUp: draft.tabs.first?.id != tab.id,
                            canMoveDown: draft.tabs.last?.id != tab.id,
                            remove: { draft.tabs.removeAll { $0.id == tab.id } },
                            move: { offset in move(tab.id, by: offset) }
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(dropTarget == tab.id ? Color.accentColor : .clear, lineWidth: 2)
                        }
                        .dropDestination(for: String.self) { ids, _ in
                            guard let value = ids.first, let source = UUID(uuidString: value),
                                  draft.tabs.contains(where: { $0.id == source }) else { return false }
                            draft.moveTab(source, before: tab.id)
                            return true
                        } isTargeted: { targeted in
                            if targeted { dropTarget = tab.id } else if dropTarget == tab.id { dropTarget = nil }
                        }
                    }
                }
                .padding(2)
            }
            Text("Commands run instead of the default shell, only when you choose Open Stack. The tab keeps the output visible when the command exits.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancel") {
                    if draft != original { discardConfirmation = true } else { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save Stack") {
                    do {
                        try save(draft)
                        dismiss()
                    } catch { failure = StackUIError(message: error.localizedDescription) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.tabs.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 760, height: 650)
        .interactiveDismissDisabled(draft != original)
        .alert(item: $failure) { failure in
            Alert(title: Text("Could not save Stack"), message: Text(failure.message))
        }
        .alert("Discard changes?", isPresented: $discardConfirmation) {
            Button("Keep editing", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        }
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let index = draft.tabs.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard draft.tabs.indices.contains(destination) else { return }
        draft.tabs.swapAt(index, destination)
    }
}

private struct StackTabEditorRow: View {
    @Binding var tab: StackTabDefinition
    let canMoveUp: Bool
    let canMoveDown: Bool
    let remove: () -> Void
    let move: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .draggable(tab.id.uuidString)
                    .help("Drag to reorder tab")
                TextField("Tab name", text: $tab.name)
                    .font(.system(size: 13, weight: .medium))
                    .accessibilityLabel("Tab name")
                Spacer()
                Button { move(-1) } label: { Image(systemName: "chevron.up") }
                    .disabled(!canMoveUp).accessibilityLabel("Move tab up")
                Button { move(1) } label: { Image(systemName: "chevron.down") }
                    .disabled(!canMoveDown).accessibilityLabel("Move tab down")
                Button(role: .destructive, action: remove) { Image(systemName: "trash") }
                    .accessibilityLabel("Remove tab")
            }
            HStack {
                Image(systemName: "folder").foregroundStyle(.secondary)
                TextField("Starting directory", text: $tab.directory)
                    .accessibilityLabel("Starting directory for \(tab.name)")
                Button("Choose…", action: chooseDirectory)
            }
            HStack {
                Image(systemName: "terminal").foregroundStyle(.secondary)
                TextField("Startup command (optional)", text: Binding(
                    get: { tab.startupCommand ?? "" },
                    set: { tab.startupCommand = $0.isEmpty ? nil : $0 }
                ))
                .font(.system(size: 12, design: .monospaced))
                .accessibilityLabel("Startup command for \(tab.name)")
            }
        }
        .textFieldStyle(.roundedBorder)
        .buttonStyle(.borderless)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose a starting directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: (tab.directory as NSString).expandingTildeInPath)
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url { tab.directory = url.path }
        }
    }
}

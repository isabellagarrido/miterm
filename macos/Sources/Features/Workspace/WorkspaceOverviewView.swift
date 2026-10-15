import AppKit
import SwiftUI

struct WorkspaceSessionSidebar: View {
  private static let sidebarWidthKey = "WorkspaceSessionSidebarWidth"
  private static let defaultSidebarWidth: CGFloat = 230
  private static let minimumSidebarWidth: CGFloat = 180
  private static let maximumSidebarWidth: CGFloat = 480

  @ObservedObject private var sessionStore = WorkspaceSessionStore.shared
  @ObservedObject private var iconStore = WorkspaceSessionIconStore.shared
  @ObservedObject private var customization = WorkspaceCustomizationStore.shared
  @State private var isCollapsed = false
  @State private var sidebarWidth: CGFloat = {
    let savedWidth = UserDefaults.ghostty.double(forKey: sidebarWidthKey)
    return savedWidth > 0 ? CGFloat(savedWidth) : defaultSidebarWidth
  }()
  @State private var dragStartWidth: CGFloat?
  @State private var hoveredSessionID: ObjectIdentifier?
  @FocusState private var focusedSessionID: ObjectIdentifier?
  @FocusState private var focusedCloseSessionID: ObjectIdentifier?
  let window: NSWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        if !isCollapsed {
          Text("Tabs")
            .font(.system(size: 13, weight: .semibold))
        }
        Spacer(minLength: 2)
        Button { sessionStore.newTab(in: window) } label: {
          Image(systemName: "plus")
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help("New tab")
        .accessibilityLabel("New tab")
        Button {
          withAnimation(.easeInOut(duration: 0.18)) { isCollapsed.toggle() }
        } label: {
          Image(systemName: isCollapsed ? "sidebar.right" : "sidebar.left")
        }
        .buttonStyle(.plain)
        .help(isCollapsed ? "Expand session sidebar" : "Collapse session sidebar")
      }

      ScrollView {
        VStack(spacing: 7) {
          ForEach(sessionStore.tabItems(in: window)) { item in
            if let session = item.session {
              let showsClose = hoveredSessionID == session.id
                || focusedSessionID == session.id || focusedCloseSessionID == session.id
              ZStack(alignment: isCollapsed ? .center : .trailing) {
                Button {
                  item.select()
                } label: {
                  sessionRow(session, showingCloseButton: showsClose)
                    .opacity(showsClose && isCollapsed ? 0 : 1)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .focused($focusedSessionID, equals: session.id)
                .help(session.title)
                .accessibilityLabel(
                  "\(session.title), \(session.isSelected ? "selected" : "inactive"), \(session.activityDescription)"
                )
                Button { sessionStore.closeSession(session.id) } label: {
                  Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(5)
                    .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .focused($focusedCloseSessionID, equals: session.id)
                .help("Close tab")
                .accessibilityLabel("Close \(session.title)")
                .opacity(showsClose ? 1 : 0)
                .allowsHitTesting(showsClose)
                .accessibilityHidden(!showsClose)
                .disabled(!showsClose)
              }
              .frame(maxWidth: .infinity)
              .contentShape(Rectangle())
              .onContinuousHover { phase in
                switch phase {
                case .active:
                  if hoveredSessionID != session.id { hoveredSessionID = session.id }
                case .ended:
                  if hoveredSessionID == session.id { hoveredSessionID = nil }
                }
              }
              .contextMenu {
                Button("Close Tab") { sessionStore.closeSession(session.id) }
              }
              .draggable(String(describing: session.id))
              .dropDestination(for: String.self) { identifiers, _ in
                guard let identifier = identifiers.first,
                      let source = sessionStore.sessions.first(where: {
                        String(describing: $0.id) == identifier
                      })?.id else { return false }
                sessionStore.moveSession(source, before: session.id)
                return true
              }
            }
          }
        }
      }
    }
    .padding(10)
    .frame(width: isCollapsed ? 52 : sidebarWidth)
    .frame(maxHeight: .infinity)
    .background(customization.configuration.tabBackground.color.opacity(0.72))
    .overlay(alignment: .trailing) {
      ZStack(alignment: .trailing) {
        Rectangle()
          .fill(customization.configuration.borderColor.color)
          .frame(width: 1)

        Rectangle()
          .fill(.clear)
          .frame(width: 7)
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 1)
              .onChanged { value in
                guard !isCollapsed else { return }
                if dragStartWidth == nil { dragStartWidth = sidebarWidth }
                let startWidth = dragStartWidth ?? sidebarWidth
                sidebarWidth = min(
                  max(startWidth + value.translation.width, Self.minimumSidebarWidth),
                  Self.maximumSidebarWidth
                )
              }
              .onEnded { _ in
                dragStartWidth = nil
                UserDefaults.ghostty.set(Double(sidebarWidth), forKey: Self.sidebarWidthKey)
              }
          )
          .accessibilityLabel("Resize session sidebar")
          .help("Drag to resize session sidebar")
      }
    }
    .onAppear { sessionStore.refresh() }
  }

  @ViewBuilder
  private func sessionRow(
    _ session: WorkspaceSessionSnapshot,
    showingCloseButton: Bool
  ) -> some View {
    HStack(spacing: 9) {
      WorkspaceSessionIconView(icon: iconStore.icon(for: session), size: 14)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(customization.configuration.tabForeground.color.opacity(0.8))
        .frame(width: 18)
      if session.hasActiveBell {
        Image(systemName: "bell.badge.fill")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(Color.accentColor)
      }

      if !isCollapsed {
        VStack(alignment: .leading, spacing: 3) {
          Text(session.title)
            .font(customization.configuration.font.font(size: 12))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
          if session.hasActiveBell {
            Text("Bell active")
              .font(.system(size: 10))
              .foregroundStyle(customization.configuration.tabForeground.color.opacity(0.68))
              .lineLimit(1)
          }
        }

        ZStack(alignment: .trailing) {
          if session.isSelected && !showingCloseButton {
            Circle()
              .fill(customization.configuration.selectedBorderColor.color)
              .frame(width: 7, height: 7)
              .accessibilityLabel("Selected")
          }
        }
        .frame(width: 20, height: 12)
      }
    }
    .foregroundStyle(customization.configuration.tabForeground.color)
    .padding(.horizontal, 8)
    .padding(.vertical, 8)
    .background(
      session.isSelected
        ? customization.configuration.selectedTabBackground.color
        : customization.configuration.tabBackground.color.opacity(0.28),
      in: RoundedRectangle(cornerRadius: max(8, customization.configuration.cornerRadius))
    )
    .overlay {
      RoundedRectangle(cornerRadius: max(8, customization.configuration.cornerRadius))
        .strokeBorder(
          session.isSelected
            ? customization.configuration.selectedBorderColor.color
            : Color.clear,
          lineWidth: 1
        )
    }
    .contentShape(RoundedRectangle(cornerRadius: max(8, customization.configuration.cornerRadius)))
  }
}

struct WorkspaceOverviewView: View {
  @ObservedObject private var sessionStore = WorkspaceSessionStore.shared
  @ObservedObject private var customization = WorkspaceCustomizationStore.shared
  @State private var orderedSessionIDs: [ObjectIdentifier] = []
  @State private var dropTarget: ObjectIdentifier?

  private let columns = [
    GridItem(.adaptive(minimum: 220), spacing: 14)
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Session Overview")
          .font(.system(size: 22, weight: .semibold))
        Text("Choose a tab or focus one of its panes.")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      }

      if sessionStore.sessions.isEmpty {
        VStack(spacing: 10) {
          Image(systemName: "terminal")
            .font(.system(size: 28))
            .foregroundStyle(.secondary)
          Text("No Open Sessions")
            .font(.system(size: 16, weight: .semibold))
          Text("Open a terminal tab to see it here.")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVGrid(columns: columns, spacing: 14) {
            ForEach(orderedSessions) { session in
              WorkspaceSessionWidget(
                session: session,
                configuration: customization.configuration,
                isDropTarget: dropTarget == session.id
              ) {
                sessionStore.selectSession(session.id)
              } focusPane: { paneID in
                sessionStore.focusPane(paneID, in: session.id)
              }
              .draggable(String(describing: session.id))
              .dropDestination(for: String.self) { identifiers, _ in
                guard let identifier = identifiers.first,
                  let source = sessionStore.sessions.first(where: {
                    String(describing: $0.id) == identifier
                  })?.id
                else { return false }
                moveSession(source, before: session.id)
                return true
              } isTargeted: { isTargeted in
                dropTarget = isTargeted ? session.id : nil
              }
            }
          }
          .padding(.vertical, 2)
        }
      }
    }
    .padding(22)
    .frame(width: 760, height: 540)
    .background(Color(nsColor: .windowBackgroundColor))
    .onAppear {
      sessionStore.refresh()
      synchronizeSessionOrder()
    }
    .onChange(of: sessionStore.sessions.map(\.id)) { _ in synchronizeSessionOrder() }
  }

  private var orderedSessions: [WorkspaceSessionSnapshot] {
    let order = Dictionary(uniqueKeysWithValues: orderedSessionIDs.enumerated().map { ($1, $0) })
    return sessionStore.sessions.sorted {
      order[$0.id, default: Int.max] < order[$1.id, default: Int.max]
    }
  }

  private func synchronizeSessionOrder() {
    let activeIDs = sessionStore.sessions.map(\.id)
    orderedSessionIDs = orderedSessionIDs.filter(activeIDs.contains)
    for id in activeIDs where !orderedSessionIDs.contains(id) {
      orderedSessionIDs.append(id)
    }
  }

  private func moveSession(_ source: ObjectIdentifier, before target: ObjectIdentifier) {
    guard source != target, let sourceIndex = orderedSessionIDs.firstIndex(of: source) else {
      return
    }
    orderedSessionIDs.remove(at: sourceIndex)
    guard let targetIndex = orderedSessionIDs.firstIndex(of: target) else {
      orderedSessionIDs.append(source)
      return
    }
    orderedSessionIDs.insert(source, at: targetIndex)
  }
}

private struct WorkspaceSessionWidget: View {
  @ObservedObject private var iconStore = WorkspaceSessionIconStore.shared
  @State private var isEmojiPickerPresented = false
  let session: WorkspaceSessionSnapshot
  let configuration: WorkspaceThemeConfiguration
  let isDropTarget: Bool
  let action: () -> Void
  let focusPane: (UUID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 11) {
      Button(action: action) {
        HStack(alignment: .top, spacing: 10) {
          WorkspaceSessionIconView(icon: iconStore.icon(for: session), size: 16)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(configuration.tabForeground.color.opacity(0.8))
          VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
              .font(configuration.font.font(size: configuration.fontSize + 1))
              .lineLimit(2)
              .multilineTextAlignment(.leading)
            HStack(spacing: 5) {
              Image(systemName: session.isSelected ? "circle.inset.filled" : "circle")
              Text(session.isSelected ? "Selected tab" : "Open tab")
              if !session.panes.isEmpty {
                Text("·")
                Text("\(session.panes.count) \(session.panes.count == 1 ? "pane" : "panes")")
              }
              if session.hasActiveBell {
                Image(systemName: "bell.badge.fill")
                  .foregroundStyle(Color.accentColor)
                Text("Bell active")
              }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(
              session.isSelected
                ? configuration.selectedBorderColor.color
                : configuration.tabForeground.color.opacity(0.65))
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          Image(systemName: "arrow.up.forward")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(configuration.tabForeground.color.opacity(0.55))
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Open this tab")

      if session.panes.count > 1 {
        Divider().overlay(configuration.borderColor.color.opacity(0.55))
        VStack(spacing: 5) {
          ForEach(session.panes) { pane in
            Button { focusPane(pane.id) } label: {
              HStack(spacing: 8) {
                Image(systemName: pane.isFocused ? "circle.inset.filled" : "terminal")
                  .font(.system(size: 11, weight: .medium))
                  .foregroundStyle(
                    pane.isFocused
                      ? configuration.selectedBorderColor.color
                      : configuration.tabForeground.color.opacity(0.7))
                VStack(alignment: .leading, spacing: 2) {
                  Text(pane.displayTitle)
                    .font(.system(size: 12, weight: pane.isFocused ? .semibold : .medium))
                    .lineLimit(1)
                  if let directory = pane.directory, !directory.isEmpty {
                    Text(directory)
                      .font(.system(size: 10, design: .monospaced))
                      .foregroundStyle(configuration.tabForeground.color.opacity(0.62))
                      .lineLimit(1)
                      .truncationMode(.middle)
                  }
                }
                Spacer(minLength: 4)
                if pane.isFocused {
                  Text("Focused")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(configuration.selectedBorderColor.color)
                }
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 6)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                pane.isFocused
                  ? configuration.selectedTabBackground.color.opacity(0.72)
                  : Color.clear,
                in: RoundedRectangle(cornerRadius: max(6, configuration.cornerRadius))
              )
              .contentShape(RoundedRectangle(cornerRadius: max(6, configuration.cornerRadius)))
            }
            .buttonStyle(.plain)
            .help("Focus \(pane.displayTitle)")
            .accessibilityLabel(
              "Focus pane \(pane.index + 1), \(pane.displayTitle)\(pane.isFocused ? ", focused" : "")"
            )
          }
        }
      }

      if let stackName = session.stackName {
        Label(stackName, systemImage: "square.stack.3d.up")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(configuration.tabForeground.color.opacity(0.7))
          .lineLimit(1)
      }
    }
    .padding(configuration.horizontalPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      configuration.tabBackground.color,
      in: RoundedRectangle(cornerRadius: configuration.cornerRadius + 5)
    )
    .overlay {
      RoundedRectangle(cornerRadius: configuration.cornerRadius + 5)
        .strokeBorder(
          isDropTarget
            ? configuration.selectedBorderColor.color
            : (session.isSelected
              ? configuration.selectedBorderColor.color : configuration.borderColor.color),
          lineWidth: isDropTarget || session.isSelected ? 2 : 1
        )
    }
    .foregroundStyle(configuration.tabForeground.color)
    .contextMenu {
      Menu("Choose Session Icon") {
        Section("System icons") {
          ForEach(Self.iconChoices, id: \.self) { symbol in
            Button {
              iconStore.setIcon(symbol, for: session)
            } label: {
              Label(symbol.replacingOccurrences(of: ".", with: " ").capitalized, systemImage: symbol)
            }
          }
        }
        Section("Emoji") {
          Button("Choose Emoji…", systemImage: "face.smiling") {
            isEmojiPickerPresented = true
          }
        }
      }
    }
    .popover(isPresented: $isEmojiPickerPresented) {
      WorkspaceSessionEmojiPickerContent(session: session)
    }
    .accessibilityLabel(
      "\(session.title), \(session.isSelected ? "selected" : "inactive"), \(session.activityDescription). Drag to rearrange."
    )
  }

  private static let iconChoices = [
    "terminal", "chevron.left.forwardslash.chevron.right", "folder", "hammer", "shippingbox",
    "sparkles",
  ]

}

import AppKit
import SwiftUI

struct WorkspaceSessionSidebar: View {
  @ObservedObject private var sessionStore = WorkspaceSessionStore.shared
  @ObservedObject private var iconStore = WorkspaceSessionIconStore.shared
  @ObservedObject private var customization = WorkspaceCustomizationStore.shared
  @State private var isCollapsed = false
  let window: NSWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        if !isCollapsed {
          Text("Tabs")
            .font(.system(size: 13, weight: .semibold))
        }
        Spacer(minLength: 2)
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
              HStack(spacing: 2) {
                Button {
                  item.select()
                } label: {
                  sessionRow(session)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
                .help(session.title)
                .accessibilityLabel(
                  "\(session.title), \(session.isSelected ? "selected" : "inactive"), \(session.activityDescription)"
                )
                Button { sessionStore.closeSession(session.id) } label: {
                  Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(5)
                }
                .buttonStyle(.plain)
                .help("Close tab")
                .accessibilityLabel("Close \(session.title)")
              }
              .contextMenu {
                Button("Close Tab") { sessionStore.closeSession(session.id) }
                if let id = session.runningStackID {
                  Button("Close Stack…") { sessionStore.requestCloseStack(id) }
                }
              }
            }
          }
        }
      }
    }
    .padding(10)
    .frame(width: isCollapsed ? 84 : 230)
    .frame(maxHeight: .infinity)
    .background(customization.configuration.tabBackground.color.opacity(0.72))
    .overlay(alignment: .trailing) {
      Rectangle()
        .fill(customization.configuration.borderColor.color)
        .frame(width: 1)
    }
    .onAppear { sessionStore.refresh() }
  }

  @ViewBuilder
  private func sessionRow(_ session: WorkspaceSessionSnapshot) -> some View {
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
          Text(session.hasActiveBell ? "Bell" : "Output activity unavailable")
            .font(.system(size: 10))
            .foregroundStyle(customization.configuration.tabForeground.color.opacity(0.68))
            .lineLimit(1)
        }

        if session.isSelected {
          Circle()
            .fill(customization.configuration.selectedBorderColor.color)
            .frame(width: 7, height: 7)
            .accessibilityLabel("Selected")
        }
      }
    }
    .foregroundStyle(customization.configuration.tabForeground.color)
    .padding(.horizontal, 8)
    .padding(.vertical, 8)
    .background(
      session.isSelected
        ? customization.configuration.selectedTabBackground.color
        : Color.clear,
      in: RoundedRectangle(cornerRadius: customization.configuration.cornerRadius)
    )
    .overlay {
      RoundedRectangle(cornerRadius: customization.configuration.cornerRadius)
        .strokeBorder(
          session.isSelected
            ? customization.configuration.selectedBorderColor.color
            : Color.clear,
          lineWidth: 1
        )
    }
    .contentShape(RoundedRectangle(cornerRadius: customization.configuration.cornerRadius))
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
        Text("Open terminal tabs from Ghostty’s window groups.")
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

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 13) {
        HStack(alignment: .top) {
          WorkspaceSessionIconView(icon: iconStore.icon(for: session), size: 16)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(configuration.tabForeground.color.opacity(0.8))
          if session.hasActiveBell {
            Image(systemName: "bell.badge.fill")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(Color.accentColor)
          }
          Spacer()
          Label(
            session.isSelected ? "Selected" : "Inactive",
            systemImage: session.isSelected ? "circle.inset.filled" : "circle"
          )
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(
            session.isSelected
              ? configuration.selectedBorderColor.color
              : configuration.tabForeground.color.opacity(0.65))
        }

        if let stackName = session.stackName {
          Label(stackName, systemImage: "square.stack.3d.up")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(configuration.tabForeground.color.opacity(0.7))
            .lineLimit(1)
        }

        Text(session.title)
          .font(configuration.font.font(size: configuration.fontSize + 1))
          .lineLimit(2)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

        HStack(spacing: 6) {
          Image(systemName: session.hasActiveBell ? "bell.badge" : "minus.circle")
          Text(session.activityDescription)
        }
        .font(.system(size: 11))
        .foregroundStyle(configuration.tabForeground.color.opacity(0.7))
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
    }
    .buttonStyle(.plain)
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

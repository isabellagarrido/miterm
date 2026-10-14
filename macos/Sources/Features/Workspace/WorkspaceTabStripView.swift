import SwiftUI

struct WorkspaceTabItem: Identifiable {
    let id: String
    let title: String
    let isSelected: Bool
    let session: WorkspaceSessionSnapshot?
    let select: () -> Void
}

struct WorkspaceTabStripView: View {
    @ObservedObject private var sessions = WorkspaceSessionStore.shared
    @ObservedObject private var sessionIcons = WorkspaceSessionIconStore.shared
    let items: [WorkspaceTabItem]
    let configuration: WorkspaceThemeConfiguration

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: configuration.spacing) {
                ForEach(items) { item in
                    HStack(spacing: 2) {
                        Button(action: item.select) {
                            HStack(spacing: 6) {
                                if let session = item.session {
                                    WorkspaceSessionIconView(
                                        icon: sessionIcons.icon(for: session),
                                        size: configuration.fontSize
                                    )
                                }
                                Text(item.title)
                                    .lineLimit(1)
                            }

                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.title)
                        .accessibilityAddTraits(item.isSelected ? .isSelected : [])
                        if let session = item.session {
                            Button { sessions.closeSession(session.id) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(5)
                            }
                            .buttonStyle(.plain)
                            .help("Close tab")
                            .accessibilityLabel("Close \(item.title)")
                        }
                    }
                    .font(configuration.font.font(size: configuration.fontSize))
                    .foregroundStyle(
                        (item.isSelected
                         ? configuration.selectedTabForeground
                         : configuration.tabForeground).color
                    )
                    .padding(.horizontal, configuration.horizontalPadding)
                    .padding(.vertical, configuration.verticalPadding)
                    .background(
                        (item.isSelected
                         ? configuration.selectedTabBackground
                         : configuration.tabBackground).color,
                        in: RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: configuration.cornerRadius)
                            .strokeBorder(
                                (item.isSelected
                                 ? configuration.selectedBorderColor
                                 : configuration.borderColor).color,
                                lineWidth: item.isSelected ? 1.5 : 1
                            )
                    }
                    .contextMenu {
                        if let session = item.session {
                            Button("Close Tab") { sessions.closeSession(session.id) }
                            if let id = session.runningStackID {
                                Button("Close Stack…") { sessions.requestCloseStack(id) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
        .background(configuration.tabBackground.color.opacity(0.42))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session tabs")
    }

    static func sampleItems() -> [WorkspaceTabItem] {
        [
            WorkspaceTabItem(
                id: "overview-1", title: "MiTerm", isSelected: true, session: nil, select: {}),
            WorkspaceTabItem(
                id: "overview-2", title: "zsh — ~/Projects", isSelected: false, session: nil, select: {}),
            WorkspaceTabItem(
                id: "overview-3", title: "Build output", isSelected: false, session: nil, select: {}),
        ]
    }
}

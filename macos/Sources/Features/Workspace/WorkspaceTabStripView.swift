import SwiftUI

struct WorkspaceTabItem: Identifiable {
    let id: String
    let title: String
    let isSelected: Bool
    let select: () -> Void
}

struct WorkspaceTabStripView: View {
    let items: [WorkspaceTabItem]
    let configuration: WorkspaceThemeConfiguration

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: configuration.spacing) {
                ForEach(items) { item in
                    Button(action: item.select) {
                        Text(item.title)
                            .font(configuration.font.font(size: configuration.fontSize))
                            .foregroundStyle(
                                (item.isSelected
                                 ? configuration.selectedTabForeground
                                 : configuration.tabForeground).color
                            )
                            .lineLimit(1)
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
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(item.isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
        .background(configuration.tabBackground.color.opacity(0.42))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workspace tabs")
    }

    static func sampleItems() -> [WorkspaceTabItem] {
        [
            WorkspaceTabItem(id: "overview-1", title: "MiTerm", isSelected: true, select: {}),
            WorkspaceTabItem(id: "overview-2", title: "zsh — ~/Projects", isSelected: false, select: {}),
            WorkspaceTabItem(id: "overview-3", title: "Build output", isSelected: false, select: {}),
        ]
    }
}

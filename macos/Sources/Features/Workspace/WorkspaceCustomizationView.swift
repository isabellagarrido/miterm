import SwiftUI

struct WorkspaceCustomizationView: View {
    @ObservedObject private var store = WorkspaceCustomizationStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Customize Workspace")
                    .font(.system(size: 22, weight: .semibold))
                Text("Style the workspace tabs independently from the terminal surface.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                Picker("Base theme", selection: Binding(
                    get: { store.configuration.baseTheme },
                    set: { store.selectBaseTheme($0) }
                )) {
                    ForEach(WorkspaceTabTheme.allCases) { theme in
                        Text(theme.name).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Tab display", selection: Binding(
                    get: { store.tabPresentation },
                    set: { store.setTabPresentation($0) }
                )) {
                    ForEach(WorkspaceTabPresentation.allCases) { presentation in
                        Text(presentation.title).tag(presentation)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }

            Divider()

            HStack(alignment: .top, spacing: 20) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Tab colors")
                            .font(.system(size: 14, weight: .semibold))
                        colorPicker("Background", keyPath: \.tabBackground)
                        colorPicker("Foreground", keyPath: \.tabForeground)
                        colorPicker("Selected background", keyPath: \.selectedTabBackground)
                        colorPicker("Selected foreground", keyPath: \.selectedTabForeground)
                        colorPicker("Border", keyPath: \.borderColor)
                        colorPicker("Selected border", keyPath: \.selectedBorderColor)

                        Divider()

                        Text("Tab layout")
                            .font(.system(size: 14, weight: .semibold))
                        Picker("Font", selection: Binding(
                            get: { store.configuration.font },
                            set: { font in store.update { $0.font = font } }
                        )) {
                            ForEach(WorkspaceThemeFont.allCases) { font in
                                Text(font.title).tag(font)
                            }
                        }
                        slider("Font size", keyPath: \.fontSize, range: 9...22, suffix: " pt")
                        slider("Tab spacing", keyPath: \.spacing, range: 0...24, suffix: " pt")
                        slider("Horizontal padding", keyPath: \.horizontalPadding, range: 4...28, suffix: " pt")
                        slider("Vertical padding", keyPath: \.verticalPadding, range: 3...18, suffix: " pt")
                        slider("Corner radius", keyPath: \.cornerRadius, range: 0...20, suffix: " pt")
                    }
                    .padding(.trailing, 4)
                }
                .frame(width: 320, height: 430)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Live preview")
                        .font(.system(size: 14, weight: .semibold))
                    WorkspaceTabStripView(
                        items: WorkspaceTabStripView.sampleItems(),
                        configuration: store.configuration
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(nsColor: .separatorColor))
                    }

                    Spacer()
                    HStack {
                        Text("Reset returns to this theme’s defaults.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reset Customizations") {
                            store.resetCustomizations()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(22)
        .frame(width: 820, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func colorPicker(
        _ title: String,
        keyPath: WritableKeyPath<WorkspaceThemeConfiguration, WorkspaceColor>
    ) -> some View {
        ColorPicker(title, selection: Binding(
            get: { store.configuration[keyPath: keyPath].color },
            set: { color in
                store.update { configuration in
                    configuration[keyPath: keyPath] = WorkspaceColor(color: color)
                }
            }
        ), supportsOpacity: false)
        .font(.system(size: 12))
    }

    private func slider(
        _ title: String,
        keyPath: WritableKeyPath<WorkspaceThemeConfiguration, Double>,
        range: ClosedRange<Double>,
        suffix: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text("\(store.configuration[keyPath: keyPath], specifier: "%.0f")\(suffix)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.system(size: 12))
            Slider(value: Binding(
                get: { store.configuration[keyPath: keyPath] },
                set: { value in store.update { $0[keyPath: keyPath] = value } }
            ), in: range)
        }
    }
}

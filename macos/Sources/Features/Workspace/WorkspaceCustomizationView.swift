import AppKit
import SwiftUI

private enum WorkspaceEditorSection: String, CaseIterable, Identifiable {
  case appearance = "Appearance"
  case terminal = "Terminal"
  case tabs = "Tabs"
  case layout = "Layout"
  case widgets = "Widgets"
  case icons = "Icons"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .appearance: "paintpalette"
    case .terminal: "terminal"
    case .tabs: "rectangle.topthird.inset.filled"
    case .layout: "rectangle.split.2x1"
    case .widgets: "square.grid.2x2"
    case .icons: "app.dashed"
    }
  }
}

struct WorkspaceCustomizationView: View {
  @ObservedObject private var store = WorkspaceCustomizationStore.shared
  @ObservedObject private var typography = TerminalTypographyStore.shared
  @ObservedObject private var sessions = WorkspaceSessionStore.shared
  @ObservedObject private var sessionIcons = WorkspaceSessionIconStore.shared
  @State private var selectedSection: WorkspaceEditorSection? = .appearance

  var body: some View {
    NavigationSplitView {
      List(WorkspaceEditorSection.allCases, selection: $selectedSection) { section in
        Label(section.rawValue, systemImage: section.symbol)
          .tag(section)
      }
      .navigationTitle("Customize Workspace")
      .navigationSplitViewColumnWidth(min: 165, ideal: 185)
    } detail: {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          sectionContent
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(Color(nsColor: .windowBackgroundColor))
    }
    .frame(minWidth: 930, minHeight: 650)
  }

  @ViewBuilder
  private var sectionContent: some View {
    switch selectedSection ?? .appearance {
    case .appearance:
      appearanceSection
    case .terminal:
      terminalSection
    case .tabs:
      tabsSection
    case .layout:
      layoutSection
    case .widgets:
      widgetsSection
    case .icons:
      iconsSection
    }
  }

  private var appearanceSection: some View {
    VStack(alignment: .leading, spacing: 18) {
      sectionHeader(
        "Appearance",
        subtitle: "Choose a workspace theme. Terminal grid styling is configured separately.")
      Picker(
        "Base theme",
        selection: Binding(
          get: { store.configuration.baseTheme },
          set: { store.selectBaseTheme($0) }
        )
      ) {
        ForEach(WorkspaceTabTheme.allCases) { theme in
          Text(theme.name).tag(theme)
        }
      }
      .pickerStyle(.segmented)

      HStack(spacing: 12) {
        ForEach(WorkspaceTabTheme.allCases) { theme in
          VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 9)
              .fill(Color(nsColor: theme.previewSurfaceColor))
              .frame(height: 84)
              .overlay(alignment: .bottomLeading) {
                Text(theme.name)
                  .font(
                    theme == .newspaper
                      ? .system(size: 15, design: .serif)
                      : .system(
                        size: 14, weight: .semibold,
                        design: theme == .pixel ? .monospaced : .default)
                  )
                  .foregroundStyle(Color(nsColor: theme.previewForegroundColor))
                  .padding(12)
              }
              .overlay {
                RoundedRectangle(cornerRadius: 9)
                  .strokeBorder(
                    store.configuration.baseTheme == theme
                      ? Color.accentColor
                      : Color(nsColor: .separatorColor),
                    lineWidth: store.configuration.baseTheme == theme ? 2 : 1
                  )
              }
            Text(theme.detail)
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .contentShape(Rectangle())
          .onTapGesture { store.selectBaseTheme(theme) }
        }
      }

      preview
      resetButton
    }
  }

  private var terminalSection: some View {
    VStack(alignment: .leading, spacing: 18) {
      sectionHeader(
        "Terminal typography",
        subtitle:
          "These settings affect Ghostty's fixed-width terminal grid and remain independent from workspace fonts."
      )

      GroupBox("Font") {
        VStack(alignment: .leading, spacing: 14) {
          HStack {
            TextField("Monospaced font family (e.g. Menlo)", text: optionalStringBinding(\.fontFamily))
              .textFieldStyle(.roundedBorder)
            Text("Family")
              .foregroundStyle(.secondary)
          }
          if typography.configuration.fontFamily != nil && !isValidTerminalFontFamily {
            Text("Choose an installed fixed-width font. Proportional or unavailable fonts are ignored.")
              .font(.system(size: 11))
              .foregroundStyle(.orange)
          }
          optionalSlider(
            "Font size", keyPath: \.fontSize, fallback: 13, range: 8...36, suffix: " pt")
        }
        .padding(.top, 6)
      }

      GroupBox("Cell metrics") {
        VStack(alignment: .leading, spacing: 14) {
          optionalSlider(
            "Character spacing", keyPath: \.characterSpacingPercent, fallback: 0, range: -20...40,
            suffix: "%")
          optionalSlider(
            "Line spacing", keyPath: \.lineSpacingPercent, fallback: 0, range: -20...60, suffix: "%"
          )
          Text(
            "Ghostty applies these with adjust-cell-width and adjust-cell-height. Cell width stays fixed for terminal applications; use small adjustments for best alignment."
          )
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
      }

      GroupBox("Terminal padding") {
        VStack(alignment: .leading, spacing: 14) {
          optionalSlider(
            "Horizontal", keyPath: \.horizontalPadding, fallback: 2, range: 0...40, suffix: " pt",
            step: 1)
          optionalSlider(
            "Vertical", keyPath: \.verticalPadding, fallback: 2, range: 0...40, suffix: " pt",
            step: 1)
        }
        .padding(.top, 6)
      }

      GroupBox("Preview") {
        VStack(alignment: .leading, spacing: 5) {
          Text("$ claude")
            .foregroundStyle(Color(nsColor: store.configuration.selectedBorderColor.nsColor))
          Text("How can I help you today?")
          Text("› Inspect the workspace files")
            .foregroundStyle(.secondary)
        }
        .font(
          .custom(
            terminalPreviewFontFamily,
            fixedSize: typography.configuration.fontSize ?? 13
          )
        )
        .tracking(
          (typography.configuration.characterSpacingPercent ?? 0)
            * (typography.configuration.fontSize ?? 13) / 100
        )
        .lineSpacing(
          (typography.configuration.lineSpacingPercent ?? 0)
            * (typography.configuration.fontSize ?? 13) / 100
        )
        .padding(.horizontal, (typography.configuration.horizontalPadding ?? 12).rounded())
        .padding(.vertical, (typography.configuration.verticalPadding ?? 10).rounded())
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(Color(nsColor: .textColor))
      }
      resetButton
    }
  }

  private var terminalPreviewFontFamily: String {
    guard let family = typography.configuration.fontFamily,
      !family.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return "Menlo"
    }
    return family
  }

  private var isValidTerminalFontFamily: Bool {
    guard let family = typography.configuration.fontFamily else { return true }
    return NSFont(name: family, size: 13)?.isFixedPitch == true
  }

  private var tabsSection: some View {
    VStack(alignment: .leading, spacing: 18) {
      sectionHeader(
        "Tabs",
        subtitle:
          "Customize the optional MiTerm strip. Native macOS tabs remain available as a fallback.")
      Picker(
        "Tab display",
        selection: Binding(
          get: { store.tabPresentation },
          set: { store.setTabPresentation($0) }
        )
      ) {
        ForEach(WorkspaceTabPresentation.allCases) { presentation in
          Text(presentation.title).tag(presentation)
        }
      }
      .pickerStyle(.segmented)

      HStack(alignment: .top, spacing: 28) {
        VStack(alignment: .leading, spacing: 14) {
          Text("Tab colors").font(.headline)
          colorPicker("Background", keyPath: \.tabBackground)
          colorPicker("Foreground", keyPath: \.tabForeground)
          colorPicker("Selected background", keyPath: \.selectedTabBackground)
          colorPicker("Selected foreground", keyPath: \.selectedTabForeground)
          colorPicker("Border", keyPath: \.borderColor)
          colorPicker("Selected border", keyPath: \.selectedBorderColor)
        }
        .frame(width: 285, alignment: .leading)

        VStack(alignment: .leading, spacing: 14) {
          Text("Tab type and spacing").font(.headline)
          Picker(
            "Font",
            selection: Binding(
              get: { store.configuration.font },
              set: { font in store.update { $0.font = font } }
            )
          ) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      preview
      resetButton
    }
  }

  private var layoutSection: some View {
    VStack(alignment: .leading, spacing: 18) {
      sectionHeader(
        "Layout",
        subtitle:
          "Split actions target the focused terminal surface. Ghostty continues to own pane layout, focus, resizing, and restoration."
      )
      Toggle(
        "Show session sidebar",
        isOn: Binding(
          get: { store.sidebarVisible },
          set: { store.setSidebarVisible($0) }
        ))
      GroupBox("Split the focused terminal") {
        HStack(spacing: 12) {
          workspaceAction("Split right", symbol: "rectangle.split.2x1") { controller in
            controller.splitRight(NSApp.keyWindow as Any)
          }
          workspaceAction("Split down", symbol: "rectangle.split.1x2") { controller in
            controller.splitDown(NSApp.keyWindow as Any)
          }
          workspaceAction("Equalize panes", symbol: "rectangle.split.2x2") { controller in
            controller.equalizeSplits(NSApp.keyWindow as Any)
          }
        }
        .padding(.top, 8)
      }
      Text(
        "Reordering and cross-group movement use AppKit's native tab controls. The MiTerm strip currently switches tabs only; it does not simulate a drag reorder because NSWindowTabGroup does not expose a safe custom reorder API."
      )
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var iconsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      sectionHeader(
        "Session icons",
        subtitle:
          "Choose a workspace icon for each open session. Icon choices are saved between launches.")
      if sessions.sessions.isEmpty {
        Text("Open a terminal window or tab to customize its icon.")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      } else {
        ForEach(sessions.sessions) { session in
          HStack {
            Image(systemName: sessionIcons.icon(for: session))
              .frame(width: 24)
            Text(session.title).lineLimit(1)
            Spacer()
            Menu {
              ForEach(Self.sessionIconChoices, id: \.self) { symbol in
                Button {
                  sessionIcons.setIcon(symbol, for: session)
                } label: {
                  Label(
                    symbol.replacingOccurrences(of: ".", with: " ").capitalized, systemImage: symbol
                  )
                }
              }
            } label: {
              Label("Choose icon", systemImage: "chevron.up.chevron.down")
            }
            .menuStyle(.borderlessButton)
          }
          .padding(10)
          .background(
            Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
        Text("Icons are associated with current window titles; duplicate titles share an icon.")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
    }
    .onAppear { sessions.refresh() }
  }

  private var widgetsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      sectionHeader(
        "Session widgets",
        subtitle:
          "Workspace Overview currently shows one movable session widget for every live Ghostty terminal window or tab."
      )
      Label("Drag a session card to reorder the overview", systemImage: "hand.draw")
      Label("Click a card to focus that session", systemImage: "macwindow")
      Label("Cards use your selected workspace theme", systemImage: "paintpalette")
      Text(
        "Widget order lasts while this overview window remains open. Additional widget types can be added here later without changing Ghostty's terminal ownership."
      )
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      Button("Open Workspace Overview") {
        (NSApp.delegate as? AppDelegate)?.showWorkspaceOverview(nil)
      }
      .buttonStyle(.borderedProminent)
    }
    .font(.system(size: 13))
  }

  private var preview: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Live tab preview").font(.headline)
      WorkspaceTabStripView(
        items: WorkspaceTabStripView.sampleItems(),
        configuration: store.configuration
      )
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(Color(nsColor: .separatorColor))
      }
    }
  }

  private var resetButton: some View {
    HStack {
      Spacer()
      Button("Reset to defaults") {
        if selectedSection == .terminal {
          typography.reset()
        } else {
          store.resetCustomizations()
        }
      }
    }
  }

  private func sectionHeader(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.system(size: 23, weight: .semibold))
      Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
    }
  }

  private func workspaceAction(
    _ title: String,
    symbol: String,
    action: @escaping (BaseTerminalController) -> Void
  ) -> some View {
    Button {
      guard let controller = NSApp.keyWindow?.windowController as? BaseTerminalController else {
        NSSound.beep()
        return
      }
      action(controller)
    } label: {
      Label(title, systemImage: symbol)
    }
    .buttonStyle(.bordered)
  }

  private func colorPicker(
    _ title: String,
    keyPath: WritableKeyPath<WorkspaceThemeConfiguration, WorkspaceColor>
  ) -> some View {
    ColorPicker(
      title,
      selection: Binding(
        get: { store.configuration[keyPath: keyPath].color },
        set: { color in store.update { $0[keyPath: keyPath] = WorkspaceColor(color: color) } }
      ), supportsOpacity: false
    )
    .font(.system(size: 12))
  }

  private func slider(
    _ title: String,
    keyPath: WritableKeyPath<WorkspaceThemeConfiguration, Double>,
    range: ClosedRange<Double>,
    suffix: String
  ) -> some View {
    settingSlider(title, value: store.configuration[keyPath: keyPath], range: range, suffix: suffix)
    { value in
      store.update { $0[keyPath: keyPath] = value }
    }
  }

  private func optionalSlider(
    _ title: String,
    keyPath: WritableKeyPath<TerminalTypographyConfiguration, Double?>,
    fallback: Double,
    range: ClosedRange<Double>,
    suffix: String,
    step: Double? = nil
  ) -> some View {
    settingSlider(
      title,
      value: typography.configuration[keyPath: keyPath] ?? fallback,
      range: range,
      suffix: suffix,
      step: step
    ) { value in
      typography.update { $0[keyPath: keyPath] = value }
    }
  }

  private func settingSlider(
    _ title: String,
    value: Double,
    range: ClosedRange<Double>,
    suffix: String,
    step: Double? = nil,
    set: @escaping (Double) -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(title)
        Spacer()
        Text("\(value, specifier: "%.0f")\(suffix)")
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      .font(.system(size: 12))
      if let step {
        Slider(value: Binding(get: { value }, set: set), in: range, step: step)
      } else {
        Slider(value: Binding(get: { value }, set: set), in: range)
      }
    }
  }

  private func optionalStringBinding(
    _ keyPath: WritableKeyPath<TerminalTypographyConfiguration, String?>
  ) -> Binding<String> {
    Binding(
      get: { typography.configuration[keyPath: keyPath] ?? "" },
      set: { value in
        typography.update { $0[keyPath: keyPath] = value.isEmpty ? nil : value }
      }
    )
  }

  private static let sessionIconChoices = [
    "terminal", "chevron.left.forwardslash.chevron.right", "folder", "hammer", "shippingbox",
    "sparkles",
  ]
}

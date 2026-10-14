import AppKit
import SwiftUI

private enum WorkspaceEditorSection: String, CaseIterable, Identifiable {
  case appearance = "Appearance"
  case colors = "Terminal Colors"
  case terminal = "Terminal"
  case tabs = "Tabs"
  case layout = "Layout"
  case widgets = "Widgets"
  case icons = "Icons"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .appearance: "paintpalette"
    case .colors: "paintpalette.fill"
    case .terminal: "terminal"
    case .tabs: "rectangle.topthird.inset.filled"
    case .layout: "rectangle.split.2x1"
    case .widgets: "square.grid.2x2"
    case .icons: "app.dashed"
    }
  }
}

private struct WorkspaceColorPickerRow: View {
  let title: String
  @Binding var color: WorkspaceColor

  @State private var hexText: String
  @State private var isInvalid = false
  @FocusState private var isHexFieldFocused: Bool

  init(_ title: String, color: Binding<WorkspaceColor>) {
    self.title = title
    self._color = color
    self._hexText = State(initialValue: "#\(color.wrappedValue.hexString.uppercased())")
  }

  var body: some View {
    HStack(spacing: 10) {
      ColorPicker(
        title,
        selection: Binding(
          get: { color.color },
          set: { color = WorkspaceColor(color: $0) }
        ),
        supportsOpacity: false
      )
      .font(.system(size: 12))

      TextField("#RRGGBB", text: $hexText)
        .font(.system(size: 11, design: .monospaced))
        .textFieldStyle(.roundedBorder)
        .frame(width: 92)
        .focused($isHexFieldFocused)
        .accessibilityLabel("\(title) hex color")
        .help(isInvalid ? "Enter six hexadecimal digits, such as #AABBCC." : "Enter a hex color, such as #AABBCC.")
        .onChange(of: hexText) { newValue in
          isInvalid = false
          guard let hex = Self.parseHex(newValue) else { return }
          color = WorkspaceColor(hex: hex)
        }
        .onChange(of: color) { newColor in
          guard !isHexFieldFocused else { return }
          hexText = "#\(newColor.hexString.uppercased())"
          isInvalid = false
        }
        .onChange(of: isHexFieldFocused) { isFocused in
          if !isFocused { commitHex() }
        }
        .onSubmit(commitHex)

      if isInvalid {
        Image(systemName: "exclamationmark.circle.fill")
          .foregroundStyle(.red)
          .help("Enter six hexadecimal digits, such as #AABBCC.")
      }
    }
  }

  private func commitHex() {
    guard let hex = Self.parseHex(hexText) else {
      isInvalid = true
      return
    }
    color = WorkspaceColor(hex: hex)
    hexText = "#\(color.hexString.uppercased())"
    isInvalid = false
  }

  private static func parseHex(_ text: String) -> UInt32? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
    guard digits.count == 6,
          digits.unicodeScalars.allSatisfy({
            CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0)
          }) else { return nil }
    return UInt32(digits, radix: 16)
  }
}

struct WorkspaceCustomizationView: View {
  @ObservedObject private var store = WorkspaceCustomizationStore.shared
  @ObservedObject private var typography = TerminalTypographyStore.shared
  @ObservedObject private var sessions = WorkspaceSessionStore.shared
  @ObservedObject private var sessionIcons = WorkspaceSessionIconStore.shared
  @ObservedObject private var terminalColorThemes = TerminalColorThemeStore.shared
  @State private var selectedSection: WorkspaceEditorSection? = .appearance
  @State private var terminalColorDraft = TerminalColorTheme.gruvboxMaterialDarkMedium
  @State private var terminalColorDraftID: String?
  @State private var newWorkspaceThemeName = ""
  @State private var emojiPickerSessionID: ObjectIdentifier?

  var body: some View {
    NavigationSplitView {
      List(WorkspaceEditorSection.allCases, selection: $selectedSection) { section in
        Label(section.rawValue, systemImage: section.symbol)
          .tag(section)
      }
      .navigationTitle("Customize Appearance")
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
    case .colors:
      terminalColorsSection
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
        subtitle: "Choose a appearance theme. Terminal grid styling is configured separately.")
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
                    store.activeProfileID == WorkspaceThemeProfile.presetID(for: theme)
                      ? Color.accentColor
                      : Color(nsColor: .separatorColor),
                    lineWidth: store.activeProfileID == WorkspaceThemeProfile.presetID(for: theme) ? 2 : 1
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

      HStack(spacing: 10) {
        TextField("Name an appearance theme", text: $newWorkspaceThemeName)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 300)
        Button("Save Current as Theme") {
          store.saveCurrentProfile(named: newWorkspaceThemeName)
          newWorkspaceThemeName = ""
        }
        .buttonStyle(.borderedProminent)
        .disabled(newWorkspaceThemeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if !store.customProfiles.isEmpty {
        GroupBox("Saved appearance themes") {
          VStack(spacing: 8) {
            ForEach(store.customProfiles) { profile in
              HStack {
                Image(systemName: store.activeProfileID == profile.id ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(store.activeProfileID == profile.id ? Color.accentColor : Color.secondary)
                TextField(
                  "Theme name",
                  text: Binding(
                    get: { profile.name },
                    set: { store.renameProfile(profile.id, to: $0) }
                  )
                )
                .textFieldStyle(.plain)
                .frame(maxWidth: 220, alignment: .leading)
                Spacer()
                if store.activeProfileID != profile.id {
                  Button("Use") { store.selectProfile(profile.id) }
                    .buttonStyle(.bordered)
                } else {
                  Text("Editing")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                  store.deleteProfile(profile.id)
                } label: {
                  Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete \(profile.name)")
              }
              .padding(.vertical, 3)
            }
          }
          .padding(.top, 5)
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
          "These settings affect Ghostty's fixed-width terminal grid and remain independent from appearance fonts."
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

  private var terminalColorsSection: some View {
    VStack(alignment: .leading, spacing: 18) {
      sectionHeader(
        "Terminal color themes",
        subtitle:
          "Choose a saved Ghostty terminal palette or create your own. These colors are separate from tab and appearance styling."
      )

      HStack(spacing: 12) {
        Picker(
          "Active colors",
          selection: Binding(
            get: { terminalColorThemes.activeThemeID },
            set: { selectTerminalColorTheme($0) }
          )
        ) {
          Text("Use appearance theme").tag(TerminalColorTheme.workspaceDefaultID)
          ForEach(terminalColorThemes.availableThemes) { theme in
            Text(theme.name).tag(theme.id)
          }
        }
        .frame(maxWidth: 360)

        Button("New theme") { beginNewTerminalColorTheme() }
        Button("Save theme") { saveTerminalColorDraft() }
          .buttonStyle(.borderedProminent)
        if let id = terminalColorDraftID {
          Button("Delete") {
            terminalColorThemes.delete(id)
            terminalColorDraftID = nil
            terminalColorDraft = .gruvboxMaterialDarkMedium
          }
          .disabled(!terminalColorThemes.customThemes.contains(where: { $0.id == id }))
        }
      }

      TextField("Theme name", text: $terminalColorDraft.name)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 360)

      HStack(alignment: .top, spacing: 24) {
        VStack(alignment: .leading, spacing: 12) {
          GroupBox("Base colors") {
            VStack(alignment: .leading, spacing: 8) {
              terminalColorPicker("Background", keyPath: \.background)
              terminalColorPicker("Foreground", keyPath: \.foreground)
              terminalColorPicker("Cursor", keyPath: \.cursor)
              terminalColorPicker("Selection background", keyPath: \.selectionBackground)
              terminalColorPicker("Selection foreground", keyPath: \.selectionForeground)
            }
            .padding(.top, 4)
          }

          GroupBox("ANSI palette") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) {
              ForEach(0..<16, id: \.self) { index in
                paletteColorPicker(index)
              }
            }
            .padding(.top, 4)
          }
        }
        .frame(maxWidth: 440, alignment: .leading)

        terminalColorPreview
          .frame(maxWidth: .infinity, alignment: .topLeading)
      }

      Text("Color edits preview immediately in open terminals. Save Theme stores the profile for future launches.")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
    .onAppear {
      loadTerminalColorDraft(terminalColorThemes.activeThemeID)
      if terminalColorThemes.activeThemeID != TerminalColorTheme.workspaceDefaultID {
        terminalColorThemes.preview(terminalColorDraft)
      }
    }
    .onDisappear { terminalColorThemes.restoreActiveTheme() }
  }

  private var terminalColorPreview: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Live terminal preview").font(.headline)
      VStack(alignment: .leading, spacing: 9) {
        Text("~/miterm  ❯  claude")
          .foregroundStyle(terminalColorDraft.palette[2].color)
        Text("Ready when you are.")
          .foregroundStyle(terminalColorDraft.foreground.color)
        Text("let workspace = \"MiTerm\"")
          .foregroundStyle(terminalColorDraft.palette[4].color)
        Text("✓  theme loaded")
          .foregroundStyle(terminalColorDraft.palette[10].color)
        HStack(spacing: 5) {
          ForEach(0..<16, id: \.self) { index in
            RoundedRectangle(cornerRadius: 2)
              .fill(terminalColorDraft.palette[index].color)
              .frame(height: 15)
          }
        }
        Rectangle()
          .fill(terminalColorDraft.cursor.color)
          .frame(width: 9, height: 18)
      }
      .font(.system(size: 13, design: .monospaced))
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(terminalColorDraft.background.color, in: RoundedRectangle(cornerRadius: 10))
      .foregroundStyle(terminalColorDraft.foreground.color)
    }
  }

  private func selectTerminalColorTheme(_ id: String) {
    terminalColorThemes.select(id)
    loadTerminalColorDraft(id)
    if id != TerminalColorTheme.workspaceDefaultID {
      terminalColorThemes.preview(terminalColorDraft)
    }
  }

  private func loadTerminalColorDraft(_ id: String) {
    guard let theme = terminalColorThemes.availableThemes.first(where: { $0.id == id }) else {
      terminalColorDraft = .gruvboxMaterialDarkMedium
      terminalColorDraft.name = "My Terminal Theme"
      terminalColorDraftID = nil
      return
    }
    terminalColorDraft = theme
    terminalColorDraftID = terminalColorThemes.customThemes.contains(where: { $0.id == id }) ? id : nil
  }

  private func beginNewTerminalColorTheme() {
    var theme = terminalColorDraft
    theme.id = UUID().uuidString
    theme.name = "My Terminal Theme"
    terminalColorDraft = theme
    terminalColorDraftID = nil
    terminalColorThemes.preview(theme)
  }

  private func saveTerminalColorDraft() {
    terminalColorDraftID = terminalColorThemes.save(
      terminalColorDraft,
      replacingID: terminalColorDraftID
    )
    terminalColorDraft.id = terminalColorDraftID ?? terminalColorDraft.id
  }

  private func terminalColorPicker(
    _ title: String,
    keyPath: WritableKeyPath<TerminalColorTheme, WorkspaceColor>
  ) -> some View {
    WorkspaceColorPickerRow(
      title,
      color: Binding(
        get: { terminalColorDraft[keyPath: keyPath] },
        set: { color in
          terminalColorDraft[keyPath: keyPath] = color
          terminalColorThemes.preview(terminalColorDraft)
        }
      )
    )
  }

  private func paletteColorPicker(_ index: Int) -> some View {
    WorkspaceColorPickerRow(
      Self.terminalPaletteLabels[index],
      color: Binding(
        get: { terminalColorDraft.palette[index] },
        set: { color in
          terminalColorDraft.palette[index] = color
          terminalColorThemes.preview(terminalColorDraft)
        }
      )
    )
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
          "Choose where session switching appears. Sidebar only hides both tab bars while keeping Ghostty's native tab groups for restoration.")
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
        .disabled(store.tabPresentation == .sidebarOnly)
      if store.tabPresentation == .sidebarOnly {
        Text("The sidebar stays visible while Sidebar only is selected so you can switch sessions.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
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
        "Native tabs remain available as a presentation option. The MiTerm strip switches tabs but does not simulate drag reordering; Ghostty continues to manage the underlying AppKit tab groups."
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
          "Choose a session icon for each terminal tab. Choices are saved between launches.")
      if sessions.sessions.isEmpty {
        Text("Open a terminal window or tab to customize its icon.")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      } else {
        ForEach(sessions.sessions) { session in
          HStack {
            WorkspaceSessionIconView(icon: sessionIcons.icon(for: session), size: 17)
            Text(session.title).lineLimit(1)
            Spacer()
            Menu {
              Section("System icons") {
                ForEach(Self.sessionIconChoices, id: \.self) { symbol in
                  Button {
                    sessionIcons.setIcon(symbol, for: session)
                  } label: {
                    Label(
                      symbol.replacingOccurrences(of: ".", with: " ").capitalized,
                      systemImage: symbol
                    )
                  }
                }
              }
            } label: {
              Label("System icon", systemImage: "chevron.up.chevron.down")
            }
            .menuStyle(.borderlessButton)
            Button("Emoji…") { emojiPickerSessionID = session.id }
              .buttonStyle(.borderless)
              .popover(
                isPresented: Binding(
                  get: { emojiPickerSessionID == session.id },
                  set: { if !$0 { emojiPickerSessionID = nil } }
                )
              ) {
                WorkspaceSessionEmojiPickerContent(session: session)
              }
          }
          .padding(10)
          .background(
            Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
        Text("Each terminal tab has its own saved icon. Open Emoji & Symbols to choose from the full macOS emoji set.")
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
          "Session Overview currently shows one movable session widget for every live Ghostty terminal window or tab."
      )
      Label("Drag a session card to reorder the overview", systemImage: "hand.draw")
      Label("Click a card to focus that session", systemImage: "macwindow")
      Label("Cards use your selected appearance theme", systemImage: "paintpalette")
      Text(
        "Widget order lasts while this overview window remains open. Additional widget types can be added here later without changing Ghostty's terminal ownership."
      )
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      Button("Open Session Overview") {
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
    WorkspaceColorPickerRow(
      title,
      color: Binding(
        get: { store.configuration[keyPath: keyPath] },
        set: { color in store.update { $0[keyPath: keyPath] = color } }
      )
    )
  }

  private func slider(
    _ title: String,
    keyPath: WritableKeyPath<WorkspaceThemeConfiguration, Double>,
    range: ClosedRange<Double>,
    suffix: String
  ) -> some View {
    settingSlider(title, value: store.configuration[keyPath: keyPath], range: range, suffix: suffix) { value in
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

  private static let terminalPaletteLabels = [
    "Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White",
    "Bright black", "Bright red", "Bright green", "Bright yellow", "Bright blue",
    "Bright magenta", "Bright cyan", "Bright white",
  ]
}

import AppKit
import SwiftUI

/// Terminal-grid typography settings. These remain independent from workspace chrome tokens.
struct TerminalTypographyConfiguration: Codable, Equatable {
    var fontFamily: String?
    var fontSize: Double?
    var characterSpacingPercent: Double?
    var lineSpacingPercent: Double?
    var horizontalPadding: Double?
    var verticalPadding: Double?

    static let defaultsKey = "TerminalTypographyConfiguration"

    static let defaults = Self(
        fontFamily: nil,
        fontSize: nil,
        characterSpacingPercent: nil,
        lineSpacingPercent: nil,
        horizontalPadding: nil,
        verticalPadding: nil
    )

    static var current: Self {
        guard let data = UserDefaults.ghostty.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            return .defaults
        }
        return decoded
    }

    var configOverlay: String? {
        var lines: [String] = []
        if let fontFamily,
           !fontFamily.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           NSFont(name: fontFamily, size: 13)?.isFixedPitch == true {
            let escaped = fontFamily.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            lines.append("font-family = \"\(escaped)\"")
        }
        if let fontSize { lines.append("font-size = \(fontSize)") }
        if let characterSpacingPercent {
            lines.append("adjust-cell-width = \(characterSpacingPercent)%")
        }
        if let lineSpacingPercent { lines.append("adjust-cell-height = \(lineSpacingPercent)%") }
        if let horizontalPadding { lines.append("window-padding-x = \(Int(horizontalPadding.rounded()))") }
        if let verticalPadding { lines.append("window-padding-y = \(Int(verticalPadding.rounded()))") }
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n") + "\n"
    }
}

@MainActor
final class TerminalTypographyStore: ObservableObject {
    static let shared = TerminalTypographyStore()

    @Published private(set) var configuration: TerminalTypographyConfiguration {
        didSet { saveAndApply() }
    }

    private init() {
        configuration = .current
    }

    func update(_ mutation: (inout TerminalTypographyConfiguration) -> Void) {
        var updated = configuration
        mutation(&updated)
        configuration = updated
    }

    func reset() {
        configuration = .defaults
    }

    private func saveAndApply() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.ghostty.set(data, forKey: TerminalTypographyConfiguration.defaultsKey)
        (NSApp.delegate as? AppDelegate)?.ghostty.setTerminalTypography(configuration)
    }
}

enum WorkspaceTabPresentation: String, CaseIterable, Identifiable, Hashable {
    case native
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .native: "Native tabs"
        case .custom: "MiTerm strip"
        }
    }
}

enum WorkspaceThemeFont: String, CaseIterable, Codable, Identifiable, Hashable {
    case system
    case serif
    case monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .serif: "Serif"
        case .monospaced: "Monospaced"
        }
    }

    func font(size: Double) -> Font {
        switch self {
        case .system: .system(size: size, weight: .medium)
        case .serif: .system(size: size, weight: .medium, design: .serif)
        case .monospaced: .system(size: size, weight: .medium, design: .monospaced)
        }
    }
}

struct WorkspaceColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }

    init(color: Color) {
        let color = NSColor(color).usingColorSpace(.deviceRGB) ?? .labelColor
        self.init(
            red: color.redComponent,
            green: color.greenComponent,
            blue: color.blueComponent,
            alpha: color.alphaComponent
        )
    }

    var nsColor: NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    var color: Color { Color(nsColor: nsColor) }

    var hexString: String {
        let color = nsColor.usingColorSpace(.deviceRGB) ?? .black
        return String(
            format: "%02x%02x%02x",
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
    }
}

/// Terminal grid colors and ANSI palette, separate from workspace chrome styling.
struct TerminalColorTheme: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var background: WorkspaceColor
    var foreground: WorkspaceColor
    var cursor: WorkspaceColor
    var selectionBackground: WorkspaceColor
    var selectionForeground: WorkspaceColor
    var palette: [WorkspaceColor]

    static let gruvboxMaterialID = "gruvbox-material-dark-medium"
    static let workspaceDefaultID = "workspace-default"

    /// Colors are based on the Gruvbox Material VS Code theme's Dark Medium Material variant.
    /// Source: https://github.com/sainnhe/gruvbox-material-vscode (MIT licensed).
    static let gruvboxMaterialDarkMedium = TerminalColorTheme(
        id: gruvboxMaterialID,
        name: "Gruvbox Material Dark Medium",
        background: WorkspaceColor(hex: 0x292828),
        foreground: WorkspaceColor(hex: 0xd4be98),
        cursor: WorkspaceColor(hex: 0xd4be98),
        selectionBackground: WorkspaceColor(hex: 0x504945),
        selectionForeground: WorkspaceColor(hex: 0xd4be98),
        palette: [
            0x32302f, 0xea6962, 0xa9b665, 0xd8a657,
            0x7daea3, 0xd3869b, 0x89b482, 0xd4be98,
            0x928374, 0xea6962, 0xa9b665, 0xd8a657,
            0x7daea3, 0xd3869b, 0x89b482, 0xddc7a1,
        ].map(WorkspaceColor.init(hex:))
    )

    var configOverlay: String {
        let primary = [
            "background = #\(background.hexString)",
            "foreground = #\(foreground.hexString)",
            "cursor-color = #\(cursor.hexString)",
            "selection-background = #\(selectionBackground.hexString)",
            "selection-foreground = #\(selectionForeground.hexString)",
        ]
        let colors = palette.enumerated().map { "palette = \($0.offset)=#\($0.element.hexString)" }
        return (primary + colors).joined(separator: "\n") + "\n"
    }

    static var active: TerminalColorTheme? {
        let defaults = UserDefaults.ghostty
        guard let id = defaults.string(forKey: TerminalColorThemeStore.activeThemeKey),
              id != workspaceDefaultID else { return nil }
        if id == gruvboxMaterialID { return gruvboxMaterialDarkMedium }
        guard let data = defaults.data(forKey: TerminalColorThemeStore.customThemesKey),
              let themes = try? JSONDecoder().decode([TerminalColorTheme].self, from: data) else {
            return nil
        }
        return themes.first { $0.id == id }
    }
}

@MainActor
final class TerminalColorThemeStore: ObservableObject {
    static let shared = TerminalColorThemeStore()
    nonisolated static let activeThemeKey = "TerminalColorTheme.Active"
    nonisolated static let customThemesKey = "TerminalColorTheme.Custom"

    @Published private(set) var customThemes: [TerminalColorTheme]
    @Published private(set) var activeThemeID: String
    @Published private(set) var previewTheme: TerminalColorTheme?

    var availableThemes: [TerminalColorTheme] {
        [.gruvboxMaterialDarkMedium] + customThemes
    }

    private init() {
        let defaults = UserDefaults.ghostty
        if let data = defaults.data(forKey: Self.customThemesKey),
           let decoded = try? JSONDecoder().decode([TerminalColorTheme].self, from: data) {
            customThemes = decoded
        } else {
            customThemes = []
        }
        activeThemeID = defaults.string(forKey: Self.activeThemeKey)
            ?? TerminalColorTheme.workspaceDefaultID
    }

    func select(_ id: String) {
        activeThemeID = id
        UserDefaults.ghostty.set(id, forKey: Self.activeThemeKey)
        previewTheme = nil
        applyActiveTheme()
    }

    func save(_ theme: TerminalColorTheme, replacingID: String? = nil) -> String {
        var savedTheme = theme
        let protectedIDs = [TerminalColorTheme.workspaceDefaultID, TerminalColorTheme.gruvboxMaterialID]
        if protectedIDs.contains(savedTheme.id) {
            savedTheme.id = UUID().uuidString
        }

        if let replacingID,
           let index = customThemes.firstIndex(where: { $0.id == replacingID }) {
            savedTheme.id = replacingID
            customThemes[index] = savedTheme
        } else {
            savedTheme.id = UUID().uuidString
            customThemes.append(savedTheme)
        }
        persistCustomThemes()
        select(savedTheme.id)
        return savedTheme.id
    }

    func delete(_ id: String) {
        customThemes.removeAll { $0.id == id }
        persistCustomThemes()
        if activeThemeID == id { select(TerminalColorTheme.workspaceDefaultID) }
    }

    func preview(_ theme: TerminalColorTheme) {
        previewTheme = theme
        (NSApp.delegate as? AppDelegate)?.ghostty.setTerminalColorTheme(theme)
    }

    func restoreActiveTheme() {
        guard previewTheme != nil else { return }
        previewTheme = nil
        applyActiveTheme()
    }

    private func applyActiveTheme() {
        (NSApp.delegate as? AppDelegate)?.ghostty.setTerminalColorTheme(TerminalColorTheme.active)
    }

    private func persistCustomThemes() {
        guard let data = try? JSONEncoder().encode(customThemes) else { return }
        UserDefaults.ghostty.set(data, forKey: Self.customThemesKey)
    }
}

/// Workspace-only appearance values. Terminal grid colors and font remain Ghostty config.
struct WorkspaceThemeConfiguration: Codable, Equatable {
    var baseTheme: WorkspaceTabTheme
    var tabBackground: WorkspaceColor
    var tabForeground: WorkspaceColor
    var selectedTabBackground: WorkspaceColor
    var selectedTabForeground: WorkspaceColor
    var borderColor: WorkspaceColor
    var selectedBorderColor: WorkspaceColor
    var font: WorkspaceThemeFont
    var fontSize: Double
    var spacing: Double
    var horizontalPadding: Double
    var verticalPadding: Double
    var cornerRadius: Double

    static func defaults(for theme: WorkspaceTabTheme) -> Self {
        switch theme {
        case .minimal:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0x292d34),
                tabForeground: .init(hex: 0xd8dce4),
                selectedTabBackground: .init(hex: 0x3b424c),
                selectedTabForeground: .init(hex: 0xffffff),
                borderColor: .init(hex: 0x454c56),
                selectedBorderColor: .init(hex: 0x6caaf2),
                font: .system,
                fontSize: 13,
                spacing: 6,
                horizontalPadding: 12,
                verticalPadding: 8,
                cornerRadius: 8
            )
        case .newspaper:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0xe9e0cd),
                tabForeground: .init(hex: 0x4a3c2d),
                selectedTabBackground: .init(hex: 0xf7f1e5),
                selectedTabForeground: .init(hex: 0x2f291f),
                borderColor: .init(hex: 0xc8b99d),
                selectedBorderColor: .init(hex: 0xa95d45),
                font: .serif,
                fontSize: 13,
                spacing: 7,
                horizontalPadding: 13,
                verticalPadding: 8,
                cornerRadius: 4
            )
        case .pixel:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0x182119),
                tabForeground: .init(hex: 0xb8f2a5),
                selectedTabBackground: .init(hex: 0x26392a),
                selectedTabForeground: .init(hex: 0xdfffcf),
                borderColor: .init(hex: 0x405342),
                selectedBorderColor: .init(hex: 0x8cff57),
                font: .monospaced,
                fontSize: 12,
                spacing: 4,
                horizontalPadding: 10,
                verticalPadding: 8,
                cornerRadius: 2
            )
        }
    }
}

@MainActor
final class WorkspaceCustomizationStore: ObservableObject {
    static let shared = WorkspaceCustomizationStore()
    static let configurationKey = "WorkspaceThemeConfiguration"
    static let presentationKey = "WorkspaceTabPresentation"
    static let sidebarVisibleKey = "WorkspaceSessionSidebarVisible"

    @Published private(set) var configuration: WorkspaceThemeConfiguration {
        didSet { saveConfiguration() }
    }

    @Published private(set) var tabPresentation: WorkspaceTabPresentation {
        didSet {
            UserDefaults.ghostty.set(tabPresentation.rawValue, forKey: Self.presentationKey)
            applyTabBarVisibility()
        }
    }

    @Published private(set) var sidebarVisible: Bool {
        didSet { UserDefaults.ghostty.set(sidebarVisible, forKey: Self.sidebarVisibleKey) }
    }

    private init() {
        let defaults = UserDefaults.ghostty
        let initialTheme = WorkspaceTabTheme.current
        if let data = defaults.data(forKey: Self.configurationKey),
           let decoded = try? JSONDecoder().decode(WorkspaceThemeConfiguration.self, from: data) {
            configuration = decoded
        } else {
            configuration = .defaults(for: initialTheme)
        }
        tabPresentation = defaults.string(forKey: Self.presentationKey)
            .flatMap(WorkspaceTabPresentation.init(rawValue:)) ?? .native
        sidebarVisible = defaults.object(forKey: Self.sidebarVisibleKey) as? Bool ?? false
    }

    func update(_ mutation: (inout WorkspaceThemeConfiguration) -> Void) {
        var updated = configuration
        mutation(&updated)
        configuration = updated
    }

    func selectBaseTheme(_ theme: WorkspaceTabTheme) {
        guard configuration.baseTheme != theme else { return }
        if WorkspaceTabTheme.current != theme,
           let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.ghostty.setWorkspaceTabTheme(theme)
        } else {
            UserDefaults.ghostty.set(theme.rawValue, forKey: WorkspaceTabTheme.defaultsKey)
        }
        configuration = .defaults(for: theme)
        NotificationCenter.default.post(name: .workspaceTabThemeDidChange, object: nil)
    }

    func resetCustomizations() {
        configuration = .defaults(for: configuration.baseTheme)
    }

    func setTabPresentation(_ presentation: WorkspaceTabPresentation) {
        guard presentation != tabPresentation else { return }
        tabPresentation = presentation
        WorkspaceSessionStore.shared.refresh()
    }

    func setSidebarVisible(_ visible: Bool) {
        sidebarVisible = visible
    }

    func applyTabBarVisibility() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.applyTabBarVisibility() }
            return
        }

        var handledGroups = Set<ObjectIdentifier>()
        for controller in TerminalController.all {
            guard let window = controller.window,
                  let group = window.tabGroup,
                  group.windows.count > 1,
                  handledGroups.insert(ObjectIdentifier(group)).inserted else { continue }

            let wantsNativeTabBar = tabPresentation == .native
            guard group.isTabBarVisible != wantsNativeTabBar else { continue }
            window.toggleTabBar(nil)
        }
    }

    private func saveConfiguration() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.ghostty.set(data, forKey: Self.configurationKey)
        UserDefaults.ghostty.set(configuration.baseTheme.rawValue, forKey: WorkspaceTabTheme.defaultsKey)
    }
}

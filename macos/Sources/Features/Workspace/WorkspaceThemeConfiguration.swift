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
    case sidebarOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .native: "Native tabs"
        case .custom: "MiTerm strip"
        case .sidebarOnly: "Sidebar only"
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

    func nsFont(size: CGFloat) -> NSFont {
        switch self {
        case .system:
            .systemFont(ofSize: size, weight: .medium)
        case .serif:
            NSFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size, weight: .medium)
        case .monospaced:
            NSFont(name: "Menlo", size: size) ?? .monospacedSystemFont(ofSize: size, weight: .medium)
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
    var cursorText: WorkspaceColor?
    var selectionBackground: WorkspaceColor
    var selectionForeground: WorkspaceColor
    var palette: [WorkspaceColor]

    static let gruvboxMaterialID = "gruvbox-material-dark-medium"
    static let workspaceDefaultID = "workspace-default"

    /// Cozy presets are available independently from workspace chrome. Selecting
    /// "Use appearance theme" follows the active appearance; these IDs let users
    /// pair or mix terminal colors with any workspace theme.
    static let cozyPresets: [TerminalColorTheme] = [
        TerminalColorTheme(
            id: "raspberry-cream", name: "Raspberry Cream",
            background: .init(hex: 0xfff6d8), foreground: .init(hex: 0x63233a),
            cursor: .init(hex: 0xa00046), cursorText: .init(hex: 0xfff6d8),
            selectionBackground: .init(hex: 0xe8c5cf),
            selectionForeground: .init(hex: 0x63233a),
            palette: [
                0x49343a, 0xa00046, 0x496b45, 0x986000, 0x355b8c, 0x7c458b, 0x2d6f70, 0x63233a,
                0x765d60, 0xc83268, 0x59774e, 0x9b6300, 0x51709f, 0x8e5d98, 0x3b7878, 0x7d3e50,
            ].map(WorkspaceColor.init(hex:))
        ),
        TerminalColorTheme(
            id: "cambridge-sunset", name: "Cambridge Sunset",
            background: .init(hex: 0xfbebd7), foreground: .init(hex: 0x622c30),
            cursor: .init(hex: 0xb6192b), cursorText: .init(hex: 0xfbebd7),
            selectionBackground: .init(hex: 0xe9c6ba),
            selectionForeground: .init(hex: 0x622c30),
            palette: [
                0x49383a, 0xa33037, 0x4b704e, 0x915f2a, 0x426785, 0x835878, 0x367371, 0x622c30,
                0x7b6260, 0xb44445, 0x56714e, 0x8b6130, 0x4d6e85, 0x865d78, 0x3c7370, 0x784347,
            ].map(WorkspaceColor.init(hex:))
        ),
        TerminalColorTheme(
            id: "forest-market", name: "Forest Market",
            background: .init(hex: 0x213c2a), foreground: .init(hex: 0xf7eac9),
            cursor: .init(hex: 0xffca32), cursorText: .init(hex: 0x213c2a),
            selectionBackground: .init(hex: 0x4c633d),
            selectionForeground: .init(hex: 0xfff5d9),
            palette: [
                0x909993, 0xf28078, 0xa4c66a, 0xffca32, 0x78aeda, 0xcf91bc, 0x71c4ad, 0xe8d9b7,
                0x9da7a0, 0xff9183, 0xc3e584, 0xffdf68, 0x9bc8ef, 0xe0add0, 0x91ddc4, 0xfff3d2,
            ].map(WorkspaceColor.init(hex:))
        ),
        TerminalColorTheme(
            id: "crimson-orchard", name: "Crimson Orchard",
            background: .init(hex: 0x401f29), foreground: .init(hex: 0xf8d8d3),
            cursor: .init(hex: 0xf7b6b8), cursorText: .init(hex: 0x401f29),
            selectionBackground: .init(hex: 0x6c3b49),
            selectionForeground: .init(hex: 0xfff0ec),
            palette: [
                0x909993, 0xda7379, 0x83a66a, 0xc8a839, 0x7598b9, 0xc27f95, 0x72a59a, 0xe7c8c5,
                0x9da7a0, 0xf17c7e, 0xa4c483, 0xdfc45b, 0x91b2d0, 0xd695aa, 0x8bc0b4, 0xffe7e2,
            ].map(WorkspaceColor.init(hex:))
        ),
        TerminalColorTheme(
            id: "terracotta-evening", name: "Terracotta Evening",
            background: .init(hex: 0x35271f), foreground: .init(hex: 0xf3dec0),
            cursor: .init(hex: 0xe6a25d), cursorText: .init(hex: 0x35271f),
            selectionBackground: .init(hex: 0x604634),
            selectionForeground: .init(hex: 0xfff0d9),
            palette: [
                0x909993, 0xd57a64, 0x8da15b, 0xd89b43, 0x7698a4, 0xba867e, 0x74a08c, 0xe1c8a6,
                0x9da7a0, 0xec8264, 0xa8b970, 0xefb65e, 0x8fb1bb, 0xcd938a, 0x91baa5, 0xfff0d9,
            ].map(WorkspaceColor.init(hex:))
        ),
        TerminalColorTheme(
            id: "retro-pop", name: "Retro Pop",
            background: .init(hex: 0xfff1bf), foreground: .init(hex: 0x472d48),
            cursor: .init(hex: 0x5e65b3), cursorText: .init(hex: 0xffffff),
            selectionBackground: .init(hex: 0xd9d8fa),
            selectionForeground: .init(hex: 0x472d48),
            palette: [
                0x443445, 0xc43a3d, 0x4f7648, 0x896700, 0x525baf, 0x914d86, 0x287478, 0x472d48,
                0x746171, 0xbb4440, 0x517543, 0x85690d, 0x5e65b3, 0x935988, 0x2f7777, 0x67425f,
            ].map(WorkspaceColor.init(hex:))
        ),
    ]

    /// Extra terminal palettes designed to pair with a different workspace
    /// appearance, adding contrast and color without changing the chrome theme.
    static let pairingPresets: [TerminalColorTheme] = [
        TerminalColorTheme(
            id: "midnight-garden", name: "Midnight Garden",
            background: .init(hex: 0x241d2c), foreground: .init(hex: 0xf5eadb),
            cursor: .init(hex: 0xf39b08), cursorText: .init(hex: 0x241d2c),
            selectionBackground: .init(hex: 0x514158), selectionForeground: .init(hex: 0xfff6e7),
            palette: [
                0x554958, 0xe36a82, 0x89a86b, 0xe9b44c, 0x729ab8, 0xb18ac4, 0x62aaa1, 0xe8d8c4,
                0x807284, 0xf0788e, 0xa8c77e, 0xf3c66a, 0x91b5d0, 0xc7a2d6, 0x7bc5b5, 0xfff2df,
            ].map(WorkspaceColor.init(hex:))
        ),
        TerminalColorTheme(
            id: "poolside", name: "Poolside",
            background: .init(hex: 0x20283a), foreground: .init(hex: 0xf8ead8),
            cursor: .init(hex: 0x4cc9c0), cursorText: .init(hex: 0x20283a),
            selectionBackground: .init(hex: 0x3c5268), selectionForeground: .init(hex: 0xfff4e7),
            palette: [
                0x47505e, 0xf07868, 0x83b879, 0xe9bd55, 0x67b3d2, 0xc08ab0, 0x4cc9c0, 0xe5d9c9,
                0x707b8b, 0xff9480, 0xa1d28d, 0xf7d16b, 0x7bc7df, 0xd098bf, 0x78ded1, 0xfff2df,
            ].map(WorkspaceColor.init(hex:))
        ),
        TerminalColorTheme(
            id: "berry-soda", name: "Berry Soda",
            background: .init(hex: 0x292033), foreground: .init(hex: 0xf7e8dc),
            cursor: .init(hex: 0xffca32), cursorText: .init(hex: 0x292033),
            selectionBackground: .init(hex: 0x55405e), selectionForeground: .init(hex: 0xfff2e8),
            palette: [
                0x51495b, 0xf06b83, 0x9bc477, 0xf0bd4e, 0x6da7d5, 0xc07bb7, 0x58c5b8, 0xe4d5ca,
                0x7a7185, 0xff879c, 0xb8db8b, 0xffd36a, 0x8bc3ec, 0xd99bce, 0x79dfd0, 0xfff1e8,
            ].map(WorkspaceColor.init(hex:))
        ),
        TerminalColorTheme(
            id: "wildflower", name: "Wildflower",
            background: .init(hex: 0x202a39), foreground: .init(hex: 0xf5e9d6),
            cursor: .init(hex: 0xf18b65), cursorText: .init(hex: 0x202a39),
            selectionBackground: .init(hex: 0x3e5060), selectionForeground: .init(hex: 0xfff4e2),
            palette: [
                0x48515c, 0xe97768, 0x91ad67, 0xd6a64e, 0x7fa1d0, 0xc08cb2, 0x62a995, 0xe5d6c3,
                0x737e8a, 0xff927c, 0xb0c980, 0xf1bf62, 0x91addb, 0xd39ac0, 0x7ac9ad, 0xfff2df,
            ].map(WorkspaceColor.init(hex:))
        ),
        TerminalColorTheme(
            id: "harvest", name: "Harvest",
            background: .init(hex: 0x302536), foreground: .init(hex: 0xf8e8d2),
            cursor: .init(hex: 0x57c4be), cursorText: .init(hex: 0x302536),
            selectionBackground: .init(hex: 0x594453), selectionForeground: .init(hex: 0xfff3df),
            palette: [
                0x554752, 0xf27260, 0x83a85e, 0xe5b44d, 0x759ac9, 0xc08ab0, 0x50aaa5, 0xe7d2b5,
                0x7c6a7b, 0xff7c66, 0xa6c77a, 0xf4cc65, 0x83aad8, 0xc994b8, 0x70c6bd, 0xfff0dc,
            ].map(WorkspaceColor.init(hex:))
        ),
    ]

    static var builtInThemes: [TerminalColorTheme] {
        [.gruvboxMaterialDarkMedium] + cozyPresets + pairingPresets
    }

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
        var primary = [
            "background = #\(background.hexString)",
            "foreground = #\(foreground.hexString)",
            "cursor-color = #\(cursor.hexString)",
        ]
        if let cursorText { primary.append("cursor-text = #\(cursorText.hexString)") }
        primary.append("selection-background = #\(selectionBackground.hexString)")
        primary.append("selection-foreground = #\(selectionForeground.hexString)")
        let colors = palette.enumerated().map { "palette = \($0.offset)=#\($0.element.hexString)" }
        return (primary + colors).joined(separator: "\n") + "\n"
    }

    static var active: TerminalColorTheme? {
        let defaults = UserDefaults.ghostty
        guard let id = defaults.string(forKey: TerminalColorThemeStore.activeThemeKey),
              id != workspaceDefaultID else { return nil }
        if let builtInTheme = builtInThemes.first(where: { $0.id == id }) { return builtInTheme }
        guard let data = defaults.data(forKey: TerminalColorThemeStore.customThemesKey),
              let themes = try? JSONDecoder().decode([TerminalColorTheme].self, from: data) else {
            return nil
        }
        return themes.first { $0.id == id }
    }
}

struct CozyThemePairing: Identifiable {
    let id: String
    let name: String
    let detail: String
    let appearance: WorkspaceTabTheme
    let terminalThemeID: String

    var terminalTheme: TerminalColorTheme {
        TerminalColorTheme.pairingPresets.first { $0.id == terminalThemeID }!
    }

    static let all: [CozyThemePairing] = [
        .init(id: "raspberry-midnight", name: "Raspberry Cream + Midnight Garden", detail: "Warm stationery with a jewel-toned terminal.", appearance: .raspberryCream, terminalThemeID: "midnight-garden"),
        .init(id: "cambridge-poolside", name: "Cambridge Sunset + Poolside", detail: "Peach and burgundy chrome with crisp aquatic color.", appearance: .cambridgeSunset, terminalThemeID: "poolside"),
        .init(id: "forest-berry", name: "Forest Market + Berry Soda", detail: "Deep forest surfaces with playful berry brights.", appearance: .forestMarket, terminalThemeID: "berry-soda"),
        .init(id: "terracotta-wildflower", name: "Terracotta Evening + Wildflower", detail: "Earthy chrome with a lively blue terminal.", appearance: .terracottaEvening, terminalThemeID: "wildflower"),
        .init(id: "retro-harvest", name: "Retro Pop + Harvest", detail: "Sunny tabs paired with rich vintage terminal colors.", appearance: .retroPop, terminalThemeID: "harvest"),
    ]
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
        TerminalColorTheme.builtInThemes + customThemes
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
        let protectedIDs = [TerminalColorTheme.workspaceDefaultID]
            + TerminalColorTheme.builtInThemes.map(\.id)
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
        case .gruvbox:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0x32302f),
                tabForeground: .init(hex: 0xa89984),
                selectedTabBackground: .init(hex: 0x45403d),
                selectedTabForeground: .init(hex: 0xd4be98),
                borderColor: .init(hex: 0x504945),
                selectedBorderColor: .init(hex: 0xa9b665),
                font: .monospaced,
                fontSize: 13,
                spacing: 5,
                horizontalPadding: 12,
                verticalPadding: 8,
                cornerRadius: 5
            )
        case .amethyst:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0x282137),
                tabForeground: .init(hex: 0xd8cde8),
                selectedTabBackground: .init(hex: 0x3d3052),
                selectedTabForeground: .init(hex: 0xfbf7ff),
                borderColor: .init(hex: 0x453a59),
                selectedBorderColor: .init(hex: 0xc084fc),
                font: .system,
                fontSize: 13,
                spacing: 6,
                horizontalPadding: 12,
                verticalPadding: 8,
                cornerRadius: 9
            )
        case .raspberryCream:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0xf9e8b8),
                tabForeground: .init(hex: 0x63233a),
                selectedTabBackground: .init(hex: 0xfff0cc),
                selectedTabForeground: .init(hex: 0x63233a),
                borderColor: .init(hex: 0xd9c99d),
                selectedBorderColor: .init(hex: 0xa00046),
                font: .serif,
                fontSize: 13,
                spacing: 7,
                horizontalPadding: 13,
                verticalPadding: 8,
                cornerRadius: 9
            )
        case .cambridgeSunset:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0xeed8c2),
                tabForeground: .init(hex: 0x622c30),
                selectedTabBackground: .init(hex: 0xf9e6d5),
                selectedTabForeground: .init(hex: 0x622c30),
                borderColor: .init(hex: 0xd3bca7),
                selectedBorderColor: .init(hex: 0xb6192b),
                font: .serif,
                fontSize: 13,
                spacing: 7,
                horizontalPadding: 13,
                verticalPadding: 8,
                cornerRadius: 9
            )
        case .forestMarket:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0x2c4b34),
                tabForeground: .init(hex: 0xe8d9b7),
                selectedTabBackground: .init(hex: 0x3b5b3e),
                selectedTabForeground: .init(hex: 0xfff3d2),
                borderColor: .init(hex: 0x4d6846),
                selectedBorderColor: .init(hex: 0xffca32),
                font: .system,
                fontSize: 13,
                spacing: 6,
                horizontalPadding: 12,
                verticalPadding: 8,
                cornerRadius: 9
            )
        case .crimsonOrchard:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0x542a36),
                tabForeground: .init(hex: 0xe7c8c5),
                selectedTabBackground: .init(hex: 0x693947),
                selectedTabForeground: .init(hex: 0xffe7e2),
                borderColor: .init(hex: 0x754756),
                selectedBorderColor: .init(hex: 0xf7b6b8),
                font: .serif,
                fontSize: 13,
                spacing: 6,
                horizontalPadding: 12,
                verticalPadding: 8,
                cornerRadius: 9
            )
        case .terracottaEvening:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0x49352a),
                tabForeground: .init(hex: 0xe1c8a6),
                selectedTabBackground: .init(hex: 0x5a4130),
                selectedTabForeground: .init(hex: 0xfff0d9),
                borderColor: .init(hex: 0x6d523a),
                selectedBorderColor: .init(hex: 0xe6a25d),
                font: .system,
                fontSize: 13,
                spacing: 6,
                horizontalPadding: 12,
                verticalPadding: 8,
                cornerRadius: 9
            )
        case .retroPop:
            .init(
                baseTheme: theme,
                tabBackground: .init(hex: 0xf7e2a4),
                tabForeground: .init(hex: 0x472d48),
                selectedTabBackground: .init(hex: 0xffefc1),
                selectedTabForeground: .init(hex: 0x472d48),
                borderColor: .init(hex: 0xd9c787),
                selectedBorderColor: .init(hex: 0x6268d5),
                font: .system,
                fontSize: 13,
                spacing: 6,
                horizontalPadding: 12,
                verticalPadding: 8,
                cornerRadius: 9
            )
        }
    }
}

struct WorkspaceThemeProfile: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var configuration: WorkspaceThemeConfiguration

    static func presetID(for theme: WorkspaceTabTheme) -> String {
        "preset:\(theme.rawValue)"
    }
}

@MainActor
final class WorkspaceCustomizationStore: ObservableObject {
    static let shared = WorkspaceCustomizationStore()
    static let configurationKey = "WorkspaceThemeConfiguration"
    nonisolated static let profilesKey = "WorkspaceThemeProfiles"
    nonisolated static let activeProfileKey = "WorkspaceTheme.ActiveProfile"
    static let presentationKey = "WorkspaceTabPresentation"
    private static let presentationMigrationKey = "WorkspaceTabPresentationSidebarOnlyMigration"
    static let sidebarVisibleKey = "WorkspaceSessionSidebarVisible"
    private var tabBarVisibilityUpdateScheduled = false

    @Published private(set) var configuration: WorkspaceThemeConfiguration {
        didSet { saveConfiguration() }
    }

    @Published private(set) var customProfiles: [WorkspaceThemeProfile]
    @Published private(set) var activeProfileID: String

    var isCustomProfileActive: Bool {
        !WorkspaceTabTheme.allCases.contains {
            WorkspaceThemeProfile.presetID(for: $0) == activeProfileID
        }
    }

    var customWorkspaceTitleFont: NSFont? {
        guard isCustomProfileActive else { return nil }
        return configuration.font.nsFont(size: CGFloat(configuration.fontSize))
    }

    var customWorkspaceTitleColor: NSColor? {
        guard isCustomProfileActive else { return nil }
        return configuration.tabForeground.nsColor
    }

    var customWorkspaceChromeColor: NSColor? {
        guard isCustomProfileActive else { return nil }
        return configuration.tabBackground.nsColor
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
        let savedProfiles: [WorkspaceThemeProfile]
        if let data = defaults.data(forKey: Self.profilesKey),
           let decoded = try? JSONDecoder().decode([WorkspaceThemeProfile].self, from: data) {
            savedProfiles = decoded
        } else {
            savedProfiles = []
        }
        let savedActiveProfileID = defaults.string(forKey: Self.activeProfileKey)
            ?? WorkspaceThemeProfile.presetID(for: initialTheme)
        customProfiles = savedProfiles
        if let savedProfile = savedProfiles.first(where: { $0.id == savedActiveProfileID }) {
            configuration = savedProfile.configuration
        } else if let data = defaults.data(forKey: Self.configurationKey),
           let decoded = try? JSONDecoder().decode(WorkspaceThemeConfiguration.self, from: data) {
            configuration = decoded
        } else {
            configuration = .defaults(for: initialTheme)
        }
        activeProfileID = savedActiveProfileID
        let initialTabPresentation: WorkspaceTabPresentation
        if defaults.bool(forKey: Self.presentationMigrationKey) {
            initialTabPresentation = defaults.string(forKey: Self.presentationKey)
                .flatMap(WorkspaceTabPresentation.init(rawValue:)) ?? .sidebarOnly
        } else {
            // Session navigation now lives in the workspace sidebar. Existing
            // installations should start with both tab bars hidden as well.
            initialTabPresentation = .sidebarOnly
            defaults.set(WorkspaceTabPresentation.sidebarOnly.rawValue, forKey: Self.presentationKey)
            defaults.set(true, forKey: Self.presentationMigrationKey)
        }
        tabPresentation = initialTabPresentation
        sidebarVisible = initialTabPresentation == .sidebarOnly
            ? true
            : defaults.object(forKey: Self.sidebarVisibleKey) as? Bool ?? false
        if initialTabPresentation == .sidebarOnly {
            defaults.set(true, forKey: Self.sidebarVisibleKey)
        }
    }

    func update(_ mutation: (inout WorkspaceThemeConfiguration) -> Void) {
        var updated = configuration
        mutation(&updated)
        configuration = updated
        NotificationCenter.default.post(name: .workspaceTabThemeDidChange, object: nil)
    }

    func selectBaseTheme(_ theme: WorkspaceTabTheme) {
        let presetID = WorkspaceThemeProfile.presetID(for: theme)
        guard activeProfileID != presetID || configuration.baseTheme != theme else { return }
        if WorkspaceTabTheme.current != theme,
           let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.ghostty.setWorkspaceTabTheme(theme)
        } else {
            UserDefaults.ghostty.set(theme.rawValue, forKey: WorkspaceTabTheme.defaultsKey)
        }
        activeProfileID = presetID
        UserDefaults.ghostty.set(presetID, forKey: Self.activeProfileKey)
        configuration = .defaults(for: theme)
        NotificationCenter.default.post(name: .workspaceTabThemeDidChange, object: nil)
    }

    func selectProfile(_ id: String) {
        if let theme = WorkspaceTabTheme.allCases.first(where: {
            WorkspaceThemeProfile.presetID(for: $0) == id
        }) {
            selectBaseTheme(theme)
            return
        }
        guard let profile = customProfiles.first(where: { $0.id == id }) else { return }
        activeProfileID = profile.id
        UserDefaults.ghostty.set(profile.id, forKey: Self.activeProfileKey)
        if WorkspaceTabTheme.current != profile.configuration.baseTheme,
           let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.ghostty.setWorkspaceTabTheme(profile.configuration.baseTheme)
        } else {
            UserDefaults.ghostty.set(
                profile.configuration.baseTheme.rawValue,
                forKey: WorkspaceTabTheme.defaultsKey
            )
        }
        configuration = profile.configuration
        NotificationCenter.default.post(name: .workspaceTabThemeDidChange, object: nil)
    }

    func saveCurrentProfile(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let profile = WorkspaceThemeProfile(
            id: UUID().uuidString,
            name: trimmedName,
            configuration: configuration
        )
        customProfiles.append(profile)
        persistProfiles()
        activeProfileID = profile.id
        UserDefaults.ghostty.set(profile.id, forKey: Self.activeProfileKey)
        NotificationCenter.default.post(name: .workspaceTabThemeDidChange, object: nil)
    }

    func deleteProfile(_ id: String) {
        customProfiles.removeAll { $0.id == id }
        persistProfiles()
        if activeProfileID == id {
            selectBaseTheme(configuration.baseTheme)
        }
    }

    func renameProfile(_ id: String, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = customProfiles.firstIndex(where: { $0.id == id }) else { return }
        customProfiles[index].name = trimmedName
        persistProfiles()
    }

    func resetCustomizations() {
        configuration = .defaults(for: configuration.baseTheme)
        NotificationCenter.default.post(name: .workspaceTabThemeDidChange, object: nil)
    }

    func setTabPresentation(_ presentation: WorkspaceTabPresentation) {
        guard presentation != tabPresentation else { return }
        if presentation == .sidebarOnly {
            sidebarVisible = true
        }
        tabPresentation = presentation
        NotificationCenter.default.post(name: .workspaceTabPresentationDidChange, object: nil)
        WorkspaceSessionStore.shared.refresh()
    }

    func setSidebarVisible(_ visible: Bool) {
        guard visible || tabPresentation != .sidebarOnly else { return }
        sidebarVisible = visible
    }

    /// Reconcile AppKit's tab-bar visibility after it updates a tab group.
    /// AppKit can recreate or show its native bar during group mutations, so
    /// defer and coalesce these requests until that update has settled.
    func scheduleTabBarVisibilityUpdate() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.scheduleTabBarVisibilityUpdate() }
            return
        }
        guard !tabBarVisibilityUpdateScheduled else { return }
        tabBarVisibilityUpdateScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(60)) { [weak self] in
            guard let self else { return }
            self.tabBarVisibilityUpdateScheduled = false
            self.applyTabBarVisibility()
        }
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
                  handledGroups.insert(ObjectIdentifier(group)).inserted else { continue }

            let wantsNativeTabBar = tabPresentation == .native && group.windows.count > 1
            guard group.isTabBarVisible != wantsNativeTabBar else { continue }
            (group.selectedWindow ?? window).toggleTabBar(nil)
        }
    }

    private func saveConfiguration() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.ghostty.set(data, forKey: Self.configurationKey)
        UserDefaults.ghostty.set(configuration.baseTheme.rawValue, forKey: WorkspaceTabTheme.defaultsKey)
        if let index = customProfiles.firstIndex(where: { $0.id == activeProfileID }) {
            customProfiles[index].configuration = configuration
            persistProfiles()
        }
    }

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(customProfiles) else { return }
        UserDefaults.ghostty.set(data, forKey: Self.profilesKey)
    }
}

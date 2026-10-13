import AppKit

/// Visual presets for the macOS workspace chrome and terminal surface.
enum WorkspaceTabTheme: String, CaseIterable, Identifiable, Codable, Hashable {
    case minimal
    case newspaper
    case pixel

    static let defaultsKey = "WorkspaceTabTheme"

    var id: String { rawValue }

    var menuTag: Int {
        switch self {
        case .minimal: 0
        case .newspaper: 1
        case .pixel: 2
        }
    }

    var name: String {
        switch self {
        case .minimal: "Minimal"
        case .newspaper: "Newspaper"
        case .pixel: "Pixel"
        }
    }

    var detail: String {
        switch self {
        case .minimal: "Use your Ghostty terminal colors and standard macOS chrome."
        case .newspaper: "Warm paper colors, earthy ANSI colors, and serif tab titles."
        case .pixel: "Dark green colors, bright accents, and fixed-width tab titles."
        }
    }

    /// A Ghostty config overlay for the terminal surface. These presentation presets are loaded
    /// after the user's config and are never written into the user's config files.
    var configOverlay: String? {
        let colors: [String: [String]] = [
            "background": ["f4eedf", "101510"],
            "foreground": ["342d24", "b8f2a5"],
            "cursor-color": ["8a5b32", "a5ff62"],
            "selection-background": ["dfd1b7", "29422a"],
            "selection-foreground": ["342d24", "e7ffe0"],
        ]
        let palettes: [[String]] = [
            [
                "28231e", "b34a3c", "62784a", "9a762e", "526a8d", "8a6685", "4e7e7b", "d3c8b5",
                "71685d", "d87a68", "8ba36f", "cba255", "839ec8", "b28cab", "75a6a2", "f4eedf",
            ],
            [
                "101510", "ff5b5b", "8cff57", "f4ee58", "5ba7ff", "dd70ff", "52edda", "b8f2a5",
                "586b56", "ff8a72", "b1ff7c", "fff27a", "83bdff", "ed9bff", "7effef", "e7ffe0",
            ],
        ]

        guard self != .minimal else { return nil }
        let paletteIndex = self == .newspaper ? 0 : 1
        let values = colors.map { key, variants in "\(key) = #\(variants[paletteIndex])" }
        let palette = palettes[paletteIndex].enumerated().map { "palette = \($0.offset)=#\($0.element)" }
        return (values + palette).joined(separator: "\n") + "\n"
    }

    static var current: WorkspaceTabTheme {
        UserDefaults.ghostty.string(forKey: defaultsKey)
            .flatMap(WorkspaceTabTheme.init(rawValue:)) ?? .minimal
    }

    func titleFont(size: CGFloat) -> NSFont? {
        switch self {
        case .minimal:
            nil
        case .newspaper:
            NSFont(name: "Georgia", size: size)
        case .pixel:
            NSFont(name: "Menlo-Bold", size: size)
        }
    }

    var titleColor: NSColor? {
        switch self {
        case .minimal:
            nil
        case .newspaper:
            NSColor(calibratedRed: 0.19, green: 0.16, blue: 0.12, alpha: 1)
        case .pixel:
            NSColor(calibratedRed: 0.64, green: 0.95, blue: 0.43, alpha: 1)
        }
    }

    var chromeColor: NSColor? {
        switch self {
        case .minimal:
            nil
        case .newspaper:
            NSColor(calibratedRed: 0.94, green: 0.90, blue: 0.82, alpha: 1)
        case .pixel:
            NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.10, alpha: 1)
        }
    }

    var previewSurfaceColor: NSColor {
        switch self {
        case .minimal:
            NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 1)
        case .newspaper:
            NSColor(calibratedRed: 0.957, green: 0.933, blue: 0.875, alpha: 1)
        case .pixel:
            NSColor(calibratedRed: 0.063, green: 0.082, blue: 0.063, alpha: 1)
        }
    }

    var previewForegroundColor: NSColor {
        switch self {
        case .minimal:
            NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.93, alpha: 1)
        case .newspaper:
            NSColor(calibratedRed: 0.204, green: 0.176, blue: 0.141, alpha: 1)
        case .pixel:
            NSColor(calibratedRed: 0.722, green: 0.949, blue: 0.647, alpha: 1)
        }
    }

    var previewAccentColor: NSColor {
        switch self {
        case .minimal:
            NSColor(calibratedRed: 0.43, green: 0.68, blue: 0.96, alpha: 1)
        case .newspaper:
            NSColor(calibratedRed: 0.69, green: 0.29, blue: 0.24, alpha: 1)
        case .pixel:
            NSColor(calibratedRed: 0.55, green: 1, blue: 0.34, alpha: 1)
        }
    }
}

extension Notification.Name {
    static let workspaceTabThemeDidChange = Notification.Name("WorkspaceTabThemeDidChange")
}

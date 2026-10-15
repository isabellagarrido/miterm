import AppKit

/// Visual presets for the macOS workspace chrome and terminal surface.
enum WorkspaceTabTheme: String, CaseIterable, Identifiable, Codable, Hashable {
    case minimal
    case newspaper
    case pixel
    case gruvbox
    case amethyst
    case raspberryCream
    case cambridgeSunset
    case forestMarket
    case crimsonOrchard
    case terracottaEvening
    case retroPop

    static let defaultsKey = "WorkspaceTabTheme"

    var id: String { rawValue }

    var menuTag: Int {
        switch self {
        case .minimal: 0
        case .newspaper: 1
        case .pixel: 2
        case .gruvbox: 3
        case .amethyst: 4
        case .raspberryCream: 5
        case .cambridgeSunset: 6
        case .forestMarket: 7
        case .crimsonOrchard: 8
        case .terracottaEvening: 9
        case .retroPop: 10
        }
    }

    var name: String {
        switch self {
        case .minimal: "Minimal"
        case .newspaper: "Newspaper"
        case .pixel: "Pixel"
        case .gruvbox: "Gruvbox Material"
        case .amethyst: "Amethyst"
        case .raspberryCream: "Raspberry Cream"
        case .cambridgeSunset: "Cambridge Sunset"
        case .forestMarket: "Forest Market"
        case .crimsonOrchard: "Crimson Orchard"
        case .terracottaEvening: "Terracotta Evening"
        case .retroPop: "Retro Pop"
        }
    }

    var detail: String {
        switch self {
        case .minimal: "Use your Ghostty terminal colors and standard macOS chrome."
        case .newspaper: "Warm paper colors, earthy ANSI colors, and serif tab titles."
        case .pixel: "Dark green colors, bright accents, and fixed-width tab titles."
        case .gruvbox: "Warm charcoal surfaces, cream text, and muted green accents."
        case .amethyst: "Deep violet surfaces, lavender text, and bright purple accents."
        case .raspberryCream: "Raspberry ink, vanilla paper, and market-stall gold."
        case .cambridgeSunset: "Soft peach paper, berry red, and sage green."
        case .forestMarket: "Forest-green surfaces with harvest gold and warm orange."
        case .crimsonOrchard: "Dark orchard plum, blossom pink, and muted harvest yellow."
        case .terracottaEvening: "Warm clay and walnut with sunset amber and olive."
        case .retroPop: "Buttercream paper, periwinkle blue, and tomato red."
        }
    }

    var usesSerifTypography: Bool {
        [.newspaper, .raspberryCream, .cambridgeSunset].contains(self)
    }

    var usesMonospacedTypography: Bool {
        [.pixel, .gruvbox].contains(self)
    }

    /// A Ghostty config overlay for the terminal surface. These presentation presets are loaded
    /// after the user's config and are never written into the user's config files.
    var configOverlay: String? {
        switch self {
        case .minimal, .gruvbox: nil
        case .newspaper:
            Self.overlay(
                background: "f4eedf", foreground: "342d24", cursor: "8a5b32",
                selection: "dfd1b7", selectionForeground: "342d24",
                palette: [
                    "28231e", "b34a3c", "62784a", "9a762e", "526a8d", "8a6685", "4e7e7b", "d3c8b5",
                    "71685d", "d87a68", "8ba36f", "cba255", "839ec8", "b28cab", "75a6a2", "f4eedf",
                ])
        case .pixel:
            Self.overlay(
                background: "101510", foreground: "b8f2a5", cursor: "a5ff62",
                selection: "29422a", selectionForeground: "e7ffe0",
                palette: [
                    "101510", "ff5b5b", "8cff57", "f4ee58", "5ba7ff", "dd70ff", "52edda", "b8f2a5",
                    "586b56", "ff8a72", "b1ff7c", "fff27a", "83bdff", "ed9bff", "7effef", "e7ffe0",
                ])
        case .amethyst:
            Self.overlay(
                background: "17121f", foreground: "e8def4", cursor: "c084fc",
                selection: "403052", selectionForeground: "fbf7ff",
                palette: [
                    "17121f", "f0719a", "9dc77a", "e5c07b", "82aaff", "c792ea", "78dce8", "e8def4",
                    "625574", "ff8eb5", "b4e88d", "f4d58d", "a1c5ff", "d9a8ff", "91e8f5", "fbf7ff",
                ])
        case .raspberryCream:
            Self.overlay(
                background: "fff6d8", foreground: "63233a", cursor: "a00046",
                cursorText: "fff6d8", selection: "e8c5cf", selectionForeground: "63233a",
                palette: [
                    "49343a", "a00046", "496b45", "986000", "355b8c", "7c458b", "2d6f70", "63233a",
                    "765d60", "c83268", "59774e", "9b6300", "51709f", "8e5d98", "3b7878", "7d3e50",
                ])
        case .cambridgeSunset:
            Self.overlay(
                background: "fbebd7", foreground: "622c30", cursor: "b6192b",
                cursorText: "fbebd7", selection: "e9c6ba", selectionForeground: "622c30",
                palette: [
                    "49383a", "a33037", "4b704e", "915f2a", "426785", "835878", "367371", "622c30",
                    "7b6260", "b44445", "56714e", "8b6130", "4d6e85", "865d78", "3c7370", "784347",
                ])
        case .forestMarket:
            Self.overlay(
                background: "213c2a", foreground: "f7eac9", cursor: "ffca32",
                cursorText: "213c2a", selection: "4c633d", selectionForeground: "fff5d9",
                palette: [
                    "909993", "f28078", "a4c66a", "ffca32", "78aeda", "cf91bc", "71c4ad", "e8d9b7",
                    "9da7a0", "ff9183", "c3e584", "ffdf68", "9bc8ef", "e0add0", "91ddc4", "fff3d2",
                ])
        case .crimsonOrchard:
            Self.overlay(
                background: "401f29", foreground: "f8d8d3", cursor: "f7b6b8",
                cursorText: "401f29", selection: "6c3b49", selectionForeground: "fff0ec",
                palette: [
                    "909993", "da7379", "83a66a", "c8a839", "7598b9", "c27f95", "72a59a", "e7c8c5",
                    "9da7a0", "f17c7e", "a4c483", "dfc45b", "91b2d0", "d695aa", "8bc0b4", "ffe7e2",
                ])
        case .terracottaEvening:
            Self.overlay(
                background: "35271f", foreground: "f3dec0", cursor: "e6a25d",
                cursorText: "35271f", selection: "604634", selectionForeground: "fff0d9",
                palette: [
                    "909993", "d57a64", "8da15b", "d89b43", "7698a4", "ba867e", "74a08c", "e1c8a6",
                    "9da7a0", "ec8264", "a8b970", "efb65e", "8fb1bb", "cd938a", "91baa5", "fff0d9",
                ])
        case .retroPop:
            Self.overlay(
                background: "fff1bf", foreground: "472d48", cursor: "5e65b3",
                cursorText: "ffffff", selection: "d9d8fa", selectionForeground: "472d48",
                palette: [
                    "443445", "c43a3d", "4f7648", "896700", "525baf", "914d86", "287478", "472d48",
                    "746171", "bb4440", "517543", "85690d", "5e65b3", "935988", "2f7777", "67425f",
                ])
        }
    }

    private static func overlay(
        background: String,
        foreground: String,
        cursor: String,
        cursorText: String? = nil,
        selection: String,
        selectionForeground: String,
        palette: [String]
    ) -> String {
        var colors = [
            "background = #\(background)",
            "foreground = #\(foreground)",
            "cursor-color = #\(cursor)",
        ]
        if let cursorText { colors.append("cursor-text = #\(cursorText)") }
        colors.append("selection-background = #\(selection)")
        colors.append("selection-foreground = #\(selectionForeground)")
        let ansi = palette.enumerated().map { "palette = \($0.offset)=#\($0.element)" }
        return (colors + ansi).joined(separator: "\n") + "\n"
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
        case .gruvbox:
            NSFont(name: "Menlo", size: size)
        case .amethyst:
            nil
        case .raspberryCream, .cambridgeSunset, .retroPop:
            NSFont(name: "Georgia", size: size)
        case .forestMarket, .crimsonOrchard, .terracottaEvening:
            nil
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
        case .gruvbox:
            NSColor(calibratedRed: 0.83, green: 0.75, blue: 0.60, alpha: 1)
        case .amethyst:
            NSColor(calibratedRed: 0.86, green: 0.77, blue: 0.96, alpha: 1)
        case .raspberryCream: Self.color(hex: 0x63233a)
        case .cambridgeSunset: Self.color(hex: 0x622c30)
        case .forestMarket: Self.color(hex: 0xf7eac9)
        case .crimsonOrchard: Self.color(hex: 0xf8d8d3)
        case .terracottaEvening: Self.color(hex: 0xf3dec0)
        case .retroPop: Self.color(hex: 0x472d48)
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
        case .gruvbox:
            NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.16, alpha: 1)
        case .amethyst:
            NSColor(calibratedRed: 0.13, green: 0.10, blue: 0.17, alpha: 1)
        case .raspberryCream: Self.color(hex: 0xf9e8b8)
        case .cambridgeSunset: Self.color(hex: 0xeed8c2)
        case .forestMarket: Self.color(hex: 0x2c4b34)
        case .crimsonOrchard: Self.color(hex: 0x542a36)
        case .terracottaEvening: Self.color(hex: 0x49352a)
        case .retroPop: Self.color(hex: 0xf7e2a4)
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
        case .gruvbox:
            NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.16, alpha: 1)
        case .amethyst:
            NSColor(calibratedRed: 0.09, green: 0.07, blue: 0.12, alpha: 1)
        case .raspberryCream: Self.color(hex: 0xfff6d8)
        case .cambridgeSunset: Self.color(hex: 0xfbebd7)
        case .forestMarket: Self.color(hex: 0x213c2a)
        case .crimsonOrchard: Self.color(hex: 0x401f29)
        case .terracottaEvening: Self.color(hex: 0x35271f)
        case .retroPop: Self.color(hex: 0xfff1bf)
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
        case .gruvbox:
            NSColor(calibratedRed: 0.83, green: 0.75, blue: 0.60, alpha: 1)
        case .amethyst:
            NSColor(calibratedRed: 0.91, green: 0.87, blue: 0.97, alpha: 1)
        case .raspberryCream: Self.color(hex: 0x63233a)
        case .cambridgeSunset: Self.color(hex: 0x622c30)
        case .forestMarket: Self.color(hex: 0xf7eac9)
        case .crimsonOrchard: Self.color(hex: 0xf8d8d3)
        case .terracottaEvening: Self.color(hex: 0xf3dec0)
        case .retroPop: Self.color(hex: 0x472d48)
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
        case .gruvbox:
            NSColor(calibratedRed: 0.66, green: 0.71, blue: 0.40, alpha: 1)
        case .amethyst:
            NSColor(calibratedRed: 0.75, green: 0.54, blue: 0.98, alpha: 1)
        case .raspberryCream: Self.color(hex: 0xa00046)
        case .cambridgeSunset: Self.color(hex: 0xb6192b)
        case .forestMarket: Self.color(hex: 0xffca32)
        case .crimsonOrchard: Self.color(hex: 0xf7b6b8)
        case .terracottaEvening: Self.color(hex: 0xe6a25d)
        case .retroPop: Self.color(hex: 0x7479e8)
        }
    }

    private static func color(hex: UInt32) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}

extension Notification.Name {
    static let workspaceTabThemeDidChange = Notification.Name("WorkspaceTabThemeDidChange")
    static let workspaceTabPresentationDidChange = Notification.Name("WorkspaceTabPresentationDidChange")
}

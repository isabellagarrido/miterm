import Testing
@testable import Ghostty

@Suite
struct WorkspaceThemeTests {
    @Test func cozyPresetsProvideCompleteReadableTerminalPalettes() throws {
        #expect(TerminalColorTheme.cozyPresets.count == 6)
        #expect(Set(TerminalColorTheme.cozyPresets.map(\.id)).count == 6)

        for terminalTheme in TerminalColorTheme.cozyPresets {
            #expect(terminalTheme.palette.count == 16)
            #expect(contrast(terminalTheme.foreground, terminalTheme.background) >= 4.5)
            let cursorText = try #require(terminalTheme.cursorText)
            #expect(contrast(cursorText, terminalTheme.cursor) >= 4.5)
            #expect(contrast(terminalTheme.selectionForeground, terminalTheme.selectionBackground) >= 4.5)
            for index in Array(1...7) + Array(9...15) {
                #expect(
                    contrast(terminalTheme.palette[index], terminalTheme.background) >= 4.5,
                    "\(terminalTheme.name) ANSI color \(index) should contrast with its terminal background"
                )
            }

            let normalizedID = terminalTheme.id.replacingOccurrences(of: "-", with: "")
            let appearance = try #require(WorkspaceTabTheme.allCases.first {
                $0.rawValue.lowercased() == normalizedID
            })
            let overlay = try #require(appearance.configOverlay)
            #expect(overlay.contains("background = #"))
            #expect(overlay.contains("foreground = #"))
            #expect(overlay.contains("cursor-color = #"))
            #expect(overlay.contains("cursor-text = #"))
            #expect(overlay.contains("selection-background = #"))
            #expect(overlay.contains("selection-foreground = #"))
            #expect(overlay.components(separatedBy: "palette = ").count == 17)
            #expect(terminalTheme.configOverlay.components(separatedBy: "palette = ").count == 17)

            let workspace = WorkspaceThemeConfiguration.defaults(for: appearance)
            #expect(contrast(workspace.tabForeground, workspace.tabBackground) >= 4.5)
            #expect(contrast(workspace.selectedTabForeground, workspace.selectedTabBackground) >= 4.5)
        }
    }

    @Test func curatedPairingsCombineDistinctAppearanceAndTerminalPresets() throws {
        #expect(CozyThemePairing.all.count == 5)
        #expect(Set(CozyThemePairing.all.map(\.id)).count == CozyThemePairing.all.count)

        for pairing in CozyThemePairing.all {
            let terminalTheme = try #require(TerminalColorTheme.builtInThemes.first {
                $0.id == pairing.terminalThemeID
            })
            #expect(terminalTheme.palette.count == 16)
            #expect(contrast(terminalTheme.foreground, terminalTheme.background) >= 4.5)
            #expect(contrast(terminalTheme.cursorText ?? terminalTheme.foreground, terminalTheme.cursor) >= 4.5)
            #expect(contrast(terminalTheme.selectionForeground, terminalTheme.selectionBackground) >= 4.5)
            for index in Array(1...7) + Array(9...15) {
                #expect(
                    contrast(terminalTheme.palette[index], terminalTheme.background) >= 4.5,
                    "\(terminalTheme.name) ANSI color \(index) should contrast with its terminal background"
                )
            }
        }
    }

    @Test func cozyAppearancePresetsRoundTripThroughProfilePersistence() throws {
        for theme in WorkspaceTabTheme.allCases where theme.configOverlay != nil {
            let profile = WorkspaceThemeProfile(
                id: WorkspaceThemeProfile.presetID(for: theme),
                name: theme.name,
                configuration: .defaults(for: theme)
            )
            let encoded = try JSONEncoder().encode(profile)
            let decoded = try JSONDecoder().decode(WorkspaceThemeProfile.self, from: encoded)
            #expect(decoded == profile)
            #expect(decoded.configuration.baseTheme == theme)
        }
    }

    @Test func terminalThemeWithoutCursorTextStillDecodes() throws {
        let legacyTheme = TerminalColorTheme.gruvboxMaterialDarkMedium
        let encoded = try JSONEncoder().encode(legacyTheme)
        let decoded = try JSONDecoder().decode(TerminalColorTheme.self, from: encoded)
        #expect(decoded == legacyTheme)
        #expect(decoded.cursorText == nil)
    }

    @Test func cozyGhosttyOverlaysParse() throws {
        let source = try TemporaryConfig("")
        for theme in WorkspaceTabTheme.allCases where theme.configOverlay != nil {
            let config = Ghostty.Config(config: Ghostty.Config.loadConfig(
                at: source.temporaryFile.path,
                finalize: true,
                workspaceTabTheme: theme,
                terminalColorTheme: nil
            ))
            #expect(config.loaded)
            #expect(config.errors.isEmpty, "\(theme.name) Ghostty overlay should contain valid config")
        }
    }

    private func contrast(_ foreground: WorkspaceColor, _ background: WorkspaceColor) -> Double {
        func luminance(_ color: WorkspaceColor) -> Double {
            func linear(_ component: Double) -> Double {
                component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(color.red)
                + 0.7152 * linear(color.green)
                + 0.0722 * linear(color.blue)
        }

        let first = luminance(foreground)
        let second = luminance(background)
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

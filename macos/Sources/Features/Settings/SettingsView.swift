import AppKit
import SwiftUI

struct SettingsView: View {
    // We need access to our app delegate to know if we're quitting or not.
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        HStack {
            Image("AppIconImage")
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)

            VStack(alignment: .leading) {
                Text("Coming Soon. 🚧").font(.title)
                Text("You can't configure settings in the GUI yet. To modify settings, " +
                     "edit the file at $HOME/.config/ghostty/config.ghostty and restart Ghostty.")
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            }
        }
        .padding()
        .frame(minWidth: 500, maxWidth: 500, minHeight: 156, maxHeight: 156)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

struct WorkspaceThemePickerView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @ObservedObject private var customization = WorkspaceCustomizationStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Choose an appearance theme")
                    .font(.system(size: 22, weight: .semibold))
                Text("Choose an appearance. Terminal color themes are selected separately.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 14) {
                ForEach(WorkspaceTabTheme.allCases) { theme in
                    WorkspaceThemeCard(
                        theme: theme,
                        isSelected: customization.activeProfileID == WorkspaceThemeProfile.presetID(for: theme)
                    ) {
                        appDelegate.selectWorkspaceTabTheme(theme)
                    }
                }
            }

            if !customization.customProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your appearance themes")
                        .font(.system(size: 13, weight: .semibold))
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(customization.customProfiles) { profile in
                                Button {
                                    customization.selectProfile(profile.id)
                                } label: {
                                    HStack(spacing: 6) {
                                        if customization.activeProfileID == profile.id {
                                            Image(systemName: "checkmark")
                                        }
                                        Text(profile.name)
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("Minimal follows your Ghostty config. Newspaper and Pixel include terminal palettes; Gruvbox appearance styling pairs with the separate Gruvbox terminal theme.")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(width: 790, height: customization.customProfiles.isEmpty ? 390 : 455)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct WorkspaceThemeCard: View {
    let theme: WorkspaceTabTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                preview
                    .frame(height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(Color(nsColor: theme.previewForegroundColor).opacity(0.12))
                    }

                HStack(alignment: .firstTextBaseline) {
                    Text(theme.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel("Selected")
                    }
                }
                Text(theme.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .topLeading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.8) : Color(nsColor: .separatorColor),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.name): \(theme.detail)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var preview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color(nsColor: theme.previewAccentColor).opacity(0.72))
                        .frame(width: 6, height: 6)
                }
                Text("workspace  /  shell")
                    .font(.system(size: 8, weight: .medium, design: theme == .newspaper ? .serif : .monospaced))
                    .foregroundStyle(Color(nsColor: theme.previewForegroundColor).opacity(0.75))
                    .padding(.leading, 5)
                Spacer()
            }
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background(Color(nsColor: theme.chromeColor ?? NSColor(calibratedWhite: 0.18, alpha: 1)))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Text("❯")
                        .foregroundStyle(Color(nsColor: theme.previewAccentColor))
                    Text("claude")
                        .foregroundStyle(Color(nsColor: theme.previewForegroundColor))
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))

                Text("Ready when you are.")
                    .font(.system(size: 10, design: theme == .newspaper ? .serif : .monospaced))
                    .foregroundStyle(Color(nsColor: theme.previewForegroundColor).opacity(0.76))

                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(nsColor: theme.previewAccentColor))
                        .frame(width: 5, height: 12)
                    Rectangle()
                        .fill(Color(nsColor: theme.previewForegroundColor).opacity(0.2))
                        .frame(width: 74, height: 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(11)
            .background(Color(nsColor: theme.previewSurfaceColor))
        }
        .background(Color(nsColor: theme.previewSurfaceColor))
    }
}

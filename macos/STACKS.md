# Stacks

Open **View → Stacks…**, choose **New Stack**, name it, and add the tabs you
want to launch together. Choose **Open in → New window** or **Current window**
when creating or editing the Stack. Each tab has a name, starting directory, and optional
startup command. Drag a tab's handle to reorder it, or use its up/down buttons.
Use **Choose emoji…** to open macOS Emoji & Symbols for the Stack icon;
the adjacent remove button clears it. Save the Stack, then choose **Open Stack**. The card menu also offers Edit,
Duplicate, and Delete. Right-click the existing Overview toolbar control for
another route to the Stack manager.

Stacks are optional. There is no startup selection, onboarding, automatic Stack
launch, or new permanent sidebar. Appearance themes, customization, and the
existing session sidebar stay separate. Workspace Overview is now called
**Session Overview**; it still displays live terminal sessions.

## Saved and running state

Definitions are stored in `~/Library/Application Support/MiTerm/Stacks.json`.
The Codable document has a format version, stable Stack and tab UUIDs, and
ordered tab definitions. Writes are atomic. Unreadable, invalid, or unsupported
versions are reported in the manager and are never silently overwritten.

Each explicit Open creates a running instance with a snapshot of the saved
definition. The saved Open in choice determines whether its tabs open in a new
window or join the most recently used terminal window. If there is no terminal
window, Current window falls back to a new one. Older definitions default to
New window, and macOS’s Prefer Tabs setting cannot merge that new window into
an existing Stack. Editing or deleting the saved
Stack does not modify its running terminals. The existing session registry tracks
running instances and surface membership; it discards instances once their
tracked terminal surfaces close. Running Stack metadata is not persisted across
app launches. Ghostty retains responsibility for its normal session restoration.

## Closing tabs and navigation

Close tabs individually using the **×** button or **Close Tab** context-menu
action. A running Stack disappears from the session registry after its last tab
closes; its saved definition remains available. There is no separate Close Stack
action.

The sidebar **×** appears when hovering anywhere over a tab row or when its
controls have keyboard focus. It does not reserve permanent horizontal space.
Both the sidebar and the top strip use the current window’s native tab group,
in the same order, with the same selection. Closing uses Ghostty’s normal
confirmation and undo behavior. Session Overview remains the view across windows.

## Directories and commands

Directories must be absolute paths or tilde paths. MiTerm expands the tilde and
checks every path is a directory with read and search access before creating any
terminal. The same directory may appear in any number of tabs. Paths are passed
to Ghostty as working directories, never interpolated into a shell command.
Missing or inaccessible directories cause a visible error, without launching
any tabs. A failure during native tab creation reports any partial launch and
leaves already opened terminals running.

Startup commands are visible in cards and editable in the tab editor. They are
single-line commands passed through Ghostty's supported surface-command API,
which runs them via its shell mechanism. No simulated keystrokes or initial-input
injection is used. A configured command replaces that tab's default shell; the
tab retains output after the command exits. Leaving the command blank launches
the normal configured shell. Commands run only on explicit Open; saving, editing,
duplicating, and viewing definitions do not execute them. There is no import
feature in this milestone.

## Architecture and scope

Reuse Ghostty's `TerminalController.newWindow` / `newTab`, AppKit tab groups,
and existing terminal surfaces. When opening a new window, creation of later tabs waits for its presentation.
Tabs attach after their predecessor to preserve saved order. Select the first tab after launch. Normal creation calls retain
their defaults and keyboard shortcuts.

A separate app-owned terminal host or tab renderer would duplicate ownership,
focus, restoration, accessibility, and split behavior. A new libghostty host
would require an even larger platform integration. Keeping the existing host
is the smallest change and preserves the fork's established terminal behavior.

Compatibility-sensitive `Workspace*` types and preference keys remain intact;
user-facing theme controls use Appearance terminology. Saved Stack definitions
contain launch settings, not appearance settings or inferred process activity.

Multiple-tab Stacks require window decorations, a tab-capable titlebar, and
native or windowed mode. Configurations that disable tabbing are rejected before
launch rather than unexpectedly creating several windows. Newly created ordinary
tabs are not automatically assigned to a Stack. Saved split layouts, multiple
windows per definition, imported commands, hooks, worktree detection, and pixel
art are future work. Surface membership provides a starting point for future
session grouping but does not model newly added split layouts.

## Validation

Automated tests cover persistence, stable IDs, duplication, reordering, malformed
and newer library data, invalid directories, optional commands, partial launches,
and independent running snapshots. The native integration test launches real
Ghostty tabs with a shared directory containing spaces, verifies command output
and tab order across repeated opens, and checks an ordinary tab does not inherit
a Stack startup command. Its temporary config disables undo to avoid the existing
undo-manager cleanup reentrancy issue in the test fixture.

Manual checks still recommended before merge: manager layout in light/dark mode,
folder picker, drag/drop, VoiceOver, focus and keyboard shortcuts, normal terminal
usage, and titlebar/fullscreen variants. Desktop-control access was unavailable
in the implementation environment, so these visual checks have not been performed.

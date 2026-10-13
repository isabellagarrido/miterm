# MiTerm — Product and Engineering Direction

## Vision
Build a highly customizable native macOS terminal workspace on Ghostty's terminal engine. Preserve ordinary shell, TUI, and Claude Code CLI compatibility. MiTerm is not an AI backend and does not transform terminal output into newspaper columns.

The key product is the customizable UI **around** terminal sessions: unconventional tab placement and styling, newspaper-inspired themes, pixel-art workspace overviews, status indicators, and theme-specific animations.

## Current implementation
The first Codex commit (ce814787, "feat(macos): add workspace theme picker") introduces Minimal, Newspaper, and Pixel presets, terminal color overlays, a theme picker, and styling of existing macOS window/tab chrome. This is a useful first experiment but is not the intended final architecture. Do not merely add more hardcoded presets.

## Product requirements
- Tabs can use different shapes, positions, layouts, fonts, spacing, colors, and indicators.
- A workspace overview shows multiple sessions as themed cards/tiles; pixel-art and newspaper presentations should be possible.
- Session cards may use terminal titles, working directories (when available), output activity, focus and idle time.
- Terminal activity is not proof Claude is working. Titles are not guaranteed semantic summaries.
- Claude Code hooks are optional future enhancements; do not require them for core functionality.
- Themes should be data-driven and support user overrides. Separate terminal-grid color/font settings from workspace chrome tokens, layouts, and animations.
- Theme switching must not restart running terminal sessions.
- Preserve keyboard shortcuts, focus, splits, selection, accessibility, restoration, performance, and terminal correctness.

## Architectural investigation — do this before writing more UI
Inspect Ghostty macOS window, tabs, splits, terminal views, and session lifecycle. Compare:
1. Custom chrome around existing AppKit tabbing.
2. App-owned workspace/session model and custom tab UI reusing Ghostty terminal views.
3. A custom native host using libghostty if the existing app architecture proves too restrictive.

Explain tradeoffs for terminal view ownership, focus, keyboard input, splits, restoration, hidden sessions, accessibility, and maintaining the fork.

## First implementation milestone
Propose a small reversible vertical slice: an **optional custom workspace header/tab strip**, powered by session data and showing live terminal titles and selection, with a fallback to native tabs. Validate multiple sessions and focus changes before implementing elaborate layouts, pixel art, or theme animations.

## Codex working instructions
- Work on feat/customizable-workspace, not main.
- Read AGENTS.md, macos/AGENTS.md, and HACKING.md.
- Present architecture options and recommendation before implementation.
- Build macOS using macos/build.nu per repository guidance.
- Make small reviewable commits and report tests actually run.
- Keep the existing theme picker until a replacement is validated.

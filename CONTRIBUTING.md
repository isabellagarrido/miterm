# Contributing to MiTerm

MiTerm is a macOS terminal app built on Ghostty. Contributions here should
focus on MiTerm’s workspace, session navigation, customization, and integration
with the shared terminal core.

## Getting started

Follow the build instructions in [README.md](README.md). [HACKING.md](HACKING.md)
contains additional details inherited from Ghostty; references to upstream
services and contribution processes apply to Ghostty, not automatically to MiTerm.

- Shared Zig terminal core: `src/`
- macOS app and workspace UI: `macos/`
- macOS unit tests: `macos/Tests/`

## Reporting bugs and proposing changes

Use the MiTerm repository for MiTerm-specific reports. Include your macOS
version, MiTerm version or commit, reproduction steps, and expected and actual
behavior. Screenshots help with visual issues; remove private terminal content.
Discuss substantial design changes with the maintainer before implementing them.

Ghostty’s vouch system, discussion categories, and Discord channels are upstream
processes, not MiTerm contribution requirements. Changes intended for Ghostty
should follow that project’s current contribution guide.

## Preparing a change

Keep changes focused and explain the problem, resulting behavior, and validation.
Understand the code you submit and review any tool-generated changes yourself.
Never include credentials, private session data, or unrelated generated files.

For Swift changes, use `swiftlint lint --strict --fix` and build with
`nu macos/build.nu --scheme Ghostty --configuration ReleaseLocal --action build`.
Run macOS unit tests with `nu macos/build.nu --action test`.
For Zig changes, use `zig fmt` on changed files and targeted tests with
`zig build test -Dtest-filter=<test name>`. See [AGENTS.md](AGENTS.md) for
additional build and automation instructions.

For UI changes, describe the manual checks and include screenshots when useful.
Preserve existing copyright and third-party license notices in redistributed code.

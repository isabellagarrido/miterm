# MiTerm ✨

MiTerm is a macOS terminal app built on [Ghostty](https://github.com/ghostty-org/ghostty), with a customizable workspace for organizing and personalizing terminal sessions.

## Features

- Workspace themes, saved terminal color themes, and emoji icons
- Typography controls and an at-a-glance workspace overview
- A session sidebar, including a sidebar-only navigation mode

## Build

Build an optimized macOS app from source with Zig, Nushell, and Xcode installed:

```sh
zig build -Demit-macos-app=false -Demit-xcframework=true -Doptimize=ReleaseFast
nu macos/build.nu --scheme Ghostty --configuration ReleaseLocal --action build
```

The Zig command must finish successfully before building the app: it generates
`macos/GhosttyKit.xcframework`, which Xcode needs. If Zig reports a missing Metal
Toolchain, install it with `xcodebuild -downloadComponent MetalToolchain`, then
rerun both build commands.

Use `ReleaseLocal` for local builds so the bundled Sparkle framework can load
without a distribution signing identity.

The app is written to `macos/build/ReleaseLocal/MiTerm.app`. This project is based on [Ghostty](https://github.com/ghostty-org/ghostty); see [HACKING.md](HACKING.md) for build requirements.

## License and acknowledgments

MiTerm builds on Ghostty and is distributed under the [MIT license](LICENSE).
The original Ghostty copyright and license notice are retained. Bundled
third-party dependencies have their own license notices in their source directories.

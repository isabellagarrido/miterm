# MiTerm

MiTerm is a macOS terminal app built on [Ghostty](https://github.com/ghostty-org/ghostty), with a customizable workspace for organizing and personalizing terminal sessions.

## Features

- Workspace themes, saved terminal color themes, and emoji icons
- Typography controls and an at-a-glance workspace overview
- A session sidebar, including a sidebar-only navigation mode

## Build

Build an optimized macOS app from source with Zig, Nushell, and Xcode installed:

```sh
zig build -Demit-macos-app=false
nu macos/build.nu --scheme Ghostty --configuration Release --action build
```

The app is written to `macos/build/Release/MiTerm.app`. This project is based on [Ghostty](https://github.com/ghostty-org/ghostty); see [HACKING.md](HACKING.md) for build requirements.

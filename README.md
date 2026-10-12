# 🚀 Launchpad

English | [繁體中文](./README.zh-TW.md)

![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A modern macOS application launcher built with SwiftUI and TCA.

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Poseidoncode/Launchpad/main/install.sh)
```

Requires macOS 14+ and Xcode 15+. Clones, builds, and installs to `~/Applications` without requiring administrator access. Override the destination with `LAUNCHPAD_INSTALL_DIR` if needed.

### Homebrew

This development formula tracks the repository's `main` branch until a tagged release is published.
Install it explicitly as a HEAD build:

```bash
brew tap Poseidoncode/Launchpad https://github.com/Poseidoncode/Launchpad.git
brew install --HEAD Poseidoncode/Launchpad/launchpad
open "$(brew --prefix)/opt/launchpad/Launchpad.app"
```

### Dev

```bash
git clone https://github.com/Poseidoncode/Launchpad.git
cd Launchpad
swift build
.build/debug/Launchpad
```

### Upgrading from the sandboxed build

If you previously installed a sandboxed build (stored in `/Applications`), your folder layout,
custom names, and settings migrate automatically on first launch — no action needed. You can
delete the old copy at `/Applications/Launchpad.app` once the new one in `~/Applications` works.

### Behavior notes

- Installs, updates, and uninstalls in the watched app directories refresh the grid automatically
  (events are debounced ~1.5s so install bursts cause a single refresh). A `~/Applications`
  folder created after launch is picked up by scans but only watched after the next launch.
- A scan that finds no apps is never cached: an empty result is treated as a transient failure,
  so the next trigger rescans instead of hiding every app for the cache lifetime.

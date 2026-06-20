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

Requires macOS 14+ and Xcode 15+. Clones, builds, and installs to `/Applications` — nothing left behind.

### Homebrew

```bash
brew tap Poseidoncode/Launchpad
brew install --HEAD launchpad
cp -r $(brew --prefix)/opt/launchpad/Launchpad.app /Applications/
```

### Dev

```bash
git clone https://github.com/Poseidoncode/Launchpad.git
cd Launchpad
swift build
.build/debug/Launchpad
```

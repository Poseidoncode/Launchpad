# 🚀 Launchpad

[English](./README.md) | 繁體中文

![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

使用 SwiftUI 和 TCA 打造的現代化 macOS 應用程式啟動器。

## 安裝

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Poseidoncode/Launchpad/main/install.sh)
```

需要 macOS 14+ 和 Xcode 15+。自動下載、編譯並安裝到 `~/Applications`，不需要管理員權限。可用 `LAUNCHPAD_INSTALL_DIR` 自訂安裝路徑。

### Homebrew

此開發版 formula 會追蹤 `main` 分支；正式標記版本發布前，請以 HEAD 模式安裝。

```bash
brew tap Poseidoncode/Launchpad https://github.com/Poseidoncode/Launchpad.git
brew install --HEAD Poseidoncode/Launchpad/launchpad
open "$(brew --prefix)/opt/launchpad/Launchpad.app"
```

### 開發

```bash
git clone https://github.com/Poseidoncode/Launchpad.git
cd Launchpad
swift build
.build/debug/Launchpad
```

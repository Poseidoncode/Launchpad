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

### 從沙盒版本升級

如果你之前裝的是沙盒版本（放在 `/Applications`），資料夾排版、自訂名稱和設定會在首次啟動時自動遷移，不需任何操作。確認 `~/Applications` 的新版運作正常後，可刪除 `/Applications/Launchpad.app` 舊拷貝。

### 行為說明

- 受監看目錄中的安裝／更新／解除安裝會自動刷新網格（事件約 1.5 秒防抖，安裝過程的大量寫入只觸發一次刷新）。啟動後才建立的 `~/Applications` 會被掃描發現，但要到下次啟動才會納入監看。
- 找不到任何 App 的掃描結果不會被快取：空結果視為短暫失敗，下次觸發時會重新掃描，而不是把所有 App 藏起來。

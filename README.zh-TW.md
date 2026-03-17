# 🚀 Launchpad

[English](./README.md) | 繁體中文

一個使用 SwiftUI 和 TCA (The Composable Architecture) 打造的現代化 macOS 應用程式啟動器。靈感來自 macOS 內建的 Launchpad 以及 LaunchOS。

![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ 特色功能

- **📊 應用程式網格** - 精美網格佈局，展示所有已安裝的應用程式
- **🔍 快速搜尋** - 依據名稱即時尋找應用程式
- **📁 智慧資料夾** - 透過拖放輕鬆將應用程式整理至自定義資料夾
- **🔄 直覺拖放** - 支援重新排列應用程式與拖曳合併資料夾
- **📂 多路徑掃描** - 自動掃描 `/Applications`、`/System/Applications`、`~/Applications` 等標準目錄
- **💾 自動儲存** - 資料夾與排列順序會自動保存，無需手動存檔
- **🎨 原生介面** - 完美整合 macOS 毛玻璃模糊特效（Native Blur Effects）
- **⌨️ 快捷鍵支援** - `ESC` 清除搜尋、支援右鍵選單

## 🛠 安裝指南

### 快速安裝（推薦）

```bash
# 複製儲存庫
git clone https://github.com/Poseidoncode/Launchpad.git
cd Launchpad

# 編譯並安裝至應用程式資料夾
./install.sh
```

### 手動編譯

```bash
# 建置 App
./build-app.sh

# 複製到應用程式目錄
cp -r build/Launchpad.app /Applications/
```

### 開發者執行

```bash
# 透過 Swift CLI 執行
swift build
.build/debug/Launchpad

# 或使用 Xcode 開啟
open Package.swift
```

## 📖 使用說明

### 基本操作

| 行動     | 操作方式               |
| -------- | ---------------------- |
| 啟動 App | 點擊應用程式圖示       |
| 搜尋 App | 直接在搜尋列輸入關鍵字 |
| 清除搜尋 | 按下 `ESC` 鍵          |
| 重新整理 | 點擊工具列中的重整按鈕 |

### 資料夾管理

| 行動         | 操作方式                           |
| ------------ | ---------------------------------- |
| 建立資料夾   | 將一個 App 拖曳到另一個 App 上面   |
| 建立空資料夾 | 點擊工具列的「+資料夾」按鈕        |
| 加入 App     | 將 App 拖曳進資料夾                |
| 開啟資料夾   | 點擊資料夾圖示                     |
| 修改名稱     | 開啟資料夾後，點擊標題旁的鉛筆圖示 |
| 從資料夾移出 | 在 App 上按右鍵 → 「從資料夾移除」 |
| 刪除資料夾   | 在資料夾上按右鍵 → 「刪除資料夾」  |
| 退出資料夾   | 按下 `ESC` 或點擊返回按鈕          |

### 編輯模式

點擊工具列的 `⇅` 按鈕進入編輯模式：

- 拖曳 App 以自定義排列順序
- 將 App 拖曳至彼此上方以合併為資料夾
- 編輯完成後點擊勾選按鈕退出

### 鍵盤快捷鍵

| 快捷鍵    | 功能                  |
| --------- | --------------------- |
| `ESC`     | 清除搜尋 / 退出資料夾 |
| `Cmd + F` | 開啟搜尋視窗          |
| `Cmd + ,` | 開啟設定介面          |

## 🏗 技術架構

```
Launchpad/
├── App/
│   └── LaunchpadApp.swift          # App 入口點
├── Features/
│   ├── AppGrid/
│   │   ├── AppGridFeature.swift    # TCA Feature (狀態管理)
│   │   └── AppGridView.swift       # SwiftUI 視圖
│   ├── Search/
│   │   ├── SearchFeature.swift
│   │   └── SearchView.swift
│   └── Settings/
│       ├── SettingsFeature.swift
│       └── SettingsView.swift
├── Models/
│   ├── AppItem.swift               # 應用程式模型
│   ├── Folder.swift                # 資料夾模型
│   └── UserPreferences.swift       # 使用者偏好設定
├── Services/
│   ├── AppScanner.swift            # 系統程式掃描服務
│   └── FileSearcher.swift          # Spotlight 檔案搜尋整合
└── Shared/
    └── Extensions/
```

## 🔧 技術棧

- **SwiftUI** - 聲明式 UI 框架
- **TCA (The Composable Architecture)** - 穩定且具測試性的狀態管理
- **Combine** - 響應式編程處理非同步事件
- **FileManager** - 檔案系統操作
- **Spotlight API** - 高效檔案檢索
- **NSWorkspace** - 應用程式生命週期管理

## 🧪 測試說明

```bash
# 執行所有測試
swift test

# 執行特定測試
swift test --filter LaunchpadTests
```

## 📝 授權聲明

Copyright (c) 2024 Poseidoncode. 採用 [CC BY 4.0](./LICENSE) 授權。

## 🙏 致謝

- 靈感源自 [LaunchOS](https://launchosapp.com/)
- 感謝 [Point-Free 的 TCA 框架](https://github.com/pointfreeco/swift-composable-architecture)

---

Made with ❤️ for macOS

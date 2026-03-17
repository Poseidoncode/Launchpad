# 🚀 Launchpad

English | [繁體中文](./README.zh-TW.md)

A modern macOS application launcher built with SwiftUI and TCA (The Composable Architecture). Inspired by macOS Launchpad and LaunchOS.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ Features

- **📊 Application Grid** - Beautiful grid layout displaying all your applications
- **🔍 Instant Search** - Quickly find apps by name
- **📁 Smart Folders** - Organize apps into custom folders with drag-and-drop
- **🔄 Intuitive Drag & Drop** - Rearrange apps and create folders by dragging
- **📂 Multi-Path Scanning** - Automatically scans `/Applications`, `/System/Applications`, `~/Applications`, and more
- **💾 Automatic Persistence** - Folders and arrangements are saved automatically without manual steps
- **🎨 Native UI** - Blends seamlessly with macOS using native blur effects (Vibrant styling)
- **⌨️ Keyboard Shortcuts** - `ESC` to clear search or exit folders, context menu support

## 🛠 Installation

### Quick Install (Recommended)

```bash
# Clone the repository
git clone https://github.com/Poseidoncode/Launchpad.git
cd Launchpad

# Build and install to Applications folder
./install.sh
```

### Manual Install

```bash
# Build the app binary
./build-app.sh

# Copy or move to Applications
cp -r build/Launchpad.app /Applications/
```

### Run for Developers

```bash
# Build and run via Swift CLI
swift build
.build/debug/Launchpad

# Or open in Xcode for debugging
open Package.swift
```

## 📖 Usage Guide

### Basic Operations

| Action       | How To                           |
| ------------ | -------------------------------- |
| Launch App   | Click on the app icon            |
| Search Apps  | Type in the search bar instantly |
| Clear Search | Press the `ESC` key              |
| Refresh Apps | Click refresh button in toolbar  |

### Folder Management

| Action                 | How To                               |
| ---------------------- | ------------------------------------ |
| Create Folder          | Drag one app onto another app        |
| Create Empty Folder    | Click folder+ button in toolbar      |
| Add App to Folder      | Drag an app onto an existing folder  |
| Open Folder            | Click on the folder icon             |
| Rename Folder          | Open folder → Click pencil icon      |
| Remove App from Folder | Right-click app → Remove from Folder |
| Delete Folder          | Right-click folder → Delete Folder   |
| Exit Folder            | Press `ESC` or click the back button |

### Edit Mode

Click the `⇅` button in the toolbar to enter edit mode:

- Drag apps to rearrange their position
- Drag apps onto each other to create new folders
- Drag apps onto folders to add them
- Click the checkmark button to exit edit mode and save

### Keyboard Shortcuts

| Shortcut  | Action                     |
| --------- | -------------------------- |
| `ESC`     | Clear search / Exit folder |
| `Cmd + F` | Open search window         |
| `Cmd + ,` | Open settings              |

## 🏗 Architecture Overview

```
Launchpad/
├── App/
│   └── LaunchpadApp.swift          # App entry point
├── Features/
│   ├── AppGrid/
│   │   ├── AppGridFeature.swift    # TCA Feature (state management)
│   │   └── AppGridView.swift       # SwiftUI Views
│   ├── Search/
│   │   ├── SearchFeature.swift
│   │   └── SearchView.swift
│   └── Settings/
│       ├── SettingsFeature.swift
│       └── SettingsView.swift
├── Models/
│   ├── AppItem.swift               # Application data model
│   ├── Folder.swift                # Folder structure model
│   └── UserPreferences.swift       # Settings persistence model
├── Services/
│   ├── AppScanner.swift            # Scanning system applications
│   └── FileSearcher.swift          # Spotlight API integration
└── Shared/
    └── Extensions/
```

## 🔧 Tech Stack

- **SwiftUI** - Declarative UI framework
- **TCA (The Composable Architecture)** - Robust and testable state management
- **Combine** - Reactive events handling
- **FileManager** - System file operations
- **Spotlight API** - High-performance file indexing
- **NSWorkspace** - Application lifecycle and launching

## 🧪 Testing

```bash
# Run all unit and integration tests
swift test

# Run specific test target
swift test --filter LaunchpadTests
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Open a Pull Request

## 📝 License

Copyright (c) 2024 Poseidoncode. Licensed under [CC BY 4.0](./LICENSE).

## 🙏 Acknowledgments

- Inspired by [LaunchOS](https://launchosapp.com/)
- Built with [Point-Free's TCA framework](https://github.com/pointfreeco/swift-composable-architecture)

---

Made with ❤️ for macOS

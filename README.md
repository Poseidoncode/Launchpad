# 🚀 Launchpad

A modern macOS application launcher built with SwiftUI and TCA (The Composable Architecture). Inspired by macOS Launchpad and LaunchOS.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ Features

- **📊 Application Grid** - Beautiful grid layout displaying all your applications
- **🔍 Instant Search** - Quickly find apps by name
- **📁 Smart Folders** - Organize apps into custom folders with drag-and-drop
- **🔄 Drag & Drop** - Rearrange apps and create folders by dragging
- **📂 Multi-Directory Scanning** - Scans `/Applications`, `/System/Applications`, `~/Applications`, and more
- **💾 Persistent Storage** - Folders and arrangements are saved automatically
- **🎨 Native UI** - Blends seamlessly with macOS using native blur effects
- **⌨️ Keyboard Shortcuts** - ESC to clear search, context menu support

## 📸 Screenshots

### Main Grid View
```
┌─────────────────────────────────────────────┐
│  🔍 Search...                               │
├─────────────────────────────────────────────┤
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐      │
│  │ 📁│ │ 📱│ │ 📱│ │ 📱│ │ 📱│ │ 📱│      │
│  │Uti│ │Saf│ │Mai│ │Cal│ │Not│ │Pho│      │
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘      │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐      │
│  │ 📱│ │ 📱│ │ 📱│ │ 📱│ │ 📱│ │ 📱│      │
│  │Map│ │Mus│ │TV │ │New│ │Sto│ │Pre│      │
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘      │
└─────────────────────────────────────────────┘
```

### Folder View
```
┌─────────────────────────────────────────────┐
│  ← Utilities                      ✏️ 🗑️    │
├─────────────────────────────────────────────┤
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐                   │
│  │ 📱│ │ 📱│ │ 📱│ │ 📱│                   │
│  │Cal│ │Ter│ │Act│ │Dic│                   │
│  └───┘ └───┘ └───┘ └───┘                   │
└─────────────────────────────────────────────┘
```

## 🛠 Installation

### Quick Install (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourusername/Launchpad.git
cd Launchpad

# Build and install
./install.sh
```

### Manual Install

```bash
# Build the app
./build-app.sh

# Copy to Applications
cp -r build/Launchpad.app /Applications/
```

### Run from Source

```bash
# Build and run
swift build
.build/debug/Launchpad

# Or open in Xcode
open Package.swift
```

## 📖 Usage

### Basic Operations

| Action | How To |
|--------|--------|
| Launch App | Click on the app icon |
| Search Apps | Type in the search bar |
| Clear Search | Press `ESC` key |
| Refresh Apps | Click refresh button in toolbar |

### Folder Management

| Action | How To |
|--------|--------|
| Create Folder | Drag one app onto another app |
| Create Empty Folder | Click folder+ button in toolbar |
| Add App to Folder | Drag app onto a folder |
| Open Folder | Click on the folder |
| Rename Folder | Open folder → Click pencil icon |
| Remove App from Folder | Right-click app → Remove from Folder |
| Delete Folder | Right-click folder → Delete Folder |
| Exit Folder | Press `ESC` or click back button |

### Edit Mode

Click the `⇅` button in the toolbar to enter edit mode:

- Drag apps to rearrange them
- Drag apps onto each other to create folders
- Drag apps onto folders to add them
- Click the checkmark button to exit edit mode

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `ESC` | Clear search / Exit folder |
| `Cmd+F` | Open search window |
| `Cmd+,` | Open settings |

## 🏗 Architecture

```
Launchpad/
├── App/
│   └── LaunchpadApp.swift          # App entry point
├── Features/
│   ├── AppGrid/
│   │   ├── AppGridFeature.swift    # TCA feature (state management)
│   │   └── AppGridView.swift       # SwiftUI views
│   ├── Search/
│   │   ├── SearchFeature.swift
│   │   └── SearchView.swift
│   └── Settings/
│       ├── SettingsFeature.swift
│       └── SettingsView.swift
├── Models/
│   ├── AppItem.swift               # App model
│   ├── Folder.swift                # Folder model
│   └── UserPreferences.swift       # Settings model
├── Services/
│   ├── AppScanner.swift            # Scan installed apps
│   └── FileSearcher.swift          # Spotlight file search
└── Shared/
    └── Extensions/
```

## 🔧 Tech Stack

- **SwiftUI** - Declarative UI framework
- **TCA (The Composable Architecture)** - State management
- **Combine** - Reactive programming
- **FileManager** - File system operations
- **Spotlight API** - File search
- **NSWorkspace** - App launching

## 🧪 Testing

```bash
# Run all tests
swift test

# Run specific test
swift test --filter LaunchpadTests
```

### Test Coverage

- Unit tests for TCA reducers
- App scanner tests
- Folder management tests
- User preferences tests
- E2E workflow tests

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [LaunchOS](https://launchosapp.com/)
- Built with [Point-Free's TCA](https://github.com/pointfreeco/swift-composable-architecture)

## 📮 Feedback

If you have any feedback or suggestions, please open an issue on GitHub.

---

Made with ❤️ for macOS
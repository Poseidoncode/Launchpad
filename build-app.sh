#!/bin/bash

# Launchpad Build Script
# 建立可執行的 macOS .app 應用程式

set -e

APP_NAME="Launchpad"
VERSION="1.0.0"
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"

echo "🚀 Building ${APP_NAME}..."

# 編譯 release 版本
echo "📦 Compiling release build..."
swift build -c release

# 創建 .app 結構
echo "📁 Creating app bundle structure..."
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# 複製可執行文件
echo "📋 Copying executable..."
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# 創建 Info.plist
echo "📝 Creating Info.plist..."
cat > "${APP_DIR}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.launchpad.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. All rights reserved.</string>
    <key>NSMainStoryboardFile</key>
    <string></string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# 創建 PkgInfo
echo "📝 Creating PkgInfo..."
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# 使用專案提供的 PNG 建立 macOS 應用程式圖示
echo "🎨 Creating app icon..."
python3 << 'PYTHON_SCRIPT'
import os
import subprocess
import sys
import shutil

app_dir = "build/Launchpad.app/Contents/Resources"
iconset_dir = "build/icon.iconset"
source_icon = "src/asset/icon.png"

if not os.path.exists(source_icon):
    print(f"Source icon not found: {source_icon}", file=sys.stderr)
    sys.exit(1)

# 創建 iconset 目錄
os.makedirs(iconset_dir, exist_ok=True)

icon_specs = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for filename, size in icon_specs:
    output_path = f"{iconset_dir}/{filename}"
    result = subprocess.run(
        [
            "sips",
            "-s",
            "format",
            "png",
            "--resampleWidth",
            str(size),
            source_icon,
            "--out",
            output_path,
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)

# 轉換為 icns
result = subprocess.run(
    ["iconutil", "-c", "icns", "-o", f"{app_dir}/AppIcon.icns", iconset_dir],
    capture_output=True,
    text=True,
)
if result.returncode != 0:
    print(result.stderr, file=sys.stderr)
    sys.exit(result.returncode)

# 清理
shutil.rmtree(iconset_dir, ignore_errors=True)
PYTHON_SCRIPT

# 設定權限
echo "🔐 Setting permissions..."
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# 完成
echo ""
echo "✅ Build complete!"
echo ""
echo "📍 App location: $(pwd)/${APP_DIR}"
echo ""
echo "🚀 To run:"
echo "   open ${APP_DIR}"
echo ""
echo "📦 To install to Applications:"
echo "   cp -r ${APP_DIR} /Applications/"
echo ""

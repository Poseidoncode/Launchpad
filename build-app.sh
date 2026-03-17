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

# 創建簡單的應用程式圖示
echo "🎨 Creating app icon..."
python3 << 'PYTHON_SCRIPT'
import os
import subprocess

app_dir = "build/Launchpad.app/Contents/Resources"
iconset_dir = "build/icon.iconset"

# 創建 iconset 目錄
os.makedirs(iconset_dir, exist_ok=True)

# 創建簡單的 PNG 圖示 (使用 sips 或 defaults)
# 這裡我們創建一個基本的圖示
for size in [16, 32, 64, 128, 256, 512]:
    icon_path = f"{iconset_dir}/icon_{size}x{size}.png"
    # 使用一個佔位圖示
    subprocess.run([
        "sips", "-s", "format", "png",
        "--resampleWidth", str(size),
        "-o", icon_path,
        "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"
    ], capture_output=True)
    
    # 創建 @2x 版本
    if size <= 256:
        icon_path_2x = f"{iconset_dir}/icon_{size}x{size}@2x.png"
        subprocess.run([
            "sips", "-s", "format", "png",
            "--resampleWidth", str(size * 2),
            "-o", icon_path_2x,
            "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"
        ], capture_output=True)

# 轉換為 icns
subprocess.run(["iconutil", "-c", "icns", "-o", f"{app_dir}/AppIcon.icns", iconset_dir], capture_output=True)

# 清理
import shutil
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
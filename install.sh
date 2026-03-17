#!/bin/bash

# Launchpad Install Script
# 將 Launchpad 安裝到 /Applications 目錄

set -e

APP_NAME="Launchpad"
BUILD_DIR="build/${APP_NAME}.app"
INSTALL_DIR="/Applications/${APP_NAME}.app"

echo "🚀 Installing ${APP_NAME}..."
echo ""

# 檢查是否已經編譯
if [ ! -d "$BUILD_DIR" ]; then
    echo "📦 Building ${APP_NAME} first..."
    ./build-app.sh
    echo ""
fi

# 檢查是否已經存在
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  ${APP_NAME} is already installed."
    read -p "Do you want to replace it? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled."
        exit 1
    fi
    echo "🗑️  Removing old version..."
    rm -rf "$INSTALL_DIR"
fi

# 複製到 Applications
echo "📋 Copying to /Applications..."
cp -r "$BUILD_DIR" "/Applications/"

# 驗證安裝
if [ -d "$INSTALL_DIR" ]; then
    echo ""
    echo "✅ ${APP_NAME} installed successfully!"
    echo ""
    echo "📍 Location: $INSTALL_DIR"
    echo ""
    echo "🚀 To launch:"
    echo "   open $INSTALL_DIR"
    echo ""
    echo "💡 Tip: You can also find it in Launchpad or Spotlight search."
    echo ""
else
    echo "❌ Installation failed."
    exit 1
fi
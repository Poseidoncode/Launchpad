#!/bin/bash
set -e

APP_NAME="Launchpad"
REPO_URL="https://github.com/Poseidoncode/Launchpad.git"

# If not inside the repo, clone to a temp dir
if [ ! -f "Package.swift" ]; then
    TMPDIR=$(mktemp -d)
    echo "📦 Cloning ${APP_NAME}..."
    git clone --depth 1 "$REPO_URL" "$TMPDIR"
    cd "$TMPDIR"
    trap "rm -rf \"$TMPDIR\"" EXIT
fi

echo "🚀 Installing ${APP_NAME}..."

# Build
./build-app.sh

# Remove existing install if present
if [ -d "/Applications/${APP_NAME}.app" ]; then
    echo "⚠️  Replacing existing installation..."
    rm -rf "/Applications/${APP_NAME}.app"
fi

# Install
cp -r "build/${APP_NAME}.app" /Applications/

echo ""
echo "✅ ${APP_NAME} installed to /Applications/"
echo "🚀 Run: open /Applications/${APP_NAME}.app"

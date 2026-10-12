#!/bin/bash
set -euo pipefail

APP_NAME="Launchpad"
REPO_URL="https://github.com/Poseidoncode/Launchpad.git"
INSTALL_DIR="${LAUNCHPAD_INSTALL_DIR:-${HOME}/Applications/${APP_NAME}.app}"
INSTALL_PARENT="$(dirname "$INSTALL_DIR")"
repo_dir=""
stage_dir=""
backup_dir=""

cleanup() {
    local exit_code=$?

    if [[ -n "$stage_dir" && -e "$stage_dir" ]]; then
        rm -rf "$stage_dir" || true
    fi
    if [[ -n "$backup_dir" && -e "$backup_dir" && ! -e "$INSTALL_DIR" && ! -L "$INSTALL_DIR" ]]; then
        mv "$backup_dir" "$INSTALL_DIR" || true
    fi
    if [[ -n "$repo_dir" && -d "$repo_dir" ]]; then
        rm -rf "$repo_dir" || true
    fi

    exit "$exit_code"
}
trap cleanup EXIT

# If not inside the repository, clone to a temporary directory.
if [[ ! -f "Package.swift" || ! -f "build-app.sh" ]]; then
    repo_dir=$(mktemp -d "${TMPDIR:-/tmp}/launchpad-install.XXXXXX")
    echo "📦 Cloning ${APP_NAME}..."
    git clone --depth 1 "$REPO_URL" "$repo_dir"
    cd "$repo_dir"
fi

echo "🚀 Installing ${APP_NAME}..."
./build-app.sh

BUILD_APP_DIR="build/${APP_NAME}.app"
if [[ ! -d "$BUILD_APP_DIR" ]]; then
    echo "❌ Build did not produce ${BUILD_APP_DIR}" >&2
    exit 1
fi

# Stage the complete bundle beside the destination before replacing it. Keep a
# backup until the replacement is in place so failed copies preserve the old app.
mkdir -p "$INSTALL_PARENT"
stage_dir="$(mktemp -d "${INSTALL_PARENT}/.${APP_NAME}.app.new.XXXXXX")"
rmdir "$stage_dir"
backup_dir="$(mktemp -d "${INSTALL_PARENT}/.${APP_NAME}.app.backup.XXXXXX")"
rmdir "$backup_dir"
ditto "$BUILD_APP_DIR" "$stage_dir"

if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
    echo "⚠️  Replacing existing installation..."
    mv "$INSTALL_DIR" "$backup_dir"
fi
mv "$stage_dir" "$INSTALL_DIR"
stage_dir=""
rm -rf "$backup_dir"
backup_dir=""

printf '\n✅ %s installed to %s\n' "$APP_NAME" "$INSTALL_DIR"
printf '🚀 Run: open "%s"\n' "$INSTALL_DIR"

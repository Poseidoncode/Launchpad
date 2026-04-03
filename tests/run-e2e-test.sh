#!/bin/bash

# E2E 測試腳本 - 需要授權輔助訪問

echo "=== Launchpad E2E 測試 ==="
echo ""
echo "⚠️  注意：此測試需要授權 AppleScript 的輔助訪問權限"
echo ""
echo "步驟："
echo "1. 打開 '系統偏好設定' > '安全性與隱私權' > '隱私權'"
echo "2. 選擇 '輔助使用'"
echo "3. 添加 '終端機' 或你使用的終端應用到列表"
echo "4. 重新運行此腳本"
echo ""

# 檢查應用是否存在
if [ ! -d "build/Launchpad.app" ]; then
    echo "❌ 應用不存在，請先構建："
    echo "   swift build -c release && ./build-app.sh"
    exit 1
fi

echo "✓ 應用已找到"
echo ""

# 清除之前的應用數據
echo "🧹 清除應用數據..."
rm -rf ~/Library/Application\ Support/Launchpad

# 啟動應用
echo "🚀 啟動應用..."
open build/Launchpad.app

sleep 3

# 檢查應用是否運行
if pgrep -f "Launchpad" > /dev/null; then
    echo "✓ 應用正在運行"
else
    echo "❌ 應用未啟動"
    exit 1
fi

echo ""
echo "=== 自動測試（需要輔助訪問權限） ==="
echo ""

#嘗試運行 AppleScript
osascript tests/e2e-test.applescript 2>&1

echo ""
echo "=== 手動測試指引 ==="
echo ""
echo "請按照 tests/ManualTestChecklist.md 進行手動測試"
echo ""
echo "測試完成後，請回報結果。"

# 提供關閉應用的選項
read -p "是否關閉應用？(y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    pkill -f "Launchpad"
    echo "✓ 應用已關閉"
fi
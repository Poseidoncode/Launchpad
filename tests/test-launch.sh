#!/bin/bash
set -euo pipefail

# 基本測試 - 不需要輔助訪問權限

echo "=== Launchpad 基本測試 ==="
echo ""

# 1. Preserve existing UserDefaults; this smoke test must not delete user data.
# 2. Build the app once; build-app.sh performs the release build itself.
echo "📦 構建應用..."
./build-app.sh

# 3. Launch the app
echo "🚀 啟動應用..."
open build/Launchpad.app

sleep 3

# 4. 檢查應用是否運行
if pgrep -x "Launchpad" > /dev/null; then
    echo "✅ PASS: 應用成功啟動"
else
    echo "❌ FAIL: 應用未啟動"
    exit 1
fi

# 5. 檢查應用 CPU 使用率
echo ""
echo "📊 檢查性能..."
process_id="$(pgrep -x "Launchpad" | head -n 1)"
ps -p "$process_id" -o pcpu=,rss= | awk '{printf "CPU: %.1f%%, Memory: %.1fMB\n", $1, $2 / 1024}'

# 6. 等待用戶手動測試
echo ""
echo "=== 需要手動測試的功能 ==="
echo ""
echo "請測試以下功能："
echo ""
echo "1️⃣  背景點擊測試："
echo "   - 創建一個 Folder（點擊工具列的 folder.badge.plus 按鈕）"
echo "   - 打開 Folder"
echo "   - 尝試點擊背景區域關閉"
echo ""
echo "2️⃣  性能測試："
echo "   - 打開包含多個 apps 的 Folder"
echo "   - 觀察是否有卡頓"
echo ""
echo "3️⃣  ESC 鍵測試："
echo "   - 打開 Folder"
echo "   - 按 ESC 鍵"
echo "   - 檢查是否關閉"
echo ""
echo "測試完成後，請回報結果。"
echo ""

# 提供關閉應用的選項
read -p "測試完成後是否關閉應用？(y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    pkill -x "Launchpad"
    echo "✓ 應用已關閉"
fi

echo ""
echo "測試結束。"
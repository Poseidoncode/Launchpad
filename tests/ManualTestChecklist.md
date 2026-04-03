# 手動測試清單 - Bug 修復驗證

## 問題描述
1. 打開資料夾時會卡頓
2. 點擊 Modal 背景無法關閉

## 測試準備

### 1. 啟動應用
```bash
# 重新安裝應用
rm -rf ~/Library/Application\ Support/Launchpad
swift build -c release && ./build-app.sh
open build/Launchpad.app
```

### 2. 創建測試資料夾
- 點擊工具列的 "folder.badge.plus" 按鈕
- 創建一個名為 "Test Folder" 的資料夾
- 添加 5-10 個 apps 到資料夾（拖拽 apps 到 folder）

---

## 測試 1：背景點擊關閉 Modal

### 步驟：
1. 點擊 "Test Folder" 打開 Modal
2. 觀察 Modal 的外觀（是否有背景區域）
3. **嘗試點擊 Modal 的背景區域**（深色模糊區域）
4. 檢查是否關閉 Modal

### 預期結果：
- ✓ Modal 能夠通過點擊背景關閉
- ✓ ESC 鍵能夠關閉 Modal
- ✓ "Close" 按鈕能夠關閉 Modal

### 實際結果：
- [ ] 通過
- [ ] 失敗（描述：________________）

---

## 測試 2：性能（打開資料夾卡頓）

### 步驟：
1. 打開包含 5-10 個 apps 的資料夾
2. 觀察打開過程是否有明顯卡頓
3. 觀察 Modal 內的 apps 渲染是否流暢

### 預期結果：
- ✓ 打開 Modal 響應迅速（< 1 秒）
- ✓ Apps 圖標渲染流暢
- ✓ 沒有明顯的 UI 卡頓

### 實際結果：
- [ ] 通過
- [ ] 失敗（卡頓時間：____秒）

---

## 測試 3：多次開關測試

### 步驟：
1. 打開資料夾
2. 關閉資料夾（使用背景點擊或 Close 按鈕）
3. 重複 5 次

### 預期結果：
- ✓ 每次都能正常開關
- ✓ 沒有性能下降

### 實際結果：
- [ ] 通過
- [ ] 失敗（問題：________________）

---

## 修復技術細節

### 修復 1：背景點擊
**問題：** 原本的 `Color.clear` 不接收點擊事件

**修復方案：**
```swift
// FolderDetailView.swift
ZStack {
    // 背景層：使用 GeometryReader 確保覆蓋全區域
    Color.clear
        .frame(width: geometry.size.width, height: geometry.size.height)
        .contentShape(Rectangle()) // 關鍵：使透明區域可點擊
        .onTapGesture { dismiss() }
        .background(VisualEffectView(...))
    
    // 內容層
    VStack(...) { ... }
        .background(
            Rectangle()
                .fill(.ultraThickMaterial)
                .allowsHitTesting(false) // 不阻止背景事件
        )
}
```

### 修復 2：性能
**問題：** folderApps 重複計算

**修復方案：**
- 使用 `appMap` 進行 O(1) 查找
- compactMap 只在 sheet 打開時執行一次

---

## 測試完成後回報

請回報以下信息：
1. 背景點擊測試結果
2. 性能測試結果
3. 是否發現其他問題

**如果測試失敗，請描述：**
- Modal 的具體外觀（截圖）
- 背景區域的位置
- 卡頓的具體時間點
- Folder 中有多少 apps
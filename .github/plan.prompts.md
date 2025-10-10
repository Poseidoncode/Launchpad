
---

### **Tauri Launchpad 開發執行步驟 (v2.0 - 高擬真版)**

#### **第一階段：專案基礎與後端強化 (圖示提取)**

- [ ] 1.  **【環境準備】確認開發環境**
    * (同前) 確認 Rust、Xcode Command Line Tools 及 Node.js 已安裝。

- [ ] 2.  **【專案創建】初始化 Tauri 專案**
    * (同前) 執行 `npm create tauri-app@latest`，選擇 `Vanilla` 模板。

- [ ] 3.  **【視窗配置】設定應用程式視窗**
    * (同前) 在 `src-tauri/tauri.conf.json` 中設定 `fullscreen`, `decorations`, `transparent`。

- [ ] 4.  **【後端依賴】新增 Rust 圖示處理套件**
    * 為了能解析 macOS 的 `.icns` 圖示檔，需要新增依賴。在 `src-tauri/` 目錄下執行 `cargo add icns` 和 `cargo add image`。

- [ ] 5.  **【後端】強化資料結構**
    * 修改 `src-tauri/src/main.rs` 中的 `AppInfo` 結構。除了 `name` 和 `path`，新增一個 `icon: String` 欄位，用來存放 Base64 編碼後的圖示圖片資料。

- [ ] 6.  **【後端】升級應用程式掃描 Command**
    * **(此為關鍵修改)** 重寫 `get_installed_apps` 函式，使其具備圖示提取能力：
        * A. 掃描 `.app` 檔案路徑（同前）。
        * B. 對於每個 `.app` 包，讀取其 `Contents/Info.plist` 檔案來找到圖示檔案的名稱（通常在 `CFBundleIconFile` 鍵中）。
        * C. 組合出 `.icns` 檔案的完整路徑。
        * D. 使用 `icns` 套件讀取 `.icns` 檔案，並選取一張高解析度的圖片（例如 256x256 或 512x512）。
        * E. 使用 `image` 套件將解析出的圖片資料轉換為 PNG 格式，並進行 Base64 編碼，生成一個 `data:image/png;base64,...` 格式的字串。
        * F. 將應用程式的名稱、路徑和 Base64 圖示字串存入 `AppInfo` 結構並回傳。

- [ ] 7.  **【後端】建立應用程式啟動 Command**
    * (同前) 建立 `launch_app` 函式，功能不變。

- [ ] 8.  **【後端】註冊所有 Commands**
    * (同前) 在 `main` 函式中註冊 `get_installed_apps` 和 `launch_app`。

#### **第二階段：前端架構與高階互動 (拖放分組)**

- [ ] 9.  **【前端依賴】安裝前端拖放函式庫**
    * 為了簡化複雜的拖放邏輯，我們需要一個強大的函式庫。在專案根目錄執行 `npm install sortablejs`。

- [ ] 10. **【前端】建立 HTML 介面骨架**
    * (同前) 在 `src/index.html` 中建立 `<div id="app-grid"></div>` 容器。

- [ ] 11. **【前端】撰寫進階 CSS 樣式**
    * 在 `src/styles.css` 中，除了基本樣式外，新增以下樣式：
        * **應用程式圖示**: 樣式化 `<img>` 標籤，使其有圓角和陰影。
        * **拖動中的項目**: 為拖動時的「佔位符」和「影子」項目定義樣式（SortableJS 會自動添加對應的 class）。
        * **資料夾/群組**: 設計資料夾的外觀，包含堆疊的圖示預覽。

- [ ] 12. **【前端】實作資料請求邏輯**
    * (同前) 從 `@tauri-apps/api/tauri` 中引入 `invoke`，並呼叫 `get_installed_apps`。

- [ ] 13. **【前端】建立狀態管理機制**
    * **(此為新增核心步驟)** 在 `src/main.js` 中，建立一個 JavaScript 物件來管理整個 Launchpad 的狀態，例如 `let state = { items: [] }`。`items` 陣列中將存放應用程式物件或群組物件。**後續所有 UI 的變動都應先修改 `state`，再根據 `state` 重新渲染畫面**。

- [ ] 14. **【前端】實作渲染函式**
    * 建立一個 `render()` 函式，其職責是：
        * A. 清空 `#app-grid` 容器。
        * B. 遍歷 `state.items` 陣列。
        * C. 如果項目是應用程式，則創建一個包含 `<img>`（`src` 設為 Base64 圖示字串）和名稱的元素。
        * D. 如果項目是群組，則創建一個資料夾外觀的元素。
        * E. 將所有創建的元素附加到 `#app-grid` 中。

- [ ] 15. **【前端】初始化拖放功能**
    * 引入 `Sortable`。在獲取資料並首次渲染後，使用 `new Sortable(document.getElementById('app-grid'), { ... });` 來初始化拖放功能。

- [ ] 16. **【前端】實作拖放結束邏輯 (排序)**
    * 在 SortableJS 的 `onEnd` 事件回呼中，根據拖放的結果（新的項目順序），更新 `state.items` 陣列的排序，然後呼叫 `render()` 函式重新渲染介面。

- [ ] 17. **【前端】實作群組建立與解散邏輯**
    * **(此為關鍵修改)** 這是最複雜的互動。需要在 SortableJS 的事件中實現：
        * **建立群組**: 監聽拖動事件。當一個應用 A 被拖動到另一個應用 B 上方並懸停一小段時間（可使用 `setTimeout`），則觸發群組建立。在 `state` 中，將 A 和 B 從 `items` 陣列移除，建立一個新的群組物件 `{ type: 'group', apps: [A, B] }`，並將其插入 `items` 陣列。最後呼叫 `render()`。
        * **加入群組**: 當一個應用被拖動到一個已存在的群組上時，更新 `state`，將該應用加入到群組的 `apps` 陣列中。
        * **解散群組**: 當一個應用被從群組中拖出，或群組內的應用少於 2 個時，解散該群組。在 `state` 中，將群組物件移除，並將其內部的應用程式重新放回 `items` 陣列。

- [ ] 18. **【測試】啟動開發模式進行完整測試**
    * 執行 `npm run tauri dev`。
    * **重點測試**:
        * 所有 App 圖示是否正常顯示？
        * 是否可以拖動 App 來改變排序？
        * 將一個 App 拖到另一個上面，是否能自動形成資料夾？
        * 是否能將 App 拖入或拖出資料夾？

- [ ] 19. **【打包】執行應用程式打包**
    * (同前) 所有功能測試無誤後，執行 `npm run tauri build`。

---

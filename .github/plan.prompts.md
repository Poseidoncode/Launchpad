好的，這是一份將 Tauri Launchpad 開發說明書轉換為單一、遞增執行步驟的清單。這份清單旨在提供一個清晰、從頭到尾的開發路線圖。

---

### **Tauri Launchpad 開發執行步驟**

1.  **【環境準備】確認開發環境**
    * 確保系統已安裝並配置好 Rust (透過 `rustup`)、macOS 的 Xcode Command Line Tools 以及 Node.js。

2.  **【專案創建】初始化 Tauri 專案**
    * 執行指令 `npm create tauri-app@latest`。
    * 在互動式提示中，設定專案名稱，並選擇 `Vanilla` (或您偏好的前端框架) 作為模板。

3.  **【視窗配置】設定應用程式視窗**
    * 開啟 `src-tauri/tauri.conf.json` 檔案。
    * 在 `windows` 陣列的第一個物件中，修改以下屬性：
        * `"fullscreen": true`
        * `"decorations": false`
        * `"transparent": true`

4.  **【後端】定義資料結構**
    * 在 `src-tauri/src/main.rs` 中，定義一個公開的 Rust 結構 `AppInfo`，包含 `name: String` 和 `path: String` 兩個欄位。
    * 為此結構加上 `#[derive(serde::Serialize)]` 宏，使其能被序列化傳遞給前端。

5.  **【後端】建立應用程式掃描 Command**
    * 在 `src-tauri/src/main.rs` 中，建立一個名為 `get_installed_apps` 的異步 Rust 函式。
    * 在其上方加上 `#[tauri::command]` 宏。
    * 在此函式中，實作掃描 `/Applications` 和 `~/Applications` 目錄的邏輯，過濾出 `.app` 檔案，並將結果封裝成 `Vec<AppInfo>` 回傳。

6.  **【後端】建立應用程式啟動 Command**
    * 在 `src-tauri/src/main.rs` 中，建立一個名為 `launch_app` 的 Rust 函式，它接收一個 `app_path: String` 參數。
    * 在其上方加上 `#[tauri::command]` 宏。
    * 在此函式中，使用 `std::process::Command` 呼叫 macOS 的 `open` 指令來啟動傳入的應用程式路徑。

7.  **【後端】註冊所有 Commands**
    * 在 `src-tauri/src/main.rs` 的 `main` 函式中，找到 `tauri::Builder`。
    * 在其上鏈式呼叫 `.invoke_handler(tauri::generate_handler![get_installed_apps, launch_app])` 來註冊剛才建立的兩個 Command。

8.  **【前端】安裝 Tauri API 客戶端**
    * 在專案根目錄下，執行指令 `npm install @tauri-apps/api`。

9.  **【前端】建立 HTML 介面骨架**
    * 編輯 `src/index.html` 檔案。
    * 在 `<body>` 內，建立一個主要的容器 `<div>`，並設定其 ID 為 `app-grid`。

10. **【前端】撰寫 CSS 介面樣式**
    * 編輯 `src/styles.css` 檔案。
    * 撰寫樣式以實現全螢幕的半透明模糊背景，並使用 CSS Grid 或 Flexbox 設計 `#app-grid` 的網格佈局及項目樣式。

11. **【前端】實作資料請求與動態渲染**
    * 編輯 `src/main.js` 檔案。
    * 從 `@tauri-apps/api/tauri` 中引入 `invoke` 函式。
    * 在 `DOMContentLoaded` 事件監聽器中，呼叫 `await invoke('get_installed_apps')` 以獲取應用程式列表。
    * 獲取資料後，遍歷回傳的陣列，為每個應用程式動態生成對應的 HTML 元素並插入到 `#app-grid` 容器中。

12. **【前端】綁定使用者互動事件**
    * 在生成每個應用程式元素的同時，為其附加一個 `click` 事件監聽器。
    * 在監聽器的回呼函式中，呼叫 `await invoke('launch_app', { appPath: '點擊項目的路徑' })`，將該應用程式的路徑傳回 Rust 後端執行。

13. **【測試】啟動開發模式進行測試**
    * 執行指令 `npm run tauri dev`。
    * 驗證應用程式是否能正常啟動、顯示所有應用程式圖示，並且點擊後能成功開啟對應的應用程式。

14. **【打包】執行應用程式打包**
    * 當所有功能開發與測試完成後，執行指令 `npm run tauri build`。

15. **【驗證】確認最終產出物**
    * 打包完成後，前往 `src-tauri/target/release/bundle/macos/` 目錄。
    * 確認已成功生成 `.app` 檔案和 `.dmg` 安裝程式，並可獨立運行。
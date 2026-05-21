# 🧋 全球排行榜安全漏洞與作弊防堵稽核報告 (Security Audit Report)

## 1. 漏洞概述 (Executive Summary)

在對「手搖飲大王（Bubble Tea Tycoon）」全球排行榜進行安全稽核時，我們發現即便之前版本對前端渲染進行了 XSS 轉義（`escapeHTML`），排行榜仍被注入了大量異常資料。

經過分析，本系統存在嚴重的 **Google Sheets 公式注入漏洞（Formula/CSV Injection）** 與 **API 伺服器端弱驗證漏洞**。這使得惡意玩家能夠：
1. 通過注入試算表公式來**竊取/外洩整張試算表的所有數據**（包括其他玩家私有的 ID、真實時間戳等），並顯示在前端排行榜中。
2. 注入惡意公式導致試算表運算錯誤（例如 `#REF!`、`#N/A` 等），使整個排行榜服務崩潰。
3. 繞過前端限制，直接向 Google Apps Script API 發送包含虛假日期、作弊金額或惡意字符的請求。

---

## 2. 漏洞技術分析 (Technical Analysis)

### 漏洞 A：Google Sheets 公式注入 (Formula Injection)
* **漏洞原理**：Google 試算表（與 Microsoft Excel 相同）會將以 `=`, `+`, `-`, `@` 開頭的儲存格內容當作**公式**執行。
* **攻擊手法**：惡意玩家以 `name` 或 `id` 欄位輸入像 `=JOIN(" | ", A:E)` 或是其他表格查詢公式。當後端透過 `appendRow` 或 `setValue` 寫入時，Google 試算表會在後台執行該公式，將整張表的內容串接起來顯示在該單元格中。
* **漏洞影響**：當其他正常玩家加載排行榜時，後端 GET 請求將會把公式計算後的結果（包含整張表的洩漏內容）以 JSON 格式回傳，直接洩漏了所有玩家的後台敏感隱私。

### 漏洞 B：API 伺服器端缺乏白名單校驗與零信任
* **漏洞原理**：Google Apps Script 的網頁應用程式（Web App）以 `Anyone` 權限暴露在公網。
* **攻擊手法**：作弊者無需開啟遊戲網頁，可以直接透過命令行（如 `curl`）或 API 測試工具，發送如下 POST 請求：
  ```bash
  curl -X POST https://script.google.com/.../exec \
    -d '{"id":"EVIL_ID","name":"=QUERY(A:Z)","money":9999999999999,"date":"2020-01-01"}'
  ```
  原本的後端 `Code.gs` 只使用正則 `/<[^>]*>/g` 去除 HTML 標籤，該過濾機制對非 HTML 的公式字元完全無效，且未校驗 ID 的字元格式，也盲目信任了客戶端傳入的 `date`。

---

## 3. 修復方案實施 (Remediation Details)

為了解決這些問題，我們對系統架構實施了**縱深防禦（Defense in Depth）**：

### 防禦 1：前端輸入即時過濾與白名單 (Frontend Whitelisting)
1. **店名輸入即時過濾（IntroScene）**：
   - 玩家輸入店名時，若以 `=`, `+`, `-`, `@` 開頭，將被即時清除。
   - 限制不能輸入 `<` 與 `>`，避免任何 HTML 相關的安全隱患。
2. **玩家 ID 強白名單（Leaderboard Modal）**：
   - 限制玩家 ID 僅能使用英數字、底線、連字符及空格（`/^[A-Z0-9 _-]*$/`），且必須以英數字開頭。
   - 這在前端完全杜絕了特殊符號、HTML 標記、腳本注入以及公式字元的輸入。

### 防禦 2：伺服器端 (Google Apps Script) 零信任強固校驗
我們重構了 `Code.gs` 後端邏輯，加入了嚴格的二次驗證：
1. **阻擋公式引導字元**：若 `id` 或 `name` 字串的首個字元為 `=`, `+`, `-`, `@`，後端將直接拒絕寫入。
2. **阻擋 HTML 括號**：若檢測到 `<` 或 `>`，直接拒絕請求。
3. **ID 與店名格式嚴格比對**：
   - ID 必須符合正則 `/^[A-Za-z0-9][A-Za-z0-9 _-]{0,9}$/`，長度 1-10。
   - 店名長度必須介於 1-10 之間，且不為空。
4. **捨棄客戶端傳入日期，由伺服器端生成**：
   - 廢除對 `params.date` 的信任。
   - 在 Apps Script 內部使用 `Utilities.formatDate` 自動抓取 GMT+8（台北時間）的 `yyyy-MM-dd` 日期，防堵日期偽造與日期注入攻擊。
5. **數值合理性校驗**：
   - `money` 必須是有效的有限數值，且大於等於 0、小於等於 1 兆（`1e12`）。
   - 後端強制進行 `Math.floor(money)` 轉為整數存檔，避免浮點數或科學記號作弊。

---

## 4. 給管理者的更新指引 (Administrator Action Required)

由於 Google Sheets 的 Apps Script 代碼儲存在您的個人雲端，**請務必手動更新您的 Apps Script 程式碼**：

1. 開啟您的 Google 試算表 `BobaKing_GlobalRanking`。
2. 點選 **擴充功能 (Extensions)** > **Apps Script**。
3. 將原本的 `Code.gs` 代碼**全部刪除**。
4. 複製並貼上新版 `google-apps-script-guide.md` 中提供的 **重構後安全版 `Code.gs`** 代碼。
5. 修改 `const SHEET_ID = "..."` 為您的試算表 ID。
6. 點選右上角的 **部署 (Deploy)** > **管理部署 (Manage deployments)**。
7. 點選右上角的 **編輯筆圖示 (Edit/Modify)**，並在 **版本 (Version)** 下拉選單選擇 **建立新版本 (New version)**。
8. 點選 **部署 (Deploy)**。
   > [!IMPORTANT]
   > **這一步極其關鍵**！如果不建立「新版本」進行部署，Google Apps Script 將會繼續執行舊的安全漏洞代碼。

---

## 5. 結論 (Conclusion)

本次升級（`v1.2.8`）在**前端防禦**、**伺服器 API 校驗**以及**資料儲存庫誠信**三個維度上完成了全面加固。即便作弊者使用外部工具繞過網頁，也無法突破 Google Apps Script 伺服器端的正則強校驗與公式字符審查，安全隱患已徹底修復。

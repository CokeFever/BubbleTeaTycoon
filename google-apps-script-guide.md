# 🧋 Google Sheets 排行榜 API 設定指南

這個指南將協助你使用 Google Sheets + Google Apps Script (GAS) 建立免費的遊戲排行榜後端。

## 步驟 1：建立 Google Sheet
1. 前往 [Google Sheets](https://sheets.google.com) 建立一個新試算表。
2. 命名為 `BobaKing_GlobalRanking` (或其他你喜歡的名字)。
3. 在第一列 (Row 1) 設定標題：
   - A1: `ID`
   - B1: `Name`
   - C1: `Money`
   - D1: `Date`
   - E1: `Timestamp`
4. 將工作表 (Sheet1) 重新命名為 `Leaderboard`。

## 步驟 2：建立 Apps Script
1. 在試算表中，點擊上方選單的 **擴充功能 (Extensions)** > **Apps Script**。
2. 將編輯器中的程式碼全部刪除，貼上以下代碼：

```javascript
// --- Code.gs START ---
const SHEET_ID = "YOUR_GOOGLE_SHEET_ID"; // **請填入你的試算表 ID** (從網址列複製)
const SHEET_NAME = "Leaderboard";

function doGet(e) {
  return handleRequest(e);
}

function doPost(e) {
  return handleRequest(e);
}

function handleRequest(e) {
  const lock = LockService.getScriptLock();
  lock.tryLock(10000);
  
  try {
    const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
    
    // GET request: Return top 50
    if (!e.postData) {
      const data = sheet.getDataRange().getValues();
      const headers = data.shift(); // Remove header
      
      // Map to JSON
      const result = data.map(row => ({
        id: String(row[0]),
        name: String(row[1]),
        money: Number(row[2]),
        date: String(row[3])
      }));
      
      // Sort by Money DESC
      result.sort((a, b) => b.money - a.money);
      
      // Return Top 50
      const top50 = result.slice(0, 50);
      
      return ContentService.createTextOutput(JSON.stringify(top50))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    // POST request: Add/Update record
    const params = JSON.parse(e.postData.contents);
    
    const rawId = params.id;
    const rawName = params.name;
    const rawMoney = Number(params.money);
    
    // 1. Strict Server-side Type Check
    if (typeof rawId !== 'string' || typeof rawName !== 'string' || isNaN(rawMoney) || !isFinite(rawMoney)) {
      return ContentService.createTextOutput(JSON.stringify({result: 'error', error: 'Invalid Types'}))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    const id = rawId.trim();
    const name = rawName.trim();
    const money = Math.floor(rawMoney); // Force integer to prevent float cheating
    
    // 2. Strict Length Checks
    if (id.length < 1 || id.length > 10 || name.length < 1 || name.length > 10) {
      return ContentService.createTextOutput(JSON.stringify({result: 'error', error: 'Invalid Length'}))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    // 3. Formula Injection (CSV Injection) Prevention
    // Reject if id or name starts with '=', '+', '-', '@'
    const formulaRegex = /^[=\+\-@]/;
    if (formulaRegex.test(id) || formulaRegex.test(name)) {
      return ContentService.createTextOutput(JSON.stringify({result: 'error', error: 'Formula Injection Detected'}))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    // 4. HTML/XSS Brackets Check
    if (id.indexOf('<') !== -1 || id.indexOf('>') !== -1 || name.indexOf('<') !== -1 || name.indexOf('>') !== -1) {
      return ContentService.createTextOutput(JSON.stringify({result: 'error', error: 'HTML Injection Detected'}))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    // 5. Strict ID Regex (Only alphanumeric, spaces, hyphens, underscores, starting with alphanumeric)
    const idRegex = /^[A-Za-z0-9][A-Za-z0-9 _-]{0,9}$/;
    if (!idRegex.test(id)) {
      return ContentService.createTextOutput(JSON.stringify({result: 'error', error: 'Invalid ID Format'}))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    // 6. Reasonable Score Range Limit (0 to 1 Trillion)
    if (money < 0 || money > 1e12) {
      return ContentService.createTextOutput(JSON.stringify({result: 'error', error: 'Score Out of Range'}))
        .setMimeType(ContentService.MimeType.JSON);
    }
    
    // 7. Secure Date Generation on Server Side (GMT+8 Taipei time)
    // This discards client-controlled date parameters to prevent time-tampering/injections
    const date = Utilities.formatDate(new Date(), "GMT+8", "yyyy-MM-dd");
    
    // Check if ID exists to update record instead of spamming duplicates
    const data = sheet.getDataRange().getValues();
    let idExists = false;
    let existingRowIndex = -1;
    
    for (let i = 1; i < data.length; i++) {
      if (String(data[i][0]).trim() === id) {
        idExists = true;
        existingRowIndex = i + 1; // 1-indexed in Google Sheets, +1 due to headers shift
        break;
      }
    }
    
    if (idExists) {
      const currentMoney = Number(data[existingRowIndex - 1][2]);
      // Only update if the new money score is higher
      if (money > currentMoney) {
        sheet.getRange(existingRowIndex, 2).setValue(name); // Column B: Name
        sheet.getRange(existingRowIndex, 3).setValue(money); // Column C: Money
        sheet.getRange(existingRowIndex, 4).setValue(date);  // Column D: Date
        sheet.getRange(existingRowIndex, 5).setValue(new Date()); // Column E: Timestamp
      }
    } else {
      // Append a new row if ID doesn't exist
      sheet.appendRow([id, name, money, date, new Date()]);
    }
    
    return ContentService.createTextOutput(JSON.stringify({result: 'success'}))
      .setMimeType(ContentService.MimeType.JSON);
      
  } catch (e) {
    return ContentService.createTextOutput(JSON.stringify({result: 'error', error: e.toString()}))
      .setMimeType(ContentService.MimeType.JSON);
  } finally {
    lock.releaseLock();
  }
}
// --- Code.gs END ---
```

## 步驟 3：填入 Sheet ID
1. 回到你的 Google Sheet，查看網址列：
   `https://docs.google.com/spreadsheets/d/1BxiMZw...12345/edit#gid=0`
2. `d/` 和 `/edit` 之間的那串亂碼就是 **Sheet ID**。
3. 將它複製並貼到程式碼中的 `const SHEET_ID = "..."` 裡。

## 步驟 4：部署為 Web App
1. 點擊右上角的 **部署 (Deploy)** > **新增部署 (New deployment)**。
2. 點擊左側齒輪圖示 > 選擇 **網頁應用程式 (Web app)**。
3. 設定如下：
   - **說明**：Global Leaderboard API
   - **執行身分 (Execute as)**：**我 (Me)** (重要！)
   - **誰可以存取 (Who has access)**：**任何人 (Anyone)** (重要！這樣才能讓玩家寫入)
4. 點擊 **部署 (Deploy)**。
5. **授權存取**：Google 會跳出警告視窗，點擊 **核對權限** > 選擇你的帳號 > **進階 (Advanced)** > **前往... (不安全/Unsafe)** > **允許 (Allow)**。
6. 複製產生的 **網頁應用程式網址 (Web App URL)**。
   (看起來像 `https://script.google.com/macros/s/.../exec`)

## 步驟 5：更新遊戲代碼
1. 打開 `index.html`。
2. 搜尋 `const GAS_API_URL = ""`。
3. 將你的網址貼進去。
4. 打開 `leaderboard.html` 做同樣的動作。

完成！現在你的遊戲擁有全球排行榜了！🎉

---
description: 如何正確更新遊戲版本號並同步 PWA 快取
---

當需要更新遊戲版本號時（例如從 v1.2.5 更新到 v1.2.6），請務必執行以下步驟以確保 PWA 用戶能收到更新：

1. **修改 `index.html` 中的顯示版本號**：
   - 搜尋 `Bubble Tea Tycoon v` 並更新其後的版本號（通常在選單底部）。

2. **修改 `index.html` 中的更新日誌 (Changelog)**：
   - 在 `Changelog Modal` 區域新增或更新對應版本的內容。

3. **同步修改 `sw.js` 中的快取名稱**：
   - 找到 `const CACHE_NAME = 'bubble-tea-tycoon-v...';`。
   - **必須** 將其中的版本號同步更新。這會觸發 PWA 的 Service Worker 更新機制。

4. **驗證一致性**：
   - 檢查 `index.html` 與 `sw.js` 中的版本字串是否完全一致。

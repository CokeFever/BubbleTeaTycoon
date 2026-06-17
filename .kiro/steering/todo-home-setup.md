---
inclusion: manual
---

# 🏠 回家後待辦事項 (Home Setup TODO)

## ~~1. 確認 GitHub 認證~~ ✅

已成功 push 兩個 repo。

## ~~2. Unity 環境安裝與專案導入~~ ✅

- Unity Hub + Unity 6.5 已安裝
- 專案已成功開啟，Console 零紅色錯誤
- 所有 C# 腳本編譯通過

## 3. 驗證加密存檔（任務清單 1.2 ~ 1.3）

- [ ] 在 Unity 場景中建立 `GameController` GameObject
- [ ] 掛載 `GameManager.cs` 和 `NetworkManager.cs`
- [ ] Play → 確認 Console 輸出存檔成功訊息
- [ ] 確認 `AppData/LocalLow/` 下產生加密存檔

## 4. Google Sheet 重新命名（可選）

舊名稱 `BobaKing_GlobalRanking` 可考慮改為 `BubbleTeaTycoon_GlobalRanking`。
這只影響 PWA 版的 Google Sheet 介面名稱，Unity 版已不使用 GAS。

## 5. 提交後續變更

```bash
git push
git -C BubbleTeaTycoon_Unity push
```

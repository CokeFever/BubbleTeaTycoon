---
inclusion: manual
---

# 🏠 回家後待辦事項 (Home Setup TODO)

## 1. 確認 GitHub 認證

```bash
git push --dry-run
git -C BubbleTeaTycoon_Unity push --dry-run
```

如果認證有問題，重新設定 credential：
```bash
git credential-manager configure
```

## 2. Unity 環境安裝與專案導入

- 安裝 Unity Hub（如尚未安裝）
- 安裝 Unity 2022 LTS 或 Unity 6000.x
- 在 Unity Hub 中「Add project from disk」→ 指向 `BubbleTeaTycoon_Unity/`
- 開啟後確認 `Assets/Scripts/Core` 與 `Assets/Scripts/Network` 下無編譯錯誤
- 注意：`GameState` 中尚未宣告 `carrierBarcode` 欄位（GameManager 已引用），需要補上：
  ```csharp
  public string carrierBarcode = "";
  ```

## 3. 驗證加密存檔（任務清單 1.2 ~ 1.3）

- 建立 `GameController` GameObject
- 掛載 `GameManager.cs` 和 `NetworkManager.cs`
- 執行遊戲，確認 Console 輸出存檔成功訊息

## 4. Google Sheet 重新命名（可選）

舊名稱 `BobaKing_GlobalRanking` 可考慮改為 `BubbleTeaTycoon_GlobalRanking`。
這只影響你自己的 Google Sheet 介面名稱，不影響 Apps Script 運作。

## 5. 提交本次 rename 變更

```bash
git add -A
git commit -m "refactor: rename Boba/BobaKing to BubbleTeaTycoon, update namespace and localStorage keys"
git push

cd BubbleTeaTycoon_Unity
git add -A
git commit -m "refactor: rename BobaTycoon namespace to BubbleTeaTycoon, BobaConfig to GameConfig, update domain to ixo.app"
git push
```

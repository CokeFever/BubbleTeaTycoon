---
inclusion: manual
---

# 🏠 Setup TODO

## ~~1. 確認 GitHub 認證~~ ✅

已成功 push 兩個 repo。

## ~~2. Unity 環境安裝與專案導入~~ ✅

- Unity Hub + Unity 6.5 已安裝
- 專案已成功開啟，Console 零紅色錯誤
- 所有 C# 腳本編譯通過

## ~~3. 驗證加密存檔（任務清單 1.2 ~ 1.3）~~ ✅

- GameController GameObject 已建立
- GameManager + NetworkManager 已掛載
- Play 後 Console 確認存檔成功：`save.dat` 已寫入 AppData/LocalLow
- OnApplicationPause 正確觸發存檔

## ~~4. MCP for Unity 連線~~ ✅

- com.coplaydev.unity-mcp package 已安裝
- MCP Server running on http://127.0.0.1:8080
- Kiro 可透過 MCP 直接操作 Unity Editor（已驗證讀取場景 hierarchy）

## ~~5. UI 骨架建立~~ ✅

- 執行 BubbleTeaTycoon → Setup UI Scene 選單
- 已建立：EventSystem、MainCanvas (1080x1920)、HUDPanel、StreetPanel、StorePanel、ManagePanel、NavigationBar (3 buttons)
- com.unity.ugui package 已加入 manifest

## 6. 下次繼續的待辦

- [ ] 把 `UINavigator` 掛到 MainCanvas，在 Inspector 拖入 StreetPanel/StorePanel/ManagePanel 參照
- [ ] 把 `HUDController` 掛到 HUDPanel，拖入 MoneyText/DayText/LevelText 參照
- [ ] 設定 NavigationBar 三個按鈕的 OnClick → 呼叫 UINavigator 的 SwitchToStreet/SwitchToStore/SwitchToManage
- [ ] Play 測試面板切換是否正常
- [ ] 開始第三階段：點餐與經營邏輯 UI 實作

---
inclusion: manual
---

# 🏠 Setup & Progress TODO

## ✅ 已完成

- [x] GitHub 認證
- [x] Unity Hub + Editor 6.5 安裝
- [x] 專案匯入，零編譯錯誤
- [x] GameController + GameManager + NetworkManager 掛載
- [x] 存檔驗證（save.dat 寫入成功）
- [x] MCP for Unity 連線成功
- [x] UI 骨架建立（Setup UI Scene 選單執行完成）
- [x] com.unity.ugui package 安裝
- [x] Kiro steering 建立（coding conventions, game design, visual style）
- [x] Core systems spec 完成（requirements → design → tasks → 實作）
- [x] Leaderboard spec 完成（requirements + design）
- [x] 所有 C# 核心邏輯實作完成（17 個 .cs 檔案）

## 下次開 Unity 要做的

- [ ] UINavigator 掛到 MainCanvas，拖入 StreetPanel/StorePanel/ManagePanel
- [ ] HUDController 掛到 HUDPanel，拖入 MoneyText/DayText/LevelText
- [ ] NavigationBar 三按鈕 OnClick → UINavigator.SwitchToStreet/Store/Manage
- [ ] Play 測試面板切換
- [ ] 在 ManagePanel 內建子面板：RecipeEditor / ShopUpgrade / Finance / DailyTasks
- [ ] 掛載對應 Controller 腳本並接線

## 後續里程碑

- [ ] POS 點餐視覺呈現（StorePanel 顯示顧客、訂單動畫）
- [ ] 街道場景視覺（StreetPanel 顯示自己的店 + AI 對手）
- [ ] 排行榜後端（Firebase Firestore + Cloud Run API）
- [ ] Firebase Auth 整合（玩家帳號）
- [ ] 美術資源製作（像素風 sprite、動畫）
- [ ] 音效與 BGM
- [ ] Android/iOS build 測試
- [ ] Widget 功能（載具條碼、推薦飲品）

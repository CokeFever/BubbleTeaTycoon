---
inclusion: auto
---

# 遊戲設計決策紀錄

## 排行榜設計

- **排名依據**：月營收（`monthlyMetric`），不使用總資產或永久累積營收
- **重置週期**：現實日曆月（每月 1 號 00:00 UTC 重置）
- **設計理念**：衡量「這個月你經營得多好」而非「你玩了多久」。有錢但不投資回店裡的不算好經營者，每月重新競爭讓新玩家有機會上榜
- **解鎖門檻**：達到特定等級（全原料/設備解鎖後）才開放排行榜功能
- **後端**：Unity 版使用 Firebase Firestore 或 GCP Cloud Run（不使用 Google Apps Script，GAS 僅限 PWA 版）

## 時間系統

- **遊戲步調**：4~6 現實小時 = 1 遊戲天（最終數值待 playtesting 確認）
- **目前程式碼設定**：`GameConfig.REAL_HOURS_PER_GAME_DAY = 4f`
- **排行榜週期與遊戲時間脫鉤**：排行榜用現實日曆月，不用遊戲內月份

## 品牌 / 命名

- 專案名稱統一使用「Bubble Tea Tycoon」，不再使用 Boba King / Boba
- 配料 ID `'boba'` 保留（代表珍珠食材，非品牌名）
- Domain: ixo.app
- C# Namespace: BubbleTeaTycoon.Core / BubbleTeaTycoon.Network
- PWA 版暫不更動（維持 boba-king cache name，未來大改版時再統一）

# Requirements Document

## Introduction

本文件定義《手搖飲大王 (Bubble Tea Tycoon)》Unity 版月營收排行榜系統的需求。排行榜採用現實日曆月結算制度，參考 Clash Royale 天梯賽季設計，以「月營收」衡量玩家經營能力而非累計資產。系統需要正規後端（Firebase Firestore 或 GCP Cloud Run）支援即時排名查詢與月底批次結算。

## Glossary

- **月營收 (monthlyMetric)**：玩家在一個現實日曆月內累積的正向收入總額，作為排行榜排名依據。
- **Season（賽季）**：一個現實日曆月為一個賽季，每月 1 號 00:00 UTC 開始新賽季。
- **Season Best（生涯最佳）**：玩家歷史上曾達到的最高月度排名，永久記錄。
- **即時排行榜**：每 5 分鐘刷新的全服排名，玩家可看到自己的即時名次變動。
- **月底結算**：每月最後一天 23:59 UTC 凍結排名，前 100 名存入歷史紀錄。
- **排行榜解鎖等級**：玩家達到 Lv.15（全原料解鎖）後才能參與排行榜。

## Requirements

### Requirement 1: 排行榜解鎖與資格

**User Story:** 身為玩家，我希望在全部原料解鎖後才看到排行榜，避免前期因差距過大而產生挫折感。

#### Acceptance Criteria

1. WHEN 玩家等級小於 GameConfig.LEADERBOARD_UNLOCK_LEVEL (15) 時，THE 排行榜功能 SHALL 隱藏且不可存取。
2. WHEN 玩家等級達到或超過 LEADERBOARD_UNLOCK_LEVEL 時，THE 排行榜功能 SHALL 解鎖並首次顯示解鎖通知。
3. THE 排行榜 SHALL 僅顯示等級達到 LEADERBOARD_UNLOCK_LEVEL 的玩家資料。

### Requirement 2: 月營收計分與重置

**User Story:** 身為玩家，我希望每月重新計分讓我有機會超越長期玩家，而不是只能看著老玩家佔據排行榜頂端。

#### Acceptance Criteria

1. THE GameManager SHALL 在偵測到現實日曆月份變更時（UTC），先將當前 `monthlyMetric` 上傳至後端作為該月最終分數，再將本地 `monthlyMetric` 重置為 0。
2. THE `monthlyMetric` SHALL 僅累計正向收入（amount > 0 的 AddMoney 呼叫），不扣除支出。
3. THE GameManager SHALL 在 GameState 中記錄 `lastLeaderboardMonth`（"yyyy-MM" 格式），用於判斷月份是否已變更。
4. IF 玩家跨月未上線（如 1 月 28 日離線，2 月 3 日上線），THEN THE 系統 SHALL 視為 1 月分數已結算（以最後上傳紀錄為準），2 月從 0 開始計分。

### Requirement 3: 即時排行榜查詢

**User Story:** 身為玩家，我希望每 5 分鐘看到最新排名，讓我知道自己在全服的即時位置。

#### Acceptance Criteria

1. THE 客戶端 SHALL 每 5 分鐘向後端發送一次排行榜查詢請求。
2. THE 後端 SHALL 回傳當月排行榜的前 100 名，包含每位玩家的：shopName、monthlyMetric、level、rank。
3. THE 客戶端 SHALL 同時回傳當前玩家自己的排名（即使不在前 100 名內）。
4. THE 排行榜顯示 SHALL 包含玩家自己的高亮行，顯示當前名次與月營收。
5. IF 網路不可用，THEN THE 客戶端 SHALL 顯示最後一次成功取得的排行榜快取，並標示「資料非即時」。

### Requirement 4: 月底結算與歷史紀錄

**User Story:** 身為玩家，我希望月底看到最終排名結果，並且我的最佳紀錄被永久保存。

#### Acceptance Criteria

1. THE 後端 SHALL 在每月 1 號 00:00 UTC 執行結算程序：凍結前月排名、存入歷史集合、清除當月即時排行。
2. THE 結算 SHALL 保存前 100 名的完整資料（rank、shopName、monthlyMetric、playerId、level）。
3. WHEN 結算完成後，THE 後端 SHALL 比對每位玩家的本月最終排名與其 `seasonBestRank`，若本月排名更好（數字更小），則更新 `seasonBestRank`。
4. THE 客戶端 SHALL 在月初首次上線時顯示「上月結算報告」，包含玩家上月最終排名、上月營收、以及是否刷新了生涯最佳。

### Requirement 5: 生涯最佳排名 (Season Best)

**User Story:** 身為玩家，我希望我的歷史最佳排名被永久記錄，作為長期目標的追求動力。

#### Acceptance Criteria

1. THE GameState SHALL 儲存 `seasonBestRank` 欄位（int，0 代表從未上榜，1 代表最佳），由後端於結算時更新。
2. THE 客戶端 SHALL 在排行榜介面顯示「Season Best: #N」的徽章。
3. WHEN 玩家的月度最終排名優於（數字小於）當前 `seasonBestRank` 時，THE 系統 SHALL 更新 `seasonBestRank` 並顯示「刷新紀錄」慶祝動畫。
4. IF `seasonBestRank` 為 0（從未上榜），THEN THE 排行榜 SHALL 顯示「尚無紀錄」而非數字。

### Requirement 6: 分數上傳與防作弊

**User Story:** 身為開發者，我需要確保排行榜分數的可信度，防止玩家作弊刷分。

#### Acceptance Criteria

1. THE 客戶端 SHALL 在每次存檔同步時（auto-save、OnApplicationPause、月底結算前）上傳包含 `monthlyMetric`、`clientTimeUnix`、`lastSaveTimeUnix`、設備等級、員工配置、菜單的完整 payload。
2. THE 後端 SHALL 使用 FinanceEngine.CalculateMaxPossibleRevenue 的等效邏輯，計算兩次上傳間的理論最大營收，若玩家的 monthlyMetric 增量超過理論上限 × 1.2（20% 容差），則拒絕更新並記錄警告。
3. IF 後端拒絕更新，THEN THE 客戶端 SHALL 收到失敗回應，不影響本地遊戲進行，但該分數不計入排行榜。
4. THE 後端 SHALL 記錄所有被拒絕的上傳請求（含 playerId、時間戳、聲稱的增量 vs 理論上限），供後續人工審查。

### Requirement 7: 後端架構

**User Story:** 身為開發者，我需要一個能支撐數千 DAU、每 5 分鐘即時查詢、且月底能批次結算的後端架構。

#### Acceptance Criteria

1. THE 後端 SHALL 使用 Firebase Firestore 作為即時排行榜儲存，利用其即時查詢與索引能力。
2. THE 後端 SHALL 使用 GCP Cloud Run 或 Firebase Cloud Functions 作為結算邏輯執行環境。
3. THE 後端 SHALL 設計為 serverless 架構，DAU 為 0 時費用趨近 $0（Cloud Run 縮容至 0、Firestore 按讀寫次數計費）。
4. THE Firestore 資料結構 SHALL 包含：`leaderboard/{currentMonth}/rankings` 集合（即時排行）、`leaderboard/history/{month}` 集合（歷史紀錄）、`players/{playerId}` 文件（含 seasonBestRank）。
5. THE 月底結算 SHALL 由 Cloud Scheduler 觸發（每月 1 號 00:01 UTC），而非依賴客戶端觸發。

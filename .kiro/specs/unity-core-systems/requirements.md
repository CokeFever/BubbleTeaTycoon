# Requirements Document

## Introduction

本文件定義手機放置/經營遊戲《手搖飲大王 (Bubble Tea Tycoon)》的純 C# 邏輯系統需求。這些系統不依賴 Unity Editor 即可運行，涵蓋：完整的 GameState 資料模型、流行熱潮事件系統 (EventManager)、每日打卡/真實購茶獎勵系統、菜單管理邏輯、以及經驗值與等級系統。遊戲設定於台北永吉路 30 巷，目標玩家為台灣 13-35 歲族群，採用 C# Actions/Events 的事件驅動架構。

## Glossary

- **GameState**：可序列化的資料類別，保存所有玩家進度，作為遊戲的唯一資料真實來源 (Single Source of Truth)。
- **EventManager**：負責觸發、追蹤與結束流行熱潮事件的靜態邏輯類別。
- **TrendEvent**：代表暫時性市場現象的資料結構，可提升特定原料吸引力、放寬價格敏感度、增加客流量。
- **CheckInManager**：驗證並處理每日真實購茶打卡請求的靜態邏輯類別。
- **MenuManager**：負責配方建立、編輯、解鎖驗證與定價規則的靜態邏輯類別。
- **LevelSystem**：計算升級所需經驗值、處理各來源經驗獲取、判定升級解鎖的靜態邏輯類別。
- **GameConfig**：存放所有原料資料、常數與遊戲參數的靜態配置類別。
- **FinanceEngine**：現有的靜態類別，負責計算經濟產出（成本、吸引力、價格係數、月度財報）。
- **CustomDrink**：可序列化結構，代表玩家自創的飲料配方，含底茶、奶類、配料與售價。
- **Ingredient**：可序列化結構，代表原料（底茶、奶類或配料），含成本、吸引力、解鎖等級等屬性。
- **遊戲天 (Game_Day)**：遊戲內時間單位，1 遊戲天等於 4 現實小時。
- **電子載具條碼 (Carrier_Barcode)**：玩家的台灣電子發票載具條碼（格式：`/XXXXXXX`，7 碼英數字）。
- **研究點數 (Research_Point)**：透過每日打卡獲取的貨幣，可加速解鎖特定原料。

## Requirements

### Requirement 1: 完整 GameState 資料模型

**User Story:** 身為開發者，我需要 GameState 類別包含 GameManager、EventManager、CheckInManager 所參照的所有欄位，以確保遊戲的唯一資料來源完整且可序列化。

#### Acceptance Criteria

1. THE GameState SHALL 宣告一個型別為 string 的 `carrierBarcode` 欄位，預設值為空字串，用於儲存玩家的台灣電子發票載具條碼（格式：`/` 加 7 碼大寫英數字）。
2. THE GameState SHALL 宣告一個型別為 string 的 `activeEventId` 欄位，預設值為空字串，用於追蹤當前啟用的流行熱潮事件；空字串代表無活躍事件。
3. THE GameState SHALL 宣告一個型別為 int 的 `activeEventRemainingDays` 欄位，預設值為 0，有效範圍為 0 至 3，用於追蹤事件剩餘持續天數。
4. THE GameState SHALL 宣告一個型別為 int 的 `daysSinceLastEvent` 欄位，預設值為 0，有效範圍為 0 至 35，用於追蹤距上次事件結束後經過的遊戲天數。
5. THE GameState SHALL 宣告一個型別為 string 的 `lastCheckInDateUTC` 欄位，預設值為空字串，以 "yyyy-MM-dd" 格式儲存最後打卡日期；空字串代表從未打卡。
6. THE GameState SHALL 宣告一個名為 `researchPoints` 的欄位，將原料 ID 字串映射至 int 值（最小值 0），代表每種原料累積的研究點數；由於 Unity JsonUtility 不支援 Dictionary 序列化，須使用可序列化的替代結構（如平行 List&lt;string&gt; 與 List&lt;int&gt;）。
7. THE GameState SHALL 宣告一個型別為 int 的 `totalCheckIns` 欄位，預設值為 0，有效範圍為 0 至 2147483647，追蹤累計打卡次數。
8. THE GameState SHALL 能透過 Unity 的 JsonUtility 完整序列化為 JSON 再反序列化回原始狀態，所有欄位值不得有資料遺失，包含 `researchPoints` 的所有鍵值對。
9. IF GameState 反序列化時任何欄位缺失（例如舊版存檔），THEN THE GameState SHALL 使用該欄位的預設值初始化，不得拋出例外或導致載入失敗。

### Requirement 2: 流行熱潮事件系統 (EventManager)

**User Story:** 身為玩家，我希望隨機觸發流行熱潮事件來暫時提升特定原料的效益，以便我調整菜單策略在市場趨勢期間賺取最大利潤。

#### Acceptance Criteria

1. WHEN EventManager 於新遊戲天進行評估且 `activeEventId` 為空字串且 `daysSinceLastEvent` 大於等於 25 時，THE EventManager SHALL 計算觸發機率為 (`daysSinceLastEvent` - 25) × 0.1，並將結果限制在 0.0 至 1.0 之間（即 `daysSinceLastEvent` 為 35 時機率為 1.0）。
2. WHEN 觸發機率檢查成功（隨機值介於 0.0 至 1.0 且小於計算出的觸發機率）時，THE EventManager SHALL 從事件資料庫中以均等機率隨機選取一個 TrendEvent 並啟用它。
3. WHEN 一個 TrendEvent 被啟用時，THE EventManager SHALL 設定 `activeEventId` 為選定事件的 `eventId`、設定 `activeEventRemainingDays` 為事件的 `durationDays` 值（2 或 3）、並重設 `daysSinceLastEvent` 為 0。
4. WHILE `activeEventId` 不為空字串，THE EventManager SHALL 對所有包含至少一種事件 `boostedIngredientIds` 清單中原料（比對 `baseTeaId`、`milkId`、或 `toppingIds` 中任一項）的飲品，將事件的 `attractionBonus` 值加入該飲品的基礎吸引力計算結果。
5. WHILE `activeEventId` 不為空字串，THE EventManager SHALL 對包含至少一種受益原料的飲品，以事件的 `priceFactorMultiplier` 乘以 FinanceEngine 中的價格係數容忍閾值（基礎值 5.0）。
6. WHILE `activeEventId` 不為空字串，THE EventManager SHALL 在計算每小時客流量時，以事件的 `trafficMultiplier` 乘以基礎客流量值（FinanceEngine 中的 `baseTraffic`）。
7. WHEN 遊戲天推進時，IF `activeEventId` 不為空字串，THEN THE EventManager SHALL 將 `activeEventRemainingDays` 減 1。
8. WHEN `activeEventRemainingDays` 到達 0 時，THE EventManager SHALL 將 `activeEventId` 清除為空字串並將 `activeEventRemainingDays` 保持為 0 以停用事件。
9. WHEN 遊戲天推進且 `activeEventId` 為空字串時，THE EventManager SHALL 將 `daysSinceLastEvent` 遞增 1。
10. THE EventManager SHALL 公開一個靜態事件資料庫（唯讀 List&lt;TrendEvent&gt;），至少包含 4 個預定義的 TrendEvent 條目，涵蓋 K-POP 偶像代言、動漫 IP 聯名、季節寒流、夏日美白潮流，且每個條目的 `boostedIngredientIds` 僅引用 GameConfig.Ingredients 中存在的原料 ID。
11. IF 事件資料庫包含少於 2 個條目，THEN THE EventManager SHALL 跳過事件觸發邏輯並透過 Debug.LogWarning 記錄警告日誌。

### Requirement 3: 每日打卡 / 真實購茶獎勵系統

**User Story:** 身為玩家，我希望在現實中購買手搖飲後每日打卡一次並選擇我買的品項，以獲得 EXP 和研究點數來幫助遊戲進度。

#### Acceptance Criteria

1. WHEN 玩家請求打卡且當前 UTC 日期字串（格式 "yyyy-MM-dd"）與 `lastCheckInDateUTC` 不同時，THE CheckInManager SHALL 允許打卡繼續進行。
2. WHEN 玩家請求打卡且當前 UTC 日期字串等於 `lastCheckInDateUTC` 時，THE CheckInManager SHALL 拒絕打卡並回傳表示今日已打卡的結果（布林值 false 或等效失敗狀態）。
3. WHEN 有效打卡處理時，THE CheckInManager SHALL 接受一個底茶 ID（string，必填）、一個奶類 ID（string，必填，可為 "none"）、以及一個配料 ID 清單（List&lt;string&gt;，0 至 3 個元素），代表玩家的現實購買內容。
4. WHEN 有效打卡處理時，THE CheckInManager SHALL 透過 LevelSystem 給予玩家 100 點基礎 EXP。
5. WHEN 有效打卡處理時，THE CheckInManager SHALL 對每個提交的唯一且有效的原料 ID（底茶、奶類、配料，排除 "none"）給予 +1 研究點數，遞增 GameState `researchPoints` 中對應的條目；若條目不存在則新建並設為 1。
6. WHEN 有效打卡處理時且 `activeEventId` 不為空字串且至少一個提交的原料 ID 存在於活躍事件的 `boostedIngredientIds` 中，THE CheckInManager SHALL 將 EXP 獎勵從 100 提升至 200（總計 200，非疊加）。
7. WHEN 有效打卡完成時，THE CheckInManager SHALL 將 `lastCheckInDateUTC` 更新為當前 UTC 日期字串（格式 "yyyy-MM-dd"），並將 `totalCheckIns` 遞增 1。
8. IF 提交的原料 ID 不存在於 GameConfig.Ingredients 清單中，THEN THE CheckInManager SHALL 忽略該原料的研究點數獎勵（不遞增 `researchPoints`），但仍完成整個打卡流程且不回傳錯誤。
9. IF 提交的底茶 ID 為空字串或 null，THEN THE CheckInManager SHALL 拒絕打卡並回傳表示輸入無效的結果。

### Requirement 4: 菜單管理邏輯

**User Story:** 身為玩家，我希望使用已解鎖的原料建立和編輯飲料配方並設定有效售價，以優化我的店鋪品項來獲得最大利潤與吸引力。

#### Acceptance Criteria

1. WHEN 玩家建立新配方時，THE MenuManager SHALL 驗證指定的底茶 ID 存在於 GameConfig.Ingredients 中、其 `type` 為 BaseTea、且其 `unlockLevel` 小於等於玩家當前等級。
2. WHEN 玩家建立新配方時，THE MenuManager SHALL 驗證指定的奶類 ID 為 "none"，或存在於 GameConfig.Ingredients 中、其 `type` 為 Milk、且其 `unlockLevel` 小於等於玩家當前等級。
3. WHEN 玩家建立新配方時，THE MenuManager SHALL 驗證每個指定的配料 ID 存在於 GameConfig.Ingredients 中、其 `type` 為 Topping、且其 `unlockLevel` 小於等於玩家當前等級。
4. IF 配方建立或編輯請求中任何原料 ID 不存在於 GameConfig.Ingredients 或其 `unlockLevel` 超過玩家當前等級，THEN THE MenuManager SHALL 拒絕該請求並回傳錯誤結果，包含未通過驗證的原料 ID 清單。
5. IF 配方建立請求的配料 ID 清單包含超過 3 個元素，THEN THE MenuManager SHALL 拒絕該配方並回傳表示配料超過上限（最多 3 種）的錯誤結果。
6. WHEN 有效配方被建立時，THE MenuManager SHALL 為飲料產生唯一 ID（不與 GameState 菜單清單中現有任何 CustomDrink 的 `id` 重複）並將新的 CustomDrink 加入 GameState 的菜單清單。
7. WHEN 玩家設定飲料售價時，THE MenuManager SHALL 驗證售價為大於 0 且小於等於 200 的正整數（int，有效範圍 1 至 200）。
8. IF 玩家設定的售價小於等於 0 或大於 200，THEN THE MenuManager SHALL 拒絕售價設定並回傳表示售價超出有效範圍的錯誤結果。
9. THE MenuManager SHALL 允許編輯現有配方的名稱、原料組合與售價，前提是所有原料解鎖驗證皆通過且售價在有效範圍內。
10. WHEN 玩家請求從菜單移除配方時，IF 移除後菜單仍有至少 1 杯飲料，THEN THE MenuManager SHALL 從 GameState 菜單清單中移除對應的 CustomDrink 條目。
11. IF 移除配方會導致 GameState 菜單清單為空（當前僅剩 1 杯飲料），THEN THE MenuManager SHALL 拒絕移除並回傳表示菜單必須保留至少 1 杯飲料的錯誤結果。
12. WHEN 有效配方被建立或編輯時，THE MenuManager SHALL 呼叫 FinanceEngine.CalculateDrinkCost 計算該配方的生產成本並回傳該值，供 UI 顯示。
13. IF 玩家建立配方時未提供飲料名稱或名稱為空白字串，THEN THE MenuManager SHALL 拒絕該配方並回傳表示名稱不可為空的錯誤結果。

### Requirement 5: 經驗值與等級系統

**User Story:** 身為玩家，我希望透過賣飲料、升級設備和完成任務來獲取經驗值，以升級並解鎖新原料與功能。

#### Acceptance Criteria

1. THE LevelSystem SHALL 使用公式計算升級所需經驗值：`NextLevelEXP = Round(100 × Level^1.5)`，其中 Level 為玩家當前等級（範圍 1 至 99），Round 為四捨五入至最接近整數。
2. WHEN 賣出一杯飲料時，THE LevelSystem SHALL 給予 EXP，數值為 `min(1 + toppingIds.Count, 3)`，即配料 0 個得 1 點、1 個得 2 點、2 個以上得 3 點。
3. WHEN 設備升級完成時，THE LevelSystem SHALL 給予 EXP，數值等於升級後的新設備等級乘以 50（例：設備升至等級 3 則給予 150 EXP）。
4. WHEN 每日任務完成時，THE LevelSystem SHALL 依據任務難度等級給予 EXP，有效範圍為 100 至 500 點（含邊界值）。
5. WHEN 累積的 `currentEXP` 達到或超過 `nextLevelEXP` 且玩家當前等級小於 99 時，THE LevelSystem SHALL 將玩家等級遞增 1、從 `currentEXP` 扣除 `nextLevelEXP`、並以新等級重新計算 `nextLevelEXP`。
6. WHEN 升級發生時，THE LevelSystem SHALL 觸發 OnLevelUp 事件（C# Action&lt;int, int&gt;），帶入新等級與新的 nextLevelEXP 值。
7. WHEN 升級後 `currentEXP` 仍達到或超過新的 `nextLevelEXP` 且等級仍小於 99 時，THE LevelSystem SHALL 以迴圈處理額外升級，直到 `currentEXP` 低於 `nextLevelEXP` 或等級達到 99。
8. THE LevelSystem SHALL 透過比較 GameConfig.Ingredients 中原料的 `unlockLevel` 欄位與玩家當前等級來判定原料解鎖資格：`unlockLevel` 小於等於玩家等級即為已解鎖。
9. WHEN 玩家從任何來源獲得 EXP 時，THE LevelSystem SHALL 觸發 OnEXPGained 事件（C# Action&lt;int&gt;），帶入本次獲得的 EXP 數量。
10. THE LevelSystem SHALL 設定最高等級為 99；WHEN 玩家等級等於 99 時，停止升級處理（不遞增等級、不扣除 EXP）但仍將獲得的 EXP 加入 `currentEXP` 並觸發 OnEXPGained 事件。
11. IF 傳入的 EXP 數量小於等於 0，THEN THE LevelSystem SHALL 忽略該次 EXP 給予，不修改 `currentEXP` 且不觸發任何事件。

### Requirement 6: TrendEvent 資料結構

**User Story:** 身為開發者，我需要一個定義完善的 TrendEvent 結構包含事件系統計算所需的所有參數，以便新增事件時無需修改程式碼。

#### Acceptance Criteria

1. THE TrendEvent 結構 SHALL 標記 `[Serializable]` 屬性，並包含一個 string 型別的 `eventId` 欄位，唯一識別該事件（不可為空字串或 null）。
2. THE TrendEvent 結構 SHALL 包含一個 string 型別的 `title` 欄位（最大長度 30 字元），用於 UI 新聞警報顯示。
3. THE TrendEvent 結構 SHALL 包含一個 string 型別的 `description` 欄位（最大長度 100 字元），存放展示給玩家的公告文字。
4. THE TrendEvent 結構 SHALL 包含一個 List&lt;string&gt; 型別的 `boostedIngredientIds` 欄位，包含 1 至 5 個元素，每個元素為 GameConfig.Ingredients 中存在的有效原料 ID。
5. THE TrendEvent 結構 SHALL 包含一個 float 型別的 `attractionBonus` 欄位，有效範圍為 30.0 至 60.0（含邊界值），指定加入受益原料飲品的額外吸引力點數。
6. THE TrendEvent 結構 SHALL 包含一個 float 型別的 `priceFactorMultiplier` 欄位，有效範圍為 1.0 至 2.0（含邊界值），指定價格敏感度放寬倍數。
7. THE TrendEvent 結構 SHALL 包含一個 float 型別的 `trafficMultiplier` 欄位，有效範圍為 1.2 至 1.5（含邊界值），指定客流量增加倍數。
8. THE TrendEvent 結構 SHALL 包含一個 int 型別的 `durationDays` 欄位，有效值為 2 或 3，指定事件持續遊戲天數。

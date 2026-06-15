# Technical Design Document

## Overview

本文件定義《手搖飲大王 (Bubble Tea Tycoon)》Unity 版核心系統的技術設計，涵蓋四個新增靜態類別（EventManager、CheckInManager、MenuManager、LevelSystem）以及擴展後的 GameState 資料模型。所有新系統位於 `BubbleTeaTycoon.Core` 命名空間，採用純 C# 邏輯實作（不繼承 MonoBehaviour），透過 C# Actions/Events 與現有的 GameManager 單例整合。

## Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GameManager (MonoBehaviour Singleton)         │
│  ┌───────────────┐                                                  │
│  │ EconomyTick() │─── 每遊戲天推進時呼叫 ──┐                        │
│  └───────────────┘                         │                        │
│        │                                   ▼                        │
│        │                         ┌──────────────────┐               │
│        │                         │  EventManager    │ (static)      │
│        │                         │  ‧ EvaluateDay() │               │
│        │                         │  ‧ GetBoost()    │               │
│        │                         └────────┬─────────┘               │
│        │                                  │                         │
│        ▼                                  ▼                         │
│  ┌─────────────┐    ┌──────────────┐   ┌──────────────┐            │
│  │FinanceEngine│◄───│ MenuManager  │   │CheckInManager│            │
│  │  (static)   │    │  (static)    │   │  (static)    │            │
│  └─────────────┘    └──────────────┘   └──────┬───────┘            │
│        ▲                                      │                     │
│        │            ┌──────────────┐          │                     │
│        └────────────│ LevelSystem  │◄─────────┘                     │
│                     │  (static)    │                                 │
│                     └──────────────┘                                 │
│                                                                     │
│  ┌──────────┐   ┌────────────┐   ┌────────────────┐                │
│  │GameConfig│   │ SaveSystem │   │ NetworkManager │                 │
│  │ (static) │   │  (static)  │   │ (MonoBehaviour)│                 │
│  └──────────┘   └────────────┘   └────────────────┘                │
└─────────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### Components

| 類別 | 型態 | 職責 |
|------|------|------|
| **GameManager** | MonoBehaviour Singleton (既有) | 生命週期管理、EconomyTick 協程、觸發新遊戲天推進 |
| **EventManager** | static class (新增) | 流行熱潮觸發機率計算、事件啟用/倒數/結束、吸引力與客流加成查詢 |
| **CheckInManager** | static class (新增) | 每日打卡驗證、EXP/研究點數發放、事件聯動加成 |
| **MenuManager** | static class (新增) | 配方 CRUD、原料解鎖驗證、售價範圍檢查、唯一 ID 產生 |
| **LevelSystem** | static class (新增) | EXP 計算與累加、升級迴圈處理、解鎖資格查詢、事件廣播 |
| **GameConfig** | static class (既有) | 原料資料庫、遊戲常數 |
| **FinanceEngine** | static class (既有) | 成本/吸引力/價格係數/月度財報計算 |
| **SaveSystem** | static class (既有) | AES-256 加密本地存檔讀寫 |
| **NetworkManager** | MonoBehaviour Singleton (既有) | 雲端同步、排行榜 |

## Data Models

### 擴展後的 GameState

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

namespace BubbleTeaTycoon.Core
{
    [Serializable]
    public class GameState
    {
        // === 既有欄位 ===
        public string shopName = "我的手搖店";
        public bool hasStarted = false;
        public int money = GameConfig.STARTING_MONEY;
        public int reputation = 0;
        public int level = 1;
        public int currentEXP = 0;
        public int nextLevelEXP = 100;

        public long gameStartTimeUnix;
        public int lastGameDay = 1;
        public int lastGameMonth = 1;
        public int lastOrderNumber = 0;

        public List<CustomDrink> menu = new List<CustomDrink>();
        public EquipmentLevels equipment = new EquipmentLevels
            { teaMachine = 1, iceMachine = 1, sealingMachine = 1, marketing = 0 };
        public StaffConfig staff = new StaffConfig
            { partTime = 0, fullTime = 0, manager = 0 };
        public bool is24h = false;

        // Metrics
        public int dailyMetric = 0;
        public int monthlyMetric = 0;
        public int totalMetric = 0;

        public long lastOnlineUnix;
        public string globalId = "";
        public string lastLoginDate = "";

        // === 新增欄位：流行熱潮事件系統 ===
        public string activeEventId = "";
        public int activeEventRemainingDays = 0;
        public int daysSinceLastEvent = 0;

        // === 新增欄位：每日打卡系統 ===
        public string carrierBarcode = "";
        public string lastCheckInDateUTC = "";
        public int totalCheckIns = 0;

        // === 新增欄位：研究點數（平行 List 序列化模式）===
        public List<string> researchPointKeys = new List<string>();
        public List<int> researchPointValues = new List<int>();

        // === 研究點數存取輔助方法 ===
        public int GetResearchPoints(string ingredientId)
        {
            int index = researchPointKeys.IndexOf(ingredientId);
            return index >= 0 ? researchPointValues[index] : 0;
        }

        public void AddResearchPoints(string ingredientId, int amount)
        {
            int index = researchPointKeys.IndexOf(ingredientId);
            if (index >= 0)
            {
                researchPointValues[index] += amount;
            }
            else
            {
                researchPointKeys.Add(ingredientId);
                researchPointValues.Add(amount);
            }
        }
    }
}
```

### TrendEvent 結構

```csharp
using System;
using System.Collections.Generic;

namespace BubbleTeaTycoon.Core
{
    /// <summary>
    /// 代表一次流行熱潮事件的不可變資料結構。
    /// 由 EventManager 的靜態事件資料庫持有，運行時僅讀取不修改。
    /// </summary>
    [Serializable]
    public struct TrendEvent
    {
        /// <summary>唯一事件識別碼（如 "kpop-oolong"）</summary>
        public string eventId;

        /// <summary>UI 新聞標題（最多 30 字元）</summary>
        public string title;

        /// <summary>公告描述文字（最多 100 字元）</summary>
        public string description;

        /// <summary>受益原料 ID 清單（1~5 個，對應 GameConfig.Ingredients）</summary>
        public List<string> boostedIngredientIds;

        /// <summary>受益飲品額外吸引力點數（30.0~60.0）</summary>
        public float attractionBonus;

        /// <summary>價格敏感度放寬倍數（1.0~2.0，乘以基礎閾值 5.0）</summary>
        public float priceFactorMultiplier;

        /// <summary>客流量乘數（1.2~1.5）</summary>
        public float trafficMultiplier;

        /// <summary>事件持續遊戲天數（2 或 3）</summary>
        public int durationDays;
    }
}
```

### CheckInResult 結構

```csharp
using System;
using System.Collections.Generic;

namespace BubbleTeaTycoon.Core
{
    /// <summary>
    /// CheckInManager.ProcessCheckIn 的回傳結果。
    /// </summary>
    [Serializable]
    public struct CheckInResult
    {
        /// <summary>打卡是否成功</summary>
        public bool success;

        /// <summary>失敗原因描述（成功時為空字串）</summary>
        public string errorMessage;

        /// <summary>本次獲得的 EXP（成功時為 100 或 200）</summary>
        public int expGained;

        /// <summary>本次獲得研究點數的原料 ID 清單</summary>
        public List<string> researchPointsAwarded;

        /// <summary>是否觸發事件加成（EXP 翻倍）</summary>
        public bool eventBonusApplied;
    }
}
```

### MenuOperationResult 結構

```csharp
using System;
using System.Collections.Generic;

namespace BubbleTeaTycoon.Core
{
    /// <summary>
    /// MenuManager 操作的統一回傳結果。
    /// </summary>
    [Serializable]
    public struct MenuOperationResult
    {
        /// <summary>操作是否成功</summary>
        public bool success;

        /// <summary>失敗原因描述（成功時為空字串）</summary>
        public string errorMessage;

        /// <summary>未通過驗證的原料 ID 清單（成功時為空）</summary>
        public List<string> invalidIngredientIds;

        /// <summary>成功建立/編輯後的飲品生產成本（失敗時為 0）</summary>
        public int productionCost;

        /// <summary>成功建立後的飲品 ID（編輯/刪除時為原 ID）</summary>
        public string drinkId;
    }
}
```

## Interface Definitions

### EventManager

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

namespace BubbleTeaTycoon.Core
{
    /// <summary>
    /// 流行熱潮事件系統。負責事件觸發、生命週期管理與加成查詢。
    /// 由 GameManager 在每遊戲天推進時呼叫 EvaluateNewDay()。
    /// </summary>
    public static class EventManager
    {
        // ==================== EVENTS ====================

        /// <summary>當新事件被觸發時廣播，帶入觸發的 TrendEvent 資料。</summary>
        public static event Action<TrendEvent> OnEventTriggered;

        /// <summary>當事件自然結束時廣播，帶入結束的事件 ID。</summary>
        public static event Action<string> OnEventEnded;

        // ==================== 預定義事件資料庫 ====================

        /// <summary>
        /// 唯讀的預定義事件清單。所有 boostedIngredientIds 皆對應
        /// GameConfig.Ingredients 中存在的有效 ID。
        /// </summary>
        public static readonly List<TrendEvent> EventDatabase;

        // ==================== PUBLIC API ====================

        /// <summary>
        /// 於新遊戲天開始時呼叫。處理事件倒數、結束判定、以及新事件觸發。
        /// 由 GameManager.EconomyTick 在遊戲天推進邏輯中呼叫。
        /// </summary>
        /// <param name="state">當前遊戲狀態（將被修改）</param>
        public static void EvaluateNewDay(GameState state);

        /// <summary>
        /// 取得指定飲品因活躍事件而獲得的額外吸引力加成。
        /// 若無活躍事件或飲品不含受益原料，回傳 0。
        /// </summary>
        /// <param name="drink">目標飲品</param>
        /// <param name="state">當前遊戲狀態</param>
        /// <returns>額外吸引力點數（int）</returns>
        public static int GetAttractionBoost(CustomDrink drink, GameState state);

        /// <summary>
        /// 取得當前活躍事件的客流量乘數。
        /// 若無活躍事件，回傳 1.0f（無加成）。
        /// </summary>
        /// <param name="state">當前遊戲狀態</param>
        /// <returns>客流量乘數（float）</returns>
        public static float GetTrafficMultiplier(GameState state);

        /// <summary>
        /// 取得指定飲品因活躍事件而獲得的價格係數容忍閾值。
        /// 基礎閾值為 5.0，事件期間為 5.0 × priceFactorMultiplier。
        /// 若飲品不含受益原料，回傳基礎閾值 5.0f。
        /// </summary>
        /// <param name="drink">目標飲品</param>
        /// <param name="state">當前遊戲狀態</param>
        /// <returns>價格係數容忍閾值（float）</returns>
        public static float GetPriceThreshold(CustomDrink drink, GameState state);

        /// <summary>
        /// 取得當前活躍事件的完整 TrendEvent 資料。
        /// 若無活躍事件回傳 null-equivalent（eventId 為空的預設 TrendEvent）。
        /// </summary>
        /// <param name="state">當前遊戲狀態</param>
        /// <returns>當前活躍的 TrendEvent（若無則 eventId 為空字串）</returns>
        public static TrendEvent GetActiveEvent(GameState state);

        /// <summary>
        /// 判斷指定飲品是否包含當前活躍事件的受益原料。
        /// </summary>
        /// <param name="drink">目標飲品</param>
        /// <param name="state">當前遊戲狀態</param>
        /// <returns>true 若飲品包含至少一種受益原料</returns>
        public static bool IsDrinkBoosted(CustomDrink drink, GameState state);
    }
}
```

### CheckInManager

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

namespace BubbleTeaTycoon.Core
{
    /// <summary>
    /// 每日打卡系統。驗證打卡資格、發放 EXP 與研究點數。
    /// 整合 LevelSystem 進行 EXP 發放，整合 EventManager 判定加成。
    /// </summary>
    public static class CheckInManager
    {
        // ==================== EVENTS ====================

        /// <summary>當打卡成功完成時廣播，帶入 CheckInResult。</summary>
        public static event Action<CheckInResult> OnCheckInCompleted;

        // ==================== PUBLIC API ====================

        /// <summary>
        /// 處理玩家的每日打卡請求。
        /// 驗證日期資格、原料有效性、計算 EXP 與研究點數獎勵。
        /// </summary>
        /// <param name="state">當前遊戲狀態（將被修改）</param>
        /// <param name="baseTeaId">玩家購買的底茶 ID（必填，不可為空或 null）</param>
        /// <param name="milkId">玩家購買的奶類 ID（必填，可為 "none"）</param>
        /// <param name="toppingIds">玩家購買的配料 ID 清單（0~3 個元素）</param>
        /// <returns>CheckInResult 包含成功/失敗狀態與獎勵明細</returns>
        public static CheckInResult ProcessCheckIn(
            GameState state,
            string baseTeaId,
            string milkId,
            List<string> toppingIds);

        /// <summary>
        /// 查詢今日是否已打卡。
        /// </summary>
        /// <param name="state">當前遊戲狀態</param>
        /// <returns>true 若今日 UTC 日期已打卡</returns>
        public static bool HasCheckedInToday(GameState state);

        /// <summary>
        /// 驗證電子載具條碼格式。
        /// 格式：斜線 + 7 碼大寫英數字（如 /ABC1234）。
        /// </summary>
        /// <param name="barcode">待驗證的條碼字串</param>
        /// <returns>true 若格式有效</returns>
        public static bool ValidateCarrierBarcode(string barcode);
    }
}
```

### MenuManager

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;

namespace BubbleTeaTycoon.Core
{
    /// <summary>
    /// 菜單管理系統。處理配方 CRUD、原料解鎖驗證、售價範圍檢查。
    /// 所有操作回傳 MenuOperationResult 以利 UI 層顯示回饋訊息。
    /// </summary>
    public static class MenuManager
    {
        // ==================== EVENTS ====================

        /// <summary>當菜單有任何變動時廣播（新增/編輯/刪除）。</summary>
        public static event Action OnMenuChanged;

        // ==================== PUBLIC API ====================

        /// <summary>
        /// 建立新飲料配方並加入 GameState 菜單清單。
        /// 驗證所有原料解鎖資格、配料數量上限（3）、名稱非空、售價範圍（1~200）。
        /// </summary>
        /// <param name="state">當前遊戲狀態（將被修改）</param>
        /// <param name="name">飲料名稱（不可為空白）</param>
        /// <param name="baseTeaId">底茶原料 ID</param>
        /// <param name="milkId">奶類原料 ID（可為 "none"）</param>
        /// <param name="toppingIds">配料 ID 清單（0~3 個）</param>
        /// <param name="price">售價（1~200）</param>
        /// <returns>MenuOperationResult 含成功狀態與生產成本</returns>
        public static MenuOperationResult CreateDrink(
            GameState state,
            string name,
            string baseTeaId,
            string milkId,
            List<string> toppingIds,
            int price);

        /// <summary>
        /// 編輯現有飲料配方。以 drinkId 定位目標飲品，更新所有欄位。
        /// 驗證規則同 CreateDrink。
        /// </summary>
        /// <param name="state">當前遊戲狀態（將被修改）</param>
        /// <param name="drinkId">目標飲品 ID</param>
        /// <param name="name">新名稱</param>
        /// <param name="baseTeaId">新底茶 ID</param>
        /// <param name="milkId">新奶類 ID</param>
        /// <param name="toppingIds">新配料 ID 清單</param>
        /// <param name="price">新售價</param>
        /// <returns>MenuOperationResult</returns>
        public static MenuOperationResult EditDrink(
            GameState state,
            string drinkId,
            string name,
            string baseTeaId,
            string milkId,
            List<string> toppingIds,
            int price);

        /// <summary>
        /// 從菜單移除指定飲品。菜單至少須保留 1 杯飲料。
        /// </summary>
        /// <param name="state">當前遊戲狀態（將被修改）</param>
        /// <param name="drinkId">欲移除的飲品 ID</param>
        /// <returns>MenuOperationResult</returns>
        public static MenuOperationResult RemoveDrink(GameState state, string drinkId);

        /// <summary>
        /// 僅更新指定飲品的售價。驗證售價範圍（1~200）。
        /// </summary>
        /// <param name="state">當前遊戲狀態（將被修改）</param>
        /// <param name="drinkId">目標飲品 ID</param>
        /// <param name="newPrice">新售價</param>
        /// <returns>MenuOperationResult</returns>
        public static MenuOperationResult SetPrice(GameState state, string drinkId, int newPrice);

        /// <summary>
        /// 產生不重複的飲品 ID。基於 state.lastOrderNumber 遞增。
        /// </summary>
        /// <param name="state">當前遊戲狀態（lastOrderNumber 將被遞增）</param>
        /// <returns>唯一字串 ID</returns>
        public static string GenerateUniqueId(GameState state);

        /// <summary>
        /// 驗證單一原料是否已解鎖（unlockLevel <= playerLevel）。
        /// </summary>
        /// <param name="ingredientId">原料 ID</param>
        /// <param name="playerLevel">玩家當前等級</param>
        /// <returns>true 若已解鎖</returns>
        public static bool IsIngredientUnlocked(string ingredientId, int playerLevel);
    }
}
```

### LevelSystem

```csharp
using System;
using UnityEngine;

namespace BubbleTeaTycoon.Core
{
    /// <summary>
    /// 經驗值與等級系統。集中管理 EXP 計算、升級迴圈、解鎖判定。
    /// 最高等級 99，升級公式：NextLevelEXP = Round(100 × Level^1.5)。
    /// </summary>
    public static class LevelSystem
    {
        // ==================== CONSTANTS ====================

        /// <summary>最高玩家等級</summary>
        public const int MAX_LEVEL = 99;

        // ==================== EVENTS ====================

        /// <summary>當升級發生時廣播（newLevel, newNextLevelEXP）。</summary>
        public static event Action<int, int> OnLevelUp;

        /// <summary>當 EXP 獲得時廣播（本次獲得量）。</summary>
        public static event Action<int> OnEXPGained;

        // ==================== PUBLIC API ====================

        /// <summary>
        /// 計算指定等級的升級所需經驗值。
        /// 公式：Round(100 × level^1.5)
        /// </summary>
        /// <param name="level">目標等級（1~99）</param>
        /// <returns>升級所需 EXP</returns>
        public static int CalculateNextLevelEXP(int level);

        /// <summary>
        /// 給予 EXP 並處理升級迴圈。
        /// 若 amount <= 0 則忽略，不修改狀態也不觸發事件。
        /// 等級達 99 時仍累加 EXP 並觸發 OnEXPGained，但不升級。
        /// </summary>
        /// <param name="state">當前遊戲狀態（將被修改）</param>
        /// <param name="amount">EXP 數量（須大於 0）</param>
        public static void AddEXP(GameState state, int amount);

        /// <summary>
        /// 計算賣出一杯飲料應獲得的 EXP。
        /// 公式：min(1 + toppingCount, 3)
        /// </summary>
        /// <param name="toppingCount">飲品的配料數量</param>
        /// <returns>EXP 值（1~3）</returns>
        public static int CalculateSaleEXP(int toppingCount);

        /// <summary>
        /// 計算設備升級應獲得的 EXP。
        /// 公式：newEquipmentLevel × 50
        /// </summary>
        /// <param name="newEquipmentLevel">升級後的設備等級</param>
        /// <returns>EXP 值</returns>
        public static int CalculateEquipmentUpgradeEXP(int newEquipmentLevel);

        /// <summary>
        /// 判定原料是否已解鎖。
        /// 規則：GameConfig.Ingredients 中該原料的 unlockLevel <= playerLevel。
        /// </summary>
        /// <param name="ingredientId">原料 ID</param>
        /// <param name="playerLevel">玩家當前等級</param>
        /// <returns>true 若已解鎖</returns>
        public static bool IsIngredientUnlocked(string ingredientId, int playerLevel);

        /// <summary>
        /// 取得玩家當前等級可解鎖的所有原料 ID 清單。
        /// </summary>
        /// <param name="playerLevel">玩家當前等級</param>
        /// <returns>已解鎖原料 ID 清單</returns>
        public static System.Collections.Generic.List<string> GetUnlockedIngredients(int playerLevel);
    }
}
```

## Event Flow

### 遊戲天推進與事件評估流程

```
GameManager.EconomyTick() [每 1 真實秒執行]
    │
    ├─ 累計遊戲時間，判斷是否跨越新遊戲天
    │  （4 現實小時 = 1 遊戲天 → 每 14,400 秒推進一天）
    │
    └─ IF 新遊戲天開始:
         │
         ├─ 1. EventManager.EvaluateNewDay(state)
         │     │
         │     ├─ IF activeEventId 不為空:
         │     │     ├─ activeEventRemainingDays--
         │     │     └─ IF remainingDays == 0:
         │     │           ├─ activeEventId = ""
         │     │           └─ 觸發 OnEventEnded
         │     │
         │     └─ IF activeEventId 為空:
         │           ├─ daysSinceLastEvent++
         │           ├─ 計算觸發機率 = (daysSinceLastEvent - 25) × 0.1
         │           └─ IF random < 機率:
         │                 ├─ 從 EventDatabase 隨機選取事件
         │                 ├─ 設定 activeEventId, activeEventRemainingDays
         │                 ├─ 重設 daysSinceLastEvent = 0
         │                 └─ 觸發 OnEventTriggered
         │
         ├─ 2. 財務計算整合事件加成:
         │     ├─ 吸引力 = FinanceEngine.CalculateAttraction(drink)
         │     │           + EventManager.GetAttractionBoost(drink, state)
         │     ├─ 客流量 = baseTraffic × EventManager.GetTrafficMultiplier(state)
         │     └─ 價格閾值 = EventManager.GetPriceThreshold(drink, state)
         │
         └─ 3. 正常 EconomyTick 收益計算（同既有邏輯）
```

### 打卡流程

```
UI 層呼叫 CheckInManager.ProcessCheckIn(state, baseTeaId, milkId, toppingIds)
    │
    ├─ 驗證 baseTeaId 非空/null → 失敗回傳
    ├─ 驗證日期（lastCheckInDateUTC != today）→ 失敗回傳
    │
    ├─ 計算 EXP:
    │   ├─ baseEXP = 100
    │   ├─ IF 活躍事件 && 原料命中受益清單 → baseEXP = 200
    │   └─ LevelSystem.AddEXP(state, baseEXP)
    │
    ├─ 發放研究點數:
    │   └─ 對每個有效原料 ID（存在於 GameConfig.Ingredients）
    │       → state.AddResearchPoints(ingredientId, 1)
    │
    ├─ 更新狀態:
    │   ├─ state.lastCheckInDateUTC = DateTime.UtcNow.ToString("yyyy-MM-dd")
    │   └─ state.totalCheckIns++
    │
    └─ 觸發 OnCheckInCompleted → 回傳 CheckInResult
```

### 菜單操作流程

```
MenuManager.CreateDrink(state, name, baseTeaId, milkId, toppingIds, price)
    │
    ├─ 驗證名稱非空白
    ├─ 驗證售價範圍 (1~200)
    ├─ 驗證配料數量 (0~3)
    ├─ 驗證所有原料:
    │   ├─ baseTeaId: 存在 && type==BaseTea && unlockLevel <= level
    │   ├─ milkId: "none" 或 (存在 && type==Milk && unlockLevel <= level)
    │   └─ toppingIds: 每個存在 && type==Topping && unlockLevel <= level
    │
    ├─ IF 任一驗證失敗 → 回傳 MenuOperationResult(success=false, invalidIngredientIds)
    │
    ├─ 產生唯一 ID (GenerateUniqueId)
    ├─ 建立 CustomDrink 加入 state.menu
    ├─ 計算 productionCost = FinanceEngine.CalculateDrinkCost(drink)
    ├─ 觸發 OnMenuChanged
    └─ 回傳 MenuOperationResult(success=true, productionCost, drinkId)
```

## Implementation Notes

### 1. 研究點數序列化模式（平行 Lists）

Unity 的 `JsonUtility` 不支援 `Dictionary<string, int>` 序列化。採用平行 `List<string>` + `List<int>` 模式：

```csharp
// GameState 中的宣告
public List<string> researchPointKeys = new List<string>();
public List<int> researchPointValues = new List<int>();

// 存取輔助方法（定義在 GameState 類別內）
public int GetResearchPoints(string ingredientId)
{
    int index = researchPointKeys.IndexOf(ingredientId);
    return index >= 0 ? researchPointValues[index] : 0;
}

public void AddResearchPoints(string ingredientId, int amount)
{
    int index = researchPointKeys.IndexOf(ingredientId);
    if (index >= 0)
    {
        researchPointValues[index] += amount;
    }
    else
    {
        researchPointKeys.Add(ingredientId);
        researchPointValues.Add(amount);
    }
}
```

**序列化驗證**：兩個 List 的長度必須始終相等。反序列化後若 `researchPointKeys.Count != researchPointValues.Count`，應將兩者清空並以 `Debug.LogWarning` 記錄錯誤。

### 2. 與既有 GameManager 的整合

GameManager 的 `EconomyTick()` 協程需新增遊戲天推進判定邏輯：

```csharp
// 在 EconomyTick 協程中新增
private int _currentGameDay = 0;

private IEnumerator EconomyTick()
{
    while (true)
    {
        yield return new WaitForSeconds(ECONOMY_TICK_INTERVAL);

        if (_state.menu == null || _state.menu.Count == 0 || !_state.hasStarted) continue;

        // 計算當前遊戲天（基於遊戲啟動以來的真實時間）
        float gameHoursPerSecond = 24f / (GameConfig.REAL_HOURS_PER_GAME_DAY * 3600f);
        long now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        double elapsedSeconds = now - _state.gameStartTimeUnix;
        int newGameDay = (int)(elapsedSeconds / (GameConfig.REAL_HOURS_PER_GAME_DAY * 3600)) + 1;

        // 遊戲天推進時觸發 EventManager
        if (newGameDay > _state.lastGameDay)
        {
            _state.lastGameDay = newGameDay;
            EventManager.EvaluateNewDay(_state);
        }

        // 既有收益計算（整合事件加成）...
    }
}
```

### 3. 預定義事件資料庫

```csharp
public static readonly List<TrendEvent> EventDatabase = new List<TrendEvent>
{
    new TrendEvent
    {
        eventId = "kpop-oolong",
        title = "K-POP 團員打卡",
        description = "韓團成員在台北街頭被拍到手持烏龍拿鐵！粉絲陷入瘋狂！",
        boostedIngredientIds = new List<string> { "oolong", "fresh-milk" },
        attractionBonus = 45f,
        priceFactorMultiplier = 1.6f,
        trafficMultiplier = 1.3f,
        durationDays = 3
    },
    new TrendEvent
    {
        eventId = "anime-collab",
        title = "動漫 IP 大聯名",
        description = "超人氣動漫聯名活動開跑！點購雙倍珍波椰即贈限定貼紙！",
        boostedIngredientIds = new List<string> { "qing-tea", "boba", "coconut-jelly" },
        attractionBonus = 35f,
        priceFactorMultiplier = 1.4f,
        trafficMultiplier = 1.3f,
        durationDays = 3
    },
    new TrendEvent
    {
        eventId = "winter-cold",
        title = "超級寒冬來襲",
        description = "強烈冷氣團過境！民眾高喊：我需要熱呼呼的奶蓋！",
        boostedIngredientIds = new List<string> { "milk-foam", "puerh" },
        attractionBonus = 50f,
        priceFactorMultiplier = 1.5f,
        trafficMultiplier = 1.2f,
        durationDays = 2
    },
    new TrendEvent
    {
        eventId = "summer-beauty",
        title = "夏日防曬美白風",
        description = "美妝博主推薦：每天一杯蘆薈愛玉，喝出亮白肌膚！",
        boostedIngredientIds = new List<string> { "aloe", "aiyu", "green-tea" },
        attractionBonus = 40f,
        priceFactorMultiplier = 1.4f,
        trafficMultiplier = 1.3f,
        durationDays = 2
    }
};
```

### 4. 檔案結構規劃

```
Assets/Scripts/Core/
├── GameConfig.cs          (既有，不修改)
├── FinanceEngine.cs       (既有，後續整合事件加成)
├── GameManager.cs         (既有，新增遊戲天推進邏輯)
├── SaveSystem.cs          (既有，GameState 擴展欄位)
├── EventManager.cs        (新增)
├── CheckInManager.cs      (新增)
├── MenuManager.cs         (新增)
├── LevelSystem.cs         (新增)
└── Models/
    ├── TrendEvent.cs      (新增)
    ├── CheckInResult.cs   (新增)
    └── MenuOperationResult.cs (新增)
```

### 5. 向後相容性

- GameState 新增欄位皆有預設值，`JsonUtility.FromJson<GameState>()` 載入舊存檔時缺失欄位自動使用預設值，不會拋出例外
- 既有 `BobaConfig.STARTING_MONEY` 引用需統一為 `GameConfig.STARTING_MONEY`（目前程式碼中已是 `GameConfig`）
- LevelSystem 的升級公式 `Round(100 × Level^1.5)` 與 GameManager 中既有的 `Mathf.RoundToInt(100 * Mathf.Pow(_state.level, 1.5f))` 完全一致，確保行為統一

### 6. 隨機數來源

EventManager 的觸發機率判定使用 `UnityEngine.Random.Range(0f, 1f)`，確保在 Unity Runtime 環境中行為一致。若需支援單元測試，可提供靜態委派 `Func<float> RandomProvider` 供注入替代實作。

## Error Handling

| 情境 | 處理方式 |
|------|----------|
| GameState 反序列化欄位缺失（舊存檔） | JsonUtility 自動使用欄位預設值，不拋出例外 |
| `researchPointKeys.Count != researchPointValues.Count` | 清空兩個 List，`Debug.LogWarning` 記錄 |
| EventDatabase 少於 2 個條目 | `Debug.LogWarning`，跳過事件觸發邏輯 |
| CheckIn 底茶 ID 為 null 或空字串 | 回傳 `CheckInResult { success = false, errorMessage = "底茶 ID 不可為空" }` |
| CheckIn 原料 ID 不在 GameConfig 中 | 忽略該原料的研究點數，不影響整體打卡流程 |
| MenuManager 找不到指定 drinkId | 回傳 `MenuOperationResult { success = false, errorMessage = "找不到指定飲品" }` |
| LevelSystem.AddEXP 傳入 amount <= 0 | 靜默忽略，不修改狀態、不觸發事件 |
| EventManager.GetActiveEvent 無活躍事件 | 回傳 `default(TrendEvent)`（eventId 為空字串） |

## Correctness Properties

### Property 1: GameState List 一致性
`researchPointKeys` 與 `researchPointValues` 長度始終相等。

### Property 2: 等級單調遞增
玩家等級只能遞增，不可遞減，且上限為 99。

### Property 3: 經驗值守恆
每次 AddEXP 呼叫後，`currentEXP + 已扣除量` 等於傳入的總 EXP 量。

### Property 4: 事件互斥
同時最多只有一個活躍事件（`activeEventId` 非空時不可觸發新事件）。

### Property 5: 菜單非空
GameState.menu 在任何操作後至少包含 1 個 CustomDrink。

### Property 6: 每日打卡唯一
同一 UTC 日期內最多成功打卡一次。

### Property 7: ID 唯一性
MenuManager.GenerateUniqueId 產生的 ID 不與現有菜單中任何飲品 ID 重複。

## Testing Strategy

由於專案暫無 Unity Test Runner 環境，測試策略如下：

1. **手動驗證（Unity Editor 開啟後）**：
   - 在 `GameManager.Start()` 中撰寫臨時測試代碼，呼叫各系統 API 並以 `Debug.Log` 輸出結果
   - 驗證存檔→讀取循環中 GameState 新欄位的完整性

2. **未來單元測試計畫（NUnit + Unity Test Framework）**：
   - `LevelSystem`: 測試 EXP 公式計算、連續升級、99 級上限
   - `MenuManager`: 測試建立/編輯/刪除配方、邊界條件（空名稱、超出售價範圍、配料超過 3 個）
   - `CheckInManager`: 測試重複打卡拒絕、事件加成判定、無效原料處理
   - `EventManager`: 測試觸發機率邊界（day 25 → 0%、day 35 → 100%）、事件倒數與結束

3. **靜態驗證**：
   - 確認所有新 .cs 檔案在 Unity Editor 中無編譯錯誤
   - 確認 GameState 擴展後 `JsonUtility.ToJson` / `FromJson` 循環不丟失資料

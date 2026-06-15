# Implementation Plan: Unity Core Systems

## Overview

實作《手搖飲大王》Unity 版的純 C# 核心邏輯系統：TrendEvent 資料結構、擴展 GameState、LevelSystem、EventManager、MenuManager、CheckInManager，以及與現有 GameManager 的整合。

## Tasks

- [x] 1. 建立 TrendEvent 資料結構與 Result 模型：在 `Assets/Scripts/Core/Models/` 下建立 `TrendEvent.cs`（[Serializable] struct，含 eventId/title/description/boostedIngredientIds/attractionBonus/priceFactorMultiplier/trafficMultiplier/durationDays）、`CheckInResult.cs`（含 success/errorMessage/expGained/researchPointsAwarded/eventBonusApplied）、`MenuOperationResult.cs`（含 success/errorMessage/invalidIngredientIds/productionCost/drinkId）。所有結構位於 namespace BubbleTeaTycoon.Core。
  - Requirements addressed: Requirement 6
- [x] 2. 擴展 GameState 資料模型：在 SaveSystem.cs 的 GameState 中新增欄位 carrierBarcode (string "")、activeEventId (string "")、activeEventRemainingDays (int 0)、daysSinceLastEvent (int 0)、lastCheckInDateUTC (string "")、totalCheckIns (int 0)、researchPointKeys (List<string>)、researchPointValues (List<int>)；新增 GetResearchPoints/AddResearchPoints 輔助方法；修正 money 初始化為 GameConfig.STARTING_MONEY。
  - Requirements addressed: Requirement 1
- [x] 3. 實作 LevelSystem 靜態類別：建立 `Assets/Scripts/Core/LevelSystem.cs`，實作 MAX_LEVEL=99、OnLevelUp/OnEXPGained 事件、CalculateNextLevelEXP (Round(100*Level^1.5))、AddEXP（含升級迴圈與 99 級上限）、CalculateSaleEXP (min(1+toppings,3))、CalculateEquipmentUpgradeEXP (level*50)、IsIngredientUnlocked、GetUnlockedIngredients。
  - Requirements addressed: Requirement 5
- [x] 4. 實作 EventManager 靜態類別：建立 `Assets/Scripts/Core/EventManager.cs`，包含 EventDatabase（4 個預定義事件：kpop-oolong/anime-collab/winter-cold/summer-beauty）、EvaluateNewDay（事件倒數/結束/觸發機率計算）、GetActiveEvent、IsDrinkBoosted、GetAttractionBoost、GetTrafficMultiplier、GetPriceThreshold、OnEventTriggered/OnEventEnded 事件。
  - Requirements addressed: Requirement 2, Requirement 6
- [x] 5. 實作 MenuManager 靜態類別：建立 `Assets/Scripts/Core/MenuManager.cs`，包含 OnMenuChanged 事件、GenerateUniqueId、CreateDrink（驗證名稱/售價1~200/配料<=3/解鎖資格/型別）、EditDrink、RemoveDrink（菜單至少1杯）、SetPrice、IsIngredientUnlocked。
  - Requirements addressed: Requirement 4
- [x] 6. 實作 CheckInManager 靜態類別：建立 `Assets/Scripts/Core/CheckInManager.cs`，包含 OnCheckInCompleted 事件、HasCheckedInToday、ValidateCarrierBarcode（正規表達式 /[A-Z0-9]{7}）、ProcessCheckIn（日期驗證/EXP 100 或事件加成 200/研究點數/更新狀態）。
  - Requirements addressed: Requirement 3
- [x] 7. 整合 GameManager 遊戲天推進邏輯：在 EconomyTick 中新增遊戲天計算與 EventManager.EvaluateNewDay 呼叫；將 AddEXP 改為委派 LevelSystem.AddEXP；移除 GameManager 中重複的升級邏輯；將 OnLevelUp/OnEXPGained 改為轉發 LevelSystem 事件。
  - Requirements addressed: Requirement 2, Requirement 5

## Task Dependency Graph

```json
{
  "waves": [
    ["1"],
    ["2"],
    ["3"],
    ["4"],
    ["5", "6"],
    ["7"]
  ]
}
```

順序：1 → 2 → 3 → 4 → 5 & 6（可平行）→ 7

## Notes

- 所有新 class 為 static class，不繼承 MonoBehaviour，純 C# 邏輯
- Task 5 與 Task 6 可平行開發，兩者互不依賴但都依賴 Task 3 (LevelSystem) 與 Task 4 (EventManager)
- Task 7 是最後的整合步驟，需要前面所有 Task 完成
- 無法在沒有 Unity Editor 的環境下驗證編譯，但可確保程式碼語法正確

---
inclusion: fileMatch
fileMatchPattern: "**/*.cs"
---

# Unity 專案程式碼規範

## Namespace

- 所有核心邏輯：`BubbleTeaTycoon.Core`
- 網路相關：`BubbleTeaTycoon.Network`
- 未來 UI 控制器：`BubbleTeaTycoon.UI`

## 類別設計原則

- 不依賴 Unity Editor 的純邏輯類別使用 **static class**（如 LevelSystem、EventManager、MenuManager、CheckInManager）
- 需要生命週期（Awake/Start/Update）的使用 **MonoBehaviour Singleton**（如 GameManager、NetworkManager）
- 資料結構使用 `[Serializable] public struct`（如 TrendEvent、CustomDrink、CheckInResult）

## 事件驅動架構

- UI 不直接修改 GameState，透過 Manager 的 public method 操作
- 狀態變化透過 `C# event Action<T>` 廣播給 UI 層監聽
- 範例：`GameManager.OnMoneyChanged`, `LevelSystem.OnLevelUp`, `EventManager.OnEventTriggered`

## 資料儲存

- GameState 是唯一資料真實來源 (Single Source of Truth)
- 序列化使用 Unity JsonUtility（不支援 Dictionary，用平行 List 替代）
- 本地存檔使用 AES-256 加密（SaveSystem）
- 新增欄位必須有預設值，確保舊存檔反序列化不會失敗

## 命名慣例

- 檔案名 = 類別名（如 `EventManager.cs` 內含 `public static class EventManager`）
- 私有欄位使用 `_camelCase`（如 `_state`, `_autoSaveTimer`）
- 常數使用 `UPPER_SNAKE_CASE`（如 `MAX_LEVEL`, `MONTHLY_RENT`）
- 靜態配置類別的成員直接 public（如 `GameConfig.Ingredients`）

## 專案結構

```
Assets/Scripts/
├── Core/           核心邏輯（不依賴 MonoBehaviour）
│   ├── Models/     資料結構（TrendEvent, CheckInResult 等）
│   └── *.cs        靜態邏輯類別 + GameManager
└── Network/        網路通訊
```

## 關鍵常數（GameConfig）

- `REAL_HOURS_PER_GAME_DAY = 4f`（可能調整為 6f）
- `STARTING_MONEY = 50000`
- `MONTHLY_RENT = 85000`
- `LEADERBOARD_UNLOCK_LEVEL = 15`
- `BUSINESS_OPEN_HOUR = 10`, `BUSINESS_CLOSE_HOUR = 22`

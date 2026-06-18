# Technical Design Document

## Overview

月營收排行榜系統的技術設計。客戶端（Unity）負責分數上傳與排行顯示，後端（Firebase Firestore + Cloud Run）負責即時排名、防作弊校驗與月底結算。

## Architecture

### System Diagram

```
┌──────────────────────────────────────────────────────┐
│                  Unity Client                         │
│                                                      │
│  GameManager ──► NetworkManager ──► HTTPS POST/GET   │
│       │                                    │         │
│       ▼                                    │         │
│  monthlyMetric                             │         │
│  seasonBestRank                            │         │
└────────────────────────────────────────────┼─────────┘
                                             │
                                             ▼
┌──────────────────────────────────────────────────────┐
│                  GCP Backend                          │
│                                                      │
│  ┌─────────────────┐    ┌──────────────────────┐    │
│  │  Cloud Run API  │    │  Cloud Scheduler     │    │
│  │  (REST)         │    │  (monthly cron)      │    │
│  │                 │    │  ┌──────────────┐    │    │
│  │  POST /sync     │    │  │ Settlement   │    │    │
│  │  GET /rankings  │    │  │ Function     │    │    │
│  │  GET /my-rank   │    │  └──────┬───────┘    │    │
│  └────────┬────────┘    └─────────┼────────────┘    │
│           │                       │                  │
│           ▼                       ▼                  │
│  ┌─────────────────────────────────────────────┐    │
│  │              Firebase Firestore              │    │
│  │                                             │    │
│  │  leaderboard/                               │    │
│  │    {yyyy-MM}/                               │    │
│  │      rankings/ (docs sorted by metric)      │    │
│  │    history/                                  │    │
│  │      {yyyy-MM}/ (frozen top 100)           │    │
│  │                                             │    │
│  │  players/                                   │    │
│  │    {playerId} (seasonBestRank, etc.)        │    │
│  └─────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
```

## Components and Interfaces

### Components

| 元件 | 位置 | 職責 |
|------|------|------|
| **LeaderboardManager** | Unity Client (static class) | 排行榜查詢排程、快取、解鎖判定 |
| **NetworkManager** (擴展) | Unity Client | 新增排行榜 API 呼叫方法 |
| **Cloud Run API** | GCP | REST endpoints: /sync, /rankings, /my-rank |
| **Settlement Function** | GCP Cloud Run/Functions | 月底結算邏輯 |
| **Cloud Scheduler** | GCP | 每月 1 號觸發結算 |
| **Firestore** | GCP | 即時排行 + 歷史紀錄 + 玩家資料 |

### Client-Side Interface: LeaderboardManager

```csharp
namespace BubbleTeaTycoon.Core
{
    public static class LeaderboardManager
    {
        /// <summary>排行榜是否已解鎖（level >= LEADERBOARD_UNLOCK_LEVEL）</summary>
        public static bool IsUnlocked(GameState state);

        /// <summary>取得快取的排行榜資料（最近一次成功查詢）</summary>
        public static LeaderboardData GetCachedRankings();

        /// <summary>觸發排行榜查詢（由 GameManager 每 5 分鐘呼叫）</summary>
        public static void RefreshRankings(GameState state, System.Action<bool> callback);

        /// <summary>取得自己的即時排名（from cache）</summary>
        public static int GetMyRank();

        /// <summary>排行榜資料更新時廣播</summary>
        public static event System.Action<LeaderboardData> OnRankingsUpdated;
    }

    [System.Serializable]
    public struct LeaderboardData
    {
        public List<LeaderboardEntry> topRankings; // Top 100
        public int myRank;                          // Player's current rank
        public int myMonthlyMetric;                 // Player's current monthly revenue
        public string month;                        // "yyyy-MM"
        public bool isStale;                        // True if data is from cache (offline)
    }

    [System.Serializable]
    public struct LeaderboardEntry
    {
        public string id;
        public string shopName;
        public int monthlyMetric;
        public int level;
        public int rank;
    }
}
```

### API Endpoints

| Method | Path | 用途 | Request Body | Response |
|--------|------|------|--------------|----------|
| POST | /sync | 上傳分數 | SyncPayload (existing) | `{success, rank, message}` |
| GET | /rankings?month=yyyy-MM | 取得排行 | - | `{rankings: [...], total}` |
| GET | /my-rank?playerId=X&month=yyyy-MM | 取得自己排名 | - | `{rank, monthlyMetric}` |

### Firestore Schema

```
// 即時排行（每月活躍）
leaderboard/{yyyy-MM}/rankings/{playerId}
{
  shopName: string,
  monthlyMetric: number,
  level: number,
  lastSyncUnix: number,
  equipment: { ... },
  staff: { ... }
}

// 歷史紀錄（月底凍結）
leaderboard/history/{yyyy-MM}/{rank}
{
  playerId: string,
  shopName: string,
  monthlyMetric: number,
  level: number,
  rank: number
}

// 玩家資料
players/{playerId}
{
  seasonBestRank: number,   // 0 = never ranked
  lastMonth: string,        // Last active month
  totalMonths: number       // Total months participated
}
```

## Event Flow

### 分數上傳流程

```
GameManager (auto-save / pause / month-end)
  │
  └─► NetworkManager.SyncGameStateToServer(state)
        │
        └─► POST /sync
              │
              ├─ 後端計算 time delta & max possible revenue
              ├─ IF metric delta > theoretical max × 1.2
              │     └─ 回傳 {success: false, message: "score rejected"}
              │        記錄異常 log
              │
              └─ IF valid
                    ├─ 寫入 Firestore: leaderboard/{month}/rankings/{playerId}
                    ├─ 計算即時排名
                    └─ 回傳 {success: true, rank: N}
```

### 月底結算流程

```
Cloud Scheduler (每月 1 號 00:01 UTC)
  │
  └─► Settlement Function
        │
        ├─ 1. 讀取上月 leaderboard/{prev-month}/rankings 全部文件
        ├─ 2. 按 monthlyMetric 降序排序
        ├─ 3. 取前 100 名寫入 leaderboard/history/{prev-month}/
        ├─ 4. 對每位玩家：
        │     ├─ IF rank < players/{id}/seasonBestRank
        │     │     └─ 更新 seasonBestRank
        │     └─ 更新 lastMonth, totalMonths
        ├─ 5. 刪除 leaderboard/{prev-month}/rankings 集合（清空即時排行）
        └─ 6. 記錄結算 log
```

## Error Handling

| 情境 | 處理 |
|------|------|
| 網路不可用 | 顯示快取排行 + "資料非即時" 標籤 |
| 後端拒絕分數 | 本地遊戲不受影響，分數不計入排行 |
| 月底結算失敗 | Cloud Scheduler 自動重試 3 次，失敗後 alert 管理員 |
| 玩家跨月未上線 | 以最後一次上傳為該月最終分數 |
| Firestore 配額超限 | Cloud Run 回傳 503，客戶端 30 秒後重試 |

## Implementation Notes

### 費用估算 (DAU 5,000)

- Firestore 讀取：5000 players × 每 5 分鐘查 1 次 = 6,000 reads/hr = 144K reads/day ≈ $0.09/day
- Firestore 寫入：5000 syncs × 6 次/天 = 30K writes/day ≈ $0.05/day
- Cloud Run：自動縮容，低流量時近乎 $0
- **月費估計：< $10 USD**（遠低於品牌合作收入）

### 客戶端實作優先序

1. 先完成 `LeaderboardManager.cs`（純邏輯，mock data）
2. 再接 NetworkManager 的真實 API 呼叫
3. 最後做 UI（排行榜面板、Season Best 徽章）

### 安全考量

- API endpoint 使用 HTTPS
- playerId 驗證：後續接 Firebase Auth 後，以 Firebase UID 作為 playerId
- Rate limiting：Cloud Run 設定每個 IP 每分鐘最多 30 次請求

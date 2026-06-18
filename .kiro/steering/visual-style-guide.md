---
inclusion: auto
---

# 視覺風格規範 (Unity 版)

## 像素美學 (Pixel Art Aesthetic)

遊戲採用 Minecraft 風格的像素美學，暖色調為主。

## 配色方案 (Color Palette)

| 名稱 | Hex | 用途 |
|------|-----|------|
| Dirt | #866043 | 主要背景、面板底色 |
| Dirt Light | #a07855 | 按鈕 hover、高亮 |
| Dirt Dark | #5c4230 | 邊框、深色背景 |
| Grass | #5d823e | 主要按鈕、正面狀態 |
| Grass Light | #7da05e | 按鈕 hover |
| Grass Dark | #3d622e | 按鈕邊框 |
| Stone | #7a7a7a | 次要按鈕、未選中狀態 |
| Stone Light | #9a9a9a | hover |
| Stone Dark | #5a5a5a | 邊框 |
| Gold | #e3b526 | 金幣、重要數值、高亮文字 |
| Gold Light | #f5d456 | 金幣動畫 |
| Gold Dark | #b38916 | 金幣邊框 |

## 字型

- **VT323** — 數值、正文內容、HUD 顯示
- **Silkscreen** — 標題、商店名稱、重要標語

## UI 規則

- 邊框：4px 實心，底部加厚至 8px（模擬 pixel button 立體感）
- 陰影：4px 4px 0px rgba(0,0,0,0.8)
- 按鈕按下效果：translate(2px, 2px) + 陰影縮小
- 場景切換動畫：0.3s slideIn（平移 + 淡入）
- 數值變化：數字跑馬燈效果（從舊值滾動到新值）

## 螢幕適配

- 目標解析度：1080 × 1920（直式 9:16）
- Canvas Scaler：Scale With Screen Size, Match 0.5
- 所有 UI 使用 Anchor 定位，不使用絕對座標

## 情緒語氣

- 輕鬆幽默、台灣在地感
- Debug 訊息用 emoji prefix（🧋 成功、⚠️ 警告、📰 事件、🔧 升級、👤 員工）
- 事件公告用報紙/推播通知風格

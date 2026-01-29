# **🎨 風格規範與 Agent 協作協議**

## **1\. 視覺風格規範 (Visual Identity)**

* **核心字型**：
  * **VT323**: 用於數值、正文內容。
  * **Silkscreen**: 用於標題、商店名稱。
* **配色方案 (Minecraft Palette)**：  
  * **Dirt (泥土)**: #866043 (Light: #a07855, Dark: #5c4230)
  * **Grass (草地)**: #5d823e (Light: #7da05e, Dark: #3d622e)
  * **Stone (石頭)**: #7a7a7a (Light: #9a9a9a, Dark: #5a5a5a)
  * **Gold (黃金)**: #e3b526 (Light: #f5d456, Dark: #b38916)
* **UI 規則**：  
  * **邊框**: 4px 實心邊框，底部加厚至 8px (PixelButton)。
  * **陰影**: `4px 4px 0px 0px rgba(0,0,0,0.8)`。
  * **動畫**: 進入場景使用 0.3s `slideIn` 平移淡入，關鍵元素使用 `float` 漂浮效果。

## **2\. 技術架構規範**

* **Single Instance**: 邏輯全部封裝於 `index.html` 的 `<script type="text/babel">` 段落中。
* **Zero External Dependencies**: 除 React, ReactDOM, Babel, Tailwind 外，不引用額外 JS 庫。
* **Responsive Layout**: 使用 Flexbox/Grid 確保在直式螢幕下 100% 寬高適配。

## **3\. 數據管理協議**

* **Storage Key**: `bobaKingState` (JSON stringified)。
* **Time Scale**: `REAL_HOURS_PER_GAME_DAY: 2`。
* **Metrics**: 必須包含 `daily`, `monthly`, `total` 三大排行指標。
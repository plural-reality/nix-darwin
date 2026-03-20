---
name: design-format-ir-slides
description: >
  形式A: IRスライド (16:9) デザイントークンとパターン集。
  ウォームグレーキャンバス、チャコールカード (16px角丸)、バッジ、チャート、テーブル。
  「スライド」「プレゼン」「事業報告」「決算」「ピッチ」で発動。
  参考: ~/Desktop/plural-reality-ir-style-preview.html
---

# 形式A: IRスライド（16:9）

事業報告・決算・ピッチ・千人会議のような概要資料に使用。

## CSS変数

```css
:root {
  --canvas: #C5C5C5;
  --card: #1E1E1E;
  --card-alt: #2A2A2A;
  --card-stripe: #2F2F2F;
  --text-on-canvas: #1E1E1E;
  --text-on-card: #FFFFFF;
  --text-muted-canvas: #5A5A5A;
  --text-muted-card: #8A8A8A;
  --radius-card: 16px;
  --radius-badge: 6px;
  --radius-dot: 50%;
  --font-sans: "Public Sans", "Noto Sans JP", "Helvetica Neue", Arial, sans-serif;
  --font-mono: "JetBrains Mono", monospace;
  --slide-pad: 48px;
  --slide-gap: 24px;
}
body { background: #E8E8E8; }
```

## スライドコンテナ
```css
.slide { aspect-ratio: 16/9; background: var(--canvas); border-radius: 8px; padding: 48px; position: relative; overflow: hidden; margin-bottom: 24px; display: flex; flex-direction: column; box-shadow: 0 4px 24px rgba(0,0,0,0.12); }
.slide-wrapper { max-width: 1200px; margin: 32px auto; padding: 0 24px; }
```

## タイポグラフィ

| 要素 | サイズ | ウェイト | spacing |
|---|---|---|---|
| slide-title | 48px | 300 | -0.02em |
| slide-title-lg | 160px | 300 | -0.04em |
| slide-subtitle | 24px | 300 | -0.01em |
| slide-body | 16px | 400 | — |
| slide-caption | 12px | — | — |
| slide-footer | 10px | — | abs bottom 16px |
| section-label | 10px (mono) | 500 | 0.08em, uppercase |

**重要**: 見出しウェイトは 300（Light）。Web の 400 より軽い。

## コンポーネント

### バッジ
```css
.badge-item { font-size: 11px; font-weight: 500; padding: 4px 10px; background: var(--card); color: var(--text-on-card); border-radius: 6px; }
.badge-item + .badge-item { margin-left: 4px; }
/* ライトバリアント */
.badge-light .badge-item { background: rgba(0,0,0,0.08); color: var(--text-on-canvas); }
```

### ダークカード
```css
.dark-card { background: var(--card); border-radius: 16px; padding: 40px; color: var(--text-on-card); flex: 1; }
.dark-card-half { background: var(--card); border-radius: 16px; padding: 32px; color: var(--text-on-card); }
```

### ナビゲーションドット
```css
.dot { width: 24px; height: 24px; border-radius: 50%; border: 1.5px solid var(--text-on-card); background: transparent; }
.dot.active { background: var(--text-on-card); }
/* 配置: position absolute, bottom 32px, right slide-pad */
```

### テーブル
```css
.ir-table { width: 100%; border-collapse: collapse; font-size: 14px; }
.ir-table th { font-family: var(--font-mono); font-size: 10px; font-weight: 500; text-transform: uppercase; letter-spacing: 0.08em; text-align: right; padding: 8px 16px; color: var(--text-muted-card); border-bottom: 1px solid rgba(255,255,255,0.1); }
.ir-table th:first-child { text-align: left; }
.ir-table td { padding: 10px 16px; text-align: right; font-variant-numeric: tabular-nums; }
.ir-table td:first-child { text-align: left; color: var(--text-muted-card); }
.ir-table tr.stripe { background: var(--card-stripe); }
.ir-table tr.total { border-top: 2px solid rgba(255,255,255,0.2); font-weight: 600; }
```

### ハイライトリスト
```css
.highlight-list { list-style: none; display: flex; flex-direction: column; gap: 2px; }
.highlight-item { background: var(--card); color: var(--text-on-card); padding: 12px 20px; font-size: 14px; display: flex; align-items: baseline; gap: 12px; }
.highlight-item:first-child { border-radius: 6px 6px 0 0; }
.highlight-item:last-child { border-radius: 0 0 6px 6px; }
.highlight-arrow { font-size: 12px; color: var(--text-muted-card); }
```

### バーチャート
```css
.bar-chart { display: flex; align-items: flex-end; gap: 32px; height: 200px; border-bottom: 1px solid rgba(255,255,255,0.15); }
.bar { width: 48px; background: #FFFFFF; border-radius: 2px 2px 0 0; }
.bar-outline { width: 48px; border: 1.5px solid rgba(255,255,255,0.4); border-radius: 2px 2px 0 0; background: transparent; }
.bar-label { font-size: 11px; color: var(--text-muted-card); }
.bar-value { font-size: 16px; font-weight: 600; color: var(--text-on-card); }
```

### セパレーター
```css
.separator { width: 100%; height: 1px; background: rgba(255,255,255,0.15); margin: 16px 0; }
```

## レイアウト
```css
.split { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; flex: 1; }
.split-text-chart { display: grid; grid-template-columns: 2fr 3fr; gap: 24px; flex: 1; }
.guidance-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; flex: 1; }
```

## 画像レイアウトパターン

### A. ヒーロー画像 + テキスト分割
右に実写画像（100%高さ、40-50%幅）、左にテキスト。事例紹介・導入ストーリーに使用。
```css
.hero-split {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0;
  flex: 1;
  overflow: hidden;
}
.hero-split-text {
  background: var(--card);
  color: var(--text-on-card);
  padding: 48px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
.hero-split-image {
  position: relative;
  overflow: hidden;
  border-radius: 0 16px 16px 0;
}
.hero-split-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
/* テキスト重ねる場合のオーバーレイ */
.hero-split-image::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(to right, var(--card) 5%, transparent 40%);
}
```

### B. フルブリードヒーロー（全面画像 + テキストオーバーレイ）
セクション区切りやインパクトスライドに使用。
```css
.hero-fullbleed {
  position: relative;
  flex: 1;
  overflow: hidden;
  border-radius: 16px;
}
.hero-fullbleed img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  position: absolute;
  inset: 0;
}
.hero-fullbleed-overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(to top, rgba(30,30,30,0.9) 30%, rgba(30,30,30,0.3) 60%, transparent);
  padding: 48px;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  color: var(--text-on-card);
}
```

### C. スクリーンショットグリッド（プロダクトデモ用）
複数の UI スクリーンショットを有機的に配置。
```css
.screenshot-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-template-rows: auto;
  gap: 12px;
  flex: 1;
  background: var(--card);
  border-radius: 16px;
  padding: 32px;
}
.screenshot-grid img {
  width: 100%;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.3);
}
/* 大きなスクリーンショットは 2col span */
.screenshot-grid .featured {
  grid-column: span 2;
}
```

### D. KPI + 画像コンテキスト
数値データの横に、その数値が示す現場の画像を配置。
```css
.kpi-with-context {
  display: grid;
  grid-template-columns: 2fr 3fr;
  gap: 24px;
  flex: 1;
}
.kpi-with-context .kpi-panel {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 16px;
}
.kpi-with-context .context-image {
  border-radius: 16px;
  overflow: hidden;
}
.kpi-with-context .context-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
```

### 画像使用ルール
- **アスペクト比**: 16:9（スライド合わせ）or 4:3（カード内）
- **最小解像度**: 1920x1080（フルブリード時）
- **色調**: 高コントラスト、彩度控えめ。ダーク背景に自然に溶ける暗めのトーンを選ぶ
- **被写体**: プロダクト UI、実際の業務風景、インフラ。人物は実在のチーム・顧客のみ
- **参考素材**: `/Users/tkgshn/palantir-presentations/Q4_2024_Feb2025/` の slide_001, slide_015, slide_040 が典型

## 8枚スライドパターン

1. **表紙**: ダークカード全面。大数字 (96px, Light) + ロゴ + 年度。ナビドット4つ (first active)
2. **ハイライト**: バッジ [Q1|事業概要]。ハイライトリスト (→ 付き7行)
3. **KPIチャート**: split-text-chart (2:3)。左テキスト、右ダークカード内バーチャート (outline→filled)
4. **導入事例**: ダークカード全面 (no slide padding)。テキスト max 55%。共同ロゴ下部
5. **テーブル**: バッジ light [付録]。ダークカード内 ir-table。stripe + total 行
6. **ガイダンス**: バッジ [Q1|見通し]。guidance-grid (2つの dark-card-half)
7. **セクション区切り**: 表紙と同構造。ドットの active 変更
8. **プロダクト概要**: ダークカード全面。grid 3col。各プロダクト = border card (12px radius)

## 参考ファイル
- テンプレート: `~/Desktop/plural-reality-ir-style-preview.html`
- 適用例: `~/Desktop/kokumyaku-ir.html`

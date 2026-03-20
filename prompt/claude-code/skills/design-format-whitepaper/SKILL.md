---
name: design-format-whitepaper
description: >
  形式B: ホワイトペーパー (A4) デザイントークンとパターン集。
  2カラム (30%/70%)、青アクセント見出し、モジュール構造、概念グリッド。
  「ホワイトペーパー」「技術文書」「導入ガイド」で発動。
  参考: ~/Desktop/plural-reality-whitepaper-style.html
---

# 形式B: ホワイトペーパー（A4 縦）

技術文書・導入ガイド・事例紹介（詳細版）に使用。

## CSS変数

```css
:root {
  --bg: #FFFFFF;
  --text: #000000;
  --accent: #2196F3;
  --muted: #666666;
  --border: #000000;
  --font-sans: "Public Sans", "Noto Sans JP", sans-serif;
  --font-mono: "JetBrains Mono", monospace;
}
body { background: #F0F0F0; font-weight: 400; line-height: 1.7; }
```

## ページ構造
```css
.document { max-width: 816px; margin: 0 auto; background: var(--bg); box-shadow: 0 0 40px rgba(0,0,0,0.08); }
.page { padding: 60px; min-height: 1056px; position: relative; display: flex; flex-direction: column; }
.page + .page { border-top: 1px solid var(--border); }
```

## フッター
```css
.page-footer { display: flex; align-items: center; justify-content: space-between; padding-top: 24px; margin-top: auto; border-top: 1px solid #E0E0E0; font-size: 10px; color: var(--muted); }
/* 左: ロゴマーク (14px黒四角 + 社名)、中央: 機密注記、右: ページ番号 */
.logo-mark { width: 14px; height: 14px; background: var(--text); display: flex; align-items: center; justify-content: center; font-size: 8px; color: var(--bg); font-weight: 700; }
```

## タイポグラフィ

| 要素 | サイズ | ウェイト | 色 |
|---|---|---|---|
| cover-title | 48px | 300 | black |
| cover-subtitle | 18px | 400 | muted |
| col-label | 20px | 600 | **accent (#2196F3)** |
| col-body | 14px | — | black, line-height 1.8 |
| module-tag | 13px | 600 | accent, uppercase, 0.08em |
| module-title | 32px | 300 | black |
| section-title | 24px | 600 | accent |
| body-text | 14px | — | black, line-height 1.8 |

## コンポーネント

### 2カラムレイアウト
```css
.two-col { display: grid; grid-template-columns: 30% 1fr; gap: 40px; margin-bottom: 48px; }
.col-label { font-size: 20px; font-weight: 600; color: var(--accent); line-height: 1.4; }
.col-body { font-size: 14px; line-height: 1.8; }
```

### 矢印リスト
```css
.arrow-list li { position: relative; padding-left: 24px; margin-bottom: 12px; font-size: 14px; line-height: 1.7; }
.arrow-list li::before { content: "→"; position: absolute; left: 0; color: var(--accent); font-weight: 500; }
```

### モジュール見出し
```css
.module-tag { font-size: 13px; font-weight: 600; color: var(--accent); letter-spacing: 0.08em; text-transform: uppercase; margin-bottom: 8px; }
.module-title { font-size: 32px; font-weight: 300; line-height: 1.3; }
```

### スクリーンショットプレースホルダー
```css
.screenshot-placeholder { background: #F5F5F5; border: 1px solid #E0E0E0; min-height: 280px; display: flex; align-items: center; justify-content: center; margin: 32px 0; }
.screenshot-caption { font-size: 11px; color: var(--muted); margin-top: -24px; font-style: italic; }
```

### 概念グリッド
```css
.concept-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 40px 48px; }
.concept-number { font-size: 11px; font-weight: 600; color: var(--muted); letter-spacing: 0.1em; text-transform: uppercase; margin-bottom: 8px; }
.concept-title { font-size: 18px; font-weight: 600; color: var(--accent); margin-bottom: 12px; }
.concept-body { font-size: 13px; line-height: 1.7; }
.concept-tag { font-family: var(--font-mono); font-size: 11px; color: var(--muted); background: #F5F5F5; padding: 3px 8px; border: 1px solid #E8E8E8; }
```

### 事例レイアウト
```css
.case-study-layout { display: grid; grid-template-columns: 45% 1fr; gap: 48px; }
.case-study-callout { font-size: 28px; font-weight: 300; line-height: 1.4; }
.case-study-callout .arrow { color: var(--accent); }
.stat-value { font-family: var(--font-mono); font-size: 28px; font-weight: 500; color: var(--accent); }
.stat-label { font-size: 12px; color: var(--muted); margin-top: 4px; }
.case-study-stat { font-family: var(--font-mono); font-size: 13px; font-weight: 500; color: var(--accent); background: #F0F7FF; padding: 2px 8px; }
```

### セクション区切り
```css
.section-rule { border: none; border-top: 1px solid var(--border); margin: 48px 0; }
```

## 表紙パターン
- ヘッダー: ロゴマーク (28px黒四角 + 社名 16px/600)
- タイトル: 48px, Light, margin-bottom 16px
- サブタイトル: 18px, 400, muted
- 写真プレースホルダー: flex-1, gradient bg
- フッター: ロゴ + "XXXX" / "Confidential — © YYYY"

## 5ページ構成パターン
1. **表紙**: ロゴ + タイトル + 写真
2. **導入**: 2カラム (col-label青 + col-body) × 2セクション + section-rule
3. **モジュール**: module-tag "MODULE 1 ↘" + module-title + 2カラム + スクリーンショット
4. **概念グリッド**: section-title + concept-grid 2×2
5. **事例**: module-tag "CASE STUDY ↘" + case-study-layout (callout + detail + stats)

## 参考ファイル
- テンプレート: `~/Desktop/plural-reality-whitepaper-style.html`
- 適用例: `~/Desktop/kokumyaku-whitepaper.html`

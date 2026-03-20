---
name: design-format-partnership
description: >
  形式C: パートナーシップ資料 (A4) デザイントークンとパターン集。
  完全モノクロ、引用ページ、目次、タイムラインテーブル、写真グリッドオーバーレイ。
  「協業」「パートナーシップ」「ケーススタディ」「協業資料」で発動。
  参考: ~/Desktop/plural-reality-partnership-style.html
---

# 形式C: パートナーシップ資料（A4 縦）

協業概要・導入効果調査・ケーススタディ（ストーリー仕立て）に使用。

## CSS変数

```css
:root {
  --bg: #FFFFFF;
  --text: #000000;
  --muted: #666666;
  --font-sans: "Public Sans", "Noto Sans JP", sans-serif;
  --font-mono: "JetBrains Mono", monospace;
}
body { background: #F0F0F0; font-weight: 300; font-size: 15px; line-height: 1.7; }
```

**ホワイトペーパーとの違い:**
- **アクセントカラーなし**（青も使わない。完全モノクロ）
- body の基本ウェイトが 300（Light）
- 余白がさらに広い（80px vs 60px）
- 引用ページ・目次ページが特徴的

## ページ構造
```css
.document { max-width: 816px; margin: 40px auto; background: var(--bg); box-shadow: 0 1px 8px rgba(0,0,0,0.08); }
.page { padding: 80px 80px 60px 80px; min-height: 1056px; position: relative; display: flex; flex-direction: column; }
.page-break { border: none; border-top: 1px solid #E0E0E0; }
```

## フッター
```css
.page-footer { margin-top: auto; padding-top: 24px; border-top: 1px solid var(--text); display: flex; justify-content: space-between; align-items: center; font-size: 11px; color: var(--muted); }
.page-number { font-family: var(--font-mono); font-size: 11px; color: var(--text); }
```

## コンポーネント

### 表紙
```css
.cover-logo { font-size: 13px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; margin-bottom: 120px; }
.cover-title { font-size: 42px; font-weight: 700; line-height: 1.15; letter-spacing: -0.01em; margin-bottom: 16px; }
.cover-subtitle { font-size: 20px; font-weight: 300; color: var(--muted); margin-bottom: 48px; }
.cover-rule { border: none; border-top: 2px solid var(--text); margin-bottom: 16px; }
.cover-meta { display: flex; justify-content: space-between; font-size: 12px; font-weight: 400; letter-spacing: 0.04em; text-transform: uppercase; }
```

### 写真プレースホルダー（グリッドオーバーレイ）
```css
.cover-photo { width: 100%; height: 320px; background: linear-gradient(135deg, #E8E8E8, #D0D0D0, #C0C0C0); display: flex; align-items: center; justify-content: center; position: relative; overflow: hidden; }
.cover-photo::before { content: ""; position: absolute; inset: 0; background: repeating-linear-gradient(0deg, transparent, transparent 39px, rgba(0,0,0,0.03) 39px, rgba(0,0,0,0.03) 40px), repeating-linear-gradient(90deg, transparent, transparent 39px, rgba(0,0,0,0.03) 39px, rgba(0,0,0,0.03) 40px); }
```

### 引用ページ
```css
.quote-page { padding: 80px 80px 60px 80px; min-height: 1056px; display: flex; flex-direction: column; justify-content: center; }
.quote-text { font-size: 28px; font-weight: 300; line-height: 1.55; letter-spacing: -0.005em; max-width: 600px; }
.quote-attribution .name { font-weight: 600; font-size: 15px; }
.quote-attribution .role { color: var(--muted); font-size: 14px; }
```

### 目次（インデックス）ページ
```css
.index-label { font-size: 14px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; margin-bottom: 80px; }
.index-item { border-top: 1px solid var(--text); padding: 28px 0; display: flex; align-items: baseline; gap: 24px; }
.index-item:last-child { border-bottom: 1px solid var(--text); }
.index-number { font-size: 16px; font-weight: 600; font-family: var(--font-mono); flex: 0 0 80px; }
.index-title { font-size: 22px; font-weight: 600; line-height: 1.3; }
.index-subtitle { font-size: 15px; font-weight: 300; color: var(--muted); }
```

### セクションヘッダー
```css
.section-header { padding: 32px 80px; border-bottom: 1px solid #E0E0E0; display: flex; align-items: flex-start; justify-content: space-between; gap: 40px; }
.section-header-logo { font-size: 12px; font-weight: 600; letter-spacing: 0.06em; text-transform: uppercase; }
.section-header-number { font-size: 12px; font-weight: 400; color: var(--muted); font-family: var(--font-mono); }
.section-header-title { font-size: 20px; font-weight: 700; line-height: 1.25; }
```

### 2カラム本文
```css
.two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 48px; }
.col-left .statement { font-size: 22px; font-weight: 400; line-height: 1.55; letter-spacing: -0.005em; }
.col-left .statement .arrow { font-size: 26px; }
.col-right p { font-size: 14px; font-weight: 300; line-height: 1.75; color: #1A1A1A; margin-bottom: 20px; }
.col-right .highlight { font-weight: 600; }
```

### タイムラインテーブル
```css
.timeline-label { font-size: 11px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; color: var(--muted); margin-bottom: 24px; }
.timeline-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.timeline-table thead th { text-align: left; font-size: 10px; font-weight: 600; letter-spacing: 0.1em; text-transform: uppercase; color: var(--muted); padding: 12px 16px 12px 0; border-bottom: 2px solid var(--text); }
.timeline-table tbody td { padding: 16px 16px 16px 0; border-bottom: 1px solid #E0E0E0; font-weight: 300; }
.timeline-table tbody td:first-child { font-weight: 600; font-family: var(--font-mono); font-size: 12px; }
.timeline-table tbody tr:last-child td { border-bottom: 2px solid var(--text); }
```

## 5ページ構成パターン
1. **表紙**: ロゴ + タイトル (42px/700) + サブタイトル + 2px黒ルール + メタ + 写真
2. **引用**: 全ページ使い切り。大クオート (28px/300) + 人名・肩書き
3. **目次**: "目次 ↘" + 番号付きインデックス (border-top区切り)
4. **本文**: セクションヘッダー + 2カラム (声明文22px + 詳細14px)
5. **タイムライン**: セクションヘッダー + テーブル + 写真

## 参考ファイル
- テンプレート: `~/Desktop/plural-reality-partnership-style.html`
- 適用例: `~/Desktop/kokumyaku-partnership.html`

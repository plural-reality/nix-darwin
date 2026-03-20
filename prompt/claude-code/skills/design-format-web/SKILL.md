---
name: design-format-web
description: >
  形式E: Web / LP / デジタルコンテンツ用デザイントークンとパターン集。
  角丸0px、ライト/ダーク切替、7:5グリッド、KPI 80px。
  参考: ~/Desktop/plural-reality-design-preview.html
---

# 形式E: Web（LP・デジタルコンテンツ）

## CSS変数

```css
:root {
  --background: #ffffff;
  --foreground: #111111;
  --secondary: #f3f3f3;
  --muted-foreground: #525252;
  --brand: #0f766e;
  --brand-foreground: #ffffff;
  --border: #e5e5e5;
  --destructive: #ef4444;
  --font-sans: "Public Sans", "Noto Sans JP", "Helvetica Neue", Arial, sans-serif;
  --font-mono: "JetBrains Mono", "SF Mono", Consolas, monospace;
  --radius: 0px;
}
[data-theme="dark"] {
  --background: #000000;
  --foreground: #ffffff;
  --secondary: #1c2127;
  --muted-foreground: #d4d9df;
  --brand: #2dd4bf;
  --brand-foreground: #000000;
  --border: #383e47;
  --card-bg: #1c2127;
  --muted-bg: #2f343c;
}
```

## レイアウト
- コンテナ: max-width 1440px, padding 0 48px
- セクション: padding 96px 0, border-top 1px solid var(--border)
- グリッド: `.grid-2` (1fr 1fr gap 32px), `.grid-3`, `.grid-4`, `.grid-7-5` (7fr 5fr gap 48px)

## タイポグラフィ

| クラス | サイズ | ウェイト | letter-spacing | line-height |
|---|---|---|---|---|
| .display | 80px | 400 | -0.02em | 1.1 |
| .h1 | 54px | 400 | -0.02em | 1.1 |
| .h2 | 42px | 400 | -0.02em | 1.2 |
| .h3 | 27px | 400 | -0.02em | 1.3 |
| .body-text | 18px | 300 | 0.01em | 1.6 |
| .caption | 14px | — | — | 1.5 |
| .tech-label | 10px (mono) | 500 | 0.125em | — |
| .kpi-value | 80px | 700 | -0.02em | 1.0 |
| .kpi-label | 11px (mono) | 500 | 0.125em | — |

## コンポーネント

### ボタン
```css
.btn { height: 48px; padding: 0 24px; font-size: 14px; font-weight: 500; border-radius: 0px; transition: all 300ms; }
.btn-ghost { background: transparent; border: 1px solid var(--foreground); color: var(--foreground); }
.btn-ghost:hover { background: var(--foreground); color: var(--background); }
.btn-primary { background: var(--foreground); border: 1px solid var(--foreground); color: var(--background); }
```

### カード
```css
.card { border-top: 1px solid var(--border); padding: 32px 0; }
.card:hover { border-color: var(--foreground); }
.card-filled { background: var(--secondary); padding: 32px; }
```

### 引用ブロック
```css
.quote-block { background: var(--secondary); padding: 64px; }
.quote-text { font-size: 28px; font-weight: 300; font-style: italic; line-height: 1.5; letter-spacing: -0.01em; }
.quote-attribution { font-size: 14px; color: var(--muted-foreground); margin-top: 24px; }
```

### KPI
```css
.kpi-value { font-size: 80px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.0; }
.kpi-label { font-family: var(--font-mono); font-size: 11px; font-weight: 500; text-transform: uppercase; letter-spacing: 0.125em; color: var(--muted-foreground); margin-top: 8px; }
```

### ダーク反転セクション
```css
.section-dark { background: var(--foreground); color: var(--background); padding: 96px 0; }
.section-dark .tech-label { color: rgba(255,255,255,0.5); }
.section-dark .body-text { color: rgba(255,255,255,0.7); }
```

### ライト/ダーク切替
固定 top-right。2ボタン (LIGHT / DARK)。active = foreground bg。

## アニメーション
```css
@keyframes fadeInUp { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
.animate-in { animation: fadeInUp 600ms ease-out both; }
.delay-1 { animation-delay: 100ms; } .delay-2 { 200ms; } .delay-3 { 300ms; } .delay-4 { 400ms; }
```

## セクション構成パターン（LP向け）
1. **ヒーロー**: tech-label + display見出し + body-text + 2ボタン (padding 128px 0 96px)
2. **KPI**: h2 + grid-4 (kpi-value + kpi-label)
3. **プロダクトカード**: grid-3, border-top cards (tech-label + h3 + body-text)
4. **引用**: quote-block (secondary bg, 64px padding)
5. **ダーク反転**: section-dark (tech-label + h1 + body-text)
6. **7:5レイアウト**: grid-7-5 (テキスト左 + カード右)
7. **価格**: grid-3 (kpi-value for price + kpi-label for plan)
8. **フッター**: caption copyright + tech-label version

## 参考ファイル
- テンプレート: `~/Desktop/plural-reality-design-preview.html`
- 適用例: `~/Desktop/kokumyaku-web.html`

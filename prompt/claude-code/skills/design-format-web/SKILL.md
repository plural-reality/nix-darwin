---
name: design-format-web
description: >
  形式E: Web / LP / デジタルコンテンツのレイアウトとコンポーネント集。
  screen register（ダーク既定）、角丸0、7:5グリッド、KPI。値は plural-reality-design-system/tokens.css を参照する。
  「Webサイト」「LP」「ランディングページ」「Webデザイン」「デジタルコンテンツ」で発動。
---

> **値の参照**: 色・書体・ウェイト・角丸・余白・動きは傘 skill `plural-reality-design-system/tokens.css` を inline して `var(--*)` で参照する。このファイルには hex・フォント名・角丸の px を書かない。用途の振り分けとロゴは傘 SKILL.md、表記は傘の `style-guide.md`、仕上げに傘の `scripts/brand-lint` を通す。
>
> **register**: `screen`（ダーク）が既定。白い面が必要なセクションだけ `data-register="document"` を付ける。

# 形式E: Web（LP・デジタルコンテンツ）

## CSS

`tokens.css` を先頭に inline し、この形式で足すのはレイアウトの変数だけ。

```css
/* tokens.css をここに inline */
body { background: var(--bg); color: var(--fg); font-family: var(--font-sans); font-weight: var(--weight-regular); line-height: var(--leading-body); letter-spacing: var(--tracking-body); }
.container { max-width: var(--container); margin: 0 auto; padding: 0 var(--space-4); }
@media (min-width: 768px) { .container { padding: 0 var(--space-5); } }
@media (min-width: 1024px) { .container { padding: 0 var(--space-6); } }
```

## レイアウト
- コンテナ: `.container`（`--container`、左右 `--space-4`→`--space-6`）。Section の中にさらに container を入れない（余白が二重になる）
- セクション: `padding: var(--space-8) 0; border-top: 1px solid var(--border);`
- グリッド: `.grid-2`（1fr 1fr、gap `--space-5`）、`.grid-3`、`.grid-4`、`.grid-7-5`（7fr 5fr、gap `--space-6`）

## タイポグラフィ

| クラス | サイズ | ウェイト | letter-spacing | line-height |
|---|---|---|---|---|
| .display | `--text-display` | `--weight-regular` | `--tracking-heading` | `--leading-tight` |
| .h1 | `--text-h1` | `--weight-regular` | `--tracking-heading` | `--leading-tight` |
| .h2 | `--text-h2` | `--weight-regular` | `--tracking-heading` | 1.2 |
| .h3 | `--text-h3` | `--weight-regular` | -0.01em | 1.3 |
| .lead | `--text-lead` | `--weight-light` | `--tracking-body` | 1.6 |
| .body-text | `--text-body` | `--weight-regular` | `--tracking-body` | `--leading-body` |
| .caption | `--text-caption` | `--weight-regular` | — | 1.5 |
| .tech-label | `--text-label`（`--font-mono`） | `--weight-medium` | `--tracking-label`（和文は `--tracking-label-ja`） | — |
| .kpi-value | `--text-kpi` | `--weight-kpi` | `--tracking-heading` | 1.0、`font-variant-numeric: tabular-nums` |
| .kpi-label | `--text-label`（`--font-mono`） | `--weight-medium` | `--tracking-label` | — |

## コンポーネント

### ボタン
```css
.btn { height: 48px; padding: 0 var(--space-4); font-size: var(--text-caption); font-weight: var(--weight-medium); border-radius: var(--radius); transition: background-color var(--duration-base) var(--ease), color var(--duration-base) var(--ease); }
.btn-ghost { background: transparent; border: 1px solid var(--fg); color: var(--fg); }
.btn-ghost:hover { background: var(--fg); color: var(--bg); }
.btn-primary { background: var(--fg); border: 1px solid var(--fg); color: var(--bg); }
.btn-brand { background: var(--accent-ui); border: 1px solid var(--accent-ui); color: var(--accent-fg); } /* 文字は黒。1画面に1つまで */
.btn:focus-visible { outline: 2px solid var(--ring); outline-offset: 2px; }
```

### カード
```css
.card { border-top: 1px solid var(--border); padding: var(--space-5) 0; transition: border-color var(--duration-base) var(--ease); }
.card:hover { border-color: var(--border-strong); }
.card-filled { background: var(--surface-1); padding: var(--space-5); }
```

### 引用ブロック
```css
.quote-block { background: var(--surface-1); padding: var(--space-7); }
.quote-text { font-size: var(--text-h3); font-weight: var(--weight-light); line-height: 1.5; } /* 斜体は掛けない（和文が合成斜体になる） */
.quote-attribution { font-size: var(--text-caption); color: var(--fg-muted); margin-top: var(--space-4); }
```

### KPI
```css
.kpi-value { font-size: var(--text-kpi); font-weight: var(--weight-kpi); letter-spacing: var(--tracking-heading); line-height: 1.0; font-variant-numeric: tabular-nums; }
.kpi-label { font-family: var(--font-mono); font-size: var(--text-label); font-weight: var(--weight-medium); letter-spacing: var(--tracking-label); color: var(--fg-muted); margin-top: var(--space-2); }
```
KPI は数えられる実績だけ（自治体数・参加者数・意見数）。出典のない率は載せない（傘 `style-guide.md` §4）。

### 反転セクション
既定がダークなので、白い面は register で切り替える。不透明度で文字を薄くしない。
```html
<section data-register="document" class="section-inverse">…</section>
```
```css
.section-inverse { background: var(--bg); color: var(--fg); padding: var(--space-8) 0; }
.section-inverse .tech-label, .section-inverse .body-text { color: var(--fg-muted); }
```

### フッター
会社マーク（傘 `assets/mark-white.svg`）＋「合同会社多元現実」＋法務リンク（プライバシーポリシー・会社概要）＋ `© 2026 Plural Reality LLC`。プロダクトの LP でもこの行は揃える（A3）。

## アニメーション
```css
@keyframes fadeInUp { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
.animate-in { animation: fadeInUp var(--duration-enter) var(--ease) both; }
.delay-1 { animation-delay: 100ms; } .delay-2 { animation-delay: 200ms; } .delay-3 { animation-delay: 300ms; } .delay-4 { animation-delay: 400ms; }
@media (prefers-reduced-motion: reduce) { .animate-in { animation: none; } }
```

## セクション構成パターン（LP向け）
1. **ヒーロー**: tech-label + display見出し + body-text + 2ボタン (padding 128px 0 96px)
2. **KPI**: h2 + grid-4 (kpi-value + kpi-label)
3. **プロダクトカード**: grid-3, border-top cards (tech-label + h3 + body-text)
4. **引用**: quote-block（`--surface-1`）
5. **反転**: section-inverse（`data-register="document"`、tech-label + h1 + body-text）
6. **7:5レイアウト**: grid-7-5 (テキスト左 + カード右)
7. **価格**: grid-3 (kpi-value for price + kpi-label for plan)
8. **フッター**: 上記「フッター」

## 参考ファイル
- 値: `plural-reality-design-system/tokens.css`
- 実装例: HP `plural-reality/website`（移行中。teal と Public Sans が残っている箇所は手本にしない）
- 適用例: Drive「デザインシステム/kokumyaku/」フォルダ(ローカル無し・原典置き場) https://drive.google.com/drive/folders/1ZqSxWJVCbVu1uQ0ZsFGcNSXFnt3Liq3H

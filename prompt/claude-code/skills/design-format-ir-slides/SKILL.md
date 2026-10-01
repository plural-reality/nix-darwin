---
name: design-format-ir-slides
description: >
  形式A: IRスライド (16:9) のレイアウトとパターン集。
  白地（document / print register）＋面とhairline、角丸0、バッジ、モノクロチャート、テーブル。画面投影だけダーク面可。
  値は plural-reality-design-system/tokens.css を参照する。
  「スライド」「プレゼン」「事業報告」「決算」「ピッチ」で発動。
---

> **値の参照**: 色・書体・ウェイト・角丸・余白は傘 skill `plural-reality-design-system/tokens.css` を inline して `var(--*)` で参照する。このファイルには hex・フォント名・角丸の px を書かない。用途の振り分けとロゴは傘 SKILL.md、表記（数値と出典・図表・日付・©）は傘の `style-guide.md`、仕上げに傘の `scripts/brand-lint` を通す。
>
> **register**: 既定は `document`（白）。配布・印刷する版は `print`（アクセントが墨に落ちる）。画面投影だけの版に限り、カードやスライドに `data-register="screen"` を付けてダーク面にしてよい。多元の資料は印刷・白黒コピーされる前提なので、ダーク面を既定にしない。
>
> **出力の既知の断絶**: この 16:9 HTML は スクショ / print-PDF が最終形。HTML デザイン → 実 Google Slides への自動経路は無い（Slides は HTML インポート非対応＝手動で作り直し）。`.pptx` 専用ツールも無い。`gws slides` は既存ネイティブ Slides の inplace 編集（get/batchUpdate）専用。

# 形式A: IRスライド（16:9）

事業報告・決算・ピッチ・千人会議のような概要資料に使用。

## CSS

```css
/* tokens.css をここに inline。<html data-register="document">（配布版は "print"） */
:root { --slide-pad: var(--space-6); --slide-gap: var(--space-4); }
body { background: var(--surface-2); color: var(--fg); font-family: var(--font-sans); }
```

## スライドコンテナ
```css
.slide { aspect-ratio: 16/9; background: var(--bg); color: var(--fg); border-radius: var(--radius); padding: var(--slide-pad); position: relative; overflow: hidden; margin-bottom: var(--slide-gap); display: flex; flex-direction: column; }
.slide-wrapper { max-width: 1200px; margin: var(--space-5) auto; padding: 0 var(--space-4); }
/* 画面投影だけのダーク版: <section class="slide" data-register="screen"> */
```

## タイポグラフィ

| 要素 | サイズ | ウェイト | spacing |
|---|---|---|---|
| slide-title | 48px | `--weight-light` | `--tracking-heading` |
| slide-title-lg | 160px | `--weight-light` | -0.04em |
| slide-subtitle | 24px | `--weight-light` | -0.01em |
| slide-body | 16px | `--weight-regular` | `--tracking-body` |
| slide-caption | 12px | `--weight-regular` | — |
| slide-footer | 10px | `--weight-regular` | abs bottom 16px。左に `© 2026 Plural Reality LLC`、右にページ番号 |
| section-label | 10px（`--font-mono`） | `--weight-medium` | `--tracking-label-ja`。和文で書く |

見出しウェイトは 300（Light）。数値は `font-variant-numeric: tabular-nums`。

## コンポーネント

### バッジ
```css
.badge-item { font-size: 11px; font-weight: var(--weight-medium); padding: 4px 10px; background: var(--fg); color: var(--bg); border-radius: var(--radius-pill); }
.badge-item + .badge-item { margin-left: 4px; }
.badge-light .badge-item { background: var(--surface-2); color: var(--fg); }
```

### パネル（カード）
```css
.panel { background: var(--surface-1); border-top: 1px solid var(--border-strong); border-radius: var(--radius); padding: 40px; flex: 1; }
.panel-half { background: var(--surface-1); border-top: 1px solid var(--border-strong); padding: 32px; }
/* 画面投影版で反転させたいパネルだけ data-register="screen" を付ける */
```

### ナビゲーションドット
```css
.dot { width: 12px; height: 12px; border-radius: var(--radius-pill); border: 1.5px solid var(--fg); background: transparent; }
.dot.active { background: var(--fg); }
/* 配置: position absolute, bottom 32px, right var(--slide-pad) */
```

### テーブル
```css
.ir-table { width: 100%; border-collapse: collapse; font-size: 14px; }
.ir-table th { font-family: var(--font-mono); font-size: 10px; font-weight: var(--weight-medium); letter-spacing: var(--tracking-label-ja); text-align: right; padding: 8px 16px; color: var(--fg-muted); border-bottom: 1px solid var(--border-strong); }
.ir-table th:first-child { text-align: left; }
.ir-table td { padding: 10px 16px; text-align: right; font-variant-numeric: tabular-nums; border-bottom: 1px solid var(--border); }
.ir-table td:first-child { text-align: left; color: var(--fg-muted); }
.ir-table tr.stripe { background: var(--surface-1); }
.ir-table tr.total { border-top: 2px solid var(--border-strong); font-weight: var(--weight-medium); }
```
表の上に `表1　タイトル`、直下に `出典：…`（傘 `style-guide.md` §4–5）。

### ハイライトリスト
```css
.highlight-list { list-style: none; display: flex; flex-direction: column; border-top: 1px solid var(--border-strong); }
.highlight-item { padding: 12px 0; font-size: 14px; display: flex; align-items: baseline; gap: 12px; border-bottom: 1px solid var(--border); }
.highlight-arrow { font-size: 12px; color: var(--fg-muted); }
```

### バーチャート（モノクロ）
過去は中空、当期は塗り。色で系列を分けない。値は棒の上に直接書く。
```css
.bar-chart { display: flex; align-items: flex-end; gap: 32px; height: 200px; border-bottom: 1px solid var(--border-strong); }
.bar { width: 48px; background: var(--fg); }
.bar-outline { width: 48px; border: 1.5px solid var(--fg); background: transparent; }
.bar-label { font-size: 11px; color: var(--fg-muted); }
.bar-value { font-size: 16px; font-weight: var(--weight-medium); color: var(--fg); font-variant-numeric: tabular-nums; }
```
図の下に `図1　タイトル` と `出典：…`。

### セパレーター
```css
.separator { width: 100%; height: 1px; background: var(--border); margin: 16px 0; }
```

## レイアウト
```css
.split { display: grid; grid-template-columns: 1fr 1fr; gap: var(--slide-gap); flex: 1; }
.split-text-chart { display: grid; grid-template-columns: 2fr 3fr; gap: var(--slide-gap); flex: 1; }
.guidance-grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--slide-gap); flex: 1; }
```

## 画像レイアウトパターン

### A. 画像 + テキスト分割
右に実写画像（100%高さ、40–50%幅）、左にテキスト。事例紹介・導入ストーリーに使用。
```css
.hero-split { display: grid; grid-template-columns: 1fr 1fr; gap: 0; flex: 1; overflow: hidden; }
.hero-split-text { padding: var(--space-6); display: flex; flex-direction: column; justify-content: center; }
.hero-split-image { position: relative; overflow: hidden; }
.hero-split-image img { width: 100%; height: 100%; object-fit: cover; }
```

### B. フルブリード画像 + 文字
セクション区切りやインパクトスライドに使用。写真の上の文字は暗幕を敷いて白で置く。
```css
.hero-fullbleed { position: relative; flex: 1; overflow: hidden; }
.hero-fullbleed img { width: 100%; height: 100%; object-fit: cover; position: absolute; inset: 0; }
.hero-fullbleed-overlay { position: absolute; inset: 0; background: linear-gradient(to top, var(--scrim) 30%, transparent 70%); padding: var(--space-6); display: flex; flex-direction: column; justify-content: flex-end; }
.hero-fullbleed-overlay > * { color: var(--fg-on-photo); text-shadow: var(--text-shadow-on-photo); }
```

### C. スクリーンショットグリッド（プロダクトデモ用）
```css
.screenshot-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; flex: 1; background: var(--surface-1); padding: var(--space-5); }
.screenshot-grid img { width: 100%; border: 1px solid var(--border); }
.screenshot-grid .featured { grid-column: span 2; }
```

### D. KPI + 画像コンテキスト
```css
.kpi-with-context { display: grid; grid-template-columns: 2fr 3fr; gap: var(--slide-gap); flex: 1; }
.kpi-with-context .kpi-panel { display: flex; flex-direction: column; justify-content: center; gap: 16px; }
.kpi-with-context .kpi-value { font-size: 96px; font-weight: var(--weight-kpi); letter-spacing: var(--tracking-heading); line-height: 1; font-variant-numeric: tabular-nums; }
.kpi-with-context .context-image { overflow: hidden; }
.kpi-with-context .context-image img { width: 100%; height: 100%; object-fit: cover; }
```
KPI は数えられる実績（自治体数・参加者数・意見数）だけ。出典のない率は載せない。

### 画像使用ルール
- **アスペクト比**: 16:9（スライド合わせ）or 4:3（カード内）
- **最小解像度**: 1920x1080（フルブリード時）
- **色調**: 撮影時の色のまま（写真はモノクロ基調の中で色が宿る場所）。加工で色を足さない
- **被写体**: プロダクト UI、実際の業務風景。人物は実在のチーム・顧客のみ
- **参考素材**: Drive「デザインシステム/presentations/」フォルダ(Palantir Q4 2024 決算スライド原典・ローカル無し) https://drive.google.com/drive/folders/11jv3sktyzhvCRoWl1m_EOea-hksMrROm

## 8枚スライドパターン

1. **表紙**: 白地。大数字 (96px, Light) + 会社マーク（傘 `assets/mark.svg`）+ 年度。ナビドット4つ (first active)
2. **ハイライト**: バッジ [Q1|事業概要]。ハイライトリスト (→ 付き7行)
3. **KPIチャート**: split-text-chart (2:3)。左テキスト、右パネル内バーチャート (outline→filled)
4. **導入事例**: hero-split（画像＋テキスト）。テキスト max 55%。共同ロゴ下部（先方ロゴの色は変えない）
5. **テーブル**: バッジ light [付録]。パネル内 ir-table。stripe + total 行
6. **ガイダンス**: バッジ [Q1|見通し]。guidance-grid (2つの panel-half)
7. **セクション区切り**: 表紙と同構造。ドットの active 変更
8. **プロダクト概要**: grid 3col。各プロダクト = 上罫の panel。製品名は「倍速会議」「倍速アンケート」（傘 `style-guide.md` §2）

## 参考ファイル
- 値: `plural-reality-design-system/tokens.css`
- PDF 化: `plural-reality-design-system/scripts/deck-to-pdf.py`
- 適用例: Drive「デザインシステム/kokumyaku/」フォルダ(ローカル無し・原典置き場) https://drive.google.com/drive/folders/1ZqSxWJVCbVu1uQ0ZsFGcNSXFnt3Liq3H

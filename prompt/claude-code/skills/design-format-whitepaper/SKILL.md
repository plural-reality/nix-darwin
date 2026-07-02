---
name: design-format-whitepaper
description: >
  形式B: ホワイトペーパー (A4) デザイントークンとパターン集。
  2カラム (30%/70%)、アクセント見出し、モジュール構造、概念グリッド、下線要旨文。
  Palantir Construction Whitepaper 2022 を参照元として忠実に再現する。
  「ホワイトペーパー」「技術文書」「導入ガイド」で発動。
---

# 形式B: ホワイトペーパー（A4 縦）

技術文書・導入ガイド・事例紹介（詳細版）に使用。
Palantir Construction Whitepaper (2022) のレイアウトを正準パターンとして準拠する。

## 参照元の構造概要

| ページ | 役割 | レイアウト |
|--------|------|-----------|
| 1 | 表紙 | ロゴ+縦線+タイトル / ヒーロー写真 |
| 2 | 導入 | 2カラム × 2セクション（課題提起 + 矢印リスト） |
| 3 | モジュール1 | モジュール見出し + 要旨文 + 本文 + スクリーンショット |
| 4 | 概念グリッド | 2×2 グリッド（各セルに矢印リスト） |
| 5 | 事例1 | 2カラム（左:成果見出し 右:叙述 + 矢印リスト + 写真） |
| 6-7 | モジュール2 + 事例2 | モジュール→叙述→事例 |
| 8-9 | モジュール3 + 事例3 | 同上 |
| 10 | モジュール4 | モジュール→叙述→矢印リスト |
| 11 | クロージング | 2カラム（結語 + CTA） |

---

## CSS変数

```css
:root {
  --bg: #FFFFFF;
  --text: #000000;
  --accent: #2196F3;       /* 見出し・リンク・矢印 */
  --muted: #666666;        /* キャプション・フッター */
  --border: #000000;       /* セクション区切り線 */
  --border-light: #E0E0E0; /* フッター上線・概念グリッド上線 */
  --font-sans: "Public Sans", "Noto Sans JP", sans-serif;
  --font-mono: "JetBrains Mono", monospace;
}
body {
  background: #F0F0F0;
  font-family: var(--font-sans);
  font-weight: 400;
  line-height: 1.7;
  color: var(--text);
}
```

---

## ページ構造

```css
.document {
  max-width: 816px;       /* A4幅 ≈ 210mm */
  margin: 0 auto;
  background: var(--bg);
  box-shadow: 0 0 40px rgba(0,0,0,0.08);
}
.page {
  padding: 48px 60px 40px;
  min-height: 1056px;      /* A4高 ≈ 297mm */
  position: relative;
  display: flex;
  flex-direction: column;
}
.page + .page {
  border-top: none;        /* ページ間は改ページで分離 */
}
@media print {
  .page { page-break-after: always; min-height: auto; padding: 15mm 20mm 12mm; }
}
```

---

## フッター（全ページ共通）

PDF パターン: 左にロゴアイコン、中央〜右に著作権表示。ページ最下部。

```css
.page-footer {
  display: flex;
  align-items: center;
  gap: 16px;
  padding-top: 16px;
  margin-top: auto;
  font-size: 9px;
  color: var(--muted);
  line-height: 1.4;
}
.footer-logo {
  width: 14px;
  height: 14px;
  background: var(--text);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 8px;
  color: var(--bg);
  font-weight: 700;
  flex-shrink: 0;
}
.footer-text {
  flex: 1;
  text-align: left;      /* 著作権はロゴの右、左寄せ小文字 */
}
```

```html
<div class="page-footer">
  <div class="footer-logo">P</div>
  <div class="footer-text">Copyright © 2026 Plural Reality Inc. All rights reserved.</div>
</div>
```

---

## タイポグラフィ

| 要素 | サイズ | ウェイト | 色 | 追加 |
|------|--------|---------|-----|------|
| cover-title | 44px | 300 (Light) | black | line-height: 1.15 |
| cover-company | 12px | 400 | muted | ロゴ下の社名 |
| cover-url | 12px | 400 | muted | `→ plural-reality.com` |
| section-heading | 20px | 400 | **accent** | 左カラム。複数行OK |
| body-text | 14px | 400 | black | line-height: 1.8 |
| thesis-sentence | 14px | 400 | black | **text-decoration: underline** |
| module-label | 28px | 300 | black | `Module N ↓` |
| module-subtitle | 16px | 400 | black | モジュールのサブタイトル |
| concept-number | 14px | 400 | accent | `Concept N` |
| concept-name | 16px | 400 | accent | `↳ Name` |
| concept-desc | 13px | 400 | black | 下線付き要旨文 |
| case-label | 14px | 400 | accent | `Real-World Example` |
| case-result | 16px | 400 | accent | `↳ 成果の説明文` |
| footnote | 10px | 400 | muted | ページ下部、番号付き |
| arrow-item | 14px | 400 | black | `→` プレフィックス |
| sub-item | 13px | 400 | black | ローマ数字 (i. ii. iii.) |

---

## コンポーネント

### 1. 2カラムレイアウト（最重要パターン）

全ページで使用。左30%に見出し（accent色）、右70%に本文。

```css
.two-col {
  display: grid;
  grid-template-columns: 30% 1fr;
  gap: 40px;
  margin-bottom: 48px;
}
.col-heading {
  font-size: 20px;
  font-weight: 400;       /* 400 — Bold ではない */
  color: var(--accent);
  line-height: 1.4;
}
.col-body {
  font-size: 14px;
  line-height: 1.8;
}
```

```html
<div class="two-col">
  <div class="col-heading">The Future of Construction</div>
  <div class="col-body">
    <p>本文テキスト...</p>
  </div>
</div>
```

### 2. 矢印リスト（→）

```css
.arrow-list {
  list-style: none;
  padding: 0;
  margin: 16px 0;
}
.arrow-list li {
  position: relative;
  padding-left: 28px;
  margin-bottom: 12px;
  font-size: 14px;
  line-height: 1.7;
}
.arrow-list li::before {
  content: "→";
  position: absolute;
  left: 0;
  color: var(--muted);    /* 矢印はmuted、accent ではない */
  font-weight: 400;
}
```

### 3. ローマ数字サブアイテム

矢印リスト内のネスト項目。PDF では i. ii. iii. iv. で表記。

```css
.sub-list {
  list-style: none;
  padding: 0;
  margin: 8px 0 0 28px;   /* 矢印リストのインデントに揃える */
}
.sub-list li {
  padding-left: 24px;
  margin-bottom: 8px;
  font-size: 13px;
  line-height: 1.7;
  position: relative;
}
.sub-list li::before {
  position: absolute;
  left: 0;
  color: var(--muted);
}
.sub-list li:nth-child(1)::before { content: "i."; }
.sub-list li:nth-child(2)::before { content: "ii."; }
.sub-list li:nth-child(3)::before { content: "iii."; }
.sub-list li:nth-child(4)::before { content: "iv."; }
```

```html
<ul class="arrow-list">
  <li><u>Project Managers</u> can:
    <ol class="sub-list">
      <li>Ensure that the correct volume of raw materials are delivered...</li>
      <li>Guarantee that crew schedules are properly aligned...</li>
      <li>React to disruptions swiftly...</li>
    </ol>
  </li>
  <li><u>Procurement</u> teams can benefit from:
    <ol class="sub-list">
      <li>Greater visibility into vendor performance...</li>
      <li>Greater raw material allocation accuracy...</li>
    </ol>
  </li>
</ul>
```

### 4. 下線パターン（3種類）

PDF で一貫して使われる下線の用途:

```css
/* A. 要旨文（thesis sentence） — セクション冒頭の要約1文 */
.thesis {
  text-decoration: underline;
  text-underline-offset: 3px;
  text-decoration-thickness: 1px;
}

/* B. 役職名・固有名詞 — 矢印リスト内で誰が何をするか示す */
.arrow-list u {
  text-decoration: underline;
  text-underline-offset: 2px;
  font-weight: 400;       /* 太字ではなく下線で強調 */
}

/* C. 指標値 — 本文中の定量成果 */
.metric {
  text-decoration: underline;
  text-underline-offset: 2px;
  font-weight: 400;
}
```

**使い分けルール:**
- **要旨文**: 各モジュール・セクションの最初の1文を下線。概要を一読で把握させる
- **役職名**: `→ <u>Project Managers</u> can:` のように、誰のための機能かを示す
- **指標値**: `saving <u>10%</u> in overall costs` のように、成果を視覚的に際立たせる

### 5. モジュール見出し

```css
.module-header {
  margin-bottom: 32px;
}
.module-rule {
  border: none;
  border-top: 1px solid var(--border);
  margin: 0 0 24px;
}
.module-label {
  font-size: 28px;
  font-weight: 300;
  line-height: 1.3;
  margin-bottom: 8px;
}
.module-label .arrow {
  color: var(--text);      /* ↓ は本文色 */
}
.module-subtitle {
  font-size: 16px;
  font-weight: 400;
  line-height: 1.5;
  margin-bottom: 0;
}
```

```html
<div class="module-header">
  <hr class="module-rule">
  <div class="module-label">Module 1 <span class="arrow">↓</span></div>
  <div class="module-subtitle">Construct a Digital Twin in days, not months</div>
</div>

<hr class="module-rule">

<p class="thesis">Module 1 creates a common data foundation for the digital twin.</p>

<p>本文テキスト...</p>
```

**構造**: `hr` → Module N ↓ + subtitle → `hr` → 下線要旨文 → 本文

### 6. 概念グリッド（2×2）

```css
.concept-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 40px 48px;
}
.concept-cell {
  /* 各セルの上に水平線 */
}
.concept-cell-rule {
  border: none;
  border-top: 1px solid var(--border);
  margin: 0 0 16px;
}
.concept-number {
  font-size: 14px;
  font-weight: 400;
  color: var(--accent);
  margin-bottom: 4px;
}
.concept-name {
  font-size: 16px;
  font-weight: 400;
  color: var(--accent);
  margin-bottom: 12px;
}
.concept-desc {
  font-size: 13px;
  line-height: 1.7;
  text-decoration: underline;
  text-underline-offset: 3px;
  margin-bottom: 16px;
}
```

```html
<div class="concept-grid">
  <div class="concept-cell">
    <hr class="concept-cell-rule">
    <div class="concept-number">Concept 1</div>
    <div class="concept-name">↳ Entities</div>
    <p class="concept-desc">Illustrate the objects, places, people, and materials that make up your project portfolio</p>
    <ul class="arrow-list">
      <li>Project</li>
      <li>Project Manager</li>
      <li>Contractor</li>
    </ul>
  </div>
  <div class="concept-cell">
    <hr class="concept-cell-rule">
    <div class="concept-number">Concept 2</div>
    <div class="concept-name">↳ Events</div>
    ...
  </div>
  <!-- Concept 3, 4 -->
</div>
```

### 7. 事例（Case Study）レイアウト

2カラムレイアウトと同じ構造（30%/70%）。左カラムにラベル+成果文、右に叙述。

```css
.case-heading {
  font-size: 14px;
  font-weight: 400;
  color: var(--accent);
  line-height: 1.4;
  margin-bottom: 8px;
}
.case-result {
  font-size: 16px;
  font-weight: 400;
  color: var(--accent);
  line-height: 1.4;
}
```

```html
<div class="two-col">
  <div>
    <div class="case-heading">Real-World Example</div>
    <div class="case-result">↳ Foundry reduces Project Management Costs by 10%</div>
  </div>
  <div class="col-body">
    <p>An American Construction & Engineering Company was experiencing...</p>
    <ul class="arrow-list">
      <li><u>Project Managers</u> to leverage this digital twin...</li>
      <li><u>Project Planners</u> to utilize Foundry's decision-simulation...</li>
    </ul>
    <p>Overall, labor productivity increased... saving <u>10%</u> in overall project management costs.</p>
    <!-- 写真プレースホルダー -->
    <div class="photo-placeholder"></div>
  </div>
</div>
```

### 8. スクリーンショット / 写真

```css
.screenshot-placeholder {
  background: #F5F5F5;
  border: 1px solid #E0E0E0;
  min-height: 280px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 32px 0;
  font-size: 12px;
  color: var(--muted);
}
.photo-placeholder {
  background: linear-gradient(135deg, #E0E0E0 0%, #F5F5F5 100%);
  min-height: 300px;
  margin: 32px 0;
}
.screenshot-caption {
  font-size: 11px;
  color: var(--muted);
  margin-top: -24px;
  font-style: italic;
}
```

### 9. 脚注

```css
.footnotes {
  margin-top: auto;       /* ページ下部に配置 */
  padding-top: 24px;
  font-size: 10px;
  color: var(--muted);
  line-height: 1.6;
}
.footnotes a {
  color: var(--accent);
  text-decoration: none;
}
.footnotes a:hover {
  text-decoration: underline;
}
```

```html
<div class="footnotes">
  <p>1 Construction demand will be a double-edged sword in 2023 (<a href="#">www.example.com/report</a>)</p>
  <p>2 Imagining construction's digital future (<a href="#">https://www.mckinsey.com/...</a>)</p>
</div>
```

### 10. セクション区切り線

```css
.section-rule {
  border: none;
  border-top: 1px solid var(--border);
  margin: 48px 0;
}
.section-rule-light {
  border: none;
  border-top: 1px solid var(--border-light);
  margin: 32px 0;
}
```

---

## 表紙パターン

PDF 表紙の正確な構造:

```
┌─────────────────────────────────────┐
│                                     │
│  [ロゴ]  │  タイトル（大、Light）    │ ← 縦線で分割
│  社名      複数行OK                 │
│  → URL                             │
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │      ヒーロー写真            │    │
│  │      (ページ下部 55-60%)     │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  [ロゴ]  Copyright © ...            │ ← フッター
└─────────────────────────────────────┘
```

```css
.cover {
  display: flex;
  flex-direction: column;
  height: 100%;
}
.cover-header {
  display: grid;
  grid-template-columns: 200px 1px 1fr;  /* ロゴ | 縦線 | タイトル */
  gap: 0 32px;
  align-items: start;
  margin-bottom: 40px;
  padding-top: 12px;
}
.cover-logo-area {
  display: flex;
  flex-direction: column;
  gap: 24px;
}
.cover-logo {
  display: flex;
  align-items: center;
  gap: 8px;
}
.cover-logo-mark {
  width: 20px;
  height: 20px;
  background: var(--text);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
  color: var(--bg);
  font-weight: 700;
}
.cover-logo-text {
  font-size: 16px;
  font-weight: 600;
}
.cover-separator {
  width: 1px;
  background: var(--border);
  align-self: stretch;
}
.cover-company {
  font-size: 12px;
  color: var(--muted);
  line-height: 1.6;
}
.cover-title {
  font-size: 44px;
  font-weight: 300;
  line-height: 1.15;
  letter-spacing: -0.01em;
  padding-top: 4px;
}
.cover-hero {
  flex: 1;
  min-height: 400px;
  background: #F0F0F0;
  margin-top: auto;
  display: flex;
  align-items: center;
  justify-content: center;
}
.cover-hero img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
```

```html
<div class="page cover">
  <div class="cover-header">
    <div class="cover-logo-area">
      <div class="cover-logo">
        <div class="cover-logo-mark">P</div>
        <span class="cover-logo-text">Plural Reality</span>
      </div>
      <div class="cover-company">
        Plural Reality Inc.<br>
        → plural-reality.com
      </div>
    </div>
    <div class="cover-separator"></div>
    <h1 class="cover-title">Breaking New Ground<br>with Connected<br>Construction</h1>
  </div>

  <div class="cover-hero">
    <span style="color:var(--muted); font-size:13px;">[ヒーロー写真]</span>
  </div>

  <div class="page-footer">
    <div class="footer-logo">P</div>
    <div class="footer-text">Copyright © 2026 Plural Reality Inc. All rights reserved.</div>
  </div>
</div>
```

---

## ページヘッダー（表紙以外）

表紙以外のページにはロゴを左上に小さく配置。

```css
.page-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 40px;
}
.page-header .logo-mark {
  width: 14px;
  height: 14px;
  background: var(--text);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 8px;
  color: var(--bg);
  font-weight: 700;
}
.page-header .logo-text {
  font-size: 13px;
  font-weight: 600;
}
```

---

## ページ構成パターン（正準11ページ構造）

### P1: 表紙
→ 上記「表紙パターン」参照

### P2: 導入（課題提起）
```
[ページヘッダー: ロゴ]

[2カラム: セクション1]
  左: "The Future of Construction"（accent色）
  右: 本文（課題の背景）

[2カラム: セクション2]
  左: "Challenges facing the Construction Industry"（accent色）
  右: 本文 + 矢印リスト（→ で列挙）+ 結語段落

[脚注]
[フッター]
```

### P3: モジュールページ
```
[ページヘッダー: ロゴ + "The Palantir Construction Offering"（見出し）]

[hr 黒線]
[Module N ↓]
[サブタイトル]

[hr 黒線]
[下線要旨文]
[本文]
[スクリーンショット]

[フッター]
```

### P4: 概念グリッド
```
[導入テキスト1行]

[2×2 概念グリッド]
  各セル:
    [hr 黒線]
    Concept N（accent色）
    ↳ Name（accent色）
    下線付き説明文
    矢印リスト
    (サブアイテムはローマ数字)

[フッター]
```

### P5/P7/P9: 事例
```
[2カラム]
  左:
    Real-World Example（accent色）
    ↳ 成果の説明文（accent色、複数行）
  右:
    叙述テキスト（複数段落）
    矢印リスト（→ + 下線役職名 + ローマ数字サブアイテム）
    成果の段落（指標値に下線）
    写真

[フッター]
```

### P11: クロージング
```
[2カラム]
  左: 結語見出し（accent色）
  右: 総括テキスト + 矢印リスト（引用形式OK） + CTA

[フッター]
```

---

## リンクスタイル

本文中のハイパーリンクは accent 色で、下線なし（ホバーで下線）。

```css
a {
  color: var(--accent);
  text-decoration: none;
}
a:hover {
  text-decoration: underline;
}
```

---

## Do / Don't チェックリスト

| Do | Don't |
|----|-------|
| 全ページ 30%/70% の2カラムで統一 | カラム比率を変えない（45%/55% 等は禁止） |
| 見出しは accent 色、本文は黒 | 見出しを太字にしない（weight 400） |
| `→` で箇条書き、`↳` でサブ見出し | `•` や `–` を使わない |
| 要旨文・役職名・指標値に下線 | 太字で代替しない |
| `Module N ↓` のフォーマット | `MODULE N ↘` にしない |
| ローマ数字 (i. ii. iii.) でネスト | 数字 (1. 2. 3.) にしない |
| 水平線で構造を区切る | 余白だけで区切らない |
| 写真は事例の末尾に配置 | 本文の途中に割り込ませない |
| 脚注は番号付きでページ下部 | 脚注をインラインにしない |
| フッターはロゴアイコン + 著作権のみ | ページ番号単体にしない |

---

## 参考ファイル
- 参照元PDF: `~/Library/CloudStorage/GoogleDrive-takagi@plural-reality.com/Shared drives/plural-reality/plural-reality/デザインシステム/presentations/Whitepapers/Supply_Chain_Construction_Whitepaper_2022.pdf`
- テンプレート: `~/Desktop/plural-reality-whitepaper-style.html`

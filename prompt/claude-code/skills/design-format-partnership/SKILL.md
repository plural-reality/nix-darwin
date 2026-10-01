---
name: design-format-partnership
description: >
  形式C: パートナーシップ資料 (A4) のレイアウトとパターン集。
  print register（完全モノクロ）、引用ページ、目次、タイムラインテーブル、テスティモニアル。
  値は plural-reality-design-system/tokens.css を参照する。
  「協業」「パートナーシップ」「ケーススタディ」「協業資料」「導入事例」で発動。
  原典: Palantir & Airbus Partnership Overview (2020)
---

> **値の参照**: 色・書体・ウェイト・角丸・余白は傘 skill `plural-reality-design-system/tokens.css` を inline して `var(--*)` で参照する。このファイルには hex・フォント名・角丸の px を書かない。用途の振り分けとロゴは傘 SKILL.md、表記（会社名・日付・数値と出典・図表・機密区分・©）は傘の `style-guide.md`、仕上げに傘の `scripts/brand-lint` を通す。
>
> **register**: `print`（白・無彩）。`<html data-register="print">`。

# 形式C: パートナーシップ資料（A4 縦）

協業概要・導入効果調査・ケーススタディ（ストーリー仕立て）に使用。
Palantir の Impact Study フォーマットを多元現実デザインシステムで再構成したもの。

## CSS

```css
/* tokens.css をここに inline。<html data-register="print"> */
body { background: var(--surface-2); color: var(--fg); font-family: var(--font-sans); font-weight: var(--weight-light); font-size: 15px; line-height: var(--leading-body); }
```

**ホワイトペーパーとの違い:**
- **アクセントカラーなし**（青も使わない。完全モノクロ）
- body の基本ウェイトが 300（Light）
- 余白がさらに広い（80px vs 60px）
- 引用ページ・目次ページ・テスティモニアルページが特徴的

## ページ構造
```css
.document { max-width: 816px; margin: 40px auto; background: var(--bg); }
.page { padding: 80px 80px 60px 80px; min-height: 1056px; position: relative; display: flex; flex-direction: column; }
.page-break { border: none; border-top: 1px solid var(--border); }
```

## フッター
```css
.page-footer { margin-top: auto; padding-top: 24px; border-top: 1px solid var(--border-strong); display: flex; justify-content: space-between; align-items: center; font-size: 11px; color: var(--fg-muted); }
.page-footer .copyright { font-size: 9px; line-height: 1.4; max-width: 70%; } /* © 2026 Plural Reality LLC */
.page-number { font-family: var(--font-mono); font-size: 11px; color: var(--fg); font-variant-numeric: tabular-nums; }
```

## コンポーネント

### 表紙
```css
.cover-logo { display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: var(--weight-medium); margin-bottom: 120px; } /* 傘 assets/mark.svg（高さ 20px）＋「合同会社多元現実」 */
.cover-logo img { height: 20px; width: auto; }
.cover-title { font-size: 42px; font-weight: var(--weight-regular); line-height: 1.25; letter-spacing: -0.01em; margin-bottom: 16px; }
.cover-subtitle { font-size: 20px; font-weight: var(--weight-light); color: var(--fg-muted); margin-bottom: 48px; }
.cover-rule { border: none; border-top: 2px solid var(--border-strong); margin-bottom: 16px; }
.cover-meta { display: flex; justify-content: space-between; font-size: 12px; font-weight: var(--weight-regular); letter-spacing: var(--tracking-label-ja); }
.cover-meta .type { /* 左: 「導入事例」「協業概要」など。機密区分もここ（傘 style-guide.md §6） */ }
.cover-meta .rights { text-align: right; /* 「2026年10月1日 / © 2026 Plural Reality LLC」 */ }
```

### 表紙写真（フルブリード）
```css
.cover-photo { width: calc(100% + 160px); margin-left: -80px; margin-top: 48px; height: 380px; overflow: hidden; position: relative; }
.cover-photo img { width: 100%; height: 100%; object-fit: cover; }
/* プレースホルダー（写真がない場合）。納品物には残さない */
.cover-photo--placeholder { background-color: var(--surface-1); background-image: linear-gradient(var(--border) 1px, transparent 1px), linear-gradient(90deg, var(--border) 1px, transparent 1px); background-size: 40px 40px; }
```

### 引用ページ
```css
.quote-page { padding: 80px 80px 60px 80px; min-height: 1056px; display: flex; flex-direction: column; justify-content: center; }
.quote-text { font-size: 28px; font-weight: var(--weight-light); line-height: 1.55; letter-spacing: -0.005em; max-width: 600px; }
.quote-text::before { content: "\201C"; /* 開き引用符。テキスト先頭に大きく表示 */ }
.quote-attribution { margin-top: 40px; margin-left: 240px; /* 右寄せ */ }
.quote-attribution .name { font-weight: var(--weight-medium); font-size: 15px; display: block; }
.quote-attribution .role { color: var(--fg-muted); font-size: 14px; display: block; }
```

### 目次（インデックス）ページ
```css
.index-label { font-size: 14px; font-weight: var(--weight-medium); letter-spacing: var(--tracking-label-ja); margin-bottom: 80px; }
/* 「目次 ↘」 */
.index-item { border-top: 1px solid var(--border-strong); padding: 28px 0; display: flex; align-items: baseline; gap: 24px; }
.index-item:last-child { border-bottom: 1px solid var(--border-strong); }
.index-number { font-size: 16px; font-weight: var(--weight-medium); font-family: var(--font-mono); flex: 0 0 80px; }
/* 番号は "01 –" "02 –" 形式 */
.index-title-group { flex: 1; }
.index-category { font-size: 15px; font-weight: var(--weight-light); color: var(--fg-muted); display: block; }
/* 例: 「協業のはじまり：」 */
.index-title { font-size: 22px; font-weight: var(--weight-regular); line-height: 1.4; }
/* 例: 「1,000人の声を1日で論点に」 */
```

### セクションヘッダー（二段構成）
```css
.section-header { padding: 32px 80px; border-bottom: 1px solid var(--border); display: flex; align-items: flex-start; justify-content: space-between; gap: 40px; }
.section-header-left { flex: 0 0 auto; }
.section-header-logo { height: 14px; width: auto; } /* 傘 assets/mark.svg */
.section-header-link { font-size: 11px; font-weight: var(--weight-regular); color: var(--fg-muted); margin-top: 8px; }
.section-header-link a { color: var(--fg); text-decoration: underline; }
.section-header-right { flex: 1; text-align: left; }
.section-header-number { font-size: 14px; font-weight: var(--weight-regular); color: var(--fg-muted); margin-bottom: 4px; }
/* 「01 – 協業のはじまり」 */
.section-header-title { font-size: 28px; font-weight: var(--weight-regular); line-height: 1.35; }
```

### 2カラム本文（声明文 + 詳細）
```css
.two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 48px; margin-top: 40px; }
.col-left .statement { font-size: 22px; font-weight: var(--weight-regular); line-height: 1.55; letter-spacing: -0.005em; }
.col-left .statement .arrow { font-size: 26px; } /* → 矢印で次への誘導 */
.col-left .photo-with-caption { margin-top: 32px; }
.col-left .photo-with-caption img { width: 100%; height: auto; }
.col-left .photo-caption { font-size: 12px; font-weight: var(--weight-light); color: var(--fg-muted); margin-top: 12px; line-height: 1.5; } /* 「図1　タイトル」。斜体は掛けない */
.col-right p { font-size: 14px; font-weight: var(--weight-light); line-height: 1.75; color: var(--fg); margin-bottom: 20px; }
.col-right .highlight { font-weight: var(--weight-medium); }
```

### タイムラインテーブル
```css
.timeline-section-label { font-size: 11px; font-weight: var(--weight-medium); letter-spacing: var(--tracking-label-ja); color: var(--fg-muted); margin-bottom: 12px; }
/* 「協業の歩み」 */
.timeline-intro { font-size: 13px; font-weight: var(--weight-light); line-height: 1.7; color: var(--fg); padding: 20px 24px; margin-bottom: 24px; }
/* テーブル上部の要約文 */
.timeline-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.timeline-table thead th { text-align: left; font-size: 10px; font-weight: var(--weight-medium); letter-spacing: var(--tracking-label-ja); color: var(--fg-muted); padding: 12px 16px 12px 0; border-bottom: 2px solid var(--border-strong); }
.timeline-table tbody td { padding: 16px 16px 16px 0; border-bottom: 1px solid var(--border); font-weight: var(--weight-light); vertical-align: top; }
.timeline-table tbody td:first-child { font-weight: var(--weight-medium); font-family: var(--font-mono); font-size: 12px; white-space: nowrap; }
/* 「第1期」「第2期」等 */
.timeline-table tbody td:nth-child(2) { font-family: var(--font-mono); font-weight: var(--weight-medium); font-variant-numeric: tabular-nums; }
/* 期間: 2025年9月〜12月 等（傘 style-guide.md §3） */
.timeline-table tbody td:nth-child(3) { font-weight: var(--weight-medium); font-variant-numeric: tabular-nums; }
/* 参加者数・意見数: 95人, 1,000件 等。数えられる実績だけ */
.timeline-table tbody tr:last-child td { border-bottom: 2px solid var(--border-strong); }
```

### テスティモニアル（顧客の声）
```css
.testimonial { display: grid; grid-template-columns: 200px 1fr; gap: 40px; padding: 40px 0; border-top: 1px solid var(--border); }
.testimonial:first-child { border-top: none; }
.testimonial-photo { width: 200px; height: 200px; overflow: hidden; }
.testimonial-photo img { width: 100%; height: 100%; object-fit: cover; }
.testimonial-photo--placeholder { background: var(--surface-2); } /* 納品物には残さない */
.testimonial-content { display: flex; flex-direction: column; justify-content: center; }
.testimonial-attribution { font-size: 11px; font-weight: var(--weight-medium); letter-spacing: var(--tracking-label-ja); color: var(--fg-muted); margin-bottom: 16px; line-height: 1.5; }
/* 「○○市 企画政策課 課長」。所属と肩書きは先方の正式表記 */
.testimonial-quote { font-size: 15px; font-weight: var(--weight-light); line-height: 1.7; }
.testimonial-quote .highlight { text-decoration: underline; text-decoration-color: currentColor; font-weight: var(--weight-regular); }
/* 下線強調: 定量的成果を目立たせる */
```

### テスティモニアル（写真なし・コンパクト版）
```css
.testimonial--compact { display: block; padding: 32px 0; border-top: 1px solid var(--border); }
.testimonial--compact .testimonial-attribution { margin-bottom: 12px; }
.testimonial--compact .testimonial-quote { font-size: 14px; }
```

### ダイアグラム（データ共有構造等）
```css
.diagram-section { margin-top: 40px; padding-top: 24px; border-top: 1px solid var(--border); }
.diagram-label { font-size: 11px; font-weight: var(--weight-medium); letter-spacing: var(--tracking-label-ja); color: var(--fg-muted); margin-bottom: 24px; }
/* 「図2　意見が論点になるまで」 */
.diagram-content { display: grid; grid-template-columns: 1fr 1fr; gap: 40px; }
.diagram-principles { }
.diagram-principles .principle { margin-bottom: 24px; }
.diagram-principles .principle-number { font-size: 14px; font-weight: var(--weight-medium); margin-bottom: 8px; }
.diagram-principles .principle-text { font-size: 13px; font-weight: var(--weight-light); line-height: 1.7; }
.diagram-visual { display: flex; flex-direction: column; align-items: center; justify-content: center; }
/* 右側: フォルダ構造やフロー図をCSS or SVGで描画 */
```

### KPI（大数値ハイライト）
```css
.kpi-row { display: flex; gap: 40px; margin: 40px 0; }
.kpi-item { flex: 1; }
.kpi-value { font-size: 48px; font-weight: var(--weight-kpi); line-height: 1.1; letter-spacing: var(--tracking-heading); font-variant-numeric: tabular-nums; }
.kpi-label { font-size: 13px; font-weight: var(--weight-light); color: var(--fg-muted); margin-top: 8px; line-height: 1.4; }
/* KPI は数えられる実績だけ。直下に出典行（傘 style-guide.md §4） */
```

## 8ページ構成パターン

Palantir Impact Study に準拠した構成:

1. **表紙**: 会社マーク + タイトル (42px/400) + サブタイトル + 2px黒ルール + メタ (種別・機密区分 / 日付・©) + フルブリード写真
2. **引用**: 全ページ中央寄せ。大クオート (28px/300) + 右下に人名・肩書き
3. **目次**: 「目次 ↘」 + 番号付き4セクション (border-top区切り、カテゴリ + タイトル二段構成)
4. **本文1**: セクションヘッダー (番号 + カテゴリ + タイトル) + 2カラム (左: 声明文22px + 写真キャプション / 右: 詳細段落)
5. **本文2 + タイムライン**: セクションヘッダー + 2カラム本文 + 「協業の歩み」テーブル (期/期間/指標/成果)
6. **本文3 + ダイアグラム**: セクションヘッダー + 2カラム本文 + ラベル付きダイアグラム (原則リスト + 図)
7. **テスティモニアル1**: セクションヘッダー + KPI要約 + 写真付き顧客の声 x2 (グリッド: 写真200px + テキスト)
8. **テスティモニアル2**: セクションヘッダー継続 + 写真付き顧客の声 x3

## 構成ルール

- **1ページ1メッセージ**: 情報を詰め込まない
- **矢印 (→)**: 声明文の末尾で次への期待を誘導
- **下線強調**: テスティモニアル内の定量成果に下線 (太字ではない)
- **写真キャプション**: 「図N　タイトル」、12px、左寄せ。斜体は掛けない
- **セクション番号**: "01 –" 形式。ハイフンではなくエンダッシュ（この形式に限る。whitepaper は使わない）
- **テスティモニアルの帰属**: 組織名 + 肩書きを小さいラベルで本文の上に配置（和文。uppercase は掛けない）
- **フッター著作権**: `© 2026 Plural Reality LLC`、9px、左寄せ。右にページ番号
- **全ページに上部ルール**: ページ上端にロゴ直上の細い横線

## docx で納品する場合

python-docx 用のテンプレート（旧 `partnership_docx_template.py`）はどこにも存在しないため、参照を削除した（2026-10-01）。
docx が必要なときは docx 生成用の skill で下の仕様に従って組む。テンプレートを作る場合はこの skill の `scripts/` に同梱し、ここから相対パスで参照する。

### デザイン仕様 (docx版)
- **フォント**: 欧文 Geist、和文（eastAsia 属性）Noto Sans JP。入っていない環境向けの代替は欧文 Arial・和文 BIZ UDPゴシック。和文に Arial を当てない（游・MS 系に置き換わる）
- **スタイル**: 全段落Normalスタイル。Headingスタイルは使わない。サイズで階層表現
- **ヘッダ**: 黒線(sz=4) + ヘッダーテキスト(9pt Bold)
- **フッタ**: 黒線(sz=4) + `© 2026 Plural Reality LLC` 左寄せ(7pt) + ページ番号右寄せ(8pt)
- **ヘッダ/フッタの線**: 必ず同じ太さ(sz=4)、色は黒(000000)
- **ページ設定**: A4, マージン上下2.5cm/左右3.0cm
- **レイアウト**: 1ページ1ビジュアル
- **完全モノクロ**: アクセントカラーなし。色の値は `tokens.css` の `print` register の hex を使う

### 空行・余白ルール (docx版、手直し確定済み)
- 表紙→引用ページ間: 空行1行(sa=Pt(0))のみ。大きなspace_afterは不要
- 目次の各項目間: `--border` の細線(sz=2) + 空行1行で分離
- セクションヘッダ(01—等)の前: 黒太線(sz=4)の直前に空行1行
- ビジュアルページの前: 空行1行(sa=Pt(8))のみ。余白入れすぎない
- クロージング前: 空行1行(sa=Pt(80))で下寄せ
- セクション区切り: 黒太線(sz=4,color=000000)
- リスト区切り: `--border` の細線(sz=2)

## 参考ファイル
- 値: `plural-reality-design-system/tokens.css`
- 適用例 (HTML): Drive「デザインシステム/kokumyaku/」フォルダ(ローカル無し・原典置き場) https://drive.google.com/drive/folders/1ZqSxWJVCbVu1uQ0ZsFGcNSXFnt3Liq3H
- 原典PDF: Palantir & Airbus Partnership Overview (Google Drive > デザインシステム > presentations > Partnerships)

---
name: design-format-partnership
description: >
  形式C: パートナーシップ資料 (A4) デザイントークンとパターン集。
  完全モノクロ、引用ページ、目次、タイムラインテーブル、テスティモニアル、写真グリッドオーバーレイ。
  「協業」「パートナーシップ」「ケーススタディ」「協業資料」「導入事例」で発動。
  参考: ~/Desktop/plural-reality-partnership-style.html
  原典: Palantir & Airbus Partnership Overview (2020)
---

# 形式C: パートナーシップ資料（A4 縦）

協業概要・導入効果調査・ケーススタディ（ストーリー仕立て）に使用。
Palantir の Impact Study フォーマットを多元現実デザインシステムで再構成したもの。

## CSS変数

```css
:root {
  --bg: #FFFFFF;
  --text: #000000;
  --muted: #666666;
  --rule: #E0E0E0;
  --font-sans: "Public Sans", "Noto Sans JP", sans-serif;
  --font-mono: "JetBrains Mono", monospace;
}
body { background: #F0F0F0; font-weight: 300; font-size: 15px; line-height: 1.7; }
```

**ホワイトペーパーとの違い:**
- **アクセントカラーなし**（青も使わない。完全モノクロ）
- body の基本ウェイトが 300（Light）
- 余白がさらに広い（80px vs 60px）
- 引用ページ・目次ページ・テスティモニアルページが特徴的

## ページ構造
```css
.document { max-width: 816px; margin: 40px auto; background: var(--bg); box-shadow: 0 1px 8px rgba(0,0,0,0.08); }
.page { padding: 80px 80px 60px 80px; min-height: 1056px; position: relative; display: flex; flex-direction: column; }
.page-break { border: none; border-top: 1px solid var(--rule); }
```

## フッター
```css
.page-footer { margin-top: auto; padding-top: 24px; border-top: 1px solid var(--text); display: flex; justify-content: space-between; align-items: center; font-size: 11px; color: var(--muted); }
.page-footer .copyright { font-size: 9px; line-height: 1.4; max-width: 70%; }
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
.cover-meta .type { /* 左: "Impact Study" 等 */ }
.cover-meta .rights { text-align: right; /* "Copyright ... / All rights reserved" */ }
```

### 表紙写真（フルブリード）
```css
.cover-photo { width: calc(100% + 160px); margin-left: -80px; margin-top: 48px; height: 380px; overflow: hidden; position: relative; }
.cover-photo img { width: 100%; height: 100%; object-fit: cover; }
/* プレースホルダー（写真がない場合） */
.cover-photo--placeholder { background: linear-gradient(135deg, #E8E8E8, #D0D0D0, #C0C0C0); display: flex; align-items: center; justify-content: center; }
.cover-photo--placeholder::before { content: ""; position: absolute; inset: 0; background: repeating-linear-gradient(0deg, transparent, transparent 39px, rgba(0,0,0,0.03) 39px, rgba(0,0,0,0.03) 40px), repeating-linear-gradient(90deg, transparent, transparent 39px, rgba(0,0,0,0.03) 39px, rgba(0,0,0,0.03) 40px); }
```

### 引用ページ
```css
.quote-page { padding: 80px 80px 60px 80px; min-height: 1056px; display: flex; flex-direction: column; justify-content: center; }
.quote-text { font-size: 28px; font-weight: 300; line-height: 1.55; letter-spacing: -0.005em; max-width: 600px; }
.quote-text::before { content: "\201C"; /* 開き引用符。テキスト先頭に大きく表示 */ }
.quote-attribution { margin-top: 40px; margin-left: 240px; /* 右寄せ */ }
.quote-attribution .name { font-weight: 600; font-size: 15px; display: block; }
.quote-attribution .role { color: var(--muted); font-size: 14px; display: block; }
```

### 目次（インデックス）ページ
```css
.index-label { font-size: 14px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; margin-bottom: 80px; }
/* "INDEX ↘" の表記 */
.index-item { border-top: 1px solid var(--text); padding: 28px 0; display: flex; align-items: baseline; gap: 24px; }
.index-item:last-child { border-bottom: 1px solid var(--text); }
.index-number { font-size: 16px; font-weight: 600; font-family: var(--font-mono); flex: 0 0 80px; }
/* 番号は "01 –" "02 –" 形式 */
.index-title-group { flex: 1; }
.index-category { font-size: 15px; font-weight: 300; color: var(--muted); display: block; }
/* 例: "The Partnership Begins:" */
.index-title { font-size: 22px; font-weight: 600; line-height: 1.3; }
/* 例: "Accelerating Delivery of the A350" */
```

### セクションヘッダー（二段構成）
```css
.section-header { padding: 32px 80px; border-bottom: 1px solid var(--rule); display: flex; align-items: flex-start; justify-content: space-between; gap: 40px; }
.section-header-left { flex: 0 0 auto; }
.section-header-logo { font-size: 12px; font-weight: 600; letter-spacing: 0.06em; text-transform: uppercase; }
.section-header-link { font-size: 11px; font-weight: 400; color: var(--muted); margin-top: 8px; }
.section-header-link a { color: var(--text); text-decoration: underline; }
.section-header-right { flex: 1; text-align: left; }
.section-header-number { font-size: 14px; font-weight: 400; color: var(--muted); margin-bottom: 4px; }
/* "01 – The Partnership Begins" */
.section-header-title { font-size: 28px; font-weight: 700; line-height: 1.25; }
/* "Accelerating Delivery of the A350" */
```

### 2カラム本文（声明文 + 詳細）
```css
.two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 48px; margin-top: 40px; }
.col-left .statement { font-size: 22px; font-weight: 400; line-height: 1.55; letter-spacing: -0.005em; }
.col-left .statement .arrow { font-size: 26px; } /* → 矢印で次への誘導 */
.col-left .photo-with-caption { margin-top: 32px; }
.col-left .photo-with-caption img { width: 100%; height: auto; }
.col-left .photo-caption { font-size: 12px; font-weight: 300; color: var(--muted); margin-top: 12px; line-height: 1.5; text-align: center; font-style: italic; }
.col-right p { font-size: 14px; font-weight: 300; line-height: 1.75; color: #1A1A1A; margin-bottom: 20px; }
.col-right .highlight { font-weight: 600; }
```

### タイムラインテーブル
```css
.timeline-section-label { font-size: 11px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; color: var(--muted); margin-bottom: 12px; }
/* "PARTNERSHIP JOURNEY AT A GLANCE" */
.timeline-intro { font-size: 13px; font-weight: 300; line-height: 1.7; color: #333; padding: 20px 24px; margin-bottom: 24px; }
/* テーブル上部の要約文 */
.timeline-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.timeline-table thead th { text-align: left; font-size: 10px; font-weight: 600; letter-spacing: 0.1em; text-transform: uppercase; color: var(--muted); padding: 12px 16px 12px 0; border-bottom: 2px solid var(--text); }
.timeline-table tbody td { padding: 16px 16px 16px 0; border-bottom: 1px solid var(--rule); font-weight: 300; vertical-align: top; }
.timeline-table tbody td:first-child { font-weight: 600; font-family: var(--font-mono); font-size: 12px; white-space: nowrap; }
/* PHASE 01, PHASE 02 等 */
.timeline-table tbody td:nth-child(2) { font-family: var(--font-mono); font-weight: 600; }
/* 年: 2015, 2016 等 */
.timeline-table tbody td:nth-child(3) { font-weight: 700; }
/* ユーザー数: 50, 500, 4,000, 18,000+ 等 */
.timeline-table tbody tr:last-child td { border-bottom: 2px solid var(--text); }
```

### テスティモニアル（顧客の声）
```css
.testimonial { display: grid; grid-template-columns: 200px 1fr; gap: 40px; padding: 40px 0; border-top: 1px solid var(--rule); }
.testimonial:first-child { border-top: none; }
.testimonial-photo { width: 200px; height: 200px; overflow: hidden; }
.testimonial-photo img { width: 100%; height: 100%; object-fit: cover; }
.testimonial-photo--placeholder { background: linear-gradient(135deg, #E8E8E8, #D0D0D0); }
.testimonial-content { display: flex; flex-direction: column; justify-content: center; }
.testimonial-attribution { font-size: 10px; font-weight: 600; letter-spacing: 0.1em; text-transform: uppercase; color: var(--muted); margin-bottom: 16px; line-height: 1.5; }
/* "LATAM AIRLINES GROUP - MANAGER, DIGITAL TRANSFORMATION TEAM" */
.testimonial-quote { font-size: 15px; font-weight: 300; line-height: 1.7; }
.testimonial-quote .highlight { text-decoration: underline; font-weight: 400; }
/* 下線強調: 定量的成果を目立たせる */
```

### テスティモニアル（写真なし・コンパクト版）
```css
.testimonial--compact { display: block; padding: 32px 0; border-top: 1px solid var(--rule); }
.testimonial--compact .testimonial-attribution { margin-bottom: 12px; }
.testimonial--compact .testimonial-quote { font-size: 14px; }
```

### ダイアグラム（データ共有構造等）
```css
.diagram-section { margin-top: 40px; padding-top: 24px; border-top: 1px solid var(--rule); }
.diagram-label { font-size: 11px; font-weight: 600; letter-spacing: 0.12em; text-transform: uppercase; color: var(--muted); margin-bottom: 24px; }
/* "SHARING DATA ON SKYWISE" */
.diagram-content { display: grid; grid-template-columns: 1fr 1fr; gap: 40px; }
.diagram-principles { }
.diagram-principles .principle { margin-bottom: 24px; }
.diagram-principles .principle-number { font-size: 14px; font-weight: 600; margin-bottom: 8px; }
.diagram-principles .principle-text { font-size: 13px; font-weight: 300; line-height: 1.7; }
.diagram-visual { display: flex; flex-direction: column; align-items: center; justify-content: center; }
/* 右側: フォルダ構造やフロー図をCSS or SVGで描画 */
```

### KPI（大数値ハイライト）
```css
.kpi-row { display: flex; gap: 40px; margin: 40px 0; }
.kpi-item { flex: 1; }
.kpi-value { font-size: 48px; font-weight: 700; line-height: 1.1; letter-spacing: -0.02em; }
.kpi-label { font-size: 13px; font-weight: 300; color: var(--muted); margin-top: 8px; line-height: 1.4; }
```

## 8ページ構成パターン

Palantir Impact Study に準拠した構成:

1. **表紙**: ロゴ + タイトル (42px/700) + サブタイトル + 2px黒ルール + メタ (種別 / 著作権) + フルブリード写真
2. **引用**: 全ページ中央寄せ。大クオート (28px/300) + 右下に人名・肩書き
3. **目次**: "INDEX ↘" + 番号付き4セクション (border-top区切り、カテゴリ + タイトル二段構成)
4. **本文1**: セクションヘッダー (番号 + カテゴリ + タイトル) + 2カラム (左: 声明文22px + 写真キャプション / 右: 詳細段落)
5. **本文2 + タイムライン**: セクションヘッダー + 2カラム本文 + "JOURNEY AT A GLANCE" テーブル (Phase/年/指標/成果)
6. **本文3 + ダイアグラム**: セクションヘッダー + 2カラム本文 + ラベル付きダイアグラム (原則リスト + 図)
7. **テスティモニアル1**: セクションヘッダー + KPI要約 + 写真付き顧客の声 x2 (グリッド: 写真200px + テキスト)
8. **テスティモニアル2**: セクションヘッダー継続 + 写真付き顧客の声 x3

## 構成ルール

- **1ページ1メッセージ**: 情報を詰め込まない
- **矢印 (→)**: 声明文の末尾で次への期待を誘導
- **下線強調**: テスティモニアル内の定量成果に下線 (太字ではない)
- **写真キャプション**: イタリック・センタリング・12px
- **セクション番号**: "01 –" 形式。ハイフンではなくエンダッシュ
- **テスティモニアルの帰属**: 組織名 + 肩書きは ALL CAPS ラベルで本文の上に配置
- **フッター著作権**: 9px、左寄せ、2行以内に収める
- **全ページに上部ルール**: ページ上端にロゴ直上の細い横線

## docx生成テンプレート (python-docx)

`partnership_docx_template.py` をimportしてdocxを直接生成できる。

```python
import sys
sys.path.insert(0, '/Users/tkgshn/.claude/skills/design-format-partnership')
from partnership_docx_template import DocBuilder

b = DocBuilder('ヘッダーテキスト', '/path/to/output.docx')

# ページ構成メソッド
b.cover('タイトル', 'サブタイトル', '/path/to/hero.jpg', 'キャプション')
b.quote('引用テキスト', '発言者名', '肩書き')
b.index([('01', 'サブ:', 'タイトル'), ('02', 'サブ:', 'タイトル')])
b.section('01', 'サブタイトル', 'メインタイトル')
b.lead('リードテキスト（大きな声明文）→')
b.body('本文テキスト。通常サイズ。')
b.visual('見出し', '説明文', '/path/to/image.png', 'キャプション')
b.timeline('LABEL', '説明', [('PHASE 01', '2020', 'スケール', '成果'), ...])
b.numbered_items([('01', 'タイトル', '説明'), ...])
b.closing('組織名1', '住所等', '組織名2', '住所等')
b.page_break()
b.save()

# 低レベルヘルパー
b.P('テキスト', sz=Pt(11), bold=False, color=BLACK, align=LEFT)
b.LINE('4', '000000')
b.IMG('/path/to/image.png', w=Cm(15))
b.CAP('キャプション')
```

### デザイン仕様 (docx版)
- **フォント**: Arial（全文統一、eastAsia属性も含む）
- **スタイル**: 全段落Normalスタイル。Headingスタイルは使わない。サイズで階層表現
- **ヘッダ**: 黒線(sz=4) + ヘッダーテキスト(9pt Bold)
- **フッタ**: 黒線(sz=4) + Copyright左寄せ(7pt) + ページ番号右寄せ(8pt)
- **ヘッダ/フッタの線**: 必ず同じ太さ(sz=4)、色は黒(000000)
- **ページ設定**: A4, マージン上下2.5cm/左右3.0cm
- **レイアウト**: 1ページ1ビジュアル
- **完全モノクロ**: アクセントカラーなし

### 空行・余白ルール (docx版、手直し確定済み)
- 表紙→引用ページ間: 空行1行(sa=Pt(0))のみ。大きなspace_afterは不要
- INDEX各項目間: E0E0E0細線(sz=2) + 空行1行で分離
- セクションヘッダ(01—等)の前: 黒太線(sz=4)の直前に空行1行
- ビジュアルページの前: 空行1行(sa=Pt(8))のみ。余白入れすぎない
- クロージング前: 空行1行(sa=Pt(80))で下寄せ
- セクション区切り: 黒太線(sz=4,color=000000)
- リスト区切り: グレー細線(sz=2,color=E0E0E0)

## 参考ファイル
- テンプレート (HTML): `~/Desktop/plural-reality-partnership-style.html`
- テンプレート (python-docx): `~/.claude/skills/design-format-partnership/partnership_docx_template.py`
- 適用例 (HTML): `~/Desktop/kokumyaku-partnership.html`
- 原典PDF: Palantir & Airbus Partnership Overview (Google Drive > デザインシステム > presentations > Partnerships)

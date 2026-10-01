---
name: design-format-service-def
description: >
  形式D: サービス定義書 (A4) デザイントークンとパターン集。
  最もフォーマル。print register（白・無彩）、両端揃え、番号付きセクション、点線TOC。
  値は plural-reality-design-system/tokens.css を参照する。
  「サービス定義書」「仕様書」「RFP」「公的調達」で発動。
---

> **値の参照**: 色・書体・ウェイト・角丸・余白は傘 skill `plural-reality-design-system/tokens.css` を inline して `var(--*)` で参照する。このファイルには hex・フォント名・角丸の px を書かない。用途の振り分けとロゴは傘 SKILL.md、表記（会社名・日付・出典・図表・機密区分・©）は傘の `style-guide.md`、仕上げに傘の `scripts/brand-lint` を通す。
>
> **register**: `print`（白・無彩）。`<html data-register="print">`。

# 形式D: サービス定義書（A4 縦）

公的調達対応・RFP回答・サービス仕様書に使用。最もフォーマル。

## CSS

```css
/* tokens.css をここに inline。<html data-register="print"> */
html { font-size: 14px; }
body { background: var(--bg); color: var(--fg); font-family: var(--font-sans); line-height: var(--leading-body); }
```

**他形式との違い:**
- アクセントカラーなし（完全モノクロ）
- 本文サイズ 13px（他形式より小さい）
- 両端揃え（justify）
- 番号付きセクション (1.0, 1.1, 1.2...)
- 表紙に会社マークとプロダクト名を置く（文字を枠で囲んだ仮ロゴは作らない）

## ページ構造
```css
.page { max-width: 816px; margin: 0 auto; padding: 48px 64px; position: relative; min-height: 100vh; }
.cover { display: flex; flex-direction: column; min-height: 100vh; padding: 0 64px; max-width: 816px; margin: 0 auto; }
.page-separator { max-width: 816px; margin: 0 auto; height: 1px; background: var(--border); }
```

## コンポーネント

### 表紙
```css
.cover-rule-top { width: 100%; height: 2px; background: var(--fg); margin-top: 48px; }
.cover-header { display: flex; justify-content: space-between; padding: 24px 0 48px 0; }
.cover-logo { display: flex; align-items: center; gap: 8px; font-weight: var(--weight-medium); font-size: 14px; } /* 傘 assets/mark.svg（高さ 20px）＋「合同会社多元現実」 */
.cover-logo img { height: 20px; width: auto; }
.cover-logo-sub { font-weight: var(--weight-regular); font-size: 11px; color: var(--fg-muted); }
.cover-title { font-size: 32px; font-weight: var(--weight-medium); letter-spacing: 0.02em; line-height: 1.3; } /* 和文タイトルなので uppercase は掛けない */
.cover-subtitle { font-size: 18px; font-weight: var(--weight-regular); letter-spacing: 0.04em; }
.cover-prepared { font-size: 13px; color: var(--fg-muted); line-height: 1.8; }
.cover-prepared strong { color: var(--fg); font-weight: var(--weight-medium); }
.confidential { font-size: 10px; font-weight: var(--weight-medium); letter-spacing: var(--tracking-label-ja); color: var(--fg-muted); } /* 「先方限り（○○市 ご担当者さま）」など。傘 style-guide.md §6 */
```

### プロダクト名
プロダクトのロゴがあればそれを使う（A3: プロダクトのロゴは製品側で決めてよい）。無ければ文字だけで組み、枠で囲んだ仮ロゴは作らない。
```css
.cover-product-name { font-size: 16px; font-weight: var(--weight-medium); letter-spacing: 0.04em; } /* 「倍速会議」「倍速アンケート」。製品名は傘 style-guide.md §2 */
```

### 表紙アート
印刷するのでベタ塗りの黒面は使わない。hairline の方眼で余白を締める。
```css
.cover-art { flex: 1; min-height: 320px; margin-top: auto; border-top: 1px solid var(--fg); position: relative; overflow: hidden;
  background-image: linear-gradient(var(--border) 1px, transparent 1px), linear-gradient(90deg, var(--border) 1px, transparent 1px); background-size: 40px 40px; }
```

### ページヘッダー
```css
.page-header { display: flex; justify-content: space-between; align-items: center; padding-bottom: 12px; border-bottom: 1px solid var(--fg); margin-bottom: 40px; }
.page-header-left { font-size: 11px; font-weight: var(--weight-medium); }
.page-header-logo { height: 14px; width: auto; } /* 傘 assets/mark.svg */
```

### ページフッター
```css
.page-footer { position: absolute; bottom: 32px; left: 64px; right: 64px; display: flex; justify-content: space-between; font-size: 10px; color: var(--fg-muted); padding-top: 12px; border-top: 1px solid var(--border); }
.page-footer-page { font-weight: var(--weight-medium); color: var(--fg); font-variant-numeric: tabular-nums; }
/* 左: © 2026 Plural Reality LLC / 右: ページ番号 */
```

### 目次（TOC）
```css
.toc-title { font-size: 24px; font-weight: var(--weight-regular); margin-bottom: 32px; }
.toc-item { display: flex; align-items: baseline; padding: 6px 0; font-size: 13px; }
.toc-number { font-weight: var(--weight-medium); min-width: 48px; font-variant-numeric: tabular-nums; }
.toc-dots { flex: 1; border-bottom: 1px dotted var(--fg-subtle); margin: 0 8px; min-width: 40px; position: relative; top: -3px; }
.toc-page { font-weight: var(--weight-medium); min-width: 24px; text-align: right; font-variant-numeric: tabular-nums; }
```

### 見出し
```css
.section-h1 { font-size: 20px; font-weight: var(--weight-medium); letter-spacing: 0.02em; margin: 48px 0 24px 0; }
.section-h2 { font-size: 16px; font-weight: var(--weight-medium); margin: 32px 0 16px 0; }
.section-h3 { font-size: 14px; font-weight: var(--weight-medium); margin: 24px 0 12px 0; }
```

### 本文
```css
.body-text { font-size: 13px; line-height: 1.75; text-align: justify; margin-bottom: 16px; }
.bullet-list { list-style: disc; padding-left: 24px; margin: 12px 0 20px 0; }
.bullet-list li { font-size: 13px; line-height: 1.75; text-align: justify; margin-bottom: 6px; }
```

### クロージングページ
白地（`print`）。上下に `--fg` の 2px ルール、中央配置:
- 会社マーク（傘 `assets/mark.svg`）
- プロダクト名
- タグライン（`--fg-muted`）
- 正規 URL（Vercel のデプロイ URL やプレビュー URL は載せない）／ `© 2026 Plural Reality LLC`
- 背景は表紙アートと同じ hairline 方眼

## 5ページ構成パターン
1. **表紙**: 2pxルール + 会社マーク/機密区分 + タイトル (32px/500) + プロダクト名 + hairline 方眼
2. **目次**: ページヘッダー + TOC (点線リーダー + ページ番号)
3. **本文**: セクション 1.0/1.1/2.0... + justify + bullet-list
4. **セキュリティ**: セクション 3.0/3.1/4.0... + nested bullets
5. **クロージング**: 白地 + 会社マーク + プロダクト名 + タグライン + URL

## 参考ファイル
- 値: `plural-reality-design-system/tokens.css`
- 適用例: Drive「デザインシステム/kokumyaku/」フォルダ(ローカル無し・原典置き場) https://drive.google.com/drive/folders/1ZqSxWJVCbVu1uQ0ZsFGcNSXFnt3Liq3H

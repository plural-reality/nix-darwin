---
name: design-format-service-def
description: >
  形式D: サービス定義書 (A4) デザイントークンとパターン集。
  最もフォーマル。両端揃え、番号付きセクション、点線TOC、黒クロージング。
  「サービス定義書」「仕様書」「RFP」「公的調達」で発動。
  参考: ~/Desktop/plural-reality-service-definition-style.html
---

# 形式D: サービス定義書（A4 縦）

公的調達対応・RFP回答・サービス仕様書に使用。最もフォーマル。

## CSS変数

```css
:root {
  --bg: #FFFFFF;
  --text: #000000;
  --muted: #555555;
  --font-sans: "Public Sans", "Noto Sans JP", sans-serif;
  --font-mono: "JetBrains Mono", monospace;
}
html { font-size: 14px; }
body { background: var(--bg); line-height: 1.7; }
```

**他形式との違い:**
- アクセントカラーなし（完全モノクロ）
- 本文サイズ 13px（他形式より小さい）
- 両端揃え（justify）
- 番号付きセクション (1.0, 1.1, 1.2...)
- プロダクトロゴアイコン (48px, 8px radius) が登場

## ページ構造
```css
.page { max-width: 816px; margin: 0 auto; padding: 48px 64px; position: relative; min-height: 100vh; }
.cover { display: flex; flex-direction: column; min-height: 100vh; padding: 0 64px; max-width: 816px; margin: 0 auto; }
.page-separator { max-width: 816px; margin: 0 auto; height: 1px; background: #e0e0e0; }
```

## コンポーネント

### 表紙
```css
.cover-rule-top { width: 100%; height: 2px; background: var(--text); margin-top: 48px; }
.cover-header { display: flex; justify-content: space-between; padding: 24px 0 48px 0; }
.cover-logo { font-weight: 800; font-size: 14px; letter-spacing: 0.08em; text-transform: uppercase; }
.cover-logo-sub { font-weight: 400; font-size: 11px; color: var(--muted); }
.cover-title { font-size: 32px; font-weight: 800; letter-spacing: 0.04em; text-transform: uppercase; line-height: 1.2; }
.cover-subtitle { font-size: 18px; font-weight: 400; letter-spacing: 0.06em; }
.cover-prepared { font-size: 13px; color: var(--muted); line-height: 1.8; }
.cover-prepared strong { color: var(--text); font-weight: 600; }
.confidential { font-size: 10px; font-weight: 600; letter-spacing: 0.1em; text-transform: uppercase; color: var(--muted); }
```

### プロダクトロゴ
```css
.cover-product-logo-icon { width: 48px; height: 48px; border: 2px solid var(--text); border-radius: 8px; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 20px; }
.cover-product-logo-text { font-size: 16px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; }
```

### 表紙アート（黒背景）
```css
.cover-art { flex: 1; min-height: 320px; margin-top: auto; background: var(--text); position: relative; overflow: hidden; }
.cover-art-grid { background-image: linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px); background-size: 40px 40px; }
/* 微細な白い水平線をランダムに配置 */
```

### ページヘッダー
```css
.page-header { display: flex; justify-content: space-between; align-items: center; padding-bottom: 12px; border-bottom: 1px solid var(--text); margin-bottom: 40px; }
.page-header-left { font-size: 11px; font-weight: 600; }
.page-header-logo-icon { display: inline-flex; width: 20px; height: 20px; border: 1.5px solid var(--text); border-radius: 4px; align-items: center; justify-content: center; font-size: 9px; font-weight: 800; }
```

### ページフッター
```css
.page-footer { position: absolute; bottom: 32px; left: 64px; right: 64px; display: flex; justify-content: space-between; font-size: 10px; color: var(--muted); padding-top: 12px; border-top: 1px solid #e0e0e0; }
.page-footer-page { font-weight: 600; color: var(--text); }
```

### 目次（TOC）
```css
.toc-title { font-size: 24px; font-weight: 700; margin-bottom: 32px; }
.toc-item { display: flex; align-items: baseline; padding: 6px 0; font-size: 13px; }
.toc-number { font-weight: 600; min-width: 48px; }
.toc-dots { flex: 1; border-bottom: 1px dotted #ccc; margin: 0 8px; min-width: 40px; position: relative; top: -3px; }
.toc-page { font-weight: 600; min-width: 24px; text-align: right; }
```

### 見出し
```css
.section-h1 { font-size: 20px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.02em; margin: 48px 0 24px 0; }
.section-h2 { font-size: 16px; font-weight: 600; margin: 32px 0 16px 0; }
.section-h3 { font-size: 14px; font-weight: 600; margin: 24px 0 12px 0; }
```

### 本文
```css
.body-text { font-size: 13px; line-height: 1.75; text-align: justify; margin-bottom: 16px; }
.bullet-list { list-style: disc; padding-left: 24px; margin: 12px 0 20px 0; }
.bullet-list li { font-size: 13px; line-height: 1.75; text-align: justify; margin-bottom: 6px; }
```

### クロージングページ（黒背景）
全面黒 (#000000)。中央配置:
- プロダクトロゴアイコン (白ボーダー)
- プロダクト名 (白文字)
- タグライン (muted #888)
- URL / copyright
- グリッドパターンオーバーレイ (rgba(255,255,255,0.03))

## 5ページ構成パターン
1. **表紙**: 2pxルール + ロゴ/機密 + タイトル (32px/800/uppercase) + プロダクトロゴ + 黒アート
2. **目次**: ページヘッダー + TOC (点線リーダー + ページ番号)
3. **本文**: セクション 1.0/1.1/2.0... + justify + bullet-list
4. **セキュリティ**: セクション 3.0/3.1/4.0... + nested bullets
5. **クロージング**: 全面黒 + プロダクトロゴ + タグライン + URL

## 参考ファイル
- テンプレート: `~/Desktop/plural-reality-service-definition-style.html`
- 適用例: `~/Desktop/kokumyaku-service-definition.html`

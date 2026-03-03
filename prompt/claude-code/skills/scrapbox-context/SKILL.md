# Scrapbox Context スキル — ナレッジベースから情報を取得して回答する

ユーザーの質問に対して、Scrapbox（Cosense）のナレッジベースから関連情報を取得し、1-hop/2-hop のリンクネットワークを活用して回答を補強する。

## トリガー

### 自動トリガー（ユーザーの指示なしで使う）

以下の場合、このスキルを**自動的に**使用すること:

1. **ユーザーが個人的な知識について質問したとき**: 「〜について何か書いてたっけ？」「前にメモしたやつ」「あのページ」
2. **プロジェクト固有の知識が必要なとき**: Plurality、plural reality、多元現実、デジタル民主主義、Polis、ガバナンスなどのトピック
3. **「スクボで調べて」「Scrapboxから探して」**: 明示的な検索依頼
4. **コンテキストが不足しているとき**: ユーザーの質問が曖昧で、Scrapboxに関連情報がありそうな場合

### 手動トリガー

- 「Scrapboxで調べて」「スクボ検索」「ナレッジベースから」

## 対応プロジェクト

| プロジェクト名 | 識別キーワード | 用途 |
|---|---|---|
| `tkgshn-private` | 「プライベート」「個人メモ」「自分の」（デフォルト） | 個人ナレッジベース |
| `plural-reality` | 「Plurality」「チーム」「plural reality」「多元現実」 | チームナレッジベース |

ユーザーが特にプロジェクトを指定しない場合:
- まず質問のトピックに関連するプロジェクトを推測する
- 不明な場合は `tkgshn-private` をデフォルトとして使う
- 必要に応じて両方のプロジェクトを検索する

## 認証情報

```
SCRAPBOX_CONNECT_SID=<YOUR_CONNECT_SID>
```

> **セットアップ**: Scrapbox にログインし、ブラウザの DevTools > Application > Cookies から `connect.sid` の値を取得して上記に設定してください。

## 使い方

### 方法1: Scrapbox Smart Context API を直接呼ぶ（推奨）

全プロジェクトに対応。`connect.sid` Cookie 付きで API を呼ぶ。

```bash
# 1-hop（指定ページ + 直接リンクされたページ）
# 重要: fish shell では % がエスケープ問題を起こすため、必ず /bin/bash -c で実行すること
/bin/bash -c 'curl -s "https://scrapbox.io/api/smart-context/export-1hop-links/PROJECT_NAME.txt?title=PAGE_TITLE" -H "Cookie: connect.sid=<YOUR_CONNECT_SID>"'

# 2-hop（1-hop + さらにそこからリンクされたページ）
/bin/bash -c 'curl -s "https://scrapbox.io/api/smart-context/export-2hop-links/PROJECT_NAME.txt?title=PAGE_TITLE" -H "Cookie: connect.sid=<YOUR_CONNECT_SID>"'
```

- `PROJECT_NAME`: `tkgshn-private` または `plural-reality`
- `PAGE_TITLE`: ページタイトル（URL エンコードすること）

### 方法2: cosense-context-proxy 経由（両プロジェクト対応）

WebFetch でも呼べるプロキシ URL。プロジェクトごとにトークンが異なる。

**plural-reality:**
```
https://cosense-context-proxy.vercel.app/r/<YOUR_PROXY_TOKEN_PLURAL_REALITY>?p=PAGE_TITLE&h=1
```

**tkgshn-private:**
```
https://cosense-context-proxy.vercel.app/r/<YOUR_PROXY_TOKEN_PRIVATE>?p=PAGE_TITLE&h=1
```

- `p`: ページタイトル
- `h`: ホップ数（1 or 2）

## 検索戦略

### ステップ1: ページタイトルの推測

ユーザーの質問からキーワードを抽出し、Scrapbox のページタイトルとして使う。

例:
- 「Polisについて調べて」→ `Polis`
- 「Pluralityの概要は？」→ `Plurality`
- 「前にデジタル民主主義についてメモしたやつ」→ `デジタル民主主義`

### ステップ2: 1-hop で取得

まず 1-hop で情報を取得する。これで十分な場合が多い。

### ステップ3: 必要に応じて 2-hop

1-hop で情報が不十分、または広い文脈が必要な場合は 2-hop を使う。
ただし 2-hop はデータ量が大きくなるので注意。

### ステップ4: 複数ページの探索

最初のページタイトルが見つからない場合（404）:
1. 表記揺れを試す（英語/日本語、大文字/小文字）
2. 関連キーワードで別のページを試す
3. Scrapbox の全文検索 API で候補を探す:
   ```bash
   /bin/bash -c 'curl -s "https://scrapbox.io/api/pages/PROJECT_NAME/search/query?q=KEYWORD&limit=5" \
     -H "Cookie: connect.sid=<YOUR_CONNECT_SID>"'
   ```
   レスポンスの `pages[].title` からページタイトルを取得し、Smart Context API に渡す。

### ステップ5: 複数プロジェクトの横断検索

トピックによっては両プロジェクトに情報がある。必要に応じて両方を検索する。

## レスポンスフォーマット

取得した情報を回答に組み込む際:

1. **出典を明示する**: 「Scrapboxの[ページ名]によると...」
2. **リンクを提供する**: `https://scrapbox.io/PROJECT/PAGE_TITLE`
3. **1-hop/2-hop の関連ページにも言及する**: 「関連ページとして[X]や[Y]もあります」
4. **情報が古い可能性を示唆する**: 必要に応じて「最終更新日は不明ですが...」

## エラーハンドリング

- **404**: ページが見つからない → 表記揺れを試す or ページ一覧で検索
- **401/403**: `connect.sid` が期限切れ → ユーザーに「Scrapbox の connect.sid が期限切れの可能性があります。ブラウザの DevTools > Application > Cookies から新しい値を取得してください」と伝える
- **502**: Scrapbox API がダウン → 時間をおいて再試行

## 注意事項

- Scrapbox の内容はユーザーの個人メモを含むため、第三者に共有しないこと
- 大量のデータを取得する場合（2-hop）はコンテキストウィンドウの消費に注意
- `connect.sid` が期限切れの場合、`save-to-scrapbox` スキルの SID も同時に更新が必要

# Save to Scrapbox スキル

会話中のコンテンツ（URL、テキスト、コードスニペットなど）をScrapboxに保存する。
ユーザーが「Scrapboxに保存して」「スクボに入れて」「メモしておいて」と言った場合にこのスキルを使用する。

トリガー例: "Scrapboxに保存して", "スクボに入れて", "メモしておいて", "保存しておいて", "save to scrapbox", "ブックマークして"

## 環境変数

```
SCRAPBOX_PROJECT_NAME=tkgshn-private
SCRAPBOX_CONNECT_SID=<YOUR_CONNECT_SID>
ANTHROPIC_API_KEY=<YOUR_ANTHROPIC_API_KEY>
ANTHROPIC_BASE_URL=<YOUR_ANTHROPIC_BASE_URL>
API_KEY=<YOUR_TWITTER_BOOKMARK_API_KEY>
```

> **セットアップ**:
> - `SCRAPBOX_CONNECT_SID`: Scrapbox にログインし、ブラウザの DevTools > Application > Cookies から `connect.sid` を取得
> - `ANTHROPIC_API_KEY` / `ANTHROPIC_BASE_URL`: LLM 処理用（ccproxy 等を使う場合はそのエンドポイント）
> - `API_KEY`: twitter-bookmark プロジェクトの API キー

## 対応プロジェクト

| プロジェクト名 | 用途 |
|---|---|
| `tkgshn-private` | 個人メモ、ブックマーク |
| `plural-reality` | 多元現実チームのナレッジベース |

ユーザーが「plural-realityに書いて」「チームのスクボに入れて」と言った場合はプロジェクト名を `plural-reality` に変更する。
デフォルトは `tkgshn-private`。

## 使い方

1. ユーザーが保存したいコンテンツを特定する（URL、テキスト、会話の要約など）
2. ツイートURLなら `/api/bookmark` に送信、それ以外なら `@cosense/std` で直接書き込み

### ツイートURLの場合

```bash
curl -s -X POST http://localhost:3000/api/bookmark \
  -H "Content-Type: application/json" \
  -H "x-api-key: <YOUR_TWITTER_BOOKMARK_API_KEY>" \
  -d '{"url": "ツイートのURL"}'
```

前提条件:
- `cd /path/to/twitter-bookmark && npm run dev` が起動中
- LLM プロキシ（ccproxy 等）が起動中

### 任意のテキストの場合

ツイートURL以外のコンテンツを保存したい場合は、Scrapboxに直接書き込む。

**重要**: `@cosense/std` が必要。`/tmp` にインストールしてから実行する:

```bash
# 初回のみ: 依存関係インストール
cd /tmp && npm init -y --silent 2>/dev/null && npm install @cosense/std 2>/dev/null

# 書き込み実行（プロジェクト名は適宜変更）
cd /tmp && npx tsx -e "
import { patch } from '@cosense/std/websocket';

const PROJECT = 'tkgshn-private';  // or 'plural-reality'
const SID = '<YOUR_CONNECT_SID_DECODED>';

await patch(
  PROJECT,
  'ページタイトル',
  () => [
    'ページタイトル',
    ' 保存したいコンテンツ',
    ' #メモ'
  ],
  { sid: SID }
);
console.log('Saved!');
"
```

> **注意**: SID は URL デコード済みの値を使うこと（`s:` で始まる形式）。
> `connect.sid` Cookie の値を URL デコードして使う。

**長いコンテンツの場合**: `.mts` ファイルを `/tmp/` に作成してから `cd /tmp && npx tsx ファイル名.mts` で実行する。

## 処理フロー

1. ユーザーの指示から保存対象を特定
2. ツイートURLなら `/api/bookmark` に送信
3. それ以外なら `@cosense/std` で直接Scrapboxに書き込み
4. 保存結果をユーザーに報告

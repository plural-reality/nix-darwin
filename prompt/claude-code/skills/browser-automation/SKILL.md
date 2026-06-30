---
name: browser-automation
description: "ブラウザ操作が必要なタスクを自動検出し、Playwright CLI で実行する。MCP比トークン70%以上削減。トリガー: \"サイトを見て\", \"ページを開いて\", \"ブラウザで確認\", \"Twitterを調べて\", \"スクショ撮って\", \"URLを開いて\", \"動作確認して\", \"browse\", \"open page\", \"check website\""
---

# Browser Automation Skill

Playwright CLI（`~/.claude/scripts/pw.mjs`）を使ったブラウザ自動操作スキル。
MCP のアクセシビリティツリー全返しと比べ、**トークン消費を70%以上削減**。

---

## アーキテクチャ

```
[Claude Code] --Bash--> [pw.mjs] --playwright-core--> [Chromium headless]
                                         ↑
                              ~/Library/Caches/ms-playwright/ のバイナリを使用
```

- **主要ツール**: `~/.claude/scripts/pw.mjs`（Node.js スクリプト）
- **依存**: `playwright-core`（`~/.claude/scripts/node_modules/`）
- **ブラウザ**: Playwright 管理の Chromium（ヘッドレス）
- **フォールバック**: Playwright MCP（`settings.local.json` で有効化済み）

---

## いつ・どう使うか

### 自動使用（ユーザー確認不要）

以下を検出したら、**Bash ツールから `pw.mjs` を即実行**:

| トリガー | コマンド例 |
|---|---|
| URL を「見て」「確認して」「開いて」 | `pw.mjs text '<url>'` |
| Twitter/X/SNS の確認 | `pw.mjs text '<url>' --wait 3000` |
| JS レンダリングが必要なページ | `pw.mjs text '<url>' --wait 2000` |
| スクリーンショット依頼 | `pw.mjs screenshot '<url>' /tmp/shot.png` |
| デプロイ後の確認 | `pw.mjs screenshot '<url>' /tmp/shot.png --full-page` |
| 認証が必要なサイト | `pw.mjs text '<url>' --user-data-dir '...'` |

### ユーザー確認が必要な操作

- 購入・決済・送金
- メッセージ送信・SNS 投稿
- アカウント設定変更
- データ削除

### 判断フロー

```
WebFetch で十分？ → Yes → WebFetch を使う
       ↓ No
JS レンダリング / 認証 / SPA が必要？ → pw.mjs を使う
       ↓
複雑なマルチステップ操作？ → Playwright MCP にフォールバック
```

---

## コマンドリファレンス

すべて **Bash ツール**から実行する。パスは常にフルパスで指定:

```bash
node ~/.claude/scripts/pw.mjs <command> <url> [args] [--options]
```

### text — テキスト取得（最頻出）

```bash
node ~/.claude/scripts/pw.mjs text '<url>' [--wait <ms>] [--max-chars <n>]
```

ページの可視テキストを抽出（script/style/svg/aria-hidden を自動除去）。
デフォルト 8000 文字で切り詰め。SNS 系は `--wait 3000` を付けること。

### screenshot — スクリーンショット

```bash
node ~/.claude/scripts/pw.mjs screenshot '<url>' [output] [--full-page] [--viewport WxH]
```

デフォルト出力: `/tmp/pw-screenshot.png`。撮影後に `Read` ツールでユーザーに見せる。

### html — HTML 取得

```bash
node ~/.claude/scripts/pw.mjs html '<url>' ['<css-selector>']
```

セレクタ指定で部分取得可能。全体取得はトークン大なので注意。

### eval — JavaScript 実行

```bash
node ~/.claude/scripts/pw.mjs eval '<url>' '<js-expression>'
```

ページ上で JS を実行し結果を返す。複雑なデータ抽出に便利。

### click — クリック操作

```bash
node ~/.claude/scripts/pw.mjs click '<url>' '<css-selector>' [--wait <ms>]
```

クリック後のページテキストを返す。

### fill — フォーム入力

```bash
node ~/.claude/scripts/pw.mjs fill '<url>' '<css-selector>' '<value>'
```

### pdf — PDF 保存

```bash
node ~/.claude/scripts/pw.mjs pdf '<url>' [output]
```

デフォルト出力: `/tmp/pw-output.pdf`

### wait — 要素待機

```bash
node ~/.claude/scripts/pw.mjs wait '<url>' '<css-selector>'
```

セレクタが表示されるまで待ってからテキストを返す。

---

## 共通オプション

| オプション | 説明 | デフォルト |
|---|---|---|
| `--timeout <ms>` | ナビゲーションタイムアウト | 30000 |
| `--wait <ms>` | 読み込み後の追加待機（SPA/SNS に必須） | 0 |
| `--viewport <WxH>` | ビューポートサイズ | 1280x720 |
| `--full-page` | フルページスクリーンショット | false |
| `--user-data-dir <path>` | Chrome ユーザーデータディレクトリ | なし |
| `--cookie-file <path>` | Cookie JSON ファイルの読み込み | なし |
| `--no-headless` | ブラウザ UI を表示して実行 | headless |
| `--max-chars <n>` | テキスト出力の最大文字数 | 8000 |

---

## よくあるパターン

### Twitter/X の投稿確認

```bash
node ~/.claude/scripts/pw.mjs text 'https://x.com/username/status/123456' --wait 3000
```

### 認証が必要なサイト（Sidekick セッション利用）

```bash
# ⚠️ 先に Sidekick ブラウザを閉じること
node ~/.claude/scripts/pw.mjs text 'https://app.example.com/dashboard' \
  --user-data-dir "$HOME/Library/Application Support/user-data/user"
```

### Vercel デプロイ確認

```bash
node ~/.claude/scripts/pw.mjs screenshot 'https://my-app.vercel.app' /tmp/deploy.png --full-page
```

### ページ内の特定要素だけ取得

```bash
node ~/.claude/scripts/pw.mjs html 'https://example.com' 'main article'
```

### 構造化データの抽出

```bash
node ~/.claude/scripts/pw.mjs eval 'https://example.com' '
  [...document.querySelectorAll("h2")].map(h => h.textContent)
'
```

---

## MCP フォールバック

以下のような CLI では難しい操作が必要な場合のみ、Playwright MCP ツールを使う:

- 複数ステップのインタラクティブ操作（ログイン → 検索 → クリック → 入力を連続）
- ドラッグ & ドロップ
- ファイルアップロード
- ダイアログ処理
- 複数タブの切り替え操作

MCP ツール: `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_type` 等

---

## トラブルシューティング

| 症状 | 対処 |
|---|---|
| `Cannot find package 'playwright-core'` | `cd ~/.claude/scripts && npm install playwright-core` |
| `Executable doesn't exist` | `playwright install chromium` |
| タイムアウト | `--timeout 60000` で延長、または `--wait 5000` で待機追加 |
| テキストが空 | SPA の場合 `--wait 3000` 以上を指定 |
| 認証エラー | `--user-data-dir` でセッションを指定。Sidekick を閉じてから |

---

## 注意事項

- `--user-data-dir` 使用時は **Sidekick ブラウザを閉じてから**実行（プロファイル競合）
- パスワード・クレデンシャル情報は出力に含めないこと
- `--max-chars` でテキスト量を制限し、トークン消費を抑えること
- 出力が 30000 文字を超える場合は Bash ツールで切り詰められるので `--max-chars` を活用

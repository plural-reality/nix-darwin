---
name: todays-task
description: 個人・多元現実の「今日やるべきタスク」を全データソース（Google カレンダー / AIペンダント Limitless / Scrapbox tkgshn-private・plural-reality / Gmail / ローカルメモリ）から並列収集し、個人/多元に分類・優先度付けして、Scrapbox の takalog プロジェクトの日付ページ（YYYY/M/D）に追記する。元タスクが住む tkgshn-private / plural-reality のページへ相互リンクを張ってハブ化する。トリガー: "/todays-task", "今日のタスク", "今日やること", "個人と多元のタスク", "todays task", "today's task"
---

# todays-task

個人・多元現実の「今日やるべきこと」を全ソースから並列収集 → 分類・優先度付け → **Scrapbox `takalog` の日付ページに追記**する orchestrator。元タスクが住む `tkgshn-private` / `plural-reality` のページへ相互リンクし、日付ページを"今日のハブ"にする。

## 実行手順

### 1. 今日の日付を確定
```bash
python3 -c "import datetime;d=datetime.date.today();print(d.isoformat());print(f'{d.year}/{d.month}/{d.day}')"
```
- 1行目 = `DATE_ISO`（例 `2026-06-01`）
- 2行目 = `PAGE`（例 `2026/6/1`）— Scrapbox 日付ページのタイトル（ゼロ埋めしない `YYYY/M/D`）

### 2. 並列収集（Workflow）
収集ロジックは別ファイルに分離済み。`args` で日付を注入して起動する：
```
Workflow({
  scriptPath: "/Users/tkgshn/.claude/skills/todays-task/gather.workflow.js",
  args: { dateIso: <DATE_ISO>, datePage: <PAGE> }
})
```
6エージェント（calendar / pendant / scrapbox:tkgshn-private / scrapbox:plural-reality / gmail / memory-residual）が並列で走り、`{source, reachable, tasks[], notes}` の配列を返す。各 task の `context` には根拠 Scrapbox ページ名が入る（リンク化に使う）。

### 3. 統合・分類
- 6ソースの結果を統合し、重複・近接重複をマージ。
- **個人 / 多元** に分類。**緊急度**（今日・直近の期日 > 継続バックログ）で並べる。
- 引っ越し・社宅・契約など個人と多元が密結合するクラスタは、冒頭に「山場」としてまとめてよい。
- データの確度を明記：カレンダー0件・Gmail要返信0件はその旨、メモリ項目は過去スナップショットのため「要現況確認」を付す。

### 4. Scrapbox 本文を整形（**LLMマーク厳守 + 相互リンク必須**）

canonical: `save-to-scrapbox`（記法）/ `scrapbox-llm-marking`（人間↔LLM 書き分け）/ `natural-writing`（文体）。**以下は例外なく厳守**。整形した本文は Python 等で `/tmp/takalog_body.txt` に出力する（タブ・全角を byte 正確に保つため）。

- **A. LLMが書いた行は必ず `[( …]` の薄字で囲う**（人間が未承認である印。AIスロップ防止）。
  - 見出し: `[(** 🔥 …]`、サブラベル: `[(* 個人]`（既存装飾に `(` を足す）。
  - タスク・散文行: `[( …]`。リンクは `[( …]` の内側に入れてよい（`[( … → [/plural-reality/ページ]]`、末尾は `]]`）。
  - `` `code` `` は装飾内で等幅が壊れるので `[( …]` の外に出す。
- **B. provenance**: ブロック先頭に人間の指示を引用（`>[tkgshn.icon]の指示: 「…」`、引用行は装飾しない）。直後の最初のLLM行にだけ `[claude code.icon]` を付け、以降も全行 `[( …]`。
- **C. タスクは page object 化 + ステータス絵文字**: `[( [⬜ タスク名] 補足 → [/project/根拠ページ]]`。絵文字は4状態（canonical=plural-reality「ToDoカンバン」infobox）: `⬜`未着手=今すぐ着手可 / `⏳`進行中=相手ボール待ち / `⏹️`保留=今は着手不可(将来/依存) / `☑️`完了（`[ ]` は使わない）。
- **D. クロスプロジェクトリンク必須**: 各タスクの根拠ページへ `[/tkgshn-private/…]` `[/plural-reality/…]` を `[( …]` 内に inline。末尾「関連」に当日日付ページ `[/tkgshn-private/<PAGE>]` `[/plural-reality/<PAGE>]` とプロジェクトリンクを置きハブ化。
- **E. 人間の行は絶対に薄字化しない**: 再実行時は既存ページを取得し、人間が触った行——打ち消し `[- …]`（却下/完了）・`[tkgshn.icon]` 等のコメント・薄字を外した素の行——を **byte 単位でそのまま残し**、LLM 行だけ再生成する。人間↔LLM の判定は ground truth（このセッションで生成したか）で行う。

### 5. takalog へ書き込み（**--verbatim / 人間の行を保持**）

薄字マークとインデントを正確に保つため必ず **`--verbatim`**（通常モードはインデント注入で崩れる・薄字化されないので使わない）。
```bash
export SCRAPBOX_SID=$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/settings.json')))['env']['SCRAPBOX_SID'])")
scrapbox-write -p takalog -t "<PAGE>" --verbatim --dry-run < /tmp/takalog_body.txt   # 必ず確認
scrapbox-write -p takalog -t "<PAGE>" --verbatim < /tmp/takalog_body.txt              # replace（既定）
```
- **新規日**（ページが空）: 生成ブロックだけを `[( …]` で組み、replace で書く。
- **再実行・既存に人間の編集あり**: `/api/pages/takalog/<PAGE>` を取得 → 人間の行はそのまま・LLM 行だけ `[( …]` 化した**全文**を組み立て → `--dry-run` 確認 → `--verbatim`（replace）で書き戻す。単純 `--append` はしない（薄字化されず重複する）。
- 書き込み後 fetch して反映を確認し、URL を報告する。承認（薄字→濃）は人間が UserScript で行う（`scrapbox-llm-marking`）。

## データソース（gather.workflow.js が叩く）
| ソース | 取得方法 |
|---|---|
| Google Calendar | MCP `mcp__claude_ai_Google_Calendar__list_events`（gcalcli は使わない） |
| AIペンダント（Limitless） | `python3 ~/.claude/scripts/pendant.py today / search` |
| Scrapbox tkgshn-private | Scrapbox API（SID 認証）。WebFetch は使わない |
| Scrapbox plural-reality | Scrapbox API（SID 認証）。「ToDoカンバン」の絵文字規約に従う |
| Gmail | MCP `mcp__claude_ai_Gmail__search_threads` |
| ローカルメモリ | `~/.claude/projects/-Users-tkgshn/memory/` を Read |

## 注意
- 出力は日本語。
- **LLMマーク（Step 4-A〜E）は厳守**。薄字 `[( …]` を付け忘れた本文を takalog に書かない。人間が承認するまで全LLM行は薄字。
- WebFetch は Scrapbox 本文を壊すので使わない（curl→ファイル→Read か cosense-fetch）。
- メモリは数か月前のスナップショットのことがある。期限超過項目は「要現況確認」と明示し、断定しない。
- `takalog` への書き込みまでがこのコマンドの責務（タスクの実行・着手はしない）。

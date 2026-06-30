---
name: claude-log-to-scb
description: >
  claude.ai の会話ログ(データエクスポート)を自分の管理下に置き、takalog(自分だけが
  アクセスできる最機密 Scrapbox)に「再利用可能なコンテキスト」として取り込む skill。
  会話ページ = ユーザー入力を全文転記(通常表示) + Claude応答を要点要約(LLM・薄表示) +
  案件/人物リンク。さらに人物/案件ごとの entity ページに分配して 2-hop グラフを作る。
  原本(conversations.json)は ~/.claude/data/claude-export/ に cold archive として保持
  (source of truth)、Scrapbox は queryable な materialized view。
  トリガー:「claude会話を取り込んで」「claude.ai のログを takalog に」「会話ログ同期」
  「claude-log-to-scb」「会話エクスポートを取り込む」
---

# claude-log-to-scb

claude.ai の会話履歴を **自分で管理** し、**takalog** に再利用可能なコンテキストとして
蓄積する。Claude Desktop のローカル IndexedDB は会話本文を durable に持たない
(evict 済・サーバが source of truth)ことが検証で判明したため、唯一の全履歴入手経路は
**claude.ai の公式データエクスポート**(設定 → データを書き出す → メールの DL リンク)。

## なぜ takalog か(3層モデル)

privacy 境界 = project 境界 = proxy token 境界。会話ログは第三者の話題や個人情報を含む
最機密データなので、**自分以外アクセスできない takalog** が正準シンク。

| project | tier | 用途 |
|---|---|---|
| plural-reality | 仕事/共有 | チームが見るナレッジ |
| tkgshn-private | 個人 | 個人メモ・日記 |
| **takalog** | **自分のみ** | **会話ログ・メール・人物CRM(最機密)** |

## パイプライン(関数型)

```
export.zip ──unzip──▶ conversations.json (cold archive = SoT)
  │
  ├─ split.py     : 各会話を抽出用にコンパクト化(transcript上限切り)        純粋
  ├─ [Workflow]   : haiku fan-out で {ja_summary,people,projects,             LLM(唯一)
  │                  decisions,commitments} を抽出 → extracted.jsonl
  ├─ ingest.py    : 会話ページ生成(human全文 + 要点 + entityリンク)→ takalog  純粋+書込
  └─ aggregate_and_upsert.py : 人物/案件 entity ページに分配(▼…▲管理ブロック)  純粋+書込
```

- **human(ユーザー入力)= 全文転記・通常表示**(`[tkgshn.icon]`)。あなたの言葉。
- **assistant(Claude)= 要点のみ・薄表示**(`[( …]`)。会話全体の要約。本文は載せない
  (assistantは全体の89%・最大198K字でScrapboxに不適。原本に残る)。
- これは [scrapbox-llm-marking] の「人間 vs LLM 書き分け」にそのまま乗る。

## 使い方

### 自動同期(推奨・API ポーラー)

claude.ai 内部 API で新規/変更会話を差分取得 → takalog。手動エクスポート不要。認証は Claude
Desktop の**生セッション(sessionKey + cf_clearance)を cookie jar から復号して相乗り**
(`claude_cookies.py`)するので Cloudflare に弾かれない。初回だけ Keychain "Claude Safe Storage"
のアクセス許可ダイアログで「常に許可」を押す(以後 headless/launchd 可)。

```bash
S=~/.claude/skills/claude-log-to-scb/scripts
"$S/sync.sh"                  # poll(差分)→split→extract→ingest→aggregate。変更0なら早期exit
"$S/sync.sh" --full           # 全会話を再構築
python3 "$S/poll.py" --dry-run  # new/changed 件数を確認するだけ(書き込み無し)
```

差分: `poll_seen.json`(uuid→updated_at)を初回は手動エクスポートから seed。新規/変更のみ
本文取得し `~/.claude/data/claude-export/live/conversations.json`(export 互換のローリング
アーカイブ)にマージ。変更分は `extracted.jsonl` を無効化して再要約させる。

### 手動エクスポート経由(ブートストラップ/フォールバック)

```bash
S=~/.claude/skills/claude-log-to-scb/scripts

# 0) エクスポート(手動): claude.ai → 設定 → データを書き出す → メールのzipをDL
#    (DLリンクは Cloudflare 保護なので curl 不可。手動DLが必要)

# 1) 抽出用にコンパクト化
python3 $S/split.py ~/Downloads/data-*.zip          # or 展開済みdir

# 2) 要点抽出(headless・claude -p haiku 並列)。extracted.jsonl に追記(冪等)
python3 $S/extract.py                 # 未抽出のみ。--workers N / --limit N / --force(全再抽出)
#    ※canonical は extract.py。大量初回だけ Workflow ツールの model:'haiku' fan-out が速い(任意)

# 3) 会話ページを takalog に(冪等・updated_at watermark)
python3 $S/ingest.py ~/Downloads/data-*.zip --project takalog
#    --dry-run / --limit N / --uuid U / --force

# 4) 人物/案件 entity ページに分配(▼…▲ 管理ブロックを再生成・ブロック外は保全)
python3 $S/aggregate_and_upsert.py --project takalog --min-mentions 2
#    --dry-run / --only ENTITY
```

### Claude Code セッション取り込み(claude.ai と同じ takalog へ)

`~/.claude/projects/**/*.jsonl`(Claude Code CLI のセッション)を claude.ai 会話と**同じ会話ページ形式**で takalog に取り込む。`sessions.py` が cwd→`[project]` リンクに正規化し、probe/一発実行(real user turn < 2、cwd が tmp)を除外。ユーザー入力=全文、Claude の作業=要点(haiku 要約・薄表示)。同じ extract/ingest 描画を再利用するので claude.ai 会話と 1 つの n-hop グラフに合流する。

```bash
S=~/.claude/skills/claude-log-to-scb/scripts

# ワンショット(build → extract(haiku増分) → render → takalog)
"$S/sessions-sync.sh"                 # 本番書込
"$S/sessions-sync.sh" --dry-run       # 書込なし確認
"$S/sessions-sync.sh" --limit 20      # render するページ数を絞る

# 個別ステップ(デバッグ用)
python3 "$S/sessions.py" build        # *.jsonl → sessions/conversations.json + conv-sessions/(compact)
python3 "$S/extract.py" --conv-dir ~/.claude/.cache/claude-log-to-scb/conv-sessions \
                        --out      ~/.claude/.cache/claude-log-to-scb/extracted-sessions.jsonl
python3 "$S/sessions.py" render --project takalog [--dry-run|--limit N|--force]
```

冪等: `seen-sessions.json`(uuid→updated_at)。セッションは追記され続けるので updated_at が進めば再 render される。

### ChatGPT 会話取り込み(claude.ai と同じ takalog へ・第3のソース)

ChatGPT の会話も Claude と同じ `mapping`(UUIDノードグラフ)+`current_node` 構造なので、
**新規に要るのは「ChatGPT → 正規化JSON」アダプタ1枚だけ**(`chatgpt_flatten.py`、純粋関数)。
`current_node` から `parent` を逆走→reverse で線形化し、claude.ai export と同じ
`chat_messages` shape を emit するので、split/extract/render/aggregate を**無改造で流用**する
(sessions.py と同じ「第2/第3ソース」パターン)。原本は ChatGPT のネイティブ graph 形のまま
`~/.claude/data/chatgpt-export/` に cold archive(SoT)、flatten は read 時に適用。

取得経路は2つ。どちらも同じ flatten→下流に合流する(差は取得層だけ):

- **PATH B(実Chrome same-origin・"動的"/即ブートストラップ)** — ログイン済み Chrome タブ内で
  `/api/auth/session`→accessToken→`/backend-api/*` を Bearer 付き同一オリジン XHR で叩く
  (`chrome_fetch.py`)。Cloudflare は実ブラウザなので素通り・token は外部に出さない。
  READ には PoW/Turnstile が掛からない。`update_time` watermark(`poll-chatgpt.json`)で差分。
  **公式 export は数日かかるので、初回フル取得もこの経路で済ませる**のが速い。
  - **一度きりの前提**: Chrome メニュー ▸ 表示 ▸ デベロッパ ▸
    「Apple Events からの JavaScript を許可」をオン(claude-log-to-scb の Keychain
    『常に許可』と同じ。以後は launchd で無人実行可)。
- **PATH A(公式 Export × Gmail・ToS 最クリーン・フォールバック)** — ChatGPT の Export Data の
  ZIP を `--source export` で読む。差分には不向きだが取り込み自体は同型。

```bash
S=~/.claude/skills/claude-log-to-scb/scripts

# 自動同期(PATH B・推奨): 実Chrome poll(差分)→extract→render → takalog
"$S/chatgpt-sync.sh"                       # chrome 差分
"$S/chatgpt-sync.sh" --full                # 全会話を再取得
python3 "$S/chatgpt.py" build --source chrome --dry-run   # new/changed 件数だけ確認

# 公式 export 経由(PATH A・ブートストラップ/フォールバック)
"$S/chatgpt-sync.sh" --source export ~/Downloads/<chatgpt-export>.zip

# 個別ステップ(デバッグ)
python3 "$S/chatgpt.py" build --source chrome [--full|--limit N|--dry-run]
python3 "$S/extract.py" --conv-dir ~/.claude/.cache/claude-log-to-scb/conv-chatgpt \
                        --out      ~/.claude/.cache/claude-log-to-scb/extracted-chatgpt.jsonl
python3 "$S/chatgpt.py" render --project takalog [--dry-run|--limit N|--force]

# 純粋アダプタ単体(stdin→stdout フィルタとして検証/合成)
cat chatgpt_conversations.json | python3 "$S/chatgpt_flatten.py" | jq length
```

冪等: 取得=`poll-chatgpt.json`(id→update_time)、render=`seen-chatgpt.json`(uuid→updated_at)。
ハブは `[ChatGPT会話ログ]`。entity ページへの backlink は会話ページ内の `[entity]` リンクで
ネイティブに張られる(aggregate の管理ブロックは claude 用と sentinel が衝突するため v1 では未配線・
backlink でグラフには合流する)。
ToS 留意: 自分の履歴でも「プログラムによる抽出」は規約グレー。低頻度・ブラウザ内・token 非持ち出しを厳守。

## 冪等性

- **会話ページ**: `seen.json`(uuid→updated_at)。updated_at 不変ならスキップ。
- **entity ページ**: `▼ claude会話ログ context … ▲` の管理ブロックを **毎回フル再生成**
  (extracted.jsonl が完全な SoT なので dedup 不要)。ブロック外の人間/CRM 記述は
  `scrapbox-write --verbatim` で **byte 単位保全**。daily-page.py と同じモデル。
- 再エクスポート → split → extract → ingest → aggregate を流すだけで差分反映。

## ファイル

| path | 役割 |
|---|---|
| `scripts/sync.sh` | claude.ai 自動同期ランナー: poll→split→extract→ingest→aggregate(変更0なら早期exit) |
| `scripts/sessions-sync.sh` | Claude Code セッション同期ランナー: build→extract→render → takalog |
| `scripts/sessions.py` | `~/.claude/projects/**/*.jsonl` を会話形式に正規化(build) + takalog 描画(render) |
| `scripts/chatgpt_flatten.py` | **ChatGPT mapping/current_node → claude.ai-export shape(純粋アダプタ・唯一の新概念)** |
| `scripts/chrome_fetch.py` | PATH B: 実Chrome same-origin GET(`/api/auth/session`→Bearer→backend-api) |
| `scripts/chatgpt.py` | ChatGPT driver: build(export/chrome 取得→flatten→native archive) + render → takalog |
| `scripts/chatgpt-sync.sh` | ChatGPT 同期ランナー: build(chrome差分)→extract→render(変更0なら早期exit) |
| `~/.claude/data/chatgpt-export/` | ChatGPT 原本 cold archive(native graph 形・SoT) |
| `[ChatGPT会話ログ]` (takalog) | ChatGPT ハブページ |
| `scripts/poll.py` | claude.ai 内部API差分ポーラー → `live/conversations.json`(export互換) |
| `scripts/claude_cookies.py` | Claude Desktop cookie jar を復号(sessionKey/cf_clearance/org) |
| `scripts/common.py` | 本文抽出 + 人物エイリアス(canon) + self除外 + esc + latest_archive |
| `scripts/split.py` | conversations.json → compact per-conv files(`~/.claude/.cache/claude-log-to-scb/conv/`) |
| `scripts/extract.py` | claude -p(haiku)並列で要点+entity抽出 → extracted.jsonl(冪等) |
| `scripts/ingest.py` | 会話ページ生成 → takalog |
| `scripts/aggregate_and_upsert.py` | entity ページ分配 → takalog |
| `~/.claude/data/claude-export/<date>/` | 原本 cold archive(SoT) |
| `~/.claude/.cache/claude-log-to-scb/extracted.jsonl` | LLM抽出結果 |
| `[claude会話ログ]` (takalog) | ハブページ(全会話が backlink) |

## 規約

- Scrapbox 記法。会話ページは `--verbatim`(human 全文のインデント/改行を保つ)。
- エイリアス(青山/Bluemo/Shutaro Aoyama → `Bluemo / Shutaro Aoyama`)は common.py の
  `ALIAS` が single source。新しい別名はここに足す(design の [人物エイリアス] 概念)。
- `#` はタグ化されるので使わない([save-to-scrapbox] 準拠)。

## 自動化(状態)

- **取得+取り込み自動化**(実装済): `sync.sh` = claude.ai 内部API差分ポーラー → takalog。
  手動エクスポート不要。launchd で定期実行すれば完全自動(初回 Keychain「常に許可」が前提)。
  内部APIは undocumented なので変わり得る(`poll.py` の3エンドポイントを直す)。
- **read 配線**(実装済): takalog は cosense-context-proxy(`ACCESS_TOKEN_TAKALOG`)+ローカル
  `cosense-fetch -p takalog` に配線済。agent が h=1/h=2 で読める。
- ToS 留意: 内部APIの自動ポーリングは自分の会話データの可搬性だが規約のグレーゾーン。
  ポーリング間隔は保守的に。レート制限値は未確認(deep-research の open question)。

## 注意

- 私的データを読むため **共有 nix-darwin へは publish しない**(mac-local-data と同様)。
- haiku 抽出の canonical は `extract.py`(`claude -p --model claude-haiku-4-5`・`CLAUDE_DAILY_SUMMARY=1` で SessionEnd hook 再帰回避)。大量初回のみ Workflow の `model:'haiku'` fan-out が速い。
- takalog は読取も配線済(2026-06-01): cosense-context-proxy に `ACCESS_TOKEN_TAKALOG`、ローカル `cosense-fetch -p takalog` 対応。agent が h=1/h=2 で takalog を読める。
- 関連: [mac-local-data](ローカルアプリデータ) / [daily-report](日次集約・同じ pipeline 思想) /
  [save-to-scrapbox](書込規約) / [scrapbox-llm-marking](書き分け)。

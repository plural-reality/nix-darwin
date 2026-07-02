---
name: review-page
description: >
  このセッションでやったことを「レビュー依頼」として内部用レビューツール
  (reviewable-html-workbench / 多元現実) にまとめ、コメントを受けられる形でプレビュー共有する。
  Triggers: /review-page, レビューページ, レビュー依頼ページを作る, やったことをまとめてレビュー
---

# /review-page — やったことをレビューページにする

いまのセッションでやったことを「レビュー依頼」として reviewable-html-workbench(表示名=内部用レビューツール｜多元現実) の document-model にまとめ、レンダリングしてプレビューサーバを立て、人(外部レビュアー含む)がコメントを書ける URL を返す。本文構成は `<root>/skills/review-request-page/SKILL.md`(A–H 規範)に従う。

## パス（固定）

- レンダラ repo root（CLI を実行する cwd）: `/Users/tkgshn/Developer/reviewable-html-workbench`
  - ここに `scripts/html_review_workbench/cli.py` がある。`python3 -m scripts.html_review_workbench.cli ...` は必ずこの root を cwd にして実行する。チャットの cwd を root にしない。
- 出力先: `<root>/output/<YYYY-MM-DD>_review-page_<slug>/`（`date +%F` と主題から slug を作る）

## 手順

1. 「やったこと」を事実で集める。
   - 引数 `$ARGUMENTS` があれば、主題・強調点として最優先で反映する。
   - 作業対象 repo（チャットの cwd 等）で `git status -s` / `git diff --stat` / 必要なら `git log --oneline -10` を読み、変更ファイルとコミットを把握する。repo でなければ会話の文脈から成果を要約する。
   - このセッションで実際に行った判断・変更・検証コマンドの結果だけを拾う。推測で埋めない。

2. `document-model.json` を Write で直接作る（`build-model` は使わない）。役割分担は **review-request-page skill**（`<root>/skills/review-request-page/SKILL.md`）に従う＝「依頼の枠」は metadata、「成果物」は本文 blocks。
   - top: `schema_version:"1.0"`, `document_id`(kebab), `title`, `summary`, `generated_at`(`date -u +%FT%TZ`), `review_settings:{enabled:true, mode:"review-server"}`, `blocks:[...]`
   - **metadata（依頼の枠 → タイトル下パネル + 初回モーダル Part2。情報が無いキーは省略可）**:
     `metadata:{ source:"/review-page", requester:"<依頼者>", assignee:"<担当者/レビュー担当>", brief:"<背景・元の依頼の1〜3文>", review_focus:["<見てほしい観点1>","<観点2>"], deadline:"<締切 or 省略>" }`
   - block 必須キー: `id`, `type`, `heading_level`(2 か 3), `content`。type は `callout`/`html`/`code`/`diagram`/`image` のみ（`section`/`text`/`table` は描画されない。表は html block 内の `<table>`）。見てほしい block は `review_required:true`。
   - 本文 blocks（成果物のみ。背景/見てほしいこと/締切/依頼者/担当者は metadata 側＝本文に二重に書かない。レビュー手順も本文に書かない＝モーダルの責務）:
     - （任意）`html`(heading_level:2): 「スコープ / 前提」。Goals・Non-goals を箇条書き。
     - `html`/`code`/`diagram`(heading_level:2, review_required:true): 「やったこと」。固有名詞と数値で具体的に。詳細は `<table>`/図/コードで。
     - （任意）`html`(heading_level:2): 「検討した代替案・判断」。重い案件のみ。
     - `html`(heading_level:2, review_required:true): 「未決事項 / 要判断」。reviewer の判断が要る具体点。
   - 文言は日本語のみ。具体・無駄なし。事実だけ（検証していないことを「やった」と書かない）。

3. CLI を root を cwd にして順に実行。ok でなければモデルを直してから次へ。
   ```bash
   cd /Users/tkgshn/Developer/reviewable-html-workbench && \
     python3 -m scripts.html_review_workbench.cli check-model --model <model.json>
   cd /Users/tkgshn/Developer/reviewable-html-workbench && \
     python3 -m scripts.html_review_workbench.cli render --model <model.json> --output <out-dir>
   cd /Users/tkgshn/Developer/reviewable-html-workbench && \
     python3 -m scripts.html_review_workbench.cli validate --root <out-dir>
   ```

4. プレビューサーバは **agent が直接** Bash tool call で起動する（ラッパースクリプトに入れない＝`$PPID` がセッションを指すように）。
   ```bash
   cd /Users/tkgshn/Developer/reviewable-html-workbench && \
     python3 -m scripts.html_review_workbench.cli preview --root <out-dir> --mode auto --owner-pid $PPID
   ```
   - 返却 JSON の `status` が `running` なら `url` と `stop_command` を取得する。ローカル確認用に `open <out-dir>/index.html` も実行してよい。

5. 最終応答には簡潔に: (a) 共有 URL（外部はこれを開く＝初回モーダルで趣旨が出る）/ (b) 停止コマンド / (c) 出力パス。コメントが付いたら `ingest-review --root <out-dir>` で取り込み、必要に応じ `add-reply --root <out-dir> --thread-id <id> --body "…"` で同じスレッドに返信する旨を一言添える。

6. **外部レビュアーに使い捨て URL で渡す場合（任意。社内ローカルで十分なら不要）**: ローカル preview の代わりに本番(Vercel + Supabase)へ publish し、ログイン不要のトークン URL を返す。
   ```bash
   cd /Users/tkgshn/Developer/reviewable-html-workbench && \
     set -a && . .secrets/supabase.env && set +a && \
     python3 scripts/publish_review.py <model.json>
   ```
   - `REVIEW_API_BASE` / `PUBLISH_SECRET` は `.secrets/supabase.env`(gitignore 済)が唯一の source。コマンドにホストや secret を直書きしない。
   - 出力された `https://<host>/?r=<token>` をそのまま外部に渡す（外部はこの URL を開くだけ＝ログイン不要、初回モーダルで趣旨が出る）。コメントは Supabase に永続化される。
   - publish 後のコメント取り込みは `GET <REVIEW_API_BASE>/api/r/<token>/comments` を `comments.json` に保存して `ingest-review` に渡す（ローカル preview とは別経路）。

## ガード
- 事実だけ載せる。検証していないことを「やった」と書かない。
- `review_settings.mode` は `review-server` 固定（コメントを受けるため）。
- 出力 UI は日本語（レンダラ側で対応済み）。

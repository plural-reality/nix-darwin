---
name: gdrive
description: >
  Google Drive 上のドキュメントをターミナルから操作するスキル。
  `gws` (Google Workspace CLI) + Docs API `batchUpdate` でセクション単位の差分更新、
  破損した .docx コメントの救出、native Google Docs への移行を扱う。
  トリガー: 「Driveのファイル」「docx 編集」「ドライブ」「gdrive」「リモートのドキュメント」
  「Google Docs」「コメントが壊れた」「多元現実関連の外部ソース」
  「法人 Google Workspace」「pull」「push」「diff」(Drive 文脈)
---

# gdrive — Google Drive Document Workflow

Google Drive 上のドキュメントを、ブラウザを開かずターミナルから操作する。Docs API の `batchUpdate` でセクション単位の部分更新を行い、他者の書式・画像・コメントを保持する。

## Golden Rules (先に読む)

1. **コメントが重要なドキュメントは最初から native Google Docs で作る**。`.docx` を経由しない。
2. **`.docx` を Drive に上書きアップロード（再生成→上書き）しない**。同一テキストでも Drive が「削除→追加」として扱い、コメント anchor が壊れる。
3. **native Docs の編集は Docs API `batchUpdate` でセクション単位**。ファイル全置換はしない。
4. **push 前に必ず `status` / `diff` でリモートの他者編集を確認**。差分があれば止まってユーザーに報告する。
5. コメントは Drive API (`drive.comments`) か docx XML (`word/comments.xml`) のどちらかに存在する。存在場所を最初に確定させる。

## Routing / Account Boundary

ユーザーがコメントや指示で **「多元現実関連の外部ソース」**、**「法人の Google Workspace」**、**「共有 Drive / Docs / Sheets / Slides」** を参照させた場合は、まず `gws` を使う。これは Plural Reality Workspace への非対話 interface であり、個人 Gmail への入口ではない。

Taka の MacBook では `gws` は Domain-wide Delegation で `takagi@plural-reality.com` を impersonate する。したがって、結果は法人アカウント側の権限・共有ドライブ・共有ドキュメントを反映する。

現在の DWD authorized scopes は **Drive / Docs / Sheets / Slides のみ**。利用できる代表操作:

- Drive: files list/get/create/copy/update/export、permissions、comments
- Docs: documents get、batchUpdate
- Sheets: spreadsheets / values の読取・更新
- Slides: presentations の読取・更新

現在の DWD では **Gmail と Google Calendar は未承認**。法人 Gmail / 法人 Google Calendar を `gws` で扱う必要が出た場合は、Workspace Admin Console の Domain-wide Delegation client `100692351286360570804` に scope を追加し、同じ scope を `/private/etc/nix-darwin/personal.nix` の wrapper `scopes` に追加してから使う。片側だけ変更してはいけない。

アカウントの切り分け:

- **個人 Gmail (`@gmail.com`)**: `gws` で読まない。個人メールの文脈なら Gmail connector / 個人 OAuth 側を使う。曖昧なら読む前に確認する。
- **法人 Gmail (`takagi@plural-reality.com`)**: `gws` の対象になりうるが、現状は Gmail scope が無いので読めない。必要時に `gmail.readonly` / `gmail.modify` 等を明示追加してから使う。
- **予定・空き時間確認**: Google Calendar ではなく Apple Calendar が authoritative。`gws` Calendar を空き判定の source of truth にしない。
- **法人 Google Calendar のオブジェクト操作**: Google Workspace 側のカレンダーを明示された場合だけ扱う。現状は Calendar scope が無いので、必要時に `calendar.readonly` / `calendar.events` / `calendar` 等を明示追加してから使う。

## Setup / Auth

`gws` は nix-darwin で全員に配布されている。認証モデルは2つある。

### 通常メンバー: user OAuth

詳細手順は Scrapbox の `倍速チーム gws セットアップ (Claude Code から Drive 操作)` ページ参照。要約:

```bash
# 1. Team Drive から client_secret.json を DL して配置
#    https://drive.google.com/file/d/1Kl0Af7JYk6ot6Cx6JjX0qtztvV9h2gPK/view
mkdir -p ~/.config/gws
mv ~/Downloads/gws-client_secret.json ~/.config/gws/client_secret.json

# 2. 自分の *@plural-reality.com アカウントで認証
gws auth login

# 3. 疎通確認
gws drive files list --params '{"pageSize": 3}'
```

OAuth は plural-reality.com 組織配下の Internal 設定なので、`*@plural-reality.com` アカウントを持つ人だけが認証できる。test user 登録は不要。以降、Claude Code が `gws` コマンドを発行 → 本人の Google 権限で動く。

### Taka の MacBook: Service Account + Domain-wide Delegation

`/private/etc/nix-darwin` の個人 downstream では、`gws auth login` の refresh token に依存しない。Home Manager の `gws` wrapper が実行時に SOPS から service account JSON を一時復号し、Domain-wide Delegation の JWT bearer flow で `takagi@plural-reality.com` の短命 access token を発行し、`GOOGLE_WORKSPACE_CLI_TOKEN` として upstream `gws` に渡す。

この方式の source of truth:

- local binding: `/private/etc/nix-darwin/personal.nix`
- encrypted key: `/private/etc/nix-darwin/secrets.yaml`
- secret key name: `gws_agent_dwd_service_account_json`
- service account: `gws-agent-dwd@plural-reality-gws.iam.gserviceaccount.com`
- Workspace DWD client ID: `100692351286360570804`
- authorized scopes: Drive / Docs / Sheets / Slides

重要: `gws 0.22.5` は `GOOGLE_WORKSPACE_CLI_IMPERSONATED_USER` を直接サポートしない。過去の built-in impersonation は削除済みなので、service account JSON を `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` に渡すだけでは service account 自身として動く。Taka の環境では wrapper が `sub=takagi@plural-reality.com` の JWT を作って token 注入することで DWD を成立させる。

検証:

```bash
gws drive about get --params '{"fields":"user/emailAddress"}'
# expected: takagi@plural-reality.com
```

平文の service account JSON を repo に置かない。追加・ローテーション時は SOPS encrypted `secrets.yaml` だけを commit 対象にする。

## メタデータ: `.gdrive.json`

各ローカル MD と同じディレクトリに置く。個人ディレクトリに作成するもので、repo にコミットしない。

```json
{
  "documentId": "GOOGLE_DOCS_ID",
  "fileName": "ドキュメント名",
  "localMd": "提案書.md",
  "lastPull": "ISO8601",
  "originalDocxId": "変換元の.docx の Drive ID (ある場合)"
}
```

## native Google Docs をゼロから作成する（`create`）

新規の正式文書（申入書・提案書など）は、最初から **native Google Docs** で作る。`.docx` を経由しない（Golden Rule 1）。

### Step 1: フォルダ ID を確定 → 空の native Doc を作成

`gws docs create` という**サブコマンドは存在しない**。native Doc は Drive API の `files.create` で `mimeType` を指定して作る。

```bash
# 置き場所(共有ドライブ等)のフォルダIDを先に検索
gws drive files list --params '{"q":"name = '\''フォルダ名'\'' and mimeType='\''application/vnd.google-apps.folder'\'' and trashed=false","fields":"files(id,name)","supportsAllDrives":true,"includeItemsFromAllDrives":true,"corpora":"allDrives"}'

# 空の native Doc を作成（webViewLink が共有/閲覧URL。documentId はこの id）
gws drive files create --json '{"name":"ドキュメント名","mimeType":"application/vnd.google-apps.document","parents":["FOLDER_ID"]}' --params '{"fields":"id,name,webViewLink,parents","supportsAllDrives":true}'
```

> **共有ドライブ内に置いた瞬間、そのフォルダの共有メンバー全員に見える。** 作成直後に `drive.permissions.list` で公開範囲を確認すること。「まだ見せたくない相手」がメンバーにいたら個人フォルダへ作る。anyone-link が付いていなくても、named member には見える。

### Step 2: 本文を「構造＋装飾」で投入する（プレーンテキスト全流し込みは禁止）

**やってはいけない**: `insertText` で全文をベタ流しするだけ。見出し・リンク・上付きなどの装飾がすべて失われ、ただのテキストの塊になる（過去にこれをやって「もともとの装飾が失われている」と指摘された）。

**正しい手順（2 ステージ）**: ① プレーンテキストを流し込む → ② **テキスト長を変えない装飾リクエスト**を `batchUpdate` でまとめて当てる。装飾はテキスト長を変えないので、流し込み時に計算した index がそのまま使える。

装飾は Python でセグメント配列（各段落に `heading` / `link` / `superscript` 属性）を組み、`doc index = 1 + 文字オフセット` で range を算出して一括投入する。要点だけ:

```jsonc
// ② batchUpdate の requests（index は ① 投入後の 1+offset）
// 見出し: 段落テキスト範囲に namedStyleType（改行は含めない＝その段落だけに効く）
{"updateParagraphStyle":{"range":{"startIndex":S,"endIndex":E},"paragraphStyle":{"namedStyleType":"HEADING_2"},"fields":"namedStyleType"}}
// ハイパーリンク: 表示テキストに link を張る（生 URL は本文に出さない）。青+下線で見た目も締まる
{"updateTextStyle":{"range":{"startIndex":S,"endIndex":E},"textStyle":{"link":{"url":"https://..."},"foregroundColor":{"color":{"rgbColor":{"red":0.067,"green":0.333,"blue":0.8}}},"underline":true},"fields":"link,foregroundColor,underline"}}
// 上付き脚注番号: Unicode の ¹²³ ではなく、通常数字 "1" に baselineOffset=SUPERSCRIPT を当てる（フォント崩れを防ぐ）
{"updateTextStyle":{"range":{"startIndex":S,"endIndex":E},"textStyle":{"baselineOffset":"SUPERSCRIPT"},"fields":"baselineOffset"}}
```

> 既存の native Doc を**編集**するとき（作成ではなく）は、全消去→全挿入をしてはいけない。他者の書式・コメントが飛ぶ。`push`（batchUpdate でセクション単位差し替え、Golden Rule 3）に従う。本「全流し込み」が許されるのは**自分が今 Step 1 で作った空 Doc の初回投入**のときだけ。

### コメントは native Docs に「アンカーできない」

Drive API `drive.comments.create` に `quotedFileContent.value`（引用文）を渡しても、**native Google Docs では本文にハイライト固定されず「元のコンテンツは削除されました」になる**（API は成功し `id` も返るので気づきにくい）。SKILL の旧版にあった「anchor は `quotedFileContent.value` から自動逆引きされる」は、移行済み .docx 等の限定ケースの話で、**新規 native Doc の本文には効かない**。

→ **計算ロジック・出典・補足は、コメントではなく本文側に入れる**。具体的には**脚注方式**（本文の数値の直後に上付き番号、文末に「脚注（算定根拠・参照資料）」セクションを作り、計算式＋ハイパーリンクを置く）。コメントは「相手にレビューしてほしい問い」専用と割り切る。

### 検証は「API の戻り値」ではなく「実際に適用された構造」で

`comments.create` の戻り値に `quotedFileContent` が入っていても、表示はアンカー切れになりうる。**作業後は必ず `documents.get` で読み戻し、`paragraphStyle.namedStyleType`(見出し) / `textStyle.link`(リンク) / `textStyle.baselineOffset`(上付き) を数え、期待数と一致するか確認する。** 「API が 200 を返した」を完了の根拠にしない。

### 対外文書を書くときの中身ルール（今回の学び）

- **数値には必ず算定根拠と出典リンクを添える**（参照透過性）。読み手が一次資料へ辿れる丁寧さが信頼になる。
- リンクは**相手に共有済みの安全な資料だけ**を貼る。社内の交渉戦略メモ（例: 何を交換材料にするか等）が書かれた Scrapbox 等は絶対に貼らない。社内版と対外版で参照先を分ける。
- 既に相手へ送ったメッセージ（過去の共有・報告）がある文脈では、**その文言・数字と地続きになるよう書く**（「先日ご報告のとおり〜」で接続し、同じ数字を使う）。新規に書き起こさない。

### 文体ルール（ユーザーが初稿をこう直した＝この形で最初から書く）

AI が書きがちな「いかにも文書」を、ユーザーは毎回そぎ落とす。下記は実際の添削差分から抽出。**最初からこの形で書けば手直しが要らない。**

- **「件名：」ラベルを付けない。** タイトル行はラベルなしで件名そのものを置く（見出しスタイルは付けてよい）。
- **拝啓・時候・前口上を入れない。** 「拝啓　平素より格別のご高配を賜り…」のような定型挨拶段落は丸ごと不要。事実（財務状況の報告など）から入る。
- **「記」を使わない。** 記書きの体裁にしない。番号セクションを直接続ける。
- **一文一行。** 一段落に複数の文を詰めない。文が変わったら改行する。意味のまとまりの切れ目には空行を入れる。
- **行頭の記号マーカーをベタ打ちしない。** `・`、`(a)`/`(b)`、`1.`/`2.` のような記号を生テキストで置かない。箇条書きが要るなら Docs のリスト機能（`createParagraphBullets`）で付ける。本文の各項目はプレーンな一文一行で並べる。
- **社内ジャーゴンを対外文では平易語に。** 「次の谷でも現金フロアを保てる」→「現金 6,000,000円 を保てる」のように、社内モデル用語（谷・フロア・予実 等）は相手に通じる言葉へ。脚注の計算根拠も同様。
- 総じて、**装飾の薄い・前置きの無い・一文一行の素直な文**を好む。丁寧さは挨拶句ではなく「数値＋根拠リンク」で担保する。

## コマンド体系

### `clone` — Drive ファイルをローカルに初回取得

```bash
# 1. ファイル検索
gws drive files list --params '{"q": "name contains '\''キーワード'\''", "fields": "files(id,name,mimeType,modifiedTime)", "supportsAllDrives": true, "includeItemsFromAllDrives": true, "corpora": "allDrives"}'

# 2a. もし .docx なら: native Google Docs にコピー変換 (一度だけ)
#     注意: docx 埋込コメント (word/comments.xml) は変換時に失われる可能性が高い。
#     コメントが重要なら先に「コメント救出」セクションの手順で extract してから実行する。
gws drive files copy --params '{"fileId": "DOCX_FILE_ID", "supportsAllDrives": true}' \
  --json '{"name": "ドキュメント名", "mimeType": "application/vnd.google-apps.document"}'
# → 返る documentId を .gdrive.json に記録

# 2b. もし native Docs なら: そのまま documentId を使う

# 3. Docs API で MD エクスポート
gws drive files export --params '{"fileId": "DOC_ID", "mimeType": "text/markdown"}' --output "export.md"
# または docx 経由:
gws drive files export --params '{"fileId": "DOC_ID", "mimeType": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"}' --output "tmp.docx"
pandoc tmp.docx -t markdown --wrap=none -o ファイル名.md && rm tmp.docx

# 4. .gdrive.json 生成
```

### `status` — 同期状態の確認

```bash
gws drive files get --params '{"fileId": "DOC_ID", "fields": "modifiedTime,lastModifyingUser/displayName,version", "supportsAllDrives": true}'
```

`.gdrive.json` の `lastPull` と比較: `in sync` / `remote ahead` / `local ahead`

### `diff` / `pull` — リモートの最新をローカルに反映

```bash
gws drive files export --params '{"fileId": "DOC_ID", "mimeType": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"}' --output "remote.docx"
pandoc remote.docx -t markdown --wrap=none -o remote_tmp.md
diff local.md remote_tmp.md
rm remote.docx remote_tmp.md
# 差分があればユーザーに報告 → マージ → lastPull 更新
```

### `push` — ローカル MD の変更をセクション単位でリモートに反映

**核心: ファイル全置換ではなく、Docs API batchUpdate で変更セクションのみ差し替える。**

#### Step 1: status 確認 (remote ahead なら停止してユーザーに報告)

#### Step 2: リモートの見出し構造を取得

`scripts/extract-headings.py` が見出し → `startIndex/endIndex` を抽出する。**中身を読む必要はない。実行して出力 (見出しごとの範囲) だけ使う。** doc.json を stdin で渡す (引数でファイルパスも可):

```bash
gws docs documents get --params '{"documentId": "DOC_ID"}' | python3 scripts/extract-headings.py
# 出力例:  <startIndex> - <endIndex>  HEADING_2     セクション名
```

#### Step 3: 変更対象セクションの範囲を特定

見出し A の endIndex 〜 次の同レベル以上見出しの startIndex がセクション本文の範囲。

#### Step 4: batchUpdate で差し替え

```bash
gws docs documents batchUpdate --params '{"documentId": "DOC_ID"}' --json '{
  "requests": [
    {"deleteContentRange": {"range": {"startIndex": SECTION_BODY_START, "endIndex": SECTION_BODY_END}}},
    {"insertText": {"location": {"index": SECTION_BODY_START}, "text": "新しいセクション本文\n"}}
  ]
}'
```

**注意:**
- requests は**高いインデックスから順に**実行する (複数セクションの場合)。
- `insertText` はプレーンテキストのみ。表・太字が必要なら `insertTable` + `updateTextStyle` を追加。
- 見出し自体は残す (`deleteContentRange` は見出しの `endIndex` 以降から開始)。
- temp ファイル (`doc.json` 等) は操作完了後に削除。

#### Step 5: `.gdrive.json` の `lastPull` を現在時刻に更新

### `export` — 提出用 docx のエクスポート (最終提出時のみ)

```bash
gws drive files export --params '{"fileId": "DOC_ID", "mimeType": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"}' --output "【提出用】ファイル名.docx"
```

この docx を Drive に戻さない。提出相手に直接渡す。

## コメント救出・再注入 (破損ドキュメントの修復)

.docx の上書きアップロード等でコメント anchor が drift した場合の手順。

### Step 1: コメントの所在を確定

```bash
# Drive API レベルのコメントか？
gws drive comments list --params '{"fileId": "DOC_ID", "includeDeleted": true, "fields": "comments(id,content,anchor,quotedFileContent,resolved,author/displayName)"}'

# 0件なら docx 埋込コメント。docx を DL して word/comments.xml を見る
gws drive files get --params '{"fileId": "DOC_ID", "alt": "media"}' --output current.docx
unzip -o current.docx -d current-unzipped
ls current-unzipped/word/comments.xml
```

### Step 2: コメントと anchor span を抽出

docx 埋込コメントの場合、`word/document.xml` 内の `<w:commentRangeStart>` / `<w:commentRangeEnd>` 間のテキスト断片が anchor span。`scripts/extract-docx-comments.py` が抽出する。**中身を読む必要はない。実行して出力 (コメント本文 + anchor span の JSON) だけ使う。** 引数は unzip 済みディレクトリ (`word/` を含む):

```bash
python3 scripts/extract-docx-comments.py current-unzipped
# 出力: { "<commentId>": {"author": ..., "text": "コメント本文", "anchor": "anchor span"} , ... }
```

anchor span が 1 文字だったり、内容と意味的にズレている場合 = drift。

### Step 3: 新 anchor 位置を semantic マッチで推定

各コメント本文のキーワード (固有名詞、トピック語) と、現ドキュメント各段落のテキストでマッチング → 候補を人間に提示して確認を取る。自動採用はしない (誤爆の影響が大きい)。

### Step 4: native Google Docs へ移行 + コメント再注入

1. `files.copy` で .docx → native Docs 変換 (コメントは引き継がれない前提)
2. 変換後の native Docs に対して、救出したコメントを正しい anchor で再付与:

```bash
# native Docs にコメントを追加
gws drive comments create --params '{"fileId": "NEW_DOC_ID", "fields": "id,content,anchor"}' \
  --json '{"content": "コメント本文", "quotedFileContent": {"value": "anchor したいテキスト"}, "anchor": "kix.xxx"}'
```

anchor は Drive API が自動で計算する `quotedFileContent.value` から逆引きされる。

### Step 5: 旧 .docx をリネームして保全

```bash
gws drive files update --params '{"fileId": "OLD_DOCX_ID"}' --json '{"name": "ファイル名_legacy_YYYYMMDD.docx"}'
```

削除ではなくリネーム。万一の参照用。

## 共有 Drive のファイル ID

Finder 上の `.gdoc` / `.gsheet` ショートカットを `cat` すると ID が取れる:

```bash
cat "/path/to/file.gdoc"
# → {"doc_id": "xxxxx", ...}
```

## トラブルシュート

### `gws auth` で `invalid_grant: reauth related error`

通常メンバーの user OAuth なら credentials が再認証要求に当たっている。`gws auth login` で再認証する。

Taka の MacBook ではこれは古い user OAuth path を踏んでいるサイン。`gws` wrapper が active profile に反映されていない可能性が高い。確認:

```bash
readlink "$(command -v gws)"
gws drive about get --params '{"fields":"user/emailAddress"}'
```

期待値は `takagi@plural-reality.com`。`invalid_rapt` が続く場合は `/private/etc/nix-darwin` で `darwin-rebuild switch` が Home Manager activation まで完了しているか確認する。

### `Export only supports Docs Editors files`

対象が .docx のまま (native Docs になっていない)。`files.copy` で変換するか、`files.get --alt media` でバイナリ DL に切り替える。

### comment API が 0 件を返すが実際にはコメントがある

Drive API ではなく docx 埋込コメント。上記「コメント救出」セクション参照。

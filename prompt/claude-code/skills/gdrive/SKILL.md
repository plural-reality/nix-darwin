---
name: gdrive
description: >
  Google Drive 上のドキュメントをターミナルから操作するスキル。
  `gws` (Google Workspace CLI) + Docs API `batchUpdate` でセクション単位の差分更新、
  破損した .docx コメントの救出、native Google Docs への移行を扱う。
  トリガー: 「Driveのファイル」「docx 編集」「ドライブ」「gdrive」「リモートのドキュメント」
  「Google Docs」「コメントが壊れた」「pull」「push」「diff」(Drive 文脈)
---

# gdrive — Google Drive Document Workflow

Google Drive 上のドキュメントを、ブラウザを開かずターミナルから操作する。Docs API の `batchUpdate` でセクション単位の部分更新を行い、他者の書式・画像・コメントを保持する。

## Golden Rules (先に読む)

1. **コメントが重要なドキュメントは最初から native Google Docs で作る**。`.docx` を経由しない。
2. **`.docx` を Drive に上書きアップロード（再生成→上書き）しない**。同一テキストでも Drive が「削除→追加」として扱い、コメント anchor が壊れる。
3. **native Docs の編集は Docs API `batchUpdate` でセクション単位**。ファイル全置換はしない。
4. **push 前に必ず `status` / `diff` でリモートの他者編集を確認**。差分があれば止まってユーザーに報告する。
5. コメントは Drive API (`drive.comments`) か docx XML (`word/comments.xml`) のどちらかに存在する。存在場所を最初に確定させる。

## Setup (各メンバーが初回に 1 回)

`gws` は nix-darwin で全員に配布されている。OAuth credentials は個人別:

```bash
# 1. OAuth client_secret の入手 (tkgshn に GCP test user 追加を依頼 → 受領)
mkdir -p ~/.config/gws
# client_secret.json を ~/.config/gws/ に配置

# 2. 自分のアカウントで認証
gws auth login
# ブラウザが開く → plural-reality.com アカウントでログイン → credentials.enc が OS keyring に暗号化保存される

# 3. 確認
gws drive files list --params '{"pageSize": 3}'
```

以降、Claude Code が `gws` コマンドを発行 → 本人の Google 権限で動く。

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

```bash
gws docs documents get --params '{"documentId": "DOC_ID"}' --output doc.json
```

```python
# doc.json から見出し → startIndex/endIndex を抽出
python3 -c "
import json
with open('doc.json') as f:
    doc = json.load(f)
for el in doc['body']['content']:
    para = el.get('paragraph')
    if para:
        style = para['paragraphStyle'].get('namedStyleType', '')
        if style.startswith('HEADING'):
            text = ''.join(r.get('textRun', {}).get('content', '') for r in para['elements'])
            print(f'{el[\"startIndex\"]:>5} - {el[\"endIndex\"]:>5}  {style:<12}  {text.strip()[:70]}')
"
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

docx 埋込コメントの場合、`word/document.xml` 内の `<w:commentRangeStart>` / `<w:commentRangeEnd>` 間のテキスト断片が anchor span。Python で抽出:

```python
import xml.etree.ElementTree as ET
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
ns = {'w': W}

# コメント本文
comments = {c.get(f'{{{W}}}id'): {
    'author': c.get(f'{{{W}}}author'),
    'text': ''.join((t.text or '') for t in c.findall('.//w:t', ns))
} for c in ET.parse('current-unzipped/word/comments.xml').getroot().findall('w:comment', ns)}

# anchor span (document order で走査)
active, anchors = {}, {}
def walk(elem):
    tag = elem.tag.split('}')[-1]
    if tag == 'commentRangeStart': active[elem.get(f'{{{W}}}id')] = []
    elif tag == 'commentRangeEnd':
        cid = elem.get(f'{{{W}}}id')
        if cid in active: anchors[cid] = ''.join(active.pop(cid))
    elif tag == 't':
        for cid in active: active[cid].append(elem.text or '')
    for child in elem: walk(child)
walk(ET.parse('current-unzipped/word/document.xml').getroot())
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

credentials が期限切れ。`gws auth login` で再認証する。

### `Export only supports Docs Editors files`

対象が .docx のまま (native Docs になっていない)。`files.copy` で変換するか、`files.get --alt media` でバイナリ DL に切り替える。

### comment API が 0 件を返すが実際にはコメントがある

Drive API ではなく docx 埋込コメント。上記「コメント救出」セクション参照。

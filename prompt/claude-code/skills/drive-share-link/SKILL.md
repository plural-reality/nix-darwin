---
name: drive-share-link
description: |
  Mac の Google Drive (CloudStorage) 上のファイルから fileId と共有URL (webViewLink) を gws CLI で取得し、
  Scrapbox ページ内のローカルパス表記 (例: `経理/xxx.md`) を Drive 共有URL に置換するワークフロー。
  Mac Finder/CloudStorage パス、GWS Drive API、Scrapbox 書き込みの3層を橋渡しする。
  関連スキル: gdrive (Drive 上の docx 編集・pull/push)、scrapbox-context (Scrapbox 読み取り)、save-to-scrapbox (Scrapbox 書き込み)。
  
  トリガー: 「Drive のリンク Scrapbox に貼って」「Drive URL 取って」「ローカルパスをリンクに」
  「Drive 共有設定」「Drive 公開」「Drive ファイル誰がアクセスできるか」
  「Drive と Scrapbox を繋いで」「Finder の Drive ファイル」
---

# Drive Share Link スキル

Mac の Google Drive Desktop で同期されているファイル (`~/Library/CloudStorage/GoogleDrive-{email}/...`) を **fileId と Web 共有 URL に変換** し、**Scrapbox に貼り付ける** ためのワークフロー集。

`gws` (Google Workspace CLI) と `~/.local/bin/scrapbox-write` を組み合わせて、ローカル(Finder/CloudStorage)とリモート(Drive)とパブリッシュ先(Scrapbox)の3層を統合する。

---

## 前提

- `gws` CLI: `/etc/profiles/per-user/tkgshn/bin/gws` に Nix home-manager 経由でインストール済み
- `gws` 認証済み (Google Workspace アカウント、Shared Drive アクセス権あり)
- `~/.local/bin/scrapbox-write` 利用可能 (`SCRAPBOX_SID` env 設定済み)
- Mac の Google Drive Desktop が同期動作中
- 経理書類は通常 `~/Library/CloudStorage/GoogleDrive-{email}/Shared drives/plural-reality/plural-reality/経理/` 配下

---

## ワークフロー1: ファイル名から fileId と webViewLink を取得

最も基本的な操作。Scrapbox に貼る URL が欲しいとき。

```bash
FILENAME="税理士向け説明資料_2026-05-28.md"

gws drive files list --params "$(cat <<JSON
{
  "q": "name = '${FILENAME}'",
  "supportsAllDrives": true,
  "includeItemsFromAllDrives": true,
  "fields": "files(id,name,webViewLink,driveId,parents)"
}
JSON
)" | jq -r '.files[0] | "fileId: \(.id)\nURL: \(.webViewLink)"'
```

**出力例**:
```
fileId: 1iz0s4ElqlxyAn64H5R8SxMzq0QD440AJ
URL: https://drive.google.com/file/d/1iz0s4ElqlxyAn64H5R8SxMzq0QD440AJ/view?usp=drivesdk
```

### 同名ファイルが複数ある場合

`parents` でフォルダを絞り込む。経理フォルダの fileId を先に取得:

```bash
# 経理フォルダの fileId を取得 (一度だけ)
KEIRI_FOLDER_ID=$(gws drive files list --params '{
  "q": "name = '\''経理'\'' and mimeType = '\''application/vnd.google-apps.folder'\''",
  "supportsAllDrives": true,
  "includeItemsFromAllDrives": true,
  "fields": "files(id,name)"
}' | jq -r '.files[0].id')

# 経理フォルダ配下で検索
gws drive files list --params "{
  \"q\": \"name = '${FILENAME}' and '${KEIRI_FOLDER_ID}' in parents\",
  \"supportsAllDrives\": true,
  \"includeItemsFromAllDrives\": true,
  \"fields\": \"files(id,name,webViewLink)\"
}"
```

---

## ワークフロー2: ローカルパスから fileId を取得

Mac CloudStorage パスを直接渡したい場合。**ファイル名を抜き出して検索するのが最も確実**:

```bash
LOCAL_PATH="/Users/tkgshn/Library/CloudStorage/GoogleDrive-takagi@plural-reality.com/Shared drives/plural-reality/plural-reality/経理/税理士向け説明資料_2026-05-28.md"
FILENAME=$(basename "$LOCAL_PATH")

gws drive files list --params "$(jq -nc --arg q "name = '${FILENAME}'" '{q:$q, supportsAllDrives:true, includeItemsFromAllDrives:true, fields:"files(id,name,webViewLink)"}')" | jq -r '.files[0].id'
```

### macOS xattr 経由 (高速だが補助用)

Drive Desktop は xattr に同期メタデータを埋める:

```bash
xattr -p com.google.drivefs.itemtableid "$LOCAL_PATH" 2>/dev/null
```

ただし `itemtableid` は Drive Desktop ローカル ID で **API fileId と異なる**ことがある。確実な変換が必要なら ワークフロー2 のファイル名検索を使う。

---

## ワークフロー3: 共有設定の確認・変更

経理書類などの機密ファイルを **特定のユーザー (税理士など) にだけ** 共有する。

### 現在の共有設定を確認

```bash
FILE_ID="1iz0s4ElqlxyAn64H5R8SxMzq0QD440AJ"

gws drive permissions list --params "{
  \"fileId\": \"${FILE_ID}\",
  \"supportsAllDrives\": true,
  \"fields\": \"permissions(id,type,role,emailAddress,domain)\"
}"
```

### 特定メールアドレスに reader 権限付与 (推奨: 税理士など)

```bash
ADVISOR_EMAIL="advisor@example.com"
FILE_ID="1iz0s4ElqlxyAn64H5R8SxMzq0QD440AJ"

gws drive permissions create --params "{
  \"fileId\": \"${FILE_ID}\",
  \"supportsAllDrives\": true,
  \"sendNotificationEmail\": false
}" --json "{
  \"role\": \"reader\",
  \"type\": \"user\",
  \"emailAddress\": \"${ADVISOR_EMAIL}\"
}"
```

### 組織ドメイン全体に reader 権限付与

```bash
gws drive permissions create --params "{
  \"fileId\": \"${FILE_ID}\",
  \"supportsAllDrives\": true
}" --json '{
  "role": "reader",
  "type": "domain",
  "domain": "plural-reality.com"
}'
```

### ⚠️ 経理書類は anyoneWithLink にしない

`type: anyone` は誰でも URL から閲覧可能になる。**経理・税務情報には絶対使わない**。
ユーザー指定 (`type: user`) かドメイン指定 (`type: domain`) を使う。

---

## ワークフロー4: Scrapbox ページ内のパス表記を URL に置換

Scrapbox ページ内に `経理/xxx.md` のような表記がある場合、それを Drive 共有 URL に置き換える。

### ステップ1: Scrapbox ページの現在の内容を取得

`scrapbox-write` には read 機能がないので、Scrapbox の公開 API か `scrapbox-context` スキル / `cosense-context-proxy` を使う:

```bash
# ページ本文を取得（cosense-fetch -r が /api/pages 取得・connect.sid・URLエンコードを隠蔽）
cosense-fetch -r 'ページタイトル' | jq -r '.lines[].text'
```

### ステップ2: パス表記を URL に置換

```bash
FILENAME="税理士向け説明資料_2026-05-28.md"
PATTERN="経理/${FILENAME}"

# fileId + webViewLink を取得
RESULT=$(gws drive files list --params "$(jq -nc --arg q "name = '${FILENAME}'" '{q:$q, supportsAllDrives:true, includeItemsFromAllDrives:true, fields:"files(id,webViewLink)"}')")
URL=$(echo "$RESULT" | jq -r '.files[0].webViewLink')

# Scrapbox 記法のリンクに変換: [表示文字 URL]
SCRAPBOX_LINK="[${FILENAME} ${URL}]"

# 既存ページの本文を取得 → sed で置換 → 全文書き戻し
PAGE_TITLE="多元現実 freee 初期設定ログ 2026-05-28"
BODY=$(cosense-fetch -r "$PAGE_TITLE" | jq -r '.lines[].text' | tail -n +2)  # 1行目はタイトルなのでスキップ

echo "$BODY" | sed "s|${PATTERN}|${SCRAPBOX_LINK}|g" \
  | ~/.local/bin/scrapbox-write --title "$PAGE_TITLE" --project plural-reality --mode replace --no-gray
# --no-gray: これは既存ページの in-place 書換（パス→URL）なので、人間の本文を灰色化しない。
# (scrapbox-write は通常書き込みでは [( …] を自動付与する＝デフォルトON)
```

### より単純な append アプローチ

ページ全体を置換せず、新しい「リンク集」セクションを追記する:

```bash
cat <<APPEND_EOF | ~/.local/bin/scrapbox-write --title "$PAGE_TITLE" --project plural-reality --append --no-gray

[* Drive 直接リンク (自動生成 $(date +%Y-%m-%d))]
 [${FILENAME} ${URL}]
APPEND_EOF
```

---

## ワークフロー5: フォルダ内全ファイルの URL リスト生成

経理フォルダの全 md ファイルを Scrapbox 用リンクリストに変換:

```bash
KEIRI_FOLDER_ID="1X4QnACGepjMxR2wWui-uUlNVBB6GInTN"  # 経理フォルダ ID

gws drive files list --params "{
  \"q\": \"'${KEIRI_FOLDER_ID}' in parents and trashed = false\",
  \"supportsAllDrives\": true,
  \"includeItemsFromAllDrives\": true,
  \"fields\": \"files(id,name,webViewLink,mimeType)\",
  \"pageSize\": 100
}" | jq -r '.files[] | " [\(.name) \(.webViewLink)]"'
```

出力をそのまま Scrapbox に貼ると、各行が Scrapbox 記法のリンクになる。

---

## ワークフロー6.5: Markdown ファイルを ネイティブ Google Docs に変換

**重要**: 経理書類・税理士向け資料・契約書など、Drive 上で運用する書類は **ネイティブ Google ドキュメント** であるべき (`.md` 添付ファイルではなく)。Scrapbox からリンクするときの URL も Docs Editor を指す:
- ❌ `https://drive.google.com/file/d/{id}/view` (Drive Viewer、添付ファイル用)
- ✅ `https://docs.google.com/document/d/{id}/edit` (Docs Editor、ネイティブ Docs 用)

### Markdown → ネイティブ Google Docs に変換

```bash
# 重要: gws の security validation のため、必ず対象ファイルのあるディレクトリに cd する
cd "$(dirname "$MD_FILE")"

DOC_NAME="ファイル名 (拡張子なし)"
PARENT_FOLDER_ID="1X4QnACGepjMxR2wWui-uUlNVBB6GInTN"  # 経理フォルダ

gws drive files create \
  --params '{"supportsAllDrives":true}' \
  --json "{\"name\":\"${DOC_NAME}\",\"mimeType\":\"application/vnd.google-apps.document\",\"parents\":[\"${PARENT_FOLDER_ID}\"]}" \
  --upload "$(basename "$MD_FILE")" \
  --upload-content-type "text/markdown"
```

レスポンスに `id` が含まれる。これが Docs の fileId。

### Docs Editor URL を構築 (API 取得不要)

```bash
DOC_URL="https://docs.google.com/document/d/${FILE_ID}/edit"
```

`gws drive files get` の出力には `Using keyring backend: file` という非 JSON 行が混じるので、`webViewLink` を取得するなら `2>/dev/null` で stderr 抑制 + `jq -r 'try .webViewLink catch empty'` で耐性を持たせる。URL 構築の方が確実。

### Drive URL → Docs URL への一括置換 (Scrapbox 等)

```bash
declare -a REPLACES=(
  "<OLD_MD_FILE_ID>|<NEW_DOC_FILE_ID>"
  ...
)

SED_ARGS=()
for R in "${REPLACES[@]}"; do
  OLD_ID="${R%%|*}"
  NEW_ID="${R##*|}"
  SED_ARGS+=("-e" "s|https://drive.google.com/file/d/${OLD_ID}/view|https://docs.google.com/document/d/${NEW_ID}/edit|g")
done

# Scrapbox ページに適用 (各ページ取得 → sed → 書き戻し)
```

### 既知の制約

- **同名ファイルの衝突**: Drive は同名ファイルを許容するが、人間として混乱するので Scrapbox ページタイトル等と被らないようにする
- **変換結果の見た目**: Markdown のヘッダー(`#`)、リスト(`-`)、テーブル(`|`)、リンク(`[]()`)は Google Docs 側でほぼ忠実に再現される。コードブロック(```` ``` ````)は等幅フォントとして変換される
- **元 md ファイル**: 変換後の Docs と並行で Drive 上に残る。ユーザー判断で削除 or 保留

## ワークフロー7: Mac Finder 操作との連携

Finder で選択中のファイルを取得 (AppleScript):

```bash
osascript -e 'tell application "Finder" to set selectedFiles to selection as alias list' \
  -e 'set output to ""' \
  -e 'repeat with f in selectedFiles' \
  -e '  set output to output & POSIX path of f & linefeed' \
  -e 'end repeat' \
  -e 'return output'
```

このパス一覧を、ワークフロー2 のスクリプトに渡せば、Finder 選択ファイルを一括で Drive URL に変換できる。

### Finder で Drive Web 版を開く

CloudStorage パスを Drive Web URL に変換して `open` で開く:

```bash
LOCAL_PATH="..."
FILE_ID=$(gws drive files list ...)  # ワークフロー2
open "https://drive.google.com/file/d/${FILE_ID}/view"
```

---

## 既知の制約・エラーケース

| 現象 | 原因 | 対処 |
|---|---|---|
| `gws drive files list` で 0 件 | Shared Drive を含めていない | `supportsAllDrives:true, includeItemsFromAllDrives:true` を必ず付ける |
| 同名ファイルが複数ヒット | `q` がファイル名だけだと一意にならない | `parents` で絞り込み or `modifiedTime` で最新を選択 |
| `permissions create` で 403 | gws 認証アカウントがファイルのオーナー/編集者でない | Drive UI で権限確認、必要なら別アカウントで `gws` 認証 |
| webViewLink が `?usp=drivesdk` 付き | Drive API デフォルト挙動 | そのままで動く、気になるなら sed で除去可 |
| Drive Desktop が同期前 | ファイル作成直後はクラウド側に反映待ち | 数秒〜数分待つ、または `fsync` 系コマンドで強制同期 |
| Scrapbox 記法 `[xxx]` がプロジェクトリンクとして拒否 | `/api/` 等のスラッシュ含む文字列 | バッククォート(コード形式)で囲む or 別記法に変える |
| `scrapbox-write` で長い heredoc を `--mode replace` した時、たまに空 body 送信されページが空になる | 原因不明(API側の処理タイミング?) | (1) 書き込み後に必ず `curl` で line count を再確認、(2) 失敗時は短いサマリ版で再書き込み、(3) 連続書き込みは間隔を空ける |
| `curl` Scrapbox API レスポンスを `jq` でパースすると `control characters` エラー | Scrapbox のページ本文に制御文字 `U+0000`〜`U+001F` を含むことがある | `grep -c '"text":'` で行数代替計測、`jq -r 'try .lines[].text catch ""'` で耐性、または `jq --raw-input '. as $line | $line'` でパースをスキップ |
| `declare -A` 連想配列が zsh で `bad substitution` エラー | macOS デフォルトシェルは zsh、Bash tool 経由でも zsh で実行されることあり | `bash <<'EOF' ... EOF` で明示的に bash サブシェルを起動する |

## 検証ルーチン (scrapbox-write 後は必ず実行)

```bash
# 書き込み直後にページの行数を確認
PAGE="ページタイトル"
LINES=$(cosense-fetch -r "$PAGE" | grep -o '"text":' | wc -l)
echo "$PAGE: $LINES lines"
# 期待される行数より大幅に少なければ書き込み失敗の可能性
```

---

## クイックリファレンス

### よく使う環境変数

```bash
# 共有 Drive (Plural Reality)
DRIVE_ID="0AKoLJ3mnU9T6Uk9PVA"

# 経理フォルダ
KEIRI_FOLDER_ID="1X4QnACGepjMxR2wWui-uUlNVBB6GInTN"

# CloudStorage マウントパス
CS_ROOT="/Users/tkgshn/Library/CloudStorage/GoogleDrive-takagi@plural-reality.com/Shared drives/plural-reality/plural-reality"

# Scrapbox
SCRAPBOX_PROJECT="plural-reality"
```

### ワンライナー集

```bash
# ファイル名 → webViewLink
gws drive files list --params "$(jq -nc --arg q "name = '${FILENAME}'" '{q:$q, supportsAllDrives:true, includeItemsFromAllDrives:true, fields:"files(webViewLink)"}')" | jq -r '.files[0].webViewLink'

# fileId → webViewLink
gws drive files get --params "{\"fileId\":\"${FILE_ID}\", \"supportsAllDrives\":true, \"fields\":\"webViewLink\"}" | jq -r '.webViewLink'

# 経理フォルダ全件
gws drive files list --params "{\"q\":\"'${KEIRI_FOLDER_ID}' in parents and trashed = false\", \"supportsAllDrives\":true, \"includeItemsFromAllDrives\":true, \"fields\":\"files(name,webViewLink)\", \"pageSize\":100}" | jq -r '.files[] | "\(.name) → \(.webViewLink)"'
```

---

## 関連スキル・ツール

- **gdrive スキル**: Drive 上の docx 編集、native Google Docs への移行、batchUpdate
- **scrapbox-context スキル**: Scrapbox から情報を取得
- **save-to-scrapbox スキル**: Scrapbox に書き込む(`scrapbox-write` のラッパー)
- **browser-automation スキル**: Drive Web UI を操作したい場合
- **email スキル**: 共有 URL をメールで税理士に送る場合

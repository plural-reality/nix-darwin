---
name: note-article
description: >-
  Markdown 原稿（本文＋画像＋キャプション）から note.com の下書き記事を、画像を正しい位置に配置し
  キャプション/クレジット付きで自動生成する。note の2026年新エディタ(editor.note.com, ProseMirror/Next.js)
  は合成イベントを無視し公式APIも無いため、Cookie復号ログイン＋Playwright実ブラウザ操作でしか位置指定
  画像挿入ができない。その唯一動く手順とハマりどころを固める。トリガー: 「note記事を作って」「noteに投稿」
  「note下書き」「note記事化」、および長文記事(japanese-tech-writing)の note 出力工程。
---

# note.com 記事作成 (本文＋位置指定画像＋キャプション)

Markdown 原稿を note.com の下書きにする。ゴールは「本文の構造(見出し/引用/リスト/リンク)＋
画像が原稿どおりの位置＋各画像にキャプションとクレジット」が入った、公開できる状態の下書き。

## 大前提: なぜ Playwright なのか (先に読む)

note の2026年エディタ `editor.note.com` は ProseMirror(Next.js SPA)。以下が全部ダメだと実証済み:

- **公式APIは無い**。非公式 `POST /api/v1/text_notes/draft_save?id={数値id}` は**旧エディタ用**で、
  editor.note.com の下書きは別ストレージ(Server Actions)にあり、旧API一覧にすら出てこない。create も 422。
- **JS 合成イベントは効かない**。`ClipboardEvent('paste')` で画像を貼ると**必ず末尾**に落ちる
  (ProseMirror の実キャレットが DOM Range / `selectionchange` に追従しない)。`scrollIntoView` も
  入れ子スクロール容器に効かず座標が画面外。CDN URL の `<img>` を HTML paste しても除去される。
- **合成編集は autosave を発火しない**。だから合成での削除・編集は reload で消える(保存されない)。

唯一動くのは **Playwright の実ブラウザ操作**: 実クリックは ProseMirror の実キャレットを動かし、
`scrollIntoViewIfNeeded` が入れ子容器もスクロールし、実入力が autosave を発火する。
本文貼り付けだけは合成 paste でも保存される(File添付/構造付きHTMLはトリガーになるらしい)。

## 前提環境

- ログイン済み実機 Chrome は **MBA の Profile 5**(note ID = tkgshn)。セッションは mini。
  mini から MBA を ssh 駆動する([[machines]] / [[reference_chrome_control_skill]])。
- Playwright は `playwright-core`(chrome channel、chromium DL 不要)。MBA に `npm i playwright-core`。
- 全スクリプトは MBA 上で実行(Chrome も MBA)。原稿・画像・スクリプトを MBA の作業dirに `scp`/`rsync`。

## 手順

### 0. 原稿と画像を用意

- 原稿 `article.md`: 本文＋ `![キャプション|クレジット](media/xxx.jpg)` 形式の画像行。
  文体は japanese-tech-writing、`content-lint.py` を ERROR=0 に。
- 画像: Wikimedia Commons 等からライセンス確認して取得([[reference_product_catalog_html_page]] の
  Commons 手順)。**eval で送るので長辺900px/700pxに再圧縮**して base64 が ~250KB を切るように
  (`magick x.jpg -resize 900x900\> -quality 78 small/x.jpg`)。
- レビューは reviewable-html-workbench で先に人間確認([[reference_reviewable_html_workbench_ops]])。

### 1. ログイン: note Cookie を復号して Playwright に注入

手動ログイン不要。Profile 5 の `_note_session_v5` を復号し `context.addCookies` する。
Keychain 鍵は ssh 越しだと取れない(ロック)ので**ユーザーに一度だけ**取ってもらう:

```
# MBA のターミナルで(GUIのKeychain許可が要る):
security unlock-keychain ~/Library/Keychains/login.keychain-db
security find-generic-password -w -s "Chrome Safe Storage"   # 例: Yqv3tVEfYDjiCpJC6f3Sqw==
```

その鍵を `CHROME_KEY` に渡して `scripts/decrypt-note-cookie.py` を実行 → `_note_session_v5` の平文。
復号は hashlib(pbkdf2 sha1, saltysalt, 1003, 16) + openssl aes-128-cbc、末尾PKCS7除去、
**先頭32byte(sha256 domain prefix)を剥がす**。curl 検証は WAF で 403 になるが Playwright では通る。

Playwright 側は `context.addCookies([{name:'_note_session_v5', value, domain:'.note.com',
path:'/', httpOnly:true, secure:true, sameSite:'Lax'}])` を **goto 前**に。
`editor.note.com/notes/{KEY}/edit/` を開いて `loginRedirect:false` かつ `.ProseMirror` が見えれば成功。

### 2. 空エディタに構造付き本文を貼る

- `pandoc note-body.md -t html --wrap=none` → `<figure>/<img>/id=` を除去した本文HTML断片。
- **表は note が平坦化する**ので、6層表などは事前に Markdown リスト(`- **層**：値`)へ変換しておく。
- クリア: `execCommand('selectAll')`→`delete` を2回(1回だと残る)。`len=0` を確認。
- 貼り付け: 空の `.ProseMirror` に focus → `selectAllChildren`+`collapseToEnd` → `ClipboardEvent('paste')`
  に `text/html` をセット。`disp=false`(preventDefault) が成功シグナル。`h`(見出し数)を確認。
- これは AppleScript+chrome-js でも Playwright でもよい(構造付きHTML paste は保存される)。

### 3. 画像を位置指定で挿入 (Playwright) = 本命

`scripts/note-insert-images.mjs`。各画像 `{file, anchor, mode}` を**記事順**に処理:

- `anchor` = 直前(または後続)の**テキスト段落の一意な部分文字列**(画像キャプションは使えない=
  貼付直後はキャプション空)。`.ProseMirror > *` の直下ブロックから `innerText.indexOf(anchor)` で探す。
- 一意化: 前段落の末尾40〜120字を取り、本文内で1回だけ出るまで伸ばす(重複すると誤爆)。
- 挿入(after): `para.scrollIntoViewIfNeeded()` → `para.click()`(実クリックでキャレット確定) →
  `keyboard.press('End')` → `page.evaluate` で **File を作って `ClipboardEvent('paste')`**。
  実クリックでキャレットが正位置にあるので、合成 paste でも**その位置に**落ちる。
- 引用ブロック直後は after だと no_upload になる。**mode:'before'** を使う: 後続段落を anchor にして
  `click()`→`keyboard.press('Home')`→paste で「その段落の直前」に入れる。連続画像も before で順序維持。
- アップロード完了待ち: img 数が増えるまで最大 ~28s ポーリング(`assets.st-note.com` に化ける)。
- 保存: 最後に実入力(space→Backspace)で autosave 発火 → `page.reload()` して **imgs 数が残るか**で永続確認。

### 4. キャプション/クレジットを入れる (Playwright)

画像は File paste では**キャプションが付かない**(CC画像は帰属表示が公開条件なので必須)。

- 各画像は `<figure><img><figcaption></figcaption></figure>`。**figcaption は ProseMirror ノード**なので
  クリックして実入力で埋める。
- **落とし穴**: `.ProseMirror figure` は画像以外の figure も拾う(90個等)。**必ず
  `.filter({has: page.locator('img')})` で画像 figure だけに絞る**。全figure index で回すとズレる(実害あり)。
- 上書き手順: 画像 figure を記事順に `nth(i)` → `figcaption.click({clickCount:3})`(トリプルクリックで
  行選択) → `keyboard.insertText(captions[i])`。誤って非画像 figure に付いたキャプションは
  `click({clickCount:3})`+`Delete` で消す。
- captions[i] は `article.md` の画像行から `キャプション（クレジット）` を記事順に抽出。

### 5. 検証

- Playwright: 画像 figure 数 = 期待値、`withCap` = 期待値、reload 後も残るか。sample の先頭数枚が
  記事順(先頭画像→2枚目→…)になっているか目視。
- サーバ真値: `curl 'https://note.com/preview/{KEY}?prev_access_key=...'`(生HTML、ブラウザ非経由)で
  `textnote-body` 内の `assets.st-note.com/.../.jpg` を数える。画像は lazy-load なので DOM で
  「表示されない」ように見えても入っている(慌てて入れ直すと二重化)。

### 6. 仕上げ

- 下書きは autosave 済み。公開はユーザー判断(自動公開しない)。
- 書影/自作図など差し替え予定の画像はキャプションに明記。
- 公開タスクは Scrapbox ToDoカンバンの「いつかやる」に ⬜ ページで積む(このセッションの運用)。

## ハマりどころ集約

- editor.note.com は旧API管轄外。API直叩きは捨てて Playwright UI で。
- 合成 paste の画像は必ず末尾。**実クリックでキャレットを置いてから** paste。
- 引用/特殊ブロック直後は `before`(後続段落 Home)で。
- 表は事前にリスト化。`selectAll+delete` は2回。
- 画像 figure は `filter({has:img})` で絞る。全figure index はズレる。
- eval 送信は容量上限(~256KB)。画像は再圧縮。
- Keychain 鍵は ssh 越し不可 → ユーザーに一度取ってもらう。
- MBA の tailnet/ssh は断続的に切れる日がある。Playwright は**1スクリプトで全枚数**処理して
  ssh 往復を最小化する(per-image ssh eval は timeout 地獄)。

## 関連

[[reference_note_com_paste_injection]](旧: chrome-js での本文/画像 paste。位置指定は不可だった) /
[[reference_chrome_cookie_decrypt_pipeline]](Cookie復号) / [[reference_chrome_control_skill]] /
[[reference_reviewable_html_workbench_ops]] / [[reference_prev_harness_article]](文体) /
[[feedback_external_writing_norms]] / [[machines]]

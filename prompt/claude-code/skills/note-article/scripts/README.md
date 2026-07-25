# note-article スクリプト

全て **MBA 上で** 実行する(ログイン済み Chrome も MBA)。mini からは ssh 駆動。
`NOTE_COOKIE` = `decrypt-note-cookie.py` の `VAL32`、`KEY` = 下書きの note key(`naba...`)。

作業dir(例 `~/tmp/hbl-note/`)に置く入力ファイル:

- `note-images2.json`: `[{"file":"x.jpg","anchor":"直前段落の一意な部分文字列","mode":"after"|"before"}, ...]`
  を **記事順**に。anchor は本文内で1回だけ出る長さに(重複すると誤爆)。`mode` 省略は after。
  引用ブロック直後は `before`(後続段落を anchor に、その直前へ挿入)。
- `captions.json`: `[{"file":"x.jpg","text":"キャプション（クレジット）"}, ...]` を記事順に。
- `img/small/*.jpg`: 長辺900/700pxに再圧縮した画像(base64 が ~250KB 未満)。

スクリプト(各自 `KEY` / dir は先頭定数を編集):

- `decrypt-note-cookie.py` — Cookie 復号(上記)。
- `note-login-check.mjs` — cookie 注入でログインでき、下書きが開けるか確認。
- `note-insert-images.mjs` — 既存画像をクリア→52枚を anchor 位置に実クリック＋Fileペースト→保存→
  reload で永続確認。after モード中心。
- `note-insert-images-before.mjs` — 引用直後など、後続段落の直前(`Home`+paste)に入れる版。
  取りこぼした画像の補完に使う。
- `note-captions.mjs` — 画像 figure(`filter has img`)だけに記事順で figcaption を上書き。
  **applyの後 autosave を長めに待つ(reload しない)**。reload が早いと保存前に消える。

検証はサーバ真値を curl:
`curl 'https://note.com/preview/<KEY>?prev_access_key=...'` の `textnote-body` 内 `assets.st-note.com/*.jpg` を数える。

詳細と落とし穴は親 `SKILL.md`。

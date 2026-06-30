---
name: imessage-send
description: "macOS の iMessage を使って連絡先にメッセージを送信する。トリガー例: \"メッセージして\", \"iMessage送って\", \"LINEして\", \"連絡して\", \"テキスト送って\", \"send message\", \"text someone\""
---

# iMessage Send Skill

macOS の Messages.app / Contacts.app を AppleScript 経由で操作し、iMessage を送る。
**宛先解決 → 送信 → chat.db での着地確認** までを `imsg-send` ヘルパーに集約してある。
素の osascript を都度書くのではなく、原則このヘルパーを使う（過去にハマった落とし穴を全部吸収済み）。

## ヘルパー `imsg-send`

場所: `~/.claude/skills/imessage-send/imsg-send`（このスキルに同梱・自己完結）

IO は Stream として扱う設計: **本文は stdin、宛先は引数、結果は stdout に JSON 1 行**。
本文の供給元（手打ち / ファイル / 別コマンド出力）と送信ロジックを分離する。

```bash
SK=~/.claude/skills/imessage-send/imsg-send

# 1. まず宛先解決だけ確認（送信しない）— ユーザー確認の材料にする
"$SK" --dry-run "Chanju"
#   → {"ok":true,"dry_run":true,"recipient":"Chanju","handle":"+819091150163"}

# 2. 送信（本文は stdin）。着地まで確認して JSON を返す
printf '%s' "送りたい本文" | "$SK" "ちゃんじゅ"
#   → {"ok":true,"handle":"+819091150163","rowid":111781}   ← rowid が出れば実際に送信された
#   → {"ok":false,"error":"..."}                            ← 解決失敗 / 送信失敗 / 着地未確認

# 本文を引数で渡すなら -m（改行や絵文字を含むなら stdin 推奨）
"$SK" -m "本文" "+819091150163"
```

宛先 `<recipient>` は次のいずれでも可:
- **エイリアス**（`~/.config/imsg-send/aliases.tsv` にある別名。例: `ちゃんじゅ`）
- **連絡先名**（Contacts を検索。例: `Chanju` / `Chan PARK`）
- **生ハンドル**（`+819091150163` / `foo@example.com`）

## 手順（エージェント向け）

1. `imsg-send --dry-run "<宛先>"` で解決されるハンドルを確定する。
2. **ユーザー確認は必須。** 宛先（名前＋ハンドル）と本文を提示し、明示的な承認を得る
   （`AskUserQuestion` で「この文面で送っていいか」を聞くのが定番。言語の選択肢も同時に出せる）。
3. 承認後、`printf '%s' "本文" | imsg-send "<宛先>"` で送信。
4. 返ってきた JSON の `"ok":true` と `rowid` を見て「送信完了」を報告する。
   `"ok":false` なら原因（解決失敗 / 送信失敗 / 着地未確認）をそのまま伝える。

## エイリアス（個人マッピング）

ニックネーム→ハンドルの対応は **スキル本体に埋め込まず** `~/.config/imsg-send/aliases.tsv` に置く
（スキルは汎用のまま配布でき、個人の連絡先はリポジトリ外に残る）。
形式は **タブ区切り** `<別名><TAB><ハンドル>`、`#` 始まりはコメント。

```tsv
ちゃんじゅ	+819091150163
チャンジュ	+819091150163
chanju	+819091150163
```

`IMSG_ALIASES=/path/to/file` で別の場所を指定可。

## よく使う連絡先

| ニックネーム | 連絡先名 | ハンドル |
|---|---|---|
| ちゃんじゅ / Chanju | Chanju PARK（配偶者・立命館の留学生） | `+819091150163`（iMessage）/ メール `ce0070xh@ed.ritsumei.ac.jp`, `treasurec529@gmail.com` |

## 落とし穴（ヘルパーで対処済み・素のosascriptで書くとき注意）

- **Contacts の予約語衝突**: `set phones to ""` のように `phones`/`emails` と同名の変数を作ると
  `Can't set every phone to ""` (-10006) で落ちる。プロパティは必ず `(phones of p)` と括る。
- **送信確認に text 列を使わない**: 近年の macOS は `message.text` が NULL で本文は `attributedBody`
  に入る。着地確認は本文一致ではなく「送信直後に `is_from_me=1` の新規行（ROWID > 送信前の MAX）が
  増えたか」で判定する。`imsg-send` は末尾10桁一致＋ROWID差分で確認している。
- **日本の番号 "+81 (0) 90 ..." の (0)**: 素朴に記号を消すと番号が壊れる。`+数字のみ` の候補を
  優先採用するか、末尾10桁で照合する。
- **二重送信の誤検知**: chat.db を見て複数の `is_from_me=1` があっても、ユーザー自身が同時刻に
  手で送った別メッセージのことがある。本文（attributedBody）で別物か確認する。

## 注意事項

- **ユーザーの明示的な承認なしに送信してはならない。**
- 連絡先が見つからない場合は、生ハンドルを聞くか `aliases.tsv` に追記する。
- iMessage が使えない相手は SMS にフォールバックされることがある（緑→送信自体は可）。
- 添付画像の送信は未対応（本文テキストのみ）。必要になったら拡張する。

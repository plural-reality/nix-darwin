---
name: beeper-send
description: >
  Beeper(Slack/LINE/Telegram/Matrix 等を集約するローカル基盤)経由で人・グループにメッセージを送る唯一の窓口。
  鉄則は「ゼロから新規投稿しない。関連する既存スレッドを先に探し、相手の元メッセージにスレッド返信(reply-in-thread)する」。
  チャンネル直投稿で会話を分断したり、依頼/質問への返答を別メッセージとして孤立させたりしない。送信先(chat title)と本文は
  送信前にユーザー承認を取る(durable 許可が無い限り)。canonical CLI はこの skill に同梱した scripts/beeper-send.sh。
  トリガー: 「Beeperで送って」「Slackで返信」「○○さんに連絡/返信」「完了報告して」「このスレッドに返信」「zos/田中さんに送って」
  「秋元さんに報告」、および他スキル(daily-report 等)からの Beeper 送信委譲。iMessage 単体は imessage-send、Beeper 経由の
  Slack/LINE/Telegram/Matrix はこのスキル。
---

# beeper-send — スレッド認識つき Beeper 送信

人にメッセージを送る/返信する時は、**まず関連する既存スレッドを探し、あればその元メッセージにスレッド返信する**。
非スレッドの channel 直投稿は、本当に新規話題でスレッドが存在しない時だけ。

## CLI

canonical CLI はこの skill 同梱の `scripts/beeper-send.sh`（read / reply / delete / thread をワンコマンド化＝トークン節約）。
skill 起動時に「Base directory for this skill」が示されるので、それを `$SKILL` として実行する:

```bash
SKILL="<このskillのbase directory>"           # 起動時に示されるパス
bash "$SKILL/scripts/beeper-send.sh" <subcmd> ...
```

前提: Beeper Desktop が起動しローカル API(`http://localhost:23373`)が生きていること。Bearer token は `~/.config/beeper/token`。

サブコマンド:
- `search "<語>"` — チャットを検索 → chatID
- `messages CHAT_ID [n]` — 直近を新しい順(出力の `reply->NNN` 列＝親メッセージID＝スレッド)
- `thread CHAT_ID MSG_ID` — そのメッセージの返信チェーンを root から復元
- `style CHAT_ID` — この相手の共有文体ガイド(CRM の Scrapbox `[** CRM 文体ガイド]` 由来)を引く。**起草前**に叩く。fail-open(gateway 未起動なら memory 文体メモに戻る)。出力の `contactId=` を控える。
- `send CHAT_ID @file` — 新規送信(スレッドなし)
- `reply CHAT_ID 親MSG_ID @file` — 元メッセージへスレッド返信(**既定**)
- `report-edit CONTACT_ID @下書き @送信済み [CHAT_ID]` — 人間が直した差分を CRM に報告し双方向学習に乗せる。**送信後、下書きと違ったときだけ**。fail-open。
- `delete CHAT_ID MSG_ID` — 自分の投稿を取り消し
- BODY は `@/path/file`(UTF-8。**日本語は必ずこれ**。argv 経由は文字化け) か `"literal"`。

CRM gateway の base は `BEEPER_CRM_GATEWAY`(既定 `http://localhost:8787`)。`style`/`report-edit` は全て best-effort＝gateway が落ちていても送信本体には一切影響しない。

## 手順（毎回これ）

1. **宛先 chat を特定**: `search "<名前/語>"` → chatID。同名・別目的の別グループを掴まないよう、候補は participants(`GET /v1/chats/{encID}`)で確定。
2. **既存スレッドを検知（ミス防止の核）**: `messages CHAT_ID` で直近を読み、返信すべき相手の元メッセージ(依頼/質問/話題)の `id` を見つける。文脈は `thread CHAT_ID <id>` で確認。「相手の依頼に応える/完了報告」→ その依頼メッセージの id に reply する。
3. **文体ガイドを引く（起草前）**: `style CHAT_ID` でこの相手の共有文体ガイド(CRM)を取得し、**human ルールを最優先**に従って起草する(auto ルール・userVoice・関係性ゴールも加味)。**出力の `contactId=` をメモ**(step7 で使う)。取得できなければ(gateway 未起動等)fail-open で、従来どおり memory の相手別文体メモ([[feedback_akiba_message_tone]] 等)にフォールバック。
4. **下書き**: 日本語本文は必ずファイル(scratchpad)に書く。文体ガイドに沿ってトーンを相手に合わせる。この AI 下書きファイルは step7 の学習報告に使うので消さない。
5. **送信前にユーザー承認**: 送信先(chat title)＋本文を提示し承認を得る(durable 許可が無い限り必須)。着手時に既送/相手返信済みでないか履歴で裏取りもする。
6. **送信 + read-back 検証**:
   - 既存スレッドに返す(既定): `reply CHAT_ID 親MSG_ID @draftfile`
   - 新規話題でスレッドが無い: `send CHAT_ID @draftfile`
   - reply は出力最新行の `reply->` が**親MSG_IDと一致**で成功。受理(`pendingMessageID`)は成功証拠でない(ブリッジは数秒遅延)。
7. **編集を学習ループへ報告**: **実際に送った文面が step4 の AI 下書きと違ったら**(＝あなた or ユーザーが直した)、`report-edit <contactId> @下書きfile @送信済みfile <CHAT_ID>` で差分を CRM に報告する。CRM が高信頼な文体ルールを Scrapbox の共有ガイドに materialize し、次回以降 CRM アプリ側の起草にも効く(双方向学習)。下書き通りに送ったなら報告不要。`contactId` は step3 の `style` 出力から。fail-open(HTTP 非200 でも送信は完了済・無視して良い)。

## 取り消し・やり直し

非スレッドで誤投稿・宛先間違い等は `delete CHAT_ID MSG_ID`(HTTP 200・read-back で `DEL` 確認)→ 正しいスレッドに `reply` で送り直す。

## してはいけない

- 相手の依頼・質問への返答を、その元メッセージに紐付けず channel 直投稿で孤立させる。
- スレッドの有無を確認せず `send` する。
- 承認なしで送る(durable 許可がある相手・文脈を除く)。
- mention pill を API で付けようとする(不可。`@名前` はただの文字列。少人数なら通知は届く)。

## 補足（実装メモ）

- スレッド親リンクは read 側の `linkedMessageID`、書き側の `replyToMessageID`(**string 必須**。number だと `VALIDATION_ERROR`)。両者が一致＝スレッド成立(Slack の thread に入る)。
- `send-to` の固定ショートカット(`tagen`/`tanaka`/`zos`)は導入者の Beeper room 依存。各自の room ID に書き換えて使う。

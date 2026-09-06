---
name: beeper-send
description: >
  Beeper(Slack/LINE/Telegram/Matrix 等を集約するローカル基盤)経由の送信用下書きと送信の窓口。
  既存の依頼への応答は元スレッドに返信し、チャンネル全員への更新共有は新規投稿にする。履歴・宛先別の本人文体を確認して起草する。
  送信先(chat title)と本文は
  送信前に、共有agent policyの二段階確認に従って生成後の本文全文へのユーザー承認を取る。canonical CLI はこの skill に同梱した scripts/beeper-send.sh。
  トリガー: 「Beeperで送って」「Slackで返信」「○○さんに連絡/返信」「完了報告して」「このスレッドに返信」「zos/田中さんに送って」
  「秋元さんに報告」、および他スキル(daily-report 等)からの Beeper 送信委譲。iMessage 単体は imessage-send、Beeper 経由の
  Slack/LINE/Telegram/Matrix はこのスキル。履歴の検索・要約だけの依頼には使わない。下書きだけなら送信手前で止める。
---

# beeper-send — スレッド認識つき Beeper 送信

目的は、相手と文脈に合う承認済み本文を、正しい会話単位に一度だけ届けること。配送と編集学習の完了は分ける。

- **個別の依頼・質問への応答**は、関連する元メッセージを先に探してスレッド返信する。
- **チャンネル全員へ見せる完了報告・更新共有**は、新規チャンネル投稿を選ぶ。関連スレッドがあっても共有対象の明示を優先し、二重投稿は依頼がある時だけ。
- 新しい話題で元スレッドがない場合も新規投稿。共有対象が不明で誤送信の影響がある時だけ確認する。
- 本人が指定した送信先・チャネル以外を追加しない。zos向けの内容を個人DMへ重ねない。

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
- `style CHAT_ID` — この相手の共有文体ガイド(CRM の Scrapbox `[** CRM 文体ガイド]` 由来)と、本人がこの会話で実際に送った直近例を引く。**起草前**に必ず叩く。別サービス/停止を成功扱いにしない。
- `send CHAT_ID @file` — 新規送信(スレッドなし)
- `reply CHAT_ID 親MSG_ID @file` — 元メッセージへの応答をスレッド返信
- `send-reviewed CHAT_ID @下書き @送信済み` / `reply-reviewed CHAT_ID 親MSG_ID @下書き @送信済み` — 送信と編集学習を一操作で実行する。AI下書きが人間編集された場合はこちらを使う。ネットワークmutation前にローカルへ非機密attempt stateを保存し、途中失敗後も再送せずreadbackから再開する。
- `report-edit CONTACT_ID @下書き @送信済み [CHAT_ID]` — 既に送った分の差分を CRM に報告する。応答は保存・候補数・Scrapbox反映結果を分けて返す。
- `delete CHAT_ID MSG_ID` — 自分の投稿を取り消し
- BODY は `@/path/file`(UTF-8。**日本語は必ずこれ**。argv 経由は文字化け) か `"literal"`。

CRM gateway の base は `BEEPER_CRM_GATEWAY`(既定 `http://localhost:18787`)。`/healthz` の `service=beeper-crm-gateway` を検証するため、同じポート上の別サービスを文体ガイド無しとして通過させない。

## 手順（毎回これ）

1. **宛先 chat を特定**: `search "<名前/語>"` → chatID。同名・別目的の別グループを掴まないよう、候補は participants(`GET /v1/chats/{encID}`)で確定。
2. **既存スレッドを検知（ミス防止の核）**: `messages CHAT_ID` で直近を読み、返信すべき相手の元メッセージ(依頼/質問/話題)の `id` を見つける。文脈は `thread CHAT_ID <id>` で確認。共有対象を上記の分岐で決める。依頼への応答はその id にreply、チャンネル全員への更新共有は新規投稿とする。
3. **文体ガイドと本人の実送信例を引く（起草前）**: `style CHAT_ID` で取得し、優先順を **human ルール → この相手/会話で本人が実際に送った直近例 → auto ルール → userVoice/関係性ゴール** とする。取得失敗時は起草を続けず gateway を復旧する。人物別 memory へのフォールバックは禁止（Scrapbox以外を第2の人物別SoTにしない）。
4. **下書きと本人訂正**: 日本語本文はファイル(scratchpad)に書く。同じ宛先・目的で最初に提示したAI案を不変のbaselineとして残し、修正版・承認済み全文は別ファイルにする。最後のAI案だけでbaselineを上書きしない。
   本人の訂正で何が変わったか（事実、依頼範囲、文体）を区別する。受領返信に未依頼の宿題・約束を足さず、削除された文を次の修正版で復活させない。目的や宛先が変わったら別の起草単位にし、案件固有の訂正を一般的な人物文体として混ぜない。中間案は必要な分だけタスク内に保持し、新たな学習DBや人物memoryを作らない。
   下書きだけの依頼は、送信先・返信先・本文を提示してここで完了し、送信や学習記録の書込みへ進まない。
5. **送信前に下書き確認**: 送信先(chat title)・返信先・本文全文を提示し、そのターンでは停止する。**その後のユーザー発言**で未変更の下書きへの明示承認を得てからstep 6へ進む。本文提示前の「送って」は承認ではない。`--ack` は直近履歴を読んだ印でしかなく、本文承認の代わりにしない。承認後に本文または宛先を変えたら再提示する。着手時に既送/相手返信済みでないか履歴でも裏取りする。
6. **送信 + read-back 検証**:
   - 元の依頼・質問に返す: `reply CHAT_ID 親MSG_ID @draftfile`
   - チャンネル全員への更新共有、または新規話題でスレッドが無い: `send CHAT_ID @draftfile`
   - reply は実送信本文と `linkedMessageID` が**親MSG_IDと一致**で成功。受理(`pendingMessageID`)は成功証拠でない(ブリッジは数秒遅延)。
7. **編集を学習ループへ報告**: **実際に送る文面が step4 の同一目的baselineと違う場合**は、step6 の `send`/`reply` の代わりに `send-reviewed`/`reply-reviewed` を使う。送信前baseline/attempt保存→本文/返信先/新規IDの厳密readback→編集イベントの冪等append→候補導出→Scrapbox書込readbackまでを一操作にする。応答の `recorded=true` と `materialization=applied|skipped` を確認する。途中失敗時の再実行はattempt stateから学習処理だけを再開し、配送結果が曖昧なら再送せず停止する。下書き通りなら通常の `send`/`reply` でよい。

## 配送と学習の結果を分ける

`pendingMessageID`、空出力、exit 0だけでは配送成功にしない。曖昧なattemptは再送せず、同じチャットの新規ID・本文全文・返信先（新規投稿なら親なし）を正本で読み戻す。
後から配送だけ確認できても、`recorded` / `materialization` が未確認なら学習完了とは言わない。同じattemptの既存復旧経路を使い、配送が曖昧なまま再送したり、別の学習イベントを重複作成したりしない。復旧できない部分は未完了として報告する。

## 取り消し・やり直し

誤投稿があっても、削除・送り直しの対象と承認範囲を確認してから `delete CHAT_ID MSG_ID`（read-backで `DEL` 確認）を使う。
全員向け新規投稿を「非スレッドだから誤り」と判断しない。送り直す場合も本文・宛先・返信先の送信前承認を守る。

## してはいけない

- 相手の依頼・質問への返答を、その元メッセージに紐付けず channel 直投稿で孤立させる。
- スレッドの有無を確認せず `send` する。
- 生成後の本文全文に対する、後続のユーザー発言による承認なしで送る。起草と送信を同じターンで行う。
- mention pill を API で付けようとする(不可。`@名前` はただの文字列。少人数なら通知は届く)。

## 補足（実装メモ）

- スレッド親リンクは read 側の `linkedMessageID`、書き側の `replyToMessageID`(**string 必須**。number だと `VALIDATION_ERROR`)。両者が一致＝スレッド成立(Slack の thread に入る)。
- `send-to` の固定ショートカット(`tagen`/`tanaka`/`zos`)は導入者の Beeper room 依存。各自の room ID に書き換えて使う。

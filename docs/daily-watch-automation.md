# 日報付帯監視の実行契約

## 目的

`automation-2` の毎日監視を、LLM がその場で組み立てる手順ではなく、Nix から配布する型付き CLI の合成として再現可能にする。

## 正本

- 監視定義: `plural-reality/自動監視（多元現実）` と `tkgshn-private/自動監視（個人）`
- 実行状態: `$CODEX_HOME/automations/automation-2/state/watch-state.json`
- Apple Calendar / Reminders: 署名済み `evkitd` を介した `evkit`
- 国税庁インボイス: 適格請求書発行事業者公表サイトの公式差分データ
- e-Tax通知: 固定署名した読取専用 `etax-watchd` が毎回新規接続する公式受付システム
- GMO: `$HOME/.chrome-automation-profile` で起動した専用 Chrome の、当該実行が作った CDP target

## 非目的

- 日報本文の収集・Scrapbox本文の更新
- 通常 Chrome のタブ、Cookie、保存済み秘密値の読取り
- Safari の表示状態・Cookie・Passwords AutoFill の無人再利用
- 認証、OTP、パスキー、CAPTCHA の自動突破
- 外部送信、申告、申込み、支払、購入、既存 Reminders の削除

## 書込み境界

- 取得成功時だけ、最小 fingerprint と取得時刻を state に mode `0600` で原子的に保存する。
- 確定差分または定義済み期限超過だけ、`evkit reminders.ensure` で marker 付き Reminders を冪等作成する。
- `reminders.ensure` は作成前後に同じ marker を EventKit から読み戻す。

## 完了証拠

1. `cosense-fetch` が書込み不能な一時ディレクトリでも取得できる。
2. `evkit status` と `evkit snapshot` が socket activation を含めて成功し、監視 marker だけを安全に投影する。
3. 専用 Chrome が通常 Chrome を前面化せず CDP 応答を返す。認証画面なら型付き停止になる。
4. 最新の公式インボイス差分から `T4011503006669` の有無を決定できる。
5. 差分 TODO は marker で重複せず、EventKit の再読込で確認できる。
6. `etax-watch watch` は資格情報を標準入出力へ出さず、通知件数・未読件数・日付・fingerprintだけを返す。

e-Tax境界の詳細は [e-Tax読取専用broker](./etax-watch-broker.md) を正本とする。

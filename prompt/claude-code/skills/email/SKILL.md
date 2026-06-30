---
name: email
description: >
  himalaya CLI でメールの確認・閲覧・送信・返信、およびメールを根拠に
  ユーザーの発言を裏取り（事実確認）する。
  トリガー: 「メール確認」「メールチェック」「受信箱」「inbox」
  「メール送って」「返信して」「email」「mail」
  「メールで裏取り」「メールで確認して」「事実確認」「〜って本当？」
  「いつ買った/売った/届いた/予約した」「購入履歴」「注文を確認」
---

# Email スキル

himalaya CLI ラッパー (`~/.claude/scripts/himalaya-mail.sh`) を使ってメール操作を行う。

## クイックリファレンス

```bash
SCRIPT=~/.claude/scripts/himalaya-mail.sh

# アカウント確認
$SCRIPT accounts

# 受信トレイ (デフォルト20件)
$SCRIPT inbox
$SCRIPT inbox gmail 50    # 50件取得

# メール読み取り
$SCRIPT read <id>

# 検索 (himalaya query は field 必須。素のキーワードは不可)
$SCRIPT search "from someone@example.com"
$SCRIPT search "subject 会議"
$SCRIPT search "body サロモン"             # 日本語/本文は body/subject を付ける
$SCRIPT search "after 2026-03-01"
$SCRIPT search "from google and after 2026-03-01"
$SCRIPT search "from mercari" gmail 60     # 第3=アカウント, 第4=件数(default 40)

# フォルダ一覧
$SCRIPT folders
```

## 裏取り（メールでの事実確認）

ユーザーの発言（「〜を買った/売った/予約した」「いつ届く」「いくらだった」等）を、
記憶ではなく**メール実物**で確認する手順。`search`→`read`→突き合わせ。

**手順**
1. 主張を検証可能な事実に分解する: 何を / いつ / いくら / どこで / **購入か売却か**。
2. `search` で候補を絞る（field query。下記の構文注意）。固有名詞は英・日 両方試す
   （`body Salomon` と `body サロモン`）。
3. 該当メールを `read <id>` で**本文まで読む**。件名で早合点しない。
4. 主張と突き合わせ、「確認できた / できなかった / 食い違った」を根拠（メールID・日付・
   該当行）付きで明示する。**矛盾は黙って採用せず必ず報告**。確認できない時は捏造せず、
   その旨を伝えて本人に確認する。

**himalaya query 構文の要点（v1.x）**
- field 必須: `from` / `to` / `subject` / `body` / `before YYYY-MM-DD` / `after YYYY-MM-DD`
  / `flag`。`and` / `or` / `not` で連結、`not (...)` で入れ子。
- **日本語の素キーワードは不可** → `body サロモン` のように field を付ける。
- 複雑な `or` 連結は IMAP サーバが BAD を返すことがある → **単一 field で何度か叩く**方が確実。
- 件数は `search "<query>" gmail 60` で増やす（深掘り時）。
- 出力に IMAP の WARN 行が混ざることがある → `... | grep -avE "imap_codec|imap_client|HIGHESTMODSEQ|Rectified|unsolicited|UNSEEN"` で除去。

**本文の読み解き（重要）**
- 件名だけで判断しない。例: メルカリ「取引が完了しました」は**買い手にも売り手にも**届く。
  本文の「**売上が反映されました**」=自分が**売った**側、「お支払い/ご購入」=買った側。
- 金額・サイズ・色・型番・注文番号・発送状況まで取り、固有名詞を確定させる。

**型の例（実績）**
主張「Salomon を買った（メールにあるはず）」→ メール上は **On Cloudmonster を 5/30 に売却**、
Salomon の購入メールは受信箱に未着。→ 件名の早合点を避け、本文＋本人確認で
**Salomon Ultra Glide 3** と確定した。「メールに無い＝嘘」ではなく「未着の可能性」も併記する。

## 送信操作 (要ユーザー確認)

**重要**: 送信・返信・転送は実行前に必ず内容をユーザーに表示し、承認を得てから実行すること。

```bash
# 新規送信 (初めての相手、新しい話題の場合のみ)
$SCRIPT send "to@example.com" "件名" "本文"

# 返信 (送信者のみ)
$SCRIPT reply <id> "返信本文"

# 全員に返信 (To + CC 全員に返信。CCが付いているメールにはこちらを使う)
$SCRIPT reply-all <id> "返信本文"

# 転送
$SCRIPT forward <id> "to@example.com" "追加メッセージ"
```

## 返信ルール (重要)

**受信メールへの応答は必ず `reply` または `reply-all` を使うこと。`send` で新規メールとして送ってはいけない。**

`send` を使うとスレッド情報（In-Reply-To / References ヘッダー）が付かず、相手のメールクライアントでスレッドがバラバラになる。

| 状況 | 使うコマンド |
|---|---|
| 受信メールに返信（CC なし、または CC の人に返信不要） | `reply <id>` |
| 受信メールに返信（CC あり、全員に返信すべき） | `reply-all <id>` |
| 新しい話題で初めてメールを送る | `send` |
| メールを別の人に転送する | `forward <id>` |

**判断基準:**
- 元メールに CC が付いている → 基本 `reply-all` を使う
- 「全員に返信」とユーザーが言った → `reply-all`
- 1対1 のやり取り → `reply`
- 迷ったらユーザーに「reply と reply-all どちらにしますか？」と確認する

## 安全ルール

1. **送信前確認必須**: メール送信・返信・転送は、宛先・件名・本文をユーザーに表示し、明示的な承認を得てから実行
2. **返信 vs 新規の区別**: 受信メールへの応答には絶対に `send` を使わない（上記「返信ルール」参照）
3. **ドラフト表示**: 長文メールは下書きを表示してレビューしてもらう
4. **個人情報注意**: メール本文に含まれる個人情報は不必要に出力しない
5. **添付ファイル**: 現在のラッパーでは未対応。直接 `himalaya` コマンドを使用

## マルチアカウント

デフォルトは `gmail`。他のアカウントを使う場合は最後の引数にアカウント名を指定:

```bash
$SCRIPT inbox work        # workアカウントの受信トレイ
$SCRIPT send "to@example.com" "件名" "本文" work
```

## Gmail フォルダ名リファレンス

| 用途 | フォルダ名 |
|---|---|
| 受信トレイ | `INBOX` |
| 送信済み | `[Gmail]/送信済みメール` |
| 下書き | `[Gmail]/下書き` |
| ゴミ箱 | `[Gmail]/ゴミ箱` |
| スパム | `[Gmail]/迷惑メール` |
| 全メール | `[Gmail]/すべてのメール` |
| スター付き | `[Gmail]/スター付き` |
| 重要 | `[Gmail]/重要` |

## アカウント追加手順

1. アプリパスワードを生成 (Google: セキュリティ → 2段階認証 → アプリパスワード)
2. Keychain に登録:
   ```bash
   security add-generic-password -a 'user@gmail.com' -s 'himalaya-imap' -w 'APP_PASSWORD'
   ```
3. `~/Library/Application Support/himalaya/config.toml` にアカウントセクション追記
4. `himalaya account list` で確認

## トラブルシューティング

- **認証エラー**: `security find-generic-password -a 'EMAIL' -s 'himalaya-imap' -w` でパスワード取得確認
- **フォルダエラー**: `himalaya folder list` で実際のフォルダ名を確認
- **タイムアウト**: IMAP 接続に数秒かかることがある。初回は待つ

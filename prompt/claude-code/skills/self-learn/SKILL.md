---
name: self-learn
description: セッション終了時(Stop hook 発火)または「振り返って」のオンデマンドで、自己学習メモリを更新する単一の窓口。canonical store は harness ネイティブの ~/.claude/projects/-Users-tkgshn/memory/(MEMORY.md が毎セッション自動注入される唯一の正本)。手続き=(1)今セッションで*依拠した注入メモリが現実と矛盾していたら*その1ファイルを自動修正/削除し readback 検証(確認なし)、(2)基本的な学びは確認せず即追加し、『一度叩けば恒久キャッシュできる高レバレッジな外部情報(保管場所/ID/アカウント帰属/APIエンドポイント等)』だけ AskUserQuestion で取得＆保存の可否を確認、(3)MEMORY.md が肥大化(>200行/重複)したら統合・圧縮。トリガー:「振り返って」「self-learn」「今の学びを保存」「学びをメモリに」、および stop-reflect-nudge.py。
---

# self-learn — 自己学習メモリの単一窓口

自己フィードバックループの **procedure はここが唯一の正本**。trigger は Stop hook
(`~/.claude/scripts/stop-reflect-nudge.py`) が決定論的に持つ。hook は「実質作業をしたら振り返れ」と
発火させるだけで、*どこに・どう書くか* の知識は持たない(ドリフト防止)。

## canonical store（唯一の正本・ここにしか書かない）

`/Users/tkgshn/.claude/projects/-Users-tkgshn/memory/`

- harness が毎セッション `MEMORY.md`(索引)を system reminder として**自動注入**する。
  ここに書けば**次の自分に即届く**。これが他のどの場所より優先される唯一の理由。
- 1ファイル = 1事実。frontmatter は `name` / `description` / `metadata.type`
  (`user` | `feedback` | `project` | `reference`)。本文で関連を `[[name]]` リンク。
- `MEMORY.md` に1行ポインタ `- [Title](file.md) — フック` を足す(本文は書かない・索引だけ)。
- ❌ `~/.codex/memories/` には**書かない**。Claude Code には自動注入されないので、書いても
  次の自分に届かない(過去この writer↔reader 不一致が事故源だった)。Codex への共有は
  別経路(read-only bridge)が担う。背景: [[project_memory_store_divergence]]。

## 手続き（Stop hook 発火時 / 「振り返って」時に一度だけ）

### 1. 補正 reconcile — 先にやる（確認なし）

今セッションで**注入されたメモリに依拠して動いた**箇所を振り返り、その主張が**現実と矛盾して
いた**もの(file:line がずれていた / フラグ名・パス・API 形状が変わっていた / 手順が古い 等)を探す。

- 該当 `<name>.md` を**直接 修正 or 削除**する。メモリは point-in-time observation なので、
  矛盾は古さの証拠 — 補正をためらわない。**確認は取らない**(低リスク・高頻度の自己補正)。
- `MEMORY.md` のポインタ行も整合させる(削除したら行ごと削除、要旨が変わったらフック文を更新)。
- **readback 検証**: 保存後に該当ファイルと MEMORY.md の該当行を読み直し、意図通りか確認する。

### 2. 追加 capture — 2 段階ゲート

再発防止に値する**一般化可能な**学びを洗い出し、下の 2 種類に振り分ける。共通: 既に
code / git / 既存 hook / 既存メモリ が encode 済みは**除外**、既存近接ファイルは**新規作成でなく更新**、
書いたら必ず **readback 検証**(`feedback` / `project` は本文に `**Why:**` / `**How to apply:**`)。

- **(A) 基本的な学び** — ツールの落とし穴 / 手順 / 規約 / 既存事実の小さな訂正。
  → **確認せず即 append**。低リスク・高頻度なので **AskUserQuestion しない**(ユーザー方針 2026-06-27)。

- **(B) 「一度叩けば恒久キャッシュできる高レバレッジな外部情報」** — → **AskUserQuestion で聞く**。
  - 定義: ユーザー本人や外部 API / ソースを *インターフェース* として一度クエリし、その答えを
    保存しておけば、将来の**再発見・再質問コストが大きく下がる**タイプの事実。
  - 例: 何かの保管場所 / canonical title / ID・アカウント帰属 / API エンドポイント・認証経路 /
    「毎回ユーザーに聞き直している前提」など、*一度取得 → 恒久キャッシュ* で効くもの。
  - 兆候: 「これ毎回調べ直している」「ユーザーに一言聞けば一発で確定する」「外部を 1 回叩けば
    取れるのに都度やっている」と感じたら、それ。
  - 行動: AskUserQuestion で「この外部情報を取得して恒久保存していいか(＋必要ならその場で値を尋ねる
    ＝**ユーザーを API として叩く**)」を確認 → 承認なら取得・保存・readback。

- **(C) 人物別の「文体/トーン」の学び — ここには書かない。共有文体ガイドへ流す。**
  「〇〇さんにはタメ口」「この人には絵文字を控える」「簡潔な箇条書きが好まれる」など
  *特定の人へのメッセージの書き方* の学びは、**新規の `feedback_*_message_tone.md` を作らない**。
  それは Beeper CRM と Claude Code で共有する単一 SoT = 対象連絡先の Scrapbox メモの
  `[** CRM 文体ガイド]` セクションが持つ(docs/SHARED_STYLE_GUIDE.md)。ルート:
  - Beeper 送信の文脈で人間がドラフトを直した → `beeper-send` の `report-edit` で差分を CRM に
    報告すれば、高信頼ルールは CRM が自動で共有ガイドに materialize する(手作業のメモ化は不要)。
  - それ以外(会話からの気づき等)で明示ルールを足したい → 対象連絡先の `[** CRM 文体ガイド]`
    セクションに**人間ルール(素行)として** scrapbox-write で追記する(gateway の `GET /api/style`
    で確認できる)。CRM アプリ側の起草にもそのまま効く。
  - 例外: 特定個人でなく**文脈クラス共通**(例: 自治体・役所宛は簡潔・丁重)は従来どおり
    `feedback` メモで可([[feedback_business_email_style_ja]])。per-person だけを共有ガイドへ回す。
  既存の [[feedback_akiba_message_tone]] / [[feedback_yamaoka_message_tone]] は移行対象
  (共有ガイドへ集約後にメモ側は縮約)。

### 3. 圧縮 compact — 肥大化対策

`MEMORY.md` が ~200 行を超える / 同一トピックのポインタが重複してきたら、その場で畳む。

- 重複・上位互換に吸収されたファイルを**統合 or 削除**し、索引を縮める(記事の「索引は 200 行以下」)。
- topic セクション単位で要約を畳む。実体ファイルを消したら MEMORY.md の行も消す。

### 4. 学びが無ければ

「今回の学び: なし」とだけ述べて停止してよい(work turn でも durable な学びが無いのは普通)。

## 不変条件（破ってはいけない）

- 書き込み先は **Store A のみ**。迷ったら「harness が注入するのはどっちか」を実測して決める。
- **補正/削除・基本的な追加(2-A)は確認なし**で進める。**AskUserQuestion は「一度叩けば恒久
  キャッシュできる高レバレッジな外部情報」(2-B)にだけ**使う(過剰な確認はノイズ)。
- 全ての書き込みは **readback 検証**まで(world-model 注入と同じ思想: [[reference_verify_world_model_inject]])。
- このループは**セッション1回限り**(hook が marker で多重発火を防ぐ)。後から出た学びは
  「振り返って」で self-learn を再実行できる。

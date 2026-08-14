---
name: weekly-review
description: GTD 週次レビューを「既存自動化の検証層」として回す orchestrator。新規タスクを一からさばくのではなく、日次で稼働する自動化（daily-report / todo-gap-analysis / wip-crawl / todays-task / Reminders・Calendar 同期）の結果を検証・調整し、詰まったプロジェクトに次の一手を1つ生やし、来週をタイムボックスする。7ステップ・約80分（軽量版15分）。個人タイムで1人実施。トリガー: 「週次レビュー」「/weekly-review」「今週の振り返り」「weekly review」「GTD 週次」、および日曜夜/金曜夕方の recurring 実施。
---

# weekly-review

GTD の週次レビューを **既存自動化の検証層（verify & recalibrate layer）** として回す orchestrator。中身は既存 skill の合成で、新規ロジックは足さない。

## 実行モードの安全境界

- **Codex Scheduled・launchd・無人実行**: 下記A〜Fはすべて読み取りと提案だけ。Gmail archive、2分タスクの実行、Reminders追加/完了、Calendar作成/変更、ToDo・案件ページ変更、WIP処理、送信を無効化する。書込みはtakalog当日日付ページの「今週の確認」だけ。
- **対話実行**: 利用者がその場で対象mutationを明示承認した場合だけ、該当するA〜Fの変更手順へ進む。週次レビュー依頼だけを、外部送信・Calendar/Reminders変更・archive・ToDo変更の包括承認とみなさない。
- どちらも支払、申告、購入、公開、削除、権限・secret・security変更は別承認なしに行わない。

## 前提モデル（確定済み・2026-07-05 ユーザー決定）

この skill は下記の設計判断を前提にする。変えるときはユーザーに確認する。

- **週次＝検証層**: 新規の気がかりを一から処理し直すのではなく、日次で稼働する自動化（`daily-report` / ToDoカンバンのギャップ分析 / `wip-crawl` / Reminders・Calendar同期）の結果が実運用とずれていないかを検証し、必要な修正だけを入れる。
- **取り込み口（保存先ではなく、思い出す条件で分ける）**:
  - **Scrapbox（ToDoカンバン＋日付ページ）＝ 思考と管理の母艦**。手書きメモ・気がかり・案件・次にやること・いったん止めること・資料は全部ここ。
  - **Apple Reminders ＝ 時刻・場所で発火させたいものだけ**（GTD の Calendar / Tickler 相当）。内容の正本ではなく、Scrapbox 項目への一方向の発火装置。だから二重管理にならない。
- **いつかやる／いったん止める ＝ Scrapbox ⏹️ のページ群**。
- **個人タイム**: 1人で実施・報告なし。カレンダーの `[📅 GTD 週次レビュー]` で time box（金曜 17:00 or 日曜夜）。
- **エスカレーション込み**: `todo-gap-analysis` で相手待ちの停滞を検出したら、その場で催促・委任の**下書きまで**作る（自動送信はしない・人間承認必須）。
- **利用者向けの状態表記は日本語＋絵文字**:
  - `⬜` 次にやる
  - `⏳cc: <題名>` AIが作業中
  - `🚨` 本人の判断・入力待ち（`cc` を付けない）
  - `⏳` 相手・外部処理・仕組みを待っている（直下に日本語で「待っている相手／条件」を書く）
  - `⏹️` いったん止める／見送る
  - `☑️` 完了
  - `📅` 日時固定 / `⏰` 締切 / `📝` 資料
  既存ページに残る `⌛️` は一括置換しない。新しい表示に `todo` / `waiting_for` / `archive` などの英語status語を増やさない。

## 実行手順（7ステップ・約80分）

冒頭で日付を確定する（`todays-task` と同じ）：
```bash
python3 -c "import datetime;d=datetime.date.today();print(d.isoformat());print(f'{d.year}/{d.month}/{d.day}')"
```
`DATE_ISO`（例 `2026-07-05`）と `PAGE`（例 `2026/7/5`）を得る。

### A. 気がかりの一括処理（15分）— 唯一の新規取り込み
自動化が拾えない口頭約束・メール・チャット・手書きメモを人手で処理し、**気がかりを全部 Scrapbox に capture**する。発火が要るものだけ Reminders へ。
- 手書きメモ → Scrapbox（ToDoカンバン or 該当ページ）へ転記。
- Gmail 個人（`email` skill / himalaya）＋法人（`gws gmail`）の未読・スター → アクション化 or アーカイブ。
- Beeper 未返信・口約束（相手待ちとして拾う）。
- `[claude code WIP.icon]` の未処理（`wip-crawl` の残り）。
- Clarify（判断チャート）: 行動可能か → No なら ⏹️見送り / 📝資料。Yes なら次の物理的行動を1つ。2分以内=その場でやる。2分超=⏳相手待ち / 📅日時固定 / ⬜次にやる。複数行動の成果は案件ページにする。
- **発火が要るものだけ** `apple-reminders-geofence` / `apple-calendar` で Reminders・Calendar に置く（内容は Scrapbox に残す）。

### B. ToDoカンバン整理（20分）
- `todo-gap-analysis`（`/todo-gap`）を走らせ、ToDoカンバン＋各タスクページのギャップ（次の一手が無い / 期日超過 / フォロー漏れ）を検出。4時間毎自動更新の繰越判定を人が確認する。
- 絵文字の状態を今に合わせ、優先度・期限で並べ替える。終わった ⬜ は ☑️、止めるものは ⏹️ にする。

### C. WIP 確認とボトルネック処理（15分）— 心臓
- `wip-crawl` ダイジェスト / WIP アイコン / プロジェクトページを見て、**止まっているプロジェクト（次の一手が無い＝ボトルネック）を識別**。
- 各詰まりに **「次の具体的・物理的な行動」を1つ必ず生やす**（GTD の心臓。意図はエージェントが知らないのでここは人間の判断）。Scrapbox はテロメア（更新時刻）で止まったページが浮くので上から拾う。
- **エスカレーション**: 相手待ち(⏳) の停滞・返ってこない依頼には、催促・委任の**下書き**だけを作る（送信は人間承認。自動送信しない）。

### D. カレンダー・Reminders 同期（10分）
- `apple-calendar` で過去1週（やり残し → 次にやること）と未来2週（近づく予定の準備 → 次にやること）を確認。
- `apple-reminders-geofence` で来週タスクに位置情報を set、予約・締切を確認。Context×2分ルールの整備。

### E. 法人案件ハブ（15分）
- `plural-reality` の案件ページ（進行中ハブ）を1つずつ見て、状態を今に合わせる。living page は append-only にしない（打消線＋`[日付]追記`）。

### F. 来週プレビュー（10分）— タイムボックス
- 来週カレンダー・Reminders を見て、**動かせない箱**（睡眠・食事・ブリック/Zwift・構想日本出社）を先に置く。
- 残った隙間に最重要の「次にやること」を「終了条件タイトル」の箱で `apple-calendar` に配置。
- 置けなかったものは「今週はやらない」と明示的に確定（断る力）。

### G. 日報サマリと記録（10分）
- `tkgshn-private` 日付ページ（`daily-report`）から週内の学びを拾い、来週への引き継ぎ note を書く（Get Creative＋Reflect）。
- 実施ログ（何を検証し、どの詰まりに何の一手を生やしたか、エスカレーション下書きの有無）を `takalog` の日付ページ `<PAGE>` に短く追記する（`todays-task` と同じ LLM マーク＝薄字 `[( …]`・`--verbatim`・人間の行を保持）。ToDoカンバン／絵文字が SoT で、この記録は使い捨ての materialized view。

## 軽量版（回り出すまではこの3手・約15分）
80分が重い週はこれだけ。まず「毎週必ず回る」ことを優先し、続くのを確認してから 7 ステップ・自動化を足す。
1. 全ての気がかり（Scrapbox の未整理行 / Reminders「やること」/ Gmail / Beeper）を確認する。
2. Projects を上から見て、止まってるやつに次の一手を1つずつ生やす。
3. 来週の最重要3つをカレンダーに箱で置く。

## 呼び出す既存 skill（新規ロジックは足さない）
| ステップ | 委譲先 skill |
|---|---|
| A 気がかり | `email` / `beeper-send`（下書き）/ `apple-reminders-geofence` / `apple-calendar` |
| B カンバン整理 | `todo-gap-analysis` |
| C WIP・心臓 | `wip-crawl` / `beeper-send`・`email`（エスカレーション下書き）|
| D 同期 | `apple-calendar` / `apple-reminders-geofence` |
| E 法人ハブ | `scrapbox-context`（案件ページ取得）+ `save-to-scrapbox`（状態更新）|
| F タイムボックス | `apple-calendar` |
| G 記録 | `daily-report` / `todays-task`（記録の LLM マーク規約を流用）|

## 注意
- 出力は日本語。
- **タスクの実行・着手はしない**。この skill の責務は「検証・調整・次の一手を生やす・タイムボックス・記録」まで。
- エスカレーション（催促・委任）は**下書きまで**。送信は必ず人間承認（`beeper-send` / `email` の規約に従う）。
- SoT を増やさない・二重管理しない。内容は Scrapbox、発火だけ Reminders。
- 月次は同じ abstraction の上位層（週次結果の集約＝パターン抽出・改善提案）。将来 `monthly-review` として同型で作れる。

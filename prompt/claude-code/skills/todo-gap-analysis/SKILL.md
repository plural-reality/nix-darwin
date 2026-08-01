---
name: todo-gap-analysis
description: "Cosense/ScrapboxのToDoカンバンページとネストされた各タスクページを横断調査し、記載ステータスと実際の進捗のギャップ（抜け漏れ・期日超過・フォロー漏れ）を検出してレポートする。トリガー: /todo-gap, /todo-gap-analysis, 「抜け漏れ調べて」「カンバン更新して」「進捗チェック」"
---

# ToDo Gap Analysis — 抜け漏れ調査スキル

ToDoカンバン（Cosense/Scrapbox）上のステータスと、各ネストページの実際の進捗を突合し、差分・抜け漏れ・要フォロー事項を検出する。

## 入力

ユーザーが以下のいずれかを提供する:
1. Cosense context proxy の URL（例: `https://cosense-context-proxy.vercel.app/r/{hash}?p=ToDoカンバン&h=2`）
2. ページタイトル（例: 「ToDoカンバン」）— この場合、proxy hash は過去の会話や MEMORY.md から取得
3. 「抜け漏れ調べて」等の指示のみ — デフォルトで `ToDoカンバン` を対象とする

## 実行手順

### Phase 1: メインページ取得

cosense-fetch でカンバンページを取得する（WebFetch は Scrapbox 本文を壊すので使わない）。状態は4状態（canonical=plural-reality「ToDoカンバン」infobox）で判定する:
- `⬜` 未着手 = 今すぐ着手可（自分のボール／実作業中含む）
- `⏳` 進行中 = 相手ボール・返答待ち
- `⏹️` 保留 = 今は着手不可（将来ToDo化 / 依存待ち）
- `☑️` 完了

```
cosense-fetch "ToDoカンバン" -p plural-reality -h 2
```

### Phase 2: ネストページの並列取得

メインページ内の `[リンクされたページ]` を全て抽出し、**並列で** cosense-fetch する（WebFetch は使わない）。
各ページからは以下を抽出:
- 最終更新日
- 実際の進捗状況（⬜未着手=今すぐ着手可 / ⏳進行中=相手待ち / ⏹️保留=着手不可 / ☑️完了）
- ブロッカー・依存関係
- 期日（明示的なもの、または文脈から推定）
- 関係者（icon記法 `[人名.icon]` から抽出）
- ネクストアクション

### Phase 3: 外部データソースとの突合

以下を**並列で**実行し、各タスクの文脈を補強する:

1. **Pendant ライフログ**: 関係者名やプロジェクト名で検索
   ```bash
   python3 ~/.claude/scripts/pendant.py -f compact today
   python3 ~/.claude/scripts/pendant.py -f markdown search "{関係者名}"
   ```

2. **Google Calendar**: 直近の関連ミーティング
   ```
   gcal_list_events: 今日〜1週間後の予定を確認
   ```

3. **Scrapbox 関連ページ**: 2階層目のリンク先で重要そうなものを追加取得

### Phase 4: ギャップ検出

各タスクについて以下の観点で差分を判定:

| 検出ルール | 条件 | 深刻度 |
|---|---|---|
| **ステータス陳腐化** | カンバン上の記載と実際の進捗が乖離 | 中 |
| **期日超過** | 明示的/暗黙的な期日を過ぎている | 高 |
| **フォロー漏れ** | 「〜待ち」が1週間以上更新なし | 高 |
| **物件・契約系の時間切れリスク** | 不動産や契約で応答が遅れている | 高 |
| **トリガー日到来** | 「〜以降」「〜が終わったら」の前提条件が満たされた | 中 |
| **先方の抜け漏れ** | 相手のアクションに期日があり、結果報告がない | 中 |
| **未記録の進捗** | Pendant/カレンダーに活動があるがカンバンに反映されていない | 低 |

### Phase 5: レポート生成

以下のフォーマットで出力:

```
## {タスク名}

| | 内容 |
|---|---|
| **カンバン上** | {記載されているステータス} |
| **実際** | {調査で判明した実際の状態} |
| **差分** | {具体的なギャップ} |

**推奨アクション:**
- {優先度順のアクションリスト}
```

最後に **横断的リマインド事項** として:
- 同一人物にまとめて連絡すべき事項のグルーピング
- 期日超過で放置リスクのあるもの一覧
- 今日がトリガーになるもの一覧

### Phase 6: Scrapbox 書き戻し（オプション）

ユーザーが「scbに書いて」「Scrapboxにまとめて」と言った場合:
- `save-to-scrapbox` の canonical な配置規約に従う。独立したギャップ分析ページや、ToDoカンバン末尾のAI専用区画は作らない
- finding は exact な task/page-object 行の直下へ、理由・期限・次の一手として短く置く。詳細・履歴・証拠は canonical task page に置く
- 推測だけならstatusを変えず、不確実性を灰色の子行として残す。status変更は根拠を確認して既存ページをin-place renameする
- exact anchorが見つからないfindingと横断run summaryは当日のdaily pageへ置く
- 書き込み後、対象行とcanonical pageを再取得し、人間行がbyte単位で不変なことを確認する

## 注意事項

- 日付の相対表現（「来週」「年度明け」）は現在日付と突合して判定する
- `[人名.icon]` 記法から責任者を抽出し、フォロー先を明確にする
- 確度が低い案件（「あんまり高くなさそう」等の記述）はカンバンへの反映を推奨する
- Pendant データはプライベート情報。レポートに含める場合は要約のみ

## 自律・局所書き戻しモード（`/todo-gap --autonomous`）

headless 実行でも ToDoカンバンを横断レポート置場にしない。`save-to-scrapbox` の構造化index規約に従い、各findingを対応するtaskへ局所反映する。

### 前提: SID 自己修復
最初に必ず SID を再生成する（静的 SID は定期失効し guest 落ちする）。run.sh が
`~/.claude/scripts/scrapbox-sid-refresh.sh` を呼んで `SCRAPBOX_SID` を注入済み。未検証なら
`cosense-fetch --me -p plural-reality` が `"name":"tkgshn"` を返すことを先に確認する。guest なら中断。

### 手順
1. Phase 1〜4 を実行し、findingを `{anchorTitle, evidence, childLines}` に正規化する。
2. ToDoカンバンとcanonical task pageを毎回ライブ取得する。
3. exact `[anchorTitle]` が1件だけ存在するfindingだけ、既存task行またはcanonical pageの対応命題へ局所反映する。
4. anchorなし・重複anchor・横断所見はToDoへ書かず、当日のdailyへrun summaryとして置く。
5. 書込前後で対象外の人間行を比較し、byte単位で不変でなければ中断する。
6. 書込後に再取得し、重複findingがなく、AI行が `[( …]` のまま、taskとの親子関係が読めることを確認する。

### 破壊防止
- 文体からAI行を推測しない。`[( …]`、agent icon、既知の実patchだけを対象にする。
- status変更はconfirmed evidenceがある場合だけ。推測なら既存statusを保つ。
- exact anchorを一意に解決できなければToDoを書き換えない。

export const meta = {
  name: 'todays-task-roundup',
  description: '指定日の個人・多元現実タスクを全データソースから並列収集',
  phases: [
    { title: '収集', detail: 'カレンダー/Scrapbox/Pendant/Gmail/メモリを並列スキャン' },
  ],
}

// 日付は args から注入（Workflow スクリプト内では Date が使えないため）。
// args.dateIso 例 "2026-06-01" / args.datePage 例 "2026/6/1"
const A = args || {}
const DATE = A.dateIso || ''
const PAGE = A.datePage || ''

const TASK_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    source: { type: 'string', description: 'このエージェントが調べたデータソース名' },
    reachable: { type: 'boolean', description: 'そのソースに実際にアクセスできたか' },
    tasks: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          title: { type: 'string', description: '何をするか（簡潔に）' },
          category: { type: 'string', enum: ['個人', '多元', '不明'] },
          due: { type: 'string', description: '期日や時刻（あれば。例 2026-06-01 14:00 / 期限切れ / なし）' },
          priority: { type: 'string', enum: ['high', 'medium', 'low'] },
          context: { type: 'string', description: '根拠・補足。可能なら根拠となった Scrapbox ページ名を明記（リンク化のため）' },
          status: { type: 'string', description: '進行中/未着手/完了済みの可能性/不明 など分かれば' },
        },
        required: ['title', 'category', 'priority', 'context'],
      },
    },
    notes: { type: 'string', description: 'アクセス不能・要確認・取りこぼしの可能性など' },
  },
  required: ['source', 'reachable', 'tasks', 'notes'],
}

phase('収集')

const calendarPrompt = `今日 ${DATE}（JST）の予定を Google Calendar から取得し、各イベントを「今日やらないといけないタスク/予定」として抽出してください。

手順:
1. ToolSearch で "select:mcp__claude_ai_Google_Calendar__list_calendars,mcp__claude_ai_Google_Calendar__list_events" を実行してスキーマを取得。
2. list_calendars でカレンダー一覧を取得。
3. 各（主要）カレンダーについて list_events を timeMin=${DATE}T00:00:00+09:00、timeMax=（${DATE} の翌日）T00:00:00+09:00 で取得。翌日日付は自分で計算すること。
4. 各イベントを TASK として出力。会議・打合せ・締切イベントは予定そのものがタスク。タイトルや参加者から「多元現実(plural-reality)の仕事」か「個人」かを推定して category を付ける。判別不能なら不明。時刻を due に入れる。

注意: gcalcli は壊れているので使わない。MCP ツールのみ。取得できなければ reachable=false にして notes に理由を書く。`

const pendantPrompt = `AIペンダント（Limitless）のライフログから、最近コミットした「やるべきこと/約束」を抽出してください。今日 ${DATE} 時点で未完のものが対象です。

手順（Bash で実行）:
1. /bin/bash -c 'python3 ~/.claude/scripts/pendant.py -f compact today'
2. 必要に応じて /bin/bash -c 'python3 ~/.claude/scripts/pendant.py -f markdown search "<関係者名/案件>" --limit 10'

出力された会話から、明確な「タスク（〜する/〜に連絡/〜を送る/〜を作る等）」だけを TASK として抽出。会話の内容から個人か多元現実(plural-reality)の仕事かを推定。雑談や単なる事実は除外。近接重複は1タスクに統合。音声認識の揺れ（多元現実/plural-reality/Flux/Sonar/OpenClaw/Claude Code/構想日本 等）は補正し、推定変換は notes に明記。
スクリプトが失敗したら reachable=false にして notes にエラー全文を書く。`

const scbPersonalPrompt = `Scrapbox の個人プロジェクト "tkgshn-private" から、今日 ${DATE} 時点で未完の個人タスクを抽出してください。

手順:
1. まずメモリ ~/.claude/projects/-Users-tkgshn/memory/reference_cosense_proxy.md を Read して、Scrapbox ページの正しい取得方法（cosense-fetch ヘルパー or curl→ファイル→Read）を確認。WebFetch は本文が壊れるので使わない。
2. 今日の日付ページ "${PAGE}" を取得（あれば予定・ToDo が書かれている）。
3. ToDo/タスク/やること系・⏳プレフィックスのページを Scrapbox 検索 API（https://scrapbox.io/api/pages/tkgshn-private/search/query?q=ToDo 等、SID は ~/.claude/settings.json の SCRAPBOX_SID）で探して取得。
4. 未完タスク（⏳=進行中/未消化チェックボックス）を TASK として抽出。context には**根拠となった Scrapbox ページ名を必ず明記**（後でリンク化するため）。category は基本 個人、多元現実の話題なら 多元。日付が過去で既消化の可能性が高いものは除外し notes に列挙。
取得手段が全滅したら reachable=false、notes に試したことと結果を書く。`

const scbPluralPrompt = `Scrapbox のチームプロジェクト "plural-reality" から、今日 ${DATE} 時点で未完の多元現実タスクを抽出してください。

手順:
1. メモリ ~/.claude/projects/-Users-tkgshn/memory/reference_cosense_proxy.md を Read して正しい取得方法を確認（cosense-fetch or curl→ファイル→Read、WebFetch 不可）。
2. 今日の日付ページ "${PAGE}" を取得。
3. ToDoカンバン / タスク / 案件 系ページを Scrapbox 検索 API（https://scrapbox.io/api/pages/plural-reality/search/query?q=ToDo 等、SID は ~/.claude/settings.json の SCRAPBOX_SID）で探して取得。canonical な「ToDoカンバン」ページのステータス絵文字規約（⬜未着手/⏹️停止/⏳進行中/☑️✅完了/❌却下、⌛️待ち/⚠️リスク）に従い、未完(⬜⏳⌛️⚠️)のみ抽出。完了・停止は除外。
4. context には**根拠となった Scrapbox ページ名を必ず明記**（後でリンク化するため）。期日超過は due に明記。category は基本 多元。
取得手段が全滅したら reachable=false、notes に詳細を書く。`

const gmailPrompt = `Gmail から、今日 ${DATE} 時点で「自分が返信・対応しないといけない」ものを抽出してください。

手順:
1. ToolSearch で "select:mcp__claude_ai_Gmail__search_threads" を実行。
2. 未読・要返信・最近のスレッドを検索（例: is:unread newer_than:14d / in:inbox newer_than:10d / 実在の人物ドメイン newer_than:30d）。
3. 明確にアクションが必要なもの（返信待ち・締切・依頼・支払い・契約等）だけを TASK として抽出。ニュースレター・宣伝・自動通知・配送/認証コード等は除外。
4. 差出人・件名から個人か多元現実(plural-reality)の仕事かを推定。
取得できなければ reachable=false、notes に理由。`

const memoryPrompt = `ローカルのエージェントメモリから、今日 ${DATE} 時点でまだ open な「継続案件・締切付き obligation」を抽出してください。メモリは ~/.claude/projects/-Users-tkgshn/memory/ 配下。

手順:
1. ~/.claude/projects/-Users-tkgshn/memory/MEMORY.md を Read（全文。truncate されている可能性があるので必ず全部読む）。
2. 関連トピックファイル（project_*.md 等で締切や残タスクを含むもの）を Read。
3. メモリに書かれた残タスク（[ ] チェックボックス、「残タスク」「要確認」「期限」記述）を TASK として抽出。
4. 重要: メモリは過去に書かれたもの。今日は ${DATE}。期日が過ぎたものは status に「期限超過・要現況確認」と明記し due に元の期日を書く。完了済みの可能性があるものはその旨を status に。
5. category は内容から 個人/多元 を判定（会社=多元現実の契約・課金・プロダクト・インフラは 多元）。
このエージェントは reachable=true（ローカルファイルは必ず読める）。`

const results = await parallel([
  () => agent(calendarPrompt, { label: 'calendar', agentType: 'general-purpose', schema: TASK_SCHEMA }),
  () => agent(pendantPrompt, { label: 'pendant', agentType: 'general-purpose', schema: TASK_SCHEMA }),
  () => agent(scbPersonalPrompt, { label: 'scrapbox:tkgshn-private', agentType: 'general-purpose', schema: TASK_SCHEMA }),
  () => agent(scbPluralPrompt, { label: 'scrapbox:plural-reality', agentType: 'general-purpose', schema: TASK_SCHEMA }),
  () => agent(gmailPrompt, { label: 'gmail', agentType: 'general-purpose', schema: TASK_SCHEMA }),
  () => agent(memoryPrompt, { label: 'memory-residual', agentType: 'general-purpose', schema: TASK_SCHEMA }),
])

return results.filter(Boolean)

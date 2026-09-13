@[agent-policy]

## Codex Runtime Compatibility

- Prefer built-in Codex `explorer` and `worker` subagents for parallelizable work. Do not create role names unless they encode a real boundary.
- Codex has no SessionStart auto-injection for Claude memory. To use the canonical Claude memory, read `~/.claude/projects/-Users-tkgshn/memory/MEMORY.md` first, then open only the relevant topic file.

## Scrapbox Writes

- Scrapboxへ書く前に、毎回`save-to-scrapbox`と`scrapbox-context` skillを読む。過去ログや一般的なMarkdown知識で書式を推測しない。
- 書込窓口はNix管理の`cosense-fetch -r` / `scrapbox-write` / `scrapbox-rename`だけとし、`save-to-scrapbox`を配置・GTD構造・LLM markingのcanonical contractとして扱う。
- `ToDoカンバン`と`プロジェクト看板`はcurated indexである。個別の契約をここへ複製せず、shared CLIのfail-closed guardを通す。

@[unix-principal]
@[engineering]
@[ponytail]
@[context-compression]
@[local-installation]
@[shell-environment]
@[architectual-decision]

## 日常の意思決定を対話で記録する

- 本人が日常・仕事・技術の選択や方針を相談する、迷う、変更する、または理由が不明な決定を述べたときは、本人がADRや質問を指定しなくても、Codex側で記録に必要な要素を点検する。ADRは一つの決定を単位にし、一回の会話や全メモを一律にADR化しない。
- 会話と許可範囲の出典から、決めたいこと、背景・きっかけ、選択肢（現状維持を含む）、重視する基準、選択と理由、引き受ける不都合、見直す条件を拾う。既に分かることは聞き直さない。全欄を埋めるための質問はせず、判断や後日の理解に重要な欠けだけを質問する。
- 重要な欠けがあれば、結論や確定記録を作る前に、本人に一〜二問ずつ具体的に尋ねる。特に本人の選択理由・優先順位・許容範囲をもっともらしい推測で補わない。使える場合はAsk Question系の質問toolを使い、各toolの利用条件に従う。使えない場合は本文で短く質問する。回答が来るまでは不足に依存する決定を確定せず、独立して進められる調査や整理を進める。
- 観察・感想・問い・提案・決定・実施後の帰結を区別する。本人が決定済みと明言した選択は尊重し、理由が不足する場合だけ補足を尋ねる。迷っている発言、AIの提案、前向きな応答、沈黙を採択とみなさない。当時出た選択肢とCodexが追加した案も分ける。
- 判断がまとまったら、決めたこと／背景／考えた選択肢／選んだ理由／不都合・残る懸念／見直す条件／状態・日付・元の会話を、必要な項目だけ短くまとめる。未決なら検討中として残る問いを示す。予想する効果と実施後に確認した結果、文章確認と方針採択と実行完了を混同しない。
- 質問しない・今は決めないという本人の意向を尊重し、不足は未確認として残す。単純な事実確認・翻訳・機械的編集、十分な根拠のある判断、既に許可された通常作業をADRのために止めない。依頼が外部操作や設定変更を伴う場合、その既存の権限境界は保つ。
- 記録案は会話内に提示する。Scrapbox等への保存・既存記録の変更は、その対象への書込が依頼で許可されている場合だけ専用skillを使う。質問やADR作成自体を、新しい保存・送信・公開の許可にしない。


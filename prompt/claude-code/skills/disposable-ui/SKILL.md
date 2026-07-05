---
name: disposable-ui
description: >
  使い捨ての単発UIをローカルに立てて人間から1回だけ回答を回収する治具。AskUserQuestion で
  収まらない「非自明な確認・選択・レビュー」を、自己完結HTML(フォーム/レビューページ/選択肢)として
  組み、単発回収サーバ askpage_server.py で配信する。回答は transport 非依存に emit する
  (ローカル自動回収 / リモート持続 / clipboard フォールバックの3経路が同一HTMLで縮退)。
  トリガー: 「ask-page」「使い捨てUIで聞いて」「レビューページで確認」「フォームで回収」
  「単発フォーム」「フラクタル要約で確認」、他スキルからの単発回収の委譲、および自走タスク中に
  要件が曖昧・人間にしか出来ない判断(バッチ判断/視覚照合/グルーピング/直接操作)に当たった時(HITL 決定点)。
  使い分け: 恒久的に残す状況整理・レビューは /review-page、選択肢2〜4個の即断は AskUserQuestion。
---

# disposable-ui — 使い捨て単発UIで人間から1回だけ回収する

## いつ使うか
- 確認・選択・レビューが AskUserQuestion の枠(短い選択肢)に収まらない。
- 但し `/review-page`(reviewable-html-workbench)ほど恒久資産化する必要はない=その場限りで捨ててよい。

**AskUserQuestion で足りない4条件**(どれか1つでも当てはまれば disposable-ui。出典=発端ページの実証):
1. **バッチ判断** — 多数の項目を一画面で一括処理する(1問ずつでは破綻する)。
2. **リッチな文脈が判断に要る** — 画像・アバター・会話履歴・差分など「根拠」を並べて視覚照合しないと判断できない。
3. **選択肢に落ちない構造的判断** — 同一/別のグルーピング、並べ替え・優先順位付け、キャンバス上の配置。
4. **直接操作が速い** — トグル・ドラッグ・スライダーの方がテキストより速く正確。

位置づけ: AskUserQuestion=**追認**(AIが選択肢を作り人間が選ぶ)/disposable-ui=**考えさせる**(判断に最適な操作と根拠を与えて、人間にしか出来ない判断を引き出す)。

> **これは "出力を描画する UI" ではなく "人間 → LLM へより良い入力を引き出す input-side UI"**。
> ゴールは under-informed decision の回避＝人間からの情報抽出の最大化。使い捨てるのは UI インスタンスだけで、
> 回答(answer)・生成した UI パターンは蓄積資産。上位契約は `~/Developer/reviewable-html-workbench/UNIFIED-HARNESS.md`(SoT)。
>
> **原則(HITL ループの界面)**: 労働者(エージェント)は経営者(tkgshn)の指示を、蓄積 context を解釈して自走・完遂する。
> 途中で**要件が曖昧・意思決定が必要な点**に当たったら、①その論点をドキュメント化し ②この disposable-ui で
> 経営者に意思決定を求め ③返ってきた決定で作り直す/続ける。disposable-ui はこの HITL ループを実体化する道具であって、
> 単なる確認フォームではない。曖昧な大タスクほど「勝手に作り切る」より「決定点を切り出して問う」方が正しい。

## 契約: 回答は transport 非依存に emit する(最重要)

ページは「決定 → 回答オブジェクト」の**純粋関数**に徹する。回答の**形**は固定、**出口(transport)**は環境に応じて縮退させる。
同一HTMLが submit 先URLの差し替えだけで両 backend に載る(=portability 契約)。

**回答 payload(固定形。persistent `submissions.payload` / ephemeral `--out` 共通)**:
```json
{ "schema_version": "1.1", "collected_at": "<iso>",
  "round": 1,
  "answers": { "…answer_schema準拠…": "…" },
  "ui_pattern": "<任意: 生成UIの識別子>",
  "ui_feedback": "<任意: このUIでは判断できない時の作り直し指示。あれば answers 未完でも有効な回答>" }
```
- `round` = このUIが何巡目か(エージェントが生成時に静的に焼き込む。初版=1)。
- `ui_feedback` = **UI再生成チャネル**(下記 HITL ループ §)。非空なら answers が部分的でも submit 成立。

**3つの transport(同一HTMLで縮退)**:

| # | 経路 | submit 先 | いつ |
|---|---|---|---|
| ① ローカル(既定) | `POST /submit` → `--out` JSON → 親が回収 → 破棄 | `/submit` | 自分がその場で判断 |
| ② リモート持続 | `POST /api/r/<token>/submit` → Supabase `submissions` | frame が `window.__COLLECT__.submitUrl` に注入 | 共有・外部レビュー・履歴 |
| ③ clipboard(フォールバック) | `navigator.clipboard` に copy-as-prompt → 人間がターミナルに貼る | なし | サーバ死・素のHTMLとして共有 |

canonical な emit スニペット(自己完結HTMLに**インライン**する。外部ファイル参照はしない=共有時に壊れる):

```js
// disposable-ui collect — transport 非依存 emit (POST → clipboard フォールバック)
const collect = ({ answers, uiPattern, uiFeedback, round }) => {
  const payload = {
    schema_version: "1.1",
    collected_at: new Date().toISOString(),
    round: round || 1,
    answers,
    ...(uiPattern ? { ui_pattern: uiPattern } : {}),
    ...(uiFeedback ? { ui_feedback: uiFeedback } : {}),
  };
  const text = JSON.stringify(payload, null, 2);
  const submitUrl = (window.__COLLECT__ && window.__COLLECT__.submitUrl) || "/submit";
  const asPrompt =
    "以下は disposable-ui の回答です。JSON をそのまま回収して続けてください:\n\n```json\n" + text + "\n```";
  const toClipboard = () =>
    navigator.clipboard.writeText(asPrompt).then(
      () => ({ ok: true, via: "clipboard" }),
      () => ({ ok: false, via: "clipboard", text: asPrompt }),
    );
  return fetch(submitUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: text,
  }).then(
    (res) => (res.ok ? { ok: true, via: "post" } : toClipboard()),
    () => toClipboard(),
  );
};
```

- `via: "post"` → 「回収済」画面。`via: "clipboard"` → 「クリップボードに入れた・ターミナルに貼って」画面。
  `ok:false`(clipboard も不可) → コピー用 textarea を出して手選択させる。
- 送信ボタンとは別に、常設の「回答をコピー」ボタン(clipboard 直行)を置く=記事の "always end with an export" 規約。素の HTML として共有された時の唯一の出口。

## 見た目とフラクタル要約(単一 canonical・対外/自分で共通)

乱立解消のため、ask-page は**独自の配色を持たない**。**単一トークン源＝`plural-reality-design-system`(ブランド・ダーク)**を消費し、
長い briefing は**フラクタル要約スライダー**(L1本質 → L5全文を1本のスライダーで連続的に切替)を標準形にする。
対外(persistent/review-page)・自分(ephemeral/local)の両 surface でこの1テーマ＋1フラクタル部品を共有する(=UNIFIED-HARNESS §5・2026-07-04 決定=Palantir 源泉 register-conditional)。内部ツールは **screen register**(ダークチャコール＋エメラルド緑)を消費する。

**canonical テーマトークン**(正本＝`plural-reality-design-system` の「単一トークン源」を全ページに inline。外部CSS参照はしない=共有時に壊れる。角丸は register 依存):
```css
:root{
  --bg:#0E0E10; --panel:#1C2127; --panel-2:#252A31; --border:#383E47;
  --fg:#FFFFFF; --muted:#D4D9DF; --accent:#00E599; --accent-ui:#00C868; --accent-fg:#000000;
  --radius:4px; --radius-panel:20px; --shadow:0 1px 0 rgba(255,255,255,.02), 0 8px 30px rgba(0,0,0,.45);
}
/* 印刷は plural-reality-design-system の @media print(白/黒/純モノクロ・緑なし)を併記 */
```

**フラクタル要約**: `examples/fractal-ask.html` が参照実装。`LAYERS`(`{level,label,text}` の配列・markdown-lite)を
**ページに静的同梱**(閲覧時LLM呼び出し無し)し、スティッキーなスライダー＋ticksクリック＋←/→キーで深さを切替。
深さ変更時のスクロール位置保持・クロスフェードは `fractal-reader` と同一機構。briefing が長い時ほど効く
(概要で全体を掴ませ、必要な人だけ深く読ませる=Ask Question の情報抽出最大化に一致)。

## 質問パターン(選択肢＋自然言語・native AskUserQuestion 準拠)

選択肢だけに閉じない。**各設問は「選択肢(quick-pick) ＋ 第一級の自由記述(自然言語)」の両方**を持つ。
Claude 純正 AskUserQuestion の "Other" と同じで、**選択肢に無ければ自由記述だけで回答が成立する**(選択肢は必須にしない)。

**選択タイプは native に倣って2つ**(純正の `multiSelect` に対応):
- **単一選択**(`multiSelect:false`) = `<input type="radio">`(同一 `name`)。回答は `{ choice: <値|null>, text }`。
- **複数選択**(`multiSelect:true`) = `<input type="checkbox">`(同一 `name`)。回答は `{ choices: [<値>...], text }`。
- どちらも自由記述 `text` を併設し、選択肢に無ければ `text` だけで回答成立(choice/choices を必須にしない)。

- `answers` は設問ID→上記の形の map にする(例 `{ "priority": {choice,text}, "features": {choices,text}, "comment": "<全体自由記述>" }`)。単純な単一自由記述設問は `text` だけの文字列でよい。
- 自由記述欄は「補足(任意)」ではなく「選択肢に無ければ自然言語で回答」と明示する(格下げしない)。
- バリデーション: 各設問が `choice`(単一) か 1つ以上の `choices`(複数) か `text` を持てば回答済み。選択肢入力を `required` にしない。
- 収集ヘルパ(radio/checkbox を自動判別・`examples/fractal-ask.html` の `readAnswers()` が参照実装):
```js
const q = (name, noteKey) => {
  const inputs = [...document.querySelectorAll(`input[name="${name}"]`)];
  const multi = inputs.some((el) => el.type === "checkbox");
  const chosen = inputs.filter((el) => el.checked).map((el) => el.value);
  const text = (new FormData(form).get(noteKey) || "").toString().trim();
  return multi ? { choices: chosen, text } : { choice: chosen[0] || null, text };
};
// 回答済み判定: a.choice || (a.choices && a.choices.length) || a.text
```
- **選び方の指針(native と同じ)**: 相互排他で1つだけ選ばせるなら単一選択、当てはまるものを複数選ばせるなら複数選択。判断が割れる時は単一＋自由記述で足りることが多い。
- **ページ内コピーの書式は `japanese-tech-writing`/content 規範に従う**(2026-07-05 ユーザー決定): 装飾的な番号マーカー(壱/弐・丸数字・■▼)を設問見出しに付けない。見出しは内容を特定する単一の句にし、日本語見出しにダッシュ(—/──)を使わない。

## パターンカタログ（HTMLの良さを最大化する6つ）

disposable-ui は単なるフォームではない。**説明する代わりに実物を描画し、指して・比べて・選ばせて決めてもらう**のが HTML の強み。用途で下記を組み合わせる（どれも同じ `collect()` と canonical テーマを共有）。

| パターン | いつ使う | 参照実装 | `answers` の形 |
|---|---|---|---|
| **質問（選択肢＋自由記述）** | 相互排他/複数の選択＋自然言語で決めさせる | `examples/fractal-ask.html` | `{ qid: {choice|choices, text}, ... }` |
| **フラクタル要約** | 長い briefing を段階開示（L1本質→L5全文） | `examples/fractal-ask.html` の `LAYERS` | 入力なし（読ませて情報抽出を最大化） |
| **要素アノテーション** | 実物（資料/デザイン/差分）を描画し**任意の箇所を指して**コメント | `examples/annotate.html` | `{ annotations:[{n,locator,snippet,comment}], overall }` |
| **バリアント比較** | 候補（フォント/配色/レイアウト）を**並べて1つ選ばせる** | font-trial 型（下記） | `{ pick: {choice, text} }` |
| **バッチ・トリアージ** | 多数項目の一括判断（承認/却下/同一・別/バケツ分け）。各行に**根拠**（アバター/会話履歴/差分）を並置 | beeper crm 同名マージUI型（下記） | `{ items: [{id, verdict}], text }` |
| **直接操作** | ドラッグ並べ替え・スライダー/トグル調整。**live preview＋最終状態を export** | blog "custom editing interfaces" 型 | `{ order: [id…] }` / `{ params: {k:v} }` |

## 要素アノテーション（⌘/Ctrl+クリック・実物を指す）

**最も HTML らしい HITL**。レビュー対象を説明でなく**実物として描画**し、人間が任意の要素を ⌘/Ctrl＋クリックして、その箇所にピン＋コメントを付ける。「どこが」を言語で特定させる負荷をゼロにする（今セッションで資料3種のレビューに使い実証）。

- canonical エンジン = `examples/annotate.html` の `mountAnnotator(rootSel)`。**再利用可能・自己完結**。任意の root（例 `#stage`）に mount すると、その配下の要素が ⌘/Ctrl+クリックで注釈対象になる。
- 使い方: 注釈対象を `<div id="stage"><div class="doc" data-doc="名前">…実物…</div></div>` に描画するだけ。`data-doc` を付けると locator に文書名が入る。locator は「文書名 › 直近の見出し › スニペット」で自動生成。
- 回答: `answers.annotations = [{ n, locator, snippet, comment }]`（＋全体 `overall`）。ピンは scroll/resize 追従、リストから削除可。`ui_pattern: "element-annotation"`。
- **実物は自分のスタイルで描画してよい**（light な印刷資料でも可）。ツール chrome は canonical ダーク、注釈対象は対象自身の見た目。両者は分離する。

## バリアント比較（候補を並べて選ばせる）

フォント・配色・レイアウトなど「見ないと決められない」ものは、**同じ内容を候補ごとに live 描画**して並べ、単一選択＋自由記述で選ばせる（font-trial で数字フォントを選定し実証）。各候補は `<label>` にラジオを内包し、`:has(input:checked)` で選択を強調。回答は質問パターンと同じ `{choice, text}`。「太字が野暮ったい」等の主観は、候補を実際に見せれば一発で決まる。

## バッチ・トリアージと直接操作（判断の摩擦を消す2つ）

- **バッチ・トリアージ**: 項目ごとに1問ずつ聞かず、全項目を1画面のカード/行にし、各項目に verdict トグル（同一/別・承認/却下・Now/Next/Later）を付ける。**判断根拠（アバター・会話履歴・差分）を項目の横に描画する**のが本体 — 根拠を見て判断が変わるのが実証済みの価値（beeper crm 同名マージUI）。既定値はエージェントの推定で pre-fill し、人間は例外だけ直す。
- **直接操作**: 並べ替えはドラッグ（HTML Drag&Drop か上下ボタンで十分）、連続値はスライダー＋live preview。**必ず export で終わる**（blog 規約）— 最終状態を `answers` に落として `collect()` に渡す。途中操作は捨て、結果だけ持ち帰る。

## HITL ループ（決定点プロトコル）

自走タスクの途中で**要件が曖昧・人間にしか出来ない判断**に当たった時の運用。UI は使い捨てだが、ループ自体は反復する。

**1巡 = ①集約 → ②ページ化 → ③配信 → ④回収 → ⑤実行 → ⑥破棄**（発端ページの骨子そのまま）:
1. 判断に必要なデータ（根拠・選択肢・トレードオフ）をエージェントが集約する。
2. **決定点ページ**を生成する。これが「論点のドキュメント化」の実体 — 別途 Markdown を書かない。構成は:
   文脈=フラクタル要約 `LAYERS`（L1「何を決めたいか」→L5 全経緯）/ 選択肢=質問パターン or バリアント比較（**推奨を `data-reco` で明示**、各選択肢に帰結を `.d` で併記）/ 常設の「UIへの注文」欄。
3. ローカル配信し実機 Chrome で開く（background 起動、`--out` を監視）。
4. 回収。**回答待ちの間、その決定に依存しない独立作業は止めずに進める。**
5. 決定に沿って実行・作り直す。決定は消さない — repo 作業なら `TASK.md`/`PLAN.md`/PR body に、プロジェクト知識なら Scrapbox の案件ページに1行で記録する（persistent 経路なら `submissions` に自動で残る）。
6. UI インスタンスは破棄する。answer と ui_pattern は資産として残る。

**UI再生成ループ（`ui_feedback`）**: 初版UIが判断に適さないことは正常系（beeper crm 実例: 人物番号ベース→「アイコン＋会話履歴を並べて」→作り直したら判断が変わった）。全ページに常設の「このUIへの注文」欄を置き、非空で submit されたら **answers が部分的でもそれを作り直し指示として受理**し、`round+1` を焼き込んだ新HTMLを生成して再配信する。部分 answers は次版に pre-fill して持ち越す。

**期限切れ・未回答の扱い**: `expired`（かつ clipboard 貼り戻しも無し）は「未回答」。**決定が要る枝は推測で進めない** — その枝を保留して独立作業を続け、turn 終了時に決定点ページの残存(HTML パス)と論点を報告する。安全で可逆な既定値が明確にある場合のみ `ponytail:` マーカー付きで既定値で進め、事後報告する。

## ローカル配信(ephemeral・既定)

`scripts/askpage_server.py` は指定HTMLを1枚だけ配信し、`POST /submit` を1回受けたら
その JSON body を `--out` へ書き出してサーバごと消滅する。状態もコンテンツ改変も持たない。

```
python3 scripts/askpage_server.py --html <page.html> --out <answer.json> [--port 8799] [--ttl 540]
# → http://127.0.0.1:<port>/ で1枚配信。ブラウザで回答すると POST /submit。
# → 回答を --out に書いて自死。標準出力に collected / expired を出す。
```

- `--ttl`(既定540s): Bash background の10分timeoutより先に自死し「期限切れ」を親へ明示する。長時間フォーム不可(上限=この秒数)。
- ブラウザは実機Chromeで開く(既存のブラウザ運用に従う)。
- **サーバが期限切れでも回答は失われない** — ③ clipboard フォールバックに縮退する(旧設計の「再起動して」は不要)。

## 共有配信(persistent・外部に渡す時)

回答を蓄積し、ログイン不要トークンURLで共有する時は既存の稼働中 backend
(`review.plural-reality.com` / Supabase `plural-reality-review`)に raw-html として publish する。
backend は稼働・E2E実証済み(UNIFIED-HARNESS.md §6)。**skill 側は endpoint を叩くだけ・backend は改変しない。**

```
# publish: 自己完結HTML を raw-html として上げてトークンURLを得る
curl -sS "$REVIEW_API_BASE/api/publish" -H 'content-type: application/json' \
  ${PUBLISH_SECRET:+-H "x-publish-secret: $PUBLISH_SECRET"} \
  -d "$(jq -n --arg h "$(cat page.html)" --arg s "<slug>" '{kind:"raw-html", html:$h, slug:$s}')"
# → {"path":"/?r=<token>"} 。共有URL = $REVIEW_API_BASE/?r=<token>
# 回答の read-back(append-only 台帳):
curl -sS "$REVIEW_API_BASE/api/r/<token>/submissions"
```

- frame(persistent SPA)は raw-html を sandbox iframe で描画し、body に `window.__COLLECT__.submitUrl = "/api/r/<token>/submit"` を注入する。
  body(このHTML)は上の `collect()` がそれを読むので、**ローカルと同一のHTMLがそのまま持続経路に載る**。
- 使い捨ての回答も `submissions` に残る=「治具は捨てるが answer・ui_pattern は育つ」(Q3)。

## 作り方
1. **回答スキーマ**(`answers` に何を入れるか)を先に決める。宣言するなら `answer_schema`(JSON Schema)として持つ(検証は任意)。
2. `examples/fractal-ask.html` を下敷きに、自己完結HTML(inline CSS/JS・外部依存なし・上の canonical ダークテーマ)を組む。長い briefing は `LAYERS` にフラクタル層を積む。上の `collect()` を**インライン**し、送信＋常設コピーボタンを繋ぐ。
3. ローカルなら `askpage_server.py` を background 起動しURLを渡す / 共有なら `/api/publish` に raw-html で上げてトークンURLを渡す。
4. 回答JSON(`--out` or `/api/r/<token>/submissions`)を読んで続ける(`expired` かつ clipboard 未使用なら未回答として扱う)。
5. `ui_feedback` が非空なら回答扱いにせず、指示どおり UI を作り直して `round+1` で再配信する(部分 answers は pre-fill で持ち越す)。

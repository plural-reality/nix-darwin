# Task graph・2看板・closure transaction

タスク・看板・完了状態を変更するときに読む。本文と通常書込は[SKILL.md](../SKILL.md)および[write-operations.md](write-operations.md)に従う。既存の状態意味を別のモデルへ置き換えない。

## GTDのcanonical contract

GTDは1つの巨大ページに集約しない。正本を増やさず、同じScrapbox graphを次の3種類のviewへ分ける。

- `ToDoカンバン`: 完了条件が明確で、実行可能な次アクションだけを置くcurated index。**階層はScrapbox本来の字下げで表す**（星の数は見た目の強調でしかなく、意味を持たせない）。行の形は3種類だけ:
  - `[** 名前]`（星2つ以上） = 升目の見出し。字下げが1段深い行はその中身。
  - 素のテキスト = その升目が何かを言う一言。見出しの直後に1行だけ置く。
  - `[ページ名]` = カード。直前の見出しに属する。素のテキストのタスクは書かない。

  現在の升目（2026-08-19 更新）:

  ```
  Inbox        分類が必要なもの
    Dependency 前のタスクが終わるまで着手できないもの
  Todo         いま自分で動かせるもの
    @5分・スマホ / @PC（10分 / 30分 / 1時間〜） / @家 / Someday
  Waiting for  何かしらに委譲しているもの
    Someone / System / AI
  Scheduled    時間で発火するもの
  Triggered    その場所に着いたら発火するもの
    コンビニ / 郵便 / ダイソー / @構想日本 / @音威子府
  ```

  - `Scheduled` の中の `今日` / `明日` / `今週` / `もっと先` は**升目として書かない**。カード名の先頭が `yyyy/mm/dd` なら表示側が日付から導出する（レーンにすると毎日手で動かす二重管理になる）。日付を持つカードは `⬜2026/08/28 …` の形に正規化する。
  - `Inbox` は分類前の置き場。完了条件を確定できるまで留め、確定したら該当の升目か個別pageへ送る。
- `プロジェクト看板`: 複数アクションを要する進行中の成果だけを置くcurated index。次アクションや進捗ログを複製しない。
- 個別task/project page: 完了条件、次の一手、blocker、期限、履歴、証拠のcanonical source。看板へ詳細を展開しない。

両看板は相互リンクする。タスクの詳細化は看板行を長くするのではなく、exact page objectのリンク先で行う。完了条件を確定できない気がかりや複数工程の成果は、ToDoへ残さず個別pageまたはプロジェクト看板へ送る。

看板は時系列ログではない。独立したCodex/Claude進捗ブロック、日次報告、横断レポートを置かない。agentの作業待ち行列は `Waiting for` > `AI` の中に置き、`[claude code WIP.icon]`はtrailing textなしの構造markerだけとし、agentの作業説明はcanonical task pageへ置く（`Agent Queue` という独立レーンは 2026-08-19 に `AI` へ統合した。待ち先がAIであることは `Waiting for` の一種であって別軸ではない）。

2看板を書き換える唯一の手順:

1. `cosense-fetch -r`で取得した`lines`から`.lines[].text`だけを順序どおりに抽出し、`JSON.stringify`相当のcompact JSON配列をSHA-256へ流す。例: `jq -cj '[.lines[].text]' raw.json | shasum -a 256 | cut -d ' ' -f1`。line object全体や末尾改行、`shasum`のファイル名欄を`--expect-sha256`へ含めない。
2. 人間行をbyte単位で保持した全体候補をローカル生成する。
3. `scrapbox-write --mode replace --verbatim --expect-sha256 <digest> --dry-run`で候補を固定する。
4. 同じimmutable bodyを`--dry-run`なしで一度だけ送る。`prepend` / `append`は禁止。
5. `cosense-fetch -r`で再取得し、dry-runのline arrayとの完全一致を確認する。

`scrapbox-write`はこの境界をfail closedで強制する。CAS不一致なら他者の変更を候補へ統合し、再取得からやり直す。

## ステータス記号（TODO）
チェックや進捗には絵文字を使う（`[ ]` `[x]` はリンク記法と衝突するので使わない）。
- `⬜` タスク / `⏳` 進行中 / `⏹️` 停止 / `☑️` 完了

## 完了は追記ではなく、task graph の状態遷移

`⬜` / `⏳` / `⏹️` / `⌛️` で始まる task page に「完了した」という本文を追記しただけでは完了ではない。タイトル、backlink、ToDoカンバンの index 行が古いまま残り、今回のように実作業とドキュメント状態が分離する。

完了証拠を確認したら、次を1つのclosure手順として扱う。これは複数ページを原子的に更新するAPIではない。途中失敗なら完了とせず、各面の実状態と残る変更を記録する。

1. canonical task page と `ToDoカンバン` のexact task objectをlive readbackし、両方の候補を用意してdry-runを通す。task本文は完了後の新タイトルを指定して描画するが、この段階では新タイトルへの書込・ページ作成をしない。2看板の相互リンクなど既存guardの前提も満たすことを確認し、失敗したらrename等の副作用を始めない。
2. `scrapbox-rename <project> "<旧status title>" "☑️<同じtitle>"`で既存ページをin-place renameする。新タイトルへの別ページ作成は禁止。rename後はtaskと看板を再取得し、更新されたtitle / backlinkを基準に候補を調整してCAS hashを再計算する。旧タイトル時点のhashを流用しない。
3. 新しい候補もdry-runした上で、canonical task page の stale な `next_action` / `現在の境界` / blocker を削除または完了事実へ置換し、証拠を関係する位置へ記録する。
4. `ToDoカンバン` の exact task 行を `☑️` へ揃え、直下の子行を `status:: done ／ completed:: YYYY/M/D ／ evidence:: ...` に置換する。古い `next_action` は残さない。
5. 両ページを再取得し、次の全 invariant を確認する。
   - task page の先頭行が `☑️`
   - ToDoカンバンに旧status titleが0件、新titleが1件
   - task直下が `status:: done` と `completed::` と検証済み evidence を持つ
   - stale な `next_action` / 再認証待ち / 未実行境界が残っていない

`scrapbox-write` は、open status title に先頭6行内の完了証拠を書こうとすると fail closed する。非closureの履歴引用だけは `--allow-open-task` で明示的に通せるが、そのフラグでtaskを完了扱いにしてはいけない。

**禁止:** open titleへの `--prepend` 成功と、その本文の再読込だけをもって「Scrapboxも更新済み」と主張すること。

---
name: daily-report
description: ターミナル(Claude Code / Codex)の1日の作業を Scrapbox の日付ページ(YYYY/M/D)に日報として記録する。案件ごとに個人(tkgshn-private)/チーム(plural-reality)へ仕分け、両方に活動があれば日付ページ同士を相互リンク、各作業に担当者アイコンと出典セッションハッシュ(`#xxxxxxxx`)を付ける。さらに Limitless ライフログ(実世界の会話・行動)を取り込み `[Limitlessライフログ]` ブロックに構造化する。トリガー:「日報」「日報書いて」「今日の作業まとめて」「日付ページに記録」「日付ページ更新」「ライフログ」「daily report」、および作業セッションの区切り・終わり。
---

# Daily Report — 日付ページへの作業ログ

その日ターミナルでやった作業を、Scrapbox の日付ページ（タイトル = `YYYY/M/D`）に「誰が・何を・どのセッションで」やったかが分かる形で追記する。日付ページを親に、担当者アイコンの下へその日の作業を**順次**足していく動的Wiki運用。

書き方の canonical な規約は [[save-to-scrapbox]]（`~/.claude/skills/save-to-scrapbox/SKILL.md`）。本スキルはその「日付ページ日報」への適用。書く前に [[scrapbox-context]] で関連ページを確認する。

## 大原則（運用ルール）

1. **案件ごとに記録先を分ける**
   - 個人/ツール作業（Claude Code・skill・Scrapbox基盤・Nix/home-manager・個人事 等）→ 個人の日付ページ `tkgshn-private`
   - 多元現実の作業（freee・会計・法人・契約・音威子府・構想日本・取引先 等）→ チームの日付ページ `plural-reality`
   - 仕分けは cwd ではなく**案件の中身**で判断する（同じ作業ディレクトリでも内容で分ける）
2. **両方に活動があった日は日付ページ同士を相互リンク**する
   - 多元現実側 → `[/tkgshn-private/YYYY/M/D]`、個人側 → `[/plural-reality/YYYY/M/D]`
3. **「誰がやったか」を担当者アイコンで示す**。自分（現在の Scrapbox ユーザー）なら `[tkgshn.icon]`。その**下に段落を下げて**内容を書く
4. **「どのセッションでやったか」を出典として各作業の末尾に付ける**
   - 表記は `` `#xxxxxxxx` `` ＝ Claude Code / Codex のセッションID先頭8桁を**インラインコード**（バッククォート）で。statusLine の `#hash` 表示と一致する
   - `#` を裸で書かない（Scrapbox でタグ化されるため）。必ずバッククォートで囲む
   - **セッションごとに内容が違うものは箇条書きを分ける**。同じトピックの複数セッションは1行にまとめ、ハッシュを複数並べる（`` `#aaaa` `#bbbb` ``）
5. **日付ページが無ければ作る**（後述「ページ作成」）。pin-diary 等のテンプレがあるプロジェクトは、人力で公式Webフロントエンドから作った時と同じ出力を再現する
6. **LLM(自分)が書いた本文は `[( …]` で灰色マーク**。アイコン・リンク・ハッシュ・前後日ナビは参照/出自なので濃いまま（`[( …]` の外）

## フォーマット

```
YYYY/M/D                                  ← ページタイトル（-t で渡す。日付そのもの）
 [tkgshn.icon] [claude code.icon]         ← 担当者アイコン＋起草エージェント（濃いまま）
  [( その作業の要約。関連ページは [ページ名] でリンクできる。] `#xxxxxxxx`
  [( 別セッションの別作業はこのように段落を分ける。] `#yyyyyyyy`
  [( 同トピックを複数セッションでやったらハッシュを並べる。] `#aaaaaaaa` `#bbbbbbbb`
  [( ↔ 個人側の同日ページ: [/tkgshn-private/YYYY/M/D]]   ← 両方に活動がある日だけ
```

- 担当者アイコン = 現在の Scrapbox ユーザー（`curl -s https://scrapbox.io/api/users/me -H "Cookie: connect.sid=$SCRAPBOX_SID"` の `name`）。`[<name>.icon]`
- 起草エージェント = Claude Code なら `[claude code.icon]`、Codex なら `[codex.icon]`
- 本文 `[( … ]` は1段下げ（アイコン行の下）。ハッシュは `]` の**外**に `` `#hash` ``
- 逆時系列: 同じ日に複数回書く場合、新しいブロックは title 直下（上）へ。理想は**1日1ブロックに集約**（同日の自分のブロックがあれば、そこへ新しい作業行を足す）

## ライフログ (Limitless) の取り込み

terminal 作業（誰が・何を）に加えて、実世界の活動（会話・打ち合わせ等）を Limitless ペンダントの文字起こしから取り込む。

- **取得**: `python3 ~/.claude/scripts/pendant.py export --since <YYYY-MM-DD> --source limitless` → `~/.claude/data/pendant-export/limitless/YYYY-MM-DD.jsonl`。各レコードの `unified.markdown` が文字起こし全文、`unified.start_time` が開始時刻、`unified.title` が要約。
  - 概要把握だけなら `pendant.py -f compact today --source limitless`。ただし markdown の `date`/`today` は要約タイトルのみで**全文は出ない**ので、全文は export した jsonl の `unified.markdown` を読む。
- **構造化**: 文字起こしから「やったこと／話したこと」をいくつかの項目にまとめる（生の全文は転記しない）。
- **仕分け**: ライフログも内容で振り分ける。多元現実の打ち合わせ → `plural-reality`、個人 → `tkgshn-private`。
- **配置・フォーマット**: terminal 作業ブロックの**直後**に置く。見出しは `[Limitlessライフログ]`（バッククォートでなくブラケットのリンク＝日次横断の集約ページになる。icon は付けない）。その下に1段下げて灰色 `[( …]` の箇条書き。各項目の末尾に**開始時刻を24時間表記**で `` `HH:MM` ``（`#hash` と同様バッククォート・`]` の外。`L` 等の接頭辞は付けない）。

```
 [Limitlessライフログ]
  [( その時間帯の会話/行動を構造化した要約。関連ページは [ページ名] でリンク可。] `11:23`
  [( 別の会話。] `00:33`
```

## 手順

### 1. 日付と前後日を出す
```bash
TODAY=$(date +%Y/%-m/%-d); PREV=$(date -j -v-1d +%Y/%-m/%-d); NEXT=$(date -j -v+1d +%Y/%-m/%-d)
```

### 2. 今日の全セッションを集約する
今日 mtime の jsonl を全プロジェクトから集め、各セッションの冒頭プロンプトと末尾 assistant メッセージで「何をやったか」を把握する。ファイル名（拡張子前）がセッションID、その**先頭8桁がハッシュ**。
```bash
python3 - <<'PY'
import json, glob, os, datetime
day = datetime.date.today().strftime("%Y-%m-%d")
def text(o, role):
    c = o.get("message",{}).get("content")
    if isinstance(c,str): return c
    return "".join(b.get("text","") for b in c if isinstance(b,dict) and b.get("type")=="text") if isinstance(c,list) else ""
for f in sorted(glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl")), key=os.path.getmtime):
    if datetime.datetime.fromtimestamp(os.path.getmtime(f)).strftime("%Y-%m-%d")!=day: continue
    lines=open(f).read().splitlines()
    if len(lines)<=10: continue          # skip aborted/empty
    sid=os.path.basename(f)[:8]          # ← session hash
    first=last=""
    for ln in lines:
        try: o=json.loads(ln)
        except: continue
        t=text(o,"")
        if o.get("type")=="user" and t.strip() and not t.lstrip().startswith("<") and not first: first=t
        if o.get("type")=="assistant" and t.strip(): last=t
    print(f"\n#{sid}  ({os.path.basename(os.path.dirname(f))})")
    print("  ▶ "+" ".join(first.split())[:160])
    print("  ⤷ "+" ".join(last.split())[:200])
PY
```
出てきた各セッションを **個人 / 多元現実 / 両方** に仕分け、内容が違うものは別の箇条書きにする（ハッシュは `#<先頭8桁>`）。

### 3. 各プロジェクトの日付ページを更新
記録先プロジェクトごとに、ページが無ければ作り、日報ブロックを title 直下に置く。`SCRAPBOX_SID` は env 設定済み。

**ページ存在チェック**
```bash
code(){ curl -s -o /dev/null -w '%{http_code}' "https://scrapbox.io/api/pages/$1/$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$2")/text" -H "Cookie: connect.sid=$SCRAPBOX_SID"; }
code plural-reality "$TODAY"   # 200=あり / 404=無し
```

**A. ページが既にある場合 → 日報ブロックを追記**
- インデント0のテンプレ行（pin-diary の `[** Habbit]` 等）が**無い**プロジェクト（plural-reality 等）:
  `scrapbox-write --prepend`（title 直下に挿入。`--append` は使わない）
- インデント0のテンプレ行が**ある**プロジェクト（tkgshn-private = pin-diary）:
  `scrapbox-write` は全行に半角スペース+1するためテンプレのインデント0を壊す。**verbatim patch でテンプレを完全保持**して書く（下記）。
  - 同日に既存の自分ブロックがある場合も、verbatim でブロックを作り直して**1日1ブロックに集約**する

**B. ページが無い場合 → 作成**（人力Web作成と同じ出力を再現）
- plural-reality（pin-diary 無し）: 素のページ + 前後日ナビ。`scrapbox-write` で日報ブロック + 空行 + `[$PREV]←→[$NEXT]` を replace
- tkgshn-private（pin-diary 相当のテンプレを再現）: verbatim patch で以下を書く
  ```
  YYYY/M/D
   [tkgshn.icon] [claude code.icon]
    [( …本日の作業…] `#xxxxxxxx`
  (空行)
  [** Habbit]
   30min: workout
   3times: [meditation]
  (空行)
  [** Task]
  (空行)
  [** Schedule]
  (空行)
  [** Notes]
  (空行)
  [PREV]←→[NEXT]
  ```

### scrapbox-write（通常の追記・新規）
各行に半角スペースを1つ足す（→ title の1段下にネストされる）。アイコン行は先頭0スペース、本文は1スペースで書く。ハッシュは `]` の後ろに `` `#hash` ``。**必ず `--dry-run` で確認**してから書く。
```bash
cat <<'BODY' | scrapbox-write -p plural-reality -t "$TODAY" --prepend --dry-run
[tkgshn.icon] [claude code.icon]
 [( 作業の要約。] `#xxxxxxxx`
 [( ↔ 個人側の同日ページ: [/tkgshn-private/__TODAY__]]
BODY
```
（`__TODAY__` 等は実値に置換。日本語・`[( ]`・`←→` を含むので heredoc かファイル経由で。エスケープ事故を避ける）

### verbatim patch（インデント完全保持・テンプレ保護）
`~/.local/share/scrapbox-write/_sbx_patch_verbatim.mjs` は行配列を**そのまま**書き込む（+1スペースなし）。pin-diary テンプレを1行も崩さずに日報ブロックだけ差し替えられる。spec を作って渡す:
```bash
SID="$SCRAPBOX_SID"
curl -s "https://scrapbox.io/api/pages/tkgshn-private/$(python3 -c 'import urllib.parse;print(urllib.parse.quote("'"$TODAY"'"))')" -H "Cookie: connect.sid=$SID" > /tmp/cur.json
python3 - <<'PY'
import json,os
title=os.environ["TODAY"]
cur=[l["text"] for l in json.load(open("/tmp/cur.json"))["lines"]]
# pin-diary テンプレの開始位置から下を完全保持
hidx=next((i for i,t in enumerate(cur) if t.strip()=="[** Habbit]"), len(cur))
block=open("/tmp/block.txt").read().rstrip("\n").split("\n")   # 日報ブロック(先頭1スペースのアイコン行〜)
new=[title]+block+([""]+cur[hidx:] if hidx<len(cur) else [])
json.dump({"project":"tkgshn-private","title":title,"lines":new}, open("/tmp/spec.json","w"), ensure_ascii=False)
PY
cd ~/.local/share/scrapbox-write
node --preserve-symlinks _sbx_patch_verbatim.mjs /tmp/spec.json --dry   # 確認
node --preserve-symlinks _sbx_patch_verbatim.mjs /tmp/spec.json         # 本番
```
（`/tmp/block.txt` は日報ブロックを exact インデントで: アイコン行=先頭1スペース、本文=2スペース）

他に `~/.local/share/scrapbox-write/_op.mjs replace-line <proj> <title> <oldLine> <newLine>` で1行だけ正確に差し替えも可能（既存行へのハッシュ追記など）。

### 4. 相互リンク
個人・多元現実の両方に活動があった日は、両ページの日報ブロック末尾に相手の同日ページへの行を入れる:
`[( ↔ 多元現実側の同日ページ: [/plural-reality/YYYY/M/D]]` / `[( ↔ 個人側の同日ページ: [/tkgshn-private/YYYY/M/D]]`

### 5. 検証
書いた後に `/api/pages/<proj>/<encoded-date>/text` を読み、アイコン・灰色マーク・`` `#hash` ``・テンプレ保持・相互リンクを目視する。書いたページ URL を報告する。

## 注意・ハマりどころ
- `scrapbox-write` は **append 禁止**（逆時系列に反する）。新規は `--prepend` か `replace`
- `scrapbox-write` の +1スペースで**インデント0行は作れない** → pin-diary テンプレ（`[** …]` がインデント0）の保持・再現には verbatim patch を使う
- ハッシュは必ずバッククォート `` `#xxxxxxxx` ``（裸の `#` はタグ化される）
- `date` は `%-m/%-d` でゼロ埋め無し（`2026/5/1`）。Scrapbox の Control+T と一致させ、リンクが割れないように
- 日付ページの**新規作成は孤児ページではない**（前後日ナビ＋相互リンクで graph に繋がる）。[[save-to-scrapbox]] の「新規ページは最後の手段」原則の例外として、日付ページ運用は許容される

## 関連
- [[save-to-scrapbox]] — Scrapbox 書き込みの canonical 規約（灰色マーク・逆時系列・アイコン）
- [[scrapbox-context]] — 書く前の関連ページ検索（読み取り）
- [[scrapbox-llm-marking]] — `[( …]` 薄表示の仕組み・auto-humanize

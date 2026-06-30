#!/usr/bin/env python3
"""daily-page.py の「人間記入を消さない」保証 + work[].links 描画 の self-check。
フレームワーク無し・assert のみ。壊れたら exit!=0。実行: python3 test_daily_page_preserve.py"""
import sys, os
sys.path.insert(0, os.path.expanduser("~/.claude/scripts"))
import importlib.util
spec = importlib.util.spec_from_file_location("dp", os.path.expanduser("~/.claude/scripts/daily-page.py"))
dp = importlib.util.module_from_spec(spec); spec.loader.exec_module(dp)

# --- 既存ページ: 人間記入が「危険地帯」(管理ブロック内)に置かれている ---
# 1) [claude code.icon] 直下に人間メモ  2) nav 行の下に人間メモ  3) [** Schedule] 内に人間メモ
existing = [
    "[tkgshn.icon]", "",
    "[** Habbit]", " 30min: workout", "",
    "[** Task]", " 牛乳を買う",                       # 人間が Task に記入
    "[** Schedule]", " 12:00~ 📅 既存の予定", " 人間が Schedule に足したメモ",  # 危険: Schedule内
    "[claude code.icon]", " [( 昨日の自動要約] `#deadbeef`", " 人間が work 直下に書いた行",  # 危険: work内
    "[** Notes]", " 人間のノート本文", "",
    "[2026/6/18]←→[2026/6/20]",
    " navの下に人間が書いた行",                          # 危険: nav の下(従来は消えていた)
]

curated = {
    "date": "2026-06-19", "project": "tkgshn-private", "template": "pin-diary", "icon": "tkgshn",
    "schedule": [{"time": "09:00", "allday": False, "summary": "新しい予定", "calendar": "Business"}],
    "work": [{"summary": "今日の作業", "hashes": ["aabbccdd"], "links": ["/plural-reality/書いたページ"]}],
    "crosslink": None,
}

out = dp.build_diary(curated, existing, "pin-diary")
body = "\n".join(out)
print("----- rendered -----"); print(body); print("--------------------")

# (要件1) 人間記入が全部生き残る
must_keep = [
    " 牛乳を買う",
    " 人間が Schedule に足したメモ",
    " 人間が work 直下に書いた行",
    " 人間のノート本文",
    " navの下に人間が書いた行",
]
for m in must_keep:
    assert m in out, f"FAIL: 人間記入が消えた -> {m!r}"

# 管理ブロックは再生成されている(昨日の自動要約は消え、今日のが入る)
assert " [( 昨日の自動要約] `#deadbeef`" not in out, "FAIL: 旧生成行が残っている(再生成されていない)"
assert any("今日の作業" in l and "#aabbccdd" in l for l in out), "FAIL: 今日の work が無い"
assert " 09:00~ 📅 新しい予定" in out, "FAIL: 今日の Schedule が無い"
# 旧 Schedule の生成行も再生成で消える
assert " 12:00~ 📅 既存の予定" not in out, "FAIL: 旧 Schedule 生成行が残存"

# (要件3) links がハッシュ行の「下の行・一段下げ(2スペース)」で描画される
hash_idx = next(i for i, l in enumerate(out) if "#aabbccdd" in l)
link_idx = next(i for i, l in enumerate(out) if "/plural-reality/書いたページ" in l)
assert link_idx == hash_idx + 1, f"FAIL: link はハッシュの直下でない (hash={hash_idx} link={link_idx})"
assert out[link_idx].startswith("  ["), f"FAIL: link が一段下げ(2スペース)でない -> {out[link_idx]!r}"
assert out[hash_idx].startswith(" [") and not out[hash_idx].startswith("  "), "FAIL: hash 行のインデントが想定外"

# (冪等性) もう一度同じ curated を、生成済みページに対して回しても安定
out2 = dp.build_diary(curated, out, "pin-diary")
assert out2 == out, "FAIL: 冪等でない(2回目で差分が出た)"

# (要件3 抽出) lifelog の scrapbox-write パーサ(オプション式 CLI: -t title / -p project)
spec2 = importlib.util.spec_from_file_location("ll", os.path.expanduser("~/.claude/scripts/lifelog.py"))
ll = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(ll)
T = ll._scrapbox_targets
assert T('cat body | scrapbox-write -t "新居で何を買うか" -p tkgshn-private --gray') == ["/tkgshn-private/新居で何を買うか"]
assert T('scrapbox-write --title "福知山案件" --project plural-reality < /tmp/b.txt') == ["/plural-reality/福知山案件"]
assert T('scrapbox-write -t "デフォルトproj"') == ["/plural-reality/デフォルトproj"], "-p 省略時は plural-reality"
assert T('scrapbox-write -t "2026/6/19" -p tkgshn-private') == [], "日付ページは除外"
assert T('scrapbox-write -t "テスト" -p tkgshn-private --dry-run') == [], "dry-run は書込でない→除外"
assert T('cat ~/.local/bin/scrapbox-write; echo "scrapbox-write 本体"') == [], "ツール自体の調査(-t無し)は除外"
assert T('cosense-fetch "あるページ" -p tkgshn-private') == [], "read(cosense-fetch)は対象外"
assert T('scrapbox-write -t "x" -p unknownproj') == [], "未知プロジェクトは除外"
# 1コマンド内に複数 write、後続コマンドの -p に汚染されないこと
assert T('scrapbox-write -t "A" -p takalog && scrapbox-write -t "B" -p tkgshn-private') \
    == ["/takalog/A", "/tkgshn-private/B"]
assert T('scrapbox-write -t "C" -p tkgshn-private && cosense-fetch "Z" -p plural-reality') \
    == ["/tkgshn-private/C"], "後続 cosense-fetch の -p に汚染されない"
assert T('for t in a b; do scrapbox-write -t "$t" -p plural-reality < x; done') == [], "未展開 shell 変数 $t は除外"
assert T('scrapbox-write -t "⏳社宅のインターネット導入" -p plural-reality') == ["/plural-reality/⏳社宅のインターネット導入"], "絵文字prefixの実タイトルは保持"
# 値が `-` 始まり(=CLI も欠落扱い)は title/proj として消費しない
assert T('scrapbox-write -t --mode -p tkgshn-private') == [], "-t の値が --mode(dash始まり)→消費せず title無し→除外"

# === Codex レビュー回帰テスト ===
# (R1) summary が backtick コードスパンで始まる生成行: mark_gray が行頭を `code` にするため
#      旧実装は foreign 誤判定→旧生成行が残り+新生成行追加で冪等崩壊(COUNT=3)した。
c_bt = {"date": "2026-06-19", "template": "pin-diary", "icon": "tkgshn", "schedule": [],
        "work": [{"summary": "`foo` を直した", "hashes": ["abcd"], "links": []}], "lifelog": []}
ex_bt = ["[claude code.icon]", " `foo` [( を直した] `#old`"]
o1 = dp.build_diary(c_bt, ex_bt, "pin-diary")
o2 = dp.build_diary(c_bt, o1, "pin-diary")
assert o1 == o2, "FAIL(R1): backtick先頭 summary で冪等でない"
assert sum(1 for l in o1 if "foo" in l) == 1, f"FAIL(R1): 生成行が蓄積している -> {[l for l in o1 if 'foo' in l]}"
assert "#old" not in "\n".join(o1), "FAIL(R1): 旧生成行(#old)が残存"

# (R2) 人間の本文に ←→ を含む行が nav 扱いされて消えないこと(nav は日付リンク形式のみ)
c_empty = {"date": "2026-06-19", "template": "pin-diary", "icon": "tkgshn", "schedule": [], "work": [], "lifelog": []}
ex_nav = ["[** Notes]", " 仕事←→生活のバランスのメモ", " その次の行"]
o_nav = dp.build_diary(c_empty, ex_nav, "pin-diary")
assert " 仕事←→生活のバランスのメモ" in o_nav, "FAIL(R2): ←→ を含む人間行が消えた"
assert " その次の行" in o_nav, "FAIL(R2): ←→行の後続が巻き込まれた"
assert sum(1 for l in o_nav if "←→" in l) == 2, "FAIL(R2): 人間の←→行 + 正規navの2本になるはず"

# (R3) 既存に管理ブロック([claude code.icon])が重複していても、再生成は1個に正規化し人間行は残す
ex_dup = ["[claude code.icon]", " [( 古い作業1] `#a`",
          "[claude code.icon]", " [( 古い作業2] `#b`", " 人間が2個目に書いたメモ"]
c_dup = {"date": "2026-06-19", "template": "pin-diary", "icon": "tkgshn", "schedule": [],
         "work": [{"summary": "新しい作業", "hashes": ["new"]}], "lifelog": []}
o_dup = dp.build_diary(c_dup, ex_dup, "pin-diary")
assert sum(1 for l in o_dup if l.strip() == "[claude code.icon]") == 1, "FAIL(R3): work見出しが重複したまま"
assert " 人間が2個目に書いたメモ" in o_dup, "FAIL(R3): 重複ブロック内の人間記入が消えた"
assert not any("古い作業" in l for l in o_dup), "FAIL(R3): 旧生成行が残存"
assert sum(1 for l in o_dup if "新しい作業" in l) == 1, "FAIL(R3): 新生成行が重複"

print("ALL PASS")

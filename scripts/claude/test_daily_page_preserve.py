#!/usr/bin/env python3
"""daily-page.py の「人間記入を消さない」保証 + work[].links 描画 の self-check。
フレームワーク無し・assert のみ。壊れたら exit!=0。実行: python3 test_daily_page_preserve.py"""
import sys, os, json, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import importlib.util
spec = importlib.util.spec_from_file_location("dp", os.path.join(HERE, "daily-page.py"))
dp = importlib.util.module_from_spec(spec); spec.loader.exec_module(dp)

# --- 既存ページ: 人間記入が「危険地帯」(管理ブロック内)に置かれている ---
# 1) [claude code.icon] 直下に人間メモ  2) nav 行の下に人間メモ  3) [** Schedule] 内に人間メモ
existing = [
    *dp.owned_block(["[tkgshn.icon]"]), "",
    "[** Habbit]", " 30min: workout", "",
    "[** Task]", " 牛乳を買う",                       # 人間が Task に記入
    *dp.owned_block(["[** Schedule]", " 12:00~ 📅 既存の予定"]), " 人間が Schedule に足したメモ",  # 危険: Schedule内
    *dp.owned_block(["[claude code.icon]", " [( 昨日の自動要約] `#deadbeef`"]), " 人間が work 直下に書いた行",  # 危険: work内
    "[** Notes]", " 人間のノート本文", "",
    *dp.owned_block(["[2026/6/18]←→[2026/6/20]"]),
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
spec2 = importlib.util.spec_from_file_location("ll", os.path.join(HERE, "lifelog.py"))
ll = importlib.util.module_from_spec(spec2); sys.modules[spec2.name] = ll; spec2.loader.exec_module(ll)
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

# 現行 Codex Desktop の正本(sessions/**/*.jsonl)から task を1件へ畳める。
codex_rows = [
    {"timestamp": "2026-06-19T00:00:00Z", "type": "session_meta",
     "payload": {"id": "019abcdef0-0000-0000-0000-000000000000", "cwd": "/work/sample"}},
    {"timestamp": "2026-06-19T01:02:00Z", "type": "event_msg",
     "payload": {"type": "user_message", "message": "日報をまとめて"}},
    {"timestamp": "2026-06-19T01:03:00Z", "type": "event_msg",
     "payload": {"type": "agent_message", "phase": "commentary", "message": "まだ処理中です"}},
    {"timestamp": "2026-06-19T01:04:00Z", "type": "event_msg",
     "payload": {"type": "agent_message", "phase": "final_answer", "message": "まとめました"}},
]
with tempfile.NamedTemporaryFile("w", suffix=".jsonl") as f:
    f.write("\n".join(json.dumps(row, ensure_ascii=False) for row in codex_rows)); f.flush()
    codex = ll._codex_session(f.name, "2026-06-19")
assert codex and codex["hash"] == "019abcde" and codex["project"] == "sample"
assert codex["prompt"] == "日報をまとめて" and codex["last"] == "まとめました"
assert codex["state"] == "完了"

# === Codex レビュー回帰テスト ===
# (R1) summary が backtick コードスパンで始まる生成行: mark_gray が行頭を `code` にするため
#      旧実装は foreign 誤判定→旧生成行が残り+新生成行追加で冪等崩壊(COUNT=3)した。
c_bt = {"date": "2026-06-19", "template": "pin-diary", "icon": "tkgshn", "schedule": [],
        "work": [{"summary": "`foo` を直した", "hashes": ["abcd"], "links": []}], "lifelog": []}
ex_bt = dp.owned_block(["[claude code.icon]", " `foo` [( を直した] `#old`"])
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
ex_dup = [*dp.owned_block(["[claude code.icon]", " [( 古い作業1] `#a`"]),
          *dp.owned_block(["[claude code.icon]", " [( 古い作業2] `#b`"]), " 人間が2個目に書いたメモ"]
c_dup = {"date": "2026-06-19", "template": "pin-diary", "icon": "tkgshn", "schedule": [],
         "work": [{"summary": "新しい作業", "hashes": ["new"]}], "lifelog": []}
o_dup = dp.build_diary(c_dup, ex_dup, "pin-diary")
assert sum(1 for l in o_dup if l.strip() == "[claude code.icon]") == 1, "FAIL(R3): work見出しが重複したまま"
assert " 人間が2個目に書いたメモ" in o_dup, "FAIL(R3): 重複ブロック内の人間記入が消えた"
assert not any("古い作業" in l for l in o_dup), "FAIL(R3): 旧生成行が残存"
assert sum(1 for l in o_dup if "新しい作業" in l) == 1, "FAIL(R3): 新生成行が重複"

# (R4) takalog の統合 activity view も管理ブロックだけを更新し、人間行を保持する。
c_log = {"date": "2026-06-19", "template": "activity-takalog", "icon": "tkgshn",
         "collection": [{"name": "Limitless", "state": "取得済み", "detail": "2件"}],
         "messages": [{"time": "12:00", "sent": True, "chat": "相談", "sender": "自分", "text": "確認します"}],
         "gmail": [{"time": "12:30", "direction": "受信", "peer": "相手", "subject": "件名", "id": "42"}],
         "weekly": ["取りこぼしを確認した"]}
ex_log = [*dp.owned_block(["[📧 Gmail]", " [( 古いメール] `#1`"]), " 人間がメール欄に書いた注記",
          "[** 独自メモ]", " 人間の本文", *dp.owned_block(["[2026/6/18]←→[2026/6/20]"])]
o_log = dp.build_diary(c_log, ex_log, "takalog")
assert " 人間がメール欄に書いた注記" in o_log, "FAIL(R4): 旧Gmail欄の人間注記が消えた"
assert " 人間の本文" in o_log, "FAIL(R4): 独自メモが消えた"
assert any("送信 / 相談" in line for line in o_log), "FAIL(R4): 日本語の送受信表記が無い"
assert any("今日のメール" in line for line in o_log), "FAIL(R4): Gmail見出しを日本語へ移行できていない"
assert dp.build_diary(c_log, o_log, "takalog") == o_log, "FAIL(R4): takalog が冪等でない"

# (R5) 灰色装飾を使った人間行でも、marker外なら所有権を推測せず保持する。
human_gray = " [( 人間が灰色で書いた注記]"
ex_gray = [*dp.owned_block(["[claude code.icon]", " [( 旧自動行]"]), human_gray]
assert human_gray in dp.build_diary(curated, ex_gray, "pin-diary"), "FAIL(R5): 人間の灰色行を削除した"

# (R6) marker無しlegacy・owned範囲内編集・改ざんmarkerはすべてfail closed。
for unsafe in (
    ["[claude code.icon]", " [( markerの無い旧自動行]"],
    [*dp.owned_block(["[claude code.icon]", " [( 自動行]"])[:2], " 人間の割込", " [( 自動行]"],
    ["[claude code.icon]", " [( 日報の自動記録: 99行 / sha256:" + "0" * 64 + "]", " x"],
):
    try:
        dp.build_diary(curated, unsafe, "pin-diary")
        raise AssertionError("FAIL(R6): unsafe管理ブロックを受理した")
    except RuntimeError:
        pass
legacy_exact = ["[claude code.icon]", dp.work_line(curated["work"][0]),
                *dp.link_lines(curated["work"][0]["links"])]
migrated = dp.build_diary(curated, legacy_exact, "pin-diary", True)
assert any("日報の自動記録" in line for line in migrated), "FAIL(R6): exact legacyをmarker移行できない"

# (R7) 管理sourceが空でもmarker外の人間行と元見出しを残す。
empty_work = [*dp.owned_block(["[claude code.icon]", " [( 古い自動行]"]), " 人間の作業メモ"]
kept_empty = dp.build_diary({**curated, "work": []}, empty_work, "pin-diary")
assert "[claude code.icon]" in kept_empty and " 人間の作業メモ" in kept_empty

# (R8) 既存の人間行はnormalize対象にしない。
human_alias = " シャンドレ不動前という原文を保持する"
kept_alias = dp.build_diary(curated, ["[** Notes]", human_alias], "pin-diary")
assert human_alias in kept_alias, "FAIL(R8): 人間行をnormalizeして改変した"

# (R9) 機微なactivity viewはtakalog以外へ出せない。
dp.validate_target("takalog", "activity-takalog")
try:
    dp.validate_target("plural-reality", "activity-takalog")
    raise AssertionError("FAIL(R9): activity-takalogの誤送信を受理した")
except RuntimeError:
    pass
try:
    dp.validate_target("takalog", "plain")
    raise AssertionError("FAIL(R9): unknown templateを受理した")
except RuntimeError:
    pass

print("ALL PASS")

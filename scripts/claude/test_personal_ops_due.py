#!/usr/bin/env python3
"""personal-ops-due.py の完了判定だけを検証する。network accessなし。"""
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("personal_ops_due", os.path.join(HERE, "personal-ops-due.py"))
due = importlib.util.module_from_spec(spec)
spec.loader.exec_module(due)

complete = ["[** 収集状況]", *[f" [( {name}: {'記録なし' if name == 'Beeper' else '取得済み'}]"
                                   for name in due.REQUIRED], "", "[** 独自メモ]", " 人間の本文"]
assert due.collection_state(complete) == "処理済み"
assert due.collection_state(complete[:-3]) == "処理済み"
assert due.collection_state(["[** 収集状況]", " [( Limitless: 一時的に取得できません]"]) == "要再確認"
assert due.collection_state(["[** Notes]", " 人間の本文"]) == "未処理"

false_positive = ["[** 収集状況]", " [( Apple Calendar: 取得済みではない]", *[
    f" [( {name}: 記録なし]" for name in due.REQUIRED[1:]]]
assert due.collection_state(false_positive) == "要再確認", "substringで取得済み扱いしてはいけない"
one_line = ["[** 収集状況]", " [( " + " / ".join(due.REQUIRED) + ": 記録なし]"]
assert due.collection_state(one_line) == "要再確認", "複数sourceを1行で満たしてはいけない"
duplicate = [*complete[:1 + len(due.REQUIRED)], " [( Gmail: 一時的に取得できません]"]
assert due.collection_state(duplicate) == "要再確認", "同じsourceの重複stateは拒否する"

print("ALL PASS")

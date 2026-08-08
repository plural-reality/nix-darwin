#!/usr/bin/env python3
"""limitless-takalog.py の純粋変換に対する最小 self-check。外部書込はしない。"""
import importlib.util
import contextlib
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("limitless_takalog", os.path.join(HERE, "limitless-takalog.py"))
lt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lt)

items = [
    {"id": "a", "start_time": "2026-08-02T11:01:00+09:00", "end_time": "2026-08-02T11:02:00+09:00",
     "markdown": "## 一つ目\n\n- Unknown: 本文A"},
    {"id": "b", "start_time": "2026-08-02T11:03:00+09:00", "end_time": "2026-08-02T11:04:00+09:00",
     "markdown": "## 二つ目\n\n- Unknown: 本文B"},
    {"id": "a", "start_time": "2026-08-02T11:01:00+09:00", "end_time": "2026-08-02T11:02:00+09:00",
     "markdown": "## 一つ目\n\n- Unknown: 本文A"},
    {"id": "c", "start_time": "2026-08-02T12:00:00+09:00", "end_time": "2026-08-02T12:01:00+09:00",
     "markdown": "## 三つ目\n\n- Unknown: 本文C"},
]

page_list = lt.pages(items, "2026-08-02")
assert len(page_list) == 2, "同一時間は1ページ、別時間は別ページになる"
assert sum(page["count"] for page in page_list) == 3, "重複IDを除いて全文が1回ずつ入る"
assert "本文A" in "\n".join(page_list[0]["body"]) and "本文B" in "\n".join(page_list[0]["body"])
assert page_list[0]["title"] == "Limitless 2026/8/2 11時"
assert lt._page_title("2026-08-02", 11, 0, 3) == "Limitless 2026/8/2 11時"
assert lt._page_title("2026-08-02", 11, 1, 3) == "Limitless 2026/8/2 11時 2"
assert lt.pages(items, "2026-08-02") == page_list, "同じ入力から常に同じページを作る"
assert lt.manifest(page_list, "2026-08-02")["pages"][0]["link"] == "/takalog/Limitless 2026/8/2 11時"

generated = page_list[0]["body"]
first = lt._merge(generated, None)
human = " 人間が追記した校正メモ"
second = lt._merge(generated, [*first, human])
assert second[-1] == human, "marker外の人間注釈を保持する"
assert lt._merge(generated, second) == second, "同じ入力は冪等"
assert lt._merge(generated, generated, True)[1:] == generated, "完全一致した旧本文だけ移行できる"

for unsafe in (
    generated,
    [first[0], " 人間が自動記録へ割り込んだ", *first[1:]],
    [" [( Limitlessの自動記録: 99行 / sha256:" + "0" * 64 + "]", " x"],
):
    try:
        lt._merge(generated, unsafe)
        raise AssertionError("unsafe archiveを受理した")
    except RuntimeError:
        pass

# 正常0件へ縮退した日でも、以前の全文ページを黙って残さない。
original_argv, original_stdin, original_archive_titles = sys.argv, sys.stdin, lt._archive_titles
captured = io.StringIO()
try:
    sys.argv = ["limitless-takalog.py", "write", "--date", "2026-08-02", "--allow-empty"]
    sys.stdin = io.StringIO("[]")
    lt._archive_titles = lambda _date: {"Limitless 2026/8/2 11時"}
    with contextlib.redirect_stdout(captured):
        try:
            lt.main()
            raise AssertionError("既存の全文ページをstaleとして拒否しなかった")
        except SystemExit as error:
            assert error.code == 1
finally:
    sys.argv, sys.stdin, lt._archive_titles = original_argv, original_stdin, original_archive_titles

assert json.loads(captured.getvalue())["stale_pages"] == ["Limitless 2026/8/2 11時"]

print("ALL PASS")

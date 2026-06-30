#!/usr/bin/env python3
"""PreToolUse guard: forbid `scrapbox-write --append`.

生きたページの新規記載は「上部 = prepend / 時系列再構成(新しい順)」が規約。
bottom-append は時系列が逆転し、過去の誤りも放置されるため禁止する。
規約: feedback_scrapbox_living_page_update_convention

Bash ツールで scrapbox-write を append モード(-a / --append / --mode append)で
呼ぼうとしたら exit 2 でブロックし、prepend / replace 再構成へ誘導する。
"""
import sys, json, re

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

if data.get("tool_name") != "Bash":
    sys.exit(0)

cmd = (data.get("tool_input") or {}).get("command", "") or ""
if "scrapbox-write" not in cmd:
    sys.exit(0)

is_append = bool(
    re.search(r'(?:^|\s)(?:-a|--append)(?:\s|$)', cmd)
    or re.search(r'--mode[ =]append', cmd)
)
if not is_append:
    sys.exit(0)

sys.stderr.write(
    "BLOCKED: `scrapbox-write --append` は禁止です。\n"
    "Scrapbox の生きたページは「新規記載=ページ上部(prepend)」が規約。"
    "bottom-append は時系列が逆転し過去の誤りも残るため使わない。\n"
    "\n"
    "代わりに:\n"
    "  - 短い追記 → `--prepend` (-P) でページ上部に入れる\n"
    "  - 大きめの更新 → `--mode replace`(または -V) で全体を時系列再構成(新しい順)。\n"
    "    AI記載は [( …] 灰色、過去の誤りは [- …] 打ち消し線+訂正注記。\n"
    "  - 書き込み後は必ず cosense-fetch -r で再フェッチし、上部配置/charsCount/原文保全を検証。\n"
    "規約: feedback_scrapbox_living_page_update_convention\n"
)
sys.exit(2)

"""claude-log-to-scb — shared helpers: message-text extraction + entity aliasing.

Single source of truth for (1) pulling clean text out of a claude.ai export
message (the top-level `text` field can hold a junk "not supported" placeholder
when the real answer lives in `content[].text` blocks) and (2) resolving entity
aliases to one canonical Scrapbox page title.
"""
import os
import re

_JUNK = "not supported on your current device"


def msg_text(m):
    """Clean text of one message. Prefer content 'text' blocks; fall back to the
    top-level text only when it is not the export's placeholder junk."""
    blocks = m.get("content")
    if isinstance(blocks, list):
        parts = [
            b.get("text", "")
            for b in blocks
            if isinstance(b, dict) and b.get("type") == "text"
        ]
        joined = "\n".join(p for p in parts if p and p.strip())
        if joined.strip():
            return joined.strip()
    t = m.get("text")
    if isinstance(t, str) and t.strip() and _JUNK not in t:
        return t.strip()
    return ""


# alias(lowercased) -> canonical Scrapbox page title. Seeds the design's
# [人物エイリアス] concept; extend as new aliases surface. Unknown names pass
# through unchanged.
ALIAS = {
    "青山": "Bluemo / Shutaro Aoyama",
    "青山周平": "Bluemo / Shutaro Aoyama",
    "aoyama": "Bluemo / Shutaro Aoyama",
    "shutaro aoyama": "Bluemo / Shutaro Aoyama",
    "bluemo": "Bluemo / Shutaro Aoyama",
    "多元現実": "多元現実",
    "合同会社多元現実": "多元現実",
    "plural reality": "多元現実",
    "plural-reality": "多元現実",
    "構想日本": "構想日本",
    "cartographer": "Cartographer",
    "倍速会議": "倍速会議",
    "sonar": "Sonar",
    "倍速アンケート": "倍速アンケート",
    "flux": "Flux",
    # heuristic person/entity seeds (high-confidence within this corpus; refine as needed)
    "blu3mo": "Bluemo / Shutaro Aoyama",
    "秋葉": "秋葉杏介",
    "秋葉さん": "秋葉杏介",
    "加藤さん": "加藤秀樹",
    "田中さん": "田中俊",
    "伊藤さん": "伊藤伸",
    "山岡": "山岡祐貴",
    "音威子府": "音威子府村",
    "倍速会議（cartographer）": "倍速会議",
}


# The user themselves — never an entity page about oneself. Filtered out of
# extracted `people` at canon() time (export attributes many name variants).
SELF = {
    "高木", "高木俊輔", "高木俊介", "高木舜介", "高木（taka）", "高木(taka)",
    "taka", "たかぎ", "たかぎしゅんすけ", "takagi", "takagi shunsuke",
    "shunsuke takagi", "tkgshn",
}


def canon(name):
    n = (name or "").strip()
    if not n:
        return ""
    low = n.lower()
    if low in SELF:
        return ""
    return ALIAS.get(low, n)


def esc(s):
    """Neutralize Scrapbox link/tag syntax in TRANSCRIBED text ([ ] -> ［ ］,
    # -> ＃) so user prompts / LLM summaries don't spawn ghost links/tags that
    pollute the graph (and so the server doesn't reject the page on invalid
    links). Intentional links ([project]/[person]/[⬜task]/hub/page-title) are
    emitted by the renderers OUTSIDE message text, so they are unaffected.

    Coerces non-str input: an LLM extraction element is occasionally a list
    (e.g. commitments [actor, action]) — join rather than crash the whole page."""
    if not isinstance(s, str):
        s = "" if s is None else (" ".join(map(str, s)) if isinstance(s, list) else str(s))
    return s.replace("[", "［").replace("]", "］").replace("#", "＃")


ARCHIVE_ROOT = os.path.expanduser("~/.claude/data/claude-export")


def latest_archive():
    """Path to the current conversations.json: the rolling live archive (poll.py)
    if present, else the newest dated manual export. Ignores non-date dirs."""
    live = os.path.join(ARCHIVE_ROOT, "live", "conversations.json")
    if os.path.isfile(live):
        return live
    if not os.path.isdir(ARCHIVE_ROOT):
        return None
    days = sorted(d for d in os.listdir(ARCHIVE_ROOT) if re.match(r"^\d{4}-\d{2}-\d{2}$", d))
    for d in reversed(days):
        cj = os.path.join(ARCHIVE_ROOT, d, "conversations.json")
        if os.path.isfile(cj):
            return cj
    return None

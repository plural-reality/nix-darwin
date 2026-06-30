#!/usr/bin/env python3
"""daily-page.py — 日報ページの決定的レンダリング＋Scrapbox書き込み。

役割分担: lifelog.py が収集、LLM(daily-report skill) が「分類＋要約」の判断だけ行い、
その curated JSON を本スクリプトに渡す。整形(pin-diaryテンプレ・Schedule記法・灰色マーク・
hashバッククォート・前後日ナビ・インデント)と書き込み(verbatim patch / 既存ページの管理ブロック
差し替え)は全部ここで決定的に行う。

stdin の curated JSON:
{
  "date": "2026-05-30", "project": "tkgshn-private", "template": "pin-diary"|"plain",
  "icon": "tkgshn",
  "schedule": [{"time":"09:00","allday":true,"summary":"Bike...","calendar":"ルーティーン"}],
  "lifelog":  [{"time":"11:23","summary":"...","links":["関連ページ名"]}],   // links は任意。本文の直下に一段下げて [被リンク] を出す
  "gmail":    [{"time":"09:12","from":"メルペイ","subject":"6月のご請求...","id":"53532"}],  // lifelog.py の gmail をそのまま渡す(本文は転記しない index)
  "work":     [{"summary":"...","hashes":["b80677fc","fdce32d9"],"links":["関連ページ名"]}],   // links は任意(同上)
  "crosslink": "/plural-reality/2026/5/30"   // or null
}
ページ = 順序付きブロック列としてマージする(block-merge)。
  管理ブロック(daily-report所有・毎回ソースから再生成/削除) = [** Schedule] / [Limitlessライフログ] /
    [claude code.icon] / [** やったこと](team) / 前後日ナビ / [📧 Gmail](takalog)。
  それ以外のブロックは既存ページから「位置ごと verbatim 保持」する =
    [** Habbit] / [** Task] / [** Notes] / [** メモ] + ユーザーが書いた独自セクション・自由記述。
  さらに管理ブロック内に人間が直接書いた行(見出し・灰色 [( …]・Schedule の📅行 以外の非空行)も
    再生成後に末尾へ残す = nav 行の下や [claude code.icon] 直下に書かれた人間記入も消さない。
  新規ページのみ人間記入用の空スキャフォールド(Habbit/Task/Notes or メモ)を生成する。
注意: fetch_lines は既存ページを safe="" で完全 URL-encode して取得し、取得失敗(非404)時は
  書き込みを中止する。これを怠ると「既存を新規と誤認 → 空テンプレで全体上書き」が起きる。

Usage:
  echo '<curated json>' | python3 daily-page.py render          # 本文を stdout に
  echo '<curated json>' | python3 daily-page.py write [--dry-run]  # 既存とマージして書き込み
Env: SCRAPBOX_SID
"""
from __future__ import annotations
import json, os, re, subprocess, sys
from datetime import date as date_cls, timedelta

HOME = os.path.expanduser("~")
SBX_DIR = os.path.join(HOME, ".local/share/scrapbox-write")
sys.path.insert(0, os.path.expanduser("~/.claude/scripts/lib"))
from normalize import normalize  # 表記ゆれ正規化(Scrapbox 書き込み境界)
VERBATIM = os.path.join(SBX_DIR, "_sbx_patch_verbatim.mjs")
HABBIT_DEFAULT = [" 30min: workout", " 3times: [meditation]"]

GMAIL_HEADER = "[📧 Gmail]"

# 日報ページのブロックモデル(canonical)。ページ = 順序付きブロック列。
#   order   = ブロックの正準順序。missing な管理ブロックを挿入する際のアンカー。
#             "~preamble" = 最初の見出し前の自由記述(常に先頭に残す)。
#   managed = daily-report が所有し、毎回ソースから「再生成 or 削除」するブロック key。
#             これ以外のブロック(Habbit/Task/Notes/メモ + ユーザー独自セクション)は
#             既存ページから verbatim で位置ごと保持する(=絶対に上書きしない)。
#   default = 新規ページのときだけ生成する人間記入用の空スキャフォールド。
# Gmail は機微情報なので pin-diary(tkgshn-private)に載せず takalog へ分離(build_gmail_takalog)。
DIARY = {
    "pin-diary": {
        "order": ["~preamble", "icon", "Habbit", "Task", "Schedule", "Limitless", "work", "Notes", "nav"],
        "managed": {"icon", "Schedule", "Limitless", "work", "nav"},
        "default": [("Habbit", HABBIT_DEFAULT), ("Task", []), ("Notes", [])],
    },
    "team": {
        "order": ["~preamble", "Schedule", "yatta", "memo", "nav"],
        "managed": {"Schedule", "yatta", "nav"},
        "default": [("memo", [])],
    },
}
KEY_HEADER = {"Habbit": "[** Habbit]", "Task": "[** Task]", "Notes": "[** Notes]", "memo": "[** メモ]"}
HEADER_KEY = {**{v: k for k, v in KEY_HEADER.items()},
              "[** やったこと]": "yatta", "[** Schedule]": "Schedule"}


def _d(s: str) -> date_cls:
    y, m, dd = (int(x) for x in s.split("-"))
    return date_cls(y, m, dd)


def _fmt(d: date_cls) -> str:
    return f"{d.year}/{d.month}/{d.day}"  # ゼロ埋め無し(Control+T と一致)


def nav_line(date_str: str) -> str:
    d = _d(date_str)
    return f"[{_fmt(d - timedelta(days=1))}]←→[{_fmt(d + timedelta(days=1))}]"


# ---------- 灰色マーク (LLM 行) ----------
# Scrapbox 装飾 [( …] の内側では backtick インラインコードが等幅表示にならず壊れる。
# よってコード span は装飾の外へ追い出し、プレーンな各区間だけを個別に [( ] で包む。
# 区間の前後空白は装飾の外側に残して元のスペーシングを保つ。リンク [Page] は装飾内に
# 残せる(=分割対象は backtick のみ)。
_CODE_SPAN = re.compile(r"(`[^`]+`)")
_TRIM = re.compile(r"^(\s*)(.*?)(\s*)$", re.S)


def mark_gray(text: str) -> str:
    def wrap(seg: str) -> str:
        lead, core, trail = _TRIM.match(seg).groups()
        return (seg if _CODE_SPAN.fullmatch(seg)
                else f"{lead}[( {core}]{trail}" if core
                else seg)
    return "".join(wrap(s) for s in _CODE_SPAN.split(text)) or f"[( {text}]"


# ---------- 管理ブロックのレンダリング ----------
def schedule_lines(items: list[dict]) -> list[str]:
    out = []
    for e in items:
        head = "終日 📅 " if e.get("allday") else f"{e.get('time', '')}~ 📅 "
        out.append(f" {head}{e.get('summary', '')}")
        if e.get("calendar"):
            out.append(f"  [( @{e['calendar']}]")
    return out


def link_lines(links: list[str], indent: str = "  ") -> list[str]:
    """本文に関連する Scrapbox ページへの被リンクを、本文(先頭スペース1)より一段深いインデントで
    1 行にまとめる(文頭はインデント空白＝「一段下げて文頭開けて」)。LLM が選んだ関連付けなので
    灰色マーク(LLM印)で包む — Scrapbox の [Title] は装飾 [( ] 内でもリンクとして機能する。
    空(None/空文字を除いて 0 件)なら行自体を出さない。"""
    titles = [t for t in links if t]
    return [f"{indent}{mark_gray(' '.join(f'[{t}]' for t in titles))}"] if titles else []


def lifelog_lines(items: list[dict]) -> list[str]:
    return [ln for e in items
            for ln in [f" {mark_gray(e.get('summary', ''))} `{e.get('time', '')}`"]
            + link_lines(e.get("links", []))]


def gmail_lines(items: list[dict]) -> list[str]:
    # LLM が収集した機微情報の index。件名/差出人は灰色マーク(LLM印)で包み、himalaya-id は
    # backtick で濃いまま残す。本文は転記せず `himalaya message read -a gmail <id>` で live 取得。
    out = []
    for e in items:
        frm = (e.get("from", "") or "").strip()
        subj = (e.get("subject", "") or "").strip()
        out.append(" " + mark_gray(f"{e.get('time', '')} ✉️ {frm}: {subj} `#{e.get('id', '')}`"))
    return out


def work_line(w: dict) -> str:
    tail = " ".join(f"`#{h.lstrip('#')}`" for h in w.get("hashes", []))
    return f" {mark_gray(w.get('summary', ''))}" + (f" {tail}" if tail else "")


def work_lines(items: list[dict], crosslink: str | None) -> list[str]:
    return [ln for w in items for ln in [work_line(w)] + link_lines(w.get("links", []))] \
        + ([f" [( ↔ 関連: [{crosslink}]]"] if crosslink else [])


# ---------- 既存ページ → ブロック列(位置ごと verbatim 保持の単位) ----------
_SECTION = re.compile(r"^\[\*\* .+\]$")  # [** ...] 見出し(独自セクションを含む)
# nav は nav_line() の生成形 [YYYY/M/D]←→[YYYY/M/D] に厳密一致させる。`"←→" in s` の緩い判定だと
# 人間が本文に「仕事←→生活」等と書いただけで nav ブロック扱いされ、その行が消え後続も巻き込まれる。
_NAV_LINE = re.compile(r"^\[\d{4}/\d{1,2}/\d{1,2}\]←→\[\d{4}/\d{1,2}/\d{1,2}\]$")


def is_header(line: str, icon: str) -> bool:
    s = line.strip()
    return (s == f"[{icon}.icon]" or s == "[Limitlessライフログ]"
            or s == "[claude code.icon]" or s == GMAIL_HEADER
            or bool(_NAV_LINE.match(s)) or bool(_SECTION.match(s)))


# daily-report 自身が生成する本文行のパターン。管理ブロックを再生成する際、これに該当しない非空行は
# 「人間が直接書いた行」とみなして保持する(=管理ブロックに人間記入を吸収させて消さないための識別)。
# 生成行 = 管理見出し / 灰色マーク [( を含む行 (work/lifelog/gmail/links/@cal/↔関連 はすべて灰色) / Schedule の📅行。
# 「行頭が [(」でなく「[( を含む」で判定する理由: summary が backtick コードスパンで始まると mark_gray が
# コード span を装飾の外へ出すため行頭が `code` になる(例 ` `foo` [( を直した] `#h`)。startswith では
# これを foreign 誤判定して旧生成行が残り続け冪等性が壊れる(Codexレビュー指摘・実証済)。
# ceiling(ponytail): 灰色 [( … や `HH:MM~ 📅` 形式は機械側の規約。人間がこの形をそのまま手書きすると
# 生成行と区別できず再生成で消える。人間記入は素のテキストで書く前提(= [( /📅 形式を手打ちしない)。
_SCHEDULE_LINE = re.compile(r"^(終日|\d{1,2}:\d{2}~) 📅 ")


def is_generated(line: str, icon: str) -> bool:
    s = line.strip()
    return (not s or is_header(line, icon)
            or "[(" in s or bool(_SCHEDULE_LINE.match(s)))


def foreign_lines(block_lines: list[str], icon: str) -> list[str]:
    """管理ブロックの既存本文から「人間が書いた行」だけを抜き出す(生成行・空行は除く)。"""
    return [ln for ln in block_lines if ln.strip() and not is_generated(ln, icon)]


def block_key(header: str, icon: str) -> str:
    """見出し行 → ブロック key。既知の人間用見出しは短縮 key、未知の独自見出しは
    見出し文字列そのものを key にする(=order に rank が無い=foreign として保持される)。"""
    s = header.strip()
    return ("icon" if s == f"[{icon}.icon]"
            else "Limitless" if s == "[Limitlessライフログ]"
            else "work" if s == "[claude code.icon]"
            else "Gmail" if s == GMAIL_HEADER
            else "nav" if _NAV_LINE.match(s)
            else HEADER_KEY.get(s, s))


def parse_blocks(lines: list[str], icon: str) -> list[tuple[str, list[str]]]:
    """本文行を (key, [見出し行 + 本文行...]) のブロック列に分解。見出し前の自由記述は
    "~preamble" ブロックとして先頭に残す。LLM が壊した parse_sections の「直前セクションへ
    巻き込み→破棄」を排し、未知の見出しも独立ブロックとして位置保持できるようにする。"""
    blocks: list[tuple[str, list[str]]] = []
    key, buf = "~preamble", []
    for ln in lines:
        if is_header(ln, icon):
            blocks.append((key, buf))
            key, buf = block_key(ln, icon), [ln]
        else:
            buf.append(ln)
    blocks.append((key, buf))
    return blocks


def merge_blocks(existing: list[tuple[str, list[str]]], managed: dict[str, list[str]],
                 template: str, icon: str) -> list[tuple[str, list[str]]]:
    """既存ブロック列に管理ブロックをマージ。管理 key は位置ごと再生成(無ければ正準位置へ挿入)、
    それ以外の foreign ブロックは順序ごと verbatim 保持する。管理ブロック内に人間が書いた行
    (foreign_lines)は再生成後も末尾に残す = 当日空で削除される管理ブロックの人間記入も失わない。
    既存に同じ管理 key が重複していても再生成は最初の1個だけ(2個目以降は人間行のみ残し正規化)。"""
    order = DIARY[template]["order"]
    managed_keys = DIARY[template]["managed"]
    rank = {k: i for i, k in enumerate(order)}
    regenerated: set[str] = set()

    def keep(k: str, lines: list[str]) -> tuple[str, list[str]]:
        if k in managed:                       # 生成内容は最初の出現にだけ付ける(重複ブロックを正規化)
            gen = [] if k in regenerated else managed[k]
            regenerated.add(k)
            return (k, gen + foreign_lines(lines, icon))
        if k in managed_keys:                  # 当日空(=managed に無い): 生成行は捨て人間行は残す
            return (k, foreign_lines(lines, icon))
        return (k, lines)                      # foreign: verbatim 保持

    result = [b for b in (keep(k, lines) for k, lines in existing) if b[1]]
    seen = {k for k, _ in result}
    for k in order:
        if k in managed and k not in seen:
            r = rank[k]
            anchor = [i for i, (kk, _) in enumerate(result) if kk in rank and rank[kk] < r]
            result.insert((anchor[-1] + 1) if anchor else 0, (k, managed[k]))
            seen.add(k)
    return result


def flatten_blocks(blocks: list[tuple[str, list[str]]]) -> list[str]:
    bodies = [b for b in (_rstrip_blanks(list(lines)) for _, lines in blocks) if b]
    return _rstrip_blanks([ln for body in bodies for ln in body + [""]])


def _rstrip_blanks(xs: list[str]) -> list[str]:
    while xs and xs[-1].strip() == "":
        xs = xs[:-1]
    return xs


# ---------- ページ本文の組み立て(管理ブロックの生成 → 既存とマージ) ----------
def render_managed(c: dict, template: str, icon: str) -> dict[str, list[str]]:
    """当日ソースから管理ブロックを生成。中身が無い管理ブロックは key 自体を含めない
    (= merge_blocks 側で「当日空 → 既存ブロックを削除」になる)。"""
    nav = [nav_line(c["date"])]
    sched = ["[** Schedule]"] + schedule_lines(c.get("schedule", []))
    return (
        {"icon": [f"[{icon}.icon]"], "Schedule": sched, "nav": nav}
        | ({"Limitless": ["[Limitlessライフログ]"] + lifelog_lines(c["lifelog"])} if c.get("lifelog") else {})
        | ({"work": ["[claude code.icon]"] + work_lines(c.get("work", []), c.get("crosslink"))}
           if (c.get("work") or c.get("crosslink")) else {})
        if template == "pin-diary" else
        {"Schedule": sched, "nav": nav,
         "yatta": ["[** やったこと]"] + work_lines(c.get("work", []), c.get("crosslink")) + lifelog_lines(c.get("lifelog", []))}
    )


def default_blocks(template: str, icon: str) -> list[tuple[str, list[str]]]:
    """新規ページのみ生成する人間記入用の空スキャフォールド(管理ブロックは merge が挿入)。"""
    return [(k, [KEY_HEADER[k]] + list(body)) for k, body in DIARY[template]["default"]]


def build_diary(c: dict, existing: list[str] | None, template: str) -> list[str]:
    """pin-diary / team 共通。新規 → デフォルトスキャフォールド、既存 → ブロック分解を土台に、
    管理ブロックだけ再生成し、Notes/メモ/Habbit/Task + ユーザー独自セクションは位置ごと保持。"""
    icon = c.get("icon", "tkgshn")
    base = parse_blocks(existing, icon) if existing is not None else default_blocks(template, icon)
    return flatten_blocks(merge_blocks(base, render_managed(c, template, icon), template, icon))


def build_plain(c: dict) -> list[str]:
    icon = c.get("icon", "tkgshn")
    out = [f" [{icon}.icon] [claude code.icon]"]
    out += [" " + l for l in work_lines(c.get("work", []), c.get("crosslink"))]
    if c.get("lifelog"):
        out += [" [Limitlessライフログ]"] + [" " + l for l in lifelog_lines(c["lifelog"])]
    out += ["", f" {nav_line(c['date'])}"]
    return out


# ---------- Gmail を takalog へ分離(機微情報) ----------
def strip_gmail_block(lines: list[str]) -> list[str]:
    """既存ページから [📧 Gmail] ブロック(ヘッダ + インデント子行)だけを除去し、他は保持する。"""
    out, skip = [], False
    for ln in lines:
        s = ln.strip()
        if s == GMAIL_HEADER:
            skip = True
            continue
        if skip:
            if ln.startswith(" ") or s == "":
                continue  # ブロック内の子行・空行は捨てる
            skip = False    # 非インデント行が来たらブロック終わり
        out.append(ln)
    return _rstrip_blanks(out)


def build_gmail_takalog(c: dict, existing: list[str]) -> list[str]:
    """takalog 用。機微な Gmail index を [📧 Gmail] ブロックとして upsert(冪等)。
    既存 Gmail ブロックを除去 → 新ブロックをタイトル直下(逆時系列)に置き、他(todays-task 等)は保持。"""
    block = [GMAIL_HEADER] + gmail_lines(c.get("gmail", []))
    rest = strip_gmail_block(existing)
    if len(block) == 1:          # gmail 無し → 既存の Gmail ブロックを消すだけ
        return rest
    return _rstrip_blanks(block + (["", *rest] if rest else []))


# ---------- Scrapbox I/O ----------
def fetch_lines(project: str, title: str) -> list[str] | None:
    sid = os.environ.get("SCRAPBOX_SID", "")
    from urllib.parse import quote
    # 日付タイトル(YYYY/M/D)のスラッシュは path 区切りでなくタイトルの一部なので safe="" で
    # 完全に percent-encode する。これを怠ると API がタイトルを途中までと誤認し全 date ページが
    # 404 → 既存ページを「新規」と誤判定 → 空テンプレで全体上書きする(=主たる上書きバグ)。
    url = f"https://scrapbox.io/api/pages/{project}/{quote(title, safe='')}/text"
    r = subprocess.run(["curl", "-s", "-o", "-", "-w", "\n%{http_code}", url,
                        "-H", f"Cookie: connect.sid={sid}"], capture_output=True, text=True)
    *body, code = r.stdout.split("\n")
    code = code.strip()
    # 200=既存(body[0]はtitle) / 404=真に不在(=新規ページ) / それ以外=一時障害。
    # 一時障害を None(新規扱い)に丸めると空テンプレで上書きするので、ここでは fail-fast し
    # main 側で書き込みを中止する(取得できないページは絶対に上書きしない)。
    return (body[1:] if code == "200"
            else None if code == "404"
            else _raise(f"fetch failed (HTTP {code or '000'}) for {project}/{title}"))


def _raise(msg: str):
    raise RuntimeError(msg)


HELPER_SRC = r'''import { patch } from "@cosense/std/websocket";
import { readFileSync } from "node:fs";
const die = (m) => { process.stderr.write(`patch-verbatim: ${m}\n`); process.exit(1); };
const argv = process.argv.slice(2);
const dry = argv.includes("--dry");
const file = argv.find((a) => !a.startsWith("-"));
!file && die("usage: node _sbx_patch_verbatim.mjs <spec.json> [--dry]");
const { project, title, lines } = JSON.parse(readFileSync(file, "utf-8"));
(!project || !title || !Array.isArray(lines)) && die("spec must have {project, title, lines[]}");
const finalLines = lines[0] === title ? lines : [title, ...lines];
const run = dry ? Promise.resolve(process.stdout.write(finalLines.join("\n") + "\n"))
  : !process.env.SCRAPBOX_SID ? Promise.resolve(die("SCRAPBOX_SID not set"))
  : patch(project, title, () => finalLines, { sid: process.env.SCRAPBOX_SID })
      .then((r) => (r && r.ok !== false)
        ? process.stdout.write(`OK https://scrapbox.io/${project}/${encodeURIComponent(title)}\n`)
        : die(`patch failed: ${JSON.stringify(r)}`));
run.catch((e) => die(e?.message ?? String(e)));
'''


def ensure_helper():
    if not os.path.exists(VERBATIM):
        open(VERBATIM, "w").write(HELPER_SRC)


def write_verbatim(project: str, title: str, body: list[str], dry: bool) -> str:
    ensure_helper()
    spec = os.path.join(SBX_DIR, "_daily_spec.json")
    json.dump({"project": project, "title": title, "lines": [normalize(title)] + [normalize(x) for x in body]},
              open(spec, "w"), ensure_ascii=False)
    args = ["node", "--preserve-symlinks", VERBATIM, spec] + (["--dry"] if dry else [])
    last = ""
    for _ in range(1 if dry else 3):
        r = subprocess.run(args, cwd=SBX_DIR, capture_output=True, text=True)
        last = (r.stdout + r.stderr).strip()
        if dry or last.startswith("OK") or last.split("\n")[-1].startswith("OK"):
            break
    return last


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    dry = "--dry-run" in sys.argv or "--dry" in sys.argv
    c = json.load(sys.stdin)
    template = c.get("template", "pin-diary")
    title = _fmt(_d(c["date"]))
    try:
        existing = (fetch_lines(c["project"], title)
                    if cmd == "write" and template in ("pin-diary", "team", "gmail-takalog") else None)
    except RuntimeError as e:
        sys.exit(f"daily-page: {e} — 既存ページを取得できないため上書きを中止しました")
    body = (build_diary(c, existing, template) if template in ("pin-diary", "team")
            else build_gmail_takalog(c, existing or []) if template == "gmail-takalog"
            else build_plain(c))
    if cmd == "render":
        print("\n".join(body))
    elif cmd == "write":
        print(write_verbatim(c["project"], title, body, dry))
    else:
        sys.exit("usage: daily-page.py render|write [--dry-run]  (curated JSON on stdin)")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""content-lint — decision-writing コンテンツ規範の決定論的 linter。

レビューの「機械で厳密に判定できる層」だけを担う。意味層(構造・トーン・平易化・
出典の裏取り・中黒が並列か固有名詞か)は LLM 側の仕事で、ここでは判定しない。

Filter パターン: テキストのバイトストリームを stdin で受け、違反を stdout へ emit する。
ストレージ(ローカル md / Scrapbox raw json / Google Docs export)から切り離す。
  - 普通のテキスト/Markdown:   cat doc.md | content-lint.py
  - Scrapbox の raw json:      jq -r '.lines[].text' page.json | content-lint.py
  - 全角スラッシュ等の warn も見る: content-lint.py --all

exit code: ERROR が1件でもあれば 1、なければ 0。--selftest で内蔵アサーション。
"""
from __future__ import annotations
import argparse, re, sys
from dataclasses import dataclass

# 装飾記号(幾何記号)。行頭マーカー・見出し・強調・区切りに使う意味のない記号。
# 🏆 のような凡例付き semantic emoji は対象外(意味を担うため)。
DECORATIVE = "■□▪▫▬▲△▶▷▼▽●○◆◇◈◉◎★☆※›»♦❖➤➔"
RE_DECORATIVE = re.compile(f"[{re.escape(DECORATIVE)}]")
# em dash(U+2014) / horizontal bar(U+2015) / 2倍ダッシュ。en dash(U+2013)は範囲用で許可。
RE_DASH = re.compile(r"[—―]")
# 丸数字 ①-⑳ / ⓵ 系。常に列挙マーカーなので即 ERROR。
RE_CIRCLED = re.compile(r"[①-⑳❶-❿⓪]")
# 番号マーカー (1)(2)… 全角半角。数字のみ内包のものだけ("(40/予測23)"のような括弧注記は除外)。
RE_PARENNUM = re.compile(r"[(（]\s*[0-9０-９]{1,2}\s*[)）]")
# 全角スラッシュ(半角推奨)。warn。
RE_ZSLASH = re.compile(r"／")
# 生 URL(warn・媒体依存)。Markdown リンク `](url)` や Scrapbox `[url]` の内側は除外。
RE_URL = re.compile(r"https?://[^\s　\])）」』]+")

SEVERITY_ERROR = "ERROR"
SEVERITY_WARN = "WARN"


@dataclass(frozen=True)
class Finding:
    line: int
    col: int
    severity: str
    rule: str
    message: str
    snippet: str


def _ctx(text: str, pos: int, width: int = 18) -> str:
    lo = max(0, pos - width)
    hi = min(len(text), pos + width)
    return ("…" if lo else "") + text[lo:hi] + ("…" if hi < len(text) else "")


def lint_line(lineno: int, text: str, check_warn: bool) -> list[Finding]:
    out: list[Finding] = []
    for m in RE_DECORATIVE.finditer(text):
        out.append(Finding(lineno, m.start() + 1, SEVERITY_ERROR, "decorative-symbol",
                           f"装飾記号 '{m.group()}' は使わない。削るか太字化(Scrapbox灰色見出しは [(* 見出し])",
                           _ctx(text, m.start())))
    for m in RE_DASH.finditer(text):
        out.append(Finding(lineno, m.start() + 1, SEVERITY_ERROR, "dash",
                           "ダッシュ(—/―/――)は区切りに使わない。言い換えは句点、同格は括弧、ラベルは全角コロン：",
                           _ctx(text, m.start())))
    for m in RE_CIRCLED.finditer(text):
        out.append(Finding(lineno, m.start() + 1, SEVERITY_ERROR, "circled-number",
                           f"丸数字 '{m.group()}' は列挙マーカー。箇条書き(改行)にする",
                           _ctx(text, m.start())))
    # 番号マーカーは「同一行に2個以上」か「行頭」で列挙とみなす(単発の括弧注記を誤検知しない)
    pn = list(RE_PARENNUM.finditer(text))
    at_head = pn and text[:pn[0].start()].strip() == ""
    if len(pn) >= 2 or at_head:
        for m in pn:
            out.append(Finding(lineno, m.start() + 1, SEVERITY_ERROR, "paren-number",
                               f"番号マーカー '{m.group()}' は使わない。箇条書き(改行)か本文の語で表す",
                               _ctx(text, m.start())))
    if check_warn:
        for m in RE_ZSLASH.finditer(text):
            out.append(Finding(lineno, m.start() + 1, SEVERITY_WARN, "fullwidth-slash",
                               "全角スラッシュ ／ は半角 / を推奨", _ctx(text, m.start())))
        for m in RE_URL.finditer(text):
            before = text[:m.start()]
            if before.endswith("](") or before.endswith("["):
                continue  # Markdown / Scrapbox リンク内は許可
            out.append(Finding(lineno, m.start() + 1, SEVERITY_WARN, "raw-url",
                               "生 URL はネイティブリンク(テキストにリンク)にする(媒体依存)",
                               _ctx(text, m.start())))
    return out


def lint(text: str, check_warn: bool) -> list[Finding]:
    return [f for i, ln in enumerate(text.split("\n"), 1) for f in lint_line(i, ln, check_warn)]


def render(findings: list[Finding], path: str) -> str:
    return "\n".join(
        f"{path}:{f.line}:{f.col}: [{f.severity} {f.rule}] {f.message}  « {f.snippet} »"
        for f in findings)


def selftest() -> int:
    good = "これは普通の文。スコア(40/予測23)や範囲 3–5 や https://x.test へのリンクは素の text では検知しない設定次第。"
    bad = "[( ■ 見出し]\nA ―― B\n穏やかな引退の3要件 (1) 保存 (2) 移行 (3) 同意\n① まず ② つぎ\n公共／民間"
    gf = lint(good, check_warn=False)
    assert gf == [], f"good text should pass (errors): {gf}"
    bf = lint(bad, check_warn=False)
    rules = {f.rule for f in bf}
    assert "decorative-symbol" in rules, rules
    assert "dash" in rules, rules
    assert "paren-number" in rules and sum(f.rule == "paren-number" for f in bf) == 3, bf
    assert "circled-number" in rules and sum(f.rule == "circled-number" for f in bf) == 2, bf
    # 単発の括弧注記は誤検知しない(行頭でない単発の (40) や (40/予測23))
    assert lint("スコア(40/予測23)", check_warn=False) == [], "paren note with non-digits must not flag"
    assert not any(f.rule == "paren-number" for f in lint("スコアは(40)だった", check_warn=False)), "single mid-line (40) must not flag"
    # 全角スラッシュは warn のみ(既定 off では出ない)
    assert not any(f.rule == "fullwidth-slash" for f in lint("公共／民間", check_warn=False))
    assert any(f.rule == "fullwidth-slash" for f in lint("公共／民間", check_warn=True))
    print("selftest: OK")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file", nargs="?", help="対象ファイル(省略時 stdin)")
    ap.add_argument("--all", "-a", action="store_true", help="warn(全角スラッシュ・生URL)も出す")
    ap.add_argument("--quiet", "-q", action="store_true", help="違反なしのとき何も出さない")
    ap.add_argument("--selftest", action="store_true", help="内蔵アサーションを実行")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    path = args.file or "-"
    text = (open(args.file, encoding="utf-8").read() if args.file else sys.stdin.read())
    findings = lint(text, check_warn=args.all)
    errors = [f for f in findings if f.severity == SEVERITY_ERROR]
    if findings:
        print(render(findings, path))
        print(f"\n{len(errors)} error(s), {len(findings) - len(errors)} warning(s)", file=sys.stderr)
    elif not args.quiet:
        print(f"{path}: 違反なし", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

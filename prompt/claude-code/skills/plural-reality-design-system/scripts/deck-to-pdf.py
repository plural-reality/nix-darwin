#!/usr/bin/env python3
"""deck-to-pdf — HTML デッキを「各スライド=1ページ」の PDF に出す（美をピクセル忠実に運ぶ）。

Slides のネイティブ形式に変換すると CSS の美は必ず落ちる。だから変換せず、Chrome の print で
HTML の描画をそのまま PDF 化する。フォント・ダーク背景・レイアウトを保持したまま配布/投影できる。

前提(2026-07-05 実証・darwin): Chrome headless print は動く。ハングの真因は外部リソース待ち
(特に fonts.googleapis の <link>)なので、印刷HTMLから外部フォントlinkを除去してから印刷する。

  deck-to-pdf.py deck.html                 # → deck.pdf
  deck-to-pdf.py deck.html -o out.pdf --size 1280x720 --slide .slide
  deck-to-pdf.py --selftest

各 .slide(既定セレクタ)を 1ページ化する印刷CSSを注入する。ダーク背景保持に print-color-adjust:exact。
"""
from __future__ import annotations
import argparse, re, subprocess, sys, tempfile, pathlib

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def print_css(w: int, h: int, slide_sel: str) -> str:
    return (
        "<style>@media print{"
        f"@page{{size:{w}px {h}px;margin:0;}}"
        "*{-webkit-print-color-adjust:exact!important;print-color-adjust:exact!important;}"
        "html,body{background:#fff;}"
        ".slide-wrapper,.slide-container{max-width:none!important;margin:0!important;padding:0!important;}"
        ".slide-label{display:none!important;}"
        f"{slide_sel}{{aspect-ratio:auto!important;width:{w}px!important;height:{h}px!important;"
        "margin:0!important;border-radius:0!important;box-shadow:none!important;"
        "page-break-after:always;break-after:page;overflow:hidden;}"
        "}</style>"
    )


def build_print_html(src: str, w: int, h: int, slide_sel: str, keep_fonts: bool) -> str:
    if not keep_fonts:
        # ハング要因の外部フォントを除去(fonts.googleapis / fonts.gstatic の <link>)
        src = re.sub(r'<link[^>]*fonts\.(?:googleapis|gstatic)\.com[^>]*>', '', src)
    css = print_css(w, h, slide_sel)
    return src.replace("</head>", css + "\n</head>", 1) if "</head>" in src else css + src


def render(in_html: str, out_pdf: str, w: int, h: int, slide_sel: str, keep_fonts: bool, timeout: int = 120) -> int:
    src = pathlib.Path(in_html).read_text(encoding="utf-8")
    tmp = tempfile.NamedTemporaryFile("w", suffix=".print.html", delete=False, encoding="utf-8")
    tmp.write(build_print_html(src, w, h, slide_sel, keep_fonts)); tmp.close()
    out = str(pathlib.Path(out_pdf).resolve())
    try:
        r = subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
             f"--print-to-pdf={out}", f"file://{pathlib.Path(tmp.name).resolve()}"],
            capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        print(f"TIMEOUT({timeout}s): 外部リソース待ちの可能性。--keep-fonts を外すか link を確認。", file=sys.stderr)
        return 2
    finally:
        pathlib.Path(tmp.name).unlink(missing_ok=True)
    p = pathlib.Path(out)
    if r.returncode != 0 or not p.exists() or p.stat().st_size == 0:
        print(f"失敗 rc={r.returncode}: {r.stderr.decode()[-200:]}", file=sys.stderr)
        return 1
    pages = p.read_bytes().count(b"/Type /Page") - p.read_bytes().count(b"/Type /Pages")
    print(f"{out}  ({p.stat().st_size//1024} KB, ~{pages} pages)")
    return 0


def selftest() -> int:
    # print CSS が期待要素を含む
    css = print_css(1280, 720, ".slide")
    assert "size:1280px 720px" in css and "print-color-adjust:exact" in css and "page-break-after:always" in css, css
    # フォントlink除去
    h = build_print_html('<head><link href="https://fonts.googleapis.com/css2?x" rel="stylesheet"></head>', 1280, 720, ".slide", False)
    assert "fonts.googleapis" not in h and "@media print" in h, "font strip / css inject failed"
    # keep_fonts なら残す
    h2 = build_print_html('<head><link href="https://fonts.googleapis.com/css2?x"></head>', 1280, 720, ".slide", True)
    assert "fonts.googleapis" in h2
    print("selftest: OK"); return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("html", nargs="?", help="入力デッキHTML")
    ap.add_argument("-o", "--out", help="出力PDF(既定=入力名.pdf)")
    ap.add_argument("--size", default="1280x720", help="1スライドのpx寸法(既定 1280x720=16:9)")
    ap.add_argument("--slide", default=".slide", help="1ページ化するスライドのCSSセレクタ(既定 .slide)")
    ap.add_argument("--keep-fonts", action="store_true", help="外部フォントlinkを除去しない(ハング注意)")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if not a.html:
        ap.error("入力HTMLを指定してください")
    w, h = (int(x) for x in a.size.lower().split("x"))
    out = a.out or str(pathlib.Path(a.html).with_suffix(".pdf"))
    return render(a.html, out, w, h, a.slide, a.keep_fonts)


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""design-learn collector — review コメントから design/visual 訂正だけを回収し、distill 用に構造化する。

= self-learn がテキスト事実に対してやることの「デザイン版」の入力段。
review-page(reviewable-html-workbench)の comments.json / DB comments から
「人が成果物の見た目に付けた訂正コメント」を拾い、どの canonical テーマ・トークンを
編集すべきかの target_hint を付けて出力する。distill(LLM)はこの構造化 FB を読んで
skill トークンの編集提案に変換する。

design タグ規約(SPA改変不要): コメント本文に #design / #visual / [design] / [visual](大小無視)。

usage:
  collect_design_feedback.py <comments.json | review-output-dir> [more...]
  collect_design_feedback.py --selfcheck
出力: JSON {schema_version, count, items:[{source, block_id, selected_text, comment, tags, target_hint, created_at}]}
stdlib のみ。
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

TAG_RE = re.compile(r"#(design|visual)\b|\[(design|visual)\]", re.IGNORECASE)

# 訂正文のキーワード → 編集すべきトークン領域(distill への当たり)
TOKEN_HINTS: list[tuple[str, str]] = [
    (r"余白|マージン|margin|パディング|padding|spacing|詰め|間隔|狭|広", "spacing"),
    (r"色|カラー|color|配色|teal|背景|background|コントラスト|contrast", "color"),
    (r"角丸|radius|丸み|カド|角|シャープ|sharp", "radius"),
    (r"フォント|font|書体|ウェイト|太さ|weight|文字サイズ|font-size|級", "typography"),
    (r"行間|line-?height|字間|letter-?spacing|tracking|字送り", "typography-spacing"),
    (r"位置|配置|レイアウト|layout|揃え|align|グリッド|grid|カラム|column", "layout"),
    (r"影|shadow|グラデ|gradient|装飾|decoration", "effects"),
]

# document_id / slug に現れる format 手掛かり → 標的 skill
FORMAT_SKILL: list[tuple[str, str]] = [
    (r"ir|slide|決算|ピッチ|千人", "design-format-ir-slides"),
    (r"whitepaper|ホワイトペーパー|白書", "design-format-whitepaper"),
    (r"partnership|協業|パートナー|ケース", "design-format-partnership"),
    (r"service|サービス定義|仕様|調達", "design-format-service-def"),
    (r"web|lp|ランディング", "design-format-web"),
]


def _target_hint(comment: str, document_id: str) -> dict[str, list[str]]:
    tokens = [name for pat, name in TOKEN_HINTS if re.search(pat, comment, re.IGNORECASE)]
    skills = [name for pat, name in FORMAT_SKILL if re.search(pat, document_id, re.IGNORECASE)]
    # format が特定できなければ傘(横断ブランド)を標的にする
    return {"token_area": tokens or ["unknown"], "skill": skills or ["plural-reality-design-system"]}


def _tags(text: str) -> list[str]:
    return sorted({(m.group(1) or m.group(2)).lower() for m in TAG_RE.finditer(text)})


def _iter_comment_files(arg: str):
    p = Path(arg)
    if p.is_dir():
        yield from sorted(p.rglob("comments.json"))
    elif p.is_file():
        yield p


def collect(paths: list[str]) -> dict:
    items: list[dict] = []
    files = [f for arg in paths for f in _iter_comment_files(arg)]
    for f in files:
        try:
            payload = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        doc = payload.get("document_id", "")
        for c in payload.get("comments", []):
            body = c.get("comment", "")
            tags = _tags(body)
            if not tags:
                continue  # design/visual タグの無いコメントは対象外
            items.append(
                {
                    "source": f"{doc}#{c.get('block_id', '')}",
                    "block_id": c.get("block_id", ""),
                    "selected_text": c.get("selected_text", ""),
                    "comment": body,
                    "tags": tags,
                    "target_hint": _target_hint(body + " " + c.get("selected_text", ""), doc),
                    "created_at": c.get("created_at", ""),
                }
            )
    return {"schema_version": "1.0", "count": len(items), "items": items}


def _selfcheck() -> int:
    sample = {
        "schema_version": "1.0",
        "document_id": "plural-reality-ir-decks",
        "comments": [
            {"id": "1", "block_id": "kpi", "selected_text": "47%", "comment": "#design カードの余白が広すぎ。もっと詰めて", "status": "open", "created_at": "t", "replies": []},
            {"id": "2", "block_id": "title", "selected_text": "見出し", "comment": "ここは普通のレビュー指摘(誤字)", "status": "open", "created_at": "t", "replies": []},
            {"id": "3", "block_id": "hero", "selected_text": "背景", "comment": "[visual] teal が強すぎる。もっと控えめに", "status": "open", "created_at": "t", "replies": []},
        ],
    }
    import tempfile
    d = tempfile.mkdtemp()
    (Path(d) / "comments.json").write_text(json.dumps(sample), encoding="utf-8")
    out = collect([d])
    assert out["count"] == 2, f"design/visual だけ拾う想定=2, got {out['count']}"
    ids = {i["block_id"] for i in out["items"]}
    assert ids == {"kpi", "hero"}, f"タグ付きのみ, got {ids}"
    kpi = next(i for i in out["items"] if i["block_id"] == "kpi")
    assert "spacing" in kpi["target_hint"]["token_area"], "『余白/詰めて』→ spacing"
    assert kpi["target_hint"]["skill"] == ["design-format-ir-slides"], "doc=ir→ir-slides skill"
    hero = next(i for i in out["items"] if i["block_id"] == "hero")
    assert "color" in hero["target_hint"]["token_area"], "『teal/控えめ』→ color"
    assert hero["tags"] == ["visual"], f"tag=visual, got {hero['tags']}"
    print("selfcheck OK: design/visual 訂正のみ回収・token/skill 標的推定 一致")
    return 0


def main(argv: list[str]) -> int:
    if not argv:
        sys.stderr.write(__doc__ or "")
        return 2
    if argv[0] == "--selfcheck":
        return _selfcheck()
    print(json.dumps(collect(argv), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

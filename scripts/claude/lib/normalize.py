#!/usr/bin/env python3
"""表記ゆれ正規化フィルタ — Scrapbox 書き込みの単一正規化境界。

Why this shape:
- データ(エイリアス表=normalize_aliases.json)とロジック(置換)を分離する。固有名詞の
  追加は JSON だけ触れば済み、コードは不変。
- stdin→stdout のストリームフィルタとして合成でき(`curl … | normalize.py | scrapbox-write -V`)、
  かつ `from normalize import normalize` で純粋関数としても再利用できる(取込スクリプト用)。
- 原本(ローカル archive の実発話)は決して変えない。正規化は Scrapbox view を生成する
  「書き込み境界」でのみ適用する materialized-view 戦略。
"""
from functools import reduce
import json
import os
import sys

_ALIASES = json.load(
    open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "normalize_aliases.json"), encoding="utf-8")
)

# reduce over the alias table: 文字列に対する各 (from→to) 置換のモノイド的畳み込み。
normalize = lambda text: reduce(lambda acc, kv: acc.replace(kv[0], kv[1]), _ALIASES.items(), text)

if __name__ == "__main__":
    sys.stdout.write(normalize(sys.stdin.read()))

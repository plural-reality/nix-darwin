#!/usr/bin/env python3
# doc.json から見出し → startIndex/endIndex を抽出
# IO: doc.json を stdin から読む (引数があればそのファイルパスを読む)
#   例: gws docs documents get --params '{"documentId":"DOC_ID"}' | python3 scripts/extract-headings.py
#       python3 scripts/extract-headings.py doc.json
import json
import sys
with (open(sys.argv[1]) if len(sys.argv) > 1 else sys.stdin) as f:
    doc = json.load(f)
for el in doc['body']['content']:
    para = el.get('paragraph')
    if para:
        style = para['paragraphStyle'].get('namedStyleType', '')
        if style.startswith('HEADING'):
            text = ''.join(r.get('textRun', {}).get('content', '') for r in para['elements'])
            print(f'{el["startIndex"]:>5} - {el["endIndex"]:>5}  {style:<12}  {text.strip()[:70]}')

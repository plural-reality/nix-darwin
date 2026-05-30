#!/usr/bin/env python3
# docx 埋込コメントと anchor span を抽出
# 引数: unzip 済みディレクトリ (word/comments.xml と word/document.xml を含む)
#   例: python3 scripts/extract-docx-comments.py current-unzipped
import sys
import os
import json
import xml.etree.ElementTree as ET
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
ns = {'w': W}
_d = sys.argv[1]

# コメント本文
comments = {c.get(f'{{{W}}}id'): {
    'author': c.get(f'{{{W}}}author'),
    'text': ''.join((t.text or '') for t in c.findall('.//w:t', ns))
} for c in ET.parse(os.path.join(_d, 'word/comments.xml')).getroot().findall('w:comment', ns)}

# anchor span (document order で走査)
active, anchors = {}, {}
def walk(elem):
    tag = elem.tag.split('}')[-1]
    if tag == 'commentRangeStart': active[elem.get(f'{{{W}}}id')] = []
    elif tag == 'commentRangeEnd':
        cid = elem.get(f'{{{W}}}id')
        if cid in active: anchors[cid] = ''.join(active.pop(cid))
    elif tag == 't':
        for cid in active: active[cid].append(elem.text or '')
    for child in elem: walk(child)
walk(ET.parse(os.path.join(_d, 'word/document.xml')).getroot())

# 抽出結果 (comments 本文 + anchor span) を JSON で stdout へ
print(json.dumps({
    cid: {**meta, 'anchor': anchors.get(cid)}
    for cid, meta in comments.items()
}, ensure_ascii=False, indent=2))

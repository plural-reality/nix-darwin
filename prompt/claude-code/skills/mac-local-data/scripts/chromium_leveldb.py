#!/usr/bin/env python3
"""Decode a Chromium/Electron LevelDB store (Local Storage *or* IndexedDB).

Every Electron app (Claude Desktop, Slack, Notion, VS Code, Signal, Cursor,
Granola, …) persists state in `<App>/Local Storage/leveldb` and
`<App>/IndexedDB/<origin>.leveldb`. Raw `grep` fails on these because data
blocks are Snappy/Zstd-compressed — this reader parses the SST (`.ldb`) and
WAL (`.log`) formats directly and decompresses, so the text becomes
searchable. Read-only; copies the store to a tempdir first so a live app
cannot tear the read.

Snappy/Zstd come from `cramjam` (self-contained wheel, no system libs, no
host mutation). Run hermetically:

  uv run --with cramjam python chromium_leveldb.py <PATH> [MODE]

PATH may be a leveldb dir, or any dir/app-support folder — it is searched
recursively for leveldb stores.

MODE:
  --keys           list distinct key prefixes + counts (what's stored)
  --grep "text"    print key + value for values containing "text" (utf-8)
  --all            print every key + value preview (default; truncated)
  --raw            with --grep, print full untruncated values

NOTE: Local Storage holds small state/strings. IndexedDB holds bulk records
but values are V8-serialized — text is embedded, framing is binary. This
recovers the readable substrings, not a typed object graph.
"""
import sys
import os
import glob
import re
import shutil
import tempfile

import cramjam


def rv(buf, pos):
    """varint32/64."""
    r = s = 0
    while True:
        b = buf[pos]
        pos += 1
        r |= (b & 0x7F) << s
        if not (b & 0x80):
            return r, pos
        s += 7


def decomp(raw, typ):
    if typ == 0:
        return raw
    if typ == 1:
        return bytes(cramjam.snappy.decompress_raw(raw))
    if typ == 2:
        return bytes(cramjam.zstd.decompress(raw))
    raise ValueError(f"unknown compression {typ}")


def parse_block(blk):
    """Yield (key, value) from a decompressed leveldb data/index block."""
    nr = int.from_bytes(blk[-4:], "little")
    end = len(blk) - 4 - 4 * nr  # entries live before the restart array
    pos = 0
    key = b""
    while pos < end:
        try:
            shared, pos = rv(blk, pos)
            non_shared, pos = rv(blk, pos)
            vlen, pos = rv(blk, pos)
        except IndexError:
            break
        key = key[:shared] + blk[pos : pos + non_shared]
        pos += non_shared
        val = blk[pos : pos + vlen]
        pos += vlen
        yield key, val


def read_handle(buf, pos):
    off, pos = rv(buf, pos)
    sz, pos = rv(buf, pos)
    return off, sz, pos


def read_sst(path):
    data = open(path, "rb").read()
    if len(data) < 48:
        return []
    footer = data[-48:]
    p = 0
    _mo, _ms, p = read_handle(footer, p)  # metaindex (skip)
    io, isz, p = read_handle(footer, p)  # index handle
    iblk = decomp(data[io : io + isz], data[io + isz])
    out = []
    for _k, v in parse_block(iblk):  # index values are data-block handles
        do, dsz, _ = read_handle(v, 0)
        try:
            dblk = decomp(data[do : do + dsz], data[do + dsz])
            out.extend(parse_block(dblk))
        except Exception:
            continue
    return out


def read_log(path):
    """Best-effort WAL reader: recovers recent (un-flushed) puts.

    Log = 32 KiB blocks of [crc(4)][len(2)][type(1)][payload]. Payloads
    reassemble into write-batches: [seq(8)][count(4)] then per-record
    [tag(1)] tag1=put(key,value) tag0=delete(key), each length varint32.
    """
    raw = open(path, "rb").read()
    frags, i = [], 0
    while i + 7 <= len(raw):
        ln = int.from_bytes(raw[i + 4 : i + 6], "little")
        typ = raw[i + 6]
        payload = raw[i + 7 : i + 7 + ln]
        i += 7 + ln
        if typ == 0:  # zero padding to block end
            i = (i + 32767) // 32768 * 32768
            continue
        frags.append((typ, payload))
    # reassemble (1=full,2=first,3=middle,4=last)
    out, buf = [], b""
    for typ, payload in frags:
        if typ == 1:
            out.append(payload)
        elif typ == 2:
            buf = payload
        elif typ == 3:
            buf += payload
        elif typ == 4:
            out.append(buf + payload)
            buf = b""
    recs = []
    for batch in out:
        if len(batch) < 12:
            continue
        pos = 12
        try:
            while pos < len(batch):
                tag = batch[pos]
                pos += 1
                if tag == 1:
                    kl, pos = rv(batch, pos)
                    k = batch[pos : pos + kl]
                    pos += kl
                    vl, pos = rv(batch, pos)
                    v = batch[pos : pos + vl]
                    pos += vl
                    recs.append((k, v))
                elif tag == 0:
                    kl, pos = rv(batch, pos)
                    pos += kl
                else:
                    break
        except IndexError:
            pass
    return recs


def find_stores(path):
    if glob.glob(os.path.join(path, "*.ldb")) or glob.glob(os.path.join(path, "*.log")):
        return [path]
    found = set()
    for root, _dirs, files in os.walk(path):
        if any(f.endswith(".ldb") or f.endswith(".log") for f in files):
            found.add(root)
    return sorted(found)


def load(store):
    """Copy store to tempdir (avoid live torn reads), parse all ldb+log."""
    tmp = tempfile.mkdtemp()
    try:
        for f in glob.glob(os.path.join(store, "*")):
            if f.endswith((".ldb", ".log")):
                shutil.copy2(f, tmp)
        recs = []
        for f in sorted(glob.glob(os.path.join(tmp, "*.ldb"))):
            try:
                recs += read_sst(f)
            except Exception as e:
                print(f"  ! {os.path.basename(f)}: {e}", file=sys.stderr)
        for f in glob.glob(os.path.join(tmp, "*.log")):
            try:
                recs += read_log(f)
            except Exception as e:
                print(f"  ! {os.path.basename(f)}: {e}", file=sys.stderr)
        return recs
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def kstr(k):
    return k.decode("utf-8", "ignore") if isinstance(k, (bytes, bytearray)) else str(k)


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    path = os.path.expanduser(argv[0])
    mode = argv[1] if len(argv) > 1 else "--all"
    pat = argv[2] if len(argv) > 2 else None
    raw = "--raw" in argv

    stores = find_stores(path)
    if not stores:
        print(f"no leveldb store found under {path}", file=sys.stderr)
        return 2

    recs = []
    for s in stores:
        r = load(s)
        print(f"# {s}: {len(r)} records", file=sys.stderr)
        recs += r

    if mode == "--keys":
        counts = {}
        for k, _v in recs:
            pref = re.split(r"[\x00-\x1f]", kstr(k))[0][:60]
            counts[pref] = counts.get(pref, 0) + 1
        for k, c in sorted(counts.items(), key=lambda x: -x[1]):
            print(f"{c:6d}  {k!r}")
        return 0

    if mode == "--grep":
        needle = pat or ""
        for k, v in recs:
            s = v.decode("utf-8", "ignore")
            if needle in s:
                txt = s if raw else "".join(c for c in s if c.isprintable())[:200]
                print(f"{kstr(k)[:80]}\t{txt}")
        return 0

    # --all
    for k, v in recs:
        txt = "".join(c for c in v.decode("utf-8", "ignore") if c.isprintable())[:120]
        if txt.strip():
            print(f"{kstr(k)[:60]}\t{txt}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""Read the local iMessage store (~/Library/Messages/chat.db, SQLite).

Pure read-only. Decodes the modern `attributedBody` typedstream blob
(NSAttributedString) when the legacy `text` column is NULL, which is the
case for almost all messages on recent macOS.

Sending is OUT OF SCOPE — use the `imessage-send` skill for that.

Usage:
  imessage.py recent [N]                 # N newest messages (default 20)
  imessage.py search "query" [N]         # full-text search (default 40)
  imessage.py with "name-or-number" [N]  # 1:1 thread only (group chats excluded)
  imessage.py chat "chat-guid" [N]       # a group or direct chat by its chat.db GUID
  imessage.py list-chats [N]             # recently active chats: date, GUID, name, members
  imessage.py stats                      # totals
  imessage.py list-handles [N]           # known handles (phone/email)

Output is TSV: date <TAB> dir <TAB> handle <TAB> text   (dir = me|them)
except `list-chats`: date <TAB> chat-guid <TAB> name <TAB> members
Designed for piping; the caller summarises. No network, no mutation.
"""
import sqlite3
import os
import sys
from datetime import datetime, timedelta, timezone

DB = os.environ.get("IMESSAGE_DB", os.path.expanduser("~/Library/Messages/chat.db"))
APPLE_EPOCH = datetime(2001, 1, 1, tzinfo=timezone.utc)


def connect():
    # read-only URI so we never mutate or lock the live store
    return sqlite3.connect(f"file:{DB}?mode=ro", uri=True)


def read_ts_int(buf, pos):
    """Read a typedstream-encoded integer. Returns (value, new_pos)."""
    b = buf[pos]
    pos += 1
    if b == 0x81:
        return int.from_bytes(buf[pos : pos + 2], "little"), pos + 2
    if b == 0x82:
        return int.from_bytes(buf[pos : pos + 4], "little"), pos + 4
    if b == 0x83:
        return int.from_bytes(buf[pos : pos + 8], "little"), pos + 8
    return b, pos


def decode_attributed_body(blob):
    """Extract the message text from a typedstream NSAttributedString blob.

    Framing observed: ...'NSString' 01 94 84 01 '+' <len> <utf8 * len> ...
    where '+' (0x2b) is the typedstream char-array marker and <len> is a
    typedstream integer. U+FFFC (object replacement) marks attachments.
    """
    if not blob:
        return None
    i = blob.find(b"NSString")
    if i < 0:
        return None
    j = blob.find(b"+", i)  # char-array marker
    if j < 0:
        return None
    try:
        length, pos = read_ts_int(blob, j + 1)
        raw = blob[pos : pos + length]
        return raw.decode("utf-8", "replace")
    except Exception:
        return None


def body(text, attributed):
    if text and text.strip():
        return text
    return decode_attributed_body(attributed) or ""


def fmt_date(apple_ns):
    if not apple_ns:
        return "?"
    # modern macOS stores ns since 2001; older stored seconds
    secs = apple_ns / 1e9 if apple_ns > 1e11 else apple_ns
    return (APPLE_EPOCH + timedelta(seconds=secs)).astimezone().strftime("%Y-%m-%d %H:%M")


def emit(rows):
    for date, is_me, handle, text, ab in rows:
        line = body(text, ab).replace("\t", " ").replace("\n", " ").strip()
        if not line:
            continue
        print(f"{fmt_date(date)}\t{'me' if is_me else 'them'}\t{handle or '-'}\t{line}")


SELECT = """
SELECT m.date, m.is_from_me, h.id AS handle, m.text, m.attributedBody
FROM message m LEFT JOIN handle h ON m.handle_id = h.ROWID
"""


def recent(cur, n=20):
    emit(cur.execute(SELECT + " ORDER BY m.date DESC LIMIT ?", (n,)).fetchall()[::-1])


def search(cur, q, n=40):
    # match the text column AND decoded bodies; SQL can only see `text`, so
    # we over-fetch on text LIKE, then also scan recent attributedBody blobs.
    like = f"%{q}%"
    rows = cur.execute(
        SELECT + " WHERE m.text LIKE ? ORDER BY m.date DESC LIMIT ?", (like, n)
    ).fetchall()
    if len(rows) < n:
        # text column is mostly NULL now — scan blobs for the query too
        scan = cur.execute(
            SELECT + " WHERE m.text IS NULL AND m.attributedBody IS NOT NULL"
            " ORDER BY m.date DESC LIMIT 4000"
        ).fetchall()
        hit = [r for r in scan if q in body(r[3], r[4])]
        rows = (rows + hit)[:n]
    emit(sorted(rows, key=lambda r: r[0] or 0))


# 「その相手との 1:1」を、相手ハンドルではなく chat で定義する。
# message.handle_id は「どの会話か」を持たないので、handle だけで絞ると
# 同じ人が参加する別グループでの発言まで混入する（＝私信の巻き込み）。
# 参加者がちょうど 1 人の chat = 直接チャット。その GUID 集合で絞る。
DIRECT_CHATS = """
SELECT chj.chat_id
FROM chat_handle_join chj JOIN handle hh ON hh.ROWID = chj.handle_id
GROUP BY chj.chat_id
HAVING count(*) = 1 AND max(hh.id) LIKE ?
"""


def with_handle(cur, who, n=60):
    rows = cur.execute(
        SELECT + " JOIN chat_message_join cmj ON cmj.message_id = m.ROWID"
        f" WHERE cmj.chat_id IN ({DIRECT_CHATS})"
        " ORDER BY m.date DESC LIMIT ?",
        (f"%{who}%", n),
    ).fetchall()
    emit(rows[::-1])


def with_chat(cur, chat_guid, n=60):
    rows = cur.execute(
        """
        SELECT m.date, m.is_from_me, h.id AS handle, m.text, m.attributedBody
        FROM chat c
        JOIN chat_message_join cmj ON cmj.chat_id = c.ROWID
        JOIN message m ON m.ROWID = cmj.message_id
        LEFT JOIN handle h ON m.handle_id = h.ROWID
        WHERE c.guid = ?
        ORDER BY m.date DESC
        LIMIT ?
        """,
        (chat_guid, n),
    ).fetchall()
    emit(rows[::-1])


def stats(cur):
    tot = cur.execute("SELECT count(*) FROM message").fetchone()[0]
    me = cur.execute("SELECT count(*) FROM message WHERE is_from_me=1").fetchone()[0]
    hs = cur.execute("SELECT count(*) FROM handle").fetchone()[0]
    print(f"messages={tot}\tsent_by_me={me}\thandles={hs}\tdb={DB}")


def list_handles(cur, n=50):
    for (hid,) in cur.execute(
        "SELECT id FROM handle ORDER BY ROWID DESC LIMIT ?", (n,)
    ).fetchall():
        print(hid)


def list_chats(cur, n=50):
    # 「最近動いた会話」順。chat.ROWID は作成順なので、久しぶりに動いた古い会話を
    # 取りこぼす。GUID だけでは選べないので、名前と参加者も一緒に出す。
    rows = cur.execute(
        """
        SELECT max(m.date), c.guid, IFNULL(NULLIF(c.display_name,''), c.chat_identifier),
               (SELECT group_concat(h2.id, ',') FROM chat_handle_join chj
                JOIN handle h2 ON h2.ROWID = chj.handle_id WHERE chj.chat_id = c.ROWID)
        FROM chat c
        JOIN chat_message_join cmj ON cmj.chat_id = c.ROWID
        JOIN message m ON m.ROWID = cmj.message_id
        WHERE c.guid IS NOT NULL
        GROUP BY c.ROWID
        ORDER BY max(m.date) DESC
        LIMIT ?
        """,
        (n,),
    ).fetchall()
    for date, guid, label, members in rows:
        print(f"{fmt_date(date)}\t{guid}\t{label or '-'}\t{members or '-'}")


CMDS = {"recent": recent, "search": search, "with": with_handle, "chat": with_chat,
        "stats": stats, "list-handles": list_handles, "list-chats": list_chats}


def main(argv):
    if not argv or argv[0] not in CMDS:
        print(__doc__)
        return 1
    if not os.path.exists(DB):
        print(f"chat.db not found at {DB}", file=sys.stderr)
        return 2
    cmd, rest = argv[0], [int(a) if a.isdigit() else a for a in argv[1:]]
    # connect() 自体も OperationalError を投げる（Full Disk Access が無いと開けない）。
    # try の外に出すと、いちばん多い原因のときだけ traceback になって案内が出ない。
    try:
        with connect() as c:
            CMDS[cmd](c.cursor(), *rest)
    except sqlite3.OperationalError as e:
        print(f"read error ({e}). Terminal likely lacks Full Disk Access.", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""Minimal runnable check for chat-scoped extraction.

守りたい不変条件:
  1. `chat` は指定した会話だけを返す。
  2. `with` は相手との 1:1 だけを返す。相手が参加する別グループの発言を混ぜない
     （handle だけで絞ると混入し、無関係な私信を下書きの材料にしてしまう）。
  3. `list-chats` は「最近動いた会話」順で、選べるだけの識別子を出す。
"""
import os
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path


SCRIPT = Path(__file__).with_name("imessage.py")

# chat 1: 相手(handle 1)との 1:1 / chat 2: 相手を含むグループ / chat 3: 無関係な 1:1
FIXTURE = """
CREATE TABLE message (ROWID INTEGER PRIMARY KEY, date INTEGER, is_from_me INTEGER,
  handle_id INTEGER, text TEXT, attributedBody BLOB);
CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, guid TEXT, display_name TEXT, chat_identifier TEXT);
CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
CREATE TABLE chat_handle_join (chat_id INTEGER, handle_id INTEGER);

INSERT INTO handle VALUES (1, '+819000000001'), (2, '+819000000002');

INSERT INTO chat VALUES (1, 'iMessage;-;+819000000001', '', '+819000000001');
INSERT INTO chat VALUES (2, 'iMessage;+;group-guid', '昼メシ会', 'chat999');
INSERT INTO chat VALUES (3, 'iMessage;-;+819000000002', '', '+819000000002');
INSERT INTO chat_handle_join VALUES (1, 1), (2, 1), (2, 2), (3, 2);

-- 1:1（chat 1）。送信済みの行も handle 経由ではなく chat 経由で拾えること。
INSERT INTO message VALUES (1, 1000000000, 0, 1, 'direct-incoming', NULL);
INSERT INTO message VALUES (2, 1100000000, 1, 1, 'direct-outgoing', NULL);
-- グループ（chat 2）。同じ相手の発言だが 1:1 には混ぜてはいけない。
INSERT INTO message VALUES (3, 4000000000, 0, 1, 'group-one', NULL);
INSERT INTO message VALUES (4, 4100000000, 0, 2, 'group-two', NULL);
-- 無関係な 1:1（chat 3）。
INSERT INTO message VALUES (5, 2000000000, 0, 2, 'other-chat', NULL);

INSERT INTO chat_message_join VALUES (1, 1), (1, 2), (2, 3), (2, 4), (3, 5);
"""


def read(db, *argv):
    return subprocess.run(
        [sys.executable, str(SCRIPT), *argv],
        check=True, capture_output=True, text=True,
        env={**os.environ, "IMESSAGE_DB": str(db)},
    ).stdout


def main():
    with tempfile.TemporaryDirectory() as temp:
        db = Path(temp) / "chat.db"
        with sqlite3.connect(db) as conn:
            conn.executescript(FIXTURE)

        by_chat = read(db, "chat", "iMessage;+;group-guid", "30")
        assert "group-one" in by_chat and "group-two" in by_chat, by_chat
        assert "other-chat" not in by_chat, by_chat

        direct = read(db, "with", "+819000000001", "30")
        assert "direct-incoming" in direct and "direct-outgoing" in direct, direct
        # 本命: 同じ相手のグループ発言も、別グループの他人の発言も混ざらない。
        assert "group-one" not in direct, direct
        assert "group-two" not in direct, direct
        assert "other-chat" not in direct, direct

        chats = [line.split("\t") for line in read(db, "list-chats", "10").splitlines()]
        # 最終メッセージが新しい順。chat 2 は ROWID 順では途中だが最近動いている。
        assert [c[1] for c in chats] == [
            "iMessage;+;group-guid", "iMessage;-;+819000000002", "iMessage;-;+819000000001",
        ], chats
        # GUID だけでは選べないので、名前と参加者が付いていること。
        assert chats[0][2] == "昼メシ会" and chats[0][3] == "+819000000001,+819000000002", chats[0]


if __name__ == "__main__":
    main()

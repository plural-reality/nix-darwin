#!/usr/bin/env python3
"""Minimal runnable check for group-chat extraction."""
import os
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path


SCRIPT = Path(__file__).with_name("imessage.py")


def fixture(db):
    with sqlite3.connect(db) as conn:
        conn.executescript(
            """
            CREATE TABLE message (ROWID INTEGER PRIMARY KEY, date INTEGER, is_from_me INTEGER,
              handle_id INTEGER, text TEXT, attributedBody BLOB);
            CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
            CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, guid TEXT);
            CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
            INSERT INTO handle VALUES (1, '+819000000001');
            INSERT INTO message VALUES (1, 1000000000, 1, 1, 'group-one', NULL);
            INSERT INTO message VALUES (2, 2000000000, 0, 1, 'group-two', NULL);
            INSERT INTO message VALUES (3, 3000000000, 0, 1, 'other-chat', NULL);
            INSERT INTO chat VALUES (1, 'iMessage;+;group-guid');
            INSERT INTO chat VALUES (2, 'iMessage;+;other-guid');
            INSERT INTO chat_message_join VALUES (1, 1);
            INSERT INTO chat_message_join VALUES (1, 2);
            INSERT INTO chat_message_join VALUES (2, 3);
            """
        )


def main():
    with tempfile.TemporaryDirectory() as temp:
        db = Path(temp) / "chat.db"
        fixture(db)
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "chat", "iMessage;+;group-guid", "30"],
            check=True,
            capture_output=True,
            text=True,
            env={**os.environ, "IMESSAGE_DB": str(db)},
        )
    assert "group-one" in result.stdout
    assert "group-two" in result.stdout
    assert "other-chat" not in result.stdout


if __name__ == "__main__":
    main()

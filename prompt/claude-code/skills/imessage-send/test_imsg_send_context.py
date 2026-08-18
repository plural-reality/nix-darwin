#!/usr/bin/env python3
"""Minimal runnable check for the mandatory CRM + iMessage context stream."""
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


SCRIPT = Path(__file__).with_name("imsg-send")


class StyleHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        payload = json.dumps({"contact": "Kentaro Iwata", "rules": ["brief"]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, _format, *_args):
        return None


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
            INSERT INTO message VALUES (1, 1000000000, 1, 1, 'history-message', NULL);
            INSERT INTO chat VALUES (1, 'iMessage;+;group-guid');
            INSERT INTO chat_message_join VALUES (1, 1);
            """
        )


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), StyleHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with tempfile.TemporaryDirectory() as temp:
            db = Path(temp) / "chat.db"
            fixture(db)
            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--context",
                    "--style-contact",
                    "Kentaro Iwata",
                    "--chat",
                    "iMessage;+;group-guid",
                    "+819000000001",
                ],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "BEEPER_CRM_GATEWAY": f"http://127.0.0.1:{server.server_port}",
                    "IMESSAGE_DB": str(db),
                },
            )
    finally:
        server.shutdown()
        server.server_close()
    payload = json.loads(result.stdout)
    assert payload["styleContact"] == "Kentaro Iwata"
    assert payload["style"]["rules"] == ["brief"]
    assert payload["history"][-1].endswith("history-message")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Minimal runnable check for the mandatory CRM + iMessage context stream.

守りたい不変条件:
  1. `--context` は CRM 文体と履歴を 1 行 JSON で返す。
  2. 履歴は既定で相手との 1:1 だけ。相手が参加する別グループの発言を混ぜない。
  3. `--chat` を渡したときだけ、そのグループの履歴を返す。
  4. localhost:18787 に居るのが beeper-crm-gateway でなければ成功扱いにしない（fail closed）。
"""
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
HANDLE = "+819000000001"
GROUP_GUID = "iMessage;+;group-guid"

FIXTURE = f"""
CREATE TABLE message (ROWID INTEGER PRIMARY KEY, date INTEGER, is_from_me INTEGER,
  handle_id INTEGER, text TEXT, attributedBody BLOB);
CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, guid TEXT, display_name TEXT, chat_identifier TEXT);
CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
CREATE TABLE chat_handle_join (chat_id INTEGER, handle_id INTEGER);

INSERT INTO handle VALUES (1, '{HANDLE}'), (2, '+819000000002');
INSERT INTO chat VALUES (1, 'iMessage;-;{HANDLE}', '', '{HANDLE}');
INSERT INTO chat VALUES (2, '{GROUP_GUID}', '昼メシ会', 'chat999');
INSERT INTO chat_handle_join VALUES (1, 1), (2, 1), (2, 2);

INSERT INTO message VALUES (1, 1000000000, 0, 1, 'direct-message', NULL);
INSERT INTO message VALUES (2, 4000000000, 0, 1, 'group-message', NULL);
INSERT INTO chat_message_join VALUES (1, 1), (2, 2);
"""


def gateway(service):
    """テスト用の gateway。service 名を差し替えて「別サービス」も再現する。"""
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            payload = json.dumps(
                {"ok": True, "service": service} if self.path.startswith("/healthz")
                else {"contactId": "@kentaro:beeper.local", "rules": ["brief"]}
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, _format, *_args):
            return None

    return ThreadingHTTPServer(("127.0.0.1", 0), Handler)


def context(db, server, *extra):
    return subprocess.run(
        [str(SCRIPT), "--context", "--style-contact", "Kentaro Iwata", *extra, HANDLE],
        capture_output=True, text=True,
        env={
            **os.environ,
            "BEEPER_CRM_GATEWAY": f"http://127.0.0.1:{server.server_port}",
            "IMESSAGE_DB": str(db),
        },
    )


def serving(service, body):
    server = gateway(service)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        body(server)
    finally:
        server.shutdown()
        server.server_close()


def main():
    with tempfile.TemporaryDirectory() as temp:
        db = Path(temp) / "chat.db"
        with sqlite3.connect(db) as conn:
            conn.executescript(FIXTURE)

        def checks(server):
            direct = context(db, server)
            assert direct.returncode == 0, direct.stderr
            payload = json.loads(direct.stdout)
            assert payload["styleContact"] == "Kentaro Iwata"
            assert payload["style"]["rules"] == ["brief"]
            assert any("direct-message" in line for line in payload["history"]), payload
            # 本命: 相手が入っているグループの発言は 1:1 の文脈に混ざらない。
            assert not any("group-message" in line for line in payload["history"]), payload

            grouped = context(db, server, "--chat", GROUP_GUID)
            assert grouped.returncode == 0, grouped.stderr
            history = json.loads(grouped.stdout)["history"]
            assert any("group-message" in line for line in history), history

        serving("beeper-crm-gateway", checks)

        def refuses(server):
            wrong = context(db, server)
            assert wrong.returncode != 0, wrong.stdout
            assert "not a beeper-crm-gateway" in wrong.stderr, wrong.stderr

        serving("some-other-service", refuses)


if __name__ == "__main__":
    main()

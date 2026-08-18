#!/usr/bin/env python3
"""Minimal runnable check for the mandatory CRM + bridge-history context stream."""
import json
import os
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


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), StyleHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with tempfile.TemporaryDirectory() as temp:
            history = Path(temp) / "imsg-history"
            history.write_text(
                "#!/usr/bin/env bash\n"
                "printf '%s\\n' '{\"type\":\"message\",\"message\":{\"text\":\"history-message\"}}'\n"
                "printf '%s\\n' '{\"type\":\"end\",\"ok\":true,\"count\":1}'\n"
            )
            history.chmod(0o755)
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
                    "IMSG_HISTORY": str(history),
                },
            )
    finally:
        server.shutdown()
        server.server_close()
    payload = json.loads(result.stdout)
    assert payload["styleContact"] == "Kentaro Iwata"
    assert payload["style"]["rules"] == ["brief"]
    assert payload["history"] == [{"text": "history-message"}]


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""disposable-ui 単発回収サーバ (治具第1号)

HTTP→ファイルのフィルタ: 指定HTMLを1枚だけ配信し、POST /submit を
1回受けたら回答をファイルへ書き出してサーバごと消滅する。
コンテンツは一切改変しない。状態も持たない。
"""
import argparse
import json
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--html", required=True)
parser.add_argument("--out", required=True)
parser.add_argument("--port", type=int, default=8799)
# ponytail: Bash backgroundタスクの10分timeoutより先に自死して
# 「期限切れ」を親に明示的に通知する。長時間フォームには不向き(上限=この秒数)。
parser.add_argument("--ttl", type=int, default=540)
args = parser.parse_args()

html_bytes = Path(args.html).read_bytes()
out_path = Path(args.out)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(html_bytes)
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path != "/submit":
            self.send_response(404)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        try:
            json.loads(body)  # 壊れたJSONは受け取らない
        except ValueError:
            self.send_response(400)
            self.end_headers()
            return
        out_path.write_bytes(body)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true}')
        threading.Thread(target=server.shutdown, daemon=True).start()

    def log_message(self, *_):
        pass


server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
threading.Timer(args.ttl, server.shutdown).start()
print(f"serving on http://127.0.0.1:{args.port}/ (ttl {args.ttl}s)", file=sys.stderr)
server.serve_forever()
print("collected" if out_path.exists() else "expired")

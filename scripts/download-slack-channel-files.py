import sys
import os
import argparse
import requests
import tarfile
import time
from typing import Generator, Iterator, Optional, NamedTuple
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

# --- 1. Data Structures ---
class FileMeta(NamedTuple):
    name: str
    url: str
    timestamp: str

    @property
    def safe_filename(self) -> str:
        # ディレクトリトラバーサル防止かつユニーク化
        clean_name = self.name.replace("/", "_").replace("\\", "_")
        return f"{self.timestamp}_{clean_name}"

class Config(NamedTuple):
    token: str
    channel_id: str

# --- 2. Pure Functions ---
def parse_args(args: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Stream Slack files as a tarball to stdout.")
    parser.add_argument("channel_id")
    return parser.parse_args(args)

def extract_file_meta(message: dict) -> Iterator[FileMeta]:
    if "files" not in message: return
    ts = message.get("ts", "0")
    for f in message["files"]:
        if f.get("mode") == "tombstone": continue
        url = f.get("url_private_download")
        name = f.get("name", "untitled")
        if url:
            yield FileMeta(name=name, url=url, timestamp=ts)

def get_token_from_stdin() -> Optional[str]:
    if not sys.stdin.isatty():
        return sys.stdin.read().strip()
    return os.environ.get("SLACK_BOT_TOKEN")

# --- 3. Stream Generator ---
def stream_history(client: WebClient, channel_id: str) -> Generator[dict, None, None]:
    cursor = None
    while True:
        response = client.conversations_history(channel=channel_id, cursor=cursor, limit=100)
        yield from response.get("messages", [])
        if not response.get("has_more"): break
        cursor = response["response_metadata"]["next_cursor"]

# --- 4. Stream Processor (The Tar Packer) ---
def pipe_to_tar(meta: FileMeta, token: str, tar: tarfile.TarFile) -> None:
    """HTTPストリームを読みながら、Tarストリームに梱包して送出する"""
    headers = {"Authorization": f"Bearer {token}"}

    # stream=True でヘッダーだけ先に取得
    try:
        with requests.get(meta.url, headers=headers, stream=True) as r:
            if r.status_code != 200:
                print(f"Skipping {meta.safe_filename}: HTTP {r.status_code}", file=sys.stderr)
                return

            # Tarヘッダーを作成するには、事前にファイルサイズが必要
            content_length = r.headers.get("Content-Length")
            if content_length is None:
                print(f"Skipping {meta.safe_filename}: No Content-Length header", file=sys.stderr)
                return

            size = int(content_length)

            # TarInfoの作成
            info = tarfile.TarInfo(name=meta.safe_filename)
            info.size = size
            info.mtime = int(float(meta.timestamp)) # タイムスタンプも維持

            print(f"Archiving: {meta.safe_filename} ({size} bytes)", file=sys.stderr)

            # rawソケットからTarストリームへ直結 (メモリに溜めない)
            tar.addfile(tarinfo=info, fileobj=r.raw)

    except Exception as e:
        print(f"Error processing {meta.safe_filename}: {e}", file=sys.stderr)

# --- 5. Main Wiring ---
def main():
    # Stdoutがターミナルに繋がっている場合はバイナリを流さない (文字化け防止)
    if sys.stdout.isatty():
        print("Error: You must pipe the output to a file or command (e.g., > output.tar)", file=sys.stderr)
        sys.exit(1)

    args = parse_args(sys.argv[1:])
    token = get_token_from_stdin()

    if not token:
        print("Error: Token required via stdin or env var.", file=sys.stderr)
        sys.exit(1)

    client = WebClient(token=token)

    # stdout.buffer を 'w|' (ストリーム書き込みモード) で開く
    with tarfile.open(fileobj=sys.stdout.buffer, mode="w|") as tar:
        try:
            messages = stream_history(client, args.channel_id)
            files = (meta for msg in messages for meta in extract_file_meta(msg))

            for meta in files:
                pipe_to_tar(meta, token, tar)

        except SlackApiError as e:
            print(f"API Error: {e}", file=sys.stderr)
            sys.exit(1)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""FTS5 session history search across Claude Code JSONL transcripts.

Usage:
  session-search.py <query>          Search all sessions
  session-search.py --rebuild        Force rebuild index
  session-search.py -i <query>       Interactive (fzf) search

Storage: ~/.claude/.session-search.db (SQLite FTS5, trigram tokenizer for CJK)
"""

import json
import sqlite3
import sys
import os
import glob
from pathlib import Path

CLAUDE_DIR = Path.home() / ".claude"
PROJECTS_DIR = CLAUDE_DIR / "projects"
DB_PATH = CLAUDE_DIR / ".session-search.db"


def init_db(conn: sqlite3.Connection) -> None:
    conn.execute("""
        CREATE TABLE IF NOT EXISTS files (
            path TEXT PRIMARY KEY,
            mtime REAL
        )
    """)
    conn.execute("DROP TABLE IF EXISTS messages_fts")
    conn.execute("""
        CREATE VIRTUAL TABLE messages_fts USING fts5(
            content,
            project UNINDEXED,
            session_id UNINDEXED,
            role UNINDEXED,
            line_no UNINDEXED,
            tokenize='trigram'
        )
    """)


def extract_text(msg: dict) -> str:
    content = msg.get("message", {}).get("content", "")
    if isinstance(content, str):
        return content[:5000]
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                text = block.get("text", "")[:3000]
                if text.strip():
                    parts.append(text)
        return "\n".join(parts)[:5000]
    return ""


def index_file(conn: sqlite3.Connection, filepath: str, mtime: float) -> None:
    project = Path(filepath).parent.name.replace("-Users-tkgshn", "~").replace("-", "/")
    session_id = Path(filepath).stem
    with open(filepath) as f:
        for line_no, raw_line in enumerate(f, 1):
            stripped = raw_line.strip()
            if not stripped:
                continue
            try:
                msg = json.loads(stripped)
            except (json.JSONDecodeError, ValueError):
                continue
            role = msg.get("type", "")
            if role not in ("human", "assistant"):
                continue
            text = extract_text(msg)
            if not text.strip():
                continue
            conn.execute(
                "INSERT INTO messages_fts(content, project, session_id, role, line_no) VALUES (?, ?, ?, ?, ?)",
                (text, project, session_id, role, line_no),
            )
    conn.execute(
        "INSERT OR REPLACE INTO files(path, mtime) VALUES (?, ?)",
        (filepath, mtime),
    )


def rebuild_index(conn: sqlite3.Connection, force: bool = False) -> int:
    if force:
        init_db(conn)
    indexed = 0
    pattern = str(PROJECTS_DIR / "*" / "*.jsonl")
    for filepath in sorted(glob.glob(pattern)):
        stat = os.stat(filepath)
        row = conn.execute("SELECT mtime FROM files WHERE path = ?", (filepath,)).fetchone()
        if row is not None and not force and abs(row[0] - stat.st_mtime) < 1.0:
            continue
        # Delete old entries for this file before re-indexing
        session_id = Path(filepath).stem
        conn.execute(
            "DELETE FROM messages_fts WHERE session_id = ? AND project = ?",
            (session_id, Path(filepath).parent.name.replace("-Users-tkgshn", "~").replace("-", "/")),
        )
        index_file(conn, filepath, stat.st_mtime)
        indexed += 1
    conn.commit()
    return indexed


def search(conn: sqlite3.Connection, query: str, limit: int = 20) -> list[dict]:
    results = conn.execute(
        """
        SELECT snippet(messages_fts, 0, '→', '←', '…', 12),
               project, session_id, role, line_no
        FROM messages_fts
        WHERE messages_fts MATCH ?
        ORDER BY rank LIMIT ?
        """,
        (query, limit),
    ).fetchall()
    return [
        {"snippet": r[0], "project": r[1], "session_id": r[2], "role": r[3], "line_no": r[4]}
        for r in results
    ]


def main() -> None:
    args = sys.argv[1:]
    rebuild_flag = "--rebuild" in args
    interactive = "-i" in args
    query_args = [a for a in args if a not in ("--rebuild", "-i")]

    conn = sqlite3.connect(str(DB_PATH))
    try:
        init_db(conn)
        n = rebuild_index(conn, force=rebuild_flag)

        if not query_args:
            print(f"Indexed {n} new/updated files.")
            return

        query = " ".join(query_args)
        results = search(conn, query)

        if interactive and results and sys.stdout.isatty():
            import subprocess
            lines = [f"{r['project']}/{r['session_id'][:8]} [{r['role']}] {r['snippet']}" for r in results]
            proc = subprocess.run(["fzf"], input="\n".join(lines), capture_output=True, text=True)
            if proc.returncode == 0 and proc.stdout.strip():
                idx = lines.index(proc.stdout.strip()) if proc.stdout.strip() in lines else 0
                sid = results[idx]["session_id"]
                print(f"Resume: cr {sid}")
            return

        if not results:
            print(f"No results for: {query}")
            return

        for r in results:
            proj = r["project"]
            sid = r["session_id"][:8]
            role = "H" if r["role"] == "human" else "A"
            snippet = r["snippet"].replace("\n", " ")[:200]
            print(f"[{proj}/{sid} {role}] {snippet}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()

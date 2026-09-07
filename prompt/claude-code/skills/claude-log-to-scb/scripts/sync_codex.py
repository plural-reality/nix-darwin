#!/usr/bin/env python3
"""Serialize host-local ingestion. Only an explicit source allowlist may project."""
import argparse
import fcntl
import json
from pathlib import Path
import subprocess
import sys

from projection import DEFAULT_LEDGER
from sessions import CACHE_DIR, CODEX_EXTRACTED

SELECTED_SNAPSHOT_ROOT = str(Path(CACHE_DIR, 'codex-projection-v2'))


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('--uuid', action='append')
    parser.add_argument('--allowlist', default=str(Path(DEFAULT_LEDGER, 'allowlist.json')))
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--force', action='store_true')
    parser.add_argument('--limit', type=int, default=0)
    args = parser.parse_args(argv)
    selected = args.uuid
    if selected is None:
        try:
            selected = json.loads(Path(args.allowlist).read_text())
        except FileNotFoundError:
            print('projection pending: explicit source allowlist required; no source was written', file=sys.stderr)
            return 75
    if not isinstance(selected, list) or any(not isinstance(item, str) or not item.startswith('codex-') or Path(item).name != item for item in selected):
        parser.error('allowlist must contain Codex source UUID strings')
    selected = list(dict.fromkeys(selected))
    if args.limit < 0:
        parser.error('limit must be non-negative')
    selected = selected[:args.limit] if args.limit else selected
    if not selected:
        print('projection: empty allowlist; nothing selected', file=sys.stderr)
        return 0
    selection = [argument for item in selected for argument in ('--uuid', item)]
    scripts = Path(__file__).resolve().parent
    snapshot = Path(SELECTED_SNAPSHOT_ROOT)
    def run():
        if args.dry_run:
            # A dry-run does not build archives, call an LLM, or alter the ledger.
            print(json.dumps({'status': 'planned', 'source_uuids': selected,
                              'scope': 'selected', 'unselected_sources': 'not_inspected',
                              'steps': ['build_selected_snapshot', 'extract_changed_revisions', 'verify_projection']}, ensure_ascii=False))
            return 0
        commands = [
            [sys.executable, str(scripts / 'sessions.py'), 'build', '--source', 'codex',
             '--output-root', str(snapshot), *selection],
            [sys.executable, str(scripts / 'extract.py'), '--conv-dir', str(snapshot / 'compact'),
             '--out', CODEX_EXTRACTED, '--workers', '1', *selection, *(['--force'] if args.force else [])],
            [sys.executable, str(scripts / 'projection.py'), '--archive', str(snapshot / 'archive' / 'conversations.json'),
             '--conv-dir', str(snapshot / 'compact'), '--extracted', CODEX_EXTRACTED, *selection],
        ]
        for command in commands:
            result = subprocess.run(command)
            if result.returncode:
                return result.returncode
        return 0
    if args.dry_run:
        return run()
    lock_path = Path(DEFAULT_LEDGER, 'sync.lock')
    lock_path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with open(lock_path, 'a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 75
        return run()


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

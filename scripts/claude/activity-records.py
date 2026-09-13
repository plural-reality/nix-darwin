#!/usr/bin/env python3
"""Immutable, private activity evidence. Never publishes or copies credentials."""
import argparse
import contextlib
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import tempfile
import time
from zoneinfo import ZoneInfo

JST = ZoneInfo('Asia/Tokyo')
SOURCES = ('mori', 'codex', 'scrapbox')
DEADLINE = time.monotonic() + 1800
TERM = re.compile(r'音威子府|otoineppu', re.I)


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n').encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, tmp = tempfile.mkstemp(prefix='.partial-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, path)
    finally:
        Path(tmp).unlink(missing_ok=True)


def immutable(directory, value):
    data = encoded(value)
    key = digest(data)
    path = directory / (key + '.json')
    if path.exists():
        if path.read_bytes() != data:
            raise ValueError('existing object is corrupt')
    else:
        atomic(path, data)
    return key


def checked(directory, key):
    if not re.fullmatch('[0-9a-f]{64}', key):
        raise ValueError('invalid digest')
    target = directory / (key + '.json')
    if target.is_symlink() or directory.is_symlink() or directory.parent.is_symlink():
        raise ValueError('symlink input forbidden')
    data = target.read_bytes()
    if digest(data) != key:
        raise ValueError('hash mismatch')
    return json.loads(data)


def run_json(args):
    for attempt in range(3):
        if time.monotonic() >= DEADLINE:
            raise RuntimeError("collection_deadline")
        try:
            result = subprocess.run(args, capture_output=True, timeout=90, check=False)
        except FileNotFoundError:
            raise RuntimeError('tool_unavailable') from None
        except subprocess.TimeoutExpired:
            if attempt == 2:
                raise RuntimeError('timeout') from None
        else:
            if result.returncode == 0:
                return json.loads(result.stdout)
            if result.returncode == 2:
                raise RuntimeError('authentication_or_usage_required')
            if attempt == 2:
                raise RuntimeError('source_failed_exit_' + str(result.returncode))
        time.sleep(2 ** attempt)


def mori(start, end, cutoff):
    sessions = run_json(['mori', 'sessions', '--from', start, '--to', end])
    for session in sessions:
        if not TERM.search(json.dumps(session, ensure_ascii=False)):
            continue  # Do not retrieve unrelated conversations.
        # Re-fetch in the reconciliation window: a cached transcript may change.
        if session.get('ended_at') and timestamp(session['ended_at']) > timestamp(cutoff):
            raise RuntimeError('session_crosses_cutoff')
        transcript = run_json(['mori', 'transcript', str(session['id'])])
        if TERM.search(json.dumps(transcript, ensure_ascii=False)):
            yield {'source': 'mori', 'id': str(session['id']),
                   'activityAt': session.get('started_at'), 'content': transcript}


def scrapbox(start, end, cutoff):
    limited = False
    for project in ('plural-reality', 'tkgshn-private', 'takalog'):
        found = run_json(['cosense-fetch', '-s', '音威子府', '-p', project, '-l', '100'])
        pages = found['pages']
        limited = limited or len(pages) >= 100
        for page in pages:
            if page.get('updated') and float(page['updated']) < timestamp(start + 'T00:00:00+09:00'):
                continue
            title = page['title']
            body = run_json(['cosense-fetch', '-r', title, '-p', project])
            if body.get('updated') and float(body['updated']) > timestamp(cutoff):
                raise RuntimeError('page_updated_after_cutoff')
            yield {'source': 'scrapbox', 'id': project + '/' + str(body['id']), 'title': title,
                   'activityAt': None, 'updatedAt': body.get('updated'), 'content': body}

    if limited:
        raise RuntimeError('search_limit_reached')

def codex(start, end, cutoff):
    # This adapter is strictly host-local. Only selected messages leave this tree.
    base = Path.home() / '.codex'
    for folder in ('sessions', 'archived_sessions'):
        for path in sorted((base / folder).glob('**/*.jsonl')):
            if time.monotonic() >= DEADLINE:
                raise RuntimeError('collection_deadline')
            if path.stat().st_mtime < timestamp(start + 'T00:00:00+09:00'):
                continue
            selected = []
            session_id = None
            with path.open() as stream:
                for line in stream:
                    if time.monotonic() >= DEADLINE:
                        raise RuntimeError('collection_deadline')
                    try:
                        event = json.loads(line)
                    except json.JSONDecodeError:
                        continue  # live writer may not have finished the last line
                    payload = event.get('payload', {})
                    if event.get('type') == 'session_meta':
                        session_id = payload.get('id')
                    if event.get('type') != 'event_msg':
                        continue
                    event_time = event.get('timestamp', '')
                    try:
                        day = dt.datetime.fromisoformat(event_time.replace('Z', '+00:00')).astimezone(JST).date().isoformat()
                    except ValueError:
                        continue
                    if event_time and dt.datetime.fromisoformat(event_time.replace('Z', '+00:00')).timestamp() > dt.datetime.fromisoformat(cutoff).timestamp():
                        continue
                    if not start <= day <= end:
                        continue
                    if payload.get('type') not in ('user_message', 'agent_message'):
                        continue
                    message = payload.get('message', '')
                    if TERM.search(message):
                        selected.append({'at': event_time, 'role': payload['type'],
                                         'text': message, 'phase': payload.get('phase')})
            if selected and session_id:
                yield {'source': 'codex', 'id': session_id, 'activityAt': None,
                       'content': selected, 'coverage': 'keyword-selected messages; not full conversation; claims are not verified outcomes'}


@contextlib.contextmanager
def lock(state):
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state / 'lock').open('a') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


def timestamp(value):
    return dt.datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()


def collect(root, state, host, day, cutoff=None):
    end = dt.date.fromisoformat(day)
    cutoff = cutoff or min(dt.datetime.combine(end, dt.time.max, JST), dt.datetime.now(JST)).isoformat()
    if dt.datetime.fromisoformat(cutoff).tzinfo is None:
        raise ValueError('cutoff requires timezone')
    start = min(end.replace(day=1), end - dt.timedelta(days=6)).isoformat()
    namespace = root / host
    refs, statuses = [], {}
    for source, adapter in zip(SOURCES, (mori, codex, scrapbox)):
        try:
            for record in adapter(start, day, cutoff):
                key = immutable(namespace / 'objects', record)
                refs.append({'source': source, 'id': record['id'], 'hash': key})
            statuses[source] = 'collected'
        except (RuntimeError, ValueError, OSError, KeyError, TypeError) as error:
            # Never persist stderr, environment, or authentication responses.
            statuses[source] = str(error) if isinstance(error, RuntimeError) else type(error).__name__
    snapshot = {'schema': 1, 'host': host, 'day': day, 'windowStart': start, 'cutoff': cutoff,
                'sources': statuses, 'records': sorted(refs, key=lambda r: (r['source'], r['id'])),
                'scope': 'otoineppu; keyword scoped; source completeness not guaranteed'}
    key = immutable(namespace / 'snapshots', snapshot)
    immutable(namespace / 'receipts', {'snapshot': key, 'observedAt': now(),
                                      'freeBytes': shutil.disk_usage(root).free})
    observed = {}
    for receipt_path in (namespace / 'receipts').glob('*.json'):
        receipt = checked(namespace / 'receipts', receipt_path.stem)
        observed[receipt['snapshot']] = max(observed.get(receipt['snapshot'], ''), receipt['observedAt'])
    prior = []
    for path in (namespace / 'snapshots').glob('*.json'):
        candidate = checked(namespace / 'snapshots', path.stem)
        if candidate['day'] < day:
            prior.append((candidate['day'] + observed.get(path.stem, ''), path.stem, candidate))
    previous = sorted(prior)[-1] if prior else None
    delta = make_diff(previous[2]['records'] if previous else [], snapshot['records'])
    diff_key = immutable(namespace / 'diffs', {'snapshot': key,
        'previous': previous[1] if previous else None, 'changes': delta,
        'missingMeaning': 'not observed in this window; never proof of deletion'})
    return {'snapshot': key, 'diff': diff_key, 'sources': statuses, 'records': len(refs)}


def make_diff(before, after):
    old = {(row['source'], row['id']): row['hash'] for row in before}
    new = {(row['source'], row['id']): row['hash'] for row in after}
    return [{'source': source, 'id': identity, 'before': old.get((source, identity)),
             'after': new.get((source, identity)),
             'kind': 'not_observed' if (source, identity) not in new else
                     'added' if (source, identity) not in old else 'changed'}
            for source, identity in sorted(old.keys() | new.keys())
            if old.get((source, identity)) != new.get((source, identity))]


def verify(root):
    count = 0
    for namespace in sorted(root.iterdir()):
        if not namespace.is_dir() or namespace.name.startswith('.'):
            continue
        for kind in ('objects', 'snapshots', 'receipts', 'months', 'diffs', 'drafts'):
            for path in sorted((namespace / kind).glob('*.json')):
                value = checked(namespace / kind, path.stem)
                if kind == 'snapshots':
                    for ref in value['records']:
                        checked(namespace / 'objects', ref['hash'])
                if kind == 'drafts':
                    checked(namespace / 'months', value['inputVersion'])
                if kind == 'diffs':
                    checked(namespace / 'snapshots', value['snapshot'])
                    if value['previous']:
                        checked(namespace / 'snapshots', value['previous'])
                if kind == 'receipts':
                    checked(namespace / 'snapshots', value['snapshot'])
                if kind == 'months':
                    for key in value['snapshots']:
                        checked(root / value['sourceHost'] / 'snapshots', key)
                count += 1
    if count == 0:
        raise ValueError('no verified input')
    return count


def inventory(root):
    return {str(p.relative_to(root)): digest(p.read_bytes()) for p in sorted(root.glob('*/*/*.json'))}


def backup(root, destination):
    if root.resolve() == destination.resolve() or root.resolve() in destination.resolve().parents:
        raise ValueError('backup must be outside synchronized root')
    verify(root)
    before = inventory(root)
    key = digest(encoded(before))
    target = destination / key
    if target.exists():
        if inventory(target) != before:
            raise ValueError('existing backup corrupt')
        return {'generation': key, 'files': len(before), 'verifiedAt': now()}
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    temp = Path(tempfile.mkdtemp(prefix='.partial-', dir=destination))
    try:
        for relative in before:
            src, dst = root / relative, temp / relative
            dst.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            shutil.copyfile(src, dst)
            dst.chmod(0o600)
        verify(temp)
        if inventory(temp) != before or inventory(root) != before:
            raise ValueError('input changed during backup; retry')
        temp.rename(target)
    finally:
        if temp.exists():
            shutil.rmtree(temp)
    return {'generation': key, 'files': len(before), 'verifiedAt': now()}


def prepare(root, host, source_host, month, snapshots):
    dt.date.fromisoformat(month + '-01')
    chosen = [checked(root / source_host / 'snapshots', key) for key in sorted(set(snapshots))]
    if len({row['day'] for row in chosen}) != len(chosen):
        raise ValueError('select exactly one version per day')
    if not chosen or any(not row['day'].startswith(month) for row in chosen):
        raise ValueError('select snapshots within target month')
    for row in chosen:
        for ref in row['records']:
            checked(root / source_host / 'objects', ref['hash'])
    bundle = {'schema': 1, 'month': month, 'authorHost': host, 'sourceHost': source_host,
              'snapshots': sorted(set(snapshots)), 'publication': 'approval-required',
              'titlePrefix': str(int(month[5:])) + '月活動記録: ',
              'cutoff': max(row.get('cutoff', row['day']) for row in chosen),
              'sources': [row['sources'] for row in chosen],
              'instruction': '音威子府だけの参考稿。出典別に相談・実装・検証・公開を区別。更新日は活動日ではない。同じ出来事を根拠付きで統合。欠測と収集範囲を明示し、本文と根拠対応表をこのタスクに提示。承認前は公開しない。'}
    key = immutable(root / host / 'months', bundle)
    return {'inputVersion': key, 'bundle': bundle}


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--state', type=Path, required=True)
    parser.add_argument('--host', required=True, choices=['tkgshn-mac-mini', 'tkgshn-MacBook-Air'])
    sub = parser.add_subparsers(dest='command', required=True)
    capture = sub.add_parser('collect')
    capture.add_argument('--date', default=(dt.datetime.now(JST).date() - dt.timedelta(days=1)).isoformat())
    capture.add_argument('--cutoff', help='ISO-8601 timestamp with timezone; immutable source cutoff')
    sub.add_parser('verify')
    sub.add_parser('index')
    sub.add_parser('status')
    delta = sub.add_parser('diff')
    delta.add_argument('--source-host', required=True, choices=['tkgshn-mac-mini', 'tkgshn-MacBook-Air'])
    delta.add_argument('--before', required=True)
    delta.add_argument('--after', required=True)
    draft = sub.add_parser('save-draft')
    draft.add_argument('--input-version', required=True)
    draft.add_argument('--text', type=Path, required=True)
    draft.add_argument('--evidence', type=Path, required=True)
    back = sub.add_parser('backup')
    back.add_argument('--destination', type=Path, required=True)
    restore = sub.add_parser('restore')
    restore.add_argument('--destination', type=Path, required=True)
    month = sub.add_parser('prepare-month')
    month.add_argument('--month', required=True)
    month.add_argument('--source-host', required=True, choices=['tkgshn-mac-mini', 'tkgshn-MacBook-Air'])
    month.add_argument('--snapshot', action='append', required=True)
    args = parser.parse_args()
    if args.root.resolve() == args.state.resolve() or args.root.resolve() in args.state.resolve().parents:
        raise ValueError('state must be outside synchronized root')
    with lock(args.state):
        if args.command == 'collect':
            result = collect(args.root, args.state, args.host, args.date, args.cutoff)
        elif args.command == 'verify':
            result = {'files': verify(args.root), 'verifiedAt': now()}
        elif args.command == 'status':
            result = {name: json.loads(path.read_text()) if path.exists() else None
                for name in ('collect', 'backup')
                for path in [args.state / ('last-' + name + '.json')]}
            result['freeBytes'] = shutil.disk_usage(args.state).free
            result['storedBytes'] = sum(path.stat().st_size for path in args.root.glob('*/*/*.json'))
        elif args.command == 'diff':
            directory = args.root / args.source_host / 'snapshots'
            before = checked(directory, args.before)
            after = checked(directory, args.after)
            for ref in before['records'] + after['records']:
                checked(args.root / args.source_host / 'objects', ref['hash'])
            result = make_diff(before['records'], after['records'])
        elif args.command == 'index':
            verify(args.root)
            target = args.state / 'index.sqlite'
            temp = args.state / 'index.partial.sqlite'
            temp.unlink(missing_ok=True)
            with sqlite3.connect(temp) as db:
                db.execute('CREATE TABLE records(host TEXT, hash TEXT, source TEXT, id TEXT, content TEXT, PRIMARY KEY(host,hash))')
                for namespace in args.root.iterdir():
                    for path in (namespace / 'objects').glob('*.json'):
                        value = checked(namespace / 'objects', path.stem)
                        db.execute('INSERT INTO records VALUES(?,?,?,?,?)', (namespace.name, path.stem, value['source'], value['id'], json.dumps(value, ensure_ascii=False)))
                count = db.execute('SELECT count(*) FROM records').fetchone()[0]
            os.replace(temp, target)
            result = {'indexedRecords': count}
        elif args.command == 'save-draft':
            checked(args.root / args.host / 'months', args.input_version)
            result = {'draftVersion': immutable(args.root / args.host / 'drafts', {
                'inputVersion': args.input_version, 'authorHost': args.host,
                'publication': 'approval-required', 'text': args.text.read_text(),
                'evidence': args.evidence.read_text()})}
        elif args.command == 'backup':
            result = backup(args.root, args.destination)
        elif args.command == 'restore':
            if args.destination.exists():
                raise ValueError('restore destination must not exist')
            verify(args.root)
            args.destination.parent.mkdir(parents=True, exist_ok=True)
            staging = Path(tempfile.mkdtemp(prefix='.partial-', dir=args.destination.parent))
            try:
                shutil.copytree(args.root, staging, dirs_exist_ok=True)
                verify(staging)
                if inventory(args.root) != inventory(staging):
                    raise ValueError('restore mismatch')
                staging.rename(args.destination)
            finally:
                if staging.exists():
                    shutil.rmtree(staging)
            result = {'restoredFiles': len(inventory(args.destination))}
        else:
            result = prepare(args.root, args.host, args.source_host, args.month, args.snapshot)
        atomic(args.state / ('last-' + args.command + '.json'), encoded(result))
        print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()

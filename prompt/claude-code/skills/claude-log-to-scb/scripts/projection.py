#!/usr/bin/env python3
"""Source-bound Codex projection; explicit canaries, durable receipts, verified writes.

Raw rollouts remain host-local. The ledger is durable operational state, not a
rebuildable cache. Preserve/back up this directory when moving writer ownership.
"""
import argparse
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.parse import quote

from extract import extraction_revision

VERSION = 'codex-projection-v2'
DEFAULT_LEDGER = os.path.expanduser('~/.claude/data/knowledge-projection/codex-v2')


def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()


def escaped(value):
    return str(value).replace('[', '［').replace(']', '］').replace('\r', '').replace('\n', ' ')


def atomic_json(path, value):
    temporary = path.with_suffix('.tmp')
    with open(temporary, 'w', opener=lambda name, flags: os.open(name, flags, 0o600)) as output:
        json.dump(value, output, ensure_ascii=False)
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, path)


def date_label(timestamp):
    date = datetime.datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
    local = date.astimezone(datetime.timezone(datetime.timedelta(hours=9)))
    return f'{local.year}/{local.month}/{local.day}'


def render_source(conv, compact, extracted):
    source = conv['_source_key']
    if conv.get('_session_kind') != 'human_session':
        raise ValueError('source is not a conversation candidate')
    if extracted.get('source_version') != conv['_source_version'] or extracted.get('extraction_revision') != extraction_revision(compact, extracted.get('engine', 'codex'), extracted.get('model')):
        raise ValueError('extraction is stale or unversioned')
    if conv.get('_provenance', {}).get('malformed_lines', 0):
        raise ValueError('source acquisition is partial')
    day = date_label(conv['created_at'])
    native = conv['_provenance']['native_id']
    name = ' '.join(escaped(extracted.get('ja_title') or conv.get('name', '会話')).split())[:42]
    # Full UUID makes creation collisions independent of titles/ordering/batch size.
    title = f'{day} {name} · Codex {native}'
    lines = [f'[( kb:begin {source}]', '[Codexセッション]', f'[{day}]',
             '[( [codex.icon] 原文から作成した要約。人物の同一性や提案の採用は未確定。]',
             f'[( source: {source}]', f'[( source_revision: {conv["_source_version"]}]',
             f'[( extraction_revision: {extracted["extraction_revision"]}]',
             '[(* 要約]']
    lines += [f'[( {escaped(line)}]' for line in extracted['ja_summary'].splitlines() if line.strip()]
    for field, label in [('decisions', '原文にある決定'), ('commitments', '原文にある約束・TODO候補')]:
        if extracted.get(field):
            lines += [f'[(* {label}]'] + [f'[( {escaped(item)}]' for item in extracted[field]]
    entities = list(dict.fromkeys(conv.get('_entities', []) + extracted.get('projects', []) + extracted.get('people', [])))[:20]
    if entities:
        lines += ['[( 関連候補: ' + ' '.join(f'[{escaped(entity)}]' for entity in entities) + ']']
    coverage = compact.get('transcript_coverage', {})
    lines += [f'[( 要約入力範囲: {escaped(json.dumps(coverage, ensure_ascii=False, separators=(",", ":")))}]',
              f'[( 原本: {escaped(conv.get("_origin", ""))}]',
              '[( 原文は元ホストに保存。本文をこのページへ全文転載していない。]',
              f'[( kb:end {source}]']
    return title, lines


def fetch_page(project, title):
    try:
        result = subprocess.run(['cosense-fetch', '-r', title, '-p', project],
                                capture_output=True, text=True, timeout=45)
        if result.returncode:
            return {'status': 'unavailable', 'reason': 'fetch_failed'}
        data = json.loads(result.stdout)
        lines = [line['text'] for line in data['lines']]
        if data.get('title') != title or not lines or lines[0] != title or any(not isinstance(line, str) for line in lines):
            return {'status': 'unavailable', 'reason': 'invalid_page'}
        if data.get('persistent') is False:
            return {'status': 'absent', 'lines': [title], 'page_id': None}
        if data.get('persistent') is not True or not isinstance(data.get('id'), str):
            return {'status': 'unavailable', 'reason': 'invalid_identity'}
        return {'status': 'found', 'page_id': data['id'], 'lines': lines, 'commit_id': data.get('commitId')}
    except (OSError, subprocess.TimeoutExpired, ValueError, KeyError, TypeError):
        return {'status': 'unavailable', 'reason': 'fetch_unverified'}


def merge_owned(current, previous, desired, source):
    start, end = f'[( kb:begin {source}]', f'[( kb:end {source}]'
    if current.count(start) != 1 or current.count(end) != 1:
        raise ValueError('owned block missing or ambiguous')
    left, right = current.index(start), current.index(end)
    if right < left or current[left:right+1] != previous:
        raise ValueError('owned block was edited; reconcile before writing')
    return current[:left] + desired + current[right+1:]


def write_page(project, title, lines, expected, page_id):
    command = ['scrapbox-write', '-p', project, '-t', title, '--mode', 'replace',
               '--verbatim', '--expect-sha256', expected]
    if page_id:
        command += ['--expect-page-id', page_id]
    try:
        result = subprocess.run(command, input='\n'.join(lines[1:]), capture_output=True,
                                text=True, timeout=90)
        return {'status': 'submitted' if result.returncode == 0 else 'unverified'}
    except (OSError, subprocess.TimeoutExpired):
        return {'status': 'unverified'}


def project_one(conv, compact, extracted, project, ledger_dir, dry_run=False,
                fetch=fetch_page, write=write_page):
    title, owned = render_source(conv, compact, extracted)
    source = conv['_source_key']
    ledger_dir = Path(ledger_dir)
    receipt_path = ledger_dir / (digest([project, source]) + '.json')
    previous = json.loads(receipt_path.read_text()) if receipt_path.exists() else None
    if previous:
        if previous.get('source_key') != source or previous.get('project') != project:
            raise ValueError('invalid source binding')
        title = previous['title']
    current = fetch(project, title)
    if current['status'] == 'unavailable':
        return {'status': 'unavailable', 'source_key': source}
    # A submitted intent is reconciled before another operation is attempted.
    if previous and previous['state'] == 'prepared':
        if current['status'] == 'found' and digest(current['lines']) == previous['desired_hash'] and (previous.get('page_id') in (None, current['page_id'])):
            previous = {**previous, 'state': 'verified', 'page_id': current['page_id'],
                        'owned_lines': previous['desired_owned_lines']}
            if not dry_run:
                atomic_json(receipt_path, previous)
        else:
            return {'status': 'conflict', 'reason': 'pending_operation_requires_reconciliation', 'source_key': source}
    if previous and previous.get('page_id'):
        if current['status'] != 'found' or current['page_id'] != previous['page_id']:
            return {'status': 'conflict', 'reason': 'page_identity_changed', 'source_key': source}
        try:
            desired = merge_owned(current['lines'], previous['owned_lines'], owned, source)
        except ValueError:
            return {'status': 'conflict', 'reason': 'owned_block_changed', 'source_key': source}
    elif current['status'] == 'found':
        return {'status': 'conflict', 'reason': 'unbound_existing_page', 'source_key': source}
    else:
        desired = [title, *owned]
    desired_hash = digest(desired)
    if current['status'] == 'found' and desired == current['lines']:
        return {'status': 'verified', 'changed': False, 'page_id': current['page_id'], 'source_key': source, 'title': title}
    operation = digest([VERSION, project, source, current.get('page_id'), digest(current['lines']), desired_hash])
    if dry_run:
        return {'status': 'planned', 'source_key': source, 'title': title,
                'operation_id': operation, 'desired_hash': desired_hash, 'line_count': len(desired)}
    intent = {'schema': VERSION, 'state': 'prepared', 'project': project, 'source_key': source,
              'title': title, 'page_id': current.get('page_id'), 'operation_id': operation,
              'source_version': conv['_source_version'], 'expected_hash': digest(current['lines']),
              'desired_hash': desired_hash, 'owned_lines': (previous or {}).get('owned_lines', []),
              'desired_owned_lines': owned, 'before_lines': current['lines'], 'desired_lines': desired}
    atomic_json(receipt_path, intent)
    write(project, title, desired, intent['expected_hash'], current.get('page_id'))
    observed = fetch(project, title)
    if observed['status'] != 'found' or observed['lines'] != desired or (current.get('page_id') not in (None, observed.get('page_id'))):
        return {'status': 'unverified', 'source_key': source, 'operation_id': operation}
    atomic_json(receipt_path, {**intent, 'state': 'verified', 'page_id': observed['page_id'], 'owned_lines': owned})
    return {'status': 'verified', 'changed': True, 'source_key': source, 'page_id': observed['page_id'],
            'title': title, 'url': f'https://scrapbox.io/{project}/{quote(title, safe="")}', 'operation_id': operation}


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument('--archive', required=True)
    parser.add_argument('--conv-dir', required=True)
    parser.add_argument('--extracted', required=True)
    parser.add_argument('--ledger', default=DEFAULT_LEDGER)
    parser.add_argument('--project', choices=('takalog',), default='takalog')
    parser.add_argument('--uuid', action='append', required=True, help='Explicit source canary; no implicit mass migration')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args(argv)
    convs = json.loads(Path(args.archive).read_text())
    selected = [conv for conv in convs if conv['uuid'] in args.uuid]
    if len(selected) != len(set(args.uuid)):
        parser.error('every selected source must resolve exactly once')
    extracted = {}
    for line in Path(args.extracted).read_text().splitlines():
        item = json.loads(line)
        extracted.setdefault(item['uuid'], []).append(item)
    def run():
        outcomes = []
        for conv in selected:
            try:
                compact = json.loads(Path(args.conv_dir, conv['uuid'] + '.json').read_text())
                matching = [item for item in extracted.get(conv['uuid'], []) if item.get('extraction_revision') == extraction_revision(compact, item.get('engine', 'codex'), item.get('model'))]
                if not matching:
                    raise ValueError('matching extraction revision unavailable')
                result = project_one(conv, compact, matching[-1], args.project, args.ledger, args.dry_run)
            except (ValueError, KeyError, OSError) as error:
                result = {'status': 'unavailable', 'source_key': conv.get('_source_key'), 'reason': type(error).__name__}
            outcomes.append(result)
            print(json.dumps(result, ensure_ascii=False))
        return 0 if all(item['status'] in ('verified', 'planned') for item in outcomes) else 1
    if args.dry_run:
        return run()
    ledger = Path(args.ledger)
    ledger.mkdir(parents=True, exist_ok=True, mode=0o700)
    with open(ledger / 'writer.lock', 'a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 75
        return run()


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

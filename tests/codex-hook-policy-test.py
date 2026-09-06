#!/usr/bin/env python3
"""Validate rendered Codex hook policy and reversible exact-hash adoption.

Pass Nix-rendered hooks/activation scripts. Private legacy fixtures stay outside Git.
The adoption checks execute only against temporary HOME directories; no hooks,
network requests, model calls or real user files are executed by this test.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
from pathlib import Path
import subprocess
import tempfile


def handlers(document: dict) -> list[tuple[str, str | None, dict]]:
    return [(event, group.get('matcher'), handler)
            for event, groups in document['hooks'].items()
            for group in groups for handler in group['hooks']]


def check_policy(path: Path) -> None:
    rows = handlers(json.loads(path.read_text()))
    assert set(row[0] for row in rows) == {
        'SessionStart', 'UserPromptSubmit', 'PreToolUse', 'PostToolUse'}
    assert all(h['type'] == 'command' and 0 < h['timeout'] <= 8
               and not h.get('async', False) for _, _, h in rows)
    memory = [h for event, _, h in rows if 'codex-shared-memory-context' in h['command']]
    assert len(memory) == 4
    assert all(sum(f'--chunk-index {i}' in h['command'] for h in memory) == 1 for i in range(4))
    expected = {
        'codex-world-model-context': ('SessionStart', None),
        'codex-daily-report-reminder': ('SessionStart', None),
        'codex-prompt-context': ('UserPromptSubmit', None),
        'scrapbox-append-guard.py': ('PreToolUse', 'Bash'),
        'gmail-draft-diff/capture-draft.py': ('PostToolUse', 'mcp__claude_ai_Gmail__create_draft'),
    }
    for script, event_matcher in expected.items():
        matching = [(event, matcher) for event, matcher, h in rows if script in h['command']]
        assert matching == [event_matcher], (script, matching)
    assert len([1 for event, matcher, _ in rows if event == 'SessionStart' and matcher == 'compact']) == 1
    assert len(rows) == 10, len(rows)
    for obsolete in ('stop-reflect', 'stop-task-reconcile', 'stop-guard-leaked',
                     'hook-fire-log', 'nix-darwin-sync-check', 'init-prompt',
                     'auto-rename', 'crm-due-inject', 'sid-freshness',
                     'hook-compaction-recovery-restore', 'hook-compact-prep'):
        assert not any(obsolete in h['command'] for _, _, h in rows), obsolete


def activate(script: Path, home: Path) -> subprocess.CompletedProcess:
    env = {**os.environ, 'HOME': str(home)}
    return subprocess.run(['bash', str(script)], env=env, text=True,
                          capture_output=True, timeout=10)


def check_adoption(script: Path, fixture: Path, relative_source: str,
                   relative_archive: str, prefix: str, hooks: Path | None = None) -> None:
    data = fixture.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    with tempfile.TemporaryDirectory(prefix='codex-hook-adoption-') as td:
        root = Path(td)
        if hooks is not None:
            # Rewrite only the test copy, never the production fixed system path.
            rendered = script.read_text()
            marker = 'readonly system_hooks="/etc/codex/hooks.json"'
            assert rendered.count(marker) == 1
            system = root/'system-hooks.json'
            test_script = root/'activation.sh'
            test_script.write_text(rendered.replace(marker,
                'readonly system_hooks=' + shlex.quote(str(system))))
            script = test_script
            gated_home = root/'system-not-ready'
            gated_src = gated_home/relative_source
            gated_src.parent.mkdir(parents=True); gated_src.write_bytes(data)
            for state in (None, b'old system registry'):
                if state is not None:
                    system.write_bytes(state)
                result = activate(script, gated_home)
                assert result.returncode == 0, result.stderr
                assert gated_src.read_bytes() == data
                assert not (gated_home/relative_archive).exists()
                assert 'replacement system hooks are not active' in result.stderr
            system.write_bytes(hooks.read_bytes())
            assert activate(script, gated_home).returncode == 0
            assert not gated_src.exists()
        # Exact reviewed content migrates once and has a durable byte-identical backup.
        home = root/'known'; src = home/relative_source
        src.parent.mkdir(parents=True); src.write_bytes(data)
        assert activate(script, home).returncode == 0
        archive = home/relative_archive/f'{prefix}.{digest}'
        assert not src.exists() and archive.read_bytes() == data
        assert archive.stat().st_mode & 0o777 == 0o600
        assert archive.parent.stat().st_mode & 0o777 == 0o700
        assert activate(script, home).returncode == 0
        assert archive.read_bytes() == data
        # A user modification does not match the allowlist and must not be removed.
        src.write_bytes(data+b'\nuser modification\n')
        assert activate(script, home).returncode == 0 and src.exists()
        # A symlink is never adopted, even when its destination has known content.
        home = root/'symlink'; src = home/relative_source
        src.parent.mkdir(parents=True); target=root/'target'; target.write_bytes(data)
        src.symlink_to(target)
        assert activate(script, home).returncode == 0 and src.is_symlink()
        assert target.read_bytes() == data
        # Colliding archive refuses migration and retains both inputs untouched.
        home = root/'collision'; src = home/relative_source
        src.parent.mkdir(parents=True); src.write_bytes(data)
        archive=home/relative_archive/f'{prefix}.{digest}'
        archive.parent.mkdir(parents=True); archive.write_bytes(b'not the original')
        assert activate(script, home).returncode != 0
        assert src.read_bytes() == data and archive.read_bytes() == b'not the original'


def main() -> None:
    p=argparse.ArgumentParser()
    p.add_argument('--hooks', type=Path, required=True)
    p.add_argument('--hook-adoption', type=Path)
    p.add_argument('--legacy-hooks', type=Path)
    p.add_argument('--agent-adoption', type=Path)
    p.add_argument('--legacy-agents', type=Path)
    args=p.parse_args(); check_policy(args.hooks)
    assert bool(args.hook_adoption) == bool(args.legacy_hooks)
    assert bool(args.agent_adoption) == bool(args.legacy_agents)
    if args.hook_adoption:
        check_adoption(args.hook_adoption, args.legacy_hooks, '.codex/hooks.json',
                       '.local/state/home-manager-adoption/codex-hooks', 'hooks.json', args.hooks)
    if args.agent_adoption:
        check_adoption(args.agent_adoption, args.legacy_agents, 'AGENTS.md',
                       '.local/state/home-manager-adoption/agent-instructions', 'AGENTS.md')
    print('Codex hook policy and requested temporary-HOME adoption cases passed')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Offline regressions for current Desktop response_item messages."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('lifelog', Path(__file__).with_name('lifelog.py'))
ll = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = ll
spec.loader.exec_module(ll)


def message(role, text, phase=None, timestamp='2026-09-12T01:00:00Z'):
    return {'timestamp': timestamp, 'type': 'response_item', 'payload': {
        'type': 'message', 'role': role, 'phase': phase,
        'content': [{'type': 'input_text' if role == 'user' else 'output_text', 'text': text}]}}


class CodexMessages(unittest.TestCase):
    def collect(self, rows, archived=False):
        with tempfile.TemporaryDirectory() as root:
            directory = Path(root, '.codex', 'archived_sessions' if archived else 'sessions')
            directory.mkdir(parents=True)
            f = directory / 'sample.jsonl'
            f.write_text('\n'.join(json.dumps(r) for r in [
                {'type': 'session_meta', 'payload': {'id': 'test-session', 'cwd': '/project'}}, *rows]))
            original = ll.HOME
            try:
                ll.HOME = root
                return ll.fetch_sessions('2026-09-12').data
            finally:
                ll.HOME = original

    def test_current_archived_final_only(self):
        rows = self.collect([message('developer', 'instructions'),
            message('user', '<environment_context>metadata</environment_context>'),
            message('user', 'Fix the parser'), message('assistant', 'Still working', 'commentary'),
            message('assistant', 'Parser repaired', 'final_answer')], archived=True)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['prompt'], 'Fix the parser')
        self.assertEqual(rows[0]['last'], 'Parser repaired')

    def test_metadata_and_request_in_separate_content_blocks(self):
        request = message('user', '<environment_context>metadata</environment_context>')
        request['payload']['content'].append({'type': 'input_text', 'text': 'Fix parser'})
        row = self.collect([request, message('assistant', 'Fixed', 'final_answer')])[0]
        self.assertEqual(row['prompt'], 'Fix parser')
        self.assertEqual(row['last'], 'Fixed')

    def test_commentary_not_result(self):
        row = self.collect([message('user', 'Fix parser'), message('assistant', 'Done soon', 'commentary')])[0]
        self.assertEqual(row['last'], '')
        self.assertEqual(row['state'], '作業中')

    def test_new_request_invalidates_previous_completion(self):
        row = self.collect([message('user', 'Fix parser'), message('assistant', 'Fixed', 'final_answer'),
                            message('user', 'Also handle archives')])[0]
        self.assertEqual(row['last'], '')
        self.assertEqual(row['state'], '作業中')

    def test_continuation_across_jst_midnight(self):
        row = self.collect([message('user', 'Fix parser', timestamp='2026-09-11T14:59:00Z'),
                            message('assistant', 'Fixed', 'final_answer', '2026-09-11T15:01:00Z')])[0]
        self.assertEqual(row['prompt'], 'Fix parser')
        self.assertEqual(row['time'], '00:01')
        self.assertEqual(row['last'], 'Fixed')


if __name__ == '__main__':
    unittest.main()

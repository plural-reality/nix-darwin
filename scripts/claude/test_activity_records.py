import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('activity', Path(__file__).with_name('activity-records.py'))
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)

class StoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / 'sync'
        self.host = 'tkgshn-mac-mini'
        self.ns = self.root / self.host
        self.record = {'source': 'mori', 'id': 'fixture', 'content': '音威子府の試験'}
        self.key = a.immutable(self.ns / 'objects', self.record)
        self.snap = a.immutable(self.ns / 'snapshots', {
            'day': '2026-09-12', 'sources': {'mori': 'collected', 'codex': 'missing'},
            'records': [{'source': 'mori', 'id': 'fixture', 'hash': self.key}]})

    def test_idempotent_object_and_month(self):
        self.assertEqual(self.key, a.immutable(self.ns / 'objects', self.record))
        one = a.prepare(self.root, self.host, self.host, '2026-09', [self.snap])
        two = a.prepare(self.root, self.host, self.host, '2026-09', [self.snap, self.snap])
        self.assertEqual(one, two)
        self.assertEqual(one['bundle']['publication'], 'approval-required')
        self.assertIn('missing', one['bundle']['sources'][0].values())

    def test_partial_transfer_rejected_then_recovers(self):
        obj = self.ns / 'objects' / (self.key + '.json')
        original = obj.read_bytes()
        obj.write_bytes(original[:10])
        with self.assertRaises(ValueError):
            a.backup(self.root, self.base / 'backup')
        obj.write_bytes(original)
        result = a.backup(self.root, self.base / 'backup')
        self.assertEqual(result['files'], 2)

    def test_deleted_source_survives_in_independent_generation(self):
        first = a.backup(self.root, self.base / 'backup')['generation']
        obj = self.ns / 'objects' / (self.key + '.json')
        obj.unlink()
        with self.assertRaises(FileNotFoundError):
            a.verify(self.root)
        saved = self.base / 'backup' / first
        self.assertEqual(a.verify(saved), 2)
        restored = self.base / 'restore'
        a.shutil.copytree(saved, restored)
        self.assertEqual(a.inventory(saved), a.inventory(restored))
        offline = a.prepare(restored, 'tkgshn-MacBook-Air', self.host, '2026-09', [self.snap])
        self.assertEqual(offline['bundle']['sourceHost'], self.host)
        self.assertEqual(offline['bundle']['authorHost'], 'tkgshn-MacBook-Air')

    def test_corrupt_generation_never_overwritten(self):
        dest = self.base / 'backup'
        key = a.backup(self.root, dest)['generation']
        (dest / key / self.host / 'objects' / (self.key + '.json')).write_text('bad')
        with self.assertRaises(ValueError):
            a.backup(self.root, dest)

    def test_backup_within_sync_rejected(self):
        with self.assertRaises(ValueError):
            a.backup(self.root, self.root / 'backup')

    def test_lock_prevents_overlapping_collectors(self):
        with a.lock(self.base / 'state'):
            with self.assertRaises(BlockingIOError):
                with a.lock(self.base / 'state'):
                    self.fail('second collector entered')

    def test_source_failure_keeps_already_written_evidence(self):
        def partial(start, end, cutoff):
            yield self.record
            raise RuntimeError('timeout')
        with patch.object(a, 'mori', partial), patch.object(a, 'codex', lambda *args: iter([])), patch.object(a, 'scrapbox', lambda *args: iter([])):
            result = a.collect(self.root, self.base / 'state', self.host, '2026-09-12', '2026-09-12T18:00:00+09:00')
        snap = a.checked(self.ns / 'snapshots', result['snapshot'])
        self.assertEqual(snap['cutoff'], '2026-09-12T18:00:00+09:00')
        self.assertEqual(snap['sources']['mori'], 'timeout')
        self.assertEqual(len(snap['records']), 1)
        self.assertEqual(snap['windowStart'], '2026-09-01')

    def test_diff_changes_not_observed_is_not_deletion(self):
        before = [{'source': 'mori', 'id': 'a', 'hash': 'old'}]
        after = [{'source': 'mori', 'id': 'a', 'hash': 'new'}]
        self.assertEqual(a.make_diff(before, after)[0]['kind'], 'changed')
        self.assertEqual(a.make_diff(before, [])[0]['kind'], 'not_observed')

    def test_symlink_rejected(self):
        obj = self.ns / 'objects' / (self.key + '.json')
        saved = self.base / 'outside.json'
        obj.rename(saved)
        obj.symlink_to(saved)
        with self.assertRaises(ValueError):
            a.verify(self.root)

    def test_codex_cutoff_excludes_later_message(self):
        sessions = self.base / '.codex' / 'sessions'
        sessions.mkdir(parents=True)
        values = [{'type': 'session_meta', 'payload': {'id': 'session'}}]
        for at in ('2026-09-30T08:59:00Z', '2026-09-30T09:01:00Z'):
            values.append({'type': 'event_msg', 'timestamp': at,
                           'payload': {'type': 'user_message', 'message': '音威子府の活動'}})
        path = sessions / 'fixture.jsonl'
        path.write_text(''.join(a.json.dumps(v) + '\n' for v in values))
        a.os.utime(path, (a.timestamp('2026-09-30T20:00:00+09:00'),) * 2)
        with patch.object(a.Path, 'home', return_value=self.base):
            rows = list(a.codex('2026-09-01', '2026-09-30', '2026-09-30T18:00:00+09:00'))
        self.assertEqual(len(rows[0]['content']), 1)
        self.assertEqual(rows[0]['content'][0]['at'], '2026-09-30T08:59:00Z')

    def test_current_codex_response_item_and_metadata_boundary(self):
        row = {'type': 'response_item', 'payload': {'type': 'message', 'role': 'user',
               'content': [{'type': 'input_text', 'text': '<environment_context>ignore</environment_context>音威子府の記事を整理して'}]}}
        self.assertEqual(a.codex_message(row)['text'], '音威子府の記事を整理して')
        row['payload']['role'] = 'developer'
        self.assertIsNone(a.codex_message(row))

    def test_late_scrapbox_page_does_not_abort_other_pages(self):
        def fake(args):
            if args[1] == '-s':
                return {'pages': [{'title': 'late'}, {'title': 'early'}]}
            title = args[2]
            return {'id': title, 'updated': a.timestamp('2026-09-12T' + ('19' if title == 'late' else '17') + ':00:00+09:00')}
        with patch.object(a, 'run_json', fake), patch.object(a, 'mori', lambda *args: iter([])), patch.object(a, 'codex', lambda *args: iter([])):
            result = a.collect(self.root, self.base / 'state', self.host, '2026-09-12', '2026-09-12T18:00:00+09:00')
        snap = a.checked(self.ns / 'snapshots', result['snapshot'])
        self.assertEqual(len(snap['records']), 3)
        self.assertEqual(snap['sources']['scrapbox'], 'post_cutoff_pages_omitted')

    def test_hash_traversal_rejected(self):
        with self.assertRaises(ValueError):
            a.checked(self.root, '../secret')

if __name__ == '__main__':
    unittest.main()

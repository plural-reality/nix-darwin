import copy
import json
from pathlib import Path
import tempfile
import unittest

import projection as p
from extract import extraction_revision


def fixture(revision='one'):
    conv = {'uuid': 'codex-id', '_source_key': 'codex:id', '_session_kind': 'human_session',
            '_source_version': revision, '_provenance': {'native_id': 'id'},
            'name': '同じ問い', 'created_at': '2026-09-01T00:00:00Z'}
    compact = {'uuid': 'codex-id', 'source_version': revision, 'transcript': 'human: example'}
    ext = {'uuid': 'codex-id', 'source_version': revision, 'ja_summary': '要点',
           'people': [], 'projects': [], 'decisions': [], 'commitments': []}
    ext['extraction_revision'] = extraction_revision(compact)
    return conv, compact, ext


class ProjectionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.directory = Path(self.tmp.name)
        self.page = None
        self.writes = []
        self.unavailable = False

    def tearDown(self):
        self.tmp.cleanup()

    def fetch(self, project, title):
        if self.unavailable:
            return {'status': 'unavailable'}
        return copy.deepcopy(self.page) if self.page else {'status': 'absent', 'lines': [title], 'page_id': None}

    def write(self, project, title, lines, expected, page_id):
        self.writes.append(lines)
        before = self.fetch(project, title)
        if p.digest(before['lines']) != expected or page_id not in (None, before['page_id']):
            return {'status': 'unverified'}
        self.page = {'status': 'found', 'lines': list(lines), 'page_id': 'stable-page'}
        return {'status': 'submitted'}

    def project(self, value=None, dry=False, write=None):
        return p.project_one(*(value or fixture()), 'takalog', self.directory, dry,
                             fetch=self.fetch, write=write or self.write)

    def test_create_and_repeat_have_one_write(self):
        self.assertEqual(self.project()['status'], 'verified')
        self.assertFalse(self.project()['changed'])
        self.assertEqual(len(self.writes), 1)
        receipt = json.loads(next(self.directory.glob('*.json')).read_text())
        self.assertEqual(receipt['state'], 'verified')
        self.assertEqual(receipt['page_id'], 'stable-page')

    def test_unavailable_does_not_create_or_claim_absent(self):
        self.unavailable = True
        self.assertEqual(self.project()['status'], 'unavailable')
        self.assertEqual(self.writes, [])
        self.assertEqual(list(self.directory.iterdir()), [])

    def test_unbound_existing_page_is_never_adopted_by_title(self):
        self.page = {'status': 'found', 'lines': ['existing', 'human'], 'page_id': 'existing'}
        self.assertEqual(self.project()['status'], 'conflict')
        self.assertEqual(self.writes, [])

    def test_human_note_outside_owned_block_survives_update(self):
        self.project()
        self.page['lines'] += ['人間の追記', ' code:unaltered']
        updated = fixture('two')
        updated[0]['name'] = '名前が変わる'
        old_title = self.page['lines'][0]
        self.assertEqual(self.project(updated)['status'], 'verified')
        self.assertEqual(self.page['lines'][-2:], ['人間の追記', ' code:unaltered'])
        self.assertEqual(self.page['lines'][0], old_title)

    def test_human_edit_inside_owned_block_is_conflict(self):
        self.project()
        self.page['lines'][5] = '人間が訂正した記述'
        self.assertEqual(self.project(fixture('two'))['status'], 'conflict')
        self.assertEqual(len(self.writes), 1)

    def test_same_title_different_page_id_is_conflict(self):
        self.project()
        self.page['page_id'] = 'replacement-page'
        self.assertEqual(self.project(fixture('two'))['status'], 'conflict')
        self.assertEqual(len(self.writes), 1)

    def test_stale_extraction_rejected(self):
        value = fixture()
        value[0]['_source_version'] = 'newer'
        with self.assertRaises(ValueError):
            self.project(value)
        self.assertEqual(self.writes, [])

    def test_timeout_after_commit_is_reconciled_by_readback(self):
        def timeout_write(*args):
            self.write(*args)
            return {'status': 'unverified'}
        self.assertEqual(self.project(write=timeout_write)['status'], 'verified')
        self.assertEqual(len(self.writes), 1)

    def test_url_or_submit_success_without_page_is_unverified(self):
        self.assertEqual(self.project(write=lambda *args: {'status': 'submitted'})['status'], 'unverified')
        receipt = json.loads(next(self.directory.glob('*.json')).read_text())
        self.assertEqual(receipt['state'], 'prepared')

    def test_crash_receipt_recovery_does_not_resend(self):
        self.project()
        file = next(self.directory.glob('*.json'))
        receipt = json.loads(file.read_text())
        receipt['state'] = 'prepared'
        receipt['page_id'] = None
        receipt['owned_lines'] = []
        file.write_text(json.dumps(receipt))
        self.assertFalse(self.project()['changed'])
        self.assertEqual(len(self.writes), 1)
        self.assertEqual(json.loads(file.read_text())['state'], 'verified')

    def test_readback_mismatch_stays_unverified(self):
        def racing_write(*args):
            self.write(*args)
            self.page['lines'] += ['concurrent human note']
        self.assertEqual(self.project(write=racing_write)['status'], 'unverified')

    def test_dry_run_creates_no_ledger_or_write(self):
        self.assertEqual(self.project(dry=True)['status'], 'planned')
        self.assertEqual(self.writes, [])
        self.assertEqual(list(self.directory.iterdir()), [])

    def test_pending_operation_is_not_resent_even_if_readback_is_old(self):
        calls = []
        def pending(*args):
            calls.append(args)
            return {'status': 'unverified'}
        self.assertEqual(self.project(write=pending)['status'], 'unverified')
        self.assertEqual(self.project(write=pending)['status'], 'conflict')
        self.assertEqual(len(calls), 1)

    def test_multiline_entities_and_decisions_are_single_physical_lines(self):
        value = fixture()
        value[2]['decisions'] = ['first\nsecond']
        value[2]['people'] = ['one\ntwo']
        title, lines = p.render_source(*value)
        self.assertTrue(all('\n' not in line for line in lines))

    def test_same_name_distinct_native_id_produces_distinct_title(self):
        first = fixture()
        second = fixture()
        second[0]['_provenance']['native_id'] = 'second'
        second[0]['_source_key'] = 'codex:second'
        self.assertNotEqual(p.render_source(*first)[0], p.render_source(*second)[0])


if __name__ == '__main__':
    unittest.main()

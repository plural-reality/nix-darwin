import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import extract as e


class ExtractionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.directory = Path(self.tmp.name)
        self.compact = {'uuid': 'id', 'transcript': 'human: first', 'source_version': 'one'}
        (self.directory / '_index.json').write_text('["id"]')
        (self.directory / 'id.json').write_text(json.dumps(self.compact))
        self.out = self.directory / 'extracted.jsonl'
        self.args = ['--conv-dir', str(self.directory), '--out', str(self.out)]

    def tearDown(self):
        self.tmp.cleanup()

    def valid(self):
        return {'uuid': 'id', 'ja_title': 'Test topic', 'ja_summary': 'summary', 'people': [], 'projects': [],
                'decisions': [], 'commitments': [], 'extraction_revision': e.extraction_revision(self.compact)}

    def test_source_and_prompt_and_engine_changes_invalidate(self):
        original = e.extraction_revision(self.compact)
        self.assertNotEqual(original, e.extraction_revision({**self.compact, 'transcript': 'human: corrected'}))
        self.assertNotEqual(original, e.extraction_revision(self.compact, 'claude'))
        with patch.object(e, 'PROMPT_HEAD', 'different'):
            self.assertNotEqual(original, e.extraction_revision(self.compact))

    def test_uuid_only_legacy_summary_is_not_fresh(self):
        self.out.write_text('{"uuid":"id"}\n')
        self.assertEqual(e.already_done(str(self.out)), set())

    def test_invalid_model_arrays_are_rejected(self):
        with self.assertRaises(ValueError):
            e.parse_json('{"ja_title":"Test topic","ja_summary":"summary","people":"person","projects":[],"decisions":[],"commitments":[]}')

    def test_force_failure_preserves_previous_results_and_exits_nonzero(self):
        before = json.dumps(self.valid()) + '\n'
        self.out.write_text(before)
        with patch.object(e, 'extract_one', side_effect=RuntimeError('fail')):
            self.assertEqual(e.main([*self.args, '--force']), 1)
        self.assertEqual(self.out.read_text(), before)

    def test_success_is_incremental_and_skip_bound_to_revision(self):
        with patch.object(e, 'extract_one', return_value=self.valid()) as run:
            self.assertEqual(e.main(self.args), 0)
            self.assertEqual(e.main(self.args), 0)
            self.assertEqual(run.call_count, 1)

    def test_dry_run_has_no_model_calls_or_output_files(self):
        with patch.object(e, 'extract_one') as run:
            self.assertEqual(e.main([*self.args, '--dry-run']), 0)
            run.assert_not_called()
        self.assertFalse(self.out.exists())
        self.assertFalse(Path(str(self.out) + '.lock').exists())


if __name__ == '__main__':
    unittest.main()

"""Synthetic selected-source snapshots; no real host logs or external writes."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import sessions
import sync_codex
from test_sessions_integrity import CHILD, PARENT, meta, message

SELECTED = "codex-" + CHILD
OTHER = "codex-" + PARENT


class SelectedBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.fixtures = self.root / "fixtures"
        self.fixtures.mkdir()
        self.archive, self.compact = self.root / "canonical-archive", self.root / "canonical-compact"
        self.archive.mkdir()
        self.compact.mkdir()
        self.previous_archive = self.archive / "conversations.json"
        self.previous_archive.write_text('[{"previous":"preserve"}]')
        self.previous_compact = self.compact / (SELECTED + ".json")
        self.previous_compact.write_text('{"previous":"compact"}')
        self.snapshot = self.root / "projection-v2"
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(sessions, "CODEX_ROOTS", (str(self.fixtures / "*.jsonl"),)))
        self.stack.enter_context(patch.object(sessions, "source_paths", return_value=(
            str(self.archive), str(self.compact), "unused", "unused")))

    def write(self, name, identity=CHILD, text="選択した依頼", **metadata):
        path = self.fixtures / name
        path.write_text("\n".join(json.dumps(item, ensure_ascii=False) for item in
                                    [meta(identity, **metadata), message(text)]))
        return path

    def run_build(self, selected=None):
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            sessions.build("codex", selected_uuids=selected or [SELECTED], output_root=str(self.snapshot))
        return json.loads(stdout.getvalue())

    def assert_canonical_preserved(self):
        self.assertEqual(self.previous_archive.read_text(), '[{"previous":"preserve"}]')
        self.assertEqual(self.previous_compact.read_text(), '{"previous":"compact"}')

    def assert_blocked(self, selected=None):
        with self.assertRaises(ValueError):
            self.run_build(selected)
        self.assertFalse(self.snapshot.exists())
        self.assert_canonical_preserved()

    def test_only_selected_filename_candidates_are_read_and_scope_is_reported(self):
        chosen = self.write(f"rollout-{CHILD}.jsonl")
        (self.fixtures / "unselected-broken.jsonl").write_text("broken")
        self.write(f"rollout-{PARENT}.jsonl", PARENT, "非選択の本文 A")
        self.write(f"rollout-{PARENT}_fork.jsonl", PARENT, "非選択の本文 B")
        with patch.object(sessions, "parse_codex_session", wraps=sessions.parse_codex_session) as parse:
            report = self.run_build()
        self.assertEqual([call.args[0] for call in parse.call_args_list], [str(chosen)])
        self.assertEqual(report["scope"], "selected")
        self.assertEqual(report["unselected_sources"], "not_inspected")
        self.assertEqual(report["source_uuids"], [SELECTED])
        self.assertEqual(report["records"], 1)
        self.assertEqual(report["candidate_files"], 1)
        conversations = json.loads((self.snapshot / "archive" / "conversations.json").read_text())
        index = json.loads((self.snapshot / "compact" / "_index.json").read_text())
        self.assertEqual([conv["uuid"] for conv in conversations], index)
        self.assertEqual(index, [SELECTED])
        self.assert_canonical_preserved()

    def test_all_selected_ids_must_be_present_once_after_safe_copy_deduplication(self):
        self.write(f"rollout-{CHILD}.jsonl")
        self.write(f"rollout-{CHILD}_copy.jsonl")
        self.write(f"rollout-{PARENT}.jsonl", PARENT)
        report = self.run_build([SELECTED, OTHER, SELECTED])
        self.assertEqual(report["records"], 2)
        self.assertEqual(report["candidate_files"], 3)
        self.assertEqual(set(report["source_uuids"]), {SELECTED, OTHER})
        self.assert_canonical_preserved()

    def test_selected_suffix_fork_conflict_is_not_filtered_away(self):
        self.write(f"rollout-{CHILD}.jsonl", text="本文 A")
        self.write(f"rollout-{CHILD}_{PARENT}.jsonl", text="本文 B")
        self.assert_blocked()

    def test_missing_selection_does_not_fall_back_to_previous_compact(self):
        self.write(f"rollout-{PARENT}.jsonl", PARENT)
        self.assert_blocked()

    def test_selected_malformed_line_blocks_generation(self):
        path = self.write(f"rollout-{CHILD}.jsonl")
        with path.open("a") as output:
            output.write("\n{malformed correction")
        self.assert_blocked()

    def test_candidate_native_identity_must_match_selection(self):
        self.write(f"rollout-{CHILD}.jsonl", PARENT)
        self.assert_blocked()

    def test_selected_ineligible_or_no_user_source_blocks_generation(self):
        path = self.write(f"rollout-{CHILD}.jsonl", source={"subagent": {}})
        self.assert_blocked()
        path.write_text(json.dumps(meta()))
        self.assert_blocked()

    def test_failure_preserves_previous_selected_snapshot_too(self):
        self.snapshot.mkdir()
        previous = self.snapshot / "previous.json"
        previous.write_text('"previous snapshot"')
        with self.assertRaises(ValueError):
            self.run_build()
        self.assertEqual(list(self.snapshot.iterdir()), [previous])
        self.assertEqual(previous.read_text(), '"previous snapshot"')
        self.assert_canonical_preserved()

    def test_output_root_is_mandatory_and_cannot_alias_canonical_paths(self):
        self.write(f"rollout-{CHILD}.jsonl")
        with self.assertRaises(ValueError):
            sessions.build("codex", selected_uuids=[SELECTED])
        alias = self.root / "alias"
        alias.mkdir()
        (alias / "archive").symlink_to(self.archive, target_is_directory=True)
        with self.assertRaises(ValueError):
            sessions.build("codex", selected_uuids=[SELECTED], output_root=str(alias))
        self.assert_canonical_preserved()


class SyncSelectionTests(unittest.TestCase):
    def test_sync_passes_exact_selection_and_snapshot_paths_to_every_step(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            snapshot = root / "snapshot"
            with patch.object(sync_codex, "DEFAULT_LEDGER", str(root / "ledger")), patch.object(
                sync_codex, "SELECTED_SNAPSHOT_ROOT", str(snapshot)
            ), patch.object(sync_codex.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
                self.assertEqual(sync_codex.main(["--uuid", SELECTED]), 0)
            commands = [call.args[0] for call in run.call_args_list]
            self.assertEqual(len(commands), 3)
            self.assertIn("--output-root", commands[0])
            self.assertEqual(commands[0][commands[0].index("--output-root") + 1], str(snapshot))
            for command in commands:
                self.assertEqual(command[command.index("--uuid") + 1], SELECTED)
            for command in commands[1:]:
                self.assertEqual(command[command.index("--conv-dir") + 1], str(snapshot / "compact"))
            self.assertEqual(commands[2][commands[2].index("--archive") + 1],
                             str(snapshot / "archive" / "conversations.json"))

    def test_build_failure_stops_before_extraction_or_projection(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(sync_codex, "DEFAULT_LEDGER", directory), patch.object(
                sync_codex.subprocess, "run", return_value=subprocess.CompletedProcess([], 1)
            ) as run:
                self.assertEqual(sync_codex.main(["--uuid", SELECTED]), 1)
            self.assertEqual(run.call_count, 1)
            self.assertIn("build", run.call_args.args[0])

    def test_dry_run_reports_selected_scope_and_creates_nothing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(sync_codex, "DEFAULT_LEDGER", str(root / "ledger")), patch.object(
                sync_codex.subprocess, "run"
            ) as run, contextlib.redirect_stdout(io.StringIO()) as stdout:
                self.assertEqual(sync_codex.main(["--uuid", SELECTED, "--dry-run"]), 0)
            self.assertEqual(json.loads(stdout.getvalue())["unselected_sources"], "not_inspected")
            run.assert_not_called()
            self.assertEqual(list(root.iterdir()), [])


if __name__ == "__main__":
    unittest.main()

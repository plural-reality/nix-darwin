import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

import extract
import sessions


class CodexSessionTests(unittest.TestCase):
    def test_parses_only_user_and_final_agent_messages(self):
        events = [
            {"timestamp": "2026-08-11T01:00:00Z", "type": "session_meta", "payload": {"id": "session-1", "cwd": "/Users/tkgshn/Developer/plural-reality/cartographer"}},
            {"timestamp": "2026-08-11T01:00:01Z", "type": "event_msg", "payload": {"type": "user_message", "message": "同期して"}},
            {"timestamp": "2026-08-11T01:00:02Z", "type": "event_msg", "payload": {"type": "agent_message", "phase": "commentary", "message": "作業中"}},
            {"timestamp": "2026-08-11T01:00:03Z", "type": "event_msg", "payload": {"type": "agent_message", "phase": "final_answer", "message": "完了しました"}},
            {"timestamp": "2026-08-11T01:00:04Z", "type": "response_item", "payload": {"type": "message", "role": "developer", "content": [{"type": "input_text", "text": "secret system context"}]}},
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "rollout-session-1.jsonl"
            path.write_text("".join(json.dumps(event) + "\n" for event in events))
            result = sessions.parse_codex_session(path)

        self.assertEqual(result["uuid"], "codex-session-1")
        self.assertEqual(result["_entities"], ["Cartographer"])
        self.assertEqual(result["chat_messages"], [
            {"sender": "human", "text": "同期して"},
            {"sender": "assistant", "text": "完了しました"},
        ])
        self.assertNotIn("secret", json.dumps(result))

    def test_rejects_session_without_user_input(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "empty.jsonl"
            path.write_text(json.dumps({"type": "session_meta", "payload": {"id": "empty", "cwd": "/Users/tkgshn"}}) + "\n")
            self.assertIsNone(sessions.parse_codex_session(path))

    def test_rejects_root_and_extraction_worker_sessions(self):
        events = [
            {"timestamp": "2026-08-15T01:00:00Z", "type": "user", "cwd": "/", "message": {"content": [{"type": "text", "text": extract.EXTRACTION_PROMPT_PREFIX + "下のJSONを抽出"}]}},
            {"timestamp": "2026-08-15T01:00:01Z", "type": "assistant", "cwd": "/", "message": {"content": [{"type": "text", "text": "{\"ja_summary\":\"ok\"}"}]}},
            {"timestamp": "2026-08-15T01:00:02Z", "type": "user", "cwd": "/", "message": {"content": [{"type": "text", "text": "続けて"}]}},
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "worker.jsonl"
            path.write_text("".join(json.dumps(event, ensure_ascii=False) + "\n" for event in events))
            self.assertIsNone(sessions.parse_session(path))

            encoded_root = pathlib.Path(directory) / "-"
            encoded_root.mkdir()
            legacy_path = encoded_root / "legacy.jsonl"
            legacy_events = [
                {"timestamp": "2026-08-15T01:00:00Z", "type": "user", "cwd": "/Users/tkgshn/Developer/form-next-training", "message": {"content": [{"type": "text", "text": "通常の依頼"}]}},
                {"timestamp": "2026-08-15T01:00:01Z", "type": "assistant", "cwd": "/Users/tkgshn/Developer/form-next-training", "message": {"content": [{"type": "text", "text": "対応中"}]}},
                {"timestamp": "2026-08-15T01:00:02Z", "type": "user", "cwd": "/Users/tkgshn/Developer/form-next-training", "message": {"content": [{"type": "text", "text": "続けて"}]}},
            ]
            legacy_path.write_text("".join(json.dumps(event, ensure_ascii=False) + "\n" for event in legacy_events))
            self.assertIsNone(sessions.parse_session(legacy_path))

    def test_accepts_normal_non_root_session(self):
        events = [
            {"timestamp": "2026-08-15T01:00:00Z", "type": "user", "cwd": "/Users/tkgshn/Developer/project", "message": {"content": [{"type": "text", "text": "通常の依頼"}]}},
            {"timestamp": "2026-08-15T01:00:01Z", "type": "assistant", "cwd": "/Users/tkgshn/Developer/project", "message": {"content": [{"type": "text", "text": "対応中"}]}},
            {"timestamp": "2026-08-15T01:00:02Z", "type": "user", "cwd": "/Users/tkgshn/Developer/project", "message": {"content": [{"type": "text", "text": "続けて"}]}},
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "normal.jsonl"
            path.write_text("".join(json.dumps(event, ensure_ascii=False) + "\n" for event in events))
            self.assertIsNotNone(sessions.parse_session(path))

    def test_extract_disables_session_persistence(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "conversation.json"
            path.write_text(json.dumps({"name": "test", "transcript": "human: test"}))
            def respond(command, **kwargs):
                output = pathlib.Path(command[command.index("--output-last-message") + 1])
                output.write_text('{"ja_title":"テストの会話","ja_summary":"ok","people":[],"projects":[],"decisions":[],"commitments":[]}')
                return type("Result", (), {"returncode": 0, "stdout": "", "stderr": ""})()
            with patch.object(extract, "CONV_DIR", directory), patch.object(
                extract.subprocess, "run", side_effect=respond,
            ) as run:
                extract.extract_one("conversation")
            self.assertIn("--ephemeral", run.call_args.args[0])
            self.assertIn("--ignore-user-config", run.call_args.args[0])
            self.assertIn("shell_tool", run.call_args.args[0])



if __name__ == "__main__":
    unittest.main()

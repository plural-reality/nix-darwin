import json
import pathlib
import tempfile
import unittest

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


if __name__ == "__main__":
    unittest.main()

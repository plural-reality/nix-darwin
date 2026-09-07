"""Synthetic regression tests for Codex identity, provenance and bounded input.

These fixtures are self-contained. They never read a real user's Codex tree or
contact the extraction engine/Cosense.
"""
import json
import pathlib
import tempfile
import unittest
from unittest.mock import patch

import sessions

CHILD = "019fb5a4-4632-7fd1-90d9-e2599b8397c4"
PARENT = "019fb5a3-b7c7-7e92-b625-3cc78158b8cf"
CWD = "/Users/example/Developer/project"


def meta(identity=CHILD, **kwargs):
    return {"type": "session_meta", "timestamp": "2026-09-07T01:00:00Z",
            "payload": {"id": identity, "cwd": CWD, **kwargs}}


def message(text, sender="human", timestamp="2026-09-07T01:00:01Z"):
    payload = {"type": "user_message" if sender == "human" else "agent_message", "message": text}
    if sender != "human":
        payload["phase"] = "final_answer"
    return {"type": "event_msg", "timestamp": timestamp, "payload": payload}


class IdentityTests(unittest.TestCase):
    def parse(self, events):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / ("rollout-" + CHILD + ".jsonl")
            path.write_text("\n".join(json.dumps(event, ensure_ascii=False) for event in events) + "\n")
            return sessions.parse_codex_session(path)

    def test_native_child_identity_is_not_overwritten_by_inherited_metadata(self):
        result = self.parse([meta(forked_from_id=PARENT), meta(PARENT, source="vscode"), message("親から引き継いだ依頼")])
        self.assertEqual(result["uuid"], "codex-" + CHILD)
        self.assertEqual(result["_source_key"], "codex:" + CHILD)
        self.assertEqual(result["_provenance"]["parent_thread_id"], PARENT)
        self.assertEqual(result["_provenance"]["inherited_session_ids"], [PARENT])
        self.assertEqual(result["_provenance"]["body_scope"], "native_rollout_including_inherited_context")

    def test_subagent_source_is_classified_and_preserved(self):
        source = {"subagent": {"thread_spawn": {"parent_thread_id": PARENT}}}
        result = self.parse([meta(source=source), message("この調査を担当して")])
        self.assertEqual(result["_session_kind"], "subagent")
        self.assertEqual(result["_provenance"]["parent_thread_id"], PARENT)
        self.assertEqual(result["chat_messages"][0]["text"], "この調査を担当して")

    def test_known_automation_prefixes_are_not_human_conversation_candidates(self):
        for prompt in (
            "あなたは AIアシスタントとの会話1件を分析し構造化抽出する。入力",
            "次の Claude Code セッションを要約・分類せよ。入力",
            "あなたは会話の文字起こしに見出しを付けます。入力",
            "あなたは会話の記録に題を付けます。入力",
            "あなたは日報の分類・要約器です。入力",
        ):
            with self.subTest(prompt=prompt):
                result = self.parse([meta(source="exec"), message(prompt)])
                self.assertEqual(result["_session_kind"], "automation")
                self.assertEqual(result["chat_messages"][0]["text"], prompt)

    def test_exec_alone_is_not_excluded_or_asserted_to_be_automation(self):
        result = self.parse([meta(source="exec"), message("この作業を実行して")])
        self.assertEqual(result["_session_kind"], "human_session")
        self.assertIn("candidate", result["_session_kind_reason"])

    def test_mentioning_an_automation_prompt_is_not_the_same_as_running_it(self):
        result = self.parse([meta(), message("この『あなたは会話の記録に題を付けます。』というプロンプトを検討して")])
        self.assertEqual(result["_session_kind"], "human_session")

    def test_malformed_first_identity_cannot_be_replaced_by_parent_identity(self):
        with self.assertRaises(ValueError):
            self.parse([meta(None), meta(PARENT), message("依頼")])

    def test_missing_or_unsafe_identity_is_rejected(self):
        for events in ([message("依頼")], [meta("../outside"), message("依頼")]):
            with self.subTest(events=events), self.assertRaises(ValueError):
                self.parse(events)

    def test_created_time_is_native_header_and_updated_does_not_regress_to_parent(self):
        inherited = meta(PARENT)
        inherited["timestamp"] = "2026-08-01T01:00:00Z"
        result = self.parse([meta(), inherited, message("親の依頼", timestamp="2026-08-01T01:00:01Z")])
        self.assertEqual(result["created_at"], "2026-09-07T01:00:00Z")
        self.assertEqual(result["updated_at"], "2026-09-07T01:00:00Z")

    def test_corrupt_header_is_not_recovered_using_an_inherited_parent_id(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "broken-header.jsonl"
            path.write_text('{"type":"session_meta",broken\n' + json.dumps(meta(PARENT)) + "\n" + json.dumps(message("依頼")))
            with self.assertRaises(ValueError):
                sessions.parse_codex_session(path)

    def test_content_and_source_revision_track_different_changes(self):
        initial = [meta(), message("最初の依頼")]
        same_content = initial + [{"type": "response_item", "payload": {"type": "tool_result", "text": "tool-only synthetic"}}]
        corrected = initial + [message("訂正: 公開せず下書きにする", timestamp="2026-09-07T02:00:00Z")]
        a, b, c = (self.parse(events) for events in (initial, same_content, corrected))
        self.assertEqual(a["_content_hash"], b["_content_hash"])
        self.assertNotEqual(a["_source_version"], b["_source_version"])
        self.assertNotEqual(a["_content_hash"], c["_content_hash"])
        self.assertTrue(a["_source_version"].startswith(sessions.CODEX_PARSER_VERSION + ":"))
        self.assertNotIn("tool-only", json.dumps(b))


def response(text, role="user", phase=None, item_id="msg_1", turn_id="turn_1", kinds=None):
    payload = {"type": "message", "id": item_id, "role": role,
               "content": [{"type": "input_text" if role == "user" else "output_text", "text": text}]}
    if phase is not None:
        payload["phase"] = phase
    if kinds is not None:
        payload["internal_chat_message_metadata_passthrough"] = {
            "turn_id": turn_id, "create_time": "2026-09-07T01:00:01Z", "content_item_kinds": kinds}
    return {"type": "response_item", "timestamp": "2026-09-07T01:00:01Z", "payload": payload}


class ResponseItemTests(unittest.TestCase):
    parse = IdentityTests.parse
    def test_current_schema_keeps_real_user_blocks_and_final_only(self):
        injection = response("plugins injected", kinds=["plugins.recommendations"])
        injection["payload"]["content"] += [
            {"type": "input_text", "text": "agent instructions injected"},
            {"type": "input_text", "text": "environment injected"}]
        injection["payload"]["internal_chat_message_metadata_passthrough"]["content_item_kinds"] += [
            "agents_md.instructions", "environments.environment_context"]
        mixed = response("# AGENTS.md instructions is my actual request", item_id="msg_user", kinds=["user.text"])
        final = response("最終回答", "assistant", "final_answer", "msg_final", kinds=["assistant.text"])
        events = [meta(), injection, mixed,
                  response("private analysis", "assistant", "analysis", "msg_analysis"),
                  response("作業中", "assistant", "commentary", "msg_commentary"), final,
                  {"type": "response_item", "payload": {"type": "agent_message", "text": "interagent private"}},
                  {"type": "event_msg", "payload": {"type": "task_complete"}}]
        result = self.parse(events)
        self.assertEqual([m["text"] for m in result["chat_messages"]], [mixed["payload"]["content"][0]["text"], "最終回答"])
        self.assertEqual(result["chat_messages"][0]["source_item_id"], "msg_user")
        self.assertEqual(result["chat_messages"][0]["turn_id"], "turn_1")
        self.assertEqual(result["_provenance"]["excluded_injected_user_blocks"], 3)
        self.assertEqual(result["_provenance"]["legacy_user_message_candidates"], 0)
        self.assertNotIn("private", json.dumps(result))

    def test_kind_to_block_mapping_can_keep_only_one_block(self):
        item = response("generated context", kinds=["agents_md.instructions"], item_id="msg_mixed")
        item["payload"]["content"].append({"type": "input_text", "text": "本人の訂正"})
        item["payload"]["internal_chat_message_metadata_passthrough"]["content_item_kinds"].append("user.text")
        result = self.parse([meta(), item])
        self.assertEqual(result["chat_messages"][0]["text"], "本人の訂正")

    def test_legacy_response_without_kinds_keeps_text_and_marks_uncertainty(self):
        result = self.parse([meta(), response("<environment_context>injected"), response("通常の依頼", item_id="msg_real")])
        self.assertEqual([m["text"] for m in result["chat_messages"]], ["通常の依頼"])
        self.assertEqual(result["_provenance"]["legacy_user_message_candidates"], 1)

    def test_old_event_and_response_mirrors_do_not_duplicate_turns(self):
        result = self.parse([meta(), message("依頼"), response("依頼", kinds=["user.text"]),
                             response("回答", "assistant", "final_answer", "msg_final"), message("回答", "assistant")])
        self.assertEqual([m["text"] for m in result["chat_messages"]], ["依頼", "回答"])
        self.assertEqual(result["chat_messages"][0]["source_item_id"], "msg_1")

    def test_identical_real_turns_are_not_text_deduplicated(self):
        result = self.parse([meta(), message("続けて"), response("続けて", kinds=["user.text"]),
                             message("続けて"), response("続けて", item_id="msg_2", turn_id="turn_2", kinds=["user.text"])])
        self.assertEqual(len(result["chat_messages"]), 2)
        self.assertEqual([m["source_item_id"] for m in result["chat_messages"]], ["msg_1", "msg_2"])

    def test_replayed_same_item_id_is_one_message(self):
        item = response("依頼", kinds=["user.text"])
        result = self.parse([meta(), item, item])
        self.assertEqual(len(result["chat_messages"]), 1)

    def test_malformed_kind_mapping_is_not_silently_dropped(self):
        with self.assertRaises(ValueError):
            self.parse([meta(), response("依頼", kinds=[])])


class TranscriptTests(unittest.TestCase):
    def assert_coverage(self, messages, bounded, cap):
        coverage = bounded["coverage"]
        self.assertLessEqual(len(bounded["text"]), cap)
        self.assertEqual(coverage["total_messages"], len(messages))
        included = 0
        covered = []
        partial = []
        for entry in coverage["message_ranges"]:
            index = entry["message_index"]
            ranges = entry["ranges"]
            previous = 0
            for span in ranges:
                self.assertLessEqual(previous, span["start"])
                self.assertLess(span["start"], span["end"])
                self.assertLessEqual(span["end"], len(messages[index]["text"]))
                previous = span["end"]
                included += span["end"] - span["start"]
            if ranges:
                covered.append(index)
                if sum(r["end"] - r["start"] for r in ranges) < len(messages[index]["text"]):
                    partial.append(index)
        self.assertEqual(coverage["covered_message_indices"], covered)
        self.assertEqual(coverage["partial_message_indices"], partial)
        self.assertEqual(coverage["omitted_message_indices"], [i for i in range(len(messages)) if i not in covered])
        self.assertEqual(coverage["included_chars"], included)

    def test_late_user_correction_survives_long_history_and_long_final_reply(self):
        messages = [{"sender": "human", "text": "最初の依頼"}] + [
            {"sender": "assistant", "text": "古い説明" * 500} for _ in range(20)
        ] + [{"sender": "human", "text": "訂正: 実行は中止し、下書きだけ残す"},
             {"sender": "assistant", "text": "確認事項" * 3000 + "結論: 下書きのまま保存しました"}]
        bounded = sessions.bounded_transcript(messages, 1200)
        self.assertIn("訂正: 実行は中止し、下書きだけ残す", bounded["text"])
        self.assertIn("結論: 下書きのまま保存しました", bounded["text"])
        self.assertIn("最初の依頼", bounded["text"])
        self.assert_coverage(messages, bounded, 1200)
        self.assertTrue(bounded["coverage"]["omitted_message_indices"])
        self.assertTrue(bounded["coverage"]["partial_message_indices"])

    def test_single_long_message_keeps_head_and_tail(self):
        messages = [{"sender": "human", "text": "依頼の目的" + "あ" * 10000 + "末尾の訂正: 送信しない"}]
        bounded = sessions.bounded_transcript(messages, 200)
        self.assertIn("依頼の目的", bounded["text"])
        self.assertIn("末尾の訂正: 送信しない", bounded["text"])
        self.assertEqual(len(bounded["coverage"]["message_ranges"][0]["ranges"]), 2)
        self.assert_coverage(messages, bounded, 200)

    def test_small_complete_input_is_not_truncated(self):
        messages = [{"sender": "human", "text": "依頼"}, {"sender": "assistant", "text": "回答"}]
        bounded = sessions.bounded_transcript(messages, 4000)
        self.assertEqual(bounded["coverage"]["omitted_message_indices"], [])
        self.assertEqual(bounded["coverage"]["partial_message_indices"], [])
        self.assert_coverage(messages, bounded, 4000)
        self.assertEqual(sessions.transcript(messages), bounded["text"])

    def test_tiny_and_zero_budget_still_obey_the_bound(self):
        messages = [{"sender": "human", "text": "本文" * 30}]
        for cap in (0, 1, 10, 50):
            with self.subTest(cap=cap):
                self.assert_coverage(messages, sessions.bounded_transcript(messages, cap), cap)


class BuildTests(unittest.TestCase):
    def test_automation_and_subagent_bodies_remain_archived_but_not_in_extraction_index(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            fixtures = root / "fixtures"
            fixtures.mkdir()
            for index, events in enumerate((
                [meta("human"), message("この変更を検討して")],
                [meta("automation"), message("あなたは会話の記録に題を付けます。入力")],
                [meta("child", source={"subagent": {}}), message("独立調査を担当して")],
            )):
                (fixtures / f"{index}.jsonl").write_text("\n".join(json.dumps(e, ensure_ascii=False) for e in events))
            archive, compact = root / "archive", root / "compact"
            with patch.object(sessions, "CODEX_ROOTS", (str(fixtures / "*.jsonl"),)), patch.object(
                sessions, "source_paths", return_value=(str(archive), str(compact), "unused-extracted", "unused-seen")
            ):
                sessions.build("codex")
            conversations = json.loads((archive / "conversations.json").read_text())
            self.assertEqual(len(conversations), 3)
            self.assertEqual({c["_session_kind"] for c in conversations}, {"human_session", "automation", "subagent"})
            self.assertEqual(json.loads((compact / "_index.json").read_text()), ["codex-human"])
            eligible = json.loads((compact / "codex-human.json").read_text())
            for field in ("source_key", "source_version", "content_hash", "session_kind", "provenance", "transcript_coverage"):
                self.assertIn(field, eligible)
            self.assertFalse((compact / "codex-automation.json").exists())
            self.assertFalse((compact / "codex-child.json").exists())

    def test_private_json_write_is_atomic_and_mode_0600(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "private.json"
            path.write_text('{"previous":"preserve"}')
            with patch.object(sessions.os, "replace", side_effect=OSError("synthetic replace failure")), self.assertRaises(OSError):
                sessions._write_private_json(str(path), {"next": "draft"})
            self.assertEqual(path.read_text(), '{"previous":"preserve"}')
            self.assertEqual(list(path.parent.iterdir()), [path])
            sessions._write_private_json(str(path), {"next": "complete"})
            self.assertEqual(json.loads(path.read_text()), {"next": "complete"})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_append_only_copy_is_deduplicated_to_the_longest_transcript(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            fixtures, archive, compact = root / "fixtures", root / "archive", root / "compact"
            fixtures.mkdir()
            initial = [meta(), message("最初の依頼")]
            for index, events in enumerate((initial, initial + [message("末尾の訂正", timestamp="2026-09-07T02:00:00Z")])):
                (fixtures / f"{index}.jsonl").write_text("\n".join(json.dumps(e) for e in events))
            with patch.object(sessions, "CODEX_ROOTS", (str(fixtures / "*.jsonl"),)), patch.object(
                sessions, "source_paths", return_value=(str(archive), str(compact), "unused", "unused")
            ):
                sessions.build("codex")
            conversations = json.loads((archive / "conversations.json").read_text())
            self.assertEqual(len(conversations), 1)
            self.assertEqual(conversations[0]["chat_messages"][-1]["text"], "末尾の訂正")

    def test_different_content_for_one_native_id_fails_without_replacing_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            fixtures, archive, compact = root / "fixtures", root / "archive", root / "compact"
            fixtures.mkdir()
            archive.mkdir()
            prior = archive / "conversations.json"
            prior.write_text('[{"previous":"preserve"}]')
            for index, prompt in enumerate(("最初の依頼", "異なる内容")):
                (fixtures / f"{index}.jsonl").write_text("\n".join(json.dumps(e) for e in [meta(), message(prompt)]))
            with patch.object(sessions, "CODEX_ROOTS", (str(fixtures / "*.jsonl"),)), patch.object(
                sessions, "source_paths", return_value=(str(archive), str(compact), "unused", "unused")
            ), self.assertRaises(ValueError):
                sessions.build("codex")
            self.assertEqual(prior.read_text(), '[{"previous":"preserve"}]')


if __name__ == "__main__":
    unittest.main()

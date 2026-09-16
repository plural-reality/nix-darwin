import importlib.util
import json
import os
import subprocess
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("beeper_mentions", Path(__file__).with_name("beeper-mentions.py"))
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class MentionTests(unittest.TestCase):
    def make_payload(self, text="@Alice", mentions=None):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "mentions.json"
            target.write_text(json.dumps(mentions or [{"id": "@one:example", "displayName": "Alice", "start": 0, "end": 6}]))
            body = Path(directory) / "body.txt"
            body.write_text(text)
            return module.payload("chat", "@" + str(body), "", "@" + str(target))

    def test_utf16_and_explicit_identity(self):
        mention = {"id": "@two:example", "displayName": "Alice", "start": 3, "end": 9}
        self.assertEqual(self.make_payload("😀 @Alice", [mention])["mentions"], [mention])

    def test_rejects_overlap_or_unbound_text(self):
        original = {"id": "@one:example", "displayName": "Alice", "start": 0, "end": 6}
        with self.assertRaises(ValueError):
            self.make_payload("@Alice", [original, {**original, "id": "@two:example"}])
        with self.assertRaises(ValueError):
            self.make_payload("@Other", [original])

    def test_readback_requires_ids_not_display_name(self):
        expected = self.make_payload()
        item = {"id": "sent", "isSender": True, "text": "@Alice"}
        self.assertFalse(module.matches_message(item, expected))
        self.assertFalse(module.matches_message({**item, "mentions": [{"id": "@two:example"}]}, expected))
        self.assertTrue(module.matches_message({**item, "mentions": [{"id": "@one:example"}]}, expected))

    def test_html_readback_and_reply_binding(self):
        expected = {**self.make_payload(), "replyToMessageId": "parent"}
        item = {"id": "sent", "isSender": True, "text": '<a href="https://matrix.to/#/%40one%3Aexample">@Alice</a>', "linkedMessageID": "parent"}
        self.assertTrue(module.matches_message(item, expected))
        self.assertFalse(module.matches_message({**item, "linkedMessageID": "wrong"}, expected))
        self.assertFalse(module.matches_message({**item, "isDeleted": True}, expected))

    def test_ambiguous_or_old_messages_fail(self):
        expected = self.make_payload()
        item = {"id": "sent", "isSender": True, "text": "@Alice", "mentions": ["@one:example"]}
        with self.assertRaises(ValueError):
            module.verified_id([item, {**item, "id": "duplicate"}], expected, "", "")
        with self.assertRaises(ValueError):
            module.verified_id([item], expected, "missing-baseline", "")
        self.assertEqual(module.verified_id([item], expected, "missing-baseline", "sent"), "sent")


    def test_reviewed_attempt_hash_binds_selected_ids(self):
        script = Path(__file__).with_name("beeper-send.sh").read_text()
        function = script[script.index("review_key() {"):script.index("review_state_file() {")]
        def key(mentions):
            result = subprocess.run(["bash", "-c", function + '\nreview_key chat "" original final'], env={**os.environ, "MENTIONS_JSON": mentions}, text=True, capture_output=True, check=True)
            return result.stdout.strip()
        self.assertNotEqual(key('[{"id":"one"}]'), key('[{"id":"two"}]'))
        self.assertEqual(key('[{"id":"one"}]'), key('[{"id":"one"}]'))
        self.assertNotEqual(key(""), key('[{"id":"one"}]'))


class CliBoundaryTests(unittest.TestCase):
    def run_cli(self, command, support="supported", mentions=True):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = Path(__file__).parent
            (root / "token").write_text("synthetic-test-value")
            script = (source / "beeper-send.sh").read_text().replace('TOKEN_FILE="$HOME/.config/beeper/token"', 'TOKEN_FILE="' + str(root / "token") + '"')
            (root / "beeper-send.sh").write_text(script)
            (root / "beeper-mentions.py").write_text((source / "beeper-mentions.py").read_text())
            (root / "body.txt").write_text("@Alice")
            (root / "mentions.json").write_text(json.dumps([{"id": "@one:example", "displayName": "Alice", "start": 0, "end": 6}]))
            (root / "sleep").write_text("#!/bin/sh\nexit 0\n")
            (root / "curl").write_text(r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ["MENTION_TEST_ROOT"])
args = sys.argv[1:]
url = next(value for value in args if value.startswith("http"))
with (root / "requests.log").open("a") as output:
    output.write(url + "\n")
body = json.loads(Path(args[args.index("--data-binary") + 1][1:]).read_text()) if "--data-binary" in args else {}
if url.endswith("/api/messages/preview"):
    print(json.dumps({**body, "support": os.environ["MENTION_TEST_SUPPORT"], "transport": "matrix-html"}))
elif url.endswith("/api/send"):
    (root / "sent.json").write_text(json.dumps(body))
    print('{"id":"sent"}')
elif url.endswith("/messages"):
    (root / "direct.json").write_text(json.dumps(body))
    print('{"pendingMessageID":"sent"}')
elif "/mention-targets" in url:
    print('{"chatId":"chat","participants":[],"complete":true,"support":"unknown"}')
else:
    sent = [{"id":"sent","isSender":True,"text":"<a href=\"https://matrix.to/#/%40one%3Aexample\">@Alice</a>","linkedMessageID":"parent" if os.environ.get("MENTION_TEST_REPLY") else ""}] if (root / "sent.json").exists() else []
    print(json.dumps({"items":sent + [{"id":"baseline","text":"baseline"}]}))
''')
            for name in ("curl", "sleep"):
                (root / name).chmod(0o755)
            args = ["bash", str(root / "beeper-send.sh"), command, "chat"]
            if command == "reply":
                args += ["parent"]
            if command != "participants":
                args += ["@" + str(root / "body.txt")]
            if mentions and command != "participants":
                args += ["--mentions", "@" + str(root / "mentions.json")]
            args += ["--ack"]
            env = {**os.environ, "PATH": str(root) + os.pathsep + os.environ["PATH"], "MENTION_TEST_ROOT": str(root), "MENTION_TEST_SUPPORT": support, "MENTION_TEST_REPLY": "yes" if command == "reply" else ""}
            result = subprocess.run(args, env=env, text=True, capture_output=True)
            requests = (root / "requests.log").read_text() if (root / "requests.log").exists() else ""
            sent = json.loads((root / "sent.json").read_text()) if (root / "sent.json").exists() else None
            direct = json.loads((root / "direct.json").read_text()) if (root / "direct.json").exists() else None
            return result, requests, sent, direct

    def test_mentions_use_gateway_and_verify_ids(self):
        result, requests, sent, direct = self.run_cli("send")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sent["mentions"][0]["id"], "@one:example")
        self.assertIsNone(direct)
        self.assertIn("/api/messages/preview", requests)
        self.assertIn("/api/send", requests)
        self.assertIn("message_readback=verified", result.stdout)
        self.assertIn("mention_targets_in_content=verified", result.stdout)
        self.assertIn("native_mention_delivery=unverified", result.stdout)
        self.assertIn("notification_delivery=unverified", result.stdout)
        self.assertNotIn("native_mention_delivery=verified", result.stdout)

    def test_reply_keeps_parent(self):
        result, _, sent, direct = self.run_cli("reply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sent["replyToMessageId"], "parent")
        self.assertIsNone(direct)

    def test_unsupported_and_unknown_never_send(self):
        for support in ("unsupported", "unknown"):
            result, requests, sent, direct = self.run_cli("send", support)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("/api/send", requests)
            self.assertIsNone(sent)
            self.assertIsNone(direct)

    def test_preview_does_not_send(self):
        result, requests, sent, direct = self.run_cli("preview")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("/api/send", requests)
        self.assertIsNone(sent)
        self.assertIsNone(direct)

    def test_plain_send_retains_existing_transport(self):
        result, requests, sent, direct = self.run_cli("send", mentions=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsNone(sent)
        self.assertEqual(direct, {"text": "@Alice"})
        self.assertNotIn("/api/", requests)

    def test_participants_only_reads(self):
        result, requests, sent, direct = self.run_cli("participants")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("/mention-targets", requests)
        self.assertIsNone(sent)
        self.assertIsNone(direct)


if __name__ == "__main__":
    unittest.main()

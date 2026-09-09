import io
import json
from pathlib import Path
import tempfile
import unittest

import tool_usage as usage


SESSION = "00000000-0000-0000-0000-000000000001"
FORK = "00000000-0000-0000-0000-000000000002"
START = "2026-08-09T00:00:00+09:00"
END = "2026-09-09T00:00:00+09:00"
NOW = "2026-09-01T00:00:00+09:00"


def call(name="functions.exec_command", arguments=None, call_id="call1", timestamp=NOW):
    return {"type": "response_item", "timestamp": timestamp, "payload": {
        "type": "function_call", "name": name, "arguments": arguments or {}, "call_id": call_id}}


def meta(session=SESSION):
    return {"type": "session_meta", "timestamp": "2026-01-01T00:00:00Z", "payload": {"id": session}}


class AuditTests(unittest.TestCase):
    def run_audit(self, files, excluded=()):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for filename, entries in files.items():
                path = root / filename
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("\n".join(json.dumps(e) if not isinstance(e, str) else e for e in entries) + "\n")
            output = io.StringIO()
            usage.audit([root], usage.parse_time(START), usage.parse_time(END), set(excluded), output)
            return json.loads(output.getvalue()), output.getvalue()

    def test_event_window_reads_old_file_and_uses_exclusive_end(self):
        data, _ = self.run_audit({"2026/01/01/old.jsonl": [meta(),
            call(call_id="start", timestamp=START), call(call_id="end", timestamp=END),
            call(call_id="old", timestamp="2026-08-08T23:59:59+09:00"), call(call_id="new")]})
        self.assertEqual(len(data["calls"]), 2)
        self.assertEqual(data["summary"]["counts"]["calls_outside_window"], 2)
        self.assertEqual(data["calls"][0]["timestamp"], "2026-08-08T15:00:00Z")

    def test_legacy_custom_and_wrapped_calls(self):
        legacy = {"type": "function_call", "timestamp": NOW, "name": "mcp__cua_repl__js",
                  "arguments": {"code": "await tab.click()"}, "call_id": "legacy"}
        custom = {"type": "custom_tool_call", "timestamp": NOW,
                  "payload": {"name": "functions.exec", "input": "tools.exec_command({})", "call_id": "custom"}}
        wrapped = call("mcp__playwright__browser_navigate", call_id="wrap")
        data, _ = self.run_audit({"a.jsonl": [meta(), legacy, custom, wrapped]})
        self.assertEqual([e["category"] for e in data["calls"]], ["gui", "orchestration", "gui"])
        self.assertEqual(data["calls"][0]["ui_method_hints"], ["click"])

    def test_global_call_id_dedup_fork_and_archive(self):
        data, _ = self.run_audit({"sessions/a.jsonl": [meta(), call()],
                                  "archived/b.jsonl": [meta(FORK), call(), call(call_id="second")]})
        self.assertEqual(len(data["calls"]), 2)
        counts = data["summary"]["counts"]
        self.assertEqual(counts["duplicate_calls"], 1)
        self.assertEqual(counts["calls_in_window_before_dedup"], 3)

    def test_embedded_js_is_lexical_only_and_privacy_allowlist(self):
        secret = "PRIVACY_SENTINEL_123456789"
        code = ('// tools.mcp__cua_repl__js is an unused reference\n'
                'if (false) await tools.mcp__playwright__browser_click({secret:"' + secret + '"});\n'
                'await tab.getByRole("button", {name:"' + secret + '"}).click();\n'
                'await tools.' + secret + '({url:"https://docs.google.com/document/d/' + secret +
                '?token=' + secret + '"}); // osascript pw.mjs screencapture')
        data, raw = self.run_audit({secret + ".jsonl": [meta(), call("functions.exec", code),
            {"type": "response_item", "timestamp": NOW, "payload": {
                "type": "function_call_output", "output": secret}}]})
        self.assertNotIn(secret, raw)
        self.assertNotIn("https://", raw)
        self.assertEqual(len(data["calls"]), 1)
        record = data["calls"][0]
        self.assertEqual(record["category"], "orchestration")
        self.assertEqual(record["service_hints"], ["google_drive"])
        self.assertEqual(record["shell_ui_hints"], ["osascript", "pw.mjs", "screencapture"])
        self.assertEqual(len(record["embedded_references"]), 3)
        self.assertNotIn("outer_gui_calls", data["summary"]["counts"])

    def test_unknown_invalid_missing_timestamp_and_output_are_not_leaked(self):
        data, raw = self.run_audit({"a.jsonl": [meta(), "not-json", "[]",
            call("SECRET_UNKNOWN_TOOL"), call(call_id="missing", timestamp=None),
            call(call_id="naive", timestamp="2026-09-01T12:00:00"),
            {"type": "message", "timestamp": NOW, "content": "SECRET_MESSAGE"}]})
        self.assertEqual(len(data["calls"]), 1)
        self.assertEqual(data["calls"][0]["tool"], "unknown")
        self.assertEqual(data["summary"]["counts"]["invalid_lines"], 2)
        self.assertEqual(data["summary"]["counts"]["calls_missing_valid_timestamp"], 2)
        self.assertNotIn("SECRET", raw)

    def test_services_require_domain_boundaries(self):
        hints = usage.lexical_hints("https://docs.google.com.evil.test/x https://evil.test/github.com")
        self.assertEqual(hints["service_hints"], ["other"])
        self.assertEqual(usage.lexical_hints("https://secure.netbk.co.jp/x")["service_hints"], ["bank"])

    def test_node_repl_browser_is_hint_but_history_is_not_gui(self):
        data, _ = self.run_audit({"a.jsonl": [meta(),
            call("functions.exec", 'await tools.mcp__node_repl__js({code:"await tab.goto(url); await tab.screenshot()"})'),
            call("mcp__computer_history__search", {"query": "yesterday"}, call_id="history")]})
        first, second = data["calls"]
        self.assertEqual(first["embedded_references"][0]["tool"], "node_repl.js")
        self.assertEqual(first["ui_method_hints"], ["goto", "screenshot"])
        self.assertEqual(second["category"], "history")
        self.assertEqual(data["summary"]["counts"]["calls_with_lexical_gui_hints"], 1)
        self.assertNotIn("outer_gui_calls", data["summary"]["counts"])

    def test_bare_js_normalized_embedded_aliases_and_history(self):
        code = ('await tools.web__run({}); await tools.codex_app__list_threads({}); '
                'await tab.domSnapshot(); await tab.getVisibleText();')
        data, _ = self.run_audit({"a.jsonl": [meta(), call("js", {"code": code}),
            call("mcp__computer_history__computer_history_status", call_id="history1"),
            call("computer_history_status", call_id="history2")]})
        first = data["calls"][0]
        self.assertEqual(first["tool"], "js")
        self.assertEqual(first["category"], "orchestration")
        self.assertNotIn("gui_family", first)
        self.assertEqual(first["ui_method_hints"], ["domSnapshot", "getVisibleText"])
        self.assertEqual([r["tool"] for r in first["embedded_references"]], ["codex.list_threads", "web.run"])
        self.assertEqual([r["category"] for r in data["calls"][1:]], ["history", "history"])
        self.assertEqual(data["summary"]["counts"]["calls_with_lexical_gui_hints"], 1)

    def test_added_service_domains_remain_fixed_and_boundary_checked(self):
        cases = {"note.com": "note", "secure.freee.co.jp": "freee", "e-tax.nta.go.jp": "tax",
                 "www.eltax.lta.go.jp": "tax", "yamap.com": "yamap", "tinder.com": "tinder"}
        for domain, category in cases.items():
            with self.subTest(domain=domain):
                self.assertEqual(usage.lexical_hints("https://" + domain + "/SECRET")["service_hints"], [category])
                self.assertEqual(usage.lexical_hints("https://" + domain + ".evil.test/SECRET")["service_hints"], ["other"])

    def test_exclusion_and_missing_call_ids(self):
        data, _ = self.run_audit({"a.jsonl": [meta(), call()],
                                  "b.jsonl": [meta(FORK), call(call_id=None), call(call_id=None)]}, [SESSION])
        self.assertEqual(len(data["calls"]), 2)
        self.assertEqual(data["summary"]["counts"]["excluded_session_calls"], 1)
        self.assertEqual(data["summary"]["counts"]["calls_without_id_not_deduplicated"], 2)

    def test_oversized_line_is_counted_and_following_record_survives(self):
        old = usage.MAX_LINE_BYTES
        usage.MAX_LINE_BYTES = 500
        try:
            data, _ = self.run_audit({"a.jsonl": [meta(), '"' + 'x' * 1200 + '"', call()]})
        finally:
            usage.MAX_LINE_BYTES = old
        self.assertEqual(data["calls"][0]["line"], 3)
        self.assertEqual(data["summary"]["counts"]["oversized_lines"], 1)

    def test_time_parser_requires_timezone(self):
        self.assertIsNone(usage.parse_time("2026-09-01T00:00:00"))
        self.assertIsNone(usage.parse_time("bad"))
        self.assertIsNotNone(usage.parse_time("2026-09-01T00:00:00Z"))

    def test_unknown_record_shapes_are_counted_without_raw_type(self):
        sentinel = "PRIVATE_FUTURE_RECORD_TYPE"
        data, raw = self.run_audit({"a.jsonl": [meta(),
            {"type": sentinel, "timestamp": NOW, "payload": {"value": sentinel}},
            {"type": "response_item", "timestamp": NOW, "payload": {"type": sentinel}},
            {"type": "response_item", "timestamp": NOW, "payload": []},
            {"type": "event_msg", "timestamp": NOW, "payload": {"type": "task_started"}},
            {"type": "response_item", "timestamp": NOW, "payload": {"type": "message", "content": sentinel}},
            call()]})
        self.assertEqual(data["summary"]["counts"]["unknown_record_shapes"], 3)
        self.assertEqual(data["summary"]["sources"][0]["counts"]["unknown_record_shapes"], 3)
        self.assertEqual(len(data["calls"]), 1)
        self.assertNotIn(sentinel, raw)


if __name__ == "__main__":
    unittest.main()

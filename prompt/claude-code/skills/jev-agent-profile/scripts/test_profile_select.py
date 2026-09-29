import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

import profile_select as selector


def fixture(host="codex"):
    model = "gpt-6-sol" if host == "codex" else "claude-sonnet-5-5"
    return {"host": host, "summary": "Fix an isolated bug.", "egressApproved": True, "allowSecond": False,
            "profiles": [{"id": "normal", "description": "Clear coding.", "sessions": [{"model": model, "effort": "medium"}]},
                         {"id": "deep", "description": "Complex reasoning.", "sessions": [{"model": model, "effort": "high"}]}]}


def response(choice="normal"):
    return {"model": selector.MODEL, "answers": {"profile": {"choice": choice, "confidence": 0.9,
            "probabilities": {name: 0.9 if name == choice else 0.05 for name in ("normal", "deep", "default")}}}}


class ProfileSelection(unittest.TestCase):
    def test_host_defaults_preserve_explicit_candidates(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "profiles.json"
            profiles = {host: fixture(host)["profiles"] for host in ("codex", "claude-code")}
            path.write_text(json.dumps(profiles))
            for host in profiles:
                data = {key: value for key, value in fixture(host).items() if key != "profiles"}
                enriched = selector.with_profiles(data, str(path))
                self.assertEqual(enriched["profiles"], profiles[host])
                self.assertTrue(selector.valid_input(enriched))
                explicit = fixture(host)
                self.assertIs(selector.with_profiles(explicit, "/missing"), explicit)
            self.assertEqual(selector.with_profiles({"host": []}, str(path)), {"host": []})
            path.write_text("[]")
            self.assertFalse(selector.valid_input(selector.with_profiles({"host": "codex"}, str(path))))

    def test_both_hosts_return_only_original_profile(self):
        for host in ("codex", "claude-code"):
            data = fixture(host)
            self.assertTrue(selector.valid_input(data))
            self.assertEqual(selector.evaluate(data, response())["profile"], data["profiles"][0])

    def test_worker_count_gate_is_local(self):
        data = fixture()
        data["profiles"][1]["sessions"] *= 2
        self.assertFalse(selector.valid_input(data))
        data["allowSecond"] = True
        self.assertTrue(selector.valid_input(data))
        data["profiles"][1]["sessions"] *= 2
        self.assertFalse(selector.valid_input(data))

    def test_unknown_settings_and_malformed_input_are_rejected(self):
        for data in (None, [], {**fixture(), "permissions": "bypass"}, {**fixture(), "host": "other"}, {**fixture(), "host": []}, {**fixture(), "host": {}}):
            self.assertEqual(selector.select(data)["status"], "blocked")
        for field, value in (("model", "$(echo hacked)"), ("effort", ["high"]), ("permissions", "bypass")):
            data = fixture()
            data["profiles"][0]["sessions"][0][field] = value
            self.assertFalse(selector.valid_input(data))
        data = fixture()
        data["profiles"][1]["id"] = "normal"
        self.assertFalse(selector.valid_input(data))

    def test_invalid_answer_falls_back_without_generated_settings(self):
        bodies = [None, {}, {"model": "other", "answers": {}}, response()]
        bodies[-1]["answers"]["profile"]["choice"] = "injected"
        for body in bodies:
            self.assertEqual(selector.evaluate(fixture(), body)["status"], "fallback")
        for value in (float("nan"), True, -1, 2, 10**400):
            body = response()
            body["answers"]["profile"]["probabilities"]["normal"] = value
            self.assertEqual(selector.evaluate(fixture(), body)["status"], "fallback")
        body = response()
        body["answers"]["profile"]["confidence"] = 10**400
        self.assertEqual(selector.evaluate(fixture(), body), selector.fallback("invalid_response"))

    def test_default_is_no_override(self):
        self.assertEqual(selector.evaluate(fixture(), response("default")), selector.fallback("no_selection"))

    @patch.dict(os.environ, {"TYPESAFE_API_KEY": "typesafe-test"}, clear=True)
    def test_provider_credentials_are_not_cross_sent(self):
        def forbidden(*args):
            self.fail("wrong provider must not receive this credential")
        self.assertEqual(selector.select(fixture(), provider="openjev", query_fn=forbidden), selector.fallback("key_unavailable"))
        self.assertEqual(selector.credential(None, "typesafe"), "typesafe-test")

    @patch.dict(os.environ, {"OPENJEV_API_KEY": "openjev-test"}, clear=True)
    def test_openjev_model_and_response_are_explicit(self):
        def fake(body, key):
            self.assertEqual(body["model"], "openjev")
            self.assertEqual(key, "openjev-test")
            result = response()
            result["model"] = "openjev"
            return result
        result = selector.select(fixture(), provider="openjev", query_fn=fake)
        self.assertEqual(result["status"], "selected")
        self.assertEqual(result["selectorModel"], "openjev")
        self.assertEqual(selector.evaluate(fixture(), response(), "openjev"), selector.fallback("invalid_response"))
        self.assertEqual(selector.credential(None, "typesafe"), "")

    def test_unknown_provider_is_blocked(self):
        for provider in ("https://other.invalid", [], None):
            self.assertEqual(selector.select(fixture(), provider=provider), {"status": "blocked", "reason": "invalid_provider"})

    @patch.dict(os.environ, {"OPENJEV_API_KEY": "openjev-test"}, clear=True)
    def test_production_query_uses_fixed_openjev_endpoint(self):
        response_data = response()
        response_data["model"] = "openjev"
        from unittest.mock import MagicMock
        opener = MagicMock()
        opener.open.return_value.__enter__.return_value.read.return_value = json.dumps(response_data).encode()
        with patch.object(selector.urllib.request, "build_opener", return_value=opener):
            self.assertEqual(selector.select(fixture(), provider="openjev")["status"], "selected")
        request = opener.open.call_args.args[0]
        self.assertEqual(request.full_url, "https://api.openjev.sh/v1/systemone")
        self.assertEqual(request.get_header("Authorization"), "Bearer openjev-test")

    @patch.dict(os.environ, {}, clear=True)
    def test_no_key_or_egress_means_no_request(self):
        def forbidden(*args):
            self.fail("network must not run")
        self.assertEqual(selector.select(fixture(), query_fn=forbidden), selector.fallback("key_unavailable"))
        data = {**fixture(), "egressApproved": False}
        self.assertEqual(selector.select(data, query_fn=forbidden), selector.fallback("egress_not_approved"))

    @patch.dict(os.environ, {"TYPESAFE_API_KEY": "test-value"}, clear=True)
    def test_single_request_uses_bounded_projection(self):
        calls = []
        def fake(body, key):
            calls.append(body)
            self.assertEqual(key, "test-value")
            self.assertEqual(set(body["state"]), {"task"})
            self.assertNotIn("egressApproved", json.dumps(body))
            return response()
        self.assertEqual(selector.select(fixture(), query_fn=fake)["status"], "selected")
        self.assertEqual(len(calls), 1)

    @patch.dict(os.environ, {"TYPESAFE_API_KEY": "test-value"}, clear=True)
    def test_http_timeout_and_bad_json_are_sanitized(self):
        for error, reason in ((urllib.error.HTTPError("url", 429, "secret detail", {}, io.BytesIO()), "rate_limited"),
                              (TimeoutError("secret detail"), "transport_error"),
                              (ValueError("secret detail"), "transport_error")):
            with patch.object(selector, "query", side_effect=error) as query:
                result = selector.select(fixture(), query_fn=query)
                self.assertEqual(result, selector.fallback(reason))
                self.assertEqual(query.call_count, 1)
                self.assertNotIn("secret", json.dumps(result))

    @patch.dict(os.environ, {}, clear=True)
    def test_explicit_file_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "key"
            path.write_text("test-value")
            path.chmod(0o644)
            self.assertEqual(selector.credential(path), "")
            path.chmod(0o600)
            self.assertEqual(selector.credential(path), "test-value")

    def test_redirect_is_refused(self):
        self.assertIsNone(selector.NoRedirect().redirect_request(None, None, 302, "", {}, "https://other.invalid"))

    def test_cli_missing_key_and_invalid_input(self):
        path = Path(selector.__file__)
        env = {key: value for key, value in os.environ.items() if key != "TYPESAFE_API_KEY"}
        for raw, status, code in ((json.dumps(fixture()), "fallback", 0), ("{", "blocked", 2), (" " * 16385, "blocked", 2)):
            result = subprocess.run([os.sys.executable, str(path)], input=raw, text=True, capture_output=True, env=env)
            self.assertEqual(result.returncode, code)
            self.assertEqual(json.loads(result.stdout)["status"], status)
            self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Exercise only the Claude invocation tail, without credentials, network or live jobs."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
START = 'echo "$(date \'+%F %T\') start (claude=$CLAUDE_BIN)" >> "$LOG"'
SUCCESS = json.dumps({"type": "result", "subtype": "success", "is_error": False, "result": "Verified no-op"})
CASES = [
    ("success", SUCCESS, "", 0, 0),
    ("auth_exit_zero", "Failed to authenticate: OAuth session expired and could not be refreshed\n", "", 0, 1),
    ("unknown_exit_zero", "Unknown command: /todo-gap\n", "", 0, 1),
    ("process_error", "", "provider unavailable\n", 17, 17),
    ("result_error", json.dumps({"type": "result", "subtype": "error_during_execution", "is_error": True}), "", 0, 1),
    ("invalid_result", "not JSON\n", "", 0, 1),
    ("missing_result", "{}", "", 0, 1),
    ("error_in_result", json.dumps({"type": "result", "subtype": "success", "is_error": False, "result": "Unknown command: /todo-gap"}), "", 0, 1),
    ("auth_in_result", json.dumps({"type": "result", "subtype": "success", "is_error": False, "result": "Failed to authenticate: OAuth session expired and could not be refreshed"}), "", 0, 1),
    ("quoted_unknown_in_success", json.dumps({"type": "result", "subtype": "success", "is_error": False, "result": "Fixed the previous failure:\nUnknown command: /todo-gap\nVerified update succeeded"}), "", 0, 0),
    ("quoted_auth_in_success", json.dumps({"type": "result", "subtype": "success", "is_error": False, "result": "Fixed the previous failure:\nFailed to authenticate: OAuth session expired and could not be refreshed\nVerified update succeeded"}), "", 0, 0),
]

class ScheduledSkillRunners(unittest.TestCase):
    def test_invocation_and_result_status(self):
        for skill in ["todo-gap-analysis", "wip-crawl"]:
            source = (REPO / "prompt/claude-code/skills" / skill / "run.sh").read_text()
            invocation = source[source.index(START):]
            for name, stdout, stderr, process_status, expected in CASES:
                with self.subTest(skill=skill, case=name), tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    stub = root / "claude-stub"
                    stub.write_text("#!" + sys.executable + "\n" +
                        "import json, os, pathlib, sys\n" +
                        "pathlib.Path(os.environ['STUB_ARGV']).write_text(json.dumps(sys.argv[1:]))\n" +
                        "sys.stdout.write(os.environ['STUB_STDOUT'])\n" +
                        "sys.stderr.write(os.environ['STUB_STDERR'])\n" +
                        "sys.exit(int(os.environ['STUB_EXIT']))\n")
                    stub.chmod(0o755)
                    log = root / "run.log"
                    argv_path = root / "argv.json"
                    env = dict(os.environ, STUB_ARGV=str(argv_path), STUB_STDOUT=stdout,
                               STUB_STDERR=stderr, STUB_EXIT=str(process_status))
                    setup = "set -eu\n" + "\n".join(
                        key + "=" + shlex.quote(str(value))
                        for key, value in [("CACHE", root), ("LOG", log), ("CLAUDE_BIN", stub)]
                    ) + "\n"
                    result = subprocess.run(["/bin/sh"], input=setup + invocation, text=True,
                                            capture_output=True, cwd=root, env=env)
                    self.assertEqual(result.returncode, expected, result.stderr + log.read_text())
                    self.assertEqual(any(line.endswith(" done") for line in log.read_text().splitlines()), expected == 0)
                    args = json.loads(argv_path.read_text())
                    self.assertTrue(args[args.index("-p") + 1].startswith("/" + skill))
                    self.assertIn("--output-format", args)
                    self.assertEqual(args[args.index("--output-format") + 1], "json")
                    self.assertIn("--dangerously-skip-permissions", args)
                    self.assertIn(stdout, log.read_text())
                    self.assertIn(stderr, log.read_text())

if __name__ == "__main__":
    unittest.main()

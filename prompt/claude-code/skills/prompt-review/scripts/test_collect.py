#!/usr/bin/env python3
import importlib.util
import json
import unittest
from pathlib import Path


collector_path = Path(__file__).with_name("collect.py")
spec = importlib.util.spec_from_file_location("prompt_review_collect", collector_path)
assert spec is not None and spec.loader is not None
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class PromptReviewProjectionTest(unittest.TestCase):
    source = {
        "tool": "Fixture Tool",
        "status": "検出",
        "period": "2026-08-27 00:00 〜 2026-08-27 00:01",
        "messages": [
            {
                "text": "do-not-emit-content api_key=fixture-value",
                "timestamp": "2026-08-27 00:00",
                "project": "fixture-project",
            }
        ],
    }

    def test_default_projection_excludes_message_text_and_values(self):
        output = collector.build_output(
            sources=[self.source],
            days=7,
            project=None,
            include_content=False,
            collected_at="2026-08-27 00:02 UTC",
        )
        serialized = json.dumps(output, ensure_ascii=False)

        self.assertFalse(output["summary"]["content_included"])
        self.assertNotIn("messages", output["sources"][0])
        self.assertNotIn("do-not-emit-content", serialized)
        self.assertNotIn("fixture-value", serialized)
        self.assertNotIn("masked_value", serialized)
        self.assertNotIn("prompt_excerpt", serialized)
        self.assertEqual(
            output["secret_warnings"],
            [{"tool": "Fixture Tool", "type": "API Key", "count": 1}],
        )

    def test_explicit_content_projection_preserves_messages(self):
        output = collector.build_output(
            sources=[self.source],
            days=7,
            project=None,
            include_content=True,
            collected_at="2026-08-27 00:02 UTC",
        )

        self.assertTrue(output["summary"]["content_included"])
        self.assertEqual(output["sources"][0]["messages"], self.source["messages"])


if __name__ == "__main__":
    unittest.main()

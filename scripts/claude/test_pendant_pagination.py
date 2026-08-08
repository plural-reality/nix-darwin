#!/usr/bin/env python3
"""Limitless の response shape と複数ページ取得の退行テスト。"""
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path


def load_module():
    path = Path(__file__).with_name("pendant.py")
    spec = importlib.util.spec_from_file_location("pendant_under_test", path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_cursor_shape(module) -> None:
    client = object.__new__(module.LimitlessClient)
    client.tz = "Asia/Tokyo"
    client._get = lambda _path, _params: {
        "data": {"lifelogs": []},
        "meta": {"lifelogs": {"nextCursor": "cursor-2"}},
    }
    logs, cursor = client.get_lifelogs(date="2026-08-01")
    assert logs == []
    assert cursor == "cursor-2"


def test_all_pages(module) -> None:
    pages = {
        None: ([module.Conversation("a", "limitless", "", "", "", "2026-08-01T00:00:00Z", "")], "c2"),
        "c2": ([module.Conversation("b", "limitless", "", "", "", "2026-08-01T01:00:00Z", "")], None),
    }

    class FakeLimitless:
        get_lifelogs = lambda self, **kwargs: pages[kwargs.get("cursor")]

    api = object.__new__(module.PendantAPI)
    api.limitless = FakeLimitless()
    assert [item.id for item in api.by_date("2026-08-01", "limitless")] == ["b", "a"]


def test_export_rebuilds_without_duplicates(module) -> None:
    conversation = module.Conversation("a", "limitless", "", "", "", "2026-08-01T00:00:00Z", "")

    class FakeLimitless:
        calls = []

        def get_lifelogs(self, **kwargs):
            self.calls.append(kwargs)
            return ([conversation], None)

    class FakeConfig:
        pass

    with tempfile.TemporaryDirectory() as root:
        config = FakeConfig()
        config.export_dir = Path(root)
        api = object.__new__(module.PendantAPI)
        api.limitless = FakeLimitless()
        exporter = module.Exporter(api, config)
        assert exporter.export_limitless() == 1
        assert exporter.export_limitless() == 1
        lines = Path(root, "limitless/2026-08-01.jsonl").read_text().splitlines()
        assert len(lines) == 1
        assert all(call["limit"] == 10 for call in api.limitless.calls)


def main() -> None:
    module = load_module()
    test_cursor_shape(module)
    test_all_pages(module)
    test_export_rebuilds_without_duplicates(module)
    print("ALL PASS")


if __name__ == "__main__":
    main()

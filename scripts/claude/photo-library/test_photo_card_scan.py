#!/usr/bin/env python3

import importlib.util
import json
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch


SOURCE = Path(__file__).with_name("photo-card-scan.py")
SPEC = importlib.util.spec_from_file_location("photo_card_scan", SOURCE)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def fixture(asset_id: str, creation_date: str | None = None) -> dict:
    return {
        "type": "asset",
        "asset": {
            "id": asset_id,
            "creationDate": creation_date,
            "modificationDate": None,
            "pixelWidth": 100,
            "pixelHeight": 100,
        },
    }


with tempfile.TemporaryDirectory() as directory:
    state = Path(directory)
    recent = datetime.now(timezone.utc).isoformat()
    responses = [
        [fixture("old", "2020-01-01T00:00:00+00:00"), fixture("new", recent)],
        [{"type": "classification", "classification": {
            "id": "new", "signals": {"candidate": True}}}],
        [{"type": "export", "export": {
            "id": "new", "path": "/tmp/new.jpg", "sha256": "abc"}}],
    ]
    with patch.object(MODULE, "run_jsonl", side_effect=responses):
        first = MODULE.scan(state, 7)
    assert first["newAssetCount"] == 1
    assert first["candidateCount"] == 1
    assert MODULE.pending(state)[0]["runId"] == first["runId"]

    acknowledged = MODULE.acknowledge(state, first["runId"])
    assert acknowledged["status"] == "complete"
    assert MODULE.pending(state) == []

    snapshot = json.loads((state / "snapshot.json").read_text())
    assert snapshot["assetIds"] == ["new", "old"]

print("photo-card-scan tests: passed")

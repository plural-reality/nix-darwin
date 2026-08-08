#!/usr/bin/env python3
"""Weekly Photos snapshot diff and local business-card candidate queue."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable


def run_jsonl(request: dict[str, Any]) -> list[dict[str, Any]]:
    completed = subprocess.run(
        [os.environ.get("PHOTO_LIBRARY_CLIENT", "photo-library"), "request"],
        input=json.dumps(request, separators=(",", ":")) + "\n",
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    records = [json.loads(line) for line in completed.stdout.splitlines() if line.strip()]
    terminal = records[-1] if records else {"type": "end", "ok": False, "error": "empty response"}
    terminal.get("ok") is True or (_ for _ in ()).throw(
        RuntimeError(terminal.get("error") or completed.stderr.strip() or "PhotoLibraryBridge failed")
    )
    return records[:-1]


def chunks(values: list[str], size: int) -> Iterable[list[str]]:
    return (values[index : index + size] for index in range(0, len(values), size))


def read_state(path: Path) -> set[str] | None:
    return set(json.loads(path.read_text())["assetIds"]) if path.exists() else None


def parse_date(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value.replace("Z", "+00:00")) if value else None


def bootstrap_ids(assets: list[dict[str, Any]], days: int) -> set[str]:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    return {
        asset["id"]
        for asset in assets
        if (created := parse_date(asset.get("creationDate"))) is not None and created >= cutoff
    }


def atomic_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w") as handle:
            json.dump(value, handle, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            handle.write("\n")
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def classify(asset_ids: list[str]) -> list[dict[str, Any]]:
    return [
        record["classification"]
        for batch in chunks(asset_ids, 50)
        for record in run_jsonl({"op": "classify", "spec": {"assetIds": batch}})
        if record.get("type") == "classification"
    ]


def export(asset_ids: list[str], run_id: str) -> list[dict[str, Any]]:
    return [
        record["export"]
        for batch in chunks(asset_ids, 50)
        for record in run_jsonl({"op": "export", "spec": {"assetIds": batch, "runId": run_id}})
        if record.get("type") == "export"
    ]


def scan(state_dir: Path, bootstrap_days: int) -> dict[str, Any]:
    snapshot_records = run_jsonl({"op": "snapshot"})
    assets = [record["asset"] for record in snapshot_records if record.get("type") == "asset"]
    current_ids = {asset["id"] for asset in assets}
    snapshot_hash = hashlib.sha256("\n".join(sorted(current_ids)).encode()).hexdigest()
    state_path = state_dir / "snapshot.json"
    previous = read_state(state_path)
    new_ids = sorted(current_ids - previous) if previous is not None else sorted(bootstrap_ids(assets, bootstrap_days))
    classifications = classify(new_ids) if new_ids else []
    candidate_ids = sorted(record["id"] for record in classifications if record["signals"]["candidate"])
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + snapshot_hash[:12]
    exports = export(candidate_ids, run_id) if candidate_ids else []
    manifest = {
        "version": 1,
        "classifierVersion": 2,
        "runId": run_id,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "snapshotHash": snapshot_hash,
        "previousAssetCount": len(previous or set()),
        "currentAssetCount": len(current_ids),
        "newAssetCount": len(new_ids),
        "candidateCount": len(candidate_ids),
        "candidates": exports,
        "classifications": classifications,
        "status": "pending" if exports else "complete",
    }
    atomic_json(state_path, {"version": 1, "snapshotHash": snapshot_hash, "assetIds": sorted(current_ids)})
    exports and atomic_json(state_dir / "jobs" / f"{run_id}.json", manifest)
    return manifest


def pending(state_dir: Path) -> list[dict[str, Any]]:
    jobs = sorted((state_dir / "jobs").glob("*.json")) if (state_dir / "jobs").exists() else []
    return [value for path in jobs if (value := json.loads(path.read_text())).get("status") == "pending"]


def acknowledge(state_dir: Path, run_id: str) -> dict[str, Any]:
    path = state_dir / "jobs" / f"{run_id}.json"
    value = json.loads(path.read_text())
    updated = {**value, "status": "complete", "completedAt": datetime.now(timezone.utc).isoformat()}
    atomic_json(path, updated)
    return updated


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser()
    value.add_argument(
        "--state-dir",
        type=Path,
        default=Path(os.environ.get(
            "PHOTO_CARD_STATE_DIR",
            Path.home() / "Library/Application Support/PhotoCardScanner")),
    )
    subcommands = value.add_subparsers(dest="command", required=True)
    run = subcommands.add_parser("run")
    run.add_argument("--bootstrap-days", type=int, default=7)
    subcommands.add_parser("pending")
    ack = subcommands.add_parser("ack")
    ack.add_argument("run_id")
    return value


def main() -> int:
    args = parser().parse_args()
    args.state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    result = (
        scan(args.state_dir, args.bootstrap_days)
        if args.command == "run"
        else pending(args.state_dir)
        if args.command == "pending"
        else acknowledge(args.state_dir, args.run_id)
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        raise SystemExit(1)

#!/usr/bin/env python3
"""Merge Nix-managed Codex policy while preserving runtime-owned state."""

from __future__ import annotations

from collections.abc import MutableMapping
from datetime import datetime, timezone
from pathlib import Path
import json
import sys

import tomlkit


RUNTIME_MCP_SERVERS = frozenset({"node_repl", "openaiDeveloperDocs"})

# The loopback router these two selected is retired. They are matched by exact value so a
# deliberate override survives; only the retired wiring is dropped.
RETIRED_ROUTER_BASE_URL = "http://127.0.0.1:21434/v1"
RETIRED_ROUTER_PROVIDER = "codex-router"


def merge(target: MutableMapping, source: MutableMapping) -> MutableMapping:
    """Recursively project source values into target."""
    for key, value in source.items():
        if isinstance(value, dict):
            current = target.get(key)
            target[key] = merge(
                current if isinstance(current, MutableMapping) else tomlkit.table(),
                value,
            )
        else:
            target[key] = value
    return target


def replace_mcp_servers(document: MutableMapping) -> MutableMapping:
    """Reset the table to Codex Desktop runtime adapters before projection."""
    servers = document.get("mcp_servers")
    runtime_servers = (
        {name: servers[name] for name in RUNTIME_MCP_SERVERS if name in servers}
        if isinstance(servers, MutableMapping)
        else {}
    )
    document["mcp_servers"] = tomlkit.table()
    return merge(document, {"mcp_servers": runtime_servers})


def replace_plugins(document: MutableMapping, managed: MutableMapping) -> MutableMapping:
    """Treat plugin enablement as an exact Nix projection, not mutable policy."""
    document["plugins"] = tomlkit.table()
    return merge(document, {"plugins": managed.get("plugins", {})})


def remove_retired_policy(document: MutableMapping) -> MutableMapping:
    """Remove policy fields that an earlier Nix projection used to manage."""
    document.pop("profiles", None)
    document.pop("service_tier", None)
    shell_policy = document.get("shell_environment_policy")
    environment = shell_policy.get("set") if isinstance(shell_policy, MutableMapping) else None
    # A rotating Scrapbox session belongs to its fail-closed runtime adapter, never config.toml.
    isinstance(environment, MutableMapping) and environment.pop("SCRAPBOX_SID", None)
    features = document.get("features")
    multi_agent = features.get("multi_agent_v2") if isinstance(features, MutableMapping) else None
    isinstance(multi_agent, MutableMapping) and multi_agent.pop("max_concurrent_threads_per_session", None)
    # Dropping these from the projection is not enough: this merge preserves keys the
    # source no longer names, so the dead loopback address would stay in the mutable file
    # and every new thread would record `codex-router` again, keeping the compatibility
    # alias alive forever. The provider definition itself stays -- threads created while
    # the router ran carry that id and an unknown id is fatal.
    document.get("openai_base_url") == RETIRED_ROUTER_BASE_URL and document.pop("openai_base_url", None)
    document.get("model_provider") == RETIRED_ROUTER_PROVIDER and document.pop("model_provider", None)
    return document


def project(document: MutableMapping, managed: MutableMapping) -> MutableMapping:
    """Pure policy projection over a parsed TOML document."""
    return merge(remove_retired_policy(replace_plugins(replace_mcp_servers(document), managed)), managed)


def load_document(config_path: Path) -> MutableMapping:
    try:
        return tomlkit.parse(config_path.read_text()) if config_path.exists() else tomlkit.document()
    except Exception as exc:
        backup_path = config_path.with_suffix(
            f".toml.invalid-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}"
        )
        config_path.rename(backup_path)
        print(f"warning: moved invalid Codex config to {backup_path}: {exc}", file=sys.stderr)
        return tomlkit.document()


def main(argv: list[str]) -> int:
    managed_path, config_path = map(Path, argv)
    managed = json.loads(managed_path.read_text())
    document = load_document(config_path)
    config_path.write_text(tomlkit.dumps(project(document, managed)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

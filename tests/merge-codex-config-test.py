#!/usr/bin/env python3
"""Dependency-light policy check for Codex config projection."""

from __future__ import annotations

import importlib.util
from pathlib import Path

import tomlkit


SCRIPT = Path(__file__).parents[1] / "scripts" / "merge-codex-config.py"
SPEC = importlib.util.spec_from_file_location("merge_codex_config", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def main() -> None:
    current = tomlkit.parse(
        """
service_tier = "priority"
[mcp_servers.scrapbox]
command = "npx"
token = "secret"
[mcp_servers.node_repl]
command = "runtime"
[mcp_servers.Mori]
stale_token = "secret"
[plugins."gmail@openai-curated"]
enabled = true
[features.multi_agent_v2]
enabled = true
max_concurrent_threads_per_session = 3
[projects."/tmp/example"]
trust_level = "trusted"
"""
    )
    managed = {
        "mcp_servers": {"Mori": {"url": "https://mcp.mori.to", "enabled": True}},
        "plugins": {"gmail@openai-curated": {"enabled": False}},
    }
    projected = MODULE.project(current, managed)
    assert set(projected["mcp_servers"]) == {"node_repl", "Mori"}
    assert "stale_token" not in projected["mcp_servers"]["Mori"]
    assert projected["plugins"] == {"gmail@openai-curated": {"enabled": False}}
    assert projected["projects"]["/tmp/example"]["trust_level"] == "trusted"
    assert "service_tier" not in projected
    assert projected["features"]["multi_agent_v2"] == {"enabled": True}


if __name__ == "__main__":
    main()

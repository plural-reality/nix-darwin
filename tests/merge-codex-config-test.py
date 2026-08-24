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


BACKEND = "https://chatgpt.com/backend-api/codex"


def main() -> None:
    current = tomlkit.parse(
        """
service_tier = "priority"
openai_base_url = "http://127.0.0.1:21434/v1"
model_provider = "codex-router"
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
[shell_environment_policy.set]
SCRAPBOX_SID = "stale-secret"
BROWSER_USE_AVAILABLE_BACKENDS = "chrome,iab"
[projects."/tmp/example"]
trust_level = "trusted"
"""
    )
    managed = {
        "model_providers": {"codex-router": {"base_url": BACKEND}},
        "mcp_servers": {"Mori": {"url": "https://mcp.mori.to", "enabled": True}},
        "plugins": {"gmail@openai-curated": {"enabled": False}},
    }
    projected = MODULE.project(current, managed)
    assert set(projected["mcp_servers"]) == {"node_repl", "Mori"}
    assert "stale_token" not in projected["mcp_servers"]["Mori"]
    assert projected["plugins"] == {"gmail@openai-curated": {"enabled": False}}
    assert projected["projects"]["/tmp/example"]["trust_level"] == "trusted"
    assert "service_tier" not in projected
    # The retired router wiring is gone, so new threads stop recording its provider id...
    assert "openai_base_url" not in projected
    assert "model_provider" not in projected
    # ...while the definition threads already recorded still resolves.
    assert projected["model_providers"]["codex-router"]["base_url"] == BACKEND
    assert projected["features"]["multi_agent_v2"] == {"enabled": True}
    assert "SCRAPBOX_SID" not in projected["shell_environment_policy"]["set"]
    assert projected["shell_environment_policy"]["set"]["BROWSER_USE_AVAILABLE_BACKENDS"] == "chrome,iab"


def test_deliberate_override_survives_retirement() -> None:
    """Only the retired router wiring is dropped, not any value under the same keys."""
    projected = MODULE.project(
        tomlkit.parse('openai_base_url = "https://proxy.example/v1"\nmodel_provider = "mine"\n'),
        {},
    )
    assert projected["openai_base_url"] == "https://proxy.example/v1"
    assert projected["model_provider"] == "mine"


if __name__ == "__main__":
    main()
    test_deliberate_override_survives_retirement()

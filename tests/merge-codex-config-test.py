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
model_catalog_json = "/nix/store/old-codex-model-catalog.json"
[mcp_servers.scrapbox]
command = "npx"
token = "secret"
[mcp_servers.node_repl]
command = "runtime"
[mcp_servers.node_repl.env]
BROWSER_USE_AVAILABLE_BACKENDS = "chrome,iab"
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
[[skills.config]]
path = "/Users/example/.agents/skills/shared/SKILL.md"
enabled = true
[[skills.config]]
path = "/Users/example/.agents/skills/personal-only/SKILL.md"
enabled = false
[[skills.config]]
name = "explicit-only"
enabled = false
"""
    )
    managed = {
        "model_providers": {"codex-router": {"base_url": BACKEND}},
        "mcp_servers": {"Mori": {"url": "https://mcp.mori.to", "enabled": True}},
        "plugins": {"gmail@openai-curated": {"enabled": False}},
        "shell_environment_policy": {
            "set": {"BROWSER_USE_AVAILABLE_BACKENDS": "chrome"}
        },
        "skills": {
            "config": [
                {
                    "path": "/Users/example/.agents/skills/shared/SKILL.md",
                    "enabled": False,
                }
            ]
        },
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
    assert "model_catalog_json" not in projected
    # ...while the definition threads already recorded still resolves.
    assert projected["model_providers"]["codex-router"]["base_url"] == BACKEND
    assert projected["features"]["multi_agent_v2"] == {"enabled": True}
    assert "SCRAPBOX_SID" not in projected["shell_environment_policy"]["set"]
    assert projected["shell_environment_policy"]["set"]["BROWSER_USE_AVAILABLE_BACKENDS"] == "chrome"
    assert projected["mcp_servers"]["node_repl"]["env"]["BROWSER_USE_AVAILABLE_BACKENDS"] == "chrome"
    assert projected["skills"]["config"] == [
        {
            "path": "/Users/example/.agents/skills/personal-only/SKILL.md",
            "enabled": False,
        },
        {"name": "explicit-only", "enabled": False},
        {
            "path": "/Users/example/.agents/skills/shared/SKILL.md",
            "enabled": False,
        },
    ]
    no_runtime = MODULE.project(tomlkit.parse(""), managed)
    assert "node_repl" not in no_runtime["mcp_servers"]

    profile = tomlkit.parse(
        """
[shell_environment_policy.set]
BROWSER_USE_AVAILABLE_BACKENDS = "chrome,iab"
[mcp_servers.node_repl.env]
BROWSER_USE_AVAILABLE_BACKENDS = "chrome,iab"
"""
    )
    profile_managed = {
        "shell_environment_policy": {
            "set": {"BROWSER_USE_AVAILABLE_BACKENDS": "chrome"}
        },
        "mcp_servers": {
            "node_repl": {
                "command": "/nix/store/codex-node-repl-profile-guard/bin/codex-node-repl-profile-guard",
                "env": {"BROWSER_USE_AVAILABLE_BACKENDS": "chrome"},
            }
        },
    }
    projected_profile = MODULE.project(profile, profile_managed)
    assert (
        projected_profile["shell_environment_policy"]["set"][
            "BROWSER_USE_AVAILABLE_BACKENDS"
        ]
        == "chrome"
    )
    projected_profile_without_runtime = MODULE.project(
        tomlkit.parse(""), profile_managed
    )
    assert (
        projected_profile_without_runtime["mcp_servers"]["node_repl"]["command"]
        == "/nix/store/codex-node-repl-profile-guard/bin/codex-node-repl-profile-guard"
    )
    assert (
        projected_profile_without_runtime["mcp_servers"]["node_repl"]["env"][
            "BROWSER_USE_AVAILABLE_BACKENDS"
        ]
        == "chrome"
    )
    assert (
        projected_profile["mcp_servers"]["node_repl"]["env"][
            "BROWSER_USE_AVAILABLE_BACKENDS"
        ]
        == "chrome"
    )


def test_deliberate_override_survives_retirement() -> None:
    """Only known retired managed values are dropped, not deliberate overrides."""
    projected = MODULE.project(
        tomlkit.parse(
            'openai_base_url = "https://proxy.example/v1"\n'
            'model_provider = "mine"\n'
            'model_catalog_json = "/Users/example/custom-model-catalog.json"\n'
        ),
        {},
    )
    assert projected["openai_base_url"] == "https://proxy.example/v1"
    assert projected["model_provider"] == "mine"
    assert projected["model_catalog_json"] == "/Users/example/custom-model-catalog.json"


if __name__ == "__main__":
    main()
    test_deliberate_override_survives_retirement()

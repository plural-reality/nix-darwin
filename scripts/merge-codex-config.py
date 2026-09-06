#!/usr/bin/env python3
"""Merge Nix-managed Codex policy while preserving runtime-owned state."""

from __future__ import annotations

from collections.abc import MutableMapping
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
import json
import sys

import tomlkit


RUNTIME_MCP_SERVERS = frozenset({"node_repl", "openaiDeveloperDocs"})
RUNTIME_PLUGINS = frozenset({
    "computer-history@openai-bundled",
    "unified-computer-use@openai-bundled",
})
BROWSER_BACKEND_ENV = "BROWSER_USE_AVAILABLE_BACKENDS"

# The loopback router these two selected is retired. They are matched by exact value so a
# deliberate override survives; only the retired wiring is dropped.
RETIRED_ROUTER_BASE_URL = "http://127.0.0.1:21434/v1"
RETIRED_ROUTER_PROVIDER = "codex-router"
RETIRED_MODEL_CATALOG_SUFFIX = "-codex-model-catalog.json"


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


def project_runtime_browser_backend(
    document: MutableMapping, managed: MutableMapping
) -> MutableMapping:
    """Carry the declarative backend allow-list into the runtime browser adapter."""
    managed_shell_policy = managed.get("shell_environment_policy")
    managed_environment = (
        managed_shell_policy.get("set")
        if isinstance(managed_shell_policy, MutableMapping)
        else None
    )
    backend = (
        managed_environment.get(BROWSER_BACKEND_ENV)
        if isinstance(managed_environment, MutableMapping)
        else None
    )
    servers = document.get("mcp_servers")
    node_repl = (
        servers.get("node_repl")
        if isinstance(servers, MutableMapping)
        else None
    )
    if not isinstance(node_repl, MutableMapping) or backend is None:
        return document
    runtime_environment = node_repl.get("env")
    node_repl["env"] = (
        runtime_environment
        if isinstance(runtime_environment, MutableMapping)
        else tomlkit.table()
    )
    node_repl["env"][BROWSER_BACKEND_ENV] = backend
    return document


def replace_mcp_servers(
    document: MutableMapping, managed: MutableMapping
) -> MutableMapping:
    """Reset the table to Codex Desktop runtime adapters before projection."""
    servers = document.get("mcp_servers")
    runtime_servers = (
        {name: servers[name] for name in RUNTIME_MCP_SERVERS if name in servers}
        if isinstance(servers, MutableMapping)
        else {}
    )
    document["mcp_servers"] = tomlkit.table()
    return project_runtime_browser_backend(
        merge(document, {"mcp_servers": runtime_servers}), managed
    )


def replace_plugins(document: MutableMapping, managed: MutableMapping) -> MutableMapping:
    """Preserve native Desktop choices; explicit Nix policy still takes precedence."""
    plugins = document.get("plugins")
    runtime_plugins = (
        {name: plugins[name] for name in RUNTIME_PLUGINS if name in plugins}
        if isinstance(plugins, MutableMapping)
        else {}
    )
    document["plugins"] = tomlkit.table()
    merge(document, {"plugins": runtime_plugins})
    return merge(document, {"plugins": managed.get("plugins", {})})


def skill_selector(entry: object) -> tuple[str, str] | None:
    """Return the stable selector used by one skills.config entry."""
    if not isinstance(entry, MutableMapping):
        return None
    for key in ("path", "name"):
        value = entry.get(key)
        if isinstance(value, str) and value:
            return key, value
    return None


def preserve_unmanaged_skill_config(
    document: MutableMapping, managed: MutableMapping
) -> MutableMapping:
    """Add managed skill selectors without deleting unrelated user choices."""
    projected = deepcopy(managed)
    managed_skills = projected.get("skills")
    managed_entries = (
        managed_skills.get("config")
        if isinstance(managed_skills, MutableMapping)
        else None
    )
    current_skills = document.get("skills")
    current_entries = (
        current_skills.get("config")
        if isinstance(current_skills, MutableMapping)
        else None
    )
    if not isinstance(managed_entries, list):
        return projected
    managed_selectors = {
        selector for entry in managed_entries if (selector := skill_selector(entry))
    }
    preserved = (
        [
            entry
            for entry in current_entries
            if skill_selector(entry) not in managed_selectors
        ]
        if isinstance(current_entries, list)
        else []
    )
    managed_skills["config"] = [*preserved, *managed_entries]
    return projected


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
    model_catalog = document.get("model_catalog_json")
    (
        isinstance(model_catalog, str)
        and model_catalog.startswith("/nix/store/")
        and model_catalog.endswith(RETIRED_MODEL_CATALOG_SUFFIX)
        and document.pop("model_catalog_json", None)
    )
    return document


def project(document: MutableMapping, managed: MutableMapping) -> MutableMapping:
    """Pure policy projection over a parsed TOML document."""
    managed_with_user_skill_choices = preserve_unmanaged_skill_config(document, managed)
    return merge(
        remove_retired_policy(
            replace_plugins(
                replace_mcp_servers(document, managed_with_user_skill_choices),
                managed_with_user_skill_choices,
            )
        ),
        managed_with_user_skill_choices,
    )


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

#!/usr/bin/env python3
"""Run the Desktop-owned node_repl through the profile browser guard.

The Codex profile must contain a complete MCP transport to remain valid when
Desktop has not written node_repl yet.  The guard therefore resolves the
transport from the base runtime config at launch time and only owns the
browser-backend environment variable.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tomllib


BACKEND = "chrome"
EXIT_BLOCKED = 78


def blocked(reason: str) -> int:
    print(
        json.dumps(
            {"ok": False, "status": "browser-backend-blocked", "reason": reason},
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        file=sys.stderr,
    )
    return EXIT_BLOCKED


def runtime_server(
    config_path: Path,
) -> tuple[str, list[str], dict[str, str], str | None] | None:
    try:
        with config_path.open("rb") as stream:
            document = tomllib.load(stream)
    except (OSError, tomllib.TOMLDecodeError):
        return None

    servers = document.get("mcp_servers")
    server = servers.get("node_repl") if isinstance(servers, dict) else None
    command = server.get("command") if isinstance(server, dict) else None
    args = server.get("args", []) if isinstance(server, dict) else None
    environment = server.get("env", {}) if isinstance(server, dict) else None
    cwd = server.get("cwd") if isinstance(server, dict) else None
    valid_args = isinstance(args, list) and all(isinstance(item, str) for item in args)
    valid_environment = isinstance(environment, dict) and all(
        isinstance(key, str) and isinstance(value, str)
        for key, value in environment.items()
    )
    valid_cwd = cwd is None or isinstance(cwd, str)
    return (
        (command, args, environment, cwd)
        if isinstance(command, str)
        and command
        and valid_args
        and valid_environment
        and valid_cwd
        else None
    )


def main() -> int:
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    server = runtime_server(codex_home / "config.toml")

    return (
        blocked("Desktop-owned node_repl transport is not available")
        if server is None
        else launch(server)
    )


def launch(server: tuple[str, list[str], dict[str, str], str | None]) -> int:
    command, args, runtime_environment, cwd = server
    child_environment = {
        **os.environ,
        **runtime_environment,
        "BROWSER_USE_AVAILABLE_BACKENDS": BACKEND,
    }
    return (
        blocked("profile guard cannot execute itself")
        if Path(command).resolve() == Path(sys.argv[0]).resolve()
        else execute(command, args, child_environment, cwd)
    )


def execute(
    command: str,
    args: list[str],
    environment: dict[str, str],
    cwd: str | None,
) -> int:
    try:
        cwd and os.chdir(cwd)
        os.execvpe(command, [command, *args], environment)
    except (OSError, ValueError):
        return blocked("Desktop-owned node_repl transport could not start")
    return blocked("node_repl transport exited before exec")


raise SystemExit(main())

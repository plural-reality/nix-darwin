#!/bin/sh
# zwift-mode.swift を再コンパイルする。.swift を編集したら必ず実行(compiled binary なので)。
# canonical な「配線」は /etc/nix-darwin/personal.nix の launchd.agents.zwift-mode、
# canonical な「ロジック」はこの zwift-mode.swift。バイナリはその build 成果物。
set -eu
dir="$(cd "$(dirname "$0")" && pwd)"
exec swiftc -O "$dir/zwift-mode.swift" -o "$dir/zwift-mode"

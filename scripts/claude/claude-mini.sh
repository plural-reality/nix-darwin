#!/usr/bin/env bash
# claude -> Mac mini delegator. All args are forwarded.
exec "$(dirname "$0")/run-on-mini.sh" cc claude "$@"

#!/usr/bin/env bash
# JIOH-14: only autoload/world_clock.gd may read the OS clock.
# Run from the project root. Exits non-zero if Time.get_ appears elsewhere.
set -euo pipefail
cd "$(dirname "$0")/.."
hits=$(grep -rn --include='*.gd' 'Time\.get_' . | grep -v '^\./autoload/world_clock\.gd:' | grep -v '^\./\.godot/' || true)
if [[ -n "$hits" ]]; then
	echo "Direct OS time calls outside autoload/world_clock.gd:" >&2
	echo "$hits" >&2
	exit 1
fi
echo "check_time_calls: OK"

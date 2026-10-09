#!/usr/bin/env bash
# Runs every probe scene headless plus the static time-call check.
# GODOT defaults to `godot` on PATH.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
status=0
tools/check_time_calls.sh || status=1
"$GODOT" --headless --path . --import >/dev/null 2>&1
for scene in tests/*Probe.tscn; do
	out=$(timeout 120 "$GODOT" --headless --path . "res://$scene" 2>&1)
	code=$?
	echo "$out" | grep -E "PROBE FAIL|PASSED|FAILED|SCRIPT ERROR|ERROR:" || true
	if [[ $code -ne 0 ]] || echo "$out" | grep -q "SCRIPT ERROR"; then
		echo "FAILED: $scene" >&2
		status=1
	fi
done
soak=$(timeout 300 "$GODOT" --headless --path . --script res://tools/debug/soak_fortnight.gd 2>&1)
code=$?
echo "$soak" | grep -E "SOAK|SCRIPT ERROR" || true
[[ $code -eq 0 ]] || { echo "FAILED: fortnight soak" >&2; status=1; }
exit $status

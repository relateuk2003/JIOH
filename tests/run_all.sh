#!/usr/bin/env bash
# Runs every probe scene headless plus the static time-call check.
# GODOT defaults to `godot` on PATH.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
status=0
tools/check_time_calls.sh || status=1
tools/check_validator_refs.sh || status=1
tools/check_text_paths.sh || status=1
"$GODOT" --headless --path . --import >/dev/null 2>&1
ids=$(timeout 120 "$GODOT" --headless --path . --script res://tools/validate_persistent_ids.gd 2>&1)
code=$?
echo "$ids" | grep validate_persistent_ids
[[ $code -eq 0 ]] || status=1
audit=$(timeout 120 "$GODOT" --headless --path . res://tools/knowledge_auditor.tscn 2>&1)
code=$?
echo "$audit" | grep knowledge_auditor
[[ $code -eq 0 ]] || status=1
roster=$(timeout 120 "$GODOT" --headless --path . res://tools/validate_roster_cli.tscn 2>&1)
code=$?
echo "$roster" | grep validate_roster
[[ $code -eq 0 ]] || status=1
for scene in tests/*Probe.tscn; do
	out=$(timeout 120 "$GODOT" --headless --fixed-fps 60 --path . "res://$scene" 2>&1)
	code=$?
	echo "$out" | grep -E "PROBE FAIL|PASSED|FAILED|SCRIPT ERROR|ERROR:" || true
	if [[ $code -ne 0 ]] || echo "$out" | grep -q "SCRIPT ERROR"; then
		echo "FAILED: $scene" >&2
		status=1
	fi
done
# GPU probes render real pixels; they need a display, so use Xvfb when there
# is none.
for scene in tests/gpu/*Probe.tscn; do
	if [[ -n "${DISPLAY:-}" ]]; then
		out=$(timeout 180 "$GODOT" --path . --rendering-driver opengl3 "res://$scene" 2>&1)
	elif command -v xvfb-run >/dev/null; then
		out=$(timeout 180 xvfb-run -a -s "-screen 0 3440x1440x24" "$GODOT" --path . --rendering-driver opengl3 "res://$scene" 2>&1)
	else
		echo "SKIPPED (no display): $scene"
		continue
	fi
	code=$?
	echo "$out" | grep -E "PROBE FAIL|PASSED|FAILED|SCRIPT ERROR" || true
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

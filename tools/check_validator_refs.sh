#!/usr/bin/env bash
# tools/check_validator_refs.sh — JIOH-29: the validator runs at handout and
# nowhere else. Fails if PackValidator is called from more than one place in
# game code (tests and the validator itself are exempt). Until the handout
# system (JIOH-30) exists the allowed count is zero callers or one; once it
# landed, so REQUIRED=1: the hatch is the one caller.
set -euo pipefail
cd "$(dirname "$0")/.."
REQUIRED="${REQUIRED:-1}"
refs=$(grep -rn --include='*.gd' 'PackValidator\.score(' . \
	| grep -v '^./tests/' | grep -v '^./scripts/validation/' | grep -v '^./.godot/' || true)
count=$(printf '%s' "$refs" | grep -c . || true)
if (( count > 1 )) || (( REQUIRED == 1 && count != 1 )); then
	echo "check_validator_refs: PackValidator called from $count places (want ${REQUIRED/0/at most 1}):"
	echo "$refs"
	exit 1
fi
echo "check_validator_refs: OK ($count caller)"

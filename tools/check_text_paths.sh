#!/usr/bin/env bash
# tools/check_text_paths.sh — JIOH-63: one text rendering path. Fails on any
# scalable font under resources/fonts, and on Label3D, SystemFont or the
# engine's fallback font anywhere in shipped scenes and scripts. Developer
# overlays (scripts/debug, tools/debug) and tests are exempt.
set -euo pipefail
cd "$(dirname "$0")/.."
status=0
fonts=$(find resources/fonts -iname '*.ttf' -o -iname '*.otf' -o -iname '*.woff*' 2>/dev/null || true)
if [[ -n "$fonts" ]]; then
	echo "check_text_paths: scalable fonts found:"; echo "$fonts"; status=1
fi
refs=$(grep -rnE 'Label3D|SystemFont|fallback_font' --include='*.gd' --include='*.tscn' --include='*.tres' . \
	| grep -vE '^\./(tests|scripts/debug|tools/debug|\.godot)/' \
	| grep -vE '^[^:]+:[0-9]+:\s*(#|##)' || true)
if [[ -n "$refs" ]]; then
	echo "check_text_paths: forbidden text nodes:"; echo "$refs"; status=1
fi
[[ $status -eq 0 ]] && echo "check_text_paths: OK"
exit $status

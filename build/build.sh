#!/usr/bin/env bash
# build/build.sh — JIOH-60: the one way to make shippable artefacts.
#
#   build/build.sh             local build: Windows, Linux (and macOS, not a gate)
#   build/build.sh --release   the same, refused on a dirty tree; appends CHANGELOG.md
#
# Shaped like the OTIF build: headless Godot, one preset per invocation, stop
# at the first failure. The version is git describe, baked into
# resources/build_info.tres for the export (and put back afterwards) so the
# game can show it, and stamped on every artefact name. Artefacts land in
# build/out/ as janice-<version>-<platform>.zip, and only when every gating
# preset has exported and verified: a failed run leaves build/out/ empty of
# artefacts, never half of them.
#
# GODOT names the Godot 4.5 binary (default: godot on PATH). Export templates
# for 4.5.1 must be installed (Editor > Manage Export Templates).
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="build/out"
STAMP="resources/build_info.tres"
RELEASE=0

for arg in "$@"; do
	case "$arg" in
		--release) RELEASE=1 ;;
		-h|--help) sed -n '2,17p' "$0"; exit 0 ;;
		*) echo "build: unknown argument '$arg' (try --help)" >&2; exit 2 ;;
	esac
done

# preset name | platform tag | binary name | gates the build
PRESETS=(
	"Windows Desktop|windows|janice.exe|1"
	"Linux|linux|janice.x86_64|1"
	"macOS|macos|janice.zip|0"
)
# Tests point this at a subset, or at a preset that does not exist.
if [[ -n "${JIOH_PRESETS:-}" ]]; then
	IFS=';' read -r -a PRESETS <<< "$JIOH_PRESETS"
fi

if ! git rev-parse --git-dir > /dev/null 2>&1; then
	echo "build: not a git checkout; the version comes from git describe" >&2
	exit 2
fi
if [[ $RELEASE -eq 1 && -n "$(git status --porcelain)" ]]; then
	echo "build: refusing a release build: the working tree has uncommitted changes." >&2
	echo "build: a release must be exactly a commit, so its version names what shipped. Commit or stash these first:" >&2
	git status --short >&2
	exit 3
fi

VERSION="$(git describe --tags --always --dirty)"
CHANNEL="local"
[[ $RELEASE -eq 1 ]] && CHANNEL="release"
echo "build: janice $VERSION ($CHANNEL)"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/janice-build.XXXXXX")"
cp "$STAMP" "$STAGE/build_info.tres.orig"
cleanup() {
	cp "$STAGE/build_info.tres.orig" "$STAMP"
	rm -rf "$STAGE"
}
trap cleanup EXIT

# Nothing stale survives a run, whether it succeeds or fails.
mkdir -p "$OUT"
rm -f "$OUT"/janice-*.zip

cat > "$STAMP" <<STAMP_EOF
[gd_resource type="Resource" script_class="BuildStamp" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/build/build_stamp.gd" id="1_stamp"]

[resource]
script = ExtResource("1_stamp")
version = "$VERSION"
channel = "$CHANNEL"
STAMP_EOF

# A clean checkout has no .godot/ import cache yet.
"$GODOT" --headless --path . --import > "$STAGE/import.log" 2>&1 || {
	echo "build: the import pass failed; see below" >&2
	tail -n 30 "$STAGE/import.log" >&2
	exit 1
}

make_zip() {  # make_zip <dir> <zip>
	local dir="$1" zipfile="$2"
	if command -v zip > /dev/null; then
		(cd "$dir" && zip -qr -X "$zipfile" .)
	elif command -v python3 > /dev/null; then
		python3 -c 'import shutil,sys; shutil.make_archive(sys.argv[1][:-4], "zip", sys.argv[2])' "$zipfile" "$dir"
	else
		powershell.exe -NoProfile -Command "Compress-Archive -Path '$dir\\*' -DestinationPath '$zipfile'"
	fi
}

READY=()
for entry in "${PRESETS[@]}"; do
	IFS='|' read -r preset tag binary gate <<< "$entry"
	dir="$STAGE/$tag"
	mkdir -p "$dir"
	echo "build: exporting '$preset'"
	status=0
	"$GODOT" --headless --path . --export-release "$preset" "$dir/$binary" > "$STAGE/$tag.log" 2>&1 || status=$?
	if [[ $status -eq 0 && ! -s "$dir/$binary" ]]; then
		status=1
	fi
	if [[ $status -eq 0 && "$tag" != "macos" ]]; then
		python3 build/verify_pack.py "$dir/${binary%.*}.pck" . || status=1
	fi
	if [[ $status -ne 0 ]]; then
		grep -E "ERROR|error" "$STAGE/$tag.log" | head -n 20 >&2 || true
		if [[ "$gate" == "1" ]]; then
			echo "build: '$preset' failed (exit $status); no artefacts written" >&2
			exit 1
		fi
		echo "build: '$preset' failed; it does not gate the build, carrying on" >&2
		continue
	fi
	artefact="$STAGE/janice-$VERSION-$tag.zip"
	if [[ "$binary" == *.zip ]]; then
		mv "$dir/$binary" "$artefact"
	else
		make_zip "$dir" "$artefact"
	fi
	READY+=("$artefact")
done

# Every gate passed: only now does anything reach build/out/.
for artefact in "${READY[@]}"; do
	mv "$artefact" "$OUT/"
	echo "build: wrote $OUT/$(basename "$artefact")"
done

if [[ $RELEASE -eq 1 ]]; then
	previous="$(git describe --tags --abbrev=0 HEAD^ 2> /dev/null || true)"
	range="${previous:+$previous..}HEAD"
	{
		echo
		echo "## $VERSION ($(date -u +%Y-%m-%d))"
		echo
		git log --no-merges --format='- %s' "$range" | head -n 200
	} >> build/CHANGELOG.md
	echo "build: appended $VERSION to build/CHANGELOG.md; commit it with the tag"
fi

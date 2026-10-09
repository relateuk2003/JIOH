#!/usr/bin/env bash
# tests/build/run_build_tests.sh — JIOH-60 acceptance criteria for
# build/build.sh. Slow (it exports for real), so not part of run_all.sh.
#
#   GODOT=/path/to/godot tests/build/run_build_tests.sh
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
export GODOT
fails=0
ok() { echo "BUILD OK: $1"; }
bad() { echo "BUILD FAIL: $1"; fails=$((fails + 1)); }

version="$(git describe --tags --always --dirty)"

# 1. No arguments: Windows and Linux artefacts, version-stamped.
if build/build.sh > /tmp/janice-build-1.log 2>&1; then ok "build.sh with no arguments succeeds"; else bad "build.sh failed"; tail -20 /tmp/janice-build-1.log; fi
for tag in windows linux; do
	[[ -s "build/out/janice-$version-$tag.zip" ]] && ok "janice-$version-$tag.zip written" || bad "no $tag artefact"
done
[[ "$(git status --porcelain resources/build_info.tres)" == "" ]] && ok "the stamp is put back after the build" || bad "build_info.tres left modified"

# 2. The built game reports the same version.
run="$(mktemp -d)"
unzip -q "build/out/janice-$version-linux.zip" -d "$run"
reported="$(timeout 60 "$run/janice.x86_64" --headless -- --print-build 2>/dev/null | grep '^JANICE BUILD' || true)"
[[ "$reported" == "JANICE BUILD $version local" ]] && ok "the binary reports $version" || bad "the binary reports '$reported', expected $version"
rm -rf "$run"

# 3. A failing preset: non-zero, and nothing left in build/out.
if JIOH_PRESETS="Linux|linux|janice.x86_64|1;No Such Preset|nope|janice.bin|1" build/build.sh > /tmp/janice-build-3.log 2>&1; then
	bad "a failing preset exited zero"
else
	ok "a failing preset exits non-zero"
fi
ls build/out/janice-*.zip > /dev/null 2>&1 && bad "artefacts left in build/out after a failure" || ok "no partial or stale artefact after a failure"

# 4. FMV ships byte-identical.
mkdir -p resources/fmv
cp tests/fixtures/video/wide_pattern.ogv resources/fmv/zz_build_test.ogv
JIOH_PRESETS="Linux|linux|janice.x86_64|1" build/build.sh > /tmp/janice-build-4.log 2>&1
grep -q "1 FMV byte-identical" /tmp/janice-build-4.log && ok "every .ogv in resources/fmv ships byte-identical" || bad "FMV check: $(grep VERIFY /tmp/janice-build-4.log)"
rm -f resources/fmv/zz_build_test.ogv resources/fmv/zz_build_test.ogv.uid
rmdir resources/fmv 2> /dev/null || true
rm -f build/out/janice-*.zip

# 5. --release on a dirty tree refuses, and says why.
touch zz_dirty_build_test
out="$(build/build.sh --release 2>&1)"; code=$?
rm -f zz_dirty_build_test
[[ $code -ne 0 && "$out" == *"uncommitted changes"* ]] && ok "--release refuses a dirty tree and says so" || bad "--release on a dirty tree: exit $code: $out"

if [[ $fails -eq 0 ]]; then echo "BUILD TESTS PASSED"; else echo "BUILD TESTS: $fails FAILED"; exit 1; fi

#!/usr/bin/env bash
# V2-INFRA-011 profile run. Applies a TEMPORARY timing patch to core/ and tests/, runs ONE suite,
# restores every tracked file with `git checkout`, and prints the TPROF / TCOUNT lines.
#
# Usage: run_profile.sh <patch.py> <tag> [suite]
#   <patch.py>  patch script; a relative path is looked up in this folder (use patch_l3.py)
#   <tag>       name of the run; output goes to $PROFILE_OUT/<tag>.out
#   [suite]     one exact suite name (default: fingerprint_guide_spirit)
# Env: GODOT_BIN     Godot binary (default /opt/homebrew/bin/godot)
#      PROFILE_OUT   output directory (default: a new temporary directory)
#
# The repository is the checkout that contains this script. The tracked files under core/, tests/
# and ui/ must be unchanged at the start. The run is valid only if the output has a
# "Tests: N total, N passed, 0 failed" line (the runner exits 0 even when it fails).
set -uo pipefail

PROBE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$PROBE_DIR" rev-parse --show-toplevel)"
PATCH="${1:?usage: run_profile.sh <patch.py> <tag> [suite]}"
TAG="${2:?usage: run_profile.sh <patch.py> <tag> [suite]}"
SUITE="${3:-fingerprint_guide_spirit}"
[[ "$PATCH" = /* ]] || PATCH="$PROBE_DIR/$PATCH"
GODOT_BIN="${GODOT_BIN:-/opt/homebrew/bin/godot}"
OUT="${PROFILE_OUT:-$(mktemp -d)}"
mkdir -p "$OUT"

cd "$REPO" || exit 1
if ! git diff --quiet -- core tests ui; then
  echo "FATAL: tracked files under core/, tests/ or ui/ are changed. Commit or stash them first." >&2
  exit 1
fi

SAVE_DIR="$(mktemp -d)"
restore() {
  git checkout -q -- core tests ui
  rm -f tests/TimingProbeAcc.gd tests/TimingProbeAcc.gd.uid
  rm -rf "$SAVE_DIR"
  git diff --quiet -- core tests ui && echo "restored: core/, tests/ and ui/ are identical to HEAD" >&2
}
trap restore EXIT

cp "$PROBE_DIR/TimingProbeAcc.gd.txt" tests/TimingProbeAcc.gd
python3 "$PATCH" || { echo "FATAL: the patch did not apply." >&2; exit 1; }

start=$(date +%s)
ECHOES_TEST_SAVE_DIR="$SAVE_DIR" /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 \
  "$GODOT_BIN" --headless --quit --path "$REPO" -- tests "=$SUITE" > "$OUT/$TAG.out" 2>&1
echo "wall=$(( $(date +%s) - start ))s output=$OUT/$TAG.out" >&2

# Exit code 0 proves nothing: require a Tests line with zero failed.
if ! grep -qE 'Tests: [0-9]+ total, [0-9]+ passed, 0 failed' "$OUT/$TAG.out"; then
  echo "FATAL: no 'Tests: N total, N passed, 0 failed' line in $OUT/$TAG.out. This run is NOT a baseline." >&2
  grep -E 'Tests:|SCRIPT ERROR|Parse Error' "$OUT/$TAG.out" | head -5 >&2
  exit 1
fi
grep -E 'TPROF|TCOUNT' "$OUT/$TAG.out" | sed 's/.*Debug output //; s/.*\(TPROF\|TCOUNT\)/\1/'

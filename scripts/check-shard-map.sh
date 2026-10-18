#!/usr/bin/env bash
# Checks that the shard map (scripts/test-shard-map.sh) and the registered test suites agree.
#
# It fails (exit 1) when any of these is true:
#   - a registered suite is missing from the map (its tests would silently never run sharded),
#   - a suite appears more than once in the map (its tests would run twice and be counted twice),
#   - the map names a suite that is not registered (stale name after a rename),
#   - a suite is in both a shard and MERGE_SUITES (that is a duplicate too),
#   - MERGE_SUITES is missing or empty,
#   - the map has an empty suite name, an empty shard, or two shards with the same name,
#   - the registered-suite list is empty (the list could not be read: that proves nothing).
#
# The registered names come from the runner itself, never from a document:
#   godot --headless --quit --path <checkout> -- tests __nomatch__
# prints every suite name in lines of the form  Debug output "  <suite>".
# Names are compared case-insensitively, because the runner's exact-match mode is
# case-insensitive. The extraction accepts any character in a name, so an unusual name
# (an upper-case letter, a dash) is checked and not silently dropped.
#
# Usage: scripts/check-shard-map.sh [checkout_path]
#   GODOT_BIN               Godot binary (default /opt/homebrew/bin/godot)
#   --registered-file FILE  read registered names (one per line) from FILE instead of Godot
#   --map-file FILE         read SHARDS from FILE instead of scripts/test-shard-map.sh
# The two options exist so the checker can be tested without a Godot process.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKOUT=""
REGISTERED_FILE=""
MAP_FILE="$SCRIPT_DIR/test-shard-map.sh"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --registered-file) REGISTERED_FILE="${2:?--registered-file needs a path}"; shift 2 ;;
    --map-file) MAP_FILE="${2:?--map-file needs a path}"; shift 2 ;;
    -*) echo "FATAL: unknown option '$1'." >&2; exit 2 ;;
    *) CHECKOUT="$1"; shift ;;
  esac
done
CHECKOUT="${CHECKOUT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
GODOT_BIN="${GODOT_BIN:-/opt/homebrew/bin/godot}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# 1. Registered suite names.
registered_raw="$WORK_DIR/registered.raw"
if [[ -n "$REGISTERED_FILE" ]]; then
  cp "$REGISTERED_FILE" "$registered_raw" || { echo "FATAL: cannot read '$REGISTERED_FILE'." >&2; exit 2; }
else
  # Own save directory: this process never touches a shard's saves.
  ECHOES_TEST_SAVE_DIR="$WORK_DIR/saves" /usr/bin/perl -e 'alarm shift; exec @ARGV' 200 \
    "$GODOT_BIN" --headless --quit --path "$CHECKOUT" -- tests __nomatch__ > "$WORK_DIR/godot.log" 2>&1
  sed -n 's/.*Debug output "  \(.*\)"$/\1/p' "$WORK_DIR/godot.log" > "$registered_raw"
  if [[ ! -s "$registered_raw" ]]; then
    echo "FATAL: the runner listed no suite names (Godot missing, import stale, or script error)." >&2
    echo "Last lines of the Godot output:" >&2
    tail -n 15 "$WORK_DIR/godot.log" >&2
    exit 1
  fi
fi
tr 'A-Z' 'a-z' < "$registered_raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d' | sort -u > "$WORK_DIR/registered"
if [[ ! -s "$WORK_DIR/registered" ]]; then
  echo "FATAL: the registered-suite list is empty." >&2
  exit 1
fi

# 2. Map names, one "<shard> <suite>" pair per line.
# shellcheck disable=SC1090
source "$MAP_FILE" || { echo "FATAL: cannot source '$MAP_FILE'." >&2; exit 2; }
if [[ -z "${SHARDS+x}" || "${#SHARDS[@]}" -eq 0 ]]; then
  echo "FATAL: '$MAP_FILE' defines no SHARDS." >&2
  exit 1
fi
problems=0
: > "$WORK_DIR/pairs"
: > "$WORK_DIR/shard_names"
for entry in "${SHARDS[@]}"; do
  shard="${entry%%|*}"
  rest="${entry#*|}"
  suites="${rest%%|*}"
  echo "$shard" >> "$WORK_DIR/shard_names"
  if [[ -z "$suites" || "$rest" == "$entry" ]]; then
    echo "PROBLEM: shard '$shard' has no suite list." >&2
    problems=$((problems + 1))
    continue
  fi
  IFS=',' read -r -a names <<< "$suites"
  for raw_name in "${names[@]}"; do
    name="$(echo "$raw_name" | tr 'A-Z' 'a-z' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [[ -z "$name" ]]; then
      echo "PROBLEM: shard '$shard' has an empty suite name (stray comma)." >&2
      problems=$((problems + 1))
      continue
    fi
    echo "$shard $name" >> "$WORK_DIR/pairs"
  done
done

if [[ -z "${MERGE_SUITES+x}" || "${#MERGE_SUITES[@]}" -eq 0 ]]; then
  echo "PROBLEM: '$MAP_FILE' defines no MERGE_SUITES (the merge step needs movement_fallback)." >&2
  problems=$((problems + 1))
else
  for raw_name in "${MERGE_SUITES[@]}"; do
    name="$(echo "$raw_name" | tr 'A-Z' 'a-z' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [[ -z "$name" ]]; then
      echo "PROBLEM: MERGE_SUITES has an empty name." >&2
      problems=$((problems + 1))
      continue
    fi
    echo "merge $name" >> "$WORK_DIR/pairs"
  done
fi

dup_shards="$(sort "$WORK_DIR/shard_names" | uniq -d)"
if [[ -n "$dup_shards" ]]; then
  while IFS= read -r s; do
    echo "PROBLEM: shard name '$s' is used by more than one map entry." >&2
    problems=$((problems + 1))
  done <<< "$dup_shards"
fi

# 3. Compare.
awk '{print $2}' "$WORK_DIR/pairs" | sort > "$WORK_DIR/map_names_sorted"
sort -u "$WORK_DIR/map_names_sorted" > "$WORK_DIR/map_names"

while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  where="$(awk -v n="$name" '$2 == n {printf "%s ", $1}' "$WORK_DIR/pairs")"
  echo "PROBLEM: suite '$name' appears more than once in the map (shards: ${where% })." >&2
  problems=$((problems + 1))
done < <(uniq -d "$WORK_DIR/map_names_sorted")

while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  echo "PROBLEM: registered suite '$name' is missing from the shard map." >&2
  problems=$((problems + 1))
done < <(comm -23 "$WORK_DIR/registered" "$WORK_DIR/map_names")

while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  where="$(awk -v n="$name" '$2 == n {printf "%s ", $1}' "$WORK_DIR/pairs")"
  echo "PROBLEM: the map names '$name' (shard ${where% }), but no registered suite has that name." >&2
  problems=$((problems + 1))
done < <(comm -13 "$WORK_DIR/registered" "$WORK_DIR/map_names")

registered_count="$(wc -l < "$WORK_DIR/registered" | tr -d ' ')"
shard_count="${#SHARDS[@]}"
if [[ "$problems" -gt 0 ]]; then
  echo "SHARD MAP CHECK: FAILED ($problems problem(s)). Fix $MAP_FILE and the shard counts in AGENTS.md together." >&2
  exit 1
fi
echo "SHARD MAP CHECK: OK ($registered_count registered suites, each in exactly one of $shard_count shards or the merge step)."
exit 0

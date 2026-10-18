#!/usr/bin/env bash
# Runs the GDScript test suite as several parallel headless Godot processes ("shards"),
# each with its own ECHOES_TEST_SAVE_DIR, then sums the per-shard "Tests: N total, N passed,
# M failed" lines into one combined result.
#
# Restriction (same as the full unsharded suite, AGENTS.md "Tests"): only the orchestrator
# and the QA/verification role may run this. It is still exclusive-resource-heavy (multiple
# godot processes, real disk I/O) even though it is parallelized.
#
# Suite selection: uses the test runner's exact-match filter mode, `tests =<a>,<b>,...`
# (ui/AppRoot.gd) — a leading "=" switches from substring containment to case-insensitive
# suite-name EQUALITY. Every shard's suite list below is therefore a disjoint, exact set of
# the live registered suite names; no suite is selected twice, and none collides with a
# sibling whose name contains it as a substring (e.g. "combat" vs "combat_roundtrip").
#
# Usage: scripts/run-tests-sharded.sh [checkout_path]
#   checkout_path defaults to the git worktree this script lives in.
#
# movement_fallback. MovementFallbackGuardTests judges a process-wide ledger of legacy-selector
# fallbacks, so inside one shard it would see only that shard's suites. It is therefore in no shard.
# After all shards finish, the "merge step" below runs it in one more process that has loaded the
# ledger file of every shard (tests/LegacyLedgerFile.gd). The verdict equals the serial run's verdict,
# including the serial rule that clears entries recorded before behavior_char (see AGENTS.md).
# A shard that wrote no ledger file makes the whole run INVALID.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKOUT="${1:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# ALARM_SECS is a per-shard HANG CEILING, not an expected duration. `wait` below returns as
# soon as each backgrounded godot process exits on its own — a shard that finishes in 90s does
# not wait out the rest of its alarm. The alarm only fires (and kills the shard) if it is still
# running past that many seconds, which is why every past verification pass that read "900s" as
# "the run takes 900s" was wrong: it was actually "the alarm didn't fire before 900s", i.e. the
# shard was still running at kill time with the true contended cost unknown beyond that lower
# bound. Three separate verification passes made this misreading; do not repeat it.
#
# Default (700s) covers shard1-5, shard7-10: real margin over the ~500s worst case measured
# for shard2/shard3/shard10 under contention across multiple runs — no other shard has come
# close to needing more.
#
# The old single `fingerprint` suite (8 tests, one shared suite name) forced all 8 to run
# serially in one shard — qa-verifier measured that shard at 623s SOLO/UNCONTENDED, and a
# subsequent 900s alarm under 10-way contention STILL fired while it was running. Both the main
# suite and its determinism self-check have since been split into 7 per-mode suite names each
# (see tests/FlowFingerprintTests.gd's register()), which lets all 14 spread across shard1-5/7/8
# alongside unrelated suites instead of one dedicated shard. No shard currently needs an alarm
# override as a result — 700s covers the measured ~500s worst case with margin even after adding
# one ~2x-cost determinism suite per shard. Re-verify ALARM_SECS after any suite-list change.
# The Godot binary path is configurable: GODOT_BIN=/path/to/godot scripts/run-tests-sharded.sh
# The default is the macOS Homebrew path that the project documents everywhere else.
GODOT_BIN="${GODOT_BIN:-/opt/homebrew/bin/godot}"
ALARM_SECS=700
# ALARM_SCALE multiplies every shard alarm (default 1 = the values in this file). Use a value
# above 1 on a machine with fewer cores than shards: the shards then run slower than the
# measured times below, and an unscaled alarm would kill them. Only integers; never below 1.
ALARM_SCALE="${ALARM_SCALE:-1}"
if ! [[ "$ALARM_SCALE" =~ ^[1-9][0-9]*$ ]]; then
  echo "FATAL: ALARM_SCALE must be a positive integer, got '$ALARM_SCALE'." >&2
  exit 1
fi

SCRATCH_ROOT="/tmp/echoes-vnext-sharded"
LOG_DIR="$SCRATCH_ROOT/logs"
SAVE_ROOT="$SCRATCH_ROOT/saves"

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR" "$SAVE_ROOT"

# The shard map (SHARDS, with the history of how it was balanced) lives in scripts/test-shard-map.sh.
# scripts/check-shard-map.sh reads the same file.
# shellcheck disable=SC1091
source "$SCRIPT_DIR/test-shard-map.sh"

# Fail before any shard starts if the map and the registered suites disagree. A suite missing
# from the map would never run in a sharded run; a suite listed twice would run twice.
if ! "$SCRIPT_DIR/check-shard-map.sh" "$CHECKOUT"; then
  echo "FATAL: shard map check failed. No shard was started." >&2
  exit 1
fi

echo "Sharding across ${#SHARDS[@]} shards. Logs: $LOG_DIR"

pids=()
shard_names=()

# If this wrapper is killed or interrupted (TERM/INT) before the wait loop below completes, the
# backgrounded godot subshells (up to 10, one potentially running ~2400s) would otherwise be left
# orphaned, still writing into the fixed scratch/save directories under $SAVE_ROOT that the NEXT
# invocation reuses and rm -rf's — reproducing exactly the concurrent-run contamination this
# script exists to prevent. Kill and reap every recorded PID on exit, interrupt or terminate.
_cleanup_children() {
  for pid in "${pids[@]:-}"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null
    fi
  done
  # Give TERM a few seconds before escalating — a godot process that ignores TERM would
  # otherwise make this cleanup itself hang forever on an unbounded `wait`.
  sleep 2
  for pid in "${pids[@]:-}"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null
    fi
  done
  for pid in "${pids[@]:-}"; do
    if [[ -n "$pid" ]]; then
      wait "$pid" 2>/dev/null
    fi
  done
}
_on_interrupt() {
  _cleanup_children
  # Without this, bash resumes after the interrupted `wait` and prints a misleading
  # "combined result" computed from truncated logs before exiting — the exit code was
  # already correct (a killed shard fails the `fail` check), but the output reads as if
  # the run completed rather than was cut short. 130 is the conventional SIGINT exit code.
  trap - EXIT
  exit 130
}
trap _cleanup_children EXIT
trap _on_interrupt INT TERM
for entry in "${SHARDS[@]}"; do
  name="${entry%%|*}"
  rest="${entry#*|}"
  suite_names="${rest%%|*}"
  alarm_override="${rest#*|}"
  # A malformed entry missing its trailing "|" (e.g. "name|suites" with no third field) makes
  # bash's "#*|" expansion return the string unchanged instead of empty — so alarm_override
  # would silently become the suite-name list itself. Perl's `alarm` numifies a non-numeric
  # argument to 0, which CANCELS the alarm rather than firing immediately, so that shard would
  # run with no hang ceiling at all and nothing would report it. Fail loudly instead.
  if [[ "$alarm_override" == "$suite_names" && -n "$alarm_override" ]]; then
    echo "FATAL: shard '$name' is missing its trailing '|' (alarm field) — entry is malformed." >&2
    exit 1
  fi
  shard_alarm_secs="${alarm_override:-$ALARM_SECS}"
  if ! [[ "$shard_alarm_secs" =~ ^[0-9]+$ ]]; then
    echo "FATAL: shard '$name' has a non-numeric alarm value '$shard_alarm_secs'." >&2
    exit 1
  fi
  shard_alarm_secs=$((shard_alarm_secs * ALARM_SCALE))
  shard_save_dir="$SAVE_ROOT/$name"
  shard_log="$LOG_DIR/$name.log"
  rm -rf "$shard_save_dir"
  mkdir -p "$shard_save_dir"

  (
    : > "$shard_log"
    echo "=== shard=$name filter==$suite_names alarm_secs=$shard_alarm_secs ===" >> "$shard_log"
    shard_start=$(date +%s)
    ECHOES_TEST_SAVE_DIR="$shard_save_dir" /usr/bin/perl -e 'alarm shift; exec @ARGV' "$shard_alarm_secs" "$GODOT_BIN" --headless --quit --path "$CHECKOUT" -- tests "=$suite_names" >> "$shard_log" 2>&1
    shard_end=$(date +%s)
    # Real elapsed time, distinct from alarm_secs above (a ceiling that may never fire).
    echo "elapsed_secs=$((shard_end - shard_start))" >> "$shard_log"
  ) &
  pids+=("$!")
  shard_names+=("$name")
done

fail=0
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    echo "WARNING: shard '${shard_names[$i]}' process exited non-zero (godot always exits 0 on its own; this likely means the alarm/timeout fired)." >&2
    fail=1
  fi
done

# Merge step: apply the movement_fallback guard to the ledger of the WHOLE run.
# Every shard process wrote its legacy-selector ledger to <its save dir>/legacy_selector_ledger.json
# (tests/LegacyLedgerFile.gd). MovementFallbackGuardTests is not in any shard. It runs here, in one
# more process, after the ledger files are loaded into it (ECHOES_LEGACY_LEDGER_IN). A fallback
# in any shard therefore fails this step, as it fails the serial run. The suite name comes from
# MERGE_SUITES in scripts/test-shard-map.sh.
ledger_files=()
ledger_missing=0
for name in "${shard_names[@]}"; do
  ledger_file="$SAVE_ROOT/$name/legacy_selector_ledger.json"
  if [[ -f "$ledger_file" ]]; then
    ledger_files+=("$ledger_file")
  else
    echo "FATAL: shard '$name' wrote no legacy-selector ledger ($ledger_file). It crashed or was killed" \
         "before its last test, so the movement_fallback guard cannot judge the whole run." >&2
    ledger_missing=1
  fi
done
merge_save_dir="$SAVE_ROOT/merge"
merge_log="$LOG_DIR/merge.log"
rm -rf "$merge_save_dir"
mkdir -p "$merge_save_dir"
merge_filter="$(IFS=,; echo "${MERGE_SUITES[*]}")"
ledger_in="$(IFS=:; echo "${ledger_files[*]}")"
: > "$merge_log"
echo "=== merge filter==$merge_filter ledger_files=${#ledger_files[@]} ===" >> "$merge_log"
ECHOES_TEST_SAVE_DIR="$merge_save_dir" ECHOES_LEGACY_LEDGER_IN="$ledger_in" \
  /usr/bin/perl -e 'alarm shift; exec @ARGV' $((300 * ALARM_SCALE)) \
  "$GODOT_BIN" --headless --quit --path "$CHECKOUT" -- tests "=$merge_filter" >> "$merge_log" 2>&1 \
  || { echo "WARNING: the merge process exited non-zero (alarm fired?)." >&2; fail=1; }

echo ""
echo "=== Per-shard results ==="
total=0
passed=0
failed=0
missing_lines=0
for name in "${shard_names[@]}" merge; do
  shard_log="$LOG_DIR/$name.log"
  shard_total=0
  shard_passed=0
  shard_failed=0
  found_any=0
  while IFS= read -r line; do
    if [[ "$line" =~ Tests:\ ([0-9]+)\ total,\ ([0-9]+)\ passed,\ ([0-9]+)\ failed ]]; then
      found_any=1
      shard_total=$((shard_total + ${BASH_REMATCH[1]}))
      shard_passed=$((shard_passed + ${BASH_REMATCH[2]}))
      shard_failed=$((shard_failed + ${BASH_REMATCH[3]}))
    fi
  done < "$shard_log"

  if [[ "$found_any" -eq 0 ]]; then
    echo "FATAL: shard '$name' produced NO 'Tests:' line in $shard_log — an unmatched filter" \
         "runs nothing and exits 0. This is NOT zero tests passing; it is a broken filter or a" \
         "crashed run. Treating the whole sharded run as FAILED." >&2
    missing_lines=1
    continue
  fi

  echo "  $name: $shard_total total, $shard_passed passed, $shard_failed failed"
  total=$((total + shard_total))
  passed=$((passed + shard_passed))
  failed=$((failed + shard_failed))
done

# Timing. Every shard log carries "TIMING_SUITE ms=<n> tests=<n> suite=<name>" and
# "TIMING_TEST ms=<n> name=<name>" lines (tests/CoreTestRunner.gd, format_timing_report).
# A shard prints only its own 20 slowest tests, so the table below is the 20 slowest of the
# union of those lists: exact for the overall top 20, because a test in the overall top 20 is
# also in the top 20 of its own shard. Times are wall-clock inside one process; they grow when
# shards compete for CPU cores, so compare them with each other and not with a solo run.
TIMING_SUITES_FILE="$LOG_DIR/timing-suites.txt"
TIMING_TESTS_FILE="$LOG_DIR/timing-tests.txt"
: > "$TIMING_SUITES_FILE"
: > "$TIMING_TESTS_FILE"
for entry in "${SHARDS[@]}"; do
  name="${entry%%|*}"
  shard_log="$LOG_DIR/$name.log"
  sed -n 's/.*TIMING_SUITE ms=\([0-9]*\) tests=\([0-9]*\) suite=\(.*\)"$/\1 \2 \3/p' "$shard_log" \
    | awk -v shard="$name" '{print $1, $2, shard, $3}' >> "$TIMING_SUITES_FILE"
  sed -n 's/.*TIMING_TEST ms=\([0-9]*\) name=\(.*\)"$/\1 \2/p' "$shard_log" \
    | awk -v shard="$name" '{print $1, shard, $2}' >> "$TIMING_TESTS_FILE"
done
echo ""
echo "=== Shard wall-clock (elapsed_secs from each shard log) ==="
for entry in "${SHARDS[@]}"; do
  name="${entry%%|*}"
  elapsed="$(sed -n 's/^elapsed_secs=//p' "$LOG_DIR/$name.log" | tail -n 1)"
  echo "  $name: ${elapsed:-unknown} s"
done
echo ""
echo "=== 20 slowest tests, all shards (ms, shard, test) ==="
sort -rn "$TIMING_TESTS_FILE" | head -n 20 | awk '{printf "  %9d ms  %-8s %s\n", $1, $2, $3}'
echo ""
echo "=== 15 slowest suites, all shards (ms, tests, shard, suite) ==="
sort -rn "$TIMING_SUITES_FILE" | head -n 15 | awk '{printf "  %9d ms  %4d tests  %-8s %s\n", $1, $2, $3, $4}'
echo "(All suites: $TIMING_SUITES_FILE   Top tests per shard: $TIMING_TESTS_FILE)"

echo ""
if [[ "$missing_lines" -eq 1 ]]; then
  echo "COMBINED RESULT: INVALID — at least one shard produced no 'Tests:' line. See FATAL lines above." >&2
  exit 1
fi

echo "COMBINED: $total total, $passed passed, $failed failed"
echo "(Exact-match shards: no suite selected twice, total should equal a serial full run's total.)"
echo ""
echo "movement_fallback: judged in the merge step on the legacy-selector ledgers of ${#ledger_files[@]} of ${#shard_names[@]} shards."
grep -h "Legacy ledger:" "$merge_log" | sed 's/.*Debug output "\(.*\)"$/  \1/'
if [[ "$ledger_missing" -eq 1 ]]; then
  echo "COMBINED RESULT: INVALID — at least one shard wrote no legacy-selector ledger. See FATAL lines above." >&2
  exit 1
fi

if [[ "$fail" -eq 1 ]]; then
  echo "COMBINED RESULT: INVALID — at least one shard's process exited non-zero (crashed or was" \
       "alarm-killed), even though it may have already printed a valid 'Tests:' line before dying." \
       "See WARNING lines above." >&2
  exit 1
fi

if [[ "$failed" -gt 0 ]]; then
  echo "COMBINED RESULT: FAILED — $failed test(s) failed in the shards or in the movement_fallback merge step." >&2
  exit 1
fi
echo "COMBINED RESULT: PASSED"
exit 0

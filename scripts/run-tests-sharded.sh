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
# KNOWN GAP — movement_fallback does not get full-suite validation here. MovementFallbackGuardTests
# is registered LAST in ui/AppRoot.gd specifically because it inspects a legacy-selector ledger
# that every earlier-registered suite in the SAME PROCESS may write to. Sharding puts it in shard4
# with ~16 sibling suites, not all ~115 — a clean sharded PASS on movement_fallback does NOT mean
# the real serial suite would also pass; a fallback triggered by a suite in another shard is
# invisible to it here. This is not fixable by rebalancing shards (it would require running every
# other suite first, in-process, defeating parallelism for this one guard). Always run the full
# SERIAL suite before committing anything that could affect legacy-selector fallback behavior.

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
GODOT_BIN="/opt/homebrew/bin/godot"
ALARM_SECS=700

SCRATCH_ROOT="/tmp/echoes-vnext-sharded"
LOG_DIR="$SCRATCH_ROOT/logs"
SAVE_ROOT="$SCRATCH_ROOT/saves"

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR" "$SAVE_ROOT"

# Shard map: "<shard_name>|<comma-separated EXACT suite names>|<alarm_secs_override_or_empty>"
# The third field overrides ALARM_SECS for that shard only; leave it empty to use the default.
# Each shard's filter is passed to the runner as a single `tests =<name1>,<name2>,...`
# invocation (exact-match mode — see ui/AppRoot.gd). shard1-5 and shard10 are the original
# line-count bin-pack (see git history for that method); shard6-9 replace the old shard6 (see
# note below). Disjoint by construction: every suite name appears in exactly one shard.
#
# Updated 2026-09-20 after PR #69 (V2-COMBAT-003.5 part 1/2) merged to main: that PR added
# two new suites, `movement_style` (tests/MovementStyleServiceTests.gd) and
# `live_movement_style` (tests/LiveMovementStyleTests.gd), registered in ui/AppRoot.gd.
#
# Updated again 2026-09-20 after a real measured run showed the old shard6 taking 763s wall
# clock — 2.7x the next-slowest shard — while line-count balance put it at only 18 suites,
# no different in kind from its siblings. Line count does not predict runtime. The old shard6
# is now 4 shards:
#   shard6 — was `fingerprint` alone (see below — now split further).
#   shard7 — `seam` (tests/Stage004SeamTests.gd) alone. 3612 lines, by a wide margin the
#     largest test source file in the repo (next largest is 1542).
#   shard8/shard9 — the remaining 16 old-shard6 suites, bin-packed by source-file line count
#     into two ~3900-line halves (see git history for the exact bin-pack).
# This is a best-effort split with no per-suite timing data — only shard-level wall clock was
# measured. Re-verify with a real timed run and adjust further if shard6-9 are still uneven.
#
# Updated again 2026-09-20 — the `fingerprint` suite fingerprint-suite refactor landed
# (tests/FlowFingerprintTests.gd). It registered 8 tests under ONE shared suite name, which is
# why the old shard6 above could never be split by suite-name sharding: all 8 had to run
# serially in whatever one shard held "fingerprint". Each of the 7 modes (combat, purify_shrine,
# recover, protect, endure, pursue, guide_spirit) is now its OWN suite name,
# `fingerprint_<mode>`, so each can land in a different shard and run in parallel with unrelated
# suites. They are added one per shard to shard1, shard2, shard3, shard4, shard5, shard7 and
# shard8 — chosen to spread the real simulation cost rather than concentrate it, with no
# per-mode timing data available, so shard1 and shard7 (the two smallest shards by suite count:
# `movement,old_echo` and `seam` alone) absorb one mode each same as every other shard picked.
# Updated again 2026-09-20 — `test_determinism_self_check` (formerly the dedicated shard6, 2400s
# override) has been split the same way the main `fingerprint` suite was: one
# `fingerprint_determinism_<mode>` suite per mode instead of one function looping all seven
# in-process. Each new determinism suite does 2 full drives of its mode (record + diff) against
# the main suite's 1, so it costs roughly 2x its corresponding `fingerprint_<mode>` suite
# (~14-29s each, unmeasured per-suite but bounded by that ratio) — call it ~28-58s. Old shard6
# is removed entirely; each determinism suite joins the SAME shard as its own mode's main
# suite (never two ~2x-cost suites in one shard), so no single shard absorbs more than one
# extra ~2x cost, avoiding a repeat of the old shard6 bottleneck. Re-measure and rebalance if a
# shard turns out to need it — no per-suite timing data exists yet for these seven.
#
# Updated again 2026-09-20 — real timed sharded runs (post-fingerprint-split) showed shard7 at
# 539-666s across repeat measurements, the new critical path. Splitting the `seam` suite
# (tests/Stage004SeamTests.gd, 25 tests, then attempted as 5 cost-tiered suite names) was tried
# and MEASURED to give no improvement (a follow-up run at 592s vs. a 546s pre-attempt baseline —
# flat/noise, not a regression): `seam` was never the real cost. Reverted back to the single
# `seam` suite name. The actual driver of shard7 is `fingerprint_pursue` +
# `fingerprint_determinism_pursue` — two tests, each one full combat encounter run to completion
# (round 7). That cost is not reducible by suite-name sharding (it's already two separate
# suites, as small as this approach can make them); making it cheaper means changing the test's
# own encounter length/assertions, a different and riskier kind of change, not attempted here.
# shard7's alarm is overridden to 900s (was the 700s default) for real margin over its measured
# range (539-666s across repeat runs) — the 700s default left as little as 34s of margin against
# the highest observed figure, thin enough to risk a false alarm-kill under heavier contention.
# Total sharded wall-clock has measured 546-666s across repeat runs (vs. a 788s pre-fingerprint-
# split baseline and a ~1090s serial baseline) — real variance under contention on this machine,
# not a regression from any single change; both figures are still a substantial improvement over
# serial. Re-measure with repeat runs, not a single sample, before tightening any alarm further.
SHARDS=(
  "shard1|movement,old_echo,fingerprint_combat,fingerprint_determinism_combat|"
  "shard2|combat_roundtrip,echofactory,emotion,exclusive_action,ko_death,melee,morale,onboarding,passive,pending_result,sanctum_pulse,sit_res,situational,skill,snapshot,stage,fingerprint_purify_shrine,fingerprint_determinism_purify_shrine|"
  "shard3|actor,bark_popup,bond_trigger,combat_terrain,conversation_repair,divergence,divergence_bark,movement_arbiter,objective,retreat,sanctum.summon,skill_loadout,snapshot_purity,structure,support,terrain,fingerprint_recover,fingerprint_determinism_recover|"
  "shard4|archetype,behavior_char,calling,calling_behavior,combat_ui,contact,foundation_ui,institution,movement_fallback,movement_option,prog,realm_prog,sanctum.party,snapshot_fingerprint,traversal,vector,weave,fingerprint_protect,fingerprint_determinism_protect|"
  "shard5|consequence,contact_actor,cooldown,directive,explore,leadership,maturity_baseline,movement_path,realm_ui,recruit,reward,sanctum.layout,shrine,skill_unlock,voice,vow,fingerprint_endure,fingerprint_determinism_endure|"
  "shard7|seam,fingerprint_pursue,fingerprint_determinism_pursue|900"
  "shard8|behavior,behavior_arbiter,combat_initiative,explore_p5,identity,live_movement_style,statinit,trace,fingerprint_guide_spirit,fingerprint_determinism_guide_spirit|"
  "shard9|economy,flow_transaction,grid,guidance,guidance_bark,movement_style,social_graph,venture_char|"
  "shard10|arbiter,bridge,combat,combat_baseline,continuity,derived,directive_cfg,echo_party,expr,intel,objective_combat,realm,realm_reward,save_integrity,snapshot_contract,thread,unified_resolve|"
)

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
  shard_save_dir="$SAVE_ROOT/$name"
  shard_log="$LOG_DIR/$name.log"
  rm -rf "$shard_save_dir"
  mkdir -p "$shard_save_dir"

  (
    : > "$shard_log"
    echo "=== shard=$name filter==$suite_names alarm_secs=$shard_alarm_secs ===" >> "$shard_log"
    ECHOES_TEST_SAVE_DIR="$shard_save_dir" /usr/bin/perl -e 'alarm shift; exec @ARGV' "$shard_alarm_secs" "$GODOT_BIN" --headless --quit --path "$CHECKOUT" -- tests "=$suite_names" >> "$shard_log" 2>&1
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

echo ""
echo "=== Per-shard results ==="
total=0
passed=0
failed=0
missing_lines=0
for entry in "${SHARDS[@]}"; do
  name="${entry%%|*}"
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

echo ""
if [[ "$missing_lines" -eq 1 ]]; then
  echo "COMBINED RESULT: INVALID — at least one shard produced no 'Tests:' line. See FATAL lines above." >&2
  exit 1
fi

echo "COMBINED: $total total, $passed passed, $failed failed"
echo "(Exact-match shards: no suite selected twice, total should equal a serial full run's total.)"
echo ""
echo "NOTE: movement_fallback (MovementFallbackGuardTests) only saw its own shard's ~16 suites in" \
     "this run, not all ~115 — it is a cross-suite ledger guard that must run LAST in the SAME" \
     "process as everything else to be meaningful (see ui/AppRoot.gd 'REGISTER LAST'). A clean" \
     "sharded result for movement_fallback does NOT have full-suite validity. Run the full SERIAL" \
     "suite before committing anything that could affect legacy-selector fallback behavior."

if [[ "$fail" -eq 1 ]]; then
  echo "COMBINED RESULT: INVALID — at least one shard's process exited non-zero (crashed or was" \
       "alarm-killed), even though it may have already printed a valid 'Tests:' line before dying." \
       "See WARNING lines above." >&2
  exit 1
fi

if [[ "$failed" -gt 0 ]]; then
  exit 1
fi
exit 0

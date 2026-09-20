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
# shard6 (`fingerprint` alone) gets its own override (see SHARDS below) because it does not fit
# the default: qa-verifier measured it at 623s SOLO/UNCONTENDED, and a subsequent 900s alarm
# under 10-way contention STILL fired while fingerprint was running — so its true contended cost
# is unmeasured beyond ">900s". Forcing every shard to share one global alarm sized for
# fingerprint's worst case would push the whole script's hang ceiling to ~15 min for no reason;
# the other 9 shards finish comfortably under 10 min even under contention. Splitting the alarm
# per-shard keeps their ceiling tight while giving fingerprint room.
# Re-verify ALARM_SECS after any suite-list change.
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
#   shard6 — `fingerprint` (tests/FlowFingerprintTests.gd) alone. Not the biggest file (928
#     lines) but AGENTS.md's own serial-suite measurement (2026-08-25) attributes ~3 of the
#     ~7 serial minutes to this suite alone — a known-slow cluster independent of line count.
#   shard7 — `seam` (tests/Stage004SeamTests.gd) alone. 3612 lines, by a wide margin the
#     largest test source file in the repo (next largest is 1542).
#   shard8/shard9 — the remaining 16 old-shard6 suites, bin-packed by source-file line count
#     into two ~3900-line halves (see git history for the exact bin-pack).
# This is a best-effort split with no per-suite timing data — only shard-level wall clock was
# measured. Re-verify with a real timed run and adjust further if shard6-9 are still uneven.
SHARDS=(
  "shard1|movement,old_echo|"
  "shard2|combat_roundtrip,echofactory,emotion,exclusive_action,ko_death,melee,morale,onboarding,passive,pending_result,sanctum_pulse,sit_res,situational,skill,snapshot,stage|"
  "shard3|actor,bark_popup,bond_trigger,combat_terrain,conversation_repair,divergence,divergence_bark,movement_arbiter,objective,retreat,sanctum.summon,skill_loadout,snapshot_purity,structure,support,terrain|"
  "shard4|archetype,behavior_char,calling,calling_behavior,combat_ui,contact,foundation_ui,institution,movement_fallback,movement_option,prog,realm_prog,sanctum.party,snapshot_fingerprint,traversal,vector,weave|"
  "shard5|consequence,contact_actor,cooldown,directive,explore,leadership,maturity_baseline,movement_path,realm_ui,recruit,reward,sanctum.layout,shrine,skill_unlock,voice,vow|"
  # shard6 override: fingerprint's true contended cost is unmeasured beyond ">900s" — a 900s
  # alarm still fired mid-run under 10-way contention. 2400s (40 min) is a deliberately generous
  # placeholder to stop killing this shard, not a measured value. The real fix is the
  # fingerprint-suite refactor (plan Part B1), which shrinks the suite itself; do not treat this
  # number as validated headroom, and re-measure with a run that completes rather than alarms.
  "shard6|fingerprint|2400"
  "shard7|seam|"
  "shard8|behavior,behavior_arbiter,combat_initiative,explore_p5,identity,live_movement_style,statinit,trace|"
  "shard9|economy,flow_transaction,grid,guidance,guidance_bark,movement_style,social_graph,venture_char|"
  "shard10|arbiter,bridge,combat,combat_baseline,continuity,derived,directive_cfg,echo_party,expr,intel,objective_combat,realm,realm_reward,save_integrity,snapshot_contract,thread,unified_resolve|"
)

echo "Sharding across ${#SHARDS[@]} shards. Logs: $LOG_DIR"

pids=()
shard_names=()
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

if [[ "$failed" -gt 0 ]]; then
  exit 1
fi
exit 0

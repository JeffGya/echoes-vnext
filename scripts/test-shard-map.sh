#!/usr/bin/env bash
# Shard map for scripts/run-tests-sharded.sh. DATA ONLY: this file defines SHARDS and runs nothing.
# scripts/run-tests-sharded.sh and scripts/check-shard-map.sh both source it, so the runner and
# the checker always read the same map.
#
# FORMAT. Each SHARDS entry is "<shard_name>|<comma-separated EXACT suite names>|<alarm_secs>".
# The runner passes the suites as one `tests =<name1>,<name2>,...` call (exact-match mode,
# ui/AppRoot.gd), so no suite runs twice and no suite is dropped. The third field is the shard's
# alarm: a HANG CEILING in seconds, not an expected duration. Empty means ALARM_SECS (700).
# Keep the entries in DESCENDING order of estimated time: the runner starts shards in map order,
# and longest-first gives the shortest total time.
#
# HOW THIS MAP WAS MADE (2026-10-18). It is not packed by line count. It is packed by MEASURED
# time with scripts/rebalance-shards.sh:
#   1. Run the runner with SHARD_MAP_FILE set to a map that has one suite per shard and with
#      SHARD_JOBS equal to the number of cores. Each suite then runs alone in its own process and
#      the times are close to solo times. The runner writes <log dir>/timing-suites.txt.
#   2. scripts/rebalance-shards.sh <timing-suites.txt> <shard_count> prints the SHARDS block below.
# Measured on a 4-core machine: 130 suites, 3637 s of test time, 12 shards. The runner starts at
# most SHARD_JOBS shards at a time (default: the number of CPU cores), so the same map suits other
# core counts. A suite is never split, so the longest suite is a floor under the wall-clock time.
# Here the floor is `reward` (1054 s, of which the one test
# reward/pace_guide_spirit_runtime_escort_vs_protect takes 991 s). Predicted wall-clock time from the
# measured times: about 1058 s plus 5 to 10 s of process start and merge, for 4, 6, 8 or 12 cores,
# and about 1850 s for 2 cores.
#
# WHEN THE SUITE LIST CHANGES. scripts/check-shard-map.sh fails until each registered suite is in
# exactly one shard (or in MERGE_SUITES). Add a new suite to the shard with the least estimated
# time, then update the counts in AGENTS.md. Re-pack from fresh timing data when a suite becomes
# slow. Older history of this map (the line-count bin-packs and the fingerprint-suite splits of
# 2026-09) is in git: `git log --follow scripts/test-shard-map.sh scripts/run-tests-sharded.sh`.
SHARDS=(
  "shard1|reward|4216"  # est 1054 s, 1 suites
  "shard2|fingerprint_determinism_guide_spirit|3102"  # est 775 s, 1 suites
  "shard3|combat_baseline|1960"  # est 490 s, 1 suites
  "shard4|fingerprint_guide_spirit|1115"  # est 279 s, 1 suites
  "shard5|fingerprint_determinism_pursue|805"  # est 201 s, 1 suites
  "shard6|combat_roundtrip|775"  # est 194 s, 1 suites
  "shard7|terrain|600"  # est 149 s, 1 suites
  "shard8|bark_popup,board_camera.bounds,board_camera.zoom,calling_behavior,combat_initiative,consequence,contact_actor,conversation_repair,fingerprint_pursue,maturity_baseline,movement_arbiter,movement_path,passive,recruit,skill_unlock,snapshot,stop_short,trace,traversal|600"  # est 99 s, 19 suites
  "shard9|combat,combat_camera,combat_ui,contact,directive_cfg,economy,expr,fingerprint_determinism_purify_shrine,fingerprint_determinism_recover,flow_transaction,grid,guidance_bark,movement_option,movement_style,onboarding,save_integrity,stage,support,unified_resolve,venture_char|600"  # est 99 s, 20 suites
  "shard10|arbiter,archetype,behavior_arbiter,board_camera.echo_detail,board_camera.view,bond_trigger,bridge,combat_terrain,continuity,derived,directive,divergence_bark,echo_party,echofactory,explore_p5,fingerprint_combat,fingerprint_determinism_protect,fingerprint_purify_shrine,intel,ko_death,leadership,live_movement_style,morale,movement,objective_combat,old_echo,realm_prog,realm_reward,sanctum.party,sanctum_pulse,shrine,sit_res,skill,skill_loadout,snapshot_fingerprint,social_graph,statinit,stop_short_wiring,thread,vector|600"  # est 99 s, 40 suites
  "shard11|behavior_char,contact_cfg,cooldown,emotion,exclusive_action,explore,fingerprint_determinism_combat,fingerprint_determinism_endure,fingerprint_endure,identity,melee,objective,retreat,sanctum.layout,sanctum.summon,skill_reach,snapshot_contract,stage_stop_ui,stop_short_search,voice,vow,weave|600"  # est 99 s, 22 suites
  "shard12|actor,behavior,board_camera.input,board_camera.pointer,board_pointer,calling,directive_char,divergence,fingerprint_protect,fingerprint_recover,foundation_ui,guidance,institution,pending_result,prog,realm,realm_ui,seam,situational,snapshot_purity,stage_camera,structure|600"  # est 99 s, 22 suites
)

# Suites that run in the merge step and in NO shard (scripts/run-tests-sharded.sh).
# movement_fallback (MovementFallbackGuardTests) fails when the process-wide legacy-selector ledger
# is not empty. In a shard it saw only that shard's suites. In the merge step it sees the ledger of
# every shard (tests/LegacyLedgerFile.gd), so a clean sharded run judges it like the serial run.
# scripts/check-shard-map.sh counts these names with the shard suites: each registered suite must
# appear exactly once in SHARDS and MERGE_SUITES together.
MERGE_SUITES=(
  movement_fallback
)

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
# Measured on a 4-core machine: 132 suites, 3987 s of test time, 13 shards. The first measurement
# (2026-10-18) had 130 suites, 3637 s and 12 shards. `felt_state` (7 s) and `fingerprint_seek` (344 s,
# measured alone) were added after V2-DIRECTIVE-002 phase D registered them; `fingerprint_seek` has its own shard. The runner starts at
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
  "shard4|fingerprint_seek|1376"  # est 344 s, 1 suites
  "shard5|fingerprint_guide_spirit|1115"  # est 279 s, 1 suites
  "shard6|fingerprint_determinism_pursue|805"  # est 201 s, 1 suites
  "shard7|combat_roundtrip|775"  # est 194 s, 1 suites
  "shard8|terrain|600"  # est 149 s, 1 suites
  "shard9|actor,arbiter,behavior,board_camera.bounds,bridge,calling_behavior,conversation_repair,econ_char,explore,fingerprint_pursue,maturity_baseline,movement,passive,sanctum.layout,sanctum_pulse,save_integrity,stage,structure,summon_price_ui,support,traversal|600"  # est 112 s, 20 suites
  "shard10|archetype,behavior_arbiter,board_camera.echo_detail,bond_trigger,combat_camera,combat_ui,continuity,cooldown,derived,directive,echo_party,echofactory,explore_p5,fingerprint_determinism_purify_shrine,fingerprint_determinism_recover,grid,guidance_bark,identity,intel,ko_death,live_movement_style,movement_arbiter,movement_option,movement_style,objective_combat,old_echo,onboarding,realm_prog,realm_reward,sanctum.party,shrine,sit_res,skill,skill_loadout,social_graph,statinit,thread,vector,venture_char,voice|600"  # est 100 s, 40 suites
  "shard11|board_camera.zoom,combat,combat_initiative,combat_terrain,contact_actor,contact_cfg,divergence_bark,economy,fingerprint_combat,fingerprint_determinism_protect,fingerprint_purify_shrine,flow_transaction,guidance,item_packs_char,objective,realm_ui,retreat,skill_reach,skill_unlock,snapshot_contract,stop_short_wiring|600"  # est 101 s, 21 suites
  "shard12|behavior_char,board_camera.pointer,consequence,contact,directive_cfg,directive_char,divergence,emotion,exclusive_action,fingerprint_determinism_combat,fingerprint_determinism_endure,fingerprint_endure,fingerprint_recover,leadership,movement_path,realm,sanctum.summon,situational,snapshot_fingerprint,stop_short_search,vow,weave|600"  # est 100 s, 22 suites
  "shard13|bark_popup,board_camera.input,board_camera.view,board_pointer,calling,expr,felt_state,fingerprint_protect,foundation_ui,institution,melee,morale,payout_ui,pending_result,prog,recruit,risk_probe,seam,snapshot,snapshot_purity,stage_camera,stage_stop_ui,stop_short,trace,unified_resolve|600"  # est 100 s, 24 suites
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

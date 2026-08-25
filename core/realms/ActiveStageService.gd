# res://core/realms/ActiveStageService.gd
# V2-INFRA-003 Phase 5 Slice A: the stage-explore SESSION domain extracted out of
# FlowRuntime.gd, following the BondConsequenceService / VowConsequenceService /
# EmotionConsequenceService extraction pattern (see
# core/runtime/controllers/WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly — requests saves via flow_ctx.request_save(reason),
#     the same choke point FlowRuntime._mark_save_requested() itself calls.
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot.
#
# THIS IS A SERVICE, NOT A CONTROLLER, and it is extracted BEFORE any stage-explore
# controller exists — services first, per core/AGENTS.md "Extract shared services BEFORE the
# controllers that need them".
#
# LOCATION — CORRECTION vs the story brief. The brief proposed
# core/state/flow/states/venture/ActiveStageService.gd. That directory holds flow
# STATES only (FlowStageExploreState, FlowStageState, FlowStageMapState, FlowEncounterState);
# a service is not a flow state. core/AGENTS.md says a new service goes in "the appropriate
# core/ subdirectory", and the extraction rules say a service that wraps a domain class is
# "placed beside that class". Every domain class this file operates on — StageExploreModel,
# StageTerrain, SituationModel, ObjectiveModel — lives in core/realms/, and core/realms/
# already contains a FlowContext-aware service (RealmService.gd), so the FlowContext
# dependency is not a reason to keep it under core/state/. Hence core/realms/.
#
# Moved verbatim (behaviour unchanged) from FlowRuntime.gd:
#   _stage_integer_cell            → stage_integer_cell            (static — pure)
#   _explore_walkable              → explore_walkable             (static — pure)
#   _lift_fog_at_cell              → lift_fog_at_cell             (static — pure)
#   _situation_blocks_step         → situation_blocks_step        (static — pure)
#   _stage_party_heading           → stage_party_heading          (static — pure)
#   _stage_reachable_costs         → stage_reachable_costs        (static — pure)
#   _stage_movement_salt           → stage_movement_salt          (reads flow_ctx.realm_id)
#   _find_explore_target           → find_explore_target
#   _count_revealed_situations     → count_revealed_situations    (static + flow_ctx param)
#   _get_stage_base_reward         → get_stage_base_reward        (static + flow_ctx param)
#   _mark_stage_objective_completed → mark_stage_objective_completed
#   _resolve_combat_situation_and_objective + the situation-resolution body of
#     _apply_victory_return_to_explore  → resolve_combat_situation_and_objective (see below)
#
# CONFIG GETTERS — corrected from the story brief, which listed
# _stage_situation_category_map and _stage_movement_slack_config as methods to move here.
# Both are plain "read a named subtree of balance.json" reads, so per the established
# config-getter rule they moved to ConfigService instead (get_situation_category_cfg,
# get_movement_slack_cfg), beside get_bond_thresholds_cfg and friends. Same for
# _get_balance_rewards_cfg (→ ConfigService.get_rewards_cfg), which additionally has a caller
# on the Phase 6 encounter-retreat path and therefore has no single domain owner at all.
#
# DETERMINISM. Nothing here draws RNG directly. The one determinism-relevant value it
# produces is stage_movement_salt(), which is fed to
# StagePartyMovementAdapter.select_frontier() as its tie-break salt. Its format string
# ("%s:%s" % [realm_id, stage.index-or-stage_id]) is reproduced character for character.
#
# THE COLLAPSED RESOLVE FUNCTION — resolve_combat_situation_and_objective().
# FlowRuntime carried TWO near-identical implementations of "mark the last-engaged situation
# resolved, bump objectives_found, set stage.objectives[idx].completed":
#   (A) _resolve_combat_situation_and_objective(), called from _end_round() before
#       build_final_snapshot(); and
#   (B) an inline block inside _apply_victory_return_to_explore() (the non-final-objective
#       victory path).
# They had DRIFTED. Every difference is now an explicit named parameter — no winner was
# silently picked, and both call sites keep their exact present behaviour. The precedent is
# the retreat path's deliberate omission of bond triggers, which became a parameter rather
# than an accident of call order.
#
#   skip_if_already_resolved  — (A) true: an already-resolved situation is a no-op, so
#                               objectives_found is NOT bumped twice. (B) false: the inline
#                               block had no such guard and re-runs the mutation (and the
#                               objectives_found increment) on a second pass. See DEFECT 1.
#   commit_only_when_modified — (A) true: write-back / request_save / log happen only when a
#                               matching, not-yet-resolved situation was actually mutated —
#                               (A) returned early on a non-Array situations list and did its
#                               write-back INSIDE the match branch. (B) false: (B) coerced a
#                               non-Array situations list to [] and did its write-back AFTER
#                               the loop unconditionally, so it commits, saves and logs even
#                               when nothing matched. See DEFECT 2.
#   log_type / log_message    — (A) "stage.combat_resolved" / "Combat situation resolved on
#                               victory (pre-snapshot)". (B) "stage.combat_resolved.nonfinal"
#                               / "Non-final objective resolved on victory".
#   log_objective_index       — (A) true: log payload carries objective_index. (B) false.
#
# NOT a difference, contrary to the story brief: BOTH implementations set
# `revealed = true` alongside `resolved = true`. There is no revealed/not-revealed drift
# between them, so no parameter expresses one.
#
# The save reason ("stage.combat_resolved") was already identical on both paths and is not
# parameterised.
#
# (A) previously took a `flow_ctx_arg: FlowContext` parameter but requested its save through
# FlowRuntime._mark_save_requested(), which writes to FlowRuntime's OWN flow_ctx member — so a
# flow_ctx_arg different from the member would have mutated one context and saved another. Its
# single call site (FlowRuntime._end_round) passed the member itself, so the two were always
# the same object. Resolved by dropping the parameter entirely: this service holds one
# flow_ctx, used for both the mutation and the save request.
#
# DEFECTS FOUND, DEPRECATED IN PLACE, NOT FIXED (this slice is pure extraction):
#   DEFECT 1 — the (B) path has no already-resolved guard, so if it runs twice against the
#              same situation it increments explore_map.objectives_found twice.
#   DEFECT 2 — the (B) path write-back is unconditional: with an unmatched
#              last_situation_id it still writes the stage back, requests a save, and logs
#              "Non-final objective resolved on victory" for a situation it never touched.
#
# V2-INFRA-003 Phase 5 Slice E — SPLIT. Slice D parked three long procedure bodies and two
# flow.resolve producers here, taking this file to 1,461 lines, past the ~1,000-line guard.
# Slice E moved them out; nothing else changed. WHAT LEFT AND WHERE IT WENT:
#   advance_turn                     → core/realms/StageExploreTurnService.gd
#   engage_situation                 → core/realms/SituationEngagementService.gd
#   resolve_situation_choice         → core/realms/SituationEngagementService.gd
#   _voice_service (private factory)   → StageExploreTurnService (its only caller)
#   _contact_conversation_service      → SituationEngagementService (its only caller)
#   build_scout_return_snapshot      → core/state/flow/states/venture/VentureResolveSnapshotBuilder.gd
#   build_situation_resolve_snapshot → core/state/flow/states/venture/VentureResolveSnapshotBuilder.gd
# Every note above this line describes code that STAYED. The notes that belonged to the moved
# code — the Slice D "why these bodies are not on VentureController" banner, the escape-roll
# determinism pair, producer C's ResolveSnapshotBuilder-purity reasoning, the EchoActor
# emotion-flattening defect — travelled with it, and each new file's header says where it came
# from. This file now owns exactly two things: the pure map/geometry + save-read helpers, and
# the collapsed resolve_combat_situation_and_objective() documented above.
#
# StageExploreTurnService still calls the static helpers here (and constructs this service once
# for find_explore_target). That is a call across a file boundary, not a shim: no function was
# left behind delegating to its new home.
#
# ────────────────────────────────────────────────────────────────────────────
# RENAMED — Half A review correction C4. WAS StageExploreSessionService.
# ────────────────────────────────────────────────────────────────────────────
# The name stopped being true at Slice E. "Session" described the three long procedure bodies
# that ran a stage-explore session — advance_turn, engage_situation, resolve_situation_choice —
# and all three left in that slice. What stayed was named after work that is no longer here,
# which is the same defect the review found in two controller headers: a file that describes a
# structure that does not exist.
#
# RENAME, NOT SPLIT — and the twelve are ONE group, not two. The obvious split is "six pure
# geometry statics" against "save reads plus objective writes", and it is a false seam:
#   - find_explore_target is geometry, but it is an instance method that needs config_service
#     and logger, so it does not belong on the pure side;
#   - get_stage_base_reward would land beside mark_stage_objective_completed, which is exactly
#     the pairing the review objected to ("a rewards reader sitting beside fog-lifting") merely
#     relocated, not resolved.
# What actually binds all twelve is the DATA, not the phase: every one of them reads or writes
# the ACTIVE STAGE RECORD — save_data.realms[realm_id].stages[stage_idx] — or a subtree passed
# down out of it. explore_map (walkable grid, fog, party heading, reachable costs, situations),
# objectives, and the reward those objectives define are four parts of ONE record, and
# get_stage_base_reward belongs beside lift_fog_at_cell for the same reason
# count_revealed_situations does: both walk the same path into the same dict, and neither has
# any other owner. That is a coherent remit and the new name states it.
#
# WHY THE "StageExplore" PREFIX WAS DROPPED, not just the "Session" noun. Two of this file's
# callers are not the explore loop at all: resolve_combat_situation_and_objective is called
# from the combat end-of-round path, and get_stage_base_reward from the encounter-retreat
# payout. Keeping a StageExplore* name would have kept a second false claim — narrower than
# the first, but the same kind. The suggested StageExploreQueryService was rejected for a
# third: three of the twelve WRITE (lift_fog_at_cell mutates the dict it is handed;
# mark_stage_objective_completed and resolve_combat_situation_and_objective write save_data
# and request saves), so "Query" would have been a fresh untruth in place of a stale one.
#
# Rename only — every body, signature, parameter and log string is byte-identical, and all 63
# references across core/ were repointed in the same change. No alias, no forwarder, no
# preload left pointing at the old path.

class_name ActiveStageService
extends RefCounted

const FlowStageExploreStateScript      := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")
const StageTerrainScript               := preload("res://core/realms/StageTerrain.gd")
const MovementPathServiceScript        := preload("res://core/movement/MovementPathService.gd")
const StagePartyMovementAdapterScript  := preload("res://core/movement/StagePartyMovementAdapter.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


# ────────────────────────────────────────────────────────────────────────────
# Pure map/geometry helpers (no flow_ctx, no config, no save writes)
# ────────────────────────────────────────────────────────────────────────────

static func stage_integer_cell(value: Variant, fallback: Dictionary = {"col": 0, "row": 0}) -> Dictionary:
	var raw: Dictionary = value if value is Dictionary else fallback
	return {
		"col": int(raw.get("col", fallback.get("col", 0))),
		"row": int(raw.get("row", fallback.get("row", 0))),
	}


# Build the walkable set for an explore_map.
# Returns the StageTerrain-derived set when terrain is present.
# Falls back to a full width×height rectangle for legacy/empty saves so BFS
# and step movement work uniformly on all maps.
static func explore_walkable(explore_map: Dictionary) -> Dictionary:
	var terrain_v: Variant = explore_map.get("terrain", {})
	var terrain: Dictionary = terrain_v if terrain_v is Dictionary else {}
	var walkable: Dictionary = StageTerrainScript.walkable_set(terrain)
	if not walkable.is_empty():
		return walkable
	# Legacy or empty terrain — fill a full rectangle so movement costs turns
	var w := int(explore_map.get("width",  30))
	var h := int(explore_map.get("height", 30))
	var full: Dictionary = {}
	for c in range(w):
		for r in range(h):
			full["%d,%d" % [c, r]] = true
	return full


# V2-STAGE-004-P5: Lift fog around a single cell — add every walkable cell within
# `radius` (Chebyshev) of `cell` to `explored_cells` (mutated in place). Pure/deterministic.
# Called per movement step so frontier chaining's adapter replan sees the freshly
# explored cells. Same rule as the former post-loop batch (union of per-cell lifts).
static func lift_fog_at_cell(cell: Dictionary, radius: int, walkable: Dictionary, explored_cells: Dictionary) -> void:
	var fog_cells := StageTerrainScript.cells_within_radius(cell, radius, walkable)
	for fc_v in fog_cells:
		var fc: Dictionary = fc_v if fc_v is Dictionary else {}
		explored_cells["%d,%d" % [int(fc.get("col", 0)), int(fc.get("row", 0))]] = true


# V2-STAGE-004-P5: mid-path stop predicate. Returns true when `cell` holds a situation the
# party must engage on contact — unresolved and (not passed, OR the deliberately re-targeted
# Tier-4 objective whose id == target_sit_id). Does NOT require revealed: stepping onto a
# hidden situation reveals it (reveal-on-arrival), mirroring the arrival-at-target path.
# Passed non-target nodes return false (walked through, no re-prompt) — preserving the
# stage.ignore_situation invariant that a passed node never re-prompts.
static func situation_blocks_step(explore_map: Dictionary, cell: Dictionary, target_sit_id: String) -> bool:
	var sits_v: Variant = explore_map.get("situations", [])
	var sits: Array = sits_v if sits_v is Array else []
	var cell_key: String = "%d,%d" % [int(cell.get("col", 0)), int(cell.get("row", 0))]
	for s_v in sits:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if bool(s.get("resolved", false)):
			continue
		if bool(s.get("passed", false)) and str(s.get("id", "")) != target_sit_id:
			continue
		var pos_v: Variant = s.get("pos", { "col": 0, "row": 0 })
		var pos: Dictionary = pos_v if pos_v is Dictionary else { "col": 0, "row": 0 }
		if ("%d,%d" % [int(pos.get("col", 0)), int(pos.get("row", 0))]) == cell_key:
			return true
	return false


# V2-COMBAT-002 Slice 6C: heading for adapter frontier choice.
static func stage_party_heading(explore_map: Dictionary) -> Dictionary:
	var origin_v: Variant = explore_map.get("last_traveled_origin", {})
	var origin: Dictionary = origin_v if origin_v is Dictionary else {}
	if origin.is_empty():
		return {}
	var party_v: Variant = explore_map.get("party_pos", {})
	var party: Dictionary = party_v if party_v is Dictionary else {}
	if party.is_empty():
		return {}
	var dc := int(party.get("col", 0)) - int(origin.get("col", 0))
	var dr := int(party.get("row", 0)) - int(origin.get("row", 0))
	if dc == 0 and dr == 0:
		return {}
	return { "col": dc, "row": dr }


static func stage_reachable_costs(party_pos: Dictionary, walkable: Dictionary) -> Dictionary:
	if walkable.is_empty():
		return {}
	var region := MovementPathServiceScript.reachable_cost_region(
		party_pos, maxi(walkable.size(), 1), walkable, {}, {}, {}
	)
	if not bool(region.get("reachable", false)):
		return {}
	var costs_v: Variant = region.get("costs", {})
	return costs_v if costs_v is Dictionary else {}


# ────────────────────────────────────────────────────────────────────────────
# Save-data reads (static — a pure .get() walk, no construction, no writes)
# ────────────────────────────────────────────────────────────────────────────

# V2-ECONOMY-001: Count how many situations in the current stage have been revealed.
static func count_revealed_situations(flow_ctx_arg: FlowContext) -> int:
	if flow_ctx_arg.realm_id.is_empty() or flow_ctx_arg.stage_id.is_empty():
		return 0
	var _stage_idx := int(flow_ctx_arg.stage_id.replace("stage.", ""))
	var _realm_v: Variant = flow_ctx_arg.save_data.get("realms", {}).get(flow_ctx_arg.realm_id, {})
	var _realm: Dictionary = _realm_v if _realm_v is Dictionary else {}
	var _stages_v: Variant = _realm.get("stages", [])
	var _stages: Array = _stages_v if _stages_v is Array else []
	if _stage_idx >= _stages.size() or not _stages[_stage_idx] is Dictionary:
		return 0
	var _stage: Dictionary = _stages[_stage_idx]
	var _emap_v: Variant = _stage.get("explore_map", {})
	var _emap: Dictionary = _emap_v if _emap_v is Dictionary else {}
	var _sits_v: Variant = _emap.get("situations", [])
	var _sits: Array = _sits_v if _sits_v is Array else []
	var count := 0
	for s in _sits:
		if s is Dictionary and bool((s as Dictionary).get("revealed", false)):
			count += 1
	return count


# V2-ECONOMY-001: Get the base reward of the current stage.
#
# V2-INFRA-003 Phase 8 — DEFECT D39 ANSWERED HERE, AND ANSWERED THE SAME WAY FOR BOTH READERS.
# This used to read `_objs[0]` only, and read its type under the key `"obj_type"`, which
# `ObjectiveModel.make()` never writes (it writes `"type"` — core/realms/ObjectiveModel.gd:63).
# Both faults pushed the same way, so every stage fell through to the "combat" default and this
# returned a flat 30, while `RewardCalc.compute()` — the stage-completion payer — SUMMED the
# same stage's objective weights. Two "base reward of this stage" readers, one stage, two
# answers, and the register warned that whatever answers D39 must answer it for both.
#
# It now delegates to `RewardCalc.base_reward()`, the single definition, so the two cannot
# drift apart again. Consequence, deliberate: the partial-withdrawal payout rises on every
# multi-objective stage (it is a fraction of this base), and shrine/boss objective weights
# reach it for the first time.
static func get_stage_base_reward(flow_ctx_arg: FlowContext, config_service_arg: ConfigService) -> int:
	var _stage_idx := int(flow_ctx_arg.stage_id.replace("stage.", ""))
	var _realm_v: Variant = flow_ctx_arg.save_data.get("realms", {}).get(flow_ctx_arg.realm_id, {})
	var _realm: Dictionary = _realm_v if _realm_v is Dictionary else {}
	var _stages_v: Variant = _realm.get("stages", [])
	var _stages: Array = _stages_v if _stages_v is Array else []
	var _objs: Array = []
	if _stage_idx >= 0 and _stage_idx < _stages.size() and _stages[_stage_idx] is Dictionary:
		var _stage: Dictionary = _stages[_stage_idx]
		var _objs_v: Variant = _stage.get("objectives", [])
		_objs = _objs_v if _objs_v is Array else []
	return RewardCalc.base_reward(_objs, ConfigService.get_rewards_cfg(config_service_arg))


# V2-INFRA-003 Phase 8 (defect D77): claim the ONE defeat consolation of the situation that
# produced the encounter now ending.
#
# The 25% defeat consolation is intended design (Jeff, 2026-08-24) and the situation must stay
# UNRESOLVED after a defeat so the fight is still retryable. Both together made the payout
# farmable without limit: lose, get paid, retry, lose, get paid. The stamp below separates the
# two — the fight stays retryable, the payout does not repeat.
#
# Returns true exactly once per situation, and writes `consolation_paid: true` onto that
# situation. Returns true (without a stamp) when there is no situation to stamp — an encounter
# driven outside the stage-explore flow, e.g. a test harness or a debug spawn. That is not a
# farming hole: repeating the payout requires re-entering the same situation, and there is no
# situation to re-enter.
#
# Callers must persist: this mutates save data through the same _write_stage_back() seam the
# rest of the stage-explore writes use.
static func claim_situation_defeat_consolation(flow_ctx_arg: FlowContext) -> bool:
	if flow_ctx_arg.realm_id.is_empty() or flow_ctx_arg.stage_id.is_empty():
		return true
	var _stage := FlowStageExploreState._get_current_stage(flow_ctx_arg)
	if _stage.is_empty():
		return true
	var _emap_v: Variant = _stage.get("explore_map", {})
	var _emap: Dictionary = _emap_v if _emap_v is Dictionary else {}
	var _sit_id := str(_emap.get("last_situation_id", ""))
	if _sit_id.is_empty():
		return true
	var _sits_v: Variant = _emap.get("situations", [])
	var _sits: Array = _sits_v if _sits_v is Array else []
	for _i in range(_sits.size()):
		var _s_v: Variant = _sits[_i]
		if not (_s_v is Dictionary):
			continue
		var _s: Dictionary = _s_v
		if str(_s.get("id", "")) != _sit_id:
			continue
		if bool(_s.get("consolation_paid", false)):
			return false
		_s["consolation_paid"] = true
		_sits[_i] = _s
		_emap["situations"] = _sits
		_stage["explore_map"] = _emap
		FlowStageExploreState._write_stage_back(flow_ctx_arg, _stage)
		return true
	# last_situation_id names a situation that is no longer in the list — nothing to stamp.
	return true


# ────────────────────────────────────────────────────────────────────────────
# Target selection
# ────────────────────────────────────────────────────────────────────────────

func stage_movement_salt(stage: Dictionary) -> String:
	return "%s:%s" % [str(flow_ctx.realm_id), str(stage.get("index", flow_ctx.stage_id))]


# V2-COMBAT-002 Slice 6C: Four-tier fog-of-war target selection routed through
# StagePartyMovementAdapter. The live stage loop no longer depends on
# StageTerrain.nearest_unexplored / next_step ordering.
#
# Priority:
#   Tier 1 — nearest DISCOVERED unresolved OBJECTIVE situation (BFS distance),
#             excluding nodes where passed==true (player skipped them; let them explore).
#   Tier 2 — best DISCOVERED unresolved non-objective situation scored by directive
#             target_preference[category], excluding passed==true nodes,
#             and reachable within the adapter's bounded slack.
#   Tier 3 — FRONTIER: adapter-selected walkable cell not yet in explored_cells.
#             Returns synthetic { "id": "", "pos": <cell>, "is_frontier": true }.
#   Tier 4 — FRONTIER EXHAUSTED (select_frontier returned {}, i.e. no reachable frontier):
#             Re-offer the nearest unresolved OBJECTIVE including passed ones — so the stage
#             remains completable when all optional nodes were skipped.
#             Non-objective passed nodes are NEVER re-offered (player dismissed them on purpose).
#             If no objective exists either, returns {} (nothing left; party parks).
#
# No directive ID may be named here. All behaviour comes from reading directive fields.
func find_explore_target(
	explore_map: Dictionary,
	directive: Dictionary,
	walkable: Dictionary,
	explored_cells: Dictionary,
	stage: Dictionary
) -> Dictionary:
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []
	var party_pos_v: Variant = explore_map.get("party_pos", { "col": 0, "row": 0 })
	var party_pos: Dictionary = party_pos_v if party_pos_v is Dictionary else { "col": 0, "row": 0 }
	var dist_from_party: Dictionary = stage_reachable_costs(party_pos, walkable)
	var category_map := ConfigService.get_situation_category_cfg(config_service)
	var slack_config := ConfigService.get_movement_slack_cfg(config_service)

	# ---- Tier 1: discovered, unresolved OBJECTIVE situations (not passed) ----
	var tier1_candidates: Array = []
	for sit_v in situations:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if bool(sit.get("resolved", false)):
			continue
		if not bool(sit.get("is_objective", false)):
			continue
		if not bool(sit.get("revealed", false)):
			continue  # undiscovered — fog; not targetable
		if bool(sit.get("passed", false)):
			continue  # player skipped it — do not re-target until Tier 4
		tier1_candidates.append(sit)
	var best_obj_sit := StagePartyMovementAdapterScript.select_objective_target(
		tier1_candidates, dist_from_party, {}, category_map, slack_config
	)
	if not best_obj_sit.is_empty():
		best_obj_sit["_movement_tier"] = StagePartyMovementAdapterScript.TIER_OBJECTIVE
		best_obj_sit["is_frontier"] = false
		return best_obj_sit

	# ---- Tier 2: discovered, unresolved non-objective situations (directive-biased, not passed) ----
	var target_pref_v: Variant = directive.get("target_preference", {})
	var target_pref: Dictionary = target_pref_v if target_pref_v is Dictionary else {}

	var tier2_candidates: Array = []
	for sit_v in situations:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if bool(sit.get("resolved", false)):
			continue
		if bool(sit.get("is_objective", false)):
			continue  # handled in Tier 1
		if not bool(sit.get("revealed", false)):
			continue  # undiscovered — fog; not targetable
		if bool(sit.get("passed", false)):
			continue  # player skipped it; never re-target non-objective passed nodes
		tier2_candidates.append(sit)
	var best_sit := StagePartyMovementAdapterScript.select_objective_target(
		tier2_candidates, dist_from_party, target_pref, category_map, slack_config
	)
	if not best_sit.is_empty():
		best_sit["_movement_tier"] = StagePartyMovementAdapterScript.TIER_WEIGHTED
		best_sit["is_frontier"] = false
		return best_sit

	# ---- Tier 3: frontier — adapter-selected unexplored cell ----
	var frontier_candidates: Array = []
	for key_value: Variant in walkable.keys():
		var key := str(key_value)
		if explored_cells.has(key):
			continue
		var parts := key.split(",", false)
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			continue
		frontier_candidates.append({ "col": int(parts[0]), "row": int(parts[1]) })
	var frontier_cell := StagePartyMovementAdapterScript.select_frontier(
		frontier_candidates,
		party_pos,
		stage_party_heading(explore_map),
		walkable,
		stage_movement_salt(stage)
	)
	if not frontier_cell.is_empty():
		return {
			"id": "",
			"pos": frontier_cell,
			"is_frontier": true,
			"_movement_tier": StagePartyMovementAdapterScript.TIER_FRONTIER,
		}

	# ---- Tier 4: frontier exhausted — re-offer nearest unresolved OBJECTIVE (including passed) ----
	# The whole reachable map is explored. If the player had previously passed an objective,
	# the stage cannot be completed until they engage it — re-offer it here so the stage stays
	# completable. Non-objective passed nodes are NOT re-offered.
	var tier4_candidates: Array = []
	for sit_v in situations:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if bool(sit.get("resolved", false)):
			continue
		if not bool(sit.get("is_objective", false)):
			continue  # only objectives are re-offered (non-objective passed nodes stay skipped)
		if not bool(sit.get("revealed", false)):
			continue  # still fog — cannot target
		tier4_candidates.append(sit)
	var best_obj4_sit := StagePartyMovementAdapterScript.select_objective_target(
		tier4_candidates, dist_from_party, {}, category_map, slack_config
	)
	if not best_obj4_sit.is_empty():
		best_obj4_sit["_movement_tier"] = StagePartyMovementAdapterScript.TIER_PASSED_OBJECTIVE
		best_obj4_sit["is_frontier"] = false
		return best_obj4_sit

	# Nothing left — whole map explored and nothing actionable remains (or all situations resolved).
	return {}


# ────────────────────────────────────────────────────────────────────────────
# Objective / situation resolution (mutates save_data, requests a save)
# ────────────────────────────────────────────────────────────────────────────

# V2-STAGE-002: Mark stage.objectives[objective_index].completed = true in save_data.
# Used for stub-completed types (recover/protect/endure/pursue) and after combat victory.
func mark_stage_objective_completed(objective_index: int, t: int) -> void:
	if objective_index < 0:
		return
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return
	var objs_v: Variant = stage.get("objectives", [])
	if not (objs_v is Array):
		return
	var objs: Array = objs_v
	if objective_index < objs.size() and objs[objective_index] is Dictionary:
		objs[objective_index]["completed"] = true
		stage["objectives"] = objs
		FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
		flow_ctx.request_save("stage.objective.completed")
		logger.debug(t, "stage.objective.completed", "Stage objective marked completed", {
			"stage_id":        flow_ctx.stage_id,
			"objective_index": objective_index,
		})


# V2-STAGE-002: On combat victory, mark the situation resolved AND the objective completed
# in one operation. Called from _end_round() before build_final_snapshot() so that:
# (a) objectives_remaining is accurate in the resolve snapshot, and
# (b) if the player returns to stage_explore, the situation is already resolved and will
#     not be re-targeted by advance_turn.
# Also called from FlowRuntime._apply_victory_return_to_explore() (the non-final-objective
# victory path), which used to carry its own drifted copy of this body — see the file header
# for every difference and the parameter that expresses it.
func resolve_combat_situation_and_objective(
	t: int,
	skip_if_already_resolved: bool,
	commit_only_when_modified: bool,
	log_type: String,
	log_message: String,
	log_objective_index: bool
) -> void:
	if flow_ctx.stage_id.is_empty():
		return
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return
	var map_v: Variant = stage.get("explore_map", {})
	var vmap: Dictionary = map_v if map_v is Dictionary else {}
	var vsit_id := str(vmap.get("last_situation_id", ""))
	if vsit_id.is_empty():
		return
	var vsits_v: Variant = vmap.get("situations", [])
	# A non-Array situations list yields an empty scan: with commit_only_when_modified the
	# function then returns without touching anything (the (A) path's early `return`), and
	# without it the unconditional write-back still runs (the (B) path's coercion to []).
	var vsits: Array = vsits_v if vsits_v is Array else []

	var modified := false
	var matched_objective_index := -1

	for _vi in range(vsits.size()):
		var _vsv: Variant = vsits[_vi]
		if not (_vsv is Dictionary):
			continue
		if str((_vsv as Dictionary).get("id", "")) != vsit_id:
			continue
		var _vs: Dictionary = _vsv
		if skip_if_already_resolved and bool(_vs.get("resolved", false)):
			break  # Already resolved (e.g. _handle_complete_stage ran first) — no-op
		_vs["resolved"] = true
		_vs["revealed"]  = true
		vsits[_vi] = _vs
		if bool(_vs.get("is_objective", false)):
			vmap["objectives_found"] = int(vmap.get("objectives_found", 0)) + 1
			# Mark the objective completed
			var _vobj_idx := int(_vs.get("objective_index", -1))
			if _vobj_idx >= 0:
				var _vstage_objs_v: Variant = stage.get("objectives", [])
				if _vstage_objs_v is Array:
					var _vstage_objs: Array = _vstage_objs_v
					if _vobj_idx < _vstage_objs.size() and _vstage_objs[_vobj_idx] is Dictionary:
						_vstage_objs[_vobj_idx]["completed"] = true
					stage["objectives"] = _vstage_objs
		modified = true
		matched_objective_index = int(_vs.get("objective_index", -1))
		break

	if commit_only_when_modified and not modified:
		return

	vmap["situations"] = vsits
	stage["explore_map"] = vmap
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.combat_resolved")
	var log_data: Dictionary = {
		"stage_id":     flow_ctx.stage_id,
		"situation_id": vsit_id,
	}
	if log_objective_index:
		log_data["objective_index"] = matched_objective_index
	logger.info(t, log_type, log_message, log_data)

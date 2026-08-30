# res://core/realms/StageExploreTurnService.gd
# V2-INFRA-003 Phase 5 Slice E: the stage.advance_turn PROCEDURE BODY, split out of
# core/realms/ActiveStageService.gd (see that file's header for the Slice A contract
# and location reasoning, which this file inherits unchanged).
#
# CONTRACT (identical to ActiveStageService's):
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly — requests saves via flow_ctx.request_save(reason).
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot.
#   - Same constructor signature (flow_ctx, config_service, logger) as every sibling service
#     in this extraction family, so a caller swaps one factory line for another.
#
# LOCATION — core/realms/, for exactly the reason Slice A gave: every domain class this body
# operates on (StageExploreModel, StageTerrain, SituationModel) lives here, and core/realms/
# already holds FlowContext-aware services (RealmService, ContactConversationService,
# ActiveStageService).
#
# WHY advance_turn IS ALONE HERE. The three procedure bodies Slice D parked on
# ActiveStageService do not form one group. advance_turn is the MOVEMENT/FOG/TURN
# body: it reads the directive, walks the party, lifts fog, sweeps discovery and queues an
# engagement popup. engage_situation and resolve_situation_choice are the SITUATION bodies:
# they mutate one situation, apply emotion deltas, and return the same "resolved" verdict
# shape through one VentureController code path. Keeping all three together would have left a
# ~810-line file — the guard this slice exists to clear. They are split on that seam, not on a
# line count: this file shares nothing with SituationEngagementService except the constructor.
#
# WHAT IT REACHES ACROSS THE FILE BOUNDARY FOR. The map/geometry helpers stay on
# ActiveStageService (they have callers beyond this body and are its own domain):
# stage_integer_cell / explore_walkable / lift_fog_at_cell / situation_blocks_step are static
# and called as ActiveStageService.<name>(). find_explore_target is an INSTANCE method
# (it reads flow_ctx.realm_id through stage_movement_salt and config_service through the
# category/slack getters), so this body builds ONE ActiveStageService up front and
# reuses it — a new instance per loop iteration would be waste in a loop that is already a
# known performance hazard. Nothing is duplicated and no lookalike API is substituted
# (AGENTS.md #19).
#
# DETERMINISM. Nothing here draws RNG directly. The escape-roll pair is unchanged: the
# turn_count INCREMENT lives in this function (after target selection, before any movement)
# and the READ lives in VentureController.handle_return_home(). Their relative order is
# untouched by this split. See the advance_turn() docstring below.

class_name StageExploreTurnService
extends RefCounted

const FlowStageExploreStateScript      := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")
const MovementPathServiceScript        := preload("res://core/movement/MovementPathService.gd")
const StagePartyMovementAdapterScript  := preload("res://core/movement/StagePartyMovementAdapter.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


# ═══════════════════════════════════════════════════════════════════════════
# V2-INFRA-003 Phase 5 Slice D — the long procedural bodies of the four biggest
# venture actions.
#
# WHY THEY ARE HERE AND NOT ON VentureController. A controller routes an action, applies
# domain calls and returns a FlowActionOutcome; it does not hold long procedural bodies
# (the slice brief's hard size requirement, and the reason Slice A built this service
# "specifically so the heavy explore-turn work has a home"). Each function below is the
# pre-extraction handler body MINUS its snapshot/transition tail; it returns a plain verdict
# that VentureController translates into a FlowActionOutcome. Nothing here holds
# flow_machine, so none of them can publish a snapshot or transition by itself.
#
# Saves are requested with flow_ctx.request_save(reason) at the ORIGINAL point in the body,
# never deferred onto the outcome — _apply_action_outcome() applies save_reasons AFTER the
# transition, which would reorder the "|"-joined save_request_reason string.
# ═══════════════════════════════════════════════════════════════════════════#
# V2-INFRA-003 Phase 5 Slice E — SPLIT, NOT MOVED. This body was extracted verbatim from
# core/realms/ActiveStageService.gd, which had grown to 1,461 lines (Slice D moved
# VentureController's heavy procedure bodies there to meet the controller's size budget, and
# the size problem simply moved with them). No behaviour changed in this slice: the split is
# by the seams the Slice D banner ABOVE already describes, which is why that banner is
# reproduced verbatim in both files the bodies split into — it is the contract for each of
# them, not a note about a file. See core/realms/ActiveStageService.gd's header for
# the full inventory of what left it and where each piece went.


## Builds a fresh NarrativeVoiceService, mirroring FlowRuntime._voice_service(). Per-call
## construction (cheap RefCounted, always correct if flow_ctx is replaced).
func _voice_service() -> NarrativeVoiceService:
	return NarrativeVoiceService.new(flow_ctx, config_service, logger)


## The body of FlowRuntime._handle_stage_advance_turn(), moved verbatim minus its four
## snapshot tails. Returns a status the caller maps to an outcome:
##   "no_stage"      — no active stage           → rebuild + refresh
##   "not_exploring" — party not exploring       → BARE refresh (no rebuild) — the one path
##                     that needs FlowActionOutcome.refresh_outcome()
##   "no_target"     — nothing left to explore   → rebuild + refresh
##   "advanced"      — a turn was consumed       → rebuild + refresh
##
## DETERMINISM: `explore_map["turn_count"] += 1` below is the INCREMENT half of the escape-roll
## pair. The READ half is in VentureController.handle_return_home()
## ("stage.escape.%s.%d" % [stage_id, turn_count]). Their relative order is unchanged by this
## extraction — the increment still happens only inside this function, after target selection
## and before any movement.
##
## `directive_service` is a parameter rather than a constructor dependency so the directive is
## resolved at exactly the pre-extraction point: AFTER the no-stage and not-exploring guards.
func advance_turn(directive_service: DirectiveService, t: int) -> String:
	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		logger.debug(t, "stage.advance.no_stage", "advance_turn: no active stage", {})
		return "no_stage"

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	if str(explore_map.get("party_state", "")) != StageExploreModel.STATE_EXPLORING:
		logger.debug(t, "stage.advance.not_exploring", "advance_turn: party not in exploring state", {
			"party_state": explore_map.get("party_state", "")
		})
		return "not_exploring"

	# V2-STAGE-004-P2: resolve directive once for this turn
	var directive := directive_service.get_active_directive()
	var step_budget := int(directive.get("step_budget", DirectiveService.DEFAULT_STEP_BUDGET))
	# V2-STAGE-004 Phase 2.5: reveal_radius replaces passive_reveal_radius as the primary fog lever.
	# Both directives always reveal (radius is the differentiator — Scout wide, Seek narrow).
	var reveal_radius := int(directive.get("reveal_radius", directive.get("passive_reveal_radius", 2)))

	# V2-STAGE-004-P2: build walkable set once (supports both terrain maps and legacy saves)
	var walkable := ActiveStageService.explore_walkable(explore_map)
	# JSON-decoded save coordinates are floats; canonicalize only at this live
	# boundary so shared path validation continues to require integer cells.
	explore_map["party_pos"] = ActiveStageService.stage_integer_cell(explore_map.get("party_pos", {}))

	# V2-STAGE-004 Phase 2.5: load durable explored_cells set (fog state).
	var explored_cells_v: Variant = explore_map.get("explored_cells", {})
	var explored_cells: Dictionary = explored_cells_v if explored_cells_v is Dictionary else {}

	# V2-STAGE-004 Phase 2.5 (Finding 2): entry-fog seed delegated to the shared static helper.
	# Idempotent (empty-guard inside); no-op when already seeded by _reset_session_state.
	# Passing precise_intel_bias from the resolved directive keeps intel quality consistent.
	var _adv_precise_bias := int(directive.get("precise_intel_bias", 0))
	var _adv_realm_seed   := int(flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("seed", 0))
	FlowStageExploreStateScript.seed_entry_fog_if_needed(
		explore_map, walkable, reveal_radius, _adv_precise_bias, _adv_realm_seed,
		flow_ctx.stage_id, logger, t
	)
	# Re-read explored_cells after the seed (may have been populated by the helper above).
	var _ec_post_v: Variant = explore_map.get("explored_cells", {})
	explored_cells = _ec_post_v if _ec_post_v is Dictionary else {}

	# V2-COMBAT-002 Slice 6C: target selection is now routed through the stage
	# party adapter. It uses shared MovementPathService reachability, continuity
	# heading, and a stable stage-identity salt.
	# V2-INFRA-003 Phase 5 Slice E: find_explore_target() is an instance method that stayed on
	# ActiveStageService (see this file's header). Built ONCE here and reused by the
	# movement loop below — the constructor only assigns three fields and writes nothing.
	var _session := ActiveStageService.new(flow_ctx, config_service, logger)
	var target := _session.find_explore_target(explore_map, directive, walkable, explored_cells, stage)

	if target.is_empty():
		# All walkable cells explored and no discovered unresolved situations — nothing left.
		logger.debug(t, "stage.advance.no_target", "advance_turn: no target found (all explored, all resolved)", {})
		return "no_target"

	# One explore-turn consumed per Advance call
	explore_map["turn_count"] = int(explore_map.get("turn_count", 0)) + 1

	var target_pos_v: Variant = target.get("pos", { "col": 0, "row": 0 })
	var target_pos: Dictionary = ActiveStageService.stage_integer_cell(target_pos_v)
	var is_frontier := bool(target.get("is_frontier", false))
	var target_sit_id := str(target.get("id", ""))
	var target_tier := int(target.get("_movement_tier", StagePartyMovementAdapterScript.TIER_FRONTIER))

	# Capture pre-advance party position as the first entry in the traveled path.
	var _pre_move: Dictionary = ActiveStageService.stage_integer_cell(explore_map.get("party_pos", {}))
	explore_map["party_pos"] = _pre_move.duplicate()
	var _origin_cell: Dictionary = {
		"col": int(_pre_move.get("col", 0)),
		"row": int(_pre_move.get("row", 0)),
	}

	# V2-STAGE-004 Phase 2.5 / P5: ALWAYS-ON fog lift, now applied PER STEP inside the
	# loop (replaces the old post-loop batch). Lift the starting cell first so the
	# zero-step case still reveals the entry vicinity (idempotent when already explored).
	# Both directives lift fog; reveal_radius is the lever (Scout wide, Seek narrow).
	ActiveStageService.lift_fog_at_cell(_pre_move, reveal_radius, walkable, explored_cells)

	var stepped: Array = []
	var steps := 0
	var _heading_origin_v: Variant = explore_map.get("last_traveled_origin", {})
	var _heading_origin: Dictionary = _heading_origin_v if _heading_origin_v is Dictionary else {}
	while steps < step_budget:
		var here: Dictionary = ActiveStageService.stage_integer_cell(explore_map.get("party_pos", {}))
		explore_map["party_pos"] = here.duplicate()
		explore_map["last_traveled_origin"] = _heading_origin.duplicate(true)
		target = _session.find_explore_target(explore_map, directive, walkable, explored_cells, stage)
		if target.is_empty():
			break
		target_pos_v = target.get("pos", { "col": 0, "row": 0 })
		target_pos = ActiveStageService.stage_integer_cell(target_pos_v)
		is_frontier = bool(target.get("is_frontier", false))
		target_sit_id = str(target.get("id", ""))
		target_tier = int(target.get("_movement_tier", StagePartyMovementAdapterScript.TIER_FRONTIER))
		if int(here.get("col", 0)) == int(target_pos.get("col", 0)) \
				and int(here.get("row", 0)) == int(target_pos.get("row", 0)):
			break

		var profile := StagePartyMovementAdapterScript.build_profile(directive)
		var goal := StagePartyMovementAdapterScript.build_goal(explore_map, target, target_tier, walkable)
		var route := MovementPathServiceScript.shortest_path(here, target_pos, walkable, {}, {}, {})
		if not bool(route.get("reachable", false)):
			var no_route_intent := StagePartyMovementAdapterScript.build_intent(profile, goal, [], here)
			if not no_route_intent.is_empty():
				StagePartyMovementAdapterScript.build_result(
					here, [], "no_route", [], no_route_intent, goal, goal.get("declared_fallback", {}) as Dictionary
				)
			break

		var route_path_v: Variant = route.get("path", [])
		var route_path: Array = route_path_v if route_path_v is Array else []
		if route_path.is_empty():
			break

		var intent := StagePartyMovementAdapterScript.build_intent(profile, goal, route_path, here)
		if intent.is_empty():
			break

		var nxt_v: Variant = route_path[0]
		var nxt: Dictionary = nxt_v if nxt_v is Dictionary else {}
		if nxt.is_empty():
			break
		if int(nxt.get("col", 0)) == int(here.get("col", 0)) \
				and int(nxt.get("row", 0)) == int(here.get("row", 0)):
			break
		var step_reaches_target := int(nxt.get("col", 0)) == int(target_pos.get("col", 0)) \
			and int(nxt.get("row", 0)) == int(target_pos.get("row", 0))
		_heading_origin = {
			"col": int(here.get("col", 0)),
			"row": int(here.get("row", 0)),
		}
		nxt = ActiveStageService.stage_integer_cell(nxt)
		explore_map["party_pos"] = nxt.duplicate()
		stepped.append(nxt.duplicate())
		steps += 1
		# Lift fog around every newly entered cell (per-step so the next adapter
		# frontier replan sees the updated explored set).
		ActiveStageService.lift_fog_at_cell(nxt, reveal_radius, walkable, explored_cells)
		var step_blocks := ActiveStageService.situation_blocks_step(explore_map, nxt, target_sit_id)
		var stop_reason := "capacity_spent"
		if step_blocks:
			stop_reason = "interrupted"
		elif step_reaches_target:
			stop_reason = "reached_destination"
		StagePartyMovementAdapterScript.build_result(here, [nxt], stop_reason, [], intent, goal)
		# V2-STAGE-004-P5 (mid-path stop): walking the party ONTO an unresolved, un-passed
		# situation (revealed OR hidden — reveal-on-arrival) ends the advance there so the
		# normal engagement popup fires. Passed nodes are walked through (no prompt) unless
		# this is exactly the node deliberately re-targeted via Tier-4 (target_sit_id match).
		# The post-loop reveal sweep + arrival check set pending_situation_id.
		if step_blocks:
			break

	# V2-STAGE-004-P2 / V2-COMBAT-002 slice 5: stash the path walked this turn for the UI
	# chained-tween animation.
	# Shape: Array of { col, row } — DESTINATIONS ONLY, one entry per cell actually entered.
	# The path EXCLUDES the origin, matching the movement contracts' path-excludes-origin
	# rule (MovementContractValidation.require_path_excludes_origin). The pre-advance cell
	# rides alongside in `last_traveled_origin` so the UI keeps its ghost-trail anchor.
	# Zero steps ⇒ empty path, and origin == the (unchanged) current party cell.
	# Presentation-only; does not affect determinism. Cleared by next advance or session reset.
	explore_map["last_traveled_origin"] = _origin_cell
	if stepped.is_empty():
		explore_map["last_traveled_path"] = []
	else:
		var _path: Array = []
		for _sp in stepped:
			var _sp_d: Dictionary = _sp if _sp is Dictionary else {}
			_path.append({ "col": int(_sp_d.get("col", 0)), "row": int(_sp_d.get("row", 0)) })
		explore_map["last_traveled_path"] = _path

	var party_pos: Dictionary = ActiveStageService.stage_integer_cell(explore_map.get("party_pos", {}))
	explore_map["party_pos"] = party_pos.duplicate()

	# V2-STAGE-004 Phase 2.5 / P5: fog was lifted PER STEP during the movement loop above
	# (ALWAYS-ON for both directives; reveal_radius is the lever). explored_cells is mutated
	# in place; persist it back so the discovery sweep below and the snapshot see every
	# newly explored cell (including all chained-frontier cells).
	explore_map["explored_cells"] = explored_cells

	# V2-STAGE-004 P5 (playtest fix): capture which OBJECTIVE situations were already revealed
	# BEFORE the discovery sweep, so we can detect a newly-revealed objective this advance and
	# fire Anansi's "objective_revealed" snippet at that narrative moment (event b).
	var _pre_reveal_obj_ids: Dictionary = {}
	var _pre_sits_v: Variant = explore_map.get("situations", [])
	var _pre_sits: Array = _pre_sits_v if _pre_sits_v is Array else []
	for _prs_v in _pre_sits:
		var _prs: Dictionary = _prs_v if _prs_v is Dictionary else {}
		if bool(_prs.get("is_objective", false)) and bool(_prs.get("revealed", false)):
			_pre_reveal_obj_ids[str(_prs.get("id", ""))] = true

	# Tile-based discovery sweep: reveal every unresolved situation whose cell is now in
	# explored_cells. This is a superset of the old radius check — any situation whose tile
	# was fog-lifted during movement (within reveal_radius of any stepped cell) is guaranteed
	# revealed. Invariant: tile in explored_cells ⟺ situation on it is revealed.
	FlowStageExploreStateScript._reveal_explored_situations_static(explore_map, explored_cells, _adv_precise_bias, _adv_realm_seed, flow_ctx.stage_id, logger, t)

	# Detect a newly-revealed objective (was hidden before the sweep, revealed after).
	var _objective_revealed := false
	var _post_sits_v: Variant = explore_map.get("situations", [])
	var _post_sits: Array = _post_sits_v if _post_sits_v is Array else []
	for _pos_v in _post_sits:
		var _pos: Dictionary = _pos_v if _pos_v is Dictionary else {}
		if bool(_pos.get("is_objective", false)) and bool(_pos.get("revealed", false)) \
				and not _pre_reveal_obj_ids.has(str(_pos.get("id", ""))):
			_objective_revealed = true
			break

	# V2-STAGE-004 Phase 2.5: arrival/engage check — check whether the final party cell
	# holds a discovered, unresolved, non-frontier situation (includes situations discovered
	# en route during this advance via the fog-lift pass above).
	var _party_key: String = "%d,%d" % [int(party_pos.get("col", 0)), int(party_pos.get("row", 0))]
	var _arrived_sit_id := ""
	var _arrived_real_sit := false

	# Check if any discovered+unresolved situation is at party's final position.
	# V2-STAGE-004 Phase 2.5 (pass-fix): only trigger engagement for a passed node when it
	# is the current deliberate target (Tier-4 re-offer).  Walking PAST a passed node en route
	# to the frontier must NOT re-prompt — that is the key fix for the "return to same node" bug.
	var sits_check_v: Variant = explore_map.get("situations", [])
	var sits_check: Array = sits_check_v if sits_check_v is Array else []
	for _acs_v in sits_check:
		var _acs: Dictionary = _acs_v if _acs_v is Dictionary else {}
		if bool(_acs.get("resolved", false)):
			continue
		if not bool(_acs.get("revealed", false)):
			continue
		# Skip passed nodes unless this is exactly the node we deliberately re-targeted
		# (Tier-4 re-offer puts the objective's id into target_sit_id before this check).
		var _acs_id := str(_acs.get("id", ""))
		if bool(_acs.get("passed", false)) and _acs_id != target_sit_id:
			continue
		var _acp_v: Variant = _acs.get("pos", { "col": 0, "row": 0 })
		var _acp: Dictionary = _acp_v if _acp_v is Dictionary else { "col": 0, "row": 0 }
		var _ack: String = "%d,%d" % [int(_acp.get("col", 0)), int(_acp.get("row", 0))]
		if _ack == _party_key:
			_arrived_sit_id   = _acs_id
			_arrived_real_sit = true
			break

	var arrived := _arrived_real_sit \
		or (not is_frontier \
			and int(party_pos.get("col", 0)) == int(target_pos.get("col", 0)) \
			and int(party_pos.get("row", 0)) == int(target_pos.get("row", 0)) \
			and not target_sit_id.is_empty())

	if _arrived_real_sit:
		# Parked on a discovered+unresolved real situation — queue engagement popup.
		explore_map["last_situation_id"]   = _arrived_sit_id
		explore_map["pending_situation_id"] = _arrived_sit_id
		explore_map["in_transit"]           = false
		explore_map["target_situation_id"]  = ""
	elif arrived and not target_sit_id.is_empty():
		# Reached the targeted real situation by position (dist==0 case).
		explore_map["last_situation_id"]   = target_sit_id
		explore_map["pending_situation_id"] = target_sit_id
		explore_map["in_transit"]           = false
		explore_map["target_situation_id"]  = ""
	else:
		# IN-TRANSIT toward frontier or mid-way to a real situation; no engagement popup.
		explore_map["in_transit"]          = true
		explore_map["target_situation_id"] = target_sit_id if not is_frontier else ""

	# V2-STAGE-004 Phase 5: travel-beat selection (bark or Anansi snippet).
	# Fires only when the party actually travelled this turn (stepped ≥1 tile).
	# Transient — same lifecycle as last_traveled_path: overwritten every advance,
	# cleared on session reset (not carried forward by _reset_session_state's rebuild).
	explore_map["travel_bark"]    = {}
	explore_map["travel_snippet"] = ""
	if not stepped.is_empty():
		_voice_service().select_travel_beat(explore_map, t, logger, SanctumService.get_active_party_echoes(flow_ctx.save_data))

	# V2-STAGE-004 P5 (playtest fix): Anansi event (b) — an objective situation was revealed
	# during this advance. Fires a snippet at that moment (overwrites the empty travel_snippet;
	# gated by data.stages.anansi_snippet_events). Independent of the echo-bark cadence above.
	if _objective_revealed:
		_voice_service().fire_anansi_snippet(explore_map, "objective_revealed", t)

	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.advance_turn")

	logger.info(t, "stage.advance_turn", "Party advanced", {
		"stage_id":           flow_ctx.stage_id,
		"target_id":          target_sit_id,
		"is_frontier":        is_frontier,
		"arrived":            arrived,
		"steps_taken":        steps,
		"turn_count":         int(explore_map.get("turn_count", 0)),
		"explored_count":     explored_cells.size(),
	})
	return "advanced"

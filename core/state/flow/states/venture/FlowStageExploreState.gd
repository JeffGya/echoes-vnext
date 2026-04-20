class_name FlowStageExploreState

extends State

const StageExploreModelScript := preload("res://core/realms/StageExploreModel.gd")  # V2-STAGE-001
const SituationModelScript    := preload("res://core/realms/SituationModel.gd")      # V2-INTEL-001

# V2-STAGE-001: Exploration stage map flow state.
#
# This state activates when the party enters a stage from the StageScreen.
# It drives a procedural exploration tilemap where hidden situations are
# scattered across the map and the party (as one guided group unit) moves
# toward them based on the active directive.
#
# The Keeper is a guide, not a commander — the party acts on directive intent,
# not direct player orders.
#
# Flow path:
#   flow.stage → cta.start → flow.stage_explore
#   stage.advance_turn   → move party, reveal check, engage situation
#   stage.return_home    → escape check → flow.stage_map (or return_failed flag)
#   stage.engage_situation (combat) → flow.encounter
#   all objectives found → flow.complete_stage

func _init(id: String = FlowStateIds.STAGE_EXPLORE) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# Lock the map on first entry so the layout persists across revisits.
	_lock_map_if_needed(flow_ctx, t)

	# Reset transient session state on every entry.
	# Map layout (situation positions, revealed flags) is preserved.
	# Position and pending engagement are NOT — the party always starts fresh.
	_reset_session_state(flow_ctx, t)

	flow_ctx.last_snapshot = build_snapshot(flow_ctx, t)


static func _reset_session_state(flow_ctx: FlowContext, t: int) -> void:
	var stage := _get_current_stage(flow_ctx)
	if stage.is_empty():
		return
	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	# Preserve map geometry and all situation intel across session entries.
	# Only session-transient fields are reset: party position, state, turn count, pending engagement.
	var width       := int(explore_map.get("width",  StageExploreModelScript.MIN_WIDTH))
	var height      := int(explore_map.get("height", StageExploreModelScript.MIN_HEIGHT))
	var obj_total   := int(explore_map.get("objectives_total", 0))
	var locked      := bool(explore_map.get("locked", false))

	# V2-INTEL-001: Carry forward revealed/resolved/intel_clues/intel_quality per situation.
	# Positions preserved; session-transient fields (party_pos, turn_count, etc.) wiped below.
	var raw_sits: Variant = explore_map.get("situations", [])
	var situations_in: Array = raw_sits if raw_sits is Array else []
	var situations_clean: Array = []
	for sit_v in situations_in:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		situations_clean.append(sit.duplicate(true))

	# V2-INTEL-001: Recompute objectives_found from persisted resolved flags.
	var obj_found := 0
	for s in situations_clean:
		if bool(s.get("is_objective", false)) and bool(s.get("resolved", false)):
			obj_found += 1

	# Rebuild explore_map — geometry + intel kept; session state zeroed.
	explore_map = {
		"width":               width,
		"height":              height,
		"party_pos":           { "col": 0, "row": height / 2 },
		"situations":          situations_clean,
		"locked":              locked,
		"party_state":         StageExploreModelScript.STATE_EXPLORING,
		"turn_count":          0,
		"objectives_found":    obj_found,
		"objectives_total":    obj_total,
		"last_situation_id":   "",
		"pending_situation_id": "",
	}

	stage["explore_map"] = explore_map
	_write_stage_back(flow_ctx, stage)
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason.is_empty():
		flow_ctx.save_request_reason = "stage.explore.session_reset"
	else:
		flow_ctx.save_request_reason += "|stage.explore.session_reset"

	if flow_ctx.logger != null:
		flow_ctx.logger.debug(t, "stage.explore.session_reset", "Explore map session state wiped on entry", {
			"stage_id": flow_ctx.stage_id,
		})

func exit(ctx: RefCounted, t: int) -> void:
	pass


# ────────────────────────────────────────────────────────────────────────────
# Map lock
# ────────────────────────────────────────────────────────────────────────────

# Sets explore_map.locked = true on first entry.
# No-op if already locked. Marks save_request so the lock persists.
static func _lock_map_if_needed(flow_ctx: FlowContext, t: int) -> void:
	var stage := _get_current_stage(flow_ctx)
	if stage.is_empty():
		return

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	if bool(explore_map.get("locked", false)):
		return  # Already locked — nothing to do

	# Lock it
	explore_map["locked"] = true
	stage["explore_map"] = explore_map

	# Write back into save_data
	_write_stage_back(flow_ctx, stage)

	flow_ctx.save_request = true
	if flow_ctx.save_request_reason.is_empty():
		flow_ctx.save_request_reason = "stage.explore.locked"
	else:
		flow_ctx.save_request_reason += "|stage.explore.locked"

	if flow_ctx.logger != null:
		flow_ctx.logger.info(t, "stage.explore.locked", "Stage explore map locked on first entry", {
			"stage_id": flow_ctx.stage_id,
			"realm_id": flow_ctx.realm_id,
		})


# ────────────────────────────────────────────────────────────────────────────
# Static snapshot builder
# ────────────────────────────────────────────────────────────────────────────

# Build the flow.stage_explore snapshot.
# Follows the same static builder pattern as FlowSummonState / FlowStageMapState.
static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	var stage := _get_current_stage(flow_ctx)

	# Guard: no active stage found
	if stage.is_empty():
		return {
			"type": FlowStateIds.STAGE_EXPLORE,
			"data": { "error": "no_active_stage" },
			"actions": {
				"nav.back": {
					"type":  "flow.go_state",
					"to":    FlowStateIds.STAGE_MAP,
					"label": "Back",
					"slot":  "nav.back",
				}
			},
			"meta": { "t": t },
		}

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}

	var party_state  := str(explore_map.get("party_state", StageExploreModelScript.STATE_EXPLORING))
	var turn_count   := int(explore_map.get("turn_count", 0))
	var obj_found    := int(explore_map.get("objectives_found", 0))
	var obj_total    := int(explore_map.get("objectives_total", 0))
	var party_pos_v: Variant = explore_map.get("party_pos", { "col": 0, "row": 0 })
	var party_pos: Dictionary = party_pos_v if party_pos_v is Dictionary else { "col": 0, "row": 0 }
	var map_width    := int(explore_map.get("width",  StageExploreModelScript.MIN_WIDTH))
	var map_height   := int(explore_map.get("height", StageExploreModelScript.MIN_HEIGHT))

	# Project situations — hidden ones show only position and "hidden" type
	var raw_sits: Variant = explore_map.get("situations", [])
	var situations_raw: Array = raw_sits if raw_sits is Array else []
	var situations: Array = []
	for sit_v in situations_raw:
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if bool(sit.get("revealed", false)):
			situations.append({
				"id":           str(sit.get("id", "")),
				"pos":          sit.get("pos", { "col": 0, "row": 0 }),
				"revealed":     true,
				"type":         str(sit.get("type", "")),
				"is_objective": bool(sit.get("is_objective", false)),
				"resolved":     bool(sit.get("resolved", false)),
			})
		else:
			situations.append({
				"id":       str(sit.get("id", "")),
				"pos":      sit.get("pos", { "col": 0, "row": 0 }),
				"revealed": false,
				"type":     "hidden",
				"is_objective": false,  # Never leak this while hidden
				"resolved": false,
			})

	# Pending situation — set by advance_turn, cleared by engage_situation
	var pending_sit_id := str(explore_map.get("pending_situation_id", ""))
	var pending_sit: Dictionary = {}
	if not pending_sit_id.is_empty():
		for sit_v2 in situations_raw:
			var sit2: Dictionary = sit_v2 if sit_v2 is Dictionary else {}
			if str(sit2.get("id", "")) == pending_sit_id and not bool(sit2.get("resolved", false)):
				pending_sit = sit2
				break

	var has_pending := not pending_sit.is_empty()

	# Build situation_pending payload for the UI engagement popup
	var situation_pending: Dictionary = {}
	if has_pending:
		var pend_revealed: bool = bool(pending_sit.get("revealed", false))
		# V2-INTEL-001: include intel_clues + enemy_estimate for previously scouted situations
		var sit_clues_v: Variant = pending_sit.get("intel_clues", [])
		var sit_clues: Array = sit_clues_v if sit_clues_v is Array else []
		var sit_quality := str(pending_sit.get("intel_quality", ""))
		var enemy_estimate := ""
		if str(pending_sit.get("type", "")) == SituationModelScript.TYPE_COMBAT and pend_revealed:
			match sit_quality:
				"precise": enemy_estimate = "You make out %d figures." % (int(pending_sit.get("seed", 0)) % 5 + 1)
				"rough":   enemy_estimate = "Hard to tell — could be a few, could be several."
		situation_pending = {
			"situation_id":   pending_sit_id,
			"revealed":       pend_revealed,
			"type":           str(pending_sit.get("type", "unknown")) if pend_revealed else "hidden",
			"is_objective":   bool(pending_sit.get("is_objective", false)) if pend_revealed else false,
			"intel_clues":    sit_clues,
			"intel_quality":  sit_quality,
			"enemy_estimate": enemy_estimate,
		}

	# Party preview (same shape as flow.stage and flow.stage_map)
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var active_ids_v: Variant = sanctum.get("active_party_ids", [])
	var active_ids: Array = active_ids_v if active_ids_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	var party_preview: Array = []
	for echo_id_v in active_ids:
		if party_preview.size() >= 5:
			break
		var echo_id := str(echo_id_v)
		for echo_v in roster:
			var echo: Dictionary = echo_v if echo_v is Dictionary else {}
			if str(echo.get("id", "")) == echo_id:
				party_preview.append({
					"name":           str(echo.get("name", "")),
					"rank":           int(echo.get("rank", 1)),
					"calling_origin": str(echo.get("calling_origin", "")),
				})
				break

	var is_exploring := party_state == StageExploreModelScript.STATE_EXPLORING

	var actions: Dictionary = {
		"cta.advance_turn": {
			"type":     "stage.advance_turn",
			"label":    "Advance",
			"slot":     "cta.advance_turn",
			"disabled": not is_exploring or has_pending,
		},
		"cta.return_home": {
			"type":     "stage.return_home",
			"label":    "Return Home",
			"slot":     "cta.return_home",
			"disabled": has_pending,
		},
		"nav.back": {
			"type":     "flow.go_state",
			"to":       FlowStateIds.STAGE_MAP,
			"label":    "Back",
			"slot":     "nav.back",
			"disabled": is_exploring,  # Party is in the field — can't teleport back
		},
	}

	if has_pending:
		actions["cta.engage_situation"] = {
			"type":         "stage.engage_situation",
			"situation_id": pending_sit_id,
			"label":        "Enter",
			"slot":         "cta.engage_situation",
		}

	return {
		"type": FlowStateIds.STAGE_EXPLORE,
		"data": {
			"stage_id":         flow_ctx.stage_id,
			"realm_id":         flow_ctx.realm_id,
			"map_width":        map_width,
			"map_height":       map_height,
			"party_pos":        party_pos,
			"party_state":      party_state,
			"turn_count":       turn_count,
			"objectives_found": obj_found,
			"objectives_total": obj_total,
			"situations":        situations,
			"situation_pending": situation_pending,
			"party_preview":     party_preview,
		},
		"actions": actions,
		"meta": { "t": t },
	}


# ────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────

# Returns the current stage dict from save_data for flow_ctx.stage_id.
# Returns {} on failure.
static func _get_current_stage(flow_ctx: FlowContext) -> Dictionary:
	var realms_v: Variant = flow_ctx.save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	var model_v: Variant = realms.get(flow_ctx.realm_id, {})
	var model: Dictionary = model_v if model_v is Dictionary else {}
	var stages_v: Variant = model.get("stages", [])
	var stages: Array = stages_v if stages_v is Array else []

	var stage_index := 0
	var sid := str(flow_ctx.stage_id)
	if sid.contains("."):
		var parts := sid.split(".")
		stage_index = int(parts[parts.size() - 1])

	for s_v in stages:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if int(s.get("index", -1)) == stage_index:
			return s

	return {}


# Write a mutated stage dict back into save_data (in-place mutation of the stages array entry).
static func _write_stage_back(flow_ctx: FlowContext, stage: Dictionary) -> void:
	var stage_index := int(stage.get("index", -1))
	if stage_index < 0:
		return
	var stages_v: Variant = flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("stages", [])
	if not (stages_v is Array):
		return
	var stages: Array = stages_v
	for i in range(stages.size()):
		var s_v: Variant = stages[i]
		if s_v is Dictionary and int((s_v as Dictionary).get("index", -1)) == stage_index:
			stages[i] = stage
			return

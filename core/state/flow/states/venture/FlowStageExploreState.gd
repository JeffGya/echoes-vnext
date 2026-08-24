class_name FlowStageExploreState

extends State

const StageExploreModelScript := preload("res://core/realms/StageExploreModel.gd")  # V2-STAGE-001
const SituationModelScript    := preload("res://core/realms/SituationModel.gd")      # V2-INTEL-001
const ObjectiveModelScript    := preload("res://core/realms/ObjectiveModel.gd")      # V2-STAGE-002
const EmotionServiceScript    := preload("res://core/emotion/EmotionService.gd")
const StageTerrainScript      := preload("res://core/realms/StageTerrain.gd")        # V2-STAGE-004-P2

# V2-STAGE-001: Exploration stage map flow state.
#
# This state activates when the party enters a stage from the stage preview flow.
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

	# V2-STAGE-004 P5 (playtest fix): capture whether this stage was already locked BEFORE
	# _lock_map_if_needed flips it. A false→true flip means this is the FIRST entry — the
	# narrative moment for Anansi's stage-entry whisper (event "stage_first_entry").
	var was_locked := _stage_was_locked(flow_ctx)

	# Lock the map on first entry so the layout persists across revisits.
	_lock_map_if_needed(flow_ctx, t)

	# Reset transient session state on every entry.
	# Map layout (situation positions, revealed flags) is preserved.
	# Position and pending engagement are NOT — the party always starts fresh.
	_reset_session_state(flow_ctx, t)

	# V2-STAGE-004 P5 (playtest fix): event-driven Anansi snippet on entry.
	# Runs AFTER _reset_session_state (which rebuilds explore_map with a clean travel_snippet)
	# and BEFORE build_snapshot so the whisper is present on the entry snapshot.
	_fire_entry_anansi_snippets(flow_ctx, was_locked, t)

	flow_ctx.last_snapshot = StageExploreSnapshotBuilder.build(flow_ctx, t)


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
	# V2-STAGE-004-P2: terrain dict is permanent geometry — must survive session reset.
	var terrain_v: Variant = explore_map.get("terrain", {})
	var terrain: Dictionary = terrain_v if terrain_v is Dictionary else {}
	# V2-STAGE-004 Phase 2.5: explored_cells is durable run-state (persists across return_home→re-entry
	# and across different parties). NOT wiped on session reset — preserved like terrain and revealed flags.
	var explored_cells_v: Variant = explore_map.get("explored_cells", {})
	var explored_cells: Dictionary = explored_cells_v if explored_cells_v is Dictionary else {}

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

	# V2-STAGE-002: preserve party_pos and turn_count if re-entering a locked stage
	# (returning from combat mid-run). Only reset them when the stage first locks
	# (first entry) so the party holds their position between encounters.
	var preserve_pos := locked  # locked=true means this is a re-entry, not a fresh start
	var preserved_pos_v: Variant = explore_map.get("party_pos", { "col": 0, "row": height / 2 })
	var preserved_pos: Dictionary = preserved_pos_v if preserved_pos_v is Dictionary else { "col": 0, "row": height / 2 }
	var preserved_turns := int(explore_map.get("turn_count", 0))

	# Rebuild explore_map — geometry + intel kept; pending engagement always cleared.
	explore_map = {
		"width":               width,
		"height":              height,
		"party_pos":           preserved_pos if preserve_pos else { "col": 0, "row": height / 2 },
		"situations":          situations_clean,
		"locked":              locked,
		"party_state":         StageExploreModelScript.STATE_EXPLORING,
		"turn_count":          preserved_turns if preserve_pos else 0,
		"objectives_found":    obj_found,
		"objectives_total":    obj_total,
		"last_situation_id":   "",
		"pending_situation_id": "",
		"pending_contact":      {},   # V2-STAGE-003: cleared on session reset; active contact persists in save
		"contact_responses":    [],   # V2-STAGE-003: cleared on session reset
		"terrain":             terrain, # V2-STAGE-004-P2: permanent geometry, never cleared on reset
		"last_traveled_path":  [],   # V2-STAGE-004-P2: presentation-only path (destinations only) for UI chained tween; cleared on session reset
		"last_traveled_origin": {},  # V2-COMBAT-002 slice 5: pre-advance cell for the path above; same lifecycle. Empty ⇒ projection falls back to party_pos
		"explored_cells":      explored_cells, # V2-STAGE-004 Phase 2.5: durable fog-of-war set; NOT a transient
		# V2-STAGE-004 P5 (playtest fix): one-shot guard so the "all objectives complete" Anansi
		# whisper fires at most once per run, even across return_home→re-entry. Durable like locked.
		"anansi_complete_fired": bool(explore_map.get("anansi_complete_fired", false)),
	}

	stage["explore_map"] = explore_map
	_write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.explore.session_reset")

	if flow_ctx.logger != null:
		flow_ctx.logger.debug(t, "stage.explore.session_reset", "Explore map session state wiped on entry", {
			"stage_id": flow_ctx.stage_id,
		})

	# V2-STAGE-004 Phase 2.5 (Finding 2): seed entry-fog BEFORE build_snapshot so the
	# first snapshot already shows the party's immediate surroundings unfogged.
	# Only runs when explored_cells is empty (first-ever entry); idempotent otherwise.
	# Resolve directive reveal_radius + precise_intel_bias from config (same pattern as build_snapshot).
	var _rss_dir_id := "directive.scout_carefully"  # fallback
	var _rss_sc_v: Variant = flow_ctx.save_data.get("stage_context", {})
	if _rss_sc_v is Dictionary:
		_rss_dir_id = str((_rss_sc_v as Dictionary).get("active_directive_id", _rss_dir_id))
	var _rss_dir: Dictionary = {}
	if flow_ctx.config_service != null:
		var _rss_bal_v: Variant = flow_ctx.config_service.get_balance()
		var _rss_bal: Dictionary = _rss_bal_v if _rss_bal_v is Dictionary else {}
		var _rss_bsd_v: Variant = _rss_bal.get("data", {})
		var _rss_bsd: Dictionary = _rss_bsd_v if _rss_bsd_v is Dictionary else {}
		var _rss_dirs_v: Variant = _rss_bsd.get("directives", {})
		var _rss_dirs: Dictionary = _rss_dirs_v if _rss_dirs_v is Dictionary else {}
		var _rss_de_v: Variant = _rss_dirs.get(_rss_dir_id, {})
		_rss_dir = _rss_de_v if _rss_de_v is Dictionary else {}
	var _rss_reveal_radius    := int(_rss_dir.get("reveal_radius", _rss_dir.get("passive_reveal_radius", 2)))
	var _rss_precise_bias     := int(_rss_dir.get("precise_intel_bias", 0))
	var _rss_realm_seed       := int(flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("seed", 0))
	var _rss_walkable         := StageTerrainScript.walkable_set(terrain)
	if _rss_walkable.is_empty():
		# Legacy: full rectangle
		for _rss_c in range(width):
			for _rss_r in range(height):
				_rss_walkable["%d,%d" % [_rss_c, _rss_r]] = true
	# Re-read explore_map from stage after write-back so mutations are on the live reference.
	var _rss_em_v2: Variant = stage.get("explore_map", {})
	var _rss_em2: Dictionary = _rss_em_v2 if _rss_em_v2 is Dictionary else {}
	seed_entry_fog_if_needed(
		_rss_em2,
		_rss_walkable,
		_rss_reveal_radius,
		_rss_precise_bias,
		_rss_realm_seed,
		flow_ctx.stage_id,
		flow_ctx.logger,
		t
	)
	stage["explore_map"] = _rss_em2
	_write_stage_back(flow_ctx, stage)

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

	flow_ctx.request_save("stage.explore.locked")

	if flow_ctx.logger != null:
		flow_ctx.logger.info(t, "stage.explore.locked", "Stage explore map locked on first entry", {
			"stage_id": flow_ctx.stage_id,
			"realm_id": flow_ctx.realm_id,
		})


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


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-002 helpers
# ────────────────────────────────────────────────────────────────────────────

# Project stage.objectives into the snapshot with display fields.
# reveal_hint is only shown when the objective's linked situation has been revealed.
static func _build_objective_entries(
	flow_ctx: FlowContext, stage: Dictionary, explore_map: Dictionary
) -> Array:
	var entries: Array = []
	var objs_v: Variant = stage.get("objectives", [])
	if not (objs_v is Array):
		return entries

	# Read stages config for label + reveal_hint
	var stages_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var bal_v: Variant = flow_ctx.config_service.get_balance()
		var bal: Dictionary = bal_v if bal_v is Dictionary else {}
		var bd_v: Variant = bal.get("data", {})
		var bd: Dictionary = bd_v if bd_v is Dictionary else {}
		var sc_v: Variant = bd.get("stages", {})
		var sc: Dictionary = sc_v if sc_v is Dictionary else {}
		var ot_v: Variant = sc.get("objective_types", {})
		stages_cfg = ot_v if ot_v is Dictionary else {}

	# Build a set of objective indices whose situations have been scouted/resolved.
	var scouted_obj_indices: Array = []
	var sits_v: Variant = explore_map.get("situations", [])
	if sits_v is Array:
		for sit_v in (sits_v as Array):
			var sit: Dictionary = sit_v if sit_v is Dictionary else {}
			if bool(sit.get("revealed", false)) or bool(sit.get("resolved", false)):
				var oi := int(sit.get("objective_index", -1))
				if oi >= 0 and oi not in scouted_obj_indices:
					scouted_obj_indices.append(oi)

	var objs: Array = objs_v
	for obj_v in objs:
		var obj: Dictionary = obj_v if obj_v is Dictionary else {}
		var obj_type := str(obj.get("type", ""))
		var obj_idx  := int(obj.get("index", -1))
		var is_completed := bool(obj.get("completed", false))
		var is_required  := bool(obj.get("required",  true))
		var type_cfg_v: Variant = stages_cfg.get(obj_type, {})
		var type_cfg: Dictionary = type_cfg_v if type_cfg_v is Dictionary else {}

		# Reveal hint shown only when the situation has been scouted or completed.
		var show_hint := is_completed or (obj_idx in scouted_obj_indices)
		entries.append({
			"type":        obj_type,
			"label":       str(type_cfg.get("label", obj_type.capitalize())),
			"reveal_hint": str(type_cfg.get("reveal_hint", "")) if show_hint else "",
			"completed":   is_completed,
			"required":    is_required,
		})
	return entries


# V2-STAGE-004 Phase 5: build the {id, label} choice list for the situation_pending
# UI popup. Reads data.stages.situation_resolution.<type>.choices from balance config —
# same config access pattern as _build_objective_entries. Only id + label are surfaced;
# fear/morale/turn_cost stay backend-side (consumed by SituationResolutionService.resolve_choice).
static func _build_situation_choices(flow_ctx: FlowContext, sit_type: String) -> Array:
	var out: Array = []
	if flow_ctx.config_service == null:
		return out
	var bal_v: Variant = flow_ctx.config_service.get_balance()
	var bal: Dictionary = bal_v if bal_v is Dictionary else {}
	var bd_v: Variant = bal.get("data", {})
	var bd: Dictionary = bd_v if bd_v is Dictionary else {}
	var sc_v: Variant = bd.get("stages", {})
	var sc: Dictionary = sc_v if sc_v is Dictionary else {}
	var res_map_v: Variant = sc.get("situation_resolution", {})
	var res_map: Dictionary = res_map_v if res_map_v is Dictionary else {}
	var type_cfg_v: Variant = res_map.get(sit_type, {})
	var type_cfg: Dictionary = type_cfg_v if type_cfg_v is Dictionary else {}
	var choices_v: Variant = type_cfg.get("choices", [])
	var choices: Array = choices_v if choices_v is Array else []
	for choice_v in choices:
		var choice: Dictionary = choice_v if choice_v is Dictionary else {}
		out.append({
			"id":    str(choice.get("id", "")),
			"label": str(choice.get("label_key", "")),
		})
	return out


# Build calling-action bonus action slots.
# Reads roster callings + party fear; returns slots dict + populates party_calling_actions array.
static func _build_calling_actions(
	flow_ctx: FlowContext, stage: Dictionary, party_calling_actions: Array
) -> Dictionary:
	var slots: Dictionary = {}
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	if party_ids.is_empty():
		return slots

	# Read stages config for calling_action_bonuses
	var calling_bonuses: Dictionary = {}
	var cautious_threshold := 50
	if flow_ctx.config_service != null:
		var bal_v: Variant = flow_ctx.config_service.get_balance()
		var bal: Dictionary = bal_v if bal_v is Dictionary else {}
		var bd_v: Variant = bal.get("data", {})
		var bd: Dictionary = bd_v if bd_v is Dictionary else {}
		var sc_v: Variant = bd.get("stages", {})
		var sc: Dictionary = sc_v if sc_v is Dictionary else {}
		var cb_v: Variant = sc.get("calling_action_bonuses", {})
		calling_bonuses = cb_v if cb_v is Dictionary else {}
		cautious_threshold = int(sc.get("cautious_advance_fear_threshold", 50))

	# Gather callings and average fear from active party echoes.
	var callings_in_party: Array = []
	var total_fear := 0
	var echo_count := 0
	var has_protect_objective := false

	for echo_v in roster:
		var echo: Dictionary = echo_v if echo_v is Dictionary else {}
		if str(echo.get("id", "")) not in party_ids:
			continue
		var calling := str(echo.get("calling", ""))
		var calling_origin := str(echo.get("calling_origin", ""))
		var effective_calling := calling if not calling.is_empty() else calling_origin
		if not effective_calling.is_empty() and effective_calling not in callings_in_party:
			callings_in_party.append(effective_calling)
		var emo_v: Variant = echo.get("emotion", {})
		var emo: Dictionary = emo_v if emo_v is Dictionary else {}
		total_fear += int(emo.get("fear_current", 0))
		echo_count += 1

	var avg_fear: int = total_fear / max(echo_count, 1)

	# Check for unresolved protect objective.
	var objs_v: Variant = stage.get("objectives", [])
	if objs_v is Array:
		for obj_v in (objs_v as Array):
			var obj: Dictionary = obj_v if obj_v is Dictionary else {}
			if str(obj.get("type", "")) == ObjectiveModelScript.TYPE_PROTECT \
					and not bool(obj.get("completed", false)):
				has_protect_objective = true
				break

	# ranger → reveal_adjacent
	if "ranger" in callings_in_party:
		var actions_v: Variant = calling_bonuses.get("ranger", [])
		if actions_v is Array and "reveal_adjacent" in (actions_v as Array):
			party_calling_actions.append({
				"calling":     "ranger",
				"action_type": "reveal_adjacent",
				"label":       "[Ranger] Scout Ahead",
				"slot":        "cta.calling_reveal_adjacent",
			})
			slots["cta.calling_reveal_adjacent"] = {
				"type":  "stage.calling_action",
				"action_type": "reveal_adjacent",
				"label": "[Ranger] Scout Ahead",
				"slot":  "cta.calling_reveal_adjacent",
			}

	# okofor → fortify_position (only when there is an unresolved protect objective)
	if "okofor" in callings_in_party and has_protect_objective:
		var actions_v: Variant = calling_bonuses.get("okofor", [])
		if actions_v is Array and "fortify_position" in (actions_v as Array):
			party_calling_actions.append({
				"calling":     "okofor",
				"action_type": "fortify_position",
				"label":       "[Okofor] Fortify Position",
				"slot":        "cta.calling_fortify_position",
			})
			slots["cta.calling_fortify_position"] = {
				"type":  "stage.calling_action",
				"action_type": "fortify_position",
				"label": "[Okofor] Fortify Position",
				"slot":  "cta.calling_fortify_position",
			}

	# aduro → inspire_push
	if "aduro" in callings_in_party:
		var actions_v: Variant = calling_bonuses.get("aduro", [])
		if actions_v is Array and "inspire_push" in (actions_v as Array):
			party_calling_actions.append({
				"calling":     "aduro",
				"action_type": "inspire_push",
				"label":       "[Aduro] Inspire Push",
				"slot":        "cta.calling_inspire_push",
			})
			slots["cta.calling_inspire_push"] = {
				"type":  "stage.calling_action",
				"action_type": "inspire_push",
				"label": "[Aduro] Inspire Push",
				"slot":  "cta.calling_inspire_push",
			}

	# Fear-based: cautious_advance (not calling-gated — any party with high avg fear).
	if avg_fear >= cautious_threshold:
		party_calling_actions.append({
			"calling":     "",
			"action_type": "cautious_advance",
			"label":       "Cautious Advance",
			"slot":        "cta.cautious_advance",
		})
		slots["cta.cautious_advance"] = {
			"type":  "stage.calling_action",
			"action_type": "cautious_advance",
			"label": "Cautious Advance",
			"slot":  "cta.cautious_advance",
		}

	return slots


# Check if the party's average fear exceeds the return threshold.
# Returns true when party_requesting_return should be surfaced in the snapshot.
static func _check_party_return_request(flow_ctx: FlowContext) -> bool:
	var threshold := 60
	if flow_ctx.config_service != null:
		var bal_v: Variant = flow_ctx.config_service.get_balance()
		var bal: Dictionary = bal_v if bal_v is Dictionary else {}
		var bd_v: Variant = bal.get("data", {})
		var bd: Dictionary = bd_v if bd_v is Dictionary else {}
		var sc_v: Variant = bd.get("stages", {})
		var sc: Dictionary = sc_v if sc_v is Dictionary else {}
		threshold = int(sc.get("party_return_fear_threshold", 60))

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	if party_ids.is_empty():
		return false

	var total_fear := 0
	var count := 0
	for echo_v in roster:
		var echo: Dictionary = echo_v if echo_v is Dictionary else {}
		if str(echo.get("id", "")) not in party_ids:
			continue
		var emo_v: Variant = echo.get("emotion", {})
		var emo: Dictionary = emo_v if emo_v is Dictionary else {}
		total_fear += int(emo.get("fear_current", 0))
		count += 1

	if count == 0:
		return false
	return (total_fear / count) > threshold


# ---------------------------------------------------------------------------
# Picker hint — short direction phrase derived from dominant_vector.
# Every echo has a unique vector even before a calling is confirmed, so this
# differentiates same-calling echoes and uncalled echoes individually.
# Used by contact_echo_bids entries so the UI can inform the player's choice.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# V2-STAGE-004-P2: traveled_path projection helper
# Projects explore_map["last_traveled_path"] into the snapshot as an Array of
# {col,row} dicts.  DESTINATIONS ONLY — the origin is NOT part of this array; it
# is carried separately by _project_traveled_origin (movement-contract
# path-excludes-origin rule).  Returns [] when the field is missing or empty
# (zero-step advances, and non-advance refreshes — contact turns, situation
# overlays, session resets).
# This is presentation-only data; it must never affect sim determinism.
# ---------------------------------------------------------------------------
static func _project_traveled_path(explore_map: Dictionary) -> Array:
	var raw_v: Variant = explore_map.get("last_traveled_path", [])
	var raw: Array = raw_v if raw_v is Array else []
	if raw.is_empty():
		return []
	var out: Array = []
	for cell_v in raw:
		var cell: Dictionary = cell_v if cell_v is Dictionary else {}
		out.append({ "col": int(cell.get("col", 0)), "row": int(cell.get("row", 0)) })
	return out


# ---------------------------------------------------------------------------
# V2-COMBAT-002 slice 5: traveled_origin projection helper
# Projects explore_map["last_traveled_origin"] — the pre-advance cell that
# `traveled_path` departs FROM — into the snapshot as a {col,row} dict.
# Falls back to the current party cell when the field is missing or empty, so
# the UI always has a valid first-segment anchor (zero-step advance, session
# reset, legacy saves repaired to {}).
# Presentation-only; never affects sim determinism.
# ---------------------------------------------------------------------------
static func _project_traveled_origin(explore_map: Dictionary) -> Dictionary:
	var raw_v: Variant = explore_map.get("last_traveled_origin", {})
	var raw: Dictionary = raw_v if raw_v is Dictionary else {}
	if raw.is_empty():
		var pos_v: Variant = explore_map.get("party_pos", {})
		raw = pos_v if pos_v is Dictionary else {}
	return { "col": int(raw.get("col", 0)), "row": int(raw.get("row", 0)) }


# ---------------------------------------------------------------------------
# V2-STAGE-004 Phase 5: travel_bark projection helper
# Projects explore_map["travel_bark"] into the snapshot as { actor_name, line }.
# Returns {} when the field is missing or empty (non-advance refreshes, or an
# advance turn where a snippet fired instead of a bark). Transient — cleared by
# session reset, same lifecycle as last_traveled_path.
# ---------------------------------------------------------------------------
static func _project_travel_bark(explore_map: Dictionary) -> Dictionary:
	var raw_v: Variant = explore_map.get("travel_bark", {})
	var raw: Dictionary = raw_v if raw_v is Dictionary else {}
	if raw.is_empty():
		return {}
	return {
		"actor_name": str(raw.get("actor_name", "")),
		"line":       str(raw.get("line", "")),
	}


static func _echo_picker_hint(bid_type: String, dominant_vector: String) -> String:
	if bid_type == "reactive":
		return "Speaking from fear"
	# Map dominant vector → readable direction phrase
	var direction := ""
	match dominant_vector:
		"vanguard":    direction = "Moves toward courage"
		"strategist":  direction = "Reads for direction"
		"skeptic":     direction = "Questions what they hear"
		"seeker":      direction = "Drawn to understanding"
		"devoted":     direction = "Holds back to listen"
		"pillar":      direction = "Lets the moment unfold"
		"mediator":    direction = "Looking for common ground"
		"protector":   direction = "Feels what others carry"
		"nurturer":    direction = "Starts from feeling"
		"opportunist": direction = "Looks for what can be given"
		_:             direction = "Direction still forming"
	if bid_type == "alignment":
		return "Natural fit — " + direction.to_lower()
	return direction


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-004 Phase 2.5: Entry-fog seed (Finding 2 fix)
# ────────────────────────────────────────────────────────────────────────────
#
# Seeds the entry-vicinity fog BEFORE the first snapshot is emitted, so the
# player's immediate surroundings are never fully fogged on initial entry.
#
# Idempotent: the empty-guard prevents re-seeding on subsequent entries
# (explored_cells is durable and survives session reset).
#
# Call sites:
#   (A) FlowStageExploreState._reset_session_state — seeds before build_snapshot
#   (B) FlowRuntime._handle_stage_advance_turn     — same guard, no-op when already seeded
#
# Parameters
#   explore_map        — mutable explore_map dict (in-place: writes explored_cells + situations)
#   walkable           — pre-built walkable set from StageTerrain.walkable_set (or full rect)
#   reveal_radius      — neighbourhood radius to seed (from active directive)
#   precise_intel_bias — 0..100 intel quality bias (from directive)
#   realm_seed         — int seed for RNG keying (from save_data.realms[realm_id].seed)
#   stage_id           — String id used in logger (flow_ctx.stage_id)
#   logger             — StructuredLogger (may be null)
#   t                  — sim tick

static func seed_entry_fog_if_needed(
		explore_map:        Dictionary,
		walkable:           Dictionary,
		reveal_radius:      int,
		precise_intel_bias: int,
		realm_seed:         int,
		stage_id:           String,
		logger,                       # StructuredLogger (untyped to avoid hard dep from state script)
		t:                  int
) -> void:
	# Guard: already seeded on a prior entry — explored_cells is durable.
	var ec_v: Variant = explore_map.get("explored_cells", {})
	var explored_cells: Dictionary = ec_v if ec_v is Dictionary else {}
	if not explored_cells.is_empty():
		return

	# Seed the entry-cell neighbourhood.
	var entry_pos_v: Variant = explore_map.get("party_pos", { "col": 0, "row": 0 })
	var entry_pos: Dictionary = entry_pos_v if entry_pos_v is Dictionary else { "col": 0, "row": 0 }
	var seed_cells: Array = StageTerrainScript.cells_within_radius(entry_pos, reveal_radius, walkable)
	for sc_v in seed_cells:
		var sc: Dictionary = sc_v if sc_v is Dictionary else {}
		explored_cells["%d,%d" % [int(sc.get("col", 0)), int(sc.get("row", 0))]] = true
	explore_map["explored_cells"] = explored_cells

	if logger != null:
		logger.debug(t, "stage.explore.fog_seed", "explored_cells seeded on first entry", {
			"stage_id":      stage_id,
			"seeded_count":  explored_cells.size(),
			"reveal_radius": reveal_radius,
		})

	# Tile-based discovery: reveal any entry-area situations now in explored_cells.
	# Uses the same invariant as the advance-turn path: tile in explored_cells ⟹ situation revealed.
	_reveal_explored_situations_static(explore_map, explored_cells, precise_intel_bias, realm_seed, stage_id, logger, t)


# Tile-based discovery sweep (static companion to FlowRuntime._reveal_explored_situations).
# Reveals every unresolved situation whose cell key is present in explored_cells.
# Idempotent: skips already-revealed situations.
static func _reveal_explored_situations_static(
		explore_map:        Dictionary,
		explored_cells:     Dictionary,
		precise_intel_bias: int,
		realm_seed:         int,
		stage_id:           String,
		logger,
		t:                  int
) -> void:
	var sits_v: Variant = explore_map.get("situations", [])
	var sits: Array = sits_v if sits_v is Array else []
	for sit_v in sits:
		if not (sit_v is Dictionary):
			continue
		var sit: Dictionary = sit_v
		if bool(sit.get("resolved", false)):
			continue
		if bool(sit.get("revealed", false)):
			continue
		var sp_v: Variant = sit.get("pos", { "col": 0, "row": 0 })
		var sp: Dictionary = sp_v if sp_v is Dictionary else { "col": 0, "row": 0 }
		var cell_key: String = "%d,%d" % [int(sp.get("col", 0)), int(sp.get("row", 0))]
		if explored_cells.has(cell_key):
			_reveal_situation_static(explore_map, sit, precise_intel_bias, realm_seed, stage_id, logger, t)
			# Re-read situations after mutation
			var updated_v: Variant = explore_map.get("situations", [])
			sits = updated_v if updated_v is Array else sits


# Single-situation reveal (static companion to FlowRuntime._reveal_situation).
# RNG key: "stage.reveal.<sit_id>" — append-only, unchanged from advance path.
# Writes revealed=true, intel_clues, intel_quality onto the situation in explore_map.
static func _reveal_situation_static(
		explore_map:        Dictionary,
		sit:                Dictionary,
		precise_intel_bias: int,
		realm_seed:         int,
		stage_id:           String,
		logger,
		t:                  int
) -> void:
	if bool(sit.get("revealed", false)):
		return
	var sit_id := str(sit.get("id", ""))
	var rng := CampaignSeed.get_rng_from(realm_seed, "stage.reveal.%s" % sit_id)
	var bias_roll := rng.randi_range(0, 100)
	var sits_v: Variant = explore_map.get("situations", [])
	var sits: Array = sits_v if sits_v is Array else []
	for _ri in range(sits.size()):
		var _rs_v: Variant = sits[_ri]
		if not (_rs_v is Dictionary):
			continue
		var _rs: Dictionary = _rs_v
		if str(_rs.get("id", "")) != sit_id:
			continue
		_rs["revealed"] = true
		var clues_v: Variant = _rs.get("intel_clues", [])
		var clues: Array = clues_v if clues_v is Array else []
		if clues.is_empty():
			clues.append(_intel_clue_for_type_static(str(_rs.get("type", ""))))
		_rs["intel_clues"]    = clues
		_rs["intel_quality"]  = "precise" if bias_roll < precise_intel_bias else "rough"
		sits[_ri] = _rs
		break
	explore_map["situations"] = sits
	if logger != null:
		logger.debug(t, "stage.situation.revealed", "Situation revealed by entry-fog seed", {
			"stage_id":     stage_id,
			"situation_id": sit_id,
		})


# Intel clue text by situation type (mirrors FlowRuntime._intel_clue_for_type).
# Kept in sync manually; type constants are stable (determinism rule: no reorder).
static func _intel_clue_for_type_static(sit_type: String) -> String:
	match sit_type:
		SituationModelScript.TYPE_COMBAT:           return "Tracks in the earth. Something passed through here with intent."
		SituationModelScript.TYPE_NPC:              return "Warmth lingers — a firepit, a scent, the sense of someone waiting."
		SituationModelScript.TYPE_LOOT:             return "A cache left behind. The kind made in haste, not ceremony."
		SituationModelScript.TYPE_MONEY:            return "A ritual trace — coins or marks, left as offering or warning."
		ObjectiveModelScript.TYPE_RECOVER:          return "Something was taken here. The absence is palpable — a hollow where something should be."
		ObjectiveModelScript.TYPE_PROTECT:          return "A fragile presence holds out nearby. It will not endure without help."
		ObjectiveModelScript.TYPE_ENDURE:           return "The pressure does not stop. Whatever is here does not yield easily."
		ObjectiveModelScript.TYPE_PURSUE:           return "Movement — recent. Something is moving through this space with purpose."
		SituationModelScript.TYPE_OMEN:             return "A wrongness in the air — birds gone quiet, a chill with no wind."
		SituationModelScript.TYPE_OBSTACLE:         return "The way narrows and snags. Whatever lies ahead will not yield easily to a careless step."
		SituationModelScript.TYPE_RITUAL:           return "Worn ground and old ash. Hands have tended this place, again and again."
		SituationModelScript.TYPE_STRUCTURE:        return "Walls, deliberate and standing. Someone raised this — and may yet return to it."
		_:                                          return "Something is present here."


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-004 Phase 5 (playtest fix): event-driven Anansi travel snippets
# ────────────────────────────────────────────────────────────────────────────
#
# Anansi is NOT a constant narrator. He interferes incidentally, at narrative
# moments, and must feel impactful when he does. His snippets are therefore
# EVENT-DRIVEN — never a cadence tied to advance parity. Four moments fire a
# snippet (each gated by data.stages.anansi_snippet_events so Jeff can tune
# presence without code):
#   (a) stage_first_entry   — the party first locks/enters a stage        (here)
#   (b) objective_revealed  — an objective situation is revealed on advance (FlowRuntime)
#   (c) objectives_complete — all required objectives are done             (here)
#   (d) return_home_failed  — a failed return-home escape roll             (FlowRuntime)
#
# The pool (data/stages/anansi_travel_snippets.json) is moment-agnostic today:
# every event draws the shared "travel" pool. `fire_anansi_snippet` centralises
# the deterministic line pick + event gate so both this state (a/c) and
# FlowRuntime (b/d) share one implementation.

# True when the current stage's explore_map is already locked (i.e. NOT first entry).
static func _stage_was_locked(flow_ctx: FlowContext) -> bool:
	var stage := _get_current_stage(flow_ctx)
	if stage.is_empty():
		return false
	var m_v: Variant = stage.get("explore_map", {})
	var m: Dictionary = m_v if m_v is Dictionary else {}
	return bool(m.get("locked", false))


# Fires the entry-time Anansi snippet (event a or c) onto the live explore_map.
# Priority: "all required objectives complete" (a completed-stage re-entry) outranks
# a plain first entry. Guarded so completion fires at most once per run.
static func _fire_entry_anansi_snippets(flow_ctx: FlowContext, was_locked: bool, t: int) -> void:
	var stage := _get_current_stage(flow_ctx)
	if stage.is_empty():
		return
	var m_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = m_v if m_v is Dictionary else {}
	var enabled := _anansi_events_cfg(flow_ctx)

	var event_key := ""
	var mark_complete_fired := false
	if _all_required_objectives_complete(stage, explore_map):
		if not bool(explore_map.get("anansi_complete_fired", false)):
			event_key = "objectives_complete"
			mark_complete_fired = true
	elif not was_locked:
		event_key = "stage_first_entry"

	if event_key.is_empty():
		return

	fire_anansi_snippet(explore_map, event_key, enabled, t, flow_ctx.logger, flow_ctx.stage_id)
	if mark_complete_fired:
		explore_map["anansi_complete_fired"] = true
	stage["explore_map"] = explore_map
	_write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.anansi_snippet")


# True when every REQUIRED stage objective is completed (mirrors build_snapshot's
# objectives_remaining logic). Returns false when there are no objectives.
static func _all_required_objectives_complete(stage: Dictionary, explore_map: Dictionary) -> bool:
	if int(explore_map.get("objectives_total", 0)) <= 0:
		return false
	var objs_v: Variant = stage.get("objectives", [])
	var objs: Array = objs_v if objs_v is Array else []
	if objs.is_empty():
		return false
	for o_v in objs:
		var o: Dictionary = o_v if o_v is Dictionary else {}
		if bool(o.get("required", true)) and not bool(o.get("completed", false)):
			return false
	return true


# Reads data.stages.anansi_snippet_events from balance config (defensive: {} when absent).
static func _anansi_events_cfg(flow_ctx: FlowContext) -> Dictionary:
	if flow_ctx.config_service == null:
		return {}
	var bal_v: Variant = flow_ctx.config_service.get_balance()
	var bal: Dictionary = bal_v if bal_v is Dictionary else {}
	var bd_v: Variant = bal.get("data", {})
	var bd: Dictionary = bd_v if bd_v is Dictionary else {}
	var sc_v: Variant = bd.get("stages", {})
	var sc: Dictionary = sc_v if sc_v is Dictionary else {}
	var ev_v: Variant = sc.get("anansi_snippet_events", {})
	return ev_v if ev_v is Dictionary else {}


# Central deterministic Anansi snippet selection, shared by this state and FlowRuntime.
# Writes explore_map["travel_snippet"] to a deterministic line for `event_key`, gated by
# `enabled_events` (an event fires unless explicitly set false). No-op (leaves the field
# untouched) when the event is disabled or the pool is empty.
static func fire_anansi_snippet(
		explore_map: Dictionary,
		event_key: String,
		enabled_events: Dictionary,
		t: int,
		logger,
		stage_id: String) -> void:
	# Defensive event gate — fire unless explicitly disabled in config.
	if not bool(enabled_events.get(event_key, true)):
		return
	var pool := _load_anansi_snippet_pool(event_key)
	if pool.is_empty():
		return
	# Deterministic line pick (no RNG) — same convention as the legacy snippet path.
	var vk: int = posmod(t, pool.size())
	var line := str(pool[vk])
	if line.is_empty():
		return
	explore_map["travel_snippet"] = line
	if logger != null:
		logger.debug(t, "stage.anansi_snippet", "Anansi snippet fired", {
			"event":    event_key,
			"stage_id": stage_id,
		})


# Loads the snippet pool for an event. Per-event-pool seam: every event currently maps to
# the moment-agnostic "travel" pool — to give an event its own authored pool later, map
# event_key → pool key here and add that key to anansi_travel_snippets.json.
static func _load_anansi_snippet_pool(_event_key: String) -> Array:
	var pool_key := "travel"   # per-event-pool seam (see above)
	var path := "res://data/stages/anansi_travel_snippets.json"
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return []
	var pool_v: Variant = (parsed as Dictionary).get(pool_key, [])
	return pool_v if pool_v is Array else []



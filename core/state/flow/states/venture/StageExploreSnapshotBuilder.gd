class_name StageExploreSnapshotBuilder

extends RefCounted

const StageExploreModelScript := preload("res://core/realms/StageExploreModel.gd")  # V2-STAGE-001
const SituationModelScript    := preload("res://core/realms/SituationModel.gd")      # V2-INTEL-001
const EmotionServiceScript    := preload("res://core/emotion/EmotionService.gd")
const StageTerrainScript      := preload("res://core/realms/StageTerrain.gd")        # V2-STAGE-004-P2

## V2-INFRA-003 Phase 5 Slice B.
##
## Pure projection for the flow.stage_explore snapshot, extracted verbatim from
## FlowStageExploreState.build_snapshot(). Reads `flow_ctx` and `flow_ctx.save_data` only —
## writes nothing. No save_data mutation, no FlowContext field mutation, no request_save(),
## no service constructed (in particular never SanctumService.new(), whose SanctumState
## constructor can write to save_data via _ensure_sanctum_dict_exists()).
##
## The purity claim was re-verified before the move: inside the 452 moved lines the only
## assignments through a subscript are `actions["cta.advance_turn"]["disabled"] = true` and
## the matching `actions["cta.return_home"]["disabled"] = true`, both into the locally built
## `actions` dictionary. There are no `flow_ctx.<field> =`, no `explore_map[...] =`, no
## `stage[...] =`, no `save_data[...] =`, no `.new(` and no `_write_stage_back()` calls.
##
## FOLLOWS THE SanctumSnapshotBuilder PRECEDENT EXACTLY, including its split: only the
## build function moved. The projection helpers it calls (_get_current_stage,
## _build_objective_entries, _build_situation_choices, _build_calling_actions,
## _check_party_return_request, _project_traveled_path, _project_traveled_origin,
## _project_travel_bark, _echo_picker_hint) stay on FlowStageExploreState and are called
## across the file boundary — the same way SanctumSnapshotBuilder calls
## FlowSanctumState._build_echo_detail_roster() and _build_active_effects(). Several of
## those helpers have callers outside this builder (_get_current_stage has ~60 across core/
## and tests/; _project_traveled_origin is asserted directly by SaveIntegrityTests), so
## moving them would have been a second, unrelated refactor.
##
## FlowStageExploreState no longer declares build_snapshot() at all (mirroring
## FlowSanctumState, which likewise kept no delegating static). Every call site — enter(),
## eleven in FlowRuntime, and the test suites — now calls StageExploreSnapshotBuilder.build()
## directly. A delegating static left behind would have proved the extraction did not happen.
##
## Lifecycle work — _lock_map_if_needed(), _reset_session_state(), _fire_entry_anansi_snippets()
## and any other save_data repair — belongs in FlowStageExploreState.enter() BEFORE this is
## called. Never add lifecycle/repair work here.
# Build the flow.stage_explore snapshot.
# Follows the same static builder pattern as FlowSummonState / FlowStageMapState.
static func build(flow_ctx: FlowContext, t: int) -> Dictionary:
	var stage := FlowStageExploreState._get_current_stage(flow_ctx)

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

	# V2-STAGE-004 Phase 2.5 — fog-of-war projection: emit ONLY discovered (revealed==true)
	# situations. Undiscovered situations are absent entirely — true fog (UI cannot draw what
	# it isn't given). Hidden placeholders dropped; the snapshot is the authoritative contract.
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
				# V2-STAGE-004 Phase 2.5 (pass-fix): passed nodes remain visible on the map
				# but the UI can style them differently (e.g. dimmed icon).
				"passed":       bool(sit.get("passed", false)),
			})
		# Undiscovered situations: no entry emitted (true fog of war)

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

	# V2-STAGE-003: pending contact state
	var pending_contact_v: Variant = explore_map.get("pending_contact", {})
	var pending_contact: Dictionary = pending_contact_v if pending_contact_v is Dictionary else {}
	var has_contact := not pending_contact.is_empty()
	var contact_pending: Dictionary = {}
	var contact_responses_out: Array = []
	var contact_echo_bids: Array = []

	if has_contact:
		var contact_cfg_v: Variant = {}
		if flow_ctx.config_service != null:
			var _bal_v: Variant = flow_ctx.config_service.get_balance()
			var _bal: Dictionary = _bal_v if _bal_v is Dictionary else {}
			var _bd_v: Variant = _bal.get("data", {})
			var _bd: Dictionary = _bd_v if _bd_v is Dictionary else {}
			contact_cfg_v = _bd.get("contact", {})
		var contact_cfg: Dictionary = contact_cfg_v if contact_cfg_v is Dictionary else {}
		var roles_cfg_v: Variant = contact_cfg.get("roles", {})
		var roles_cfg: Dictionary = roles_cfg_v if roles_cfg_v is Dictionary else {}
		var contact_role := str(pending_contact.get("role", ""))
		var role_cfg_v: Variant = roles_cfg.get(contact_role, {})
		var role_cfg: Dictionary = role_cfg_v if role_cfg_v is Dictionary else {}

		contact_pending = {
			"role":              contact_role,
			"role_label":        str(role_cfg.get("label", contact_role.capitalize())),
			"name":              str(pending_contact.get("name", "")),
			"virtue_primary":    str(pending_contact.get("virtue_primary",   "")),
			"virtue_secondary":  str(pending_contact.get("virtue_secondary", "")),
			"disposition":       str(pending_contact.get("disposition", "")),
			"fear":              int(pending_contact.get("fear",         50)),
			"morale":            int(pending_contact.get("morale",       50)),
			"turn_current":      int(pending_contact.get("turn_current", 0)),
			"turn_count":        int(pending_contact.get("turn_count",   2)),
			"state":             str(pending_contact.get("state", "pending")),
			"npc_line":          str(pending_contact.get("npc_line",         "")),
			"npc_reaction_word": str(pending_contact.get("npc_reaction_word", "")),
			# V2-PROG-012 playtest fix: winning-turn Storyweight feedback for the speaking Echo.
			# Reset to 0/"" every turn in FlowRuntime._handle_stage_speak_response — never stale.
			"last_turn_storyweight_gain": int(pending_contact.get("last_turn_storyweight_gain", 0)),
			"last_turn_speaker_name":     str(pending_contact.get("last_turn_speaker_name",     "")),
		}

		# Contact responses (pre-generated by FlowRuntime)
		var cr_v: Variant = explore_map.get("contact_responses", [])
		var cr: Array = cr_v if cr_v is Array else []
		for resp_v in cr:
			var resp: Dictionary = resp_v if resp_v is Dictionary else {}
			contact_responses_out.append({
				"echo_id":             str(resp.get("echo_id",             "")),
				"echo_name":           str(resp.get("echo_name",           "")),
				"calling":             str(resp.get("calling",             "")),
				"response_text":       str(resp.get("response_text",       "")),
				"resonance_score":     float(resp.get("resonance_score",   0.5)),
				"emotional_status":   str(resp.get("emotional_status", "grounded")),
				"stat_texture":        str(resp.get("stat_texture",        "thoughtful")),
				"is_calling_aligned":  bool(resp.get("is_calling_aligned", false)),
				"bid_type":            str(resp.get("bid_type",            "")),
			})

		# Echo bids — build from party echoes
		var sanctum_bids_v: Variant = flow_ctx.save_data.get("sanctum", {})
		var sanctum_bids: Dictionary = sanctum_bids_v if sanctum_bids_v is Dictionary else {}
		var bid_party_ids_v: Variant = sanctum_bids.get("active_party_ids", [])
		var bid_party_ids: Array = bid_party_ids_v if bid_party_ids_v is Array else []
		var bid_roster_v: Variant = sanctum_bids.get("roster", [])
		var bid_roster: Array = bid_roster_v if bid_roster_v is Array else []
		for be_v in bid_roster:
			var be: Dictionary = be_v if be_v is Dictionary else {}
			if str(be.get("id", "")) not in bid_party_ids:
				continue
			var be_calling := str(be.get("calling", ""))
			if be_calling.is_empty():
				be_calling = str(be.get("calling_origin", ""))
			var emo_v2: Variant = be.get("emotion", {})
			var emo2: Dictionary = emo_v2 if emo_v2 is Dictionary else {}
			var fear2   := int(emo2.get("fear_current",   0))
			var morale2 := int(emo2.get("morale_current", 50))
			var emotional_status2 := EmotionServiceScript.get_emotional_status(morale2, fear2)
			# Determine bid type: alignment or reactive
			var bid_type := ""
			if fear2 >= 60:
				bid_type = "reactive"
			else:
				match contact_role:
					"charge":         if be_calling in ["okofor", "onyamesu"]: bid_type = "alignment"
					"witness":        if be_calling in ["okomfo", "kra_soro"]: bid_type = "alignment"
					"guide":          if be_calling in ["okomfo", "kra_soro", "sum_okwanfo"]: bid_type = "alignment"
					"claimant":       if be_calling in ["aduro", "okomfo"]: bid_type = "alignment"
					"temporary_ally": if be_calling in ["aduro", "okofor"]: bid_type = "alignment"
			# dominant_vector is the unique differentiator — two echoes with the same calling
			# but different vectors lean in meaningfully different directions.
			var be_dominant_vector := str(be.get("dominant_vector", ""))
			# Generate hint from dominant_vector (not calling) so each echo reads differently.
			var hint := FlowStageExploreState._echo_picker_hint(bid_type, be_dominant_vector)
			# Always include every party echo — bid_type may be empty for neutral echoes.
			# The UI shows alignment/reactive badges when present, plain chip when absent.
			contact_echo_bids.append({
				"echo_id":          str(be.get("id",   "")),
				"echo_name":        str(be.get("name", "")),
				"calling":          be_calling,
				"dominant_vector":  be_dominant_vector,
				"emotional_status": emotional_status2,
				"bid_type":         bid_type,
				"bid_label":        "Wants to help" if bid_type == "alignment" else ("Reacting from fear" if bid_type == "reactive" else ""),
				"hint":             hint,
			})

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
		# V2-STAGE-004 Phase 5: authored choice list for obstacle/structure situations.
		# Empty for all other types — only these two route to the "choice" panel_kind
		# (see SituationResolutionService + data.stages.situation_resolution config).
		var pend_type := str(pending_sit.get("type", ""))
		var pend_choices: Array = []
		if pend_revealed and (pend_type == SituationModelScript.TYPE_OBSTACLE or pend_type == SituationModelScript.TYPE_STRUCTURE):
			pend_choices = FlowStageExploreState._build_situation_choices(flow_ctx, pend_type)
		situation_pending = {
			"situation_id":   pending_sit_id,
			"revealed":       pend_revealed,
			"type":           str(pending_sit.get("type", "unknown")) if pend_revealed else "hidden",
			"is_objective":   bool(pending_sit.get("is_objective", false)) if pend_revealed else false,
			"intel_clues":    sit_clues,
			"choices":        pend_choices,
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
				# V2-STAGE-004 Phase 5: mirror the contact-bids emotional_status derivation
				# (see contact_echo_bids above) -- defaults to "grounded" defensively.
				var pp_emo_v: Variant = echo.get("emotion", {})
				var pp_emo: Dictionary = pp_emo_v if pp_emo_v is Dictionary else {}
				var pp_fear   := int(pp_emo.get("fear_current",   0))
				var pp_morale := int(pp_emo.get("morale_current", 50))
				var pp_emotional_status := EmotionServiceScript.get_emotional_status(pp_morale, pp_fear)
				party_preview.append({
					"name":             str(echo.get("name", "")),
					"rank":             int(echo.get("rank", 1)),
					"calling_origin":   str(echo.get("calling_origin", "")),
					"emotional_status": pp_emotional_status,
				})
				break

	var is_exploring := party_state == StageExploreModelScript.STATE_EXPLORING

	# V2-STAGE-002: project stage objectives with label, reveal_hint, completed, required.
	var objectives: Array = FlowStageExploreState._build_objective_entries(flow_ctx, stage, explore_map)
	var objectives_remaining := 0
	for _obj_entry_v in objectives:
		var _oe: Dictionary = _obj_entry_v if _obj_entry_v is Dictionary else {}
		if bool(_oe.get("required", true)) and not bool(_oe.get("completed", false)):
			objectives_remaining += 1

	# V2-STAGE-002: calling-action bonuses + fear-based actions.
	var party_calling_actions: Array = []
	var calling_action_slots: Dictionary = FlowStageExploreState._build_calling_actions(flow_ctx, stage, party_calling_actions)

	# V2-STAGE-002: party return request — fires when avg party fear > threshold.
	var party_requesting_return := FlowStageExploreState._check_party_return_request(flow_ctx)

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

	# V2-STAGE-003: when contact conversation is active, override normal explore actions
	if has_contact:
		# Disable advance_turn and return_home during conversation
		actions["cta.advance_turn"]["disabled"] = true
		actions["cta.return_home"]["disabled"]   = true
		# disengage_contact always present
		actions["cta.disengage_contact"] = {
			"type":  "stage.disengage_contact",
			"label": "Disengage",
			"slot":  "cta.disengage_contact",
		}
		# speak_response slots — one per response option
		for _cr_v in contact_responses_out:
			var _cr: Dictionary = _cr_v if _cr_v is Dictionary else {}
			var _cr_eid := str(_cr.get("echo_id", ""))
			if not _cr_eid.is_empty():
				actions["cta.speak_response." + _cr_eid] = {
					"type":    "stage.speak_response",
					"echo_id": _cr_eid,
					"label":   str(_cr.get("echo_name", _cr_eid)),
					"slot":    "cta.speak_response." + _cr_eid,
				}
		# consult_echoes slot: show when party > 3 and responses not yet generated.
		# Include all party IDs in the action — handler trims to max 3 automatically.
		var _snap_party_ids_v: Variant = flow_ctx.save_data.get("sanctum", {}).get("active_party_ids", []) \
			if flow_ctx.save_data.get("sanctum", null) is Dictionary else []
		var _snap_party_ids: Array = _snap_party_ids_v if _snap_party_ids_v is Array else []
		var _snap_party_count := _snap_party_ids.size()
		if contact_responses_out.is_empty() and _snap_party_count > 3:
			actions["cta.consult_echoes"] = {
				"type":     "stage.consult_echoes",
				"echo_ids": _snap_party_ids,
				"label":    "Hear Them Out",
				"slot":     "cta.consult_echoes",
			}

	if has_pending:
		actions["cta.engage_situation"] = {
			"type":         "stage.engage_situation",
			"situation_id": pending_sit_id,
			"label":        "Enter",
			"slot":         "cta.engage_situation",
		}
		# V2-STAGE-002: player can dismiss the engagement popup without resolving the situation.
		actions["cta.ignore_situation"] = {
			"type":         "stage.ignore_situation",
			"situation_id": pending_sit_id,
			"label":        "Ignore",
			"slot":         "cta.ignore_situation",
		}

	# V2-STAGE-002: stage-complete gate — all required objectives done AND every objective
	# situation actually reached.
	#
	# The `objectives_found >= obj_total` term is the fix for D94. `objectives_remaining` counts
	# only stage.objectives entries flagged `required`, and RealmGenerator writes the boss
	# objective `required = false` unconditionally (RealmGenerator.gd:152) while a `pursue`
	# pre-boss is optional too (:146). realm.01 generates exactly two objectives, so about 14%
	# of its stages carry NO required objective and this gate opened the moment nothing was
	# pending — on entry, or on the first dismissal of an engagement popup. The explore map
	# already tracked the honest pair, `objectives_found` against `objectives_total`, and the
	# gate ignored it.
	#
	# Harmless until Phase 8A (091bcfd) moved the stage settlement into
	# VentureController.handle_complete_stage and paid the no-encounter path as `cleared`
	# (the D05 fix). From then on, walking one step past a situation paid a full stage reward.
	#
	# A stage whose objectives are all optional stays completable: once the frontier is
	# exhausted, ActiveStageService.find_explore_target Tier 4 re-offers a passed objective,
	# and situation_blocks_step re-prompts on that deliberate re-target.
	var objectives_reached := int(explore_map.get("objectives_found", 0)) >= obj_total
	if is_exploring and not has_pending and objectives_remaining == 0 and obj_total > 0 \
			and objectives_reached:
		actions["cta.proceed_to_stage_map"] = {
			"type":  "flow.complete_stage",
			"label": "Stage Complete",
			"slot":  "cta.proceed_to_stage_map",
		}

	# V2-STAGE-002: party return request notification action (separate from player-initiated).
	if party_requesting_return and is_exploring:
		actions["cta.party_return_request"] = {
			"type":  "ui.show_return_confirm",
			"label": "Party Requests Return",
			"slot":  "cta.party_return_request",
		}

	# Add calling-action bonus slots to actions dict.
	for _slot_key in calling_action_slots:
		actions[_slot_key] = calling_action_slots[_slot_key]

	# V2-STAGE-004-P2: resolve directive fields for snapshot projection.
	# Reads active_directive_id from save_data → looks up directive dict from balance config.
	# Mirrors DirectiveService.get_active_directive() without needing the service instance.
	var _sc_snap_v: Variant = flow_ctx.save_data.get("stage_context", {})
	var _sc_snap: Dictionary = _sc_snap_v if _sc_snap_v is Dictionary else {}
	var _dir_id_snap := str(_sc_snap.get("active_directive_id", "directive.scout_carefully"))
	var _dir_snap: Dictionary = {}
	if flow_ctx.config_service != null:
		var _bal_snap_v: Variant = flow_ctx.config_service.get_balance()
		var _bal_snap: Dictionary = _bal_snap_v if _bal_snap_v is Dictionary else {}
		var _bsd_v: Variant = _bal_snap.get("data", {})
		var _bsd: Dictionary = _bsd_v if _bsd_v is Dictionary else {}
		var _bdd_v: Variant = _bsd.get("directives", {})
		var _bdd: Dictionary = _bdd_v if _bdd_v is Dictionary else {}
		var _de_v: Variant = _bdd.get(_dir_id_snap, {})
		_dir_snap = _de_v if _de_v is Dictionary else {}
	var _step_budget_snap := int(_dir_snap.get("step_budget", DirectiveService.DEFAULT_STEP_BUDGET))

	# V2-STAGE-004 Phase 5: composite directive field — bundles the active directive's
	# id + label so the UI does not need to separately resolve config to show it.
	# All existing individual directive-derived fields (step_budget etc.) are unchanged.
	var _directive_snap: Dictionary = {
		"id":    _dir_id_snap,
		"label": str(_dir_snap.get("label", "")),
	}

	# steps_to_target: BFS distance from party to the in-transit target situation.
	var _steps_to_target := 0
	var _target_sit_id_snap := str(explore_map.get("target_situation_id", ""))
	if not _target_sit_id_snap.is_empty():
		var _tsit_pos_v: Variant = { "col": 0, "row": 0 }
		for _sn_v in situations_raw:
			var _sn: Dictionary = _sn_v if _sn_v is Dictionary else {}
			if str(_sn.get("id", "")) == _target_sit_id_snap:
				var _snp_v: Variant = _sn.get("pos", { "col": 0, "row": 0 })
				_tsit_pos_v = _snp_v if _snp_v is Dictionary else { "col": 0, "row": 0 }
				break
		var _tsit_pos: Dictionary = _tsit_pos_v if _tsit_pos_v is Dictionary else { "col": 0, "row": 0 }
		var _terrain_snap_v: Variant = explore_map.get("terrain", {})
		var _terrain_snap: Dictionary = _terrain_snap_v if _terrain_snap_v is Dictionary else {}
		var _wk_snap: Dictionary = StageTerrainScript.walkable_set(_terrain_snap)
		if not _wk_snap.is_empty():
			var _df_snap: Dictionary = StageTerrainScript.bfs_distance_field(_tsit_pos, _wk_snap)
			var _pk_snap: String = "%d,%d" % [int(party_pos.get("col", 0)), int(party_pos.get("row", 0))]
			_steps_to_target = int(_df_snap.get(_pk_snap, 0))
		else:
			_steps_to_target = GridService.chebyshev_distance(party_pos, _tsit_pos)

	return {
		"type": FlowStateIds.STAGE_EXPLORE,
		"data": {
			"stage_id":               flow_ctx.stage_id,
			"realm_id":               flow_ctx.realm_id,
			"map_width":              map_width,
			"map_height":             map_height,
			"party_pos":              party_pos,
			"party_state":            party_state,
			"turn_count":             turn_count,
			"objectives_found":       obj_found,
			"objectives_total":       obj_total,
			"objectives":             objectives,
			"objectives_remaining":   objectives_remaining,
			"situations":             situations,
			"situation_pending":      situation_pending,
			"party_preview":          party_preview,
			"party_calling_actions":  party_calling_actions,
			"party_requesting_return": party_requesting_return,
			"contact_pending":         contact_pending,
			"contact_responses":       contact_responses_out,
			"contact_echo_bids":       contact_echo_bids,
			# V2-STAGE-004 Phase 5: composite directive (id + label) for UI display.
			"directive":               _directive_snap,
			# V2-STAGE-004-P2 traversal fields
			"step_budget":             _step_budget_snap,
			"steps_to_target":         _steps_to_target,
			"in_transit":              bool(explore_map.get("in_transit", false)),
			"target_situation_id":     str(explore_map.get("target_situation_id", "")),
			"terrain":                 explore_map.get("terrain", {}),
			# traveled_path: Array of {col,row} dicts — DESTINATIONS ONLY, one per cell entered
			# this turn. Excludes the origin (movement-contract path-excludes-origin rule).
			# Empty when no movement occurred (non-advance refreshes). UI uses this for chained tween.
			"traveled_path":           FlowStageExploreState._project_traveled_path(explore_map),
			# traveled_origin: {col,row} — the pre-advance cell the path starts FROM. The UI
			# anchors the first tween segment / ghost here. Falls back to the current party
			# cell when no advance has been stashed (zero-step advance, session reset).
			"traveled_origin":         FlowStageExploreState._project_traveled_origin(explore_map),
			# V2-STAGE-004 Phase 2.5: discovered-tile set { "col,row": true } for fog-of-war rendering.
			# Three tile states: void (not walkable) = no tile; walkable + in explored_cells = normal;
			# walkable + NOT in explored_cells = fog tile. Drives both overview and in-exploration views.
			"explored_cells":          explore_map.get("explored_cells", {}),
			# V2-STAGE-004 Phase 5: transient travel-beat fields, stashed onto explore_map by
			# FlowRuntime._handle_stage_advance_turn only when the party actually moved this turn.
			# Same lifecycle as last_traveled_path: cleared by session reset, absent/empty on
			# non-advance refreshes (contact turns, situation overlays, etc.).
			"travel_bark":             FlowStageExploreState._project_travel_bark(explore_map),
			"travel_snippet":          str(explore_map.get("travel_snippet", "")),
		},
		"actions": actions,
		"meta": { "t": t },
	}

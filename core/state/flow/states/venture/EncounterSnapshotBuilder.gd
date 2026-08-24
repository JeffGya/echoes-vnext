class_name EncounterSnapshotBuilder

extends RefCounted

## V2-INFRA-003 Phase 6 Slice 6J — the encounter/keeper-trial projection and snapshot-shaping
## layer, extracted from core/state/flow/states/venture/FlowEncounterState.gd. Follows the
## SanctumSnapshotBuilder / StageExploreSnapshotBuilder precedent in this same directory:
## a class_name RefCounted holding only static functions.
##
## Every function here moved VERBATIM. No projected field, no action slot, no objective_state
## key and no snapshot value changed. The only edits at the moved sites are the class prefix
## on cross-file calls (FlowEncounterState.X -> EncounterSnapshotBuilder.X) and, for producer
## B below, the composition rewrite described further down.
##
## PURITY CONTRACT.
## Nothing in this file writes save_data, mutates FlowContext, calls request_save(), or
## constructs a service whose constructor can write (in particular never SanctumService.new(),
## whose SanctumState constructor can write to save_data via _ensure_sanctum_dict_exists()).
## It READS flow_ctx and flow_ctx.save_data, exactly as StageExploreSnapshotBuilder does —
## that is the weaker of the two precedents in this directory and the one that applies, since
## build_round_snapshot() and _build_combat_intro_line() genuinely need the context.
## _project_actor()'s purity is pinned directly by
## tests/FlowSnapshotFingerprintTests.gd snapshot_purity/project_actor_does_not_mutate, and
## the two snapshot builders' purity w.r.t. _bark_line by
## snapshot_purity/build_round_snapshot_and_final_snapshot_do_not_mutate_bark.
##
## WHAT DELIBERATELY DID NOT MOVE — FlowEncounterState.build_final_snapshot().
## That function is producer A, and it is NOT pure: it applies the temporary-ally death knock
## to the runtime actors, pays the stage reward through EconomyService.reward_stage_complete(),
## calls flow_ctx.request_save("stage.reward"), awards post-combat XP through
## ProgressionService.award_post_combat_xp(), and writes each echo's final fear/morale back
## into the save-data roster. It therefore cannot join a pure builder. Those writes are the
## subject of defect-register entries D36 and D77, whose fix (moving the settlement into
## VentureController.handle_complete_stage) is scheduled for the after-Phase-9 bundle with a
## single explained baseline re-record — because moving the payment empties `ase_awarded` and
## `ekwan_awarded` from the resolve snapshot and moves all seven combat fingerprints. Slice 6J
## moved nothing of that. build_final_snapshot() stays on FlowEncounterState and calls into
## this file for its projections; when D36/D77 land and the payment leaves it, whatever
## remains is a pure producer and can move here in that change.
##
## PRODUCER B LIVES HERE, PRODUCER A DOES NOT.
## _build_keeper_intro_final_snapshot() (producer B of docs/resolve-snapshot-block-spec.md) is
## pure — it reads config, ectx and already-computed values, and writes nothing — so it moved.
## Producer A stays with the payment it is fused to. Both now COMPOSE their payload through
## ResolveSnapshotBuilder's block library, completing the Phase 5 -> Phase 6 migration; see
## the note at _build_keeper_intro_final_snapshot() for B's two preserved irregularities.
##
## Lifecycle work — EncounterSetupService.setup() and any save_data repair — belongs in
## FlowEncounterState.enter() BEFORE these are called. Never add lifecycle work here.
# ────────────────────────────────────────────────────────────────────────────
# COMBAT-007: Pure static helper functions — projection and objective state.
# ────────────────────────────────────────────────────────────────────────────

## Derives the actor's operational combat status.
## Emotional state is represented exclusively by emotional_status in the snapshot.
static func _derive_status(actor: Dictionary) -> String:
	if actor.get("is_dead", false):
		return "dead"
	if actor.get("guard_state", false):
		return "guarding"
	return "alive"


## Projects a full runtime actor dict to the minimal render-safe snapshot shape.
## Strips internal fields (traits, xp, archetype, raw stats block, etc.)
## while preserving all fields needed by CombatBoardScreen.
## S14a: contribution_ledger is optional (default null → no "contribution" key added, byte-
## identical to pre-S14a shape). Pass EncounterContext.echo_action_logs to project a per-actor
## "contribution": {damage_dealt, damage_taken, kills} sub-dict (zeros when the actor has no
## ledger entry). Only build_final_snapshot() passes it — build_round_snapshot() stays untouched.
## S14b (Tier 2): the same sub-dict also carries the support/offensive fields
## {guards_granted, morale_given, fear_relieved, support_actions, fear_inflicted}.
static func _project_actor(actor: Dictionary, contribution_ledger: Variant = null) -> Dictionary:
	var stats: Dictionary = actor.get("stats", {})
	var max_hp: int = int(stats.get("max_hp", 1))
	var fear: int = int(actor.get("fear", 0))
	var actor_id: String = str(actor.get("id", ""))
	# V2-VOICE-002 / V2-INFRA-003 Phase 3 Slice C: read-only. Neither this helper nor its two
	# callers (build_round_snapshot()/build_final_snapshot() below) ever clear _bark_line
	# anymore — both are now pure projections. The clear lives in FlowRuntime.dispatch()'s
	# closure, gated to flow.encounter/flow.keeper_trial/flow.resolve snapshots, AFTER the
	# snapshot that surfaced this value has been published. See that gate for why it is safe
	# there (every call to either builder happens inside exactly one dispatch()) and why it must
	# NOT live at "true round advance" (_end_round()/combat.confirm_round) instead: these
	# builders also run once per actor turn (combat.next_actor), each its own dispatch(), so a
	# clear gated only to round-advance would let one actor's bark bleed into every other
	# actor's per-turn snapshot for the rest of that round.
	var bark_line_val: String = str(actor.get("_bark_line", ""))
	var proj: Dictionary = {
		"id":             actor_id,
		"name":           str(actor.get("name", "")),
		"hp":             int(actor.get("current_hp", max_hp)),
		"max_hp":         max_hp,
		"status":         EncounterSnapshotBuilder._derive_status(actor),
		"grid_pos":       actor.get("grid_pos", { "col": 0, "row": 0 }),
		"faction":        str(actor.get("faction", "")),
		"is_structure":   bool(actor.get("is_structure", false)),
		"is_quarry":      bool(actor.get("is_quarry", false)),
		"is_spirit":      bool(actor.get("is_spirit", false)),
		# V2-STAGE-004 Phase 4 (S12): Temporary Ally — additive projection field only.
		"is_ally":        bool(actor.get("is_ally", false)),
		# UI-004: added for party strip and pre-battle overlay.
		"calling_origin":    str(actor.get("calling_origin", "")),
		# V2-EMOTION-002: the only player-facing feeling field.
		"emotional_status":  EmotionService.get_emotional_status(int(actor.get("morale", 50)), fear),
		# PROG-008: active skill slots forwarded for pre-battle and resolve screens.
		"skill_slots": (actor.get("skill_slots", [""]) as Array).duplicate(),
		# V2-VOICE-001: bark fields — written by ActorStateMachine, read by CombatBoardScreen.
		"bark_line":        bark_line_val,
		"bark_context":     str(actor.get("_bark_context",     "")),
		"bark_tier":        str(actor.get("_bark_tier",        "")),
		"bark_target_id":   str(actor.get("_bark_target_id",   "")),
		"bark_is_response": bool(actor.get("_bark_is_response", false)),
		# V2-PROG-010: maturity expression — written by ActorStateMachine.advance_turn()
		"expression_band":   str(actor.get("_expression_band",   "")),
		"presence_strength": float(actor.get("_presence_strength", 0.1)),
		# V2-PROG-012 Phase 1: hidden autonomy outputs — no consumer reads these yet.
		"judgment":          float(actor.get("_judgment",  0.0)),
		"presence":          float(actor.get("_presence",  0.0)),
		"composure":         float(actor.get("_composure", 0.0)),
		"legibility":        float(actor.get("_legibility", 0.0)),
	}
	# S14a: offensive contribution ledger, projected read-only for the resolve screen / S14 recruit formula.
	if contribution_ledger is Dictionary:
		var _ledger_entry_v: Variant = (contribution_ledger as Dictionary).get(actor_id, {})
		var _ledger_entry: Dictionary = _ledger_entry_v if _ledger_entry_v is Dictionary else {}
		proj["contribution"] = {
			"damage_dealt":    int(_ledger_entry.get("damage_dealt", 0)),
			"damage_taken":    int(_ledger_entry.get("damage_taken", 0)),
			"kills":           int(_ledger_entry.get("kills", 0)),
			# S14b Tier 2 — support (echo-gated) + offensive fear (all-faction)
			"guards_granted":  int(_ledger_entry.get("guards_granted", 0)),
			"morale_given":    int(_ledger_entry.get("morale_given", 0)),
			"fear_relieved":   int(_ledger_entry.get("fear_relieved", 0)),
			"support_actions": int(_ledger_entry.get("support_actions", 0)),
			"fear_inflicted":  int(_ledger_entry.get("fear_inflicted", 0)),
		}
	return proj

## Builds the objective_state sub-dict from ectx and combat_state.
## type: objective string; shrine_hp/shrine_alive: back-compat structure fields.
## V2-STAGE-004 P3: additive fields — objective_hp, objective_alive, round,
## rounds_required, hold_progress, hold_required. All read defensively; zero when N/A.
static func _build_objective_state(ectx: EncounterContext, combat_state: Dictionary) -> Dictionary:
	var obj_type: String = ""
	if not combat_state.is_empty():
		obj_type = str(combat_state.get("objective", ""))
	elif ectx != null:
		obj_type = str(ectx.resolution_mode)

	var shrine_hp: int     = 0
	var shrine_alive: bool = false
	var objective_hp: int  = 0
	var objective_alive: bool = false
	if ectx != null:
		for a_v in ectx.actors:
			if a_v is Dictionary and a_v.get("is_structure", false):
				var _struct_hp:    int  = int(a_v.get("current_hp", 0))
				var _struct_alive: bool = not bool(a_v.get("is_dead", false))
				shrine_hp    = _struct_hp
				shrine_alive = _struct_alive
				objective_hp    = _struct_hp
				objective_alive = _struct_alive
				break

	# V2-STAGE-004 P3: read round progress from combat_state; objective_params from ectx.
	var _obj_params: Dictionary = combat_state.get("objective_params", {}) if not combat_state.is_empty() else {}
	var _round: int          = int(combat_state.get("round_counter", 0)) if not combat_state.is_empty() else 0
	var _rounds_required: int = int(_obj_params.get("duration_turns", 0))
	var _hold_progress: int  = int(combat_state.get("hold_counter", 0)) if not combat_state.is_empty() else 0
	var _hold_required: int  = int(_obj_params.get("hold_rounds", 0))

	# V2-STAGE-004 Distinctiveness §4-I: additional objective_state fields.
	# objective_invulnerable: true when the located structure has is_objective_relic (RECOVER relic).
	var _objective_invulnerable: bool = false
	if ectx != null:
		for _oi_a in ectx.actors:
			if _oi_a is Dictionary and bool(_oi_a.get("is_structure", false)):
				if bool(_oi_a.get("is_objective_relic", false)):
					_objective_invulnerable = true
				break
	# waves_remaining / wave_total: ENDURE only.
	var _total_waves: int    = int(combat_state.get("total_waves", 0)) if not combat_state.is_empty() else 0
	var _waves_spawned: int  = int(combat_state.get("waves_spawned", 0)) if not combat_state.is_empty() else 0
	var _waves_remaining: int = maxi(0, _total_waves - _waves_spawned)
	var _wave_total: int = _total_waves if obj_type == EncounterResolutionModes.ENDURE else 0
	if obj_type != EncounterResolutionModes.ENDURE:
		_waves_remaining = 0
	# totem_stolen: PROTECT only.
	var _totem_stolen: bool = bool(combat_state.get("totem_stolen", false)) if not combat_state.is_empty() else false

	# V2-STAGE-004 P3b: PURSUE quarry distance to nearest board edge.
	var _quarry_dist_to_exit: int = 0
	if ectx != null and obj_type == EncounterResolutionModes.PURSUE:
		var _qd_bounds: Dictionary = ectx.terrain.get("bounds", {}) if not ectx.terrain.is_empty() else {}
		var _qd_max_col: int = int(_qd_bounds.get("w", 10)) - 1
		var _qd_max_row: int = int(_qd_bounds.get("h", 10)) - 1
		for _qd_a in ectx.actors:
			if _qd_a is Dictionary and bool(_qd_a.get("is_quarry", false)) and not bool(_qd_a.get("is_dead", false)):
				var _qd_p: Dictionary = _qd_a.get("grid_pos", {})
				var _qd_col: int = int(_qd_p.get("col", 0))
				var _qd_row: int = int(_qd_p.get("row", 0))
				_quarry_dist_to_exit = mini(mini(_qd_col, _qd_row), mini(_qd_max_col - _qd_col, _qd_max_row - _qd_row))
				break

	# V2-STAGE-004 P3c: GUIDE_SPIRIT fields (zero/false/"" when N/A).
	var _gs_mode: String          = ""
	var _gs_spirit_alive: bool    = false
	var _gs_spirit_hp: int        = 0
	var _gs_spirit_name_out: String = ""
	var _gs_joins_out: bool       = false
	var _gs_destination_reached: bool = false
	var _gs_destination_pos: Dictionary = {}
	var _gs_rounds_remaining: int = 0
	if obj_type == EncounterResolutionModes.GUIDE_SPIRIT:
		_gs_mode              = str(_obj_params.get("guide_mode", "protect"))
		_gs_spirit_name_out    = str(_obj_params.get("spirit_name", ""))
		_gs_joins_out          = bool(_obj_params.get("spirit_joins_battle", false))
		_gs_destination_reached = bool(combat_state.get("destination_reached", false)) if not combat_state.is_empty() else false
		if ectx != null:
			for _gs_a in ectx.actors:
				if _gs_a is Dictionary and bool(_gs_a.get("is_spirit", false)):
					_gs_spirit_alive = not bool(_gs_a.get("is_dead", false))
					_gs_spirit_hp    = int(_gs_a.get("current_hp", 0))
					if _gs_spirit_name_out.is_empty():
						_gs_spirit_name_out = str(_gs_a.get("name", ""))
					break
		if _gs_mode == "escort":
			var _gs_dc: int = int(_obj_params.get("destination_col", -1))
			var _gs_dr: int = int(_obj_params.get("destination_row", -1))
			if _gs_dc >= 0 and _gs_dr >= 0:
				_gs_destination_pos = { "col": _gs_dc, "row": _gs_dr }
		else:
			# V2-STAGE-004 P3c "guard to count": protect-mode progress is guide_protect_counter
			# (rounds an echo was within escort_radius of the spirit), NOT wall rounds — so the
			# HUD shows real guard progress toward the win, not the raw round timer.
			var _gs_guard_progress: int = int(combat_state.get("guide_protect_counter", 0)) if not combat_state.is_empty() else 0
			_gs_rounds_remaining = maxi(0, _rounds_required - _gs_guard_progress)

	return {
		"type":                  obj_type,
		"shrine_hp":             shrine_hp,
		"shrine_alive":          shrine_alive,
		# V2-STAGE-004 P3: enriched fields (back-compat: zero when N/A).
		"objective_hp":          objective_hp,
		"objective_alive":       objective_alive,
		"round":                 _round,
		"rounds_required":       _rounds_required,
		"hold_progress":         _hold_progress,
		"hold_required":         _hold_required,
		# V2-STAGE-004 Distinctiveness §4-I: new fields (zero/false when N/A).
		"objective_invulnerable": _objective_invulnerable,
		"waves_remaining":        _waves_remaining,
		"wave_total":             _wave_total,
		"totem_stolen":           _totem_stolen,
		# V2-STAGE-004 PROTECT guard-proximity: actual guarded-round progress vs required.
		"protect_progress":       int(combat_state.get("protect_counter", 0)) if not combat_state.is_empty() else 0,
		"protect_required":       int(_obj_params.get("duration_turns", 0)),
		# V2-STAGE-004 PROTECT entity name: objective_params carries it (default "Protected One").
		"entity_name":            str(_obj_params.get("entity_name", "")),
		# V2-STAGE-004 P3b: PURSUE fields (zero/false when N/A).
		"contain_progress":       int(combat_state.get("contain_counter", 0)) if not combat_state.is_empty() else 0,
		"contain_required":       int(_obj_params.get("contain_rounds", 0)),
		"window_remaining":       maxi(0, int(_obj_params.get("window_turns", 0)) - _round) if not combat_state.is_empty() else 0,
		"quarry_distance_to_exit": _quarry_dist_to_exit,
		# V2-STAGE-004 P3c: GUIDE_SPIRIT fields (zero/false/"" when N/A).
		"guide_mode":             _gs_mode,
		"spirit_alive":           _gs_spirit_alive,
		"spirit_hp":              _gs_spirit_hp,
		"spirit_name":            _gs_spirit_name_out,
		"spirit_joins_battle":    _gs_joins_out,
		"destination_reached":    _gs_destination_reached,
		"destination_pos":        _gs_destination_pos,
		"rounds_remaining":       _gs_rounds_remaining,
		# V2-STAGE-004 S15 prep: true when S13's failed-charge pressure bump was applied
		# to this encounter's objective. Default false.
		"charge_pressure_applied": ectx.charge_pressure_applied if ectx != null else false,
	}


## V2-STAGE-004 S15 prep: short context line for a hostile-claimant-forced combat.
## Reads the durable explore_map.combat_intro_reason marker set by FlowRuntime's
## stage.claimant.combat_forced branch (cleared at encounter teardown alongside
## the ally fields — see RecruitmentConsequenceService.clear_ally_fields_if_present). No hard-coded copy here;
## the line itself lives in data.contact.claimant.combat_intro_line.
static func _build_combat_intro_line(flow_ctx: FlowContext) -> String:
	if flow_ctx == null:
		return ""
	var _cil_stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
	if _cil_stage.is_empty():
		return ""
	var _cil_map_v: Variant = _cil_stage.get("explore_map", {})
	var _cil_map: Dictionary = _cil_map_v if _cil_map_v is Dictionary else {}
	var _cil_reason := str(_cil_map.get("combat_intro_reason", ""))
	if _cil_reason != "claimant_hostile":
		return ""
	if flow_ctx.config_service == null:
		return ""
	var _cil_bal: Dictionary = flow_ctx.config_service.get_balance()
	var _cil_data_v: Variant = _cil_bal.get("data", {})
	var _cil_data: Dictionary = _cil_data_v if _cil_data_v is Dictionary else {}
	var _cil_contact_v: Variant = _cil_data.get("contact", {})
	var _cil_contact: Dictionary = _cil_contact_v if _cil_contact_v is Dictionary else {}
	var _cil_claimant_v: Variant = _cil_contact.get("claimant", {})
	var _cil_claimant: Dictionary = _cil_claimant_v if _cil_claimant_v is Dictionary else {}
	return str(_cil_claimant.get("combat_intro_line", ""))


# ────────────────────────────────────────────────────────────────────────────
# COMBAT-007: Primary snapshot builders.
# ────────────────────────────────────────────────────────────────────────────

## COMBAT-007: RoundSnapshot builder — emits type "flow.encounter".
## Covers all non-terminal phases: pre_combat, actor_turn, round_end.
## Called from enter(), _handle_combat_init(), _resolve_next_actor(), and
## _end_round() when combat is NOT over.
static func build_round_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	# Read board config.
	var grid_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		var bdata: Dictionary = balance.get("data", {})
		grid_cfg = bdata.get("grid", {})
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	# V2-STAGE-004 P3a: use terrain bounds when available, else legacy grid_cfg.
	var _snap_terrain: Dictionary = ectx.terrain if ectx != null else {}
	var _snap_bounds: Dictionary  = _snap_terrain.get("bounds", {}) if not _snap_terrain.is_empty() else {}
	var board_cols: int = int(_snap_bounds["w"]) if _snap_bounds.has("w") else GridService.get_board_cols(grid_cfg)
	var board_rows: int = int(_snap_bounds["h"]) if _snap_bounds.has("h") else GridService.get_board_rows(grid_cfg)
	var raw_actors: Array = ectx.actors if ectx != null else []
	var combat_state: Dictionary = ectx.combat_state if ectx != null else {}
	var encounter_id: String = ectx.encounter_id if ectx != null else ""
	var placement_seed: int = ectx.placement_seed if ectx != null else 0
	var combat_over: bool = bool(combat_state.get("combat_over", false))
	if encounter_id == "keeper_intro.first_trial":
		board_cols = 5
		board_rows = 5

	var round: int = 0
	var initiative_order: Array = []
	var active_initiative_index: int = 0

	# Determine round_phase from combat_state.
	var cs_phase: String = str(combat_state.get("round_phase", "idle"))
	var round_phase: String
	if combat_state.is_empty():
		round_phase = "pre_combat"
	elif cs_phase == "in_round":
		round_phase = "actor_turn"
	else:
		round_phase = "round_end"

	if not combat_state.is_empty():
		round                   = int(combat_state.get("round_counter", 0))
		initiative_order        = combat_state.get("initiative_order", [])
		active_initiative_index = int(combat_state.get("active_initiative_index", 0))

	# Per-actor display fields.
	var current_actor_id: String      = str(ectx.last_actor_action.get("source_id", "")) if ectx != null else ""
	# V2-COMBAT-002 Slice 6D: deep duplicate — last_actor_action now carries a nested
	# `path` Array; a shallow copy would alias a mutable array across the core/UI boundary.
	var last_actor_action_v: Dictionary = ectx.last_actor_action.duplicate(true) if ectx != null else {}

	# Project actors to clean render shape.
	# V2-INFRA-003 Phase 3 Slice C: this loop used to clear (a_v as Dictionary)["_bark_line"] = ""
	# here, right after projecting — that made build_round_snapshot() itself an impure builder
	# (a projection that mutates the source it is projecting). The clear now happens in
	# FlowRuntime.dispatch()'s closure, once, after the published snapshot is logged. Do NOT
	# reintroduce a clear in this loop — see the comment on _project_actor() above for why.
	var projected_actors: Array = []
	for a_v in raw_actors:
		if a_v is Dictionary:
			projected_actors.append(EncounterSnapshotBuilder._project_actor(a_v))

	var actions: Dictionary = {}
	if encounter_id != "keeper_intro.first_trial":
		actions["nav.back"] = {
			"type":  "flow.go_state",
			"to":    FlowStateIds.SANCTUM,
			"label": "← Back",
			"slot":  "nav.back",
		}

	# UI-004: Retreat eligibility — computed pre_combat only; inert in all other phases.
	var retreat_eligible:    bool   = false
	var retreat_ase_cost:    int    = 0
	var retreat_tier_label:  String = ""
	var retreat_success_pct: int    = 0

	match round_phase:
		"pre_combat":
			actions["cta.combat_init"] = {
				"type":  "combat.init",
				"label": "Start Combat",
				"slot":  "cta.combat_init",
			}
			# UI-004: compute retreat fields from ectx.actors.
			var raw_actors_for_retreat: Array = ectx.actors if ectx != null else []
			retreat_eligible = RetreatService.can_attempt(raw_actors_for_retreat)
			var combat_cfg_r: Dictionary = {}
			if flow_ctx.config_service != null:
				var bal_r: Dictionary   = flow_ctx.config_service.get_balance()
				var bdata_r: Dictionary = bal_r.get("data", {})
				combat_cfg_r = bdata_r.get("combat", {})
			retreat_ase_cost = int(combat_cfg_r.get("retreat_ase_cost", 30))
			var tier_cfg_r: Array = combat_cfg_r.get("retreat_agi_tiers", [])
			var tier_r: Dictionary = RetreatService.get_chance_tier(raw_actors_for_retreat, tier_cfg_r)
			if not tier_r.is_empty():
				retreat_tier_label  = str(tier_r.get("label", ""))
				retreat_success_pct = int(tier_r.get("success_pct", 0))
				actions["cta.retreat"] = {
					"type":        "encounter.retreat",
					"slot":        "cta.retreat",
					"success_pct": retreat_success_pct,
					"ase_cost":    retreat_ase_cost,
				}
		"actor_turn":
			actions["cta.next_actor"] = {
				"type":  "combat.next_actor",
				"label": "Next",
				"slot":  "cta.next_actor",
			}
		"round_end":
			actions["cta.confirm_round"] = {
				"type":  "combat.confirm_round",
				"label": "Confirm Round",
				"slot":  "cta.confirm_round",
			}

	return {
		"type": FlowStateIds.KEEPER_TRIAL if encounter_id == "keeper_intro.first_trial" else FlowStateIds.ENCOUNTER,
		"data": {
			"title":                   "Encounter",
			"encounter_id":            encounter_id,
			"board_cols":              board_cols,
			"board_rows":              board_rows,
			"actors":                  projected_actors,
			"placement_seed":          placement_seed,
			"objective_state":         EncounterSnapshotBuilder._build_objective_state(ectx, combat_state),
			"round":                   round,
			"initiative_order":        initiative_order,
			"active_initiative_index": active_initiative_index,
			"action_results":          ectx.last_round_results.duplicate() if ectx != null else [],
			"current_actor_id":        current_actor_id,
			"last_actor_action":       last_actor_action_v,
			"round_phase":             round_phase,
			"combat_over":             combat_over,
			# UI-004: always present; non-zero/non-empty only in pre_combat phase.
			"retreat_eligible":        retreat_eligible,
			"retreat_ase_cost":        retreat_ase_cost,
			"retreat_tier_label":      retreat_tier_label,
			"retreat_success_pct":     retreat_success_pct,
			# V2-STAGE-002: remaining required objectives (informational during combat).
			"objectives_remaining":    EncounterSnapshotBuilder._count_remaining_required_objectives(flow_ctx),
			# V2-STAGE-004 P3a: irregular terrain dict for CombatBoardScreen tilemap.
			# {} when no terrain (legacy 10×10 path).
			"terrain":        (ectx.terrain if ectx != null else {}),
			# P1 CLOSE: stub fields to keep round field_count >= final field_count.
			"surface":        "",
			"summary_line":   "",
			# V2-STAGE-004 S15 prep: short context beat for a hostile-claimant-forced combat.
			# "" when not applicable.
			"combat_intro_line": EncounterSnapshotBuilder._build_combat_intro_line(flow_ctx),
		},
		"actions": actions,
		"meta":    { "t": t },
	}


# V2-STAGE-002: objectives_remaining controls routing from the resolve screen.
# - Victory, all objectives done  → cta.next_stage advances the stage; cta.continue goes to Sanctum
# - Victory, objectives remain   → cta.continue returns to exploration (no stage advance yet)
# - Defeat                       → cta.continue goes to Sanctum (unchanged)
static func _build_resolve_actions(victory: bool, objectives_remaining: int = 0) -> Dictionary:
	var actions: Dictionary = {}
	if victory:
		if objectives_remaining == 0:
			# All required objectives complete — advance stage
			actions["cta.continue"] = {
				"type":        "flow.complete_stage",
				"destination": FlowStateIds.SANCTUM,
				"label":       "To Sanctum",
				"slot":        "cta.continue",
			}
			actions["cta.next_stage"] = {
				"type":  "flow.complete_stage",
				"label": "Next Stage",
				"slot":  "cta.next_stage",
			}
		else:
			# More objectives to find — return to exploration
			actions["cta.continue"] = {
				"type":  "flow.go_state",
				"to":    FlowStateIds.STAGE_EXPLORE,
				"label": "Return to Exploration",
				"slot":  "cta.continue",
			}
	else:
		actions["cta.continue"] = {
			"type":  "flow.go_state",
			"to":    FlowStateIds.SANCTUM,
			"label": "To Sanctum",
			"slot":  "cta.continue",
		}
	return actions


# V2-STAGE-002: Count required objectives in the current stage that are not yet completed.
# Returns 0 when all required objectives are done (or no stage/objectives exist).
static func _count_remaining_required_objectives(flow_ctx: FlowContext) -> int:
	var model := RealmService.get_active(flow_ctx)
	if model.is_empty():
		return 0
	var stage_index := 0
	var sid := str(flow_ctx.stage_id)
	if sid.contains("."):
		var parts := sid.split(".")
		stage_index = int(parts[parts.size() - 1])
	var stages_v: Variant = model.get("stages", [])
	var stages: Array = stages_v if stages_v is Array else []
	var stage: Dictionary = {}
	for s_v in stages:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if int(s.get("index", -1)) == stage_index:
			stage = s
			break
	if stage.is_empty():
		return 0
	var objs_v: Variant = stage.get("objectives", [])
	var objs: Array = objs_v if objs_v is Array else []
	var remaining := 0
	for obj_v in objs:
		var obj: Dictionary = obj_v if obj_v is Dictionary else {}
		if bool(obj.get("required", true)) and not bool(obj.get("completed", false)):
			remaining += 1
	return remaining


## Producer B of docs/resolve-snapshot-block-spec.md — the keeper-trial resolve card.
##
## V2-INFRA-003 Phase 6 Slice 6J: composed through ResolveSnapshotBuilder's block library,
## completing the Phase 5 migration (C/D/E/F went first; A is the sibling in
## FlowEncounterState.build_final_snapshot()). No key and no value changed. The spec's Phase 5
## claim that Phase 6 needs NO edit to ResolveSnapshotBuilder.gd was re-verified here: B's
## sixteen keys are exactly legacy_title + combat_stats + actors + victory_flag + ledger +
## grade_rank + progression + emotion, at the granularity those blocks already have.
##
## TWO MEASURED IRREGULARITIES, PRESERVED EXACTLY — do not "tidy" either one.
##  1. B calls add_ledger (ase_awarded + reward_breakdown) but NOT add_ekwan, so
##     `ekwan_awarded` is absent from this payload while A, C and E all set it. That is
##     precisely why the block library splits ekwan out as block #8 instead of making it a
##     `ledger(include_ekwan)` flag — a missing add_ekwan line is visible; a flipped default
##     is not. NO TEST PINS THE OMISSION today (`onboarding` covers the type, actors and
##     cta.continue routing; `fingerprint` does not drive the keeper trial), so this comment
##     and the absent call are the only record.
##  2. B's emotion entries carry no `direction` and no `tag` fields, unlike A (which adds
##     both) and E (both plus `bark`) — see _build_keeper_intro_emotion_summary() below.
##     Registered as defect D35; recorded, not fixed.
##
## Key ORDER in `data` changes with the composition (and `meta` now sits second in the
## snapshot), which is safe: FlowFingerprintTests._final_fingerprint() sorts `data_keys`
## before hashing (tests/FlowFingerprintTests.gd:238-241) and no test JSON-hashes a whole
## resolve snapshot. Every read in ui/screens/venture/ResolveScreen.gd is data.get(key, ...).
static func _build_keeper_intro_final_snapshot(
	flow_ctx: FlowContext,
	t: int,
	ectx: EncounterContext,
	combat_state: Dictionary,
	combat_result: Dictionary,
	projected_actors: Array,
	enemies_defeated: int,
	echoes_survived: int,
	round_ended: int
) -> Dictionary:
	var ase_reward := 40
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		var data_v: Variant = balance.get("data", {})
		var data: Dictionary = data_v if data_v is Dictionary else {}
		var intro_v: Variant = data.get("keeper_intro", {})
		var intro: Dictionary = intro_v if intro_v is Dictionary else {}
		ase_reward = int(intro.get("first_trial_ase_reward", ase_reward))
	var victory := bool(combat_result.get("victory", false))

	var _actions: Dictionary = {
		"cta.continue": {
			"type": "keeper_intro.trial.finish",
			"label": "Carry It Home",
			"slot": "cta.continue",
		}
	} if victory else {
		"cta.continue": {
			"type": "flow.go_state",
			"to": FlowStateIds.KEEPER_TRIAL,
			"label": "Try Again",
			"slot": "cta.continue",
		}
	}
	var _breakdown: Array = [
		{ "label": "First Trial", "delta": ase_reward }
	] if victory else []

	# B emits no run_type — like A and F it falls through to ResolveScreen's combat renderer.
	var _snap: Dictionary = ResolveSnapshotBuilder.build(t, _actions)
	var _data: Dictionary = _snap["data"]
	ResolveSnapshotBuilder.add_legacy_title(_data, "Result")
	ResolveSnapshotBuilder.add_combat_stats(
		_data,
		"keeper_intro.first_trial",
		str(combat_result.get("reason", "")),
		round_ended,
		enemies_defeated,
		echoes_survived,
		EncounterSnapshotBuilder._build_objective_state(ectx, combat_state)
	)
	ResolveSnapshotBuilder.add_actors(_data, projected_actors)
	ResolveSnapshotBuilder.add_victory_flag(_data, victory)
	ResolveSnapshotBuilder.add_ledger(_data, ase_reward if victory else 0, _breakdown)
	ResolveSnapshotBuilder.add_grade_rank(_data, "A" if victory else "F")
	ResolveSnapshotBuilder.add_progression(_data, {}, [], [])
	ResolveSnapshotBuilder.add_emotion(_data, EncounterSnapshotBuilder._build_keeper_intro_emotion_summary(ectx))
	# NO add_ekwan — see irregularity 1 above.
	return _snap


static func _build_keeper_intro_emotion_summary(ectx: EncounterContext) -> Array:
	var summary: Array = []
	if ectx == null:
		return summary
	var pre_morale_map: Dictionary = ectx.pre_encounter_morale
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var actor: Dictionary = a_v
		if str(actor.get("faction", "")) != "echo":
			continue
		var eid := str(actor.get("id", ""))
		var pre_morale := int(pre_morale_map.get(eid, 50))
		var post_morale := int(actor.get("morale", 50))
		var post_fear := int(actor.get("fear", 0))
		summary.append({
			"echo_id": eid,
			"name": str(actor.get("name", "")),
			"pre_emotional_status": EmotionService.get_emotional_status(pre_morale, 0),
			"post_emotional_status": EmotionService.get_emotional_status(post_morale, post_fear),
			"morale_delta": post_morale - pre_morale,
			"refused": post_fear >= FlowEncounterState.FEAR_THRESHOLD_DEFAULT,
		})
	return summary


# P1 CLOSE: maps emotional status string to a rank index (higher = better).
# Used to compute direction in emotion_summary entries.
# radiant > whole > grounded > uncertain > hesitant > burdened > pressed > strained > fraying > hollow
static func _emotional_status_rank(status: String) -> int:
	match status:
		"radiant":   return 9
		"whole":     return 8
		"grounded":  return 7
		"uncertain": return 6
		"hesitant":  return 5
		"burdened":  return 4
		"pressed":   return 3
		"strained":  return 2
		"fraying":   return 1
		"hollow":    return 0
	return 5  # default: hesitant (middle)

class_name FlowEncounterState

extends State

func _init(id: String = FlowStateIds.ENCOUNTER) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	# Create encounter context once per active encounter.
	if flow_ctx.encounter_ctx == null:
		flow_ctx.encounter_ctx = EncounterContext.new()
		flow_ctx.encounter_ctx.encounter_id = flow_ctx.encounter_id
		# COMBAT-006 dev toggle: use override if set, otherwise default to PURIFY_SHRINE.
		if not flow_ctx.dev_combat_objective.is_empty():
			flow_ctx.encounter_ctx.resolution_mode = flow_ctx.dev_combat_objective
		else:
			# BUG-002: read stage's first objective type and map to resolution mode.
			flow_ctx.encounter_ctx.resolution_mode = _resolve_mode_from_stage(flow_ctx)

	# Create machine once, register states once.
	if flow_ctx.encounter_machine == null:
		flow_ctx.encounter_machine = EncounterStateMachine.new()
		flow_ctx.encounter_machine.register_default_states()

	# GRID-001: read board config from balance.json data.grid block.
	var grid_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		var bdata: Dictionary = balance.get("data", {})
		grid_cfg = bdata.get("grid", {})
		# COMBAT-002: store initiative modifiers so EncounterRoundsState.enter() can use them.
		var combat_cfg: Dictionary = bdata.get("combat", {})
		flow_ctx.encounter_ctx.initiative_cfg = combat_cfg.get("initiative_modifiers", {})

	# Build actors only once (when phase_snapshot is empty = first entry before machine starts).
	if flow_ctx.encounter_ctx.phase_snapshot.is_empty():

		# GRID-002: build echo actor list from the active party in save_data.
		var echo_actors: Array = []
		if flow_ctx.save_data.has("sanctum"):
			var party_ids: Array = flow_ctx.save_data["sanctum"].get("active_party_ids", [])
			var roster: Array = flow_ctx.save_data["sanctum"].get("roster", [])
			for echo in roster:
				if echo.get("id", "") in party_ids:
					echo_actors.append(EchoActor.from_echo(echo))
		echo_actors.sort_custom(func(a, b): return a["id"] < b["id"])

		# GRID-002: build enemy actor list (hardcoded stubs — actors.json is empty in MVP).
		# BALANCE-001: pass birth_stats + enemy_types cfg so EnemyActor uses DerivedStatService.
		var actor_cfg: Dictionary = {}
		if flow_ctx.config_service != null:
			var bal: Dictionary  = flow_ctx.config_service.get_balance()
			var bd: Dictionary   = bal.get("data", {})
			actor_cfg = {
				"birth_stats": bd.get("summoning", {}).get("birth_stats", {}),
				"enemy_types": bd.get("actor", {}).get("enemy_types", {}),
			}
		var enemy_defs: Array = [
			{ "id": "enemy_guardian_01", "name": "Guardian", "type": "guardian", "faction": "enemy" },
			{ "id": "enemy_shadow_01",   "name": "Shadow",   "type": "shadow",   "faction": "enemy" },
		]
		var enemy_actors: Array = []
		for defn in enemy_defs:
			enemy_actors.append(EnemyActor.from_definition(defn, t, actor_cfg))
		enemy_actors.sort_custom(func(a, b): return a["id"] < b["id"])

		# GRID-003: deterministic seeded placement.
		var place_cfg: Dictionary = grid_cfg.get("placement_modifiers", {})
		var placement_seed: int = 0
		var rng := RandomNumberGenerator.new()
		if flow_ctx.campaign_seed != null:
			placement_seed = flow_ctx.campaign_seed.derive(
				"combat.placement." + flow_ctx.encounter_ctx.encounter_id)
			rng = flow_ctx.campaign_seed.get_rng(
				"combat.placement." + flow_ctx.encounter_ctx.encounter_id)
		else:
			rng.seed = hash(flow_ctx.encounter_ctx.encounter_id)

		GridService.place_actors(echo_actors, enemy_actors, grid_cfg, rng, place_cfg)

		# COMBAT-006: spawn shrine actor if objective is purify_shrine.
		var shrine_actor: Dictionary = {}
		var shrine_cfg: Dictionary = {}
		if flow_ctx.encounter_ctx.resolution_mode == EncounterResolutionModes.PURIFY_SHRINE:
			var structure_cfg: Dictionary = {}
			if flow_ctx.config_service != null:
				var bal: Dictionary = flow_ctx.config_service.get_balance()
				var bd: Dictionary  = bal.get("data", {})
				structure_cfg = bd.get("actor", {}).get("structures", {})
				shrine_cfg    = bd.get("combat", {}).get("shrine", {})
			var shrine_def: Dictionary = structure_cfg.get("shrine", {
				"id": "shrine_01", "name": "Ancestral Shrine",
				"faction": "structure", "max_hp": 200,
				"grid_pos": { "col": 0, "row": 4 }
			})
			shrine_actor = StructureActor.from_definition(shrine_def, t)
			# Runtime-only shrine fields — not in ActorSchema REQUIRED_FIELDS.
			shrine_actor["purify_stacks"] = []

		# COMBAT-001: store placed actors and seed on ectx for snapshot rebuilds.
		var all_actors: Array = echo_actors + enemy_actors
		if not shrine_actor.is_empty():
			all_actors.append(shrine_actor)
		flow_ctx.encounter_ctx.actors = all_actors.duplicate(true)
		flow_ctx.encounter_ctx.placement_seed = placement_seed

		# COMBAT-006: select purifier and initialise cooldown field on the actor.
		if not shrine_actor.is_empty() and not shrine_cfg.is_empty():
			var purifier_id: String = ShrineService.select_purifier(echo_actors, shrine_cfg)
			flow_ctx.encounter_ctx.purifier_id = purifier_id
			# Tag the purifier actor in ectx.actors with purify_cooldown = 0.
			if not purifier_id.is_empty():
				for i in range(flow_ctx.encounter_ctx.actors.size()):
					var a: Dictionary = flow_ctx.encounter_ctx.actors[i]
					if a.get("id", "") == purifier_id:
						flow_ctx.encounter_ctx.actors[i]["purify_cooldown"] = 0
						break

		# GRID-003: log combat.actor.spawned — includes placement_seed for determinism audit.
		if flow_ctx.logger != null:
			for actor in all_actors:
				flow_ctx.logger.info(t, "combat.actor.spawned",
					"Actor spawned at (%d,%d)" % [actor["grid_pos"]["col"], actor["grid_pos"]["row"]],
					{ "actor_id": actor["id"], "name": actor["name"],
					  "faction": actor.get("faction", ""), "grid_pos": actor["grid_pos"],
					  "placement_seed": placement_seed })
			# COMBAT-006: log purifier selection.
			if not flow_ctx.encounter_ctx.purifier_id.is_empty():
				flow_ctx.logger.info(t, "combat.purifier_selected",
					"Purifier selected for shrine objective",
					{ "purifier_id": flow_ctx.encounter_ctx.purifier_id,
					  "shrine_id":   shrine_actor.get("id", "") })

	# COMBAT-001/COMBAT-007: always build round snapshot at entry (pre_combat phase).
	flow_ctx.last_snapshot = FlowEncounterState.build_round_snapshot(flow_ctx, t)

func exit(ctx: RefCounted, t: int) -> void:
	pass


# ────────────────────────────────────────────────────────────────────────────
# BUG-002: Reads the stage's first objective type and maps it to the correct
# encounter resolution mode. Same stage-lookup pattern as FlowStageState.enter().
# ────────────────────────────────────────────────────────────────────────────

static func _resolve_mode_from_stage(flow_ctx: FlowContext) -> String:
	var model := RealmService.get_active(flow_ctx)
	if model.is_empty():
		return EncounterResolutionModes.PURIFY_SHRINE

	# Parse stage index from "stage.N" — same pattern as FlowStageState
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
		return EncounterResolutionModes.PURIFY_SHRINE

	# Fix BUG-002: use stage.type (set by RealmGenerator from any shrine objective)
	# not objectives[0].type (which only checks the first objective and misses mixed stages).
	match str(stage.get("type", "")):
		StageModel.TYPE_PURIFICATION:
			return EncounterResolutionModes.PURIFY_SHRINE
		StageModel.TYPE_COMBAT:
			return EncounterResolutionModes.COMBAT
		_:
			return EncounterResolutionModes.COMBAT


# ────────────────────────────────────────────────────────────────────────────
# COMBAT-007: Pure static helper functions — projection and objective state.
# ────────────────────────────────────────────────────────────────────────────

## Derives a player-facing status string from a runtime actor dict.
## Priority: dead > guarding > refusing (fear ≥ 80) > alive
static func _derive_status(actor: Dictionary) -> String:
	if actor.get("is_dead", false):
		return "dead"
	if actor.get("guard_state", false):
		return "guarding"
	if int(actor.get("fear", 0)) >= 80:
		return "refusing"
	return "alive"


## Projects a full runtime actor dict to the minimal render-safe snapshot shape.
## Strips internal fields (traits, xp, archetype, raw stats block, etc.)
## while preserving all fields needed by CombatBoardScreen.
static func _project_actor(actor: Dictionary) -> Dictionary:
	var stats: Dictionary = actor.get("stats", {})
	var max_hp: int = int(stats.get("max_hp", 1))
	var fear: int = int(actor.get("fear", 0))
	return {
		"id":             str(actor.get("id", "")),
		"name":           str(actor.get("name", "")),
		"hp":             int(actor.get("current_hp", max_hp)),
		"max_hp":         max_hp,
		"status":         FlowEncounterState._derive_status(actor),
		"grid_pos":       actor.get("grid_pos", { "col": 0, "row": 0 }),
		"faction":        str(actor.get("faction", "")),
		"is_structure":   bool(actor.get("is_structure", false)),
		"fear":           fear,
		"morale":         int(actor.get("morale", 50)),
		# UI-004: added for party strip and pre-battle overlay.
		"calling_origin": str(actor.get("calling_origin", "")),
		"morale_status":  FlowEncounterState._derive_morale_status(fear),
		# PROG-008: active skill slots forwarded for pre-battle and resolve screens.
		"skill_slots": (actor.get("skill_slots", [""]) as Array).duplicate(),
	}


## UI-004: Derives a player-facing morale status label from the actor's current fear level.
static func _derive_morale_status(fear: int) -> String:
	if fear >= 80:
		return "Broken"
	if fear >= 40:
		return "Afraid"
	if fear > 0:
		return "Shaken"
	return "Normal"


## Builds the objective_state sub-dict from ectx and combat_state.
## type: objective string; shrine_hp: current shrine HP (0 if N/A); shrine_alive: bool.
static func _build_objective_state(ectx: EncounterContext, combat_state: Dictionary) -> Dictionary:
	var obj_type: String = ""
	if not combat_state.is_empty():
		obj_type = str(combat_state.get("objective", ""))
	elif ectx != null:
		obj_type = str(ectx.resolution_mode)

	var shrine_hp: int    = 0
	var shrine_alive: bool = false
	if ectx != null:
		for a_v in ectx.actors:
			if a_v is Dictionary and a_v.get("is_structure", false):
				shrine_hp    = int(a_v.get("current_hp", 0))
				shrine_alive = not bool(a_v.get("is_dead", false))
				break

	return {
		"type":         obj_type,
		"shrine_hp":    shrine_hp,
		"shrine_alive": shrine_alive,
	}


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
	var board_cols: int = GridService.get_board_cols(grid_cfg)
	var board_rows: int = GridService.get_board_rows(grid_cfg)

	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var raw_actors: Array = ectx.actors if ectx != null else []
	var combat_state: Dictionary = ectx.combat_state if ectx != null else {}
	var encounter_id: String = ectx.encounter_id if ectx != null else ""
	var placement_seed: int = ectx.placement_seed if ectx != null else 0

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
	var last_actor_action_v: Dictionary = ectx.last_actor_action.duplicate() if ectx != null else {}

	# Project actors to clean render shape.
	var projected_actors: Array = []
	for a_v in raw_actors:
		if a_v is Dictionary:
			projected_actors.append(FlowEncounterState._project_actor(a_v))

	var actions: Dictionary = {
		"nav.back": {
			"type":  "flow.go_state",
			"to":    FlowStateIds.SANCTUM,
			"label": "← Back",
			"slot":  "nav.back",
		},
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
		"type": FlowStateIds.ENCOUNTER,
		"data": {
			"title":                   "Encounter",
			"encounter_id":            encounter_id,
			"board_cols":              board_cols,
			"board_rows":              board_rows,
			"actors":                  projected_actors,
			"placement_seed":          placement_seed,
			"objective_state":         FlowEncounterState._build_objective_state(ectx, combat_state),
			"round":                   round,
			"initiative_order":        initiative_order,
			"active_initiative_index": active_initiative_index,
			"action_results":          ectx.last_round_results.duplicate() if ectx != null else [],
			"current_actor_id":        current_actor_id,
			"last_actor_action":       last_actor_action_v,
			"round_phase":             round_phase,
			"combat_over":             false,
			# UI-004: always present; non-zero/non-empty only in pre_combat phase.
			"retreat_eligible":        retreat_eligible,
			"retreat_ase_cost":        retreat_ase_cost,
			"retreat_tier_label":      retreat_tier_label,
			"retreat_success_pct":     retreat_success_pct,
		},
		"actions": actions,
		"meta":    { "t": t },
	}


## COMBAT-007: FinalCombatSnapshot builder — emits type "flow.resolve".
## Called from _end_round() only when combat_over is true.
## Consumed by ResolveScreen (UI-005 scaffold).
static func build_final_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var raw_actors: Array = ectx.actors if ectx != null else []
	var combat_state: Dictionary = ectx.combat_state if ectx != null else {}
	var encounter_id: String = ectx.encounter_id if ectx != null else ""
	var combat_result: Dictionary = ectx.combat_result if ectx != null else {}

	# Project actors to clean render shape.
	var projected_actors: Array = []
	for a_v in raw_actors:
		if a_v is Dictionary:
			projected_actors.append(FlowEncounterState._project_actor(a_v))

	# UI-005: pre-compute summary counts so ResolveScreen reads clean fields.
	var enemies_defeated: int = 0
	var echoes_survived: int  = 0
	var total_enemies: int    = 0
	var total_echoes: int     = 0
	for a in projected_actors:
		var faction := str(a.get("faction", ""))
		var status  := str(a.get("status", ""))
		if faction == "enemy":
			total_enemies += 1
			if status == "dead":
				enemies_defeated += 1
		elif faction == "echo":
			total_echoes += 1
			if status != "dead":
				echoes_survived += 1

	# ECONOMY-004: Read reward config from balance.json
	var reward_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		var bal_data_v: Variant = balance.get("data", {})
		var bal_data: Dictionary = bal_data_v if bal_data_v is Dictionary else {}
		var rc_v: Variant = bal_data.get("rewards", {})
		reward_cfg = rc_v if rc_v is Dictionary else {}

	# ECONOMY-004: Resolve stage objectives from realm model
	var stage_objectives: Array = []
	var realm_model: Dictionary = RealmService.get_active(flow_ctx)
	var raw_model_stages: Variant = realm_model.get("stages", [])
	var model_stages: Array = raw_model_stages if raw_model_stages is Array else []
	var sid := str(flow_ctx.stage_id)
	var stage_index := 0
	if sid.contains("."):
		var parts := sid.split(".")
		stage_index = int(parts[parts.size() - 1])
	for s_v in model_stages:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if int(s.get("index", -1)) == stage_index:
			var raw_objs: Variant = s.get("objectives", [])
			stage_objectives = raw_objs if raw_objs is Array else []
			break

	# REALM-005: Compute virtue-based stage bonus
	var realm_virtue  := str(realm_model.get("virtue", ""))
	var run_index     := int(realm_model.get("run_index", 0))
	var stage_reward_data: Dictionary = RealmService.calculate_stage_reward(
		stage_index, realm_virtue, run_index, reward_cfg
	)
	var virtue_bonus   := int(stage_reward_data.get("virtue_bonus", 0))
	var formula_inputs: Dictionary = stage_reward_data.get("formula_inputs", {})

	# LOG_ECONOMY_REWARD: confirms formula_inputs (REALM-005 DoD point 4)
	if flow_ctx.logger != null:
		flow_ctx.logger.info(t, "economy.stage.reward", "Stage reward formula", formula_inputs)

	# ECONOMY-004: Compute and pay reward
	var run_count := int(realm_model.get("run_count", 0))
	var victory   := bool(combat_result.get("victory", false))
	var round_ended := int(combat_result.get("round_ended", 0))

	var reward_data: Dictionary = RewardCalc.compute(
		victory,
		stage_objectives,
		enemies_defeated,
		total_enemies,
		echoes_survived,
		total_echoes,
		round_ended,
		run_count,
		reward_cfg
	)

	var economy_svc := EconomyService.new(flow_ctx.save_data)
	var reward_result: Dictionary = economy_svc.reward_stage_complete(
		victory,
		int(reward_data.get("base_reward", 0)),
		int(reward_data.get("enemy_bonus", 0)),
		enemies_defeated,
		int(reward_data.get("echo_bonus", 0)),
		echoes_survived,
		int(reward_data.get("speed_bonus", 0)),
		float(reward_data.get("redo_multiplier", 1.0)),
		str(reward_data.get("rank", "F")),
		virtue_bonus,
		flow_ctx.logger,
		t
	)

	# Trigger save — Ase is now in save data and must persist
	flow_ctx.save_request = true
	if flow_ctx.save_request_reason != "":
		flow_ctx.save_request_reason += "|stage.reward"
	else:
		flow_ctx.save_request_reason = "stage.reward"

	# PROG-003: award XP and check level-ups for all party echoes.
	var xp_events: Array = []
	var prog_cfg_v: Variant = {}
	var birth_stats_v: Variant = {}
	if flow_ctx.config_service != null:
		var bal_p: Dictionary = flow_ctx.config_service.get_balance()
		var bd_p: Dictionary  = bal_p.get("data", {})
		prog_cfg_v   = bd_p.get("progression", {})
		birth_stats_v = bd_p.get("summoning", {}).get("birth_stats", {})
	var prog_cfg_d: Dictionary   = prog_cfg_v if prog_cfg_v is Dictionary else {}
	var birth_stats_d: Dictionary = birth_stats_v if birth_stats_v is Dictionary else {}

	# Detect realm completion: is this the final stage?
	var stage_count: int = int(realm_model.get("stage_count", 1))
	var realm_complete_now: bool = victory and (stage_index >= stage_count - 1)

	var echo_logs: Dictionary = {}
	if ectx != null:
		echo_logs = ectx.echo_action_logs
		# PROG-004: mark survived=false for any echo that was KO'd during the encounter.
		# Defaults to true (set when entry is first created in echo_action_logs).
		# Used by ProgressionService to compute the faith virtue XP multiplier.
		for actor_v in ectx.actors:
			if not actor_v is Dictionary:
				continue
			if str(actor_v.get("faction", "")) != "echo":
				continue
			var eid: String = str(actor_v.get("id", ""))
			if echo_logs.has(eid):
				if bool(actor_v.get("is_dead", false)):
					echo_logs[eid]["survived"] = false
				elif not echo_logs[eid].has("survived"):
					echo_logs[eid]["survived"] = true

	# XP tuning: compute realm XP multiplier from campaign position (run_index).
	# run_index = how many times this realm has been started (campaign difficulty proxy).
	var realm_xp_mult: float = 1.0
	var mult_rate: float = float(prog_cfg_d.get("realm_xp_multiplier_per_realm", 0.0))
	if mult_rate > 0.0:
		realm_xp_mult = 1.0 + float(run_index) * mult_rate

	# XP tuning: kill XP was already applied mid-combat — skip it here to avoid double-count.
	xp_events = ProgressionService.award_post_combat_xp(
		flow_ctx.save_data,
		echo_logs,
		victory,
		realm_complete_now,
		prog_cfg_d,
		birth_stats_d,
		flow_ctx.logger,
		t,
		realm_xp_mult,
		true
	)

	# XP mutations are covered by the save_request set above.
	if flow_ctx.save_request_reason != "" and not xp_events.is_empty():
		flow_ctx.save_request_reason += "|progression.xp"

	# Bug fix (PROG-003): sync final combat emotion state back to roster so EchoParty
	# reflects the actual fear/morale echoes accumulated during the encounter.
	# The win/loss drift in _apply_encounter_emotion_drift() then applies on top.
	if ectx != null:
		var em_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
		var em_sanctum: Dictionary = em_sanctum_v if em_sanctum_v is Dictionary else {}
		var em_roster_v: Variant = em_sanctum.get("roster", [])
		var em_roster: Array = em_roster_v if em_roster_v is Array else []
		for actor_v in ectx.actors:
			if not actor_v is Dictionary:
				continue
			if str(actor_v.get("faction", "")) != "echo":
				continue
			var eid: String = str(actor_v.get("id", ""))
			for i in range(em_roster.size()):
				if em_roster[i] is Dictionary and str(em_roster[i].get("id", "")) == eid:
					if not em_roster[i].has("emotion"):
						em_roster[i]["emotion"] = {}
					em_roster[i]["emotion"]["fear_current"]   = int(actor_v.get("fear", 0))
					em_roster[i]["emotion"]["morale_current"] = int(actor_v.get("morale", 0))
					break

	return {
		"type": FlowStateIds.RESOLVE,
		"data": {
			"title":            "Result",
			"encounter_id":     encounter_id,
			"actors":           projected_actors,
			"objective_state":  FlowEncounterState._build_objective_state(ectx, combat_state),
			"victory":          victory,
			"reason":           str(combat_result.get("reason", "")),
			"round_ended":      round_ended,
			"enemies_defeated": enemies_defeated,
			"echoes_survived":  echoes_survived,
			"ase_awarded":      int(reward_result.get("ase_awarded", 0)),
			"rank":             str(reward_result.get("rank", "F")),
			"reward_breakdown": reward_result.get("breakdown", []),
			"formula_inputs":   formula_inputs,
			"relics":           [],
			# PROG-003: per-echo XP events for ResolveScreen and EchoParty display.
			"xp_events":        xp_events,
		},
		"actions": _build_resolve_actions(victory),
		"meta": { "t": t },
	}


# Fix BUG-004: cta.next_stage only offered on victory — defeat should not advance the stage.
# Bug fix: on victory, cta.continue also advances the stage (destination overrides routing to SANCTUM).
# On defeat, cta.continue is a plain go_state — no stage advance.
static func _build_resolve_actions(victory: bool) -> Dictionary:
	var actions: Dictionary = {}
	if victory:
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
		actions["cta.continue"] = {
			"type":  "flow.go_state",
			"to":    FlowStateIds.SANCTUM,
			"label": "To Sanctum",
			"slot":  "cta.continue",
		}
	return actions

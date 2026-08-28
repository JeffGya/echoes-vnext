# res://core/combat/EncounterSetupService.gd
# V2-INFRA-003 Phase 6 Slice 6I: ENCOUNTER SETUP, moved verbatim out of
# core/state/flow/states/venture/FlowEncounterState.gd::enter() (lines :11-:992, of which
# :12-:990 were setup and the last line built the snapshot). That method was 982 lines — the
# largest single function left in the repo after Phase 6 slices A-H.
#
# WHAT THIS IS. Everything that turns a save file, a realm model and balance.json into a board
# ready for the first round, in the order it ran before the move and still runs now:
#
#    1. EncounterContext + EncounterStateMachine creation, resolution-mode resolution
#    2. grid_cfg + initiative_cfg read                                    (GRID-001, COMBAT-002)
#    3. party actor build + pre-encounter morale capture                  (GRID-002, V2-EMOTION-001)
#    4. enemy count derivation, spawn-group selection, enemy actor build  (V2-COMBAT-001)
#    5. board sizing (PURSUE / GUIDE_SPIRIT long-board overrides) + terrain generation
#    6. seeded placement of party and enemies                             (GRID-003)
#    7. shrine spawn                              -> EncounterObjectiveSpawnService
#    8. objective_params derivation + charge-pressure consumption         (writes save)
#    9. objective actor spawn                     -> EncounterObjectiveSpawnService
#   10. surprise fear bump for an unscouted approach
#   11. all_actors assembly
#   12. temporary-ally auto-join                                          (writes save)
#   13. unique-id repair, ectx handover, purifier selection, spawn logging
#
# What did NOT come with it: the final line of enter(), which builds the round snapshot. That
# stays on the state, because building a snapshot is what a flow state does.
#
# WHY THIS IS A SERVICE AND NOT A BUILDER. Steps 8 and 12 each call
# flow_ctx.request_save(...) — "encounter.charge_pressure_consumed" and
# "encounter.ally_joined" — and step 12 writes the stage back through
# FlowStageExploreState._write_stage_back(). Setup is not a pure function of its inputs and
# cannot be made one without a behaviour change. Both saves are queued from inside the
# dispatch that transitions into ENCOUNTER (FlowStateMachine.transition_to runs inside
# FlowRuntime.dispatch), which is exactly where they landed before the move, so the reason
# string they join with "|" is unchanged. Requesting a save through flow_ctx — never through
# SaveService — is what the Phase 6 contract permits a service to do.
#
# WHY core/combat/. The output is a combat board. It files beside CombatRoundSpawnService,
# ShrineService and CombatTurnContextService, the other Phase 6 combat helpers, and beside
# EncounterObjectiveSpawnService, which it constructs.
#
# CONTRACT (same as every Phase 6 sibling):
#   - Typed RefCounted. Explicit dependencies at construction — no autoloads, no service
#     locator, no reaching back into FlowRuntime.
#   - NO flow_machine. This class cannot transition state or rebuild a snapshot. It writes
#     flow_ctx.encounter_ctx and flow_ctx.encounter_machine, which are encounter-scoped
#     containers, never the flow state machine.
#   - Never calls SaveService. The two saves are REQUESTS, via flow_ctx.request_save().
#   - Calls no controller.
#
# CONSTRUCTOR NOTE. config_service and logger are declared UNTYPED, deliberately. FlowContext
# declares both untyped itself (FlowContext.gd:51,53) and test harnesses substitute mock
# config objects into ctx.config_service; typing them here would impose a constraint the
# pre-extraction code did not have. Both fields exist for signature parity with the Phase 6
# siblings; the moved body reads flow_ctx.config_service and flow_ctx.logger verbatim, as it
# did before, and that is preserved rather than "tidied" because the two can in principle
# differ.
#
# WHAT IT TOUCHES — the complete read/write set, established by reading every line rather
# than trusting the brief:
#
#   READS  (save data)
#     sanctum.active_party_ids, sanctum.roster (id, emotion.morale_current, and every field
#         EchoActor.from_echo consumes)
#     realms.<id>.is_completed                    -> completion_index
#     stage_context.encounter_approach.situation_was_revealed
#     the active realm model, via RealmService.get_active(flow_ctx): seed, virtue, stages[]
#         (index, objectives[].type, objectives[].params)
#     the current stage's explore_map, via FlowStageExploreState._get_current_stage:
#         hostile_charge_sit_id, ally_contact, ally_consumed_in_encounter
#
#   READS  (flow_ctx)
#     encounter_id, stage_id, active_encounter_objective_index, campaign_seed,
#     config_service, logger, dev_combat_objective, dev_guide_mode, dev_guide_joins
#
#   READS  (balance.json)
#     data.grid                                   board dims + placement_modifiers
#     data.combat.initiative_modifiers            -> ectx.initiative_cfg
#     data.combat.enemy_spawn_config              counts, thresholds, group selection
#     data.combat.board                           base/max cols+rows, growth, pursue_override,
#                                                 guide_spirit_override
#     data.combat.charge_pressure                 protect_duration_bonus, endure_wave_bonus
#     data.combat.objective_modes.<mode>          scaled objective params (see D30)
#     data.combat.encounter_approach.surprise_fear
#     data.contact.ally                           level_base / growth / max, ally build cfg
#     data.stages                                 terrain signature, via RealmGenerator
#     data.maturity_expression                    passed to LeadershipEmotionService
#     data.actor.birth_stats + data.actor.enemy_types, via ConfigService.get_enemy_actor_cfg
#     actors.json data.enemies + data.groups, via config_service.get_actors()
#
#   WRITES (flow_ctx.encounter_ctx)
#     encounter_id, resolution_mode, initiative_cfg, pre_encounter_morale, terrain,
#     objective_params, charge_pressure_applied, actors, placement_seed, purifier_id
#
#   WRITES (flow_ctx)
#     encounter_ctx (created), encounter_machine (created), save_request +
#     save_request_reason (twice, via request_save)
#
#   WRITES (save data)
#     the current stage's explore_map.hostile_charge_sit_id -> "" (charge pressure consumed)
#     the current stage's explore_map.ally_consumed_in_encounter -> true (ally joined)
#     both through FlowStageExploreState._write_stage_back
#
#   NOT TOUCHED: flow_ctx.last_snapshot (the caller sets it), flow_ctx.flow_machine,
#   ectx.combat_state (it does not exist yet — CombatState.create() runs later, in
#   EncounterRoundsState.enter()), ectx.round_bark_events, ectx.echo_action_logs, and the
#   economy.
#
#   INDIRECT CALLS: EchoActor.from_echo, EnemyActor.from_definition, StructureActor
#   .from_definition, ContactActorBuilder.build, GridService.place_actors, StageTerrain
#   .generate / .walkable_set, RealmGenerator._resolve_terrain_signature, RealmService
#   .get_active, ShrineService.select_purifier, LeadershipEmotionService.apply_fear_gain,
#   ConfigService.get_enemy_actor_cfg, FlowStageExploreState._get_current_stage /
#   _write_stage_back, and EncounterObjectiveSpawnService. None of them is a controller.
#
# DETERMINISM — the strongest constraint on this file. Setup is where most encounter
# randomness happens. Four seeded generators are drawn here and two more inside
# EncounterObjectiveSpawnService. No seed path string changed, no draw was added, removed or
# reordered inside any single generator:
#     "combat.pursue_board." + encounter_id        1 draw, PURSUE board orientation
#     "combat.guide_spirit_board." + encounter_id  1 draw, GUIDE_SPIRIT board orientation
#     "combat.terrain." + encounter_id             passed to StageTerrain.generate as a
#                                                  namespace; that generator owns its own order
#     "combat.placement." + encounter_id           derive() for placement_seed, then get_rng()
#                                                  for GridService.place_actors — TWO calls on
#                                                  the same path, in that order, preserved
# Every other ordering here is a total order over sorted data, not a draw. The party actor
# list is sorted by id and the enemy list is sorted by id before placement, and both sorts are
# kept exactly where they were. No dispatch is added or removed — the retreat roll's seed path
# embeds the sim tick, so a changed dispatch count would move every retreat result in the game.
#
# _ensure_unique_actor_ids IS LOAD-BEARING FOR DETERMINISM, not only for the freeze bug it was
# written for: initiative derives a per-actor tiebreak from the actor id, so a repaired id
# changes turn order. It runs after the ally append and before ectx.actors is handed over,
# which is where it ran before.
#
# NO SHIM WAS LEFT (AGENTS.md #20). Three statics came with the setup they belong to —
# _ensure_unique_actor_ids and _resolve_mode_from_stage had no caller outside enter(), and
# resolve_objective_params had 25 call sites in tests/ObjectiveCombatTests.gd, every one of
# which was repointed to this class in the same change.
#
# DEFECT NOTES — recorded in docs/v2-infra-003-defect-register.md, deliberately NOT fixed:
# D30 (data.combat.objective_modes still has no ConfigService owner; the read MOVED here, so
# the site count is unchanged), D17 (answered from this call site: escort destination and
# spirit spawn CAN coincide, via the relaxation branch), D79 (the depth-scaled placement
# routine written out six times), D80 (GUIDE_SPIRIT escort on a legacy no-terrain board gets
# destination -1,-1 and can never complete).

class_name EncounterSetupService
extends RefCounted

const LeadershipEmotionService = preload("res://core/combat/LeadershipEmotionService.gd")

var flow_ctx: FlowContext
var config_service
var logger


func _init(_flow_ctx: FlowContext, _config_service = null, _logger = null) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


## Runs once per transition into the ENCOUNTER flow state, from FlowEncounterState.enter().
## Idempotent in the same two ways it always was: the EncounterContext and the
## EncounterStateMachine are created only when absent, and the whole board build is gated on
## ectx.phase_snapshot being empty, so a re-entry mid-encounter rebuilds nothing.
func setup(t: int) -> void:

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
			# V2-EMOTION-001: capture pre-encounter morale per echo for resolve delta.
			for echo_v2 in roster:
				var echo_2: Dictionary = echo_v2 if echo_v2 is Dictionary else {}
				if str(echo_2.get("id", "")) in party_ids:
					var _emo_e: Dictionary = echo_2.get("emotion", {})
					flow_ctx.encounter_ctx.pre_encounter_morale[str(echo_2.get("id", ""))] = \
						int(_emo_e.get("morale_current", 50))
		echo_actors.sort_custom(func(a, b): return a["id"] < b["id"])

		# V2-COMBAT-001: config-driven enemy spawn via actors.json spawn groups.
		# BALANCE-001: pass birth_stats + enemy_types cfg so EnemyActor uses DerivedStatService.
		var actor_cfg: Dictionary = {}
		var spawn_cfg: Dictionary = {}
		var actors_json: Dictionary = {}
		if flow_ctx.config_service != null:
			var bal: Dictionary  = flow_ctx.config_service.get_balance()
			var bd: Dictionary   = bal.get("data", {})
			# V2-INFRA-003 Phase 6 Slice 6B: the { birth_stats, enemy_types } assembly now has
			# one owner (ConfigService.get_enemy_actor_cfg). Same dict, same keys as before.
			actor_cfg = ConfigService.get_enemy_actor_cfg(flow_ctx.config_service)
			spawn_cfg = bd.get("combat", {}).get("enemy_spawn_config", {})
			actors_json = flow_ctx.config_service.get_actors()

		# Derive realm completion index (how many realms fully completed).
		var completion_index: int = 0
		var realms_data: Dictionary = flow_ctx.save_data.get("realms", {})
		for realm_id_key in realms_data:
			var rm: Dictionary = realms_data[realm_id_key] if realms_data[realm_id_key] is Dictionary else {}
			if rm.get("is_completed", false):
				completion_index += 1
		var idx_key: String = str(mini(completion_index, 2))

		# Derive stage index from stage_id ("stage.N" format).
		var stage_index: int = 0
		var sid := str(flow_ctx.stage_id)
		var dot_pos: int = sid.rfind(".")
		if dot_pos >= 0:
			stage_index = int(sid.substr(dot_pos + 1))

		# Compute enemy count from config.
		var base_count: int = int(spawn_cfg.get("base_count_by_completion_index", {}).get(idx_key, \
			spawn_cfg.get("default_base_count", 1)))
		var mid_thresh: int  = int(spawn_cfg.get("stage_mid_threshold", 2))
		var late_thresh: int = int(spawn_cfg.get("stage_late_threshold", 3))
		var max_count: int   = int(spawn_cfg.get("max_count", 4))
		if stage_index >= mid_thresh:
			base_count += int(spawn_cfg.get("mid_count_bonus", 1))
		if stage_index >= late_thresh:
			base_count += int(spawn_cfg.get("late_count_bonus", 1))
		var enemy_count: int = mini(base_count, max_count)

		# Select spawn group and build enemy actors.
		var actors_data: Dictionary = actors_json.get("data", {})
		var enemies_dict: Dictionary = actors_data.get("enemies", {})
		var groups_dict: Dictionary  = actors_data.get("groups", {})
		var group_id: String = str(spawn_cfg.get("group_by_completion_index", {}).get(idx_key, \
			spawn_cfg.get("default_group", "group.vale_patrol_sm")))
		var group_def: Dictionary = groups_dict.get(group_id, {})
		var enemy_actors: Array = []
		if not group_def.is_empty():
			var spawns: Array = group_def.get("spawns", [])
			var built: int = 0
			for spawn_v in spawns:
				if built >= enemy_count: break
				if not (spawn_v is Dictionary): continue
				var template_id: String = str(spawn_v.get("template_id", ""))
				var spawn_count: int = int(spawn_v.get("count", 1))
				var tmpl: Dictionary = enemies_dict.get(template_id, {})
				if tmpl.is_empty(): continue
				for _si in range(spawn_count):
					if built >= enemy_count: break
					# EnemyActor.from_definition() needs "type" to look up in balance.json enemy_types.
					# actors.json ID is "enemy.X" — strip prefix to get the balance.json key.
					var type_key: String = template_id
					if type_key.begins_with("enemy."):
						type_key = type_key.substr(6)
					var defn: Dictionary = {
						"id":      template_id + "_" + str(built + 1),
						"name":    str(tmpl.get("name", template_id)),
						"type":    type_key,
						"faction": "enemy",
					}
					enemy_actors.append(EnemyActor.from_definition(defn, t, actor_cfg))
					built += 1
		if enemy_actors.is_empty():
			# Fallback: use hardcoded stub if spawn groups not yet populated.
			enemy_actors.append(EnemyActor.from_definition(
				{ "id": "enemy_guardian_01", "name": "Guardian", "type": "guardian", "faction": "enemy" }, t, actor_cfg))
		enemy_actors.sort_custom(func(a, b): return a["id"] < b["id"])
		# V2-STAGE-004 P3b: PURSUE spawns quarry only — no regular enemy group.
		if flow_ctx.encounter_ctx.resolution_mode == EncounterResolutionModes.PURSUE:
			enemy_actors = []

		# V2-STAGE-004 P3a: Generate irregular combat-board terrain.
		# Guard: keeper_intro and any encounter without an active realm model fall back to
		# the legacy path (no terrain generated, grid_cfg used as-is → legacy 10×10).
		var grid_cfg_for_placement: Dictionary = grid_cfg
		var active_realm_model: Dictionary = RealmService.get_active(flow_ctx)
		if not active_realm_model.is_empty() \
				and flow_ctx.encounter_ctx.encounter_id != "keeper_intro.first_trial":
			# Read realm_seed and virtue from the stored model.
			var cb_realm_seed: int    = int(active_realm_model.get("seed", 0))
			var cb_realm_virtue: String = str(active_realm_model.get("virtue", ""))

			# Resolve terrain signature the same way RealmGenerator does.
			var cb_stages_cfg: Dictionary = {}
			if flow_ctx.config_service != null:
				var cb_bal: Dictionary = flow_ctx.config_service.get_balance()
				cb_stages_cfg = cb_bal.get("data", {}).get("stages", {})
			var cb_realm_cfg: Dictionary = { "virtue": cb_realm_virtue }
			var cb_signature: Dictionary = RealmGenerator._resolve_terrain_signature(cb_realm_cfg, cb_stages_cfg)

			# Compute board bounds scaled by realm completion order.
			# completion_index (already computed above) = number of fully completed realms.
			var cb_board_cfg_block: Dictionary = {}
			if flow_ctx.config_service != null:
				var cb_bal2: Dictionary = flow_ctx.config_service.get_balance()
				cb_board_cfg_block = cb_bal2.get("data", {}).get("combat", {}).get("board", {})
			var cb_base_cols: int = int(cb_board_cfg_block.get("base_cols",          12))
			var cb_base_rows: int = int(cb_board_cfg_block.get("base_rows",          12))
			var cb_growth:    int = int(cb_board_cfg_block.get("growth_per_completion", 1))
			var cb_max_cols:  int = int(cb_board_cfg_block.get("max_cols",            22))
			var cb_max_rows:  int = int(cb_board_cfg_block.get("max_rows",            22))
			var cb_cols: int = mini(cb_base_cols + completion_index * cb_growth, cb_max_cols)
			var cb_rows: int = mini(cb_base_rows + completion_index * cb_growth, cb_max_rows)
			# V2-STAGE-004 P3b: PURSUE board is 2× one dimension, randomised per encounter seed.
			if flow_ctx.encounter_ctx.resolution_mode == EncounterResolutionModes.PURSUE:
				var _pur_override: Dictionary = cb_board_cfg_block.get("pursue_override", {})
				var _pur_mul: float = float(_pur_override.get("long_multiplier", 2.0))
				var _pur_rng := RandomNumberGenerator.new()
				if flow_ctx.campaign_seed != null:
					_pur_rng = flow_ctx.campaign_seed.get_rng(
						"combat.pursue_board." + flow_ctx.encounter_ctx.encounter_id)
				else:
					_pur_rng.seed = hash("pursue_board_" + flow_ctx.encounter_ctx.encounter_id)
				if _pur_rng.randi() % 2 == 0:
					cb_cols = int(float(cb_cols) * _pur_mul)
				else:
					cb_rows = int(float(cb_rows) * _pur_mul)
			# V2-STAGE-004 P3c: GUIDE_SPIRIT board is 5× one dimension, randomised per encounter seed.
			# Same mechanism as the PURSUE override above — both "long board" objectives.
			if flow_ctx.encounter_ctx.resolution_mode == EncounterResolutionModes.GUIDE_SPIRIT:
				var _gsb_override: Dictionary = cb_board_cfg_block.get("guide_spirit_override", {})
				var _gsb_mul: float = float(_gsb_override.get("long_multiplier", 5.0))
				var _gsb_rng := RandomNumberGenerator.new()
				if flow_ctx.campaign_seed != null:
					_gsb_rng = flow_ctx.campaign_seed.get_rng(
						"combat.guide_spirit_board." + flow_ctx.encounter_ctx.encounter_id)
				else:
					_gsb_rng.seed = hash("guide_spirit_board_" + flow_ctx.encounter_ctx.encounter_id)
				if _gsb_rng.randi() % 2 == 0:
					cb_cols = int(float(cb_cols) * _gsb_mul)
				else:
					cb_rows = int(float(cb_rows) * _gsb_mul)
			var cb_bounds: Dictionary = { "w": cb_cols, "h": cb_rows }

			# Generate terrain on a separate append-only RNG namespace.
			var cb_terrain: Dictionary = StageTerrain.generate(
				cb_realm_seed,
				stage_index,
				cb_signature,
				cb_bounds,
				"combat.terrain." + flow_ctx.encounter_ctx.encounter_id
			)
			flow_ctx.encounter_ctx.terrain = cb_terrain

			# Build terrain-aware grid_cfg (duplicate so original is untouched).
			var cb_walkable: Dictionary = StageTerrain.walkable_set(cb_terrain)
			grid_cfg_for_placement = grid_cfg.duplicate(true)
			grid_cfg_for_placement["walkable"]   = cb_walkable
			grid_cfg_for_placement["board_cols"] = cb_cols
			grid_cfg_for_placement["board_rows"] = cb_rows

		# GRID-003: deterministic seeded placement.
		var place_cfg: Dictionary = grid_cfg_for_placement.get("placement_modifiers", {})
		var placement_seed: int = 0
		var rng := RandomNumberGenerator.new()
		if flow_ctx.campaign_seed != null:
			placement_seed = flow_ctx.campaign_seed.derive(
				"combat.placement." + flow_ctx.encounter_ctx.encounter_id)
			rng = flow_ctx.campaign_seed.get_rng(
				"combat.placement." + flow_ctx.encounter_ctx.encounter_id)
		else:
			rng.seed = hash(flow_ctx.encounter_ctx.encounter_id)

		GridService.place_actors(echo_actors, enemy_actors, grid_cfg_for_placement, rng, place_cfg)

		# V2-INFRA-003 Phase 6 Slice 6I: the two objective-actor spawn blocks that used to sit
		# inline here now live in EncounterObjectiveSpawnService. Same bodies, same order, same
		# seed paths — see that file's header for the full read/write set.
		var _obj_spawn := EncounterObjectiveSpawnService.new(flow_ctx, config_service, logger)

		# COMBAT-006: spawn shrine actor if objective is purify_shrine.
		var _shrine_result: Dictionary = _obj_spawn.spawn_shrine(
			echo_actors, enemy_actors, completion_index, t)
		var shrine_actor: Dictionary = _shrine_result["shrine_actor"]
		var shrine_cfg: Dictionary   = _shrine_result["shrine_cfg"]

		# V2-STAGE-004 P3: Compute scaled objective_params for RECOVER/PROTECT/ENDURE modes.
		# For COMBAT/PURIFY_SHRINE/others: objective_params stays {}.
		# Uses resolve_objective_params() pure static helper (float growth + roundi to avoid int(0.5)==0 truncation).
		var _obj_mode_key: String = ""
		match flow_ctx.encounter_ctx.resolution_mode:
			EncounterResolutionModes.RECOVER:  _obj_mode_key = "recover"
			EncounterResolutionModes.PROTECT:  _obj_mode_key = "protect"
			EncounterResolutionModes.ENDURE:   _obj_mode_key = "endure"
			EncounterResolutionModes.PURSUE:   _obj_mode_key = "pursue"
			EncounterResolutionModes.GUIDE_SPIRIT: _obj_mode_key = "guide_spirit"
		if not _obj_mode_key.is_empty():
			var _om_data: Dictionary = {}
			if flow_ctx.config_service != null:
				var _om_bal: Dictionary = flow_ctx.config_service.get_balance()
				_om_data = _om_bal.get("data", {})
			var _om_cfg: Dictionary = ConfigService.get_objective_modes_cfg(
				flow_ctx.config_service).get(_obj_mode_key, {})
			# Read stage-level objective params override (non-empty overrides scaled values).
			var _om_stage_params: Dictionary = {}
			var _om_realm_model: Dictionary = RealmService.get_active(flow_ctx)
			if not _om_realm_model.is_empty():
				var _om_sid := str(flow_ctx.stage_id)
				var _om_stage_index: int = 0
				if _om_sid.contains("."):
					var _om_parts := _om_sid.split(".")
					_om_stage_index = int(_om_parts[_om_parts.size() - 1])
				var _om_stages_v: Variant = _om_realm_model.get("stages", [])
				var _om_stages: Array = _om_stages_v if _om_stages_v is Array else []
				var _om_obj_idx: int = flow_ctx.active_encounter_objective_index
				for _om_sv in _om_stages:
					var _om_s: Dictionary = _om_sv if _om_sv is Dictionary else {}
					if int(_om_s.get("index", -1)) == _om_stage_index:
						var _om_objs_v: Variant = _om_s.get("objectives", [])
						var _om_objs: Array = _om_objs_v if _om_objs_v is Array else []
						if _om_obj_idx >= 0 and _om_obj_idx < _om_objs.size() and _om_objs[_om_obj_idx] is Dictionary:
							var _om_op_v: Variant = (_om_objs[_om_obj_idx] as Dictionary).get("params", {})
							if _om_op_v is Dictionary and not (_om_op_v as Dictionary).is_empty():
								_om_stage_params = _om_op_v as Dictionary
						break
			flow_ctx.encounter_ctx.objective_params = \
				EncounterSetupService.resolve_objective_params(_obj_mode_key, _om_cfg, completion_index, _om_stage_params)

			# V2-STAGE-004 Phase 4 (S13): Charge pressure — a failed non-objective Charge sets
			# explore_map.hostile_charge_sit_id (FlowRuntime._apply_contact_outcome charge branch).
			# Applied AFTER the completion-index scaling above; consumed exactly once by the first
			# PROTECT/ENDURE objective combat that reads it, then cleared. Other modes ignore it —
			# it stays set until a protect/endure fight consumes it (intended, per design).
			if _obj_mode_key == "protect" or _obj_mode_key == "endure":
				var _cp_stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
				if not _cp_stage.is_empty():
					var _cp_map_v: Variant = _cp_stage.get("explore_map", {})
					var _cp_map: Dictionary = _cp_map_v if _cp_map_v is Dictionary else {}
					var _cp_sit_id := str(_cp_map.get("hostile_charge_sit_id", ""))
					if not _cp_sit_id.is_empty():
						match _obj_mode_key:
							"protect":
								var _cp_bonus: int = int(_om_data.get("combat", {}).get("charge_pressure", {}).get("protect_duration_bonus", 0))
								var _cp_max: int = int(_om_cfg.get("duration_max", flow_ctx.encounter_ctx.objective_params.get("duration_turns", 0)))
								flow_ctx.encounter_ctx.objective_params["duration_turns"] = clampi(
									int(flow_ctx.encounter_ctx.objective_params.get("duration_turns", 0)) + _cp_bonus,
									0, _cp_max)
							"endure":
								var _cp_bonus2: int = int(_om_data.get("combat", {}).get("charge_pressure", {}).get("endure_wave_bonus", 0))
								var _cp_max2: int = int(_om_cfg.get("wave_size_max", flow_ctx.encounter_ctx.objective_params.get("wave_size", 0)))
								flow_ctx.encounter_ctx.objective_params["wave_size"] = clampi(
									int(flow_ctx.encounter_ctx.objective_params.get("wave_size", 0)) + _cp_bonus2,
									0, _cp_max2)
						# V2-STAGE-004 S15 prep: durable per-encounter flag so the objective_state
						# projection can surface "charge_pressure_applied" for THIS encounter only.
						flow_ctx.encounter_ctx.charge_pressure_applied = true
						_cp_map["hostile_charge_sit_id"] = ""
						_cp_stage["explore_map"] = _cp_map
						FlowStageExploreState._write_stage_back(flow_ctx, _cp_stage)
						flow_ctx.request_save("encounter.charge_pressure_consumed")
						if flow_ctx.logger != null:
							flow_ctx.logger.info(t, "combat.charge_pressure.applied",
								"Charge pressure applied to objective combat", {
									"mode":         _obj_mode_key,
									"situation_id": _cp_sit_id,
								})

		# V2-STAGE-004 P3: Spawn objective structure actor for RECOVER / PROTECT modes.
		# ENDURE spawns no objective actor (wave-only). Shrine path is unchanged above.
		var objective_actor: Dictionary = _obj_spawn.spawn_objective_actor(
			echo_actors, enemy_actors, actor_cfg, completion_index, t)

		# V2-STAGE-004 P3: Surprise fear bump — unscouted encounter approach.
		# Applied to echo actors only, after they are built and before all_actors assembly.
		# Guard: approach dict must be non-empty AND situation_was_revealed must be false.
		var _ea_approach_ctx: Dictionary = flow_ctx.save_data.get("stage_context", {}).get("encounter_approach", {})
		if not _ea_approach_ctx.is_empty() and not bool(_ea_approach_ctx.get("situation_was_revealed", true)):
			var _ea_data: Dictionary = {}
			if flow_ctx.config_service != null:
				var _ea_bal: Dictionary = flow_ctx.config_service.get_balance()
				_ea_data = _ea_bal.get("data", {})
			var _ea_bump: int = int(_ea_data.get("combat", {}).get("encounter_approach", {}).get("surprise_fear", 0))
			if _ea_bump > 0:
				var _ea_expr_cfg: Dictionary = _ea_data.get("maturity_expression", {})
				for _ea_i in range(echo_actors.size()):
					var _ea_actor: Dictionary = echo_actors[_ea_i]
					var _ea_applied := LeadershipEmotionService.apply_fear_gain(
						_ea_actor, _ea_bump, echo_actors, _ea_expr_cfg)
					echo_actors[_ea_i]["fear"] = clampi(
						int(_ea_actor.get("fear", 0)) + _ea_applied, 0, 100)

		# COMBAT-001: store placed actors and seed on ectx for snapshot rebuilds.
		var all_actors: Array = echo_actors + enemy_actors
		if not shrine_actor.is_empty():
			all_actors.append(shrine_actor)
		if not objective_actor.is_empty():
			all_actors.append(objective_actor)

		# V2-STAGE-004 Phase 4 (S12): Temporary Ally auto-join. Mirrors the GUIDE_SPIRIT
		# joined-spirit injection above — build via ContactActorBuilder (EnemyActor.from_definition,
		# faction "echo"), append to all_actors BEFORE _ensure_unique_actor_ids. Gated on a durable
		# ally_contact set by FlowRuntime._apply_contact_outcome's temporary_ally/good branch AND
		# not yet consumed this stage session — one battle only.
		var _ally_stage: Dictionary = FlowStageExploreState._get_current_stage(flow_ctx)
		if not _ally_stage.is_empty():
			var _ally_map_v: Variant = _ally_stage.get("explore_map", {})
			var _ally_map: Dictionary = _ally_map_v if _ally_map_v is Dictionary else {}
			var _ally_contact_v: Variant = _ally_map.get("ally_contact", {})
			var _ally_contact: Dictionary = _ally_contact_v if _ally_contact_v is Dictionary else {}
			if not _ally_contact.is_empty() and not bool(_ally_map.get("ally_consumed_in_encounter", false)):
				var _ally_bal_cfg: Dictionary = {}
				if flow_ctx.config_service != null:
					var _ally_bal: Dictionary = flow_ctx.config_service.get_balance()
					_ally_bal_cfg = _ally_bal.get("data", {}).get("contact", {}).get("ally", {})
				# Level scaled by realm completion — same completion_index + clamp pattern as
				# resolve_objective_params() below (base + growth*completion_index, clamped).
				var _ally_lvl_base: int    = int(_ally_bal_cfg.get("level_base", 1))
				var _ally_lvl_growth: float = float(_ally_bal_cfg.get("level_growth_per_completion", 0.0))
				var _ally_lvl_max: int     = int(_ally_bal_cfg.get("level_max", _ally_lvl_base))
				var _ally_level: int = clampi(
					_ally_lvl_base + roundi(_ally_lvl_growth * float(completion_index)),
					_ally_lvl_base, _ally_lvl_max)
				var _ally_build_cfg: Dictionary = _ally_bal_cfg.duplicate()
				_ally_build_cfg["actor_cfg"] = actor_cfg
				var _ally_actor: Dictionary = ContactActorBuilder.build(
					_ally_contact, _ally_build_cfg, t, _ally_level)

				# BUGFIX (playtest): place_actors() (line ~237) already ran before this block,
				# so _ally_actor still carries EnemyActor.from_definition's grid_pos placeholder
				# { col:0, row:0 } (core/actors/EnemyActor.gd:75). On irregular terrain boards
				# that cell is VOID (outside StageTerrain's walkable set), which strands the ally
				# off-board with no legal move (GridService.move_toward roots over the walkable
				# set). Assign a real walkable, unoccupied, party-side cell here via
				# GridService.place_on_terrain(), targeting proximity to the party's centroid
				# instead of a depth-scaled column. Legacy full-rect boards (grid_cfg_for_placement
				# has no "walkable" key) are untouched — (0,0) is a normal, non-void, unoccupied
				# cell there (echoes fill from col=1 inward), so the ally still "just works".
				var _ally_walkable: Dictionary = grid_cfg_for_placement.get("walkable", {})
				if not _ally_walkable.is_empty():
					var _ally_spawned: Array = []
					if not shrine_actor.is_empty():
						_ally_spawned.append(shrine_actor)
					if not objective_actor.is_empty():
						_ally_spawned.append(objective_actor)
					var _ally_occupied: Dictionary = GridService.occupied_cells(
						[echo_actors, enemy_actors, _ally_spawned])

					# Party centroid — place the ally near the echoes it's fighting alongside.
					var _ally_centroid_col: float = 0.0
					var _ally_centroid_row: float = 0.0
					if not echo_actors.is_empty():
						for _ao_v in echo_actors:
							if _ao_v is Dictionary:
								var _ag: Dictionary = _ao_v.get("grid_pos", {})
								_ally_centroid_col += float(_ag.get("col", 0))
								_ally_centroid_row += float(_ag.get("row", 0))
						_ally_centroid_col /= float(echo_actors.size())
						_ally_centroid_row /= float(echo_actors.size())

					var _ally_candidates: Array = GridService.collect_unoccupied_cells(
						_ally_walkable, _ally_occupied)
					# Target column AND row reference are both the party centroid, ranked by
					# summed distance — the ally wants the nearest cell to the party, not the
					# nearest cell in a target column.
					var _ally_cell: Dictionary = GridService.place_on_terrain(
						_ally_candidates, _ally_centroid_col, _ally_centroid_row,
						GridService.PLACE_METRIC_MANHATTAN)
					if not _ally_cell.is_empty():
						_ally_actor["grid_pos"] = _ally_cell

				all_actors.append(_ally_actor)

				_ally_map["ally_consumed_in_encounter"] = true
				_ally_stage["explore_map"] = _ally_map
				FlowStageExploreState._write_stage_back(flow_ctx, _ally_stage)
				flow_ctx.request_save("encounter.ally_joined")
				if flow_ctx.logger != null:
					flow_ctx.logger.info(t, "combat.ally.joined", "Temporary ally auto-joined encounter", {
						"actor_id": _ally_actor.get("id", ""),
						"level":    _ally_level,
					})

		# Safety net: the combat round loop is id-keyed (CombatState builds initiative_order
		# from actor ids; FlowRuntime._resolve_next_actor looks the actor back up via
		# _find_actor_by_id, which returns the FIRST match). If two actors enter with the
		# same id (most commonly an empty "") every duplicate initiative slot resolves the
		# SAME actor, so all but one duplicate FREEZE at spawn for the whole fight.
		# Deterministically repair any empty or duplicate id BEFORE initiative is built.
		# No-op when all ids are already unique + non-empty (legacy behaviour preserved).
		_ensure_unique_actor_ids(all_actors, flow_ctx.logger, t)

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



# Deterministic guard against the id-keyed round-loop freeze. Scans the assembled
# actor list in stable order; the first time an id is empty or already seen, it is
# replaced in-place with a collision-free "<faction>_<index>" fallback (bumped if the
# fallback itself collides). Logs each repair via the structured logger (t injected).
# When every id is already unique + non-empty, this mutates nothing and is a no-op —
# combat behaviour is byte-identical to before. Mutates `actors` in place.
static func _ensure_unique_actor_ids(actors: Array, logger, t: int) -> void:
	var seen: Dictionary = {}
	for idx in range(actors.size()):
		var a_v: Variant = actors[idx]
		if typeof(a_v) != TYPE_DICTIONARY:
			continue
		var a: Dictionary = a_v
		var id: String = str(a.get("id", ""))
		if id != "" and not seen.has(id):
			seen[id] = true
			continue
		# Empty or duplicate id — assign a deterministic, unique fallback.
		var faction: String = str(a.get("faction", "actor"))
		if faction.is_empty():
			faction = "actor"
		var new_id: String = "%s_%d" % [faction, idx]
		while seen.has(new_id) or new_id == "":
			new_id += "_d"
		a["id"] = new_id
		seen[new_id] = true
		if logger != null:
			logger.warn(t, "combat.actor.id_conflict",
				"Actor entered combat with an empty or duplicate id; repaired to avoid round-loop freeze",
				{ "index": idx, "bad_id": id, "repaired_id": new_id, "faction": faction })


# ────────────────────────────────────────────────────────────────────────────
# BUG-002: Reads the stage's first objective type and maps it to the correct
# encounter resolution mode. Same stage-lookup pattern as FlowStageState.enter().
# ────────────────────────────────────────────────────────────────────────────

static func _resolve_mode_from_stage(flow_ctx: FlowContext) -> String:
	var model := RealmService.get_active(flow_ctx)
	if model.is_empty():
		return EncounterResolutionModes.COMBAT

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
		return EncounterResolutionModes.COMBAT

	# V2-STAGE-002: Read the specific objective type via active_encounter_objective_index.
	# stage.type is a display-only summary field — resolution mode must reflect the actual objective.
	var obj_index := flow_ctx.active_encounter_objective_index
	var objs_v: Variant = stage.get("objectives", [])
	var objs: Array = objs_v if objs_v is Array else []

	if obj_index >= 0 and obj_index < objs.size() and objs[obj_index] is Dictionary:
		var obj_type := str((objs[obj_index] as Dictionary).get("type", ""))
		match obj_type:
			ObjectiveModel.TYPE_SHRINE:
				return EncounterResolutionModes.PURIFY_SHRINE
			ObjectiveModel.TYPE_RECOVER:
				return EncounterResolutionModes.RECOVER
			ObjectiveModel.TYPE_PROTECT:
				return EncounterResolutionModes.PROTECT
			ObjectiveModel.TYPE_ENDURE:
				return EncounterResolutionModes.ENDURE
			ObjectiveModel.TYPE_PURSUE:
				return EncounterResolutionModes.PURSUE
			ObjectiveModel.TYPE_GUIDE_SPIRIT:
				return EncounterResolutionModes.GUIDE_SPIRIT
			_:
				return EncounterResolutionModes.COMBAT

	# V2-STAGE-002: No objective linked (non-objective situation, or pre-V2-STAGE-002 save).
	# ALWAYS use COMBAT. Never read stage.type here — stage.type is a display-only summary
	# and using it caused non-objective combat situations on purification stages to incorrectly
	# spawn shrine actors and drain the party.
	return EncounterResolutionModes.COMBAT


# ────────────────────────────────────────────────────────────────────────────
# V2-STAGE-004 P3: Pure static helper — scales objective params by completion order.
#
# Fixes float truncation bug: config growth values like 0.5 must be read as float
# and rounded (not int()-truncated, which collapses 0.5 → 0 making scaling a no-op).
#
# Generic scaling pattern per field:
#   base   := int(mode_cfg.get(field, base_default))
#   growth := float(mode_cfg.get(field+"_growth_per_completion", 0.0))
#   maxv   := int(mode_cfg.get(field+"_max", base))
#   scaled := clampi(base + roundi(growth * float(completion_index)), base, maxv)
#
# stage_params (non-empty) are merged on top as overrides — caller passes {} when none.
# Returns {} for any mode_key outside {"recover","protect","endure"}.
# ────────────────────────────────────────────────────────────────────────────
static func resolve_objective_params(
	mode_key: String,
	mode_cfg: Dictionary,
	completion_index: int,
	stage_params: Dictionary
) -> Dictionary:
	var params: Dictionary = {}
	match mode_key:
		"recover":
			var _r_base:   int   = int(mode_cfg.get("hold_rounds",                         2))
			var _r_growth: float = float(mode_cfg.get("hold_rounds_growth_per_completion",  0.0))
			var _r_max:    int   = int(mode_cfg.get("hold_rounds_max",                      4))
			params["hold_rounds"]       = clampi(_r_base + roundi(_r_growth * float(completion_index)), _r_base, _r_max)
			params["relic_def_id"]      = str(mode_cfg.get("relic_def_id",  "recover_relic"))
			params["relic_name"]        = str(mode_cfg.get("relic_name",    "Ancestral Relic"))
			params["relic_max_hp"]      = int(mode_cfg.get("relic_max_hp",  150))
			params["reinforce_interval"]  = int(mode_cfg.get("reinforce_interval",  2))
			params["reinforce_size"]      = int(mode_cfg.get("reinforce_size",      1))
			params["reinforce_group"]     = str(mode_cfg.get("reinforce_group",     "group.vale_patrol_sm"))
			params["reinforce_max_total"] = int(mode_cfg.get("reinforce_max_total", 4))
		"protect":
			var _p_base:      int   = int(mode_cfg.get("duration_turns",                        4))
			var _p_growth:    float = float(mode_cfg.get("duration_growth_per_completion",       0.0))
			var _p_max:       int   = int(mode_cfg.get("duration_max",                           8))
			var _p_hp_base:   int   = int(mode_cfg.get("entity_max_hp",                          70))
			var _p_hp_growth: float = float(mode_cfg.get("entity_hp_growth_per_completion",      0.0))
			params["duration_turns"] = clampi(_p_base + roundi(_p_growth * float(completion_index)), _p_base, _p_max)
			params["entity_def_id"]  = str(mode_cfg.get("entity_def_id",  "protect_entity"))
			params["entity_name"]    = str(mode_cfg.get("entity_name",    "Protected One"))
			params["entity_max_hp"]  = _p_hp_base + roundi(_p_hp_growth * float(completion_index))
		"endure":
			var _e_base:      int   = int(mode_cfg.get("duration_turns",                        5))
			var _e_growth:    float = float(mode_cfg.get("duration_growth_per_completion",       0.0))
			var _e_max:       int   = int(mode_cfg.get("duration_max",                           9))
			var _e_ws_base:   int   = int(mode_cfg.get("wave_size",                              2))
			var _e_ws_growth: float = float(mode_cfg.get("wave_size_growth_per_completion",      0.0))
			var _e_ws_max:    int   = int(mode_cfg.get("wave_size_max",                          4))
			params["duration_turns"]       = clampi(_e_base + roundi(_e_growth * float(completion_index)), _e_base, _e_max)
			params["wave_interval"]        = int(mode_cfg.get("wave_interval", 2))
			params["wave_size"]            = clampi(_e_ws_base + roundi(_e_ws_growth * float(completion_index)), _e_ws_base, _e_ws_max)
			params["wave_group"]           = str(mode_cfg.get("wave_group", ""))
			params["wave_size_max"]        = _e_ws_max
			params["wave_size_rising_step"] = int(mode_cfg.get("wave_size_rising_step", 0))
		"pursue":
			var _w_base:   int   = int(mode_cfg.get("window_turns",                           8))
			var _w_growth: float = float(mode_cfg.get("window_turns_growth_per_completion",   0.0))
			var _w_max:    int   = int(mode_cfg.get("window_turns_max",                       12))
			var _c_base:   int   = int(mode_cfg.get("contain_rounds",                         3))
			var _c_growth: float = float(mode_cfg.get("contain_rounds_growth_per_completion", 0.0))
			var _c_max:    int   = int(mode_cfg.get("contain_rounds_max",                     5))
			params["window_turns"]                = clampi(_w_base + roundi(_w_growth * float(completion_index)), _w_base, _w_max)
			params["contain_rounds"]              = clampi(_c_base + roundi(_c_growth * float(completion_index)), _c_base, _c_max)
			params["quarry_def_id"]               = str(mode_cfg.get("quarry_def_id",   "pursue_quarry"))
			params["quarry_name"]                 = str(mode_cfg.get("quarry_name",     "Fleeing Quarry"))
			params["quarry_near_exit_threshold"]  = int(mode_cfg.get("quarry_near_exit_threshold", 3))
			params["directive_intent_weights"]    = mode_cfg.get("directive_intent_weights", {})
		"guide_spirit":
			var _gs_base:      int   = int(mode_cfg.get("duration_turns",                        4))
			var _gs_growth:    float = float(mode_cfg.get("duration_growth_per_completion",       0.0))
			var _gs_max:       int   = int(mode_cfg.get("duration_max",                           8))
			var _gs_hp_base:   int   = int(mode_cfg.get("spirit_max_hp",                          60))
			var _gs_hp_growth: float = float(mode_cfg.get("spirit_hp_growth_per_completion",       0.0))
			params["duration_turns"]  = clampi(_gs_base + roundi(_gs_growth * float(completion_index)), _gs_base, _gs_max)
			params["spirit_def_id"]   = str(mode_cfg.get("spirit_def_id",  "guide_spirit"))
			params["spirit_name"]     = str(mode_cfg.get("spirit_name",    "Wandering Spirit"))
			params["spirit_max_hp"]   = _gs_hp_base + roundi(_gs_hp_growth * float(completion_index))
			params["escort_radius"]             = int(mode_cfg.get("escort_radius",             2))
			params["skittish_radius"]           = int(mode_cfg.get("skittish_radius",            3))
			params["destination_min_distance"]  = int(mode_cfg.get("destination_min_distance",   6))
			params["spirit_damage_mul"]         = float(mode_cfg.get("spirit_damage_mul",         0.75))
			params["directive_intent_weights"]  = mode_cfg.get("directive_intent_weights", {})
		_:
			return {}
	# Stage-level overrides applied last (non-empty only).
	if not stage_params.is_empty():
		params.merge(stage_params, true)  # true = overwrite existing keys
	return params

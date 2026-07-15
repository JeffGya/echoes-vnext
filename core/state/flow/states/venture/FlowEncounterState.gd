class_name FlowEncounterState

extends State

const FEAR_THRESHOLD_DEFAULT: int = 80
const LeadershipEmotionService = preload("res://core/combat/LeadershipEmotionService.gd")

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
			actor_cfg = {
				"birth_stats": bd.get("summoning", {}).get("birth_stats", {}),
				"enemy_types": bd.get("actor", {}).get("enemy_types", {}),
			}
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
			# V2-STAGE-004 P3a/P3b: When irregular terrain is present, relocate the shrine to a
			# deterministic walkable cell rather than the hardcoded grid_pos (col 0 is almost
			# always VOID after border erosion).  Empty terrain (legacy 10×10, keeper_intro,
			# no active realm) is left byte-identical — the hardcoded grid_pos is untouched.
			# P3b: depth is interpolated by realm completion_index so early realms get a
			# central shrine (reachable) and late realms get the deep-enemy side (hard).
			var _shrine_terrain: Dictionary = flow_ctx.encounter_ctx.terrain
			if not _shrine_terrain.is_empty():
				var _shrine_walkable: Dictionary = StageTerrain.walkable_set(_shrine_terrain)
				# Collect already-occupied cells from echo + enemy actors (placed just above).
				var _shrine_occupied: Dictionary = {}
				for _so_v in echo_actors:
					if _so_v is Dictionary:
						var _so_gp: Dictionary = _so_v.get("grid_pos", {})
						var _so_key: String = str(int(_so_gp.get("col", -1))) + "," + str(int(_so_gp.get("row", -1)))
						_shrine_occupied[_so_key] = true
				for _so_v in enemy_actors:
					if _so_v is Dictionary:
						var _so_gp: Dictionary = _so_v.get("grid_pos", {})
						var _so_key: String = str(int(_so_gp.get("col", -1))) + "," + str(int(_so_gp.get("row", -1)))
						_shrine_occupied[_so_key] = true
				# Build a sorted list of candidates so iteration order is deterministic.
				var _shrine_candidates: Array = []
				for _sc_key in _shrine_walkable:
					if not _shrine_occupied.has(_sc_key):
						var _sc_parts: Array = str(_sc_key).split(",")
						if _sc_parts.size() == 2:
							_shrine_candidates.append({ "col": int(_sc_parts[0]), "row": int(_sc_parts[1]) })

				# P3b: read depth-scale config from balance.json; safe in-code defaults.
				var _op_cfg: Dictionary = {}
				if flow_ctx.config_service != null:
					var _op_bal: Dictionary = flow_ctx.config_service.get_balance()
					_op_cfg = _op_bal.get("data", {}).get("combat", {}).get("objective_placement", {})
				var _op_min_frac:  float = float(_op_cfg.get("depth_min_frac",      0.35))
				var _op_max_frac:  float = float(_op_cfg.get("depth_max_frac",      1.0))
				var _op_full_at:   float = float(_op_cfg.get("completion_full_at",  6.0))

				# Depth fraction: 0 = echo/left side; 1 = enemy/right (max-col) side.
				var _op_f: float = clampf(float(completion_index) / _op_full_at, _op_min_frac, _op_max_frac)

				# Derive walkable column range.
				var _op_min_col: int = 999999
				var _op_max_col: int = -1
				for _opc_v in _shrine_candidates:
					var _opc: Dictionary = _opc_v
					if _opc["col"] < _op_min_col: _op_min_col = _opc["col"]
					if _opc["col"] > _op_max_col: _op_max_col = _opc["col"]

				# Target column for this completion_index.
				var _op_target_col: int = roundi(_op_min_col + _op_f * float(_op_max_col - _op_min_col))

				# Board vertical centre for tiebreak.
				var _shrine_board_h: int = int(_shrine_terrain.get("bounds", {}).get("h", 12))
				var _shrine_mid_row: float = float(_shrine_board_h - 1) * 0.5

				# Stable sort: nearest to target_col first; tiebreak row nearest mid; then lowest col; then lowest row.
				_shrine_candidates.sort_custom(func(a, b):
					var da_col: int = abs(a["col"] - _op_target_col)
					var db_col: int = abs(b["col"] - _op_target_col)
					if da_col != db_col:
						return da_col < db_col
					var da_row: float = abs(float(a["row"]) - _shrine_mid_row)
					var db_row: float = abs(float(b["row"]) - _shrine_mid_row)
					if da_row != db_row:
						return da_row < db_row
					if a["col"] != b["col"]:
						return a["col"] < b["col"]
					return a["row"] < b["row"]
				)
				if not _shrine_candidates.is_empty():
					shrine_actor["grid_pos"] = {
						"col": _shrine_candidates[0]["col"],
						"row": _shrine_candidates[0]["row"],
					}
			# Runtime-only shrine fields — not in ActorSchema REQUIRED_FIELDS.
			shrine_actor["purify_stacks"] = []

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
			var _om_cfg: Dictionary = _om_data.get("combat", {}).get("objective_modes", {}).get(_obj_mode_key, {})
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
				FlowEncounterState.resolve_objective_params(_obj_mode_key, _om_cfg, completion_index, _om_stage_params)

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
						flow_ctx.save_request = true
						if flow_ctx.save_request_reason.is_empty():
							flow_ctx.save_request_reason = "encounter.charge_pressure_consumed"
						else:
							flow_ctx.save_request_reason += "|encounter.charge_pressure_consumed"
						if flow_ctx.logger != null:
							flow_ctx.logger.info(t, "combat.charge_pressure.applied",
								"Charge pressure applied to objective combat", {
									"mode":         _obj_mode_key,
									"situation_id": _cp_sit_id,
								})

		# V2-STAGE-004 P3: Spawn objective structure actor for RECOVER / PROTECT modes.
		# ENDURE spawns no objective actor (wave-only). Shrine path is unchanged above.
		var objective_actor: Dictionary = {}
		var _op_cfg_p3: Dictionary = {}
		if flow_ctx.config_service != null:
			var _opal_bal: Dictionary = flow_ctx.config_service.get_balance()
			_op_cfg_p3 = _opal_bal.get("data", {}).get("combat", {}).get("objective_placement", {})
		var _op_min_frac_p3: float  = float(_op_cfg_p3.get("depth_min_frac",      0.35))
		var _op_max_frac_p3: float  = float(_op_cfg_p3.get("depth_max_frac",      1.0))
		var _op_full_at_p3:  float  = float(_op_cfg_p3.get("completion_full_at",  6.0))
		var _op_f_p3: float = clampf(float(completion_index) / _op_full_at_p3, _op_min_frac_p3, _op_max_frac_p3)

		match flow_ctx.encounter_ctx.resolution_mode:
			EncounterResolutionModes.RECOVER:
				# Spawn relic structure — placed deep (enemy-side) like the shrine.
				var _rec_obj_params: Dictionary = flow_ctx.encounter_ctx.objective_params
				var _rec_def_id: String     = str(_rec_obj_params.get("relic_def_id", "recover_relic"))
				var _rec_name: String       = str(_rec_obj_params.get("relic_name",   "Ancestral Relic"))
				var _rec_max_hp: int        = int(_rec_obj_params.get("relic_max_hp", 150))
				var _rec_struct_cfg: Dictionary = {}
				if flow_ctx.config_service != null:
					var _rb: Dictionary = flow_ctx.config_service.get_balance()
					_rec_struct_cfg = _rb.get("data", {}).get("actor", {}).get("structures", {})
				var _rec_def: Dictionary = _rec_struct_cfg.get(_rec_def_id, {
					"id": _rec_def_id + "_01", "name": _rec_name,
					"faction": "structure", "max_hp": _rec_max_hp,
					"grid_pos": { "col": 0, "row": 4 }
				})
				objective_actor = StructureActor.from_definition(_rec_def, t)
				objective_actor["is_objective_relic"] = true
				# Place deep (high column = enemy side) on irregular terrain; legacy: use grid_pos.
				var _rec_terrain: Dictionary = flow_ctx.encounter_ctx.terrain
				if not _rec_terrain.is_empty():
					var _rec_walkable: Dictionary = StageTerrain.walkable_set(_rec_terrain)
					var _rec_occupied: Dictionary = {}
					for _ro_v in echo_actors:
						if _ro_v is Dictionary:
							var _rg: Dictionary = _ro_v.get("grid_pos", {})
							_rec_occupied[str(int(_rg.get("col",-1))) + "," + str(int(_rg.get("row",-1)))] = true
					for _ro_v in enemy_actors:
						if _ro_v is Dictionary:
							var _rg: Dictionary = _ro_v.get("grid_pos", {})
							_rec_occupied[str(int(_rg.get("col",-1))) + "," + str(int(_rg.get("row",-1)))] = true
					var _rec_candidates: Array = []
					for _rc_key in _rec_walkable:
						if not _rec_occupied.has(_rc_key):
							var _rc_p: Array = str(_rc_key).split(",")
							if _rc_p.size() == 2:
								_rec_candidates.append({ "col": int(_rc_p[0]), "row": int(_rc_p[1]) })
					var _rec_min_col: int = 999999
					var _rec_max_col: int = -1
					for _rc_v in _rec_candidates:
						if _rc_v["col"] < _rec_min_col: _rec_min_col = _rc_v["col"]
						if _rc_v["col"] > _rec_max_col: _rec_max_col = _rc_v["col"]
					var _rec_target_col: int = roundi(_rec_min_col + _op_f_p3 * float(_rec_max_col - _rec_min_col))
					var _rec_board_h: int = int(_rec_terrain.get("bounds", {}).get("h", 12))
					var _rec_mid_row: float = float(_rec_board_h - 1) * 0.5
					# Stable sort: nearest target_col first; tiebreak row nearest mid; lowest col; lowest row.
					_rec_candidates.sort_custom(func(a, b):
						var da: int = abs(a["col"] - _rec_target_col)
						var db: int = abs(b["col"] - _rec_target_col)
						if da != db: return da < db
						var dra: float = abs(float(a["row"]) - _rec_mid_row)
						var drb: float = abs(float(b["row"]) - _rec_mid_row)
						if dra != drb: return dra < drb
						if a["col"] != b["col"]: return a["col"] < b["col"]
						return a["row"] < b["row"]
					)
					if not _rec_candidates.is_empty():
						objective_actor["grid_pos"] = { "col": _rec_candidates[0]["col"], "row": _rec_candidates[0]["row"] }

			EncounterResolutionModes.PROTECT:
				# Spawn entity structure — placed mid-field (nearest cell to board-centre column).
				var _prt_obj_params: Dictionary = flow_ctx.encounter_ctx.objective_params
				var _prt_def_id: String  = str(_prt_obj_params.get("entity_def_id", "protect_entity"))
				var _prt_name: String    = str(_prt_obj_params.get("entity_name",   "Protected One"))
				var _prt_max_hp: int     = int(_prt_obj_params.get("entity_max_hp", 100))
				var _prt_struct_cfg: Dictionary = {}
				if flow_ctx.config_service != null:
					var _pb: Dictionary = flow_ctx.config_service.get_balance()
					_prt_struct_cfg = _pb.get("data", {}).get("actor", {}).get("structures", {})
				var _prt_def: Dictionary = _prt_struct_cfg.get(_prt_def_id, {
					"id": _prt_def_id + "_01", "name": _prt_name,
					"faction": "structure", "max_hp": _prt_max_hp,
					"grid_pos": { "col": 4, "row": 4 }
				})
				# Patch scaled max_hp into the def before building (config def may have base HP).
				var _prt_def_copy: Dictionary = _prt_def.duplicate(true)
				_prt_def_copy["max_hp"] = _prt_max_hp
				_prt_def_copy["name"]   = _prt_name
				objective_actor = StructureActor.from_definition(_prt_def_copy, t)
				# Place mid-field: nearest unoccupied walkable cell to centre column.
				var _prt_terrain: Dictionary = flow_ctx.encounter_ctx.terrain
				if not _prt_terrain.is_empty():
					var _prt_walkable: Dictionary = StageTerrain.walkable_set(_prt_terrain)
					var _prt_occupied: Dictionary = {}
					for _po_v in echo_actors:
						if _po_v is Dictionary:
							var _pg: Dictionary = _po_v.get("grid_pos", {})
							_prt_occupied[str(int(_pg.get("col",-1))) + "," + str(int(_pg.get("row",-1)))] = true
					for _po_v in enemy_actors:
						if _po_v is Dictionary:
							var _pg: Dictionary = _po_v.get("grid_pos", {})
							_prt_occupied[str(int(_pg.get("col",-1))) + "," + str(int(_pg.get("row",-1)))] = true
					var _prt_candidates: Array = []
					for _pc_key in _prt_walkable:
						if not _prt_occupied.has(_pc_key):
							var _pc_p: Array = str(_pc_key).split(",")
							if _pc_p.size() == 2:
								_prt_candidates.append({ "col": int(_pc_p[0]), "row": int(_pc_p[1]) })
					# Derive centre column from walkable bounds.
					var _prt_min_col: int = 999999
					var _prt_max_col: int = -1
					var _prt_board_h: int = int(_prt_terrain.get("bounds", {}).get("h", 12))
					var _prt_mid_row: float = float(_prt_board_h - 1) * 0.5
					for _pc_v in _prt_candidates:
						if _pc_v["col"] < _prt_min_col: _prt_min_col = _pc_v["col"]
						if _pc_v["col"] > _prt_max_col: _prt_max_col = _pc_v["col"]
					var _prt_centre_col: int = (_prt_min_col + _prt_max_col) / 2
					# Stable sort: nearest centre column first; tiebreak nearest mid row; lowest col; lowest row.
					_prt_candidates.sort_custom(func(a, b):
						var da: int = abs(a["col"] - _prt_centre_col)
						var db: int = abs(b["col"] - _prt_centre_col)
						if da != db: return da < db
						var dra: float = abs(float(a["row"]) - _prt_mid_row)
						var drb: float = abs(float(b["row"]) - _prt_mid_row)
						if dra != drb: return dra < drb
						if a["col"] != b["col"]: return a["col"] < b["col"]
						return a["row"] < b["row"]
					)
					if not _prt_candidates.is_empty():
						objective_actor["grid_pos"] = { "col": _prt_candidates[0]["col"], "row": _prt_candidates[0]["row"] }
				# Legacy path (no terrain): grid_pos from def used as-is — no relocation needed.

			EncounterResolutionModes.PURSUE:
				# Spawn quarry enemy — placed deep (enemy-side) like the relic.
				var _qry_obj_params: Dictionary = flow_ctx.encounter_ctx.objective_params
				var _qry_def_id: String  = str(_qry_obj_params.get("quarry_def_id", "pursue_quarry"))
				var _qry_name: String    = str(_qry_obj_params.get("quarry_name",   "Fleeing Quarry"))
				var _qry_defn: Dictionary = {
					"id":      "pursue_quarry_01",
					"name":    _qry_name,
					"type":    _qry_def_id,
					"level":   1,
					"faction": "enemy",
				}
				objective_actor = EnemyActor.from_definition(_qry_defn, t, actor_cfg)
				objective_actor["is_quarry"] = true
				# Place deep (high column = enemy side) on irregular terrain.
				var _qry_terrain: Dictionary = flow_ctx.encounter_ctx.terrain
				if not _qry_terrain.is_empty():
					var _qry_walkable: Dictionary = StageTerrain.walkable_set(_qry_terrain)
					var _qry_occupied: Dictionary = {}
					for _qo_v in echo_actors:
						if _qo_v is Dictionary:
							var _qq: Dictionary = _qo_v.get("grid_pos", {})
							_qry_occupied[str(int(_qq.get("col",-1))) + "," + str(int(_qq.get("row",-1)))] = true
					for _qo_v in enemy_actors:
						if _qo_v is Dictionary:
							var _qq: Dictionary = _qo_v.get("grid_pos", {})
							_qry_occupied[str(int(_qq.get("col",-1))) + "," + str(int(_qq.get("row",-1)))] = true
					var _qry_candidates: Array = []
					for _qc_key in _qry_walkable:
						if not _qry_occupied.has(_qc_key):
							var _qc_p: Array = str(_qc_key).split(",")
							if _qc_p.size() == 2:
								_qry_candidates.append({ "col": int(_qc_p[0]), "row": int(_qc_p[1]) })
					var _qry_min_col: int = 999999
					var _qry_max_col: int = -1
					for _qc_v in _qry_candidates:
						if _qc_v["col"] < _qry_min_col: _qry_min_col = _qc_v["col"]
						if _qc_v["col"] > _qry_max_col: _qry_max_col = _qc_v["col"]
					var _qry_target_col: int = roundi(_qry_min_col + _op_f_p3 * float(_qry_max_col - _qry_min_col))
					var _qry_board_h: int = int(_qry_terrain.get("bounds", {}).get("h", 12))
					var _qry_mid_row: float = float(_qry_board_h - 1) * 0.5
					_qry_candidates.sort_custom(func(a, b):
						var da: int = abs(a["col"] - _qry_target_col)
						var db: int = abs(b["col"] - _qry_target_col)
						if da != db: return da < db
						var dra: float = abs(float(a["row"]) - _qry_mid_row)
						var drb: float = abs(float(b["row"]) - _qry_mid_row)
						if dra != drb: return dra < drb
						if a["col"] != b["col"]: return a["col"] < b["col"]
						return a["row"] < b["row"]
					)
					if not _qry_candidates.is_empty():
						objective_actor["grid_pos"] = { "col": _qry_candidates[0]["col"], "row": _qry_candidates[0]["row"] }

			EncounterResolutionModes.GUIDE_SPIRIT:
				# V2-STAGE-004 P3c: seed guide_mode 50/50 — "protect" (stay in place) or
				# "escort" (walk to a seeded edge destination). Mirrors PURSUE's per-encounter
				# seeded coin-flip pattern exactly.
				var _gs_obj_params: Dictionary = flow_ctx.encounter_ctx.objective_params
				var _gs_mode_rng := RandomNumberGenerator.new()
				if flow_ctx.campaign_seed != null:
					_gs_mode_rng = flow_ctx.campaign_seed.get_rng(
						"combat.guide_mode." + flow_ctx.encounter_ctx.encounter_id)
				else:
					_gs_mode_rng.seed = hash("guide_mode_" + flow_ctx.encounter_ctx.encounter_id)
				var _gs_mode: String = "protect" if _gs_mode_rng.randi() % 2 == 0 else "escort"
				# V2-STAGE-004 P3c dev override: honour a non-empty dev_guide_mode INSTEAD of the
				# roll — but the seeded draw above already ran unconditionally (draw-then-override),
				# so RNG draw order is identical with or without the override.
				if not flow_ctx.dev_guide_mode.is_empty():
					if flow_ctx.logger != null:
						flow_ctx.logger.info(t, "combat.guide.dev_override",
							"Dev override applied to guide_mode",
							{ "field": "guide_mode", "seeded": _gs_mode,
							  "forced": flow_ctx.dev_guide_mode })
					_gs_mode = flow_ctx.dev_guide_mode

				# Seed the spirit's name: draw gender first (50/50), then NameBank.build_full_name().
				var _gs_name_rng := RandomNumberGenerator.new()
				if flow_ctx.campaign_seed != null:
					_gs_name_rng = flow_ctx.campaign_seed.get_rng(
						"combat.spirit_name." + flow_ctx.encounter_ctx.encounter_id)
				else:
					_gs_name_rng.seed = hash("spirit_name_" + flow_ctx.encounter_ctx.encounter_id)
				var _gs_gender: String = "female" if _gs_name_rng.randi() % 2 == 0 else "male"
				# NameBank.build_full_name() always returns "%s %s" from non-empty curated pools
				# (falls back to "Nameless" internally if a pool were ever empty) — never leading-
				# space or empty, so no post-hoc guard/fallback is needed here.
				var _gs_spirit_name: String = NameBank.build_full_name(_gs_gender, _gs_name_rng)

				# Escort only — seed whether the spirit joins battle as a combatant (50/50).
				var _gs_joins: bool = false
				if _gs_mode == "escort":
					var _gs_joins_rng := RandomNumberGenerator.new()
					if flow_ctx.campaign_seed != null:
						_gs_joins_rng = flow_ctx.campaign_seed.get_rng(
							"combat.guide_spirit_joins." + flow_ctx.encounter_ctx.encounter_id)
					else:
						_gs_joins_rng.seed = hash("guide_spirit_joins_" + flow_ctx.encounter_ctx.encounter_id)
					_gs_joins = _gs_joins_rng.randi() % 2 == 0
					# V2-STAGE-004 P3c dev override: honour a non-empty dev_guide_joins INSTEAD of the
					# roll — draw-then-override (the seeded draw above already ran) keeps RNG order
					# identical. Only meaningful in escort mode, same as the natural roll.
					if not flow_ctx.dev_guide_joins.is_empty():
						var _gs_forced_joins: bool = flow_ctx.dev_guide_joins == "join"
						if flow_ctx.logger != null:
							flow_ctx.logger.info(t, "combat.guide.dev_override",
								"Dev override applied to spirit_joins_battle",
								{ "field": "spirit_joins_battle", "seeded": _gs_joins,
								  "forced": _gs_forced_joins })
						_gs_joins = _gs_forced_joins

				var _gs_max_hp: int = int(_gs_obj_params.get("spirit_max_hp", 60))
				var _gs_def_id: String = str(_gs_obj_params.get("spirit_def_id", "guide_spirit"))
				var _gs_dmg_mul: float = float(_gs_obj_params.get("spirit_damage_mul", 0.75))

				if _gs_joins:
					# Escort + joins battle: build via EnemyActor (actor_type "enemy" → BehaviorArbiter)
					# but with faction "echo" so the spirit fights alongside the party — ActorService
					# filters targeting by faction, not actor_type, so this makes it a valid ally for
					# get_threatened_ally() and a valid combatant against the "enemy" faction.
					var _gs_defn: Dictionary = {
						"id":      "guide_spirit_01",
						"name":    _gs_spirit_name,
						"type":    _gs_def_id,
						"level":   1,
						"faction": "echo",
					}
					objective_actor = EnemyActor.from_definition(_gs_defn, t, actor_cfg)
					objective_actor["_spirit_damage_mul"] = _gs_dmg_mul
				else:
					# Protect, or escort without joining: idle structure (StructureActor →
					# IdleBehaviorModule), same precedent as the RECOVER relic / PROTECT entity.
					var _gs_struct_cfg: Dictionary = {}
					if flow_ctx.config_service != null:
						var _gsb: Dictionary = flow_ctx.config_service.get_balance()
						_gs_struct_cfg = _gsb.get("data", {}).get("actor", {}).get("structures", {})
					var _gs_def: Dictionary = _gs_struct_cfg.get(_gs_def_id, {
						"id": "guide_spirit_01", "name": _gs_spirit_name,
						"faction": "structure", "max_hp": _gs_max_hp,
						"grid_pos": { "col": 0, "row": 4 }
					})
					var _gs_def_copy: Dictionary = _gs_def.duplicate(true)
					_gs_def_copy["id"]      = "guide_spirit_01"
					_gs_def_copy["max_hp"]  = _gs_max_hp
					_gs_def_copy["name"]    = _gs_spirit_name
					objective_actor = StructureActor.from_definition(_gs_def_copy, t)

				objective_actor["is_spirit"] = true
				objective_actor["name"] = _gs_spirit_name

				# Placement: deep on enemy side — identical candidate/sort pattern as the
				# PURSUE quarry block above, reusing the same _op_f_p3 depth scaling.
				var _gs_terrain: Dictionary = flow_ctx.encounter_ctx.terrain
				var _gs_candidates: Array = []
				if not _gs_terrain.is_empty():
					var _gs_walkable: Dictionary = StageTerrain.walkable_set(_gs_terrain)
					var _gs_occupied: Dictionary = {}
					for _go_v in echo_actors:
						if _go_v is Dictionary:
							var _gg: Dictionary = _go_v.get("grid_pos", {})
							_gs_occupied[str(int(_gg.get("col",-1))) + "," + str(int(_gg.get("row",-1)))] = true
					for _go_v in enemy_actors:
						if _go_v is Dictionary:
							var _gg: Dictionary = _go_v.get("grid_pos", {})
							_gs_occupied[str(int(_gg.get("col",-1))) + "," + str(int(_gg.get("row",-1)))] = true
					for _gc_key in _gs_walkable:
						if not _gs_occupied.has(_gc_key):
							var _gc_p: Array = str(_gc_key).split(",")
							if _gc_p.size() == 2:
								_gs_candidates.append({ "col": int(_gc_p[0]), "row": int(_gc_p[1]) })
					var _gs_min_col: int = 999999
					var _gs_max_col: int = -1
					for _gc_v in _gs_candidates:
						if _gc_v["col"] < _gs_min_col: _gs_min_col = _gc_v["col"]
						if _gc_v["col"] > _gs_max_col: _gs_max_col = _gc_v["col"]
					var _gs_target_col: int = roundi(_gs_min_col + _op_f_p3 * float(_gs_max_col - _gs_min_col))
					var _gs_board_h: int = int(_gs_terrain.get("bounds", {}).get("h", 12))
					var _gs_mid_row: float = float(_gs_board_h - 1) * 0.5
					_gs_candidates.sort_custom(func(a, b):
						var da: int = abs(a["col"] - _gs_target_col)
						var db: int = abs(b["col"] - _gs_target_col)
						if da != db: return da < db
						var dra: float = abs(float(a["row"]) - _gs_mid_row)
						var drb: float = abs(float(b["row"]) - _gs_mid_row)
						if dra != drb: return dra < drb
						if a["col"] != b["col"]: return a["col"] < b["col"]
						return a["row"] < b["row"]
					)
					if not _gs_candidates.is_empty():
						objective_actor["grid_pos"] = { "col": _gs_candidates[0]["col"], "row": _gs_candidates[0]["row"] }

				# Escort — seed destination on the walkable BORDER/FRONTIER ring, Chebyshev distance
				# >= destination_min_distance from the spirit's spawn cell (relax to farthest frontier
				# cell if none qualify). A frontier cell is a walkable cell with at least one 4-dir
				# neighbour that is non-walkable OR out of bounds. On irregular StageTerrain the walkable
				# set is usually inset from the outer ring, so literal bounds cells (col==0 etc.) are
				# empty — the frontier ring is where the terrain actually ends. On a full-rect board the
				# frontier reduces to the literal edge cells, so behaviour there is preserved.
				var _gs_dest_col: int = -1
				var _gs_dest_row: int = -1
				if _gs_mode == "escort" and not _gs_terrain.is_empty():
					var _gs_walkable_dest: Dictionary = StageTerrain.walkable_set(_gs_terrain)
					var _gs_spawn_pos: Dictionary = objective_actor.get("grid_pos", { "col": 0, "row": 0 })
					var _gs_min_dist: int = int(_gs_obj_params.get("destination_min_distance", 6))
					var _gs_edge_candidates: Array = []
					for _gc_v in _gs_candidates:
						var _gc_col: int = _gc_v["col"]
						var _gc_row: int = _gc_v["row"]
						# Frontier test: any 4-dir neighbour absent from the walkable set (this also
						# covers out-of-bounds neighbours, which are never in the walkable set).
						var _is_edge: bool = \
							not _gs_walkable_dest.has("%d,%d" % [_gc_col - 1, _gc_row]) \
							or not _gs_walkable_dest.has("%d,%d" % [_gc_col + 1, _gc_row]) \
							or not _gs_walkable_dest.has("%d,%d" % [_gc_col, _gc_row - 1]) \
							or not _gs_walkable_dest.has("%d,%d" % [_gc_col, _gc_row + 1])
						if _is_edge:
							_gs_edge_candidates.append({ "col": _gc_col, "row": _gc_row })
					# Sort deterministically (col then row) before indexing.
					_gs_edge_candidates.sort_custom(func(a, b):
						if a["col"] != b["col"]: return a["col"] < b["col"]
						return a["row"] < b["row"]
					)
					var _gs_far_candidates: Array = []
					for _ec_v in _gs_edge_candidates:
						var _ec_dist: int = maxi(abs(_ec_v["col"] - int(_gs_spawn_pos.get("col", 0))),
							abs(_ec_v["row"] - int(_gs_spawn_pos.get("row", 0))))
						if _ec_dist >= _gs_min_dist:
							_gs_far_candidates.append(_ec_v)
					if _gs_far_candidates.is_empty() and not _gs_edge_candidates.is_empty():
						# Relax to the farthest edge cell (deterministic: stable sort by dist desc, then col, row).
						_gs_edge_candidates.sort_custom(func(a, b):
							var da: int = maxi(abs(a["col"] - int(_gs_spawn_pos.get("col", 0))),
								abs(a["row"] - int(_gs_spawn_pos.get("row", 0))))
							var db: int = maxi(abs(b["col"] - int(_gs_spawn_pos.get("col", 0))),
								abs(b["row"] - int(_gs_spawn_pos.get("row", 0))))
							if da != db: return da > db
							if a["col"] != b["col"]: return a["col"] < b["col"]
							return a["row"] < b["row"]
						)
						_gs_far_candidates = [_gs_edge_candidates[0]]
					if not _gs_far_candidates.is_empty():
						var _gs_dest_rng := RandomNumberGenerator.new()
						if flow_ctx.campaign_seed != null:
							_gs_dest_rng = flow_ctx.campaign_seed.get_rng(
								"combat.spirit_destination." + flow_ctx.encounter_ctx.encounter_id)
						else:
							_gs_dest_rng.seed = hash("spirit_destination_" + flow_ctx.encounter_ctx.encounter_id)
						var _gs_pick: Dictionary = _gs_far_candidates[_gs_dest_rng.randi() % _gs_far_candidates.size()]
						_gs_dest_col = _gs_pick["col"]
						_gs_dest_row = _gs_pick["row"]

				# Stash the RNG-derived runtime decisions on objective_params — CombatState.create()
				# (called downstream in EncounterRoundsState.enter(), out of this file's scope) threads
				# objective_params verbatim onto combat_state, so these ride along without touching
				# CombatState.gd. _build_objective_state() below reads them back for the snapshot.
				flow_ctx.encounter_ctx.objective_params["guide_mode"]          = _gs_mode
				flow_ctx.encounter_ctx.objective_params["spirit_joins_battle"] = _gs_joins
				flow_ctx.encounter_ctx.objective_params["spirit_name"]        = _gs_spirit_name
				if _gs_mode == "escort":
					flow_ctx.encounter_ctx.objective_params["destination_col"] = _gs_dest_col
					flow_ctx.encounter_ctx.objective_params["destination_row"] = _gs_dest_row

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
				# set). Assign a real walkable, unoccupied, party-side cell here — same
				# candidate/sort pattern as the RECOVER/PROTECT/GUIDE_SPIRIT objective placement
				# above (~line 452-486 / 691-741), targeting proximity to the party's centroid
				# instead of a depth-scaled column. Legacy full-rect boards (grid_cfg_for_placement
				# has no "walkable" key) are untouched — (0,0) is a normal, non-void, unoccupied
				# cell there (echoes fill from col=1 inward), so the ally still "just works".
				var _ally_walkable: Dictionary = grid_cfg_for_placement.get("walkable", {})
				if not _ally_walkable.is_empty():
					var _ally_occupied: Dictionary = {}
					for _ao_v in echo_actors:
						if _ao_v is Dictionary:
							var _ag: Dictionary = _ao_v.get("grid_pos", {})
							_ally_occupied[str(int(_ag.get("col",-1))) + "," + str(int(_ag.get("row",-1)))] = true
					for _ao_v in enemy_actors:
						if _ao_v is Dictionary:
							var _ag: Dictionary = _ao_v.get("grid_pos", {})
							_ally_occupied[str(int(_ag.get("col",-1))) + "," + str(int(_ag.get("row",-1)))] = true
					if not shrine_actor.is_empty():
						var _ag: Dictionary = shrine_actor.get("grid_pos", {})
						_ally_occupied[str(int(_ag.get("col",-1))) + "," + str(int(_ag.get("row",-1)))] = true
					if not objective_actor.is_empty():
						var _ag: Dictionary = objective_actor.get("grid_pos", {})
						_ally_occupied[str(int(_ag.get("col",-1))) + "," + str(int(_ag.get("row",-1)))] = true

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

					var _ally_candidates: Array = []
					for _ac_key in _ally_walkable:
						if not _ally_occupied.has(_ac_key):
							var _ac_p: Array = str(_ac_key).split(",")
							if _ac_p.size() == 2:
								_ally_candidates.append({ "col": int(_ac_p[0]), "row": int(_ac_p[1]) })
					# Stable sort: nearest to party centroid (Manhattan) first; tiebreak lowest col, then row.
					_ally_candidates.sort_custom(func(a, b):
						var da: float = abs(float(a["col"]) - _ally_centroid_col) + abs(float(a["row"]) - _ally_centroid_row)
						var db: float = abs(float(b["col"]) - _ally_centroid_col) + abs(float(b["row"]) - _ally_centroid_row)
						if da != db: return da < db
						if a["col"] != b["col"]: return a["col"] < b["col"]
						return a["row"] < b["row"]
					)
					if not _ally_candidates.is_empty():
						_ally_actor["grid_pos"] = { "col": _ally_candidates[0]["col"], "row": _ally_candidates[0]["row"] }

				all_actors.append(_ally_actor)

				_ally_map["ally_consumed_in_encounter"] = true
				_ally_stage["explore_map"] = _ally_map
				FlowStageExploreState._write_stage_back(flow_ctx, _ally_stage)
				flow_ctx.save_request = true
				if flow_ctx.save_request_reason.is_empty():
					flow_ctx.save_request_reason = "encounter.ally_joined"
				else:
					flow_ctx.save_request_reason += "|encounter.ally_joined"
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

	# COMBAT-001/COMBAT-007: always build round snapshot at entry (pre_combat phase).
	flow_ctx.last_snapshot = FlowEncounterState.build_round_snapshot(flow_ctx, t)

func exit(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	flow_ctx.active_encounter_objective_index = -1


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
static func _project_actor(actor: Dictionary, contribution_ledger: Variant = null) -> Dictionary:
	var stats: Dictionary = actor.get("stats", {})
	var max_hp: int = int(stats.get("max_hp", 1))
	var fear: int = int(actor.get("fear", 0))
	var actor_id: String = str(actor.get("id", ""))
	# V2-VOICE-002: consume bark on first projection — prevents re-enqueueing across subsequent snapshots.
	var bark_line_val: String = str(actor.get("_bark_line", ""))
	actor["_bark_line"] = ""
	var proj: Dictionary = {
		"id":             actor_id,
		"name":           str(actor.get("name", "")),
		"hp":             int(actor.get("current_hp", max_hp)),
		"max_hp":         max_hp,
		"status":         FlowEncounterState._derive_status(actor),
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
	}
	# S14a: offensive contribution ledger, projected read-only for the resolve screen / S14 recruit formula.
	if contribution_ledger is Dictionary:
		var _ledger_entry_v: Variant = (contribution_ledger as Dictionary).get(actor_id, {})
		var _ledger_entry: Dictionary = _ledger_entry_v if _ledger_entry_v is Dictionary else {}
		proj["contribution"] = {
			"damage_dealt": int(_ledger_entry.get("damage_dealt", 0)),
			"damage_taken": int(_ledger_entry.get("damage_taken", 0)),
			"kills":        int(_ledger_entry.get("kills", 0)),
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
## the ally fields — see _clear_ally_fields_if_present). No hard-coded copy here;
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
	var last_actor_action_v: Dictionary = ectx.last_actor_action.duplicate() if ectx != null else {}

	# Project actors to clean render shape.
	var projected_actors: Array = []
	for a_v in raw_actors:
		if a_v is Dictionary:
			projected_actors.append(FlowEncounterState._project_actor(a_v))

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
			"objective_state":         FlowEncounterState._build_objective_state(ectx, combat_state),
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
			"objectives_remaining":    FlowEncounterState._count_remaining_required_objectives(flow_ctx),
			# V2-STAGE-004 P3a: irregular terrain dict for CombatBoardScreen tilemap.
			# {} when no terrain (legacy 10×10 path).
			"terrain":        (ectx.terrain if ectx != null else {}),
			# P1 CLOSE: stub fields to keep round field_count >= final field_count.
			"surface":        "",
			"summary_line":   "",
			# V2-STAGE-004 S15 prep: short context beat for a hostile-claimant-forced combat.
			# "" when not applicable.
			"combat_intro_line": FlowEncounterState._build_combat_intro_line(flow_ctx),
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
	var victory := bool(combat_result.get("victory", false))
	var round_ended := int(combat_result.get("round_ended", 0))

	# V2-STAGE-004 Phase 4 (S12): Temporary Ally death knock. If the joined ally (is_ally
	# true) died in this battle, apply a small party morale/fear knock — a thematic loss,
	# never a battle failure (combat_result is untouched). Mirrors the surprise-fear
	# precedent (LeadershipEmotionService.apply_fear_gain, ~line 785 above) plus the
	# parallel apply_morale_loss helper. Gated on an ally actor being present AND dead —
	# no-op (byte-identical) for every encounter without a joined ally.
	var _ak_ally: Dictionary = {}
	for _ak_v in raw_actors:
		if _ak_v is Dictionary and bool(_ak_v.get("is_ally", false)):
			_ak_ally = _ak_v
			break
	if not _ak_ally.is_empty() and bool(_ak_ally.get("is_dead", false)):
		var _ak_cfg: Dictionary = {}
		var _ak_expr_cfg: Dictionary = {}
		if flow_ctx.config_service != null:
			var _ak_bal: Dictionary = flow_ctx.config_service.get_balance()
			var _ak_data: Dictionary = _ak_bal.get("data", {})
			_ak_cfg = _ak_data.get("contact", {}).get("ally", {})
			_ak_expr_cfg = _ak_data.get("maturity_expression", {})
		var _ak_fear_knock: int   = int(_ak_cfg.get("death_fear_knock",   0))
		var _ak_morale_knock: int = int(_ak_cfg.get("death_morale_knock", 0))
		for _ak_i in range(raw_actors.size()):
			var _ak_target_v: Variant = raw_actors[_ak_i]
			if not (_ak_target_v is Dictionary):
				continue
			var _ak_target: Dictionary = _ak_target_v
			if str(_ak_target.get("faction", "")) != "echo" or bool(_ak_target.get("is_dead", false)):
				continue
			# Exclude a joined guide spirit and the ally itself — the knock is meant for the
			# player's real echoes only (mirrors the deliberate exclusions used elsewhere).
			if bool(_ak_target.get("is_spirit", false)) or bool(_ak_target.get("is_ally", false)):
				continue
			if _ak_fear_knock > 0:
				var _ak_fear_applied := LeadershipEmotionService.apply_fear_gain(
					_ak_target, _ak_fear_knock, raw_actors, _ak_expr_cfg)
				raw_actors[_ak_i]["fear"] = clampi(int(_ak_target.get("fear", 0)) + _ak_fear_applied, 0, 100)
			if _ak_morale_knock > 0:
				var _ak_morale_applied := LeadershipEmotionService.apply_morale_loss(
					_ak_target, _ak_morale_knock, raw_actors, _ak_expr_cfg, round_ended)
				raw_actors[_ak_i]["morale"] = clampi(int(_ak_target.get("morale", 50)) - _ak_morale_applied, 0, 100)
		if flow_ctx.logger != null:
			flow_ctx.logger.info(t, "combat.ally.killed", "Temporary ally died — party knock applied", {
				"actor_id": _ak_ally.get("id", ""),
				"fear_knock":   _ak_fear_knock,
				"morale_knock": _ak_morale_knock,
			})

	# Project actors to clean render shape.
	# S14a: pass the offensive contribution ledger so each projected actor carries a
	# "contribution" sub-dict (damage_dealt/damage_taken/kills) for the resolve screen / S14.
	var _s14a_contribution_ledger: Dictionary = ectx.echo_action_logs if ectx != null else {}
	var projected_actors: Array = []
	for a_v in raw_actors:
		if a_v is Dictionary:
			projected_actors.append(FlowEncounterState._project_actor(a_v, _s14a_contribution_ledger))

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

	if encounter_id == "keeper_intro.first_trial":
		return _build_keeper_intro_final_snapshot(
			flow_ctx,
			t,
			ectx,
			combat_state,
			combat_result,
			projected_actors,
			enemies_defeated,
			echoes_survived,
			round_ended
		)

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

	# V2-ECONOMY-001: pre-compute ekwan_factor from first stage objective type
	var _obj_type := "combat"
	if not stage_objectives.is_empty() and stage_objectives[0] is Dictionary:
		_obj_type = str((stage_objectives[0] as Dictionary).get("obj_type", "combat"))
	var _ekwan_factor := float(reward_cfg.get("ekwan_base_factor", 0.12))
	if _obj_type == "shrine":
		_ekwan_factor *= float(reward_cfg.get("ekwan_shrine_multiplier", 1.5))

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
		_ekwan_factor,
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

	# V2-EMOTION-001: per-echo emotion delta summary for resolve screen.
	var pre_morale_map: Dictionary = ectx.pre_encounter_morale if ectx != null else {}
	var emotion_summary: Array = []
	for a_v in raw_actors:
		if not (a_v is Dictionary): continue
		var ea: Dictionary = a_v
		if str(ea.get("faction", "")) != "echo": continue
		var eid: String     = str(ea.get("id", ""))
		var pre_morale: int  = int(pre_morale_map.get(eid, 50))
		var post_morale: int = int(ea.get("morale", 50))
		var post_fear: int   = int(ea.get("fear", 0))
		# P1 CLOSE: compute pre/post status for direction comparison.
		var _pre_status  := EmotionService.get_emotional_status(pre_morale, 0)
		var _post_status := EmotionService.get_emotional_status(post_morale, post_fear)
		var _pre_rank  := FlowEncounterState._emotional_status_rank(_pre_status)
		var _post_rank := FlowEncounterState._emotional_status_rank(_post_status)
		var _direction: String
		if _post_rank > _pre_rank:
			_direction = "lift"
		elif _post_rank < _pre_rank:
			_direction = "fall"
		else:
			_direction = "steady"
		# P1 CLOSE: tag — "ko" if dead, "refused" if existing refused flag, else "".
		var _is_dead := bool(ea.get("is_dead", false))
		var _tag: String
		if _is_dead:
			_tag = "ko"
		elif post_fear >= FEAR_THRESHOLD_DEFAULT:
			_tag = "refused"
		else:
			_tag = ""
		emotion_summary.append({
			"echo_id":               eid,
			"name":                  str(ea.get("name", "")),
			# V2-EMOTION-002: unified status arc (replaces pre/post morale_tier + fear_signal).
			"pre_emotional_status":  _pre_status,
			"post_emotional_status": _post_status,
			"morale_delta":          post_morale - pre_morale,
			"refused":               post_fear >= FEAR_THRESHOLD_DEFAULT,
			# P1 CLOSE: additive fields for unified Resolve component.
			"direction":             _direction,
			"tag":                   _tag,
		})

	# V2-VOICE-001: enrich each echo actor row with arrival_bark from save-data roster.
	# _select_arrival_barks_for_party() writes _sanctum_bark to roster entries before this call.
	var _arb_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if _arb_sanctum_v is Dictionary:
		var _arb_roster_v: Variant = (_arb_sanctum_v as Dictionary).get("roster", [])
		var _arb_roster: Array = _arb_roster_v if _arb_roster_v is Array else []
		for _pa_v in projected_actors:
			if not (_pa_v is Dictionary):
				continue
			var _pa: Dictionary = _pa_v
			if str(_pa.get("faction", "")) != "echo":
				continue
			var _pa_id := str(_pa.get("id", ""))
			for _re_v in _arb_roster:
				if _re_v is Dictionary and str((_re_v as Dictionary).get("id", "")) == _pa_id:
					var _bark_v: Variant = (_re_v as Dictionary).get("_sanctum_bark", {})
					_pa["arrival_bark"] = str(_bark_v.get("line", "")) if _bark_v is Dictionary else ""
					break

	# V2-STAGE-002: count required objectives not yet completed (post-victory mark).
	var objectives_remaining := _count_remaining_required_objectives(flow_ctx)

	# P1 CLOSE: surface — use the first objective type when known, else "combat" or "shrine".
	var _combat_surface := _obj_type if not _obj_type.is_empty() else "combat"

	# P1 CLOSE: summary_line — synthesize from reason and victory.
	var _raw_reason := str(combat_result.get("reason", ""))
	var _summary_line: String
	if victory:
		_summary_line = "The line held — %s." % _raw_reason if not _raw_reason.is_empty() \
			else "The line held."
	else:
		_summary_line = "%s." % _raw_reason if not _raw_reason.is_empty() \
			else "The line broke."

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
			"ekwan_awarded":    int(reward_result.get("ekwan_awarded", 0)),
			"rank":             str(reward_result.get("rank", "F")),
			"reward_breakdown": reward_result.get("breakdown", []),
			"formula_inputs":   formula_inputs,
			"relics":           [],
			# PROG-003: per-echo XP events for ResolveScreen and EchoParty display.
			"xp_events":        xp_events,
			# V2-EMOTION-001: per-echo emotion delta for ResolveScreen.
			"emotion_summary":  emotion_summary,
			# VOW-001 / V2-VOW-002: vow break/benefit/compliance outcome for ResolveScreen.
			"vow_outcome":      flow_ctx.vow_outcome.duplicate() if not flow_ctx.vow_outcome.is_empty() else {},
			# V2-VOW-002: vows unlocked during this stage for ResolveScreen "Vow Revealed" section.
			"newly_unlocked_vows": flow_ctx.session_unlocked_vows.duplicate(),
			# V2-STAGE-002: remaining required objectives (drives resolve routing).
			"objectives_remaining": objectives_remaining,
			# P1 CLOSE: additive fields for unified Resolve component.
			"surface":          _combat_surface,
			"summary_line":     _summary_line,
			# V2-STAGE-004 P3c: GUIDE_SPIRIT victory via protect-mode survival — V2-ITEM-002
			# free-summon seam flag only (no reward logic here).
			"guide_spirit_protected": victory and str(combat_result.get("reason", "")) == "spirit_protected",
			# V2-STAGE-004 S15 prep: short context beat for a hostile-claimant-forced combat.
			# "" when not applicable.
			"combat_intro_line": FlowEncounterState._build_combat_intro_line(flow_ctx),
		},
		"actions": _build_resolve_actions(victory, objectives_remaining),
		"meta": { "t": t },
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
	return {
		"type": FlowStateIds.RESOLVE,
		"data": {
			"title": "Result",
			"encounter_id": "keeper_intro.first_trial",
			"actors": projected_actors,
			"objective_state": FlowEncounterState._build_objective_state(ectx, combat_state),
			"victory": victory,
			"reason": str(combat_result.get("reason", "")),
			"round_ended": round_ended,
			"enemies_defeated": enemies_defeated,
			"echoes_survived": echoes_survived,
			"ase_awarded": ase_reward if victory else 0,
			"rank": "A" if victory else "F",
			"reward_breakdown": [
				{ "label": "First Trial", "delta": ase_reward }
			] if victory else [],
			"formula_inputs": {},
			"relics": [],
			"xp_events": [],
			"emotion_summary": _build_keeper_intro_emotion_summary(ectx),
		},
		"actions": {
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
		},
		"meta": { "t": t },
	}


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
			"refused": post_fear >= FEAR_THRESHOLD_DEFAULT,
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

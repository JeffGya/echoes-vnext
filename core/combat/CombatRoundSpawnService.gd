# res://core/combat/CombatRoundSpawnService.gd
# V2-INFRA-003 Phase 6 Slice 6B: the two MID-ROUND OBJECTIVE SPAWN phases, extracted verbatim
# out of core/runtime/FlowRuntime.gd::_end_round (the RECOVER block that sat at :2782–:2960 and
# the ENDURE block that sat at :2962–:3110).
#
# CONTRACT (identical to CombatRoundEmotionService, the sibling built from the same function in
# slice 6A):
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly. Both bodies request NO save at all, which is the
#     pre-extraction behaviour and must stay that way: FlowRuntime._mark_save_requested()
#     joins reasons with "|", so a save queued here would glue its reason onto the next
#     dispatch's string.
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot.
#   - Same constructor signature (flow_ctx, config_service, logger) as every sibling service.
#
# LOCATION — core/combat/, beside CombatRoundEmotionService and ShrineService, the other two
# per-round combat consequence helpers _end_round calls. These phases are combat-round
# consequences of the encounter's resolution mode; they are not actor construction (that is
# EnemyActor, which they call) and not placement policy (that is GridService, which they call).
#
# WHAT IT TOUCHES — the complete read/write set, verified line by line rather than assumed:
#
#   READS
#     ectx.resolution_mode                     mode gate for both phases
#     ectx.actors                              is_dead, is_structure, faction, id, name,
#                                              grid_pos, speed, stats.agi
#     ectx.terrain                             via StageTerrain.walkable_set()
#     ectx.combat_state["round_counter"]        re-read locally by BOTH phases (_rec_round /
#                                              _round_no) even though _end_round already has
#                                              it in `round` — preserved verbatim
#     ectx.combat_state["objective_params"]     reinforce_* (RECOVER) / wave_* + duration_turns
#     ectx.combat_state["hold_counter"]
#     ectx.combat_state["recover_holder_id"]
#     ectx.combat_state["recover_reinforce_count"]
#     ectx.combat_state["initiative_order"]
#     ectx.combat_state["waves_spawned"] / ["total_waves"] / ["all_waves_spawned"]
#     flow_ctx.config_service                   get_balance() (grid dims, legacy path) and
#                                              get_actors() (enemy templates + spawn groups).
#                                              NOTE this is flow_ctx.config_service, NOT this
#                                              service's own config_service field, and it is
#                                              null-guarded at every use — both preserved
#                                              exactly, because the two can in principle differ.
#
#   WRITES
#     ectx.actors                              APPENDED (never reordered, never removed)
#     ectx.combat_state["hold_counter"]
#     ectx.combat_state["recover_holder_id"]
#     ectx.combat_state["recover_reinforce_count"]
#     ectx.combat_state["initiative_order"]     appended to the END only
#     ectx.combat_state["total_waves"]          written once, on first ENDURE round
#     ectx.combat_state["waves_spawned"]
#     ectx.combat_state["all_waves_spawned"]
#     grid_pos on the newly built actors, via GridService.assign_grid_pos()
#     five logger lines (combat.recover.hold, combat.recover.holder_assigned,
#     combat.recover.reinforce, combat.wave.spawned)
#
#   NOT TOUCHED, contrary to what a quick read of the block might suggest: save data (never
#   read, never written), ectx.round_bark_events (the trap slice 6A hit — these two phases
#   fire no bark and construct no NarrativeVoiceService), ectx.last_round_results,
#   flow_ctx.save_data, and flow_ctx.flow_machine. flow_ctx is used for exactly one thing:
#   reaching flow_ctx.config_service.
#
#   INDIRECT CALLS, all verified pure: EnemyActor.from_definition() ("No RNG, no OS time.
#   Purely deterministic field mapping." — it calls DerivedStatService.compute_stats and
#   returns a fresh dict), GridService.assign_grid_pos() (writes only the passed actor's
#   grid_pos), GridService.get_board_cols/rows(), StageTerrain.walkable_set(), and
#   GridService.is_adjacent(). None reads or writes save data; none draws RNG.
#
# DETERMINISM. Nothing here draws RNG — placement is a total order over walkable cells (col
# desc, row asc, col asc), and the legacy no-terrain path is a fixed nested range scan. No
# dispatch is added or removed (the retreat roll's seed path embeds the tick), and the
# round-counter increment stays in _end_round, untouched (the theft roll's seed path embeds
# the round counter).
#
# ORDERING IS LOAD-BEARING and unchanged. New actors are appended to ectx.actors and to the
# END of combat_state.initiative_order, never re-sorted — the "readiness computed once"
# invariant (V2-COMBAT-001). Actor ids are formatted from the round number and the per-spawn
# index ("recover_reinf_%d_%d" / "wave_%d_%d"); initiative derives a per-actor seed from the
# actor id, so both the id strings and the append order are reproduced byte-for-byte here.
# The two phases run in the same order relative to each other and to their neighbours as
# before: emotion tick → RECOVER → ENDURE → GUIDE_SPIRIT.
#
# ONE DELIBERATE NON-VERBATIM CHANGE, and only one. The `{ "birth_stats": ..., "enemy_types": ... }`
# assembly both phases wrote out longhand — carrying the comment "matching FlowEncounterState.enter()
# shape" — now reads ConfigService.get_enemy_actor_cfg(), the single owner introduced by this
# slice. Copying that assembly into a new file would have made four copies of it (AGENTS.md #19).
# The getter returns the same two keys and returns {} for a null ConfigService, which is what
# the `if flow_ctx.config_service != null` guard produced before.

class_name CombatRoundSpawnService
extends RefCounted

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


## RECOVER phase, run once per round from _end_round AFTER the in-combat emotion tick and
## BEFORE the ENDURE wave spawn. Three sub-steps in a fixed order: hold-counter update,
## one-time holder designation, then the interval reinforcement spawn. The mode gate lives
## here rather than at the call site — COMBAT / PURIFY_SHRINE / ENDURE / GUIDE_SPIRIT /
## PROTECT / PURSUE return immediately and are byte-identical.
##
## `round` is passed in rather than re-read so that the two log lines below carry the exact
## value _end_round logged in combat.round_end for the same round. The reinforcement trigger
## deliberately re-reads round_counter into _rec_round instead of using it — preserved.
func apply_recover_round(ectx: EncounterContext, round: int, t: int) -> void:
	if ectx.resolution_mode != EncounterResolutionModes.RECOVER:
		return
	var combat_state: Dictionary = ectx.combat_state

	# V2-STAGE-004 P3a — RECOVER: update hold_counter based on echo adjacency to the relic.
	# Locate the relic: first living is_structure actor.
	var _relic: Dictionary = {}
	for _ra in ectx.actors:
		if _ra is Dictionary and bool(_ra.get("is_structure", false)) \
				and not bool(_ra.get("is_dead", false)):
			_relic = _ra
			break
	if not _relic.is_empty():
		var _relic_pos: Dictionary = _relic.get("grid_pos", {})
		var _any_adjacent: bool = false
		for _re_a in ectx.actors:
			if not (_re_a is Dictionary): continue
			if bool(_re_a.get("is_dead", false)): continue
			if str(_re_a.get("faction", "")) != "echo": continue
			if GridService.is_adjacent(_re_a.get("grid_pos", {}), _relic_pos):
				_any_adjacent = true
				break
		if _any_adjacent:
			combat_state["hold_counter"] = int(combat_state.get("hold_counter", 0)) + 1
		else:
			combat_state["hold_counter"] = 0
		logger.debug(t, "combat.recover.hold", "RECOVER hold_counter updated", {
			"round":        round,
			"hold_counter": int(combat_state.get("hold_counter", 0)),
			"adjacent":     _any_adjacent,
		})

	# V2-STAGE-004 Distinctiveness §4-D: designate holder once (deterministic pick).
	# Among living echoes: highest speed; tiebreak highest stats.agi; tiebreak lowest id.
	if str(combat_state.get("recover_holder_id", "")) == "":
		var _holder_best: Dictionary = {}
		for _hd_a in ectx.actors:
			if not (_hd_a is Dictionary): continue
			if bool(_hd_a.get("is_dead", false)): continue
			if str(_hd_a.get("faction", "")) != "echo": continue
			if _holder_best.is_empty():
				_holder_best = _hd_a
			else:
				var _hd_spd: int  = int(_hd_a.get("speed", 0))
				var _hb_spd: int  = int(_holder_best.get("speed", 0))
				if _hd_spd > _hb_spd:
					_holder_best = _hd_a
				elif _hd_spd == _hb_spd:
					var _hd_agi: int = int(_hd_a.get("stats", {}).get("agi", 0))
					var _hb_agi: int = int(_holder_best.get("stats", {}).get("agi", 0))
					if _hd_agi > _hb_agi:
						_holder_best = _hd_a
					elif _hd_agi == _hb_agi:
						# Tiebreak: lowest id string (lexicographic).
						if str(_hd_a.get("id", "")) < str(_holder_best.get("id", "")):
							_holder_best = _hd_a
		if not _holder_best.is_empty():
			combat_state["recover_holder_id"] = str(_holder_best.get("id", ""))
			logger.info(t, "combat.recover.holder_assigned", "RECOVER holder designated", {
				"round":     round,
				"holder_id": str(combat_state.get("recover_holder_id", "")),
				"holder_name": str(_holder_best.get("name", "")),
			})

	# V2-STAGE-004 Distinctiveness §4-E: RECOVER reinforcement spawn.
	# Trigger: round > 0, divisible by reinforce_interval, and under max total.
	var _rec_obj2: Dictionary = combat_state.get("objective_params", {})
	var _reinf_interval: int   = int(_rec_obj2.get("reinforce_interval", 2))
	var _reinf_size: int       = int(_rec_obj2.get("reinforce_size", 1))
	var _reinf_group: String   = str(_rec_obj2.get("reinforce_group", "group.vale_patrol_sm"))
	var _reinf_max: int        = int(_rec_obj2.get("reinforce_max_total", 4))
	var _rec_round: int        = int(combat_state.get("round_counter", 0))
	var _rec_reinf_count: int  = int(combat_state.get("recover_reinforce_count", 0))
	if _rec_round > 0 and _reinf_interval > 0 \
			and _rec_round % _reinf_interval == 0 \
			and _rec_reinf_count < _reinf_max:
		# actor_cfg matching FlowEncounterState.enter() shape — now via the single owner,
		# ConfigService.get_enemy_actor_cfg(). Same two keys; {} when config_service is null.
		var _ri_actor_cfg: Dictionary = ConfigService.get_enemy_actor_cfg(flow_ctx.config_service)
		var _ri_actors_json: Dictionary = {}
		if flow_ctx.config_service != null:
			_ri_actors_json = flow_ctx.config_service.get_actors()
		var _ri_actors_data: Dictionary = _ri_actors_json.get("data", {})
		var _ri_enemies_dict: Dictionary = _ri_actors_data.get("enemies", {})
		var _ri_groups_dict: Dictionary  = _ri_actors_data.get("groups", {})
		var _ri_group_def: Dictionary    = _ri_groups_dict.get(_reinf_group, {})
		var _ri_spawns: Array = _ri_group_def.get("spawns", []) if not _ri_group_def.is_empty() else []
		var _ri_new_actors: Array = []
		var _ri_built: int = 0
		var _ri_tmpl_idx: int = 0
		while _ri_built < _reinf_size and not _ri_spawns.is_empty():
			var _ri_sp: Dictionary = _ri_spawns[_ri_tmpl_idx % _ri_spawns.size()]
			_ri_tmpl_idx += 1
			if not (_ri_sp is Dictionary): continue
			var _ri_template_id: String = str(_ri_sp.get("template_id", ""))
			var _ri_tmpl: Dictionary = _ri_enemies_dict.get(_ri_template_id, {})
			if _ri_tmpl.is_empty(): continue
			var _ri_type_key: String = _ri_template_id
			if _ri_type_key.begins_with("enemy."):
				_ri_type_key = _ri_type_key.substr(6)
			var _ri_defn: Dictionary = {
				"id":      "recover_reinf_%d_%d" % [_rec_round, _ri_built],
				"name":   str(_ri_tmpl.get("name", _ri_template_id)),
				"type":   _ri_type_key,
				"faction": "enemy",
			}
			_ri_new_actors.append(EnemyActor.from_definition(_ri_defn, t, _ri_actor_cfg))
			_ri_built += 1
		# Placement: enemy-side (highest columns), deterministic — reuse ENDURE placement logic.
		var _ri_walkable: Dictionary = StageTerrain.walkable_set(ectx.terrain) \
			if not ectx.terrain.is_empty() else {}
		var _ri_occupied: Dictionary = {}
		for _ri_oa in ectx.actors:
			if _ri_oa is Dictionary and not bool(_ri_oa.get("is_dead", false)):
				var _ri_op: Dictionary = _ri_oa.get("grid_pos", {})
				if not _ri_op.is_empty():
					_ri_occupied["%d,%d" % [int(_ri_op.get("col", 0)), int(_ri_op.get("row", 0))]] = true
		if not _ri_walkable.is_empty():
			var _ri_candidate_keys: Array = []
			for _ri_k in _ri_walkable:
				if not _ri_occupied.has(_ri_k):
					_ri_candidate_keys.append(_ri_k)
			_ri_candidate_keys.sort_custom(func(a: String, b: String) -> bool:
				var _ap := a.split(","); var _bp := b.split(",")
				var _ac: int = int(_ap[0]); var _bc: int = int(_bp[0])
				if _ac != _bc: return _ac > _bc  # highest col first (enemy side)
				var _ar: int = int(_ap[1]); var _br: int = int(_bp[1])
				if _ar != _br: return _ar < _br   # row asc tiebreak
				return _ac < _bc                  # col asc final tiebreak
			)
			var _ri_cell_idx: int = 0
			for _ri_na in _ri_new_actors:
				if _ri_cell_idx >= _ri_candidate_keys.size():
					break
				var _ri_ck: String = _ri_candidate_keys[_ri_cell_idx]
				var _ri_ck_parts := _ri_ck.split(",")
				GridService.assign_grid_pos(_ri_na,
					int(_ri_ck_parts[0]), int(_ri_ck_parts[1]))
				_ri_occupied[_ri_ck] = true
				_ri_cell_idx += 1
		else:
			# Legacy path (no terrain): rightmost columns.
			var _ri_bal_leg: Dictionary = {}
			if flow_ctx.config_service != null:
				_ri_bal_leg = flow_ctx.config_service.get_balance()
			var _ri_grid_leg: Dictionary = _ri_bal_leg.get("data", {}).get("grid", {})
			var _ri_cols: int = GridService.get_board_cols(_ri_grid_leg)
			var _ri_rows: int = GridService.get_board_rows(_ri_grid_leg)
			var _ri_leg_cells: Array = []
			for _ri_leg_c in range(_ri_cols - 1, -1, -1):
				for _ri_leg_r in range(_ri_rows):
					var _ri_leg_k: String = "%d,%d" % [_ri_leg_c, _ri_leg_r]
					if not _ri_occupied.has(_ri_leg_k):
						_ri_leg_cells.append({ "col": _ri_leg_c, "row": _ri_leg_r })
			var _ri_leg_idx: int = 0
			for _ri_na in _ri_new_actors:
				if _ri_leg_idx >= _ri_leg_cells.size():
					break
				var _ri_leg_cell: Dictionary = _ri_leg_cells[_ri_leg_idx]
				GridService.assign_grid_pos(_ri_na,
					int(_ri_leg_cell.get("col", 0)), int(_ri_leg_cell.get("row", 0)))
				_ri_occupied["%d,%d" % [int(_ri_leg_cell.get("col", 0)), int(_ri_leg_cell.get("row", 0))]] = true
				_ri_leg_idx += 1
		# Append to ectx.actors + END of initiative_order (never re-sort).
		var _ri_init_order: Array = combat_state.get("initiative_order", [])
		for _ri_na in _ri_new_actors:
			ectx.actors.append(_ri_na)
			_ri_init_order.append({ "id": str(_ri_na.get("id", "")), "name": str(_ri_na.get("name", "")) })
		combat_state["initiative_order"] = _ri_init_order
		combat_state["recover_reinforce_count"] = _rec_reinf_count + _ri_new_actors.size()
		logger.info(t, "combat.recover.reinforce", "RECOVER reinforcement spawned", {
			"round":              _rec_round,
			"count":              _ri_new_actors.size(),
			"reinforce_group":    _reinf_group,
			"total_reinforced":   int(combat_state.get("recover_reinforce_count", 0)),
		})


## ENDURE phase, run once per round from _end_round immediately AFTER apply_recover_round()
## and BEFORE the GUIDE_SPIRIT escort step. The mode gate lives here rather than at the call
## site — every other resolution mode returns immediately and is byte-identical.
##
## Note that combat_state["total_waves"] is computed on the FIRST ENDURE round this runs and
## then never recomputed (the `has()` guard), so it reflects the duration_turns/wave_interval
## in force at that moment. That is pre-existing behaviour and is preserved unchanged.
func apply_endure_wave_spawn(ectx: EncounterContext, t: int) -> void:
	if ectx.resolution_mode != EncounterResolutionModes.ENDURE:
		return
	var combat_state: Dictionary = ectx.combat_state

	# V2-STAGE-004 P3a — ENDURE: spawn an enemy wave at the configured interval.
	var _end_obj: Dictionary = combat_state.get("objective_params", {})
	var _wave_interval: int      = int(_end_obj.get("wave_interval", 2))
	var _wave_size_base: int     = int(_end_obj.get("wave_size", 2))
	var _wave_size_max: int      = int(_end_obj.get("wave_size_max", 4))
	var _wave_size_rising: int   = int(_end_obj.get("wave_size_rising_step", 0))
	var _wave_group: String      = str(_end_obj.get("wave_group", "group.vale_patrol_sm"))
	var _duration_turns: int     = int(_end_obj.get("duration_turns", 5))
	var _round_no: int           = int(combat_state.get("round_counter", 0))

	# V2-STAGE-004 Distinctiveness §4-F: compute total_waves once (count intervals in range).
	if not combat_state.has("total_waves"):
		var _tw: int = 0
		if _wave_interval > 0:
			for _r in range(1, _duration_turns):
				if _r % _wave_interval == 0:
					_tw += 1
		combat_state["total_waves"] = _tw

	# Spawn when: not round 0, divisible by interval, and before the final/winning round.
	if _round_no > 0 and _wave_interval > 0 \
			and _round_no % _wave_interval == 0 \
			and _round_no < _duration_turns:
		# §4-F: rising wave size — N = waves_spawned (1-indexed after increment).
		var _waves_so_far: int = int(combat_state.get("waves_spawned", 0))
		var _wave_n: int       = _waves_so_far + 1  # 1-indexed for this spawn
		var _wave_size: int    = clampi(_wave_size_base + (_wave_n - 1) * _wave_size_rising, _wave_size_base, _wave_size_max)
		# actor_cfg same as FlowEncounterState.enter() — now via the single owner,
		# ConfigService.get_enemy_actor_cfg(). Same two keys; {} when config_service is null.
		var _w_actor_cfg: Dictionary = ConfigService.get_enemy_actor_cfg(flow_ctx.config_service)
		var _w_actors_json: Dictionary = {}
		if flow_ctx.config_service != null:
			_w_actors_json = flow_ctx.config_service.get_actors()
		var _w_actors_data: Dictionary = _w_actors_json.get("data", {})
		var _w_enemies_dict: Dictionary = _w_actors_data.get("enemies", {})
		var _w_groups_dict: Dictionary  = _w_actors_data.get("groups", {})
		var _w_group_def: Dictionary    = _w_groups_dict.get(_wave_group, {})
		# Collect spawn templates from the group, repeating to fill wave_size.
		var _w_spawns: Array = _w_group_def.get("spawns", []) if not _w_group_def.is_empty() else []
		var _w_new_actors: Array = []
		var _w_built: int = 0
		var _w_tmpl_idx: int = 0
		while _w_built < _wave_size and not _w_spawns.is_empty():
			var _w_sp: Dictionary = _w_spawns[_w_tmpl_idx % _w_spawns.size()]
			_w_tmpl_idx += 1
			if not (_w_sp is Dictionary): continue
			var _w_template_id: String = str(_w_sp.get("template_id", ""))
			var _w_tmpl: Dictionary = _w_enemies_dict.get(_w_template_id, {})
			if _w_tmpl.is_empty(): continue
			var _w_type_key: String = _w_template_id
			if _w_type_key.begins_with("enemy."):
				_w_type_key = _w_type_key.substr(6)
			var _w_defn: Dictionary = {
				"id":      "wave_%d_%d" % [_round_no, _w_built],
				"name":   str(_w_tmpl.get("name", _w_template_id)),
				"type":   _w_type_key,
				"faction": "enemy",
			}
			_w_new_actors.append(EnemyActor.from_definition(_w_defn, t, _w_actor_cfg))
			_w_built += 1

		# Determine walkable cells; use ENEMY-SIDE (highest columns) for placement.
		# Purely deterministic: sort walkable cells descending by col, tiebreak row then col.
		var _w_walkable: Dictionary = StageTerrain.walkable_set(ectx.terrain) \
			if not ectx.terrain.is_empty() else {}
		# Build occupied set from all living actors.
		var _w_occupied: Dictionary = {}
		for _w_oa in ectx.actors:
			if _w_oa is Dictionary and not bool(_w_oa.get("is_dead", false)):
				var _w_op: Dictionary = _w_oa.get("grid_pos", {})
				if not _w_op.is_empty():
					_w_occupied["%d,%d" % [int(_w_op.get("col", 0)), int(_w_op.get("row", 0))]] = true
		if not _w_walkable.is_empty():
			# Build candidate cells sorted descending by col (highest col = enemy side),
			# tiebreak row asc then col asc for full determinism.
			var _w_candidate_keys: Array = []
			for _w_k in _w_walkable:
				if not _w_occupied.has(_w_k):
					_w_candidate_keys.append(_w_k)
			_w_candidate_keys.sort_custom(func(a: String, b: String) -> bool:
				var _ap := a.split(","); var _bp := b.split(",")
				var _ac: int = int(_ap[0]); var _bc: int = int(_bp[0])
				if _ac != _bc: return _ac > _bc  # highest col first (enemy side)
				var _ar: int = int(_ap[1]); var _br: int = int(_bp[1])
				if _ar != _br: return _ar < _br   # row asc tiebreak
				return _ac < _bc                  # col asc final tiebreak
			)
			var _w_cell_idx: int = 0
			for _w_na in _w_new_actors:
				if _w_cell_idx >= _w_candidate_keys.size():
					break
				var _w_ck: String = _w_candidate_keys[_w_cell_idx]
				var _w_ck_parts := _w_ck.split(",")
				GridService.assign_grid_pos(_w_na,
					int(_w_ck_parts[0]), int(_w_ck_parts[1]))
				_w_occupied[_w_ck] = true
				_w_cell_idx += 1
		else:
			# Legacy path (no terrain): mirror GridService enemy packing — rightmost columns.
			var _w_bal_leg: Dictionary = {}
			if flow_ctx.config_service != null:
				_w_bal_leg = flow_ctx.config_service.get_balance()
			var _w_grid_leg: Dictionary = _w_bal_leg.get("data", {}).get("grid", {})
			var _w_cols: int = GridService.get_board_cols(_w_grid_leg)
			var _w_rows: int = GridService.get_board_rows(_w_grid_leg)
			# Collect unoccupied rightmost cells: descending col, ascending row.
			var _w_leg_cells: Array = []
			for _w_leg_c in range(_w_cols - 1, -1, -1):
				for _w_leg_r in range(_w_rows):
					var _w_leg_k: String = "%d,%d" % [_w_leg_c, _w_leg_r]
					if not _w_occupied.has(_w_leg_k):
						_w_leg_cells.append({ "col": _w_leg_c, "row": _w_leg_r })
			var _w_leg_idx: int = 0
			for _w_na in _w_new_actors:
				if _w_leg_idx >= _w_leg_cells.size():
					break
				var _w_leg_cell: Dictionary = _w_leg_cells[_w_leg_idx]
				GridService.assign_grid_pos(_w_na,
					int(_w_leg_cell.get("col", 0)), int(_w_leg_cell.get("row", 0)))
				_w_occupied["%d,%d" % [int(_w_leg_cell.get("col", 0)), int(_w_leg_cell.get("row", 0))]] = true
				_w_leg_idx += 1

		# Append new actors to ectx.actors and their ids to the END of initiative_order.
		# Never re-sort — "readiness computed once" invariant (V2-COMBAT-001) preserved.
		var _w_init_order: Array = combat_state.get("initiative_order", [])
		for _w_na in _w_new_actors:
			ectx.actors.append(_w_na)
			_w_init_order.append({ "id": str(_w_na.get("id", "")), "name": str(_w_na.get("name", "")) })
		combat_state["initiative_order"] = _w_init_order
		# §4-F: increment waves_spawned and set all_waves_spawned flag.
		combat_state["waves_spawned"] = _waves_so_far + 1
		combat_state["all_waves_spawned"] = int(combat_state.get("waves_spawned", 0)) >= int(combat_state.get("total_waves", 9999))
		logger.info(t, "combat.wave.spawned", "ENDURE wave spawned", {
			"round":            _round_no,
			"count":            _w_new_actors.size(),
			"wave_group":       _wave_group,
			"wave_n":           _wave_n,
			"wave_size_used":   _wave_size,
			"waves_spawned":    int(combat_state.get("waves_spawned", 0)),
			"total_waves":      int(combat_state.get("total_waves", 0)),
			"all_waves_spawned": bool(combat_state.get("all_waves_spawned", false)),
		})

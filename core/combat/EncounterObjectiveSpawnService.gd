# res://core/combat/EncounterObjectiveSpawnService.gd
# V2-INFRA-003 Phase 6 Slice 6I: the two OBJECTIVE-ACTOR SPAWN blocks of encounter setup,
# moved verbatim out of core/state/flow/states/venture/FlowEncounterState.gd::enter()
# (the PURIFY_SHRINE block that sat at :238-:330, and the RECOVER / PROTECT / PURSUE /
# GUIDE_SPIRIT block that sat at :412-:825 — the single largest sub-unit of that 982-line
# method at 414 lines).
#
# WHAT THIS IS. Everything that turns the resolution mode plus the already-placed party and
# enemy actors plus the generated terrain into the ONE extra actor a mode needs on the board,
# and — for GUIDE_SPIRIT only — the seeded runtime decisions that ride along on
# objective_params. ENDURE and COMBAT spawn nothing and fall straight through.
#
# WHY IT IS NOT PART OF CombatRoundSpawnService. That service owns MID-ROUND spawning: the
# RECOVER interval reinforcements and the ENDURE waves, both keyed on round_counter, both
# appending to combat_state.initiative_order after initiative already exists. This class runs
# ONCE, before combat_state exists at all, and its output is placed by depth-scaled candidate
# sorting rather than CombatRoundSpawnService's fixed col-desc/row-asc scan. The two share no
# code path. What they DID share — the { birth_stats, enemy_types } assembly — already has a
# single owner (ConfigService.get_enemy_actor_cfg, slice 6B); the caller reads it once and
# hands it in here as `actor_cfg`, so this class assembles no config of its own and adds no
# sixth longhand site.
#
# CONTRACT (same as every Phase 6 sibling):
#   - Typed RefCounted. Explicit dependencies at construction — no autoloads, no service
#     locator, no reaching back into FlowRuntime.
#   - NO flow_machine. This class cannot transition state or rebuild a snapshot.
#   - Never calls SaveService and never sets flow_ctx.save_request. Neither moved block
#     requested a save before the move and neither does now: FlowContext.request_save() joins
#     reasons with "|", so a save queued here would glue its reason onto the reason string of
#     the dispatch that is already in flight.
#   - Calls no controller.
#
# CONSTRUCTOR NOTE. config_service and logger are declared UNTYPED, deliberately. FlowContext
# declares both untyped itself (FlowContext.gd:51,53) and test harnesses substitute mock
# config objects into ctx.config_service; typing them here would impose a constraint the
# pre-extraction code did not have. Both fields exist for signature parity with the Phase 6
# siblings — the moved bodies read flow_ctx.config_service and flow_ctx.logger verbatim, as
# they did before, and that is preserved rather than "tidied" because the two can in
# principle differ.
#
# WHAT IT TOUCHES — the complete read/write set, verified line by line:
#
#   READS
#     flow_ctx.encounter_ctx.resolution_mode      mode gate for both methods
#     flow_ctx.encounter_ctx.terrain              legacy (empty) vs irregular-board placement
#     flow_ctx.encounter_ctx.encounter_id         embedded in all four RNG seed paths
#     flow_ctx.encounter_ctx.objective_params     relic/entity/quarry/spirit def id, name,
#                                                 max_hp, damage mul, destination_min_distance
#     flow_ctx.campaign_seed                      get_rng(); null-guarded, hash() fallback
#     flow_ctx.dev_guide_mode / dev_guide_joins   draw-then-override dev toggles
#     flow_ctx.config_service.get_balance()       data.actor.structures, data.combat.shrine,
#                                                 data.combat.objective_placement
#     flow_ctx.logger                             two dev-override info lines
#     echo_actors / enemy_actors                  grid_pos only (occupancy + party centroid row)
#     completion_index, actor_cfg, t              passed in
#
#   WRITES
#     flow_ctx.encounter_ctx.objective_params     GUIDE_SPIRIT only — guide_mode,
#                                                 spirit_joins_battle, spirit_name, and (escort
#                                                 only) destination_col / destination_row.
#                                                 CombatState.create() threads objective_params
#                                                 verbatim onto combat_state downstream.
#     the returned actor dict                     freshly built by StructureActor /
#                                                 EnemyActor.from_definition; never appended to
#                                                 ectx.actors here — the caller does that.
#
#   NOT TOUCHED: save data (never read, never written), ectx.actors, ectx.combat_state (it does
#   not exist yet at this point in the encounter), ectx.round_bark_events, flow_ctx.last_snapshot,
#   flow_ctx.flow_machine, and the echo/enemy actor dicts themselves (grid_pos is read, never
#   written).
#
# DETERMINISM — the reason this file is verbatim rather than tidied. Four seeded draws live
# here and NONE of their seed path strings, draw counts or draw ORDER changed:
#     "combat.guide_mode." + encounter_id          1 draw   (coin flip)
#     "combat.spirit_name." + encounter_id         1 draw for gender, then NameBank
#                                                  .build_full_name() draws from the SAME
#                                                  generator — that sequence is order-critical
#                                                  and is preserved as one contiguous block
#     "combat.guide_spirit_joins." + encounter_id  1 draw   (escort only)
#     "combat.spirit_destination." + encounter_id  1 draw   (escort only, and only when at
#                                                  least one far candidate exists)
# Both dev toggles use DRAW-THEN-OVERRIDE: the seeded draw runs unconditionally and the
# override is applied afterwards, so RNG draw order is identical with or without the toggle.
# That shape is load-bearing and must not be "simplified" into a conditional draw.
# Every candidate list is built by iterating a Dictionary and then stably sorted before it is
# indexed, so cell selection is a total order and needs no RNG. No dispatch is added or removed.
#
# NO SHIM WAS LEFT (AGENTS.md #20). Both blocks were inline code with no name of their own, so
# there were no reflection call sites to repoint.
#
# PLACEMENT. All four spawn branches, and spawn_shrine() above them, pick their cell through
# GridService.place_on_terrain(). Each passes its own target column and its own row reference;
# see the note there before you change either.
#
# DEFECT NOTES — found while standing at this code, recorded in
# docs/v2-infra-003-defect-register.md and deliberately NOT fixed here: D80 (the shrine's
# legacy no-terrain default grid_pos col 0 row 4 collides with the RECOVER relic's identical
# default), D81 (PROTECT's centre column uses integer division on a possibly-negative
# sentinel when no candidate cell exists).

class_name EncounterObjectiveSpawnService
extends RefCounted

var flow_ctx: FlowContext
var config_service
var logger


func _init(_flow_ctx: FlowContext, _config_service = null, _logger = null) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


## Depth along COLUMNS for this realm's completion_index: 0 = echo/left side, 1 = enemy/deep
## side. Both spawn methods derive their target column from this, so the
## data.combat.objective_placement read happens once, here.
func _depth_fraction(completion_index: int) -> float:
	var cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var bal: Dictionary = flow_ctx.config_service.get_balance()
		cfg = ConfigService.get_objective_placement_cfg_from_balance(bal)
	var min_frac: float = float(cfg.get("depth_min_frac",     0.35))
	var max_frac: float = float(cfg.get("depth_max_frac",     1.0))
	var full_at:  float = float(cfg.get("completion_full_at", 6.0))
	return clampf(float(completion_index) / full_at, min_frac, max_frac)


## PURIFY_SHRINE only. Runs once, immediately AFTER GridService.place_actors() (the occupancy
## set it builds depends on the party and enemies already holding their cells) and BEFORE the
## objective_params derivation. Returns { "shrine_actor": Dictionary, "shrine_cfg": Dictionary }
## — both empty for every other mode. shrine_cfg is returned as well as shrine_actor because
## the caller needs it later, unchanged, for ShrineService.select_purifier(); re-reading it
## there would be a second read of the same balance subtree.
func spawn_shrine(
	echo_actors: Array,
	enemy_actors: Array,
	completion_index: int,
	t: int
) -> Dictionary:
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
			var _shrine_occupied: Dictionary = GridService.occupied_cells([echo_actors, enemy_actors])
			var _shrine_candidates: Array = GridService.collect_unoccupied_cells(
				_shrine_walkable, _shrine_occupied)

			# Depth fraction: 0 = echo/left side; 1 = enemy/right (max-col) side.
			var _op_f: float = _depth_fraction(completion_index)
			var _shrine_cols: Dictionary = GridService.candidate_column_range(_shrine_candidates)
			var _op_target_col: int = roundi(
				_shrine_cols["min_col"] + _op_f * float(_shrine_cols["max_col"] - _shrine_cols["min_col"]))
			# Row reference: board vertical centre.
			var _shrine_board_h: int = int(_shrine_terrain.get("bounds", {}).get("h", 12))
			var _shrine_mid_row: float = float(_shrine_board_h - 1) * 0.5

			var _shrine_cell: Dictionary = GridService.place_on_terrain(
				_shrine_candidates, float(_op_target_col), _shrine_mid_row)
			if not _shrine_cell.is_empty():
				shrine_actor["grid_pos"] = _shrine_cell
		# Runtime-only shrine fields — not in ActorSchema REQUIRED_FIELDS.
		shrine_actor["purify_stacks"] = []

	return { "shrine_actor": shrine_actor, "shrine_cfg": shrine_cfg }


## RECOVER / PROTECT / PURSUE / GUIDE_SPIRIT. Runs once, AFTER the objective_params derivation
## (every branch reads scaled values back off objective_params) and BEFORE the surprise-fear
## bump. Returns the single objective actor, or {} for COMBAT / PURIFY_SHRINE / ENDURE, which
## spawn no objective actor at all. The caller appends the result to all_actors.
##
## The depth fraction _op_f_p3 is computed unconditionally at the top, exactly as it was before
## the move — including for the modes that fall through the match and never use it.
func spawn_objective_actor(
	echo_actors: Array,
	enemy_actors: Array,
	actor_cfg: Dictionary,
	completion_index: int,
	t: int
) -> Dictionary:
	# V2-STAGE-004 P3: Spawn objective structure actor for RECOVER / PROTECT modes.
	# ENDURE spawns no objective actor (wave-only). Shrine path is unchanged above.
	var objective_actor: Dictionary = {}
	var _op_f_p3: float = _depth_fraction(completion_index)

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
				var _rec_occupied: Dictionary = GridService.occupied_cells([echo_actors, enemy_actors])
				var _rec_candidates: Array = GridService.collect_unoccupied_cells(
					_rec_walkable, _rec_occupied)
				var _rec_cols: Dictionary = GridService.candidate_column_range(_rec_candidates)
				var _rec_target_col: int = roundi(
					_rec_cols["min_col"] + _op_f_p3 * float(_rec_cols["max_col"] - _rec_cols["min_col"]))
				# Row reference: board vertical centre.
				var _rec_board_h: int = int(_rec_terrain.get("bounds", {}).get("h", 12))
				var _rec_mid_row: float = float(_rec_board_h - 1) * 0.5
				var _rec_cell: Dictionary = GridService.place_on_terrain(
					_rec_candidates, float(_rec_target_col), _rec_mid_row)
				if not _rec_cell.is_empty():
					objective_actor["grid_pos"] = _rec_cell

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
				var _prt_occupied: Dictionary = GridService.occupied_cells([echo_actors, enemy_actors])
				var _prt_candidates: Array = GridService.collect_unoccupied_cells(
					_prt_walkable, _prt_occupied)
				# Row reference: board vertical centre.
				var _prt_board_h: int = int(_prt_terrain.get("bounds", {}).get("h", 12))
				var _prt_mid_row: float = float(_prt_board_h - 1) * 0.5
				# Target column: board centre, not depth-scaled. PROTECT is the only mode that
				# ignores completion_index. D81: the integer division keeps the 999999 / -1
				# sentinels when there is no candidate cell — not fixed here.
				var _prt_cols: Dictionary = GridService.candidate_column_range(_prt_candidates)
				var _prt_centre_col: int = (int(_prt_cols["min_col"]) + int(_prt_cols["max_col"])) / 2
				var _prt_cell: Dictionary = GridService.place_on_terrain(
					_prt_candidates, float(_prt_centre_col), _prt_mid_row)
				if not _prt_cell.is_empty():
					objective_actor["grid_pos"] = _prt_cell
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
				var _qry_occupied: Dictionary = GridService.occupied_cells([echo_actors, enemy_actors])
				var _qry_candidates: Array = GridService.collect_unoccupied_cells(
					_qry_walkable, _qry_occupied)
				var _qry_cols: Dictionary = GridService.candidate_column_range(_qry_candidates)
				var _qry_target_col: int = roundi(
					_qry_cols["min_col"] + _op_f_p3 * float(_qry_cols["max_col"] - _qry_cols["min_col"]))
				# V2-COMBAT-002 Slice 6E: anchor the row tie-break to the PARTY's spawn band,
				# not the board's midpoint. `_op_f_p3` scales depth along COLUMNS only, so on
				# a tall board the old board-midpoint rule parked the quarry ~24 rows from a
				# party spawning in the top rows — a Chebyshev gap the depth fraction never
				# governed. PURSUE is uniquely punished by that because a quarry escape is an
				# IMMEDIATE defeat (CombatState.gd:200-202), so the mode became unwinnable by
				# geometry alone. Column depth (and therefore progression scaling) is unchanged.
				# Falls back to the board midpoint when no echo has a position.
				# This row reference is LOCAL to PURSUE. The other four modes pass the board
				# midpoint; do not propagate this one to them — it moves their spawn cells.
				var _qry_board_h: int = int(_qry_terrain.get("bounds", {}).get("h", 12))
				var _qry_mid_row: float = float(_qry_board_h - 1) * 0.5
				var _qry_row_sum: float = 0.0
				var _qry_row_n: int = 0
				for _qr_v in echo_actors:
					if _qr_v is Dictionary:
						var _qr_p: Dictionary = (_qr_v as Dictionary).get("grid_pos", {}) as Dictionary
						if not _qr_p.is_empty():
							_qry_row_sum += float(int(_qr_p.get("row", 0)))
							_qry_row_n += 1
				if _qry_row_n > 0:
					_qry_mid_row = _qry_row_sum / float(_qry_row_n)
				var _qry_cell: Dictionary = GridService.place_on_terrain(
					_qry_candidates, float(_qry_target_col), _qry_mid_row)
				if not _qry_cell.is_empty():
					objective_actor["grid_pos"] = _qry_cell

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
				var _gs_occupied: Dictionary = GridService.occupied_cells([echo_actors, enemy_actors])
				# place_on_terrain() sorts this array in place; the escort destination block
				# below re-reads it, so the reference must be the one declared above.
				_gs_candidates = GridService.collect_unoccupied_cells(_gs_walkable, _gs_occupied)
				var _gs_cols: Dictionary = GridService.candidate_column_range(_gs_candidates)
				var _gs_target_col: int = roundi(
					_gs_cols["min_col"] + _op_f_p3 * float(_gs_cols["max_col"] - _gs_cols["min_col"]))
				# Row reference: board vertical centre.
				var _gs_board_h: int = int(_gs_terrain.get("bounds", {}).get("h", 12))
				var _gs_mid_row: float = float(_gs_board_h - 1) * 0.5
				var _gs_cell: Dictionary = GridService.place_on_terrain(
					_gs_candidates, float(_gs_target_col), _gs_mid_row)
				if not _gs_cell.is_empty():
					objective_actor["grid_pos"] = _gs_cell

			# Escort — seed destination on the walkable BORDER/FRONTIER ring, Chebyshev distance
			# >= destination_min_distance from the spirit's spawn cell (relax to farthest frontier
			# cell if none qualify). A frontier cell is a walkable cell with at least one 4-dir
			# neighbour that is non-walkable OR out of bounds. On irregular StageTerrain the walkable
			# set is usually inset from the outer ring, so literal bounds cells (col==0 etc.) are
			# empty — the frontier ring is where the terrain actually ends. On a full-rect board the
			# frontier reduces to the literal edge cells, so behaviour there is preserved.
			var _gs_dest_col: int = -1
			var _gs_dest_row: int = -1
			if _gs_mode == "escort":
				var _gs_spawn_pos: Dictionary = objective_actor.get("grid_pos", { "col": 0, "row": 0 })
				var _gs_min_dist: int = int(_gs_obj_params.get("destination_min_distance", 6))
				var _gs_edge_candidates: Array = []
				if not _gs_terrain.is_empty():
					var _gs_walkable_dest: Dictionary = StageTerrain.walkable_set(_gs_terrain)
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
				else:
					# D80: a board with no terrain has no walkable set, so there is no frontier
					# ring to draw from and the escort used to get destination (-1,-1) — a cell no
					# spirit can ever stand on, making the objective uncompletable. Every cell of a
					# legacy board is walkable, so the frontier reduces to the literal board edge.
					# The authored rule then applies unchanged: distance filter, then a seeded pick.
					var _gs_bal_leg: Dictionary = {}
					if flow_ctx.config_service != null:
						_gs_bal_leg = flow_ctx.config_service.get_balance()
					var _gs_grid_leg: Dictionary = _gs_bal_leg.get("data", {}).get("grid", {})
					var _gs_cols_leg: int = GridService.get_board_cols(_gs_grid_leg)
					var _gs_rows_leg: int = GridService.get_board_rows(_gs_grid_leg)
					var _gs_occ_leg: Dictionary = GridService.occupied_cells([echo_actors, enemy_actors])
					for _gl_col in range(_gs_cols_leg):
						for _gl_row in range(_gs_rows_leg):
							if _gl_col != 0 and _gl_col != _gs_cols_leg - 1 \
									and _gl_row != 0 and _gl_row != _gs_rows_leg - 1:
								continue
							if _gs_occ_leg.has("%d,%d" % [_gl_col, _gl_row]):
								continue
							_gs_edge_candidates.append({ "col": _gl_col, "row": _gl_row })
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
					# D17: the relaxation has to keep a floor. With none, the farthest frontier
					# cell can be the spawn cell itself (one unoccupied frontier cell on a small
					# terrain island), and the escort latch then wins on round 1 with no movement.
					# Below the floor there is no valid destination, so choose none.
					var _gs_relaxed_dist: int = maxi(
						abs(int(_gs_edge_candidates[0]["col"]) - int(_gs_spawn_pos.get("col", 0))),
						abs(int(_gs_edge_candidates[0]["row"]) - int(_gs_spawn_pos.get("row", 0))))
					if _gs_relaxed_dist > 0:
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

	return objective_actor

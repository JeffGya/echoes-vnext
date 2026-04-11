class_name RealmGenerator

extends RefCounted

const SituationModelScript    := preload("res://core/realms/SituationModel.gd")     # V2-STAGE-001
const StageExploreModelScript := preload("res://core/realms/StageExploreModel.gd")  # V2-STAGE-001

# REALM-002: Deterministic stage list generator for a realm run.
# Pure static — no side effects, no ctx, no OS calls.
# Same inputs always produce identical output (determinism guarantee).
#
# Generation rules:
#   - Each stage has obj_count objectives picked from [obj_count_min, obj_count_max].
#   - Pre-boss objectives are weighted random: combat (weight 2) vs shrine (weight 1).
#   - The final objective of every stage is always "boss" (stub — no encounter logic yet).
#   - Stage summary type: "purification" if any pre-boss obj is shrine; "combat" otherwise.
#
# V2-STAGE-001: Each stage also gets an explore_map (StageExploreModel dict).
#   - Map dimensions are random and asymmetric, derived per-stage from realm_seed.
#   - Situations (SituationModel dicts) are scattered with minimum distance between them.
#   - 1–2 situations are marked is_objective=true.
#   - All start hidden (revealed=false).
#   - explore_map seed paths are appended after all existing draws — do NOT reorder.
#
# Post-MVP: REALM-003 extends this with objective group pools for richer stage composition.

# Weighted type pool for pre-boss objectives.
# Extend by appending entries — do NOT reorder (determinism).
const _PRE_BOSS_POOL: Array = [
	ObjectiveModel.TYPE_COMBAT,  # weight 2
	ObjectiveModel.TYPE_COMBAT,
	ObjectiveModel.TYPE_SHRINE,  # weight 1
]

# Minimum Chebyshev distance between any two situations.
const _MIN_SIT_DISTANCE: int = 4

# Default situation count range (used when config keys are absent).
const _DEFAULT_SIT_MIN: int = 4
const _DEFAULT_SIT_MAX: int = 6

# Stage-index bump applied to map size min/max per stage (makes later stages larger).
const _MAP_SIZE_STAGE_BUMP: int = 2


# Generate a deterministic list of StageModel dicts for a realm run.
#
# realm_seed:      the realm's derived seed (from CampaignSeed)
# stage_count:     how many stages this run has
# obj_count_min:   min objectives per stage (from realms.json config)
# obj_count_max:   max objectives per stage (from realms.json config)
# explore_cfg:     Dict with keys: sit_count_min, sit_count_max,
#                  map_width_min, map_width_max, map_height_min, map_height_max
#                  (all optional — safe defaults applied when missing)
#
# Returns Array of stage Dicts (each is a valid StageModel with explore_map).
static func generate(
	realm_seed: int,
	stage_count: int,
	obj_count_min: int,
	obj_count_max: int,
	explore_cfg: Dictionary = {}
) -> Array:
	var stages: Array = []

	for i in range(stage_count):
		# Stage-level RNG — all stage decisions derived from this
		var stage_rng := CampaignSeed.get_rng_from(realm_seed, "stage.%d" % i)
		var stage_seed := stage_rng.randi()

		# Pick objective count for this stage
		var obj_count := stage_rng.randi_range(
			max(obj_count_min, 1),  # at minimum 1 (the boss)
			max(obj_count_max, 1)
		)

		var objectives: Array = []
		var has_shrine := false

		# Generate pre-boss objectives (all but the last slot)
		var pre_boss_count := obj_count - 1
		for j in range(pre_boss_count):
			var obj_rng := CampaignSeed.get_rng_from(realm_seed, "stage.%d.obj.%d" % [i, j])
			var obj_seed := obj_rng.randi()
			var type_idx := obj_rng.randi_range(0, _PRE_BOSS_POOL.size() - 1)
			var obj_type: String = _PRE_BOSS_POOL[type_idx]
			if obj_type == ObjectiveModel.TYPE_SHRINE:
				has_shrine = true
			objectives.append(ObjectiveModel.make(j, obj_type, obj_seed))

		# Final objective: always boss (stub)
		var boss_idx := pre_boss_count
		var boss_rng := CampaignSeed.get_rng_from(realm_seed, "stage.%d.obj.%d" % [i, boss_idx])
		var boss_seed := boss_rng.randi()
		objectives.append(ObjectiveModel.make(boss_idx, ObjectiveModel.TYPE_BOSS, boss_seed))

		# Derive stage summary type from pre-boss composition
		var stage_type: String = StageModel.TYPE_PURIFICATION if has_shrine else StageModel.TYPE_COMBAT

		# V2-STAGE-001: Generate exploration map for this stage.
		# Seed paths are appended after all existing draws — never reorder.
		var explore_map := _generate_explore_map(realm_seed, i, explore_cfg)

		stages.append(StageModel.make(i, stage_type, stage_seed, objectives, explore_map))

	return stages


# V2-STAGE-001: Generate a deterministic StageExploreModel dict for one stage.
# All RNG paths use the "stage.N.explore.*" namespace — appended after existing draws.
static func _generate_explore_map(realm_seed: int, stage_index: int, cfg: Dictionary) -> Dictionary:
	# --- Map dimensions ---
	var size_rng := CampaignSeed.get_rng_from(realm_seed, "stage.%d.explore.map_size" % stage_index)

	# Apply stage-index bump so later stages within the same realm are bigger.
	var bump := stage_index * _MAP_SIZE_STAGE_BUMP

	var w_min := int(cfg.get("map_width_min",  StageExploreModelScript.MIN_WIDTH))  + bump
	var w_max := int(cfg.get("map_width_max",  w_min + 15))                   + bump
	var h_min := int(cfg.get("map_height_min", StageExploreModelScript.MIN_HEIGHT)) + bump
	var h_max := int(cfg.get("map_height_max", h_min + 12))                   + bump

	# Enforce absolute floor
	w_min = max(w_min, StageExploreModelScript.MIN_WIDTH)
	w_max = max(w_max, w_min)
	h_min = max(h_min, StageExploreModelScript.MIN_HEIGHT)
	h_max = max(h_max, h_min)

	var width:  int = size_rng.randi_range(w_min, w_max)
	var height: int = size_rng.randi_range(h_min, h_max)

	# --- Situation count ---
	var count_rng  := CampaignSeed.get_rng_from(realm_seed, "stage.%d.explore.sit_count" % stage_index)
	var sit_min    := int(cfg.get("sit_count_min", _DEFAULT_SIT_MIN))
	var sit_max    := int(cfg.get("sit_count_max", _DEFAULT_SIT_MAX))
	var sit_count  := count_rng.randi_range(max(sit_min, 2), max(sit_max, 2))

	# --- Objective count: 1 when sit_count <= 3, 2 otherwise ---
	var obj_count := 1 if sit_count <= 3 else 2

	# --- Situation placement ---
	var situations: Array = _place_situations(realm_seed, stage_index, width, height, sit_count, obj_count)

	return StageExploreModelScript.make(width, height, situations)


# Place situations deterministically on the map with minimum distance enforcement.
# Returns Array of SituationModel dicts.
static func _place_situations(
	realm_seed: int,
	stage_index: int,
	width: int,
	height: int,
	sit_count: int,
	obj_count: int
) -> Array:
	var situations: Array = []
	var placed_positions: Array = []  # Array[{col, row}]

	for idx in range(sit_count):
		var sit_rng  := CampaignSeed.get_rng_from(realm_seed, "stage.%d.explore.sit.%d" % [stage_index, idx])
		var sit_seed := sit_rng.randi()

		# Pick situation type from pool
		var type_idx  := sit_rng.randi_range(0, SituationModelScript.SITUATION_TYPE_POOL.size() - 1)
		var sit_type: String = SituationModelScript.SITUATION_TYPE_POOL[type_idx]

		# Objectives always marked as combat (V2-STAGE-002 broadens this)
		var is_obj := idx < obj_count
		if is_obj:
			sit_type = SituationModelScript.TYPE_COMBAT

		# Find a valid position — retry up to 20 times before relaxing constraint
		var col := 0
		var row := 0
		var placed := false
		var max_attempts := 20

		for attempt in range(max_attempts):
			var try_rng := CampaignSeed.get_rng_from(realm_seed, "stage.%d.explore.sit.%d.pos.%d" % [stage_index, idx, attempt])
			# Keep situations away from the party entry edge (col >= 2)
			var c := try_rng.randi_range(2, width - 1)
			var r := try_rng.randi_range(0, height - 1)

			if _is_far_enough(c, r, placed_positions):
				col = c
				row = r
				placed = true
				break

		if not placed:
			# Relaxed fallback: just pick any unoccupied cell
			var fb_rng := CampaignSeed.get_rng_from(realm_seed, "stage.%d.explore.sit.%d.fallback" % [stage_index, idx])
			col = fb_rng.randi_range(2, width - 1)
			row = fb_rng.randi_range(0, height - 1)

		placed_positions.append({ "col": col, "row": row })
		situations.append(SituationModelScript.make(
			"sit.%d" % idx,
			sit_type,
			col,
			row,
			sit_seed,
			is_obj
		))

	return situations


# Returns true if (col, row) is at least _MIN_SIT_DISTANCE (Chebyshev) from all placed positions.
static func _is_far_enough(col: int, row: int, placed: Array) -> bool:
	for pos_v in placed:
		var pos: Dictionary = pos_v if pos_v is Dictionary else {}
		var dc: int = abs(col - int(pos.get("col", 0)))
		var dr: int = abs(row - int(pos.get("row", 0)))
		if max(dc, dr) < _MIN_SIT_DISTANCE:
			return false
	return true

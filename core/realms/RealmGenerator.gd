class_name RealmGenerator

extends RefCounted

const SituationModelScript    := preload("res://core/realms/SituationModel.gd")     # V2-STAGE-001
const StageExploreModelScript := preload("res://core/realms/StageExploreModel.gd")  # V2-STAGE-001
const ContactModelScript      := preload("res://core/realms/ContactModel.gd")       # V2-STAGE-003

# Lesson 8: data-heavy content in JSON, loaded once into a static cache.
static var _npc_lines_loaded: bool = false
static var _npc_lines: Dictionary = {}

static func _ensure_npc_lines_loaded() -> void:
	if _npc_lines_loaded:
		return
	var f := FileAccess.open("res://data/conversations/npc_opening_lines.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary:
			_npc_lines = parsed
	_npc_lines_loaded = true

# REALM-002: Deterministic stage list generator for a realm run.
# Pure static — no side effects, no ctx, no OS calls.
# Same inputs always produce identical output (determinism guarantee).
#
# Generation rules:
#   - Each stage has obj_count objectives picked from [obj_count_min, obj_count_max].
#   - Pre-boss objectives are drawn from a configurable pool (config-driven, V2-STAGE-002).
#   - The final objective of every stage is always "boss" (stub — no encounter logic yet).
#   - Stage summary type: "purification" if any pre-boss obj is shrine;
#     "recovery" if any obj is recover; "protection" if any obj is protect;
#     "combat" otherwise.
#
# V2-STAGE-001: Each stage also gets an explore_map (StageExploreModel dict).
#   - Map dimensions are random and asymmetric, derived per-stage from realm_seed.
#   - Situations (SituationModel dicts) are scattered with minimum distance between them.
#   - 1–2 situations are marked is_objective=true with objective_index bound to stage.objectives.
#   - All start hidden (revealed=false).
#   - explore_map seed paths are appended after all existing draws — do NOT reorder.
#
# V2-STAGE-002: Objective pool is now config-driven.
#   - Realm overrides via realm.objective_pool in realms.json.
#   - Falls back to balance.json data.stages.foundation_objective_pool.
#   - Falls back to _PRE_BOSS_POOL_FALLBACK if neither is present.
#   - Situation types on objective situations now match their objective type.
#   - objective_index on each objective situation binds it to stage.objectives[idx].

# Hardcoded fallback pool — used when no config is present.
# IMMUTABLE: never reorder entries (determinism guarantee).
# Append new entries at end only; bump version if structure changes.
const _PRE_BOSS_POOL_FALLBACK: Array = [
	ObjectiveModel.TYPE_COMBAT,  # weight 2
	ObjectiveModel.TYPE_COMBAT,
	ObjectiveModel.TYPE_SHRINE,  # weight 1
]

# Burden variant keys per role — must stay in sync with contact_responses.json burden_variants.
# IMMUTABLE order: determinism guarantee. Append new keys at end only.
const _BURDEN_VARIANTS_BY_ROLE: Dictionary = {
	"witness":        ["still_waiting", "grateful_to_be_found"],
	"guide":          ["knows_too_much", "reluctant_helper"],
	"charge":         ["hiding_fear", "refusing_danger"],
	"claimant":       ["defending_what_is_lost", "testing_the_newcomers"],
	"temporary_ally": ["measuring_worth", "waiting_for_the_right_sign"],
}

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
#                  map_width_min, map_width_max, map_height_min, map_height_max,
#                  objective_pool (Array[String] — realm override of pre-boss pool)
#                  (all optional — safe defaults applied when missing)
# stages_cfg:      Dict from balance.json data.stages — foundation_objective_pool fallback.
#                  (optional — safe defaults applied when missing)
#
# Returns Array of stage Dicts (each is a valid StageModel with explore_map).
static func generate(
	realm_seed: int,
	stage_count: int,
	obj_count_min: int,
	obj_count_max: int,
	explore_cfg: Dictionary = {},
	stages_cfg: Dictionary = {},
	contact_cfg: Dictionary = {}
) -> Array:
	# Resolve the pre-boss objective pool (config-driven, realm override wins).
	var obj_pool: Array = _resolve_objective_pool(explore_cfg, stages_cfg)

	var stages: Array = []

	for i in range(stage_count):
		# Stage-level RNG — all stage decisions derived from this
		var stage_rng := CampaignSeed.get_rng_from(realm_seed, "stage.%d" % i)
		var stage_seed := stage_rng.randi()

		# Pick objective count for this stage.
		# Minimum 2: always 1 boss + at least 1 pre-boss primary objective.
		# A stage with only the boss has no explorable objective — player has nothing to find.
		var obj_count := stage_rng.randi_range(
			max(obj_count_min, 2),
			max(obj_count_max, 2)
		)

		var objectives: Array = []

		# Generate pre-boss objectives (all but the last slot)
		var pre_boss_count := obj_count - 1
		for j in range(pre_boss_count):
			var obj_rng := CampaignSeed.get_rng_from(realm_seed, "stage.%d.obj.%d" % [i, j])
			var obj_seed := obj_rng.randi()
			var type_idx := obj_rng.randi_range(0, obj_pool.size() - 1)
			var obj_type: String = obj_pool[type_idx]
			# required: true for all pre-boss objectives (pursue is optional per config default)
			var is_required: bool = (obj_type != ObjectiveModel.TYPE_PURSUE)
			objectives.append(ObjectiveModel.make(j, obj_type, obj_seed, {}, false, is_required))

		# Final objective: always boss (stub)
		var boss_idx := pre_boss_count
		var boss_rng := CampaignSeed.get_rng_from(realm_seed, "stage.%d.obj.%d" % [i, boss_idx])
		var boss_seed := boss_rng.randi()
		objectives.append(ObjectiveModel.make(boss_idx, ObjectiveModel.TYPE_BOSS, boss_seed, {}, false, false))

		# Derive stage summary type from pre-boss composition
		var stage_type: String = _derive_stage_type(objectives, pre_boss_count)

		# V2-STAGE-001/002: Generate exploration map for this stage.
		# Seed paths are appended after all existing draws — never reorder.
		var explore_map := _generate_explore_map(realm_seed, i, explore_cfg, objectives, contact_cfg)

		stages.append(StageModel.make(i, stage_type, stage_seed, objectives, explore_map))

	return stages


# Resolve the objective pool for pre-boss generation.
# Priority: realm.objective_pool (in explore_cfg) → balance.stages.foundation_objective_pool → _PRE_BOSS_POOL_FALLBACK
static func _resolve_objective_pool(explore_cfg: Dictionary, stages_cfg: Dictionary) -> Array:
	var realm_pool_v: Variant = explore_cfg.get("objective_pool", null)
	if realm_pool_v is Array and not (realm_pool_v as Array).is_empty():
		return realm_pool_v as Array

	var foundation_pool_v: Variant = stages_cfg.get("foundation_objective_pool", null)
	if foundation_pool_v is Array and not (foundation_pool_v as Array).is_empty():
		return foundation_pool_v as Array

	return _PRE_BOSS_POOL_FALLBACK


# Derive the stage summary type from the pre-boss objectives.
# Used for display (stage overview description) — NOT for encounter resolution mode.
static func _derive_stage_type(objectives: Array, pre_boss_count: int) -> String:
	var has_shrine   := false
	var has_recover  := false
	var has_protect  := false

	for j in range(mini(pre_boss_count, objectives.size())):
		var obj: Dictionary = objectives[j] if objectives[j] is Dictionary else {}
		match str(obj.get("type", "")):
			ObjectiveModel.TYPE_SHRINE:  has_shrine  = true
			ObjectiveModel.TYPE_RECOVER: has_recover = true
			ObjectiveModel.TYPE_PROTECT: has_protect = true

	if has_shrine:
		return StageModel.TYPE_PURIFICATION
	if has_protect:
		return StageModel.TYPE_PROTECTION
	if has_recover:
		return StageModel.TYPE_RECOVERY
	return StageModel.TYPE_COMBAT


# V2-STAGE-001/002: Generate a deterministic StageExploreModel dict for one stage.
# All RNG paths use the "stage.N.explore.*" namespace — appended after existing draws.
# objectives: pre-generated Array of ObjectiveModel dicts (for binding situation types).
static func _generate_explore_map(
	realm_seed: int,
	stage_index: int,
	cfg: Dictionary,
	objectives: Array = [],
	contact_cfg: Dictionary = {}
) -> Dictionary:
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
	# Capped by the number of pre-boss objectives actually generated.
	var pre_boss_obj_count := 0
	for obj_v in objectives:
		var obj: Dictionary = obj_v if obj_v is Dictionary else {}
		if str(obj.get("type", "")) != ObjectiveModel.TYPE_BOSS:
			pre_boss_obj_count += 1
	var obj_count := mini(1 if sit_count <= 3 else 2, pre_boss_obj_count)

	# --- Situation placement ---
	var situations: Array = _place_situations(
		realm_seed, stage_index, width, height, sit_count, obj_count, objectives, contact_cfg
	)

	return StageExploreModelScript.make(width, height, situations)


# Place situations deterministically on the map with minimum distance enforcement.
# V2-STAGE-002: objective situations now derive their type from the matching objective,
# and carry objective_index to bind them to stage.objectives[idx].
# Returns Array of SituationModel dicts.
static func _place_situations(
	realm_seed: int,
	stage_index: int,
	width: int,
	height: int,
	sit_count: int,
	obj_count: int,
	objectives: Array = [],
	contact_cfg: Dictionary = {}
) -> Array:
	var situations: Array = []
	var placed_positions: Array = []  # Array[{col, row}]

	for idx in range(sit_count):
		var sit_rng  := CampaignSeed.get_rng_from(realm_seed, "stage.%d.explore.sit.%d" % [stage_index, idx])
		var sit_seed := sit_rng.randi()

		# Pick situation type from pool
		var type_idx  := sit_rng.randi_range(0, SituationModelScript.SITUATION_TYPE_POOL.size() - 1)
		var sit_type: String = SituationModelScript.SITUATION_TYPE_POOL[type_idx]

		var is_obj := idx < obj_count
		var bound_obj_index := -1

		if is_obj:
			bound_obj_index = idx
			# V2-STAGE-002: derive sit_type from the corresponding objective type.
			# Objective index idx corresponds to pre-boss objective at position idx.
			if idx < objectives.size() and objectives[idx] is Dictionary:
				var obj: Dictionary = objectives[idx]
				sit_type = str(obj.get("type", SituationModelScript.TYPE_COMBAT))

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
			is_obj,
			bound_obj_index  # V2-STAGE-002: bind to objective
		))

		# V2-STAGE-003: generate and attach contact for NPC situations
		if sit_type == SituationModelScript.TYPE_NPC and not contact_cfg.is_empty():
			var contact := _generate_contact(
				realm_seed, stage_index, idx, "sit.%d" % idx, contact_cfg, 0
			)
			situations[situations.size() - 1]["contact"] = contact
			situations[situations.size() - 1]["role"] = str(contact.get("role", ""))

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


# V2-STAGE-003: Generate a deterministic ContactModel dict for one NPC situation.
# fail_count is appended as a version suffix to all seed paths so NPC re-seeds on retry.
# All paths under "stage.N.explore.sit.M.contact.vF.*" — appended after existing draws, never reorder.
static func _generate_contact(
	realm_seed: int,
	stage_index: int,
	sit_index: int,
	sit_id: String,
	contact_cfg: Dictionary,
	fail_count: int = 0
) -> Dictionary:
	var v := "v%d" % fail_count
	var ns := "stage.%d.explore.sit.%d.contact.%s" % [stage_index, sit_index, v]

	# Role: pick from realm's role_pool
	# realm_id comes from contact_cfg["realm_id"] when caller knows it; fallback to stage_index hint
	var realm_id: String = str(contact_cfg.get("realm_id", "realm.%02d" % (stage_index + 1)))
	var role_pools_v: Variant = contact_cfg.get("role_pool_by_realm", {})
	var role_pools: Dictionary = role_pools_v if role_pools_v is Dictionary else {}
	var role_pool_v: Variant = role_pools.get(realm_id, [])
	var role_pool: Array = role_pool_v if (role_pool_v is Array and not (role_pool_v as Array).is_empty()) else []
	if role_pool.is_empty():
		var fb_pool_v: Variant = contact_cfg.get("role_pool_fallback", [])
		role_pool = fb_pool_v if (fb_pool_v is Array and not (fb_pool_v as Array).is_empty()) else ["witness"]
	var role_rng := CampaignSeed.get_rng_from(realm_seed, ns + ".role")
	var role: String = str(role_pool[role_rng.randi_range(0, role_pool.size() - 1)])

	# Primary virtue: from realm config (passed via contact_cfg["realm_virtue"] or fallback "courage")
	var virtue_primary: String = str(contact_cfg.get("realm_virtue", "courage"))

	# Secondary virtue: pick from adjacent virtues of primary
	var virtue_wheel_v: Variant = contact_cfg.get("virtue_wheel", [])
	var virtue_wheel: Array = virtue_wheel_v if virtue_wheel_v is Array else []
	var virtue_secondary: String = virtue_primary
	if virtue_wheel.size() >= 3:
		var idx_in_wheel := virtue_wheel.find(virtue_primary)
		if idx_in_wheel >= 0:
			var wheel_size := virtue_wheel.size()
			var adj_left  := str(virtue_wheel[(idx_in_wheel - 1 + wheel_size) % wheel_size])
			var adj_right := str(virtue_wheel[(idx_in_wheel + 1) % wheel_size])
			var virt_rng := CampaignSeed.get_rng_from(realm_seed, ns + ".virtue")
			virtue_secondary = adj_left if virt_rng.randi() % 2 == 0 else adj_right

	# Disposition: pick from disposition_pool_by_role
	var disp_pools_v: Variant = contact_cfg.get("disposition_pool_by_role", {})
	var disp_pools: Dictionary = disp_pools_v if disp_pools_v is Dictionary else {}
	var disp_pool_v: Variant = disp_pools.get(role, [])
	var disp_pool: Array = disp_pool_v if (disp_pool_v is Array and not (disp_pool_v as Array).is_empty()) else ["reflective"]
	var disp_rng := CampaignSeed.get_rng_from(realm_seed, ns + ".disposition")
	var disposition: String = str(disp_pool[disp_rng.randi_range(0, disp_pool.size() - 1)])

	# Name: pick from realm name_pool
	var name_pools_v: Variant = contact_cfg.get("name_pool_by_realm", {})
	var name_pools: Dictionary = name_pools_v if name_pools_v is Dictionary else {}
	var name_pool_v: Variant = name_pools.get(realm_id, [])
	var name_pool: Array = name_pool_v if (name_pool_v is Array and not (name_pool_v as Array).is_empty()) else []
	if name_pool.is_empty():
		var fb_name_v: Variant = contact_cfg.get("name_pool_fallback", [])
		name_pool = fb_name_v if (fb_name_v is Array and not (fb_name_v as Array).is_empty()) else ["An Unknown Presence"]
	var name_rng := CampaignSeed.get_rng_from(realm_seed, ns + ".name")
	var npc_name: String = str(name_pool[name_rng.randi_range(0, name_pool.size() - 1)])

	# Fear / morale: pick within role's fear_range / morale_range
	var roles_cfg_v: Variant = contact_cfg.get("roles", {})
	var roles_cfg: Dictionary = roles_cfg_v if roles_cfg_v is Dictionary else {}
	var role_cfg_v: Variant = roles_cfg.get(role, {})
	var role_cfg: Dictionary = role_cfg_v if role_cfg_v is Dictionary else {}
	var fear_range_v: Variant = role_cfg.get("fear_range", [20, 50])
	var fear_range: Array = fear_range_v if (fear_range_v is Array and not (fear_range_v as Array).is_empty()) else [20, 50]
	var morale_range_v: Variant = role_cfg.get("morale_range", [30, 60])
	var morale_range: Array = morale_range_v if (morale_range_v is Array and not (morale_range_v as Array).is_empty()) else [30, 60]
	var emo_rng := CampaignSeed.get_rng_from(realm_seed, ns + ".emotion")
	var fear: int   = emo_rng.randi_range(int(fear_range[0]),   int(fear_range[fear_range.size()-1]))
	var morale: int = emo_rng.randi_range(int(morale_range[0]), int(morale_range[morale_range.size()-1]))

	# Turn count: from role config
	var turn_count_base: int = int(role_cfg.get("turn_count_base", 2))

	var contact := ContactModelScript.make(
		sit_id, role, virtue_primary, virtue_secondary, fear, morale, disposition, npc_name, turn_count_base
	)

	# Pick burden variant (NPC opening-line archetype) deterministically.
	var bv_pool_v: Variant = _BURDEN_VARIANTS_BY_ROLE.get(role, [])
	var bv_pool: Array = bv_pool_v if bv_pool_v is Array else []
	if not bv_pool.is_empty():
		var bv_rng := CampaignSeed.get_rng_from(realm_seed, ns + ".burden_variant")
		contact["burden_variant"] = str(bv_pool[bv_rng.randi_range(0, bv_pool.size() - 1)])

	# Select opening line deterministically — embeds virtue signal in prose (no explicit label).
	# Pool: npc_opening_lines.json → role → virtue_primary → Array[String].
	_ensure_npc_lines_loaded()
	var role_pool_lines_v: Variant = _npc_lines.get(role, {})
	var role_pool_lines: Dictionary = role_pool_lines_v if role_pool_lines_v is Dictionary else {}
	var virtue_lines_v: Variant = role_pool_lines.get(virtue_primary, [])
	var virtue_lines: Array = virtue_lines_v if virtue_lines_v is Array else []
	if not virtue_lines.is_empty():
		var line_rng := CampaignSeed.get_rng_from(realm_seed, ns + ".npc_line")
		contact["npc_line"] = str(virtue_lines[line_rng.randi_range(0, virtue_lines.size() - 1)])

	return contact

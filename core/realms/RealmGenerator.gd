class_name RealmGenerator

extends RefCounted

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
# Post-MVP: REALM-003 extends this with objective group pools for richer stage composition.

# Weighted type pool for pre-boss objectives.
# Extend by appending entries — do NOT reorder (determinism).
const _PRE_BOSS_POOL: Array = [
	ObjectiveModel.TYPE_COMBAT,  # weight 2
	ObjectiveModel.TYPE_COMBAT,
	ObjectiveModel.TYPE_SHRINE,  # weight 1
]


# Generate a deterministic list of StageModel dicts for a realm run.
#
# realm_seed:    the realm's derived seed (from CampaignSeed)
# stage_count:   how many stages this run has
# obj_count_min: min objectives per stage (from realms.json config)
# obj_count_max: max objectives per stage (from realms.json config)
#
# Returns Array of stage Dicts (each is a valid StageModel).
static func generate(
	realm_seed: int,
	stage_count: int,
	obj_count_min: int,
	obj_count_max: int
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

		stages.append(StageModel.make(i, stage_type, stage_seed, objectives))

	return stages

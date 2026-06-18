class_name EncounterRoundsState

extends State

func _init() -> void:
	super(EncounterStateIds.ROUNDS)

func enter(ctx: RefCounted, t: int) -> void:
	var ectx := ctx as EncounterContext
	ectx.encounter_step += 1
	ectx.phase_index = 2

	# COMBAT-001: initialize combat state from pre-placed actors.
	# COMBAT-002: pass placement_seed + initiative_cfg for deterministic turn order.
	ectx.combat_state = CombatState.create(
		ectx.actors,
		ectx.resolution_mode,
		ectx.placement_seed,
		ectx.initiative_cfg,
		ectx.objective_params
	)

	# Minimal phase_snapshot — FlowEncounterState.build_snapshot() drives the real UI snapshot.
	ectx.phase_snapshot = {
		"type": EncounterStateIds.ROUNDS,
		"data": {
			"round_counter": 0,
			"objective": ectx.resolution_mode,
		},
		"actions": {
			"cta.confirm_round": {
				"type":     "combat.confirm_round",
				"label":    "Confirm Round",
				"slot":     "cta.confirm_round",
				"disabled": true,
			},
		},
		"meta": { "t": t },
	}

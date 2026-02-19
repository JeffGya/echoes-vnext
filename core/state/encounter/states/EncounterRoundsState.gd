class_name EncounterRoundsState

extends State

func _init() -> void:
	super(EncounterStateIds.ROUNDS)
	
func enter(ctx: RefCounted, t: int) -> void:
	var ectx := ctx as EncounterContext
	ectx.encounter_step += 1
	ectx.phase_index = 2
	
	# MVP: rounds are not implemented yet; show placeholder using round_index.
	ectx.phase_snapshot = {
		"type": EncounterStateIds.ROUNDS,
		"data": {
			"encounter_id": ectx.encounter_id,
			"resolution_mode": ectx.resolution_mode,
			"round_index": ectx.round_index,
			"note": "Combat rounds will be implemented in COMBAT backlog stories."
		},
		"actions": [
			{
				"type": "encounter.advance",
				"label": "Resolve Encounter",
				"to": EncounterStateIds.RESOLUTION
			}
		],
		"meta": {
			"t": t
		}
	}

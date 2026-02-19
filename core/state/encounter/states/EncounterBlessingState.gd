class_name EncounterBlessingState

extends State

func _init() -> void:
	super(EncounterStateIds.BLESSING)
	
func enter(ctx: RefCounted, t: int) -> void:
	var ectx := ctx as EncounterContext
	ectx.encounter_step += 1
	ectx.phase_index = 1
	
	ectx.phase_snapshot = {
		"type": EncounterStateIds.BLESSING,
		"data": {
			"encounter_id": ectx.encounter_id,
			"resolution_mode": ectx.resolution_mode,
			"note": "Blessing selection will be implemented later."
		},
		"actions": [
			{
				"type": "encounter.advance",
				"label": "Continue",
				"to": EncounterStateIds.ROUNDS
			}
		],
		"meta": {
			"t": t
		}
	}

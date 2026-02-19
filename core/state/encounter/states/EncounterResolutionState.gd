class_name EncounterResolutionState

extends State

func _init() -> void:
	super(EncounterStateIds.RESOLUTION)
	
func enter(ctx: RefCounted, t: int) -> void:
	var ectx := ctx as EncounterContext
	ectx.encounter_step += 1
	ectx.phase_index = 3
	
	ectx.phase_snapshot = {
		"type": EncounterStateIds.RESOLUTION,
		"data": {
			"encounter_id": ectx.encounter_id,
			"resolution_mode": ectx.resolution_mode,
			"note": "Outcome resolution will be implemented later."
		},
		"actions": [
			{
				"type": "encounter.advance",
				"label": "Continue",
				"to": EncounterStateIds.AFTERMATH
			}
		],
		"meta": {
			"t": t
		}
	}

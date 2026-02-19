class_name EncounterSetupState

extends State

func _init() -> void:
	super(EncounterStateIds.SETUP)
	
func enter(ctx: RefCounted, t: int) -> void:
	var ectx := ctx as EncounterContext
	ectx.encounter_step += 1
	ectx.phase_index = 0
	
	ectx.phase_snapshot = {
		"type": EncounterStateIds.SETUP,
		"data": {
			"encounter_id": ectx.encounter_id,
			"resolution_mode": ectx.resolution_mode
		},
		"actions": [
			{
				"type": "encounter.advance",
				"label": "Continue",
				"to": EncounterStateIds.BLESSING
			}
		],
		"meta": {
			"t": t
		}
	}

class_name EncounterAftermathState

extends State

func _init() -> void:
	super(EncounterStateIds.AFTERMATH)
	
func enter(ctx: RefCounted, t: int) -> void:
	var ectx := ctx as EncounterContext
	ectx.encounter_step += 1
	ectx.phase_index = 4
	
	ectx.phase_snapshot = {
		"type": EncounterStateIds.AFTERMATH,
		"data": {
			"encounter_id": ectx.encounter_id,
			"resolution_mode": ectx.resolution_mode,
			"note": "Rewards / aftermath will be implemented later."
		},
		"actions": [
			{
				"type": "encounter.complete",
				"label": "Return",
				"reason": "Complete"
			}
		],
		"meta": {
			"t": t
		}
	}

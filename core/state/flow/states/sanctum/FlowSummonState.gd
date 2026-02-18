class_name FlowSummonState
extends State

func _init(id: String = FlowStateIds.SUMMON) -> void:
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	flow_ctx.last_snapshot = {
		"type": FlowStateIds.SUMMON,
		"data": {
			"title": "Summon Echo",
			"summon_grade_options": ["low","medium","high"], # MVP will only support low. Medium grade summons will come with classes and be mid level. Each summon grade will have different costs. UI will default to low grade and show medium/high as disabled until implemented.
			"summon_amount_options": [1, 5, 10],
			"default_summon_amount": 1,
			"default_summon_grade": "low",
			"note": "MVP scaffold: summon logic not implemented yet."
		},
		"actions": [
			{
				"type": "flow.go_state",
				"to": FlowStateIds.SANCTUM,
				"label": "Back"
			},
			{
				"type": "flow.summon_echo",
				"label": "Summon",
				"disabled": true
			}
		],
		"meta": {
			"t": t
		}
	}

func exit(ctx: RefCounted, t: int) -> void:
	pass

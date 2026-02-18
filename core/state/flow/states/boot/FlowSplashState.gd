class_name FlowSplashState

extends State

func _init(id: String = FlowStateIds.SPLASH) -> void:
	super(id)
	
func enter(ctx: RefCounted, t:int) -> void:
	var flow_ctx := ctx as FlowContext
	
	# Splash is a pure presentation snapshot
	# No timers yet (determinism). UI can provide a "Continue" button for now.
	flow_ctx.last_snapshot ={
		"type": FlowStateIds.SPLASH,
		"data":{
			"title": "Legends never die",
			"subtitle": "Echoes vNext"
		},
		"actions": [
			{
				"type": "flow.advance",
				"to": FlowStateIds.MAIN_MENU,
				"label": "Continue"
			}
		],
		"meta": {
			"t": t
		}
	}

func exit(ctx: RefCounted, t: int) -> void: 
	# No cleanup required for MVP
	pass

class_name FlowSplashState

extends State

func _init(id: String = FlowStateIds.SPLASH) -> void:
	super(id)
	
func enter(ctx: RefCounted, t:int) -> void:
	var flow_ctx := ctx as FlowContext
	var is_first_boot := true
	if typeof(flow_ctx.save_data) == TYPE_DICTIONARY:
		is_first_boot = bool(flow_ctx.save_data.get("first_boot", true))
	var action: Dictionary = {
		"type": "flow.new_game" if is_first_boot else "flow.advance",
		"label": "Continue",
		"slot": "main.cta_primary",
	}
	if not is_first_boot:
		action["to"] = FlowStateIds.MAIN_MENU
	
	# Splash is a pure presentation snapshot
	# No timers yet (determinism). UI can provide a "Continue" button for now.
	flow_ctx.last_snapshot ={
		"type": FlowStateIds.SPLASH,
		"data":{
			"title": "Legends never die",
			"subtitle": "Echoes vNext"
		},
		"actions": { "main.cta_primary": action },
		"meta": {
			"t": t
		}
	}

func exit(ctx: RefCounted, t: int) -> void: 
	# No cleanup required for MVP
	pass

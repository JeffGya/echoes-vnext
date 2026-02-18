class_name FlowMainMenuState

extends State

func _init(id: String = FlowStateIds.MAIN_MENU) -> void:
	super(id)
	
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	
	# MVP: Menu is a snapshot. Braching logic happens when action are resolved (subtasks 6)
	# We still expose enough info in snapshot data for UI/debug.
	var is_first_boot := true
	if typeof(flow_ctx.save_data) == TYPE_DICTIONARY:
		# Missing flag defaults to true for safety.
		is_first_boot = flow_ctx.save_data.get("first_boot", true)
		
	flow_ctx.last_snapshot = {
		"type": FlowStateIds.MAIN_MENU,
		"data": {
			"title": "Main Menu",
			"is_first_boot": is_first_boot
		},
		"actions":[
			{
				"type": "flow.continue",
				"label": "Continue"
			},
			{
				"type": "flow.settings",
				"label": "Settings"
			},
			{
				"type": "flow.quit",
				"label": "Quit"
			}
		],
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass

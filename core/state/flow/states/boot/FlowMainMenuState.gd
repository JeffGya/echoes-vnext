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
		"actions": _build_actions(is_first_boot),
		"meta": {
			"t": t
		}
	}
	
func exit(ctx: RefCounted, t: int) -> void:
	pass

func _build_actions(is_first_boot: bool) -> Array:
	var actions: Array = []

	if is_first_boot:
		actions.append({
			"type": "flow.new_game",
			"label": "Start",
			"slot": "main.cta_primary"
		})
	else:
		actions.append({
			"type": "flow.continue",
			"label": "Continue",
			"slot": "main.cta_primary"
		})

	actions.append({
		"type": "flow.settings",
		"label": "Settings",
		"slot": "main.settings"
	})
	actions.append({
		"type": "flow.quit",
		"label": "Quit",
		"slot": "main.quit"
	})

	return actions

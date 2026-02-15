# LogFormatter
# Helper for turning LogEvents into readable strings
# This does not change stored logs. It's display-only

class_name LogFormatter

extends RefCounted

static func format(event: Dictionary) -> String:
	var t := int(event.get("t", -1))
	var sev := str(event.get("sev", "info"))
	var type := str(event.get("type", ""))
	var msg := str(event.get("msg", ""))
	
	var sev_label := "Info"
	if sev == "debug":
		sev_label = "Debug"
		
	var category := "Core"
	if type.begins_with("save."):
		category = "Save"
	elif type.begins_with("state."):
		category = "State"
	elif type.begins_with("combat."):
		category = "Combat"
		
	# Default fallback: show msg + (optional) type for context
	return '[t:%d][%s][%s] %s' % [t, sev_label, category, msg]

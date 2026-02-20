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
	elif type.begins_with("economy."):
		category = "Econ"
	elif type.begins_with("config."):
		category = "Config"
	elif type.begins_with("debug.cmd."):
		category = "DebugCmd"
	
	var data: Dictionary = event.get("data", {})
	var suffix := ""

	if typeof(data) == TYPE_DICTIONARY:
		# Economy: show amount + before/after + reason (if present)
		if type.begins_with("economy."):
			var amount := ""
			if data.has("amount"):
				amount = str(data["amount"])
			var before := str(data["before"]) if data.has("before") else ""
			var after := str(data["after"]) if data.has("after") else ""
			var reason := str(data["reason"]) if data.has("reason") else ""

			if amount != "":
				# Prefix sign for readability if numeric-ish
				if type.find(".add") != -1:
					suffix += " (+" + amount + ")"
				elif type.find(".spend") != -1:
					suffix += " (-" + amount + ")"
				else:
					suffix += " (" + amount + ")"

			if before != "" and after != "":
				suffix += " " + before + "→" + after
			elif before != "":
				suffix += " bal=" + before

			if sev == "debug" and reason != "":
				suffix += " reason=" + reason

				# Debug command logs: show cmd/line directly
		elif type == "debug.cmd.in":
			if data.has("cmd"):
				suffix += " cmd=\"" + str(data["cmd"]) + "\""
		elif type == "debug.cmd.out":
			if data.has("line"):
				suffix += " \"" + str(data["line"]) + "\""
		elif type == "debug.cmd.err":
			if data.has("line"):
				suffix += " \"" + str(data["line"]) + "\""
		
		# Save schema repair: show notes (compact)
		elif type == "save.schema.repair":
			if data.has("notes"):
				suffix += " notes=" + str(data["notes"])

	var t_str := str(t)
	if t < 0:
		t_str = "-"

	# Default fallback: show msg + (optional) type for context
	return '[t:%s][%s][%s] %s%s' % [t_str, sev_label, category, msg, suffix]

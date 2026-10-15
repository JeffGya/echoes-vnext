class_name StageWhyText
extends RefCounted
## Wording for the stage stop mark and the why card. All text lives in data/ui/stage_why_text.json.
## A missing key gives "". It never gives a token, an id or a number.

const _PATH := "res://data/ui/stage_why_text.json"
const _ROWS: Array[Array] = [
	["cause", "cause"],
	["purpose", "purpose_family"],
	["route", "route_character"],
]

static var _data: Dictionary = {}


static func text(group: String, token: String) -> String:
	if _data.is_empty():
		var file := FileAccess.open(_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		_data = parsed if parsed is Dictionary else { "_": true }
	var g: Variant = _data.get(group, {})
	var v: Variant = (g as Dictionary).get(token, "") if g is Dictionary and not token.begins_with("_") else ""
	return v if v is String else ""


## The why card content: { title, rows }. `rows` holds at most four strings, empty ones left out.
static func compose(why: Dictionary) -> Dictionary:
	var rows: Array[String] = []
	for pair in _ROWS:
		var line := text(pair[0], str(why.get(pair[1], "")))
		if not line.is_empty():
			rows.append(line)
	var echo_name := str(why.get("named_echo_name", ""))
	var echo_line := text("echo_reason", str(why.get("echo_reason_class", "")))
	if echo_line.is_empty() and not echo_name.is_empty():
		echo_line = text("ui", "echo_named")
	if not echo_name.is_empty() and not echo_line.is_empty():
		rows.append(echo_line.replace("{name}", echo_name))
	return { "title": text("stop", str(why.get("stop_kind", ""))), "rows": rows }

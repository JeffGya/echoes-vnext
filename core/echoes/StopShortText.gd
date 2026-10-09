# res://core/echoes/StopShortText.gd
# All wording lives in data/shouts/stop_short_text.json; this file holds none.
# Lazy load, cached for the session. A missing key is an error, never a silent default.

class_name StopShortText

const _PATH: String = "res://data/shouts/stop_short_text.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func row_word(benefit: String) -> String:
	return _text_or_error(["row_word", benefit])


## Reason line for a benefit. A `code` with no own line gives the plain line.
static func reason_line(benefit: String, code: String = "") -> String:
	var path: Array = ["reason_line", benefit, "plain"]
	if not code.is_empty() and has_key(["reason_line", benefit, "with_cause", code]):
		path = ["reason_line", benefit, "with_cause", code]
	return _text_or_error(path)


static func cause_clause(code: String) -> String:
	return _text_or_error(["cause_clause", code])


static func has_key(path: Array) -> bool:
	return lookup(path).get("ok", false) as bool


## { ok: bool, text: String }. Never pushes an error; tests use it to prove a miss.
static func lookup(path: Array) -> Dictionary:
	_ensure_loaded()
	var node: Variant = _data
	for key_v: Variant in path:
		var key: String = str(key_v)
		if not (node is Dictionary) or not (node as Dictionary).has(key):
			return { "ok": false, "text": "" }
		node = (node as Dictionary)[key]
	if node is String:
		return { "ok": true, "text": node as String }
	return { "ok": false, "text": "" }


static func all_lines() -> Array:
	_ensure_loaded()
	var out: Array = []
	_collect(_data, out)
	return out


## Lines under a node flagged `_about_other: true` (a line about another Echo; may use pronouns).
static func about_other_lines() -> Array:
	_ensure_loaded()
	var out: Array = []
	_collect_flagged(_data, out)
	return out


static func _collect_flagged(node: Variant, out: Array) -> void:
	if not (node is Dictionary):
		return
	var d: Dictionary = node as Dictionary
	if bool(d.get("_about_other", false)):
		_collect(d, out)
		return
	for key: String in d.keys():
		_collect_flagged(d[key], out)


static func _collect(node: Variant, out: Array) -> void:
	if node is String:
		out.append(node)
	elif node is Dictionary:
		for key: String in (node as Dictionary).keys():
			if not key.begins_with("_"):
				_collect((node as Dictionary)[key], out)


static func _text_or_error(path: Array) -> String:
	var found: Dictionary = lookup(path)
	if not bool(found["ok"]):
		push_error("StopShortText: missing key %s in %s" % [str(path), _PATH])
		return ""
	return str(found["text"])


static func _ensure_loaded() -> void:
	if _loaded:
		return
	var f := FileAccess.open(_PATH, FileAccess.READ)
	if f == null:
		push_error("StopShortText: cannot open %s" % _PATH)
		_loaded = true
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_data = parsed as Dictionary
	else:
		push_error("StopShortText: invalid JSON in %s" % _PATH)
	_loaded = true

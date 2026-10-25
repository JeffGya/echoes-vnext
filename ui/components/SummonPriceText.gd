class_name SummonPriceText
extends RefCounted
## Wording for the Summon price card. All text lives in data/ui/summon_price_text.json.
## A missing key gives "". It never gives an id or a computed number.

const _PATH := "res://data/ui/summon_price_text.json"

static var _data: Dictionary = {}


static func text(group: String, key: String) -> String:
	if _data.is_empty():
		var file := FileAccess.open(_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		_data = parsed if parsed is Dictionary else { "_": true }
	var g: Variant = _data.get(group, {})
	var v: Variant = (g as Dictionary).get(key, "") if g is Dictionary and not key.begins_with("_") else ""
	return v if v is String else ""


## The text with {n} replaced by `n` (a number the snapshot gave, shown as is).
static func with_number(group: String, key: String, n: int) -> String:
	return text(group, key).replace("{n}", str(n))

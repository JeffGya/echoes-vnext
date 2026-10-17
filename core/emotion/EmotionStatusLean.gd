# res://core/emotion/EmotionStatusLean.gd
# Turns the shared emotional status (EmotionService.get_emotional_status) into one lean from
# -1 (afraid) to +1 (bold). Pure and static: the table is `felt_state.band_lean` of the
# combat movement config, and the status itself is never re-derived here.

class_name EmotionStatusLean


## The band_lean table inside a combat movement config; {} when absent.
static func table_of(movement_cfg: Dictionary) -> Dictionary:
	var felt: Variant = movement_cfg.get("felt_state", {})
	var table: Variant = (felt as Dictionary).get("band_lean", {}) if felt is Dictionary else {}
	return table as Dictionary if table is Dictionary else {}


## Status of an actor view. Fear is max(fear, fear_base), as every other combat reader does.
static func status_of(actor: Dictionary) -> String:
	var fear: int = maxi(int(actor.get("fear", 0)), int(actor.get("fear_base", 0)))
	return EmotionService.get_emotional_status(int(actor.get("morale", 50)), fear)


## Lean of a status. 0.0 when the table has no entry for it.
static func lean(status: String, table: Dictionary) -> float:
	return float(table.get(status, 0.0))


static func afraid(lean_value: float) -> float:
	return maxf(0.0, -lean_value)


static func bold(lean_value: float) -> float:
	return maxf(0.0, lean_value)


## Composure softens a lean: lean x (1 - dampen_scale x composure).
static func soften(lean_value: float, composure: float, dampen_scale: float) -> float:
	return lean_value * (1.0 - dampen_scale * clampf(composure, 0.0, 1.0))


## Afraid part of an actor's status lean, softened by composure. 0.0 when `table` is empty.
static func afraid_of(actor: Dictionary, table: Dictionary, composure: float, dampen_scale: float) -> float:
	if table.is_empty():
		return 0.0
	return afraid(soften(lean(status_of(actor), table), composure, dampen_scale))


## True when the table has all ten statuses, each a finite number in [-1, 1], never falling
## along EmotionService.STATUS_LADDER, with the two calm statuses at exactly 0.
static func is_valid(table: Variant) -> bool:
	if not table is Dictionary:
		return false
	var previous: float = -1.0
	for status: String in EmotionService.STATUS_LADDER:
		var value: Variant = (table as Dictionary).get(status, null)
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
		var number: float = float(value)
		if number < -1.0 or number > 1.0 or number < previous:
			return false
		previous = number
	return float((table as Dictionary)["grounded"]) == 0.0 and float((table as Dictionary)["whole"]) == 0.0

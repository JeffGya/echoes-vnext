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


## True for a real Echo: Echo faction and Echo kind. A temporary ally has the faction but not the kind.
## The one gate for the felt-state lean and the state steps.
static func is_echo(actor: Dictionary) -> bool:
	return str(actor.get("faction", "")) == "echo" and str(actor.get("kind", actor.get("actor_type", "echo"))) == "echo"


## The one status rule: fear is max(fear, fear_base).
static func status_from(morale: int, fear: int, fear_base: int) -> String:
	return EmotionService.get_emotional_status(morale, maxi(fear, fear_base))


## Status of an actor view (flat morale, fear, fear_base).
static func status_of(actor: Dictionary) -> String:
	return status_from(int(actor.get("morale", 50)), int(actor.get("fear", 0)), int(actor.get("fear_base", 0)))


## Status of a saved emotion block (morale_current, fear_current, fear_base).
static func status_of_emotion(emotion: Dictionary) -> String:
	return status_from(int(emotion.get("morale_current", 50)), int(emotion.get("fear_current", 0)), int(emotion.get("fear_base", 0)))


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


## Curved afraid value for the action layer and style: afraid(lean)^exponent, softened once by
## composure. The curve acts on the unsoftened lean. Slices 5 and 6 keep the linear afraid().
static func curved_afraid(lean_value: float, exponent: float, composure: float, dampen_scale: float) -> float:
	return soften(pow(afraid(lean_value), exponent), composure, dampen_scale)


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

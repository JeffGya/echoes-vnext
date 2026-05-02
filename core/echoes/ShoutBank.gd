## ShoutBank.gd
## Lookup service for Echo bark/shout lines.
## Bark copy lives in data/shouts/*.json — add a new JSON file to extend.
## Load is lazy (first call) and cached for the session.
##
## Usage:
##   var tier  := ShoutBank.get_tier(courage, wisdom, faith)
##   var line  := ShoutBank.get_shout("arrival", arch, tier)
##   var line  := ShoutBank.get_expression_shout("combat_ko", arch, band, calling, variation_key)
##
## JSON structure (each file):
##   { "shouts": { context → arch → tier → String|Array[String] },
##     "tier_shouts": { context → voice_key → band → String|Array[String] } }
##
## voice_key priority in tier_shouts: "arch_calling" > "arch" > _FALLBACK
## variation_key selection: array[variation_key % size()] — deterministic, no RNG.
class_name ShoutBank

const STRONG_THRESHOLD: float   = 15.0
const MODERATE_THRESHOLD: float = 5.0
const _FALLBACK: String         = "I'll do my part."

## All bark content files. Add new paths here to extend without touching logic.
const _JSON_PATHS: Array[String] = [
	"res://data/shouts/arrival.json",
	"res://data/shouts/combat_legacy.json",
	"res://data/shouts/combat_expressions.json",
	"res://data/shouts/combat_callings.json",
	"res://data/shouts/sanctum.json",
	"res://data/shouts/journey.json",
]

static var _loaded: bool       = false
static var _shouts: Dictionary = {}      # context → arch → tier → String|Array
static var _tier_shouts: Dictionary = {} # context → voice_key → band → String|Array


# ── Private ───────────────────────────────────────────────────────────────────

static func _ensure_loaded() -> void:
	if _loaded:
		return
	for path in _JSON_PATHS:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_warning("ShoutBank: missing bark file %s" % path)
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if not (parsed is Dictionary):
			push_warning("ShoutBank: invalid JSON in %s" % path)
			continue
		var pd := parsed as Dictionary
		if pd.has("shouts") and pd["shouts"] is Dictionary:
			_shouts.merge(pd["shouts"] as Dictionary, true)
		if pd.has("tier_shouts") and pd["tier_shouts"] is Dictionary:
			_tier_shouts.merge(pd["tier_shouts"] as Dictionary, true)
	_loaded = true


## Resolve a data entry that may be a String (legacy) or Array[String] (V2).
static func _resolve_line(line: Variant, variation_key: int) -> String:
	if line is Array:
		var arr := line as Array
		if arr.is_empty():
			return ""
		return str(arr[variation_key % arr.size()])
	if line is String:
		return line as String
	return ""


# ── Public API ────────────────────────────────────────────────────────────────

## Derive a tier string ("strong" / "moderate" / "weak") from raw trait values.
static func get_tier(courage: int, wisdom: int, faith: int) -> String:
	var c := float(courage)
	var w := float(wisdom)
	var f := float(faith)
	var mean: float = (c + w + f) / 3.0
	var max_delta: float = maxf(c - mean, maxf(w - mean, f - mean))
	if max_delta >= STRONG_THRESHOLD:
		return "strong"
	if max_delta >= MODERATE_THRESHOLD:
		return "moderate"
	return "weak"


## Legacy tier-based lookup. Used for "arrival" and legacy combat stubs.
## Fallback chain: requested tier → "moderate" → "weak" → _FALLBACK.
static func get_shout(
	context: String,
	arch: String,
	tier: String,
	variation_key: int = 0
) -> String:
	_ensure_loaded()
	var ctx_block: Variant = _shouts.get(context)
	if not (ctx_block is Dictionary):
		return _FALLBACK
	var arch_block: Variant = (ctx_block as Dictionary).get(arch)
	if not (arch_block is Dictionary):
		return _FALLBACK
	var ab := arch_block as Dictionary
	for t in [tier, "moderate", "weak"]:
		var line: Variant = ab.get(t)
		var resolved := _resolve_line(line, variation_key)
		if not resolved.is_empty():
			return resolved
	return _FALLBACK


## V2 expression-band lookup. Used for all combat and sanctum contexts.
## voice_key priority: arch_calling → arch → _FALLBACK.
## Band fallback chain: expression_band → "forming" → "nascent" → _FALLBACK.
static func get_expression_shout(
	context: String,
	arch: String,
	expression_band: String,
	calling_origin: String = "",
	variation_key: int = 0
) -> String:
	_ensure_loaded()
	var ctx_block: Variant = _tier_shouts.get(context)
	if not (ctx_block is Dictionary):
		return _FALLBACK
	var cb := ctx_block as Dictionary

	var voice_keys: Array = []
	if not calling_origin.is_empty():
		voice_keys.append(arch + "_" + calling_origin)
	voice_keys.append(arch)

	for vk in voice_keys:
		var arch_block: Variant = cb.get(vk)
		if not (arch_block is Dictionary):
			continue
		var ab := arch_block as Dictionary
		for st in [expression_band, "forming", "nascent"]:
			var line: Variant = ab.get(st)
			var resolved := _resolve_line(line, variation_key)
			if not resolved.is_empty():
				return resolved

	return _FALLBACK

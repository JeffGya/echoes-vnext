## PersonalityArchetype.gd
## Canonical 9-archetype personality system for Echoes.
## Source of truth for: archetype names, deterministic mapping, combat bias, dialogue key.
##
## Archetypes are personality TONE, not power modifiers.
## They are orthogonal to vectors (combat role) and calling_origin (summon lineage).
##
## Canon: archetypes_mvp.md §1–3, GDD §5 (Hero personality tone).
class_name PersonalityArchetype

## Canonical list of valid archetype strings.
## Use this for validity checks (e.g. SaveService repair) and iteration.
const ARCHETYPES: Array = [
	"loyal", "proud", "reflective", "valiant",
	"canny", "devout", "stoic", "empathic", "ambitious"
]

## Tunable knobs (balance levers — do not change without updating tests).
const DOMINANCE_THRESHOLD: float = 8.0
const BAND_EDGE: float = 5.0


## Deterministic mapping from trait values to archetype string.
## No RNG. Same inputs always produce the same output.
##
## Algorithm (archetypes_mvp.md §2):
##   1. Centre deltas around mean of {courage, wisdom, faith}.
##   2. Dominance pass: if one delta is uniquely highest AND >= DOMINANCE_THRESHOLD.
##   3. Band rules (first match wins), fallback = "reflective".
static func from_traits(courage: int, wisdom: int, faith: int) -> String:
	var c := float(courage)
	var w := float(wisdom)
	var f := float(faith)

	# Step 1 — centre
	var mean: float = (c + w + f) / 3.0
	var dc: float = c - mean
	var dw: float = w - mean
	var df: float = f - mean

	# Step 2 — dominance pass (unique maximum AND >= threshold)
	var max_delta: float = maxf(dc, maxf(dw, df))
	if max_delta >= DOMINANCE_THRESHOLD:
		var dc_is_max := (dc == max_delta)
		var dw_is_max := (dw == max_delta)
		var df_is_max := (df == max_delta)
		# Unique max — exactly one delta equals the maximum
		var unique := int(dc_is_max) + int(dw_is_max) + int(df_is_max) == 1
		if unique:
			if dc_is_max:
				return "valiant"
			if dw_is_max:
				return "canny"
			return "devout"

	# Step 3 — band classification
	var c_band := _band(dc)
	var w_band := _band(dw)
	var f_band := _band(df)

	# Rule 1
	if c_band == 1 and f_band == 1:
		return "loyal"
	# Rule 2
	if c_band == 1 and f_band == -1:
		return "proud"
	# Rule 3
	if c_band == -1 and w_band == 1:
		return "stoic"
	# Rule 4
	if f_band == 1 and w_band >= 0:
		return "empathic"
	# Rule 5
	if w_band == 1 and c_band == 0:
		return "ambitious"
	# Rule 6 — siphon rule
	if c_band == 1 and w_band == 1 and f_band == 0:
		return "ambitious"

	# Rule 7 — fallback
	return "reflective"


## Returns the combat bias for an archetype.
## One of: "aggressive" | "cautious" | "steadfast" | "supportive" | "balanced"
static func combat_bias(arch: String) -> String:
	const BIAS: Dictionary = {
		"loyal":      "steadfast",
		"proud":      "aggressive",
		"reflective": "cautious",
		"valiant":    "aggressive",
		"canny":      "balanced",
		"devout":     "steadfast",
		"stoic":      "steadfast",
		"empathic":   "supportive",
		"ambitious":  "balanced",
	}
	return BIAS.get(arch, "balanced")


## Returns the stable dialogue voice key for an archetype.
## Format: "voice_<archetype>" — ready for localisation lookup.
static func dialogue_key(arch: String) -> String:
	if arch in ARCHETYPES:
		return "voice_" + arch
	return "voice_unknown"


# ── Private ──────────────────────────────────────────────────────────────────

## Classify a delta into HIGH (+1), MID (0), or LOW (-1) band.
static func _band(delta: float) -> int:
	if delta >= BAND_EDGE:
		return 1
	if delta <= -BAND_EDGE:
		return -1
	return 0

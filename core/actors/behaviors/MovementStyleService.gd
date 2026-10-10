# res://core/actors/behaviors/MovementStyleService.gd
# docs/movement-model.md §9/§10.4 — how well ONE already-generated route candidate
# reads as this actor's identity, expressed as a score BehaviorArbiter folds into
# that candidate's own total (decision #18).
#
# The flow runs candidate -> style -> score. It never runs style -> hunt for a
# matching candidate: a winner that did not win its own arbiter sort breaks
# DecisionTrace's margin rule (§6.6) and DivergenceDetector's stated precondition.
#
# DETERMINISTIC, NO SAMPLING. No RNG anywhere in this file: `CampaignSeed` is never
# imported here, on purpose. Pure and static — every weight arrives via `cfg`
# (data.actor.movement_style_weights) and every identity/emotion/social fact arrives
# already resolved by the caller.
#
# alignment(style) = (vector_bias + calling_family_bias + fear_bias + morale_bias
#                     + bond_bias + vow_bias + trait_nudge) * alignment_weight
# `alignment_weight` converts identity units into arbiter score units. It exists
# because these weights are now compared against `_score()`/`_spatial_utility`
# totals rather than only against each other.

class_name MovementStyleService

## §9's ten expressive styles. Distinct vocabulary from MovementOptionService's
## route-SHAPE tokens even where the words coincide — route-shape names the
## MECHANIC, movement_style names how the move READS.
const STYLES: Array = [
	"direct", "restrained", "careful", "forceful", "cohesive",
	"low_exposure", "lateral", "intercepting", "retreating", "overcommitted",
]

## `retreating` only makes sense while the purpose is already about disengaging or
## consolidating; `overcommitted` only while it is already about pressing forward.
const _RETREATING_PURPOSES: Array = ["withdraw", "regroup", "escort", "reposition"]
const _OVERCOMMITTED_PURPOSES: Array = ["engage", "intercept", "cut_off", "pursue"]

## The eight styles open to every purpose (all but `retreating`/`overcommitted`).
const _UNIVERSAL_STYLES: Array = [
	"direct", "restrained", "careful", "forceful", "cohesive",
	"low_exposure", "lateral", "intercepting",
]

## Returned for a candidate whose route-shape is a style its purpose cannot
## truthfully express. Neutral, not a veto: the candidate gets no identity-driven
## style bonus, but can still win on its own mechanical merit (cost, hazard
## avoidance, spatial utility) — a purpose-ineligible route is never systematically
## unselectable (decision #21).
const INELIGIBLE_ALIGNMENT: float = 0.0

## movement_style -> route-shape token. Eight of ten share their token outright;
## `restrained`/`careful` read the route-shapes `conservative`/`safe`, and
## `intercepting` reads the route-shape `intercept` (§9 spells the style with the
## -ing, which also keeps it distinct from `intercept` the §9 PURPOSE).
const ROUTE_STYLE_BY_MOVEMENT_STYLE: Dictionary = {
	"direct":        "direct",
	"restrained":    "conservative",
	"careful":       "safe",
	"forceful":      "forceful",
	"cohesive":      "cohesive",
	"low_exposure":  "low_exposure",
	"lateral":       "lateral",
	"intercepting":  "intercept",
	"retreating":    "retreating",
	"overcommitted": "overcommitted",
}

## The inverse. Route-shape `screen` is absent: it is MovementOptionService's own
## purpose-keyed primary for protect/escort and has no movement_style counterpart,
## so a screen candidate scores a neutral 0.0 rather than any style's alignment.
const MOVEMENT_STYLE_BY_ROUTE_STYLE: Dictionary = {
	"direct":        "direct",
	"conservative":  "restrained",
	"safe":          "careful",
	"forceful":      "forceful",
	"cohesive":      "cohesive",
	"low_exposure":  "low_exposure",
	"lateral":       "lateral",
	"intercept":     "intercepting",
	"retreating":    "retreating",
	"overcommitted": "overcommitted",
}


## The styles a purpose may truthfully express (§9).
static func eligible_styles(purpose: String) -> Array:
	var eligible: Array = _UNIVERSAL_STYLES.duplicate()
	if _RETREATING_PURPOSES.has(purpose):
		eligible.append("retreating")
	if _OVERCOMMITTED_PURPOSES.has(purpose):
		eligible.append("overcommitted")
	return eligible


## How strongly this actor's identity pulls toward a candidate whose route-shape is
## `route_style`, in arbiter score units. 0.0 (== INELIGIBLE_ALIGNMENT) both when the
## route-shape has no style counterpart and when the style is one `purpose` cannot
## express — neither case earns an identity bonus, but neither is penalised either.
##
## `vector_scores` / `traits`: read straight off the actor dict (top-level fields per
## ActorSchema), the same shape `BehaviorArbiter._score()` already reads.
## `calling_family`: "anchor" | "edge" | "sight" | "" — resolved by the caller from
## data.calling.definitions[calling_id].family.
## `fear`: 0-100, the same floor-blended value `_score()` uses (max of fear/fear_base).
## `morale_tier`: EmotionService.get_morale_tier()'s output.
## `bond_pressure`: 0.0-1.0, how strongly a bonded subject presses on THIS candidate's
## own goal subject.
## `vow_lean`: -1.0 (fully Ward — holding the vow) .. +1.0 (fully Break — straining
## against it). 0.0 when no vow is active.
static func style_alignment_score(
	route_style: String,
	purpose: String,
	vector_scores: Dictionary,
	calling_family: String,
	traits: Dictionary,
	fear: float,
	morale_tier: String,
	bond_pressure: float,
	vow_lean: float,
	cfg: Dictionary
) -> float:
	var style: String = movement_style_for(route_style)
	if style.is_empty():
		return 0.0
	if not eligible_styles(purpose).has(style):
		return INELIGIBLE_ALIGNMENT
	var raw: float = _score_style(
		style, vector_scores, calling_family, traits, fear, morale_tier,
		bond_pressure, vow_lean, cfg
	)
	return raw * float(cfg.get("alignment_weight", 1.0))


## The route-shape token that expresses `movement_style`. `""` if unrecognised.
static func route_style_for(movement_style: String) -> String:
	return str(ROUTE_STYLE_BY_MOVEMENT_STYLE.get(movement_style, ""))


## The movement_style a route-shape reads as. `""` for `screen` and for anything
## outside the route-shape vocabulary.
static func movement_style_for(route_style: String) -> String:
	return str(MOVEMENT_STYLE_BY_ROUTE_STYLE.get(route_style, ""))


static func _score_style(
	style: String,
	vector_scores: Dictionary,
	calling_family: String,
	traits: Dictionary,
	fear: float,
	morale_tier: String,
	bond_pressure: float,
	vow_lean: float,
	cfg: Dictionary
) -> float:
	var total: float = 0.0

	var vector_bias: Dictionary = cfg.get("vector_bias", {}) as Dictionary
	for vector_key: String in vector_scores:
		var row: Dictionary = vector_bias.get(vector_key, {}) as Dictionary
		total += float(vector_scores[vector_key]) * float(row.get(style, 0.0))

	var family_bias: Dictionary = cfg.get("calling_family_bias", {}) as Dictionary
	var family_row: Dictionary = family_bias.get(calling_family, {}) as Dictionary
	total += float(family_row.get(style, 0.0))

	var fear_weight: Dictionary = cfg.get("fear_weight", {}) as Dictionary
	total += (clampf(fear, 0.0, 100.0) / 100.0) * float(fear_weight.get(style, 0.0))

	var morale_bias: Dictionary = cfg.get("morale_bias", {}) as Dictionary
	var morale_row: Dictionary = morale_bias.get(morale_tier, {}) as Dictionary
	total += float(morale_row.get(style, 0.0))

	var bond_weight: Dictionary = cfg.get("bond_weight", {}) as Dictionary
	total += clampf(bond_pressure, 0.0, 1.0) * float(bond_weight.get(style, 0.0))

	var ward_weight: Dictionary = cfg.get("vow_ward_weight", {}) as Dictionary
	var break_weight: Dictionary = cfg.get("vow_break_weight", {}) as Dictionary
	var ward_lean: float = maxf(-vow_lean, 0.0)
	var break_lean: float = maxf(vow_lean, 0.0)
	total += ward_lean * float(ward_weight.get(style, 0.0))
	total += break_lean * float(break_weight.get(style, 0.0))

	var trait_nudge: Dictionary = cfg.get("trait_nudge", {}) as Dictionary
	for trait_key: String in traits:
		var trait_row: Dictionary = trait_nudge.get(trait_key, {}) as Dictionary
		total += float(traits[trait_key]) * float(trait_row.get(style, 0.0))

	return total

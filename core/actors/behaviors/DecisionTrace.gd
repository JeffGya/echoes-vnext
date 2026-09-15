# res://core/actors/behaviors/DecisionTrace.gd
# docs/movement-model.md §6.6 — the authoritative explanation of one behavior decision.
#
# This file owns three things and nothing else:
#   1. the trace SHAPE (§6.6, field for field);
#   2. its CONSTRUCTION from the decomposition BehaviorArbiter already recorded;
#   3. the SANITIZED projection a player-facing snapshot may carry.
#
# It computes no behaviour fact of its own. Every number it reads was produced by
# BehaviorArbiter._score() / _spatial_utility() / _apply_bias() during the turn's
# ordinary scoring pass and kept on the candidate. Nothing here re-scores anything,
# so building a trace can never change a decision.
#
# WHY THE PRIMARY REASON IS CHOSEN BY REMOVAL (§6.6). A reason is only allowed to be
# surfaced when it is causal: a hard override that selected the plan, a contribution
# whose removal would have changed the winner, or the baseline tactical purpose. A
# contribution that merely broke a tie must not be promoted into a character
# explanation. `material` is that test, and it is answered exactly — the winner's and
# the runner-up's recorded terms are both present, so "score with source S removed"
# is arithmetic, not a re-run of the arbiter.
#
# WHY SOURCE, NOT TERM, IS THE UNIT. §6.6 fixes the vocabulary of `source`. A single
# source can reach the score through several terms (the Directive presses through
# `directive_bonus` AND through five weighted spatial terms), and "would removing the
# Directive have changed the winner?" is only answerable if all of them come out
# together. `code` then names which of that source's terms dominated.
#
# Pure. Static. No state, no RNG, no Time, no ConfigService.

class_name DecisionTrace

const DivergenceDetectorScript = preload("res://core/actors/DivergenceDetector.gd")

## §6.6 `source` vocabulary, plus `movement_style` (V2-COMBAT-003.5 Phase 3b — no
## §6.6 source names the vector/calling/fear/morale/bond/vow blend MovementStyleService
## produces, so it is its own category rather than forced into one of the narrower
## ones). Also the deterministic tie-break order when two sources produce the same
## swing.
const SOURCES: Array = [
	"hard_rule", "objective", "danger", "bond", "vow", "calling",
	"vector", "movement_style", "emotion", "directive", "guidance", "equipment", "baseline",
]

## §6.6 `causal_kind` vocabulary, verbatim.
const CAUSAL_KINDS: Array = ["hard_override", "co_decisive", "baseline"]

const STRENGTH_BANDS: Array = ["none", "slight", "moderate", "strong", "decisive"]

## The ONLY fields a player-facing snapshot may carry (§6.6's sanitized list:
## reason code and source, subject, purpose, message key and arguments, voice tone).
## `sanitize()` builds exactly this and nothing else; DecisionTraceTests fails if the
## set ever widens.
const PLAYER_SAFE_FIELDS: Array = ["primary", "purpose", "message_key", "message_args", "voice_tone"]
const PLAYER_SAFE_PRIMARY_FIELDS: Array = ["code", "source", "subject_id"]

## Which `source` each recorded score term belongs to. Traits, virtue scores and
## archetype all land on `vector` because §6.6's vocabulary has no finer identity
## source; `code` keeps them apart (disposition / values / temperament).
const _TERM_SOURCE: Dictionary = {
	"base":              "calling",
	"trait_bonus":       "vector",
	"vector_bonus":      "vector",
	"archetype_bonus":   "vector",
	"morale_bonus":      "emotion",
	"fear_factor":       "emotion",
	"calling_mul":       "calling",
	"directive_bonus":   "directive",
	"situational_bonus": "danger",
}

## Which `source` each `_spatial_utility()` term belongs to. Cohesion and commitment
## are `baseline`: they shape the tactical default rather than expressing a pressure.
const _SPATIAL_SOURCE: Dictionary = {
	"urgency":                       "objective",
	"objective_progress":            "objective",
	"exposure":                      "danger",
	"congestion":                    "danger",
	"cohesion":                      "baseline",
	"commitment":                    "baseline",
	"directive_objective_advance":   "directive",
	"directive_avoid_overcommit":    "directive",
	"directive_exposure_acceptance": "directive",
	"directive_ally_protection":     "directive",
	"directive_threat_interception": "directive",
}

## Which `source` each post-scoring bias belongs to. `leadership_cover` is another
## Echo's whole-band aura teaching this one to end its route behind terrain — the
## nearest §6.6 source is `guidance`.
## NOTE: `leadership_cover` and `guidance` share the source `guidance`, so a removal
## takes both out together. That is correct for §6.6's question — both are someone else
## telling this Echo where to be — and `code` still separates them in the surfaced
## reason. GuidanceContribution never asks this file about the `guidance` source, so a
## guidance response's own reason cannot be confused by the pairing.
## `movement_style` blends vector/calling/fear/morale/bond/vow into one alignment term
## (MovementStyleService) — no single §6.6 source names that blend, so it gets its own
## source rather than being forced into `vow`/`bond`/`guidance`, which each mean
## something narrower.
const _BIAS_SOURCE: Dictionary = {
	"vow":              "vow",
	"bond":             "bond",
	"leadership_cover": "guidance",
	"guidance":         "guidance",
	"movement_style":   "movement_style",
}

## Reason `code` for the dominant term of a source. Player-readable, no IDs.
const _TERM_CODE: Dictionary = {
	"base":              "calling_weight",
	"calling_mul":       "calling_press",
	"trait_bonus":       "disposition",
	"vector_bonus":      "values",
	"archetype_bonus":   "temperament",
	"morale_bonus":      "morale",
	"fear_factor":       "fear",
	"directive_bonus":   "directive_order",
	"situational_bonus": "situation",
	"urgency":                       "objective_urgency",
	"objective_progress":            "objective_progress",
	"exposure":                      "route_exposure",
	"congestion":                    "route_congestion",
	"cohesion":                      "formation_cohesion",
	"commitment":                    "commitment_cost",
	"directive_objective_advance":   "directive_shaping",
	"directive_avoid_overcommit":    "directive_shaping",
	"directive_exposure_acceptance": "directive_shaping",
	"directive_ally_protection":     "directive_shaping",
	"directive_threat_interception": "directive_shaping",
	"vow":              "vow_held",
	"bond":             "bond_pull",
	"leadership_cover": "leader_cover",
	"guidance":         "keeper_guidance",
	"movement_style":   "style_expression",
}

## Presentation tone per source. A projection of the trace, not a new fact about the
## actor. Emotion-driven tone — fear or morale colouring the voice — is deferred,
## together with the five guidance responses.
const _SOURCE_TONE: Dictionary = {
	"hard_rule": "urgent",
	"objective": "focused",
	"danger":    "strained",
	"bond":      "committed",
	"vow":       "committed",
	"calling":   "assured",
	"vector":    "assured",
	"movement_style": "assured",
	"emotion":   "strained",
	"directive": "focused",
	"guidance":  "plain",
	"equipment": "plain",
	"baseline":  "plain",
}

## PROPOSED DEFAULT — how far past the runner-up a contribution had to carry the
## decision, as a fraction of `decision_scale` (the spread of the options the mover
## actually weighed). Not yet playtest-ratified; kept here rather than in
## balance.json because nothing tunes behaviour by it — it only bands a label.
const _BAND_SLIGHT_MAX: float = 0.15
const _BAND_MODERATE_MAX: float = 0.35
const _BAND_STRONG_MAX: float = 0.60


## `inputs` is BehaviorArbiter's `_decision_inputs` payload:
##   winner / runner_up: {action_type, target_id, score, components, spatial, bias}
##                       (runner_up is {} when the mover had only one candidate)
##   decision_scale: float — spread of the options as the mover saw them
##   purpose:        String — §9 movement purpose, "" on the legacy (goal-less) path
##   subject_id:     String — who or what the decision is about
##   commitment / capacity: int
##   hard_override:  String — non-empty when a rule, not a score, selected the plan
##
## `legibility` is MaturityExpressionService.derive_expression()'s output. It governs
## how specific the surfaced message may be, through the same band function
## DivergenceDetector uses — there is exactly one notion of specificity in the code.
static func build(inputs: Dictionary, legibility: float, divergence_cfg: Dictionary) -> Dictionary:
	var winner: Dictionary = inputs.get("winner", {}) as Dictionary
	var runner_up: Dictionary = inputs.get("runner_up", {}) as Dictionary
	var purpose: String = str(inputs.get("purpose", ""))
	var subject_id: String = str(inputs.get("subject_id", ""))
	var decision_scale: float = float(inputs.get("decision_scale", 0.0))
	var hard_override: String = str(inputs.get("hard_override", ""))

	var swings: Dictionary = {}
	var margin: float = 0.0
	var primary: Dictionary = {}
	var supporting: Array = []

	if not hard_override.is_empty():
		primary = _reason(hard_override, "hard_rule", subject_id, "hard_override", true, "decisive")
	else:
		margin = float(winner.get("score", 0.0)) - float(runner_up.get("score", 0.0))
		var material: Array = []
		for source: String in SOURCES:
			var swing: float = _removal_swing(winner, runner_up, source)
			swings[source] = swing
			# The decision changes when removing this source costs the winner more
			# than the margin it won by. Anything less only broke a tie, and §6.6
			# forbids promoting that into a character explanation.
			if not runner_up.is_empty() and swing > margin:
				material.append({"source": source, "swing": swing})
		material.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			if float(left["swing"]) != float(right["swing"]):
				return float(left["swing"]) > float(right["swing"])
			return SOURCES.find(str(left["source"])) < SOURCES.find(str(right["source"]))
		)
		for index: int in range(material.size()):
			var entry: Dictionary = material[index] as Dictionary
			var source: String = str(entry["source"])
			var reason: Dictionary = _reason(
				dominant_code(winner, source),
				source,
				subject_id,
				"co_decisive",
				true,
				_strength_band(float(entry["swing"]), decision_scale)
			)
			if index == 0:
				primary = reason
			else:
				supporting.append(reason)
		if primary.is_empty():
			# §6.6's third permitted primary: no identity pressure was decisive, so
			# the baseline tactical purpose is the honest explanation.
			primary = _reason(
				purpose if not purpose.is_empty() else "tactical_default",
				"baseline", subject_id, "baseline", false, "none"
			)

	var band: String = DivergenceDetectorScript.specificity_band(legibility, divergence_cfg)
	return {
		"primary":    primary,
		"supporting": supporting,
		"purpose":    purpose,
		"message_key": _message_key(primary, band),
		"message_args": _message_args(primary, purpose, band),
		"voice_tone": str(_SOURCE_TONE.get(str(primary["source"]), "plain")),
		"debug_components": {
			"winner":         winner,
			"runner_up":      runner_up,
			"margin":         margin,
			"decision_scale": decision_scale,
			"swings":         swings,
			"commitment":     int(inputs.get("commitment", 0)),
			"capacity":       int(inputs.get("capacity", 0)),
			"legibility":     legibility,
		},
	}


## The player-safe projection (§6.6). Raw scores, weights, trait values, vector
## totals and `debug_components` never leave here.
static func sanitize(trace: Dictionary) -> Dictionary:
	var primary: Dictionary = trace.get("primary", {}) as Dictionary
	var safe_primary: Dictionary = {}
	for field: String in PLAYER_SAFE_PRIMARY_FIELDS:
		safe_primary[field] = str(primary.get(field, ""))
	return {
		"primary":      safe_primary,
		"purpose":      str(trace.get("purpose", "")),
		"message_key":  str(trace.get("message_key", "")),
		"message_args": (trace.get("message_args", {}) as Dictionary).duplicate(true),
		"voice_tone":   str(trace.get("voice_tone", "")),
	}


## Score this candidate would have had with every term belonging to `source` removed.
## `source` = "" reconstructs the recorded score — DecisionTraceTests pins that
## reconstruction against the arbiter's own value, which is what proves this file
## reads the real decomposition instead of an approximation of it.
static func score_without(entry: Dictionary, source: String) -> float:
	if entry.is_empty():
		return 0.0
	var components: Dictionary = entry.get("components", {}) as Dictionary
	var bracket: float = 0.0
	for term: String in ["base", "trait_bonus", "vector_bonus", "archetype_bonus", "morale_bonus"]:
		if str(_TERM_SOURCE[term]) != source:
			bracket += float(components.get(term, 0.0))
	var fear_factor: float = 1.0 if str(_TERM_SOURCE["fear_factor"]) == source \
		else float(components.get("fear_factor", 1.0))
	var calling_mul: float = 1.0 if str(_TERM_SOURCE["calling_mul"]) == source \
		else float(components.get("calling_mul", 1.0))
	var total: float = bracket * fear_factor * calling_mul
	for term: String in ["directive_bonus", "situational_bonus"]:
		if str(_TERM_SOURCE[term]) != source:
			total += float(components.get(term, 0.0))

	var spatial: Dictionary = entry.get("spatial", {}) as Dictionary
	if not spatial.is_empty():
		var parts: Dictionary = spatial.get("parts", {}) as Dictionary
		var removed: float = 0.0
		for part: String in parts:
			if str(_SPATIAL_SOURCE.get(part, "baseline")) == source:
				removed += float(parts[part])
		var cap: float = float(spatial.get("cap", 0.0))
		# The spatial term is clamped, so a removal must be re-clamped from `raw`.
		total += clampf(float(spatial.get("raw", 0.0)) - removed, -cap, cap)

	var bias: Dictionary = entry.get("bias", {}) as Dictionary
	for key: String in bias:
		if str(_BIAS_SOURCE.get(key, "baseline")) != source:
			total += float(bias[key])
	return total


## How much further past the runner-up the winner was carried by `source`. Positive
## means removing the source narrows the gap; greater than the margin means removing
## it reverses the decision.
static func _removal_swing(winner: Dictionary, runner_up: Dictionary, source: String) -> float:
	if winner.is_empty() or runner_up.is_empty():
		return 0.0
	var winner_loss: float = float(winner.get("score", 0.0)) - score_without(winner, source)
	var runner_loss: float = float(runner_up.get("score", 0.0)) - score_without(runner_up, source)
	return winner_loss - runner_loss


## Names which of `source`'s terms carried it, by absolute recorded magnitude.
## Deterministic: the constant tables above are scanned in declaration order.
## Public because GuidanceContribution names the same term for a guidance response —
## one code vocabulary, one owner.
static func dominant_code(entry: Dictionary, source: String) -> String:
	var components: Dictionary = entry.get("components", {}) as Dictionary
	var spatial_parts: Dictionary = (entry.get("spatial", {}) as Dictionary).get("parts", {}) as Dictionary
	var bias: Dictionary = entry.get("bias", {}) as Dictionary
	var best_key: String = ""
	var best_abs: float = 0.0
	for term: String in _TERM_SOURCE:
		if str(_TERM_SOURCE[term]) != source:
			continue
		# fear_factor and calling_mul are multipliers: 1.0 means "did nothing".
		var magnitude: float = absf(float(components.get(term, 1.0 if term in ["fear_factor", "calling_mul"] else 0.0)) \
			- (1.0 if term in ["fear_factor", "calling_mul"] else 0.0))
		if magnitude > best_abs:
			best_abs = magnitude
			best_key = term
	for part: String in spatial_parts:
		if str(_SPATIAL_SOURCE.get(part, "baseline")) != source:
			continue
		var magnitude: float = absf(float(spatial_parts[part]))
		if magnitude > best_abs:
			best_abs = magnitude
			best_key = part
	for key: String in bias:
		if str(_BIAS_SOURCE.get(key, "baseline")) != source:
			continue
		var magnitude: float = absf(float(bias[key]))
		if magnitude > best_abs:
			best_abs = magnitude
			best_key = key
	return str(_TERM_CODE.get(best_key, source))


static func _strength_band(swing: float, decision_scale: float) -> String:
	if decision_scale <= 0.0:
		return "decisive"
	var ratio: float = swing / decision_scale
	if ratio < _BAND_SLIGHT_MAX:
		return "slight"
	if ratio < _BAND_MODERATE_MAX:
		return "moderate"
	if ratio < _BAND_STRONG_MAX:
		return "strong"
	return "decisive"


static func _reason(
	code: String,
	source: String,
	subject_id: String,
	causal_kind: String,
	material: bool,
	strength_band: String
) -> Dictionary:
	return {
		"code":          code,
		"source":        source,
		"subject_id":    subject_id,
		"causal_kind":   causal_kind,
		"material":      material,
		"strength_band": strength_band,
	}


static func _message_key(primary: Dictionary, band: String) -> String:
	match str(primary.get("causal_kind", "")):
		"hard_override":
			return "decision.reason.hard_rule"
		"baseline":
			return "decision.reason.baseline"
		_:
			return "decision.reason.%s" % band


## Legibility is what decides how much the message may say: a barely legible Echo
## surfaces a purpose and no attribution; a fully legible one names the pressure and
## its subject.
static func _message_args(primary: Dictionary, purpose: String, band: String) -> Dictionary:
	var args: Dictionary = {"purpose": purpose}
	if str(primary.get("causal_kind", "")) == "baseline":
		return args
	if str(primary.get("causal_kind", "")) == "hard_override" or band != "vague":
		args["source"] = str(primary.get("source", ""))
		args["code"] = str(primary.get("code", ""))
	if str(primary.get("causal_kind", "")) == "hard_override" or band == "explicit":
		args["subject_id"] = str(primary.get("subject_id", ""))
	return args

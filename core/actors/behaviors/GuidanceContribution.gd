# res://core/actors/behaviors/GuidanceContribution.gd
# The Keeper's guidance as one behaviour contribution, and the five answers an Echo
# may give it: Align, Interpret, Hesitate, Object, Refuse.
#
# This file owns four things and nothing else:
#   1. WHO the suggestion reaches (an Echo named as a recipient, and no one else);
#   2. HOW MUCH the suggestion is worth against her own reading of the board;
#   3. WHICH of the five answers she gives;
#   4. THE ONE REASON she gives for any answer but Align, and the proof it is true.
#
# It derives no identity value. `judgment` and `composure` arrive already computed by
# MaturityExpressionService; nothing here recomputes either, and there is deliberately
# no obedience number anywhere in this file. Standing buys COHERENCE, not compliance:
# at the same contest a coherent Echo interprets or objects where a young one only
# hesitates, so the two are equally likely to end up doing what was suggested — they
# differ in how clearly they say what they are doing.
#
# THE GUIDANCE IS A BIAS, NOT A SCORE TERM. Every answer is a transform on one
# post-scoring contribution applied through BehaviorArbiter._apply_bias, beside vow
# and bond. _score()'s body is untouched, so `directive_bonus` keeps its position as a
# flat additive term outside the fear and calling brackets — the placement
# `self_score = score - directive_bonus` depends on. It also makes the no-guidance
# case exact rather than approximate: with no request, resolve() returns {} before it
# reads a single candidate, so not one number moves.
#
# THE CONTEST DOES NOT DEPEND ON HOW HARD THE KEEPER PUSHED. It is her own spread:
# how far below her own choice the suggested plan already sat, divided by how much her
# options differed to her at all. A Keeper cannot make an Echo object by suggesting
# harder, only by suggesting something she likes less.
#
# Pure. Static. No state, no RNG, no Time, no ConfigService.

class_name GuidanceContribution

const DecisionTraceScript = preload("res://core/actors/behaviors/DecisionTrace.gd")

## The five answers, in ladder order.
const RESPONSES: Array = ["align", "interpret", "hesitate", "object", "refuse"]

## PROPOSED DEFAULT — the contest at which each answer begins, as a fraction of the
## spread of the options the Echo actually weighed. Both ends of that fraction come from
## the same candidate set, so the contest is bounded in [0, 1] by construction: 0 means
## the suggestion IS her own choice, 1 means it is the worst thing on her board.
##
## Measured before they were chosen, over 678 Echo turns: 293 turns at exactly 0, 179 at
## exactly 1, 206 spread between. A suggestion usually either names what she already
## meant to do or names the one thing she was avoiding, so the ends are heavy — which is
## why Interpret is not a band here (see the ladder in resolve()) and why T_REFUSE sits
## below the top of the range rather than at it: composure scales the ladder up, and a
## threshold at 1.0 would put refusal out of reach of every steady Echo.
##
## The owner tunes these in play. They live in this file rather than balance.json
## because the guidance source is headless for this story and has no config block yet —
## V2-COMBAT-004 opens one.
const T_ALIGN: float = 0.10
const T_OBJECT: float = 0.45
const T_REFUSE: float = 0.80

## PROPOSED DEFAULT — the judgment at which an Echo can hold a purpose while changing
## its method (interpret), and at which she can name a disagreement instead of only
## showing it (object). Below both she hesitates instead, at every contest. This is the
## whole of what Standing buys: not compliance, articulacy.
##
## Set from measurement, not from the 0-1 range the field suggests. Judgment as actually
## derived is compressed low: over the same 678 turns it ran 0.030 to 0.214, median 0.060,
## and a Standing-6 Echo reached only 0.214. Gates chosen at 1.0 scale would have made
## Interpret and Object dead code — the first measurement pass proved exactly that.
const J_INTERPRET: float = 0.09
const J_OBJECT: float = 0.13

## The suggestion can carry a plan over a gap of at most T_ALIGN spreads — exactly the
## band in which she aligns. Deliberately not an independent number: a suggestion that
## could carry further than the align band would be an order, not a suggestion.
const PLAN_AUTHORITY: float = T_ALIGN
## Interpret keeps the purpose and drops the plan, so its contribution reaches every
## option serving that purpose at the same weight the plan part would have had.
const PURPOSE_AUTHORITY: float = T_ALIGN
## PROPOSED DEFAULT — what a hesitant Echo does with the suggestion, and what she
## charges herself for committing far while unsure.
const HESITATE_SCALE: float = 0.35
const HESITATE_COMMITMENT_COST: float = 0.20

## Composure raises the whole ladder at once: a steady Echo does not make a scene about
## a small disagreement, and does not refuse one either. Same lever, same meaning and
## the same default as DivergenceDetector's noise gate — composure is steadiness under
## contradiction in exactly one place in this codebase.
const COMPOSURE_NOISE_GATE: float = 0.5

## Below this the options all looked the same to her, so there is nothing to contest.
## Mirrors DivergenceDetector's decision_scale_epsilon for the same reason.
const SPREAD_EPSILON: float = 1.0

## Prose for each DecisionTrace reason code. No number, no identifier — this is the
## sentence the Echo gives, and it is only ever chosen after the code has passed the
## materiality test below.
const _REASON_TEXT: Dictionary = {
	"calling_weight":     "this is not what she was called to do",
	"calling_press":      "her calling presses the other way",
	"disposition":        "it is not in her nature",
	"values":             "it goes against what she holds to",
	"temperament":        "her temperament pulls another way",
	"morale":             "she has no heart for it",
	"fear":               "she is too afraid of that ground",
	"directive_order":    "the standing Directive says otherwise",
	"situation":          "what is in front of her changed",
	"objective_urgency":  "what she is holding will not wait",
	"objective_progress": "she is closer to finishing what matters",
	"route_exposure":     "the lane you marked is open ground",
	"route_congestion":   "the way you marked is crowded",
	"formation_cohesion": "she will not break from the others",
	"commitment_cost":    "it is further than she will commit",
	"vow_held":           "her vow holds her",
	"bond_pull":          "she will not leave the one she is bound to",
	"leader_cover":       "another already told her where to stand",
	"keeper_guidance":    "she reads it the way you do",
}

## Prose for the baseline answer — §6.6's third permitted primary, used when no single
## pressure carried the decision and the honest reason is the purpose she is already
## serving. Keyed by MovementGoal.PURPOSES.
const _PURPOSE_TEXT: Dictionary = {
	"advance":     "she is already moving where it matters",
	"engage":      "she is already in the fight",
	"intercept":   "she is already cutting a way off",
	"protect":     "she is already covering someone",
	"hold":        "she is already holding the ground that counts",
	"pursue":      "she is already after the one who ran",
	"cut_off":     "she is already closing a way out",
	"reposition":  "she is already moving to better ground",
	"regroup":     "she is already closing on the others",
	"withdraw":    "she is already pulling back",
	"read":        "she is still reading the ground",
	"escort":      "she is already walking someone out",
}


## `request` is the headless guidance source (V2-COMBAT-003 decision 2 — only tests and
## one debug command write it; V2-COMBAT-004 connects the real interface here):
##   guidance_id:   String — names the suggestion for the log
##   action_type:   String — the suggested plan, "" for a purpose-only suggestion
##   subject_id:    String — who or what it is about, "" for any
##   purpose:       String — a MovementGoal purpose, "" for a plan-only suggestion
##   recipient_ids: Array  — [] means every Echo on the board
##
## `entries` are the arbiter's candidates normalized to one shape (see
## BehaviorArbiter._guidance_entries): key / action_type / target_id / purpose /
## commitment / capacity / score / components / spatial / bias. `score` is each
## candidate's score as it stands BEFORE any guidance, which is what makes the contest
## her own reading rather than a reaction to the suggestion's weight.
##
## Returns {} when the suggestion does not reach this actor at all. An absent response
## is "unaffected" and must never be read as a refusal.
static func resolve(
	request: Dictionary,
	entries: Array,
	actor: Dictionary,
	judgment: float,
	composure: float
) -> Dictionary:
	if request.is_empty() or entries.is_empty():
		return {}
	# The Keeper guides the Echoes in her care. A Distortion receives nothing.
	if str(actor.get("faction", "")) != "echo":
		return {}
	var recipients: Array = request.get("recipient_ids", []) as Array
	if not recipients.is_empty() and not recipients.has(str(actor.get("id", ""))):
		return {}

	var spread: float = _option_spread(entries)
	var match_result: Dictionary = _suggested_match(request, entries)
	var suggested: Dictionary = match_result["entry"] as Dictionary
	var self_plan: Dictionary = _best_entry(entries)
	if suggested.is_empty():
		# Nothing she can do this turn serves the suggestion. That is not disagreement,
		# so it is not one of the five answers.
		return {}

	# The contest: how far below her own choice the suggestion already sat, measured
	# against how much her options differed to her at all.
	var contest: float = 0.0
	if spread > SPREAD_EPSILON:
		contest = maxf(float(self_plan.get("score", 0.0)) - float(suggested.get("score", 0.0)), 0.0) / spread

	# Composure raises the whole ladder at once, so it buys steadiness rather than
	# obedience: a composed Echo needs more contest to hesitate, to object AND to refuse.
	var steadiness: float = 1.0 + COMPOSURE_NOISE_GATE * clampf(composure, 0.0, 1.0)
	var t_align: float = T_ALIGN * steadiness
	var t_object: float = T_OBJECT * steadiness
	var t_refuse: float = T_REFUSE * steadiness

	# The ladder. Interpret is deliberately NOT a contest band: keeping a purpose while
	# changing its method is a STRUCTURAL fact about her own plan, not a magnitude.
	# Measurement forced this twice. As a contest band it was unreachable, because the
	# contest is bimodal and almost nothing lands in the middle. As "same purpose,
	# different candidate" it was unreachable too: a goal's purpose fixes its planned
	# action, so the best option serving a purpose IS her own choice.
	#
	# What is left is the design's own example, and it is common: you name the line, she
	# cannot serve exactly that, and her own plan still serves what you meant. That is a
	# suggestion whose most specific form did not match — see _suggested_match.
	var shares_purpose: bool = not str(request.get("purpose", "")).is_empty() \
		and str(self_plan.get("purpose", "")) == str(request.get("purpose", "")) \
		and (bool(match_result["relaxed"]) \
			or str(self_plan.get("key", "")) != str(suggested.get("key", "")))

	# Interpret sits ABOVE Align on purpose. When the suggestion as given cannot be served,
	# she did not do what you said — she did what you meant, and that is a different
	# answer even when it costs her nothing.
	var response: String = "align"
	if contest >= t_refuse:
		response = "refuse"
	elif shares_purpose:
		response = "interpret" if judgment >= J_INTERPRET else "hesitate"
	elif contest < t_align:
		response = "align"
	elif contest >= t_object:
		response = "object" if judgment >= J_OBJECT else "hesitate"
	else:
		response = "hesitate"

	var reason: Dictionary = _reason_for(response, self_plan, suggested, request)
	return {
		"guidance_id":       str(request.get("guidance_id", "")),
		"response":          response,
		"reason":            reason,
		"reason_text":       _reason_text(response, reason, self_plan),
		"contest":           contest,
		"option_spread":     spread,
		"suggested_key":     str(suggested.get("key", "")),
		"self_key":          str(self_plan.get("key", "")),
		"shares_purpose":    shares_purpose,
		"recipient_dropped": response == "refuse",
		"deltas":            _deltas(response, request, entries, suggested, spread),
	}


## What each answer does to the one contribution. This table IS the difference between
## the five: nothing else in this file distinguishes them mechanically.
##
##   align      the suggestion arrives whole — plan and purpose;
##   interpret  the plan part is dropped; every option serving the same purpose keeps
##              the full weight, so she goes there her own way;
##   hesitate   the whole contribution is scaled down AND every option is charged for
##              how far it commits, so she moves shorter and later;
##   object     nothing arrives; she acts on her own judgment and says so;
##   refuse     nothing arrives, and she leaves the suggestion's recipients — she still
##              acts, on her own purpose, because removing the Keeper's influence
##              cannot remove hers.
static func _deltas(
	response: String,
	request: Dictionary,
	entries: Array,
	suggested: Dictionary,
	spread: float
) -> Dictionary:
	var deltas: Dictionary = {}
	if response == "object" or response == "refuse" or spread <= SPREAD_EPSILON:
		return deltas
	var plan_weight: float = PLAN_AUTHORITY * spread
	var purpose_weight: float = PURPOSE_AUTHORITY * spread
	var scale: float = HESITATE_SCALE if response == "hesitate" else 1.0
	var purpose: String = str(request.get("purpose", ""))
	for entry_v: Variant in entries:
		var entry: Dictionary = entry_v as Dictionary
		var delta: float = 0.0
		if response != "interpret" and str(entry.get("key", "")) == str(suggested.get("key", "")):
			delta += plan_weight
		if not purpose.is_empty() and str(entry.get("purpose", "")) == purpose:
			delta += purpose_weight
		delta *= scale
		if response == "hesitate":
			var capacity: float = maxf(float(entry.get("capacity", 0.0)), 1.0)
			delta -= HESITATE_COMMITMENT_COST * spread * (float(entry.get("commitment", 0.0)) / capacity)
		if delta != 0.0:
			deltas[str(entry.get("key", ""))] = delta
	return deltas


## The one reason, and the proof it is true (§6.6). A source may be named only when
## REMOVING it would have put the suggested plan back ahead of her own — the same
## counterfactual DecisionTrace uses, run against the same recorded decomposition, so
## a reason can never name a pressure that did not change this decision.
##
## When no single source carries that weight the honest answer is not a stronger claim
## but a weaker one: §6.6's baseline primary, the purpose she is already serving.
static func _reason_for(
	response: String,
	self_plan: Dictionary,
	suggested: Dictionary,
	request: Dictionary
) -> Dictionary:
	var subject_id: String = str(request.get("subject_id", ""))
	if response == "align":
		return _reason("keeper_guidance", "guidance", subject_id, "co_decisive", true, "none")

	var margin: float = float(self_plan.get("score", 0.0)) - float(suggested.get("score", 0.0))
	var best_source: String = ""
	var best_swing: float = 0.0
	for source: String in DecisionTraceScript.SOURCES:
		var winner_loss: float = float(self_plan.get("score", 0.0)) \
			- DecisionTraceScript.score_without(self_plan, source)
		var suggested_loss: float = float(suggested.get("score", 0.0)) \
			- DecisionTraceScript.score_without(suggested, source)
		var swing: float = winner_loss - suggested_loss
		if swing > margin and swing > best_swing:
			best_swing = swing
			best_source = source
	if best_source.is_empty():
		return _reason(
			str(self_plan.get("purpose", "")), "baseline", subject_id, "baseline", false, "none"
		)
	return _reason(
		DecisionTraceScript.dominant_code(self_plan, best_source),
		best_source,
		subject_id,
		"co_decisive",
		true,
		_band_for(response)
	)


static func _reason_text(response: String, reason: Dictionary, self_plan: Dictionary) -> String:
	if response == "align":
		return ""
	if str(reason.get("source", "")) == "baseline":
		return str(_PURPOSE_TEXT.get(str(self_plan.get("purpose", "")), "she is already doing what matters more"))
	return str(_REASON_TEXT.get(str(reason.get("code", "")), "she reads the board differently"))


static func _band_for(response: String) -> String:
	match response:
		"interpret":
			return "slight"
		"hesitate":
			return "moderate"
		"object":
			return "strong"
		"refuse":
			return "decisive"
		_:
			return "none"


## The option the suggestion names, as her own options express it. Preferring the
## highest-scoring match keeps the contest honest: the suggestion is measured against
## the BEST way she has of doing what was asked, never against her worst.
##
## Matching relaxes the suggestion's specificity in a fixed order until something she
## can actually do this turn matches. Without the cascade, a suggestion whose exact
## triple she cannot serve would produce no answer at all — and silence is not one of
## the five.
const _MATCH_TIERS: Array = [
	["plan", "purpose", "subject"],
	["plan", "subject"],
	["plan", "purpose"],
	["plan"],
	["purpose"],
]

## Returns the matched entry and whether the match cost the suggestion specificity.
## `relaxed` is what tells Interpret from Align: it means the suggestion, exactly as the
## Keeper gave it, is not something this Echo can do this turn.
static func _suggested_match(request: Dictionary, entries: Array) -> Dictionary:
	var tried_specific: bool = false
	for tier_v: Variant in _MATCH_TIERS:
		var tier: Array = tier_v
		if tier.has("plan") and str(request.get("action_type", "")).is_empty():
			continue
		if tier.has("purpose") and str(request.get("purpose", "")).is_empty():
			continue
		if tier.has("subject") and str(request.get("subject_id", "")).is_empty():
			continue
		var match_found: Dictionary = _best_match(request, entries, tier)
		if not match_found.is_empty():
			return {"entry": match_found, "relaxed": tried_specific}
		tried_specific = true
	return {"entry": {}, "relaxed": false}


static func _best_match(request: Dictionary, entries: Array, tier: Array) -> Dictionary:
	var best: Dictionary = {}
	for entry_v: Variant in entries:
		var entry: Dictionary = entry_v as Dictionary
		if tier.has("plan") and str(entry.get("action_type", "")) != str(request.get("action_type", "")):
			continue
		if tier.has("purpose") and str(entry.get("purpose", "")) != str(request.get("purpose", "")):
			continue
		if tier.has("subject") and str(entry.get("target_id", "")) != str(request.get("subject_id", "")):
			continue
		if best.is_empty() or _entry_before(entry, best):
			best = entry
	return best


static func _best_entry(entries: Array) -> Dictionary:
	var best: Dictionary = {}
	for entry_v: Variant in entries:
		var entry: Dictionary = entry_v as Dictionary
		if best.is_empty() or _entry_before(entry, best):
			best = entry
	return best


## Deterministic order: score, then the candidate's generation-order key.
static func _entry_before(left: Dictionary, right: Dictionary) -> bool:
	var left_score: float = float(left.get("score", 0.0))
	var right_score: float = float(right.get("score", 0.0))
	if left_score != right_score:
		return left_score > right_score
	return str(left.get("key", "")) < str(right.get("key", ""))


static func _option_spread(entries: Array) -> float:
	var low: float = INF
	var high: float = -INF
	for entry_v: Variant in entries:
		var score: float = float((entry_v as Dictionary).get("score", 0.0))
		low = minf(low, score)
		high = maxf(high, score)
	return (high - low) if high >= low else 0.0


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

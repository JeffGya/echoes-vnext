# res://core/actors/DivergenceDetector.gd
# V2-PROG-012 Phase 4 — Echo/Directive divergence detection.
#
# GDD §7.3:259: "Resistance without a readable reason is not character
# autonomy; it is lost player agency." `directive_band_mul` (nascent 1.30 →
# whole 0.75) already makes a Whole Echo weight directives less than a
# Nascent one — but nothing detected, named, or recorded the moment her own
# judgment actually out-voted the Directive. This file is that detection.
#
# Why a separate file (not folded into BehaviorArbiter or
# MaturityExpressionService): score arithmetic must stay out of
# MaturityExpressionService (which reads identity and would become the hidden
# stat tree GDD:1438-1442 forbids), and threshold POLICY must stay out of
# BehaviorArbiter (which is a scoring engine that only REPORTS — see the
# comment on `directive_bonus` inside BehaviorArbiter._score()). This is the
# one place that turns raw score components into a diverged/not-diverged
# verdict.
#
# Pure. Static. No state, no RNG, no CampaignSeed, no Time. Same inputs
# always produce the same output dict.
#
# The output vocabulary (diverged / divergence_kind / severity / etc.) is
# deliberately NOT the five COMBAT-003 responses (Align/Interpret/Hesitate/
# Object/Refuse) — this phase only detects, names, and records. V2-COMBAT-003
# maps this vocabulary onto player-facing responses later. No bark is
# produced here either — V2-PROG-012 Phase 5 owns that.
# V2-VOICE-002 aggregates across a party; this file stays strictly per-Echo.
#
# Detection changes NO score. Every value read here (`score`, `directive_bonus`,
# `directive_bonus_nascent`, `components`) was already computed by
# BehaviorArbiter's normal scoring pass before this file ever runs — this is
# observation, not re-scoring.

class_name DivergenceDetector

## Player-readable labels for the dominant _score() term. No IDs — this
## project forbids IDs in player-facing text, and V2-PROG-012 Phase 5 voices
## these strings verbatim as bark material. Order is the deterministic
## tie-break order for _primary_reason()'s dominant-term scan (GDScript
## Dictionary literals preserve insertion order).
const _COMPONENT_LABELS: Dictionary = {
	"base":              "calling pressure",
	"trait_bonus":       "personal disposition",
	"vector_bonus":      "her own values",
	"archetype_bonus":   "temperament",
	"morale_bonus":      "morale",
	"directive_bonus":   "the Directive",
	"situational_bonus": "the situation",
}


## chosen / directive_preferred shape (both produced by BehaviorArbiter, never
## constructed by policy code — see select_intent()/select_movement_intent()):
##   action_type: String
##   target_id:   String
##   score:       float — the candidate's FINAL _score, i.e. whatever value the
##                 arbiter's own winner-sort actually compared (this may include
##                 spatial_utility / purifier-override adjustments the caller
##                 applied on top of _score()'s return — see BehaviorArbiter).
##   directive_bonus:         float — _directive_bonus() at the ACTUAL expression_band.
##   directive_bonus_nascent: float — _directive_bonus() re-evaluated at band "nascent".
##   components: Dictionary — (chosen only; ignored on directive_preferred) the raw
##                 _score() term breakdown, used only for primary_reason.
##
## divergence_cfg: data.maturity_expression.divergence from balance.json.
static func detect(
	chosen: Dictionary,
	directive_preferred: Dictionary,
	composure: float,
	legibility: float,
	divergence_cfg: Dictionary
) -> Dictionary:
	var chosen_action: String    = str(chosen.get("action_type", ""))
	var directive_action: String = str(directive_preferred.get("action_type", ""))

	var w_directive_bonus: float = float(chosen.get("directive_bonus", 0.0))
	var d_directive_bonus: float = float(directive_preferred.get("directive_bonus", 0.0))
	# self_score(c) = c.score - directive_bonus(c): the Echo's own judgment with
	# the Directive's voice algebraically removed (see BehaviorArbiter._score()
	# for why this subtraction is exact).
	var w_self_score: float = float(chosen.get("score", 0.0)) - w_directive_bonus
	var d_self_score: float = float(directive_preferred.get("score", 0.0)) - d_directive_bonus

	# directive_pull >= 0 by construction: directive_preferred is defined as the
	# candidate maximizing directive_bonus, so no candidate can exceed it.
	var directive_pull: float = d_directive_bonus - w_directive_bonus
	var self_margin: float    = w_self_score - d_self_score
	# Algebraic guarantee (pinned in DivergenceDetectorTests):
	#   overrule_strength == chosen.score - directive_preferred.score
	# which is >= 0 whenever `chosen` genuinely won its own arbiter sort — so
	# self_margin >= directive_pull >= 0 holds for every real winner. This is
	# exactly "how far past merely tying the Echo's own judgment carried it."
	var overrule_strength: float = self_margin - directive_pull

	var min_margin: float         = float(divergence_cfg.get("divergence_min_margin", 6.0))
	var noise_gate: float         = float(divergence_cfg.get("composure_noise_gate", 0.5))
	var contradiction_gain: float = float(divergence_cfg.get("composure_contradiction_gain", 0.75))
	# Composure does GDD:1369's two-sided sentence with one number: it RAISES the
	# bar for what counts as divergence (noise rejection)...
	var effective_min_margin: float = min_margin * (1.0 + noise_gate * composure)

	var diverged: bool = chosen_action != directive_action \
		and directive_pull > 0.0 \
		and overrule_strength >= effective_min_margin

	var severity: float = 0.0
	var divergence_kind: String = ""
	var primary_reason: String = ""
	if diverged:
		# ...and AMPLIFIES recorded severity when it does fire (contradiction sharpening).
		severity = overrule_strength * (1.0 + contradiction_gain * composure)

		# divergence_kind — the headline claim made observable. Re-evaluate ONLY the
		# directive_bonus term (not the whole score) at band "nascent", the most
		# literal weighting (directive_band_mul.nascent == 1.30). self_score already
		# excludes directive_bonus, so it is band-invariant by construction; adding
		# the nascent-band bonus back in answers "would D have beaten W if this Echo
		# had weighted the Directive at Nascent instead of her actual band?"
		var w_nascent: float = w_self_score + float(chosen.get("directive_bonus_nascent", 0.0))
		var d_nascent: float = d_self_score + float(directive_preferred.get("directive_bonus_nascent", 0.0))
		divergence_kind = "interpretation" if d_nascent >= w_nascent else "judgment"

		primary_reason = _primary_reason(
			chosen.get("components", {}) as Dictionary, legibility, divergence_cfg
		)

	return {
		"diverged":          diverged,
		"divergence_kind":   divergence_kind,
		"overrule_strength": overrule_strength,
		"directive_pull":    directive_pull,
		"self_margin":       self_margin,
		"threshold":         effective_min_margin,
		"severity":          severity,
		"primary_reason":    primary_reason,
		"directive_action":  directive_action,
		"chosen_action":     chosen_action,
	}


## Names the dominant _score() term for `chosen`, at a specificity that scales
## with legibility (data.maturity_expression.divergence.legibility_specificity_bands).
## No IDs — this string is stable and player-readable; V2-PROG-012 Phase 5 will
## voice it as a bark, this phase only produces it.
static func _primary_reason(components: Dictionary, legibility: float, divergence_cfg: Dictionary) -> String:
	if components.is_empty():
		return "her own judgment"

	# base/trait_bonus/vector_bonus/archetype_bonus/morale_bonus all live inside
	# BehaviorArbiter._score()'s fear/calling bracket; directive_bonus and
	# situational_bonus are flat additive terms outside it (see that function).
	# Weighting the bracket terms by the same multiplier _score() applies keeps
	# this comparison honest to each term's actual contribution to the total.
	var mult: float = float(components.get("fear_factor", 1.0)) * float(components.get("calling_mul", 1.0))
	var contributions: Dictionary = {
		"base":              float(components.get("base", 0.0)) * mult,
		"trait_bonus":       float(components.get("trait_bonus", 0.0)) * mult,
		"vector_bonus":      float(components.get("vector_bonus", 0.0)) * mult,
		"archetype_bonus":   float(components.get("archetype_bonus", 0.0)) * mult,
		"morale_bonus":      float(components.get("morale_bonus", 0.0)) * mult,
		"directive_bonus":   float(components.get("directive_bonus", 0.0)),
		"situational_bonus": float(components.get("situational_bonus", 0.0)),
	}

	var dominant_key: String = ""
	var dominant_abs: float = 0.0
	for key: String in _COMPONENT_LABELS:
		var v: float = absf(float(contributions.get(key, 0.0)))
		if v > dominant_abs:
			dominant_abs = v
			dominant_key = key
	if dominant_key.is_empty():
		return "her own judgment"

	var bands: Dictionary = divergence_cfg.get("legibility_specificity_bands", {})
	var vague_max: float = float(bands.get("vague_max", 0.34))
	var named_max: float = float(bands.get("named_max", 0.67))
	var label: String = str(_COMPONENT_LABELS.get(dominant_key, "her own judgment"))

	if legibility <= vague_max:
		return "her own judgment"
	elif legibility <= named_max:
		return label
	else:
		return "%s outweighed the Directive" % label

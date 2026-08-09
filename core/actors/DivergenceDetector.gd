# res://core/actors/DivergenceDetector.gd
# V2-PROG-012 Phase 4 — Echo/Directive divergence detection.
#
# GDD §7.3:259: "Resistance without a readable reason is not character
# autonomy; it is lost player agency." `directive_interpretation_mul` (V2-PROG-012
# Phase 6: continuous over interpretation_width/judgment, replacing the old
# per-band `directive_band_mul` table — low judgment 1.30 → high judgment 0.75)
# already makes a high-judgment Echo weight directives less than a low-judgment
# one — but nothing detected, named, or recorded the moment her own judgment
# actually out-voted the Directive. This file is that detection.
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


## chosen shape (produced by BehaviorArbiter, never constructed by policy code —
## see select_intent()/select_movement_intent()):
##   action_type: String
##   target_id:   String
##   score:       float — the candidate's FINAL _score, i.e. whatever value the
##                 arbiter's own winner-sort actually compared (this may include
##                 spatial_utility / purifier-override adjustments the caller
##                 applied on top of _score()'s return — see BehaviorArbiter).
##   directive_bonus:         float — _directive_bonus() at the ACTUAL expression_band.
##   directive_bonus_nascent: float — _directive_bonus() re-evaluated at band "nascent".
##   components: Dictionary — the raw _score() term breakdown, used only for primary_reason.
##
## directive_candidates: the FULL ranking BehaviorArbiter computed, descending by
## directive_bonus (same per-entry shape as `chosen`, minus `components`) — not
## just the single top candidate. Part B: a directive whose favourite action is
## merely "do nothing" (divergence_ignored_directive_actions, default
## ["actor.idle"]) is not something an acting Echo can meaningfully defy, so this
## falls through the ranking to the next entry whose action_type isn't ignored —
## see _resolve_directive_preferred() below for why FALL-THROUGH was chosen over
## simple suppression (measured data: directive.scout_carefully's directive
## preference is actor.idle on ~100% of turns in a real encounter — suppression
## alone would leave this detector permanently silent, exactly the "dormant seam"
## failure mode the story brief calls out).
##
## decision_scale: max(self_score) - min(self_score) across every regularly-scored
## candidate this turn (BehaviorArbiter's select_intent()/select_movement_intent()
## compute this — see the comment on `_decision_scale` there). It is the yardstick
## `directive_pull` is measured against: "how large was the directive's push,
## relative to how much the options actually differed to HER?" A raw margin
## (the pre-fix version of this file) conflates "the directive pushed hard" with
## "her options were very different from each other" — see the story brief for
## the production case (directive_pull 10.5 against a ~235-point tactical spread:
## a 4% nudge, not a contest) that this fixes.
##
## divergence_cfg: data.maturity_expression.divergence from balance.json.
static func detect(
	chosen: Dictionary,
	directive_candidates: Array,
	decision_scale: float,
	composure: float,
	legibility: float,
	divergence_cfg: Dictionary
) -> Dictionary:
	var ignored_actions: Array = divergence_cfg.get("divergence_ignored_directive_actions", ["actor.idle"])
	var directive_preferred: Dictionary = _resolve_directive_preferred(directive_candidates, ignored_actions)

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
	# KEPT as a diagnostic field (and the algebraic invariant tests still pin it)
	# but it is NO LONGER the trigger — see `contest_ratio` below.
	var overrule_strength: float = self_margin - directive_pull

	var min_contest_ratio: float      = float(divergence_cfg.get("min_contest_ratio", 0.35))
	var decision_scale_epsilon: float = float(divergence_cfg.get("decision_scale_epsilon", 1.0))
	var noise_gate: float             = float(divergence_cfg.get("composure_noise_gate", 0.5))
	var contradiction_gain: float     = float(divergence_cfg.get("composure_contradiction_gain", 0.75))

	# contest_ratio: how large the directive's push was RELATIVE TO how much the
	# scored options actually differed to her — a proportion, not a raw number.
	# Guard against a near-zero decision_scale: if every option looked about the
	# same to her, no meaningful divergence is possible (there was nothing to
	# diverge FROM), regardless of how large directive_pull happens to be.
	var decision_scale_valid: bool = decision_scale > decision_scale_epsilon
	var contest_ratio: float = (directive_pull / decision_scale) if (decision_scale_valid and directive_pull > 0.0) else 0.0

	# Composure does GDD:1369's two-sided sentence with one number: it RAISES the
	# bar for what counts as divergence (noise rejection)...
	var effective_min_contest_ratio: float = min_contest_ratio * (1.0 + noise_gate * composure)

	# `directive_preferred` was already resolved past any ignored action_type by
	# _resolve_directive_preferred() above (Part B) — if it came back empty (every
	# candidate's action_type was ignored, or the candidate list was empty), there
	# is no meaningful directive preference left to contest.
	var diverged: bool = not directive_preferred.is_empty() \
		and chosen_action != directive_action \
		and directive_pull > 0.0 \
		and decision_scale_valid \
		and contest_ratio >= effective_min_contest_ratio

	var severity: float = 0.0
	var divergence_kind: String = ""
	var primary_reason: String = ""
	if diverged:
		# ...and AMPLIFIES recorded severity when it does fire (contradiction sharpening).
		# severity now derives from contest_ratio (a stable, comparable-across-encounters
		# fraction), not overrule_strength (a raw number dominated by tactical quality).
		severity = contest_ratio * (1.0 + contradiction_gain * composure)

		# divergence_kind — the headline claim made observable. Re-evaluate ONLY the
		# directive_bonus term (not the whole score) at interpretation_width=0.0, the
		# most literal weighting (directive_interpretation_mul.high == 1.30 — V2-PROG-012
		# Phase 6; field name `directive_bonus_nascent` is unchanged for contract
		# stability, but it is now computed at interpretation_width=0.0, not band
		# "nascent"). self_score already excludes directive_bonus, so it is
		# interpretation_width-invariant by construction; adding the most-literal
		# bonus back in answers "would D have beaten W if this Echo had judgment at
		# its floor instead of her actual level?"
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
		"decision_scale":    decision_scale,
		"contest_ratio":     contest_ratio,
		"threshold":         effective_min_contest_ratio,
		"severity":          severity,
		"primary_reason":    primary_reason,
		"directive_action":  directive_action,
		"chosen_action":     chosen_action,
	}


## V2-PROG-012 Phase 4 fix — Part B: picks the effective directive_preferred by
## scanning `directive_candidates` (already ranked descending by directive_bonus
## by BehaviorArbiter — see _rank_directive_candidates()) and returning the first
## entry whose action_type is NOT in `ignored_actions`. Returns {} if every entry
## is ignored (or the list is empty) — `detect()` treats that as "no meaningful
## directive preference to contest".
##
## FALL-THROUGH, not suppression: a detector that simply refused to fire whenever
## the single top-ranked D was "actor.idle" would have gone silent for an entire
## real encounter under directive.scout_carefully — measurement showed D is
## actor.idle on ~100% of turns there (it carries more directive_action_muls
## semantic keys than any other action), so "D is ignored" and "D is actor.idle"
## were nearly the same event. Falling through to the next-best NON-ignored
## preference (typically actor.guard, a genuinely deliberate defensive choice)
## keeps the detector answering its real question — "did she defy a meaningful
## directive preference?" — instead of going dormant. See the story's measurement
## writeup for the before/after event counts that justified this choice.
static func _resolve_directive_preferred(directive_candidates: Array, ignored_actions: Array) -> Dictionary:
	for candidate_v: Variant in directive_candidates:
		var candidate: Dictionary = candidate_v as Dictionary
		if not ignored_actions.has(str(candidate.get("action_type", ""))):
			return candidate
	return {}


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

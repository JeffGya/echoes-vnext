# res://core/actors/MaturityExpressionService.gd
# Derives the maturity-expression band and presence strength for an actor.
# Replaces SmartnessTierService (V2-PROG-006).
#
# The maturity-expression layer reflects how internally authored an Echo has
# become — not AI competence tiers. Expression band is derived from Standing
# (rank) and shapes behavior selection, refusal thresholds, social spillover,
# and directive interpretation.
#
# Four outputs (GDD §11.5, §7.3):
#   expression_band — how strongly the Echo holds/asserts self under pressure (band form)
#   judgment        — how strongly the Echo can hold, interpret, and assert self under pressure
#   presence        — how strongly that current state presses onto nearby or bonded others
#   composure       — less casually swayable by noise, but more sharply affected by true contradiction
#   legibility      — how specific and readable the Echo's intent is
#
# Rules:
# - Pure static helpers. No state, no side effects. No RNG.
# - Uses actor["calling"] if present and non-empty (confirmed identity),
#   falls back to actor["calling_origin"] (birth bias).
# - All config reads are from caller-supplied dicts (never loads ConfigService directly).
# - judgment/presence/composure/legibility are float, clamped 0.0-1.0, and are
#   NEVER persisted — they live only on the transient combat actor dict.

class_name MaturityExpressionService

const SocialGraphService = preload("res://core/sanctum/SocialGraphService.gd")


# ── Expression band ───────────────────────────────────────────────────────────

# Returns the expression band for this actor based on Standing (rank).
# Possible values: "nascent" | "forming" | "grounded" | "whole"
#   nascent  — self still assembling (rank 1)
#   forming  — self taking shape (rank 2)
#   grounded — rooted, able to assert self; first calling milestone (rank 3)
#   whole    — integrated, self-commanding (rank 4–5)
#
# band_by_standing: data.maturity_expression.band_by_standing from balance.json
static func get_expression_band(rank: int, band_by_standing: Dictionary) -> String:
	var key := str(rank)
	if band_by_standing.has(key):
		return band_by_standing[key]
	# Clamp to highest defined band if rank exceeds table
	return band_by_standing.get("5", "whole")


# ── Presence strength ─────────────────────────────────────────────────────────

# Returns presence_strength (0.0–1.0): how strongly the Echo's state presses
# onto nearby or bonded others. Derived from expression band.
# Higher presence = stronger social spillover, broader leadership radius.
static func get_presence_strength(expression_band: String) -> float:
	match expression_band:
		"nascent":  return 0.1
		"forming":  return 0.25
		"grounded": return 0.5
		"whole":    return 1.0
	return 0.1


# ── Autonomy outputs (V2-PROG-012 Phase 1) ────────────────────────────────────

# Derives the full per-turn maturity-expression + autonomy-output dict for an actor.
# Used by ActorStateMachine to inject the shared seam into augmented context.
# Replaces the separate get_expression_band() / get_calling_behavior() /
# get_rank_strength() call trio that ActorStateMachine used to make.
#
# judgment / presence / composure / legibility (GDD §11.5, §7.3) are pure,
# deterministic, no-RNG floats clamped 0.0-1.0. They are NEVER persisted —
# callers must keep them on the transient combat actor dict only.
#
# Derivation (frozen shape; weights are config-driven — see
# data.maturity_expression.autonomy_outputs):
#   judgment   = rank_strength + storyweight_maturity + identity_coherence
#              + calling_accent_confirmed + bond_support - fear_pressure - instability
#   presence   = rank_strength + archetype_projection + calling_family_projection
#              + bond_density + morale_lift - instability
#   composure  = rank_strength + vow_held + trait_balance
#              - structural_dread - situational_spike - instability
#   legibility = rank_strength + storyweight_maturity + calling_accent_confirmed
#              + identity_coherence - instability
#
# composure reads fear TWICE, deliberately: structural_dread comes from
# fear_base (permanent, earned from combat losses — lowers the ceiling),
# situational_spike comes from fear_current above fear_base (recoverable
# within the encounter). This is a design requirement, not duplication —
# do not collapse it back into a single max(fear_current, fear_base) read
# the way BehaviorArbiter._score() does for its own (different) purpose.
#
# actor: the combat actor dict (EchoActor.from_echo() / EnemyActor.from_definition()
#   shape). Reads: rank, storyweight (falls back to xp_total), vector_scores,
#   calling, calling_origin, archetype_birth, traits, morale, fear, fear_base.
#
# ctx_inputs: small pure dict the caller assembles from context it already holds:
#   {
#     "bonds":            Array,      — bond edges already filtered by the caller
#                                        to this actor + currently-living party members
#     "bond_thresholds":  Dictionary, — data.sanctum.bond_thresholds (rival_max/friend_min)
#     "active_vow":       Dictionary, — VowService.get_active_vow() result, or {}
#     "calling_family":   String,     — "anchor" | "edge" | "sight" | "" — resolved by
#                                        the caller from data.calling.definitions.<id>.family
#     "instability":      float,      — reserved seam; no instability/distortion system
#                                        exists yet. Defaults to 0.0 if absent.
#     "level_thresholds": Array,      — data.progression.level_thresholds, for
#                                        storyweight_maturity normalisation
#   }
#
# expr_cfg: data.maturity_expression from balance.json (must contain autonomy_outputs).
#
# Returns:
#   {
#     "expression_band":  String,     — "nascent" | "forming" | "grounded" | "whole"
#     "judgment":         float,      — 0.0–1.0
#     "presence":         float,      — 0.0–1.0
#     "composure":        float,      — 0.0–1.0
#     "legibility":        float,     — 0.0–1.0
#     "calling_behavior": Dictionary  — per-calling combat personality config
#     "rank_strength":    float,      — 0.0–1.0 continuous rank scalar
#   }
static func derive_expression(actor: Dictionary, ctx_inputs: Dictionary, expr_cfg: Dictionary) -> Dictionary:
	var band_by_standing: Dictionary = expr_cfg.get("band_by_standing", {})
	var calling_cfg: Dictionary      = expr_cfg.get("calling_behavior", {})
	var max_rank: int                = int(expr_cfg.get("rank_strength_scale", {}).get("max_rank", 9))
	var autonomy_cfg: Dictionary     = expr_cfg.get("autonomy_outputs", {})

	var rank: int = int(actor.get("rank", 1))
	var expression_band := get_expression_band(rank, band_by_standing)
	var calling_behavior := get_calling_behavior(actor, calling_cfg)
	var rank_strength := get_rank_strength(rank, max_rank)

	# ── Shared sub-scores (0.0-1.0), each feeding one or more outputs ──
	# actor/ctx_inputs entries are defensively type-checked (not blind `as`
	# casts) — some hand-authored test fixtures across the suite carry
	# placeholder values (e.g. "traits": []) that don't match the real
	# EchoActor/EnemyActor shape. Matches the defensive style already used
	# by VectorService/SocialGraphService for the same reason.
	var storyweight: int = int(actor.get("storyweight", actor.get("xp_total", 0)))
	var level_thresholds: Array = _as_array(ctx_inputs.get("level_thresholds", []))
	var storyweight_maturity := _storyweight_maturity(storyweight, level_thresholds)

	var vector_scores: Dictionary = _as_dict(actor.get("vector_scores", {}))
	var identity_coherence := _identity_coherence(vector_scores)

	var calling_accent_confirmed: float = 1.0 if str(actor.get("calling", "")) != "" else 0.0

	var archetype_cfg: Dictionary = autonomy_cfg.get("archetype_projection", {})
	var archetype_projection := clampf(
		float(archetype_cfg.get(str(actor.get("archetype_birth", "")), 0.0)), 0.0, 1.0)

	var family_cfg: Dictionary = autonomy_cfg.get("calling_family_projection", {})
	var calling_family_projection := clampf(
		float(family_cfg.get(str(ctx_inputs.get("calling_family", "")), 0.0)), 0.0, 1.0)

	var bond_scale_cfg: Dictionary = autonomy_cfg.get("bond_scale", {})
	var bond_thresholds: Dictionary = _as_dict(ctx_inputs.get("bond_thresholds", {}))
	var bonds: Array = _as_array(ctx_inputs.get("bonds", []))
	var bond_stats := _bond_support_and_density(bonds, bond_thresholds, bond_scale_cfg)
	var bond_support: float = bond_stats["support"]
	var bond_density: float = bond_stats["density"]

	var active_vow: Dictionary = _as_dict(ctx_inputs.get("active_vow", {}))
	var vow_held: float = 1.0 if str(active_vow.get("vow_id", "")) != "" else 0.0

	var traits: Dictionary = _as_dict(actor.get("traits", {}))
	var trait_balance: float = clampf(float(traits.get("faith", 0)) / 100.0, 0.0, 1.0)

	var fear_current: float = float(actor.get("fear", 0))
	var fear_base: float    = float(actor.get("fear_base", 0))
	var fear_base_max: float = maxf(1.0, float(autonomy_cfg.get("fear_base_max", 40)))
	var fear_pressure: float      = clampf(maxf(fear_current, fear_base) / 100.0, 0.0, 1.0)
	var structural_dread: float   = clampf(fear_base / fear_base_max, 0.0, 1.0)
	var situational_spike: float  = clampf(maxf(0.0, fear_current - fear_base) / 100.0, 0.0, 1.0)

	var morale_lift: float = clampf(float(actor.get("morale", 50)) / 100.0, 0.0, 1.0)

	var instability: float = float(ctx_inputs.get("instability", 0.0))

	# ── Outputs ──
	var judgment_cfg: Dictionary = autonomy_cfg.get("judgment", {})
	var judgment := clampf(
		rank_strength            * float(judgment_cfg.get("rank_strength_weight", 0.0))
		+ storyweight_maturity   * float(judgment_cfg.get("storyweight_maturity_weight", 0.0))
		+ identity_coherence     * float(judgment_cfg.get("identity_coherence_weight", 0.0))
		+ calling_accent_confirmed * float(judgment_cfg.get("calling_accent_confirmed_weight", 0.0))
		+ bond_support           * float(judgment_cfg.get("bond_support_weight", 0.0))
		- fear_pressure          * float(judgment_cfg.get("fear_pressure_weight", 0.0))
		- instability            * float(judgment_cfg.get("instability_weight", 0.0)),
		0.0, 1.0)

	var presence_cfg: Dictionary = autonomy_cfg.get("presence", {})
	var presence := clampf(
		rank_strength              * float(presence_cfg.get("rank_strength_weight", 0.0))
		+ archetype_projection     * float(presence_cfg.get("archetype_projection_weight", 0.0))
		+ calling_family_projection * float(presence_cfg.get("calling_family_projection_weight", 0.0))
		+ bond_density              * float(presence_cfg.get("bond_density_weight", 0.0))
		+ morale_lift               * float(presence_cfg.get("morale_lift_weight", 0.0))
		- instability               * float(presence_cfg.get("instability_weight", 0.0)),
		0.0, 1.0)

	var composure_cfg: Dictionary = autonomy_cfg.get("composure", {})
	var composure := clampf(
		rank_strength         * float(composure_cfg.get("rank_strength_weight", 0.0))
		+ vow_held            * float(composure_cfg.get("vow_held_weight", 0.0))
		+ trait_balance       * float(composure_cfg.get("trait_balance_weight", 0.0))
		- structural_dread    * float(composure_cfg.get("structural_dread_weight", 0.0))
		- situational_spike   * float(composure_cfg.get("situational_spike_weight", 0.0))
		- instability         * float(composure_cfg.get("instability_weight", 0.0)),
		0.0, 1.0)

	var legibility_cfg: Dictionary = autonomy_cfg.get("legibility", {})
	var legibility := clampf(
		rank_strength              * float(legibility_cfg.get("rank_strength_weight", 0.0))
		+ storyweight_maturity     * float(legibility_cfg.get("storyweight_maturity_weight", 0.0))
		+ calling_accent_confirmed * float(legibility_cfg.get("calling_accent_confirmed_weight", 0.0))
		+ identity_coherence       * float(legibility_cfg.get("identity_coherence_weight", 0.0))
		- instability              * float(legibility_cfg.get("instability_weight", 0.0)),
		0.0, 1.0)

	return {
		"expression_band":  expression_band,
		"judgment":         judgment,
		"presence":         presence,
		"composure":        composure,
		"legibility":       legibility,
		"calling_behavior": calling_behavior,
		"rank_strength":    rank_strength,
	}


# Defensive coercion for values read out of caller-supplied actor/ctx_inputs dicts.
# Some hand-authored actor fixtures across the test suite carry placeholder values
# (e.g. "traits": []) that do not match the real EchoActor/EnemyActor shape — a blind
# `as Dictionary`/`as Array` cast on those throws. Returns {} / [] on any type mismatch.
static func _as_dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}

static func _as_array(v: Variant) -> Array:
	return v if v is Array else []


# Normalises storyweight against data.progression.level_thresholds (last entry = ceiling).
# Returns 0.0 if thresholds are empty or the ceiling is non-positive (no config to normalise against).
static func _storyweight_maturity(storyweight: int, level_thresholds: Array) -> float:
	if level_thresholds.is_empty():
		return 0.0
	var ceiling: float = float(level_thresholds[level_thresholds.size() - 1])
	if ceiling <= 0.0:
		return 0.0
	return clampf(float(storyweight) / ceiling, 0.0, 1.0)


# How peaked the Echo's identity is: normalised margin between the dominant
# vector score and the runner-up, as a fraction of the total. 0.0 = evenly
# spread (no clear identity); 1.0 = fully dominated by a single vector.
# VectorService has no equivalent helper (compute_dominant() only returns a
# hysteresis-gated winner key, not a coherence magnitude) so this is new.
static func _identity_coherence(vector_scores: Dictionary) -> float:
	if vector_scores.is_empty():
		return 0.0
	var top: float = -1.0
	var second: float = -1.0
	var total: float = 0.0
	for key in vector_scores:
		var v: float = float(int(vector_scores[key]))
		total += v
		if v > top:
			second = top
			top = v
		elif v > second:
			second = v
	if total <= 0.0:
		return 0.0
	if second < 0.0:
		second = 0.0
	return clampf((top - second) / total, 0.0, 1.0)


# Sums friend-tier bonds as +1 and rival-tier bonds as -1 (support) / +1 magnitude
# (density), normalised by bond_scale_cfg.max_bonds and clamped.
# bonds: edge dicts already filtered by the caller to this actor + living party members.
static func _bond_support_and_density(bonds: Array, bond_thresholds: Dictionary, bond_scale_cfg: Dictionary) -> Dictionary:
	var max_bonds: float = maxf(1.0, float(bond_scale_cfg.get("max_bonds", 4)))
	var support_sum: float = 0.0
	var density_sum: float = 0.0
	for edge_v in bonds:
		if not (edge_v is Dictionary):
			continue
		var edge: Dictionary = edge_v
		var strength: int = int(edge.get("strength", 0))
		var bond_type: String = SocialGraphService.get_bond_type(strength, bond_thresholds)
		if bond_type == "friend":
			support_sum += 1.0
			density_sum += 1.0
		elif bond_type == "rival":
			support_sum -= 1.0
			density_sum += 1.0
	return {
		"support": clampf(support_sum / max_bonds, -1.0, 1.0),
		"density": clampf(density_sum / max_bonds, 0.0, 1.0),
	}


# ── Rank strength (continuous scalar) ────────────────────────────────────────

# V2-PROG-010: Continuous rank scalar. 0.0 at rank 1 → 1.0 at rank 9.
# max_rank from config (data.maturity_expression.rank_strength_scale.max_rank); defaults to 9.
# Used for all rank-scaled effects: identity weight, composure, fear recovery.
static func get_rank_strength(rank: int, max_rank: int = 9) -> float:
	if max_rank <= 1:
		return 0.0
	return clampf(float(rank - 1) / float(max_rank - 1), 0.0, 1.0)


# ── Sanctum fear recovery bonus ───────────────────────────────────────────────

# V2-PROG-010: Bonus fear reduction applied per sanctum recovery tick.
# Starts at mid_rank_start (default 5), scales with rank_strength.
# Identity-based: calling (confirmed) and dominant_vector each add a small bonus.
# Returns integer bonus to add onto the base fear recovery delta.
static func compute_sanctum_fear_recovery_bonus(echo: Dictionary, cfg_data: Dictionary) -> int:
	var expr_cfg: Dictionary     = cfg_data.get("maturity_expression", {})
	var recovery_cfg: Dictionary = expr_cfg.get("sanctum_fear_recovery_bonus", {})
	var mid_rank:  int = int(recovery_cfg.get("mid_rank_start", 5))
	var bonus_max: int = int(recovery_cfg.get("bonus_max", 4))
	var rank: int = int(echo.get("rank", 1))
	if rank < mid_rank:
		return 0
	var max_rank: int  = int(expr_cfg.get("rank_strength_scale", {}).get("max_rank", 9))
	var rs: float      = get_rank_strength(rank, max_rank)
	var bonus: int     = int(round(float(bonus_max) * rs))
	# Identity contribution — calling confirmed + dominant_vector present
	var call_bonus: int = int(recovery_cfg.get("identity_calling_bonus", 1)) \
		if str(echo.get("calling", "")) != "" else 0
	var vec_bonus: int  = int(recovery_cfg.get("identity_vector_bonus", 1)) \
		if str(echo.get("dominant_vector", "")) != "" else 0
	return clampi(bonus + call_bonus + vec_bonus, 0, bonus_max + 2)


# ── Calling behavior ──────────────────────────────────────────────────────────

# Returns the calling_behavior entry for this actor.
# Prefers actor["calling"] (confirmed identity), falls back to
# actor["calling_origin"] (birth bias). Falls back to "uncalled" config.
#
# calling_cfg: data.maturity_expression.calling_behavior from balance.json
static func get_calling_behavior(actor: Dictionary, calling_cfg: Dictionary) -> Dictionary:
	var calling: String = ""
	if actor.has("calling") and actor["calling"] != "":
		calling = actor["calling"]
	elif actor.has("calling_origin") and actor["calling_origin"] != "":
		calling = actor["calling_origin"]
	if calling_cfg.has(calling):
		return calling_cfg[calling]
	# Fallback: uncalled behavior
	return calling_cfg.get("uncalled", {})

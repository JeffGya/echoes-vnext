# res://core/actors/MaturityExpressionService.gd
# Derives the maturity-expression band and presence strength for an actor.
# Replaces SmartnessTierService (V2-PROG-006).
#
# The maturity-expression layer reflects how internally authored an Echo has
# become — not AI competence tiers. Expression band is derived from Standing
# (rank) and shapes behavior selection, refusal thresholds, social spillover,
# and directive interpretation.
#
# Two outputs (GDD §11.5):
#   expression_band   — how strongly the Echo holds/asserts self under pressure
#   presence_strength — how strongly that state presses onto nearby/bonded others
#
# Rules:
# - Pure static helpers. No state, no side effects.
# - Uses actor["calling"] if present and non-empty (confirmed identity),
#   falls back to actor["calling_origin"] (birth bias).
# - All config reads are from caller-supplied dicts (never loads ConfigService directly).

class_name MaturityExpressionService


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


# ── Full expression dict ──────────────────────────────────────────────────────

# Convenience method: returns the complete expression dict for an actor.
# Used by ActorStateMachine to inject the shared seam into augmented context.
#
# Returns:
#   {
#     "expression_band":    String,     — "nascent" | "forming" | "grounded" | "whole"
#     "presence_strength":  float,      — 0.0–1.0
#     "calling_behavior":   Dictionary  — per-calling combat personality config
#   }
#
# cfg_data: the full data block from balance.json (context.get("cfg", {}).get("data", {}))
static func get_expression(actor: Dictionary, cfg_data: Dictionary) -> Dictionary:
	var expr_cfg: Dictionary = cfg_data.get("maturity_expression", {})
	var band_by_standing: Dictionary = expr_cfg.get("band_by_standing", {})
	var calling_cfg: Dictionary = expr_cfg.get("calling_behavior", {})

	var expression_band := get_expression_band(int(actor.get("rank", 1)), band_by_standing)
	var presence_strength := get_presence_strength(expression_band)
	var calling_behavior := get_calling_behavior(actor, calling_cfg)

	return {
		"expression_band":   expression_band,
		"presence_strength": presence_strength,
		"calling_behavior":  calling_behavior,
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

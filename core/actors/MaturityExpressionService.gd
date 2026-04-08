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

# res://core/actors/SmartnessTierService.gd
# Maps actor rank and calling to smartness tier and calling behavior config.
#
# Rules:
# - Pure static helpers. No state, no side effects.
# - Uses actor["calling"] if present (PROG-007 forward), falls back to actor["calling_origin"].
# - All config reads are from caller-supplied dicts (never loads ConfigService directly).

class_name SmartnessTierService

# Returns "novice" / "adept" / "veteran" / "elite" based on rank.
# tier_by_rank: data.smartness.tier_by_rank from balance.json
static func get_tier(rank: int, tier_by_rank: Dictionary) -> String:
	var key := str(rank)
	if tier_by_rank.has(key):
		return tier_by_rank[key]
	# Clamp to highest defined tier if rank exceeds table
	return tier_by_rank.get("5", "elite")

# Returns the calling_behavior entry for this actor.
# Prefers actor["calling"] (PROG-007), falls back to actor["calling_origin"].
# calling_cfg: data.smartness.calling_behavior from balance.json
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

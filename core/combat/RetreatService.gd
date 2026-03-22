# res://core/combat/RetreatService.gd
# UI-004: Pure static service for retreat eligibility, chance tier, and roll.
#
# Two-step retreat check:
#   1. Speed gate (binary): echo_avg_speed > enemy_avg_speed → attempt allowed.
#   2. Agi tier: agi_delta = echo_avg_agi − enemy_avg_agi → maps to one of 5 chance tiers.
#
# Dead actors (is_dead == true) and structures (is_structure == true) are excluded from all averages.

class_name RetreatService

# ──────────────────────────────────────────
# Public API
# ──────────────────────────────────────────

## Returns true if the echo faction can ATTEMPT a retreat (speed gate).
## Echo avg speed must be strictly greater than enemy avg speed.
## Returns false if either faction has no living non-structure actors.
static func can_attempt(actors: Array) -> bool:
	var echo_actors  := _filter_live_faction(actors, "echo")
	var enemy_actors := _filter_live_faction(actors, "enemy")
	if echo_actors.is_empty() or enemy_actors.is_empty():
		return false
	var echo_speed  := _avg_stat(echo_actors,  "speed")
	var enemy_speed := _avg_stat(enemy_actors, "speed")
	return echo_speed > enemy_speed


## Returns a tier Dictionary { "label": String, "success_pct": int } based on the agi delta.
## tier_cfg is the Array from balance.json data.combat.retreat_agi_tiers.
## Returns {} (empty) when can_attempt() == false or tier_cfg is empty.
## Tier entries must be ordered highest min_delta first. The first entry whose min_delta
## is ≤ agi_delta is selected.
static func get_chance_tier(actors: Array, tier_cfg: Array) -> Dictionary:
	if not can_attempt(actors):
		return {}
	if tier_cfg.is_empty():
		return {}

	var echo_actors  := _filter_live_faction(actors, "echo")
	var enemy_actors := _filter_live_faction(actors, "enemy")
	var agi_delta := _avg_stat(echo_actors, "agi") - _avg_stat(enemy_actors, "agi")

	# Walk tiers (highest min_delta first). First match wins.
	for tier in tier_cfg:
		if tier is Dictionary:
			var min_delta: float = float(tier.get("min_delta", -9999))
			if agi_delta >= min_delta:
				return {
					"label":       str(tier.get("label", "")),
					"success_pct": int(tier.get("success_pct", 0)),
				}

	# Fallback: use last tier if nothing matched (shouldn't happen with -9999 catch-all).
	var last: Dictionary = tier_cfg[tier_cfg.size() - 1]
	return {
		"label":       str(last.get("label", "")),
		"success_pct": int(last.get("success_pct", 0)),
	}


## Executes the retreat roll. Returns { "success": bool }.
## success_pct 100 → always succeeds. 0 → always fails.
## Uses the provided RNG (seeded externally for determinism).
static func roll_retreat(success_pct: int, rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randi_range(0, 99)
	return { "success": roll < success_pct }


# ──────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────

## Returns actors with the given faction that are alive and not structures.
static func _filter_live_faction(actors: Array, faction: String) -> Array:
	var out: Array = []
	for a in actors:
		if not (a is Dictionary):
			continue
		if str(a.get("faction", "")) != faction:
			continue
		if bool(a.get("is_dead", false)):
			continue
		if bool(a.get("is_structure", false)):
			continue
		out.append(a)
	return out


## Returns the average value of stats[stat_key] across the actor list.
## Falls back to 5 per actor if the stat is missing (old save compat).
static func _avg_stat(faction_actors: Array, stat_key: String) -> float:
	if faction_actors.is_empty():
		return 0.0
	var total: float = 0.0
	for a in faction_actors:
		var stats: Dictionary = a.get("stats", {})
		total += float(stats.get(stat_key, 5))
	return total / float(faction_actors.size())

extends RefCounted
## Exposure map for the stage route price (V2-DIRECTIVE-002 design 3b). Pure and static.
## Cell key "col,row" -> exposure 0..1. Sources: known hostile situations (revealed, unresolved,
## not passed) and `explore_map.known_hazards` (empty today). Bridges are NOT sources (D-31).

const AdapterScript := preload("res://core/movement/StagePartyMovementAdapter.gd")

## Category token in `data.stages.situation_category`, not a Directive id.
const HOSTILE_CATEGORY := "combat"


static func cfg_num(cfg: Dictionary, key: String) -> float:
	var v: Variant = cfg.get(key, 0.0)
	return float(v) if v is int or v is float else 0.0


## An absent or empty `exposure_cfg` gives an empty map: no pricing. `exclude_id` leaves out one
## situation as a source (the exposure pause ignores the hostile the party walks to, D-52 F1).
static func build(explore_map: Dictionary, category_map: Dictionary, exposure_cfg: Dictionary, exclude_id: String = "") -> Dictionary:
	var exposure: Dictionary = {}
	var radius := int(cfg_num(exposure_cfg, "hostile_radius"))
	var peak := cfg_num(exposure_cfg, "hostile_peak")
	if radius < 0 or peak <= 0.0:
		return exposure
	var sits_v: Variant = explore_map.get("situations", [])
	for sit_v in (sits_v as Array if sits_v is Array else []):
		var sit: Dictionary = sit_v if sit_v is Dictionary else {}
		if not bool(sit.get("revealed", false)) or bool(sit.get("resolved", false)) or bool(sit.get("passed", false)):
			continue
		if str(category_map.get(str(sit.get("type", "")), "")) != HOSTILE_CATEGORY:
			continue
		if not exclude_id.is_empty() and str(sit.get("id", "")) == exclude_id:
			continue
		_stamp(exposure, sit.get("pos", {}), radius, peak)
	var hazards_v: Variant = explore_map.get("known_hazards", [])
	for hazard in (hazards_v as Array if hazards_v is Array else []):
		_stamp(exposure, hazard, radius, peak)
	return exposure


## Entry cost = 1 + round(exposure * (1 - tolerance) * price_scale). Cells that stay at 1 are omitted,
## so an empty map gives {} and the caller keeps today's plain call.
static func to_terrain_costs(exposure: Dictionary, tolerance: float, price_scale: int) -> Dictionary:
	var costs: Dictionary = {}
	var weight := 1.0 - clampf(tolerance, 0.0, 1.0)
	for key in exposure:
		var cost := 1 + roundi(float(exposure[key]) * weight * float(price_scale))
		if cost > 1:
			costs[key] = cost
	return costs


## A priced route longer than the plain route plus the slack envelope is refused (never a wall).
static func detour_within_slack(priced_len: int, plain_len: int, slack_config: Dictionary) -> bool:
	return priced_len <= plain_len + AdapterScript._slack_envelope(plain_len, slack_config)


static func _stamp(exposure: Dictionary, cell_v: Variant, radius: int, peak: float) -> void:
	var cell: Dictionary = cell_v if cell_v is Dictionary else {}
	if not (cell.get("col") is int or cell.get("col") is float) or not (cell.get("row") is int or cell.get("row") is float):
		return
	var col := int(cell["col"])
	var row := int(cell["row"])
	for dc in range(-radius, radius + 1):
		for dr in range(-radius, radius + 1):
			var d := maxi(absi(dc), absi(dr))
			var value := peak * (1.0 - float(d) / float(radius + 1))
			var key := "%d,%d" % [col + dc, row + dr]
			exposure[key] = maxf(float(exposure.get(key, 0.0)), value)

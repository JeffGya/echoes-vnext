class_name FindsRules
extends RefCounted

## How many finds one won fight offers: the cap by realm scale and the per-slot chance by fight rank.
## Pure statics on `data.inventory` (`ConfigService.get_inventory_cfg`). Reads nothing else, writes nothing.
## Stream: `inventory.finds.<stage_id>.<run_count>.<situation_id>`. It must never share a path with
## `stage.settle.*` or `inventory.leave.*`, so a finds roll cannot move a settlement.

## `cap_for_scale` result when `finds_cap_by_realm_scale` is missing or empty. Only test configs lack the
## key (shipping has it; the `finds_rules` suite runs `ConfigValidator.validate_finds`, which requires it).
## The seam will read it as "no cap" (V2-ITEM-001b C6).
const NO_CAP := -1
## Debug only: "no cap override" for `ActiveStageService.record_found_items` (-1 is NO_CAP, a real answer).
const NO_OVERRIDE := -2
## A realm scale is a float sum of steps. A step such as 0.1 is not exact in binary, so the sum can land a
## hair under a band edge; the tolerance keeps it on that band.
const SCALE_EPS := 0.000001


## The cap of the highest band whose scale is at or below `realm_scale`. A scale below the first band
## uses the first band. NO_CAP when the band list is missing or empty.
static func cap_for_scale(inv_cfg: Dictionary, realm_scale: float) -> int:
	# UNWIRED (target: V2-ITEM-002): the bands above realm.02 (1.75, 2.5, 3.5) are placeholders until realm 3 exists
	var bands_v: Variant = inv_cfg.get("finds_cap_by_realm_scale", null)
	if not (bands_v is Array) or (bands_v as Array).is_empty():
		return NO_CAP
	var bands: Array = bands_v
	var cap := int((bands[0] as Dictionary).get("cap", 0))
	for band in bands:
		if float(band.get("scale", 0.0)) <= realm_scale + SCALE_EPS:
			cap = int(band.get("cap", 0))
	return cap


## Chance in integer percent that find slot `slot_index` (0 = first) hits at fight rank `rank`.
## 0 for a slot past the base list and for a rank with no modifier key (F, a loss, an unknown rank).
static func slot_chance_pct(inv_cfg: Dictionary, slot_index: int, rank: String) -> int:
	var chance := _chance_cfg(inv_cfg)
	var base_v: Variant = chance.get("base_by_slot_pct", [])
	var base: Array = base_v if base_v is Array else []
	if slot_index < 0 or slot_index >= base.size() or not _is_win_rank(inv_cfg, rank):
		return 0
	var mod := int((chance["rank_modifier_pct"] as Dictionary)[rank])
	return clampi(int(base[slot_index]) + mod, 0, int(chance.get("max_pct", 0)))


static func stream_path(stage_id: String, run_count: int, situation_id: String) -> String:
	return "inventory.finds.%s.%d.%s" % [stage_id, run_count, situation_id]


## Number of finds of one won fight. Draws only from its own stream (`stream_path`).
static func roll_count(inv_cfg: Dictionary, realm_seed: int, stage_id: String, run_count: int,
		situation_id: String, realm_scale: float, rank: String) -> int:
	var cap := cap_for_scale(inv_cfg, realm_scale)
	if cap < 1 or not _is_win_rank(inv_cfg, rank):
		return 0
	return roll_count_with(inv_cfg, CampaignSeed.get_rng_from(realm_seed,
		stream_path(stage_id, run_count, situation_id)), cap, rank)


## Exactly `cap` draws of randi_range(0, 99), one per slot, ALL made even after a miss: the draw count
## must never depend on the results, so the stream stays the same length for every outcome.
## Slots are independent (D-50); the count is the number of hits. A non-win rank draws nothing.
static func roll_count_with(inv_cfg: Dictionary, rng: RandomNumberGenerator, cap: int, rank: String) -> int:
	if cap < 1 or not _is_win_rank(inv_cfg, rank):
		return 0
	var hits := 0
	for slot in range(cap):
		if rng.randi_range(0, 99) < slot_chance_pct(inv_cfg, slot, rank):
			hits += 1
	return hits


## True when `rank` is a winning rank (has a chance modifier). A loss rank (F, unknown) has none.
static func is_win_rank(inv_cfg: Dictionary, rank: String) -> bool:
	return _is_win_rank(inv_cfg, rank)


static func _is_win_rank(inv_cfg: Dictionary, rank: String) -> bool:
	var mods_v: Variant = _chance_cfg(inv_cfg).get("rank_modifier_pct", {})
	return mods_v is Dictionary and (mods_v as Dictionary).has(rank)


static func _chance_cfg(inv_cfg: Dictionary) -> Dictionary:
	var chance_v: Variant = inv_cfg.get("finds_chance", {})
	return chance_v if chance_v is Dictionary else {}

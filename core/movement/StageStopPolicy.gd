extends RefCounted
## Stage stop kinds and the journey "why" (V2-DIRECTIVE-002 design 3a, 8). Pure and static, no RNG.
## The six player kinds live here, not in MovementResult.STOP_REASONS (shared with combat).
## spotted_ahead and paused_to_read both ride the result reason "interrupted".

const ExposureScript := preload("res://core/movement/StageExposureMap.gd")

const KINDS: Array = ["arrived_at", "capacity_spent", "interrupted", "spotted_ahead", "paused_to_read", "no_route"]
const CAUSES: Array = ["echo", "terrain", "objective", "situation", "party", "directive"]
const PURPOSES: Array = ["advance", "reposition", "read", "hold"]
const ROUTES: Array = ["direct", "skirted"]
const REASON_CLASSES: Array = ["calling", "temperament", "fear", "morale"]
const WHY_SLOTS: Array = ["cause", "purpose_family", "route_character", "stop_kind", "named_echo_name", "echo_reason_class"]


## Read-only peek at the situations on cells the last fog lift added. They are still unrevealed:
## the post-walk sweep reveals them, so the walk never targets a find it just saw.
## Returns "spotted_ahead", "paused_to_read" or "". `reveal_kinds` switches each kind on (D-52 F2).
## Objective and combat finds are never noise and never a "paused_to_read".
static func classify_reveals(explore_map: Dictionary, new_cell_keys: Array, category_map: Dictionary,
		weights: Dictionary, reveal_kinds: Array, stop_cfg: Dictionary, width: float) -> String:
	if new_cell_keys.is_empty():
		return ""
	var fresh: Dictionary = {}
	for k in new_cell_keys:
		fresh[str(k)] = true
	var noise_width := _num(stop_cfg, "noise_width_min")
	var noise_weight := _num(stop_cfg, "noise_weight_max")
	var pause := false
	for s_v in _arr(explore_map.get("situations", [])):
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if bool(s.get("revealed", false)) or bool(s.get("resolved", false)) or bool(s.get("passed", false)):
			continue
		var pos_v: Variant = s.get("pos", {})
		var pos: Dictionary = pos_v if pos_v is Dictionary else {}
		if not fresh.has("%d,%d" % [int(pos.get("col", 0)), int(pos.get("row", 0))]):
			continue
		var category := "objective" if bool(s.get("is_objective", false)) else str(category_map.get(str(s.get("type", "")), "intel"))
		if category == "objective" or category == ExposureScript.HOSTILE_CATEGORY:
			if reveal_kinds.has("spotted_ahead"):
				return "spotted_ahead"
			continue
		if reveal_kinds.has("paused_to_read") and not (width >= noise_width and float(weights.get(category, 1.0)) < noise_weight):
			pause = true
	return "paused_to_read" if pause else ""


## True when entering a cell of this exposure makes the party stop first (numbers.md section 7).
static func exposure_pause(exposure: float, tolerance: float, stop_willingness: float, pause_trigger: float) -> bool:
	return pause_trigger > 0.0 and exposure * (1.0 - clampf(tolerance, 0.0, 1.0)) * stop_willingness >= pause_trigger


## Player stop kind for the end of a walk. `revealed_kind` (from classify_reveals or exposure_pause)
## wins. Reaching the target situation is "arrived_at" even though the result reason is "interrupted".
static func kind_for(reason: String, revealed_kind: String, at_target: bool) -> String:
	if revealed_kind != "":
		return revealed_kind
	match reason:
		"reached_destination":
			return "arrived_at"
		"interrupted":
			return "arrived_at" if at_target else "interrupted"
		"capacity_spent", "commitment_spent":
			return "capacity_spent"
		"no_route":
			return "no_route"
	return ""


## Allowed slots only; every value a String from its allowed set (the name is free text). No id, no number.
static func sanitise_why(why: Dictionary) -> Dictionary:
	var allowed := {"cause": CAUSES, "purpose_family": PURPOSES, "route_character": ROUTES, "stop_kind": KINDS, "echo_reason_class": REASON_CLASSES}
	var out: Dictionary = {}
	for slot in WHY_SLOTS:
		var v: Variant = why.get(slot, "")
		var text: String = v if v is String else ""
		out[slot] = text if slot == "named_echo_name" or (allowed[slot] as Array).has(text) else ""
	return out


static func _arr(v: Variant) -> Array:
	return v if v is Array else []


static func _num(d: Dictionary, key: String) -> float:
	var v: Variant = d.get(key, 0.0)
	return float(v) if v is int or v is float else 0.0

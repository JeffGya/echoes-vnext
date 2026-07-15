# res://core/realms/SituationResolutionService.gd
# V2-STAGE-004 Phase 1 — Unified situation resolution decision layer.
# Pure-static RefCounted: no side effects, no save_data mutation, no global RNG.
# All randomness injected via a RandomNumberGenerator provided by the caller.
#
# Three entry points:
#   route()             — which track a situation takes (async vs in_explore)
#   resolve_in_explore() — compute in-place outcome (PURE, returns result dict)
#   resolve_choice()     — outcome for a player-picked choice (obstacle/structure)

class_name SituationResolutionService
extends RefCounted


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Situation types resolved asynchronously (hand off to combat board).
# NPC is NOT here — npc resolves in-explore (contact conversation or stub),
# decided inside the in_explore branch by the caller, never a combat handoff.
const _ASYNC_SIT_TYPES: Array = ["combat"]

# Objective types that force the async track regardless of situation type.
# (e.g. a shrine objective lives inside a combat situation — still async.)
# "boss" is defensive: not yet generated as an engageable situation (REALM-002),
# but if it ever is, it must hand off to combat — never resolve in-explore.
const _ASYNC_OBJ_TYPES: Array = ["combat", "shrine", "boss", "recover", "protect", "endure", "pursue", "guide_spirit"]

# Fallback strings used when config is missing.
const _FALLBACK_RESULT_TEXT := "The moment passes without resolution."
const _FALLBACK_CHOICE_TEXT := "The choice leads somewhere uncertain."


# ---------------------------------------------------------------------------
# route
# ---------------------------------------------------------------------------

# Returns "async" or "in_explore".
# "async"      → combat, shrine, recover, protect, endure, pursue — hand off.
# "in_explore" → npc, loot, money, omen, obstacle, ritual, structure.
#
# is_objective=true AND objective type is async → always "async".
# Situation type determines track otherwise.
static func route(sit_type: String, is_objective: bool) -> String:
	if is_objective and (sit_type in _ASYNC_SIT_TYPES or sit_type in _ASYNC_OBJ_TYPES):
		return "async"
	if sit_type in _ASYNC_SIT_TYPES:
		return "async"
	return "in_explore"


# ---------------------------------------------------------------------------
# resolve_in_explore
# ---------------------------------------------------------------------------

# PURE computation — returns a result dict describing the full outcome.
# No mutations. Caller applies side effects.
#
# sit        : SituationModel dict (must have "type", "seed").
# stages_cfg : balance.json data.stages (contains situation_emotion_effects +
#              situation_resolution sub-dicts).
# rng        : caller-owned, seeded RandomNumberGenerator.
#
# Return shape:
# {
#   "panel_kind":   String,   # "acknowledge" | "take" | "leave" | "choice"
#   "result_text":  String,   # "" when panel_kind == "choice"
#   "fear_delta":   int,
#   "morale_delta": int,
#   "ase_delta":    int,
#   "loot_results": Array,    # [{ "kind": String, "seed": int }] for loot; else []
#   "choices":      Array,    # [{ "id": String, "label_key": String }] for "choice"; else []
# }
static func resolve_in_explore(
	sit: Dictionary,
	stages_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var sit_type: String = str(sit.get("type", ""))
	var sit_seed: int    = int(sit.get("seed", 0))

	# -- Pull sub-configs (guard with is Dictionary) --
	var emotion_map_v: Variant = stages_cfg.get("situation_emotion_effects", {})
	var emotion_map: Dictionary = emotion_map_v if emotion_map_v is Dictionary else {}

	var res_map_v: Variant = stages_cfg.get("situation_resolution", {})
	var res_map: Dictionary = res_map_v if res_map_v is Dictionary else {}

	# Type-specific resolution config.
	var type_cfg_v: Variant = res_map.get(sit_type, {})
	var type_cfg: Dictionary = type_cfg_v if type_cfg_v is Dictionary else {}

	# panel_kind
	var panel_kind: String = str(type_cfg.get("panel_kind", "acknowledge"))

	# -- result_text: derive index from situation seed (stable regardless of rng draw order) --
	var result_text: String = ""
	if panel_kind != "choice":
		var texts_v: Variant = type_cfg.get("result_text", [])
		var texts: Array = texts_v if texts_v is Array else []
		if texts.size() > 0:
			var idx: int = absi(sit_seed) % texts.size()
			result_text = str(texts[idx])
		else:
			result_text = _FALLBACK_RESULT_TEXT

	# -- fear_delta / morale_delta: 0 for "choice" panel_kind (emotion comes from resolve_choice) --
	var fear_delta: int   = 0
	var morale_delta: int = 0
	if panel_kind != "choice":
		var emotion_v: Variant = emotion_map.get(sit_type, {})
		var emotion: Dictionary = emotion_v if emotion_v is Dictionary else {}
		fear_delta   = int(emotion.get("fear_delta",   0))
		morale_delta = int(emotion.get("morale_delta", 0))

	# -- ase_delta: money type only --
	var ase_delta: int = 0
	if sit_type == "money" and panel_kind == "take":
		var money_cfg_v: Variant = type_cfg.get("money", {})
		var money_cfg: Dictionary = money_cfg_v if money_cfg_v is Dictionary else {}
		var ase_min: int = int(money_cfg.get("ase_min", 0))
		var ase_max: int = int(money_cfg.get("ase_max", ase_min))
		var range_val: int = maxi(0, ase_max - ase_min)
		ase_delta = ase_min + (rng.randi() % (range_val + 1)) if range_val > 0 else ase_min

	# -- loot_results: loot type only --
	var loot_results: Array = []
	if sit_type == "loot":
		var loot_cfg_v: Variant = type_cfg.get("loot", {})
		var loot_cfg: Dictionary = loot_cfg_v if loot_cfg_v is Dictionary else {}
		var kinds_v: Variant = loot_cfg.get("kinds", [])
		var kinds: Array = kinds_v if kinds_v is Array else []
		if kinds.size() > 0:
			var kind_idx: int = rng.randi() % kinds.size()
			var picked_kind: String = str(kinds[kind_idx])
			var loot_seed: int = rng.randi()
			loot_results.append({ "kind": picked_kind, "seed": loot_seed })

	# -- choices: "choice" panel_kind only --
	var choices: Array = []
	if panel_kind == "choice":
		var raw_choices_v: Variant = type_cfg.get("choices", [])
		var raw_choices: Array = raw_choices_v if raw_choices_v is Array else []
		for entry_v in raw_choices:
			if not (entry_v is Dictionary):
				continue
			var entry: Dictionary = entry_v as Dictionary
			var c_id_v: Variant = entry.get("id", "")
			var c_label_v: Variant = entry.get("label_key", "")
			choices.append({
				"id":        str(c_id_v),
				"label_key": str(c_label_v),
			})

	return {
		"panel_kind":   panel_kind,
		"result_text":  result_text,
		"fear_delta":   fear_delta,
		"morale_delta": morale_delta,
		"ase_delta":    ase_delta,
		"loot_results": loot_results,
		"choices":      choices,
	}


# ---------------------------------------------------------------------------
# resolve_choice
# ---------------------------------------------------------------------------

# PURE computation — outcome for a player-picked choice (obstacle/structure).
# No mutations. Caller applies side effects.
#
# Returns: { "result_text": String, "fear_delta": int, "morale_delta": int, "turn_cost": int }
static func resolve_choice(
	sit: Dictionary,
	choice_id: String,
	stages_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var sit_type: String = str(sit.get("type", ""))

	var res_map_v: Variant = stages_cfg.get("situation_resolution", {})
	var res_map: Dictionary = res_map_v if res_map_v is Dictionary else {}

	var type_cfg_v: Variant = res_map.get(sit_type, {})
	var type_cfg: Dictionary = type_cfg_v if type_cfg_v is Dictionary else {}

	# Find matching choice entry by id.
	var raw_choices_v: Variant = type_cfg.get("choices", [])
	var raw_choices: Array = raw_choices_v if raw_choices_v is Array else []

	var matched_choice: Dictionary = {}
	for entry_v in raw_choices:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v as Dictionary
		if str(entry.get("id", "")) == choice_id:
			matched_choice = entry
			break

	# result_text: from result_text_by_choice[choice_id].
	var result_text: String = _FALLBACK_CHOICE_TEXT
	var text_map_v: Variant = type_cfg.get("result_text_by_choice", {})
	var text_map: Dictionary = text_map_v if text_map_v is Dictionary else {}
	var mapped_text_v: Variant = text_map.get(choice_id, "")
	var mapped_text: String = str(mapped_text_v)
	if mapped_text != "":
		result_text = mapped_text

	if matched_choice.is_empty():
		# Unknown choice_id — return safe zeros.
		return {
			"result_text":  result_text,
			"fear_delta":   0,
			"morale_delta": 0,
			"turn_cost":    0,
		}

	var fear_delta: int   = int(matched_choice.get("fear_delta",   0))
	var morale_delta: int = int(matched_choice.get("morale_delta", 0))
	var turn_cost: int    = int(matched_choice.get("turn_cost",    0))

	# rng is available for future use (e.g. probabilistic outcomes per choice).
	# Currently unused — suppress warning by referencing it.
	var _rng_ref := rng

	return {
		"result_text":  result_text,
		"fear_delta":   fear_delta,
		"morale_delta": morale_delta,
		"turn_cost":    turn_cost,
	}

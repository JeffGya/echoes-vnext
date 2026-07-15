# res://tests/SituationResolutionServiceTests.gd
# V2-STAGE-004 Phase 1 — Tests for SituationResolutionService (pure-static).
#
# Tests:
#   1.  sit_res/route_async_types          — all async sit types return "async"
#   2.  sit_res/route_in_explore_types     — all in_explore types return "in_explore"
#   3.  sit_res/route_npc_not_objective    — route("npc", false) == "in_explore"
#   4.  sit_res/route_recover_objective    — route("recover", true) == "async"
#   5.  sit_res/resolve_omen              — panel=acknowledge, fear+2, morale-3, no loot/choices
#   6.  sit_res/resolve_ritual            — panel=leave, fear-4, morale+4
#   7.  sit_res/resolve_loot              — panel=take, loot size 1, kind in config, ase 0
#   8.  sit_res/resolve_money             — panel=take, ase in [8,20]
#   9.  sit_res/resolve_obstacle_choice   — panel=choice, text "", fear 0, morale 0, 2 choices with id+label_key
#   10. sit_res/resolve_structure_choice  — panel=choice, 2 choices with correct ids
#   11. sit_res/choice_obstacle_push      — resolve_choice push_through → morale -6, turn 0, non-empty text
#   12. sit_res/choice_obstacle_find      — resolve_choice find_route → turn_cost 1
#   13. sit_res/choice_structure_enter    — resolve_choice enter → fear +3, morale +6
#   14. sit_res/choice_structure_observe  — resolve_choice observe → fear -2, morale +2
#   15. sit_res/choice_unknown_id         — resolve_choice "nope" → zeros, non-empty fallback text
#   16. sit_res/determinism_result_text   — same seed → same result_text (run twice)
#   17. sit_res/determinism_money_ase     — two RNGs with identical seed → same ase_delta

extends RefCounted
class_name SituationResolutionServiceTests


# ─── Inline stages_cfg fixture ───────────────────────────────────────────────
# Mirror the frozen schema so tests are isolated from tuning changes.

static func _make_stages_cfg() -> Dictionary:
	return {
		"situation_emotion_effects": {
			"loot":      { "fear_delta": -5, "morale_delta":  0 },
			"money":     { "fear_delta": -3, "morale_delta":  5 },
			"npc":       { "fear_delta":  0, "morale_delta":  8 },
			"omen":      { "fear_delta":  2, "morale_delta": -3 },
			"ritual":    { "fear_delta": -4, "morale_delta":  4 },
			"obstacle":  { "fear_delta":  0, "morale_delta":  0 },
			"structure": { "fear_delta":  0, "morale_delta":  0 },
		},
		"situation_resolution": {
			"omen": {
				"panel_kind":  "acknowledge",
				"result_text": ["A shadow passes through the air.", "The ground trembles, then stills."],
			},
			"ritual": {
				"panel_kind":  "leave",
				"result_text": ["You step away from the old rite.", "The ceremony ends where you begin."],
			},
			"loot": {
				"panel_kind":  "take",
				"result_text": ["You find something useful.", "A fragment left behind."],
				"loot": {
					"kinds": ["relic", "herb", "shard"],
				},
			},
			"money": {
				"panel_kind":  "take",
				"result_text": ["An offering remains here.", "Coin and ash."],
				"money": {
					"ase_min": 8,
					"ase_max": 20,
				},
			},
			"npc": {
				"panel_kind":  "acknowledge",
				"result_text": ["A figure stands quietly.", "Eyes find you from the distance."],
			},
			"obstacle": {
				"panel_kind": "choice",
				"result_text_by_choice": {
					"push_through": "You force a path through.",
					"find_route":   "A longer way reveals itself.",
				},
				"choices": [
					{ "id": "push_through", "label_key": "obstacle.push_through", "fear_delta": 0, "morale_delta": -6, "turn_cost": 0 },
					{ "id": "find_route",   "label_key": "obstacle.find_route",   "fear_delta": 0, "morale_delta":  0, "turn_cost": 1 },
				],
			},
			"structure": {
				"panel_kind": "choice",
				"result_text_by_choice": {
					"enter":   "You step inside and feel the weight of old memory.",
					"observe": "You watch from the threshold — safer, but distant.",
				},
				"choices": [
					{ "id": "enter",   "label_key": "structure.enter",   "fear_delta":  3, "morale_delta":  6, "turn_cost": 0 },
					{ "id": "observe", "label_key": "structure.observe", "fear_delta": -2, "morale_delta":  2, "turn_cost": 0 },
				],
			},
		},
	}


# Build a minimal SituationModel-compatible dict inline (no preload needed).
static func _make_sit(sit_type: String, seed_val: int = 1001) -> Dictionary:
	return {
		"id":              "sit.test",
		"type":            sit_type,
		"pos":             { "col": 5, "row": 5 },
		"seed":            seed_val,
		"revealed":        false,
		"is_objective":    false,
		"resolved":        false,
		"intel_clues":     [],
		"objective_index": -1,
		"role":            "",
	}


static func _make_rng(seed_val: int = 123) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


# ─── Registration ─────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("sit_res/route_async_types",         Callable(SituationResolutionServiceTests, "_t_route_async_types"))
	runner.register_test("sit_res/route_in_explore_types",    Callable(SituationResolutionServiceTests, "_t_route_in_explore_types"))
	runner.register_test("sit_res/route_npc_not_objective",   Callable(SituationResolutionServiceTests, "_t_route_npc_not_objective"))
	runner.register_test("sit_res/route_recover_objective",   Callable(SituationResolutionServiceTests, "_t_route_recover_objective"))
	runner.register_test("sit_res/route_guide_spirit_objective", Callable(SituationResolutionServiceTests, "_t_route_guide_spirit_objective"))
	runner.register_test("sit_res/resolve_omen",              Callable(SituationResolutionServiceTests, "_t_resolve_omen"))
	runner.register_test("sit_res/resolve_ritual",            Callable(SituationResolutionServiceTests, "_t_resolve_ritual"))
	runner.register_test("sit_res/resolve_loot",              Callable(SituationResolutionServiceTests, "_t_resolve_loot"))
	runner.register_test("sit_res/resolve_money",             Callable(SituationResolutionServiceTests, "_t_resolve_money"))
	runner.register_test("sit_res/resolve_obstacle_choice",   Callable(SituationResolutionServiceTests, "_t_resolve_obstacle_choice"))
	runner.register_test("sit_res/resolve_structure_choice",  Callable(SituationResolutionServiceTests, "_t_resolve_structure_choice"))
	runner.register_test("sit_res/choice_obstacle_push",      Callable(SituationResolutionServiceTests, "_t_choice_obstacle_push"))
	runner.register_test("sit_res/choice_obstacle_find",      Callable(SituationResolutionServiceTests, "_t_choice_obstacle_find"))
	runner.register_test("sit_res/choice_structure_enter",    Callable(SituationResolutionServiceTests, "_t_choice_structure_enter"))
	runner.register_test("sit_res/choice_structure_observe",  Callable(SituationResolutionServiceTests, "_t_choice_structure_observe"))
	runner.register_test("sit_res/choice_unknown_id",         Callable(SituationResolutionServiceTests, "_t_choice_unknown_id"))
	runner.register_test("sit_res/determinism_result_text",   Callable(SituationResolutionServiceTests, "_t_determinism_result_text"))
	runner.register_test("sit_res/determinism_money_ase",     Callable(SituationResolutionServiceTests, "_t_determinism_money_ase"))


# ─── Test 1 — route() async types all return "async" ─────────────────────────
# "combat" is async regardless of is_objective.
# "shrine","recover","protect","endure","pursue","guide_spirit" are async only when is_objective=true.
static func _t_route_async_types() -> Dictionary:
	# combat always async
	var result_combat := SituationResolutionService.route("combat", false)
	if result_combat != "async":
		return { "ok": false, "error": "route('combat', false) expected 'async', got '%s'" % result_combat }

	# objective-only async types — must be objective to trigger async
	var obj_async_types := ["shrine", "recover", "protect", "endure", "pursue", "guide_spirit"]
	for t in obj_async_types:
		var r := SituationResolutionService.route(t, true)
		if r != "async":
			return { "ok": false, "error": "route('%s', true) expected 'async', got '%s'" % [t, r] }

	return { "ok": true }


# ─── Test 2 — route() in_explore types all return "in_explore" ───────────────
static func _t_route_in_explore_types() -> Dictionary:
	var in_explore_types := ["npc", "loot", "money", "omen", "obstacle", "ritual", "structure"]
	for t in in_explore_types:
		var result := SituationResolutionService.route(t, false)
		if result != "in_explore":
			return { "ok": false, "error": "route('%s', false) expected 'in_explore', got '%s'" % [t, result] }
	return { "ok": true }


# ─── Test 3 — route("npc", false) == "in_explore" ────────────────────────────
static func _t_route_npc_not_objective() -> Dictionary:
	var result := SituationResolutionService.route("npc", false)
	if result != "in_explore":
		return { "ok": false, "error": "route('npc', false) expected 'in_explore', got '%s'" % result }
	return { "ok": true }


# ─── Test 4 — route("recover", true) == "async" ──────────────────────────────
static func _t_route_recover_objective() -> Dictionary:
	var result := SituationResolutionService.route("recover", true)
	if result != "async":
		return { "ok": false, "error": "route('recover', true) expected 'async', got '%s'" % result }
	return { "ok": true }


# ─── Test 4b — route("guide_spirit", true) == "async" ────────────────────────
# V2-STAGE-004 Phase 4 fix: guide_spirit objective must hand off to combat
# (FlowEncounterState / GUIDE_SPIRIT mode), never resolve as in-explore flavor
# text — otherwise stage.objectives[idx].completed can never flip true and
# the player soft-locks (cta.proceed_to_stage_map never renders).
static func _t_route_guide_spirit_objective() -> Dictionary:
	var result := SituationResolutionService.route("guide_spirit", true)
	if result != "async":
		return { "ok": false, "error": "route('guide_spirit', true) expected 'async', got '%s'" % result }
	return { "ok": true }


# ─── Test 5 — resolve_in_explore omen ────────────────────────────────────────
static func _t_resolve_omen() -> Dictionary:
	var cfg  := _make_stages_cfg()
	var sit  := _make_sit("omen", 1001)
	var rng  := _make_rng(42)
	var out  := SituationResolutionService.resolve_in_explore(sit, cfg, rng)

	if str(out.get("panel_kind", "")) != "acknowledge":
		return { "ok": false, "error": "omen: expected panel_kind 'acknowledge', got '%s'" % out.get("panel_kind", "") }
	if str(out.get("result_text", "")) == "":
		return { "ok": false, "error": "omen: result_text should be non-empty" }
	if int(out.get("fear_delta", 0)) != 2:
		return { "ok": false, "error": "omen: expected fear_delta 2, got %d" % out.get("fear_delta", 0) }
	if int(out.get("morale_delta", 0)) != -3:
		return { "ok": false, "error": "omen: expected morale_delta -3, got %d" % out.get("morale_delta", 0) }
	if int(out.get("ase_delta", 0)) != 0:
		return { "ok": false, "error": "omen: expected ase_delta 0, got %d" % out.get("ase_delta", 0) }
	var loot_v: Variant = out.get("loot_results", [])
	var loot: Array = loot_v if loot_v is Array else []
	if loot.size() != 0:
		return { "ok": false, "error": "omen: expected loot_results empty, got size %d" % loot.size() }
	var choices_v: Variant = out.get("choices", [])
	var choices: Array = choices_v if choices_v is Array else []
	if choices.size() != 0:
		return { "ok": false, "error": "omen: expected choices empty, got size %d" % choices.size() }
	return { "ok": true }


# ─── Test 6 — resolve_in_explore ritual ──────────────────────────────────────
static func _t_resolve_ritual() -> Dictionary:
	var cfg  := _make_stages_cfg()
	var sit  := _make_sit("ritual", 2002)
	var rng  := _make_rng(42)
	var out  := SituationResolutionService.resolve_in_explore(sit, cfg, rng)

	if str(out.get("panel_kind", "")) != "leave":
		return { "ok": false, "error": "ritual: expected panel_kind 'leave', got '%s'" % out.get("panel_kind", "") }
	if int(out.get("fear_delta", 0)) != -4:
		return { "ok": false, "error": "ritual: expected fear_delta -4, got %d" % out.get("fear_delta", 0) }
	if int(out.get("morale_delta", 0)) != 4:
		return { "ok": false, "error": "ritual: expected morale_delta 4, got %d" % out.get("morale_delta", 0) }
	return { "ok": true }


# ─── Test 7 — resolve_in_explore loot ────────────────────────────────────────
static func _t_resolve_loot() -> Dictionary:
	var cfg   := _make_stages_cfg()
	var sit   := _make_sit("loot", 3003)
	var rng   := _make_rng(42)
	var out   := SituationResolutionService.resolve_in_explore(sit, cfg, rng)
	var valid_kinds := ["relic", "herb", "shard"]

	if str(out.get("panel_kind", "")) != "take":
		return { "ok": false, "error": "loot: expected panel_kind 'take', got '%s'" % out.get("panel_kind", "") }
	if int(out.get("ase_delta", 0)) != 0:
		return { "ok": false, "error": "loot: expected ase_delta 0, got %d" % out.get("ase_delta", 0) }

	var loot_v: Variant = out.get("loot_results", [])
	var loot: Array = loot_v if loot_v is Array else []
	if loot.size() != 1:
		return { "ok": false, "error": "loot: expected loot_results size 1, got %d" % loot.size() }

	var loot_entry_v: Variant = loot[0]
	var loot_entry: Dictionary = loot_entry_v if loot_entry_v is Dictionary else {}
	var picked_kind := str(loot_entry.get("kind", ""))
	if not (picked_kind in valid_kinds):
		return { "ok": false, "error": "loot: picked kind '%s' not in valid kinds" % picked_kind }

	return { "ok": true }


# ─── Test 8 — resolve_in_explore money ───────────────────────────────────────
static func _t_resolve_money() -> Dictionary:
	var cfg := _make_stages_cfg()
	var sit := _make_sit("money", 4004)
	var rng := _make_rng(42)
	var out := SituationResolutionService.resolve_in_explore(sit, cfg, rng)

	if str(out.get("panel_kind", "")) != "take":
		return { "ok": false, "error": "money: expected panel_kind 'take', got '%s'" % out.get("panel_kind", "") }

	var ase := int(out.get("ase_delta", -1))
	if ase < 8 or ase > 20:
		return { "ok": false, "error": "money: ase_delta %d not in [8, 20]" % ase }

	return { "ok": true }


# ─── Test 9 — resolve_in_explore obstacle → choice panel ─────────────────────
static func _t_resolve_obstacle_choice() -> Dictionary:
	var cfg := _make_stages_cfg()
	var sit := _make_sit("obstacle", 5005)
	var rng := _make_rng(42)
	var out := SituationResolutionService.resolve_in_explore(sit, cfg, rng)

	if str(out.get("panel_kind", "")) != "choice":
		return { "ok": false, "error": "obstacle: expected panel_kind 'choice', got '%s'" % out.get("panel_kind", "") }
	if str(out.get("result_text", "NONEMPTY")) != "":
		return { "ok": false, "error": "obstacle: result_text should be '' for choice panel, got '%s'" % out.get("result_text", "") }
	if int(out.get("fear_delta", 99)) != 0:
		return { "ok": false, "error": "obstacle: expected fear_delta 0, got %d" % out.get("fear_delta", 0) }
	if int(out.get("morale_delta", 99)) != 0:
		return { "ok": false, "error": "obstacle: expected morale_delta 0, got %d" % out.get("morale_delta", 0) }

	var choices_v: Variant = out.get("choices", [])
	var choices: Array = choices_v if choices_v is Array else []
	if choices.size() != 2:
		return { "ok": false, "error": "obstacle: expected 2 choices, got %d" % choices.size() }

	var expected_ids := ["push_through", "find_route"]
	for c_v in choices:
		var c: Dictionary = c_v if c_v is Dictionary else {}
		var c_id := str(c.get("id", ""))
		if not (c_id in expected_ids):
			return { "ok": false, "error": "obstacle: unexpected choice id '%s'" % c_id }
		if not c.has("label_key"):
			return { "ok": false, "error": "obstacle: choice missing label_key (id=%s)" % c_id }
		# Confirm delta fields NOT leaked into choices array
		if c.has("fear_delta") or c.has("morale_delta") or c.has("turn_cost"):
			return { "ok": false, "error": "obstacle: choice should not contain delta fields (id=%s)" % c_id }

	return { "ok": true }


# ─── Test 10 — resolve_in_explore structure → choice panel ───────────────────
static func _t_resolve_structure_choice() -> Dictionary:
	var cfg := _make_stages_cfg()
	var sit := _make_sit("structure", 6006)
	var rng := _make_rng(42)
	var out := SituationResolutionService.resolve_in_explore(sit, cfg, rng)

	if str(out.get("panel_kind", "")) != "choice":
		return { "ok": false, "error": "structure: expected panel_kind 'choice', got '%s'" % out.get("panel_kind", "") }

	var choices_v: Variant = out.get("choices", [])
	var choices: Array = choices_v if choices_v is Array else []
	if choices.size() != 2:
		return { "ok": false, "error": "structure: expected 2 choices, got %d" % choices.size() }

	var expected_ids := ["enter", "observe"]
	for c_v in choices:
		var c: Dictionary = c_v if c_v is Dictionary else {}
		var c_id := str(c.get("id", ""))
		if not (c_id in expected_ids):
			return { "ok": false, "error": "structure: unexpected choice id '%s'" % c_id }

	return { "ok": true }


# ─── Test 11 — resolve_choice obstacle push_through ──────────────────────────
static func _t_choice_obstacle_push() -> Dictionary:
	var cfg := _make_stages_cfg()
	var sit := _make_sit("obstacle", 5005)
	var rng := _make_rng(42)
	var out := SituationResolutionService.resolve_choice(sit, "push_through", cfg, rng)

	if int(out.get("morale_delta", 0)) != -6:
		return { "ok": false, "error": "push_through: expected morale_delta -6, got %d" % out.get("morale_delta", 0) }
	if int(out.get("turn_cost", 99)) != 0:
		return { "ok": false, "error": "push_through: expected turn_cost 0, got %d" % out.get("turn_cost", 0) }
	if str(out.get("result_text", "")) == "":
		return { "ok": false, "error": "push_through: result_text should be non-empty" }

	return { "ok": true }


# ─── Test 12 — resolve_choice obstacle find_route ────────────────────────────
static func _t_choice_obstacle_find() -> Dictionary:
	var cfg := _make_stages_cfg()
	var sit := _make_sit("obstacle", 5005)
	var rng := _make_rng(42)
	var out := SituationResolutionService.resolve_choice(sit, "find_route", cfg, rng)

	if int(out.get("turn_cost", 0)) != 1:
		return { "ok": false, "error": "find_route: expected turn_cost 1, got %d" % out.get("turn_cost", 0) }

	return { "ok": true }


# ─── Test 13 — resolve_choice structure enter ────────────────────────────────
static func _t_choice_structure_enter() -> Dictionary:
	var cfg := _make_stages_cfg()
	var sit := _make_sit("structure", 6006)
	var rng := _make_rng(42)
	var out := SituationResolutionService.resolve_choice(sit, "enter", cfg, rng)

	if int(out.get("fear_delta", 0)) != 3:
		return { "ok": false, "error": "structure enter: expected fear_delta 3, got %d" % out.get("fear_delta", 0) }
	if int(out.get("morale_delta", 0)) != 6:
		return { "ok": false, "error": "structure enter: expected morale_delta 6, got %d" % out.get("morale_delta", 0) }

	return { "ok": true }


# ─── Test 14 — resolve_choice structure observe ──────────────────────────────
static func _t_choice_structure_observe() -> Dictionary:
	var cfg := _make_stages_cfg()
	var sit := _make_sit("structure", 6006)
	var rng := _make_rng(42)
	var out := SituationResolutionService.resolve_choice(sit, "observe", cfg, rng)

	if int(out.get("fear_delta", 0)) != -2:
		return { "ok": false, "error": "structure observe: expected fear_delta -2, got %d" % out.get("fear_delta", 0) }
	if int(out.get("morale_delta", 0)) != 2:
		return { "ok": false, "error": "structure observe: expected morale_delta 2, got %d" % out.get("morale_delta", 0) }

	return { "ok": true }


# ─── Test 15 — resolve_choice unknown id → safe zeros + non-empty fallback ───
static func _t_choice_unknown_id() -> Dictionary:
	var cfg := _make_stages_cfg()
	var sit := _make_sit("obstacle", 5005)
	var rng := _make_rng(42)
	var out := SituationResolutionService.resolve_choice(sit, "nope", cfg, rng)

	if int(out.get("fear_delta", 99)) != 0:
		return { "ok": false, "error": "unknown id: expected fear_delta 0, got %d" % out.get("fear_delta", 0) }
	if int(out.get("morale_delta", 99)) != 0:
		return { "ok": false, "error": "unknown id: expected morale_delta 0, got %d" % out.get("morale_delta", 0) }
	if int(out.get("turn_cost", 99)) != 0:
		return { "ok": false, "error": "unknown id: expected turn_cost 0, got %d" % out.get("turn_cost", 0) }
	if str(out.get("result_text", "")) == "":
		return { "ok": false, "error": "unknown id: result_text (fallback) should be non-empty" }

	return { "ok": true }


# ─── Test 16 — DETERMINISM: same seed → same result_text ─────────────────────
static func _t_determinism_result_text() -> Dictionary:
	var cfg  := _make_stages_cfg()
	var sit  := _make_sit("omen", 7777)
	var rng1 := _make_rng(99)
	var rng2 := _make_rng(99)

	var out1 := SituationResolutionService.resolve_in_explore(sit, cfg, rng1)
	var out2 := SituationResolutionService.resolve_in_explore(sit, cfg, rng2)

	var text1 := str(out1.get("result_text", ""))
	var text2 := str(out2.get("result_text", ""))
	if text1 != text2:
		return { "ok": false, "error": "Determinism failure: result_text '%s' != '%s'" % [text1, text2] }

	return { "ok": true }


# ─── Test 17 — DETERMINISM: identical RNG seeds → same money ase_delta ────────
static func _t_determinism_money_ase() -> Dictionary:
	var cfg  := _make_stages_cfg()
	var sit  := _make_sit("money", 8888)
	var r1   := RandomNumberGenerator.new()
	r1.seed  = 123
	var r2   := RandomNumberGenerator.new()
	r2.seed  = 123

	var out1 := SituationResolutionService.resolve_in_explore(sit, cfg, r1)
	var out2 := SituationResolutionService.resolve_in_explore(sit, cfg, r2)

	var ase1 := int(out1.get("ase_delta", -1))
	var ase2 := int(out2.get("ase_delta", -1))
	if ase1 != ase2:
		return { "ok": false, "error": "Determinism failure: ase_delta %d != %d" % [ase1, ase2] }

	return { "ok": true }

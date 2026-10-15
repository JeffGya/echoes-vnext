# res://tests/ContactConfigLiteralTests.gd
# V2-DIRECTIVE-002 S4a: contact literals now read config. Each test checks that the shipped value
# equals the old literal and that changing the key in a runtime copy changes the behaviour.
# Filter: `tests contact_cfg`.

extends RefCounted
class_name ContactConfigLiteralTests

const ContactModelScript := preload("res://core/realms/ContactModel.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("contact_cfg/shipped_values_equal_old_literals", Callable(ContactConfigLiteralTests, "_t_shipped"))
	runner.register_test("contact_cfg/npc_fear_gate", Callable(ContactConfigLiteralTests, "_t_fear_gate"))
	runner.register_test("contact_cfg/npc_score_bonuses_and_morale_limit", Callable(ContactConfigLiteralTests, "_t_bonuses"))
	runner.register_test("contact_cfg/turn_count_modifiers", Callable(ContactConfigLiteralTests, "_t_turn_count"))
	runner.register_test("contact_cfg/reactive_threshold_both_places", Callable(ContactConfigLiteralTests, "_t_reactive"))
	runner.register_test("contact_cfg/voices_cap_and_party_size", Callable(ContactConfigLiteralTests, "_t_voices_and_party"))


static func _fail(msg: String) -> Dictionary:
	return { "ok": false, "error": msg }


# Runtime copy of the shipped config; data/balance.json is never edited.
static func _cfg(overrides: Dictionary = {}) -> ConfigService:
	var cs := ConfigService.new()
	cs.load_balance()
	_apply(cs, overrides)
	return cs


# overrides: "dot.path.under.data" -> value
static func _apply(cs: ConfigService, overrides: Dictionary) -> void:
	for path: String in overrides:
		var keys := path.split(".")
		var node: Dictionary = cs._balance["data"]
		for i in range(keys.size() - 1):
			node = node[keys[i]]
		node[keys[keys.size() - 1]] = overrides[path]


static func _fit(cs: ConfigService, disposition: String, fear: int, morale: int, status: String, role: String = "") -> float:
	var cfg: Dictionary = cs.get_balance()["data"]["contact"]
	return ConversationService._compute_emotional_fit(disposition, fear, morale, status, cfg, role)


static func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


static func _t_shipped() -> Dictionary:
	var cs := _cfg()
	var fit := ConfigService.get_contact_emotional_fit_cfg(cs)
	if int(fit.get("high_fear_npc_min", -1)) != 60 or not _near(float(fit.get("high_fear_broken_charge_bonus", -1)), 0.2) \
			or int(fit.get("low_morale_npc_max", -1)) != 20 or not _near(float(fit.get("low_morale_broken_bonus", -1)), 0.1):
		return _fail("emotional_fit_modifiers differ from the old literals")
	var tc := ConfigService.get_contact_turn_count_cfg(cs)
	if int(tc.get("npc_fear_above", -1)) != 60 or int(tc.get("npc_morale_below", -1)) != 30:
		return _fail("turn_count_modifiers differ from the old literals")
	if int(ConfigService.get_contact_bid_cfg(cs).get("reactive_fear_min", -1)) != 60:
		return _fail("bid.reactive_fear_min differs from the old literal")
	if ConfigService.get_contact_max_voices_per_turn(cs, 99) != 3 or ConfigService.get_party_max_size(cs, 99) != 5:
		return _fail("voices cap or party max size differs from the old literal")
	return { "ok": true }


# wary + grounded status: 0.2 disposition fit, plus 0.1 grounding bonus when the NPC is frightened.
static func _t_fear_gate() -> Dictionary:
	var base := _cfg()
	if not _near(_fit(base, "wary", 60, 50, "grounded"), 0.3) or not _near(_fit(base, "wary", 59, 50, "grounded"), 0.2):
		return _fail("default gate is not >= 60")
	var raised := _cfg({ "contact.emotional_fit_modifiers.high_fear_npc_min": 70 })
	if not _near(_fit(raised, "wary", 60, 50, "grounded"), 0.2):
		return _fail("raising high_fear_npc_min to 70 did not close the gate at fear 60")
	return { "ok": true }


static func _t_bonuses() -> Dictionary:
	var base := _cfg()
	# bold + hollow = -0.1; frightened charge NPC adds the broken-charge bonus (0.2).
	if not _near(_fit(base, "bold", 60, 50, "hollow", "charge"), 0.1):
		return _fail("default broken-charge bonus is not 0.2")
	var b1 := _cfg({ "contact.emotional_fit_modifiers.high_fear_broken_charge_bonus": 0.5 })
	if not _near(_fit(b1, "bold", 60, 50, "hollow", "charge"), 0.4):
		return _fail("high_fear_broken_charge_bonus did not move the score")
	# wary + hollow has no disposition fit; low morale adds 0.1.
	if not _near(_fit(base, "wary", 50, 20, "hollow"), 0.1) or not _near(_fit(base, "wary", 50, 21, "hollow"), 0.0):
		return _fail("default morale limit is not <= 20")
	var m1 := _cfg({ "contact.emotional_fit_modifiers.low_morale_npc_max": 30 })
	if not _near(_fit(m1, "wary", 50, 21, "hollow"), 0.1):
		return _fail("low_morale_npc_max did not move the limit")
	var m2 := _cfg({ "contact.emotional_fit_modifiers.low_morale_broken_bonus": 0.4 })
	if not _near(_fit(m2, "wary", 50, 20, "hollow"), 0.4):
		return _fail("low_morale_broken_bonus did not move the score")
	return { "ok": true }


static func _make_env(contact_fear: int, contact_morale: int, echo_fears: Array) -> Dictionary:
	var contact := ContactModelScript.make("contact.cc", "witness", "courage", "wisdom", contact_fear, contact_morale, "bold", "Nana Adwoa", 2)
	var save := ConversationRepairTests._make_save_with_contact_situation(contact)
	var roster: Array = []
	var ids: Array = []
	for i in range(echo_fears.size()):
		var e := ConversationRepairTests._make_echo("echo.c%d" % i)
		e["emotion"]["fear_current"] = int(echo_fears[i])
		roster.append(e)
		ids.append(e["id"])
	save["sanctum"]["roster"] = roster
	save["sanctum"]["active_party_ids"] = ids
	return { "runtime": ConversationRepairTests._make_runtime(save, ConversationRepairTests._make_logger("off")) }


# Engages with a config override and returns { snap, contact, responses }.
static func _engage(contact_fear: int, contact_morale: int, echo_fears: Array, overrides: Dictionary) -> Dictionary:
	var bak := ConversationRepairTests._capture_save()
	var runtime: FlowRuntime = _make_env(contact_fear, contact_morale, echo_fears)["runtime"]
	_apply(runtime.flow_ctx.config_service, overrides)
	var snap: Dictionary = runtime.dispatch({ "type": "stage.engage_situation", "situation_id": "sit.t1" })
	var stage: Dictionary = FlowStageExploreState._get_current_stage(runtime.flow_ctx)
	var em: Dictionary = stage.get("explore_map", {})
	ConversationRepairTests._restore_save(bak)
	return { "snap": snap, "contact": em.get("pending_contact", {}), "responses": em.get("contact_responses", []), "runtime": runtime }


static func _t_turn_count() -> Dictionary:
	var tc := func(f: int, m: int, o: Dictionary) -> int:
		return int(_engage(f, m, [5], o)["contact"].get("turn_count", -1))
	if tc.call(61, 68, {}) != 1 or tc.call(60, 68, {}) != 2:
		return _fail("default fear modifier is not > 60")
	if tc.call(61, 68, { "contact.turn_count_modifiers.npc_fear_above": 70 }) != 2:
		return _fail("npc_fear_above did not move the limit")
	if tc.call(24, 29, {}) != 3 or tc.call(24, 30, {}) != 2:
		return _fail("default morale modifier is not < 30")
	if tc.call(24, 29, { "contact.turn_count_modifiers.npc_morale_below": 20 }) != 2:
		return _fail("npc_morale_below did not move the limit")
	return { "ok": true }


static func _bids(r: Dictionary) -> Array:
	var sim := str((r["responses"][0] as Dictionary).get("bid_type", "?")) if (r["responses"] as Array).size() == 1 else "?"
	var cards: Array = r["snap"].get("data", {}).get("contact_echo_bids", [])
	var card := str((cards[0] as Dictionary).get("bid_type", "?")) if cards.size() == 1 else "?"
	return [sim, card]


static func _t_reactive() -> Dictionary:
	if _bids(_engage(24, 68, [60], {})) != ["reactive", "reactive"]:
		return _fail("default reactive bid at fear 60 is wrong: %s" % [_bids(_engage(24, 68, [60], {}))])
	if _bids(_engage(24, 68, [59], {})) != ["", ""]:
		return _fail("fear 59 must not bid reactive")
	var raised := _engage(24, 68, [60], { "contact.bid.reactive_fear_min": 70 })
	if _bids(raised) != ["", ""]:
		return _fail("reactive_fear_min 70 must move simulation and card together: %s" % [_bids(raised)])
	return { "ok": true }


static func _t_voices_and_party() -> Dictionary:
	# Three Echoes: auto-responses at cap 3, none at cap 2.
	if (_engage(24, 68, [5, 5, 5], {})["responses"] as Array).size() != 3:
		return _fail("cap 3 must auto-respond for 3 Echoes")
	if not (_engage(24, 68, [5, 5, 5], { "contact.max_voices_per_turn": 2 })["responses"] as Array).is_empty():
		return _fail("cap 2 must not auto-respond for 3 Echoes")
	# Consult trim: four Echoes, all four ids sent.
	var ids := ["echo.c0", "echo.c1", "echo.c2", "echo.c3"]
	for pair in [[{}, 3], [{ "contact.max_voices_per_turn": 2 }, 2]]:
		var bak := ConversationRepairTests._capture_save()
		var runtime: FlowRuntime = _make_env(24, 68, [5, 5, 5, 5])["runtime"]
		_apply(runtime.flow_ctx.config_service, pair[0])
		runtime.dispatch({ "type": "stage.engage_situation", "situation_id": "sit.t1" })
		runtime.dispatch({ "type": "stage.consult_echoes", "echo_ids": ids })
		var em: Dictionary = FlowStageExploreState._get_current_stage(runtime.flow_ctx).get("explore_map", {})
		var got: int = (em.get("pending_contact", {}).get("consulted_ids_this_turn", []) as Array).size()
		ConversationRepairTests._restore_save(bak)
		if got != int(pair[1]):
			return _fail("consult trim: expected %d voices, got %d" % [int(pair[1]), got])
	# Party preview size.
	var wide := _engage(24, 68, [5, 5, 5, 5, 5, 5], {})["snap"].get("data", {}).get("party_preview", []) as Array
	var narrow := _engage(24, 68, [5, 5, 5, 5, 5, 5], { "sanctum.party_max_size": 2 })["snap"].get("data", {}).get("party_preview", []) as Array
	if wide.size() != 5 or narrow.size() != 2:
		return _fail("party_preview size: expected 5 and 2, got %d and %d" % [wide.size(), narrow.size()])
	return { "ok": true }

extends RefCounted
class_name CombatObjectiveLabelTests

## Confirms the pre-battle modal label (_format_objective_label) and the live
## ObjectiveBanner's static instruction text (_objective_instruction_text, the shared
## source both surfaces call) cannot diverge — the divergence this test exists to catch
## already shipped unnoticed once.

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat_ui/objective_instruction_text_combat", Callable(CombatObjectiveLabelTests, "_t_instruction_combat"))
	runner.register_test("combat_ui/objective_instruction_text_purify_shrine", Callable(CombatObjectiveLabelTests, "_t_instruction_purify_shrine"))
	runner.register_test("combat_ui/objective_instruction_text_pursue", Callable(CombatObjectiveLabelTests, "_t_instruction_pursue"))
	runner.register_test("combat_ui/objective_instruction_text_recover", Callable(CombatObjectiveLabelTests, "_t_instruction_recover"))
	runner.register_test("combat_ui/objective_instruction_text_endure", Callable(CombatObjectiveLabelTests, "_t_instruction_endure"))
	runner.register_test("combat_ui/objective_instruction_text_protect_with_name", Callable(CombatObjectiveLabelTests, "_t_instruction_protect_with_name"))
	runner.register_test("combat_ui/objective_instruction_text_protect_fallback", Callable(CombatObjectiveLabelTests, "_t_instruction_protect_fallback"))
	runner.register_test("combat_ui/objective_instruction_text_guide_spirit_escort_with_name", Callable(CombatObjectiveLabelTests, "_t_instruction_guide_spirit_escort_with_name"))
	runner.register_test("combat_ui/objective_instruction_text_guide_spirit_protect_with_name", Callable(CombatObjectiveLabelTests, "_t_instruction_guide_spirit_protect_with_name"))
	runner.register_test("combat_ui/objective_instruction_text_guide_spirit_fallback", Callable(CombatObjectiveLabelTests, "_t_instruction_guide_spirit_fallback"))
	runner.register_test("combat_ui/format_objective_label_matches_shared_text_all_modes", Callable(CombatObjectiveLabelTests, "_t_format_label_matches_shared_text_all_modes"))


static func _check(actual: String, expected: String, label: String) -> Dictionary:
	if actual != expected:
		return { "ok": false, "error": "%s: expected \"%s\", got \"%s\"" % [label, expected, actual] }
	return { "ok": true }


static func _t_instruction_combat() -> Dictionary:
	return _check(
		CombatBoardScreen._objective_instruction_text("combat", {}),
		"Defeat all enemies",
		"combat"
	)


static func _t_instruction_purify_shrine() -> Dictionary:
	return _check(
		CombatBoardScreen._objective_instruction_text("purify_shrine", {}),
		"Purify the shrine",
		"purify_shrine"
	)


static func _t_instruction_pursue() -> Dictionary:
	return _check(
		CombatBoardScreen._objective_instruction_text("pursue", {}),
		"Contain the quarry",
		"pursue"
	)


static func _t_instruction_recover() -> Dictionary:
	return _check(
		CombatBoardScreen._objective_instruction_text("recover", {}),
		"Hold the relic ground",
		"recover"
	)


static func _t_instruction_endure() -> Dictionary:
	return _check(
		CombatBoardScreen._objective_instruction_text("endure", {}),
		"Survive the onslaught",
		"endure"
	)


static func _t_instruction_protect_with_name() -> Dictionary:
	return _check(
		CombatBoardScreen._objective_instruction_text("protect", { "entity_name": "Kwame" }),
		"Protect Kwame",
		"protect with name"
	)


static func _t_instruction_protect_fallback() -> Dictionary:
	return _check(
		CombatBoardScreen._objective_instruction_text("protect", { "entity_name": "" }),
		"Protect the totem",
		"protect fallback"
	)


static func _t_instruction_guide_spirit_escort_with_name() -> Dictionary:
	return _check(
		CombatBoardScreen._objective_instruction_text("guide_spirit", {
			"guide_mode": "escort",
			"spirit_name": "Ama",
		}),
		"Guide Ama to safety",
		"guide_spirit escort with name"
	)


static func _t_instruction_guide_spirit_protect_with_name() -> Dictionary:
	return _check(
		CombatBoardScreen._objective_instruction_text("guide_spirit", {
			"guide_mode": "protect",
			"spirit_name": "Ama",
		}),
		"Keep Ama calm",
		"guide_spirit protect with name"
	)


static func _t_instruction_guide_spirit_fallback() -> Dictionary:
	var escort_result := _check(
		CombatBoardScreen._objective_instruction_text("guide_spirit", {
			"guide_mode": "escort",
			"spirit_name": "",
		}),
		"Guide the spirit to safety",
		"guide_spirit escort fallback"
	)
	if not bool(escort_result.get("ok", false)):
		return escort_result
	return _check(
		CombatBoardScreen._objective_instruction_text("guide_spirit", {
			"guide_mode": "protect",
			"spirit_name": "",
		}),
		"Keep the spirit calm",
		"guide_spirit protect fallback"
	)


## The strongest form of the divergence guard: _format_objective_label (the pre-battle
## modal's builder) must equal _objective_instruction_text (the source the live banner
## also calls) for every mode, including the name/fallback branches. Since both are pure
## static string logic with no Node/scene access, this runs headless with no scene tree.
static func _t_format_label_matches_shared_text_all_modes() -> Dictionary:
	var cases: Array[Dictionary] = [
		{ "type": "combat" },
		{ "type": "purify_shrine" },
		{ "type": "pursue" },
		{ "type": "recover" },
		{ "type": "endure" },
		{ "type": "protect", "entity_name": "Kwame" },
		{ "type": "protect", "entity_name": "" },
		{ "type": "guide_spirit", "guide_mode": "escort", "spirit_name": "Ama" },
		{ "type": "guide_spirit", "guide_mode": "protect", "spirit_name": "Ama" },
		{ "type": "guide_spirit", "guide_mode": "escort", "spirit_name": "" },
		{ "type": "guide_spirit", "guide_mode": "protect", "spirit_name": "" },
	]

	for obj_state in cases:
		var obj_type: String = str(obj_state.get("type", ""))
		var modal_text: String = CombatBoardScreen._format_objective_label(obj_state)
		var shared_text: String = CombatBoardScreen._objective_instruction_text(obj_type, obj_state)
		if modal_text != shared_text:
			return {
				"ok": false,
				"error": "Divergence for %s: modal=\"%s\" shared=\"%s\"" % [obj_state, modal_text, shared_text],
			}

	return { "ok": true }

# res://tests/MovementSlice2ContractTests.gd
# V2-COMBAT-002 Slice 2: exact dormant planning contract validation.

class_name MovementSlice2ContractTests
extends RefCounted

const ActionPlan = preload("res://core/movement/contracts/MovementActionPlan.gd")
const ActorFact = preload("res://core/movement/contracts/MovementPerceivedActorFact.gd")
const HazardFact = preload("res://core/movement/contracts/MovementKnownHazardFact.gd")
const PressureSnapshot = preload("res://core/movement/contracts/CombatPressureSnapshot.gd")
const ContextContract = preload("res://core/movement/contracts/MovementContext.gd")
const GoalContract = preload("res://core/movement/contracts/MovementGoal.gd")
const OptionContract = preload("res://core/movement/contracts/MovementOption.gd")
const IntentContract = preload("res://core/movement/contracts/MovementIntent.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("movement/slice2_contracts/action_plan_exact_and_legacy", Callable(MovementSlice2ContractTests, "_t_action_plan_exact_and_legacy"))
	runner.register_test("movement/slice2_contracts/actor_fact_truth", Callable(MovementSlice2ContractTests, "_t_actor_fact_truth"))
	runner.register_test("movement/slice2_contracts/hazard_fact_exact", Callable(MovementSlice2ContractTests, "_t_hazard_fact_exact"))
	runner.register_test("movement/slice2_contracts/pressure_snapshot_modes", Callable(MovementSlice2ContractTests, "_t_pressure_snapshot_modes"))
	runner.register_test("movement/slice2_contracts/pressure_unknown_and_roles", Callable(MovementSlice2ContractTests, "_t_pressure_unknown_and_roles"))
	runner.register_test("movement/slice2_contracts/context_fact_correlation", Callable(MovementSlice2ContractTests, "_t_context_fact_correlation"))
	runner.register_test("movement/slice2_contracts/context_map_failures", Callable(MovementSlice2ContractTests, "_t_context_map_failures"))
	runner.register_test("movement/slice2_contracts/goal_exact", Callable(MovementSlice2ContractTests, "_t_goal_exact"))
	runner.register_test("movement/slice2_contracts/option_exact", Callable(MovementSlice2ContractTests, "_t_option_exact"))
	runner.register_test("movement/slice2_contracts/intent_exact", Callable(MovementSlice2ContractTests, "_t_intent_exact"))
	runner.register_test("movement/slice2_contracts/reversed_input_stable", Callable(MovementSlice2ContractTests, "_t_reversed_input_stable"))
	runner.register_test("movement/slice2_contracts/required_fields", Callable(MovementSlice2ContractTests, "_t_required_fields"))


static func _t_action_plan_exact_and_legacy() -> Dictionary:
	var metadata := {"skill_id": "skill.path", "candidate": {"rank": 2}}
	var candidate := {
		"action_type": "actor.move",
		"target_id": "objective.relic",
		"payload": metadata,
		"skill_family": "path",
	}
	var plan: Dictionary = ActionPlan.from_legacy_candidate(candidate)
	var expected := {
		"type": "actor.move",
		"target_id": "objective.relic",
		"payload": {
			"skill_id": "skill.path",
			"candidate": {"rank": 2},
			"skill_family": "path",
		},
	}
	if plan != expected:
		return _fail("legacy candidate did not canonicalize exactly: %s" % str(plan))
	var result: Dictionary = ActionPlan.validate(plan)
	if not bool(result["valid"]):
		return _fail("valid action plan rejected: %s" % str(result))
	(metadata["candidate"] as Dictionary)["rank"] = 9
	if int(((plan["payload"] as Dictionary)["candidate"] as Dictionary)["rank"]) != 2:
		return _fail("action plan retained nested payload alias")
	var extra: Dictionary = plan.duplicate(true)
	extra["label"] = "UI field"
	if not _matches(ActionPlan.validate(extra), "unexpected_field", "label"):
		return _fail("action plan accepted undocumented field")
	if bool(ActionPlan.validate({})["valid"]):
		return _fail("empty primary action plan accepted")
	return _pass()


static func _t_actor_fact_truth() -> Dictionary:
	var fact: Dictionary = _actor("echo.1", {"col": 1, "row": 1}, "echo", true)
	if not bool(ActorFact.validate(fact)["valid"]):
		return _fail("valid actor fact rejected")
	var dead_control: Dictionary = fact.duplicate(true)
	dead_control["is_dead"] = true
	if not _matches(ActorFact.validate(dead_control), "incapable_actor_cannot_control", "controlling_state"):
		return _fail("dead controlling actor fact accepted")
	var structure_kind: Dictionary = fact.duplicate(true)
	structure_kind["is_structure"] = true
	if not _matches(ActorFact.validate(structure_kind), "kind_structure_mismatch", "kind"):
		return _fail("structure flag/kind mismatch accepted")
	var bad_health: Dictionary = fact.duplicate(true)
	bad_health["health_ratio"] = 1.01
	if not _matches(ActorFact.validate(bad_health), "number_out_of_range", "health_ratio"):
		return _fail("actor health outside unit interval accepted")
	bad_health["health_ratio"] = NAN
	if not _matches(ActorFact.validate(bad_health), "non_finite_number", "health_ratio"):
		return _fail("actor accepted non-finite health")
	return _pass()


static func _t_hazard_fact_exact() -> Dictionary:
	var position := {"col": 2, "row": 2}
	var hazard: Dictionary = HazardFact.build("hazard.binding.1", position, "binding")
	position["col"] = 9
	if int((hazard["position"] as Dictionary)["col"]) != 2:
		return _fail("hazard retained position alias")
	if not bool(HazardFact.validate(hazard)["valid"]):
		return _fail("valid known hazard rejected")
	var invalid: Dictionary = hazard.duplicate(true)
	invalid["hazard_type"] = "Binding Growth"
	if not _matches(HazardFact.validate(invalid), "invalid_semantic_token", "hazard_type"):
		return _fail("invalid hazard semantic token accepted")
	return _pass()


static func _t_pressure_snapshot_modes() -> Dictionary:
	for mode_value: Variant in PressureSnapshot.MODES:
		var mode: String = str(mode_value)
		var pressure: Dictionary = _pressure(mode)
		if mode == "guide_spirit":
			pressure["guide_mode"] = "protect"
		var result: Dictionary = PressureSnapshot.validate(pressure)
		if not bool(result["valid"]):
			return _fail("valid pressure mode %s rejected: %s" % [mode, str(result)])
	var outside_guide: Dictionary = _pressure("recover")
	outside_guide["guide_mode"] = "escort"
	if not _matches(PressureSnapshot.validate(outside_guide), "guide_mode_outside_guide", "guide_mode"):
		return _fail("guide_mode accepted outside GUIDE")
	return _pass()


static func _t_pressure_unknown_and_roles() -> Dictionary:
	var unknown: Dictionary = _pressure("purify_shrine")
	unknown["objective_known"] = false
	unknown["objective_position"] = {}
	unknown["destination_region"] = []
	unknown["approach_region"] = []
	unknown["fallback_region"] = []
	unknown["search_region"] = [{"col": 5, "row": 5}]
	if not bool(PressureSnapshot.validate(unknown)["valid"]):
		return _fail("truthful unknown-objective pressure rejected")
	unknown["destination_region"] = [{"col": 4, "row": 4}]
	if not _matches(PressureSnapshot.validate(unknown), "unknown_objective_has_region", "destination_region"):
		return _fail("unknown objective accepted destination region")
	var missing_holder: Dictionary = _pressure("recover")
	missing_holder["holder_id"] = ""
	if not _matches(PressureSnapshot.validate(missing_holder), "factual_role_id_missing", "holder_id"):
		return _fail("holder factual role accepted without holder ID")
	var wrong_health_name: Dictionary = _pressure("recover")
	wrong_health_name.erase("objective_health_ratio")
	wrong_health_name["health_ratio"] = 0.5
	if not _matches(PressureSnapshot.validate(wrong_health_name), "missing_field", "objective_health_ratio"):
		return _fail("root pressure health alias accepted")
	var non_finite: Dictionary = _pressure("recover")
	non_finite["objective_health_ratio"] = NAN
	if not _matches(PressureSnapshot.validate(non_finite), "non_finite_number", "objective_health_ratio"):
		return _fail("pressure accepted non-finite objective health")
	var forbidden_gap: Dictionary = _pressure("recover")
	forbidden_gap["objective_health_ratio"] = -0.5
	if not _matches(PressureSnapshot.validate(forbidden_gap), "invalid_unavailable_ratio", "objective_health_ratio"):
		return _fail("pressure accepted objective health between unavailable and zero")
	for allowed_ratio: float in [-1.0, 0.0, 1.0]:
		var boundary: Dictionary = _pressure("recover")
		boundary["objective_health_ratio"] = allowed_ratio
		if not bool(PressureSnapshot.validate(boundary)["valid"]):
			return _fail("pressure rejected allowed objective health boundary %s" % str(allowed_ratio))
	return _pass()


static func _t_context_fact_correlation() -> Dictionary:
	var context: Dictionary = _context()
	var result: Dictionary = ContextContract.validate(context)
	if not bool(result["valid"]):
		return _fail("valid exact movement context rejected: %s" % str(result))
	var original_actor: Dictionary = _actor("echo.copy", {"col": 4, "row": 4}, "echo", false)
	var built: Dictionary = ContextContract.build(
		"echo.copy", "activation.copy", {"col": 4, "row": 4}, {"w": 6, "h": 6},
		{"4,4": true}, {"4,4": true}, {"4,4": "echo.copy"}, [original_actor],
		{}, {"4,4": 1}, [], {}, []
	)
	original_actor["id"] = "mutated"
	var built_fact: Dictionary = (built["perceived_actors"] as Array)[0] as Dictionary
	if str(built_fact["id"]) != "echo.copy" or built_fact.keys().size() != ActorFact.REQUIRED_FIELDS.size():
		return _fail("exact actor fact was not deep-copied intact")
	return _pass()


static func _t_context_map_failures() -> Dictionary:
	var bad_key: Dictionary = _context()
	bad_key["terrain_costs"] = {"01,1": 1}
	if not _matches(ContextContract.validate(bad_key), "invalid_cell_key", "terrain_costs.01,1"):
		return _fail("alternate decimal cell key accepted")
	var mismatch: Dictionary = _context()
	mismatch["occupancy"] = {"2,2": "enemy.1"}
	if not _matches(ContextContract.validate(mismatch), "occupancy_position_mismatch", "occupancy.2,2"):
		return _fail("occupancy/fact position mismatch accepted")
	var unknown_relation: Dictionary = _context()
	unknown_relation["relationships"] = {"hidden.enemy": "hostile"}
	if not _matches(ContextContract.validate(unknown_relation), "unknown_actor_id", "relationships.hidden.enemy"):
		return _fail("relationship to hidden actor accepted")
	var duplicate: Dictionary = _context()
	(duplicate["perceived_actors"] as Array).append((duplicate["perceived_actors"] as Array)[0])
	if not _matches(ContextContract.validate(duplicate), "duplicate_actor_id", "perceived_actors"):
		return _fail("duplicate perceived actor ID accepted")
	var duplicate_reversed: Dictionary = duplicate.duplicate(true)
	(duplicate_reversed["perceived_actors"] as Array).reverse()
	if ContextContract.validate(duplicate) != ContextContract.validate(duplicate_reversed):
		return _fail("reversing duplicate perceived actors changed validation")
	var malformed_actors_a: Dictionary = _context()
	var actor_without_position: Dictionary = _actor("echo.bad_a", {"col": 4, "row": 4}, "echo", false)
	actor_without_position.erase("position")
	var actor_without_kind: Dictionary = _actor("echo.bad_b", {"col": 5, "row": 5}, "echo", false)
	actor_without_kind.erase("kind")
	malformed_actors_a["perceived_actors"] = [actor_without_position, actor_without_kind]
	var malformed_actors_b: Dictionary = malformed_actors_a.duplicate(true)
	(malformed_actors_b["perceived_actors"] as Array).reverse()
	if ContextContract.validate(malformed_actors_a) != ContextContract.validate(malformed_actors_b):
		return _fail("reversing malformed perceived actors changed validation")
	var malformed_actor_insertion: Dictionary = malformed_actors_a.duplicate(true)
	malformed_actor_insertion["perceived_actors"] = [_reverse_dictionary_insertion(actor_without_position)]
	var malformed_actor_single: Dictionary = malformed_actors_a.duplicate(true)
	malformed_actor_single["perceived_actors"] = [actor_without_position]
	if ContextContract.validate(malformed_actor_single) != ContextContract.validate(malformed_actor_insertion):
		return _fail("reversing malformed actor field insertion changed validation")
	var duplicate_hazards_a: Dictionary = _context()
	(duplicate_hazards_a["known_hazards"] as Array).append((duplicate_hazards_a["known_hazards"] as Array)[0])
	var duplicate_hazards_b: Dictionary = duplicate_hazards_a.duplicate(true)
	(duplicate_hazards_b["known_hazards"] as Array).reverse()
	if ContextContract.validate(duplicate_hazards_a) != ContextContract.validate(duplicate_hazards_b):
		return _fail("reversing duplicate hazards changed validation")
	var malformed_hazards_a: Dictionary = _context()
	var hazard_without_position: Dictionary = HazardFact.build("hazard.bad_a", {"col": 4, "row": 4}, "binding")
	hazard_without_position.erase("position")
	var hazard_without_type: Dictionary = HazardFact.build("hazard.bad_b", {"col": 5, "row": 5}, "binding")
	hazard_without_type.erase("hazard_type")
	malformed_hazards_a["known_hazards"] = [hazard_without_position, hazard_without_type]
	var malformed_hazards_b: Dictionary = malformed_hazards_a.duplicate(true)
	(malformed_hazards_b["known_hazards"] as Array).reverse()
	if ContextContract.validate(malformed_hazards_a) != ContextContract.validate(malformed_hazards_b):
		return _fail("reversing malformed hazards changed validation")
	var malformed_hazard_insertion: Dictionary = malformed_hazards_a.duplicate(true)
	malformed_hazard_insertion["known_hazards"] = [_reverse_dictionary_insertion(hazard_without_position)]
	var malformed_hazard_single: Dictionary = malformed_hazards_a.duplicate(true)
	malformed_hazard_single["known_hazards"] = [hazard_without_position]
	if ContextContract.validate(malformed_hazard_single) != ContextContract.validate(malformed_hazard_insertion):
		return _fail("reversing malformed hazard field insertion changed validation")
	return _pass()


static func _t_goal_exact() -> Dictionary:
	var region: Array = [{"col": 4, "row": 2}, {"col": 2, "row": 4}, {"col": 4, "row": 2}]
	var goal: Dictionary = GoalContract.build(
		"goal.recover.hold.holder.c2r4", "hold", region, 0.75, 0.5,
		["echo.2", "echo.1", "echo.2"], ["role.holder", "mode.recover"],
		_action("actor.guard"), _action("actor.idle")
	)
	if goal["destination_region"] != [{"col": 2, "row": 4}, {"col": 4, "row": 2}]:
		return _fail("goal region not canonical col/row sorted unique")
	if goal["relevant_actors"] != ["echo.1", "echo.2"]:
		return _fail("goal relevant actors not sorted unique")
	var origin := {"col": 1, "row": 1}
	if not bool(GoalContract.validate(goal, origin)["valid"]):
		return _fail("valid exact goal rejected")
	var empty_primary: Dictionary = goal.duplicate(true)
	empty_primary["planned_primary"] = {}
	var empty_result: Dictionary = GoalContract.validate(empty_primary, origin)
	if not str(empty_result["reason"]).begins_with("invalid_action_plan."):
		return _fail("goal accepted empty primary")
	var bad_purpose: Dictionary = goal.duplicate(true)
	bad_purpose["purpose"] = "carry"
	if not _matches(GoalContract.validate(bad_purpose, origin), "invalid_purpose", "purpose"):
		return _fail("unfrozen goal purpose accepted")
	var advance_at_origin: Dictionary = GoalContract.build(
		"goal.combat.advance.baseline.c1r1", "advance", [origin], 0.5, 0.0, [],
		["mode.combat"], _action("actor.move"), _action("actor.idle")
	)
	if not _matches(
		GoalContract.validate(advance_at_origin, origin),
		"goal_region_contains_origin",
		"destination_region"
	):
		return _fail("non-hold goal accepted mover origin in destination region")
	var hold_at_origin: Dictionary = GoalContract.build(
		"goal.combat.hold.baseline.c1r1", "hold", [origin], 0.5, 0.0, [],
		["mode.combat"], _action("actor.guard"), _action("actor.idle")
	)
	if not bool(GoalContract.validate(hold_at_origin, origin)["valid"]):
		return _fail("truthful hold rejected mover origin in destination region")
	var invalid_origin_result: Dictionary = GoalContract.validate(
		goal,
		{"col": 1, "row": 1, "label": "not canonical"}
	)
	if not _matches(invalid_origin_result, "invalid_position", "mover_origin"):
		return _fail("goal validator accepted non-canonical mover origin")
	for purpose_value: Variant in GoalContract.PURPOSES:
		var purpose: String = str(purpose_value)
		var purpose_goal: Dictionary = _goal_for_purpose(purpose)
		if not bool(GoalContract.validate(purpose_goal, origin)["valid"]):
			return _fail("valid %s goal plan rejected: %s" % [purpose, str(GoalContract.validate(purpose_goal, origin))])
		var wrong_plan: Dictionary = purpose_goal.duplicate(true)
		(wrong_plan["planned_primary"] as Dictionary)["type"] = "actor.refuse"
		if not _matches(GoalContract.validate(wrong_plan, origin), "invalid_primary_for_purpose", "planned_primary.type"):
			return _fail("%s goal accepted wrong primary plan" % purpose)
		var wrong_target: Dictionary = purpose_goal.duplicate(true)
		(wrong_target["planned_primary"] as Dictionary)["target_id"] = "unlisted.actor"
		if not _matches(GoalContract.validate(wrong_target, origin), "invalid_primary_target", "planned_primary.target_id"):
			return _fail("%s goal accepted wrong primary target" % purpose)
	var primary_metadata: Dictionary = {
		"candidate": {"skill_id": "skill.guardian_interpose", "family": "guardian"},
	}
	var primary_with_metadata: Dictionary = _action("actor.guard")
	primary_with_metadata["payload"] = primary_metadata
	var payload_goal: Dictionary = GoalContract.build(
		"goal.combat.hold.holder.c2r1", "hold", [{"col": 2, "row": 1}], 0.5, 0.5,
		["target.1"], ["mode.combat", "role.holder"], primary_with_metadata,
		_action("actor.idle")
	)
	if not bool(GoalContract.validate(payload_goal, origin)["valid"]):
		return _fail("goal rejected nonempty primary candidate metadata")
	(primary_metadata["candidate"] as Dictionary)["skill_id"] = "mutated"
	if str((((payload_goal["planned_primary"] as Dictionary)["payload"] as Dictionary)["candidate"] as Dictionary)["skill_id"]) != "skill.guardian_interpose":
		return _fail("goal retained nested primary metadata alias")
	var invalid_mode: Dictionary = _goal_for_purpose("hold")
	invalid_mode["goal_id"] = "goal.unknown.hold.holder.c2r1"
	if not _matches(GoalContract.validate(invalid_mode, origin), "invalid_goal_mode", "goal_id"):
		return _fail("goal accepted unknown mode in ID")
	var mismatched_purpose: Dictionary = _goal_for_purpose("hold")
	mismatched_purpose["goal_id"] = "goal.combat.advance.holder.c2r1"
	if not _matches(GoalContract.validate(mismatched_purpose, origin), "goal_id_purpose_mismatch", "goal_id"):
		return _fail("goal accepted mismatched purpose in ID")
	var invalid_role: Dictionary = _goal_for_purpose("hold")
	invalid_role["goal_id"] = "goal.combat.hold.unknown.c2r1"
	if not _matches(GoalContract.validate(invalid_role, origin), "invalid_goal_role", "goal_id"):
		return _fail("goal accepted unknown role in ID")
	var malformed_anchor: Dictionary = _goal_for_purpose("hold")
	malformed_anchor["goal_id"] = "goal.combat.hold.holder.c02r1"
	if not _matches(GoalContract.validate(malformed_anchor, origin), "invalid_goal_anchor", "goal_id"):
		return _fail("goal accepted noncanonical anchor in ID")
	var mismatched_anchor: Dictionary = _goal_for_purpose("hold")
	mismatched_anchor["goal_id"] = "goal.combat.hold.holder.c3r1"
	if not _matches(GoalContract.validate(mismatched_anchor, origin), "goal_anchor_mismatch", "goal_id"):
		return _fail("goal accepted mismatched destination anchor in ID")
	var missing_fallback: Dictionary = _goal_for_purpose("hold")
	missing_fallback["declared_fallback"] = {}
	if not _matches(GoalContract.validate(missing_fallback, origin), "missing_universal_fallback", "declared_fallback"):
		return _fail("non-idle goal accepted missing fallback")
	var wrong_fallback: Dictionary = _goal_for_purpose("hold")
	wrong_fallback["declared_fallback"] = _action("actor.guard")
	if not _matches(GoalContract.validate(wrong_fallback, origin), "invalid_universal_fallback", "declared_fallback"):
		return _fail("non-idle goal accepted non-idle fallback")
	var payload_fallback: Dictionary = _goal_for_purpose("hold")
	(payload_fallback["declared_fallback"] as Dictionary)["payload"] = {"candidate": {"skill_id": "skill.invalid"}}
	if not _matches(GoalContract.validate(payload_fallback, origin), "invalid_universal_fallback", "declared_fallback"):
		return _fail("goal accepted nonempty universal fallback payload")
	var idle_with_fallback: Dictionary = _goal_for_purpose("read")
	idle_with_fallback["declared_fallback"] = _action("actor.idle")
	if not _matches(GoalContract.validate(idle_with_fallback, origin), "idle_primary_requires_empty_fallback", "declared_fallback"):
		return _fail("idle goal accepted explicit fallback")
	var purifier_advance: Dictionary = _goal_for_purpose("advance")
	(purifier_advance["planned_primary"] as Dictionary)["type"] = "actor.purify_shrine"
	if not bool(GoalContract.validate(purifier_advance, origin)["valid"]):
		return _fail("advance rejected frozen purifier action plan")
	return _pass()


static func _t_option_exact() -> Dictionary:
	var option: Dictionary = _option()
	if not bool(OptionContract.validate(option, {"col": 1, "row": 1})["valid"]):
		return _fail("valid exact option rejected")
	var metric: Dictionary = option.duplicate(true)
	metric["exposure"] = -0.01
	if not _matches(OptionContract.validate(metric, {"col": 1, "row": 1}), "number_out_of_range", "exposure"):
		return _fail("option accepted metric outside unit interval")
	var hazard_count: Dictionary = option.duplicate(true)
	(hazard_count["hazard_summary"] as Dictionary)["known_count"] = 2
	if not _matches(OptionContract.validate(hazard_count, {"col": 1, "row": 1}), "hazard_count_mismatch", "hazard_summary.known_count"):
		return _fail("option accepted mismatched hazard count")
	var stay: Dictionary = OptionContract.build(
		"goal.combat.advance.baseline.c1r1", "option.combat.advance.baseline.c1r1.direct.d1r1.pstay", "advance", {"col": 1, "row": 1}, [],
		0, 0, 0, 2, 0, 0.0, 0.0, 1.0, [], {"known_count": 0, "known_ids": []},
		1.0, _action("actor.guard"), _action("actor.idle")
	)
	if not _matches(OptionContract.validate(stay, {"col": 1, "row": 1}), "stationary_option_requires_hold", "purpose"):
		return _fail("non-hold stationary option accepted")
	for style_value: Variant in OptionContract.STYLES:
		var style_option: Dictionary = _option()
		style_option["option_id"] = str(style_option["option_id"]).replace(".direct.", ".%s." % str(style_value))
		if not bool(OptionContract.validate(style_option, {"col": 1, "row": 1})["valid"]):
			return _fail("valid %s option style rejected" % str(style_value))
	var wrong_style: Dictionary = _option()
	wrong_style["option_id"] = str(wrong_style["option_id"]).replace(".direct.", ".reckless.")
	if not _matches(OptionContract.validate(wrong_style, {"col": 1, "row": 1}), "invalid_option_style", "option_id"):
		return _fail("option accepted unknown style")
	var wrong_prefix: Dictionary = _option()
	wrong_prefix["option_id"] = "option.recover.advance.holder.c2r1.direct.d2r1.pc2r1"
	if not _matches(OptionContract.validate(wrong_prefix, {"col": 1, "row": 1}), "invalid_option_id", "option_id"):
		return _fail("option accepted ID outside exact goal suffix")
	var malformed_goal_anchor: Dictionary = _option()
	malformed_goal_anchor["goal_id"] = "goal.recover.advance.runner.c02r1"
	malformed_goal_anchor["option_id"] = "option.recover.advance.runner.c02r1.direct.d2r1.pc2r1"
	if not _matches(OptionContract.validate(malformed_goal_anchor, {"col": 1, "row": 1}), "invalid_goal_id", "goal_id"):
		return _fail("option accepted noncanonical goal anchor")
	var wrong_destination_token: Dictionary = _option()
	wrong_destination_token["option_id"] = str(wrong_destination_token["option_id"]).replace(".d2r1.", ".d9r9.")
	if not _matches(OptionContract.validate(wrong_destination_token, {"col": 1, "row": 1}), "option_id_destination_mismatch", "option_id"):
		return _fail("option accepted mismatched destination token")
	var wrong_path_token: Dictionary = _option()
	wrong_path_token["option_id"] = str(wrong_path_token["option_id"]).replace(".pc2r1", ".pc2r2")
	if not _matches(OptionContract.validate(wrong_path_token, {"col": 1, "row": 1}), "option_id_path_mismatch", "option_id"):
		return _fail("option accepted mismatched path token")
	var stay_for_path: Dictionary = _option()
	stay_for_path["option_id"] = str(stay_for_path["option_id"]).replace(".pc2r1", ".pstay")
	if not _matches(OptionContract.validate(stay_for_path, {"col": 1, "row": 1}), "option_id_path_mismatch", "option_id"):
		return _fail("moving option accepted stationary path token")
	return _pass()


static func _t_intent_exact() -> Dictionary:
	var intent: Dictionary = IntentContract.build(
		"echo.1", "activation.1", "goal.recover.advance.runner.c2r1",
		"option.recover.advance.runner.c2r1.direct.d2r1.pc2r1", [{"col": 2, "row": 1}],
		2, 1, _action("actor.move", "objective.relic"), _action("actor.idle"),
		["role.runner", "mode.recover"]
	)
	if not bool(IntentContract.validate(intent, {"col": 1, "row": 1})["valid"]):
		return _fail("valid exact intent rejected")
	var empty: Dictionary = intent.duplicate(true)
	empty["planned_action"] = {}
	var empty_result: Dictionary = IntentContract.validate(empty, {"col": 1, "row": 1})
	if not str(empty_result["reason"]).begins_with("invalid_action_plan."):
		return _fail("intent accepted empty primary action")
	return _pass()


static func _t_reversed_input_stable() -> Dictionary:
	var pressure_a: Dictionary = _pressure("recover")
	var pressure_b: Dictionary = {}
	var keys: Array = pressure_a.keys()
	keys.reverse()
	for key_value: Variant in keys:
		pressure_b[key_value] = pressure_a[key_value]
	if PressureSnapshot.validate(pressure_a) != PressureSnapshot.validate(pressure_b):
		return _fail("reversed pressure field insertion changed validation")
	var context_a: Dictionary = _context()
	var context_b: Dictionary = context_a.duplicate(true)
	var reversed_terrain: Dictionary = {}
	var terrain_keys: Array = (context_a["terrain_costs"] as Dictionary).keys()
	terrain_keys.reverse()
	for key_value: Variant in terrain_keys:
		reversed_terrain[key_value] = (context_a["terrain_costs"] as Dictionary)[key_value]
	context_b["terrain_costs"] = reversed_terrain
	if ContextContract.validate(context_a) != ContextContract.validate(context_b):
		return _fail("reversed cell map insertion changed validation")
	return _pass()


static func _t_required_fields() -> Dictionary:
	var tables: Array = [
		[ActionPlan.REQUIRED_FIELDS, ["type", "target_id", "payload"]],
		[ActorFact.REQUIRED_FIELDS, ["id", "position", "kind", "is_dead", "is_ko", "is_structure", "is_spirit", "is_quarry", "controlling_state", "health_ratio"]],
		[HazardFact.REQUIRED_FIELDS, ["id", "position", "hazard_type"]],
		[PressureSnapshot.REQUIRED_FIELDS, ["mode", "guide_mode", "mover_alignment", "factual_role", "objective_known", "objective_id", "objective_position", "destination_region", "approach_region", "fallback_region", "search_region", "purifier_id", "holder_id", "carrier_id", "quarry_id", "spirit_id", "objective_health_ratio", "progress_current", "progress_required", "escort_started", "spirit_joins_battle", "totem_stolen", "pressure_sources"]],
	]
	for table_value: Variant in tables:
		var table: Array = table_value as Array
		if table[0] != table[1]:
			return _fail("required-field table changed: %s" % str(table[0]))
	return _pass()


static func _pressure(mode: String) -> Dictionary:
	return PressureSnapshot.build(
		mode, "", "party", "holder", true, "objective.relic", {"col": 4, "row": 4},
		[{"col": 4, "row": 3}], [{"col": 3, "row": 3}], [{"col": 2, "row": 3}], [],
		"", "echo.1", "", "", "", -1.0, 1, 2, false, false, false,
		["role.holder", "mode.%s" % mode]
	)


static func _context() -> Dictionary:
	return ContextContract.build(
		"echo.1", "activation.1", {"col": 1, "row": 1}, {"w": 6, "h": 6},
		{"1,1": true, "2,1": true, "3,1": true},
		{"1,1": true, "2,1": true, "3,1": true},
		{"1,1": "echo.1", "3,1": "enemy.1"},
		[_actor("echo.1", {"col": 1, "row": 1}, "echo", true), _actor("enemy.1", {"col": 3, "row": 1}, "enemy", true)],
		{"enemy.1": "hostile"}, {"1,1": 1, "2,1": 2, "3,1": 1},
		[HazardFact.build("hazard.binding.1", {"col": 2, "row": 1}, "binding")],
		_pressure("recover"), []
	)


static func _actor(actor_id: String, position: Dictionary, kind: String, controls: bool) -> Dictionary:
	return ActorFact.build(actor_id, position, kind, false, false, false, false, false, controls, 1.0)


static func _reverse_dictionary_insertion(value: Dictionary) -> Dictionary:
	var reversed: Dictionary = {}
	var keys: Array = value.keys()
	keys.reverse()
	for key_value: Variant in keys:
		reversed[key_value] = value[key_value]
	return reversed


static func _goal_for_purpose(purpose: String) -> Dictionary:
	var action_type: String = "actor.move"
	var target_id: String = ""
	match purpose:
		"advance":
			action_type = "actor.move"
			target_id = "target.1"
		"engage", "pursue":
			action_type = "melee_attack"
			target_id = "target.1"
		"intercept", "hold", "cut_off":
			action_type = "actor.guard"
		"protect", "escort":
			action_type = "protect_ally"
			target_id = "target.1"
		"reposition", "regroup", "withdraw":
			action_type = "actor.move"
		"read":
			action_type = "actor.idle"
	var fallback: Dictionary = _action("actor.idle")
	if purpose == "read":
		fallback = {}
	return GoalContract.build(
		"goal.combat.%s.holder.c2r1" % purpose,
		purpose,
		[{"col": 2, "row": 1}],
		0.5,
		0.5,
		["target.1"],
		["mode.combat", "role.holder"],
		_action(action_type, target_id),
		fallback
	)


static func _option() -> Dictionary:
	return OptionContract.build(
		"goal.recover.advance.runner.c2r1", "option.recover.advance.runner.c2r1.direct.d2r1.pc2r1",
		"advance", {"col": 2, "row": 1}, [{"col": 2, "row": 1}],
		1, 1, 0, 2, 1, 0.0, 0.125, 1.0, [],
		{"known_count": 1, "known_ids": ["hazard.binding.1"]}, 1.0,
		_action("actor.move", "objective.relic"), _action("actor.idle")
	)


static func _action(action_type: String, target_id: String = "") -> Dictionary:
	return ActionPlan.build(action_type, target_id, {})


static func _matches(result: Dictionary, reason: String, field: String) -> bool:
	return (
		not bool(result.get("valid", true))
		and str(result.get("reason", "")) == reason
		and str(result.get("field", "")) == field
	)


static func _pass() -> Dictionary:
	return {"ok": true}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

# res://tests/WeavingRiteTests.gd
# V2-WEAVE-002: Foundation Weaving Rite tests.

class_name WeavingRiteTests
extends RefCounted

const WeavingRiteServiceScript := preload("res://core/progression/WeavingRiteService.gd")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("weave/good_fit_high_readiness_returns_accept", Callable(WeavingRiteTests, "_test_good_fit_high_readiness_returns_accept"))
	runner.register_test("weave/good_fit_low_readiness_returns_defer", Callable(WeavingRiteTests, "_test_good_fit_low_readiness_returns_defer"))
	runner.register_test("weave/poor_fit_stable_returns_reject", Callable(WeavingRiteTests, "_test_poor_fit_stable_returns_reject"))
	runner.register_test("weave/accept_removes_thread_from_reserve", Callable(WeavingRiteTests, "_test_accept_removes_thread_from_reserve"))
	runner.register_test("weave/accept_appends_to_woven_threads", Callable(WeavingRiteTests, "_test_accept_appends_to_woven_threads"))
	runner.register_test("weave/reject_removes_thread_from_reserve", Callable(WeavingRiteTests, "_test_reject_removes_thread_from_reserve"))
	runner.register_test("weave/defer_keeps_thread_in_reserve", Callable(WeavingRiteTests, "_test_defer_keeps_thread_in_reserve"))
	runner.register_test("weave/defer_does_not_touch_echo", Callable(WeavingRiteTests, "_test_defer_does_not_touch_echo"))
	runner.register_test("weave/defer_adds_memory_mark", Callable(WeavingRiteTests, "_test_defer_adds_memory_mark"))
	runner.register_test("weave/same_virtue_overspecialisation_lowers_readiness", Callable(WeavingRiteTests, "_test_same_virtue_overspecialisation_lowers_readiness"))
	runner.register_test("weave/non_chosen_consequences_applied_on_accept", Callable(WeavingRiteTests, "_test_non_chosen_consequences_applied_on_accept"))
	runner.register_test("weave/non_chosen_consequences_exist_for_reject_and_defer", Callable(WeavingRiteTests, "_test_non_chosen_consequences_exist_for_reject_and_defer"))
	runner.register_test("weave/commitment_lock_blocks_non_confirm_runtime_actions", Callable(WeavingRiteTests, "_test_commitment_lock_blocks_non_confirm_runtime_actions"))
	runner.register_test("weave/start_for_echo_transitions_to_rite", Callable(WeavingRiteTests, "_test_start_for_echo_transitions_to_rite"))


static func _make_cfg() -> Dictionary:
	return {
		"max_candidates": 3,
		"fit_threshold_accept": 0.55,
		"readiness_threshold_defer": 0.38,
		# V2-PROG-012 Phase 9: WeavingRiteService._compute_fit now reads
		# cfg.vector_virtue_composition (semantic — vector's PRIMARY [0] composing
		# virtue), not the old vector_to_virtue_primary bijection. Verbatim mirror of
		# balance.json data.contact.vector_virtue_composition (GDD-derived, see
		# docs/calling-reference.md:28-37).
		"vector_virtue_composition": {
			"vanguard":    ["courage", "leadership"],
			"protector":   ["courage", "compassion"],
			"seeker":      ["wisdom", "truth"],
			"strategist":  ["wisdom", "leadership"],
			"skeptic":     ["truth", "humility"],
			"pillar":      ["acceptance", "humility"],
			"devoted":     ["acceptance", "generosity"],
			"opportunist": ["courage", "wisdom"],
			"mediator":    ["empathy", "forgiveness"],
			"nurturer":    ["generosity", "compassion"],
		},
		"calling_to_virtue_primary": {
			"okofor":      "courage",
			"onyamesu":    "acceptance",
			"aduro":       "courage",
			"sum_okwanfo": "courage",
			"okomfo":      "wisdom",
			"kra_soro":    "wisdom",
		},
		"clue_vocab": {
			"fit": { "high": "Drawn", "medium": "Resonant", "low": "Misaligned", "false": "FalsePull" },
			"readiness": { "high": "ClearEyed", "medium": "Unsteady", "low": "Trembling", "blocked": "NotYet" },
			"strain": { "low": "Settled", "medium": "Contested", "high": "Burdened" },
		},
		"non_chosen_consequence_base_morale_delta": -8,
		"non_chosen_consequence_base_fear_delta": 5,
		"non_chosen_consequence_base_bond_delta": -8,
	}


static func _make_logger() -> StructuredLogger:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	return logger


static func _make_echo(
	echo_id: String,
	dominant_vector: String,
	morale_current: int = 60,
	fear_current: int = 10,
	woven_threads: Array = []
) -> Dictionary:
	return {
		"id": echo_id,
		"name": "Echo %s" % echo_id,
		"dominant_vector": dominant_vector,
		"calling": "",
		"calling_origin": dominant_vector,
		"standing": 1,
		"emotion": {
			"faith": 50,
			"morale_base": 50,
			"morale_current": morale_current,
			"fear_current": fear_current,
		},
		"woven_threads": woven_threads.duplicate(true),
		"weave_memory_marks": [],
	}


static func _make_save(thread_virtue: String = "courage") -> Dictionary:
	return {
		"sanctum": {
			"threads": {
				"thread.1": {
					"id": "thread.1",
					"virtue": thread_virtue,
					"quality_tier": "clean",
				}
			},
			"roster": [
				_make_echo("echo.1", "vanguard", 80, 5),
				_make_echo("echo.2", "protector", 65, 10),
				_make_echo("echo.3", "seeker", 55, 20),
			],
			"active_party_ids": ["echo.1", "echo.2", "echo.3"],
			"bonds": [],
		},
	}


static func _find_echo(save_data: Dictionary, echo_id: String) -> Dictionary:
	var roster_v: Variant = save_data.get("sanctum", {}).get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	for e_v in roster:
		if e_v is Dictionary and str(e_v.get("id", "")) == echo_id:
			return e_v
	return {}


static func _thread(save_data: Dictionary, thread_id: String = "thread.1") -> Dictionary:
	var threads_v: Variant = save_data.get("sanctum", {}).get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	var th_v: Variant = threads.get(thread_id, {})
	return th_v if th_v is Dictionary else {}


static func _test_good_fit_high_readiness_returns_accept() -> Dictionary:
	var cfg := _make_cfg()
	var save := _make_save("courage")
	var echo := _find_echo(save, "echo.1")
	var thread := _thread(save)
	var outcome := WeavingRiteServiceScript.resolve_outcome(echo, thread, save, cfg)
	if outcome != "accept":
		return { "ok": false, "error": "Expected accept, got %s" % outcome }
	return { "ok": true }


static func _test_good_fit_low_readiness_returns_defer() -> Dictionary:
	var cfg := _make_cfg()
	var save := _make_save("courage")
	var echo := _find_echo(save, "echo.1")
	echo["emotion"]["morale_current"] = 20
	echo["emotion"]["fear_current"] = 95
	var thread := _thread(save)
	var outcome := WeavingRiteServiceScript.resolve_outcome(echo, thread, save, cfg)
	if outcome != "defer":
		return { "ok": false, "error": "Expected defer, got %s" % outcome }
	return { "ok": true }


static func _test_poor_fit_stable_returns_reject() -> Dictionary:
	var cfg := _make_cfg()
	var save := _make_save("acceptance")
	var echo := _find_echo(save, "echo.1")  # vanguard -> courage (opposite with acceptance)
	echo["emotion"]["morale_current"] = 85
	echo["emotion"]["fear_current"] = 5
	var thread := _thread(save)
	var outcome := WeavingRiteServiceScript.resolve_outcome(echo, thread, save, cfg)
	if outcome != "reject":
		return { "ok": false, "error": "Expected reject, got %s" % outcome }
	return { "ok": true }


static func _test_accept_removes_thread_from_reserve() -> Dictionary:
	var save := _make_save("courage")
	WeavingRiteServiceScript.apply_outcome("accept", "echo.1", "thread.1", save, _make_logger(), 1)
	if save.get("sanctum", {}).get("threads", {}).has("thread.1"):
		return { "ok": false, "error": "Expected thread.1 to be removed after accept" }
	return { "ok": true }


static func _test_accept_appends_to_woven_threads() -> Dictionary:
	var save := _make_save("courage")
	var echo_before := _find_echo(save, "echo.1")
	var before_count := (echo_before.get("woven_threads", []) as Array).size()
	WeavingRiteServiceScript.apply_outcome("accept", "echo.1", "thread.1", save, _make_logger(), 1)
	var echo_after := _find_echo(save, "echo.1")
	var woven_v: Variant = echo_after.get("woven_threads", [])
	var woven: Array = woven_v if woven_v is Array else []
	if woven.size() != before_count + 1:
		return { "ok": false, "error": "Expected woven_threads to grow by 1" }
	return { "ok": true }


static func _test_reject_removes_thread_from_reserve() -> Dictionary:
	var save := _make_save("courage")
	WeavingRiteServiceScript.apply_outcome("reject", "echo.1", "thread.1", save, _make_logger(), 1)
	if save.get("sanctum", {}).get("threads", {}).has("thread.1"):
		return { "ok": false, "error": "Expected thread.1 to be removed after reject" }
	return { "ok": true }


static func _test_defer_keeps_thread_in_reserve() -> Dictionary:
	var save := _make_save("courage")
	WeavingRiteServiceScript.apply_outcome("defer", "echo.1", "thread.1", save, _make_logger(), 1)
	if not save.get("sanctum", {}).get("threads", {}).has("thread.1"):
		return { "ok": false, "error": "Expected thread.1 to stay in reserve after defer" }
	return { "ok": true }


static func _test_defer_does_not_touch_echo() -> Dictionary:
	var save := _make_save("courage")
	var echo_before := _find_echo(save, "echo.1")
	var before_woven: Array = (echo_before.get("woven_threads", []) as Array).duplicate(true)
	WeavingRiteServiceScript.apply_outcome("defer", "echo.1", "thread.1", save, _make_logger(), 1)
	var echo_after := _find_echo(save, "echo.1")
	var after_woven_v: Variant = echo_after.get("woven_threads", [])
	var after_woven: Array = after_woven_v if after_woven_v is Array else []
	if after_woven != before_woven:
		return { "ok": false, "error": "Expected woven_threads unchanged on defer" }
	return { "ok": true }


static func _test_defer_adds_memory_mark() -> Dictionary:
	var save := _make_save("courage")
	WeavingRiteServiceScript.apply_outcome("defer", "echo.1", "thread.1", save, _make_logger(), 9)
	var echo := _find_echo(save, "echo.1")
	var marks_v: Variant = echo.get("weave_memory_marks", [])
	var marks: Array = marks_v if marks_v is Array else []
	if marks.is_empty():
		return { "ok": false, "error": "Expected defer to append a memory mark" }
	var mark_v: Variant = marks[0]
	if not (mark_v is Dictionary):
		return { "ok": false, "error": "Expected mark payload to be a Dictionary" }
	var mark: Dictionary = mark_v
	if str(mark.get("thread_id", "")) != "thread.1":
		return { "ok": false, "error": "Memory mark thread_id mismatch" }
	return { "ok": true }


static func _test_same_virtue_overspecialisation_lowers_readiness() -> Dictionary:
	var cfg := _make_cfg()
	var save := _make_save("courage")
	var base_echo := _make_echo("echo.base", "vanguard", 70, 10)
	var overspec_echo := _make_echo(
		"echo.over",
		"vanguard",
		70,
		10,
		[
			{ "id": "w1", "virtue": "courage", "quality_tier": "clean" },
			{ "id": "w2", "virtue": "courage", "quality_tier": "clean" },
			{ "id": "w3", "virtue": "courage", "quality_tier": "clean" },
		]
	)
	var thread := _thread(save)
	var base_readiness := WeavingRiteServiceScript._compute_readiness(base_echo, thread, save)
	var overspec_readiness := WeavingRiteServiceScript._compute_readiness(overspec_echo, thread, save)
	if overspec_readiness >= base_readiness:
		return {
			"ok": false,
			"error": "Expected overspecialisation readiness penalty (%f >= %f)" % [overspec_readiness, base_readiness]
		}
	return { "ok": true }


static func _test_non_chosen_consequences_applied_on_accept() -> Dictionary:
	var logger := _make_logger()
	var runtime := FlowRuntime.new(logger, ConfigService.new(), "/tmp/echoes-vnext-tests/weaving_rite_slot.json")
	runtime.flow_ctx = FlowContext.new()
	runtime.flow_ctx.save_data = _make_save("courage")

	var non_chosen := [
		{ "echo_id": "echo.2", "name": "Echo 2", "morale_delta": -8, "fear_delta": 5, "bond_delta": -8 },
		{ "echo_id": "echo.3", "name": "Echo 3", "morale_delta": -10, "fear_delta": 6, "bond_delta": -10 },
	]
	runtime.call("_apply_weave_non_chosen_consequences", non_chosen, "echo.1", 3)

	var echo_2 := _find_echo(runtime.flow_ctx.save_data, "echo.2")
	var emo_2 := EmotionService.get_emotion(echo_2)
	if int(emo_2.get("morale_current", 50)) >= 65:
		return { "ok": false, "error": "Expected echo.2 morale to drop after non-chosen consequence" }
	if int(emo_2.get("fear_current", 0)) <= 10:
		return { "ok": false, "error": "Expected echo.2 fear to increase after non-chosen consequence" }

	var bonds_v: Variant = runtime.flow_ctx.save_data.get("sanctum", {}).get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []
	var edge := SocialGraphService.get_edge(bonds, "echo.1", "echo.2")
	if edge.is_empty():
		return { "ok": false, "error": "Expected bond edge between chosen and non-chosen echo" }
	if int(edge.get("strength", 0)) >= 0:
		return { "ok": false, "error": "Expected bond strain to push strength negative" }

	return { "ok": true }


static func _test_non_chosen_consequences_exist_for_reject_and_defer() -> Dictionary:
	var cfg := _make_cfg()
	var candidates: Array = [
		{ "echo_id": "echo.1", "name": "Echo 1", "strain_score": 0.5 },
		{ "echo_id": "echo.2", "name": "Echo 2", "strain_score": 0.6 },
	]

	var reject_non_chosen := WeavingRiteServiceScript.get_non_chosen_consequences(candidates, "echo.1", "reject", cfg)
	if reject_non_chosen.is_empty():
		return { "ok": false, "error": "Expected reject to produce non-chosen fallout entries" }

	var defer_non_chosen := WeavingRiteServiceScript.get_non_chosen_consequences(candidates, "echo.1", "defer", cfg)
	if defer_non_chosen.is_empty():
		return { "ok": false, "error": "Expected defer to produce non-chosen fallout entries" }

	return { "ok": true }


static func _test_commitment_lock_blocks_non_confirm_runtime_actions() -> Dictionary:
	var logger := _make_logger()
	var runtime := FlowRuntime.new(logger, ConfigService.new(), "/tmp/echoes-vnext-tests/weaving_rite_slot.json")
	runtime.flow_ctx = FlowContext.new()
	runtime.flow_ctx.sim_tick = 0
	runtime.flow_ctx.weave_commit_locked = true
	runtime.flow_ctx.last_snapshot = {
		"type": FlowStateIds.WEAVING_RITE,
		"meta": { "t": 0 },
		"data": { "phase": "aftermath" },
		"actions": {},
	}

	var out := runtime.dispatch({
		"type": "flow.go_state",
		"to": FlowStateIds.SANCTUM,
	})

	if str(out.get("type", "")) != FlowStateIds.WEAVING_RITE:
		return { "ok": false, "error": "Expected dispatch to keep rite snapshot while locked" }
	if runtime.flow_ctx.weave_commit_locked != true:
		return { "ok": false, "error": "Expected commitment lock to remain active" }

	return { "ok": true }


static func _test_start_for_echo_transitions_to_rite() -> Dictionary:
	var logger := _make_logger()
	var runtime := FlowRuntime.new(logger, ConfigService.new(), "/tmp/echoes-vnext-tests/weaving_rite_slot.json")
	runtime.flow_ctx = FlowContext.new()
	runtime.flow_ctx.sim_tick = 0
	runtime.flow_ctx.save_data = _make_save("courage")
	runtime.flow_ctx.last_snapshot = {
		"type": FlowStateIds.ECHO_PARTY,
		"meta": { "t": 0 },
		"data": {},
		"actions": {},
	}
	runtime.flow_machine = FlowStateMachine.new()
	runtime.flow_machine.register_default_states()

	runtime.dispatch({
		"type": "weave.start_for_echo",
		"echo_id": "echo.1",
	})

	var out := runtime.flow_ctx.last_snapshot
	if str(out.get("type", "")) != FlowStateIds.WEAVING_RITE:
		return { "ok": false, "error": "Expected transition to flow.weaving_rite" }
	if str(runtime.flow_ctx.selected_weave_echo_id) != "echo.1":
		return { "ok": false, "error": "Expected selected_weave_echo_id to be seeded" }

	return { "ok": true }

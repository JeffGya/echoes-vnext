# res://tests/StructureTests.gd
# Tests for the ACTOR-006 Structure Actor Support:
#   1. from_definition() produces a valid actor dict (is_structure=true, actor_type="structure").
#   2. ActorStateMachine.advance_turn() → snapshot has is_structure=true, movement_skipped=true.
#   3. advance_turn() fires "actor.turn" log event with is_structure=true, movement_skipped=true.
#   4. Structure actor selects actor.idle intent (IdleBehaviorModule default for non-echo actors).
#
# All tests use StructureActor.from_definition() directly — no full echo schema needed.
# Tests 2–4 confirm that actor_type="structure" falls into the else → IdleBehaviorModule branch
# in ActorStateMachine._init() without any routing change.
# Run via Debug Panel: tests

extends RefCounted
class_name StructureTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("structure/from_definition_passes_validate",          Callable(StructureTests, "_t_from_definition_passes_validate"))
	runner.register_test("structure/sm_movement_skipped_in_snapshot",          Callable(StructureTests, "_t_sm_movement_skipped_in_snapshot"))
	runner.register_test("structure/sm_logs_actor_turn_event",                 Callable(StructureTests, "_t_sm_logs_actor_turn_event"))
	runner.register_test("structure/selects_idle_intent",                      Callable(StructureTests, "_t_selects_idle_intent"))
	# COMBAT-006: ShrineService tests.
	runner.register_test("shrine/drain_applies_base_drain_each_round",         Callable(StructureTests, "_t_drain_applies_base_drain"))
	runner.register_test("shrine/purify_stack_reduces_drain",                  Callable(StructureTests, "_t_purify_stack_reduces_drain"))
	runner.register_test("shrine/purify_stack_expiry_adds_penalty",            Callable(StructureTests, "_t_purify_stack_expiry_adds_penalty"))
	runner.register_test("shrine/select_purifier_prefers_faith_pillar_vector", Callable(StructureTests, "_t_select_purifier_prefers_faith_pillar"))


# -------------------------
# Tests
# -------------------------

# Test 1: from_definition_passes_validate
# Setup: minimal structure definition dict.
# Expected: validate() passes; is_structure=true; actor_type="structure".
# Demonstrates: StructureActor factory produces a valid Actor dict that passes schema.
static func _t_from_definition_passes_validate() -> Dictionary:
	var defn := {
		"id":       "shrine_001",
		"name":     "Test Shrine",
		"max_hp":   200,
		"faction":  "neutral",
		"grid_pos": { "col": 3, "row": 4 },
	}

	var actor: Dictionary = StructureActor.from_definition(defn, 1)

	if not ActorSchema.validate(actor):
		return { "ok": false, "error": "validate() returned false for StructureActor output" }
	if actor.get("is_structure") != true:
		return { "ok": false, "error": "Expected is_structure=true, got: %s" % str(actor.get("is_structure")) }
	if str(actor.get("actor_type", "")) != "structure":
		return { "ok": false, "error": "Expected actor_type='structure', got: %s" % str(actor.get("actor_type")) }
	if str(actor.get("id", "")) != "shrine_001":
		return { "ok": false, "error": "Expected id='shrine_001', got: %s" % str(actor.get("id")) }
	if int(actor.get("current_hp", -1)) != 200:
		return { "ok": false, "error": "Expected current_hp=200, got: %s" % str(actor.get("current_hp")) }

	return { "ok": true }


# Test 2: structure_sm_movement_skipped_in_snapshot
# Setup: structure actor → ActorStateMachine → advance_turn().
# Expected: get_snapshot() returns is_structure=true, movement_skipped=true.
# Demonstrates: _movement_skipped flag is set in advance_turn() and exposed in snapshot.
static func _t_sm_movement_skipped_in_snapshot() -> Dictionary:
	var defn := { "id": "shrine_002", "name": "Shrine Alpha", "max_hp": 100 }
	var actor: Dictionary = StructureActor.from_definition(defn, 1)

	var sm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("info")

	var context := { "actor": actor, "all_actors": [], "t": 5 }
	sm.advance_turn(context, logger, 5)

	var snapshot: Dictionary = sm.get_snapshot()

	if snapshot.get("is_structure") != true:
		return { "ok": false, "error": "Expected snapshot.is_structure=true, got: %s" % str(snapshot.get("is_structure")) }
	if snapshot.get("movement_skipped") != true:
		return { "ok": false, "error": "Expected snapshot.movement_skipped=true, got: %s" % str(snapshot.get("movement_skipped")) }

	return { "ok": true }


# Test 3: structure_sm_logs_actor_turn_event
# Setup: structure actor → ActorStateMachine → advance_turn() with logger.
# Expected: "actor.turn" log event fires with is_structure=true, movement_skipped=true.
# Demonstrates: advance_turn() logs the movement skip for structure actors.
static func _t_sm_logs_actor_turn_event() -> Dictionary:
	var defn := { "id": "totem_001", "name": "Totem Beta", "max_hp": 80 }
	var actor: Dictionary = StructureActor.from_definition(defn, 2)

	var sm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("info")

	var context := { "actor": actor, "all_actors": [], "t": 10 }
	sm.advance_turn(context, logger, 10)

	var logs: Array = logger.get_logs()
	var turn_event: Dictionary = {}
	for entry in logs:
		if str(entry.get("type", "")) == "actor.turn" and turn_event.is_empty():
			turn_event = entry

	if turn_event.is_empty():
		return { "ok": false, "error": "No actor.turn log event found" }

	var data: Dictionary = turn_event.get("data", {})
	if data.get("is_structure") != true:
		return { "ok": false, "error": "actor.turn data.is_structure expected true, got: %s" % str(data.get("is_structure")) }
	if data.get("movement_skipped") != true:
		return { "ok": false, "error": "actor.turn data.movement_skipped expected true, got: %s" % str(data.get("movement_skipped")) }
	if str(data.get("actor_id", "")) != "totem_001":
		return { "ok": false, "error": "actor.turn data.actor_id expected 'totem_001', got: %s" % str(data.get("actor_id")) }

	return { "ok": true }


# Test 4: structure_selects_idle_intent
# Setup: structure actor → ActorStateMachine (no explicit module).
# Expected: intent.action_type == "actor.idle".
# Demonstrates: actor_type="structure" routes to IdleBehaviorModule (else branch in _init).
static func _t_selects_idle_intent() -> Dictionary:
	var defn := { "id": "hazard_001", "name": "Fire Hazard", "max_hp": 50 }
	var actor: Dictionary = StructureActor.from_definition(defn, 3)

	var sm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("info")

	var context := { "actor": actor, "all_actors": [], "t": 15 }
	var intent: Dictionary = sm.advance_turn(context, logger, 15)

	if str(intent.get("action_type", "")) != "actor.idle":
		return { "ok": false, "error": "Expected actor.idle from structure, got: %s" % str(intent.get("action_type")) }

	return { "ok": true }


# COMBAT-006 — ShrineService tests ----------------------------------------

# Test 5: drain_applies_base_drain_each_round
# Shrine at 200 hp, no stacks, base_drain=5 → current_hp becomes 195.
static func _t_drain_applies_base_drain() -> Dictionary:
	var shrine: Dictionary = { "current_hp": 200, "purify_stacks": [] }
	var cfg: Dictionary    = { "base_drain_per_round": 5, "purify_expiry_penalty": 2 }

	var result: Dictionary = ShrineService.apply_drain(shrine, cfg)

	if int(result.get("drain", -1)) != 5:
		return { "ok": false, "error": "Expected drain=5, got: %s" % str(result.get("drain")) }
	if int(shrine.get("current_hp", -1)) != 195:
		return { "ok": false, "error": "Expected shrine hp=195, got: %s" % str(shrine.get("current_hp")) }

	return { "ok": true }


# Test 6: purify_stack_reduces_drain
# Shrine at 200 hp, 1 active stack (reduction=3, duration=2), base=5 → drain=2, hp=198.
static func _t_purify_stack_reduces_drain() -> Dictionary:
	var shrine: Dictionary = {
		"current_hp":    200,
		"purify_stacks": [{ "duration": 2, "reduction": 3 }],
	}
	var cfg: Dictionary = { "base_drain_per_round": 5, "purify_expiry_penalty": 2 }

	var result: Dictionary = ShrineService.apply_drain(shrine, cfg)

	if int(result.get("drain", -1)) != 2:
		return { "ok": false, "error": "Expected drain=2 (5-3=2), got: %s" % str(result.get("drain")) }
	if int(shrine.get("current_hp", -1)) != 198:
		return { "ok": false, "error": "Expected shrine hp=198, got: %s" % str(shrine.get("current_hp")) }

	return { "ok": true }


# Test 7: purify_stack_expiry_adds_penalty
# Shrine at 200 hp, 1 stack with duration=1 (expires this tick), penalty=2, base=5 → drain=7, hp=193.
static func _t_purify_stack_expiry_adds_penalty() -> Dictionary:
	var shrine: Dictionary = {
		"current_hp":    200,
		"purify_stacks": [{ "duration": 1, "reduction": 3 }],
	}
	var cfg: Dictionary = { "base_drain_per_round": 5, "purify_expiry_penalty": 2 }

	var result: Dictionary = ShrineService.apply_drain(shrine, cfg)

	# duration ticks down to 0 → expires → penalty applies (no reduction)
	# drain = 5 - 0 + 2 = 7
	if int(result.get("drain", -1)) != 7:
		return { "ok": false, "error": "Expected drain=7 (5+2 penalty), got: %s" % str(result.get("drain")) }
	if int(shrine.get("current_hp", -1)) != 193:
		return { "ok": false, "error": "Expected shrine hp=193, got: %s" % str(shrine.get("current_hp")) }
	if int(result.get("stacks_expired", -1)) != 1:
		return { "ok": false, "error": "Expected stacks_expired=1, got: %s" % str(result.get("stacks_expired")) }

	return { "ok": true }


# Test 8: select_purifier_prefers_faith_pillar_vector
# echo_A: faith=60, dominant_vector=vanguard → weight = 60*0.5 + 0 = 30
# echo_B: faith=40, dominant_vector=pillar   → weight = 40*0.5 + 20 = 40
# Expected: echo_B selected.
static func _t_select_purifier_prefers_faith_pillar() -> Dictionary:
	var echo_a: Dictionary = {
		"id":            "echo_a",
		"traits":        { "faith": 60 },
		"vector_scores": { "vanguard": 100, "pillar": 10, "protector": 10, "seeker": 10 },
	}
	var echo_b: Dictionary = {
		"id":            "echo_b",
		"traits":        { "faith": 40 },
		"vector_scores": { "pillar": 100, "vanguard": 10, "protector": 10, "seeker": 10 },
	}
	var shrine_cfg: Dictionary = {
		"purify_weight_faith": 0.5,
		"purify_weight_by_vector": { "pillar": 20, "protector": 10, "seeker": 5, "vanguard": 0 },
	}

	var purifier_id: String = ShrineService.select_purifier([echo_a, echo_b], shrine_cfg)

	if purifier_id != "echo_b":
		return { "ok": false, "error": "Expected echo_b (weight=40 > echo_a weight=30), got: %s" % purifier_id }

	return { "ok": true }

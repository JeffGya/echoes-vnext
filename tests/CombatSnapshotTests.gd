# res://tests/CombatSnapshotTests.gd
# COMBAT-007: Tests for the snapshot builder split, actors projection, objective_state,
# and LOG_SNAPSHOT_EMITTED field_count.
#
#   1. snapshot/round_snapshot_has_required_fields
#   2. snapshot/final_snapshot_has_required_fields
#   3. snapshot/actor_projection_fields
#   4. snapshot/status_derivation
#   5. snapshot/objective_state_shape
#   6. snapshot/field_count_is_nonzero
#
# All tests are pure unit tests — no FlowRuntime, no save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name CombatSnapshotTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("snapshot/round_snapshot_has_required_fields", Callable(CombatSnapshotTests, "_t_round_snapshot_has_required_fields"))
	runner.register_test("snapshot/final_snapshot_has_required_fields", Callable(CombatSnapshotTests, "_t_final_snapshot_has_required_fields"))
	runner.register_test("snapshot/actor_projection_fields",            Callable(CombatSnapshotTests, "_t_actor_projection_fields"))
	runner.register_test("snapshot/status_derivation",                  Callable(CombatSnapshotTests, "_t_status_derivation"))
	runner.register_test("snapshot/objective_state_shape",              Callable(CombatSnapshotTests, "_t_objective_state_shape"))
	runner.register_test("snapshot/field_count_is_nonzero",             Callable(CombatSnapshotTests, "_t_field_count_is_nonzero"))
	# UI-004 additions:
	runner.register_test("snapshot/pre_combat_has_retreat_fields",       Callable(CombatSnapshotTests, "_t_pre_combat_has_retreat_fields"))
	runner.register_test("snapshot/cta_retreat_absent_when_ineligible",  Callable(CombatSnapshotTests, "_t_cta_retreat_absent_when_ineligible"))
	runner.register_test("snapshot/last_actor_action_retains_move_to_pos", Callable(CombatSnapshotTests, "_t_last_actor_action_retains_move_to_pos"))
	# V2-COMBAT-002 Slice 6D additions:
	runner.register_test("snapshot/last_actor_action_forwards_path_and_from_pos", Callable(CombatSnapshotTests, "_t_last_actor_action_forwards_path_and_from_pos"))
	runner.register_test("snapshot/last_actor_action_path_is_deep_copy",          Callable(CombatSnapshotTests, "_t_last_actor_action_path_is_deep_copy"))
	runner.register_test("snapshot/last_actor_action_empty_path_projects_empty",  Callable(CombatSnapshotTests, "_t_last_actor_action_empty_path_projects_empty"))


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

## Returns a minimal FlowContext with an empty EncounterContext (pre_combat state).
static func _make_pre_combat_ctx() -> FlowContext:
	var ctx := FlowContext.new()
	ctx.config_service = null  # triggers safe defaults (board 10×10)
	var ectx := EncounterContext.new()
	ectx.encounter_id   = "test_enc_001"
	ectx.placement_seed = 42
	ectx.actors         = []
	ectx.combat_state   = {}  # empty → pre_combat phase
	ctx.encounter_ctx   = ectx
	return ctx


## Returns a minimal FlowContext where combat has ended with victory.
static func _make_combat_over_ctx() -> FlowContext:
	var ctx := FlowContext.new()
	ctx.config_service = null
	var ectx := EncounterContext.new()
	ectx.encounter_id   = "test_enc_002"
	ectx.placement_seed = 7
	ectx.actors         = []
	ectx.combat_state   = { "combat_over": true, "objective": "defeat_enemies", "round_counter": 3 }
	ectx.combat_result  = { "victory": true, "reason": "all_enemies_defeated", "round_ended": 3 }
	ctx.encounter_ctx   = ectx
	return ctx


# ──────────────────────────────────────────────────────────────────────────────
# Tests
# ──────────────────────────────────────────────────────────────────────────────

# Test 1: round_snapshot_has_required_fields
# Setup: minimal pre_combat FlowContext.
# Expected: build_round_snapshot returns data with actors, objective_state,
#           round, action_results, round_phase; type == "flow.encounter".
static func _t_round_snapshot_has_required_fields() -> Dictionary:
	var ctx: FlowContext = CombatSnapshotTests._make_pre_combat_ctx()
	var snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(ctx, 1)

	if str(snap.get("type", "")) != "flow.encounter":
		return { "ok": false, "error": "Expected type='flow.encounter', got: %s" % str(snap.get("type")) }

	var data: Dictionary = snap.get("data", {})
	for key in ["actors", "objective_state", "round", "action_results", "round_phase"]:
		if not data.has(key):
			return { "ok": false, "error": "data missing required key: '%s'" % key }

	if str(data.get("round_phase", "")) != "pre_combat":
		return { "ok": false, "error": "Expected round_phase='pre_combat', got: %s" % str(data.get("round_phase")) }

	return { "ok": true }


# Test 2: final_snapshot_has_required_fields
# Setup: combat-over FlowContext (victory=true, reason="all_enemies_defeated").
# Expected: build_final_snapshot returns type=="flow.resolve";
#           data has victory, reason, round_ended.
static func _t_final_snapshot_has_required_fields() -> Dictionary:
	var ctx: FlowContext = CombatSnapshotTests._make_combat_over_ctx()
	var snap: Dictionary = FlowEncounterState.build_final_snapshot(ctx, 1)

	if str(snap.get("type", "")) != "flow.resolve":
		return { "ok": false, "error": "Expected type='flow.resolve', got: %s" % str(snap.get("type")) }

	var data: Dictionary = snap.get("data", {})
	for key in ["victory", "reason", "round_ended", "actors", "objective_state"]:
		if not data.has(key):
			return { "ok": false, "error": "data missing required key: '%s'" % key }

	if bool(data.get("victory", false)) != true:
		return { "ok": false, "error": "Expected victory=true, got: %s" % str(data.get("victory")) }
	if str(data.get("reason", "")) != "all_enemies_defeated":
		return { "ok": false, "error": "Expected reason='all_enemies_defeated', got: %s" % str(data.get("reason")) }
	if int(data.get("round_ended", -1)) != 3:
		return { "ok": false, "error": "Expected round_ended=3, got: %s" % str(data.get("round_ended")) }

	return { "ok": true }


# Test 3: actor_projection_fields
# Setup: full runtime actor dict with traits, xp_total, archetype_birth, stats block, current_hp.
# Expected: _project_actor preserves render and operational fields, exposes emotional_status only,
#           and strips raw/legacy emotion plus other internal fields.
static func _t_actor_projection_fields() -> Dictionary:
	var actor: Dictionary = {
		"id":             "echo_a",
		"name":           "Kofi",
		"current_hp":     60,
		"stats":          { "max_hp": 100, "atk": 15, "def": 8, "agi": 12, "int": 9, "cha": 7 },
		"grid_pos":       { "col": 3, "row": 4 },
		"faction":        "echo",
		"is_structure":   false,
		"is_dead":        false,
		"guard_state":    false,
		"fear":           20,
		"morale":         55,
		# Internal fields that should NOT appear in projection:
		"traits":         { "courage": 70, "wisdom": 50, "faith": 40 },
		"xp_total":       0,
		"archetype_birth": "brave",
		"calling_origin": "blade",
		"rank":           1,
	}

	var proj: Dictionary = EncounterSnapshotBuilder._project_actor(actor)

	# Player-facing emotion uses the canonical emotional_status only.
	for key in ["id", "name", "hp", "max_hp", "status", "grid_pos", "faction",
				"is_structure", "calling_origin", "emotional_status"]:
		if not proj.has(key):
			return { "ok": false, "error": "projection missing key: '%s'" % key }

	# Internal keys must NOT be present.
	for key in ["traits", "xp_total", "archetype_birth"]:
		if proj.has(key):
			return { "ok": false, "error": "projection contains internal key that should be stripped: '%s'" % key }
	for legacy_key in [
		"fear", "morale", "morale_status", "fear_signal",
		"emotional_readiness", "morale_tier", "refuse_cause",
	]:
		if proj.has(legacy_key):
			return { "ok": false, "error": "projection exposes raw or legacy emotion key: %s" % legacy_key }

	if int(proj.get("hp", -1)) != 60:
		return { "ok": false, "error": "Expected hp=60 (from current_hp), got: %s" % str(proj.get("hp")) }
	if int(proj.get("max_hp", -1)) != 100:
		return { "ok": false, "error": "Expected max_hp=100, got: %s" % str(proj.get("max_hp")) }
	if str(proj.get("status", "")) != "alive":
		return { "ok": false, "error": "Expected status='alive', got: %s" % str(proj.get("status")) }
	if str(proj.get("emotional_status", "")) != "whole":
		return { "ok": false, "error": "Expected emotional_status='whole', got: %s" % str(proj.get("emotional_status")) }

	return { "ok": true }


# Test 4: status_derivation
# Operational status is independent from emotional state.
static func _t_status_derivation() -> Dictionary:
	var dead_actor:        Dictionary = { "is_dead": true,  "guard_state": false, "fear": 0  }
	var guard_actor:       Dictionary = { "is_dead": false, "guard_state": true,  "fear": 0  }
	var refuse_actor:      Dictionary = { "is_dead": false, "guard_state": false, "fear": 80 }
	var hesitating_actor:  Dictionary = { "is_dead": false, "guard_state": false, "fear": 50 }
	var alive_actor:       Dictionary = { "is_dead": false, "guard_state": false, "fear": 39 }

	if EncounterSnapshotBuilder._derive_status(dead_actor) != "dead":
		return { "ok": false, "error": "Expected 'dead' for is_dead=true, got: %s" % EncounterSnapshotBuilder._derive_status(dead_actor) }
	if EncounterSnapshotBuilder._derive_status(guard_actor) != "guarding":
		return { "ok": false, "error": "Expected 'guarding' for guard_state=true, got: %s" % EncounterSnapshotBuilder._derive_status(guard_actor) }
	if EncounterSnapshotBuilder._derive_status(refuse_actor) != "alive":
		return { "ok": false, "error": "Fear must not replace operational status" }
	if EncounterSnapshotBuilder._derive_status(hesitating_actor) != "alive":
		return { "ok": false, "error": "Hesitation must be expressed through emotional_status" }
	if EncounterSnapshotBuilder._derive_status(alive_actor) != "alive":
		return { "ok": false, "error": "Expected 'alive' for fear=39, got: %s" % EncounterSnapshotBuilder._derive_status(alive_actor) }

	return { "ok": true }


# Test 5: objective_state_shape
# Setup: EncounterContext with a living shrine actor (is_structure=true, current_hp=150).
#        combat_state has objective="purify_shrine".
# Expected: _build_objective_state returns { type, shrine_hp, shrine_alive }
#           with type="purify_shrine", shrine_hp=150, shrine_alive=true.
static func _t_objective_state_shape() -> Dictionary:
	var ectx := EncounterContext.new()
	ectx.resolution_mode = "purify_shrine"
	ectx.actors = [
		{ "id": "shrine_01", "is_structure": true, "current_hp": 150, "is_dead": false },
		{ "id": "echo_01",   "is_structure": false, "current_hp": 80,  "is_dead": false },
	]
	var combat_state: Dictionary = { "objective": "purify_shrine", "round_counter": 2 }

	var obj: Dictionary = EncounterSnapshotBuilder._build_objective_state(ectx, combat_state)

	if str(obj.get("type", "")) != "purify_shrine":
		return { "ok": false, "error": "Expected type='purify_shrine', got: %s" % str(obj.get("type")) }
	if int(obj.get("shrine_hp", -1)) != 150:
		return { "ok": false, "error": "Expected shrine_hp=150, got: %s" % str(obj.get("shrine_hp")) }
	if bool(obj.get("shrine_alive", false)) != true:
		return { "ok": false, "error": "Expected shrine_alive=true, got: %s" % str(obj.get("shrine_alive")) }

	return { "ok": true }


# Test 6: field_count_is_nonzero
# Setup: round snapshot + final snapshot via minimal contexts.
# Expected: data.size() > 0 for both (confirms LOG_SNAPSHOT_EMITTED would log field_count > 0).
# Also checks round snapshot has more fields than final (round carries board + initiative data).
static func _t_field_count_is_nonzero() -> Dictionary:
	var round_ctx: FlowContext = CombatSnapshotTests._make_pre_combat_ctx()
	var final_ctx: FlowContext = CombatSnapshotTests._make_combat_over_ctx()

	var round_snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(round_ctx, 1)
	var final_snap: Dictionary = FlowEncounterState.build_final_snapshot(final_ctx, 1)

	var round_field_count: int = round_snap.get("data", {}).size()
	var final_field_count: int = final_snap.get("data", {}).size()

	if round_field_count <= 0:
		return { "ok": false, "error": "round_snapshot field_count must be > 0, got: %d" % round_field_count }
	if final_field_count <= 0:
		return { "ok": false, "error": "final_snapshot field_count must be > 0, got: %d" % final_field_count }

	# Round snapshot carries at least as many fields as final (board_cols, initiative, etc.).
	# V2-COMBAT-001 added emotion delta fields to final, equalising counts — use >= not >.
	if round_field_count < final_field_count:
		return { "ok": false, "error": "round_snapshot should not have fewer fields than final (%d vs %d)" % [round_field_count, final_field_count] }

	return { "ok": true }


# Test 7 (UI-004): pre_combat_has_retreat_fields
# Setup: minimal pre_combat FlowContext (no config_service → defaults apply).
# Expected: build_round_snapshot returns data with retreat_eligible, retreat_ase_cost,
#           retreat_tier_label, retreat_success_pct keys.
static func _t_pre_combat_has_retreat_fields() -> Dictionary:
	var ctx: FlowContext = CombatSnapshotTests._make_pre_combat_ctx()
	var snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(ctx, 1)
	var data: Dictionary = snap.get("data", {})

	for key in ["retreat_eligible", "retreat_ase_cost", "retreat_tier_label", "retreat_success_pct"]:
		if not data.has(key):
			return { "ok": false, "error": "pre_combat data missing UI-004 key: '%s'" % key }

	return { "ok": true }


# Test 8 (UI-004): cta_retreat_absent_when_ineligible
# Setup: pre_combat FlowContext with NO actors (empty) → speed gate fails → ineligible.
# Expected: actions dict does NOT contain "cta.retreat".
#           retreat_eligible == false in data.
static func _t_cta_retreat_absent_when_ineligible() -> Dictionary:
	var ctx: FlowContext = CombatSnapshotTests._make_pre_combat_ctx()
	# No actors → RetreatService.can_attempt() returns false.
	ctx.encounter_ctx.actors = []

	var snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(ctx, 1)
	var data: Dictionary = snap.get("data", {})
	var actions: Dictionary = snap.get("actions", {})

	if bool(data.get("retreat_eligible", true)) != false:
		return { "ok": false, "error": "Expected retreat_eligible=false with no actors, got: %s" % str(data.get("retreat_eligible")) }

	if actions.has("cta.retreat"):
		return { "ok": false, "error": "cta.retreat must not be present in actions when ineligible" }

	return { "ok": true }


# Test 9: last_actor_action_retains_move_to_pos
# Setup: actor_turn snapshot with a move action already resolved in runtime state.
# Expected: build_round_snapshot forwards last_actor_action unchanged, including to_pos.
static func _t_last_actor_action_retains_move_to_pos() -> Dictionary:
	var ctx: FlowContext = CombatSnapshotTests._make_pre_combat_ctx()
	ctx.encounter_ctx.combat_state = {
		"round_phase": "in_round",
		"objective": "defeat_enemies",
		"round_counter": 1,
		"initiative_order": [],
		"active_initiative_index": 0,
	}
	ctx.encounter_ctx.last_actor_action = {
		"action_type": "actor.move",
		"source_id": "echo_01",
		"to_pos": { "col": 4, "row": 3 },
	}

	var snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(ctx, 2)
	var action: Dictionary = snap.get("data", {}).get("last_actor_action", {})

	if str(action.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "Expected last_actor_action.action_type='actor.move', got %s" % str(action.get("action_type", "")) }
	if int(action.get("to_pos", {}).get("col", -1)) != 4:
		return { "ok": false, "error": "Expected last_actor_action.to_pos.col=4" }
	if int(action.get("to_pos", {}).get("row", -1)) != 3:
		return { "ok": false, "error": "Expected last_actor_action.to_pos.row=3" }

	return { "ok": true }


## Shared setup for the Slice 6D path-projection tests: an actor_turn context whose
## last_actor_action already carries the additive from_pos/path keys.
static func _make_path_ctx(from_pos: Dictionary, path: Array) -> FlowContext:
	var ctx: FlowContext = CombatSnapshotTests._make_pre_combat_ctx()
	ctx.encounter_ctx.combat_state = {
		"round_phase": "in_round",
		"objective": "defeat_enemies",
		"round_counter": 1,
		"initiative_order": [],
		"active_initiative_index": 0,
	}
	ctx.encounter_ctx.last_actor_action = {
		"action_type": "melee_attack",
		"source_id": "echo_01",
		"from_pos": from_pos,
		"path": path,
	}
	return ctx


# Test 10: last_actor_action_forwards_path_and_from_pos
# Setup: last_actor_action carries a multi-cell traversed path plus the pre-activation cell.
# Expected: build_round_snapshot forwards both keys unchanged, exact cell sequence preserved.
static func _t_last_actor_action_forwards_path_and_from_pos() -> Dictionary:
	var expected: Array = [
		{ "col": 2, "row": 5 },
		{ "col": 3, "row": 5 },
		{ "col": 3, "row": 4 },
	]
	var ctx: FlowContext = CombatSnapshotTests._make_path_ctx({ "col": 1, "row": 5 }, expected.duplicate(true))

	var snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(ctx, 3)
	var action: Dictionary = snap.get("data", {}).get("last_actor_action", {})

	if not action.has("from_pos"):
		return { "ok": false, "error": "last_actor_action.from_pos missing from snapshot" }
	if int(action.get("from_pos", {}).get("col", -1)) != 1 or int(action.get("from_pos", {}).get("row", -1)) != 5:
		return { "ok": false, "error": "Expected from_pos {col:1,row:5}, got %s" % str(action.get("from_pos", {})) }

	if not action.has("path"):
		return { "ok": false, "error": "last_actor_action.path missing from snapshot" }
	var path: Array = action.get("path", []) as Array
	if path.size() != expected.size():
		return { "ok": false, "error": "Expected path size %d, got %d" % [expected.size(), path.size()] }
	for i: int in range(expected.size()):
		var got: Dictionary = path[i] as Dictionary
		var want: Dictionary = expected[i] as Dictionary
		if int(got.get("col", -1)) != int(want["col"]) or int(got.get("row", -1)) != int(want["row"]):
			return { "ok": false, "error": "path[%d] expected %s, got %s" % [i, str(want), str(got)] }

	return { "ok": true }


# Test 11: last_actor_action_path_is_deep_copy
# Setup: mutate the path Array (and a cell inside it) returned in the snapshot.
# Expected: ectx.last_actor_action is untouched — no aliasing across the core/UI boundary.
static func _t_last_actor_action_path_is_deep_copy() -> Dictionary:
	var ctx: FlowContext = CombatSnapshotTests._make_path_ctx(
		{ "col": 0, "row": 0 },
		[{ "col": 1, "row": 0 }, { "col": 2, "row": 0 }]
	)

	var snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(ctx, 4)
	var action: Dictionary = snap.get("data", {}).get("last_actor_action", {})
	var path: Array = action.get("path", []) as Array

	path.append({ "col": 99, "row": 99 })
	(path[0] as Dictionary)["col"] = 77
	(action.get("from_pos", {}) as Dictionary)["col"] = 55

	var source_path: Array = ctx.encounter_ctx.last_actor_action.get("path", []) as Array
	if source_path.size() != 2:
		return { "ok": false, "error": "Source path was mutated: expected size 2, got %d" % source_path.size() }
	if int((source_path[0] as Dictionary).get("col", -1)) != 1:
		return { "ok": false, "error": "Source path cell was mutated: expected col=1, got %d" % int((source_path[0] as Dictionary).get("col", -1)) }
	var source_from: Dictionary = ctx.encounter_ctx.last_actor_action.get("from_pos", {}) as Dictionary
	if int(source_from.get("col", -1)) != 0:
		return { "ok": false, "error": "Source from_pos was mutated: expected col=0, got %d" % int(source_from.get("col", -1)) }

	return { "ok": true }


# Test 12: last_actor_action_empty_path_projects_empty
# Setup: an activation with no traversal — path is [] and from_pos is the current cell.
# Expected: `path` is present and an empty Array (not missing, not null); from_pos present.
static func _t_last_actor_action_empty_path_projects_empty() -> Dictionary:
	var ctx: FlowContext = CombatSnapshotTests._make_path_ctx({ "col": 6, "row": 2 }, [])

	var snap: Dictionary = EncounterSnapshotBuilder.build_round_snapshot(ctx, 5)
	var action: Dictionary = snap.get("data", {}).get("last_actor_action", {})

	if not action.has("path"):
		return { "ok": false, "error": "last_actor_action.path missing — key must always be present" }
	var path_v: Variant = action.get("path")
	if not (path_v is Array):
		return { "ok": false, "error": "last_actor_action.path must be an Array, got %s" % type_string(typeof(path_v)) }
	if not (path_v as Array).is_empty():
		return { "ok": false, "error": "Expected empty path, got size %d" % (path_v as Array).size() }

	if not action.has("from_pos"):
		return { "ok": false, "error": "last_actor_action.from_pos missing — key must always be present" }
	if int(action.get("from_pos", {}).get("col", -1)) != 6 or int(action.get("from_pos", {}).get("row", -1)) != 2:
		return { "ok": false, "error": "Expected from_pos {col:6,row:2}, got %s" % str(action.get("from_pos", {})) }

	return { "ok": true }

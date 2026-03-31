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
	var snap: Dictionary = FlowEncounterState.build_round_snapshot(ctx, 1)

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
# Expected: _project_actor returns { id, name, hp, max_hp, status, grid_pos, faction, is_structure, fear, morale }.
#           No traits, xp_total, archetype_birth keys.
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

	var proj: Dictionary = FlowEncounterState._project_actor(actor)

	# Required keys must be present (UI-004 added calling_origin + morale_status).
	for key in ["id", "name", "hp", "max_hp", "status", "grid_pos", "faction",
				"is_structure", "fear", "morale", "calling_origin", "morale_status"]:
		if not proj.has(key):
			return { "ok": false, "error": "projection missing key: '%s'" % key }

	# Internal keys must NOT be present.
	for key in ["traits", "xp_total", "archetype_birth"]:
		if proj.has(key):
			return { "ok": false, "error": "projection contains internal key that should be stripped: '%s'" % key }

	if int(proj.get("hp", -1)) != 60:
		return { "ok": false, "error": "Expected hp=60 (from current_hp), got: %s" % str(proj.get("hp")) }
	if int(proj.get("max_hp", -1)) != 100:
		return { "ok": false, "error": "Expected max_hp=100, got: %s" % str(proj.get("max_hp")) }
	if str(proj.get("status", "")) != "alive":
		return { "ok": false, "error": "Expected status='alive', got: %s" % str(proj.get("status")) }

	return { "ok": true }


# Test 4: status_derivation
# Setup: four actor dicts covering all branches.
# Expected: dead→"dead", guard_state→"guarding", fear≥80→"refusing", else→"alive".
static func _t_status_derivation() -> Dictionary:
	var dead_actor:     Dictionary = { "is_dead": true, "guard_state": false, "fear": 0 }
	var guard_actor:    Dictionary = { "is_dead": false, "guard_state": true,  "fear": 0 }
	var refuse_actor:   Dictionary = { "is_dead": false, "guard_state": false, "fear": 80 }
	var alive_actor:    Dictionary = { "is_dead": false, "guard_state": false, "fear": 50 }

	if FlowEncounterState._derive_status(dead_actor) != "dead":
		return { "ok": false, "error": "Expected 'dead' for is_dead=true, got: %s" % FlowEncounterState._derive_status(dead_actor) }
	if FlowEncounterState._derive_status(guard_actor) != "guarding":
		return { "ok": false, "error": "Expected 'guarding' for guard_state=true, got: %s" % FlowEncounterState._derive_status(guard_actor) }
	if FlowEncounterState._derive_status(refuse_actor) != "refusing":
		return { "ok": false, "error": "Expected 'refusing' for fear=80, got: %s" % FlowEncounterState._derive_status(refuse_actor) }
	if FlowEncounterState._derive_status(alive_actor) != "alive":
		return { "ok": false, "error": "Expected 'alive' for normal actor, got: %s" % FlowEncounterState._derive_status(alive_actor) }

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

	var obj: Dictionary = FlowEncounterState._build_objective_state(ectx, combat_state)

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

	var round_snap: Dictionary = FlowEncounterState.build_round_snapshot(round_ctx, 1)
	var final_snap: Dictionary = FlowEncounterState.build_final_snapshot(final_ctx, 1)

	var round_field_count: int = round_snap.get("data", {}).size()
	var final_field_count: int = final_snap.get("data", {}).size()

	if round_field_count <= 0:
		return { "ok": false, "error": "round_snapshot field_count must be > 0, got: %d" % round_field_count }
	if final_field_count <= 0:
		return { "ok": false, "error": "final_snapshot field_count must be > 0, got: %d" % final_field_count }

	# Round snapshot carries more display fields (board_cols, initiative, etc.) than final.
	if round_field_count <= final_field_count:
		return { "ok": false, "error": "round_snapshot should have more fields than final (%d vs %d)" % [round_field_count, final_field_count] }

	return { "ok": true }


# Test 7 (UI-004): pre_combat_has_retreat_fields
# Setup: minimal pre_combat FlowContext (no config_service → defaults apply).
# Expected: build_round_snapshot returns data with retreat_eligible, retreat_ase_cost,
#           retreat_tier_label, retreat_success_pct keys.
static func _t_pre_combat_has_retreat_fields() -> Dictionary:
	var ctx: FlowContext = CombatSnapshotTests._make_pre_combat_ctx()
	var snap: Dictionary = FlowEncounterState.build_round_snapshot(ctx, 1)
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

	var snap: Dictionary = FlowEncounterState.build_round_snapshot(ctx, 1)
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

	var snap: Dictionary = FlowEncounterState.build_round_snapshot(ctx, 2)
	var action: Dictionary = snap.get("data", {}).get("last_actor_action", {})

	if str(action.get("action_type", "")) != "actor.move":
		return { "ok": false, "error": "Expected last_actor_action.action_type='actor.move', got %s" % str(action.get("action_type", "")) }
	if int(action.get("to_pos", {}).get("col", -1)) != 4:
		return { "ok": false, "error": "Expected last_actor_action.to_pos.col=4" }
	if int(action.get("to_pos", {}).get("row", -1)) != 3:
		return { "ok": false, "error": "Expected last_actor_action.to_pos.row=3" }

	return { "ok": true }

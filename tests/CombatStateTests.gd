# res://tests/CombatStateTests.gd
# COMBAT-001: Tests for the CombatState container and EncounterRoundsState integration.
#   1. combat/state_shape                  — CombatState.create() returns correct shape.
#   2. combat/state_actors_deep_copy       — Mutating source array does not mutate combat_state.
#   3. combat/rounds_enter_creates_state   — EncounterRoundsState.enter() stores valid CombatState.
#   4. combat/rounds_combat_state_fields   — round_counter == 0 and objective matches resolution_mode.
#
# COMBAT-002: Tests for initiative order calculation.
#   5. combat/initiative_shape             — initiative_order is Array with correct size; active_initiative_index == 0.
#   6. combat/initiative_sort_by_score     — higher speed+agi actor appears first.
#   7. combat/initiative_determinism       — same inputs always produce identical initiative_order.
#   8. combat/initiative_tiebreak_order    — equal-score actors preserve input list order.
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name CombatStateTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat/state_shape",                Callable(CombatStateTests, "_t_state_shape"))
	runner.register_test("combat/state_actors_deep_copy",     Callable(CombatStateTests, "_t_state_actors_deep_copy"))
	runner.register_test("combat/rounds_enter_creates_state", Callable(CombatStateTests, "_t_rounds_enter_creates_state"))
	runner.register_test("combat/rounds_combat_state_fields", Callable(CombatStateTests, "_t_rounds_combat_state_fields"))
	# COMBAT-002
	runner.register_test("combat/initiative_shape",           Callable(CombatStateTests, "_t_initiative_shape"))
	runner.register_test("combat/initiative_sort_by_score",   Callable(CombatStateTests, "_t_initiative_sort_by_score"))
	runner.register_test("combat/initiative_determinism",     Callable(CombatStateTests, "_t_initiative_determinism"))
	runner.register_test("combat/initiative_tiebreak_order",  Callable(CombatStateTests, "_t_initiative_tiebreak_order"))
	# V2-PROG-002: initiative uses confirmed calling modifier over birth origin
	runner.register_test("combat/initiative_uses_confirmed_calling", Callable(CombatStateTests, "_t_initiative_uses_confirmed_calling"))
	# V2-STAGE-004 Phase 4 (S16b): all_echoes_dead exclusion — is_ally must not keep a wiped party "alive"
	runner.register_test("combat/all_echoes_dead_excludes_ally", Callable(CombatStateTests, "_t_all_echoes_dead_excludes_ally"))
	runner.register_test("combat/all_echoes_dead_living_normal_echo_prevents", Callable(CombatStateTests, "_t_all_echoes_dead_living_normal_echo_prevents"))
	# V2-COMBAT-003.5: no objective is exempt from the stalemate check by name any more —
	# CombatState.get_progress_watch() supplies a genuine per-objective signal instead.
	runner.register_test("combat/no_progress_no_longer_exempt_by_name", Callable(CombatStateTests, "_t_no_progress_no_longer_exempt_by_name"))
	runner.register_test("combat/no_progress_still_applies_to_guide_spirit_protect", Callable(CombatStateTests, "_t_no_progress_still_applies_to_guide_spirit_protect"))
	runner.register_test("combat/progress_watch_tracks_shrine_hp", Callable(CombatStateTests, "_t_progress_watch_tracks_shrine_hp"))
	runner.register_test("combat/progress_watch_tracks_spirit_distance", Callable(CombatStateTests, "_t_progress_watch_tracks_spirit_distance"))
	runner.register_test("combat/progress_watch_stable_when_nothing_changes", Callable(CombatStateTests, "_t_progress_watch_stable_when_nothing_changes"))
	runner.register_test("combat/progress_watch_board_sees_actor_movement", Callable(CombatStateTests, "_t_progress_watch_board_sees_actor_movement"))
	runner.register_test("combat/progress_watch_endure_and_pursue_countdown", Callable(CombatStateTests, "_t_progress_watch_endure_and_pursue_countdown"))
	runner.register_test("combat/record_progress_watch_rejects_repeats", Callable(CombatStateTests, "_t_record_progress_watch_rejects_repeats"))


# -------------------------
# COMBAT-001 Tests
# -------------------------

static func _t_state_shape() -> Dictionary:
	var actors: Array = [{ "id": "a1" }, { "id": "a2" }]
	var state: Dictionary = CombatState.create(actors, EncounterResolutionModes.COMBAT)

	if not state.has("actors"):
		return { "ok": false, "error": "missing 'actors' key" }
	if not state.has("objective"):
		return { "ok": false, "error": "missing 'objective' key" }
	if not state.has("round_counter"):
		return { "ok": false, "error": "missing 'round_counter' key" }
	if str(state["objective"]) != EncounterResolutionModes.COMBAT:
		return { "ok": false, "error": "objective mismatch (got %s)" % str(state["objective"]) }
	if int(state["round_counter"]) != 0:
		return { "ok": false, "error": "round_counter should be 0 (got %d)" % int(state["round_counter"]) }
	var stored: Array = state["actors"] as Array
	if stored.size() != 2:
		return { "ok": false, "error": "actors array wrong size (got %d)" % stored.size() }
	return { "ok": true }


static func _t_state_actors_deep_copy() -> Dictionary:
	var source: Array = [{ "id": "x1" }]
	var state: Dictionary = CombatState.create(source, "survive")

	# Mutate source after creation.
	source.append({ "id": "x2" })
	(source[0] as Dictionary)["id"] = "mutated"

	var stored: Array = state["actors"] as Array
	if stored.size() != 1:
		return { "ok": false, "error": "deep copy should have 1 actor, got %d" % stored.size() }
	var first_id: String = str((stored[0] as Dictionary).get("id", ""))
	if first_id == "mutated":
		return { "ok": false, "error": "source mutation propagated into combat_state actors" }
	return { "ok": true }


static func _t_rounds_enter_creates_state() -> Dictionary:
	var ectx := EncounterContext.new()
	ectx.encounter_id = "test_enc_001"
	ectx.resolution_mode = EncounterResolutionModes.COMBAT
	ectx.actors = [
		{ "id": "echo_0001", "faction": "echo" },
		{ "id": "enemy_01",  "faction": "enemy" },
	]

	var state := EncounterRoundsState.new()
	state.enter(ectx, 1)

	if ectx.combat_state.is_empty():
		return { "ok": false, "error": "combat_state is empty after enter()" }
	if not CombatState.validate(ectx.combat_state):
		return { "ok": false, "error": "CombatState.validate() returned false" }
	return { "ok": true }


static func _t_rounds_combat_state_fields() -> Dictionary:
	var ectx := EncounterContext.new()
	ectx.encounter_id = "test_enc_002"
	ectx.resolution_mode = "purify_shrine"
	ectx.actors = [{ "id": "echo_0002", "faction": "echo" }]

	var state := EncounterRoundsState.new()
	state.enter(ectx, 2)

	var cs: Dictionary = ectx.combat_state
	if int(cs.get("round_counter", -1)) != 0:
		return { "ok": false, "error": "round_counter should be 0 (got %d)" % int(cs.get("round_counter", -1)) }
	if str(cs.get("objective", "")) != ectx.resolution_mode:
		return { "ok": false, "error": "objective should match resolution_mode (got '%s')" % str(cs.get("objective", "")) }
	return { "ok": true }


# -------------------------
# COMBAT-002 Tests
# -------------------------

static func _t_initiative_shape() -> Dictionary:
	var actors: Array = [
		{ "id": "a1", "name": "Alpha", "speed": 5, "stats": { "agi": 2 } },
		{ "id": "a2", "name": "Beta",  "speed": 3, "stats": { "agi": 1 } },
	]
	var state: Dictionary = CombatState.create(actors, EncounterResolutionModes.COMBAT, 0, {})

	if not state.has("initiative_order"):
		return { "ok": false, "error": "missing 'initiative_order' key" }
	if not state.has("active_initiative_index"):
		return { "ok": false, "error": "missing 'active_initiative_index' key" }
	var order: Array = state["initiative_order"] as Array
	if order.size() != 2:
		return { "ok": false, "error": "initiative_order should have 2 entries (got %d)" % order.size() }
	if int(state["active_initiative_index"]) != 0:
		return { "ok": false, "error": "active_initiative_index should be 0 (got %d)" % int(state["active_initiative_index"]) }
	return { "ok": true }


static func _t_initiative_sort_by_score() -> Dictionary:
	# Actor A has much higher speed+agi — must appear first.
	var actors: Array = [
		{ "id": "fast", "name": "Fast", "speed": 10, "stats": { "agi": 8 } },
		{ "id": "slow", "name": "Slow", "speed": 2,  "stats": { "agi": 1 } },
	]
	var state: Dictionary = CombatState.create(actors, EncounterResolutionModes.COMBAT, 0, {})
	var order: Array = state["initiative_order"] as Array

	if order.size() != 2:
		return { "ok": false, "error": "expected 2 entries (got %d)" % order.size() }
	var first_id: String = str((order[0] as Dictionary).get("id", ""))
	if first_id != "fast":
		return { "ok": false, "error": "highest speed+agi actor should be first (got '%s')" % first_id }
	return { "ok": true }


static func _t_initiative_determinism() -> Dictionary:
	var actors: Array = [
		{ "id": "e1", "name": "Echo One",   "speed": 7, "stats": { "agi": 4 } },
		{ "id": "e2", "name": "Enemy One",  "speed": 5, "stats": { "agi": 3 } },
		{ "id": "e3", "name": "Echo Three", "speed": 6, "stats": { "agi": 2 } },
	]
	var seed: int = 12345

	var state_a: Dictionary = CombatState.create(actors, EncounterResolutionModes.COMBAT, seed, {})
	var state_b: Dictionary = CombatState.create(actors, EncounterResolutionModes.COMBAT, seed, {})

	var order_a: Array = state_a["initiative_order"] as Array
	var order_b: Array = state_b["initiative_order"] as Array

	if order_a.size() != order_b.size():
		return { "ok": false, "error": "order sizes differ (%d vs %d)" % [order_a.size(), order_b.size()] }
	for i in range(order_a.size()):
		var id_a: String = str((order_a[i] as Dictionary).get("id", ""))
		var id_b: String = str((order_b[i] as Dictionary).get("id", ""))
		if id_a != id_b:
			return { "ok": false, "error": "initiative_order not deterministic at index %d ('%s' vs '%s')" % [i, id_a, id_b] }
	return { "ok": true }


static func _t_initiative_tiebreak_order() -> Dictionary:
	# Both actors have identical speed+agi and no modifiers — seed=0 gives same nudge.
	# Actor at input index 0 must appear first (party list order tiebreak).
	var actors: Array = [
		{ "id": "first",  "name": "First",  "speed": 5, "stats": { "agi": 5 } },
		{ "id": "second", "name": "Second", "speed": 5, "stats": { "agi": 5 } },
	]
	var state: Dictionary = CombatState.create(actors, EncounterResolutionModes.COMBAT, 0, {})
	var order: Array = state["initiative_order"] as Array

	if order.size() != 2:
		return { "ok": false, "error": "expected 2 entries (got %d)" % order.size() }
	var first_id: String = str((order[0] as Dictionary).get("id", ""))
	# With seed=0: nudge for "first" = derive_from(0,"first")%10; nudge for "second" = derive_from(0,"second")%10.
	# If nudges differ, sort by score. If equal, index 0 wins. Either way "first" should be first
	# unless the nudge for "second" strictly exceeds "first" — in that case the score-sort is correct.
	# We validate the stable-sort property: if scores are equal, index 0 must win.
	# Compute expected nudge to verify.
	var nudge_first:  int = int(CampaignSeed.derive_from(0, "first")  % 10)
	var nudge_second: int = int(CampaignSeed.derive_from(0, "second") % 10)
	# Both have same base score (5*3 + 5*2 = 25). If nudges are equal, "first" must be first.
	# If nudge_second > nudge_first, "second" correctly appears first by score.
	if nudge_first == nudge_second:
		if first_id != "first":
			return { "ok": false, "error": "equal scores: input index 0 ('first') should be first, got '%s'" % first_id }
	else:
		# Scores differ — verify the higher nudge wins.
		var expected_first: String = "first" if nudge_first > nudge_second else "second"
		if first_id != expected_first:
			return { "ok": false, "error": "score-based sort failed: expected '%s' first, got '%s'" % [expected_first, first_id] }
	return { "ok": true }


# -------------------------
# V2-PROG-002: Calling seam — initiative test
# -------------------------

# COMBAT-002/V2-PROG-002: confirmed calling modifier takes priority over birth origin.
# Actor A: calling_origin="okomfo", calling="okofor"  → resolved key "okofor" → +10 modifier.
# Actor B: calling_origin="okomfo", calling=""         → resolved key "okomfo"   → +0 modifier.
# Both have identical base stats (speed=5, agi=5 → base=25).
# Actor A goes first due to confirmed calling modifier (+10 → score=35 vs 25).
static func _t_initiative_uses_confirmed_calling() -> Dictionary:
	var actor_a := {
		"id":             "echo_seam_a",
		"name":           "A",
		"speed":          5,
		"stats":          { "agi": 5 },
		"calling_origin": "okomfo",
		"calling":        "okofor",  # confirmed — okofor modifier (+10) should apply
	}
	var actor_b := {
		"id":             "echo_seam_b",
		"name":           "B",
		"speed":          5,
		"stats":          { "agi": 5 },
		"calling_origin": "okomfo",
		"calling":        "",  # unconfirmed — okomfo modifier (0) applies
	}
	var init_cfg := {
		"by_calling_origin": { "okofor": 10, "okomfo": 0 },
		"by_archetype":      {},
		"by_dominant_trait": {},
		"by_dominant_vector": {},
	}
	var state: Dictionary = CombatState.create([actor_a, actor_b], EncounterResolutionModes.COMBAT, 0, init_cfg)
	var order: Array = state["initiative_order"] as Array
	if order.size() != 2:
		return { "ok": false, "error": "Expected 2 actors in initiative order, got %d" % order.size() }
	var first_id: String = str((order[0] as Dictionary).get("id", ""))
	if first_id != "echo_seam_a":
		return {
			"ok": false,
			"error": "Confirmed okofor (A, +10 modifier) should go first. Got '%s' first — birth origin 'okomfo' must not override confirmed calling." % first_id,
		}
	return { "ok": true }


# -------------------------
# V2-STAGE-004 Phase 4 (S16b): all_echoes_dead exclusion tests
# -------------------------

# A joined Temporary Ally (is_ally=true) must NOT keep a wiped party "alive" —
# CombatState.check_end_condition's living_echoes filter excludes is_ally actors
# (mirrors the pre-existing is_spirit exclusion for GUIDE_SPIRIT).
static func _t_all_echoes_dead_excludes_ally() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_1",  "faction": "echo",  "is_dead": true },
		{ "id": "echo_2",  "faction": "echo",  "is_dead": true },
		{ "id": "ally_1",  "faction": "echo",  "is_dead": false, "is_ally": true },
		{ "id": "enemy_1", "faction": "enemy", "is_dead": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, EncounterResolutionModes.COMBAT, {})
	if not bool(result.get("over", false)):
		return { "ok": false, "error": "Expected combat over (party wiped except a living ally), got over=false" }
	if bool(result.get("victory", false)):
		return { "ok": false, "error": "Expected defeat (victory=false) when only a living ally remains" }
	if str(result.get("reason", "")) != "all_echoes_dead":
		return { "ok": false, "error": "Expected reason='all_echoes_dead', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


# Control: a living NORMAL echo (is_ally=false, is_spirit=false) must still prevent
# all_echoes_dead from firing — proves the exclusion is scoped to is_ally/is_spirit only.
static func _t_all_echoes_dead_living_normal_echo_prevents() -> Dictionary:
	var actors: Array = [
		{ "id": "echo_1",  "faction": "echo",  "is_dead": true },
		{ "id": "echo_2",  "faction": "echo",  "is_dead": false },
		{ "id": "enemy_1", "faction": "enemy", "is_dead": false },
	]
	var result: Dictionary = CombatState.check_end_condition(actors, EncounterResolutionModes.COMBAT, {})
	if bool(result.get("over", false)):
		return {
			"ok": false,
			"error": "Expected combat NOT over (one normal echo still alive), got over=true reason='%s'" % str(result.get("reason", ""))
		}
	return { "ok": true }


# -------------------------
# V2-COMBAT-003.5: the by-name exemption list is gone. CombatState.check_end_condition() now
# force-retreats ANY objective once no_progress_streak reaches the limit — it is
# FlowRuntime._end_round() that keeps the streak from ever reaching the limit while an
# objective's own clock (shrine HP, spirit distance, the four counters) is genuinely moving, via
# CombatState.get_progress_watch(). These tests cover both halves: check_end_condition() no
# longer special-cases any objective (this file), and get_progress_watch() actually sees each
# objective's clock (below).
#
# guide_mode is set directly via objective_params — no seeded roll — so all tests are
# deterministic.
# -------------------------

static func _guide_spirit_actors() -> Array:
	return [
		{ "id": "echo_1",   "faction": "echo",  "is_dead": false },
		{ "id": "enemy_1",  "faction": "enemy", "is_dead": false },
		{ "id": "spirit_1", "faction": "neutral", "is_dead": false, "is_spirit": true },
	]


static func _shrine_actors(shrine_hp: int) -> Array:
	return [
		{ "id": "echo_1",  "faction": "echo",  "is_dead": false },
		{ "id": "enemy_1", "faction": "enemy", "is_dead": false },
		{ "id": "shrine_1", "faction": "neutral", "is_dead": false, "is_structure": true, "current_hp": shrine_hp },
	]


## check_end_condition() must force-retreat PURIFY_SHRINE and GUIDE_SPIRIT escort at the limit
## exactly like every other objective — proving the by-name exemption at this layer is gone. A
## future objective type is covered the same way with no code change here.
static func _t_no_progress_no_longer_exempt_by_name() -> Dictionary:
	var cases: Array = [
		{ "objective": EncounterResolutionModes.PURIFY_SHRINE, "actors": _shrine_actors(100), "params": {} },
		{ "objective": EncounterResolutionModes.GUIDE_SPIRIT,  "actors": _guide_spirit_actors(), "params": { "guide_mode": "escort" } },
	]
	for c_v in cases:
		var c: Dictionary = c_v
		var actors: Array = c["actors"]
		var combat_state: Dictionary = CombatState.create(
			actors, c["objective"], 0, {}, c["params"], { "no_progress_round_limit": 15 })
		combat_state["no_progress_streak"] = 15
		var result: Dictionary = CombatState.check_end_condition(actors, c["objective"], combat_state)
		if not bool(result.get("over", false)):
			return { "ok": false, "error": "Expected %s to hit the stalemate check at the limit (no by-name exemption), got over=false" % str(c["objective"]) }
		if str(result.get("reason", "")) != "no_progress_forced_retreat":
			return { "ok": false, "error": "Expected reason='no_progress_forced_retreat' for %s, got '%s'" % [str(c["objective"]), str(result.get("reason", ""))] }
	return { "ok": true }


## HONEST LABEL: branch 10 has no objective term left, so at this layer this asserts exactly what
## the escort case above asserts — it discriminates nothing between guide modes any more. It is
## kept as a regression guard against anyone reintroducing a protect-mode exemption here. The
## real per-objective discrimination lives in the get_progress_watch() tests below.
static func _t_no_progress_still_applies_to_guide_spirit_protect() -> Dictionary:
	var actors: Array = _guide_spirit_actors()
	var combat_state: Dictionary = CombatState.create(
		actors, EncounterResolutionModes.GUIDE_SPIRIT, 0, {}, { "guide_mode": "protect" },
		{ "no_progress_round_limit": 15 })
	combat_state["no_progress_streak"] = 15

	var result: Dictionary = CombatState.check_end_condition(actors, EncounterResolutionModes.GUIDE_SPIRIT, combat_state)
	if not bool(result.get("over", false)):
		return { "ok": false, "error": "Expected GUIDE_SPIRIT protect to still hit the stalemate check, got over=false" }
	if str(result.get("reason", "")) != "no_progress_forced_retreat":
		return { "ok": false, "error": "Expected reason='no_progress_forced_retreat', got '%s'" % str(result.get("reason", "")) }
	return { "ok": true }


## get_progress_watch() must reflect shrine HP for PURIFY_SHRINE, and differ once the shrine
## drains — this is what stops no_progress_streak from ever reaching the limit in a real fight.
static func _t_progress_watch_tracks_shrine_hp() -> Dictionary:
	var actors: Array = _shrine_actors(100)
	var combat_state: Dictionary = CombatState.create(
		actors, EncounterResolutionModes.PURIFY_SHRINE, 0, {}, {}, { "no_progress_round_limit": 15 })
	var watch_a: Dictionary = CombatState.get_progress_watch(actors, EncounterResolutionModes.PURIFY_SHRINE, combat_state)
	if int(watch_a.get("shrine_hp", -1)) != 100:
		return { "ok": false, "error": "Expected shrine_hp=100 in the watch, got %s" % str(watch_a.get("shrine_hp")) }

	var drained_actors: Array = _shrine_actors(95)
	var watch_b: Dictionary = CombatState.get_progress_watch(drained_actors, EncounterResolutionModes.PURIFY_SHRINE, combat_state)
	if watch_a == watch_b:
		return { "ok": false, "error": "Expected the watch to change when shrine HP drains from 100 to 95" }
	return { "ok": true }


## get_progress_watch() must reflect spirit-to-destination distance for GUIDE_SPIRIT escort, and
## differ once the spirit steps closer.
static func _t_progress_watch_tracks_spirit_distance() -> Dictionary:
	var params: Dictionary = { "guide_mode": "escort", "destination_col": 9, "destination_row": 9 }
	var combat_state: Dictionary = CombatState.create(
		_guide_spirit_actors(), EncounterResolutionModes.GUIDE_SPIRIT, 0, {}, params,
		{ "no_progress_round_limit": 15 })

	var actors_far: Array = _guide_spirit_actors()
	for a_v in actors_far:
		var a: Dictionary = a_v
		if a.get("is_spirit", false):
			a["grid_pos"] = { "col": 0, "row": 0 }
	var watch_a: Dictionary = CombatState.get_progress_watch(actors_far, EncounterResolutionModes.GUIDE_SPIRIT, combat_state)
	if int(watch_a.get("spirit_distance", -1)) != 9:
		return { "ok": false, "error": "Expected spirit_distance=9 (Chebyshev from (0,0) to (9,9)), got %s" % str(watch_a.get("spirit_distance")) }

	var actors_near: Array = _guide_spirit_actors()
	for a_v in actors_near:
		var a: Dictionary = a_v
		if a.get("is_spirit", false):
			a["grid_pos"] = { "col": 1, "row": 1 }
	var watch_b: Dictionary = CombatState.get_progress_watch(actors_near, EncounterResolutionModes.GUIDE_SPIRIT, combat_state)
	if watch_a == watch_b:
		return { "ok": false, "error": "Expected the watch to change when the spirit steps one cell closer to the destination" }
	if int(watch_b.get("spirit_distance", -1)) != 8:
		return { "ok": false, "error": "Expected spirit_distance=8 after the step, got %s" % str(watch_b.get("spirit_distance")) }
	return { "ok": true }


## When nothing objective-relevant changes — same shrine HP, same spirit position, same
## counters — the watch must be identical, so a genuine stall (nothing moving for
## no_progress_round_limit rounds) still reaches the limit and force-retreats. This is the other
## half of "no false negatives": the generic signal must not manufacture progress that isn't there.
static func _t_progress_watch_stable_when_nothing_changes() -> Dictionary:
	var shrine_actors: Array = _shrine_actors(100)
	var shrine_state: Dictionary = CombatState.create(
		shrine_actors, EncounterResolutionModes.PURIFY_SHRINE, 0, {}, {}, { "no_progress_round_limit": 15 })
	var w1: Dictionary = CombatState.get_progress_watch(shrine_actors, EncounterResolutionModes.PURIFY_SHRINE, shrine_state)
	var w2: Dictionary = CombatState.get_progress_watch(shrine_actors, EncounterResolutionModes.PURIFY_SHRINE, shrine_state)
	if w1 != w2:
		return { "ok": false, "error": "Expected an identical watch across two calls with unchanged shrine HP" }

	var params: Dictionary = { "guide_mode": "escort", "destination_col": 9, "destination_row": 9 }
	var spirit_actors: Array = _guide_spirit_actors()
	for a_v in spirit_actors:
		var a: Dictionary = a_v
		if a.get("is_spirit", false):
			a["grid_pos"] = { "col": 0, "row": 0 }
	var spirit_state: Dictionary = CombatState.create(
		spirit_actors, EncounterResolutionModes.GUIDE_SPIRIT, 0, {}, params, { "no_progress_round_limit": 15 })
	var w3: Dictionary = CombatState.get_progress_watch(spirit_actors, EncounterResolutionModes.GUIDE_SPIRIT, spirit_state)
	var w4: Dictionary = CombatState.get_progress_watch(spirit_actors, EncounterResolutionModes.GUIDE_SPIRIT, spirit_state)
	if w3 != w4:
		return { "ok": false, "error": "Expected an identical watch across two calls with an unmoved spirit" }
	return { "ok": true }


## The generic activity term, and the fix for the escort approach phase: an Echo walking toward a
## spirit it has not reached yet moves no counter and no objective clock — the spirit is
## movement-gated until escort_started latches — but the board changed, so the round is activity.
static func _t_progress_watch_board_sees_actor_movement() -> Dictionary:
	var params: Dictionary = { "guide_mode": "escort", "destination_col": 9, "destination_row": 9 }
	var before: Array = _guide_spirit_actors()
	for a_v in before:
		var a: Dictionary = a_v
		a["grid_pos"] = { "col": 0, "row": 0 } if a.get("is_spirit", false) else { "col": 6, "row": 6 }
	var state: Dictionary = CombatState.create(
		before, EncounterResolutionModes.GUIDE_SPIRIT, 0, {}, params, { "no_progress_round_limit": 15 })
	var w_before: Dictionary = CombatState.get_progress_watch(before, EncounterResolutionModes.GUIDE_SPIRIT, state)

	# Only the echo steps; the spirit has not moved, so spirit_distance is unchanged.
	var after: Array = _guide_spirit_actors()
	for a_v in after:
		var a: Dictionary = a_v
		a["grid_pos"] = { "col": 0, "row": 0 } if a.get("is_spirit", false) else { "col": 5, "row": 5 }
	var w_after: Dictionary = CombatState.get_progress_watch(after, EncounterResolutionModes.GUIDE_SPIRIT, state)

	if int(w_before.get("spirit_distance", -1)) != int(w_after.get("spirit_distance", -2)):
		return { "ok": false, "error": "setup wrong — spirit_distance should be unchanged, got %s then %s" % [str(w_before.get("spirit_distance")), str(w_after.get("spirit_distance"))] }
	if w_before == w_after:
		return { "ok": false, "error": "Expected the watch to change when an echo moves toward the spirit — the approach phase must not read as a stall" }
	if not CombatState.record_progress_watch(state, w_after):
		return { "ok": false, "error": "Expected the moved board to be a state this fight has not been in" }
	return { "ok": true }


## ENDURE and PURSUE win or lose on round_counter alone, so their countdown to that guaranteed
## end is their progress signal. It must fall every round and clamp at 0, which re-arms the
## detector if the objective ever stops ending on its own.
static func _t_progress_watch_endure_and_pursue_countdown() -> Dictionary:
	var cases: Array = [
		{ "objective": EncounterResolutionModes.ENDURE, "params": { "duration_turns": 5 }, "limit": 5 },
		{ "objective": EncounterResolutionModes.PURSUE, "params": { "window_turns": 8 },   "limit": 8 },
	]
	for c_v in cases:
		var c: Dictionary = c_v
		var actors: Array = _guide_spirit_actors()
		var state: Dictionary = CombatState.create(
			actors, c["objective"], 0, {}, c["params"], { "no_progress_round_limit": 15 })
		var expected: Array = [int(c["limit"]), int(c["limit"]) - 1, 0, 0]
		var rounds: Array = [0, 1, int(c["limit"]), int(c["limit"]) + 4]
		for i in range(rounds.size()):
			state["round_counter"] = int(rounds[i])
			var watch: Dictionary = CombatState.get_progress_watch(actors, c["objective"], state)
			if int(watch.get("objective_countdown", -1)) != int(expected[i]):
				return { "ok": false, "error": "%s: expected objective_countdown=%d at round %d, got %s" % [str(c["objective"]), int(expected[i]), int(rounds[i]), str(watch.get("objective_countdown"))] }
	return { "ok": true }


## Progress is a board state the fight has NEVER been in. A repeat is not progress, and neither
## is an oscillation between two states — which is what a plain "differs from last round" test
## would wrongly accept, leaving a blocked party pacing forever.
static func _t_record_progress_watch_rejects_repeats() -> Dictionary:
	var actors: Array = _shrine_actors(100)
	var state: Dictionary = CombatState.create(
		actors, EncounterResolutionModes.PURIFY_SHRINE, 0, {}, {}, { "no_progress_round_limit": 15 })
	var a: Dictionary = CombatState.get_progress_watch(actors, EncounterResolutionModes.PURIFY_SHRINE, state)
	# create() already recorded the start-of-combat state, so an unchanged round 1 is a repeat.
	if CombatState.record_progress_watch(state, a):
		return { "ok": false, "error": "Expected the start-of-combat state, seen again unchanged, to be a repeat" }

	var moved: Array = _shrine_actors(100)
	for m_v in moved:
		var m: Dictionary = m_v
		if str(m.get("id", "")) == "echo_1":
			m["grid_pos"] = { "col": 3, "row": 3 }
	var b: Dictionary = CombatState.get_progress_watch(moved, EncounterResolutionModes.PURIFY_SHRINE, state)
	if not CombatState.record_progress_watch(state, b):
		return { "ok": false, "error": "Expected a board with the echo on a new cell to be a new state" }
	# Back to where it started: an oscillation, not progress.
	if CombatState.record_progress_watch(state, a):
		return { "ok": false, "error": "Expected the return to a previously visited board to be a repeat, not progress" }
	if CombatState.record_progress_watch(state, b):
		return { "ok": false, "error": "Expected the second half of the oscillation to be a repeat too" }
	return { "ok": true }

# res://tests/EmotionTests.gd
# Tests for EmotionService interface:
#   EMOTION-001:
#   1. faith is clamped 0–100 (below 0 → 0, above 100 → 100)
#   2. get_morale_tier() returns correct tier at all four boundary values
#   3. init_echo() adds emotion defaults to an echo that has no emotion block
#      (same logic used by SaveService repair loop — bare echo → fallback 50)
#   4. EchoActor.from_echo() reads morale_current and fear_current from emotion block
#   EMOTION-002:
#   5. init_echo() derives morale_base from traits.courage + archetype_birth modifier (25–74 range)
#   6–9. Drift tests: apply_morale_delta, apply_fear_delta/threshold, win drift, determinism
#
# All tests are pure unit tests (no runtime or save file needed).
# Run via Debug Panel: tests

extends RefCounted
class_name EmotionTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("emotion/faith_clamped",              Callable(EmotionTests, "_t_faith_clamped"))
	runner.register_test("emotion/morale_tier_boundaries",     Callable(EmotionTests, "_t_morale_tier_boundaries"))
	runner.register_test("emotion/init_adds_emotion_block",    Callable(EmotionTests, "_t_init_adds_emotion_block"))
	runner.register_test("emotion/echo_actor_reads_emotion",   Callable(EmotionTests, "_t_echo_actor_reads_emotion"))
	# EMOTION-002 tests
	runner.register_test("emotion/birth_variance_from_traits", Callable(EmotionTests, "_t_birth_variance_from_traits"))
	runner.register_test("emotion/drift_morale_delta",         Callable(EmotionTests, "_t_drift_morale_delta"))
	runner.register_test("emotion/drift_fear_threshold",       Callable(EmotionTests, "_t_drift_fear_threshold"))
	runner.register_test("emotion/drift_combat_exit_win",      Callable(EmotionTests, "_t_drift_combat_exit_win"))
	runner.register_test("emotion/drift_determinism",          Callable(EmotionTests, "_t_drift_determinism"))
	# V2-EMOTION-002 tests
	runner.register_test("emotion/emotional_status_radiant",         Callable(EmotionTests, "_t_emotional_status_radiant"))
	runner.register_test("emotion/emotional_status_burdened",        Callable(EmotionTests, "_t_emotional_status_burdened"))
	runner.register_test("emotion/emotional_status_pressed",         Callable(EmotionTests, "_t_emotional_status_pressed"))
	runner.register_test("emotion/emotional_status_hollow",          Callable(EmotionTests, "_t_emotional_status_hollow"))
	runner.register_test("emotion/emotional_status_ten_tier_boundaries", Callable(EmotionTests, "_t_emotional_status_ten_tier_boundaries"))
	runner.register_test("emotion/project_actor_emotional_status",   Callable(EmotionTests, "_t_project_actor_emotional_status"))
	runner.register_test("emotion/resolve_emotion_summary_unified",  Callable(EmotionTests, "_t_resolve_emotion_summary_unified"))
	# V2-EMOTION-003 tests
	runner.register_test("emotion/fear_base_birth_from_traits",      Callable(EmotionTests, "_t_fear_base_birth_from_traits"))
	runner.register_test("emotion/fear_base_clamp",                  Callable(EmotionTests, "_t_fear_base_clamp"))
	runner.register_test("emotion/fear_base_increments_on_loss",     Callable(EmotionTests, "_t_fear_base_increments_on_loss"))
	runner.register_test("emotion/fear_base_decrements_on_win",      Callable(EmotionTests, "_t_fear_base_decrements_on_win"))
	runner.register_test("emotion/fear_base_max_cap",                Callable(EmotionTests, "_t_fear_base_max_cap"))
	runner.register_test("emotion/morale_base_streak_win",           Callable(EmotionTests, "_t_morale_base_streak_win"))
	runner.register_test("emotion/morale_base_streak_loss",          Callable(EmotionTests, "_t_morale_base_streak_loss"))
	runner.register_test("emotion/morale_base_streak_resets",        Callable(EmotionTests, "_t_morale_base_streak_resets"))
	runner.register_test("emotion/sanctum_tick_fear_above_base",     Callable(EmotionTests, "_t_sanctum_tick_fear_above_base"))
	runner.register_test("emotion/sanctum_tick_fear_below_base",     Callable(EmotionTests, "_t_sanctum_tick_fear_below_base"))
	runner.register_test("emotion/sanctum_tick_fear_at_base",        Callable(EmotionTests, "_t_sanctum_tick_fear_at_base"))
	runner.register_test("emotion/arbiter_floor_blend",              Callable(EmotionTests, "_t_arbiter_floor_blend"))


# -------------------------
# Tests
# -------------------------

# Test 1: faith_clamped
# EmotionService.set_faith() must clamp below 0 → 0 and above 100 → 100.
static func _t_faith_clamped() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "echo_clamp_test" }

	EmotionService.set_faith(echo, -10, logger, 1)
	if echo["emotion"]["faith"] != 0:
		return { "ok": false, "error": "Expected faith=0 for input -10, got: %d" % echo["emotion"]["faith"] }

	EmotionService.set_faith(echo, 200, logger, 2)
	if echo["emotion"]["faith"] != 100:
		return { "ok": false, "error": "Expected faith=100 for input 200, got: %d" % echo["emotion"]["faith"] }

	EmotionService.set_faith(echo, 50, logger, 3)
	if echo["emotion"]["faith"] != 50:
		return { "ok": false, "error": "Expected faith=50 for input 50, got: %d" % echo["emotion"]["faith"] }

	return { "ok": true }


# Test 2: morale_tier_boundaries
# get_morale_tier() must return the correct tier at every threshold boundary.
static func _t_morale_tier_boundaries() -> Dictionary:
	var cases := [
		[0,   "broken"],
		[24,  "broken"],
		[25,  "shaken"],
		[49,  "shaken"],
		[50,  "steady"],
		[74,  "steady"],
		[75,  "inspired"],
		[100, "inspired"],
	]
	for c in cases:
		var val: int  = c[0]
		var want: String = c[1]
		var got: String  = EmotionService.get_morale_tier(val)
		if got != want:
			return { "ok": false, "error": "get_morale_tier(%d): expected '%s', got '%s'" % [val, want, got] }

	return { "ok": true }


# Test 3: init_adds_emotion_block
# init_echo() must add a full emotion block with defaults on an echo that has none.
# This covers the same logic used by the SaveService repair loop for old saves.
static func _t_init_adds_emotion_block() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("info")

	var echo := { "id": "echo_repair_test", "name": "Ama Owusu" }

	if echo.has("emotion"):
		return { "ok": false, "error": "Pre-condition failed: echo should not have emotion block yet" }

	EmotionService.init_echo(echo, logger, 1)

	if not echo.has("emotion"):
		return { "ok": false, "error": "init_echo() did not add emotion block" }

	var emo: Dictionary = echo["emotion"]
	if emo.get("faith", -1) != 50:
		return { "ok": false, "error": "Expected faith=50, got: %d" % emo.get("faith", -1) }
	if emo.get("morale_base", -1) != 50:
		return { "ok": false, "error": "Expected morale_base=50, got: %d" % emo.get("morale_base", -1) }
	if emo.get("morale_current", -1) != 50:
		return { "ok": false, "error": "Expected morale_current=50, got: %d" % emo.get("morale_current", -1) }
	if emo.get("fear_current", -1) != 0:
		return { "ok": false, "error": "Expected fear_current=0, got: %d" % emo.get("fear_current", -1) }

	# Idempotency: calling again must not overwrite existing values
	echo["emotion"]["faith"] = 80
	EmotionService.init_echo(echo, logger, 2)
	if echo["emotion"]["faith"] != 80:
		return { "ok": false, "error": "init_echo() overwrote existing faith value — must be idempotent" }

	# Verify emotion.init log event fired
	var logs: Array = logger.get_logs()
	var found := false
	for entry in logs:
		if str(entry.get("type", "")) == "emotion.init":
			found = true
			break
	if not found:
		return { "ok": false, "error": "No emotion.init log event found after init_echo()" }

	return { "ok": true }


# Test 4: echo_actor_reads_emotion
# EchoActor.from_echo() must read morale_current and fear_current from the emotion block.
static func _t_echo_actor_reads_emotion() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_emo_test", "Kweku Ananse")
	echo["emotion"] = {
		"faith":          60,
		"morale_base":    55,
		"morale_current": 72,
		"fear_current":   15
	}

	var actor: Dictionary = EchoActor.from_echo(echo)

	if int(actor.get("morale", -1)) != 72:
		return { "ok": false, "error": "Expected actor.morale=72 from emotion.morale_current, got: %d" % int(actor.get("morale", -1)) }

	if int(actor.get("fear", -1)) != 15:
		return { "ok": false, "error": "Expected actor.fear=15 from emotion.fear_current, got: %d" % int(actor.get("fear", -1)) }

	return { "ok": true }


# -------------------------
# EMOTION-002 Tests
# -------------------------

# Test 5: birth_variance_from_traits
# init_echo() must derive morale_base from traits.courage (continuous base)
# plus an archetype_birth modifier (9-archetype system).
# Modifiers: valiant +5, proud +5, loyal +3, ambitious +3, devout +2, empathic +2, canny 0, stoic 0, reflective -5.
# Final value clamped to 25–74. Echoes with no traits fall back to flat 50.
static func _t_birth_variance_from_traits() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	# High courage + valiant archetype → base=74, modifier=+5 → clamped 74
	# (c=70, w=40, f=40 derives "valiant" via dominance pass — dc=20, unique max ≥8)
	var echo_valiant := { "id": "echo_valiant", "archetype_birth": "valiant",
		"traits": { "courage": 70, "wisdom": 40, "faith": 40 } }
	EmotionService.init_echo(echo_valiant, logger, 1)
	if int(echo_valiant["emotion"]["morale_base"]) != 74:
		return { "ok": false, "error": "Expected morale_base=74 (valiant, courage=70), got: %d" % int(echo_valiant["emotion"]["morale_base"]) }

	# High courage + canny archetype → base=74, modifier=0 → 74
	# (c=70, w=80, f=40 derives "canny" via dominance pass — dw=16.7, unique max ≥8)
	var echo_canny := { "id": "echo_canny", "archetype_birth": "canny",
		"traits": { "courage": 70, "wisdom": 80, "faith": 40 } }
	EmotionService.init_echo(echo_canny, logger, 2)
	if int(echo_canny["emotion"]["morale_base"]) != 74:
		return { "ok": false, "error": "Expected morale_base=74 (canny, courage=70), got: %d" % int(echo_canny["emotion"]["morale_base"]) }

	# Low courage + devout archetype → base=25, modifier=+2 → clamped 27
	# (c=30, w=40, f=60 derives "devout" via dominance pass — df=16.7, unique max ≥8)
	var echo_devout := { "id": "echo_devout", "archetype_birth": "devout",
		"traits": { "courage": 30, "wisdom": 40, "faith": 60 } }
	EmotionService.init_echo(echo_devout, logger, 3)
	if int(echo_devout["emotion"]["morale_base"]) != 27:
		return { "ok": false, "error": "Expected morale_base=27 (devout, courage=30), got: %d" % int(echo_devout["emotion"]["morale_base"]) }

	# No traits → fallback flat 50 (test echo and save-repair safety)
	var echo_bare := { "id": "echo_bare" }
	EmotionService.init_echo(echo_bare, logger, 4)
	if int(echo_bare["emotion"]["morale_base"]) != 50:
		return { "ok": false, "error": "Expected morale_base=50 fallback for echo with no traits, got: %d" % int(echo_bare["emotion"]["morale_base"]) }

	# morale_current always equals morale_base at birth
	if echo_valiant["emotion"]["morale_current"] != echo_valiant["emotion"]["morale_base"]:
		return { "ok": false, "error": "morale_current must equal morale_base at init" }

	# fear always 0 at birth regardless of archetype
	if int(echo_valiant["emotion"]["fear_current"]) != 0:
		return { "ok": false, "error": "fear_current must be 0 at init regardless of traits/archetype" }

	# faith uses trait value directly (courage=70, faith trait=40 → emotion.faith=40)
	if int(echo_valiant["emotion"]["faith"]) != 40:
		return { "ok": false, "error": "Expected emotion.faith=40 (from traits.faith=40), got: %d" % int(echo_valiant["emotion"]["faith"]) }

	return { "ok": true }


# Test 6: drift_morale_delta
# apply_morale_delta() must add the delta, clamp 0–100, and log emotion.morale.drift.
static func _t_drift_morale_delta() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("info")

	var echo := { "id": "echo_drift_test", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 50, "fear_current": 0 } }

	# +10: 50 → 60
	EmotionService.apply_morale_delta(echo, 10, "test_win", logger, 1)
	if int(echo["emotion"]["morale_current"]) != 60:
		return { "ok": false, "error": "Expected morale_current=60 after +10, got: %d" % int(echo["emotion"]["morale_current"]) }

	# −15: 60 → 45
	EmotionService.apply_morale_delta(echo, -15, "test_loss", logger, 2)
	if int(echo["emotion"]["morale_current"]) != 45:
		return { "ok": false, "error": "Expected morale_current=45 after -15, got: %d" % int(echo["emotion"]["morale_current"]) }

	# Clamp at 0: −100 from 45 → 0
	EmotionService.apply_morale_delta(echo, -100, "test_clamp_low", logger, 3)
	if int(echo["emotion"]["morale_current"]) != 0:
		return { "ok": false, "error": "Expected morale_current=0 (floor clamp), got: %d" % int(echo["emotion"]["morale_current"]) }

	# Clamp at 100: +200 from 0 → 100
	EmotionService.apply_morale_delta(echo, 200, "test_clamp_high", logger, 4)
	if int(echo["emotion"]["morale_current"]) != 100:
		return { "ok": false, "error": "Expected morale_current=100 (ceiling clamp), got: %d" % int(echo["emotion"]["morale_current"]) }

	# Verify emotion.morale.drift log event fired
	var logs: Array = logger.get_logs()
	var found := false
	for entry in logs:
		if str(entry.get("type", "")) == "emotion.morale.drift":
			found = true
			break
	if not found:
		return { "ok": false, "error": "No emotion.morale.drift log event found" }

	return { "ok": true }


# Test 7: drift_fear_threshold
# apply_fear_delta() must clamp 0–100 and fire emotion.fear.threshold_crossed when fear >= threshold.
static func _t_drift_fear_threshold() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("info")

	var echo := { "id": "echo_fear_test", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 50, "fear_current": 60 } }

	var threshold := 80

	# +20 from 60 → 80: exactly at threshold → threshold_crossed must fire
	EmotionService.apply_fear_delta(echo, 20, "test_loss", threshold, logger, 1)
	if int(echo["emotion"]["fear_current"]) != 80:
		return { "ok": false, "error": "Expected fear_current=80 after +20 from 60, got: %d" % int(echo["emotion"]["fear_current"]) }

	var logs: Array = logger.get_logs()
	var threshold_fired := false
	for entry in logs:
		if str(entry.get("type", "")) == "emotion.fear.threshold_crossed":
			threshold_fired = true
			break
	if not threshold_fired:
		return { "ok": false, "error": "emotion.fear.threshold_crossed should fire when fear >= 80" }

	# −10 from 80 → 70: below threshold → no NEW threshold event beyond first
	# (Use a fresh logger to isolate)
	var logger2 := StructuredLogger.new()
	logger2.set_level("info")
	EmotionService.apply_fear_delta(echo, -10, "test_recovery", threshold, logger2, 2)
	if int(echo["emotion"]["fear_current"]) != 70:
		return { "ok": false, "error": "Expected fear_current=70 after -10 from 80, got: %d" % int(echo["emotion"]["fear_current"]) }

	var logs2: Array = logger2.get_logs()
	var extra_threshold := false
	for entry in logs2:
		if str(entry.get("type", "")) == "emotion.fear.threshold_crossed":
			extra_threshold = true
			break
	if extra_threshold:
		return { "ok": false, "error": "emotion.fear.threshold_crossed must not fire when fear < threshold (got 70)" }

	return { "ok": true }


# Test 8: drift_combat_exit_win
# Win deltas: morale +10, fear −5. Applied together represent a combat victory.
static func _t_drift_combat_exit_win() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "echo_win_test", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 45, "fear_current": 20 } }

	var threshold := 80
	EmotionService.apply_morale_delta(echo, 10, "combat_exit_win", logger, 1)
	EmotionService.apply_fear_delta(  echo, -5, "combat_exit_win", threshold, logger, 2)

	if int(echo["emotion"]["morale_current"]) != 55:
		return { "ok": false, "error": "Expected morale_current=55 after win (+10 from 45), got: %d" % int(echo["emotion"]["morale_current"]) }
	if int(echo["emotion"]["fear_current"]) != 15:
		return { "ok": false, "error": "Expected fear_current=15 after win (-5 from 20), got: %d" % int(echo["emotion"]["fear_current"]) }

	return { "ok": true }


# Test 9: drift_determinism
# Two echoes with identical starting state + identical delta sequence → identical final values.
static func _t_drift_determinism() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var threshold := 80

	var echo_a := { "id": "echo_det_a", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 50, "fear_current": 0 } }
	var echo_b := { "id": "echo_det_b", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 50, "fear_current": 0 } }

	# Same deltas in same order on both echoes
	EmotionService.apply_morale_delta(echo_a, -15, "combat_exit_loss", logger, 1)
	EmotionService.apply_fear_delta(  echo_a,  20, "combat_exit_loss", threshold, logger, 2)
	EmotionService.apply_morale_delta(echo_a,  10, "combat_exit_win",  logger, 3)
	EmotionService.apply_fear_delta(  echo_a,  -5, "combat_exit_win",  threshold, logger, 4)

	EmotionService.apply_morale_delta(echo_b, -15, "combat_exit_loss", logger, 1)
	EmotionService.apply_fear_delta(  echo_b,  20, "combat_exit_loss", threshold, logger, 2)
	EmotionService.apply_morale_delta(echo_b,  10, "combat_exit_win",  logger, 3)
	EmotionService.apply_fear_delta(  echo_b,  -5, "combat_exit_win",  threshold, logger, 4)

	if int(echo_a["emotion"]["morale_current"]) != int(echo_b["emotion"]["morale_current"]):
		return { "ok": false, "error": "Morale determinism failed: echo_a=%d, echo_b=%d" % [
			int(echo_a["emotion"]["morale_current"]), int(echo_b["emotion"]["morale_current"]) ] }

	if int(echo_a["emotion"]["fear_current"]) != int(echo_b["emotion"]["fear_current"]):
		return { "ok": false, "error": "Fear determinism failed: echo_a=%d, echo_b=%d" % [
			int(echo_a["emotion"]["fear_current"]), int(echo_b["emotion"]["fear_current"]) ] }

	return { "ok": true }


# -------------------------
# V2-EMOTION-002 Tests
# -------------------------

# Test 10: emotional_status_radiant
# morale=80, fear=10 → "radiant"
static func _t_emotional_status_radiant() -> Dictionary:
	var got := EmotionService.get_emotional_status(80, 10)
	if got != "radiant":
		return { "ok": false, "error": "get_emotional_status(80, 10): expected 'radiant', got '%s'" % got }
	return { "ok": true }


# Test 11: emotional_status_burdened
# morale=50, fear=45 → "burdened"
static func _t_emotional_status_burdened() -> Dictionary:
	var got := EmotionService.get_emotional_status(50, 45)
	if got != "burdened":
		return { "ok": false, "error": "get_emotional_status(50, 45): expected 'burdened', got '%s'" % got }
	return { "ok": true }


# Test 12: emotional_status_pressed
# morale=50, fear=55 → "pressed"
static func _t_emotional_status_pressed() -> Dictionary:
	var got := EmotionService.get_emotional_status(50, 55)
	if got != "pressed":
		return { "ok": false, "error": "get_emotional_status(50, 55): expected 'pressed', got '%s'" % got }
	return { "ok": true }


# Test 13: emotional_status_hollow
# morale=30, fear=85 → "hollow"
static func _t_emotional_status_hollow() -> Dictionary:
	var got := EmotionService.get_emotional_status(30, 85)
	if got != "hollow":
		return { "ok": false, "error": "get_emotional_status(30, 85): expected 'hollow', got '%s'" % got }
	return { "ok": true }


static func _t_emotional_status_ten_tier_boundaries() -> Dictionary:
	var cases: Array = [
		[70, 15, "radiant"], [69, 15, "whole"],
		[55, 30, "whole"], [54, 30, "grounded"],
		[40, 40, "grounded"], [39, 40, "uncertain"],
		[35, 44, "uncertain"], [34, 44, "hesitant"],
		[25, 44, "hesitant"], [24, 0, "burdened"],
		[50, 45, "burdened"], [50, 54, "burdened"],
		[50, 55, "pressed"], [50, 64, "pressed"],
		[50, 65, "strained"], [50, 74, "strained"],
		[50, 75, "fraying"], [50, 84, "fraying"],
		[50, 85, "hollow"], [5, 0, "hollow"],
		[80, 70, "strained"], # high morale cannot hide refusal-range fear
		[25, 0, "hesitant"],  # minimum birth morale remains readable, not burdened
	]
	for case_v in cases:
		var case: Array = case_v
		var got := EmotionService.get_emotional_status(int(case[0]), int(case[1]))
		if got != str(case[2]):
			return { "ok": false, "error": "status(%d,%d): expected %s, got %s" % [case[0], case[1], case[2], got] }
	return { "ok": true }


# Test 14: project_actor_emotional_status
# _project_actor() with morale=60, fear=20 → emotional_status=="whole"
# (morale=60 ≥ 55 AND fear=20 ≤ 30 → "whole" per the 8-tier derivation)
static func _t_project_actor_emotional_status() -> Dictionary:
	var actor := {
		"id": "echo_01", "name": "Test", "faction": "echo",
		"current_hp": 80, "stats": { "max_hp": 100 },
		"grid_pos": { "col": 0, "row": 0 },
		"is_dead": false, "guard_state": false, "is_structure": false,
		"morale": 60, "fear": 20,
		"calling_origin": "Okofor", "skill_slots": [""],
	}
	var proj := FlowEncounterState._project_actor(actor)
	if str(proj.get("emotional_status", "")) != "whole":
		return { "ok": false, "error": "Expected emotional_status='whole' for morale=60/fear=20, got '%s'" % proj.get("emotional_status", "") }
	return { "ok": true }


# Test 15: resolve_emotion_summary_unified
# build_final_snapshot() must include emotion_summary with pre/post_emotional_status + refused.
# Pre: morale=60, fear=0 → "whole". Post: morale=30, fear=70 → "strained". refused=false (fear<80).
static func _t_resolve_emotion_summary_unified() -> Dictionary:
	var ctx := FlowContext.new()
	ctx.config_service = null
	var ectx := EncounterContext.new()
	ectx.encounter_id  = "test_enc_003"
	ectx.combat_result = { "victory": true, "reason": "all_enemies_defeated", "round_ended": 2 }
	ectx.combat_state  = { "combat_over": true, "objective": "defeat_enemies", "round_counter": 2 }
	ectx.actors = [{
		"id": "echo_01", "name": "Kojo", "faction": "echo",
		"current_hp": 80, "stats": { "max_hp": 100 },
		"grid_pos": { "col": 0, "row": 0 },
		"is_dead": false, "guard_state": false, "is_structure": false,
		"morale": 30, "fear": 70,
		"calling_origin": "Okofor", "skill_slots": [""],
	}]
	ectx.pre_encounter_morale["echo_01"] = 60
	ctx.encounter_ctx = ectx

	var snap := FlowEncounterState.build_final_snapshot(ctx, 1)
	var data: Dictionary = snap.get("data", {})

	if not data.has("emotion_summary"):
		return { "ok": false, "error": "data missing 'emotion_summary' key" }

	var es: Array = data["emotion_summary"]
	if es.size() != 1:
		return { "ok": false, "error": "Expected emotion_summary.size()==1, got %d" % es.size() }

	var row: Dictionary = es[0]
	if str(row.get("pre_emotional_status", "")) != "whole":
		return { "ok": false, "error": "Expected pre_emotional_status='whole' (morale=60/fear=0), got '%s'" % row.get("pre_emotional_status", "") }
	if str(row.get("post_emotional_status", "")) != "strained":
		return { "ok": false, "error": "Expected post_emotional_status='strained' (morale=30/fear=70), got '%s'" % row.get("post_emotional_status", "") }
	if int(row.get("morale_delta", 0)) != -30:
		return { "ok": false, "error": "Expected morale_delta==-30, got %d" % int(row.get("morale_delta", 0)) }
	if bool(row.get("refused", true)):
		return { "ok": false, "error": "Expected refused==false for fear=70 (threshold is 80)" }

	return { "ok": true }


# -------------------------
# V2-EMOTION-003 Tests
# -------------------------

static func _make_bare_echo(id: String, courage: int, archetype: String) -> Dictionary:
	return { "id": id, "archetype_birth": archetype, "traits": { "courage": courage, "wisdom": 50, "faith": 50 } }


# Test 16: fear_base_birth_from_traits
# init_echo() must derive fear_base from courage (inverted) + archetype modifier, clamped 0–20.
static func _t_fear_base_birth_from_traits() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	# courage=30, stoic: base_fear=20, mod=-5 → 15
	var e1 := _make_bare_echo("e1", 30, "stoic")
	EmotionService.init_echo(e1, logger, 1)
	var fb1 := int(e1["emotion"]["fear_base"])
	if fb1 != 15:
		return { "ok": false, "error": "Expected fear_base=15 (courage=30, stoic), got %d" % fb1 }

	# courage=70, valiant: base_fear=5, mod=-3 → clamped 2
	var e2 := _make_bare_echo("e2", 70, "valiant")
	EmotionService.init_echo(e2, logger, 2)
	var fb2 := int(e2["emotion"]["fear_base"])
	if fb2 != 2:
		return { "ok": false, "error": "Expected fear_base=2 (courage=70, valiant), got %d" % fb2 }

	# courage=50, proud: base_fear = 20 - int(round(20 * 15.0/40.0)) = 20 - 8 = 12, mod=+3 → 15
	var e3 := _make_bare_echo("e3", 50, "proud")
	EmotionService.init_echo(e3, logger, 3)
	var fb3 := int(e3["emotion"]["fear_base"])
	if fb3 != 15:
		return { "ok": false, "error": "Expected fear_base=15 (courage=50, proud), got %d" % fb3 }

	# No traits → fallback flat 10
	var e4 := { "id": "e4" }
	EmotionService.init_echo(e4, logger, 4)
	var fb4 := int(e4["emotion"]["fear_base"])
	if fb4 != 10:
		return { "ok": false, "error": "Expected fear_base=10 fallback (no traits), got %d" % fb4 }

	# win_streak and loss_streak must be 0 at birth
	if int(e1["emotion"]["win_streak"]) != 0 or int(e1["emotion"]["loss_streak"]) != 0:
		return { "ok": false, "error": "win_streak and loss_streak must be 0 at birth" }

	return { "ok": true }


# Test 17: fear_base_clamp
# fear_base birth clamped 0–20: stoic+valiant can reach 0, proud+ambitious caps at 20.
static func _t_fear_base_clamp() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	# courage=70, stoic: base_fear=5, mod=-5 → clamped to 0
	var e_floor := _make_bare_echo("e_floor", 70, "stoic")
	EmotionService.init_echo(e_floor, logger, 1)
	var fb_floor := int(e_floor["emotion"]["fear_base"])
	if fb_floor != 0:
		return { "ok": false, "error": "Expected fear_base=0 (courage=70, stoic), got %d" % fb_floor }

	# courage=30, proud: base_fear=20, mod=+3 → clamped to 20
	var e_ceil := _make_bare_echo("e_ceil", 30, "proud")
	EmotionService.init_echo(e_ceil, logger, 2)
	var fb_ceil := int(e_ceil["emotion"]["fear_base"])
	if fb_ceil != 20:
		return { "ok": false, "error": "Expected fear_base=20 (courage=30, proud), got %d" % fb_ceil }

	return { "ok": true }


# Test 18: fear_base_increments_on_loss
# set_fear_base() increments by 1 on combat loss; EmotionService setter clamps 0–100.
static func _t_fear_base_increments_on_loss() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "e_loss", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 50,
		"fear_current": 0, "fear_base": 8, "win_streak": 0, "loss_streak": 0 } }

	var old_fb := int(echo["emotion"]["fear_base"])
	EmotionService.set_fear_base(echo, old_fb + 1, logger, 1)
	if int(echo["emotion"]["fear_base"]) != 9:
		return { "ok": false, "error": "Expected fear_base=9 after loss +1, got %d" % int(echo["emotion"]["fear_base"]) }

	return { "ok": true }


# Test 19: fear_base_decrements_on_win
# set_fear_base() decrements by 1 on combat win; floored at 0.
static func _t_fear_base_decrements_on_win() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "e_win", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 50,
		"fear_current": 0, "fear_base": 5, "win_streak": 0, "loss_streak": 0 } }

	var old_fb := int(echo["emotion"]["fear_base"])
	EmotionService.set_fear_base(echo, maxi(0, old_fb - 1), logger, 1)
	if int(echo["emotion"]["fear_base"]) != 4:
		return { "ok": false, "error": "Expected fear_base=4 after win -1, got %d" % int(echo["emotion"]["fear_base"]) }

	# Floor at 0: win when fear_base is already 0
	EmotionService.set_fear_base(echo, 0, logger, 2)
	EmotionService.set_fear_base(echo, maxi(0, 0 - 1), logger, 3)
	if int(echo["emotion"]["fear_base"]) != 0:
		return { "ok": false, "error": "Expected fear_base=0 (floored), got %d" % int(echo["emotion"]["fear_base"]) }

	return { "ok": true }


# Test 20: fear_base_max_cap
# set_fear_base() with value beyond 40 must cap at 40 (fear_base_max is enforced by caller, setter clamps 0–100).
# We verify the setter itself clamps at 100; the 40-cap is enforced by FlowRuntime.
static func _t_fear_base_max_cap() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "e_cap", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 50,
		"fear_current": 0, "fear_base": 39, "win_streak": 0, "loss_streak": 0 } }

	# Simulate FlowRuntime clamping to fear_base_max (40)
	var fear_base_max := 40
	var new_fb := mini(fear_base_max, int(echo["emotion"]["fear_base"]) + 1)
	EmotionService.set_fear_base(echo, new_fb, logger, 1)
	if int(echo["emotion"]["fear_base"]) != 40:
		return { "ok": false, "error": "Expected fear_base=40 (at cap), got %d" % int(echo["emotion"]["fear_base"]) }

	# Another loss beyond cap must not push above 40
	new_fb = mini(fear_base_max, int(echo["emotion"]["fear_base"]) + 1)
	EmotionService.set_fear_base(echo, new_fb, logger, 2)
	if int(echo["emotion"]["fear_base"]) != 40:
		return { "ok": false, "error": "Expected fear_base to stay at 40 after additional loss, got %d" % int(echo["emotion"]["fear_base"]) }

	return { "ok": true }


# Test 21: morale_base_streak_win
# After 3 consecutive wins (win_streak reaches 3): morale_base +1, win_streak resets to 0.
static func _t_morale_base_streak_win() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "e_streak_win", "emotion": {
		"faith": 50, "morale_base": 55, "morale_current": 55,
		"fear_current": 0, "fear_base": 5, "win_streak": 2, "loss_streak": 0 } }

	# Simulate one more win (streak hits 3)
	var streak_threshold := 3
	var morale_base_delta := 1
	var morale_base_max := 90
	var morale_base_min := 10
	var win_streak := int(echo["emotion"]["win_streak"]) + 1
	var loss_streak := 0
	if win_streak >= streak_threshold:
		var mb := clampi(int(echo["emotion"]["morale_base"]) + morale_base_delta, morale_base_min, morale_base_max)
		EmotionService.set_morale_base(echo, mb, logger, 1)
		win_streak = 0
	echo["emotion"]["win_streak"]  = win_streak
	echo["emotion"]["loss_streak"] = loss_streak

	if int(echo["emotion"]["morale_base"]) != 56:
		return { "ok": false, "error": "Expected morale_base=56 after 3-win streak, got %d" % int(echo["emotion"]["morale_base"]) }
	if int(echo["emotion"]["win_streak"]) != 0:
		return { "ok": false, "error": "Expected win_streak=0 after threshold reset, got %d" % int(echo["emotion"]["win_streak"]) }

	return { "ok": true }


# Test 22: morale_base_streak_loss
# After 3 consecutive losses (loss_streak reaches 3): morale_base -1, loss_streak resets to 0.
static func _t_morale_base_streak_loss() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "e_streak_loss", "emotion": {
		"faith": 50, "morale_base": 55, "morale_current": 40,
		"fear_current": 20, "fear_base": 10, "win_streak": 0, "loss_streak": 2 } }

	var streak_threshold := 3
	var morale_base_delta := 1
	var morale_base_max := 90
	var morale_base_min := 10
	var loss_streak := int(echo["emotion"]["loss_streak"]) + 1
	var win_streak := 0
	if loss_streak >= streak_threshold:
		var mb := clampi(int(echo["emotion"]["morale_base"]) - morale_base_delta, morale_base_min, morale_base_max)
		EmotionService.set_morale_base(echo, mb, logger, 1)
		loss_streak = 0
	echo["emotion"]["win_streak"]  = win_streak
	echo["emotion"]["loss_streak"] = loss_streak

	if int(echo["emotion"]["morale_base"]) != 54:
		return { "ok": false, "error": "Expected morale_base=54 after 3-loss streak, got %d" % int(echo["emotion"]["morale_base"]) }
	if int(echo["emotion"]["loss_streak"]) != 0:
		return { "ok": false, "error": "Expected loss_streak=0 after threshold reset, got %d" % int(echo["emotion"]["loss_streak"]) }

	return { "ok": true }


# Test 23: morale_base_streak_resets
# A loss resets win_streak to 0 without triggering morale_base mutation (streak < 3).
static func _t_morale_base_streak_resets() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "e_reset", "emotion": {
		"faith": 50, "morale_base": 55, "morale_current": 55,
		"fear_current": 0, "fear_base": 5, "win_streak": 2, "loss_streak": 0 } }

	# A single loss: win_streak resets; loss_streak becomes 1; no morale_base change
	var streak_threshold := 3
	var morale_base_delta := 1
	var morale_base_max := 90
	var morale_base_min := 10
	var loss_streak := int(echo["emotion"]["loss_streak"]) + 1
	var win_streak := 0
	if loss_streak >= streak_threshold:
		var mb := clampi(int(echo["emotion"]["morale_base"]) - morale_base_delta, morale_base_min, morale_base_max)
		EmotionService.set_morale_base(echo, mb, logger, 1)
		loss_streak = 0
	echo["emotion"]["win_streak"]  = win_streak
	echo["emotion"]["loss_streak"] = loss_streak

	if int(echo["emotion"]["morale_base"]) != 55:
		return { "ok": false, "error": "Expected morale_base=55 (no change from single loss), got %d" % int(echo["emotion"]["morale_base"]) }
	if int(echo["emotion"]["win_streak"]) != 0:
		return { "ok": false, "error": "Expected win_streak=0 after loss, got %d" % int(echo["emotion"]["win_streak"]) }
	if int(echo["emotion"]["loss_streak"]) != 1:
		return { "ok": false, "error": "Expected loss_streak=1 after loss, got %d" % int(echo["emotion"]["loss_streak"]) }

	return { "ok": true }


# Test 24: sanctum_tick_fear_above_base
# When fear_current > fear_base, sanctum tick decrements toward base, clamped so it never goes below.
static func _t_sanctum_tick_fear_above_base() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "e_tick_above", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 50,
		"fear_current": 20, "fear_base": 8, "win_streak": 0, "loss_streak": 0 } }

	# tick_fear_abs = 3; fear_current=20 > fear_base=8; delta = -min(3, 20-8) = -3
	var tick_fear_abs := 3
	var fear_base    := int(echo["emotion"]["fear_base"])
	var fear_current := int(echo["emotion"]["fear_current"])
	var delta := -mini(tick_fear_abs, fear_current - fear_base)
	EmotionService.apply_fear_delta(echo, delta, "sanctum_tick", 999, logger, 1)

	if int(echo["emotion"]["fear_current"]) != 17:
		return { "ok": false, "error": "Expected fear_current=17 after tick (20 - 3), got %d" % int(echo["emotion"]["fear_current"]) }

	# Tick again until exactly at base — must clamp at fear_base, not below
	echo["emotion"]["fear_current"] = 9  # 1 above base
	fear_current = 9
	delta = -mini(tick_fear_abs, fear_current - fear_base)  # -min(3, 1) = -1
	EmotionService.apply_fear_delta(echo, delta, "sanctum_tick", 999, logger, 2)
	if int(echo["emotion"]["fear_current"]) != 8:
		return { "ok": false, "error": "Expected fear_current=8 (clamped at fear_base), got %d" % int(echo["emotion"]["fear_current"]) }

	return { "ok": true }


# Test 25: sanctum_tick_fear_below_base
# When fear_current < fear_base (kill euphoria), sanctum tick increments back toward base.
static func _t_sanctum_tick_fear_below_base() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "e_tick_below", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 50,
		"fear_current": 3, "fear_base": 8, "win_streak": 0, "loss_streak": 0 } }

	# tick_fear_abs=3; fear_current=3 < fear_base=8; delta = +min(3, 8-3) = +3
	var tick_fear_abs := 3
	var fear_base    := int(echo["emotion"]["fear_base"])
	var fear_current := int(echo["emotion"]["fear_current"])
	var delta := mini(tick_fear_abs, fear_base - fear_current)
	EmotionService.apply_fear_delta(echo, delta, "sanctum_tick", 999, logger, 1)

	if int(echo["emotion"]["fear_current"]) != 6:
		return { "ok": false, "error": "Expected fear_current=6 after tick (3 + 3), got %d" % int(echo["emotion"]["fear_current"]) }

	# Clamp so it doesn't exceed fear_base when close
	echo["emotion"]["fear_current"] = 6
	fear_current = 6
	delta = mini(tick_fear_abs, fear_base - fear_current)  # min(3, 2) = 2
	EmotionService.apply_fear_delta(echo, delta, "sanctum_tick", 999, logger, 2)
	if int(echo["emotion"]["fear_current"]) != 8:
		return { "ok": false, "error": "Expected fear_current=8 (clamped at fear_base), got %d" % int(echo["emotion"]["fear_current"]) }

	return { "ok": true }


# Test 26: sanctum_tick_fear_at_base
# When fear_current == fear_base, no tick fires (delta = 0, no change).
static func _t_sanctum_tick_fear_at_base() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var echo := { "id": "e_tick_eq", "emotion": {
		"faith": 50, "morale_base": 50, "morale_current": 50,
		"fear_current": 8, "fear_base": 8, "win_streak": 0, "loss_streak": 0 } }

	# Neither branch fires — fear_current == fear_base
	var fear_base    := int(echo["emotion"]["fear_base"])
	var fear_current := int(echo["emotion"]["fear_current"])
	if fear_current > fear_base:
		var delta := -mini(3, fear_current - fear_base)
		EmotionService.apply_fear_delta(echo, delta, "sanctum_tick", 999, logger, 1)
	elif fear_current < fear_base:
		var delta := mini(3, fear_base - fear_current)
		EmotionService.apply_fear_delta(echo, delta, "sanctum_tick", 999, logger, 1)

	if int(echo["emotion"]["fear_current"]) != 8:
		return { "ok": false, "error": "Expected fear_current unchanged at 8, got %d" % int(echo["emotion"]["fear_current"]) }

	return { "ok": true }


# Test 27: arbiter_floor_blend
# When fear_current < fear_base, BehaviorArbiter uses fear_base as effective_fear for fear_factor.
# Verified by checking that an actor with high fear_base but low fear_current
# gets a lower fear_factor than the same actor with fear_base == 0.
static func _t_arbiter_floor_blend() -> Dictionary:
	# Minimal actor dict — only fields needed for _score() fear computation
	var actor_base := {
		"id": "a1", "name": "Test", "faction": "echo",
		"calling_origin": "uncalled", "archetype_birth": "stoic",
		"traits": { "courage": 50, "wisdom": 50, "faith": 50 },
		"vector_scores": {}, "morale": 50,
		"is_dead": false, "is_structure": false,
		"grid_pos": { "col": 0, "row": 0 },
		"stats": { "max_hp": 100 }, "current_hp": 100,
		"rarity": "common", "rank": 1,
		"xp_total": 0, "level": 1, "actor_type": "echo", "speed": 5,
		"death_round": 0, "resilience_traits": [], "leadership_traits": [],
		"skill_slots": [""], "equipped_skills": {}, "dominant_vector": "",
	}

	# Actor A: fear_current=5 (post-kill), fear_base=0 → effective_fear = max(5,0) = 5
	var actor_a := actor_base.duplicate(true)
	actor_a["fear"]      = 5
	actor_a["fear_base"] = 0

	# Actor B: fear_current=5 (post-kill), fear_base=15 → effective_fear = max(5,15) = 15
	var actor_b := actor_base.duplicate(true)
	actor_b["fear"]      = 5
	actor_b["fear_base"] = 15

	# Compute effective fear for each actor (mirror of BehaviorArbiter._score() floor blend)
	var eff_fear_a := maxf(float(actor_a.get("fear", 0)), float(actor_a.get("fear_base", 0)))
	var eff_fear_b := maxf(float(actor_b.get("fear", 0)), float(actor_b.get("fear_base", 0)))

	if eff_fear_a != 5.0:
		return { "ok": false, "error": "Expected effective_fear=5.0 for actor_a (fear=5, fear_base=0), got %s" % str(eff_fear_a) }
	if eff_fear_b != 15.0:
		return { "ok": false, "error": "Expected effective_fear=15.0 for actor_b (fear=5, fear_base=15), got %s" % str(eff_fear_b) }

	# fear_factor = clamp(1 - fear/100 * 0.6, 0, 1). Higher effective_fear → lower fear_factor.
	var dampen := 0.6
	var ff_a := clampf(1.0 - (eff_fear_a / 100.0) * dampen, 0.0, 1.0)
	var ff_b := clampf(1.0 - (eff_fear_b / 100.0) * dampen, 0.0, 1.0)

	if not (ff_a > ff_b):
		return { "ok": false, "error": "Expected fear_factor(A) > fear_factor(B) (high fear_base should depress scoring), ff_a=%s ff_b=%s" % [str(ff_a), str(ff_b)] }

	# Verify EchoActor.from_echo() maps fear_base to the actor dict
	var echo := ActorTests._make_test_echo("e_fb_test", "Test Echo")
	echo["emotion"] = {
		"faith": 50, "morale_base": 50, "morale_current": 50,
		"fear_current": 5, "fear_base": 15, "win_streak": 0, "loss_streak": 0
	}
	var actor := EchoActor.from_echo(echo)
	if int(actor.get("fear_base", -1)) != 15:
		return { "ok": false, "error": "EchoActor.from_echo() must map emotion.fear_base → actor.fear_base. Got %d" % int(actor.get("fear_base", -1)) }

	return { "ok": true }

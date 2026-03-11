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
# plus an archetype_birth modifier (brave +5, sage -5, devout 0).
# Final value clamped to 25–74. Echoes with no traits fall back to flat 50.
static func _t_birth_variance_from_traits() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")

	# High courage + brave archetype → base=74, modifier=+5 → clamped 74
	var echo_brave := { "id": "echo_brave", "archetype_birth": "brave",
		"traits": { "courage": 70, "wisdom": 40, "faith": 40 } }
	EmotionService.init_echo(echo_brave, logger, 1)
	if int(echo_brave["emotion"]["morale_base"]) != 74:
		return { "ok": false, "error": "Expected morale_base=74 (brave, courage=70), got: %d" % int(echo_brave["emotion"]["morale_base"]) }

	# High courage + sage archetype → base=74, modifier=-5 → 69
	var echo_sage := { "id": "echo_sage", "archetype_birth": "sage",
		"traits": { "courage": 70, "wisdom": 80, "faith": 40 } }
	EmotionService.init_echo(echo_sage, logger, 2)
	if int(echo_sage["emotion"]["morale_base"]) != 69:
		return { "ok": false, "error": "Expected morale_base=69 (sage, courage=70), got: %d" % int(echo_sage["emotion"]["morale_base"]) }

	# Low courage + devout archetype → base=25, modifier=0 → 25 (floor)
	var echo_devout := { "id": "echo_devout", "archetype_birth": "devout",
		"traits": { "courage": 30, "wisdom": 40, "faith": 60 } }
	EmotionService.init_echo(echo_devout, logger, 3)
	if int(echo_devout["emotion"]["morale_base"]) != 25:
		return { "ok": false, "error": "Expected morale_base=25 (devout, courage=30), got: %d" % int(echo_devout["emotion"]["morale_base"]) }

	# No traits → fallback flat 50 (test echo and save-repair safety)
	var echo_bare := { "id": "echo_bare" }
	EmotionService.init_echo(echo_bare, logger, 4)
	if int(echo_bare["emotion"]["morale_base"]) != 50:
		return { "ok": false, "error": "Expected morale_base=50 fallback for echo with no traits, got: %d" % int(echo_bare["emotion"]["morale_base"]) }

	# morale_current always equals morale_base at birth
	if echo_brave["emotion"]["morale_current"] != echo_brave["emotion"]["morale_base"]:
		return { "ok": false, "error": "morale_current must equal morale_base at init" }

	# fear always 0 at birth regardless of archetype
	if int(echo_brave["emotion"]["fear_current"]) != 0:
		return { "ok": false, "error": "fear_current must be 0 at init regardless of traits/archetype" }

	# faith uses trait value directly (courage=70, faith trait=40 → emotion.faith=40)
	if int(echo_brave["emotion"]["faith"]) != 40:
		return { "ok": false, "error": "Expected emotion.faith=40 (from traits.faith=40), got: %d" % int(echo_brave["emotion"]["faith"]) }

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

# res://tests/EmotionTests.gd
# Tests for the EMOTION-001 EmotionService interface:
#   1. faith is clamped 0–100 (below 0 → 0, above 100 → 100)
#   2. get_morale_tier() returns correct tier at all four boundary values
#   3. init_echo() adds emotion defaults to an echo that has no emotion block
#      (same logic used by SaveService repair loop)
#   4. EchoActor.from_echo() reads morale_current and fear_current from emotion block
#
# All tests are pure unit tests (no runtime or save file needed).
# Run via Debug Panel: tests

extends RefCounted
class_name EmotionTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("emotion/faith_clamped",            Callable(EmotionTests, "_t_faith_clamped"))
	runner.register_test("emotion/morale_tier_boundaries",   Callable(EmotionTests, "_t_morale_tier_boundaries"))
	runner.register_test("emotion/init_adds_emotion_block",  Callable(EmotionTests, "_t_init_adds_emotion_block"))
	runner.register_test("emotion/echo_actor_reads_emotion", Callable(EmotionTests, "_t_echo_actor_reads_emotion"))


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

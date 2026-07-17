class_name VoiceTests
# V2-VOICE-001: Tests for the bark/voice system.
# Covers: reactive bark queue, ShoutBank variation, sanctum bark context selection.

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("voice/reactive_bark_fires_forming", Callable(VoiceTests, "_test_reactive_bark_fires_forming"))
	runner.register_test("voice/reactive_bark_silent_nascent", Callable(VoiceTests, "_test_reactive_bark_silent_nascent"))
	runner.register_test("voice/reactive_bark_deterministic", Callable(VoiceTests, "_test_reactive_bark_deterministic"))
	runner.register_test("voice/shoutbank_variation_deterministic", Callable(VoiceTests, "_test_shoutbank_variation_deterministic"))
	runner.register_test("voice/sanctum_bark_context_victory_defeat", Callable(VoiceTests, "_test_sanctum_bark_context"))
	runner.register_test("voice/legacy_fallback_tolerates_array_traits", Callable(VoiceTests, "_test_legacy_fallback_tolerates_array_traits"))


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_echo_actor(id: String, arch: String, calling: String, faction: String,
		fear: int, morale: int, band: String, col: int = 0, row: int = 0) -> Dictionary:
	return {
		"id":              id,
		"name":            "Echo_" + id,
		"faction":         faction,
		"archetype_birth": arch,
		"calling_origin":  calling,
		"expression_band": band,
		"fear":            fear,
		"morale":          morale,
		"grid_pos":        { "col": col, "row": row },
		"is_dead":         false,
		"is_structure":    false,
	}


static func _make_actor_cfg() -> Dictionary:
	# Minimal cfg that ActorStateMachine can work with.
	return {
		"max_hp":         20,
		"base_attack":    3,
		"base_defense":   2,
		"base_speed":     3,
		"base_morale":    50,
		"base_fear_threshold": 80,
		"traits":         [],
		"calling_origin": "",
		"skill_slots":    [""],
	}


# ── Test 1: reactive bark fires for forming+ band ──────────────────────────────

## Verify that a forming-band echo reacts to a same-faction high-signal bark in round_bark_events.
static func _test_reactive_bark_fires_forming() -> Dictionary:
	var actor := _make_echo_actor("e1", "loyal", "okofor", "echo", 10, 60, "forming", 2, 2)
	var context := {
		"actor":            actor,
		"all_actors":       [actor],
		"board_cfg":        { "cols": 10, "rows": 10 },
		"cfg":              { "data": { "voice": { "reactive_range": 4, "reactive_min_expression_band": "forming" } } },
		"t":                42,
		"round":            1,
		"purifier_id":      "",
		"is_purifier":      false,
		"shrine_alive":     false,
		"shrine_hp_ratio":  0.0,
		"prefer_objective_target": false,
		"active_vow":       {},
		"party_size":       1,
		"bonds":            [],
		"bond_thresholds":  {},
		"bond_behavior_cfg": {},
		# High-signal bark in same faction, within range.
		"round_bark_events": [
			{
				"actor_id":     "ally1",
				"faction":      "echo",
				"bark_context": "combat_last_stand",
				"grid_pos":     { "col": 3, "row": 2 },
			}
		],
	}

	var asm := ActorStateMachine.new(actor, null, _make_actor_cfg())
	asm._expression_band = "forming"  # Must be set manually when calling outside advance_turn()
	asm._check_reactive_bark(context, 42)

	if not asm._bark_is_response:
		return { "ok": false, "error": "Expected _bark_is_response = true for forming band with high-signal ally bark" }
	if asm._bark_context != "combat_rally_ally":
		return { "ok": false, "error": "Expected bark_context = 'combat_rally_ally', got '%s'" % asm._bark_context }

	return { "ok": true }


# ── Test 2: reactive bark silent for nascent band ─────────────────────────────

## Nascent-band actors do NOT react to ally barks (not expressive enough).
static func _test_reactive_bark_silent_nascent() -> Dictionary:
	var actor := _make_echo_actor("e2", "watchful", "kra_soro", "echo", 10, 60, "nascent", 2, 2)
	var context := {
		"actor":            actor,
		"all_actors":       [actor],
		"board_cfg":        { "cols": 10, "rows": 10 },
		"cfg":              { "data": { "voice": { "reactive_range": 4 } } },
		"t":                10,
		"round":            1,
		"purifier_id":      "",
		"is_purifier":      false,
		"shrine_alive":     false,
		"shrine_hp_ratio":  0.0,
		"prefer_objective_target": false,
		"active_vow":       {},
		"party_size":       1,
		"bonds":            [],
		"bond_thresholds":  {},
		"bond_behavior_cfg": {},
		"round_bark_events": [
			{
				"actor_id":     "ally1",
				"faction":      "echo",
				"bark_context": "combat_fear_extreme",
				"grid_pos":     { "col": 1, "row": 1 },
			}
		],
	}

	var asm := ActorStateMachine.new(actor, null, _make_actor_cfg())
	asm._check_reactive_bark(context, 10)

	if asm._bark_is_response:
		return { "ok": false, "error": "Nascent actor should NOT react to ally bark (is_response must be false)" }

	return { "ok": true }


# ── Test 3: reactive bark is deterministic ────────────────────────────────────

## Same inputs → same bark line every time (no RNG, deterministic variation_key).
static func _test_reactive_bark_deterministic() -> Dictionary:
	var actor := _make_echo_actor("e3", "loyal", "onyamesu", "echo", 5, 70, "grounded", 1, 1)
	var context := {
		"actor":            actor,
		"all_actors":       [actor],
		"board_cfg":        { "cols": 10, "rows": 10 },
		"cfg":              { "data": { "voice": { "reactive_range": 4 } } },
		"t":                55,
		"round":            2,
		"purifier_id":      "",
		"is_purifier":      false,
		"shrine_alive":     false,
		"shrine_hp_ratio":  0.0,
		"prefer_objective_target": false,
		"active_vow":       {},
		"party_size":       2,
		"bonds":            [],
		"bond_thresholds":  {},
		"bond_behavior_cfg": {},
		"round_bark_events": [
			{
				"actor_id":     "ally2",
				"faction":      "echo",
				"bark_context": "combat_taunt",
				"grid_pos":     { "col": 2, "row": 1 },
			}
		],
	}

	var asm1 := ActorStateMachine.new(actor.duplicate(true), null, _make_actor_cfg())
	asm1._expression_band = "grounded"  # Must be set manually when calling outside advance_turn()
	asm1._check_reactive_bark(context, 55)
	var line1 := asm1._bark_line

	var asm2 := ActorStateMachine.new(actor.duplicate(true), null, _make_actor_cfg())
	asm2._expression_band = "grounded"  # Must be set manually when calling outside advance_turn()
	asm2._check_reactive_bark(context, 55)
	var line2 := asm2._bark_line

	if line1 != line2:
		return { "ok": false, "error": "Reactive bark not deterministic: '%s' vs '%s'" % [line1, line2] }
	if line1.is_empty():
		return { "ok": false, "error": "Expected non-empty reactive bark line for grounded actor" }

	return { "ok": true }


# ── Test 4: ShoutBank variation is deterministic ──────────────────────────────

## Same variation_key → same line; different key → may differ (for array entries).
static func _test_shoutbank_variation_deterministic() -> Dictionary:
	var line_a1 := ShoutBank.get_expression_shout("combat_attack", "loyal", "grounded", "", 0)
	var line_a2 := ShoutBank.get_expression_shout("combat_attack", "loyal", "grounded", "", 0)
	if line_a1 != line_a2:
		return { "ok": false, "error": "Same variation_key should produce same line: '%s' vs '%s'" % [line_a1, line_a2] }
	if line_a1.is_empty():
		return { "ok": false, "error": "Expected non-empty line for combat_attack/loyal/grounded" }

	# Variation key 0 vs 1 should produce different lines if the data has >= 2 entries.
	var line_b0 := ShoutBank.get_expression_shout("combat_attack", "loyal", "grounded", "", 0)
	var line_b1 := ShoutBank.get_expression_shout("combat_attack", "loyal", "grounded", "", 1)
	# We can't guarantee they differ (could be same if only 1 line), just verify no crash.
	if line_b0.is_empty() or line_b1.is_empty():
		return { "ok": false, "error": "get_expression_shout returned empty for variation keys 0 or 1" }

	return { "ok": true }


# ── Regression: malformed legacy traits must not crash bark fallback ────────────────

## Some legacy integration fixtures carry traits as an Array. The actor contract
## requires a Dictionary, but bark selection must remain silent instead of emitting
## an Array.get() arity error when the expression lookup reaches its legacy fallback.
static func _test_legacy_fallback_tolerates_array_traits() -> Dictionary:
	var actor := _make_echo_actor("legacy", "missing_archetype", "", "echo", 10, 50, "nascent")
	actor["traits"] = []
	var asm := ActorStateMachine.new(actor, null, _make_actor_cfg())
	asm._expression_band = "nascent"
	asm._select_bark("missing_archetype", "", "actor.guard", 10, 10,
		"steady", "steady", false, false, "", 0, 0)

	if asm._bark_context != "combat_banter":
		return { "ok": false, "error": "Expected combat_banter context, got '%s'" % asm._bark_context }
	return { "ok": true }


# ── Test 5: sanctum bark context — victory vs defeat ──────────────────────────

## Victory → "sanctum.arrival_victory"; defeat → "sanctum.arrival_defeat".
static func _test_sanctum_bark_context() -> Dictionary:
	var arch := "loyal"
	var band := "nascent"
	var calling := ""
	var vk := 0

	var vline := ShoutBank.get_expression_shout("sanctum.arrival_victory", arch, band, calling, vk)
	var dline := ShoutBank.get_expression_shout("sanctum.arrival_defeat", arch, band, calling, vk)

	if vline.is_empty():
		return { "ok": false, "error": "Expected non-empty sanctum.arrival_victory line" }
	if dline.is_empty():
		return { "ok": false, "error": "Expected non-empty sanctum.arrival_defeat line" }
	# Lines should differ between victory and defeat contexts.
	if vline == dline:
		return { "ok": false, "error": "Victory and defeat bark contexts returned identical lines — possible data issue" }

	return { "ok": true }

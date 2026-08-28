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
	runner.register_test("voice/bark_budget_caps_at_authored_max", Callable(VoiceTests, "_test_bark_budget_caps_at_authored_max"))
	runner.register_test("voice/bark_budget_boundary_three_and_four", Callable(VoiceTests, "_test_bark_budget_boundary_three_and_four"))
	runner.register_test("voice/bark_budget_prefers_higher_tier", Callable(VoiceTests, "_test_bark_budget_prefers_higher_tier"))
	runner.register_test("voice/bark_budget_unknown_context_takes_lowest_tier", Callable(VoiceTests, "_test_bark_budget_unknown_context_takes_lowest_tier"))
	runner.register_test("voice/bark_budget_reactions_ride_above_cap", Callable(VoiceTests, "_test_bark_budget_reactions_ride_above_cap"))
	runner.register_test("voice/bark_budget_reactions_inside_cap_when_configured", Callable(VoiceTests, "_test_bark_budget_reactions_inside_cap_when_configured"))
	runner.register_test("voice/bark_budget_is_deterministic", Callable(VoiceTests, "_test_bark_budget_is_deterministic"))
	runner.register_test("voice/bark_budget_is_wired_into_round_snapshot", Callable(VoiceTests, "_test_bark_budget_is_wired_into_round_snapshot"))


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


# ── D03: the data.voice round bark budget ─────────────────────────────────────
#
# NarrativeVoiceService.apply_round_bark_budget() is the single owner of "which barks reach
# the player". Before D03 the same policy lived as literals inside
# CombatBoardScreen._show_bark_popups() and the authored data.voice block had no reader at all.
#
# These tests drive the pure static function on projected snapshot rows — the exact shape
# EncounterSnapshotBuilder hands it — so no scene tree and no encounter are needed.

## One projected actor row, reduced to the fields the budget reads and writes.
static func _bark_row(id: String, context: String, is_response: bool = false,
		target_id: String = "") -> Dictionary:
	return {
		"id":               id,
		"bark_line":        "line for " + id,
		"bark_context":     context,
		"bark_target_id":   target_id,
		"bark_is_response": is_response,
	}


## The shipped data.voice block, so the authored 3 / 1 are what these tests exercise.
static func _shipped_voice_cfg() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	config.load_balance(logger, 0)
	return ConfigService.get_voice_cfg(config)


static func _lines_kept(rows: Array) -> Array:
	var kept: Array = []
	for row_v in rows:
		if str((row_v as Dictionary).get("bark_line", "")) != "":
			kept.append(str((row_v as Dictionary).get("id", "")))
	return kept


## Six tier-3 originals, authored cap 3 → exactly three survive, in board order.
static func _test_bark_budget_caps_at_authored_max() -> Dictionary:
	var cfg := _shipped_voice_cfg()
	if int(cfg.get("max_barks_per_round", -1)) != 3:
		return { "ok": false, "error": "expected shipped max_barks_per_round 3, got %s" % cfg.get("max_barks_per_round", "<absent>") }
	var rows: Array = []
	for i in range(6):
		rows.append(_bark_row("a%d" % i, "combat_attack"))
	NarrativeVoiceService.apply_round_bark_budget(rows, cfg)
	var kept := _lines_kept(rows)
	if kept != ["a0", "a1", "a2"]:
		return { "ok": false, "error": "expected [a0,a1,a2] to survive the cap, got %s" % str(kept) }
	return { "ok": true }


## Boundary: three offered pass untouched; four offered lose exactly one.
static func _test_bark_budget_boundary_three_and_four() -> Dictionary:
	var cfg := _shipped_voice_cfg()

	var three: Array = []
	for i in range(3):
		three.append(_bark_row("b%d" % i, "combat_attack"))
	NarrativeVoiceService.apply_round_bark_budget(three, cfg)
	if _lines_kept(three).size() != 3:
		return { "ok": false, "error": "three offered must all survive, kept %s" % str(_lines_kept(three)) }

	var four: Array = []
	for i in range(4):
		four.append(_bark_row("c%d" % i, "combat_attack"))
	NarrativeVoiceService.apply_round_bark_budget(four, cfg)
	if _lines_kept(four) != ["c0", "c1", "c2"]:
		return { "ok": false, "error": "four offered must keep the first three, kept %s" % str(_lines_kept(four)) }
	return { "ok": true }


## Selection rule: tier decides, not arrival order. A tier-1 line placed last still survives,
## and each survivor is stamped with its authored tier.
static func _test_bark_budget_prefers_higher_tier() -> Dictionary:
	var cfg := _shipped_voice_cfg()
	var rows: Array = [
		_bark_row("chatter1", "combat_attack"),          # tier 3
		_bark_row("chatter2", "combat_guard"),           # tier 3
		_bark_row("chatter3", "combat_banter"),          # tier 3
		_bark_row("taunt",    "combat_taunt"),           # tier 2
		_bark_row("laststand", "combat_last_stand"),     # tier 1
	]
	NarrativeVoiceService.apply_round_bark_budget(rows, cfg)
	var kept := _lines_kept(rows)
	kept.sort()
	if kept != ["chatter1", "laststand", "taunt"]:
		return { "ok": false, "error": "expected tier 1 + tier 2 + first tier 3 to survive, got %s" % str(kept) }
	if int((rows[4] as Dictionary).get("bark_priority", -1)) != 1:
		return { "ok": false, "error": "combat_last_stand must be stamped bark_priority 1, got %s" % (rows[4] as Dictionary).get("bark_priority", "<absent>") }
	if int((rows[3] as Dictionary).get("bark_priority", -1)) != 2:
		return { "ok": false, "error": "combat_taunt must be stamped bark_priority 2, got %s" % (rows[3] as Dictionary).get("bark_priority", "<absent>") }
	if int((rows[0] as Dictionary).get("bark_priority", -1)) != 3:
		return { "ok": false, "error": "combat_attack must be stamped bark_priority 3, got %s" % (rows[0] as Dictionary).get("bark_priority", "<absent>") }
	return { "ok": true }


## A context absent from bark_tiers falls to the lowest authored tier — it neither outranks
## an authored line nor sinks below one. combat_divergence is the live case: data.voice
## .bark_tiers does not list it, so it ranks 3 here, where the deleted UI table gave it 2.
static func _test_bark_budget_unknown_context_takes_lowest_tier() -> Dictionary:
	var cfg := _shipped_voice_cfg()
	var rows: Array = [
		_bark_row("divergence", "combat_divergence"),
		_bark_row("banter",     "combat_banter"),
		_bark_row("taunt",      "combat_taunt"),
	]
	NarrativeVoiceService.apply_round_bark_budget(rows, cfg)
	if int((rows[0] as Dictionary).get("bark_priority", -1)) != 3:
		return { "ok": false, "error": "an unlisted context must take the lowest authored tier 3, got %s" % (rows[0] as Dictionary).get("bark_priority", "<absent>") }
	# Ordering check: with four contenders the tier-2 line survives and one tier-3 line is cut.
	var rows2: Array = [
		_bark_row("divergence", "combat_divergence"),
		_bark_row("banter",     "combat_banter"),
		_bark_row("guard",      "combat_guard"),
		_bark_row("taunt",      "combat_taunt"),
	]
	NarrativeVoiceService.apply_round_bark_budget(rows2, cfg)
	var kept := _lines_kept(rows2)
	if kept != ["divergence", "banter", "taunt"]:
		return { "ok": false, "error": "expected [divergence,banter,taunt], got %s" % str(kept) }
	return { "ok": true }


## reactions_exceed_cap true (authored): a reaction rides above the three-original budget,
## but only max_reactions_per_original of them, and only for an original that survived.
static func _test_bark_budget_reactions_ride_above_cap() -> Dictionary:
	var cfg := _shipped_voice_cfg()
	if int(cfg.get("max_reactions_per_original", -1)) != 1:
		return { "ok": false, "error": "expected shipped max_reactions_per_original 1, got %s" % cfg.get("max_reactions_per_original", "<absent>") }
	if not bool(cfg.get("reactions_exceed_cap", false)):
		return { "ok": false, "error": "expected shipped reactions_exceed_cap true" }
	var rows: Array = [
		_bark_row("o1", "combat_attack"),
		_bark_row("o2", "combat_attack"),
		_bark_row("o3", "combat_attack"),
		_bark_row("o4", "combat_attack"),                              # over the cap
		_bark_row("r1", "combat_rally_ally", true, "o1"),
		_bark_row("r2", "combat_rally_ally", true, "o1"),              # second for o1
		_bark_row("r4", "combat_rally_ally", true, "o4"),              # original was cut
	]
	NarrativeVoiceService.apply_round_bark_budget(rows, cfg)
	var kept := _lines_kept(rows)
	if kept != ["o1", "o2", "o3", "r1"]:
		return { "ok": false, "error": "expected [o1,o2,o3,r1], got %s" % str(kept) }
	return { "ok": true }


## reactions_exceed_cap false: the same reaction now competes for the round budget and loses.
## Config-driven, so both states of the key are exercised rather than one dead branch.
static func _test_bark_budget_reactions_inside_cap_when_configured() -> Dictionary:
	var cfg := _shipped_voice_cfg().duplicate(true)
	cfg["reactions_exceed_cap"] = false
	var rows: Array = [
		_bark_row("o1", "combat_attack"),
		_bark_row("o2", "combat_attack"),
		_bark_row("o3", "combat_attack"),
		_bark_row("r1", "combat_rally_ally", true, "o1"),
	]
	NarrativeVoiceService.apply_round_bark_budget(rows, cfg)
	var kept := _lines_kept(rows)
	if kept != ["o1", "o2", "o3"]:
		return { "ok": false, "error": "reaction must be cut when it counts against the cap, kept %s" % str(kept) }

	# With one original short of the cap the same reaction fits.
	var rows2: Array = [
		_bark_row("o1", "combat_attack"),
		_bark_row("o2", "combat_attack"),
		_bark_row("r1", "combat_rally_ally", true, "o1"),
	]
	NarrativeVoiceService.apply_round_bark_budget(rows2, cfg)
	if _lines_kept(rows2) != ["o1", "o2", "r1"]:
		return { "ok": false, "error": "reaction must fit inside a budget with room, kept %s" % str(_lines_kept(rows2)) }
	return { "ok": true }


## Identical input must produce an identical survivor set — no set/hash iteration order.
static func _test_bark_budget_is_deterministic() -> Dictionary:
	var cfg := _shipped_voice_cfg()
	var first: Array = []
	for run in range(2):
		var rows: Array = [
			_bark_row("z1", "combat_guard"),
			_bark_row("z2", "combat_taunt"),
			_bark_row("z3", "combat_guard"),
			_bark_row("z4", "combat_taunt"),
			_bark_row("z5", "combat_banter"),
		]
		NarrativeVoiceService.apply_round_bark_budget(rows, cfg)
		if run == 0:
			first = _lines_kept(rows)
		elif _lines_kept(rows) != first:
			return { "ok": false, "error": "survivor set is not deterministic: %s vs %s" % [str(first), str(_lines_kept(rows))] }
	if first != ["z2", "z4", "z1"] and first != ["z1", "z2", "z4"]:
		return { "ok": false, "error": "expected the two tier-2 lines plus the first tier-3, got %s" % str(first) }
	return { "ok": true }


## WIRING: the budget must actually run inside the snapshot builder, not merely exist.
## Six actors carry a bark; the published round snapshot must expose three.
static func _test_bark_budget_is_wired_into_round_snapshot() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	config.load_balance(logger, 0)

	var ectx := EncounterContext.new()
	ectx.encounter_id = "voice.bark_budget"
	ectx.combat_state = { "round_phase": "in_round", "round_counter": 1 }
	for i in range(6):
		ectx.actors.append({
			"id":            "w%d" % i,
			"name":          "W%d" % i,
			"faction":       "echo",
			"current_hp":    10,
			"stats":         { "max_hp": 10 },
			"grid_pos":      { "col": i, "row": 0 },
			"morale":        50,
			"fear":          0,
			"skill_slots":   [""],
			"_bark_line":    "line %d" % i,
			"_bark_context": "combat_attack",
		})

	var flow_ctx := FlowContext.new()
	flow_ctx.logger = logger
	flow_ctx.config_service = config
	flow_ctx.encounter_ctx = ectx

	var snap := EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, 1)
	var rows: Array = (snap.get("data", {}) as Dictionary).get("actors", [])
	var kept := _lines_kept(rows)
	if kept.size() != 3:
		return { "ok": false, "error": "round snapshot must carry the budgeted 3 barks, carries %d: %s" % [kept.size(), str(kept)] }

	# The budget must not have reached back into the runtime actors (builder purity).
	for a_v in ectx.actors:
		if str((a_v as Dictionary).get("_bark_line", "")) == "":
			return { "ok": false, "error": "the budget cleared a runtime actor's _bark_line — the builder must stay pure" }
	return { "ok": true }

# res://tests/SanctumPulseTests.gd
# Tests for V2-SANCTUM-001: ConsequencePassService + EmotionRecoveryService
#
# 13 tests covering:
#   ConsequencePassService.collect() — economy/emotion/vow/intel groups
#   EmotionRecoveryService.apply_recovery_from_elapsed() + set_modifier()
#   FlowSanctumState — run_consequence consumed on enter()
#
# All tests are pure unit tests (no runtime or save file needed).
# Run via Debug Panel: tests

extends RefCounted
class_name SanctumPulseTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("sanctum_pulse/collect_victory_has_economy_and_emotion",      Callable(SanctumPulseTests, "_t_collect_victory_has_economy_and_emotion"))
	runner.register_test("sanctum_pulse/collect_defeat_economy_signal_loss",           Callable(SanctumPulseTests, "_t_collect_defeat_economy_signal_loss"))
	runner.register_test("sanctum_pulse/collect_victory_economy_signal_gain",          Callable(SanctumPulseTests, "_t_collect_victory_economy_signal_gain"))
	runner.register_test("sanctum_pulse/collect_withdrawal_runs_without_resolve_snap", Callable(SanctumPulseTests, "_t_collect_withdrawal_runs_without_resolve_snap"))
	runner.register_test("sanctum_pulse/emotion_entries_use_emotional_status",         Callable(SanctumPulseTests, "_t_emotion_entries_use_emotional_status"))
	runner.register_test("sanctum_pulse/vow_released_produces_vow_group",              Callable(SanctumPulseTests, "_t_vow_released_produces_vow_group"))
	runner.register_test("sanctum_pulse/no_vow_no_vow_group",                          Callable(SanctumPulseTests, "_t_no_vow_no_vow_group"))
	runner.register_test("sanctum_pulse/run_consequence_cleared_after_consume",        Callable(SanctumPulseTests, "_t_run_consequence_cleared_after_consume"))
	runner.register_test("sanctum_pulse/recovery_reduces_fear_over_elapsed",           Callable(SanctumPulseTests, "_t_recovery_reduces_fear_over_elapsed"))
	runner.register_test("sanctum_pulse/recovery_respects_morale_base_ceiling",        Callable(SanctumPulseTests, "_t_recovery_respects_morale_base_ceiling"))
	runner.register_test("sanctum_pulse/modifier_ticks_down",                          Callable(SanctumPulseTests, "_t_modifier_ticks_down"))
	runner.register_test("sanctum_pulse/defeat_modifier_slows_fear_recovery",          Callable(SanctumPulseTests, "_t_defeat_modifier_slows_fear_recovery"))
	runner.register_test("sanctum_pulse/victory_modifier_speeds_morale_recovery",      Callable(SanctumPulseTests, "_t_victory_modifier_speeds_morale_recovery"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _make_logger() -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level("off")
	return l


static func _make_echo(id: String, morale: int = 50, fear: int = 0, morale_base: int = 50) -> Dictionary:
	return {
		"id": id,
		"name": id,
		"emotion": {
			"faith":          50,
			"morale_base":    morale_base,
			"morale_current": morale,
			"fear_current":   fear,
		},
		"recovery_modifiers": {
			"morale_multiplier": 1.0,
			"fear_multiplier":   1.0,
			"ticks_remaining":   0,
		},
	}


static func _make_resolve_snap(ase: int, rank: String, victory: bool) -> Dictionary:
	return {
		"type": "flow.resolve",
		"meta": { "t": 0 },
		"data": {
			"title":       "Resolve",
			"victory":     victory,
			"ase_awarded": ase,
			"rank":        rank,
		},
		"actions": {},
	}


static func _make_save_with_party(echo_ids: Array, morale: int = 50, fear: int = 0) -> Dictionary:
	var roster: Array = []
	for eid in echo_ids:
		roster.append(_make_echo(str(eid), morale, fear))
	return {
		"sanctum": {
			"roster":           roster,
			"active_party_ids": echo_ids.duplicate(),
			"active_vow":       {},
		},
		"realms": {},
	}


static func _make_recovery_cfg(morale_per_min: float = 1.0, fear_per_min: float = 0.5,
		cap: int = 28800, ticks: int = 3) -> Dictionary:
	return {
		"morale_recovery_per_min": morale_per_min,
		"fear_recovery_per_min":   fear_per_min,
		"offline_cap_seconds":     cap,
		"modifier_ticks_duration": ticks,
		"modifier_victory_morale_mul": 1.5,
		"modifier_defeat_fear_mul":    0.5,
		"modifier_ko_morale_mul":      0.5,
		"modifier_survived_morale_mul": 1.25,
	}


# ---------------------------------------------------------------------------
# Tests — ConsequencePassService
# ---------------------------------------------------------------------------

# Test 1: victory run always produces economy + emotion groups
static func _t_collect_victory_has_economy_and_emotion() -> Dictionary:
	var snap     := _make_resolve_snap(120, "A", true)
	var save     := _make_save_with_party(["echo_001"])
	var result   := ConsequencePassService.collect(snap, "win", save, false, {})
	if result.get("run_outcome", "") != "win":
		return { "ok": false, "error": "run_outcome should be 'win'" }
	var groups: Array = result.get("groups", [])
	var has_econ  := false
	var has_emo   := false
	for g in groups:
		if str((g as Dictionary).get("type", "")) == "economy":
			has_econ = true
		if str((g as Dictionary).get("type", "")) == "emotion":
			has_emo = true
	if not has_econ:
		return { "ok": false, "error": "Missing economy group on victory" }
	if not has_emo:
		return { "ok": false, "error": "Missing emotion group on victory" }
	return { "ok": true }


# Test 2: defeat + ase=0 → economy entry has signal "loss"
static func _t_collect_defeat_economy_signal_loss() -> Dictionary:
	var snap   := _make_resolve_snap(0, "D", false)
	var save   := _make_save_with_party(["echo_001"])
	var result := ConsequencePassService.collect(snap, "defeat", save, false, {})
	var groups: Array = result.get("groups", [])
	for g_v in groups:
		var g: Dictionary = g_v
		if str(g.get("type", "")) == "economy":
			var entries: Array = g.get("entries", [])
			if entries.is_empty():
				return { "ok": false, "error": "Economy group has no entries" }
			var first: Dictionary = entries[0]
			if str(first.get("signal", "")) != "loss":
				return { "ok": false, "error": "Expected signal=loss for ase=0 defeat, got: %s" % str(first.get("signal", "")) }
			return { "ok": true }
	return { "ok": false, "error": "No economy group found" }


# Test 3: victory + ase>0 → economy entry has signal "gain"
static func _t_collect_victory_economy_signal_gain() -> Dictionary:
	var snap   := _make_resolve_snap(150, "S", true)
	var save   := _make_save_with_party(["echo_001"])
	var result := ConsequencePassService.collect(snap, "win", save, false, {})
	var groups: Array = result.get("groups", [])
	for g_v in groups:
		var g: Dictionary = g_v
		if str(g.get("type", "")) == "economy":
			var entries: Array = g.get("entries", [])
			if entries.is_empty():
				return { "ok": false, "error": "Economy group has no entries" }
			var first: Dictionary = entries[0]
			if str(first.get("signal", "")) != "gain":
				return { "ok": false, "error": "Expected signal=gain for ase>0 victory, got: %s" % str(first.get("signal", "")) }
			return { "ok": true }
	return { "ok": false, "error": "No economy group found" }


# Test 4: withdrawal with a non-resolve snap (fallback scaffold) → outcome is "withdrawal"
static func _t_collect_withdrawal_runs_without_resolve_snap() -> Dictionary:
	var fallback_snap := {
		"type": "flow.stage_map",
		"meta": { "t": 0 },
		"data": { "title": "Stage Map" },
		"actions": {},
	}
	var save   := _make_save_with_party(["echo_001"])
	var result := ConsequencePassService.collect(fallback_snap, "withdrawal", save, false, {})
	if str(result.get("run_outcome", "")) != "withdrawal":
		return { "ok": false, "error": "run_outcome should be 'withdrawal'" }
	return { "ok": true }


# Test 5: emotion entries use emotional_status — no raw morale/fear integers in summaries
static func _t_emotion_entries_use_emotional_status() -> Dictionary:
	var snap   := _make_resolve_snap(0, "C", false)
	var save   := _make_save_with_party(["echo_001"], 40, 30)
	var result := ConsequencePassService.collect(snap, "defeat", save, false, {})
	var groups: Array = result.get("groups", [])
	for g_v in groups:
		var g: Dictionary = g_v
		if str(g.get("type", "")) != "emotion":
			continue
		for entry_v in (g.get("entries", []) as Array):
			var entry: Dictionary = entry_v
			var summary := str(entry.get("summary", ""))
			if "morale_current" in summary or "fear_current" in summary:
				return { "ok": false, "error": "Emotion summary exposes raw field name: '%s'" % summary }
		return { "ok": true }
	return { "ok": false, "error": "No emotion group found" }


# Test 6: vow_released=true → vow group with 'fulfilled' entry
static func _t_vow_released_produces_vow_group() -> Dictionary:
	var snap   := _make_resolve_snap(100, "B", true)
	var save   := _make_save_with_party(["echo_001"])
	var result := ConsequencePassService.collect(snap, "win", save, true, {})
	var groups: Array = result.get("groups", [])
	for g_v in groups:
		var g: Dictionary = g_v
		if str(g.get("type", "")) == "vow":
			var entries: Array = g.get("entries", [])
			if entries.is_empty():
				return { "ok": false, "error": "Vow group has no entries" }
			var summary := str((entries[0] as Dictionary).get("summary", ""))
			if "fulfill" not in summary.to_lower():
				return { "ok": false, "error": "Expected 'fulfill' in vow summary, got: '%s'" % summary }
			return { "ok": true }
	return { "ok": false, "error": "No vow group found when vow_released=true" }


# Test 7: vow_released=false + no active_vow → no vow group
static func _t_no_vow_no_vow_group() -> Dictionary:
	var snap   := _make_resolve_snap(50, "B", true)
	var save   := _make_save_with_party(["echo_001"])
	save["sanctum"]["active_vow"] = {}
	var result := ConsequencePassService.collect(snap, "win", save, false, {})
	var groups: Array = result.get("groups", [])
	for g_v in groups:
		var g: Dictionary = g_v
		if str(g.get("type", "")) == "vow":
			return { "ok": false, "error": "Vow group present but no vow active and not released" }
	return { "ok": true }


# Test 8: FlowSanctumState.enter() clears last_run_consequence after reading it
static func _t_run_consequence_cleared_after_consume() -> Dictionary:
	var logger := _make_logger()
	var ctx    := FlowContext.new()
	ctx.logger = logger
	ctx.save_data = {
		"sanctum": { "roster": [], "active_party_ids": [], "active_vow": {} },
		"realms":   {},
		"economy":  { "ase": 0, "ekwan": 0 },
	}
	ctx.last_run_consequence = {
		"run_outcome": "win",
		"groups":      [],
	}

	# Call FlowSanctumState.enter() — it should consume last_run_consequence
	var state := FlowSanctumState.new()
	state.enter(ctx, 0)

	if not ctx.last_run_consequence.is_empty():
		return { "ok": false, "error": "last_run_consequence not cleared after enter()" }
	return { "ok": true }


# ---------------------------------------------------------------------------
# Tests — EmotionRecoveryService
# ---------------------------------------------------------------------------

# Test 9: 600s elapsed → fear delta applied (partial recovery)
static func _t_recovery_reduces_fear_over_elapsed() -> Dictionary:
	var logger  := _make_logger()
	var echo    := _make_echo("echo_001", 50, 40)  # morale=50(base), fear=40
	var roster  := [echo]
	var cfg     := _make_recovery_cfg(0.0, 1.0)  # only fear recovers
	var results := EmotionRecoveryService.apply_recovery_from_elapsed(roster, 600, cfg, 80, logger, 0)
	var fear_after := int(echo["emotion"]["fear_current"])
	if fear_after >= 40:
		return { "ok": false, "error": "Fear did not reduce. Before=40, after=%d" % fear_after }
	if results.is_empty():
		return { "ok": false, "error": "Results array should not be empty when delta applied" }
	return { "ok": true }


# Test 10: morale at base → no morale delta applied
static func _t_recovery_respects_morale_base_ceiling() -> Dictionary:
	var logger    := _make_logger()
	var echo      := _make_echo("echo_001", 50, 0, 50)  # morale=50 == morale_base=50
	var roster    := [echo]
	var cfg       := _make_recovery_cfg(5.0, 0.0)  # high morale rate, no fear
	var results   := EmotionRecoveryService.apply_recovery_from_elapsed(roster, 3600, cfg, 80, logger, 0)
	var morale_after := int(echo["emotion"]["morale_current"])
	if morale_after != 50:
		return { "ok": false, "error": "Morale moved above base. Expected 50, got %d" % morale_after }
	if not results.is_empty():
		return { "ok": false, "error": "Results should be empty when morale already at base" }
	return { "ok": true }


# Test 11: ticks_remaining decrements and resets multipliers to 1.0 at 0
static func _t_modifier_ticks_down() -> Dictionary:
	var logger := _make_logger()
	# Echo with fear below base so recovery fires
	var echo   := _make_echo("echo_001", 40, 10, 50)
	echo["recovery_modifiers"] = {
		"morale_multiplier": 2.0,
		"fear_multiplier":   2.0,
		"ticks_remaining":   1,
	}
	var roster := [echo]
	var cfg    := _make_recovery_cfg(1.0, 1.0)

	# First apply — ticks should go from 1 → 0 and reset multipliers
	EmotionRecoveryService.apply_recovery_from_elapsed(roster, 600, cfg, 80, logger, 0)

	var rm: Dictionary = echo.get("recovery_modifiers", {})
	if int(rm.get("ticks_remaining", -1)) != 0:
		return { "ok": false, "error": "Expected ticks_remaining=0, got %d" % int(rm.get("ticks_remaining", -1)) }
	if float(rm.get("morale_multiplier", -1.0)) != 1.0:
		return { "ok": false, "error": "Expected morale_multiplier reset to 1.0" }
	if float(rm.get("fear_multiplier", -1.0)) != 1.0:
		return { "ok": false, "error": "Expected fear_multiplier reset to 1.0" }
	return { "ok": true }


# Test 12: defeat modifier (fear_mul=0.5) → fear recovery delta is smaller than unmodified
static func _t_defeat_modifier_slows_fear_recovery() -> Dictionary:
	var logger := _make_logger()
	var cfg    := _make_recovery_cfg(0.0, 1.0)

	# Unmodified echo
	var echo_normal := _make_echo("a", 50, 40)
	EmotionRecoveryService.apply_recovery_from_elapsed([echo_normal], 600, cfg, 80, logger, 0)
	var fear_normal := int(echo_normal["emotion"]["fear_current"])

	# Defeat-modified echo (fear recovery slowed to 50%)
	var echo_mod := _make_echo("b", 50, 40)
	echo_mod["recovery_modifiers"] = { "morale_multiplier": 1.0, "fear_multiplier": 0.5, "ticks_remaining": 5 }
	EmotionRecoveryService.apply_recovery_from_elapsed([echo_mod], 600, cfg, 80, logger, 0)
	var fear_mod := int(echo_mod["emotion"]["fear_current"])

	if fear_mod <= fear_normal:
		return { "ok": false, "error": "Defeat modifier should slow fear recovery. normal=%d mod=%d" % [fear_normal, fear_mod] }
	return { "ok": true }


# Test 13: victory modifier (morale_mul=1.5) → morale recovery delta is larger than unmodified
static func _t_victory_modifier_speeds_morale_recovery() -> Dictionary:
	var logger := _make_logger()
	var cfg    := _make_recovery_cfg(1.0, 0.0)

	# Unmodified echo (morale below base)
	var echo_normal := _make_echo("a", 30, 0, 50)
	EmotionRecoveryService.apply_recovery_from_elapsed([echo_normal], 3600, cfg, 80, logger, 0)
	var morale_normal := int(echo_normal["emotion"]["morale_current"])

	# Victory-modified echo (morale recovery at 1.5x)
	var echo_mod := _make_echo("b", 30, 0, 50)
	echo_mod["recovery_modifiers"] = { "morale_multiplier": 1.5, "fear_multiplier": 1.0, "ticks_remaining": 5 }
	EmotionRecoveryService.apply_recovery_from_elapsed([echo_mod], 3600, cfg, 80, logger, 0)
	var morale_mod := int(echo_mod["emotion"]["morale_current"])

	if morale_mod <= morale_normal:
		return { "ok": false, "error": "Victory modifier should speed morale recovery. normal=%d mod=%d" % [morale_normal, morale_mod] }
	return { "ok": true }

# res://tests/ProgressionTests.gd
# PROG-003: Unit tests for ProgressionService.
#
# Isolation rule: save_data roster mutations are performed directly on the dict
# ref — no live services involved. Birth_stats_cfg uses a minimal stub dict
# that is enough for DerivedStatService to produce valid ints.
class_name ProgressionTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("prog_no_actions_gets_clear_xp_only",         Callable(ProgressionTests, "_test_no_actions_clear_xp"))
	runner.register_test("prog_kill_bonus_awarded_to_attacker",        Callable(ProgressionTests, "_test_kill_bonus"))
	runner.register_test("prog_stage_clear_shared_all_party_echoes",   Callable(ProgressionTests, "_test_stage_clear_shared"))
	runner.register_test("prog_realm_completion_bonus_on_final_stage", Callable(ProgressionTests, "_test_realm_completion_bonus"))
	runner.register_test("prog_level_up_triggers_stat_recompute",      Callable(ProgressionTests, "_test_level_up_stat_recompute"))
	runner.register_test("prog_level_capped_at_max_per_rank",          Callable(ProgressionTests, "_test_level_cap"))
	runner.register_test("prog_virtue_multiplier_courage",             Callable(ProgressionTests, "_test_virtue_multiplier"))
	runner.register_test("prog_xp_persisted_to_save_data",            Callable(ProgressionTests, "_test_xp_persisted"))


# ────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────

static func _make_echo(id: String, xp: int = 0, level: int = 1) -> Dictionary:
	return {
		"id":           id,
		"name":         "Echo_%s" % id,
		"rank":         1,
		"level":        level,
		"xp_total":     xp,
		"rarity":       "uncalled",
		"calling_origin": "uncalled",
		"archetype_birth": "valiant",
		"traits": { "courage": 60, "wisdom": 40, "faith": 40 },
		"stats": {
			"max_hp": 100, "atk": 8, "def": 4,
			"agi": 4, "int": 6, "cha": 2, "speed": 4
		},
		"emotion": { "morale_current": 50, "fear_current": 0 },
	}

static func _make_save(echo_ids: Array, party_ids: Array = []) -> Dictionary:
	var roster: Array = []
	for eid in echo_ids:
		roster.append(_make_echo(eid))
	var actual_party: Array = party_ids if not party_ids.is_empty() else echo_ids.duplicate()
	return {
		"sanctum": {
			"roster":          roster,
			"active_party_ids": actual_party,
		}
	}

static func _default_prog_cfg() -> Dictionary:
	return {
		"xp_kill_bonus":             25,
		"xp_stage_clear_base":       40,
		"xp_realm_completion_bonus": 100,
		"virtue_xp_multiplier_max":  0.20,
		"level_thresholds":          [0, 100, 250, 450, 700],
		"max_level_per_rank":        5,
	}

## Minimal birth_stats stub — real values not needed, just valid numbers.
static func _stub_birth_stats() -> Dictionary:
	return {
		"hp_base": 80.0, "hp_per_level": 5.0, "hp_per_rank": 10.0,
		"hp_courage_mul": 0.25, "hp_faith_mul": 0.15, "hp_min": 15.0,
		"atk_base": 3.0, "atk_per_level": 1.0, "atk_per_rank": 2.0,
		"atk_courage_mul": 0.2, "atk_faith_mul": 0.12,
		"def_base": 2.5, "def_per_level": 0.0, "def_per_rank": 1.0,
		"def_wisdom_mul": 0.08, "def_faith_mul": 0.04,
		"agi_base": 2.0, "agi_per_level": 0.0, "agi_per_rank": 1.0,
		"agi_wisdom_mul": 0.08, "agi_courage_mul": 0.08,
		"int_base": 4.0, "int_per_level": 1.0, "int_per_rank": 1.0,
		"int_wisdom_mul": 0.22, "int_courage_mul": 0.04,
		"cha_base": 1.0, "cha_per_level": 0.0, "cha_per_rank": 1.0,
		"cha_faith_mul": 0.08, "cha_wisdom_mul": 0.08,
		"speed_base": 2.0, "speed_per_level": 0.0, "speed_per_rank": 1.0,
		"speed_courage_mul": 0.06, "speed_wisdom_mul": 0.04,
	}


# ────────────────────────────────────────────────────────────────────────────
# Tests
# ────────────────────────────────────────────────────────────────────────────

## 1. Echo with no combat actions still gets stage_clear XP on victory.
static func _test_no_actions_clear_xp() -> Dictionary:
	var save := _make_save(["e1"])
	var action_logs: Dictionary = {}  # no actions recorded
	var events := ProgressionService.award_post_combat_xp(
		save, action_logs, true, false,
		_default_prog_cfg(), _stub_birth_stats(), null, 0
	)
	if events.is_empty():
		return { "ok": false, "error": "Expected at least one XpEvent" }
	var ev: Dictionary = events[0]
	var expected: int  = 40  # xp_stage_clear_base, no kill bonus, no virtue multiplier
	if int(ev.get("xp_gained", 0)) != expected:
		return { "ok": false, "error": "Expected xp_gained=%d got %d" % [expected, int(ev.get("xp_gained", 0))] }
	return { "ok": true }


## 2. Kill bonus is added to the attacker's XP.
static func _test_kill_bonus() -> Dictionary:
	var save := _make_save(["e1"])
	var action_logs := {
		"e1": { "melee_count": 2, "guard_count": 0, "kill_count": 1, "total_count": 2 }
	}
	var events := ProgressionService.award_post_combat_xp(
		save, action_logs, true, false,
		_default_prog_cfg(), _stub_birth_stats(), null, 0
	)
	if events.is_empty():
		return { "ok": false, "error": "Expected XpEvent" }
	var ev: Dictionary = events[0]
	# kill_xp=25, clear_xp=40, virtue_mul = (2/2) * (60/100) * 0.20 = 0.12
	# final = round(65 * 1.12) = round(72.8) = 73
	if int(ev.get("xp_gained", 0)) < 60:
		return { "ok": false, "error": "Kill bonus not reflected — xp_gained=%d" % int(ev.get("xp_gained", 0)) }
	return { "ok": true }


## 3. Stage clear XP goes to ALL echoes in the party (not just those with kills).
static func _test_stage_clear_shared() -> Dictionary:
	var save := _make_save(["e1", "e2", "e3"])
	# Only e1 has kills; e2 and e3 did nothing (no action log entries)
	var action_logs := {
		"e1": { "melee_count": 1, "guard_count": 0, "kill_count": 1, "total_count": 1 }
	}
	var events := ProgressionService.award_post_combat_xp(
		save, action_logs, true, false,
		_default_prog_cfg(), _stub_birth_stats(), null, 0
	)
	# All 3 echoes should have at least 40 XP (stage_clear_base)
	if events.size() != 3:
		return { "ok": false, "error": "Expected 3 events, got %d" % events.size() }
	for ev in events:
		if int(ev.get("xp_gained", 0)) < 40:
			return { "ok": false, "error": "%s got only %d XP (expected >= 40)" % [ev.get("echo_name", "?"), int(ev.get("xp_gained", 0))] }
	return { "ok": true }


## 4. Realm completion bonus is added when realm_completed=true.
static func _test_realm_completion_bonus() -> Dictionary:
	var save := _make_save(["e1"])
	var events_no_realm := ProgressionService.award_post_combat_xp(
		save, {}, true, false,
		_default_prog_cfg(), _stub_birth_stats(), null, 0
	)
	# Reset xp_total
	save["sanctum"]["roster"][0]["xp_total"] = 0
	save["sanctum"]["roster"][0]["level"] = 1
	var events_with_realm := ProgressionService.award_post_combat_xp(
		save, {}, true, true,
		_default_prog_cfg(), _stub_birth_stats(), null, 0
	)

	if events_no_realm.is_empty() or events_with_realm.is_empty():
		return { "ok": false, "error": "Expected events in both calls" }
	var without := int(events_no_realm[0].get("xp_gained", 0))
	var with_r  := int(events_with_realm[0].get("xp_gained", 0))
	if with_r <= without:
		return { "ok": false, "error": "realm bonus not applied: with=%d without=%d" % [with_r, without] }
	return { "ok": true }


## 5. Crossing a level threshold triggers stat recomputation.
static func _test_level_up_stat_recompute() -> Dictionary:
	# Set echo at 90 XP (10 short of level 2 threshold at 100)
	var save: Dictionary = {
		"sanctum": {
			"roster":          [_make_echo("e1", 90)],
			"active_party_ids": ["e1"],
		}
	}
	var old_stats: Dictionary = save["sanctum"]["roster"][0]["stats"].duplicate()

	# Award 40 XP (stage clear) → total 130 → should hit level 2
	var events := ProgressionService.award_post_combat_xp(
		save, {}, true, false,
		_default_prog_cfg(), _stub_birth_stats(), null, 0
	)
	if events.is_empty():
		return { "ok": false, "error": "No XpEvent returned" }
	var ev: Dictionary = events[0]
	if not bool(ev.get("leveled_up", false)):
		return { "ok": false, "error": "Expected leveled_up=true, got false" }
	if int(ev.get("new_level", 0)) != 2:
		return { "ok": false, "error": "Expected new_level=2, got %d" % int(ev.get("new_level", 0)) }

	var new_stats: Dictionary = save["sanctum"]["roster"][0]["stats"]
	# At level 2, max_hp should be higher than at level 1 (hp_per_level=5.0)
	if int(new_stats.get("max_hp", 0)) <= int(old_stats.get("max_hp", 0)):
		return { "ok": false, "error": "max_hp not recomputed: old=%d new=%d" % [int(old_stats["max_hp"]), int(new_stats.get("max_hp", 0))] }
	return { "ok": true }


## 6. Level is capped at max_level_per_rank (5) regardless of XP.
static func _test_level_cap() -> Dictionary:
	var save: Dictionary = {
		"sanctum": {
			"roster":          [_make_echo("e1", 700, 5)],  # already at level 5
			"active_party_ids": ["e1"],
		}
	}
	# Award a large XP that would push past level 5 if uncapped
	var big_cfg := _default_prog_cfg()
	big_cfg["xp_stage_clear_base"] = 9999
	var events := ProgressionService.award_post_combat_xp(
		save, {}, true, false,
		big_cfg, _stub_birth_stats(), null, 0
	)
	if events.is_empty():
		return { "ok": false, "error": "No events" }
	var ev: Dictionary = events[0]
	if int(ev.get("new_level", 0)) > 5:
		return { "ok": false, "error": "Level exceeded cap: got %d" % int(ev.get("new_level", 0)) }
	if bool(ev.get("leveled_up", false)):
		return { "ok": false, "error": "leveled_up should be false at cap" }
	return { "ok": true }


## 7. High-courage echo with high melee ratio gets a virtue XP bonus > 0.
static func _test_virtue_multiplier() -> Dictionary:
	# courage=80, all actions are melee → maximum multiplier for this echo
	var high_courage_echo := _make_echo("e1")
	high_courage_echo["traits"] = { "courage": 80, "wisdom": 30, "faith": 30 }
	var save: Dictionary = {
		"sanctum": {
			"roster":          [high_courage_echo],
			"active_party_ids": ["e1"],
		}
	}
	# All 4 actions are melee
	var action_logs := {
		"e1": { "melee_count": 4, "guard_count": 0, "kill_count": 0, "total_count": 4 }
	}
	var events := ProgressionService.award_post_combat_xp(
		save, action_logs, true, false,
		_default_prog_cfg(), _stub_birth_stats(), null, 0
	)
	if events.is_empty():
		return { "ok": false, "error": "No events" }
	var ev: Dictionary = events[0]
	# raw_xp = 40 (stage clear). multiplier = 1.0 * 0.80 * 0.20 = 0.16 → +6.4 → final = 47
	# At minimum, xp_gained must be > 40
	if int(ev.get("xp_gained", 0)) <= 40:
		return { "ok": false, "error": "Virtue multiplier not applied: xp_gained=%d (expected > 40)" % int(ev.get("xp_gained", 0)) }
	return { "ok": true }


## 8. XP and level mutations are persisted to save_data roster.
static func _test_xp_persisted() -> Dictionary:
	var save := _make_save(["e1"])
	ProgressionService.award_post_combat_xp(
		save, {}, true, false,
		_default_prog_cfg(), _stub_birth_stats(), null, 0
	)
	var new_xp: int = int(save["sanctum"]["roster"][0].get("xp_total", 0))
	if new_xp != 40:
		return { "ok": false, "error": "Expected xp_total=40 in save_data, got %d" % new_xp }
	return { "ok": true }

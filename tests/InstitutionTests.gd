# res://tests/InstitutionTests.gd
# Tests for V2-SANCTUM-002: InstitutionService
#
# 13 tests covering:
#   Unlock gating (continuity threshold)
#   Establish (Ekwan spend + unlock)
#   Echo assign/remove (Ase/Ekwan spend, capacity, party auto-remove)
#   Condition transitions (neglected/healthy/strained)
#   Compatibility (natural_fit)
#   Determinism
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name InstitutionTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("institution/locked_below_continuity_threshold",  Callable(InstitutionTests, "_t_locked_below_continuity_threshold"))
	runner.register_test("institution/candidate_at_continuity_threshold",  Callable(InstitutionTests, "_t_candidate_at_continuity_threshold"))
	runner.register_test("institution/establish_spends_ekwan_and_unlocks", Callable(InstitutionTests, "_t_establish_spends_ekwan_and_unlocks"))
	runner.register_test("institution/establish_fails_insufficient_ekwan", Callable(InstitutionTests, "_t_establish_fails_insufficient_ekwan"))
	runner.register_test("institution/assign_spends_ase_and_adds_occupant", Callable(InstitutionTests, "_t_assign_spends_ase_and_adds_occupant"))
	runner.register_test("institution/assign_auto_removes_from_party",     Callable(InstitutionTests, "_t_assign_auto_removes_from_party"))
	runner.register_test("institution/assign_fails_at_capacity",           Callable(InstitutionTests, "_t_assign_fails_at_capacity"))
	runner.register_test("institution/remove_spends_ekwan_and_removes",    Callable(InstitutionTests, "_t_remove_spends_ekwan_and_removes"))
	runner.register_test("institution/condition_neglected_when_no_occupants", Callable(InstitutionTests, "_t_condition_neglected_when_no_occupants"))
	runner.register_test("institution/condition_healthy_within_threshold", Callable(InstitutionTests, "_t_condition_healthy_within_threshold"))
	runner.register_test("institution/condition_strained_outside_healthy", Callable(InstitutionTests, "_t_condition_strained_outside_healthy"))
	runner.register_test("institution/compatibility_natural_fit",          Callable(InstitutionTests, "_t_compatibility_natural_fit"))
	runner.register_test("institution/determinism",                        Callable(InstitutionTests, "_t_determinism"))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _make_logger() -> StructuredLogger:
	var l := StructuredLogger.new()
	l.set_level("off")
	return l


static func _make_inst_cfg() -> Dictionary:
	return {
		"hearth": {
			"unlock_continuity_threshold": 1,
			"establish_ekwan_cost":        10,
			"assign_ase_cost":             5,
			"unassign_ekwan_cost":         3,
			"capacity":                    4,
			"healthy_max_elapsed_seconds": 3600,
			"strained_max_elapsed_seconds": 10800,
			"primary_vectors":             ["pillar"],
			"primary_callings":            ["onyamesu", "okomfo"],
			"primary_archetypes":          [],
		},
		"training_grounds": {
			"unlock_continuity_threshold": 2,
			"establish_ekwan_cost":        15,
			"assign_ase_cost":             5,
			"unassign_ekwan_cost":         3,
			"capacity":                    4,
			"healthy_max_elapsed_seconds": 3600,
			"strained_max_elapsed_seconds": 10800,
			"primary_vectors":             ["vanguard"],
			"primary_callings":            ["aduro", "okofor", "kra_soro"],
			"primary_archetypes":          [],
		},
		"unassign_natural_fit_morale_delta": -5,
		"unassign_natural_fit_fear_delta":    5,
	}


static func _make_save(continuity: int, ase: int, ekwan: int, roster: Array = [], party_ids: Array = []) -> Dictionary:
	return {
		"economy": { "ase": ase, "ekwan": ekwan },
		"sanctum": {
			"continuity": continuity,
			"roster": roster,
			"active_party_ids": party_ids,
			"institutions": {
				"hearth":           { "unlocked": false, "tier": 0, "condition": "neglected", "last_activated_unix": 0, "occupant_ids": [] },
				"training_grounds": { "unlocked": false, "tier": 0, "condition": "neglected", "last_activated_unix": 0, "occupant_ids": [] },
			},
		},
	}


static func _make_echo(id: String, vector: String = "", calling: String = "") -> Dictionary:
	return {
		"id": id,
		"name": id,
		"dominant_vector": vector,
		"calling_origin":  calling,
		"archetype_birth": "",
		"emotion": { "morale_base": 50, "morale_current": 50, "fear_current": 0 },
		"recovery_modifiers": { "morale_multiplier": 1.0, "fear_multiplier": 1.0, "ticks_remaining": 0 },
	}


static func _make_econ(save: Dictionary) -> EconomyService:
	var logger := _make_logger()
	var econ := EconomyService.new()
	econ.init(save, logger)
	return econ


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

static func _t_locked_below_continuity_threshold() -> Dictionary:
	var save := _make_save(0, 100, 100)
	var inst_cfg := _make_inst_cfg()
	var result := InstitutionService.is_candidate("hearth", save, inst_cfg)
	if result:
		return { "ok": false, "error": "Expected is_candidate=false with continuity=0, got true" }
	return { "ok": true, "error": "" }


static func _t_candidate_at_continuity_threshold() -> Dictionary:
	var save := _make_save(1, 100, 100)
	var inst_cfg := _make_inst_cfg()
	var result := InstitutionService.is_candidate("hearth", save, inst_cfg)
	if not result:
		return { "ok": false, "error": "Expected is_candidate=true with continuity=1, got false" }
	return { "ok": true, "error": "" }


static func _t_establish_spends_ekwan_and_unlocks() -> Dictionary:
	var save := _make_save(1, 100, 20)
	var inst_cfg := _make_inst_cfg()
	var logger := _make_logger()
	var econ := _make_econ(save)
	var ok := InstitutionService.establish("hearth", save, econ, inst_cfg, logger, 1)
	if not ok:
		return { "ok": false, "error": "establish returned false" }
	if not InstitutionService.is_unlocked("hearth", save):
		return { "ok": false, "error": "hearth not unlocked after establish" }
	if econ.get_ekwan() != 10:
		return { "ok": false, "error": "Expected ekwan=10 after spending 10, got %d" % econ.get_ekwan() }
	return { "ok": true, "error": "" }


static func _t_establish_fails_insufficient_ekwan() -> Dictionary:
	var save := _make_save(1, 100, 5)
	var inst_cfg := _make_inst_cfg()
	var logger := _make_logger()
	var econ := _make_econ(save)
	var ok := InstitutionService.establish("hearth", save, econ, inst_cfg, logger, 1)
	if ok:
		return { "ok": false, "error": "Expected establish to fail with only 5 ekwan (cost 10)" }
	if InstitutionService.is_unlocked("hearth", save):
		return { "ok": false, "error": "hearth should not be unlocked after failed establish" }
	return { "ok": true, "error": "" }


static func _t_assign_spends_ase_and_adds_occupant() -> Dictionary:
	var echo := _make_echo("e1")
	var save := _make_save(1, 100, 20, [echo])
	var inst_cfg := _make_inst_cfg()
	var logger := _make_logger()
	var econ := _make_econ(save)
	InstitutionService.establish("hearth", save, econ, inst_cfg, logger, 1)
	var ase_before := econ.get_ase()
	var ok := InstitutionService.assign_echo("hearth", "e1", save, econ, inst_cfg, logger, 2)
	if not ok:
		return { "ok": false, "error": "assign_echo returned false" }
	var institutions_v: Variant = (save["sanctum"] as Dictionary).get("institutions", {})
	var occupants: Array = ((institutions_v as Dictionary).get("hearth", {}) as Dictionary).get("occupant_ids", []) as Array
	if not occupants.has("e1"):
		return { "ok": false, "error": "e1 not in occupant_ids after assign" }
	if econ.get_ase() != ase_before - 5:
		return { "ok": false, "error": "Expected ase reduced by 5, got ase=%d" % econ.get_ase() }
	return { "ok": true, "error": "" }


static func _t_assign_auto_removes_from_party() -> Dictionary:
	var echo := _make_echo("e1")
	var save := _make_save(1, 100, 20, [echo], ["e1"])
	var inst_cfg := _make_inst_cfg()
	var logger := _make_logger()
	var econ := _make_econ(save)
	InstitutionService.establish("hearth", save, econ, inst_cfg, logger, 1)
	InstitutionService.assign_echo("hearth", "e1", save, econ, inst_cfg, logger, 2)
	var party: Array = (save["sanctum"] as Dictionary).get("active_party_ids", []) as Array
	if party.has("e1"):
		return { "ok": false, "error": "e1 should have been removed from party on assign" }
	return { "ok": true, "error": "" }


static func _t_assign_fails_at_capacity() -> Dictionary:
	var roster: Array = []
	for i in range(5):
		roster.append(_make_echo("e%d" % i))
	var save := _make_save(1, 200, 50, roster)
	var inst_cfg := _make_inst_cfg()
	var logger := _make_logger()
	var econ := _make_econ(save)
	InstitutionService.establish("hearth", save, econ, inst_cfg, logger, 1)
	for i in range(4):
		InstitutionService.assign_echo("hearth", "e%d" % i, save, econ, inst_cfg, logger, 2 + i)
	var ok := InstitutionService.assign_echo("hearth", "e4", save, econ, inst_cfg, logger, 6)
	if ok:
		return { "ok": false, "error": "5th assign should have failed (capacity=4)" }
	return { "ok": true, "error": "" }


static func _t_remove_spends_ekwan_and_removes() -> Dictionary:
	var echo := _make_echo("e1")
	var save := _make_save(1, 100, 50, [echo])
	var inst_cfg := _make_inst_cfg()
	var logger := _make_logger()
	var econ := _make_econ(save)
	InstitutionService.establish("hearth", save, econ, inst_cfg, logger, 1)
	InstitutionService.assign_echo("hearth", "e1", save, econ, inst_cfg, logger, 2)
	var ekwan_before := econ.get_ekwan()
	var ok := InstitutionService.remove_echo("hearth", "e1", save, econ, inst_cfg, logger, 3)
	if not ok:
		return { "ok": false, "error": "remove_echo returned false" }
	var institutions_v: Variant = (save["sanctum"] as Dictionary).get("institutions", {})
	var occupants: Array = ((institutions_v as Dictionary).get("hearth", {}) as Dictionary).get("occupant_ids", []) as Array
	if occupants.has("e1"):
		return { "ok": false, "error": "e1 still in occupant_ids after remove" }
	if econ.get_ekwan() != ekwan_before - 3:
		return { "ok": false, "error": "Expected ekwan reduced by 3, got ekwan=%d" % econ.get_ekwan() }
	return { "ok": true, "error": "" }


static func _t_condition_neglected_when_no_occupants() -> Dictionary:
	var save := _make_save(1, 100, 20)
	var inst_cfg := _make_inst_cfg()
	var logger := _make_logger()
	var econ := _make_econ(save)
	InstitutionService.establish("hearth", save, econ, inst_cfg, logger, 1)
	var cond := InstitutionService.get_condition("hearth", save)
	if cond != InstitutionService.CONDITION_NEGLECTED:
		return { "ok": false, "error": "Expected neglected with no occupants, got: " + cond }
	return { "ok": true, "error": "" }


static func _t_condition_healthy_within_threshold() -> Dictionary:
	var echo := _make_echo("e1")
	var save := _make_save(1, 100, 50, [echo])
	var inst_cfg := _make_inst_cfg()
	var logger := _make_logger()
	var econ := _make_econ(save)
	InstitutionService.establish("hearth", save, econ, inst_cfg, logger, 1)
	InstitutionService.assign_echo("hearth", "e1", save, econ, inst_cfg, logger, 2)
	# Seed last_activated_unix to 1000 seconds ago (well within 3600s healthy threshold)
	var now := 10000
	var hearth: Dictionary = ((save["sanctum"] as Dictionary).get("institutions", {}) as Dictionary).get("hearth", {}) as Dictionary
	hearth["last_activated_unix"] = now - 1000
	InstitutionService.update_condition("hearth", save, inst_cfg.get("hearth", {}), now, logger, 3)
	var cond := InstitutionService.get_condition("hearth", save)
	if cond != InstitutionService.CONDITION_HEALTHY:
		return { "ok": false, "error": "Expected healthy at 1000s elapsed, got: " + cond }
	return { "ok": true, "error": "" }


static func _t_condition_strained_outside_healthy() -> Dictionary:
	var echo := _make_echo("e1")
	var save := _make_save(1, 100, 50, [echo])
	var inst_cfg := _make_inst_cfg()
	var logger := _make_logger()
	var econ := _make_econ(save)
	InstitutionService.establish("hearth", save, econ, inst_cfg, logger, 1)
	InstitutionService.assign_echo("hearth", "e1", save, econ, inst_cfg, logger, 2)
	var now := 20000
	var hearth: Dictionary = ((save["sanctum"] as Dictionary).get("institutions", {}) as Dictionary).get("hearth", {}) as Dictionary
	hearth["last_activated_unix"] = now - 7200  # 7200s > healthy_max 3600s, < strained_max 10800s
	InstitutionService.update_condition("hearth", save, inst_cfg.get("hearth", {}), now, logger, 3)
	var cond := InstitutionService.get_condition("hearth", save)
	if cond != InstitutionService.CONDITION_STRAINED:
		return { "ok": false, "error": "Expected strained at 7200s elapsed, got: " + cond }
	return { "ok": true, "error": "" }


static func _t_compatibility_natural_fit() -> Dictionary:
	var echo := _make_echo("e1", "pillar", "onyamesu")
	var inst_cfg := _make_inst_cfg()
	var result := InstitutionService.compute_compatibility(echo, "hearth", inst_cfg)
	if result != InstitutionService.COMPAT_NATURAL:
		return { "ok": false, "error": "Expected natural_fit for pillar vector at Hearth, got: " + result }
	return { "ok": true, "error": "" }


static func _t_determinism() -> Dictionary:
	var echo := _make_echo("e1", "pillar", "okomfo")
	var save := _make_save(1, 100, 50, [echo])
	var inst_cfg := _make_inst_cfg()
	var result_a := InstitutionService.get_snapshot_data(save, inst_cfg, 1)
	var result_b := InstitutionService.get_snapshot_data(save, inst_cfg, 1)
	if result_a.size() != result_b.size():
		return { "ok": false, "error": "Snapshot size differs between identical calls" }
	for i in range(result_a.size()):
		var a: Dictionary = result_a[i]
		var b: Dictionary = result_b[i]
		if str(a.get("id", "")) != str(b.get("id", "")):
			return { "ok": false, "error": "Institution ids differ at index %d" % i }
		if a.get("is_candidate", null) != b.get("is_candidate", null):
			return { "ok": false, "error": "is_candidate differs at index %d" % i }
	return { "ok": true, "error": "" }

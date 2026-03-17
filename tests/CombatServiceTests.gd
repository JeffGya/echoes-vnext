# res://tests/CombatServiceTests.gd
# COMBAT-003: Tests for CombatService — the full action resolver.
#
#   1. combat/resolve_melee_base          — atk=10, def=5, neutral morale/fear → damage=5; HP reduced.
#   2. combat/resolve_melee_clamped       — atk=3, def=10 → damage floors at 0; HP unchanged.
#   3. combat/resolve_melee_modifiers     — morale=80 (+3 bonus), fear=60 (-3 penalty) → net delta correct.
#   4. combat/resolve_melee_kills         — hp_before=3, damage sufficient → hp_after=0, is_dead=true, death_round set.
#   5. combat/resolve_guard_reduces_dmg   — guarding defender (guard_state=true) takes reduced damage vs unguarded.
#   6. combat/resolve_refuse              — resolve_action("actor.refuse",...) returns { refused:true }, no HP mutation.
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name CombatServiceTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("combat/resolve_melee_base",        Callable(CombatServiceTests, "_t_resolve_melee_base"))
	runner.register_test("combat/resolve_melee_clamped",     Callable(CombatServiceTests, "_t_resolve_melee_clamped"))
	runner.register_test("combat/resolve_melee_modifiers",   Callable(CombatServiceTests, "_t_resolve_melee_modifiers"))
	runner.register_test("combat/resolve_melee_kills",       Callable(CombatServiceTests, "_t_resolve_melee_kills"))
	runner.register_test("combat/resolve_guard_reduces_dmg", Callable(CombatServiceTests, "_t_resolve_guard_reduces_dmg"))
	runner.register_test("combat/resolve_refuse",            Callable(CombatServiceTests, "_t_resolve_refuse"))


# -------------------------
# Helpers
# -------------------------

static func _make_attacker(atk: int, morale: int = 50, fear: int = 0) -> Dictionary:
	return {
		"id":         "attacker_01",
		"faction":    "echo",
		"actor_type": "echo",
		"atk":        atk,
		"morale":     morale,
		"fear":        fear,
		"guard_state": false,
	}

static func _make_defender(def: int, hp: int, guard_state: bool = false) -> Dictionary:
	return {
		"id":         "defender_01",
		"faction":    "enemy",
		"actor_type": "enemy",
		"def":         def,
		"current_hp":  hp,
		"is_dead":     false,
		"guard_state": guard_state,
	}


# -------------------------
# Tests
# -------------------------

# Test 1: resolve_melee_base
# atk=10, def=5, morale=50 (neutral), fear=0 → effective_def=5, base=5, bonus=0, penalty=0 → damage=5.
static func _t_resolve_melee_base() -> Dictionary:
	var attacker := _make_attacker(10)
	var defender := _make_defender(5, 20)

	var result: Dictionary = CombatService.resolve_action("melee_attack", attacker, defender, 1)

	if str(result.get("action_type", "")) != "melee_attack":
		return { "ok": false, "error": "Expected action_type='melee_attack', got: %s" % result.get("action_type") }
	if int(result.get("damage", -1)) != 5:
		return { "ok": false, "error": "Expected damage=5, got: %d" % int(result.get("damage", -1)) }
	if int(result.get("defender_hp_after", -1)) != 15:
		return { "ok": false, "error": "Expected defender_hp_after=15, got: %d" % int(result.get("defender_hp_after", -1)) }
	if int(defender["current_hp"]) != 15:
		return { "ok": false, "error": "Defender dict not mutated: expected current_hp=15, got: %d" % int(defender["current_hp"]) }

	return { "ok": true }


# Test 2: resolve_melee_clamped
# atk=3, def=10 → base = max(0, 3-10) = 0; morale/fear neutral → damage=0; HP unchanged.
static func _t_resolve_melee_clamped() -> Dictionary:
	var attacker := _make_attacker(3)
	var defender := _make_defender(10, 20)

	var result: Dictionary = CombatService.resolve_action("melee_attack", attacker, defender, 1)

	if int(result.get("damage", -1)) != 0:
		return { "ok": false, "error": "Expected damage=0 (clamped), got: %d" % int(result.get("damage", -1)) }
	if int(defender["current_hp"]) != 20:
		return { "ok": false, "error": "Expected HP unchanged at 20, got: %d" % int(defender["current_hp"]) }

	return { "ok": true }


# Test 3: resolve_melee_modifiers
# atk=10, def=5, morale=80 → bonus=(80-50)/10=3; fear=60 → penalty=60/20=3.
# damage = max(0, 5 + 3 - 3) = 5. Net modifier delta is 0 (bonus and penalty cancel).
# Verify against neutral baseline (morale=50, fear=0) to confirm formula paths.
static func _t_resolve_melee_modifiers() -> Dictionary:
	var base_attacker   := _make_attacker(10, 50, 0)   # neutral
	var modfear_attacker := _make_attacker(10, 80, 60)  # morale=80, fear=60

	var def_base   := _make_defender(5, 20)
	var def_modfear := _make_defender(5, 20)

	var r_base:    Dictionary = CombatService.resolve_action("melee_attack", base_attacker, def_base, 1)
	var r_modfear: Dictionary = CombatService.resolve_action("melee_attack", modfear_attacker, def_modfear, 1)

	# With morale=80 and fear=60: bonus=3, penalty=3 → net delta = 0 vs baseline.
	var base_dmg:    int = int(r_base.get("damage", -1))
	var modfear_dmg: int = int(r_modfear.get("damage", -1))

	if base_dmg != 5:
		return { "ok": false, "error": "Baseline: expected damage=5, got: %d" % base_dmg }
	if modfear_dmg != 5:
		return { "ok": false, "error": "With morale=80 + fear=60: expected damage=5 (net 0 delta), got: %d" % modfear_dmg }

	# Verify high morale alone boosts damage: morale=80, fear=0 → bonus=3, penalty=0 → damage=8.
	var hi_morale := _make_attacker(10, 80, 0)
	var def_hm    := _make_defender(5, 20)
	var r_hm:    Dictionary = CombatService.resolve_action("melee_attack", hi_morale, def_hm, 1)
	if int(r_hm.get("damage", -1)) != 8:
		return { "ok": false, "error": "High morale (80): expected damage=8, got: %d" % int(r_hm.get("damage", -1)) }

	return { "ok": true }


# Test 4: resolve_melee_kills
# hp_before=3, atk=10, def=0 → base=10, damage=10 → hp_after=0, is_dead=true, death_round set.
static func _t_resolve_melee_kills() -> Dictionary:
	var attacker := _make_attacker(10)
	var defender := _make_defender(0, 3)

	var result: Dictionary = CombatService.resolve_action("melee_attack", attacker, defender, 2)

	if int(result.get("defender_hp_after", -1)) != 0:
		return { "ok": false, "error": "Expected defender_hp_after=0, got: %d" % int(result.get("defender_hp_after", -1)) }
	if not bool(defender.get("is_dead", false)):
		return { "ok": false, "error": "Expected defender is_dead=true after lethal hit" }
	if int(defender.get("death_round", -1)) != 2:
		return { "ok": false, "error": "Expected death_round=2, got: %d" % int(defender.get("death_round", -1)) }

	return { "ok": true }


# Test 5: resolve_guard_reduces_dmg
# Guarding defender (guard_state=true) has effective_def doubled → takes less damage vs same attacker unguarded.
static func _t_resolve_guard_reduces_dmg() -> Dictionary:
	var attacker_a := _make_attacker(10)
	var attacker_b := _make_attacker(10)
	var def_unguarded := _make_defender(5, 30, false)
	var def_guarded   := _make_defender(5, 30, true)

	var r_unguarded: Dictionary = CombatService.resolve_action("melee_attack", attacker_a, def_unguarded, 1)
	var r_guarded:   Dictionary = CombatService.resolve_action("melee_attack", attacker_b, def_guarded, 1)

	var dmg_unguarded: int = int(r_unguarded.get("damage", -1))
	var dmg_guarded:   int = int(r_guarded.get("damage", -1))

	# Unguarded: eff_def=5, base=5, damage=5.
	if dmg_unguarded != 5:
		return { "ok": false, "error": "Unguarded: expected damage=5, got: %d" % dmg_unguarded }

	# Guarded: eff_def=5*2=10, base=max(0,10-10)=0, damage=0.
	if dmg_guarded != 0:
		return { "ok": false, "error": "Guarded: expected damage=0 (def doubled), got: %d" % dmg_guarded }

	if dmg_guarded >= dmg_unguarded:
		return { "ok": false, "error": "Guarded should take less damage than unguarded" }

	return { "ok": true }


# Test 6: resolve_refuse
# resolve_action("actor.refuse",...) returns { action_type, refused:true, actor_id }.
# Defender HP must remain unmutated (no damage applied).
static func _t_resolve_refuse() -> Dictionary:
	var attacker := _make_attacker(10)
	attacker["id"] = "echo_refuse_01"
	var defender := _make_defender(5, 20)

	var result: Dictionary = CombatService.resolve_action("actor.refuse", attacker, defender, 1)

	if str(result.get("action_type", "")) != "actor.refuse":
		return { "ok": false, "error": "Expected action_type='actor.refuse', got: %s" % str(result.get("action_type")) }
	if not bool(result.get("refused", false)):
		return { "ok": false, "error": "Expected refused=true in result" }
	if str(result.get("actor_id", "")) != "echo_refuse_01":
		return { "ok": false, "error": "Expected actor_id='echo_refuse_01', got: %s" % str(result.get("actor_id")) }
	if int(defender["current_hp"]) != 20:
		return { "ok": false, "error": "Defender HP mutated by refuse — should be 20, got: %d" % int(defender["current_hp"]) }

	return { "ok": true }

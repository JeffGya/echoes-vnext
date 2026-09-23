# res://tests/CombatConsequenceTests.gd
# V2-COMBAT-001: Tests for combat consequence routing — guard, hesitation, bond bias, vow bias.
#   1. consequence/guard_sets_guard_state_on_self
#   2. consequence/interpose_sets_guard_state_on_ally_not_self
#   3. consequence/hesitating_status_at_fear_40
#   4. consequence/alive_status_at_fear_39
#   5. consequence/refusing_status_at_fear_80
#   6. consequence/neutral_bond_no_protect_bias
#   7. consequence/bond_friend_raises_protect_score
#   8. consequence/bond_rival_lowers_protect_score
#   9. consequence/vow_boosts_cohesion_actions
#  10. consequence/vow_penalizes_aggression_small_party
#  11. consequence/near_death_fires_at_quarter_hp
#  12. consequence/near_death_silent_above_quarter_hp
#  13. consequence/near_death_fires_once_per_actor
#  14. consequence/resist_fear_reduces_hit_fear
#  15. consequence/resist_fear_reduces_near_death_fear
#  16. consequence/resist_fear_inert_at_nascent
#  17. consequence/resist_fear_hit_voices_combat_resilient_next_turn
#  18. consequence/resist_fear_reduces_ally_death_knock
#  19. consequence/combat_resilient_bark_has_cooldown
#  20. consequence/resist_fear_reduces_ally_ko_spread_fear
#
# All tests are pure unit tests — no runtime or save file needed.
# Run via Debug Panel: tests

extends RefCounted
class_name CombatConsequenceTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("consequence/guard_sets_guard_state_on_self",
		Callable(CombatConsequenceTests, "_t_guard_sets_guard_state_on_self"))
	runner.register_test("consequence/interpose_sets_guard_state_on_ally_not_self",
		Callable(CombatConsequenceTests, "_t_interpose_sets_guard_state_on_ally_not_self"))
	runner.register_test("consequence/alive_status_at_fear_40",
		Callable(CombatConsequenceTests, "_t_alive_status_at_fear_40"))
	runner.register_test("consequence/alive_status_at_fear_39",
		Callable(CombatConsequenceTests, "_t_alive_status_at_fear_39"))
	runner.register_test("consequence/alive_status_at_fear_80",
		Callable(CombatConsequenceTests, "_t_alive_status_at_fear_80"))
	runner.register_test("consequence/neutral_bond_no_protect_bias",
		Callable(CombatConsequenceTests, "_t_neutral_bond_no_protect_bias"))
	runner.register_test("consequence/bond_friend_raises_protect_score",
		Callable(CombatConsequenceTests, "_t_bond_friend_raises_protect_score"))
	runner.register_test("consequence/bond_rival_lowers_protect_score",
		Callable(CombatConsequenceTests, "_t_bond_rival_lowers_protect_score"))
	runner.register_test("consequence/vow_boosts_cohesion_actions",
		Callable(CombatConsequenceTests, "_t_vow_boosts_cohesion_actions"))
	runner.register_test("consequence/vow_penalizes_aggression_small_party",
		Callable(CombatConsequenceTests, "_t_vow_penalizes_aggression_small_party"))
	runner.register_test("consequence/near_death_fires_at_quarter_hp",
		Callable(CombatConsequenceTests, "_t_near_death_fires_at_quarter_hp"))
	runner.register_test("consequence/near_death_silent_above_quarter_hp",
		Callable(CombatConsequenceTests, "_t_near_death_silent_above_quarter_hp"))
	runner.register_test("consequence/near_death_fires_once_per_actor",
		Callable(CombatConsequenceTests, "_t_near_death_fires_once_per_actor"))
	runner.register_test("consequence/resist_fear_reduces_hit_fear",
		Callable(CombatConsequenceTests, "_t_resist_fear_reduces_hit_fear"))
	runner.register_test("consequence/resist_fear_reduces_near_death_fear",
		Callable(CombatConsequenceTests, "_t_resist_fear_reduces_near_death_fear"))
	runner.register_test("consequence/resist_fear_inert_at_nascent",
		Callable(CombatConsequenceTests, "_t_resist_fear_inert_at_nascent"))
	runner.register_test("consequence/resist_fear_hit_voices_combat_resilient_next_turn",
		Callable(CombatConsequenceTests, "_t_resist_fear_hit_voices_combat_resilient_next_turn"))
	runner.register_test("consequence/resist_fear_reduces_ally_death_knock",
		Callable(CombatConsequenceTests, "_t_resist_fear_reduces_ally_death_knock"))
	runner.register_test("consequence/combat_resilient_bark_has_cooldown",
		Callable(CombatConsequenceTests, "_t_combat_resilient_bark_has_cooldown"))
	runner.register_test("consequence/combat_resilient_cooldown_yields_to_fear_rising",
		Callable(CombatConsequenceTests, "_t_combat_resilient_cooldown_yields_to_fear_rising"))
	runner.register_test("consequence/resist_fear_reduces_ally_ko_spread_fear",
		Callable(CombatConsequenceTests, "_t_resist_fear_reduces_ally_ko_spread_fear"))


# -------------------------
# Tests 1–2: Self-guard and interpose (V2-COMBAT-001 guard routing fix)
# -------------------------

# Test 1: actor.guard intent must set guard_state=true on the guarding actor itself.
static func _t_guard_sets_guard_state_on_self() -> Dictionary:
	var actor := { "id": "echo_a", "faction": "echo", "guard_state": false }
	var sm := ActorStateMachine.new(actor)
	var intent := { "action_type": "actor.guard" }
	var context := { "all_actors": [actor], "cfg": {} }
	sm._update_passive_state(intent, context, 1)
	if not bool(actor.get("guard_state", false)):
		return { "ok": false, "error": "guard_state should be true after actor.guard, got: %s" % str(actor.get("guard_state")) }
	return { "ok": true }


# Test 2: actor.interpose sets guard_state on the protected ally, NOT on the interposer.
static func _t_interpose_sets_guard_state_on_ally_not_self() -> Dictionary:
	var actor_a := { "id": "echo_a", "faction": "echo" }
	var actor_b := { "id": "echo_b", "faction": "echo", "guard_state": false }
	var sm := ActorStateMachine.new(actor_a)
	var intent := { "action_type": "actor.interpose", "target_id": "echo_b" }
	var context := { "all_actors": [actor_a, actor_b], "cfg": {} }
	sm._update_passive_state(intent, context, 1)
	if not bool(actor_b.get("guard_state", false)):
		return { "ok": false, "error": "Ally echo_b should have guard_state=true after interpose" }
	if bool(actor_a.get("guard_state", false)):
		return { "ok": false, "error": "Interposer echo_a should NOT have guard_state=true" }
	return { "ok": true }


# -------------------------
# Tests 3–5: Hesitation band (_derive_status) — V2-COMBAT-001
# -------------------------

# Test 3: fear does not replace the operational actor status.
static func _t_alive_status_at_fear_40() -> Dictionary:
	var actor := { "is_dead": false, "guard_state": false, "fear": 40 }
	var status: String = EncounterSnapshotBuilder._derive_status(actor)
	if status != "alive":
		return { "ok": false, "error": "Fear must not replace operational status; got: '%s'" % status }
	return { "ok": true }


# Test 4: fear=39 → "alive" (below hesitation threshold).
static func _t_alive_status_at_fear_39() -> Dictionary:
	var actor := { "is_dead": false, "guard_state": false, "fear": 39 }
	var status: String = EncounterSnapshotBuilder._derive_status(actor)
	if status != "alive":
		return { "ok": false, "error": "Expected 'alive' at fear=39, got: '%s'" % status }
	return { "ok": true }


# Test 5: refusal is an action/event, not an operational actor status.
static func _t_alive_status_at_fear_80() -> Dictionary:
	var actor := { "is_dead": false, "guard_state": false, "fear": 80 }
	var status: String = EncounterSnapshotBuilder._derive_status(actor)
	if status != "alive":
		return { "ok": false, "error": "Refusal must not replace operational status; got: '%s'" % status }
	return { "ok": true }


# -------------------------
# Tests 6–8: Bond score bias in BehaviorArbiter (BOND-002 integration)
# -------------------------

static func _bond_thresholds() -> Dictionary:
	return { "rival_max": -30, "friend_min": 30 }


# Test 6: indifferent bond (strength=0) adds no bias to protect_ally score.
static func _t_neutral_bond_no_protect_bias() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var actor := { "id": "echo_a", "faction": "echo" }
	var bonds: Array = [{ "actor_a": "echo_a", "actor_b": "echo_b", "strength": 0 }]
	var base_score := 30.0
	var candidate := { "action_type": "protect_ally", "target_id": "echo_b", "_score": base_score }
	var candidates: Array = [candidate]
	var bond_cfg := { "friend_protect_weight_bonus": 12.0, "rival_protect_penalty": -10.0 }
	arbiter._apply_bond_bias(candidates, actor, bonds, _bond_thresholds(), bond_cfg)
	var new_score := float(candidates[0].get("_score", 0.0))
	if absf(new_score - base_score) > 0.001:
		return { "ok": false, "error": "Indifferent bond should not change score (expected %.1f, got %.1f)" % [base_score, new_score] }
	return { "ok": true }


# Test 7: friend bond (strength=50) raises protect_ally score by friend_bonus.
static func _t_bond_friend_raises_protect_score() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var actor := { "id": "echo_a", "faction": "echo" }
	var bonds: Array = [{ "actor_a": "echo_a", "actor_b": "echo_b", "strength": 50 }]
	var base_score := 30.0
	var candidate := { "action_type": "protect_ally", "target_id": "echo_b", "_score": base_score }
	var candidates: Array = [candidate]
	var bond_cfg := { "friend_protect_weight_bonus": 12.0, "rival_protect_penalty": -10.0 }
	arbiter._apply_bond_bias(candidates, actor, bonds, _bond_thresholds(), bond_cfg)
	var new_score := float(candidates[0].get("_score", 0.0))
	if new_score <= base_score:
		return { "ok": false, "error": "Friend bond should raise protect_ally score (expected > %.1f, got %.1f)" % [base_score, new_score] }
	if absf(new_score - (base_score + 12.0)) > 0.001:
		return { "ok": false, "error": "Friend bonus expected +12 (got %.1f)" % new_score }
	return { "ok": true }


# Test 8: rival bond (strength=-50) lowers protect_ally score by rival_penalty.
static func _t_bond_rival_lowers_protect_score() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var actor := { "id": "echo_a", "faction": "echo" }
	var bonds: Array = [{ "actor_a": "echo_a", "actor_b": "echo_b", "strength": -50 }]
	var base_score := 30.0
	var candidate := { "action_type": "protect_ally", "target_id": "echo_b", "_score": base_score }
	var candidates: Array = [candidate]
	var bond_cfg := { "friend_protect_weight_bonus": 12.0, "rival_protect_penalty": -10.0 }
	arbiter._apply_bond_bias(candidates, actor, bonds, _bond_thresholds(), bond_cfg)
	var new_score := float(candidates[0].get("_score", 0.0))
	if new_score >= base_score:
		return { "ok": false, "error": "Rival bond should lower protect_ally score (expected < %.1f, got %.1f)" % [base_score, new_score] }
	if absf(new_score - (base_score - 10.0)) > 0.001:
		return { "ok": false, "error": "Rival penalty expected -10 (got %.1f)" % new_score }
	return { "ok": true }


# -------------------------
# Tests 9–10: Vow score bias in BehaviorArbiter (VOW-001 integration)
# -------------------------

# Test 9: tikoro_nko_agyina vow with full party (>=3) boosts protect_ally and actor.guard.
static func _t_vow_boosts_cohesion_actions() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var active_vow := { "vow_id": "tikoro_nko_agyina", "tier": 1 }
	var protect_base := 30.0
	var guard_base   := 20.0
	var candidates: Array = [
		{ "action_type": "protect_ally", "target_id": "echo_b", "_score": protect_base },
		{ "action_type": "actor.guard",  "target_id": "",       "_score": guard_base   },
	]
	arbiter._apply_vow_bias(candidates, active_vow, 3)  # party_size >= 3
	if float(candidates[0].get("_score", 0.0)) <= protect_base:
		return { "ok": false, "error": "protect_ally should be boosted by tikoro vow with full party (>=3)" }
	if float(candidates[1].get("_score", 0.0)) <= guard_base:
		return { "ok": false, "error": "actor.guard should be boosted by tikoro vow with full party (>=3)" }
	return { "ok": true }


# Test 10: tikoro_nko_agyina with small party (<3) penalizes melee_attack and actor.move.
static func _t_vow_penalizes_aggression_small_party() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var active_vow := { "vow_id": "tikoro_nko_agyina", "tier": 1 }
	var melee_base := 40.0
	var move_base  := 30.0
	var candidates: Array = [
		{ "action_type": "melee_attack", "target_id": "enemy_a", "_score": melee_base },
		{ "action_type": "actor.move",   "target_id": "enemy_a", "_score": move_base  },
	]
	arbiter._apply_vow_bias(candidates, active_vow, 2)  # party_size < 3
	if float(candidates[0].get("_score", 0.0)) >= melee_base:
		return { "ok": false, "error": "melee_attack should be penalized by tikoro vow with small party (<3)" }
	if float(candidates[1].get("_score", 0.0)) >= move_base:
		return { "ok": false, "error": "actor.move should be penalized by tikoro vow with small party (<3)" }
	return { "ok": true }


# -------------------------
# Tests 11–13: near-death trigger (V2-INFRA-003 D01)
#
# The trigger fires once per actor when a hit leaves it at or below a quarter of its maximum
# health, paying data.combat.emotion.morale_on_near_death and .fear_on_near_death. It read
# max_hp at the top level of the actor dict, where no builder writes it, so the guard default
# of 1 made `current_hp * 4 <= max_hp` unsatisfiable and the branch never ran. These three
# tests pin the live branch: it fires exactly at the boundary, stays silent one HP above it,
# and pays only once.
#
# Damage here is exact, not sampled: CombatService._melee_damage is atk − def, plus
# (morale − 50) / 10, minus fear / 20, with no RNG. atk 10 / def 0 / morale 50 / fear 0 = 10.
# -------------------------

# max_hp 100, so the boundary is current_hp 25. def 0 keeps the 10 damage exact.
static func _nd_actor(id: String, faction: String, atk: int, current_hp: int) -> Dictionary:
	return {
		"id": id, "name": id, "actor_type": "echo", "faction": faction,
		"rank": 1, "calling_origin": "okofor", "archetype_birth": "empathic",
		"is_dead": false, "death_round": 0, "level": 1, "xp_total": 0,
		"current_hp": current_hp,
		"stats": { "max_hp": 100, "atk": atk, "def": 0, "agi": 5, "int": 5, "cha": 5 },
		"speed": 5, "morale": 50, "fear": 0, "fear_base": 0,
		"grid_pos": { "col": 0, "row": 0 },
		"traits": { "courage": 50, "wisdom": 50, "faith": 50 }, "vector_scores": {},
		"leadership_traits": [], "resilience_traits": [],
	}


## One melee activation of `attacker` against `target`, through the production path.
static func _nd_activate(attacker: Dictionary, target: Dictionary, bdata: Dictionary) -> void:
	var ectx := EncounterContext.new()
	ectx.actors = [attacker, target]
	var svc := CombatTurnActionService.new(StructuredLogger.new())
	svc.resolve_activation(
		attacker,
		{ "action_type": "melee_attack", "target_id": str(target.get("id", "")) },
		"melee_attack",
		ActorStateMachine.new(attacker),
		ectx,
		bdata,
		_nd_balance().get("data", {}).get("maturity_expression", {}),
		1, 1)


static func _nd_balance() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	return parsed if parsed is Dictionary else {}


# Test 11: a hit landing exactly on 25% of max_hp fires morale + fear, using the authored keys.
static func _t_near_death_fires_at_quarter_hp() -> Dictionary:
	var bdata: Dictionary = _nd_balance().get("data", {})
	var emo: Dictionary = bdata.get("combat", {}).get("emotion", {})
	var nd_morale: int   = int(emo.get("morale_on_near_death", 0))
	var nd_fear: int     = int(emo.get("fear_on_near_death", 0))
	var fear_per_hit: int = int(emo.get("fear_per_hit", 0))
	if nd_morale <= 0 or nd_fear <= 0:
		return { "ok": false, "error": "balance.json must authorise morale_on_near_death and fear_on_near_death" }

	var attacker := _nd_actor("nd_attacker", "echo", 10, 100)
	var target := _nd_actor("nd_target", "enemy", 0, 35)  # 35 − 10 = 25 = exactly 25% of 100
	_nd_activate(attacker, target, bdata)

	if int(target.get("current_hp", 0)) != 25:
		return { "ok": false, "error": "fixture drift: expected current_hp 25, got %d" % int(target.get("current_hp", 0)) }
	if not bool(target.get("_near_death_morale_fired", false)):
		return { "ok": false, "error": "near-death trigger did not fire at the 25% boundary" }
	if int(target.get("morale", 0)) != 50 + nd_morale:
		return { "ok": false, "error": "expected morale %d, got %d" % [50 + nd_morale, int(target.get("morale", 0))] }
	if int(target.get("fear", 0)) != fear_per_hit + nd_fear:
		return { "ok": false, "error": "expected fear %d (per-hit + near-death), got %d" % [fear_per_hit + nd_fear, int(target.get("fear", 0))] }
	return { "ok": true }


# Test 12: one HP above the boundary the trigger stays silent — only per-hit fear lands.
static func _t_near_death_silent_above_quarter_hp() -> Dictionary:
	var bdata: Dictionary = _nd_balance().get("data", {})
	var emo: Dictionary = bdata.get("combat", {}).get("emotion", {})
	var fear_per_hit: int = int(emo.get("fear_per_hit", 0))

	var attacker := _nd_actor("nd_attacker_b", "echo", 10, 100)
	var target := _nd_actor("nd_target_b", "enemy", 0, 36)  # 36 − 10 = 26, one above the boundary
	_nd_activate(attacker, target, bdata)

	if int(target.get("current_hp", 0)) != 26:
		return { "ok": false, "error": "fixture drift: expected current_hp 26, got %d" % int(target.get("current_hp", 0)) }
	if bool(target.get("_near_death_morale_fired", false)):
		return { "ok": false, "error": "near-death trigger fired one HP above the 25% boundary" }
	if int(target.get("morale", 0)) != 50:
		return { "ok": false, "error": "morale moved above the boundary: %d" % int(target.get("morale", 0)) }
	if int(target.get("fear", 0)) != fear_per_hit:
		return { "ok": false, "error": "expected only per-hit fear %d, got %d" % [fear_per_hit, int(target.get("fear", 0))] }
	return { "ok": true }


# Test 13: the trigger pays once per actor — a second hit below the boundary adds only per-hit fear.
static func _t_near_death_fires_once_per_actor() -> Dictionary:
	var bdata: Dictionary = _nd_balance().get("data", {})
	var emo: Dictionary = bdata.get("combat", {}).get("emotion", {})
	var nd_morale: int    = int(emo.get("morale_on_near_death", 0))
	var nd_fear: int      = int(emo.get("fear_on_near_death", 0))
	var fear_per_hit: int = int(emo.get("fear_per_hit", 0))

	var attacker := _nd_actor("nd_attacker_c", "echo", 10, 100)
	var target := _nd_actor("nd_target_c", "enemy", 0, 35)
	_nd_activate(attacker, target, bdata)
	_nd_activate(attacker, target, bdata)  # 25 → 15, still below the boundary

	if int(target.get("current_hp", 0)) != 15:
		return { "ok": false, "error": "fixture drift: expected current_hp 15, got %d" % int(target.get("current_hp", 0)) }
	if int(target.get("morale", 0)) != 50 + nd_morale:
		return { "ok": false, "error": "near-death morale paid twice: %d" % int(target.get("morale", 0)) }
	if int(target.get("fear", 0)) != (fear_per_hit * 2) + nd_fear:
		return { "ok": false, "error": "expected fear %d, got %d" % [(fear_per_hit * 2) + nd_fear, int(target.get("fear", 0))] }
	return { "ok": true }


# -------------------------
# Tests 14–16: resist_fear on the per-hit and near-death paths
#
# Two identical targets take the same hit; only resilience_traits differs. Rank 3 is the first
# band past nascent in data.maturity_expression.band_by_standing, where the trait may fire.
# -------------------------

static func _rf_target(id: String, rank: int, current_hp: int, resist: bool) -> Dictionary:
	var target := _nd_actor(id, "enemy", 0, current_hp)
	target["rank"] = rank
	target["resilience_traits"] = ["resist_fear"] if resist else []
	return target


# Test 14: 36 − 10 = 26 stays above the near-death boundary, so only per-hit fear lands.
static func _t_resist_fear_reduces_hit_fear() -> Dictionary:
	var bdata: Dictionary = _nd_balance().get("data", {})
	var fear_per_hit: int = int(bdata.get("combat", {}).get("emotion", {}).get("fear_per_hit", 0))
	var plain := _rf_target("rf_plain", 3, 36, false)
	var steady := _rf_target("rf_steady", 3, 36, true)
	_nd_activate(_nd_actor("rf_atk_a", "echo", 10, 100), plain, bdata)
	_nd_activate(_nd_actor("rf_atk_b", "echo", 10, 100), steady, bdata)
	var plain_fear := int(plain.get("fear", 0))
	var steady_fear := int(steady.get("fear", 0))
	if plain_fear != fear_per_hit:
		return { "ok": false, "error": "control drift: expected fear %d, got %d" % [fear_per_hit, plain_fear] }
	if steady_fear >= plain_fear:
		return { "ok": false, "error": "resist_fear did not reduce hit fear: %d vs %d" % [steady_fear, plain_fear] }
	if steady_fear != roundi(float(fear_per_hit) * 0.6):
		return { "ok": false, "error": "expected 40%% reduction to %d, got %d" % [roundi(float(fear_per_hit) * 0.6), steady_fear] }
	return { "ok": true }


# Test 15: 35 − 10 = 25 crosses the boundary; both the hit and the near-death payment shrink.
static func _t_resist_fear_reduces_near_death_fear() -> Dictionary:
	var bdata: Dictionary = _nd_balance().get("data", {})
	var emo: Dictionary = bdata.get("combat", {}).get("emotion", {})
	var fear_per_hit: int = int(emo.get("fear_per_hit", 0))
	var nd_fear: int = int(emo.get("fear_on_near_death", 0))
	var plain := _rf_target("rf_nd_plain", 3, 35, false)
	var steady := _rf_target("rf_nd_steady", 3, 35, true)
	_nd_activate(_nd_actor("rf_nd_atk_a", "echo", 10, 100), plain, bdata)
	_nd_activate(_nd_actor("rf_nd_atk_b", "echo", 10, 100), steady, bdata)
	if not bool(steady.get("_near_death_morale_fired", false)):
		return { "ok": false, "error": "fixture drift: near-death did not fire" }
	if int(plain.get("fear", 0)) != fear_per_hit + nd_fear:
		return { "ok": false, "error": "control drift: expected fear %d, got %d" % [fear_per_hit + nd_fear, int(plain.get("fear", 0))] }
	var expected := roundi(float(fear_per_hit) * 0.6) + roundi(float(nd_fear) * 0.6)
	if int(steady.get("fear", 0)) != expected:
		return { "ok": false, "error": "expected fear %d with resist_fear, got %d" % [expected, int(steady.get("fear", 0))] }
	return { "ok": true }


# Test 16: at a nascent rank the trait stays dormant, matching EmotionService.apply_fear_delta.
static func _t_resist_fear_inert_at_nascent() -> Dictionary:
	var bdata: Dictionary = _nd_balance().get("data", {})
	var plain := _rf_target("rf_n_plain", 1, 36, false)
	var steady := _rf_target("rf_n_steady", 1, 36, true)
	_nd_activate(_nd_actor("rf_n_atk_a", "echo", 10, 100), plain, bdata)
	_nd_activate(_nd_actor("rf_n_atk_b", "echo", 10, 100), steady, bdata)
	if int(steady.get("fear", 0)) != int(plain.get("fear", 0)):
		return { "ok": false, "error": "resist_fear fired at nascent: %d vs %d" % [int(steady.get("fear", 0)), int(plain.get("fear", 0))] }
	return { "ok": true }


# -------------------------
# Test 17: a resist_fear hit is voiced as combat_resilient on the target's own next turn.
# A second living echo keeps combat_last_stand (priority 1) out of the way. The flag must be
# consumed by that turn, so the turn after it does not voice resilience again.
# -------------------------

static func _rf_bark_context(target: Dictionary, bdata: Dictionary) -> Dictionary:
	target["faction"] = "echo"
	var buddy := _nd_actor("rf_bark_buddy", "echo", 10, 100)
	var enemy := _nd_actor("rf_bark_enemy", "enemy", 10, 100)
	enemy["actor_type"] = "enemy"
	enemy["grid_pos"] = { "col": 3, "row": 0 }
	_nd_activate(enemy, target, bdata)
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var context := { "actor": target, "all_actors": [target, buddy, enemy], "cfg": _nd_balance(), "t": 2 }
	var asm := ActorStateMachine.new(target)
	asm.advance_turn(context, logger, 2)
	var first := str(target.get("_bark_context", ""))
	var flag_left := target.has("_resist_fear_fired")
	context["t"] = 3
	ActorStateMachine.new(target).advance_turn(context, logger, 3)
	return { "first": first, "second": str(target.get("_bark_context", "")), "flag_left": flag_left }


static func _t_resist_fear_hit_voices_combat_resilient_next_turn() -> Dictionary:
	var bdata: Dictionary = _nd_balance().get("data", {})
	var steady := _rf_target("rf_bark_steady", 3, 100, true)
	var plain := _rf_target("rf_bark_plain", 3, 100, false)
	var got := _rf_bark_context(steady, bdata)
	var control := _rf_bark_context(plain, bdata)
	if str(control["first"]) == "combat_resilient":
		return { "ok": false, "error": "control echo without resist_fear voiced combat_resilient" }
	if str(got["first"]) != "combat_resilient":
		return { "ok": false, "error": "expected combat_resilient on the next turn, got '%s'" % got["first"] }
	if bool(got["flag_left"]):
		return { "ok": false, "error": "_resist_fear_fired was not consumed by the target's turn" }
	if str(got["second"]) == "combat_resilient":
		return { "ok": false, "error": "combat_resilient repeated on a turn with no new resisted fear" }
	return { "ok": true }


# -------------------------
# Test 18: the joined-ally death knock in FlowEncounterState.build_final_snapshot() pays
# resist_fear's reduced amount, and nothing extra for a rank-1 (nascent) echo.
# -------------------------

static func _t_resist_fear_reduces_ally_death_knock() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var knock := int(cs.get_balance().get("data", {}).get("contact", {}).get("ally", {}).get("death_fear_knock", 0))
	if knock <= 0:
		return { "ok": false, "error": "balance.json must authorise contact.ally.death_fear_knock" }
	var plain := _rf_target("rf_ak_plain", 3, 100, false)
	var steady := _rf_target("rf_ak_steady", 3, 100, true)
	var nascent := _rf_target("rf_ak_nascent", 1, 100, true)
	var ally := _nd_actor("rf_ak_ally", "echo", 10, 0)
	ally["is_ally"] = true
	ally["is_dead"] = true
	for a in [plain, steady, nascent]:
		a["faction"] = "echo"
	var ectx := EncounterContext.new()
	ectx.encounter_id = "rf_ak_enc"
	ectx.combat_result = { "victory": true, "reason": "all_enemies_defeated", "round_ended": 2 }
	ectx.combat_state = { "combat_over": true, "objective": EncounterResolutionModes.COMBAT, "round_counter": 2 }
	ectx.actors = [plain, steady, nascent, ally]
	var ctx := FlowContext.new()
	ctx.config_service = cs
	var logger := StructuredLogger.new()
	logger.set_level("off")
	ctx.logger = logger
	ctx.encounter_ctx = ectx
	FlowEncounterState.build_final_snapshot(ctx, 1)
	if int(plain.get("fear", 0)) != knock:
		return { "ok": false, "error": "control drift: expected fear %d, got %d" % [knock, int(plain.get("fear", 0))] }
	if int(steady.get("fear", 0)) != roundi(float(knock) * 0.6):
		return { "ok": false, "error": "expected resist_fear knock %d, got %d" % [roundi(float(knock) * 0.6), int(steady.get("fear", 0))] }
	if int(nascent.get("fear", 0)) != knock:
		return { "ok": false, "error": "resist_fear fired at nascent: expected %d, got %d" % [knock, int(nascent.get("fear", 0))] }
	return { "ok": true }


# -------------------------
# Test 19 (V2-COMBAT-003.5 Phase 5 decision #47): combat_resilient has its own cooldown
# (data.maturity_expression.combat_resilient.bark_cooldown_ticks), so a resist_fear echo
# resisting fear on two consecutive eligible turns only barks it on the first. Unlike test 17
# above, both turns here genuinely earn resilience_fired — this proves the cooldown gate, not
# just the absence of a second trigger.
# -------------------------

static func _t_combat_resilient_bark_has_cooldown() -> Dictionary:
	var bdata: Dictionary = _nd_balance().get("data", {})
	var steady := _rf_target("rf_cd_steady", 3, 100, true)
	steady["faction"] = "echo"
	var buddy := _nd_actor("rf_cd_buddy", "echo", 10, 100)
	var enemy := _nd_actor("rf_cd_enemy", "enemy", 10, 100)
	enemy["actor_type"] = "enemy"
	enemy["grid_pos"] = { "col": 3, "row": 0 }
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var context := { "actor": steady, "all_actors": [steady, buddy, enemy], "cfg": _nd_balance(), "t": 2 }

	_nd_activate(enemy, steady, bdata)
	if not bool(steady.get("_resist_fear_fired", false)):
		return { "ok": false, "error": "fixture drift: first hit did not set _resist_fear_fired" }
	ActorStateMachine.new(steady).advance_turn(context, logger, 2)
	var first := str(steady.get("_bark_context", ""))
	if first != "combat_resilient":
		return { "ok": false, "error": "expected combat_resilient on the first eligible turn, got '%s'" % first }

	# Second consecutive eligible turn: resist_fear fires again, but the cooldown set by
	# turn 2 (t + bark_cooldown_ticks) must still be active at t=3.
	_nd_activate(enemy, steady, bdata)
	if not bool(steady.get("_resist_fear_fired", false)):
		return { "ok": false, "error": "fixture drift: second hit did not set _resist_fear_fired" }
	context["t"] = 3
	ActorStateMachine.new(steady).advance_turn(context, logger, 3)
	var second := str(steady.get("_bark_context", ""))
	if second == "combat_resilient":
		return { "ok": false, "error": "combat_resilient repeated on a consecutive eligible turn — cooldown not applied" }
	return { "ok": true }


# -------------------------
# Test 19b (V2-COMBAT-003.5 Phase 5 decision #47, follow-up): the cooldown above only
# proves combat_resilient stays silent on its own. This proves WHY it exists — a
# genuinely higher-priority bark must win the slot instead of being crowded out. Calls
# _select_bark directly (established pattern: CombatDivergenceBarkTests._t_cooldown_gated_not_high_priority),
# so the fear crossing is asserted without routing ~40 melee hits through resist_fear's
# ~1-fear-per-hit reduction to reach the threshold.
# -------------------------

static func _t_combat_resilient_cooldown_yields_to_fear_rising() -> Dictionary:
	var actor: Dictionary = { "id": "rf_yield_steady", "fear": 0, "morale": 50 }
	var asm := ActorStateMachine.new(actor, null, {})

	# Turn 1 (t=2): resilience fires and wins the slot, setting the cooldown
	# (_resilient_bark_next_t = t + resilient_cooldown_ticks, default 10 → 12).
	asm._select_bark("stoic", "", "melee_attack", 0, 0, "steady", "steady", false, true, "", 0, 2)
	if asm._bark_context != "combat_resilient":
		return { "ok": false, "error": "expected combat_resilient to win turn 1, got '%s'" % asm._bark_context }

	# Turn 2 (t=3, inside the cooldown window that runs through t=12): resilience is
	# still firing AND fear crosses both the 40 and 60 combat_fear_rising thresholds.
	# The crowd-out fix requires combat_fear_rising to win this slot, not silence.
	asm._bark_line = ""
	asm._bark_context = ""
	asm._select_bark("stoic", "", "melee_attack", 39, 65, "steady", "steady", false, true, "", 1, 3)
	if asm._bark_context == "combat_resilient":
		return { "ok": false, "error": "combat_resilient crowded out combat_fear_rising during its own cooldown" }
	if asm._bark_context != "combat_fear_rising":
		return { "ok": false, "error": "expected combat_fear_rising to win the slot during the cooldown, got '%s'" % asm._bark_context }
	return { "ok": true }


## One round of CombatRoundEmotionService.apply_round_emotion_tick(), isolated to term A:
## a fallen echo ally spreads fear to one living survivor and one living enemy (equal echo/enemy
## counts keeps term D silent; the KO result's action_type is not "melee_attack" so term F stays
## silent; no refuse results so term E stays silent). Returns the survivor's resulting fear.
static func _ako_run_survivor(cs: ConfigService, expr_cfg: Dictionary, resist: bool) -> int:
	var fallen := _rf_target("ako_fallen", 3, 0, false)
	fallen["faction"] = "echo"
	fallen["is_dead"] = true
	var survivor := _rf_target("ako_survivor", 3, 100, resist)
	survivor["faction"] = "echo"
	var enemy := _rf_target("ako_enemy", 3, 100, false)
	enemy["faction"] = "enemy"
	var ectx := EncounterContext.new()
	ectx.actors = [fallen, survivor, enemy]
	ectx.last_round_results = [{ "action_type": "other", "target_id": "ako_fallen", "defender_hp_after": 0 }]
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var svc := CombatRoundEmotionService.new(FlowContext.new(), cs, logger)
	svc.apply_round_emotion_tick(ectx, 1, expr_cfg, 1)
	return int(survivor.get("fear", 0))


# -------------------------
# Test 20 (V2-COMBAT-003.5 Phase 5 decision #48): the ally-KO fear spread
# (CombatRoundEmotionService.apply_round_emotion_tick, term A) now goes through the same
# _resist_fear() wrapper as the per-hit/near-death paths. Isolates term A by zeroing
# fear_per_round on a duplicated balance dict — every other term in the tick either does not
# apply here (no refuse/overwhelm results, equal echo/enemy counts) or does not touch fear
# (morale decay, no-damage streak).
# -------------------------

static func _t_resist_fear_reduces_ally_ko_spread_fear() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var emo_cfg: Dictionary = bal.get("data", {}).get("combat", {}).get("emotion", {})
	var fear_per_ally_ko: int = int(emo_cfg.get("fear_per_ally_ko", 0))
	if fear_per_ally_ko <= 0:
		return { "ok": false, "error": "balance.json must authorise combat.emotion.fear_per_ally_ko" }
	# Isolate term A: no other term in the tick may add or remove fear this round.
	(bal["data"]["combat"]["emotion"] as Dictionary)["fear_per_round"] = 0
	cs._balance = bal

	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var plain_fear := _ako_run_survivor(cs, expr_cfg, false)
	var steady_fear := _ako_run_survivor(cs, expr_cfg, true)
	if plain_fear != fear_per_ally_ko:
		return { "ok": false, "error": "control drift: expected fear %d, got %d" % [fear_per_ally_ko, plain_fear] }
	if steady_fear >= plain_fear:
		return { "ok": false, "error": "resist_fear did not reduce ally-KO spread fear: %d vs %d" % [steady_fear, plain_fear] }
	if steady_fear != roundi(float(fear_per_ally_ko) * 0.6):
		return { "ok": false, "error": "expected 40%% reduction to %d, got %d" % [roundi(float(fear_per_ally_ko) * 0.6), steady_fear] }
	return { "ok": true }

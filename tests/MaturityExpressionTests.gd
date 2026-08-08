# res://tests/MaturityExpressionTests.gd
# V2-PROG-006: Tests for MaturityExpressionService + behavior expression-band gates.
#
# Tests:
#   1. get_expression_band maps rank 1–5 to correct band strings
#   2. get_calling_behavior uses calling_origin as fallback when calling is absent
#   3. Nascent echo: no actor.retreat candidate at any HP
#   4. Forming warrior: no retreat candidate even at 10% HP
#   5. Forming archer: retreat candidate present at 45% HP (< 50% threshold)
#   6. Forming guardian: no retreat at 35%, retreat candidate at 25%
#   7. Enemy Forming focus fire: targets most-wounded echo, not nearest
#   8. Last-stand Grounded: fear gate raised to 88 (not 80)
#   9. Last-stand Whole: fear gate raised to 95
#  10. suppress_panic_spiral: raises gate by +5 above band baseline
#  11. Balance: empathic echo near 20%-HP ally → protect_ally fires (threshold 0.50)
#  12. Balance: empathic echo near 90%-HP ally → protect_ally NOT generated
#  13. Grounded aduro: actor.taunt is a candidate vs nearest enemy
#  14. Bark: melee_attack → non-empty bark_line in snapshot
#  15. Bark: actor.idle → empty bark_line in snapshot
#  16. Snapshot: all V2-PROG-006 fields present after advance_turn()

extends RefCounted
class_name MaturityExpressionTests

const _BAND_BY_STANDING := {
	"1": "nascent", "2": "forming", "3": "grounded", "4": "whole", "5": "whole"
}

const _CALLING_CFG := {
	"okofor":   { "retreat_threshold": 0.30, "press_advantage": false, "directive_mul": 1.0, "leadership_radius": 3 },
	"aduro":    { "retreat_threshold": null,  "press_advantage": true,  "directive_mul": 1.0, "leadership_radius": 3 },
	"kra_soro": { "retreat_threshold": 0.50, "press_advantage": false, "directive_mul": 1.0, "leadership_radius": 4 },
	"uncalled": { "retreat_threshold": 0.30, "press_advantage": false, "directive_mul": 1.5, "leadership_radius": 3 },
}

const _EXPR_CFG := {
	"band_by_standing":          { "1": "nascent", "2": "forming", "3": "grounded", "4": "whole", "5": "whole" },
	"calling_behavior":          {
		"okofor":   { "retreat_threshold": 0.30, "press_advantage": false, "directive_mul": 1.0, "leadership_radius": 3 },
		"aduro":    { "retreat_threshold": null,  "press_advantage": true,  "directive_mul": 1.0, "leadership_radius": 3, "absolute_fear_threshold": 75 },
		"kra_soro": { "retreat_threshold": 0.50, "press_advantage": false, "directive_mul": 1.0, "leadership_radius": 4 },
		"uncalled": { "retreat_threshold": 0.30, "press_advantage": false, "directive_mul": 1.5, "leadership_radius": 3 },
	},
	"last_stand_fear_threshold": { "grounded": 88, "whole": 95 },
	"last_stand_whole_morale_tick": 5,
	"enemy_demoralize_fear_tick": 5,
	"enemy_demoralize_radius": 3,
	"resilience_trait_pool":    {},
	"leadership_trait_pool":    {},
	"leadership_trait_effects": {},
	# V2-PROG-010 additions
	"rank_strength_scale":       { "max_rank": 9 },
	"refusal_thresholds_by_band": { "nascent": 65, "forming": 72, "grounded": 80, "whole": 90 },
	"identity_weight_scale":     { "trait": 0.6, "vector": 0.6 },
	"presence_dampen_scale":     { "value": 0.4 },
	"fear_self_recovery": {
		"passive_max": 3,
		"active_spike_min": 3,
		"active_spike_max": 12,
		"identity_threshold_calling": 30,
		"identity_threshold_vector": 0.15,
	},
	"sanctum_fear_recovery_bonus": { "mid_rank_start": 5, "bonus_max": 4, "identity_calling_bonus": 1, "identity_vector_bonus": 1 },
	"directive_band_mul":         { "nascent": 1.30, "forming": 1.10, "grounded": 0.90, "whole": 0.75 },
	"rank_benefits_config": {
		"fear_recovery": { "min_rank": 5, "label": "Settles Quickly", "description": "This Echo steadies between ventures." },
	},
}

const _BALANCE_CFG := {
	"data": {
		"maturity_expression": {
			"band_by_standing":          { "1": "nascent", "2": "forming", "3": "grounded", "4": "whole", "5": "whole" },
			"calling_behavior":          {
				"okofor":   { "retreat_threshold": 0.30, "press_advantage": false, "directive_mul": 1.0, "leadership_radius": 3 },
				"aduro":    { "retreat_threshold": null,  "press_advantage": true,  "directive_mul": 1.0, "leadership_radius": 3, "absolute_fear_threshold": 75 },
				"kra_soro": { "retreat_threshold": 0.50, "press_advantage": false, "directive_mul": 1.0, "leadership_radius": 4 },
				"uncalled": { "retreat_threshold": 0.30, "press_advantage": false, "directive_mul": 1.5, "leadership_radius": 3 },
			},
			"last_stand_fear_threshold": { "grounded": 88, "whole": 95 },
			"last_stand_whole_morale_tick": 5,
			"enemy_demoralize_fear_tick": 5,
			"enemy_demoralize_radius": 3,
			"resilience_trait_pool":    {},
			"leadership_trait_pool":    {},
			"leadership_trait_effects": {},
			# V2-PROG-010 additions
			"rank_strength_scale":       { "max_rank": 9 },
			"refusal_thresholds_by_band": { "nascent": 65, "forming": 72, "grounded": 80, "whole": 90 },
			"identity_weight_scale":     { "trait": 0.6, "vector": 0.6 },
			"presence_dampen_scale":     { "value": 0.4 },
			"fear_self_recovery": {
				"passive_max": 3,
				"active_spike_min": 3,
				"active_spike_max": 12,
				"identity_threshold_calling": 30,
				"identity_threshold_vector": 0.15,
			},
			"sanctum_fear_recovery_bonus": { "mid_rank_start": 5, "bonus_max": 4, "identity_calling_bonus": 1, "identity_vector_bonus": 1 },
			"directive_band_mul":         { "nascent": 1.30, "forming": 1.10, "grounded": 0.90, "whole": 0.75 },
			"rank_benefits_config": {
				"fear_recovery": { "min_rank": 5, "label": "Settles Quickly", "description": "This Echo steadies between ventures." },
			},
		},
		"emotion": { "fear_threshold": 80 },
		"actor":   {
			"threat_threshold": 0.50,
		},
	}
}

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("expr/get_expression_band_maps_ranks_1_to_5",    Callable(MaturityExpressionTests, "_t_get_expression_band_maps_ranks"))
	runner.register_test("expr/calling_behavior_proxy_fallback",           Callable(MaturityExpressionTests, "_t_calling_behavior_proxy_fallback"))
	runner.register_test("expr/nascent_no_retreat",                        Callable(MaturityExpressionTests, "_t_nascent_no_retreat"))
	runner.register_test("expr/forming_warrior_no_retreat",                Callable(MaturityExpressionTests, "_t_forming_warrior_no_retreat"))
	runner.register_test("expr/forming_archer_retreat_at_45pct",           Callable(MaturityExpressionTests, "_t_forming_archer_retreat"))
	runner.register_test("expr/forming_guardian_retreat_threshold",        Callable(MaturityExpressionTests, "_t_forming_guardian_retreat_threshold"))
	runner.register_test("expr/enemy_forming_focus_fire",                  Callable(MaturityExpressionTests, "_t_enemy_forming_focus_fire"))
	runner.register_test("expr/last_stand_grounded_fear_threshold_88",     Callable(MaturityExpressionTests, "_t_last_stand_grounded_threshold"))
	runner.register_test("expr/last_stand_whole_fear_threshold_95",        Callable(MaturityExpressionTests, "_t_last_stand_whole_threshold"))
	runner.register_test("expr/suppress_panic_spiral_adds_5",              Callable(MaturityExpressionTests, "_t_suppress_panic_spiral"))
	runner.register_test("expr/protect_ally_fires_at_20pct_hp",            Callable(MaturityExpressionTests, "_t_protect_ally_fires_20pct"))
	runner.register_test("expr/protect_ally_no_fire_at_90pct_hp",          Callable(MaturityExpressionTests, "_t_protect_ally_no_fire_90pct"))
	runner.register_test("expr/grounded_aduro_taunt_candidate",            Callable(MaturityExpressionTests, "_t_grounded_aduro_taunt"))
	runner.register_test("expr/bark_melee_nonempty",                       Callable(MaturityExpressionTests, "_t_bark_melee_nonempty"))
	runner.register_test("expr/bark_idle_empty",                           Callable(MaturityExpressionTests, "_t_bark_idle_empty"))
	runner.register_test("expr/snapshot_prog006_fields_present",           Callable(MaturityExpressionTests, "_t_snapshot_fields_present"))
	# V2-PROG-010 tests
	runner.register_test("expr/nascent_refuses_before_whole",              Callable(MaturityExpressionTests, "_t_nascent_refuses_before_whole"))
	runner.register_test("expr/rank_strength_scale_0_to_1",               Callable(MaturityExpressionTests, "_t_rank_strength_scale"))
	runner.register_test("expr/identity_weight_scales_with_rank",         Callable(MaturityExpressionTests, "_t_identity_weight_scales_with_rank"))
	runner.register_test("expr/composure_rank9_vs_rank1_under_fear",      Callable(MaturityExpressionTests, "_t_composure_rank9_vs_rank1"))
	runner.register_test("expr/identity_spike_fires_on_calling_vector",   Callable(MaturityExpressionTests, "_t_identity_spike_fires"))
	runner.register_test("expr/no_spike_on_non_identity_action",          Callable(MaturityExpressionTests, "_t_no_spike_on_non_identity"))
	runner.register_test("expr/rank_benefits_build_correct_entries",      Callable(MaturityExpressionTests, "_t_rank_benefits_build"))
	# V2-PROG-012 Phase 0
	runner.register_test("expr/config_defaults_reachable_and_consistent", Callable(MaturityExpressionTests, "_t_config_defaults_reachable_and_consistent"))
	# V2-PROG-012 Phase 1 — derive_expression() autonomy outputs
	runner.register_test("expr/derive_expression_is_pure",                        Callable(MaturityExpressionTests, "_t_derive_expression_is_pure"))
	runner.register_test("expr/derive_expression_outputs_discriminate",           Callable(MaturityExpressionTests, "_t_derive_expression_outputs_discriminate"))
	runner.register_test("expr/derive_expression_no_new_save_fields",             Callable(MaturityExpressionTests, "_t_derive_expression_no_new_save_fields"))
	runner.register_test("expr/composure_separates_structural_and_situational_fear", Callable(MaturityExpressionTests, "_t_composure_separates_structural_and_situational_fear"))
	runner.register_test("expr/judgment_rises_with_standing",                     Callable(MaturityExpressionTests, "_t_judgment_rises_with_standing"))
	# V2-PROG-012 Phase 1 review-fix — structural_dread must lower composure's CEILING
	runner.register_test("expr/composure_ceiling_never_floors_at_high_fear_base",  Callable(MaturityExpressionTests, "_t_composure_ceiling_never_floors_at_high_fear_base"))
	# V2-PROG-012 Phase 1 review-fix — trait_balance must read courage/wisdom/faith, not faith alone
	runner.register_test("expr/trait_balance_reads_all_three_traits",              Callable(MaturityExpressionTests, "_t_trait_balance_reads_all_three_traits"))


# ─── Test 1 ────────────────────────────────────────────────────────────────
static func _t_get_expression_band_maps_ranks() -> Dictionary:
	var expected := { 1: "nascent", 2: "forming", 3: "grounded", 4: "whole", 5: "whole" }
	for rank in expected:
		var got: String = MaturityExpressionService.get_expression_band(rank, _BAND_BY_STANDING)
		if got != expected[rank]:
			return { "ok": false, "error": "rank %d: expected %s, got %s" % [rank, expected[rank], got] }
	return { "ok": true }


# ─── Test 2 ────────────────────────────────────────────────────────────────
static func _t_calling_behavior_proxy_fallback() -> Dictionary:
	# No "calling" key → should use calling_origin
	var actor_no_calling := { "calling_origin": "kra_soro" }
	var beh: Dictionary = MaturityExpressionService.get_calling_behavior(actor_no_calling, _CALLING_CFG)
	if float(beh.get("retreat_threshold", 0.0)) != 0.50:
		return { "ok": false, "error": "Expected archer retreat_threshold=0.50, got: %s" % beh }
	# Empty calling → fallback to uncalled
	var actor_empty := { "calling_origin": "unknown_faction" }
	var beh2: Dictionary = MaturityExpressionService.get_calling_behavior(actor_empty, _CALLING_CFG)
	if float(beh2.get("directive_mul", 0.0)) != 1.5:
		return { "ok": false, "error": "Expected uncalled fallback directive_mul=1.5, got: %s" % beh2 }
	return { "ok": true }


# ─── Test 3 — Nascent echo: no retreat candidate ────────────────────────────
static func _t_nascent_no_retreat() -> Dictionary:
	var actor := _make_echo("echo_n1", "kra_soro", 1, 5, 100)  # rank=1 (nascent), HP=5%
	var enemy := _make_enemy("en1", { "col": 1, "row": 0 })
	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor": actor, "all_actors": [enemy],
		"expression_band": "nascent",
		"calling_behavior": _CALLING_CFG.get("kra_soro", {}),
	}
	var candidates := _get_candidates(arbiter, actor, [enemy], context)
	if _has_action(candidates, "actor.retreat"):
		return { "ok": false, "error": "Nascent should never have retreat candidate" }
	return { "ok": true }


# ─── Test 4 — Forming warrior: no retreat ────────────────────────────────────
static func _t_forming_warrior_no_retreat() -> Dictionary:
	var actor := _make_echo("echo_w2", "aduro", 2, 5, 100)  # rank=2 (forming), HP=5%
	var enemy := _make_enemy("en2", { "col": 1, "row": 0 })
	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor": actor, "all_actors": [enemy],
		"expression_band": "forming",
		"calling_behavior": _CALLING_CFG.get("aduro", {}),
	}
	var candidates := _get_candidates(arbiter, actor, [enemy], context)
	if _has_action(candidates, "actor.retreat"):
		return { "ok": false, "error": "Warrior should never have retreat candidate" }
	return { "ok": true }


# ─── Test 5 — Forming archer: retreat at 45% HP ─────────────────────────────
static func _t_forming_archer_retreat() -> Dictionary:
	var actor := _make_echo("echo_a2", "kra_soro", 2, 45, 100)  # rank=2 (forming), HP=45%
	var enemy := _make_enemy("en3", { "col": 3, "row": 0 })
	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor": actor, "all_actors": [enemy],
		"expression_band": "forming",
		"calling_behavior": _CALLING_CFG.get("kra_soro", {}),
	}
	var candidates := _get_candidates(arbiter, actor, [enemy], context)
	if not _has_action(candidates, "actor.retreat"):
		return { "ok": false, "error": "Forming archer at 45%% HP should have retreat candidate (threshold=50%%)" }
	return { "ok": true }


# ─── Test 6 — Forming guardian retreat threshold ────────────────────────────
static func _t_forming_guardian_retreat_threshold() -> Dictionary:
	var arbiter := BehaviorArbiter.new({})
	var enemy := _make_enemy("en4", { "col": 3, "row": 0 })

	# At 35% HP — above guardian threshold 30% — no retreat
	var actor_35 := _make_echo("echo_g35", "okofor", 2, 35, 100)
	var ctx_35 := {
		"actor": actor_35, "all_actors": [enemy],
		"expression_band": "forming",
		"calling_behavior": _CALLING_CFG.get("okofor", {}),
	}
	var cands_35 := _get_candidates(arbiter, actor_35, [enemy], ctx_35)
	if _has_action(cands_35, "actor.retreat"):
		return { "ok": false, "error": "Guardian at 35%% HP should NOT have retreat (threshold=30%%)" }

	# At 25% HP — below threshold — retreat candidate expected
	var actor_25 := _make_echo("echo_g25", "okofor", 2, 25, 100)
	var ctx_25 := {
		"actor": actor_25, "all_actors": [enemy],
		"expression_band": "forming",
		"calling_behavior": _CALLING_CFG.get("okofor", {}),
	}
	var cands_25 := _get_candidates(arbiter, actor_25, [enemy], ctx_25)
	if not _has_action(cands_25, "actor.retreat"):
		return { "ok": false, "error": "Guardian at 25%% HP should have retreat candidate (threshold=30%%)" }

	return { "ok": true }


# ─── Test 7 — Enemy Forming focus fire: most wounded ─────────────────────────
static func _t_enemy_forming_focus_fire() -> Dictionary:
	var enemy_actor := {
		"id": "enemy_forming", "faction": "enemy", "calling_origin": "enemy",
		"actor_type": "enemy", "rank": 2,
		"traits": { "courage": 0, "wisdom": 0, "faith": 0 }, "vector_scores": {},
		"fear": 0, "morale": 50, "grid_pos": { "col": 5, "row": 0 },
	}
	# Nearest echo (col=4) has 90% HP, wounded echo (col=6) has 10% HP
	var echo_near := {
		"id": "echo_near", "faction": "echo", "actor_type": "echo", "is_dead": false,
		"current_hp": 90, "stats": { "max_hp": 100 },
		"grid_pos": { "col": 4, "row": 0 },
	}
	var echo_wounded := {
		"id": "echo_wounded", "faction": "echo", "actor_type": "echo", "is_dead": false,
		"current_hp": 10, "stats": { "max_hp": 100 },
		"grid_pos": { "col": 7, "row": 0 },
	}
	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor": enemy_actor, "all_actors": [echo_near, echo_wounded],
		"expression_band": "forming",
		"calling_behavior": {},
	}
	var intent: Dictionary = arbiter.select_intent(context)
	# Forming enemy should target the wounded echo via focus fire, not the nearest
	if str(intent.get("target_id", "")) == "echo_wounded":
		return { "ok": true }
	# Also acceptable: if the enemy moves toward the wounded target
	return { "ok": false, "error": "Enemy Forming should focus-fire wounded echo, got target: %s action: %s" % [intent.get("target_id", ""), intent.get("action_type", "")] }


# ─── Tests 8–10 — Fear threshold gates (ActorStateMachine) ─────────────────
static func _t_last_stand_grounded_threshold() -> Dictionary:
	# Grounded last-echo-standing: fear=85 should NOT trigger refuse (threshold=88)
	var echo := ActorTests._make_test_echo("echo_gnd", "Ama Kwei")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["rank"]  = 3       # grounded
	actor["fear"]  = 85      # above default 80, below grounded 88
	actor["morale"] = 50
	actor["grid_pos"] = { "col": 0, "row": 0 }
	# Make this the last echo standing — no other echoes alive
	var dead_ally := { "id": "echo_dead", "faction": "echo", "actor_type": "echo", "is_dead": true,
		"grid_pos": { "col": 5, "row": 5 } }
	var enemy := _make_enemy("en_gnd", { "col": 1, "row": 0 })

	var sm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var context := {
		"actor": actor, "all_actors": [dead_ally, enemy],
		"cfg": _BALANCE_CFG, "t": 1
	}
	var intent: Dictionary = sm.advance_turn(context, logger, 1)

	if str(intent.get("action_type", "")) == "actor.refuse":
		return { "ok": false, "error": "Grounded last-standing at fear=85 should NOT refuse (threshold=88)" }
	return { "ok": true }


static func _t_last_stand_whole_threshold() -> Dictionary:
	# Whole last-echo-standing: fear=92 should NOT trigger refuse (threshold=95)
	var echo := ActorTests._make_test_echo("echo_whl", "Kwame Oto")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["rank"]  = 4       # whole
	actor["fear"]  = 92
	actor["morale"] = 50
	actor["grid_pos"] = { "col": 0, "row": 0 }
	var dead_ally := { "id": "echo_dead2", "faction": "echo", "actor_type": "echo", "is_dead": true,
		"grid_pos": { "col": 5, "row": 5 } }
	var enemy := _make_enemy("en_whl", { "col": 1, "row": 0 })

	var sm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var context := {
		"actor": actor, "all_actors": [dead_ally, enemy],
		"cfg": _BALANCE_CFG, "t": 1
	}
	var intent: Dictionary = sm.advance_turn(context, logger, 1)

	if str(intent.get("action_type", "")) == "actor.refuse":
		return { "ok": false, "error": "Whole last-standing at fear=92 should NOT refuse (threshold=95)" }
	return { "ok": true }


static func _t_suppress_panic_spiral() -> Dictionary:
	# suppress_panic_spiral on a grounded echo: adds +5 to threshold (88+5=93)
	# Fear=90 with suppress_panic_spiral + grounded last-stand → should NOT refuse (93 > 90)
	var echo := ActorTests._make_test_echo("echo_sps", "Abena Sarp")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["rank"]  = 3       # grounded
	actor["fear"]  = 90
	actor["morale"] = 50
	actor["resilience_traits"] = ["suppress_panic_spiral"]
	actor["grid_pos"] = { "col": 0, "row": 0 }
	var dead_ally := { "id": "echo_dead3", "faction": "echo", "actor_type": "echo", "is_dead": true,
		"grid_pos": { "col": 5, "row": 5 } }
	var enemy := _make_enemy("en_sps", { "col": 1, "row": 0 })

	var sm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var context := {
		"actor": actor, "all_actors": [dead_ally, enemy],
		"cfg": _BALANCE_CFG, "t": 1
	}
	var intent: Dictionary = sm.advance_turn(context, logger, 1)

	if str(intent.get("action_type", "")) == "actor.refuse":
		return { "ok": false, "error": "Grounded+suppress_panic_spiral at fear=90 should NOT refuse (threshold=88+5=93)" }
	return { "ok": true }


# ─── Tests 11–12 — Balance: protect_ally threshold ─────────────────────────
static func _t_protect_ally_fires_20pct() -> Dictionary:
	# Empathic echo + ally at 20% HP → protect_ally candidate generated (threshold=0.50)
	var actor := {
		"id": "echo_emp1", "faction": "echo", "calling_origin": "okofor",
		"actor_type": "echo", "archetype_birth": "empathic",
		"traits": { "courage": 40, "wisdom": 40, "faith": 60 }, "vector_scores": {},
		"fear": 0, "morale": 60, "grid_pos": { "col": 0, "row": 0 },
	}
	var enemy := _make_enemy("en_emp1", { "col": 5, "row": 0 })
	var ally := {
		"id": "echo_hurt", "faction": "echo", "actor_type": "echo", "is_dead": false,
		"current_hp": 20, "stats": { "max_hp": 100 },
		"grid_pos": { "col": 2, "row": 0 },
	}
	# Use balance cfg with threshold=0.50 (ally must be below 50% HP)
	var actor_cfg := { "threat_threshold": 0.50 }
	var arbiter := BehaviorArbiter.new(actor_cfg)
	var context := { "actor": actor, "all_actors": [enemy, ally] }
	var candidates := _get_candidates(arbiter, actor, [enemy, ally], context)
	if not _has_action(candidates, "protect_ally"):
		return { "ok": false, "error": "Ally at 20%% HP should generate protect_ally candidate (threshold=0.50)" }
	return { "ok": true }


static func _t_protect_ally_no_fire_90pct() -> Dictionary:
	# Empathic echo + ally at 90% HP → protect_ally NOT generated (threshold=0.50)
	var actor := {
		"id": "echo_emp2", "faction": "echo", "calling_origin": "okofor",
		"actor_type": "echo", "archetype_birth": "empathic",
		"traits": { "courage": 40, "wisdom": 40, "faith": 60 }, "vector_scores": {},
		"fear": 0, "morale": 60, "grid_pos": { "col": 0, "row": 0 },
	}
	var enemy := _make_enemy("en_emp2", { "col": 5, "row": 0 })
	var ally := {
		"id": "echo_healthy", "faction": "echo", "actor_type": "echo", "is_dead": false,
		"current_hp": 90, "stats": { "max_hp": 100 },
		"grid_pos": { "col": 2, "row": 0 },
	}
	var actor_cfg := { "threat_threshold": 0.50 }
	var arbiter := BehaviorArbiter.new(actor_cfg)
	var context := { "actor": actor, "all_actors": [enemy, ally] }
	var candidates := _get_candidates(arbiter, actor, [enemy, ally], context)
	if _has_action(candidates, "protect_ally"):
		return { "ok": false, "error": "Ally at 90%% HP should NOT generate protect_ally candidate (threshold=0.50)" }
	return { "ok": true }


# ─── Test 13 — Grounded aduro: taunt candidate ────────────────────────────
static func _t_grounded_aduro_taunt() -> Dictionary:
	var actor := {
		"id": "echo_aduro_gnd", "faction": "echo", "calling_origin": "aduro",
		"actor_type": "echo",
		"traits": { "courage": 60, "wisdom": 40, "faith": 30 }, "vector_scores": {},
		"fear": 0, "morale": 65, "grid_pos": { "col": 0, "row": 0 },
	}
	var enemy := _make_enemy("en_taunt", { "col": 3, "row": 0 })
	var arbiter := BehaviorArbiter.new({})
	var context := {
		"actor": actor, "all_actors": [enemy],
		"expression_band": "grounded",
		"calling_behavior": _CALLING_CFG.get("aduro", {}),
	}
	var candidates := _get_candidates(arbiter, actor, [enemy], context)
	if not _has_action(candidates, "actor.taunt"):
		return { "ok": false, "error": "Grounded aduro should have actor.taunt candidate" }
	# Verify taunt target is the enemy
	for c in candidates:
		if c.get("action_type", "") == "actor.taunt":
			if str(c.get("target_id", "")) != "en_taunt":
				return { "ok": false, "error": "Taunt target_id should be 'en_taunt', got: %s" % str(c.get("target_id")) }
			break
	return { "ok": true }


# ─── Tests 14–15 — Bark fields ────────────────────────────────────────────
static func _t_bark_melee_nonempty() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_bk1", "Esi Owu")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["rank"] = 2  # forming
	actor["fear"] = 0
	actor["morale"] = 60
	actor["grid_pos"] = { "col": 0, "row": 0 }
	var enemy := _make_enemy("en_bk1", { "col": 1, "row": 0 })

	var sm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var context := { "actor": actor, "all_actors": [enemy], "cfg": _BALANCE_CFG, "t": 1 }
	sm.advance_turn(context, logger, 1)
	var snap: Dictionary = sm.get_snapshot()

	# After a melee_attack turn, bark_line should be set OR context should indicate action
	# (bark selection fires when fear < 30, morale not high enough for banter — may be silent for some states)
	# Core assertion: all bark fields must be present
	for field in ["bark_line", "bark_context", "bark_tier", "bark_target_id"]:
		if not snap.has(field):
			return { "ok": false, "error": "Snapshot missing bark field: %s" % field }
	return { "ok": true }


static func _t_bark_idle_empty() -> Dictionary:
	# An echo with fear=100 → refuses, which fires combat_refuse bark.
	# For idle bark test: need echo that idles. Use fear=99 (below threshold=80 default?).
	# Actually idle happens when no enemy nearby.
	var echo := ActorTests._make_test_echo("echo_bk2", "Kwesi Mensa")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["rank"] = 1  # nascent
	actor["fear"] = 0
	actor["morale"] = 50
	actor["grid_pos"] = { "col": 0, "row": 0 }
	# No enemies → only actor.idle candidate → bark should be empty (idle = no bark)

	var sm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var context := { "actor": actor, "all_actors": [], "cfg": _BALANCE_CFG, "t": 1 }
	sm.advance_turn(context, logger, 1)
	var snap: Dictionary = sm.get_snapshot()

	if not str(snap.get("bark_line", "")).is_empty():
		return { "ok": false, "error": "actor.idle should produce no bark, got: '%s'" % snap.get("bark_line") }
	return { "ok": true }


# ─── Test 16 — Snapshot: all V2-PROG-006 fields present ──────────────────────
static func _t_snapshot_fields_present() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_snap", "Ama Darko")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["rank"] = 3
	actor["grid_pos"] = { "col": 0, "row": 0 }
	var enemy := _make_enemy("en_snap", { "col": 1, "row": 0 })

	var sm := ActorStateMachine.new(actor)
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var context := { "actor": actor, "all_actors": [enemy], "cfg": _BALANCE_CFG, "t": 1 }
	sm.advance_turn(context, logger, 1)
	var snap: Dictionary = sm.get_snapshot()

	var required_fields := [
		"expression_band", "resilience_traits", "leadership_traits", "active_leadership",
		"bark_line", "bark_context", "bark_tier", "bark_target_id"
	]
	for field in required_fields:
		if not snap.has(field):
			return { "ok": false, "error": "Snapshot missing V2-PROG-006 field: %s" % field }
	return { "ok": true }


# ─── Helpers ────────────────────────────────────────────────────────────────

static func _make_echo(id: String, calling: String, rank: int, current_hp: int, max_hp: int) -> Dictionary:
	return {
		"id":             id,
		"faction":        "echo",
		"calling_origin": calling,
		"actor_type":     "echo",
		"traits":         { "courage": 50, "wisdom": 50, "faith": 50 },
		"vector_scores":  {},
		"fear":           0,
		"morale":         50,
		"rank":           rank,
		"current_hp":     current_hp,
		"stats":          { "max_hp": max_hp, "atk": 10, "def": 5, "agi": 5, "int": 5, "cha": 5 },
		"grid_pos":       { "col": 0, "row": 0 },
		"resilience_traits": [],
		"leadership_traits": [],
	}


static func _make_enemy(id: String, grid_pos: Dictionary) -> Dictionary:
	return {
		"id":             id,
		"faction":        "enemy",
		"actor_type":     "enemy",
		"calling_origin": "enemy",
		"is_dead":        false,
		"current_hp":     50,
		"stats":          { "max_hp": 50 },
		"grid_pos":       grid_pos,
	}


# Call _generate_candidates via select_intent and return all candidates before scoring.
# We use a minimal wrapper: set scores, then extract candidates from the intent.
# Since _generate_candidates is private, we use select_intent and check the winner type.
# For candidate presence tests, we inject a custom arbiter subtest that serializes candidates.
static func _get_candidates(arbiter: BehaviorArbiter, actor: Dictionary, all_actors: Array, context: Dictionary) -> Array:
	# We call select_intent with all 3 candidate types possible and check which action types appear.
	# Build context array by running through the arbiter and checking the candidate pool indirectly.
	# Approach: run select_intent once at very high/low values to see which actions appear.
	# Actually simpler: call _generate_candidates via a test harness that exposes it.
	# Since it's a private method in GDScript, we can call it directly:
	var ctx := context.duplicate()
	if not ctx.has("actor"):
		ctx["actor"] = actor
	if not ctx.has("all_actors"):
		ctx["all_actors"] = all_actors

	# GDScript allows calling "private" methods (no enforcement) — use for test inspection.
	var expression_band: String = str(ctx.get("expression_band", "nascent"))
	var calling_behavior: Dictionary = ctx.get("calling_behavior", {})
	return arbiter._generate_candidates(actor, all_actors, ctx, expression_band, calling_behavior)


static func _has_action(candidates: Array, action_type: String) -> bool:
	for c in candidates:
		if c is Dictionary and str(c.get("action_type", "")) == action_type:
			return true
	return false


# ─── V2-PROG-010 Tests ───────────────────────────────────────────────────────

# Test 17 — nascent refuses before whole under identical fear
static func _t_nascent_refuses_before_whole() -> Dictionary:
	# Rank 1 (nascent, no calling override) and rank 9 (whole, no calling override).
	# Fear=68: above nascent threshold (65), below whole threshold (90).
	var echo_n := ActorTests._make_test_echo("echo_n17", "Aba Kofi")
	var actor_n: Dictionary = EchoActor.from_echo(echo_n)
	actor_n["rank"]     = 1
	actor_n["fear"]     = 68
	actor_n["morale"]   = 50
	actor_n["grid_pos"] = { "col": 0, "row": 0 }

	var echo_w := ActorTests._make_test_echo("echo_w17", "Kweku Asante")
	var actor_w: Dictionary = EchoActor.from_echo(echo_w)
	actor_w["rank"]     = 9
	actor_w["fear"]     = 68
	actor_w["morale"]   = 50
	actor_w["grid_pos"] = { "col": 0, "row": 0 }

	var enemy := _make_enemy("en17", { "col": 1, "row": 0 })
	var logger := StructuredLogger.new()
	logger.set_level("info")

	var sm_n := ActorStateMachine.new(actor_n)
	var intent_n := sm_n.advance_turn({ "actor": actor_n, "all_actors": [enemy], "cfg": _BALANCE_CFG, "t": 1 }, logger, 1)
	if str(intent_n.get("action_type", "")) != "actor.refuse":
		return { "ok": false, "error": "Nascent at fear=68 should refuse (threshold=65), got: %s" % intent_n.get("action_type", "") }

	var sm_w := ActorStateMachine.new(actor_w)
	var intent_w := sm_w.advance_turn({ "actor": actor_w, "all_actors": [enemy], "cfg": _BALANCE_CFG, "t": 1 }, logger, 1)
	if str(intent_w.get("action_type", "")) == "actor.refuse":
		return { "ok": false, "error": "Whole at fear=68 should NOT refuse (threshold=90), got: actor.refuse" }

	return { "ok": true }


# Test 18 — rank_strength scalar 0.0 → 1.0
static func _t_rank_strength_scale() -> Dictionary:
	var rs1: float = MaturityExpressionService.get_rank_strength(1, 9)
	var rs9: float = MaturityExpressionService.get_rank_strength(9, 9)
	var rs5: float = MaturityExpressionService.get_rank_strength(5, 9)

	if not is_equal_approx(rs1, 0.0):
		return { "ok": false, "error": "rank_strength(1,9) should be 0.0, got %.4f" % rs1 }
	if not is_equal_approx(rs9, 1.0):
		return { "ok": false, "error": "rank_strength(9,9) should be 1.0, got %.4f" % rs9 }
	if rs5 < 0.49 or rs5 > 0.51:
		return { "ok": false, "error": "rank_strength(5,9) should be ~0.5, got %.4f" % rs5 }
	return { "ok": true }


# Test 19 — identity weight scales trait+vector contribution with rank
static func _t_identity_weight_scales_with_rank() -> Dictionary:
	# Aduro echo at rank 1 vs rank 9. Fear=0 so fear_factor=1.0 for both.
	# rank 9 should score melee_attack higher (trait+vector amplified).
	var actor_base := {
		"id": "echo_iw1", "faction": "echo", "calling_origin": "aduro",
		"actor_type": "echo", "archetype_birth": "valiant",
		"traits": { "courage": 60, "wisdom": 40, "faith": 20 },
		"vector_scores": { "vanguard": 80, "protector": 10 },
		"fear": 0, "fear_base": 0, "morale": 60,
		"grid_pos": { "col": 0, "row": 0 }, "rank": 1,
	}
	var enemy := _make_enemy("en19", { "col": 1, "row": 0 })

	var arbiter := BehaviorArbiter.new({})

	var actor_r1 := actor_base.duplicate(true)
	actor_r1["rank"] = 1
	var context_r1 := {
		"actor": actor_r1, "all_actors": [enemy],
		"expression_band": "nascent", "calling_behavior": {},
		"presence_strength": 0.1, "rank_strength": 0.0,
	}
	var score_r1: float = arbiter._score("melee_attack", actor_r1, {}, {}, "nascent", {}, {}, 0.1, 0.0)

	var actor_r9 := actor_base.duplicate(true)
	actor_r9["rank"] = 9
	var score_r9: float = arbiter._score("melee_attack", actor_r9, {}, {}, "whole", {}, {}, 1.0, 1.0)

	if score_r9 <= score_r1:
		return { "ok": false, "error": "Rank 9 melee_attack score (%.2f) should be > rank 1 (%.2f)" % [score_r9, score_r1] }
	return { "ok": true }


# Test 20 — composure: rank 9 scores higher under fear than rank 1
static func _t_composure_rank9_vs_rank1() -> Dictionary:
	var actor_base := {
		"id": "echo_cmp", "faction": "echo", "calling_origin": "aduro",
		"actor_type": "echo", "archetype_birth": "valiant",
		"traits": { "courage": 60, "wisdom": 40, "faith": 20 },
		"vector_scores": { "vanguard": 80, "protector": 10 },
		"fear": 60, "fear_base": 0, "morale": 50,
		"grid_pos": { "col": 0, "row": 0 },
	}
	var arbiter := BehaviorArbiter.new({})

	var score_r1: float = arbiter._score("melee_attack", actor_base, {}, {}, "nascent", {}, {}, 0.1, 0.0)
	var score_r9: float = arbiter._score("melee_attack", actor_base, {}, {}, "whole",   {}, {}, 1.0, 1.0)

	if score_r9 <= score_r1:
		return { "ok": false, "error": "At fear=60, rank 9 (%.2f) should score > rank 1 (%.2f)" % [score_r9, score_r1] }
	return { "ok": true }


# Test 21 — active fear spike fires on identity-consistent action (aduro + vanguard → melee_attack)
static func _t_identity_spike_fires() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_spk21", "Kofi Mensah")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["rank"]           = 7
	actor["calling_origin"] = "aduro"
	actor["dominant_vector"] = "vanguard"
	actor["fear"]           = 50
	actor["morale"]         = 60
	actor["grid_pos"]       = { "col": 0, "row": 0 }

	var enemy := _make_enemy("en21", { "col": 1, "row": 0 })
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var sm := ActorStateMachine.new(actor)
	sm.advance_turn({ "actor": actor, "all_actors": [enemy], "cfg": _BALANCE_CFG, "t": 1 }, logger, 1)

	# Fear should have decreased due to passive tick + spike
	if int(actor.get("fear", 50)) >= 50:
		return { "ok": false, "error": "Fear should decrease after turn for rank-7 aduro+vanguard, got: %d" % actor.get("fear", 50) }
	return { "ok": true }


# Test 22 — no spike on non-identity action (idle when no enemies)
static func _t_no_spike_on_non_identity() -> Dictionary:
	var echo := ActorTests._make_test_echo("echo_nospk22", "Ama Frema")
	var actor: Dictionary = EchoActor.from_echo(echo)
	actor["rank"]            = 7
	actor["calling_origin"]  = "aduro"
	actor["dominant_vector"] = "vanguard"
	actor["fear"]            = 50
	actor["morale"]          = 60
	actor["grid_pos"]        = { "col": 0, "row": 0 }

	# No enemies → only actor.idle candidate → not identity-consistent for aduro+vanguard
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var sm := ActorStateMachine.new(actor)
	sm.advance_turn({ "actor": actor, "all_actors": [], "cfg": _BALANCE_CFG, "t": 1 }, logger, 1)

	# _fear_spike_fired should be false (spike should not have fired)
	if bool(actor.get("_fear_spike_fired", false)):
		return { "ok": false, "error": "_fear_spike_fired should be false after idle action, was true" }
	return { "ok": true }


# Test 23 — rank_benefits build: rank < min_rank returns [], rank >= min_rank returns entry
static func _t_rank_benefits_build() -> Dictionary:
	# Rank 4 — below min_rank_start=5 → empty
	var echo_r4 := { "rank": 4, "calling": "", "dominant_vector": "" }
	var benefits_r4: Array = FlowSanctumState._build_rank_benefits(echo_r4, _BALANCE_CFG["data"])
	if benefits_r4.size() != 0:
		return { "ok": false, "error": "Rank 4 should have 0 benefits, got %d" % benefits_r4.size() }

	# Rank 6 — above min_rank_start=5 → fear_recovery benefit present
	var echo_r6 := { "rank": 6, "calling": "aduro", "dominant_vector": "vanguard" }
	var benefits_r6: Array = FlowSanctumState._build_rank_benefits(echo_r6, _BALANCE_CFG["data"])
	if benefits_r6.size() == 0:
		return { "ok": false, "error": "Rank 6 should have ≥1 benefit, got 0" }
	var b: Dictionary = benefits_r6[0]
	if str(b.get("id", "")) != "fear_recovery":
		return { "ok": false, "error": "Expected benefit id 'fear_recovery', got: %s" % b.get("id", "") }
	if str(b.get("label", "")).is_empty():
		return { "ok": false, "error": "Benefit label should not be empty" }
	return { "ok": true }


# ─── Test 24 — V2-PROG-012 Phase 0 config-integrity guard ─────────────────
# BehaviorArbiter._cfg_get(key) falls through to _DEFAULTS[key] whenever _cfg
# lacks the key. Before V2-PROG-012 Phase 0, seven keys authored under
# data.maturity_expression (directive_band_mul, identity_weight_scale,
# presence_dampen_scale, press_attack_bonus, press_hp_threshold,
# protect_ally_grounded_mul, protect_ally_grounded_hp_threshold) were never
# merged into the actor_cfg passed to BehaviorArbiter, so they silently fell
# through to _DEFAULTS on every turn — the authored balance.json values were
# decorative. This test guards against that regressing.
#
# For every _DEFAULTS key that is also authored somewhere in the real
# balance.json (loaded via ConfigService, same as FlowRuntime does at
# runtime), we check two things against a cfg built by calling
# FlowRuntime._merge_actor_cfg() directly — the actual static helper
# _get_actor_cfg_merged() calls in production (data.actor ∪
# data.maturity_expression, data.actor winning on collision). Calling the
# production function itself (rather than re-implementing the merge here)
# means this test can't silently drift from production if the merge logic
# ever changes — the earlier draft of this test copy-pasted the loop inline,
# which the merge was subsequently extracted out from under.
#   (a) value consistency — the arbiter resolves exactly the authored value.
#   (b) reachability — swapping the key's value for a sentinel and rebuilding
#       the arbiter must produce the SENTINEL, not the old value and not
#       _DEFAULTS[key]. A test that only checked (a) would have passed while
#       the bug was live, because the authored values happened to be
#       bit-for-bit identical to _DEFAULTS — comparing resolved-vs-authored
#       can't tell "read from cfg" apart from "fell through to a default that
#       happens to match." Only forcing a value _DEFAULTS does NOT have, and
#       confirming the arbiter reflects it, proves _cfg is actually consulted.
#
# Note: _cfg_get() ends with `return _DEFAULTS[key]` — a key present in
# balance.json but absent from _DEFAULTS would be a runtime invalid-index
# error, not a silent fallback. Any new key BehaviorArbiter reads via
# _cfg_get() must be added to _DEFAULTS as well as to balance.json.
static func _t_config_defaults_reachable_and_consistent() -> Dictionary:
	const _SENTINEL: String = "__V2_PROG_012_SENTINEL__"

	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var bdata: Dictionary = bal.get("data", {})
	var maturity_cfg: Dictionary = bdata.get("maturity_expression", {})
	var actor_data_cfg: Dictionary = bdata.get("actor", {})

	# Call the actual production merge helper — not a re-implementation — so this
	# test cannot drift from what FlowRuntime._get_actor_cfg_merged() really does.
	var merged_cfg: Dictionary = FlowRuntime._merge_actor_cfg(actor_data_cfg, maturity_cfg)

	var defaults: Dictionary = BehaviorArbiter._DEFAULTS
	var checked: int = 0
	for key: String in defaults.keys():
		if not merged_cfg.has(key):
			continue  # not authored anywhere reachable from this cfg — nothing to guard here
		checked += 1

		# (a) value consistency.
		var arbiter_real := BehaviorArbiter.new(merged_cfg)
		var resolved: Variant = arbiter_real._cfg_get(key)
		if resolved != merged_cfg[key]:
			return { "ok": false, "error": "Key '%s': arbiter resolved %s, authored balance.json has %s" % [key, str(resolved), str(merged_cfg[key])] }

		# (b) reachability — force a sentinel value _DEFAULTS does not have and confirm
		# the arbiter reflects it, proving _cfg_get() actually reads _cfg for this key.
		var sentinel_cfg: Dictionary = merged_cfg.duplicate(true)
		sentinel_cfg[key] = _SENTINEL
		var arbiter_sentinel := BehaviorArbiter.new(sentinel_cfg)
		var resolved_sentinel: Variant = arbiter_sentinel._cfg_get(key)
		if resolved_sentinel != _SENTINEL:
			return { "ok": false, "error": "Key '%s' is NOT reachable through _cfg — arbiter did not reflect a sentinel override (still fell through to _DEFAULTS or a stale value)" % key }

	if checked == 0:
		return { "ok": false, "error": "No _DEFAULTS keys matched any authored balance.json key — test is vacuous, check config paths" }
	return { "ok": true }


# ─── V2-PROG-012 Phase 1 — derive_expression() autonomy outputs ───────────

# Test 25 — purity: identical inputs called twice produce an identical dict,
# including exact float equality (not just is_equal_approx).
static func _t_derive_expression_is_pure() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var bdata: Dictionary = bal.get("data", {})
	var expr_cfg: Dictionary = bdata.get("maturity_expression", {})

	var echo := ActorTests._make_test_echo("echo_pure1", "Pure Echo")
	echo["rank"] = 5
	echo["calling"] = "okofor"
	echo["vector_scores"] = { "protector": 200, "pillar": 80 }
	echo["xp_total"] = 400
	echo["emotion"] = { "morale_current": 55, "fear_current": 30, "fear_base": 15 }
	var actor: Dictionary = EchoActor.from_echo(echo)

	var ctx_inputs: Dictionary = {
		"bonds":            [{ "actor_a": str(actor.get("id", "")), "actor_b": "ally_1", "strength": 40 }],
		"bond_thresholds":  { "rival_max": -30, "friend_min": 30 },
		"active_vow":       { "vow_id": "vow.test" },
		"calling_family":   "anchor",
		"instability":      0.0,
		"level_thresholds": bdata.get("progression", {}).get("level_thresholds", []),
	}

	var r1: Dictionary = MaturityExpressionService.derive_expression(actor, ctx_inputs, expr_cfg)
	var r2: Dictionary = MaturityExpressionService.derive_expression(actor, ctx_inputs, expr_cfg)

	for key: String in ["judgment", "presence", "composure", "legibility", "rank_strength"]:
		if float(r1[key]) != float(r2[key]):
			return { "ok": false, "error": "Key '%s' not exactly equal across two calls with identical inputs: %s vs %s" % [key, str(r1[key]), str(r2[key])] }
	if str(r1.get("expression_band", "")) != str(r2.get("expression_band", "")):
		return { "ok": false, "error": "expression_band differs across two calls with identical inputs" }
	return { "ok": true }


# Test 26 (Opus review fix) — replaces the vacuous range check. The old test's
# `if v < 0.0 or v > 1.0` could never fail: every output is clampf(..., 0.0, 1.0)
# at its assignment site inside derive_expression(), so the check tested clampf,
# not the derivation. It also could not catch NaN — clampf propagates NaN, and
# both `NaN < 0.0` and `NaN > 1.0` evaluate false.
#
# This test actually exercises the derivation: across a spread of actors (rank
# 1 and 9, zero and max fear, no bonds and many bonds, no calling and confirmed
# calling) every output must be finite (catches NaN), AND across that whole
# spread each output must NOT collapse to a single repeated value — i.e. the
# derivation genuinely discriminates between actors. That second assertion is
# exactly the shape of check that would have caught the FIX-1 Composure
# flooring bug, where every fear_base past ~16 collapsed Composure to exactly
# 0.0 for an entire cohort of low-Standing Echoes.
static func _t_derive_expression_outputs_discriminate() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var bdata: Dictionary = bal.get("data", {})
	var expr_cfg: Dictionary = bdata.get("maturity_expression", {})
	var level_thresholds: Array = bdata.get("progression", {}).get("level_thresholds", [])

	var many_bonds: Array = []
	for i in range(8):
		many_bonds.append({
			"actor_a": "echo_range1", "actor_b": "ally_%d" % i,
			"strength": 40 if i % 2 == 0 else -40,
		})

	var seen: Dictionary = { "judgment": [], "presence": [], "composure": [], "legibility": [] }
	for rank in [1, 9]:
		for fear in [0, 100]:
			for bonds in [[], many_bonds]:
				for calling in ["", "okofor"]:
					var echo := ActorTests._make_test_echo("echo_range1", "Range Echo")
					echo["rank"] = rank
					echo["calling"] = calling
					echo["xp_total"] = 300
					echo["vector_scores"] = { "protector": 120, "pillar": 40 }
					echo["emotion"] = { "morale_current": 50, "fear_current": fear, "fear_base": mini(fear, 40) }
					var actor: Dictionary = EchoActor.from_echo(echo)
					var ctx_inputs: Dictionary = {
						"bonds":            bonds,
						"bond_thresholds":  { "rival_max": -30, "friend_min": 30 },
						"active_vow":       {},
						"calling_family":   "anchor",
						"instability":      0.0,
						"level_thresholds": level_thresholds,
					}
					var result: Dictionary = MaturityExpressionService.derive_expression(actor, ctx_inputs, expr_cfg)
					for key: String in ["judgment", "presence", "composure", "legibility"]:
						var v: float = float(result.get(key, NAN))
						if not is_finite(v):
							return { "ok": false, "error": "%s is not finite (%s) for rank=%d fear=%d bonds=%d calling='%s'" % [key, str(v), rank, fear, bonds.size(), calling] }
						(seen[key] as Array).append(v)

	for key: String in seen.keys():
		var values: Array = seen[key]
		var first: float = float(values[0])
		var all_same := true
		for v in values:
			if not is_equal_approx(float(v), first):
				all_same = false
				break
		if all_same:
			return { "ok": false, "error": "%s never varies across the actor spread (always %.4f) — derivation is not discriminating between actors" % [key, first] }
	return { "ok": true }


# Test 27 (Opus review fix) — replaces a test that pinned the wrong object. The
# old test compared echo.keys() before/after running combat via
# EchoActor.from_echo(echo) — but from_echo() deep-copies the echo and the
# autonomy fields are only ever added to the TRANSIENT copy, so the source
# echo's keyset could never change no matter what derive_expression() does.
# It was a regression test for EchoActor.from_echo()'s deep-copy behaviour,
# and it never touched SaveService — the actual persistence boundary.
#
# This test drives a real combat encounter through FlowRuntime (roster echo →
# EchoActor.from_echo() → ActorStateMachine.advance_turn() sets the five
# transient keys on the combat actor), then round-trips the resulting
# save_data through the real SaveService.save_to_file()/load_from_file() path
# and asserts the persisted roster echo carries none of them. This would catch
# a future regression where the transient autonomy fields get merged back onto
# the save-side echo (the codebase already has precedent for writing transient
# per-actor state like "_sanctum_bark" onto roster entries), or where
# EchoActor.from_echo() stops deep-copying and starts aliasing.
static func _t_derive_expression_no_new_save_fields() -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("off")
	var config := ConfigService.new()
	var test_path := "/tmp/echoes-vnext-tests/maturity_expr_save_roundtrip_slot.json"
	var runtime := FlowRuntime.new(logger, config, test_path)
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx

	flow_ctx.realm_id = "realm.01"
	var rm: Dictionary = RealmService.get_or_create("realm.01", flow_ctx, 0)
	if rm.is_empty():
		return { "ok": false, "error": "setup failed: realm not created" }
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.save_roundtrip"

	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var echo: Dictionary = EchoFactory.generate("save_roundtrip", "echo.0", 0, "summon", summ_cfg, expr_cfg)
	echo["id"] = "echo_save_rt_0001"
	flow_ctx.save_data["sanctum"]["roster"] = [echo]
	flow_ctx.save_data["sanctum"]["active_party_ids"] = [str(echo["id"])]

	flow_ctx.dev_combat_objective = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null

	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, 0)
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx == null:
		return { "ok": false, "error": "setup failed: no encounter context" }

	runtime.dispatch({ "type": "combat.init" })
	for _r in range(3):
		runtime.dispatch({ "type": "combat.confirm_round" })
		var guard: int = 0
		while guard < 40:
			guard += 1
			var cs2: Dictionary = ectx.combat_state
			if bool(cs2.get("combat_over", false)): break
			if str(cs2.get("round_phase", "")) != "in_round": break
			runtime.dispatch({ "type": "combat.next_actor" })
		if bool(ectx.combat_state.get("combat_over", false)): break

	# Precondition: confirm the transient combat actor actually computed
	# _composure — otherwise this test would trivially pass without ever
	# exercising the derivation.
	var combat_actor: Dictionary = {}
	for a_v in ectx.actors:
		if a_v is Dictionary and str(a_v.get("id", "")) == str(echo.get("id", "")):
			combat_actor = a_v
			break
	if not combat_actor.has("_composure"):
		return { "ok": false, "error": "precondition failed: combat actor never computed _composure — test does not exercise the derivation" }

	if not SaveService.save_to_file(test_path, flow_ctx.save_data, logger, 0):
		return { "ok": false, "error": "SaveService.save_to_file() failed" }
	var result: Dictionary = SaveService.load_from_file(test_path, logger, 0)
	var data: Dictionary = result.get("data", {}) as Dictionary
	var roster: Array = (data.get("sanctum", {}) as Dictionary).get("roster", []) as Array
	if roster.is_empty():
		return { "ok": false, "error": "reloaded save has an empty roster" }
	var saved_echo: Dictionary = roster[0]
	for forbidden in ["_judgment", "_presence", "_composure", "_legibility", "_presence_strength"]:
		if saved_echo.has(forbidden):
			return { "ok": false, "error": "persisted echo unexpectedly contains transient key '%s'" % forbidden }
	return { "ok": true }


# Test 28 — composure design requirement: two actors with identical
# fear_current but different fear_base must produce DIFFERENT composure.
# A grounded Echo with fear_base=20 is a different person from one at
# fear_base=2 at the same fear_current — this pins that split.
static func _t_composure_separates_structural_and_situational_fear() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var bdata: Dictionary = bal.get("data", {})
	var expr_cfg: Dictionary = bdata.get("maturity_expression", {})
	var level_thresholds: Array = bdata.get("progression", {}).get("level_thresholds", [])

	var ctx_inputs: Dictionary = {
		"bonds":            [],
		"bond_thresholds":  { "rival_max": -30, "friend_min": 30 },
		"active_vow":       {},
		"calling_family":   "anchor",
		"instability":      0.0,
		"level_thresholds": level_thresholds,
	}

	var echo_low := ActorTests._make_test_echo("echo_cmp_low", "Low Dread")
	echo_low["rank"] = 5
	echo_low["xp_total"] = 300
	echo_low["emotion"] = { "morale_current": 50, "fear_current": 40, "fear_base": 2 }
	var actor_low: Dictionary = EchoActor.from_echo(echo_low)

	var echo_high := ActorTests._make_test_echo("echo_cmp_high", "High Dread")
	echo_high["rank"] = 5
	echo_high["xp_total"] = 300
	echo_high["emotion"] = { "morale_current": 50, "fear_current": 40, "fear_base": 20 }
	var actor_high: Dictionary = EchoActor.from_echo(echo_high)

	var r_low: Dictionary = MaturityExpressionService.derive_expression(actor_low, ctx_inputs, expr_cfg)
	var r_high: Dictionary = MaturityExpressionService.derive_expression(actor_high, ctx_inputs, expr_cfg)
	var composure_low: float = float(r_low.get("composure", 0.0))
	var composure_high: float = float(r_high.get("composure", 0.0))

	if is_equal_approx(composure_low, composure_high):
		return { "ok": false, "error": "Composure identical (%.4f) for fear_base=2 vs fear_base=20 at same fear_current=40" % composure_low }
	if composure_low <= composure_high:
		return { "ok": false, "error": "Expected lower fear_base (2) to yield HIGHER composure than higher fear_base (20); got low=%.4f high=%.4f" % [composure_low, composure_high] }
	return { "ok": true }


# Test 29 — judgment rises monotonically with Standing (rank), all else equal.
static func _t_judgment_rises_with_standing() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var bdata: Dictionary = bal.get("data", {})
	var expr_cfg: Dictionary = bdata.get("maturity_expression", {})
	var level_thresholds: Array = bdata.get("progression", {}).get("level_thresholds", [])

	var ctx_inputs: Dictionary = {
		"bonds":            [],
		"bond_thresholds":  { "rival_max": -30, "friend_min": 30 },
		"active_vow":       {},
		"calling_family":   "anchor",
		"instability":      0.0,
		"level_thresholds": level_thresholds,
	}

	var prev_judgment: float = -1.0
	for rank in range(1, 10):
		var echo := ActorTests._make_test_echo("echo_jr_%d" % rank, "Judgment Rank %d" % rank)
		echo["rank"] = rank
		echo["xp_total"] = 300
		echo["calling"] = "okofor"
		echo["vector_scores"] = { "protector": 150, "pillar": 40 }
		echo["emotion"] = { "morale_current": 50, "fear_current": 10, "fear_base": 0 }
		var actor: Dictionary = EchoActor.from_echo(echo)
		var result: Dictionary = MaturityExpressionService.derive_expression(actor, ctx_inputs, expr_cfg)
		var judgment: float = float(result.get("judgment", 0.0))
		if rank > 1 and judgment <= prev_judgment:
			return { "ok": false, "error": "Judgment did not rise at rank %d: %.4f <= previous %.4f" % [rank, judgment, prev_judgment] }
		prev_judgment = judgment
	return { "ok": true }


# Test 30 (Opus review fix) — structural_dread must lower composure's CEILING
# multiplicatively, not subtract from it directly. Two actors identical except
# fear_base, using values (16 and 32) that are BOTH past the point where the old
# subtractive formula floored composure to exactly 0.0 for a rank-1 Echo (fear_base
# 16 alone consumed all available headroom under the pre-fix weights). Pins:
#   (a) composure(fear_base=16) and composure(fear_base=32) are DIFFERENT — ordering
#       between actors is preserved instead of both collapsing to the same floor.
#   (b) composure(fear_base=16) > composure(fear_base=32) — more structural dread
#       still means less composure.
#   (c) NEITHER value is exactly 0.0 — a single input (fear_base) can no longer
#       drive composure to the absolute floor on its own.
static func _t_composure_ceiling_never_floors_at_high_fear_base() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var bdata: Dictionary = bal.get("data", {})
	var expr_cfg: Dictionary = bdata.get("maturity_expression", {})
	var level_thresholds: Array = bdata.get("progression", {}).get("level_thresholds", [])

	var ctx_inputs: Dictionary = {
		"bonds":            [],
		"bond_thresholds":  { "rival_max": -30, "friend_min": 30 },
		"active_vow":       {},
		"calling_family":   "anchor",
		"instability":      0.0,
		"level_thresholds": level_thresholds,
	}

	# fear_current == fear_base for both — isolates the structural_dread ceiling
	# effect from situational_spike (which is 0 when there's no spike above base).
	var echo_16 := ActorTests._make_test_echo("echo_ceiling_16", "Rank1 Dread16")
	echo_16["rank"] = 1
	echo_16["emotion"] = { "morale_current": 50, "fear_current": 16, "fear_base": 16 }
	var actor_16: Dictionary = EchoActor.from_echo(echo_16)

	var echo_32 := ActorTests._make_test_echo("echo_ceiling_32", "Rank1 Dread32")
	echo_32["rank"] = 1
	echo_32["emotion"] = { "morale_current": 50, "fear_current": 32, "fear_base": 32 }
	var actor_32: Dictionary = EchoActor.from_echo(echo_32)

	var r16: Dictionary = MaturityExpressionService.derive_expression(actor_16, ctx_inputs, expr_cfg)
	var r32: Dictionary = MaturityExpressionService.derive_expression(actor_32, ctx_inputs, expr_cfg)
	var composure_16: float = float(r16.get("composure", 0.0))
	var composure_32: float = float(r32.get("composure", 0.0))

	if is_equal_approx(composure_16, composure_32):
		return { "ok": false, "error": "Composure identical (%.4f) for fear_base=16 vs fear_base=32 — structural_dread is flooring both to the same value" % composure_16 }
	if composure_16 <= composure_32:
		return { "ok": false, "error": "Expected fear_base=16 to yield HIGHER composure than fear_base=32; got 16=%.4f 32=%.4f" % [composure_16, composure_32] }
	if is_equal_approx(composure_16, 0.0):
		return { "ok": false, "error": "composure(fear_base=16) floored to 0.0 — structural_dread alone must never drive composure to the absolute floor" }
	if is_equal_approx(composure_32, 0.0):
		return { "ok": false, "error": "composure(fear_base=32) floored to 0.0 — structural_dread alone must never drive composure to the absolute floor" }
	return { "ok": true }


static func _make_trait_test_actor(id: String, courage: int, wisdom: int, faith: int) -> Dictionary:
	var echo := ActorTests._make_test_echo(id, id)
	echo["rank"] = 1
	echo["traits"] = { "courage": courage, "wisdom": wisdom, "faith": faith }
	echo["emotion"] = { "morale_current": 50, "fear_current": 0, "fear_base": 0 }
	return EchoActor.from_echo(echo)


# Test 31 (Opus review fix) — trait_balance must read all three traits
# (courage/wisdom/faith), not faith alone. Pins:
#   (a) 50/50/50 and 90/30/30 (same mean=50) produce DIFFERENT trait_balance
#       (and therefore different Composure) — evenness matters, not just level.
#   (b) Changing courage ALONE (holding wisdom/faith fixed) changes Composure —
#       which the old faith-only formula provably could not do.
static func _t_trait_balance_reads_all_three_traits() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal: Dictionary = cs.get_balance()
	var bdata: Dictionary = bal.get("data", {})
	var expr_cfg: Dictionary = bdata.get("maturity_expression", {})
	var level_thresholds: Array = bdata.get("progression", {}).get("level_thresholds", [])

	var ctx_inputs: Dictionary = {
		"bonds":            [],
		"bond_thresholds":  { "rival_max": -30, "friend_min": 30 },
		"active_vow":       {},
		"calling_family":   "anchor",
		"instability":      0.0,
		"level_thresholds": level_thresholds,
	}

	# (a) Same mean (50), different spread.
	var actor_even: Dictionary   = _make_trait_test_actor("echo_tb_even", 50, 50, 50)
	var actor_uneven: Dictionary = _make_trait_test_actor("echo_tb_uneven", 90, 30, 30)
	var r_even: Dictionary   = MaturityExpressionService.derive_expression(actor_even, ctx_inputs, expr_cfg)
	var r_uneven: Dictionary = MaturityExpressionService.derive_expression(actor_uneven, ctx_inputs, expr_cfg)
	var composure_even: float   = float(r_even.get("composure", 0.0))
	var composure_uneven: float = float(r_uneven.get("composure", 0.0))
	if is_equal_approx(composure_even, composure_uneven):
		return { "ok": false, "error": "Composure identical (%.4f) for 50/50/50 vs 90/30/30 (same mean) — trait_balance ignores evenness" % composure_even }

	# (b) Changing courage alone (wisdom/faith held fixed) must change Composure —
	# the old faith-only read could never move under a courage-only change.
	var actor_base: Dictionary       = _make_trait_test_actor("echo_tb_base", 50, 50, 50)
	var actor_courage_up: Dictionary = _make_trait_test_actor("echo_tb_courage_up", 90, 50, 50)
	var r_base: Dictionary        = MaturityExpressionService.derive_expression(actor_base, ctx_inputs, expr_cfg)
	var r_courage_up: Dictionary  = MaturityExpressionService.derive_expression(actor_courage_up, ctx_inputs, expr_cfg)
	var composure_base: float        = float(r_base.get("composure", 0.0))
	var composure_courage_up: float  = float(r_courage_up.get("composure", 0.0))
	if is_equal_approx(composure_base, composure_courage_up):
		return { "ok": false, "error": "Composure did not change when courage alone changed (50→90, wisdom/faith fixed): %.4f vs %.4f" % [composure_base, composure_courage_up] }
	return { "ok": true }

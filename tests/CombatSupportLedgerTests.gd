# res://tests/CombatSupportLedgerTests.gd
# V2-COMBAT-00x (S14b, Tier 2): Support/defensive attribution on the combat contribution ledger.
# Covers: ActorStateMachine _support_tally accumulation per support action type; the
# ContributionLedgerService fold (fold_support_tally) + credit helper; projection of the extended
# contribution sub-dict; and explicit zero-regression on the offensive ledger consumers.
#
#   A. ASM unit (direct-drive _update_passive_state / _apply_leadership)
#     1. support/hold_ground_credits_effective_morale_and_action
#     2. support/hold_ground_effective_delta_respects_cap
#     3. support/steady_call_credits_fear_relieved_excludes_self
#     4. support/interpose_credits_guard_grant_not_self_morale
#     5. support/rally_call_once_per_combat_guard
#     6. support/inspire_aura_credits_morale_and_support_action
#     7. support/calm_fear_credits_most_feared_only
#     8. support/seer_idle_aura_credits_fear_relieved
#   B. Fold + credit helper (FlowRuntime, no boot)
#     9. support/credit_helper_accumulates_and_zero_is_noop
#    10. support/fold_merges_tally_into_ledger_and_clears
#    11. support/fold_gated_to_echo_faction
#    12. support/fold_no_double_count_across_turns
#   C. Zero-regression
#    13. support/round_snapshot_has_no_contribution_key
#    14. support/final_snapshot_contribution_has_all_keys
#    15. support/progression_xp_ignores_support_fields
#    16. support/recruitment_chance_ignores_support_fields
#
# Run via Debug Panel: tests

extends RefCounted
class_name CombatSupportLedgerTests

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("support/hold_ground_credits_effective_morale_and_action",
		Callable(CombatSupportLedgerTests, "_t_hold_ground_credits"))
	runner.register_test("support/hold_ground_effective_delta_respects_cap",
		Callable(CombatSupportLedgerTests, "_t_hold_ground_cap"))
	runner.register_test("support/steady_call_credits_fear_relieved_excludes_self",
		Callable(CombatSupportLedgerTests, "_t_steady_call_excludes_self"))
	runner.register_test("support/interpose_credits_guard_grant_not_self_morale",
		Callable(CombatSupportLedgerTests, "_t_interpose_guard_grant"))
	runner.register_test("support/rally_call_once_per_combat_guard",
		Callable(CombatSupportLedgerTests, "_t_rally_call_once"))
	runner.register_test("support/inspire_aura_credits_morale_and_support_action",
		Callable(CombatSupportLedgerTests, "_t_inspire_aura_counts"))
	runner.register_test("support/calm_fear_credits_most_feared_only",
		Callable(CombatSupportLedgerTests, "_t_calm_fear_most_feared_only"))
	runner.register_test("support/seer_idle_aura_credits_fear_relieved",
		Callable(CombatSupportLedgerTests, "_t_seer_idle_aura"))
	runner.register_test("support/credit_helper_accumulates_and_zero_is_noop",
		Callable(CombatSupportLedgerTests, "_t_credit_helper"))
	runner.register_test("support/fold_merges_tally_into_ledger_and_clears",
		Callable(CombatSupportLedgerTests, "_t_fold_merges_and_clears"))
	runner.register_test("support/fold_gated_to_echo_faction",
		Callable(CombatSupportLedgerTests, "_t_fold_gated_to_echo"))
	runner.register_test("support/fold_no_double_count_across_turns",
		Callable(CombatSupportLedgerTests, "_t_fold_no_double_count"))
	runner.register_test("support/round_snapshot_has_no_contribution_key",
		Callable(CombatSupportLedgerTests, "_t_round_snapshot_no_contribution"))
	runner.register_test("support/final_snapshot_contribution_has_all_keys",
		Callable(CombatSupportLedgerTests, "_t_final_snapshot_contribution_keys"))
	runner.register_test("support/progression_xp_ignores_support_fields",
		Callable(CombatSupportLedgerTests, "_t_progression_ignores_support"))
	runner.register_test("support/recruitment_chance_ignores_support_fields",
		Callable(CombatSupportLedgerTests, "_t_recruitment_ignores_support"))


# -------------------------
# Helpers
# -------------------------

static func _off_logger() -> StructuredLogger:
	var lg := StructuredLogger.new()
	lg.set_level("off")
	return lg


static func _tally(actor: Dictionary) -> Dictionary:
	var v: Variant = actor.get("_support_tally", {})
	return v if v is Dictionary else {}


static func _runtime(tag: String) -> FlowRuntime:
	# No boot() — the fold/credit helpers only touch the args passed to them.
	return FlowRuntime.new(_off_logger(), ConfigService.new(), TestSaveHarness.dir() + "support_" + tag + ".json")


# -------------------------
# A. ActorStateMachine unit tests
# -------------------------

# 1: hold_ground grants +3 morale to a nearby ally → morale_given=3, support_actions=1.
static func _t_hold_ground_credits() -> Dictionary:
	var actor := { "id": "echo_a", "faction": "echo", "grid_pos": { "col": 0, "row": 0 } }
	var ally := { "id": "echo_b", "faction": "echo", "grid_pos": { "col": 1, "row": 0 }, "morale": 50 }
	var sm := ActorStateMachine.new(actor)
	sm._update_passive_state({ "action_type": "actor.hold_ground" }, { "all_actors": [actor, ally], "cfg": {} }, 1)
	var tl := _tally(actor)
	if int(tl.get("morale_given", 0)) != 3:
		return { "ok": false, "error": "expected morale_given=3, got %s" % str(tl.get("morale_given")) }
	if int(tl.get("support_actions", 0)) != 1:
		return { "ok": false, "error": "expected support_actions=1, got %s" % str(tl.get("support_actions")) }
	return { "ok": true }


# 2: effective delta respects the 100 clamp — ally at 99 gains only +1.
static func _t_hold_ground_cap() -> Dictionary:
	var actor := { "id": "echo_a", "faction": "echo", "grid_pos": { "col": 0, "row": 0 } }
	var ally := { "id": "echo_b", "faction": "echo", "grid_pos": { "col": 1, "row": 0 }, "morale": 99 }
	var sm := ActorStateMachine.new(actor)
	sm._update_passive_state({ "action_type": "actor.hold_ground" }, { "all_actors": [actor, ally], "cfg": {} }, 1)
	if int(_tally(actor).get("morale_given", 0)) != 1:
		return { "ok": false, "error": "expected effective morale_given=1 (capped), got %s" % str(_tally(actor).get("morale_given")) }
	return { "ok": true }


# 3: steady_call relieves fear from allies but NOT from self (self is in the effect loop).
static func _t_steady_call_excludes_self() -> Dictionary:
	var actor := { "id": "echo_a", "faction": "echo", "grid_pos": { "col": 0, "row": 0 }, "fear": 30 }
	var ally := { "id": "echo_b", "faction": "echo", "grid_pos": { "col": 1, "row": 0 }, "fear": 30 }
	var sm := ActorStateMachine.new(actor)
	sm._update_passive_state({ "action_type": "actor.steady_call" }, { "all_actors": [actor, ally], "cfg": {} }, 1)
	var tl := _tally(actor)
	# Only the ally (30→10 = 20) is credited; self's own -20 is excluded.
	if int(tl.get("fear_relieved", 0)) != 20:
		return { "ok": false, "error": "expected fear_relieved=20 (ally only), got %s" % str(tl.get("fear_relieved")) }
	if int(tl.get("support_actions", 0)) != 1:
		return { "ok": false, "error": "expected support_actions=1, got %s" % str(tl.get("support_actions")) }
	# Sanity: the effect itself still de-feared self (unchanged behaviour).
	if int(actor.get("fear", 0)) != 10:
		return { "ok": false, "error": "self fear should still drop to 10 (effect unchanged), got %s" % str(actor.get("fear")) }
	return { "ok": true }


# 4: interpose credits guards_granted + support_actions; the interposer's own +morale is excluded.
static func _t_interpose_guard_grant() -> Dictionary:
	var actor := { "id": "echo_a", "faction": "echo", "morale": 50 }
	var ally := { "id": "echo_b", "faction": "echo", "guard_state": false }
	var sm := ActorStateMachine.new(actor)
	sm._update_passive_state({ "action_type": "actor.interpose", "target_id": "echo_b" }, { "all_actors": [actor, ally], "cfg": {} }, 1)
	var tl := _tally(actor)
	if int(tl.get("guards_granted", 0)) != 1:
		return { "ok": false, "error": "expected guards_granted=1, got %s" % str(tl.get("guards_granted")) }
	if int(tl.get("support_actions", 0)) != 1:
		return { "ok": false, "error": "expected support_actions=1, got %s" % str(tl.get("support_actions")) }
	if int(tl.get("morale_given", 0)) != 0:
		return { "ok": false, "error": "self-morale must NOT count as morale_given, got %s" % str(tl.get("morale_given")) }
	if not bool(ally.get("guard_state", false)):
		return { "ok": false, "error": "ally guard_state should be true (effect unchanged)" }
	return { "ok": true }


# 5: rally_call once-per-combat — a second fire (with _rally_call_used set) adds nothing.
static func _t_rally_call_once() -> Dictionary:
	var actor := { "id": "echo_L", "faction": "echo", "grid_pos": { "col": 0, "row": 0 } }
	var ally := { "id": "echo_A", "faction": "echo", "actor_type": "echo", "grid_pos": { "col": 1, "row": 0 }, "morale": 50 }
	var sm := ActorStateMachine.new(actor)
	var expr_cfg := { "leadership_trait_effects": { "rally_call": { "morale_boost": 10, "once_per_combat": true, "radius": 3 } } }
	var ctx := { "all_actors": [actor, ally], "round": 1 }
	var lg := _off_logger()
	sm._apply_leadership(["rally_call"], expr_cfg, ctx, lg, 1)
	sm._apply_leadership(["rally_call"], expr_cfg, ctx, lg, 2)  # blocked by _rally_call_used
	var tl := _tally(actor)
	if int(tl.get("morale_given", 0)) != 10:
		return { "ok": false, "error": "expected morale_given=10 after once-only rally, got %s" % str(tl.get("morale_given")) }
	if int(tl.get("support_actions", 0)) != 1:
		return { "ok": false, "error": "expected support_actions=1 (once), got %s" % str(tl.get("support_actions")) }
	return { "ok": true }


# 6: inspire_aura (passive leadership) credits morale_given AND support_actions (Jeff: auras count).
static func _t_inspire_aura_counts() -> Dictionary:
	var actor := { "id": "echo_L", "faction": "echo", "grid_pos": { "col": 0, "row": 0 } }
	var ally := { "id": "echo_A", "faction": "echo", "actor_type": "echo", "grid_pos": { "col": 1, "row": 0 }, "morale": 50 }
	var sm := ActorStateMachine.new(actor)
	var expr_cfg := { "leadership_trait_effects": { "inspire_aura": { "morale_per_round": 5, "radius": 3 } } }
	sm._apply_leadership(["inspire_aura"], expr_cfg, { "all_actors": [actor, ally], "round": 1 }, _off_logger(), 1)
	var tl := _tally(actor)
	if int(tl.get("morale_given", 0)) != 5:
		return { "ok": false, "error": "expected morale_given=5, got %s" % str(tl.get("morale_given")) }
	if int(tl.get("support_actions", 0)) != 1:
		return { "ok": false, "error": "expected support_actions=1 for passive aura, got %s" % str(tl.get("support_actions")) }
	return { "ok": true }


# 7: calm_fear relieves fear from the single most-feared ally only.
static func _t_calm_fear_most_feared_only() -> Dictionary:
	var actor := { "id": "echo_L", "faction": "echo", "grid_pos": { "col": 0, "row": 0 } }
	var low := { "id": "echo_low", "faction": "echo", "actor_type": "echo", "grid_pos": { "col": 1, "row": 0 }, "fear": 30 }
	var high := { "id": "echo_high", "faction": "echo", "actor_type": "echo", "grid_pos": { "col": 0, "row": 1 }, "fear": 60 }
	var sm := ActorStateMachine.new(actor)
	var expr_cfg := { "leadership_trait_effects": { "calm_fear": { "fear_reduction": 10, "radius": 3 } } }
	sm._apply_leadership(["calm_fear"], expr_cfg, { "all_actors": [actor, low, high], "round": 1 }, _off_logger(), 1)
	var tl := _tally(actor)
	if int(tl.get("fear_relieved", 0)) != 10:
		return { "ok": false, "error": "expected fear_relieved=10 (most-feared only), got %s" % str(tl.get("fear_relieved")) }
	if int(high.get("fear", 0)) != 50 or int(low.get("fear", 0)) != 30:
		return { "ok": false, "error": "only the most-feared ally should change (high=%s low=%s)" % [str(high.get("fear")), str(low.get("fear"))] }
	return { "ok": true }


# 8: Seer idle_fear_aura relieves nearby ally fear when idling → fear_relieved + support_actions.
static func _t_seer_idle_aura() -> Dictionary:
	var actor := { "id": "echo_seer", "faction": "echo", "calling_origin": "seer", "grid_pos": { "col": 0, "row": 0 } }
	var ally := { "id": "echo_b", "faction": "echo", "grid_pos": { "col": 1, "row": 0 }, "fear": 30 }
	var sm := ActorStateMachine.new(actor)
	sm._update_passive_state({ "action_type": "actor.idle" }, { "all_actors": [actor, ally], "cfg": {} }, 1)
	var tl := _tally(actor)
	if int(tl.get("fear_relieved", 0)) != 3:
		return { "ok": false, "error": "expected fear_relieved=3 (idle aura), got %s" % str(tl.get("fear_relieved")) }
	if int(tl.get("support_actions", 0)) != 1:
		return { "ok": false, "error": "expected support_actions=1, got %s" % str(tl.get("support_actions")) }
	return { "ok": true }


# -------------------------
# B. Fold + credit helper (ContributionLedgerService statics, no runtime, no boot)
# V2-INFRA-003 Phase 6 Slice 6H: these four moved off FlowRuntime onto
# ContributionLedgerService. No delegating shim was left behind (AGENTS.md #20), so the call
# sites below address the new owner directly.
# -------------------------

# 9: credit_support_tally accumulates; amount 0 is a no-op that creates no tally.
static func _t_credit_helper() -> Dictionary:
	var a := { "id": "echo_a", "faction": "echo" }
	ContributionLedgerService.credit_support_tally(a, "morale_given", 4)
	ContributionLedgerService.credit_support_tally(a, "morale_given", 4)
	if int(_tally(a).get("morale_given", 0)) != 8:
		return { "ok": false, "error": "expected accumulated morale_given=8, got %s" % str(_tally(a).get("morale_given")) }
	var b := { "id": "echo_b", "faction": "echo" }
	ContributionLedgerService.credit_support_tally(b, "fear_relieved", 0)
	if b.has("_support_tally"):
		return { "ok": false, "error": "amount 0 should be a no-op — no _support_tally created" }
	return { "ok": true }


# 10: fold merges the tally into the ledger entry and erases the tally.
static func _t_fold_merges_and_clears() -> Dictionary:
	var ectx := EncounterContext.new()
	var a := { "id": "echo_x", "faction": "echo", "_support_tally": {
		"guards_granted": 1, "morale_given": 5, "fear_relieved": 3, "support_actions": 2 } }
	ContributionLedgerService.fold_support_tally(a, ectx)
	if not ectx.echo_action_logs.has("echo_x"):
		return { "ok": false, "error": "ledger entry should be created for echo_x" }
	var e: Dictionary = ectx.echo_action_logs["echo_x"]
	if int(e.get("guards_granted", 0)) != 1 or int(e.get("morale_given", 0)) != 5 \
			or int(e.get("fear_relieved", 0)) != 3 or int(e.get("support_actions", 0)) != 2:
		return { "ok": false, "error": "folded values mismatch: %s" % str(e) }
	if a.has("_support_tally"):
		return { "ok": false, "error": "_support_tally must be erased after fold" }
	return { "ok": true }


# 11: fold is echo-gated — a non-echo actor's tally is NOT merged, but is still erased.
static func _t_fold_gated_to_echo() -> Dictionary:
	var ectx := EncounterContext.new()
	var enemy := { "id": "enemy_x", "faction": "enemy", "_support_tally": { "morale_given": 9 } }
	ContributionLedgerService.fold_support_tally(enemy, ectx)
	if ectx.echo_action_logs.has("enemy_x"):
		return { "ok": false, "error": "non-echo actor must not create a ledger entry" }
	if enemy.has("_support_tally"):
		return { "ok": false, "error": "_support_tally must be erased even when gated out" }
	return { "ok": true }


# 12: two turns (fresh tally each) accumulate additively — no double count, no residue.
static func _t_fold_no_double_count() -> Dictionary:
	var ectx := EncounterContext.new()
	var a := { "id": "echo_y", "faction": "echo", "_support_tally": { "morale_given": 5 } }
	ContributionLedgerService.fold_support_tally(a, ectx)          # ledger = 5, tally erased
	ContributionLedgerService.fold_support_tally(a, ectx)          # no tally → no-op
	a["_support_tally"] = { "morale_given": 2 }  # next turn
	ContributionLedgerService.fold_support_tally(a, ectx)          # ledger = 7
	if int(ectx.echo_action_logs["echo_y"].get("morale_given", 0)) != 7:
		return { "ok": false, "error": "expected additive morale_given=7, got %s" % str(ectx.echo_action_logs["echo_y"].get("morale_given")) }
	return { "ok": true }


# -------------------------
# C. Zero-regression
# -------------------------

# 13: round-snapshot projection (no ledger arg) never adds a "contribution" key.
static func _t_round_snapshot_no_contribution() -> Dictionary:
	var actor := { "id": "echo_a", "faction": "echo", "stats": { "max_hp": 10 }, "current_hp": 10, "morale": 50, "fear": 0 }
	var proj: Dictionary = EncounterSnapshotBuilder._project_actor(actor)
	if proj.has("contribution"):
		return { "ok": false, "error": "round snapshot must not carry a contribution key" }
	return { "ok": true }


# 14: final-snapshot projection carries the 3 offensive + 5 Tier-2 keys.
static func _t_final_snapshot_contribution_keys() -> Dictionary:
	var actor := { "id": "echo_a", "faction": "echo", "stats": { "max_hp": 10 }, "current_hp": 10, "morale": 50, "fear": 0 }
	var ledger := { "echo_a": {
		"damage_dealt": 7, "damage_taken": 2, "kills": 1,
		"guards_granted": 1, "morale_given": 5, "fear_relieved": 3, "support_actions": 2, "fear_inflicted": 4 } }
	var proj: Dictionary = EncounterSnapshotBuilder._project_actor(actor, ledger)
	if not proj.has("contribution"):
		return { "ok": false, "error": "final snapshot must carry a contribution key" }
	var c: Dictionary = proj["contribution"]
	for key in ["damage_dealt", "damage_taken", "kills", "guards_granted", "morale_given", "fear_relieved", "support_actions", "fear_inflicted"]:
		if not c.has(key):
			return { "ok": false, "error": "contribution missing key: %s" % key }
	if int(c.get("fear_inflicted", -1)) != 4 or int(c.get("morale_given", -1)) != 5:
		return { "ok": false, "error": "projected values mismatch: %s" % str(c) }
	return { "ok": true }


# 15: ProgressionService virtue multiplier ignores Tier-2 support fields.
static func _t_progression_ignores_support() -> Dictionary:
	var traits := { "courage": 50, "wisdom": 50, "faith": 50 }
	var base := { "total_count": 3, "melee_count": 2, "guard_count": 1, "kill_count": 1, "survived": true,
		"damage_dealt": 40, "damage_taken": 10, "kills": 1 }
	var with_support: Dictionary = base.duplicate(true)
	with_support["guards_granted"] = 5
	with_support["morale_given"] = 99
	with_support["fear_relieved"] = 99
	with_support["support_actions"] = 9
	with_support["fear_inflicted"] = 99
	var m1: float = ProgressionService.compute_virtue_multiplier(traits, base, 2.0, {})
	var m2: float = ProgressionService.compute_virtue_multiplier(traits, with_support, 2.0, {})
	if absf(m1 - m2) > 0.0000001:
		return { "ok": false, "error": "virtue multiplier changed with support fields: %f vs %f" % [m1, m2] }
	return { "ok": true }


# 16: RecruitmentService combat component ignores Tier-2 support fields.
static func _t_recruitment_ignores_support() -> Dictionary:
	var ally := { "id": "ally_1", "current_hp": 20, "max_hp": 40, "death_round": 0 }
	var base := { "damage_dealt": 20, "damage_taken": 10, "kills": 1 }
	var with_support: Dictionary = base.duplicate(true)
	with_support["guards_granted"] = 3
	with_support["morale_given"] = 88
	with_support["fear_relieved"] = 88
	with_support["support_actions"] = 7
	with_support["fear_inflicted"] = 88
	var r1: Dictionary = RecruitmentService._combat_component(ally, base, 3, {})
	var r2: Dictionary = RecruitmentService._combat_component(ally, with_support, 3, {})
	if absf(float(r1.get("points", 0.0)) - float(r2.get("points", 0.0))) > 0.0000001:
		return { "ok": false, "error": "recruit combat points changed with support fields: %s vs %s" % [str(r1), str(r2)] }
	return { "ok": true }

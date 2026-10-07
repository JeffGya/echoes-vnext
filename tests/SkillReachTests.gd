# res://tests/SkillReachTests.gd
# Follow-up #6 PR0 (defect DE-9): actor.mark and actor.reveal must resolve as themselves at
# distance 2 and 3, not as actor.idle. Reach comes from CombatActivationService.ACTION_RANGES.
#
# Tests 1, 2, 3 drive the real live path: an Echo party built through EchoFactory.generate,
# EmotionService.init_echo and VectorService.init_vectors, one dispatched combat.next_actor,
# then the resolved action read from last_round_results.
# Test 4 reads the candidate generator, which owns the mark and reveal offer gates.

class_name SkillReachTests
extends RefCounted

# Tags pin the seeded party. The arbiter picks the skill on these fixtures (selected is
# asserted, so a tuning change that moves the pick fails loudly and needs a re-pin).
const _MARK_TAGS: Dictionary = { 2: "scan0_2_rangers_mark", 3: "scan6_3_rangers_mark" }
const _REVEAL_TAG: String = "scan6_3_seers_reveal"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("skill_reach/mark_resolves_at_distance_2_and_3_and_marks_target",
		Callable(SkillReachTests, "_t_mark_resolves_at_reach"))
	runner.register_test("skill_reach/reveal_resolves_at_reach_sets_used_flag_once",
		Callable(SkillReachTests, "_t_reveal_resolves_at_reach_once"))
	runner.register_test("skill_reach/beyond_reach_not_offered_and_never_resolves_idle",
		Callable(SkillReachTests, "_t_beyond_reach"))
	runner.register_test("skill_reach/mark_adds_ten_to_ally_melee_bonus",
		Callable(SkillReachTests, "_t_mark_bonus_on_melee"))


static func _setup(tag: String, equip: Dictionary) -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("debug")
	var config := ConfigService.new()
	var runtime := FlowRuntime.new(logger, config, TestSaveHarness.fresh_save_path("skill_reach_%s.json" % tag))
	runtime.boot()
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0
	flow_ctx.realm_id = "realm.01"
	if RealmService.get_or_create("realm.01", flow_ctx, t).is_empty():
		return {}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.%s" % tag
	flow_ctx.save_data["economy"]["ase"] = 0
	flow_ctx.save_data["economy"]["ekwan"] = 0
	var bal: Dictionary = config.get_balance()
	var summ_cfg: Dictionary = bal.get("data", {}).get("summoning", {})
	var expr_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var vec_cfg: Dictionary = bal.get("data", {}).get("vectors", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(5):
		var echo: Dictionary = EchoFactory.generate(tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		EmotionService.init_echo(echo, logger, t)
		VectorService.init_vectors(echo, vec_cfg, logger, t)
		FlowFingerprintTests._promote_echo_rank(echo, 3, bal, flow_ctx.campaign_seed, logger, t)
		if i == 0:
			echo["equipped_skills"] = equip.duplicate(true)
		roster.append(echo)
		party_ids.append(str(echo["id"]))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids
	flow_ctx.dev_combat_objective = "combat"
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	if flow_ctx.encounter_ctx == null:
		return {}
	return { "runtime": runtime, "ectx": flow_ctx.encounter_ctx, "logger": logger }


## One real actor turn for echo_0001 with the nearest hostile `dist` cells away on row 1 and
## every other actor parked far away. Returns the resolved action and the two actor dicts.
static func _one_turn(tag: String, equip: Dictionary, dist: int, reveal_used: bool = false) -> Dictionary:
	var env: Dictionary = _setup(tag, equip)
	if env.is_empty():
		return { "ok": false, "error": "setup failed" }
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	runtime.dispatch({ "type": "combat.init" })
	runtime.dispatch({ "type": "combat.confirm_round" })
	var actor: Dictionary = EncounterContext.find_actor_by_id(ectx.actors, "echo_0001")
	var enemy: Dictionary = {}
	var far_col: int = 9
	for a_v: Variant in ectx.actors:
		var a: Dictionary = a_v as Dictionary
		if a == actor:
			continue
		if enemy.is_empty() and str(a.get("faction", "")) == "enemy" and not bool(a.get("is_structure", false)):
			enemy = a
			continue
		GridService.assign_grid_pos(a, far_col, 9 - (far_col % 3))
		far_col -= 1
	if actor.is_empty() or enemy.is_empty():
		return { "ok": false, "error": "missing actor or enemy" }
	GridService.assign_grid_pos(actor, 1, 1)
	GridService.assign_grid_pos(enemy, 1 + dist, 1)
	actor.erase("last_intent")
	if reveal_used:
		actor["_reveal_used"] = true
	var order: Array = ectx.combat_state.get("initiative_order", []) as Array
	var idx: int = -1
	for i in range(order.size()):
		if str((order[i] as Dictionary).get("id", "")) == "echo_0001":
			idx = i
	if idx < 0:
		return { "ok": false, "error": "echo_0001 not in initiative order" }
	ectx.combat_state["current_actor_index"] = idx
	var pre_actor: Dictionary = actor.duplicate(true)
	var pre_enemy: Dictionary = enemy.duplicate(true)
	var before: int = ectx.last_round_results.size()
	var logger: StructuredLogger = env["logger"]
	logger.clear()
	runtime.dispatch({ "type": "combat.next_actor" })
	var selected: String = ""
	for e_v: Variant in logger.get_logs():
		var e: Dictionary = e_v as Dictionary
		if str(e.get("type", "")) == "actor.decision_trace":
			selected = str((e.get("data", {}) as Dictionary).get("action_type", ""))
	if ectx.last_round_results.size() <= before:
		return { "ok": false, "error": "no turn resolved" }
	var last: Dictionary = ectx.last_round_results.back() as Dictionary
	return {
		"ok": true, "resolved": str(last.get("action_type", "")), "actor": actor, "enemy": enemy,
		"pre_actor": pre_actor, "pre_enemy": pre_enemy,
		"actor_id": str(last.get("source_id", "")), "selected": selected,
	}


static func _t_mark_resolves_at_reach() -> Dictionary:
	for dist: int in [2, 3]:
		var r: Dictionary = _one_turn(str(_MARK_TAGS[dist]), { "0": "rangers_mark" }, dist)
		if not bool(r["ok"]):
			return r
		if str(r["selected"]) != "actor.mark":
			return { "ok": false, "error": "fixture drifted: dist %d selected %s" % [dist, str(r["selected"])] }
		if str(r["actor_id"]) != "echo_0001":
			return { "ok": false, "error": "wrong actor resolved: %s" % str(r["actor_id"]) }
		if str(r["resolved"]) != "actor.mark":
			return { "ok": false, "error": "dist %d selected %s resolved %s, expected actor.mark" % [dist, str(r["selected"]), str(r["resolved"])] }
		if str((r["enemy"] as Dictionary).get("marked_by", "")) != "echo_0001":
			return { "ok": false, "error": "dist %d: marked_by not set on target" % dist }
	return { "ok": true }


static func _t_reveal_resolves_at_reach_once() -> Dictionary:
	var r: Dictionary = _one_turn(_REVEAL_TAG, { "0": "seers_reveal" }, 3)
	if not bool(r["ok"]):
		return r
	if str(r["selected"]) != "actor.reveal":
		return { "ok": false, "error": "fixture drifted: selected %s" % str(r["selected"]) }
	if str(r["resolved"]) != "actor.reveal":
		return { "ok": false, "error": "dist 3 selected %s resolved %s, expected actor.reveal" % [str(r["selected"]), str(r["resolved"])] }
	var actor: Dictionary = r["actor"] as Dictionary
	if not bool(actor.get("_reveal_used", false)):
		return { "ok": false, "error": "_reveal_used not set after reveal resolved" }
	# Same pre-turn positions: offered while the flag is clear, not offered once it is set.
	var pre_actor: Dictionary = r["pre_actor"] as Dictionary
	var pre_enemy: Dictionary = r["pre_enemy"] as Dictionary
	if not _offered_types(pre_actor, pre_enemy, "seers_reveal").has("actor.reveal"):
		return { "ok": false, "error": "control: actor.reveal not offered at distance 3 before the turn" }
	pre_actor["_reveal_used"] = true
	if _offered_types(pre_actor, pre_enemy, "seers_reveal").has("actor.reveal"):
		return { "ok": false, "error": "actor.reveal offered again after _reveal_used" }
	# A second real turn with the flag set must not resolve reveal.
	var r2: Dictionary = _one_turn(_REVEAL_TAG, { "0": "seers_reveal" }, 3, true)
	if not bool(r2["ok"]):
		return r2
	if str(r2["selected"]) == "actor.reveal" or str(r2["resolved"]) == "actor.reveal":
		return { "ok": false, "error": "reveal repeated with _reveal_used set" }
	return { "ok": true }


static func _t_beyond_reach() -> Dictionary:
	var cases: Array = [
		["rangers_mark", "actor.mark", str(_MARK_TAGS[3])],
		["seers_reveal", "actor.reveal", _REVEAL_TAG],
	]
	for c_v: Variant in cases:
		var skill_id: String = str((c_v as Array)[0])
		var action: String = str((c_v as Array)[1])
		var r: Dictionary = _one_turn(str((c_v as Array)[2]), { "0": skill_id }, 4)
		if not bool(r["ok"]):
			return r
		var pre_actor: Dictionary = r["pre_actor"] as Dictionary
		var pre_enemy: Dictionary = r["pre_enemy"] as Dictionary
		var pre_dist: int = GridService.chebyshev_distance(
			pre_actor.get("grid_pos", {}), pre_enemy.get("grid_pos", {}))
		if pre_dist != 4:
			return { "ok": false, "error": "fixture drifted: pre-turn distance %d, expected 4" % pre_dist }
		if _offered_types(pre_actor, pre_enemy, skill_id).has(action):
			return { "ok": false, "error": "%s offered at distance 4" % action }
		if str(r["resolved"]) == action:
			return { "ok": false, "error": "%s resolved at distance 4" % action }
	return { "ok": true }


static func _t_mark_bonus_on_melee() -> Dictionary:
	var ally: Dictionary = { "id": "echo_ally", "faction": "echo", "actor_type": "echo",
		"grid_pos": { "col": 1, "row": 1 }, "current_hp": 50, "stats": { "max_hp": 50 } }
	var enemy: Dictionary = { "id": "enemy_x", "faction": "enemy", "actor_type": "enemy",
		"grid_pos": { "col": 2, "row": 1 }, "current_hp": 50, "stats": { "max_hp": 50 } }
	var unmarked: float = _melee_mark_bonus(ally, enemy)
	enemy["marked_by"] = "echo_0001"
	var marked: float = _melee_mark_bonus(ally, enemy)
	if unmarked != 0.0 or marked != 10.0:
		return { "ok": false, "error": "melee _mark_bonus unmarked=%s marked=%s, expected 0 and 10" % [str(unmarked), str(marked)] }
	return { "ok": true }


static func _melee_mark_bonus(ally: Dictionary, enemy: Dictionary) -> float:
	for c: Dictionary in _generate(ally, enemy, {}):
		if str(c.get("action_type", "")) == "melee_attack":
			return float(c.get("_mark_bonus", -1.0))
	return -1.0


static func _generate(actor: Dictionary, enemy: Dictionary, skills_cfg: Dictionary) -> Array[Dictionary]:
	var ctx: Dictionary = { "skills_cfg": skills_cfg }
	return ActionCandidateGenerator.generate_candidates(
		actor, [actor, enemy], ctx, "forming", {}, {}, 2, 0.0, {}, {})


static func _offered_types(actor: Dictionary, enemy: Dictionary, skill_id: String) -> Array:
	var cfg := ConfigService.new()
	cfg.load_balance()
	var skills_cfg: Dictionary = cfg.get_balance().get("data", {}).get("skills", {})
	var out: Array = []
	for c: Dictionary in _generate(actor, enemy, skills_cfg):
		out.append(str(c.get("action_type", "")))
	return out

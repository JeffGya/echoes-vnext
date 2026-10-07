# res://core/actors/behaviors/ActionCandidateGenerator.gd
# Builds the raw action-candidate pool BehaviorArbiter scores each turn.
#
# Owns: which action_types are even offered this turn (actor.idle, actor.guard,
# melee_attack, actor.move, protect_ally, actor.retreat, actor.taunt, skill-gated
# candidates), plus the legacy/route candidate reshaping used by
# select_movement_intent() and the purifier hard-override candidate.
#
# Does NOT score candidates (BehaviorArbiter._score() does) and does NOT read a
# ConfigService: every config value arrives as a parameter, resolved by the
# caller's own `_cfg_get()`. Pure, static. Used by BOTH select_intent() and
# select_movement_intent() — not movement-only despite the historical name.

class_name ActionCandidateGenerator

const MovementActionPlanContract = preload("res://core/movement/contracts/MovementActionPlan.gd")
const ReachAuthority = preload("res://core/movement/CombatActivationService.gd")


## Generates all candidate intents for this turn:
## - actor.idle: always available (safe fallback, never absent)
## - actor.guard: only when nearest enemy is within guard_range tiles
## - melee_attack: only when nearest enemy is at Chebyshev distance == 1
## - actor.move: when nearest enemy exists but is not yet adjacent
## - protect_ally: only when a same-faction ally has taken any damage
##
## guard_range, threat_threshold and situational_muls are data.actor config values
## resolved by the caller (BehaviorArbiter._cfg_get()); this class holds no
## ConfigService by design. skill_weight_cfg carries the two tables
## resolve_skill_base() needs (intent_weights_by_calling_origin, default_intent_weight)
## — kept out of this function's own config trio because they belong to that helper,
## not to the candidate-gating logic here.
static func generate_candidates(
	actor: Dictionary,
	all_actors: Array,
	context: Dictionary,
	expression_band: String,
	calling_behavior: Dictionary,
	leadership_mods: Dictionary,
	guard_range: int,
	threat_threshold: float,
	situational_muls: Dictionary,
	skill_weight_cfg: Dictionary = {}
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []

	# actor.idle is always a candidate — the unconditional safe fallback.
	candidates.append({ "action_type": "actor.idle", "target_id": "", "priority": 0.0 })

	var actor_type: String = str(actor.get("actor_type", "echo"))
	# Prefer confirmed calling (runtime identity) over birth origin, once one exists.
	var _confirmed_calling: String = str(actor.get("calling", ""))
	var calling_origin: String = _confirmed_calling \
		if not _confirmed_calling.is_empty() and _confirmed_calling != "uncalled" \
		else str(actor.get("calling_origin", "uncalled"))
	var my_pos: Dictionary = actor.get("grid_pos", { "col": 0, "row": 0 })

	# Enemy Forming+ focus fire — prefer most-wounded echo over nearest.
	var nearest_enemy: Dictionary
	if actor_type == "enemy" \
			and (expression_band == "forming" or expression_band == "grounded" or expression_band == "whole"):
		nearest_enemy = _get_most_wounded_enemy(actor, all_actors)
		if nearest_enemy.is_empty():
			nearest_enemy = ActorService.get_nearest_enemy(actor, all_actors)
	else:
		nearest_enemy = ActorService.get_nearest_enemy(actor, all_actors)

	var enemy_dist: int = 999999
	var t_pos: Dictionary = {}
	if not nearest_enemy.is_empty():
		t_pos = nearest_enemy.get("grid_pos", { "col": 0, "row": 0 })
		enemy_dist = GridService.chebyshev_distance(my_pos, t_pos)

	# Pre-compute mark/reveal bonuses for a melee_attack candidate, if one is offered below.
	var _mark_bonus: float   = 0.0
	var _reveal_bonus: float = 0.0
	if not nearest_enemy.is_empty():
		if not str(nearest_enemy.get("marked_by", "")).is_empty():
			_mark_bonus = 10.0
		if not str(nearest_enemy.get("revealed_by_seer", "")).is_empty():
			_reveal_bonus = 15.0

	if not nearest_enemy.is_empty():
		var target_hp_ratio: float = ActorService.health_ratio(nearest_enemy)
		if GridService.is_adjacent(my_pos, t_pos):
			candidates.append({
				"action_type":     "melee_attack",
				"target_id":       str(nearest_enemy.get("id", "")),
				"distance":        enemy_dist,
				"target_hp_ratio": target_hp_ratio,
				"priority":        1.0,
				"_mark_bonus":     _mark_bonus,
				"_reveal_bonus":   _reveal_bonus,
			})
		else:
			candidates.append({
				"action_type":     "actor.move",
				"target_id":       str(nearest_enemy.get("id", "")),
				"target_pos":      t_pos,
				"target_distance": enemy_dist,
				"target_hp_ratio": target_hp_ratio,
				"priority":        1.0,
			})

	# actor.guard — only meaningful when an enemy is within guard_range tiles.
	#
	# Guard is a passive action (fear never dampens it); under sustained hits that add
	# fear but deal 0 damage, its score gap over melee widens every round until guard
	# wins permanently and combat never resolves. So: if the actor guarded last round
	# and HP is not critical, suppress guard — for every actor type and calling. At
	# critical HP guard stays available so a dying actor can try to survive.
	if not nearest_enemy.is_empty() and enemy_dist <= guard_range:
		var allow_guard: bool = true
		var last_i_g_v: Variant = actor.get("last_intent", {})
		var last_i_g: Dictionary = last_i_g_v if last_i_g_v is Dictionary else {}
		if str(last_i_g.get("action_type", "")) == "actor.guard":
			# Suppress unless critically wounded — a dying actor may legitimately need to guard.
			var crit_threshold: float = float(
				situational_muls.get("own_hp_critical", {}).get("threshold", 0.20)
			)
			allow_guard = ActorService.health_ratio(actor) <= crit_threshold
		if allow_guard:
			candidates.append({ "action_type": "actor.guard", "target_id": "", "priority": 0.0 })

	# protect_ally — only when a same-faction ally has taken any damage (current_hp < max_hp).
	var threatened: Dictionary = ActorService.get_threatened_ally(actor, all_actors, threat_threshold)
	if not threatened.is_empty():
		var ally_id: String = str(threatened.get("id", ""))
		candidates.append({
			"action_type":       "protect_ally",
			"target_id":         ally_id,
			"protected_actor_id": ally_id,
			"priority":          1.0,
		})

	# actor.retreat — calling-aware, Forming+ only. Aduro never retreats.
	if actor_type == "echo" \
			and (expression_band == "forming" or expression_band == "grounded" or expression_band == "whole"):
		var retreat_threshold: Variant = calling_behavior.get("retreat_threshold", null)
		if retreat_threshold != null and calling_origin != "aduro":
			var hp_r: float = ActorService.health_ratio(actor)
			# threat_read — a Whole leader in range reads the threat for its allies, so
			# they hold on longer before retreat enters the pool.
			var retreat_gate: float = maxf(0.0, float(retreat_threshold)
				- float(leadership_mods.get("_retreat_threshold_reduction", 0.0)))
			if hp_r < retreat_gate:
				candidates.append({
					"action_type": "actor.retreat",
					"target_id":   "",
					"priority":    1.0,
				})

	# actor.taunt — Aduro calling Grounded+ only.
	if actor_type == "echo" and calling_origin == "aduro" \
			and (expression_band == "grounded" or expression_band == "whole") \
			and not nearest_enemy.is_empty():
		candidates.append({
			"action_type": "actor.taunt",
			"target_id":   str(nearest_enemy.get("id", "")),
			"priority":    1.0,
		})

	# Skill-gated action candidates. Each echo may have equipped_skills (slot →
	# skill_id). For each equipped skill whose condition is met this turn, generate a
	# typed candidate with a pre-resolved skill_base_bonus so _score() doesn't need
	# intent weight rows for every calling skill action_type.
	if actor_type == "echo":
		var skills_cfg: Dictionary = context.get("skills_cfg", {})
		var skill_defs: Dictionary = skills_cfg.get("definitions", {})
		var equipped: Dictionary   = actor.get("equipped_skills", {})
		for _slot_key in equipped:
			var skill_id: String = str(equipped[_slot_key])
			if skill_id.is_empty():
				continue
			var defn: Dictionary = skill_defs.get(skill_id, {})
			if defn.is_empty():
				continue
			var action_t: String = str(defn.get("action_type", ""))
			if action_t.is_empty():
				continue
			var weight_tag: String = str(defn.get("intent_weight_tag", "melee_attack"))
			match action_t:
				"actor.press":
					# Condition: hit same target last round AND still adjacent.
					var press_li_v: Variant = actor.get("last_intent", {})
					var press_li: Dictionary = press_li_v if press_li_v is Dictionary else {}
					if str(press_li.get("action_type", "")) == "melee_attack" \
							and not str(press_li.get("target_id", "")).is_empty() \
							and not nearest_enemy.is_empty() \
							and str(press_li.get("target_id", "")) == str(nearest_enemy.get("id", "")) \
							and not t_pos.is_empty() \
							and GridService.is_adjacent(my_pos, t_pos):
						candidates.append({
							"action_type":      "actor.press",
							"target_id":        str(nearest_enemy.get("id", "")),
							"target_hp_ratio":  ActorService.health_ratio(nearest_enemy),
							"skill_id":         skill_id,
							"skill_base_bonus": resolve_skill_base(calling_origin, weight_tag, 15.0, skill_weight_cfg),
							"priority":         1.0,
						})
				"actor.interpose":
					# Condition: ally threatened.
					var interpose_ally: Dictionary = ActorService.get_threatened_ally(actor, all_actors, threat_threshold)
					if not interpose_ally.is_empty():
						candidates.append({
							"action_type":      "actor.interpose",
							"target_id":        str(interpose_ally.get("id", "")),
							"skill_id":         skill_id,
							"skill_base_bonus": resolve_skill_base(calling_origin, weight_tag, 0.0, skill_weight_cfg),
							"priority":         1.0,
						})
				"actor.hold_ground":
					# Condition: adjacent to shrine OR 2+ faction allies within 2 tiles.
					var hg_shrine: bool = false
					var hg_allies: int  = 0
					for hg_av in all_actors:
						if not (hg_av is Dictionary): continue
						var hg_a: Dictionary = hg_av
						if hg_a.get("is_dead", false): continue
						var hg_pos: Dictionary = hg_a.get("grid_pos", {})
						if hg_pos.is_empty(): continue
						if hg_a.get("is_structure", false):
							if GridService.chebyshev_distance(my_pos, hg_pos) <= 1:
								hg_shrine = true
						elif str(hg_a.get("faction", "")) == str(actor.get("faction", "")) \
								and str(hg_a.get("id", "")) != str(actor.get("id", "")):
							if GridService.chebyshev_distance(my_pos, hg_pos) <= 2:
								hg_allies += 1
					if hg_shrine or hg_allies >= 2:
						candidates.append({
							"action_type":      "actor.hold_ground",
							"target_id":        "",
							"skill_id":         skill_id,
							"skill_base_bonus": resolve_skill_base(calling_origin, weight_tag, 0.0, skill_weight_cfg),
							"priority":         1.0,
						})
				"actor.steady_call":
					# Once per combat; no other condition required.
					if not bool(actor.get("_steady_call_used", false)):
						candidates.append({
							"action_type":      "actor.steady_call",
							"target_id":        "",
							"skill_id":         skill_id,
							"skill_base_bonus": resolve_skill_base(calling_origin, weight_tag, 10.0, skill_weight_cfg),
							"priority":         1.0,
						})
				"actor.mark":
					# Condition: enemy within 3 tiles AND not already marked.
					if not nearest_enemy.is_empty() and enemy_dist <= ReachAuthority.SKILL_REACH \
							and str(nearest_enemy.get("marked_by", "")).is_empty():
						candidates.append({
							"action_type":      "actor.mark",
							"target_id":        str(nearest_enemy.get("id", "")),
							"skill_id":         skill_id,
							"skill_base_bonus": resolve_skill_base(calling_origin, weight_tag, 5.0, skill_weight_cfg),
							"priority":         1.0,
						})
				"actor.withdraw":
					# Condition: adjacent to 2+ enemies AND not on cooldown.
					if int(actor.get("_withdraw_cooldown", 0)) <= 0:
						var wd_count: int = 0
						for wd_av in all_actors:
							if not (wd_av is Dictionary): continue
							var wd_a: Dictionary = wd_av
							if wd_a.get("is_dead", false) or wd_a.get("is_structure", false): continue
							if str(wd_a.get("faction", "")) != str(actor.get("faction", "")):
								var wd_pos: Dictionary = wd_a.get("grid_pos", {})
								if not wd_pos.is_empty() and GridService.is_adjacent(my_pos, wd_pos):
									wd_count += 1
						if wd_count >= 2:
							candidates.append({
								"action_type":      "actor.withdraw",
								"target_id":        "",
								"skill_id":         skill_id,
								"skill_base_bonus": resolve_skill_base(calling_origin, weight_tag, 0.0, skill_weight_cfg),
								"priority":         1.0,
							})
				"actor.read_field":
					# Condition: _read_field_cooldown == 0.
					if int(actor.get("_read_field_cooldown", 0)) == 0:
						candidates.append({
							"action_type":      "actor.read_field",
							"target_id":        "",
							"skill_id":         skill_id,
							"skill_base_bonus": resolve_skill_base(calling_origin, weight_tag, 10.0, skill_weight_cfg),
							"priority":         1.0,
						})
				"actor.reveal":
					# Once per combat; condition: nearest enemy not yet revealed by seer.
					if not bool(actor.get("_reveal_used", false)) \
							and not nearest_enemy.is_empty() and enemy_dist <= ReachAuthority.SKILL_REACH \
							and str(nearest_enemy.get("revealed_by_seer", "")).is_empty():
						candidates.append({
							"action_type":      "actor.reveal",
							"target_id":        str(nearest_enemy.get("id", "")),
							"skill_id":         skill_id,
							"skill_base_bonus": resolve_skill_base(calling_origin, weight_tag, 10.0, skill_weight_cfg),
							"priority":         1.0,
						})

	return candidates


# PROG-010: Returns the most wounded (lowest hp_ratio) enemy relative to this actor.
# Used for enemy Adept+ focus fire. Falls back to empty if no enemies exist.
static func _get_most_wounded_enemy(actor: Dictionary, all_actors: Array) -> Dictionary:
	var my_faction: String = str(actor.get("faction", "echo"))
	var best: Dictionary = {}
	var best_ratio: float = 2.0
	for a_v in all_actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v as Dictionary
		if str(a.get("faction", "")) == my_faction:
			continue
		if a.get("is_dead", false) or a.get("is_structure", false):
			continue
		var r: float = ActorService.health_ratio(a)
		if r < best_ratio:
			best_ratio = r
			best = a
	return best


static func stationary_candidate(
	legacy: Dictionary,
	movement_context: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var plan: Dictionary = MovementActionPlanContract.from_legacy_candidate(legacy)
	var result: Dictionary = legacy.duplicate(true)
	apply_stationary_identity(result, plan, movement_context, profile)
	return result


## A goal-derived candidate, INCLUDING a zero-step one. A stay option that a goal
## published is a spatial decision like any other, so it keeps its goal and option and
## is scored with the same spatial terms as the routes it competes against. Re-badging
## it as a legacy stationary candidate (which `stationary_candidate` still does for
## candidates that never had a goal) would strip objective_progress, exposure, cohesion
## and congestion from it and hand every route a standing head start over staying put.
static func route_candidate(
	legacy: Dictionary,
	plan: Dictionary,
	goal: Dictionary,
	option: Dictionary,
	movement_context: Dictionary,
	profile: Dictionary
) -> Dictionary:
	var candidate: Dictionary = legacy.duplicate(true)
	if candidate.is_empty():
		candidate = (plan["payload"] as Dictionary).duplicate(true)
	candidate["action_type"] = str(plan["type"])
	candidate["target_id"] = str(plan["target_id"])
	if legacy.is_empty():
		add_perceived_target_health(candidate, movement_context)
	candidate["_movement_plan"] = plan.duplicate(true)
	candidate["_movement_goal"] = goal
	candidate["_movement_option"] = option
	candidate["_movement_route"] = true
	candidate["_movement_goal_id"] = str(goal["goal_id"])
	candidate["_movement_option_id"] = str(option["option_id"])
	candidate["_movement_path"] = (option["path"] as Array).duplicate(true)
	candidate["_movement_commitment"] = int(option["commitment"])
	candidate["_movement_fallback"] = (option["fallback"] as Dictionary).duplicate(true)
	candidate["_movement_pressure_sources"] = (goal["pressure_sources"] as Array).duplicate(true)
	return candidate


static func add_perceived_target_health(candidate: Dictionary, movement_context: Dictionary) -> void:
	var target_id: String = str(candidate.get("target_id", ""))
	if target_id.is_empty():
		return
	var facts: Dictionary = MovementContext.facts_by_id(movement_context)
	if facts.has(target_id):
		candidate["target_hp_ratio"] = float((facts[target_id] as Dictionary)["health_ratio"])


static func apply_stationary_identity(
	candidate: Dictionary,
	plan: Dictionary,
	movement_context: Dictionary,
	profile: Dictionary
) -> void:
	var origin: Dictionary = movement_context["origin"] as Dictionary
	var action_token: String = str(plan["type"]).replace(".", "_")
	var anchor: String = "c%dr%d" % [int(origin["col"]), int(origin["row"])]
	var goal_id: String = "goal.legacy.stationary.%s.%s" % [action_token, anchor]
	candidate["_movement_plan"] = plan.duplicate(true)
	candidate["_movement_goal"] = {}
	candidate["_movement_option"] = {}
	candidate["_movement_route"] = false
	candidate["_movement_goal_id"] = goal_id
	candidate["_movement_option_id"] = "%s.stationary.d%dr%d.pstay" % [
		goal_id, int(origin["col"]), int(origin["row"]),
	]
	candidate["_movement_path"] = []
	candidate["_movement_commitment"] = 0
	candidate["_movement_fallback"] = {}
	candidate["_movement_pressure_sources"] = []
	candidate["capacity"] = int(profile["capacity"])


static func append_legacy_purifier_candidate(
	candidates: Array[Dictionary],
	context: Dictionary,
	actor: Dictionary,
	all_actors: Array,
	movement_context: Dictionary,
	profile: Dictionary
) -> void:
	if not context.get("is_purifier", false) \
			or not context.get("shrine_alive", false) \
			or int(actor.get("purify_cooldown", 0)) != 0:
		return
	var my_pos: Dictionary = actor.get("grid_pos", {}) as Dictionary
	for actor_value: Variant in all_actors:
		if actor_value is Dictionary:
			var other: Dictionary = actor_value as Dictionary
			if other.get("is_structure", false) and not other.get("is_dead", false):
				if ReachAuthority.in_reach(my_pos, other.get("grid_pos", {}), "actor.purify_shrine"):
					var candidate: Dictionary = stationary_candidate(
						{"action_type": "actor.purify_shrine", "target_id": "", "priority": 1.0},
						movement_context,
						profile
					)
					candidate["_score"] = 9999.0
					candidate["_hard_override"] = "purify_shrine_in_reach"
					candidates.append(candidate)
				return


## Resolves the base score for a skill candidate. Looks up calling_origin's weight
## for intent_weight_tag (the action type this skill resembles) from
## skill_weight_cfg.intent_weights_by_calling_origin, then adds a skill-specific bonus.
## Stored as skill_base_bonus in the candidate dict so _score() can use it in place of
## the normal action_type table lookup.
static func resolve_skill_base(
	calling_origin: String, intent_weight_tag: String, bonus: float, skill_weight_cfg: Dictionary
) -> float:
	var origin_table: Dictionary = skill_weight_cfg.get("intent_weights_by_calling_origin", {})
	var calling_row: Dictionary  = origin_table.get(calling_origin, origin_table.get("uncalled", {}))
	var default_weight: float    = float(skill_weight_cfg.get("default_intent_weight", 0.0))
	return float(calling_row.get(intent_weight_tag, default_weight)) + bonus

## PaceService
## Pure static owner of the pace bonus rules: which modes carry pace, par at fight start, the
## pace state and bonus curve, and the reached-enemy and ally-kill sets the rank uses.
## Spec: docs/stories/pace-reward/design.md. No RNG, no config reads, no service calls.

class_name PaceService extends RefCounted

const PACE_FULL := "full"
const PACE_PARTIAL := "partial"
const PACE_NONE := "none"

## The GUIDE_SPIRIT variant that carries pace (EncounterObjectiveSpawnService rolls it).
const GUIDE_ESCORT := "escort"

## Modes whose win can happen faster or slower (design §3).
const PACE_MODES := [
	EncounterResolutionModes.COMBAT,
	EncounterResolutionModes.PURIFY_SHRINE,
	EncounterResolutionModes.RECOVER,
	EncounterResolutionModes.PURSUE,
]

## Modes whose rank counts only reached enemies (design §5). COMBAT and PURIFY_SHRINE win only
## by killing every enemy, so their full enemy count is already the right ceiling.
const REACHED_ENEMY_MODES := [
	EncounterResolutionModes.PROTECT,
	EncounterResolutionModes.ENDURE,
	EncounterResolutionModes.RECOVER,
	EncounterResolutionModes.PURSUE,
	EncounterResolutionModes.GUIDE_SPIRIT,
]


## GUIDE_SPIRIT carries pace only in its escort variant (decisions.md D-31); protect is a
## timer mode (D-06). guide_mode is objective_params / combat_state["guide_mode"].
static func is_pace_mode(mode: String, guide_mode: String) -> bool:
	if mode == EncounterResolutionModes.GUIDE_SPIRIT:
		return guide_mode == GUIDE_ESCORT
	return mode in PACE_MODES


static func tracks_reached_enemies(mode: String) -> bool:
	return mode in REACHED_ENEMY_MODES


## Par for one fight: travel_par + required_hold (design §3). Returns 0.0 for a no-pace mode.
## travel_par = distance / mean party capacity, clamped to at least 1.0 and NOT rounded — the
## tuned values (tuning.md §0) were measured on this unrounded form.
## actors must hold their fight-start positions.
## GUIDE_SPIRIT escort: a joined spirit uses the kill-mode par (decisions.md D-32); a non-joined
## spirit uses _escort_par (D-33).
static func compute_par(actors: Array, mode: String, objective_params: Dictionary,
		capacity_cfg: Dictionary) -> float:
	if not is_pace_mode(mode, str(objective_params.get("guide_mode", ""))):
		return 0.0
	var escort_walk := mode == EncounterResolutionModes.GUIDE_SPIRIT \
		and not bool(objective_params.get("spirit_joins_battle", false))
	var echoes: Array = []
	var targets: Array = []
	for a_v in actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if _is_party_echo(a):
			echoes.append(a)
		elif escort_walk:
			if bool(a.get("is_spirit", false)):
				targets.append(a.get("grid_pos", {}))
		elif mode == EncounterResolutionModes.RECOVER:
			if bool(a.get("is_objective_relic", false)):
				targets.append(a.get("grid_pos", {}))
		elif mode == EncounterResolutionModes.PURSUE:
			if bool(a.get("is_quarry", false)):
				targets.append(a.get("grid_pos", {}))
		elif _is_enemy(a) and not bool(a.get("is_dead", false)):
			targets.append(a.get("grid_pos", {}))

	var required_hold := 0
	if mode == EncounterResolutionModes.RECOVER:
		required_hold = maxi(0, int(objective_params.get("hold_rounds", 0)) - 1)
	elif mode == EncounterResolutionModes.PURSUE:
		required_hold = maxi(0, int(objective_params.get("contain_rounds", 0)) - 1)

	if escort_walk:
		return _escort_par(echoes, targets, objective_params, capacity_cfg)

	var travel_par := 1.0
	if not echoes.is_empty() and not targets.is_empty():
		var dist_sum := 0
		var dist_min := -1
		for e_v in echoes:
			var e: Dictionary = e_v
			var near := -1
			for p_v in targets:
				var d := GridService.chebyshev_distance(e.get("grid_pos", {}), p_v)
				near = d if near < 0 else mini(near, d)
			dist_sum += near
			dist_min = near if dist_min < 0 else mini(dist_min, near)
		# RECOVER: one echo must reach the relic, so the nearest echo sets par (decisions.md D-09).
		var distance: float = float(dist_min) if mode == EncounterResolutionModes.RECOVER \
			else float(dist_sum) / float(echoes.size())
		var mean_cap := _mean_capacity(echoes, capacity_cfg)
		if mean_cap > 0.0:
			travel_par = maxf(1.0, distance / mean_cap)
	return travel_par + float(required_hold)


## Non-joined escort par (decisions.md D-33, E-min), no hold term:
## max(1, max(0, nearest echo→spirit − 1) / party mean capacity + spirit→destination / spirit capacity).
## The spirit capacity is the authored capacity the game moves it with. The spirit starts to
## walk only when an echo stands next to it, so the echo walk stops one cell short.
static func _escort_par(echoes: Array, spirit_cells: Array, objective_params: Dictionary,
		capacity_cfg: Dictionary) -> float:
	if echoes.is_empty() or spirit_cells.is_empty():
		return 1.0
	var spirit_cell: Dictionary = spirit_cells[0]
	var near := -1
	for e_v in echoes:
		var d := GridService.chebyshev_distance((e_v as Dictionary).get("grid_pos", {}), spirit_cell)
		near = d if near < 0 else mini(near, d)
	var mean_cap := _mean_capacity(echoes, capacity_cfg)
	var party_walk := float(maxi(0, near - 1)) / mean_cap if mean_cap > 0.0 else 0.0
	# No valid destination (col -1) means no escort win exists; only the party walk counts.
	var spirit_walk := 0.0
	var dest := { "col": int(objective_params.get("destination_col", -1)),
		"row": int(objective_params.get("destination_row", -1)) }
	if int(dest["col"]) >= 0 and int(dest["row"]) >= 0:
		spirit_walk = float(GridService.chebyshev_distance(spirit_cell, dest)) \
			/ float(GuideSpiritActivationService.AUTHORED_CAPACITY)
	return maxf(1.0, party_walk + spirit_walk)


static func _mean_capacity(echoes: Array, capacity_cfg: Dictionary) -> float:
	var cap_sum := 0
	for e_v in echoes:
		cap_sum += int(MovementProfileService.derive_profile(e_v, capacity_cfg).get("capacity", 0))
	return float(cap_sum) / float(echoes.size())


## Bonus fraction in [0, 1] for a fight that ends on round_ended (design §4). 0.0 when par is 0.
static func bonus_fraction(round_ended: int, par_rounds: float, full_ratio: float,
		zero_ratio: float) -> float:
	if par_rounds <= 0.0:
		return 0.0
	var ratio := float(round_ended) / par_rounds
	if ratio <= full_ratio:
		return 1.0
	if ratio >= zero_ratio:
		return 0.0
	return (zero_ratio - ratio) / (zero_ratio - full_ratio)


## Ase a win on round_ended pays: roundi(stage base × pace_bonus_pct × fraction).
static func bonus_ase(round_ended: int, par_rounds: float, full_ratio: float, zero_ratio: float,
		stage_base: int, bonus_pct: float) -> int:
	return roundi(float(stage_base) * bonus_pct
		* bonus_fraction(round_ended, par_rounds, full_ratio, zero_ratio))


## The maximum pace bonus in Ase: the bonus at fraction 1.0.
static func max_bonus_ase(stage_base: int, bonus_pct: float) -> int:
	return roundi(float(stage_base) * bonus_pct)


## "full" / "partial" / "none" (design §6). "" when par is 0 (no-pace mode).
## Set from the Ase paid (decisions.md D-22): full = the maximum, none = 0, partial = between.
## The live colour and the result both call this, so they cannot disagree with the Ase row.
static func pace_state(round_counter: int, par_rounds: float, full_ratio: float,
		zero_ratio: float, stage_base: int, bonus_pct: float) -> String:
	if par_rounds <= 0.0:
		return ""
	var paid := bonus_ase(round_counter, par_rounds, full_ratio, zero_ratio, stage_base, bonus_pct)
	# 0 Ase is "none" first, so a maximum that rounds to 0 is never "full".
	if paid <= 0:
		return PACE_NONE
	if paid >= max_bonus_ase(stage_base, bonus_pct):
		return PACE_FULL
	return PACE_PARTIAL


## Appends to combat_state["reached_enemy_ids"] every living enemy that ends this round within
## Chebyshev 1 of a living party echo. Never removes an id. A dead enemy is not checked: a kill
## reaches only through record_kill() (decisions.md D-23).
static func record_reached_enemies(actors: Array, combat_state: Dictionary) -> void:
	if not tracks_reached_enemies(str(combat_state.get("objective", ""))):
		return
	var reached: Array = combat_state.get("reached_enemy_ids", [])
	var echo_cells: Array = []
	for a_v in actors:
		if a_v is Dictionary and _is_party_echo(a_v) and not bool(a_v.get("is_dead", false)):
			echo_cells.append((a_v as Dictionary).get("grid_pos", {}))
	for a_v in actors:
		if not (a_v is Dictionary) or not _is_enemy(a_v) or bool(a_v.get("is_dead", false)):
			continue
		var enemy_id := str((a_v as Dictionary).get("id", ""))
		if enemy_id in reached:
			continue
		var cell: Dictionary = (a_v as Dictionary).get("grid_pos", {})
		for c_v in echo_cells:
			if GridService.chebyshev_distance(cell, c_v) <= 1:
				reached.append(enemy_id)
				break
	combat_state["reached_enemy_ids"] = reached


## Records the killer side of one resolved action, at kill time (decisions.md D-23).
## result is one ectx.last_round_results entry; only a melee kill of an enemy counts.
## A Temporary Ally or joined-spirit kill goes to combat_state["ally_killed_enemy_ids"] in every
## mode. A party-echo kill marks the enemy reached in the reached-enemy modes, also when that
## echo is already dead (it died in the same round). Reads the killer's flags, never its HP.
static func record_kill(result: Dictionary, actors: Array, combat_state: Dictionary) -> void:
	if str(result.get("action_type", "")) != "melee_attack" or not bool(result.get("is_kill", false)):
		return
	var target: Dictionary = EncounterContext.find_actor_by_id(actors, str(result.get("target_id", "")))
	if target.is_empty() or not _is_enemy(target):
		return
	var killer: Dictionary = EncounterContext.find_actor_by_id(actors, str(result.get("attacker_id", "")))
	var key := ""
	if _is_ally_or_spirit(killer):
		key = "ally_killed_enemy_ids"
	elif _is_party_echo(killer) and tracks_reached_enemies(str(combat_state.get("objective", ""))):
		key = "reached_enemy_ids"
	if key.is_empty():
		return
	var ids: Array = combat_state.get(key, [])
	var enemy_id := str(target.get("id", ""))
	if not enemy_id in ids:
		ids.append(enemy_id)
	combat_state[key] = ids


## The reach-mode rank ceiling count: reached ids minus ally-killed ids, as a set difference
## (decisions.md D-23), so an enemy is never removed twice.
static func rank_reached_count(combat_state: Dictionary) -> int:
	var ally_killed: Array = combat_state.get("ally_killed_enemy_ids", [])
	var n := 0
	for id_v in combat_state.get("reached_enemy_ids", []):
		if not id_v in ally_killed:
			n += 1
	return n


## A roster echo: joined allies and spirits are faction "echo" but are not the party
## (same exclusion as the reward tally in FlowEncounterState.build_final_snapshot).
static func _is_party_echo(a: Dictionary) -> bool:
	return str(a.get("faction", "")) == "echo" \
		and not bool(a.get("is_ally", false)) and not bool(a.get("is_spirit", false))


## A Temporary Ally or a joined guide spirit: it fights for the party but is not the party.
static func _is_ally_or_spirit(a: Dictionary) -> bool:
	return bool(a.get("is_ally", false)) or bool(a.get("is_spirit", false))


static func _is_enemy(a: Dictionary) -> bool:
	return str(a.get("faction", "")) == "enemy" and not bool(a.get("is_structure", false))

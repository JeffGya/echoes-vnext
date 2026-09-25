## PaceService
## Pure static owner of the pace bonus rules: which modes carry pace, par at fight start, the
## pace state and bonus curve, and the reached-enemy set the rank uses.
## Spec: docs/stories/pace-reward/design.md. No RNG, no config reads, no service calls.

class_name PaceService extends RefCounted

const PACE_FULL := "full"
const PACE_PARTIAL := "partial"
const PACE_NONE := "none"

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


static func is_pace_mode(mode: String) -> bool:
	return mode in PACE_MODES


static func tracks_reached_enemies(mode: String) -> bool:
	return mode in REACHED_ENEMY_MODES


## Par for one fight: travel_par + required_hold (design §3). Returns 0.0 for a no-pace mode.
## travel_par = distance / mean party capacity, clamped to at least 1.0 and NOT rounded — the
## tuned values (tuning.md §0) were measured on this unrounded form.
## actors must hold their fight-start positions.
static func compute_par(actors: Array, mode: String, objective_params: Dictionary,
		capacity_cfg: Dictionary) -> float:
	if not is_pace_mode(mode):
		return 0.0
	var echoes: Array = []
	var targets: Array = []
	for a_v in actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if _is_party_echo(a):
			echoes.append(a)
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

	var travel_par := 1.0
	if not echoes.is_empty() and not targets.is_empty():
		var cap_sum := 0
		var dist_sum := 0
		var dist_min := -1
		for e_v in echoes:
			var e: Dictionary = e_v
			cap_sum += int(MovementProfileService.derive_profile(e, capacity_cfg).get("capacity", 0))
			var near := -1
			for p_v in targets:
				var d := GridService.chebyshev_distance(e.get("grid_pos", {}), p_v)
				near = d if near < 0 else mini(near, d)
			dist_sum += near
			dist_min = near if dist_min < 0 else mini(dist_min, near)
		# RECOVER: one echo must reach the relic, so the nearest echo sets par (decisions.md D-09).
		var distance: float = float(dist_min) if mode == EncounterResolutionModes.RECOVER \
			else float(dist_sum) / float(echoes.size())
		var mean_cap := float(cap_sum) / float(echoes.size())
		if mean_cap > 0.0:
			travel_par = maxf(1.0, distance / mean_cap)
	return travel_par + float(required_hold)


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


## "full" / "partial" / "none" (design §6). "" when par is 0 (no-pace mode).
## The colour follows the Ase (design §7): a partial fraction whose bonus rounds to 0 Ase
## is "none", so the state and the "Pace bonus" row always agree.
static func pace_state(round_counter: int, par_rounds: float, full_ratio: float,
		zero_ratio: float, stage_base: int, bonus_pct: float) -> String:
	if par_rounds <= 0.0:
		return ""
	if bonus_fraction(round_counter, par_rounds, full_ratio, zero_ratio) >= 1.0:
		return PACE_FULL
	if bonus_ase(round_counter, par_rounds, full_ratio, zero_ratio, stage_base, bonus_pct) >= 1:
		return PACE_PARTIAL
	return PACE_NONE


## Appends to combat_state["reached_enemy_ids"] every enemy that ends this round within
## Chebyshev 1 of a living party echo. Never removes an id. Dead enemies are checked at their
## last cell, so an enemy killed in the round it arrives still counts.
static func record_reached_enemies(actors: Array, combat_state: Dictionary) -> void:
	if not tracks_reached_enemies(str(combat_state.get("objective", ""))):
		return
	var reached: Array = combat_state.get("reached_enemy_ids", [])
	var echo_cells: Array = []
	for a_v in actors:
		if a_v is Dictionary and _is_party_echo(a_v) and not bool(a_v.get("is_dead", false)):
			echo_cells.append((a_v as Dictionary).get("grid_pos", {}))
	for a_v in actors:
		if not (a_v is Dictionary) or not _is_enemy(a_v):
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


## A roster echo: joined allies and spirits are faction "echo" but are not the party
## (same exclusion as the reward tally in FlowEncounterState.build_final_snapshot).
static func _is_party_echo(a: Dictionary) -> bool:
	return str(a.get("faction", "")) == "echo" \
		and not bool(a.get("is_ally", false)) and not bool(a.get("is_spirit", false))


static func _is_enemy(a: Dictionary) -> bool:
	return str(a.get("faction", "")) == "enemy" and not bool(a.get("is_structure", false))

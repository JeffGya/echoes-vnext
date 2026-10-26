## RewardCalc
## ECONOMY-004: Pure static helper — computes stage reward values from encounter result.
## No side effects, no service calls, no OS access.
## Same inputs → identical output every time (deterministic).

class_name RewardCalc extends RefCounted

## THE single definition of a stage's base reward, for every reader. It sums the weights of the
## objectives selected by `mode`; no reader keeps its own copy.
##   MODE_COMPLETED:             objectives with `completed` true (stage payer, partials).
##   MODE_COMPLETED_PLUS_FOUGHT: those, plus the objective at `fought_index` (the fight base_reward).
##   MODE_FOUGHT:                only the objective at `fought_index` (defeat consolation).
## Select first, then weigh: an objective that is not selected is never looked up, so it logs
## nothing. A selected type with no key in `objective_weights` logs
## `economy.reward.unknown_objective_type` through `logger` (when given) and counts 0.
## A key with value 0 (the boss) is a weight and logs nothing.
## The type key is `"type"`, never `"obj_type"`.
const MODE_COMPLETED := "completed"
const MODE_COMPLETED_PLUS_FOUGHT := "completed_plus_fought"
const MODE_FOUGHT := "fought"


static func base_reward(objectives: Array, reward_cfg: Dictionary,
		logger: StructuredLogger = null, t: int = 0,
		mode: String = MODE_COMPLETED, fought_index: int = -1) -> int:
	return _sum_selected(objectives, reward_cfg, "objective_weights", logger, t, mode, fought_index)


## The stage's Ekwan before the replay factor: the sum of `objective_ekwan` over the COMPLETED
## objectives (same selection as the Ase base). The caller rounds ONCE on this sum.
static func stage_ekwan(objectives: Array, reward_cfg: Dictionary,
		logger: StructuredLogger = null, t: int = 0) -> int:
	return _sum_selected(objectives, reward_cfg, "objective_ekwan", logger, t, MODE_COMPLETED, -1)


## Shared selection and lookup behind `base_reward` and `stage_ekwan`, so the two tables cannot
## drift in what they select or how a missing key behaves.
static func _sum_selected(objectives: Array, reward_cfg: Dictionary, table_key: String,
		logger: StructuredLogger, t: int, mode: String, fought_index: int) -> int:
	var weights_v: Variant = reward_cfg.get(table_key, {})
	var weights: Dictionary = weights_v if weights_v is Dictionary else {}
	var base := 0
	for i in objectives.size():
		var obj: Dictionary = objectives[i] if objectives[i] is Dictionary else {}
		var done := bool(obj.get("completed", false))
		var fought := i == fought_index
		var selected := (done and mode != MODE_FOUGHT) or (fought and mode != MODE_COMPLETED)
		if not selected:
			continue
		var type := str(obj.get("type", ""))
		if not weights.has(type):
			if logger != null:
				logger.warn(t, "economy.reward.unknown_objective_type",
					"Objective type has no weight — counts 0", {
						"type": type, "objective_index": i, "table": table_key })
			continue
		var w_v: Variant = weights[type]
		base += int(w_v) if typeof(w_v) == TYPE_INT or typeof(w_v) == TYPE_FLOAT else 0
	return base


## The objectives not settled at a return home (D-105). The stage payer sums only these; a settled
## objective was paid by the roll and pays nothing more.
static func unsettled(objectives: Array) -> Array:
	var out: Array = []
	for obj_v in objectives:
		if not (obj_v is Dictionary and bool((obj_v as Dictionary).get("settled", false))):
			out.append(obj_v)
	return out


## Counts for the ledger row "overcome of total". Types in `reward_cfg.objective_count_excluded_types`
## (the boss stub) are in neither number. Display only: it never changes a payout.
static func objective_counts(objectives: Array, reward_cfg: Dictionary) -> Dictionary:
	var excluded_v: Variant = reward_cfg.get("objective_count_excluded_types", [])
	var excluded: Array = excluded_v if excluded_v is Array else []
	var overcome := 0
	var total := 0
	for obj_v in objectives:
		var obj: Dictionary = obj_v if obj_v is Dictionary else {}
		if excluded.has(str(obj.get("type", ""))):
			continue
		total += 1
		if bool(obj.get("completed", false)):
			overcome += 1
	return { "overcome": overcome, "total": total }


## The one reader of a numeric `data.rewards` key. There is no code default: a missing key logs
## `economy.reward.missing_config_key` through `logger` (`push_error` when none is given) and
## returns `safe`, a neutral value (1.0 for a factor, 0.0 for a bonus), never a design number.
static func cfg_num(reward_cfg: Dictionary, key: String, safe: float,
		logger: StructuredLogger = null, t: int = 0) -> float:
	var v: Variant = reward_cfg.get(key)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v)
	if logger != null:
		logger.warn(t, "economy.reward.missing_config_key",
			"data.rewards key is missing or not a number", { "key": key, "safe": safe })
	else:
		push_error("RewardCalc: data.rewards.%s is missing or not a number; using %s" % [key, safe])
	return safe


## Realm scale on objective Ase and Ekwan (D-63): 1 + step x (position in `realm_order` - 1).
## A realm outside `realm_order` (the prologue) uses 1.0. The Echoes stipend is never scaled.
static func realm_scale(realm_id: String, realm_order: Array, reward_cfg: Dictionary,
		logger: StructuredLogger = null, t: int = 0) -> float:
	var pos := realm_order.find(realm_id)
	if pos < 0:
		return 1.0
	return 1.0 + cfg_num(reward_cfg, "realm_scale_step", 0.0, logger, t) * float(pos)


## Replay factor on objective Ase and Ekwan (D-54): flat, 1.0 on a first run (`run_count` 0).
static func replay_factor(run_count: int, reward_cfg: Dictionary,
		logger: StructuredLogger = null, t: int = 0) -> float:
	if run_count <= 0:
		return 1.0
	return cfg_num(reward_cfg, "replay_factor", 1.0, logger, t)


## Rounds a payout amount. The epsilon keeps a true x.5 (30 x 0.35 = 10.5) from falling to x.4999.
static func round_payout(amount: float) -> int:
	return roundi(amount + 0.000000001)


## The party Echoes of a fight: `alive` (not dead), `started` (all of them) and `lost` (display
## names of the dead ones). Temporary allies and the guide spirit are not roster Echoes (D-45).
## Downed and withdrawn Echoes count as home: only `is_dead` removes one. `prior_lost` (names that
## died in an earlier fight of the stage) also removes one from `alive`; `lost` stays this fight's dead.
static func echo_tally(actors: Array, prior_lost: Array = []) -> Dictionary:
	var alive := 0
	var started := 0
	var lost: Array = []
	for a_v in actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) != "echo" or bool(a.get("is_ally", false)) \
				or bool(a.get("is_spirit", false)):
			continue
		started += 1
		var nm := str(a.get("name", ""))
		if bool(a.get("is_dead", false)):
			lost.append(nm)
		elif not prior_lost.has(nm):
			alive += 1
	return { "alive": alive, "started": started, "lost": lost }


## Compute the fight's reward values from the encounter result.
## Returns a dict ready for EconomyService.reward_encounter_complete().
##
## echoes_survived / total_echoes: roster Echoes home / started in the fight (no allies, no spirit).
## round_ended, par_rounds, resolution_mode, guide_mode: give the pace fraction. par_rounds is
##   0.0 for a no-pace mode.
## logger, t: receive the unknown-objective-type error from base_reward(); t is injected.
## fought_index: the objective of the situation being fought, -1 for none. `base_reward` is the
##   completed objectives plus this one; `consolation_base` (the defeat pay base) is this one alone.
## realm_scale_in: the realm scale (`realm_scale`), handed through for the consolation payer.
## Speed pays no Ase (D-49). It enters only the rank score (`rank_score`).
static func compute(
	victory: bool,
	objectives: Array,
	echoes_survived: int,
	total_echoes: int,
	round_ended: int,
	run_count: int,
	reward_cfg: Dictionary,
	resolution_mode: String,
	par_rounds: float,
	guide_mode: String = "",
	logger: StructuredLogger = null,
	t: int = 0,
	fought_index: int = -1,
	realm_scale_in: float = 1.0
) -> Dictionary:
	var base := base_reward(objectives, reward_cfg, logger, t, MODE_COMPLETED_PLUS_FOUGHT, fought_index)
	# The fought objective is already inside `base`, so it logs there; no second log here.
	var consolation_base := base_reward(objectives, reward_cfg, null, t, MODE_FOUGHT, fought_index)

	var is_pace    := PaceService.is_pace_mode(resolution_mode, guide_mode) and par_rounds > 0.0
	var full_ratio := cfg_num(reward_cfg, "pace_full_ratio", 1.0, logger, t) if is_pace else 1.0
	var zero_ratio := cfg_num(reward_cfg, "pace_zero_ratio", 2.0, logger, t) if is_pace else 2.0
	var fraction   := PaceService.bonus_fraction(round_ended, par_rounds, full_ratio, zero_ratio)

	var replay := replay_factor(run_count, reward_cfg, logger, t)

	# A no-pace mode has no speed to earn, so it takes the full pace points and is not capped.
	# `rank_without_pace` is the grade with the pace points removed, for the rank-cause note.
	var rank := "F"
	var rank_without_pace := "F"
	var any_death := echoes_survived < total_echoes
	if victory:
		var thresholds_v: Variant = reward_cfg.get("rank_thresholds", {})
		var thresholds: Dictionary = thresholds_v if thresholds_v is Dictionary else {}
		var pace_credit := fraction if is_pace else 1.0
		rank = _compute_rank(rank_score(echoes_survived, total_echoes, pace_credit, reward_cfg, logger, t),
			thresholds, any_death, logger, t)
		rank_without_pace = _compute_rank(rank_score(echoes_survived, total_echoes, 0.0, reward_cfg, logger, t),
			thresholds, any_death, logger, t) if is_pace else rank

	return {
		"base_reward":       base,
		"consolation_base":  consolation_base,
		"pace_mode":         is_pace,
		# A defeat carries no pace state (design §7).
		"pace_state":        PaceService.pace_state(round_ended, par_rounds, full_ratio, zero_ratio) \
			if is_pace and victory else "",
		"pace_changed_rank": rank != rank_without_pace,
		"realm_scale":       realm_scale_in,
		"replay_factor":     replay,
		"rank":              rank,
	}


## The rank score of a win: win points + home points x (home / started) + pace points x pace_credit.
## Reads no Ase amount and no replay factor (D-74). pace_credit is the pace fraction (0 to 1).
static func rank_score(echoes_survived: int, total_echoes: int, pace_credit: float,
		reward_cfg: Dictionary, logger: StructuredLogger = null, t: int = 0) -> float:
	var pts_v: Variant = reward_cfg.get("rank_points", {})
	var pts: Dictionary = pts_v if pts_v is Dictionary else {}
	var home_share := float(echoes_survived) / float(total_echoes) if total_echoes > 0 else 1.0
	var score := cfg_num(pts, "win", 0.0, logger, t) + cfg_num(pts, "home", 0.0, logger, t) * home_share \
		+ cfg_num(pts, "pace", 0.0, logger, t) * pace_credit
	return score


## Any death caps a win at this grade, whatever the pace credit (D-69).
const DEATH_CAP_RANK := "A"


static func _compute_rank(raw_score: float, thresholds: Dictionary, any_death: bool = false,
		logger: StructuredLogger = null, t: int = 0) -> String:
	# A score on a threshold must not be lost to float error (0.4 + 0.4 + 0.2 x 0.5 sums to 0.8999...).
	var rank_score := raw_score + 0.000000001
	var s_thresh := cfg_num(thresholds, "S", 2.0, logger, t)
	var a_thresh := cfg_num(thresholds, "A", 2.0, logger, t)
	var b_thresh := cfg_num(thresholds, "B", 2.0, logger, t)
	var c_thresh := cfg_num(thresholds, "C", 2.0, logger, t)
	var d_thresh := cfg_num(thresholds, "D", 2.0, logger, t)
	if rank_score >= s_thresh and not any_death:
		return "S"
	if rank_score >= a_thresh:
		return "A"
	if rank_score >= b_thresh:
		return "B"
	if rank_score >= c_thresh:
		return "C"
	if rank_score >= d_thresh:
		return "D"
	return "F"

# res://core/economy/StageSettlementService.gd
# V2-INFRA-003 Phase 8 — the STAGE-CADENCE settlement (defects D05 / D36 / D77).
#
# WHY THIS FILE EXISTS
# --------------------
# `FlowEncounterState.build_final_snapshot()` used to pay the whole reward at every combat end:
# the stage's summed objective weights, a realm-virtue bonus (removed, D-40), and the stage-clear
# Storyweight. Stage-cadence payouts, fired once per ENCOUNTER, inside a snapshot builder,
# in a dispatch that never advances the stage. That produced D77 (every combat situation in a
# stage paid another full stage reward; a defeat paid a 25% consolation without limit) and D36
# (quit at the Resolve screen and the money is banked while the stage stays "current"), and its
# mirror image D05 (finish a stage WITHOUT a fight and you are paid nothing at all).
#
# The three payouts now land here, once per stage, in the `flow.complete_stage` dispatch, ahead
# of `RealmService.advance_stage()`. Payment and stage advance are one dispatch and one flush,
# so there is no window to quit inside. And because this path does not care whether an encounter
# happened, a stage completed without combat is paid — D05's "receives no reward" half.
#
# CONTRACT (the WeaveController/EmotionConsequenceService service contract):
#   - Typed RefCounted. Explicit typed dependencies at construction. No autoloads, no service
#     locator, no reaching back into FlowRuntime.
#   - No `flow_machine` reference — cannot transition or refresh a snapshot.
#   - Never calls SaveService directly, and never calls a controller. Saves are requested
#     through `flow_ctx.request_save(reason)`.
#   - No UI or scene-tree reference.
#
# PLACED IN core/economy/ beside EconomyService.gd and RewardCalc.gd, the two things it
# orchestrates — the "a service wrapping a domain class lives beside that class" rule
# (VowConsequenceService beside VowService). It is NOT part of EconomySettlementService.gd next
# door: that file settles the OFFLINE ASE CLOCK (last_settle_unix, accrual, institution tick).
# Same English word, unrelated mechanic; fusing them would give one class two clocks.
#
# IDEMPOTENCY
# -----------
# One stamp per stage: `save_data.realms[realm].stages[i].settlement_receipt`, the shape
# SaveService's repair pass already defaults to `{}`
# (core/save/SaveService.gd:1218-1224) — `{ version, result_id, settled, outcome, settled_t }`.
# `settled == true` means this stage has paid; `settle()` then returns `{}` and mutates nothing.
# The precedent is `onboarding.first_trial_rewards_granted`
# (core/onboarding/KeeperIntroService.gd:140-153): read the flag, return early, otherwise pay
# and set it in the same call.
#
# THE FRESH-STAGE GAP. A stage generated at runtime by RealmGenerator has no
# `settlement_receipt` key at all until the next save repair pass runs over it. That is handled
# by reading the receipt with a `{}` default and treating a missing/!settled receipt as
# unsettled, then WRITING the full receipt onto the stage dict here. The repair pass only ever
# adds `{}` where the key is absent (it never overwrites a populated one — pinned by
# tests/SaveBridgeTests.gd:394-431), so a receipt written here survives it.
#
# NOT SETTLED HERE: the defeat consolation (paid at the fight by
# `EconomyService.reward_encounter_complete()`) and per-kill Storyweight (mid-combat kill-XP path).

class_name StageSettlementService
extends RefCounted

const RECEIPT_VERSION: int = 1

var flow_ctx: FlowContext
var config_service: ConfigService
var econ: EconomyService
var logger: StructuredLogger


func _init(
	_flow_ctx: FlowContext,
	_config_service: ConfigService,
	_econ: EconomyService,
	_logger: StructuredLogger
) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	econ = _econ
	logger = _logger


## Settle the stage the party has just completed.
##
## Returns the payout dict `{ ase_awarded, ekwan_awarded, breakdown, xp_events }` on the one
## call that pays, and `{}` on every later call for the same stage (already settled), on a
## stage that cannot be located, and when `stage_cleared` is false.
##
## stage_cleared — false only if this is somehow reached after a defeat. The Resolve screen
##   offers `flow.complete_stage` on victory only (EncounterSnapshotBuilder._build_resolve_actions
##   :498-504 gives a defeat nothing but `flow.go_state` to SANCTUM), so this is a guard, not a
##   live branch. A stage the party did not clear pays nothing and stamps nothing.
##
## MUST be called while `flow_ctx.encounter_ctx` is still non-null on the combat path: the
## Storyweight virtue multiplier reads each echo's action log off it. `handle_complete_stage()`
## calls this before it nulls the context.
func settle(stage_cleared: bool, t: int) -> Dictionary:
	if not stage_cleared:
		return {}
	if flow_ctx.realm_id.is_empty() or flow_ctx.stage_id.is_empty():
		return {}

	var realm_model: Dictionary = RealmService.get_active(flow_ctx)
	if realm_model.is_empty():
		return {}

	var stage_index := _stage_index()
	var stage_ref := _stage_ref(realm_model, stage_index)
	if stage_ref.is_empty():
		return {}

	# --- idempotency stamp -------------------------------------------------
	var receipt_v: Variant = stage_ref.get("settlement_receipt", {})
	var receipt: Dictionary = receipt_v if receipt_v is Dictionary else {}
	if bool(receipt.get("settled", false)):
		if logger != null:
			logger.info(t, "economy.stage.already_settled", "Stage already settled — no payout", {
				"realm_id":    flow_ctx.realm_id,
				"stage_index": stage_index,
				"result_id":   str(receipt.get("result_id", "")),
			})
		return {}

	# --- the stage-cadence Ase/Ekwan ---------------------------------------
	var plan := _plan(realm_model, stage_ref, stage_index, logger, t)
	var base: int = plan["base"]
	# The preview never logs this.
	if logger != null:
		logger.info(t, "economy.stage.reward", "Stage reward inputs", {
			"stage_index": stage_index, "base": base,
			"realm_scale": plan["realm_scale"], "replay_factor": plan["replay_factor"] })

	var payout: Dictionary = econ.settle_stage_complete(
		base, plan["realm_scale"], plan["replay_factor"], logger, t,
		plan["counts"], plan["ekwan_base"], plan["echo_home"],
		plan["settled_ase"], plan["settled_ekwan"]
	)
	flow_ctx.request_save("stage.reward")

	# --- the stage-cadence Storyweight -------------------------------------
	var xp_events := _award_stage_clear_xp(realm_model, stage_index, t)
	if not xp_events.is_empty():
		flow_ctx.request_save("progression.xp")

	# --- stamp --------------------------------------------------------------
	stage_ref["settlement_receipt"] = {
		"version":   RECEIPT_VERSION,
		"result_id": "%s.stage.%d" % [flow_ctx.realm_id, stage_index],
		"settled":   true,
		"outcome":   "cleared",
		"settled_t": t,
	}

	if logger != null:
		logger.info(t, "economy.stage.settled", "Stage settled", {
			"realm_id":      flow_ctx.realm_id,
			"stage_index":   stage_index,
			"base_reward":   base,
			"ase_awarded":   int(payout.get("ase_awarded", 0)),
			"ekwan_awarded": int(payout.get("ekwan_awarded", 0)),
			"xp_events":     xp_events.size(),
		})

	payout["xp_events"] = xp_events
	return payout


# ---------------------------------------------------------------------------
# Preview
# ---------------------------------------------------------------------------

## What `settle()` would pay for the current stage, without paying it. Pure and read-only: no
## RNG, no save write, no log, no receipt. It reads the same `_plan()` and the same
## `EconomyService.stage_payout_rows()` that `settle()` pays from, so the two cannot drift.
## Objectives settled at a return home are not in it (D-105).
## Returns { rows: Array, ase: int, ekwan: int } (rows are Ase only), or {} when the stage
## cannot be located or is already settled.
func preview() -> Dictionary:
	if flow_ctx.realm_id.is_empty() or flow_ctx.stage_id.is_empty():
		return {}
	var realm_model: Dictionary = RealmService.get_active(flow_ctx)
	if realm_model.is_empty():
		return {}
	var stage_index := _stage_index()
	var stage_ref := _stage_ref(realm_model, stage_index)
	if stage_ref.is_empty():
		return {}
	var receipt_v: Variant = stage_ref.get("settlement_receipt", {})
	if receipt_v is Dictionary and bool((receipt_v as Dictionary).get("settled", false)):
		return {}
	var plan := _plan(realm_model, stage_ref, stage_index, null, 0)
	var rows := EconomyService.stage_payout_rows(
		plan["base"], plan["realm_scale"], plan["replay_factor"], plan["counts"],
		plan["ekwan_base"], plan["echo_home"], plan["settled_ase"], plan["settled_ekwan"])
	return { "rows": rows["breakdown"], "ase": rows["ase"], "ekwan": rows["ekwan"] }


## The inputs of the stage payout, shared by `settle()` and `preview()`. Pure apart from the
## unknown-type log inside `RewardCalc.base_reward` (only when `log` is given). The base and Ekwan
## sums skip objectives settled at a return home (D-105); the counts still include them.
func _plan(realm_model: Dictionary, stage_ref: Dictionary, stage_index: int,
		log: StructuredLogger, t: int) -> Dictionary:
	var reward_cfg := ConfigService.get_rewards_cfg(config_service)
	var objectives_v: Variant = stage_ref.get("objectives", [])
	var objectives: Array = objectives_v if objectives_v is Array else []
	var unsettled := RewardCalc.unsettled(objectives)

	return {
		"base":           RewardCalc.base_reward(unsettled, reward_cfg, log, t),
		"realm_scale":    RewardCalc.realm_scale(flow_ctx.realm_id,
			ConfigService.get_realm_order(config_service), reward_cfg, log, t),
		"replay_factor":  RewardCalc.replay_factor(int(realm_model.get("run_count", 0)), reward_cfg, log, t),
		"ekwan_base":     RewardCalc.stage_ekwan(unsettled, reward_cfg, log, t),
		"counts":         RewardCalc.objective_counts(objectives, reward_cfg),
		"echo_home":      _echo_home(realm_model, reward_cfg, log, t),
		"settled_ase":    maxi(0, int(stage_ref.get("settled_ase", 0))),
		"settled_ekwan":  maxi(0, int(stage_ref.get("settled_ekwan", 0))),
	}


## The Echoes stipend input (D-43 to D-45, D-53). Both branches read the stage death record (D-50),
## so the card preview equals the payout after a reload, when no fight context exists.
func _echo_home(realm_model: Dictionary, reward_cfg: Dictionary,
		log: StructuredLogger, t: int) -> Dictionary:
	var tally: Dictionary
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx != null:
		var all_lost := ActiveStageService.lost_echo_names_with(flow_ctx, ectx.actors)
		tally = RewardCalc.echo_tally(ectx.actors, all_lost)
		tally["lost"] = all_lost
	else:
		var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
		var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
		var ids_v: Variant = sanctum.get("active_party_ids", [])
		var ids: Array = ids_v if ids_v is Array else []
		var roster_v: Variant = sanctum.get("roster", [])
		var roster: Array = roster_v if roster_v is Array else []
		var party: Array = []
		for e_v in roster:
			if e_v is Dictionary and ids.has(str((e_v as Dictionary).get("id", ""))):
				party.append({ "faction": "echo", "name": str((e_v as Dictionary).get("name", "")) })
		var stage_lost := ActiveStageService.stage_lost_echo_names(flow_ctx)
		tally = RewardCalc.echo_tally(party, stage_lost)
		tally["lost"] = stage_lost
	var replay := int(realm_model.get("run_count", 0)) > 0
	tally["rate"] = int(RewardCalc.cfg_num(reward_cfg, "echo_home_ase", 0.0, log, t))
	tally["cap"] = int(RewardCalc.cfg_num(reward_cfg,
		"echo_home_cap_replay" if replay else "echo_home_cap", 0.0, log, t))
	tally["replay"] = replay
	return tally


# ---------------------------------------------------------------------------
# Settle on leaving (D-104 to D-106)
# ---------------------------------------------------------------------------

const OUTCOME_NONE := "none"
const OUTCOME_SOME := "some"
const OUTCOME_ALL := "all"
const OUTCOME_NOTHING_NEW := "nothing_new"


## What a return home would settle NOW: the objectives that are completed and not yet settled, at
## the same scale and replay factor as the stage payout. Pure and read-only; no roll, no odds.
## `ase`, `ekwan` = the gathered amount before the roll. `indexes` = the objectives it would mark.
## `nothing_new` = no gathered Ase or Ekwan (so the payer draws no roll).
## Returns { ase, ekwan, overcome, total, indexes, nothing_new, settled_ase, settled_ekwan }.
static func settle_plan(ctx: FlowContext, cfg_service: ConfigService,
		logger: StructuredLogger = null, t: int = 0) -> Dictionary:
	var plan := { "ase": 0, "ekwan": 0, "overcome": 0, "total": 0, "indexes": [],
		"nothing_new": true, "settled_ase": 0, "settled_ekwan": 0 }
	if ctx.realm_id.is_empty() or ctx.stage_id.is_empty():
		return plan
	var stage_ref := _live_stage(ctx)
	if stage_ref.is_empty():
		return plan
	var reward_cfg := ConfigService.get_rewards_cfg(cfg_service)
	var objectives_v: Variant = stage_ref.get("objectives", [])
	var objectives: Array = objectives_v if objectives_v is Array else []
	var counts := RewardCalc.objective_counts(objectives, reward_cfg)
	plan["overcome"] = int(counts.get("overcome", 0))
	plan["total"] = int(counts.get("total", 0))
	plan["settled_ase"] = maxi(0, int(stage_ref.get("settled_ase", 0)))
	plan["settled_ekwan"] = maxi(0, int(stage_ref.get("settled_ekwan", 0)))

	var picked: Array = []
	for i in objectives.size():
		var obj: Dictionary = objectives[i] if objectives[i] is Dictionary else {}
		if bool(obj.get("completed", false)) and not bool(obj.get("settled", false)):
			picked.append(obj)
			(plan["indexes"] as Array).append(i)
	var fx := ActiveStageService.get_payout_factors(ctx, cfg_service, logger, t)
	var k: float = float(fx["realm_scale"]) * float(fx["replay_factor"])
	plan["ase"] = RewardCalc.round_payout(
		float(RewardCalc.base_reward(picked, reward_cfg, logger, t)) * k)
	plan["ekwan"] = RewardCalc.round_payout(
		float(RewardCalc.stage_ekwan(picked, reward_cfg, logger, t)) * k)
	plan["nothing_new"] = int(plan["ase"]) <= 0 and int(plan["ekwan"]) <= 0
	return plan


## The roll table from `data.rewards.carry_odds` and `carry_shares`: [{ outcome, share, pct }] in
## config order, `pct` summing to 100. `retention_mul` (Scout) multiplies the weight of every outcome
## whose share is above 0; the renormalisation keeps every share at or below 100%. Returns [] when
## the config is missing or has no weight, and logs it.
static func carry_table(reward_cfg: Dictionary, retention_mul: float,
		logger: StructuredLogger = null, t: int = 0) -> Array:
	var odds_v: Variant = reward_cfg.get("carry_odds", {})
	var shares_v: Variant = reward_cfg.get("carry_shares", {})
	var odds: Dictionary = odds_v if odds_v is Dictionary else {}
	var shares: Dictionary = shares_v if shares_v is Dictionary else {}
	var rows: Array = []
	var total := 0.0
	for key in [OUTCOME_NONE, OUTCOME_SOME, OUTCOME_ALL]:
		var w := RewardCalc.cfg_num(odds, key, 0.0, logger, t)
		var share := clampf(RewardCalc.cfg_num(shares, key, 0.0, logger, t), 0.0, 1.0)
		if share > 0.0:
			w *= maxf(retention_mul, 0.0)
		w = maxf(w, 0.0)
		rows.append({ "outcome": key, "share": share, "weight": w })
		total += w
	if total <= 0.0:
		return []
	var out: Array = []
	for r in rows:
		out.append({ "outcome": r["outcome"], "share": r["share"], "pct": float(r["weight"]) / total * 100.0 })
	return out


## Settles the completed, unsettled objectives by ONE roll and pays the result through `econ`
## exactly once (D-104 to D-106). What the roll does not pay is lost. The roll stream is
## `stage.settle.<stage_id>.<run_count>.<settle_count>` and is drawn only when there is something new
## to settle, so nothing new draws nothing and changes nothing. The `settled` mark on each objective is
## the re-roll stamp: a cancel, a reload or a retry finds them marked. The caller requests the save and
## calls this only after the escape has succeeded.
## Returns { outcome, ase, ekwan, overcome, total, intel_count }; `outcome` is "none", "some", "all" or
## "nothing_new".
static func settle_leave(ctx: FlowContext, cfg_service: ConfigService, econ_service: EconomyService,
		retention_mul: float, reason: String, logger: StructuredLogger, t: int) -> Dictionary:
	var plan := settle_plan(ctx, cfg_service, logger, t)
	var result := { "outcome": OUTCOME_NOTHING_NEW, "ase": 0, "ekwan": 0,
		"overcome": plan["overcome"], "total": plan["total"],
		"intel_count": ActiveStageService.count_revealed_situations(ctx) }
	if bool(plan["nothing_new"]):
		return result
	var table := carry_table(ConfigService.get_rewards_cfg(cfg_service), retention_mul, logger, t)
	var realm_model: Dictionary = RealmService.get_active(ctx)
	var stage_ref := _live_stage(ctx)
	if table.is_empty() or realm_model.is_empty() or stage_ref.is_empty():
		return result

	var settle_count := maxi(0, int(stage_ref.get("settle_count", 0)))
	var rng := CampaignSeed.get_rng_from(int(realm_model.get("seed", 0)),
		"stage.settle.%s.%d.%d" % [ctx.stage_id, int(realm_model.get("run_count", 0)), settle_count])
	var roll := float(rng.randi_range(0, 99))
	var picked: Dictionary = table[table.size() - 1]
	var cum := 0.0
	for row in table:
		cum += float(row["pct"])
		if roll < cum:
			picked = row
			break

	var share: float = picked["share"]
	var ase := RewardCalc.round_payout(float(plan["ase"]) * share)
	var ekwan := RewardCalc.round_payout(float(plan["ekwan"]) * share)
	if ase > 0:
		econ_service.add_ase(ase, reason, logger, t)
	if ekwan > 0:
		econ_service.add_ekwan(ekwan, reason, logger, t)

	var objectives: Array = stage_ref["objectives"]
	for i in plan["indexes"]:
		(objectives[i] as Dictionary)["settled"] = true
		(objectives[i] as Dictionary)["settled_share"] = roundi(share * 100.0)
	stage_ref["settled_ase"] = int(plan["settled_ase"]) + ase
	stage_ref["settled_ekwan"] = int(plan["settled_ekwan"]) + ekwan
	stage_ref["settle_count"] = settle_count + 1

	result["outcome"] = picked["outcome"]
	result["ase"] = ase
	result["ekwan"] = ekwan
	return result


## The `intel_retention_bonus` of a directive, or 1.0 when it does not retain intel. In the roll it
## multiplies the weights of the outcomes that pay something (`carry_table`), never the amount.
static func retention_mul(directive: Dictionary) -> float:
	if bool(directive.get("intel_retention", false)):
		return float(directive.get("intel_retention_bonus", 1.0))
	return 1.0


## The LIVE stage dict of the active stage, or {}.
static func _live_stage(ctx: FlowContext) -> Dictionary:
	var realm_model: Dictionary = RealmService.get_active(ctx)
	var stages_v: Variant = realm_model.get("stages", [])
	if not (stages_v is Array):
		return {}
	var sid := str(ctx.stage_id)
	var index := int(sid.split(".")[-1]) if sid.contains(".") else 0
	for s_v in (stages_v as Array):
		if s_v is Dictionary and int((s_v as Dictionary).get("index", -1)) == index:
			return s_v
	return {}


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Zero-based index of the stage named by flow_ctx.stage_id ("stage.N", or "realm.x.stage.N").
func _stage_index() -> int:
	var sid := str(flow_ctx.stage_id)
	if sid.contains("."):
		var parts := sid.split(".")
		return int(parts[parts.size() - 1])
	return 0


## The LIVE stage dict inside save_data (not a copy) — writing settlement_receipt onto the
## return value must persist. Matched on the stage's own `index` field, the same way
## FlowEncounterState resolved stage objectives before this moved.
func _stage_ref(realm_model: Dictionary, stage_index: int) -> Dictionary:
	var stages_v: Variant = realm_model.get("stages", [])
	if not (stages_v is Array):
		return {}
	for s_v in (stages_v as Array):
		if s_v is Dictionary and int((s_v as Dictionary).get("index", -1)) == stage_index:
			return s_v
	return {}


## Stage-clear Storyweight, moved verbatim from FlowEncounterState.build_final_snapshot().
##
## `skip_kill_xp` stays TRUE, which is what already split this award by cadence before Phase 8
## touched it: kill Storyweight is applied per kill, mid-combat, at the ENCOUNTER cadence, and
## this call has therefore only ever paid `xp_stage_clear_base` (+ the realm-completion bonus on
## the final stage) — both stage-cadence. No new flag was needed; the existing one had already
## drawn the line the split needed.
##
## `victory` is passed true: reaching here means the stage was cleared. On the no-encounter path
## that is the D05 repair — the party completed the stage's objectives without a fight and is
## paid for it.
func _award_stage_clear_xp(realm_model: Dictionary, stage_index: int, t: int) -> Array:
	var prog_cfg: Dictionary = {}
	var birth_stats: Dictionary = {}
	if config_service != null:
		var bal: Dictionary = config_service.get_balance()
		var bd_v: Variant = bal.get("data", {})
		var bd: Dictionary = bd_v if bd_v is Dictionary else {}
		var pc_v: Variant = bd.get("progression", {})
		prog_cfg = pc_v if pc_v is Dictionary else {}
		var sm_v: Variant = bd.get("summoning", {})
		var sm: Dictionary = sm_v if sm_v is Dictionary else {}
		var bs_v: Variant = sm.get("birth_stats", {})
		birth_stats = bs_v if bs_v is Dictionary else {}

	# PROG-004: mark survived=false for any echo KO'd during the encounter — the faith virtue
	# multiplier reads it. Moved with the award it feeds; no-op with no encounter context.
	var echo_logs: Dictionary = {}
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx != null:
		echo_logs = ectx.echo_action_logs
		for actor_v in ectx.actors:
			if not (actor_v is Dictionary):
				continue
			if str((actor_v as Dictionary).get("faction", "")) != "echo":
				continue
			var eid := str((actor_v as Dictionary).get("id", ""))
			if echo_logs.has(eid):
				if bool((actor_v as Dictionary).get("is_dead", false)):
					echo_logs[eid]["survived"] = false
				elif not echo_logs[eid].has("survived"):
					echo_logs[eid]["survived"] = true

	# Realm completion: is this the final stage? Read BEFORE advance_stage runs.
	var stage_count := int(realm_model.get("stage_count", 1))
	var realm_complete_now := stage_index >= stage_count - 1

	# XP tuning: realm XP multiplier from campaign position (run_index).
	var realm_xp_mult := ProgressionService.get_realm_xp_multiplier(
		flow_ctx.realm_id, flow_ctx.save_data, prog_cfg
	)

	return ProgressionService.award_post_combat_xp(
		flow_ctx.save_data,
		echo_logs,
		true,
		realm_complete_now,
		prog_cfg,
		birth_stats,
		logger,
		t,
		realm_xp_mult,
		true
	)

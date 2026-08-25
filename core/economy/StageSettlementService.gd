# res://core/economy/StageSettlementService.gd
# V2-INFRA-003 Phase 8 — the STAGE-CADENCE settlement (defects D05 / D36 / D77).
#
# WHY THIS FILE EXISTS
# --------------------
# `FlowEncounterState.build_final_snapshot()` used to pay the whole reward at every combat end:
# the stage's summed objective weights, the stage's realm-virtue bonus, and the stage-clear
# Storyweight. Three stage-cadence payouts, fired once per ENCOUNTER, inside a snapshot builder,
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
# WHAT IS NOT SETTLED HERE, deliberately: the enemies-defeated bonus, the echoes-survived bonus,
# the speed bonus and per-kill Storyweight. Those measure one FIGHT and are paid at the fight,
# by `EconomyService.reward_encounter_complete()` and by the mid-combat kill-XP path. See the
# split writeup at the top of EconomyService.gd's Stage Reward API section.

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

	var reward_cfg := ConfigService.get_rewards_cfg(config_service)

	# --- the stage-cadence Ase/Ekwan ---------------------------------------
	var objectives_v: Variant = stage_ref.get("objectives", [])
	var objectives: Array = objectives_v if objectives_v is Array else []
	var base := RewardCalc.base_reward(objectives, reward_cfg)
	var redo_mul := RewardCalc.redo_multiplier(int(realm_model.get("run_count", 0)), reward_cfg)

	# REALM-005: virtue-based stage bonus. Same call, same inputs, same log line the encounter
	# path made — it has only moved to the dispatch that actually completes the stage.
	var realm_virtue := str(realm_model.get("virtue", ""))
	var run_index    := int(realm_model.get("run_index", 0))
	var stage_reward_data: Dictionary = RealmService.calculate_stage_reward(
		stage_index, realm_virtue, run_index, reward_cfg
	)
	var virtue_bonus := int(stage_reward_data.get("virtue_bonus", 0))
	var formula_inputs: Dictionary = stage_reward_data.get("formula_inputs", {})
	if logger != null:
		logger.info(t, "economy.stage.reward", "Stage reward formula", formula_inputs)

	# V2-ECONOMY-001: ekwan_factor from the first stage objective type.
	# CARRIED VERBATIM, INCLUDING ITS BUG. The read is `objectives[0].obj_type`, and
	# ObjectiveModel.make() writes `type`, never `obj_type` — so `_obj_type` is always the
	# "combat" default and `ekwan_shrine_multiplier` has never applied. Register entry D83.
	# Fixing it here would move Ekwan on shrine stages in the same re-record as the settlement
	# split and make neither attributable. Recorded, not fixed.
	var obj_type := "combat"
	if not objectives.is_empty() and objectives[0] is Dictionary:
		obj_type = str((objectives[0] as Dictionary).get("obj_type", "combat"))
	var ekwan_factor := float(reward_cfg.get("ekwan_base_factor", 0.12))
	if obj_type == "shrine":
		ekwan_factor *= float(reward_cfg.get("ekwan_shrine_multiplier", 1.5))

	var payout: Dictionary = econ.settle_stage_complete(
		base, redo_mul, virtue_bonus, ekwan_factor, logger, t
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
			"virtue_bonus":  virtue_bonus,
			"ase_awarded":   int(payout.get("ase_awarded", 0)),
			"ekwan_awarded": int(payout.get("ekwan_awarded", 0)),
			"xp_events":     xp_events.size(),
		})

	payout["xp_events"] = xp_events
	return payout


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

	# XP tuning: realm XP multiplier from campaign position (run_index). Formula carried
	# verbatim; see register D33 — it duplicates ProgressionService.get_realm_xp_multiplier(),
	# which slice 6J measured as unable to differ. Collapsing them is a separate change.
	var realm_xp_mult := 1.0
	var mult_rate := float(prog_cfg.get("realm_xp_multiplier_per_realm", 0.0))
	if mult_rate > 0.0:
		realm_xp_mult = 1.0 + float(int(realm_model.get("run_index", 0))) * mult_rate

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

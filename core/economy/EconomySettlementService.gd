# res://core/economy/EconomySettlementService.gd
# V2-INFRA-003 Phase 4 Slice 7: flow-level economy settle orchestration extracted out of
# FlowRuntime.gd, following the EmotionConsequenceService/VowConsequenceService extraction
# pattern (see core/runtime/controllers/WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly — requests saves via flow_ctx.request_save(reason),
#     the same choke point FlowRuntime._mark_save_requested() itself calls.
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot. settle() mutates
#     flow_ctx.save_data (economy / institutions / emotion) and returns; the caller decides
#     whether/how to refresh the snapshot.
#
# WHY A SIBLING OF EconomyAccrualService, NOT AN EXTENSION OF IT: EconomyAccrualService's own
# header says what it is — "Pure math utilities for Ase accrual. No OS time calls. No logging.
# No save mutation." settle() below does all three (reads now_unix off the action dict, logs
# via StructuredLogger, mutates flow_ctx.save_data and calls flow_ctx.request_save()). Adding
# that here would break EconomyAccrualService's own invariant, the same reasoning core/AGENTS.md
# gives for never adding a ConfigService read to EmotionService/SocialGraphService/
# MaturityExpressionService. This file is placed beside EconomyAccrualService.gd instead — a
# service wrapping a domain class lives beside that class (VowConsequenceService next to
# VowService, NarrativeVoiceService next to ShoutBank) — and calls
# EconomyAccrualService.compute_online_settle_gain() as a plain static call, same as
# FlowRuntime did before this move.
#
# Moved verbatim (behaviour unchanged) from FlowRuntime.gd: _handle_economy_settle_time → settle.
# The only behaviour NOT preserved 1:1 is the unconditional flow_machine.refresh_snapshot() call
# at the old function's end — that call is structurally impossible here (no flow_machine
# reference, per RULES) and is now the caller's responsibility. See each call site:
#   - EconomySettlementController.handle_settle_time() returns
#     FlowActionOutcome.snapshot_outcome(flow_ctx.last_snapshot) — the established
#     "refresh without rebuilding" translation DebugController's header documents.
#   - FlowRuntime._handle_sanctum_summon() / _handle_sanctum_unlock_skill() already end with
#     their own explicit flow_machine.refresh_snapshot() call after settle() returns, which
#     covers the same requirement (refresh_snapshot() is idempotent — re-running it against an
#     already-current ctx.last_snapshot changes nothing — and neither handler reads
#     flow_ctx.last_snapshot between the settle-time call and its own final rebuild, confirmed
#     by reading both bodies). No behaviour is lost; one redundant mid-handler refresh is.
#
# THREE SETTLEMENTS, THREE CLOCKS (Phase 1 architecture review, verified against this body):
#   1. Ase accrual — EconomyAccrualService.compute_online_settle_gain() + econ.add_ase() twice
#      (normal gain, then the KeeperIntroService Ase-flame boost). Clock: last_settle_unix.
#   2. Emotion recovery — EmotionConsequenceService.apply_emotion_recovery_if_needed(), which
#      already owns its own last_emotion_settle_unix double-settle guard. Just called here.
#   3. Institution tick — InstitutionService.run_settle_tick() (update_condition +
#      apply_institution_modifiers + apply_passive_effects, including the Training Grounds
#      Storyweight grant). No clock of its own; driven off this settle's now_unix/hours_elapsed.
# Call order (Ase, then emotion, then institutions) is preserved exactly — later steps read
# state the earlier ones write (see the header rule this story was built to satisfy).
#
# CONFIG GETTERS RELOCATED (same "true owner" reasoning as EmotionConsequenceService's own
# relocations): _get_balance_economy_cfg (data.economy) was used by both this settle path and
# FlowRuntime._apply_offline_accrual_if_needed (an unrelated function, still on FlowRuntime at
# the time of this slice and out of its scope; the Half A review correction C1 has since moved
# it to OfflineAccrualService.apply_if_needed, the sibling file beside this one) — moved to
# ConfigService.get_economy_cfg(), not duplicated or
# left as a delegating shim. _is_ase_flame_awakened (reads save_data.sanctum.ase_flame.awakened)
# was used by the same two callers — moved to KeeperIntroService.is_ase_flame_awakened(), the
# file that already owns every other ase_flame read/write. Both callers now call the same
# relocated function. _get_max_online_settle_delta_seconds had exactly one caller (this settle
# path) and moved here whole, unchanged, as a private helper.

class_name EconomySettlementService
extends RefCounted

var flow_ctx: FlowContext
var config_service: ConfigService
var econ: EconomyService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _econ: EconomyService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	econ = _econ
	logger = _logger


## economy.settle_time (all three call shapes: the dispatched action, the settle-before-spend
## pre-step on economy.ase.spend, and the settle-before-afford-check pre-step on
## sanctum.summon / sanctum.unlock_skill). Moved verbatim from
## FlowRuntime._handle_economy_settle_time — see this file's header for what changed (nothing,
## except the trailing refresh_snapshot() call, which callers now handle themselves).
func settle(action: Dictionary, t: int) -> void:
	var now_unix := int(action.get("now_unix", 0))
	var source := str(action.get("source", ""))

	if now_unix <= 0:
		logger.info(t, "economy.time_anomaly", "Denied settle (invalid now_unix)", {
			"now_unix": now_unix,
			"source": source
		})
		return

	# Ensure economy dict exists
	if not flow_ctx.save_data.has("economy") or not (flow_ctx.save_data["economy"] is Dictionary):
		logger.info(t, "economy.settle.denied", "No economy data in save", {
			"source": source
		})
		return

	var econ_data := flow_ctx.save_data["economy"] as Dictionary
	var last_settle := int(econ_data.get("last_settle_unix", now_unix))

	var raw_delta := now_unix - last_settle
	var delta_seconds := raw_delta

	# Clamp policy (MVP)
	var clamped_negative := false
	var clamped_cap := false

	if delta_seconds < 0:
		delta_seconds = 0
		clamped_negative = true

	var max_delta_seconds := _max_online_settle_delta_seconds()
	if delta_seconds > max_delta_seconds:
		delta_seconds = max_delta_seconds
		clamped_cap = true

	var note := ""
	if clamped_cap:
		note = "delta clamped to cap (likely boot catch-up; not offline accrual)"
	elif clamped_negative:
		note = "negative delta clamped to 0"

	# Read balance knobs
	var econ_cfg := ConfigService.get_economy_cfg(config_service)
	var ase_per_min := float(econ_cfg.get("ase_online_per_min_base", 0.0))
	if not KeeperIntroService.is_ase_flame_awakened(flow_ctx.save_data):
		ase_per_min = 0.0
	var rate_per_sec := ase_per_min / 60.0

	# Multiplier seam (Faith later) - optional input, default 1.0
	var multiplier := float(action.get("multiplier", 1.0))

	# Compute gain
	var gain := EconomyAccrualService.compute_online_settle_gain(delta_seconds, rate_per_sec, multiplier)

	var settle_reason := "economy.settle_time.normal"
	if clamped_cap:
		settle_reason = "economy.settle_time.catch_up"
	elif clamped_negative:
		settle_reason = "economy.settle_time.anomaly"

	# Apply via EconomyService (keep logging cnetralized there)
	if gain > 0:
		# Replace this call with your EconomyService signature if different.
		econ.add_ase(gain, settle_reason, logger, t)
	var boost_gain: int = KeeperIntroService.apply_ase_boost_from_save(flow_ctx.save_data, config_service.get_balance(), delta_seconds)
	if boost_gain > 0:
		econ.add_ase(boost_gain, "keeper_intro.ase_flame_boost", logger, t)

	# Update settle guard even if gain=0 (prevents re-settling same window)
	econ_data["last_settle_unix"] = now_unix

	# Structured settle log (Core truth)
	var settle_msg := "Ase settled"
	if clamped_cap:
		settle_msg = "Ase settled (clamped)"
	elif clamped_negative:
		settle_msg = "Ase settled (time anomaly)"

	logger.debug(t, "economy.settle", settle_msg, {
		"source": source,
		"now_unix": now_unix,
		"last_settle_unix_before": last_settle,
		"raw_delta_seconds": raw_delta,
		"delta_seconds_used": delta_seconds,
		"clamped_negative": clamped_negative,
		"clamped_cap": clamped_cap,
		"cap_seconds": max_delta_seconds,
		"note": note,
		"ase_per_min_base": ase_per_min,
		"multiplier": multiplier,
		"gain": gain + boost_gain,
		"base_gain": gain,
		"boost_gain": boost_gain,
		"ase_after": int(econ_data.get("ase", 0)),
	})

	# V2-SANCTUM-001: piggyback emotion recovery on the bank timer settle
	EmotionConsequenceService.new(flow_ctx, config_service, logger).apply_emotion_recovery_if_needed(now_unix, t)

	# V2-SANCTUM-002: update institution conditions + apply bank-tick modifiers + passive effects
	var _inst_cfg_b := ConfigService.get_institutions_cfg(config_service)
	var _bldg_cfg_b := ConfigService.get_buildings_cfg(config_service)
	var _hours_elapsed := float(delta_seconds) / 3600.0
	InstitutionService.run_settle_tick(flow_ctx.save_data, _inst_cfg_b, _bldg_cfg_b, now_unix, _hours_elapsed, logger, t)

	# V2-INFRA-003: this handler mutates flow_ctx.save_data (economy, institutions, emotion)
	# but never requested a save — confirmed defect, approved fix. Ase/settle progress made
	# here was previously lost on crash/quit before the next save-worthy action fired.
	flow_ctx.request_save("economy.settle_time")


## Online settle guard. Offline accrual has its own capped window (see
## OfflineAccrualService.apply_if_needed's own cap logic — a different, dynamic cap).
## Moved verbatim from FlowRuntime._get_max_online_settle_delta_seconds — single caller
## (this settle path), so it moved here whole rather than to a shared owner.
func _max_online_settle_delta_seconds() -> int:
	return 3600 # 1 hour

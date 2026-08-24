# res://core/economy/OfflineAccrualService.gd
# V2-INFRA-003 Half A review correction C1: the offline-accrual block extracted out of
# FlowRuntime.gd (_apply_offline_accrual_if_needed + _build_offline_retention_context +
# _build_offline_return_notification, ~258 lines — 14% of the file it left). It was the
# largest block of pure domain logic still sitting in a file whose stated end state is
# "a composition and transaction shell", and it wrote player-facing prose, which is the
# least shell-like thing a runtime can do.
#
# There was never a structural blocker: it holds no flow_machine, calls no controller, and
# has exactly one production caller (the "flow.continue" arm of FlowRuntime.dispatch()).
# EconomySettlementService.gd's own header named it twice as "an unrelated, still-on-
# FlowRuntime function" — i.e. the move was seen and skipped, not judged impossible.
#
# CONTRACT (identical to EconomySettlementService's, which this file sits beside):
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly — requests saves via flow_ctx.request_save(reason),
#     the same choke point FlowRuntime._mark_save_requested() itself delegates to. Both
#     save requests below fire from inside the "flow.continue" dispatch arm, so their
#     reasons join that dispatch's own pipe-joined save_request_reason exactly as before;
#     nothing here is queued outside a dispatch boundary.
#   - No flow_machine reference — this class cannot transition state or rebuild a snapshot.
#     It mutates flow_ctx.save_data (economy) plus flow_ctx.pending_return_notification and
#     returns the gain; the caller decides what to do next. The old function did no more.
#   - Uses OS time (Time.get_unix_time_from_system()). That is legal here for the same
#     reason it was legal on FlowRuntime: offline accrual is defined against wall-clock
#     absence, not the sim tick. It is NOT an RNG source and touches no CampaignSeed path.
#
# WHY A SIBLING OF EconomySettlementService, NOT A METHOD ON IT. The obvious home is the
# service the review named first. It is the wrong one, for the reason that file gives for
# its own placement:
#   - EconomySettlementService is documented as "THREE SETTLEMENTS, THREE CLOCKS" — Ase
#     accrual, emotion recovery, institution tick — all driven off ONE clock,
#     last_settle_unix, on the online bank timer. Offline accrual runs off a DIFFERENT
#     clock (last_offline_unix), on a different trigger (once per session, on entering
#     from flow.continue — never on boot, splash or menu), against a different, dynamic
#     cap. Folding it in would mean rewriting that header's central claim to accommodate a
#     fourth path that shares none of its three.
#   - It also produces something no settlement produces: a player-facing return
#     notification with authored copy. That is a retention concern riding on an economy
#     computation, and it deserves a file a reader can find by name.
# The two files sit beside each other, both beside EconomyAccrualService (the pure maths
# both call), which is the same "a service wrapping a domain class lives beside that class"
# placement rule EconomySettlementService cites for itself.
#
# CONFIG. Reads data.economy through ConfigService.get_economy_cfg() — the shared getter
# Phase 4 Slice 7 created precisely because this function and settle() both needed it. The
# ase_flame gate goes through KeeperIntroService.is_ase_flame_awakened(), same shared owner.
# No config key, default or clamp was touched by this move.
#
# MOVED VERBATIM. Behaviour is unchanged, bodies included. The only edits are mechanical:
# _apply_offline_accrual_if_needed → apply_if_needed, the two private builders lost their
# now-redundant "offline_" infix, _mark_save_requested(x) → flow_ctx.request_save(x) (the
# same single implementation), and KeeperIntroServiceScript → KeeperIntroService (the
# preload const was a FlowRuntime-local alias for the same script).
#
# NO SHIM WAS LEFT. FlowRuntime has no forwarder for any of the three. Its one production
# call site now constructs this service; tests/EconomyTests.gd's five
# runtime.call("_apply_offline_accrual_if_needed", …) reflection sites were rewritten to
# construct it too, in this same change (AGENTS.md mistakes 19 and 20).
#
# KNOWN DEFECT, NOT FIXED HERE (register D81, found at this site during the C1 move): the
# "house dormant" gate is evaluated TWICE, and the second evaluation is unreachable. The
# inline gate near the top reads save_data.sanctum.ase_flame.awakened and returns 0; the
# later KeeperIntroService.is_ase_flame_awakened() check reads the same key by the same
# rule, so it can only be reached when the first already passed. The two are not
# equivalent in effect — the first returns without touching the clocks, the dead one rolls
# last_offline_unix / last_settle_unix forward and requests an "economy.offline_guard"
# save — which is why deleting it is a behaviour question, not a tidy-up. Moved verbatim,
# both branches intact. See the defect register.

class_name OfflineAccrualService
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


## flow.continue's once-per-session offline catch-up. Returns the Ase gain (0 when gated,
## when no time elapsed, or when time went backwards). Moved verbatim from
## FlowRuntime._apply_offline_accrual_if_needed — see this file's header for the mechanical
## edits, which are the only changes.
func apply_if_needed(t: int, source: String) -> int:
	# Offline accrual must only happen when the player enters the session (flow.continue),
	# not on boot/splash/menu. Uses OS time only here.
	var now_unix := int(Time.get_unix_time_from_system())

	# Ensure economy dict exists
	if not flow_ctx.save_data.has("economy") or not (flow_ctx.save_data["economy"] is Dictionary):
		flow_ctx.save_data["economy"] = {}
	var econ_data := flow_ctx.save_data["economy"] as Dictionary

	# V2-ECONOMY-001: gate on ase_flame.awakened — house is dormant before onboarding completes
	var _sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var _sanctum_gate: Dictionary = _sanctum_v if _sanctum_v is Dictionary else {}
	var _flame_v: Variant = _sanctum_gate.get("ase_flame", {})
	var _flame_gate: Dictionary = _flame_v if _flame_v is Dictionary else {}
	if not bool(_flame_gate.get("awakened", false)):
		logger.debug(t, "economy.offline.noop", "Offline accrual skipped (house dormant)", { "source": source })
		return 0

	var last_offline := int(econ_data.get("last_offline_unix", now_unix))
	var raw_delta := now_unix - last_offline

	# Nothing to do (or suspicious backwards time)
	if raw_delta <= 0:
		if raw_delta < 0:
			logger.info(t, "economy.time_anomaly", "Offline accrual denied (time went backwards)", {
				"source": source,
				"now_unix": now_unix,
				"last_offline_unix": last_offline,
				"raw_delta_seconds": raw_delta
			})
		else:
			logger.debug(t, "economy.offline.skip", "Offline accrual skipped (no elapsed time)", {
				"source": source,
				"now_unix": now_unix,
				"last_offline_unix": last_offline,
				"raw_delta_seconds": raw_delta
			})
		return 0

	# Read balance knobs
	var econ_cfg := ConfigService.get_economy_cfg(config_service)
	if not KeeperIntroService.is_ase_flame_awakened(flow_ctx.save_data):
		logger.debug(t, "economy.offline.skip", "Offline accrual skipped (Ase Flame dormant)", {
			"source": source,
			"now_unix": now_unix,
			"last_offline_unix": last_offline,
			"raw_delta_seconds": raw_delta
		})
		econ_data["last_offline_unix"] = now_unix
		econ_data["last_settle_unix"] = now_unix
		flow_ctx.request_save("economy.offline_guard")
		return 0

	var ase_per_min := float(econ_cfg.get("ase_online_per_min_base", 0.0))
	var rate_per_sec := ase_per_min / 60.0
	var offline_start_factor := float(econ_cfg.get("offline_start_factor", 0.06))
	var base_offline_cap_seconds := int(econ_cfg.get("offline_cap_seconds", 151200))
	var continuity_cap_bonus_seconds := int(econ_cfg.get("offline_continuity_cap_bonus_seconds", 14400))
	var stability_cap_bonus_seconds := int(econ_cfg.get("offline_stability_cap_bonus_seconds", 7200))
	var stability_cap_penalty_seconds := int(econ_cfg.get("offline_stability_cap_penalty_seconds", 43200))
	var continuity_multiplier_bonus := float(econ_cfg.get("offline_continuity_multiplier_bonus", 0.25))
	var stability_multiplier_bonus := float(econ_cfg.get("offline_stability_multiplier_bonus", 0.15))
	var stability_multiplier_penalty := float(econ_cfg.get("offline_stability_multiplier_penalty", 0.45))
	var min_multiplier := float(econ_cfg.get("offline_min_multiplier", 0.05))
	var max_multiplier := float(econ_cfg.get("offline_max_multiplier", 1.2))
	var min_cap_seconds := int(econ_cfg.get("offline_min_cap_seconds", 108000))
	var max_cap_seconds := int(econ_cfg.get("offline_max_cap_seconds", 172800))

	var retention_ctx := _build_retention_context()
	var continuity_norm := float(retention_ctx.get("continuity_norm", 0.0))
	var stability_score := float(retention_ctx.get("stability_score", 0.0))
	var continuity_bonus := continuity_norm * continuity_multiplier_bonus
	var stability_multiplier_delta := stability_score * (stability_multiplier_bonus if stability_score >= 0.0 else stability_multiplier_penalty)
	var multiplier := clampf(0.8 + continuity_bonus + stability_multiplier_delta, min_multiplier, max_multiplier)
	var cap_adjust := roundi(continuity_norm * float(continuity_cap_bonus_seconds))
	if stability_score >= 0.0:
		cap_adjust += roundi(stability_score * float(stability_cap_bonus_seconds))
	else:
		cap_adjust -= roundi(absf(stability_score) * float(stability_cap_penalty_seconds))
	var offline_cap_seconds := clampi(base_offline_cap_seconds + cap_adjust, min_cap_seconds, max_cap_seconds)

	# Clamp elapsed to the dynamic taper window. Time beyond the window carries no further charge.
	var delta_seconds := raw_delta
	var clamped_cap := false
	if offline_cap_seconds > 0 and delta_seconds > offline_cap_seconds:
		delta_seconds = offline_cap_seconds
		clamped_cap = true

	# V2-ECONOMY-001: boost stub — no-op now, extensibility hook for future bank-tick boost system
	var _boost := float(_flame_gate.get("boost_per_bank_tick", 0.0))
	multiplier += _boost


	var ase_before := int(econ_data.get("ase", 0))

	var gain := EconomyAccrualService.compute_offline_gain(
		delta_seconds,
		rate_per_sec,
		multiplier,
		offline_start_factor,
		offline_cap_seconds
	)

	# Apply via EconomyService (centralizes ledger logs)
	if gain > 0:
		econ.add_ase(gain, "economy.offline_accrual", logger, t)
		logger.debug(t, "economy.offline.apply", "Offline accrual applied", {
			"source": source,
			"now_unix": now_unix,
			"last_offline_unix_before": last_offline,
			"raw_delta_seconds": raw_delta,
			"delta_seconds_used": delta_seconds,
			"clamped_cap": clamped_cap,
			"offline_start_factor": offline_start_factor,
			"offline_cap_seconds": offline_cap_seconds,
			"ase_per_min_base": ase_per_min,
			"multiplier": multiplier,
			"continuity_norm": continuity_norm,
			"stability_score": stability_score,
			"gain": gain,
			"ase_before": ase_before,
			"ase_after": int(econ_data.get("ase", 0)),
		})
	else:
		logger.debug(t, "economy.offline.noop", "Offline accrual no-op", {
			"source": source,
			"now_unix": now_unix,
			"last_offline_unix_before": last_offline,
			"raw_delta_seconds": raw_delta,
			"delta_seconds_used": delta_seconds,
			"clamped_cap": clamped_cap,
			"offline_start_factor": offline_start_factor,
			"offline_cap_seconds": offline_cap_seconds,
			"ase_per_min_base": ase_per_min,
			"multiplier": multiplier,
			"continuity_norm": continuity_norm,
			"stability_score": stability_score,
			"gain": gain,
		})

	if gain > 0 or bool(retention_ctx.get("severe_disorder", false)):
		flow_ctx.pending_return_notification = _build_return_notification(
			gain,
			retention_ctx,
			raw_delta,
			multiplier,
			now_unix
		)

	# Update guards ONLY here (so we don't re-award next launch)
	econ_data["last_offline_unix"] = now_unix

	# Also reset last_settle_unix so online settle doesn't mint a "catch-up" window after continue
	econ_data["last_settle_unix"] = now_unix

	# Persist via Flow boundary save policy (sanctioned boundary)
	flow_ctx.request_save("economy.offline_accrual")
	
	return gain

func _build_retention_context() -> Dictionary:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var continuity_raw := clampi(int(sanctum.get("continuity", 0)), 0, 100)
	var continuity_norm := clampf(float(continuity_raw) / 100.0, 0.0, 1.0)

	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	var morale_total := 0.0
	var fear_total := 0.0
	var counted := 0
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var emo_v: Variant = echo.get("emotion", {})
		var emo: Dictionary = emo_v if emo_v is Dictionary else {}
		morale_total += float(int(emo.get("morale_current", 50)))
		fear_total += float(int(emo.get("fear_current", 0)))
		counted += 1

	var avg_morale := 50.0
	var avg_fear := 0.0
	if counted > 0:
		avg_morale = morale_total / float(counted)
		avg_fear = fear_total / float(counted)

	var morale_score := clampf((avg_morale - 50.0) / 50.0, -1.0, 1.0)
	var fear_score := clampf((avg_fear - 20.0) / 80.0, -1.0, 1.0)
	var emotion_score := clampf((morale_score * 0.7) - (fear_score * 0.85), -1.0, 1.0)

	var vow_v: Variant = sanctum.get("active_vow", {})
	var active_vow: Dictionary = vow_v if vow_v is Dictionary else {}
	var vow_score := 0.0
	var violation_streak := 0
	if not active_vow.is_empty():
		var streak_keys := [
			"consecutive_small_deployments",
			"consecutive_same_calling_deployments",
			"consecutive_blind_engagements",
		]
		for key: String in streak_keys:
			violation_streak = maxi(violation_streak, int(active_vow.get(key, 0)))
		if violation_streak <= 0:
			vow_score = 0.08
		elif violation_streak == 1:
			vow_score = -0.18
		else:
			vow_score = -0.55

	var stability_score := clampf(emotion_score + vow_score, -1.0, 1.0)
	var severe_disorder := violation_streak >= 2 or avg_morale <= 35.0 or avg_fear >= 70.0 or stability_score <= -0.65
	return {
		"continuity_norm": continuity_norm,
		"avg_morale": avg_morale,
		"avg_fear": avg_fear,
		"stability_score": stability_score,
		"violation_streak": violation_streak,
		"severe_disorder": severe_disorder,
	}

func _build_return_notification(
	gain: int,
	retention_ctx: Dictionary,
	raw_delta_seconds: int,
	retention_multiplier: float,
	now_unix: int
) -> Dictionary:
	var severe_disorder := bool(retention_ctx.get("severe_disorder", false))
	var stability_score := float(retention_ctx.get("stability_score", 0.0))
	var title := "The Flame Held"
	var body := "A little charge remained in your absence."
	var tone := "neutral"
	if severe_disorder and gain <= 0:
		title = "The Flame Faltered"
		body = "The Sanctum could not hold much charge in your absence."
		tone = "negative"
	elif gain <= 3 or stability_score < -0.15 or retention_multiplier < 0.8:
		title = "The Flame Guttered"
		body = "Only a little charge remained while you were away."
		tone = "warning"
	elif gain >= 12 or stability_score > 0.25 or retention_multiplier >= 1.0:
		title = "The Flame Held Steady"
		body = "The Sanctum kept a faithful charge in your absence."
		tone = "positive"
	var amount := ("+%d Ase retained" % gain) if gain > 0 else "No charge was retained"
	return {
		"id":               "offline.%d.%d" % [now_unix, raw_delta_seconds],
		"title":            title,
		"body":             body,
		"detail":           "",
		"amount":           amount,
		"tone":             tone,
		"auto_dismiss":     true,
		"blocking_overlay": true,
		"duration_seconds": 4.2,
	}

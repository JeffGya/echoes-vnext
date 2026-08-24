# res://core/emotion/EmotionConsequenceService.gd
# V2-INFRA-003 Phase 4 Slice 4: flow-level emotion consequence orchestration extracted out of
# FlowRuntime.gd, following the WeaveController/VowConsequenceService extraction pattern (see
# core/runtime/controllers/WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly — requests saves via flow_ctx.request_save(reason),
#     the same choke point FlowRuntime._mark_save_requested() itself calls.
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot.
#
# THIS IS A SERVICE, NOT A CONTROLLER. These methods are consequence hooks called from several
# unrelated call sites — flow.continue, flow.go_state→SANCTUM (defeat path), stage-complete,
# encounter.complete, keeper-intro completion, retreat, contact resolution (charge/claimant),
# and the economy settle-time tick. Putting them on a controller would force those domains'
# controllers to call into this one — and controller-to-controller calls are forbidden. A
# service has no such restriction: anyone may call it.
#
# EmotionService remains the single choke point for emotion mutation outside the documented
# mid-combat direct-write exception — every method here still routes morale/fear writes through
# EmotionService.apply_morale_delta()/apply_fear_delta() or EmotionRecoveryService.set_modifier(),
# exactly as the private FlowRuntime methods did. Behaviour, deltas, order and log events are
# unchanged; only ownership moved.
#
# Moved verbatim (behaviour unchanged) from FlowRuntime.gd:
#   _apply_sanctum_emotion_tick        → apply_sanctum_emotion_tick
#   _apply_emotion_recovery_if_needed  → apply_emotion_recovery_if_needed
#   _apply_run_emotion_modifiers       → apply_run_emotion_modifiers
#   _apply_encounter_emotion_drift     → apply_encounter_emotion_drift
#   _apply_morale_to_party             → apply_morale_to_party
#   _get_fear_threshold                → _get_fear_threshold (private helper — only ever called
#                                          internally, by apply_emotion_recovery_if_needed)
#
# CONFIG GETTERS — corrected from the story brief: _get_emotion_recovery_cfg was listed as a
# 7th method to move here, but it is a plain "read a named subtree of balance.json"
# (data.emotion.recovery) — the same shape as ConfigService.get_emotion_drift_cfg
# (data.emotion.drift, its sibling). Per the established config-getter rule it now lives on
# ConfigService as get_emotion_recovery_cfg(config_service) instead, alongside
# get_emotion_drift_cfg/get_continuity_cfg/get_bond_thresholds_cfg. Not duplicated here.
#
# apply_run_emotion_modifiers also called two FlowRuntime-private config getters that were not
# in the story's method list — _get_institutions_cfg / _get_buildings_cfg (institution/building
# morale-fear-recovery multiplier composition, V2-SANCTUM-002). Both are plain balance.json
# subtree reads still needed by FlowRuntime's own institution handlers, so — same "true owner"
# reasoning as the getters above, not a duplication — they moved to ConfigService as
# get_institutions_cfg / get_buildings_cfg rather than being copied onto this service or left
# stranded as FlowRuntime-only private helpers.

class_name EmotionConsequenceService
extends RefCounted

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


# EMOTION-002/003: applies combat win/loss morale+fear deltas + fear_base mutation + morale
# streak tracking. Called from "encounter.complete" and _apply_victory_return_to_explore /
# _handle_complete_stage (before encounter_ctx is nulled).
func apply_encounter_emotion_drift(outcome: String, t: int) -> void:
	var drift := ConfigService.get_emotion_drift_cfg(config_service)
	var fear_threshold        := int(drift.get("fear_threshold",            80))
	var fear_base_per_win     := int(drift.get("fear_base_per_win",          1))
	var fear_base_per_loss    := int(drift.get("fear_base_per_loss",         1))
	var fear_base_max         := int(drift.get("fear_base_max",             40))
	var streak_threshold      := int(drift.get("morale_base_streak_threshold", 3))
	var morale_base_delta     := int(drift.get("morale_base_delta",          1))
	var morale_base_max       := int(drift.get("morale_base_max",           90))
	var morale_base_min       := int(drift.get("morale_base_min",           10))
	var roster_v: Variant = flow_ctx.save_data.get("sanctum", {}).get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	for echo_v in roster:
		if not echo_v is Dictionary:
			continue
		# Morale + fear current deltas (unchanged from EMOTION-002)
		if outcome == "win":
			EmotionService.apply_morale_delta(echo_v, int(drift.get("combat_exit_win_morale",   10)), "combat_exit_win",  logger, t)
			EmotionService.apply_fear_delta(  echo_v, int(drift.get("combat_exit_win_fear",      -5)), "combat_exit_win",  fear_threshold, logger, t)
		else:
			EmotionService.apply_morale_delta(echo_v, int(drift.get("combat_exit_loss_morale", -15)), "combat_exit_loss", logger, t)
			EmotionService.apply_fear_delta(  echo_v, int(drift.get("combat_exit_loss_fear",    20)), "combat_exit_loss", fear_threshold, logger, t)

		# EMOTION-003: mutate fear_base per outcome
		var emo := EmotionService.get_emotion(echo_v)
		var fb := int(emo.get("fear_base", 0))
		if outcome == "win":
			fb = maxi(0, fb - fear_base_per_win)
		else:
			fb = mini(fear_base_max, fb + fear_base_per_loss)
		EmotionService.set_fear_base(echo_v, fb, logger, t)

		# EMOTION-003: streak tracking for morale_base mutation
		var win_streak  := int(emo.get("win_streak",  0))
		var loss_streak := int(emo.get("loss_streak", 0))
		if outcome == "win":
			win_streak  += 1
			loss_streak  = 0
			if win_streak >= streak_threshold:
				var mb := clampi(int(emo.get("morale_base", 50)) + morale_base_delta, morale_base_min, morale_base_max)
				EmotionService.set_morale_base(echo_v, mb, logger, t)
				win_streak = 0
		else:
			loss_streak += 1
			win_streak   = 0
			if loss_streak >= streak_threshold:
				var mb := clampi(int(emo.get("morale_base", 50)) - morale_base_delta, morale_base_min, morale_base_max)
				EmotionService.set_morale_base(echo_v, mb, logger, t)
				loss_streak = 0
		# Write streak counters back directly (no setter needed — they're transient accumulators)
		echo_v["emotion"]["win_streak"]  = win_streak
		echo_v["emotion"]["loss_streak"] = loss_streak
	flow_ctx.request_save("encounter.emotion_drift")


# EMOTION-002/003: applies sanctum morale recovery and bidirectional fear recovery toward each
# echo's base. Called from flow.go_state→SANCTUM (non-defeat path), keeper_intro.complete, and
# stage.return_home.scout_return.
func apply_sanctum_emotion_tick(t: int) -> void:
	var drift := ConfigService.get_emotion_drift_cfg(config_service)
	var tick_morale  := int(drift.get("sanctum_tick_morale", 2))
	# EMOTION-003: abs value used — direction determined by position relative to fear_base
	var tick_fear_abs: Variant = abs(int(drift.get("sanctum_tick_fear", -3)))
	var roster_v: Variant = flow_ctx.save_data.get("sanctum", {}).get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	for echo_v in roster:
		if not echo_v is Dictionary:
			continue
		var emo := EmotionService.get_emotion(echo_v)
		var morale_base    := int(emo.get("morale_base",    50))
		var morale_current := int(emo.get("morale_current", 50))
		# Morale: recovery only moves toward base — never above it
		if morale_current < morale_base:
			EmotionService.apply_morale_delta(echo_v, tick_morale, "sanctum_tick", logger, t)

		# EMOTION-003: Fear — bidirectional recovery toward fear_base; never overshoots
		var fear_base    := int(emo.get("fear_base",    0))
		var fear_current := int(emo.get("fear_current", 0))
		if fear_current > fear_base:
			# Too high — tick down; clamp so result doesn't go below fear_base
			var delta := -mini(tick_fear_abs, fear_current - fear_base)
			EmotionService.apply_fear_delta(echo_v, delta, "sanctum_tick", 999, logger, t)
		elif fear_current < fear_base:
			# Below base (kill euphoria) — tick back up; clamp so result doesn't exceed fear_base
			var delta := mini(tick_fear_abs, fear_base - fear_current)
			EmotionService.apply_fear_delta(echo_v, delta, "sanctum_tick", 999, logger, t)


# V2-SANCTUM-001 — Emotion recovery + consequence helpers
# ---------------------------------------------------------------------------

# Reads balance.data.emotion.drift.fear_threshold. Only used internally, by
# apply_emotion_recovery_if_needed's call into EmotionRecoveryService.
func _get_fear_threshold() -> int:
	var drift := ConfigService.get_emotion_drift_cfg(config_service)
	return int(drift.get("fear_threshold", 80))


# V2-SANCTUM-001: time-based fear/morale recovery catch-up. Called on flow.continue (session
# resume) and piggybacked on the economy bank-timer settle (economy.settle_time).
#
# Watch the double-settle guard: last_emotion_settle_unix is only ever advanced to now_unix
# here, and every early-return path either leaves it untouched (elapsed <= 0) or advances it
# and requests a save (first-ever settle, or a settle that produced no roster-visible delta).
# This must stay exactly as it was on FlowRuntime — a second dispatch with the same now_unix
# (or one before the stored clock) must not re-apply the same elapsed window.
func apply_emotion_recovery_if_needed(now_unix: int, t: int) -> void:
	var econ_v: Variant = flow_ctx.save_data.get("economy", {})
	if not (econ_v is Dictionary):
		return
	var econ_data: Dictionary = econ_v as Dictionary
	var last_settle := int(econ_data.get("last_emotion_settle_unix", 0))
	if last_settle <= 0:
		econ_data["last_emotion_settle_unix"] = now_unix
		flow_ctx.request_save("emotion.recovery_clock")
		return

	var elapsed := now_unix - last_settle
	if elapsed <= 0:
		return

	var cfg := ConfigService.get_emotion_recovery_cfg(config_service)
	if cfg.is_empty():
		return

	var fear_threshold := _get_fear_threshold()
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v as Dictionary
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	# V2-PROG-010: pass full cfg_data so EmotionRecoveryService can apply rank-based fear bonus.
	var _emo_cfg_data: Dictionary = {}
	if config_service != null:
		_emo_cfg_data = config_service.get_balance().get("data", {})
	var changed := EmotionRecoveryService.apply_recovery_from_elapsed(
		roster, elapsed, cfg, fear_threshold, logger, t, _emo_cfg_data)

	if changed.size() > 0:
		sanctum["roster"] = roster
		flow_ctx.request_save("emotion.recovery")
		logger.info(t, "emotion.recovery", "Emotion recovery applied", {
			"elapsed_seconds": elapsed,
			"echoes_changed":  changed.size(),
		})

	econ_data["last_emotion_settle_unix"] = now_unix
	# Persist the consumed recovery window even when rounding/clamps produced no
	# emotion delta; otherwise a later dispatch can settle the same elapsed time twice.
	flow_ctx.request_save("emotion.recovery_clock")


# V2-SANCTUM-001: sets a timed morale/fear recovery-rate modifier on every active party echo
# after a run resolves (victory/defeat/withdrawal), then composes it with any active
# V2-SANCTUM-002 institution condition modifier. Called from flow.go_state→SANCTUM (victory),
# flow.go_state→SANCTUM defeat path, and encounter.retreat (withdrawal).
func apply_run_emotion_modifiers(outcome: String, t: int) -> void:
	var cfg := ConfigService.get_emotion_recovery_cfg(config_service)
	if cfg.is_empty():
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v as Dictionary
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty():
		return

	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []

	var ticks := int(cfg.get("modifier_ticks_duration", 3))

	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v as Dictionary
		if not party_ids.has(str(echo.get("id", ""))):
			continue
		var morale_mul := 1.0
		var fear_mul   := 1.0
		match outcome:
			"victory":
				morale_mul = float(cfg.get("modifier_victory_morale_mul",  1.5))
			"defeat":
				fear_mul   = float(cfg.get("modifier_defeat_fear_mul",     0.5))
			"withdrawal":
				morale_mul = float(cfg.get("modifier_survived_morale_mul", 1.25))
		EmotionRecoveryService.set_modifier(echo, morale_mul, fear_mul, ticks, logger, t)

	# V2-SANCTUM-002: compose institution modifiers with run-outcome modifiers for party echoes
	var _inst_cfg := ConfigService.get_institutions_cfg(config_service)
	var _bldg_cfg := ConfigService.get_buildings_cfg(config_service)
	if not _inst_cfg.is_empty() and not _bldg_cfg.is_empty():
		for echo_v2 in roster:
			if not (echo_v2 is Dictionary):
				continue
			var echo2: Dictionary = echo_v2 as Dictionary
			var echo2_id := str(echo2.get("id", ""))
			if not party_ids.has(echo2_id):
				continue
			var inst_for := InstitutionService.find_institution_for_echo(echo2_id, flow_ctx.save_data)
			if inst_for.is_empty():
				continue
			var cond := InstitutionService.get_condition(inst_for, flow_ctx.save_data)
			if cond == InstitutionService.CONDITION_NEGLECTED:
				continue
			var b_cfg: Dictionary = _bldg_cfg.get(inst_for, {}) as Dictionary
			var inst_morale := float(b_cfg.get("morale_mul_" + cond, 1.0))
			var inst_fear   := float(b_cfg.get("fear_mul_"   + cond, 1.0))
			var inst_ticks  := int(b_cfg.get("ticks", ticks))
			var rm: Dictionary = echo2.get("recovery_modifiers", {}) as Dictionary
			var existing_morale := float(rm.get("morale_multiplier", 1.0))
			var existing_fear   := float(rm.get("fear_multiplier",   1.0))
			EmotionRecoveryService.set_modifier(echo2, existing_morale * inst_morale, existing_fear * inst_fear, inst_ticks, logger, t)

	flow_ctx.request_save("emotion.run_modifier")


# Apply morale delta to all active party echoes. Called from contact resolution (charge/
# claimant good/partial outcomes).
func apply_morale_to_party(delta: int, reason: String, t: int) -> void:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		if str(echo.get("id", "")) not in party_ids:
			continue
		EmotionService.apply_morale_delta(echo, delta, reason, logger, t)

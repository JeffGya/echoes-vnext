# res://core/runtime/controllers/WeaveController.gd
# V2-INFRA-003 Phase 4 Slice 1: first bounded domain controller extracted out of
# FlowRuntime.gd. Sets the pattern the remaining eight controllers follow.
#
# CONTRACT (see core/AGENTS.md + story brief for the full rationale):
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no
#     autoloads, no service locator, no reaching back into FlowRuntime.
#   - Mutates only through FlowContext (fields it owns: selected_weave_thread_id,
#     selected_weave_echo_id, weave_resolution, weave_commit_locked) and existing
#     domain services (WeavingRiteService, ContinuityService, EmotionService,
#     SocialGraphService, ShoutBank) — all of which are stateless static-func
#     utility classes, called the same way FlowRuntime itself already calls them.
#   - Never calls another controller. Never calls SaveService directly — save
#     intent is reported on the returned FlowActionOutcome (save_reasons) and
#     applied by FlowRuntime.dispatch() via flow_ctx.request_save().
#   - No UI or scene-tree reference.
#   - Does NOT hold a FlowStateMachine reference and does NOT transition or
#     refresh the snapshot itself. Every handler returns a FlowActionOutcome
#     describing what should happen (transition / replacement snapshot / save);
#     FlowRuntime.dispatch() is the sole place that acts on that intent. This is
#     what "the controller does not transition by itself" means in practice —
#     it structurally cannot, because it was never given the means to.
#
# Owns 6 actions: weave.start_for_echo, weave.select_thread, weave.begin_rite,
# weave.confirm, weave.enter_rite, weave.pick_echo. Moved verbatim (behaviour
# unchanged) from FlowRuntime.gd:
#   _handle_weave_start_for_echo, _handle_weave_begin_rite, _handle_weave_confirm,
#   _apply_weave_non_chosen_consequences, _build_weave_aftermath_lines,
#   _get_weaving_rite_cfg
# plus the three actions (select_thread, enter_rite, pick_echo) that previously
# lived inline in FlowRuntime.dispatch()'s match block — pulled into named
# handler methods here so all 6 weave actions are owned by one controller.
#
# V2-INFRA-003 Phase 4 Slice 1b: the five tiny config-read helpers that were
# duplicated here (_find_roster_echo, _get_drift_cfg, _get_bond_thresholds_cfg,
# _get_continuity_cfg, _get_expression_band_for_echo) have been relocated to
# their real owners and are called from there instead — no duplicates remain:
#   SanctumService.find_roster_echo(save_data, echo_id)              — reads save_data["sanctum"]["roster"], the data SanctumService owns
#   ConfigService.get_emotion_drift_cfg(config_service)               — data.emotion.drift; EmotionService's setters take individual values, never this whole dict
#   ConfigService.get_continuity_cfg(config_service)                  — data.continuity; feeds ContinuityService, which is pure (mirrors EconomyService — never touches ConfigService)
#   ConfigService.get_bond_thresholds_cfg(config_service)             — data.sanctum.bond_thresholds; feeds SocialGraphService, which is pure ("receive data in, return data out")
#   MaturityExpressionService.get_expression_band_for_echo(echo, band_by_standing) — band_by_standing itself comes from ConfigService.get_maturity_expression_band_by_standing(config_service); MaturityExpressionService's own file rule is "never loads ConfigService directly"
# ConfigService ended up the owner for four of the five: it is the sole reader
# of balance.json in this codebase, and every domain service that consumes
# these subtrees is deliberately pure (config dicts passed in, never fetched).

class_name WeaveController
extends RefCounted

const FlowWeavingRiteStateScript := preload("res://core/state/flow/states/sanctum/FlowWeavingRiteState.gd")
const WeavingRiteServiceScript   := preload("res://core/progression/WeavingRiteService.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


## weave.start_for_echo — opens the Weaving Rite for a specific echo from Sanctum/EchoParty.
func handle_start_for_echo(action: Dictionary, t: int) -> FlowActionOutcome:
	var snap_type := str(flow_ctx.last_snapshot.get("type", ""))
	if snap_type != FlowStateIds.ECHO_PARTY and snap_type != FlowStateIds.SANCTUM:
		logger.debug(t, "weave.start_for_echo.ignored", "weave.start_for_echo ignored outside Sanctum family", {
			"snapshot_type": snap_type,
		})
		return FlowActionOutcome.handled_outcome()

	var echo_id := str(action.get("echo_id", "")).strip_edges()
	if echo_id.is_empty():
		logger.debug(t, "weave.start_for_echo.denied", "Missing echo_id for rite start", {})
		return FlowActionOutcome.handled_outcome()

	var echo_ref := SanctumService.find_roster_echo(flow_ctx.save_data, echo_id)
	if echo_ref.is_empty():
		logger.debug(t, "weave.start_for_echo.denied", "Echo not found in roster", {
			"echo_id": echo_id,
		})
		return FlowActionOutcome.handled_outcome()

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var threads_v: Variant = sanctum.get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	if threads.is_empty():
		logger.debug(t, "weave.start_for_echo.denied", "No threads in reserve", {
			"echo_id": echo_id,
		})
		return FlowActionOutcome.handled_outcome()

	flow_ctx.selected_weave_echo_id = echo_id
	flow_ctx.selected_weave_thread_id = ""
	flow_ctx.weave_resolution = {}
	flow_ctx.weave_commit_locked = false
	return FlowActionOutcome.transition_outcome(FlowStateIds.WEAVING_RITE, "ui.weave.start_for_echo")


## weave.select_thread — records the reserve thread the Keeper is considering for the rite.
func handle_select_thread(action: Dictionary, t: int) -> FlowActionOutcome:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.WEAVING_RITE:
		logger.debug(t, "weave.select_thread.ignored", "Selection ignored outside rite state", {})
		return FlowActionOutcome.handled_outcome()

	flow_ctx.selected_weave_thread_id = str(action.get("thread_id", ""))
	flow_ctx.weave_resolution = {}
	flow_ctx.weave_commit_locked = false
	return FlowActionOutcome.snapshot_outcome(FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t))


## weave.begin_rite — resolves the rite outcome for the selected echo/thread pair, applies
## consequences (Continuity, non-chosen fallout), and commits the weave lock.
func handle_begin_rite(t: int) -> FlowActionOutcome:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.WEAVING_RITE:
		logger.debug(t, "weave.begin_rite.ignored", "weave.begin_rite ignored outside rite state", {})
		return FlowActionOutcome.handled_outcome()

	var thread_id := str(flow_ctx.selected_weave_thread_id).strip_edges()
	var echo_id := str(flow_ctx.selected_weave_echo_id).strip_edges()
	if thread_id.is_empty() or echo_id.is_empty():
		logger.debug(t, "weave.begin_rite.denied", "Missing selected thread or echo", {
			"thread_id": thread_id,
			"echo_id": echo_id,
		})
		return FlowActionOutcome.snapshot_outcome(FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t))

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var threads_v: Variant = sanctum.get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var thread_v: Variant = threads.get(thread_id, {})
	if not (thread_v is Dictionary):
		logger.debug(t, "weave.begin_rite.denied", "Selected thread not found in reserve", {
			"thread_id": thread_id,
		})
		return FlowActionOutcome.snapshot_outcome(FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t))
	var thread: Dictionary = thread_v

	var echo_ref := SanctumService.find_roster_echo(flow_ctx.save_data, echo_id)
	if echo_ref.is_empty():
		logger.debug(t, "weave.begin_rite.denied", "Selected echo not found in roster", {
			"echo_id": echo_id,
		})
		return FlowActionOutcome.snapshot_outcome(FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t))

	var rite_cfg := _get_weaving_rite_cfg()
	var resonance_candidates: Array = WeavingRiteServiceScript.get_candidates(thread, roster, flow_ctx.save_data, rite_cfg)

	var outcome: String = WeavingRiteServiceScript.resolve_outcome(echo_ref, thread, flow_ctx.save_data, rite_cfg)
	flow_ctx.weave_commit_locked = true
	WeavingRiteServiceScript.apply_outcome(outcome, echo_id, thread_id, flow_ctx.save_data, logger, t)

	# V2-CONTINUITY-001: Thread outcome drives Continuity.
	var _cont_cfg := ConfigService.get_continuity_cfg(config_service)
	if outcome == "accept":
		var _cont_pts := int(_cont_cfg.get("thread_integration_points", 5))
		ContinuityService.add_points(flow_ctx.save_data, _cont_pts, "thread.integration", logger, t)
	elif outcome == "reject":
		var _rej_base := int(_cont_cfg.get("thread_reject_base_penalty", 2))
		var _rej_max  := int(_cont_cfg.get("thread_reject_max_penalty", 10))
		ContinuityService.apply_reject_penalty(flow_ctx.save_data, echo_id, _rej_base, _rej_max, "thread.reject", logger, t)
	# "defer" → no Continuity change

	var non_chosen: Array = []
	non_chosen = WeavingRiteServiceScript.get_non_chosen_consequences(resonance_candidates, echo_id, outcome, rite_cfg)
	if not non_chosen.is_empty():
		_apply_weave_non_chosen_consequences(non_chosen, echo_id, t)

	# V2-VOICE-001: select rite bark for chosen echo.
	var _rite_ctx_key := "rite.thread_" + outcome
	var _rite_arch := str(echo_ref.get("archetype_birth", "loyal"))
	var _rite_calling := str(echo_ref.get("calling_origin", ""))
	var _rite_band := MaturityExpressionService.get_expression_band_for_echo(echo_ref, ConfigService.get_maturity_expression_band_by_standing(config_service))
	var _rite_vk: int = (t + str(echo_id).hash()) % 997
	var _rite_line := ShoutBank.get_expression_shout(_rite_ctx_key, _rite_arch, _rite_band, _rite_calling, _rite_vk)

	flow_ctx.weave_resolution = {
		"outcome": outcome,
		"thread_id": thread_id,
		"thread_virtue": str(thread.get("virtue", "unknown")),
		"thread_quality_tier": str(thread.get("quality_tier", "broken")),
		"echo_id": echo_id,
		"echo_name": str(echo_ref.get("name", "")),
		"non_chosen": non_chosen,
		"aftermath_lines": _build_weave_aftermath_lines(outcome, echo_ref, thread, non_chosen),
		# V2-VOICE-001: rite bark line for WeavingRiteScreen outcome display.
		"echo_bark": { "line": _rite_line, "context": _rite_ctx_key },
	}

	return FlowActionOutcome.snapshot_outcome(FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t)).with_save_reason("weave.begin_rite")


## weave.confirm — acknowledges the aftermath and returns to Sanctum, releasing the weave lock.
func handle_confirm(t: int) -> FlowActionOutcome:
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.WEAVING_RITE:
		logger.debug(t, "weave.confirm.ignored", "weave.confirm ignored outside rite state", {})
		return FlowActionOutcome.handled_outcome()

	flow_ctx.selected_weave_thread_id = ""
	flow_ctx.selected_weave_echo_id = ""
	flow_ctx.weave_resolution = {}
	flow_ctx.weave_commit_locked = false
	return FlowActionOutcome.transition_outcome(FlowStateIds.SANCTUM, "ui.weave.confirm")


## weave.enter_rite — enters the Weaving Rite screen with a clean slate (no echo/thread chosen).
func handle_enter_rite(t: int) -> FlowActionOutcome:
	flow_ctx.selected_weave_echo_id = ""
	flow_ctx.selected_weave_thread_id = ""
	flow_ctx.weave_resolution = {}
	flow_ctx.weave_commit_locked = false
	return FlowActionOutcome.transition_outcome(FlowStateIds.WEAVING_RITE, "ui.weave.enter_rite")


## weave.pick_echo — picks the echo to weave with from the rite's echo_candidates list.
func handle_pick_echo(action: Dictionary, t: int) -> FlowActionOutcome:
	var echo_id := str(action.get("echo_id", "")).strip_edges()
	if str(flow_ctx.last_snapshot.get("type", "")) != FlowStateIds.WEAVING_RITE or echo_id.is_empty():
		return FlowActionOutcome.handled_outcome()

	flow_ctx.selected_weave_echo_id = echo_id
	flow_ctx.selected_weave_thread_id = ""
	flow_ctx.weave_resolution = {}
	flow_ctx.weave_commit_locked = false
	return FlowActionOutcome.snapshot_outcome(FlowWeavingRiteStateScript.build_snapshot(flow_ctx, t))


## Moved verbatim from FlowRuntime._apply_weave_non_chosen_consequences. Applies morale/fear/
## bond fallout to the resonant echoes who were NOT chosen for the rite.
func _apply_weave_non_chosen_consequences(non_chosen: Array, chosen_id: String, t: int) -> void:
	if non_chosen.is_empty():
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v

	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []
	var thresholds := ConfigService.get_bond_thresholds_cfg(config_service)

	var drift := ConfigService.get_emotion_drift_cfg(config_service)
	var fear_threshold := int(drift.get("fear_threshold", 80))
	var applied := 0
	for c_v in non_chosen:
		if not (c_v is Dictionary):
			continue
		var c: Dictionary = c_v
		var target_id := str(c.get("echo_id", "")).strip_edges()
		if target_id.is_empty() or target_id == chosen_id:
			continue

		var echo_ref := SanctumService.find_roster_echo(flow_ctx.save_data, target_id)
		if echo_ref.is_empty():
			continue

		var morale_delta := int(c.get("morale_delta", 0))
		var fear_delta := int(c.get("fear_delta", 0))
		var bond_delta := int(c.get("bond_delta", 0))

		if morale_delta != 0:
			EmotionService.apply_morale_delta(echo_ref, morale_delta, "weave.non_chosen", logger, t)
		if fear_delta != 0:
			EmotionService.apply_fear_delta(echo_ref, fear_delta, "weave.non_chosen", fear_threshold, logger, t)
		if bond_delta != 0:
			bonds = SocialGraphService.apply_score_delta(
				bonds,
				chosen_id,
				target_id,
				bond_delta,
				thresholds,
				logger,
				t
			)
		applied += 1

	sanctum["bonds"] = bonds
	flow_ctx.save_data["sanctum"] = sanctum

	if applied > 0:
		logger.info(t, "weave.non_chosen.applied", "Applied non-chosen weave consequences", {
			"chosen_id": chosen_id,
			"affected_count": applied,
		})


## Moved verbatim from FlowRuntime._build_weave_aftermath_lines. Pure — no dependencies beyond
## its arguments.
func _build_weave_aftermath_lines(outcome: String, echo: Dictionary, thread: Dictionary, non_chosen: Array) -> Array:
	var echo_name := str(echo.get("name", "This echo"))
	var virtue := str(thread.get("virtue", "story"))
	var lines: Array = []
	match outcome:
		"accept":
			lines.append("%s accepts the %s thread." % [echo_name, virtue])
			lines.append("The weave settles and the reserve releases its hold.")
			if not non_chosen.is_empty():
				lines.append("The other resonant Echoes leave with tightened bonds and shaken hearts.")
		"reject":
			lines.append("%s rejects the %s thread." % [echo_name, virtue])
			lines.append("The thread is consumed in refusal, and identity is clarified.")
			if not non_chosen.is_empty():
				lines.append("Others who leaned toward this thread take the refusal personally.")
		"defer":
			lines.append("%s defers the %s thread." % [echo_name, virtue])
			lines.append("A memory mark remains; the thread returns to reserve.")
			if not non_chosen.is_empty():
				lines.append("The waiting unsettles nearby hearts, even without full rupture.")
		_:
			lines.append("The rite resolves without a clear outcome.")
	return lines


## Moved verbatim from FlowRuntime._get_weaving_rite_cfg.
func _get_weaving_rite_cfg() -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var rite_v: Variant = data.get("weaving_rite", {})
	var rite: Dictionary = (rite_v if rite_v is Dictionary else {}).duplicate(true)

	# V2-PROG-012 Phase 9: overlay the canonical identity tables from data.contact —
	# same "overlay canonical source onto a local cfg copy" pattern as
	# RecruitmentService.build_effective_cfg. WeavingRiteService reads
	# cfg.vector_virtue_composition, cfg.calling_to_virtue_primary, and cfg.virtue_wheel;
	# all three live canonically under data.contact, not data.weaving_rite (see
	# balance.json's "_comment_identity" on data.contact for why).
	var contact_v: Variant = data.get("contact", {})
	var contact: Dictionary = contact_v if contact_v is Dictionary else {}
	var composition_v: Variant = contact.get("vector_virtue_composition", {})
	rite["vector_virtue_composition"] = composition_v if composition_v is Dictionary else {}
	var calling_primary_v: Variant = contact.get("calling_to_virtue_primary", {})
	rite["calling_to_virtue_primary"] = calling_primary_v if calling_primary_v is Dictionary else {}
	# chore/finish-virtue-wheel-and-dead-config: WeavingRiteService._is_adjacent migrated
	# off its hardcoded _VIRTUE_WHEEL const onto this overlaid cfg.virtue_wheel, matching
	# the ConversationService._virtue_wheel_distance precedent. Without this overlay,
	# _is_adjacent silently degrades to false for every pair (empty wheel -> find() == -1),
	# disabling the 0.6 adjacent fit tier and the +0.1 calling-virtue-adjacency bonus.
	var virtue_wheel_v: Variant = contact.get("virtue_wheel", [])
	rite["virtue_wheel"] = virtue_wheel_v if virtue_wheel_v is Array else []

	return rite

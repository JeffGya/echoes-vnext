# res://core/sanctum/RecruitmentConsequenceService.gd
# V2-INFRA-003 Phase 4 Slice 5: flow-level recruitment (STAGE-004 Phase 4 "Earned Return")
# consequence orchestration extracted out of FlowRuntime.gd, following the
# BondConsequenceService/VowConsequenceService extraction pattern.
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly — requests saves via flow_ctx.request_save(reason),
#     the same choke point FlowRuntime._mark_save_requested() itself calls.
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot.
#
# core/sanctum/RecruitmentService.gd already exists and stays exactly as it is — it holds
# recruitment DOMAIN rules (the chance formula, the seeded roll, minting a roster echo). This
# class holds the FLOW-level orchestration that decides WHEN those domain rules run against
# live encounter/roster state and how results are threaded into save_data for the Sanctum UI
# to read (the companion_invite inbox).
#
# Moved verbatim (behaviour unchanged) from FlowRuntime.gd:
#   _compute_ally_recruit_offer_if_eligible → compute_ally_recruit_offer_if_eligible
#   _clear_ally_fields_if_present           → clear_ally_fields_if_present
#
# NOT moved — these are action handlers for sanctum.companion.accept / .decline, not
# combat-teardown consequence hooks. They belong to SanctumController, which is not extracted
# yet (per Slice 5 scope). Left on FlowRuntime as _handle_companion_accept / _handle_companion_decline:
#   _handle_companion_accept
#   _handle_companion_decline
#
# _get_active_party_echoes() substitution: the moved compute_ally_recruit_offer_if_eligible()
# used FlowRuntime._get_active_party_echoes() (raw roster-dict filter by active_party_ids) to
# build RecruitmentService.compute_recruit_chance()'s party_echoes argument. V2-INFRA-003
# extracted that read into SanctumService.get_active_party_echoes(save_data) — a static, pure
# reader (no SanctumState construction, so no risk of the mutate-on-construct path described
# on SanctumService's façade doc comment) — and FlowRuntime._get_active_party_echoes() now
# delegates to it too, so there is exactly one implementation. Used here directly instead of
# SanctumService.new(flow_ctx.save_data).get_party_actors(), which the file previously used:
# that instance method constructs a SanctumState, which can mutate save_data on construction
# if "sanctum" were ever missing — unacceptable on a combat-resolution read path.

class_name RecruitmentConsequenceService
extends RefCounted

const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


# V2-STAGE-004 Phase 4 (S14) — REDESIGNED (Jeff, Sanctum-event pass): "Earned Return" — if a
# joined ally survived AND the encounter was won, compute the recruit-chance breakdown + a
# single seeded roll. On a SUCCESSFUL roll, the invite is stored on save_data.sanctum
# .companion_invite — a one-slot Sanctum inbox surfaced by FlowSanctumState on entry (see
# FlowRuntime._handle_companion_accept/_handle_companion_decline) — instead of the old
# resolve-screen explore_map.ally_recruit_offer. Called from _end_round() BEFORE any teardown
# path clears explore_map.ally_contact or nulls encounter_ctx. See ANSWERS.md #28/#30/#31.
#
# Compute-once guard: skips silently if THIS encounter_id's roll was already evaluated (never
# re-rolls on re-render / save+Continue). Tracked via explore_map.ally_recruit_rolled_encounter_id,
# separate from the invite itself — a failed roll or a no-stack-discarded success leaves no trace
# in sanctum.companion_invite, so presence of the invite alone can't serve as the guard anymore.
#
# No-stack guard: a successful roll is discarded (not stored) when save_data.sanctum
# .companion_invite is already non-empty — one pending companion invite max. The invite then
# PERSISTS until the player accepts/declines it (no auto-clear on encounter teardown, no expiry).
#
# No-op (no write) when: no joined ally, the ally died, or the encounter was not a victory.
func compute_ally_recruit_offer_if_eligible(is_victory: bool, rounds_total: int, t: int) -> void:
	if not is_victory:
		return
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx == null:
		return

	var _aro_ally: Dictionary = {}
	for _aro_a_v in ectx.actors:
		if _aro_a_v is Dictionary and bool((_aro_a_v as Dictionary).get("is_ally", false)):
			_aro_ally = _aro_a_v
			break
	if _aro_ally.is_empty() or bool(_aro_ally.get("is_dead", false)):
		return

	var _aro_stage: Dictionary = FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if _aro_stage.is_empty():
		return
	var _aro_map_v: Variant = _aro_stage.get("explore_map", {})
	var _aro_map: Dictionary = _aro_map_v if _aro_map_v is Dictionary else {}
	var _aro_source_contact_v: Variant = _aro_map.get("ally_contact", {})
	var _aro_source_contact: Dictionary = _aro_source_contact_v if _aro_source_contact_v is Dictionary else {}
	if _aro_source_contact.is_empty():
		return

	var _aro_encounter_id: String = str(ectx.encounter_id)
	if str(_aro_map.get("ally_recruit_rolled_encounter_id", "")) == _aro_encounter_id:
		return  # already evaluated for this encounter — never re-roll

	var _aro_bal: Dictionary = config_service.get_balance()
	var _aro_bal_data_v: Variant = _aro_bal.get("data", {})
	var _aro_bal_data: Dictionary = _aro_bal_data_v if _aro_bal_data_v is Dictionary else {}
	var _aro_contact_cfg_v: Variant = _aro_bal_data.get("contact", {})
	var _aro_contact_cfg: Dictionary = _aro_contact_cfg_v if _aro_contact_cfg_v is Dictionary else {}
	var _aro_recruit_cfg_v: Variant = _aro_contact_cfg.get("recruitment", {})
	var _aro_recruit_cfg: Dictionary = _aro_recruit_cfg_v if _aro_recruit_cfg_v is Dictionary else {}
	# Override the recruitment block's copies of rival_archetype_pairs / good thresholds
	# with their canonical sources, and pull in virtue_vector_key from its single
	# canonical location (data.contact — V2-PROG-012 Phase 9; no recruitment-block copy
	# exists anymore) — see RecruitmentService.build_effective_cfg.
	var _aro_effective_cfg: Dictionary = RecruitmentService.build_effective_cfg(_aro_bal_data)

	# See file header note: SanctumService.get_active_party_echoes() is the pure static
	# reader (V2-INFRA-003) that replaced the mutating SanctumService.new(...).get_party_actors()
	# construction previously used here.
	var _aro_party_echoes: Array = SanctumService.get_active_party_echoes(flow_ctx.save_data)
	var _aro_contribution_v: Variant = ectx.echo_action_logs.get(str(_aro_ally.get("id", "")), {})
	var _aro_contribution: Dictionary = _aro_contribution_v if _aro_contribution_v is Dictionary else {}

	var _aro_breakdown: Dictionary = RecruitmentService.compute_recruit_chance(
		_aro_ally, _aro_source_contact, _aro_party_echoes, _aro_contribution, rounds_total, _aro_effective_cfg)

	# Seeded roll for determinism — append-only namespace, one draw per encounter.
	var _aro_rng := RandomNumberGenerator.new()
	if flow_ctx.campaign_seed != null:
		_aro_rng = flow_ctx.campaign_seed.get_rng("combat." + _aro_encounter_id + ".ally_recruit")
	else:
		# Unexpected in real flow (campaign_seed is always set) — log so a silent divergent
		# fallback never hides an upstream bug.
		logger.warn(t, "combat.ally_recruit_offer.null_seed_fallback",
			"campaign_seed was null when computing ally recruit offer — using non-deterministic hash fallback", {
				"encounter_id": _aro_encounter_id,
			})
		_aro_rng.seed = hash("combat." + _aro_encounter_id + ".ally_recruit")
	var _aro_chance: int = int(_aro_breakdown.get("chance", 0))
	# V2-STAGE-004 Phase 4 (S14) dev toggle: draw-then-override — the seeded roll always
	# runs first, so RNG draw order is byte-identical whether or not the override is
	# active; only the boolean RESULT is swapped afterward. flow_ctx.dev_force_recruit
	# defaults to "" (real play), which never touches _aro_success.
	var _aro_success: bool = RecruitmentService.roll(_aro_chance, _aro_rng)
	if flow_ctx.dev_force_recruit == "success":
		_aro_success = true
	elif flow_ctx.dev_force_recruit == "fail":
		_aro_success = false

	# Mark this encounter's roll as evaluated regardless of outcome — compute-once guard.
	_aro_map["ally_recruit_rolled_encounter_id"] = _aro_encounter_id
	_aro_stage["explore_map"] = _aro_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, _aro_stage)
	flow_ctx.request_save("sanctum.companion_invite")
	logger.info(t, "combat.ally_recruit_offer", "Ally recruit offer evaluated", {
		"encounter_id":   _aro_encounter_id,
		"chance":         _aro_chance,
		"conversation":   int(_aro_breakdown.get("conversation", 0)),
		"combat":         int(_aro_breakdown.get("combat", 0)),
		"fit":            int(_aro_breakdown.get("fit", 0)),
		"rolled_success": _aro_success,
	})

	if not _aro_success:
		return

	# No-stack guard: one pending companion invite max — a successful roll is discarded
	# (not stored) if the Sanctum already has an invite awaiting a decision.
	if not flow_ctx.save_data.has("sanctum") or not (flow_ctx.save_data["sanctum"] is Dictionary):
		flow_ctx.save_data["sanctum"] = {}
	var _aro_sanctum: Dictionary = flow_ctx.save_data["sanctum"]
	var _aro_existing_invite_v: Variant = _aro_sanctum.get("companion_invite", {})
	var _aro_existing_invite: Dictionary = _aro_existing_invite_v if _aro_existing_invite_v is Dictionary else {}
	if not _aro_existing_invite.is_empty():
		logger.info(t, "sanctum.companion_invite.discarded",
			"Ally recruit succeeded but a companion invite was already pending — discarded (no-stack)", {
				"encounter_id": _aro_encounter_id,
			})
		return

	_aro_sanctum["companion_invite"] = {
		"chance":         _aro_chance,
		"conversation":   int(_aro_breakdown.get("conversation", 0)),
		"combat":         int(_aro_breakdown.get("combat", 0)),
		"fit":            int(_aro_breakdown.get("fit", 0)),
		"cap":            int(_aro_recruit_cfg.get("cap", 75)),
		"ally_name":      str(_aro_ally.get("name", "")),
		"ally_actor":     (_aro_ally as Dictionary).duplicate(true),
		"source_contact": (_aro_source_contact as Dictionary).duplicate(true),
	}
	flow_ctx.save_data["sanctum"] = _aro_sanctum
	logger.info(t, "sanctum.companion_invite.created", "Companion invite created for Sanctum pickup", {
		"encounter_id": _aro_encounter_id,
		"ally_name":    str(_aro_ally.get("name", "")),
	})


# V2-STAGE-004 Phase 4 (S12): clears the durable Temporary Ally auto-join fields on the
# current stage's explore_map at encounter teardown (win or loss — the ally is spent for
# one battle either way). No-op (and no write) when nothing is set, so the common no-ally
# path stays byte-identical.
func clear_ally_fields_if_present(t: int) -> void:
	var _acf_stage: Dictionary = FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if _acf_stage.is_empty():
		return
	var _acf_map_v: Variant = _acf_stage.get("explore_map", {})
	var _acf_map: Dictionary = _acf_map_v if _acf_map_v is Dictionary else {}
	var _acf_ally_v: Variant = _acf_map.get("ally_contact", {})
	var _acf_ally: Dictionary = _acf_ally_v if _acf_ally_v is Dictionary else {}
	var _acf_has_ally: bool = not _acf_ally.is_empty() \
		or bool(_acf_map.get("ally_consumed_in_encounter", false))
	# V2-STAGE-004 S15 prep: also clear the combat_intro_reason marker (set by the
	# claimant-hostile combat-forced branch) at the same teardown point.
	var _acf_has_intro_marker: bool = not str(_acf_map.get("combat_intro_reason", "")).is_empty()
	# V2-STAGE-004 Phase 4 (S14 redesign): the earned-return companion invite now lives on
	# save_data.sanctum.companion_invite (Sanctum-scoped, persists until the player decides) —
	# encounter teardown must NOT touch it. Only the ally-join fields + intro marker are
	# encounter-scoped and clear here.
	if not _acf_has_ally and not _acf_has_intro_marker:
		return
	if _acf_has_ally:
		_acf_map["ally_contact"]              = {}
		_acf_map["ally_contact_id"]           = ""
		_acf_map["ally_consumed_in_encounter"] = false
	if _acf_has_intro_marker:
		_acf_map["combat_intro_reason"] = ""
	_acf_stage["explore_map"] = _acf_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, _acf_stage)
	flow_ctx.request_save("encounter.ally_cleared")
	if _acf_has_ally:
		logger.info(t, "stage.ally.cleared", "Temporary ally auto-join fields cleared at encounter teardown", {
			"stage_id": flow_ctx.stage_id,
		})
	if _acf_has_intro_marker:
		logger.info(t, "stage.combat_intro.cleared", "Combat intro reason marker cleared at encounter teardown", {
			"stage_id": flow_ctx.stage_id,
		})

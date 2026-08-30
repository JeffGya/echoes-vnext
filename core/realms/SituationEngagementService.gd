# res://core/realms/SituationEngagementService.gd
# V2-INFRA-003 Phase 5 Slice E: the stage.engage_situation and stage.resolve_situation_choice
# PROCEDURE BODIES, split out of core/realms/ActiveStageService.gd (see that file's
# header for the Slice A contract and location reasoning, which this file inherits unchanged).
#
# CONTRACT (identical to ActiveStageService's):
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly — requests saves via flow_ctx.request_save(reason).
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot.
#   - Same constructor signature (flow_ctx, config_service, logger) as every sibling service
#     in this extraction family, so a caller swaps one factory line for another.
#
# LOCATION — core/realms/, beside SituationModel and SituationResolutionService, the two
# domain classes these bodies operate on.
#
# NOT SituationResolutionService. That class is the PURE RULES: route() decides async vs
# in-explore, resolve_in_explore() and resolve_choice() compute deltas from config and a
# seeded RNG. It reads no FlowContext and writes no save_data. THIS class is the PROCEDURE
# around it: it finds the situation in save_data, mutates revealed/resolved, writes intel
# clues, applies emotion deltas to the active party, awards Ase, requests saves, and returns
# the verdict VentureController maps onto an outcome. Rules stay pure; the procedure lives
# here.
#
# WHY THESE TWO ARE TOGETHER. They share a seam, not just a file: both call
# SituationResolutionService with the same seeded RNG namespace ("stage.resolution.%s"), both
# build the same emotion_summary / effects payload, and both return the identical "resolved"
# verdict shape so VentureController translates them through ONE code path. Splitting them
# would have cut through that shared shape. advance_turn went to StageExploreTurnService
# instead because it shares none of it — see that file's header.
#
# DETERMINISM. Neither body derives a new seed path. Both call
# CampaignSeed.get_rng_from(realm_seed, "stage.resolution.%s" % sit_id), the same string as
# before, and neither adds, removes or reorders a draw. resolve_situation_choice() advances
# turn_count by the choice's turn_cost, exactly as before — that is a separate mutation from
# advance_turn()'s single-turn increment and is unaffected by the split.

class_name SituationEngagementService
extends RefCounted

const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


# ═══════════════════════════════════════════════════════════════════════════
# V2-INFRA-003 Phase 5 Slice D — the long procedural bodies of the four biggest
# venture actions.
#
# WHY THEY ARE HERE AND NOT ON VentureController. A controller routes an action, applies
# domain calls and returns a FlowActionOutcome; it does not hold long procedural bodies
# (the slice brief's hard size requirement, and the reason Slice A built this service
# "specifically so the heavy explore-turn work has a home"). Each function below is the
# pre-extraction handler body MINUS its snapshot/transition tail; it returns a plain verdict
# that VentureController translates into a FlowActionOutcome. Nothing here holds
# flow_machine, so none of them can publish a snapshot or transition by itself.
#
# Saves are requested with flow_ctx.request_save(reason) at the ORIGINAL point in the body,
# never deferred onto the outcome — _apply_action_outcome() applies save_reasons AFTER the
# transition, which would reorder the "|"-joined save_request_reason string.
# ═══════════════════════════════════════════════════════════════════════════#
# V2-INFRA-003 Phase 5 Slice E — SPLIT, NOT MOVED. This body was extracted verbatim from
# core/realms/ActiveStageService.gd, which had grown to 1,461 lines (Slice D moved
# VentureController's heavy procedure bodies there to meet the controller's size budget, and
# the size problem simply moved with them). No behaviour changed in this slice: the split is
# by the seams the Slice D banner ABOVE already describes, which is why that banner is
# reproduced verbatim in both files the bodies split into — it is the contract for each of
# them, not a note about a file. See core/realms/ActiveStageService.gd's header for
# the full inventory of what left it and where each piece went.


## Builds a fresh ContactConversationService — the contact seam. VentureController may not
## call ContactController, so the NPC-conversation route out of engage_situation() passes
## through this service instead. See core/realms/ContactConversationService.gd.
func _contact_conversation_service() -> ContactConversationService:
	return ContactConversationService.new(flow_ctx, config_service, logger)


# ---------------------------------------------------------------------------
# stage.engage_situation
# ---------------------------------------------------------------------------

## The body of FlowRuntime._handle_stage_engage_situation(), moved verbatim minus its four
## snapshot/transition tails. Returns a verdict Dictionary keyed on "outcome":
##   "invalid"  — missing id / no stage / situation not found  → handled, nothing happens
##   "async"    — combat or shrine                             → transition to ENCOUNTER;
##                carries "reason"
##   "contact"  — NPC with a contact dict; the conversation has ALREADY been started through
##                ContactConversationService (the contact seam)  → rebuild + refresh
##   "choice"   — player must pick first                       → rebuild + refresh, with
##                carries "situation_id" / "type" / "choices" for data.situation_overlay
##   "resolved" — acknowledge / take / leave applied           → situation resolve card +
##                transition to RESOLVE; carries "sit", "emotion_summary", "effects",
##                "summary_line", "ase_awarded"
##
## The async-vs-in-explore decision is NOT reimplemented here: SituationResolutionService.route()
## makes it, exactly as before.
##
## `econ` is a PARAMETER, not a constructor dependency — same reasoning as advance_turn()'s
## `directive_service`. Slice A fixed this service's constructor at
## (flow_ctx, config_service, logger) and two call sites already build it that way; widening
## the constructor for two mid-body uses (the VowConsequenceService the engage condition needs,
## and the situation.money award) would churn every existing construction site for no gain.
func engage_situation(sit_id: String, econ: EconomyService, t: int) -> Dictionary:
	if sit_id.is_empty():
		logger.debug(t, "stage.engage.no_id", "engage_situation: missing situation_id", {})
		return { "outcome": "invalid" }

	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return { "outcome": "invalid" }

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	# Clear pending state — engagement is now committed
	explore_map["pending_situation_id"] = ""
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []

	# VOW-001: capture revealed state before engagement mutation so obi_nnim_kyere can check it.
	var _sit_was_revealed := false
	for _sv_peek in situations:
		if _sv_peek is Dictionary and str((_sv_peek as Dictionary).get("id", "")) == sit_id:
			_sit_was_revealed = bool((_sv_peek as Dictionary).get("revealed", false))
			break

	# Find and mutate the situation — set ONLY revealed (not resolved).
	var sit: Dictionary = {}
	for i in range(situations.size()):
		var s_v: Variant = situations[i]
		if s_v is Dictionary and str((s_v as Dictionary).get("id", "")) == sit_id:
			var s: Dictionary = s_v
			s["revealed"] = true
			# V2-INTEL-001: write firsthand intel on direct engagement if not already scouted
			var eng_clues_v: Variant = s.get("intel_clues", [])
			var eng_clues: Array = eng_clues_v if eng_clues_v is Array else []
			if eng_clues.is_empty():
				eng_clues.append(FlowStageExploreStateScript._intel_clue_for_type_static(str(s.get("type", ""))))
			s["intel_clues"] = eng_clues
			if str(s.get("intel_quality", "")).is_empty():
				s["intel_quality"] = "rough"
			situations[i] = s
			sit = s
			break

	if sit.is_empty():
		logger.debug(t, "stage.engage.not_found", "engage_situation: situation not found", {
			"situation_id": sit_id
		})
		return { "outcome": "invalid" }

	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.engage_situation")

	# VOW-001: evaluate engage condition (obi_nnim_kyere revealed check).
	VowConsequenceService.new(flow_ctx, config_service, econ, logger) \
		.apply_vow_engage_condition(_sit_was_revealed, t)

	# V2-STAGE-002: set active objective index for encounter resolution mode lookup.
	var _sit_obj_index := int(sit.get("objective_index", -1))
	flow_ctx.active_encounter_objective_index = _sit_obj_index

	var sit_type := str(sit.get("type", ""))

	logger.info(t, "stage.engage_situation", "Party engaged situation", {
		"stage_id":        flow_ctx.stage_id,
		"situation_id":    sit_id,
		"type":            sit_type,
		"is_objective":    sit.get("is_objective", false),
		"objective_index": _sit_obj_index,
		"obj_found":       explore_map.get("objectives_found", 0),
		"obj_total":       explore_map.get("objectives_total", 0),
	})

	# V2-STAGE-004: route via SituationResolutionService.
	var _track := SituationResolutionService.route(sit_type, bool(sit.get("is_objective", false)))

	if _track == "async":
		# Compute encounter_approach context before handing off.
		var _ea_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
		var _ea_sanctum: Dictionary = _ea_sanctum_v if _ea_sanctum_v is Dictionary else {}
		var _ea_roster_v: Variant = _ea_sanctum.get("roster", [])
		var _ea_roster: Array = _ea_roster_v if _ea_roster_v is Array else []
		var _ea_party_ids_v: Variant = _ea_sanctum.get("active_party_ids", [])
		var _ea_party_ids: Array = _ea_party_ids_v if _ea_party_ids_v is Array else []
		var _ea_fear_sum  := 0
		var _ea_morale_sum := 0
		var _ea_count := 0
		for _ea_echo_v in _ea_roster:
			if not (_ea_echo_v is Dictionary):
				continue
			var _ea_echo: Dictionary = _ea_echo_v
			if str(_ea_echo.get("id", "")) not in _ea_party_ids:
				continue
			var _ea_emo_v: Variant = _ea_echo.get("emotion", {})
			var _ea_emo: Dictionary = _ea_emo_v if _ea_emo_v is Dictionary else {}
			_ea_fear_sum   += int(_ea_emo.get("fear_current",   0))
			_ea_morale_sum += int(_ea_emo.get("morale_current", 0))
			_ea_count += 1
		var _ea_avg_fear   := (_ea_fear_sum   / _ea_count) if _ea_count > 0 else 0
		var _ea_avg_morale := (_ea_morale_sum / _ea_count) if _ea_count > 0 else 0
		var _ea_flow_v: Variant = flow_ctx.save_data.get("flow", {})
		var _ea_flow: Dictionary = _ea_flow_v if _ea_flow_v is Dictionary else {}
		var _ea_directive := str(_ea_flow.get("active_directive", "directive.scout_carefully"))
		var _stage_ctx_v: Variant = flow_ctx.save_data.get("stage_context", {})
		var _stage_ctx: Dictionary = _stage_ctx_v if _stage_ctx_v is Dictionary else {}
		_stage_ctx["encounter_approach"] = {
			"turns_taken":             int(explore_map.get("turn_count", 0)),
			"directive_id":            _ea_directive,
			"situation_was_revealed":  _sit_was_revealed,
			"party_avg_fear":          _ea_avg_fear,
			"party_avg_morale":        _ea_avg_morale,
		}
		flow_ctx.save_data["stage_context"] = _stage_ctx
		flow_ctx.request_save("stage.encounter_approach")

		var _engage_reason := "stage.engage.shrine" if sit_type == ObjectiveModel.TYPE_SHRINE \
			else "stage.engage.combat"
		return { "outcome": "async", "reason": _engage_reason }

	# in_explore branch
	# V2-STAGE-003: NPC with contact dict → start conversation.
	if sit_type == SituationModel.TYPE_NPC:
		var _contact_dict_v: Variant = sit.get("contact", {})
		var _contact_dict: Dictionary = _contact_dict_v if _contact_dict_v is Dictionary else {}
		if not _contact_dict.is_empty():
			_contact_conversation_service().start_conversation(sit, sit_id, explore_map, stage, t)
			return { "outcome": "contact" }

	# V2-STAGE-004: resolve in-explore via SituationResolutionService.
	var _realm_seed := int(flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("seed", 0))
	var _res_rng := CampaignSeed.get_rng_from(_realm_seed, "stage.resolution.%s" % sit_id)

	var _sit_bal_v: Variant = config_service.get_balance().get("data", {})
	var _sit_bal: Dictionary = _sit_bal_v if _sit_bal_v is Dictionary else {}
	var _stages_cfg_v: Variant = _sit_bal.get("stages", {})
	var _stages_cfg: Dictionary = _stages_cfg_v if _stages_cfg_v is Dictionary else {}

	var _r := SituationResolutionService.resolve_in_explore(sit, _stages_cfg, _res_rng)

	if str(_r.get("panel_kind", "")) == "choice":
		# Do not resolve — player must pick a choice first.
		return {
			"outcome":      "choice",
			"situation_id": sit_id,
			"type":         sit_type,
			"choices":      _r.get("choices", []),
		}

	# acknowledge / take / leave — apply effects, resolve, then route to RESOLVE screen.
	var _in_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var _in_sanctum: Dictionary = _in_sanctum_v if _in_sanctum_v is Dictionary else {}
	var _in_roster_v: Variant = _in_sanctum.get("roster", [])
	var _in_roster: Array = _in_roster_v if _in_roster_v is Array else []
	var _in_party_ids_v: Variant = _in_sanctum.get("active_party_ids", [])
	var _in_party_ids: Array = _in_party_ids_v if _in_party_ids_v is Array else []
	var _in_fear_delta:   int = int(_r.get("fear_delta",   0))
	var _in_morale_delta: int = int(_r.get("morale_delta", 0))

	# P1 CLOSE: Capture pre-emotion status for each affected active party echo.
	var _in_pre_status: Dictionary = {}
	for _in_pre_v in _in_roster:
		if not (_in_pre_v is Dictionary):
			continue
		var _in_pre_e: Dictionary = _in_pre_v
		var _in_pre_id := str(_in_pre_e.get("id", ""))
		if _in_pre_id not in _in_party_ids:
			continue
		if _in_fear_delta == 0 and _in_morale_delta == 0:
			continue
		var _in_pre_emo_v: Variant = _in_pre_e.get("emotion", {})
		var _in_pre_emo: Dictionary = _in_pre_emo_v if _in_pre_emo_v is Dictionary else {}
		_in_pre_status[_in_pre_id] = EmotionService.get_emotional_status(
			int(_in_pre_emo.get("morale_current", 50)),
			int(_in_pre_emo.get("fear_current",   0))
		)

	for _in_echo_v in _in_roster:
		if not (_in_echo_v is Dictionary):
			continue
		var _in_echo: Dictionary = _in_echo_v
		if str(_in_echo.get("id", "")) not in _in_party_ids:
			continue
		if _in_fear_delta != 0:
			EmotionService.apply_fear_delta(_in_echo, _in_fear_delta,
				"situation." + sit_type, 80, logger, t)
		if _in_morale_delta != 0:
			EmotionService.apply_morale_delta(_in_echo, _in_morale_delta,
				"situation." + sit_type, logger, t)

	if int(_r.get("ase_delta", 0)) > 0:
		econ.add_ase(int(_r.get("ase_delta", 0)), "situation.money", logger, t)

	var _loot_results_v: Variant = _r.get("loot_results", [])
	var _loot_results: Array = _loot_results_v if _loot_results_v is Array else []
	if _loot_results.size() > 0:
		var _em_loot_v: Variant = explore_map.get("loot_results", [])
		var _em_loot: Array = _em_loot_v if _em_loot_v is Array else []
		for _loot_entry in _loot_results:
			_em_loot.append(_loot_entry)
		explore_map["loot_results"] = _em_loot

	# Mark resolved and update objectives if applicable.
	for _ri2 in range(situations.size()):
		var _sv2: Variant = situations[_ri2]
		if _sv2 is Dictionary and str((_sv2 as Dictionary).get("id", "")) == sit_id:
			var _s2: Dictionary = _sv2
			_s2["resolved"] = true
			situations[_ri2] = _s2
			break
	if bool(sit.get("is_objective", false)):
		explore_map["objectives_found"] = int(explore_map.get("objectives_found", 0)) + 1
	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.resolve_in_explore")

	# P1 CLOSE: Build emotion_summary (post deltas applied).
	var _in_emotion_summary: Array = []
	# Compute direction from the situation's deltas (uniform for all echoes).
	var _in_direction: String
	if _in_morale_delta > 0:
		_in_direction = "lift"
	elif _in_fear_delta < 0:
		_in_direction = "ease"
	elif _in_morale_delta < 0 or _in_fear_delta > 0:
		_in_direction = "fall"
	else:
		_in_direction = "steady"
	for _in_post_v in _in_roster:
		if not (_in_post_v is Dictionary):
			continue
		var _in_post_e: Dictionary = _in_post_v
		var _in_post_id := str(_in_post_e.get("id", ""))
		if _in_post_id not in _in_party_ids:
			continue
		if not _in_pre_status.has(_in_post_id):
			continue
		var _in_post_emo_v: Variant = _in_post_e.get("emotion", {})
		var _in_post_emo: Dictionary = _in_post_emo_v if _in_post_emo_v is Dictionary else {}
		_in_emotion_summary.append({
			"echo_id":               _in_post_id,
			"name":                  str(_in_post_e.get("name", "")),
			"pre_emotional_status":  _in_pre_status[_in_post_id],
			"post_emotional_status": EmotionService.get_emotional_status(
				int(_in_post_emo.get("morale_current", 50)),
				int(_in_post_emo.get("fear_current",   0))
			),
			"direction": _in_direction,
			"tag":       "",
		})

	# P1 CLOSE: Build effects array.
	var _in_effects: Array = []
	# Loot kind chips.
	for _loot_chip in _loot_results:
		if _loot_chip is Dictionary:
			var _loot_kind := str((_loot_chip as Dictionary).get("kind", ""))
			if not _loot_kind.is_empty():
				_in_effects.append({
					"kind":  "item",
					"label": _loot_kind.capitalize(),
					"value": "",
					"tone":  "item",
				})
	# Intel clue chip (first clue, if any).
	var _in_clues_v: Variant = sit.get("intel_clues", [])
	var _in_clues: Array = _in_clues_v if _in_clues_v is Array else []
	if _in_clues.size() > 0 and not str(_in_clues[0]).is_empty():
		_in_effects.append({
			"kind":  "intel",
			"label": str(_in_clues[0]),
			"value": "",
			"tone":  "intel",
		})

	# P1 CLOSE: Transition to RESOLVE screen instead of overlay.
	return {
		"outcome":         "resolved",
		"sit":             sit,
		"emotion_summary": _in_emotion_summary,
		"effects":         _in_effects,
		"summary_line":    str(_r.get("result_text", "")),
		"ase_awarded":     int(_r.get("ase_delta", 0)),
	}


# ---------------------------------------------------------------------------
# stage.resolve_situation_choice
# ---------------------------------------------------------------------------

## The body of FlowRuntime._handle_stage_resolve_situation_choice(), moved verbatim minus its
## transition tail. Returns { "outcome": "invalid" } or the same "resolved" verdict shape
## engage_situation() returns, so VentureController translates both through one code path.
func resolve_situation_choice(sit_id: String, choice_id: String, t: int) -> Dictionary:
	if sit_id.is_empty() or choice_id.is_empty():
		logger.debug(t, "stage.resolve_choice.invalid", "resolve_situation_choice: missing payload", {
			"situation_id": sit_id, "choice_id": choice_id
		})
		return { "outcome": "invalid" }

	var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
	if stage.is_empty():
		return { "outcome": "invalid" }

	var map_v: Variant = stage.get("explore_map", {})
	var explore_map: Dictionary = map_v if map_v is Dictionary else {}
	var sits_v: Variant = explore_map.get("situations", [])
	var situations: Array = sits_v if sits_v is Array else []

	# Find the situation.
	var sit: Dictionary = {}
	for _sv in situations:
		if _sv is Dictionary and str((_sv as Dictionary).get("id", "")) == sit_id:
			sit = _sv
			break

	if sit.is_empty():
		logger.debug(t, "stage.resolve_choice.not_found", "resolve_situation_choice: situation not found", {
			"situation_id": sit_id
		})
		return { "outcome": "invalid" }

	var sit_type := str(sit.get("type", ""))

	# Seeded rng — same namespace as resolve_in_explore (no draws made in resolve_choice currently).
	var _realm_seed := int(flow_ctx.save_data.get("realms", {}).get(flow_ctx.realm_id, {}).get("seed", 0))
	var _rng := CampaignSeed.get_rng_from(_realm_seed, "stage.resolution.%s" % sit_id)

	var _sit_bal_v: Variant = config_service.get_balance().get("data", {})
	var _sit_bal: Dictionary = _sit_bal_v if _sit_bal_v is Dictionary else {}
	var _stages_cfg_v: Variant = _sit_bal.get("stages", {})
	var _stages_cfg: Dictionary = _stages_cfg_v if _stages_cfg_v is Dictionary else {}

	var _c := SituationResolutionService.resolve_choice(sit, choice_id, _stages_cfg, _rng)

	# P1 CLOSE: Capture pre-emotion status before applying choice deltas.
	var _rc_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var _rc_sanctum: Dictionary = _rc_sanctum_v if _rc_sanctum_v is Dictionary else {}
	var _rc_roster_v: Variant = _rc_sanctum.get("roster", [])
	var _rc_roster: Array = _rc_roster_v if _rc_roster_v is Array else []
	var _rc_party_ids_v: Variant = _rc_sanctum.get("active_party_ids", [])
	var _rc_party_ids: Array = _rc_party_ids_v if _rc_party_ids_v is Array else []
	var _rc_fear_delta:   int = int(_c.get("fear_delta",   0))
	var _rc_morale_delta: int = int(_c.get("morale_delta", 0))

	var _rc_pre_status: Dictionary = {}
	for _rc_pre_v in _rc_roster:
		if not (_rc_pre_v is Dictionary):
			continue
		var _rc_pre_e: Dictionary = _rc_pre_v
		var _rc_pre_id := str(_rc_pre_e.get("id", ""))
		if _rc_pre_id not in _rc_party_ids:
			continue
		if _rc_fear_delta == 0 and _rc_morale_delta == 0:
			continue
		var _rc_pre_emo_v: Variant = _rc_pre_e.get("emotion", {})
		var _rc_pre_emo: Dictionary = _rc_pre_emo_v if _rc_pre_emo_v is Dictionary else {}
		_rc_pre_status[_rc_pre_id] = EmotionService.get_emotional_status(
			int(_rc_pre_emo.get("morale_current", 50)),
			int(_rc_pre_emo.get("fear_current",   0))
		)

	# Apply emotion effects to active party.
	for _rc_echo_v in _rc_roster:
		if not (_rc_echo_v is Dictionary):
			continue
		var _rc_echo: Dictionary = _rc_echo_v
		if str(_rc_echo.get("id", "")) not in _rc_party_ids:
			continue
		if _rc_fear_delta != 0:
			EmotionService.apply_fear_delta(_rc_echo, _rc_fear_delta,
				"situation." + sit_type, 80, logger, t)
		if _rc_morale_delta != 0:
			EmotionService.apply_morale_delta(_rc_echo, _rc_morale_delta,
				"situation." + sit_type, logger, t)

	# Advance turn count by choice's turn_cost.
	explore_map["turn_count"] = int(explore_map.get("turn_count", 0)) + int(_c.get("turn_cost", 0))

	# Mark situation resolved.
	for _ri3 in range(situations.size()):
		var _sv3: Variant = situations[_ri3]
		if _sv3 is Dictionary and str((_sv3 as Dictionary).get("id", "")) == sit_id:
			var _s3: Dictionary = _sv3
			_s3["resolved"] = true
			situations[_ri3] = _s3
			break
	explore_map["situations"] = situations
	stage["explore_map"] = explore_map
	FlowStageExploreStateScript._write_stage_back(flow_ctx, stage)
	flow_ctx.request_save("stage.resolve_choice")

	# P1 CLOSE: Build emotion_summary and effects, then route to RESOLVE screen.
	var _rc_emotion_summary: Array = []
	var _rc_direction: String
	if _rc_morale_delta > 0:
		_rc_direction = "lift"
	elif _rc_fear_delta < 0:
		_rc_direction = "ease"
	elif _rc_morale_delta < 0 or _rc_fear_delta > 0:
		_rc_direction = "fall"
	else:
		_rc_direction = "steady"
	for _rc_post_v in _rc_roster:
		if not (_rc_post_v is Dictionary):
			continue
		var _rc_post_e: Dictionary = _rc_post_v
		var _rc_post_id := str(_rc_post_e.get("id", ""))
		if _rc_post_id not in _rc_party_ids:
			continue
		if not _rc_pre_status.has(_rc_post_id):
			continue
		var _rc_post_emo_v: Variant = _rc_post_e.get("emotion", {})
		var _rc_post_emo: Dictionary = _rc_post_emo_v if _rc_post_emo_v is Dictionary else {}
		_rc_emotion_summary.append({
			"echo_id":               _rc_post_id,
			"name":                  str(_rc_post_e.get("name", "")),
			"pre_emotional_status":  _rc_pre_status[_rc_post_id],
			"post_emotional_status": EmotionService.get_emotional_status(
				int(_rc_post_emo.get("morale_current", 50)),
				int(_rc_post_emo.get("fear_current",   0))
			),
			"direction": _rc_direction,
			"tag":       "",
		})

	# Turn-cost chip for find_route / any turn_cost > 0.
	var _rc_effects: Array = []
	var _rc_turn_cost := int(_c.get("turn_cost", 0))
	if _rc_turn_cost > 0 or choice_id == "find_route":
		_rc_effects.append({
			"kind":  "objective",
			"label": "+%d turn" % _rc_turn_cost,
			"value": "",
			"tone":  "objective",
		})

	return {
		"outcome":         "resolved",
		"sit":             sit,
		"emotion_summary": _rc_emotion_summary,
		"effects":         _rc_effects,
		"summary_line":    str(_c.get("result_text", "")),
		"ase_awarded":     0,
	}

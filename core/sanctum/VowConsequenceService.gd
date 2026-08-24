# res://core/sanctum/VowConsequenceService.gd
# V2-INFRA-003 Phase 4 Slice 2: flow-level vow consequence orchestration extracted out of
# FlowRuntime.gd, following the WeaveController extraction pattern (see
# core/runtime/controllers/WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - Never calls SaveService directly — requests saves via flow_ctx.request_save(reason),
#     the same choke point FlowRuntime._mark_save_requested() itself calls.
#   - No UI or scene-tree reference. No flow_machine reference — this class does not (and
#     structurally cannot) transition state or rebuild a snapshot. It only mutates
#     flow_ctx.save_data / flow_ctx.vow_outcome / flow_ctx.session_* fields, the same
#     surface these methods mutated as private FlowRuntime methods.
#
# THIS IS A SERVICE, NOT A CONTROLLER. The eight methods below are consequence hooks called
# from several different call sites — stage entry (flow.go_state → STAGE_EXPLORE), situation
# engagement (stage.engage_situation), stage completion (_handle_complete_stage), combat
# round resolution (final-snapshot build), and return-to-Sanctum paths (defeat go_state,
# victory _handle_complete_stage, retreat). None of them are triggered by a dispatched vow.*
# action — that's VowController's job (vow.pledge, vow.break, debug.vow.unlock). Because
# these hooks are invoked from several unrelated domains (stage/venture, encounter,
# resolve), putting them on VowController would force those domains' controllers to call
# into VowController — and controller-to-controller calls are forbidden. A service has no
# such restriction: anyone may call it.
#
# Moved verbatim (behaviour unchanged) from FlowRuntime.gd:
#   _check_vow_discovery              → check_vow_discovery
#   _apply_vow_stage_entry_condition  → apply_vow_stage_entry_condition
#   _apply_vow_engage_condition       → apply_vow_engage_condition
#   _apply_vow_stage_complete_benefit → apply_vow_stage_complete_benefit
#   _apply_vow_emotion_to_party       → _apply_vow_emotion_to_party (private helper)
#   _apply_vow_break_aftermath        → apply_vow_break_aftermath (public — VowController's
#                                        handle_break() calls this after VowService.break_vow())
#   _store_vow_benefit_preview        → store_vow_benefit_preview
#   _check_vow_release_condition      → check_vow_release_condition
#   _get_roster_echo_ids              → _get_roster_echo_ids (private helper, only used by
#                                        apply_vow_break_aftermath)
#
# core/sanctum/VowService.gd already exists and stays exactly as it is — it holds vow DOMAIN
# rules (pledge/break/release/unlock, condition evaluation). This class holds the FLOW-level
# orchestration that decides WHEN those domain rules run and how their results are threaded
# into save_data / vow_outcome / session state for the UI to read.
#
# V2-INFRA-003 Phase 4 Slice 3: this file used to carry a private _write_sanctum_bark_for_echo,
# a scoped copy of FlowRuntime._select_sanctum_bark_for_echo_data_and_write, added in Slice 2
# because that helper was still private on FlowRuntime and shared by non-vow call sites out of
# Slice 2's scope. It has been deleted; apply_vow_stage_entry_condition() now calls
# NarrativeVoiceService.select_sanctum_bark_for_echo_data_and_write() (core/echoes/
# NarrativeVoiceService.gd) via the _voice_service() helper below — the real owner of that
# helper now that it, and its sibling bark/snippet helpers, have moved off FlowRuntime.

class_name VowConsequenceService
extends RefCounted

const FlowVowStateScript          := preload("res://core/state/flow/states/sanctum/FlowVowState.gd")
const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var econ: EconomyService
var logger: StructuredLogger


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _econ: EconomyService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	econ = _econ
	logger = _logger


# VOW-001: Check if any vow was discovered by a scenario condition during this stage.
# Called from _handle_complete_stage after stage data is finalized.
func check_vow_discovery(t: int) -> void:
	var cfg := config_service.get_balance()
	var defs := VowService.get_definitions(cfg)
	if defs.is_empty():
		return

	var unlocked := VowService.get_unlocked_vows(flow_ctx.save_data)

	# Determine combat outcome from the final resolve snapshot.
	var _last_snap_data_v: Variant = flow_ctx.last_snapshot.get("data", {})
	var _last_snap_data: Dictionary = _last_snap_data_v if _last_snap_data_v is Dictionary else {}
	var is_victory := bool(_last_snap_data.get("victory", false))

	# Collect party actor dicts from ectx.actors — use runtime actors (not save roster) so
	# is_dead reflects actual combat deaths (is_dead is runtime-only, never written to save).
	# ectx is still non-null here; it is nulled immediately after check_vow_discovery returns.
	var party_ids: Array = []
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if sanctum_v is Dictionary:
		var p_v: Variant = (sanctum_v as Dictionary).get("active_party_ids", [])
		if p_v is Array:
			party_ids = p_v

	var party_actors: Array = []
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx != null:
		for a_v in ectx.actors:
			if not (a_v is Dictionary):
				continue
			var a: Dictionary = a_v
			if str(a.get("faction", "")) == "echo" and party_ids.has(str(a.get("id", ""))):
				party_actors.append(a)

	# Gather current stage situations (already updated by situation write-back before this call).
	var situations: Array = []
	if not flow_ctx.stage_id.is_empty():
		var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
		if not stage.is_empty():
			var map_v: Variant = stage.get("explore_map", {})
			if map_v is Dictionary:
				var sits_v: Variant = (map_v as Dictionary).get("situations", [])
				if sits_v is Array:
					situations = sits_v

	for vow_id in defs:
		if unlocked.has(vow_id):
			continue
		var defn_v: Variant = defs[vow_id]
		if not (defn_v is Dictionary):
			continue
		var scenario := str((defn_v as Dictionary).get("unlock_scenario", ""))
		if VowService.evaluate_discovery_scenario(scenario, party_actors, situations, is_victory):
			VowService.unlock_vow(vow_id, flow_ctx.realm_id, flow_ctx.save_data, flow_ctx, logger, t)
			# V2-VOW-002: record in session list for "Discovered" badge and ResolveScreen reveal.
			# and "Discovered" badge on VowScreen. Resets on new FlowContext (new boot).
			var _disc_defn := VowService.get_definition(vow_id, cfg)
			if not _disc_defn.is_empty():
				flow_ctx.session_unlocked_vows.append({
					"vow_id":      vow_id,
					"vow_name":    str(_disc_defn.get("vow_name", "")),
					"proverb_twi": str(_disc_defn.get("proverb_twi", "")),
					"proverb_en":  str(_disc_defn.get("proverb_en", "")),
				})


# VOW-001 / V2-VOW-002: Apply stage-entry vow condition (party size / calling diversity).
# Called from flow.go_state → STAGE_EXPLORE (covers first entry and re-entry after defeat).
func apply_vow_stage_entry_condition(t: int) -> void:
	# V2-VOW-002: tick guard — prevents double-fire if two paths both route through STAGE_EXPLORE.
	if t == flow_ctx.vow_entry_check_t:
		return
	flow_ctx.vow_entry_check_t = t

	# V2-VOW-002: clear transient state from previous stage entry.
	flow_ctx.vow_outcome = {}
	flow_ctx.session_broken_vow_effect = {}
	# Also clear the persisted debuff chip from save_data.
	var _clear_sanc_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if _clear_sanc_v is Dictionary:
		(_clear_sanc_v as Dictionary).erase("pending_broken_vow_effect")

	var av := VowService.get_active_vow(flow_ctx.save_data)
	if av.is_empty():
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []

	var cfg: Dictionary = config_service.get_balance()
	var result := VowService.evaluate_stage_condition(flow_ctx.save_data, party_ids, cfg)

	var status := str(result.get("status", "none"))
	if status == "none":
		return

	# V2-VOW-002: on compliant entry, increment compliance_count + lifetime honors.
	if status == "compliant":
		var _s_v: Variant = flow_ctx.save_data.get("sanctum", {})
		if _s_v is Dictionary:
			var _av_s: Dictionary = (_s_v as Dictionary).get("active_vow", {})
			if not _av_s.is_empty():
				var _new_count := int(_av_s.get("compliance_count", 0)) + 1
				_av_s["compliance_count"] = _new_count
				(_s_v as Dictionary)["active_vow"] = _av_s
				flow_ctx.save_data["sanctum"] = _s_v
			# Increment lifetime vow_stats.honors (direct index — .get() returns a temp copy).
			var _sanc_h: Dictionary = _s_v as Dictionary
			if not _sanc_h.has("vow_stats") or not (_sanc_h["vow_stats"] is Dictionary):
				_sanc_h["vow_stats"] = {"honors": 0, "breaks": 0}
			var _vstats_h: Dictionary = _sanc_h["vow_stats"]
			_vstats_h["honors"] = int(_vstats_h.get("honors", 0)) + 1
		# Store vow_outcome for the ResolveScreen (compliant event).
		if flow_ctx.vow_outcome.is_empty():
			var _vow_id := str(av.get("vow_id", ""))
			var _defn   := VowService.get_definition(_vow_id, cfg)
			flow_ctx.vow_outcome = {
				"event":       "compliant",
				"vow_id":      _vow_id,
				"vow_name":    str(_defn.get("vow_name", "")),
				"tier":        int(av.get("tier", 1)),
				"morale_delta": int(result.get("morale_delta", 0)),
				"fear_delta":   int(result.get("fear_delta", 0)),
				"compliance_count": int(flow_ctx.save_data.get("sanctum", {})
					.get("active_vow", {}).get("compliance_count", 0)),
			}

	# Apply morale / fear deltas to all party echoes
	var morale_d := int(result.get("morale_delta", 0))
	var fear_d   := int(result.get("fear_delta", 0))
	_apply_vow_emotion_to_party(party_ids, morale_d, fear_d, "vow.condition." + status, cfg, t)

	# V2-VOW-002: compliance tracking — increment count and record outcome for resolve screen.
	if status == "compliant":
		var _s_v: Variant = flow_ctx.save_data.get("sanctum", {})
		var _new_count := 0
		if _s_v is Dictionary:
			var _av_s: Dictionary = (_s_v as Dictionary).get("active_vow", {})
			if not _av_s.is_empty():
				_new_count = int(_av_s.get("compliance_count", 0)) + 1
				_av_s["compliance_count"] = _new_count
				(_s_v as Dictionary)["active_vow"] = _av_s
		# Store compliant vow_outcome only if break hasn't already set it (break takes precedence).
		if flow_ctx.vow_outcome.is_empty():
			var _av_c := VowService.get_active_vow(flow_ctx.save_data)
			var _defn_c := VowService.get_definition(str(_av_c.get("vow_id", "")), cfg)
			flow_ctx.vow_outcome = {
				"event":            "compliant",
				"vow_id":           str(_av_c.get("vow_id", "")),
				"vow_name":         str(_defn_c.get("vow_name", "")),
				"proverb_twi":      str(_defn_c.get("proverb_twi", "")),
				"tier":             int(_av_c.get("tier", 1)),
				"morale_delta":     morale_d,
				"fear_delta":       0,
				"bond_score_delta": 0,
				"ase_delta":        0,
				"echoes_affected":  party_ids,
				"compliance_count": _new_count,
			}

	# V2-VOICE-001: vow stage-entry bark from party leader (or first party echo).
	if status in ["benefit", "penalty"]:
		var _vow_bark_ctx := "vow." + status
		var _vow_roster_v: Variant = sanctum.get("roster", [])
		var _vow_roster: Array = _vow_roster_v if _vow_roster_v is Array else []
		# Find party leader (first echo in active_party_ids that is in roster).
		var _vow_speaker: Dictionary = {}
		for _pid in party_ids:
			for _re in _vow_roster:
				if _re is Dictionary and str((_re as Dictionary).get("id", "")) == str(_pid):
					_vow_speaker = _re
					break
			if not _vow_speaker.is_empty():
				break
		if not _vow_speaker.is_empty():
			_voice_service().select_sanctum_bark_for_echo_data_and_write(_vow_speaker, _vow_bark_ctx, t, _vow_roster)
			sanctum["roster"] = _vow_roster
			flow_ctx.save_data["sanctum"] = sanctum

	var should_break := bool(result.get("should_auto_break", false))

	var log_type := "vow.condition.auto_break" if should_break else ("vow.condition." + status)
	logger.info(t, log_type, "Vow stage condition evaluated", {
		"vow_id":      str(av.get("vow_id", "")),
		"status":      status,
		"party_size":  party_ids.size(),
		"auto_break":  should_break,
	})
	flow_ctx.request_save()

	if should_break:
		var summary := VowService.break_vow(cfg, flow_ctx.save_data, flow_ctx, econ, logger, t)
		if not summary.is_empty():
			apply_vow_break_aftermath(summary, cfg, t)


# VOW-001: Apply situation-engagement vow condition (obi_nnim_kyere revealed check).
# sit_was_revealed: captured BEFORE the engagement mutation sets revealed=true.
func apply_vow_engage_condition(sit_was_revealed: bool, t: int) -> void:
	var av := VowService.get_active_vow(flow_ctx.save_data)
	if av.is_empty():
		return

	# Build a minimal situation dict reflecting the pre-engagement revealed state.
	var sit_peek := { "revealed": sit_was_revealed }
	var cfg := config_service.get_balance()
	var result := VowService.evaluate_engage_condition(
		flow_ctx.save_data, sit_peek, flow_ctx.stage_id, cfg
	)

	var status := str(result.get("status", "none"))
	if status == "none":
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var party_ids: Array = []
	if sanctum_v is Dictionary:
		var party_v: Variant = (sanctum_v as Dictionary).get("active_party_ids", [])
		if party_v is Array:
			party_ids = party_v

	var morale_d := int(result.get("morale_delta", 0))
	var fear_d   := int(result.get("fear_delta", 0))
	_apply_vow_emotion_to_party(party_ids, morale_d, fear_d, "vow.engage." + status, cfg, t)

	var should_break := bool(result.get("should_auto_break", false))
	logger.info(t, "vow.engage." + status, "Vow engage condition evaluated", {
		"vow_id":     str(av.get("vow_id", "")),
		"status":     status,
		"revealed":   sit_was_revealed,
		"auto_break": should_break,
	})
	flow_ctx.request_save()

	if should_break:
		var summary := VowService.break_vow(cfg, flow_ctx.save_data, flow_ctx, econ, logger, t)
		if not summary.is_empty():
			apply_vow_break_aftermath(summary, cfg, t)


# VOW-001: Apply post-stage completion vow benefit (obi_nnim_kyere full-scout bonus).
func apply_vow_stage_complete_benefit(t: int) -> void:
	var av := VowService.get_active_vow(flow_ctx.save_data)
	if av.is_empty():
		return

	var cfg := config_service.get_balance()

	# Gather current stage situations for the full-scout check.
	var situations: Array = []
	if not flow_ctx.stage_id.is_empty():
		var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
		if not stage.is_empty():
			var map_v: Variant = stage.get("explore_map", {})
			if map_v is Dictionary:
				var sits_v: Variant = (map_v as Dictionary).get("situations", [])
				if sits_v is Array:
					situations = sits_v

	var result := VowService.evaluate_stage_complete_benefit(flow_ctx.save_data, situations, cfg)
	var morale_d := int(result.get("morale_delta", 0))
	if morale_d == 0:
		return

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var party_ids: Array = []
	if sanctum_v is Dictionary:
		var party_v: Variant = (sanctum_v as Dictionary).get("active_party_ids", [])
		if party_v is Array:
			party_ids = party_v

	_apply_vow_emotion_to_party(party_ids, morale_d, 0, "vow.stage_complete.benefit", cfg, t)
	logger.info(t, "vow.stage_complete.benefit", "Vow full-scout bonus applied", {
		"vow_id":      str(av.get("vow_id", "")),
		"morale_delta": morale_d,
	})
	# V2-VOW-002: store vow_outcome for resolve screen (overwrites preview set by store_vow_benefit_preview).
	var _defn_b := VowService.get_definition(str(av.get("vow_id", "")), cfg)
	flow_ctx.vow_outcome = {
		"event":            "benefit",
		"vow_id":           str(av.get("vow_id", "")),
		"vow_name":         str(_defn_b.get("vow_name", "")),
		"proverb_twi":      str(_defn_b.get("proverb_twi", "")),
		"tier":             int(av.get("tier", 1)),
		"morale_delta":     morale_d,
		"fear_delta":       0,
		"bond_score_delta": 0,
		"ase_delta":        0,
		"echoes_affected":  party_ids,
	}
	flow_ctx.request_save()


# VOW-001: Shared helper — applies morale/fear deltas to party echoes via EmotionService.
func _apply_vow_emotion_to_party(
	party_ids: Array,
	morale_d:  int,
	fear_d:    int,
	cause:     String,
	cfg:       Dictionary,
	t:         int
) -> void:
	if morale_d == 0 and fear_d == 0:
		return
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var roster_v: Variant = (sanctum_v as Dictionary).get("roster", [])
	if not (roster_v is Array):
		return
	var fear_threshold := int(cfg.get("data", {}).get("emotion", {}).get("fear_threshold", 80))
	for echo_v in (roster_v as Array):
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		if not party_ids.has(str(echo.get("id", ""))):
			continue
		if morale_d != 0:
			EmotionService.apply_morale_delta(echo, morale_d, cause, logger, t)
		if fear_d != 0:
			EmotionService.apply_fear_delta(echo, fear_d, cause, fear_threshold, logger, t)


# VOW-001: Apply EmotionRecoveryService.set_modifier on vow break (shared between manual and
# auto-break paths). Public: VowController.handle_break() calls this after VowService.break_vow()
# succeeds, since a controller may call a service (only controller-to-controller calls are
# forbidden).
func apply_vow_break_aftermath(summary: Dictionary, cfg: Dictionary, t: int) -> void:
	# V2-VOW-002: write vow_outcome for ResolveScreen "The promise fractured." section.
	var _break_vow_id := str(summary.get("vow_id", ""))
	var _break_defn   := VowService.get_definition(_break_vow_id, cfg)
	var _break_name   := str(_break_defn.get("vow_name", ""))
	flow_ctx.vow_outcome = {
		"event":       "break",
		"vow_id":      _break_vow_id,
		"vow_name":    _break_name,
		"tier":        int(summary.get("tier", 1)),
		"morale_delta": int(summary.get("morale_delta", 0)),
		"fear_delta":   int(summary.get("fear_delta", 0)),
		"ase_delta":    -int(summary.get("ase_spent", 0)),
	}
	# V2-VOW-002: transient debuff chip for the Sanctum Active Effects panel.
	# Cleared on the next stage entry (apply_vow_stage_entry_condition).
	var _break_morale := int(summary.get("morale_delta", 0))
	var _break_fear   := int(summary.get("fear_delta",   0))
	var _break_ase    := -int(summary.get("ase_spent",   0))
	var _break_body   := "Applied to all echoes in your roster:"
	if _break_morale != 0:
		_break_body += "\nMorale %+d" % _break_morale
	if _break_fear != 0:
		_break_body += "\nFear %+d" % _break_fear
	if _break_ase != 0:
		_break_body += "\n%+d Ase" % _break_ase
	flow_ctx.session_broken_vow_effect = {
		"effect_id":    "vow_broken",
		"label":        _break_name,
		"direction":    "debuff",
		"headline":     "Vow Broken — " + _break_name,
		"body":         _break_body,
		"duration_hint": "Clears when you re-enter a stage.",
		"source":       "vow",
	}
	# V2-VOW-002: persist the debuff chip to save_data so it survives restarts.
	var _pbe_sanc_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if _pbe_sanc_v is Dictionary:
		(_pbe_sanc_v as Dictionary)["pending_broken_vow_effect"] = flow_ctx.session_broken_vow_effect.duplicate()
		# Set pledge cooldown from config (tuneable: data.vows.pledge_cooldown_stages).
		var _cd_vows_v: Variant = cfg.get("data", {})
		var _cd_vows: Dictionary = {}
		if _cd_vows_v is Dictionary:
			var _cd_data: Dictionary = _cd_vows_v as Dictionary
			var _cd_v: Variant = _cd_data.get("vows", {})
			if _cd_v is Dictionary:
				_cd_vows = _cd_v as Dictionary
		var _cd_stages := int(_cd_vows.get("pledge_cooldown_stages", 1))
		(_pbe_sanc_v as Dictionary)["pledge_cooldown_stages_remaining"] = _cd_stages
	# V2-VOW-002: increment lifetime breaks count (direct index — .get() returns a temp copy).
	if _pbe_sanc_v is Dictionary:
		var _sanc_b: Dictionary = _pbe_sanc_v as Dictionary
		if not _sanc_b.has("vow_stats") or not (_sanc_b["vow_stats"] is Dictionary):
			_sanc_b["vow_stats"] = {"honors": 0, "breaks": 0}
		var _vstats_b: Dictionary = _sanc_b["vow_stats"]
		_vstats_b["breaks"] = int(_vstats_b.get("breaks", 0)) + 1

	# Also apply immediate morale/fear to roster (same as VowController.handle_break() manual path).
	var morale_d := int(summary.get("morale_delta", 0))
	var fear_d   := int(summary.get("fear_delta", 0))
	var recovery_cfg_v: Variant = cfg.get("data", {})
	var recovery_cfg: Dictionary = {}
	if recovery_cfg_v is Dictionary:
		var em_v: Variant = (recovery_cfg_v as Dictionary).get("emotion", {})
		if em_v is Dictionary:
			var rec_v: Variant = (em_v as Dictionary).get("recovery", {})
			if rec_v is Dictionary:
				recovery_cfg = rec_v

	var vow_morale_mul := float(recovery_cfg.get("modifier_vow_break_morale_mul", 0.5))
	var vow_fear_mul   := float(recovery_cfg.get("modifier_vow_break_fear_mul", 0.5))
	var mod_ticks      := int(recovery_cfg.get("modifier_ticks_duration", 120))
	var fear_threshold := int(cfg.get("data", {}).get("emotion", {}).get("fear_threshold", 80))

	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var roster_v: Variant = (sanctum_v as Dictionary).get("roster", [])
	if not (roster_v is Array):
		return

	for echo_v in (roster_v as Array):
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		if morale_d != 0:
			EmotionService.apply_morale_delta(echo, morale_d, "vow.break", logger, t)
		if fear_d != 0:
			EmotionService.apply_fear_delta(echo, fear_d, "vow.break", fear_threshold, logger, t)
		EmotionRecoveryService.set_modifier(echo, vow_morale_mul, vow_fear_mul, mod_ticks, logger, t)

	# V2-VOW-002: enrich vow_outcome with proverb_twi, bond_score_delta, echoes_affected.
	flow_ctx.vow_outcome["proverb_twi"]      = str(_break_defn.get("proverb_twi", ""))
	flow_ctx.vow_outcome["bond_score_delta"] = int(summary.get("bond_score_delta", 0))
	flow_ctx.vow_outcome["echoes_affected"]  = _get_roster_echo_ids()

	# V2-CONTINUITY-001: Vow break costs Continuity. Stacks every time.
	var _vb_cont_cfg := ConfigService.get_continuity_cfg(config_service)
	var _vb_pen      := int(_vb_cont_cfg.get("vow_break_penalty", 3))
	ContinuityService.apply_penalty(flow_ctx.save_data, _vb_pen, "vow.break", logger, t)


## V2-INFRA-003 Phase 4 Slice 3: builds a fresh NarrativeVoiceService scoped to the current
## flow_ctx/config_service/logger. Replaces the private _write_sanctum_bark_for_echo that used
## to live here — a byte-for-byte scoped copy of FlowRuntime._select_sanctum_bark_for_echo_
## data_and_write, called out in that method's old doc-comment as a deliberate-for-now
## duplication. NarrativeVoiceService.select_sanctum_bark_for_echo_data_and_write() is now the
## one real owner; this is a service calling a service (no restriction on that, unlike
## controller-to-controller calls).
func _voice_service() -> NarrativeVoiceService:
	return NarrativeVoiceService.new(flow_ctx, config_service, logger)


## V2-VOW-002: Pure probe — evaluates whether a stage-complete vow benefit is due and stores a
## provisional vow_outcome on FlowContext so build_final_snapshot() can include it in the
## resolve snapshot. No emotion mutations here; actual deltas are applied later by
## apply_vow_stage_complete_benefit() inside _handle_complete_stage().
func store_vow_benefit_preview(t: int) -> void:
	var av := VowService.get_active_vow(flow_ctx.save_data)
	if av.is_empty():
		return
	# Do not overwrite a break outcome already stored this stage.
	if not flow_ctx.vow_outcome.is_empty():
		return
	var cfg := config_service.get_balance()
	var situations: Array = []
	if not flow_ctx.stage_id.is_empty():
		var stage := FlowStageExploreStateScript._get_current_stage(flow_ctx)
		if not stage.is_empty():
			var map_v: Variant = stage.get("explore_map", {})
			if map_v is Dictionary:
				var sits_v: Variant = (map_v as Dictionary).get("situations", [])
				if sits_v is Array:
					situations = sits_v
	var result := VowService.evaluate_stage_complete_benefit(flow_ctx.save_data, situations, cfg)
	var morale_d := int(result.get("morale_delta", 0))
	if morale_d == 0:
		return  # no benefit due — leave vow_outcome empty
	var defn := VowService.get_definition(str(av.get("vow_id", "")), cfg)
	var party_ids: Array = []
	var sanctum_vp: Variant = flow_ctx.save_data.get("sanctum", {})
	if sanctum_vp is Dictionary:
		var p_v: Variant = (sanctum_vp as Dictionary).get("active_party_ids", [])
		if p_v is Array:
			party_ids = p_v
	flow_ctx.vow_outcome = {
		"event":            "benefit",
		"vow_id":           str(av.get("vow_id", "")),
		"vow_name":         str(defn.get("vow_name", "")),
		"proverb_twi":      str(defn.get("proverb_twi", "")),
		"tier":             int(av.get("tier", 1)),
		"morale_delta":     morale_d,
		"fear_delta":       0,
		"bond_score_delta": 0,
		"ase_delta":        0,
		"echoes_affected":  party_ids,
	}


## V2-VOW-002: Returns Array of echo id Strings from the save-data roster.
## Used by apply_vow_break_aftermath() to populate vow_outcome.echoes_affected.
func _get_roster_echo_ids() -> Array:
	var ids: Array = []
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return ids
	var roster_v: Variant = (sanctum_v as Dictionary).get("roster", [])
	if not (roster_v is Array):
		return ids
	for echo_v in (roster_v as Array):
		if echo_v is Dictionary:
			ids.append(str((echo_v as Dictionary).get("id", "")))
	return ids


func check_vow_release_condition(t: int) -> bool:
	var active_vow := VowService.get_active_vow(flow_ctx.save_data)
	if active_vow.is_empty():
		return false
	var vow_outcome_v: Variant = flow_ctx.save_data.get("flow", {})
	if vow_outcome_v is Dictionary:
		var vow_outcome_dict: Dictionary = (vow_outcome_v as Dictionary).get("vow_outcome", {})
		if str(vow_outcome_dict.get("event", "")) == "benefit":
			VowService.release_vow(flow_ctx.save_data, null, logger, t)
			flow_ctx.request_save("vow.released")
			return true
	return false

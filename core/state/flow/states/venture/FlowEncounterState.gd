class_name FlowEncounterState

extends State

const FEAR_THRESHOLD_DEFAULT: int = 80
const LeadershipEmotionService = preload("res://core/combat/LeadershipEmotionService.gd")

func _init(id: String = FlowStateIds.ENCOUNTER) -> void:
	super(id)

# V2-INFRA-003 Phase 6 Slice 6I: the 979-line encounter setup that used to be the body of
# this method now lives in EncounterSetupService. Everything it did — context and machine
# creation, actor build, board sizing, terrain, placement, shrine and objective spawn,
# objective_params, charge pressure, the surprise fear bump, the temporary-ally auto-join,
# unique-id repair and purifier selection — moved verbatim, with no seed path, draw order,
# dispatch or save reason changed. Building the entry snapshot stays here, because that is
# what a flow state does.
func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext

	EncounterSetupService.new(flow_ctx, flow_ctx.config_service, flow_ctx.logger).setup(t)

	# COMBAT-001/COMBAT-007: always build round snapshot at entry (pre_combat phase).
	flow_ctx.last_snapshot = EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, t)

func exit(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	flow_ctx.active_encounter_objective_index = -1



## COMBAT-007: FinalCombatSnapshot builder — emits type "flow.resolve".
## Called from _end_round() only when combat_over is true.
## Consumed by ResolveScreen (UI-005 scaffold).
static func build_final_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	var raw_actors: Array = ectx.actors if ectx != null else []
	var combat_state: Dictionary = ectx.combat_state if ectx != null else {}
	var encounter_id: String = ectx.encounter_id if ectx != null else ""
	var combat_result: Dictionary = ectx.combat_result if ectx != null else {}
	var victory := bool(combat_result.get("victory", false))
	var round_ended := int(combat_result.get("round_ended", 0))

	# V2-STAGE-004 Phase 4 (S12): Temporary Ally death knock. If the joined ally (is_ally
	# true) died in this battle, apply a small party morale/fear knock — a thematic loss,
	# never a battle failure (combat_result is untouched). Mirrors the surprise-fear
	# precedent (LeadershipEmotionService.apply_fear_gain, ~line 785 above) plus the
	# parallel apply_morale_loss helper. Gated on an ally actor being present AND dead —
	# no-op (byte-identical) for every encounter without a joined ally.
	var _ak_ally: Dictionary = {}
	for _ak_v in raw_actors:
		if _ak_v is Dictionary and bool(_ak_v.get("is_ally", false)):
			_ak_ally = _ak_v
			break
	if not _ak_ally.is_empty() and bool(_ak_ally.get("is_dead", false)):
		var _ak_cfg: Dictionary = {}
		var _ak_expr_cfg: Dictionary = {}
		if flow_ctx.config_service != null:
			var _ak_bal: Dictionary = flow_ctx.config_service.get_balance()
			var _ak_data: Dictionary = _ak_bal.get("data", {})
			_ak_cfg = _ak_data.get("contact", {}).get("ally", {})
			_ak_expr_cfg = _ak_data.get("maturity_expression", {})
		var _ak_fear_knock: int   = int(_ak_cfg.get("death_fear_knock",   0))
		var _ak_morale_knock: int = int(_ak_cfg.get("death_morale_knock", 0))
		for _ak_i in range(raw_actors.size()):
			var _ak_target_v: Variant = raw_actors[_ak_i]
			if not (_ak_target_v is Dictionary):
				continue
			var _ak_target: Dictionary = _ak_target_v
			if str(_ak_target.get("faction", "")) != "echo" or bool(_ak_target.get("is_dead", false)):
				continue
			# Exclude a joined guide spirit and the ally itself — the knock is meant for the
			# player's real echoes only (mirrors the deliberate exclusions used elsewhere).
			if bool(_ak_target.get("is_spirit", false)) or bool(_ak_target.get("is_ally", false)):
				continue
			if _ak_fear_knock > 0:
				var _ak_fear_applied := LeadershipEmotionService.apply_fear_gain(
					_ak_target, _ak_fear_knock, raw_actors, _ak_expr_cfg)
				raw_actors[_ak_i]["fear"] = clampi(int(_ak_target.get("fear", 0)) + _ak_fear_applied, 0, 100)
			if _ak_morale_knock > 0:
				var _ak_morale_applied := LeadershipEmotionService.apply_morale_loss(
					_ak_target, _ak_morale_knock, raw_actors, _ak_expr_cfg, round_ended)
				raw_actors[_ak_i]["morale"] = clampi(int(_ak_target.get("morale", 50)) - _ak_morale_applied, 0, 100)
		if flow_ctx.logger != null:
			flow_ctx.logger.info(t, "combat.ally.killed", "Temporary ally died — party knock applied", {
				"actor_id": _ak_ally.get("id", ""),
				"fear_knock":   _ak_fear_knock,
				"morale_knock": _ak_morale_knock,
			})

	# Project actors to clean render shape.
	# S14a: pass the offensive contribution ledger so each projected actor carries a
	# "contribution" sub-dict (damage_dealt/damage_taken/kills) for the resolve screen / S14.
	var _s14a_contribution_ledger: Dictionary = ectx.echo_action_logs if ectx != null else {}
	# V2-INFRA-003 Phase 3 Slice C: same rationale as build_round_snapshot() above — no clear in
	# this loop. FlowRuntime.dispatch()'s closure clears _bark_line once, after publish.
	var projected_actors: Array = []
	for a_v in raw_actors:
		if a_v is Dictionary:
			projected_actors.append(EncounterSnapshotBuilder._project_actor(a_v, _s14a_contribution_ledger))

	# UI-005: pre-compute summary counts so ResolveScreen reads clean fields.
	var enemies_defeated: int = 0
	var echoes_survived: int  = 0
	var total_enemies: int    = 0
	var total_echoes: int     = 0
	for a in projected_actors:
		var faction := str(a.get("faction", ""))
		var status  := str(a.get("status", ""))
		if faction == "enemy":
			total_enemies += 1
			if status == "dead":
				enemies_defeated += 1
		elif faction == "echo":
			# FIX (Codex review bug 2): a joined Temporary Ally (is_ally) or GUIDE_SPIRIT
			# (is_spirit) is a faction:"echo" combatant but NOT a roster echo — exclude both
			# from the reward/survivor/rank tally so a surviving ally/spirit doesn't grant an
			# extra echo-survival bonus and a dead one doesn't skew the rank denominator.
			# Rendering (projected_actors) and combat end-conditions are untouched.
			if bool(a.get("is_ally", false)) or bool(a.get("is_spirit", false)):
				continue
			total_echoes += 1
			if status != "dead":
				echoes_survived += 1

	if encounter_id == "keeper_intro.first_trial":
		return EncounterSnapshotBuilder._build_keeper_intro_final_snapshot(
			flow_ctx,
			t,
			ectx,
			combat_state,
			combat_result,
			projected_actors,
			enemies_defeated,
			echoes_survived,
			round_ended
		)

	# ECONOMY-004: Read reward config from balance.json
	var reward_cfg: Dictionary = {}
	if flow_ctx.config_service != null:
		var balance: Dictionary = flow_ctx.config_service.get_balance()
		var bal_data_v: Variant = balance.get("data", {})
		var bal_data: Dictionary = bal_data_v if bal_data_v is Dictionary else {}
		var rc_v: Variant = bal_data.get("rewards", {})
		reward_cfg = rc_v if rc_v is Dictionary else {}

	# ECONOMY-004: Resolve stage objectives from realm model
	var stage_objectives: Array = []
	var realm_model: Dictionary = RealmService.get_active(flow_ctx)
	var raw_model_stages: Variant = realm_model.get("stages", [])
	var model_stages: Array = raw_model_stages if raw_model_stages is Array else []
	var sid := str(flow_ctx.stage_id)
	var stage_index := 0
	if sid.contains("."):
		var parts := sid.split(".")
		stage_index = int(parts[parts.size() - 1])
	for s_v in model_stages:
		var s: Dictionary = s_v if s_v is Dictionary else {}
		if int(s.get("index", -1)) == stage_index:
			var raw_objs: Variant = s.get("objectives", [])
			stage_objectives = raw_objs if raw_objs is Array else []
			break

	# REALM-005: Compute virtue-based stage bonus
	var realm_virtue  := str(realm_model.get("virtue", ""))
	var run_index     := int(realm_model.get("run_index", 0))
	var stage_reward_data: Dictionary = RealmService.calculate_stage_reward(
		stage_index, realm_virtue, run_index, reward_cfg
	)
	var virtue_bonus   := int(stage_reward_data.get("virtue_bonus", 0))
	var formula_inputs: Dictionary = stage_reward_data.get("formula_inputs", {})

	# LOG_ECONOMY_REWARD: confirms formula_inputs (REALM-005 DoD point 4)
	if flow_ctx.logger != null:
		flow_ctx.logger.info(t, "economy.stage.reward", "Stage reward formula", formula_inputs)

	# ECONOMY-004: Compute and pay reward
	var run_count := int(realm_model.get("run_count", 0))
	var reward_data: Dictionary = RewardCalc.compute(
		victory,
		stage_objectives,
		enemies_defeated,
		total_enemies,
		echoes_survived,
		total_echoes,
		round_ended,
		run_count,
		reward_cfg
	)

	# V2-ECONOMY-001: pre-compute ekwan_factor from first stage objective type
	var _obj_type := "combat"
	if not stage_objectives.is_empty() and stage_objectives[0] is Dictionary:
		_obj_type = str((stage_objectives[0] as Dictionary).get("obj_type", "combat"))
	var _ekwan_factor := float(reward_cfg.get("ekwan_base_factor", 0.12))
	if _obj_type == "shrine":
		_ekwan_factor *= float(reward_cfg.get("ekwan_shrine_multiplier", 1.5))

	var economy_svc := EconomyService.new(flow_ctx.save_data)
	var reward_result: Dictionary = economy_svc.reward_stage_complete(
		victory,
		int(reward_data.get("base_reward", 0)),
		int(reward_data.get("enemy_bonus", 0)),
		enemies_defeated,
		int(reward_data.get("echo_bonus", 0)),
		echoes_survived,
		int(reward_data.get("speed_bonus", 0)),
		float(reward_data.get("redo_multiplier", 1.0)),
		str(reward_data.get("rank", "F")),
		virtue_bonus,
		_ekwan_factor,
		flow_ctx.logger,
		t
	)

	# Trigger save — Ase is now in save data and must persist
	flow_ctx.request_save("stage.reward")

	# PROG-003: award XP and check level-ups for all party echoes.
	var xp_events: Array = []
	var prog_cfg_v: Variant = {}
	var birth_stats_v: Variant = {}
	if flow_ctx.config_service != null:
		var bal_p: Dictionary = flow_ctx.config_service.get_balance()
		var bd_p: Dictionary  = bal_p.get("data", {})
		prog_cfg_v   = bd_p.get("progression", {})
		birth_stats_v = bd_p.get("summoning", {}).get("birth_stats", {})
	var prog_cfg_d: Dictionary   = prog_cfg_v if prog_cfg_v is Dictionary else {}
	var birth_stats_d: Dictionary = birth_stats_v if birth_stats_v is Dictionary else {}

	# Detect realm completion: is this the final stage?
	var stage_count: int = int(realm_model.get("stage_count", 1))
	var realm_complete_now: bool = victory and (stage_index >= stage_count - 1)

	var echo_logs: Dictionary = {}
	if ectx != null:
		echo_logs = ectx.echo_action_logs
		# PROG-004: mark survived=false for any echo that was KO'd during the encounter.
		# Defaults to true (set when entry is first created in echo_action_logs).
		# Used by ProgressionService to compute the faith virtue XP multiplier.
		for actor_v in ectx.actors:
			if not actor_v is Dictionary:
				continue
			if str(actor_v.get("faction", "")) != "echo":
				continue
			var eid: String = str(actor_v.get("id", ""))
			if echo_logs.has(eid):
				if bool(actor_v.get("is_dead", false)):
					echo_logs[eid]["survived"] = false
				elif not echo_logs[eid].has("survived"):
					echo_logs[eid]["survived"] = true

	# XP tuning: compute realm XP multiplier from campaign position (run_index).
	# run_index = how many times this realm has been started (campaign difficulty proxy).
	var realm_xp_mult: float = 1.0
	var mult_rate: float = float(prog_cfg_d.get("realm_xp_multiplier_per_realm", 0.0))
	if mult_rate > 0.0:
		realm_xp_mult = 1.0 + float(run_index) * mult_rate

	# XP tuning: kill XP was already applied mid-combat — skip it here to avoid double-count.
	xp_events = ProgressionService.award_post_combat_xp(
		flow_ctx.save_data,
		echo_logs,
		victory,
		realm_complete_now,
		prog_cfg_d,
		birth_stats_d,
		flow_ctx.logger,
		t,
		realm_xp_mult,
		true
	)

	# XP mutations are covered by the save_request set above.
	if flow_ctx.save_request_reason != "" and not xp_events.is_empty():
		flow_ctx.request_save("progression.xp")

	# Bug fix (PROG-003): sync final combat emotion state back to roster so EchoParty
	# reflects the actual fear/morale echoes accumulated during the encounter.
	# The win/loss drift in _apply_encounter_emotion_drift() then applies on top.
	if ectx != null:
		var em_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
		var em_sanctum: Dictionary = em_sanctum_v if em_sanctum_v is Dictionary else {}
		var em_roster_v: Variant = em_sanctum.get("roster", [])
		var em_roster: Array = em_roster_v if em_roster_v is Array else []
		for actor_v in ectx.actors:
			if not actor_v is Dictionary:
				continue
			if str(actor_v.get("faction", "")) != "echo":
				continue
			var eid: String = str(actor_v.get("id", ""))
			for i in range(em_roster.size()):
				if em_roster[i] is Dictionary and str(em_roster[i].get("id", "")) == eid:
					if not em_roster[i].has("emotion"):
						em_roster[i]["emotion"] = {}
					em_roster[i]["emotion"]["fear_current"]   = int(actor_v.get("fear", 0))
					em_roster[i]["emotion"]["morale_current"] = int(actor_v.get("morale", 0))
					break

	# V2-EMOTION-001: per-echo emotion delta summary for resolve screen.
	var pre_morale_map: Dictionary = ectx.pre_encounter_morale if ectx != null else {}
	var emotion_summary: Array = []
	for a_v in raw_actors:
		if not (a_v is Dictionary): continue
		var ea: Dictionary = a_v
		if str(ea.get("faction", "")) != "echo": continue
		var eid: String     = str(ea.get("id", ""))
		var pre_morale: int  = int(pre_morale_map.get(eid, 50))
		var post_morale: int = int(ea.get("morale", 50))
		var post_fear: int   = int(ea.get("fear", 0))
		# P1 CLOSE: compute pre/post status for direction comparison.
		var _pre_status  := EmotionService.get_emotional_status(pre_morale, 0)
		var _post_status := EmotionService.get_emotional_status(post_morale, post_fear)
		var _pre_rank  := EncounterSnapshotBuilder._emotional_status_rank(_pre_status)
		var _post_rank := EncounterSnapshotBuilder._emotional_status_rank(_post_status)
		var _direction: String
		if _post_rank > _pre_rank:
			_direction = "lift"
		elif _post_rank < _pre_rank:
			_direction = "fall"
		else:
			_direction = "steady"
		# P1 CLOSE: tag — "ko" if dead, "refused" if existing refused flag, else "".
		var _is_dead := bool(ea.get("is_dead", false))
		var _tag: String
		if _is_dead:
			_tag = "ko"
		elif post_fear >= FEAR_THRESHOLD_DEFAULT:
			_tag = "refused"
		else:
			_tag = ""
		emotion_summary.append({
			"echo_id":               eid,
			"name":                  str(ea.get("name", "")),
			# V2-EMOTION-002: unified status arc (replaces pre/post morale_tier + fear_signal).
			"pre_emotional_status":  _pre_status,
			"post_emotional_status": _post_status,
			"morale_delta":          post_morale - pre_morale,
			"refused":               post_fear >= FEAR_THRESHOLD_DEFAULT,
			# P1 CLOSE: additive fields for unified Resolve component.
			"direction":             _direction,
			"tag":                   _tag,
		})

	# V2-VOICE-001: enrich each echo actor row with arrival_bark from save-data roster.
	# _select_arrival_barks_for_party() writes _sanctum_bark to roster entries before this call.
	var _arb_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if _arb_sanctum_v is Dictionary:
		var _arb_roster_v: Variant = (_arb_sanctum_v as Dictionary).get("roster", [])
		var _arb_roster: Array = _arb_roster_v if _arb_roster_v is Array else []
		for _pa_v in projected_actors:
			if not (_pa_v is Dictionary):
				continue
			var _pa: Dictionary = _pa_v
			if str(_pa.get("faction", "")) != "echo":
				continue
			var _pa_id := str(_pa.get("id", ""))
			for _re_v in _arb_roster:
				if _re_v is Dictionary and str((_re_v as Dictionary).get("id", "")) == _pa_id:
					var _bark_v: Variant = (_re_v as Dictionary).get("_sanctum_bark", {})
					_pa["arrival_bark"] = str(_bark_v.get("line", "")) if _bark_v is Dictionary else ""
					break

	# V2-STAGE-002: count required objectives not yet completed (post-victory mark).
	var objectives_remaining := EncounterSnapshotBuilder._count_remaining_required_objectives(flow_ctx)

	# P1 CLOSE: surface — use the first objective type when known, else "combat" or "shrine".
	var _combat_surface := _obj_type if not _obj_type.is_empty() else "combat"

	# P1 CLOSE: summary_line — synthesize from reason and victory.
	var _raw_reason := str(combat_result.get("reason", ""))
	var _summary_line: String
	if victory:
		_summary_line = "The line held — %s." % _raw_reason if not _raw_reason.is_empty() \
			else "The line held."
	else:
		_summary_line = "%s." % _raw_reason if not _raw_reason.is_empty() \
			else "The line broke."

	# V2-INFRA-003 Phase 6 Slice 6J: producer A of docs/resolve-snapshot-block-spec.md,
	# composed through ResolveSnapshotBuilder's block library — the last of the six producers
	# to migrate. No key and no value changed; the spec's claim that Phase 6 needs NO edit to
	# ResolveSnapshotBuilder.gd was re-verified here (A's twenty-four keys are exactly
	# legacy_title + combat_stats + actors + victory_flag + ledger + ekwan + grade_rank +
	# progression + emotion + vows + banner + combat_seams, at the granularity those blocks
	# already have). A emits no run_type, so it falls through to ResolveScreen's combat
	# renderer exactly as before.
	#
	# Key ORDER in `data` changes with the composition, and `meta` now sits second in the
	# snapshot. Safe: FlowFingerprintTests._final_fingerprint() sorts `data_keys` before
	# hashing (tests/FlowFingerprintTests.gd:238-241), the one whole Dictionary it hashes
	# (objective_state) is still built by the unchanged _build_objective_state(), no test
	# JSON-hashes a whole resolve snapshot, and every read in
	# ui/screens/venture/ResolveScreen.gd is data.get(key, <default>).
	#
	# THE PAYMENT ABOVE DID NOT MOVE, deliberately. reward_stage_complete(),
	# request_save("stage.reward"), award_post_combat_xp() and the roster emotion write-back
	# all stay where they were — that is defect-register D36/D77, scheduled for the
	# after-Phase-9 bundle because relocating them empties ase_awarded/ekwan_awarded here and
	# moves all seven combat fingerprints. Slice 6J is extraction and composition only, which
	# is also why this producer stays on FlowEncounterState rather than joining the pure
	# EncounterSnapshotBuilder beside producer B.
	var _breakdown: Array = reward_result.get("breakdown", [])
	var _vow_outcome: Dictionary = flow_ctx.vow_outcome.duplicate() if not flow_ctx.vow_outcome.is_empty() else {}

	var _snap: Dictionary = ResolveSnapshotBuilder.build(
		t, EncounterSnapshotBuilder._build_resolve_actions(victory, objectives_remaining)
	)
	var _data: Dictionary = _snap["data"]
	ResolveSnapshotBuilder.add_legacy_title(_data, "Result")
	ResolveSnapshotBuilder.add_combat_stats(
		_data,
		encounter_id,
		str(combat_result.get("reason", "")),
		round_ended,
		enemies_defeated,
		echoes_survived,
		EncounterSnapshotBuilder._build_objective_state(ectx, combat_state)
	)
	ResolveSnapshotBuilder.add_actors(_data, projected_actors)
	ResolveSnapshotBuilder.add_victory_flag(_data, victory)
	ResolveSnapshotBuilder.add_ledger(_data, int(reward_result.get("ase_awarded", 0)), _breakdown)
	ResolveSnapshotBuilder.add_ekwan(_data, int(reward_result.get("ekwan_awarded", 0)))
	ResolveSnapshotBuilder.add_grade_rank(_data, str(reward_result.get("rank", "F")))
	# PROG-003: per-echo XP events for ResolveScreen and EchoParty display.
	ResolveSnapshotBuilder.add_progression(_data, formula_inputs, [], xp_events)
	# V2-EMOTION-001: per-echo emotion delta for ResolveScreen.
	ResolveSnapshotBuilder.add_emotion(_data, emotion_summary)
	# VOW-001 / V2-VOW-002: vow break/benefit/compliance outcome + vows unlocked this stage.
	ResolveSnapshotBuilder.add_vows(_data, _vow_outcome, flow_ctx.session_unlocked_vows.duplicate())
	# P1 CLOSE: additive fields for unified Resolve component.
	ResolveSnapshotBuilder.add_banner(_data, _combat_surface, _summary_line)
	# objectives_remaining drives resolve routing (V2-STAGE-002); guide_spirit_protected is the
	# V2-ITEM-002 free-summon seam flag for a GUIDE_SPIRIT protect-mode survival win (no reward
	# logic here); combat_intro_line is the V2-STAGE-004 S15 context beat for a
	# hostile-claimant-forced combat, "" when not applicable.
	ResolveSnapshotBuilder.add_combat_seams(
		_data,
		objectives_remaining,
		victory and str(combat_result.get("reason", "")) == "spirit_protected",
		EncounterSnapshotBuilder._build_combat_intro_line(flow_ctx)
	)
	return _snap

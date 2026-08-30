extends RefCounted

class_name KeeperIntroService

const STEP_CALL := "call_of_realm"
const STEP_TRIAL := "first_trial"
const STEP_REWIND := "anansi_rewind"
const STEP_THREAD_RETURN := "thread_returns"
const STEP_AWAKENING := "awakening_rite"
const STEP_WEAVING := "first_weaving"
const STEP_KEEPING := "into_keeping"
const STEP_COMPLETE := "complete"

const TRIAL_READY := "ready"
const TRIAL_WOUND := "wound_acts"
const TRIAL_ECHO := "echo_acts"

const FIRST_THREAD_ID := "thread.prologue.first.0"

const STEPS := [
	STEP_CALL,
	STEP_TRIAL,
	STEP_REWIND,
	STEP_THREAD_RETURN,
	STEP_AWAKENING,
	STEP_WEAVING,
	STEP_KEEPING,
]


static func ensure_intro(save_data: Dictionary, cfg: Dictionary = {}) -> Dictionary:
	var onboarding := OnboardingService.ensure_onboarding(save_data, cfg)
	var chapter_complete := bool(onboarding.get("chapter_one_complete", false))
	if not onboarding.has("keeper_intro_complete") or typeof(onboarding["keeper_intro_complete"]) != TYPE_BOOL:
		onboarding["keeper_intro_complete"] = false
	if not onboarding.has("keeper_intro_step") or typeof(onboarding["keeper_intro_step"]) != TYPE_STRING:
		onboarding["keeper_intro_step"] = STEP_CALL if chapter_complete else ""
	if not onboarding.has("keeper_trial_phase") or typeof(onboarding["keeper_trial_phase"]) != TYPE_STRING:
		onboarding["keeper_trial_phase"] = TRIAL_READY
	if not onboarding.has("keeper_trial_rewind_used") or typeof(onboarding["keeper_trial_rewind_used"]) != TYPE_BOOL:
		onboarding["keeper_trial_rewind_used"] = false
	if not onboarding.has("first_thread_id") or typeof(onboarding["first_thread_id"]) != TYPE_STRING:
		onboarding["first_thread_id"] = ""
	if not onboarding.has("first_trial_rewards_granted") or typeof(onboarding["first_trial_rewards_granted"]) != TYPE_BOOL:
		onboarding["first_trial_rewards_granted"] = false
	if not onboarding.has("awakening_choice") or typeof(onboarding["awakening_choice"]) != TYPE_STRING:
		onboarding["awakening_choice"] = ""
	_ensure_sanctum_intro_fields(save_data)
	return onboarding


static func start_after_chapter_one(save_data: Dictionary, cfg: Dictionary) -> void:
	var onboarding := ensure_intro(save_data, cfg)
	onboarding["keeper_intro_complete"] = false
	onboarding["keeper_intro_step"] = STEP_CALL
	onboarding["keeper_trial_phase"] = TRIAL_READY
	onboarding["keeper_trial_rewind_used"] = false
	onboarding["first_thread_id"] = ""
	onboarding["first_trial_rewards_granted"] = false
	onboarding["awakening_choice"] = ""
	_ensure_sanctum_intro_fields(save_data)


static func is_complete(save_data: Dictionary) -> bool:
	var onboarding_v: Variant = save_data.get("onboarding", {})
	var onboarding: Dictionary = onboarding_v if onboarding_v is Dictionary else {}
	return bool(onboarding.get("keeper_intro_complete", false))


static func current_step(save_data: Dictionary, cfg: Dictionary) -> String:
	var onboarding := ensure_intro(save_data, cfg)
	if bool(onboarding.get("keeper_intro_complete", false)):
		return STEP_COMPLETE
	var step := str(onboarding.get("keeper_intro_step", STEP_CALL))
	if step not in STEPS:
		step = STEP_CALL
		onboarding["keeper_intro_step"] = step
	return step


static func set_step(save_data: Dictionary, cfg: Dictionary, step: String) -> void:
	var onboarding := ensure_intro(save_data, cfg)
	onboarding["keeper_intro_step"] = step if step in STEPS else STEP_CALL


static func step_to_flow_id(step: String) -> String:
	match step:
		STEP_CALL:
			return FlowStateIds.KEEPER_CALL
		STEP_TRIAL:
			return FlowStateIds.KEEPER_TRIAL
		STEP_REWIND:
			return FlowStateIds.KEEPER_REWIND
		STEP_THREAD_RETURN:
			return FlowStateIds.KEEPER_THREAD_RETURN
		STEP_AWAKENING:
			return FlowStateIds.KEEPER_AWAKENING
		STEP_WEAVING:
			return FlowStateIds.KEEPER_WEAVING
		STEP_KEEPING:
			return FlowStateIds.KEEPER_KEEPING
	return FlowStateIds.KEEPER_CALL


static func get_intro_cfg(cfg: Dictionary) -> Dictionary:
	var data_v: Variant = cfg.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var intro_v: Variant = data.get("keeper_intro", {})
	return intro_v if intro_v is Dictionary else {}


static func get_selected_virtue(save_data: Dictionary, cfg: Dictionary) -> String:
	var selected := OnboardingService.selected_fragment(save_data, cfg)
	return str(selected.get("virtue", ""))


static func get_selected_vector(save_data: Dictionary, cfg: Dictionary) -> String:
	var virtue := get_selected_virtue(save_data, cfg)
	return OnboardingService.vector_for_virtue(cfg, virtue)


static func ensure_starter_party(save_data: Dictionary) -> String:
	_ensure_sanctum_intro_fields(save_data)
	var sanctum: Dictionary = save_data["sanctum"]
	var echo := OnboardingService.get_starter_echo(save_data)
	var echo_id := str(echo.get("id", ""))
	if echo_id.is_empty():
		return ""
	var active_v: Variant = sanctum.get("active_party_ids", [])
	var active: Array = active_v if active_v is Array else []
	if not echo_id in active:
		active.append(echo_id)
	sanctum["active_party_ids"] = active
	return echo_id


static func grant_trial_rewards(save_data: Dictionary, cfg: Dictionary, econ: EconomyService, logger: StructuredLogger, t: int) -> void:
	_ensure_sanctum_intro_fields(save_data)
	var onboarding := ensure_intro(save_data, cfg)
	if bool(onboarding.get("first_trial_rewards_granted", false)):
		_prune_extra_first_threads(save_data)
		return
	var intro_cfg := get_intro_cfg(cfg)
	var ase_reward := int(intro_cfg.get("first_trial_ase_reward", 40))
	if econ != null and ase_reward > 0:
		econ.add_ase(ase_reward, "keeper_intro.first_trial", logger, t)

	var virtue := get_selected_virtue(save_data, cfg)
	if virtue.is_empty():
		virtue = "story"
	_grant_first_thread_via_thread_service(save_data, cfg, virtue, logger, t)
	onboarding["first_thread_id"] = FIRST_THREAD_ID
	onboarding["first_trial_rewards_granted"] = true


static func awaken_flame(save_data: Dictionary, cfg: Dictionary, choice: String, logger: StructuredLogger, t: int) -> void:
	_ensure_sanctum_intro_fields(save_data)
	var intro_cfg := get_intro_cfg(cfg)
	var onboarding := ensure_intro(save_data, cfg)
	onboarding["awakening_choice"] = choice
	var sanctum: Dictionary = save_data["sanctum"]
	var flame_v: Variant = sanctum.get("ase_flame", {})
	var flame: Dictionary = flame_v if flame_v is Dictionary else {}
	flame["awakened"] = true
	flame["boost_remaining_seconds"] = int(intro_cfg.get("awakening_boost_duration_seconds", 600))
	flame["boost_per_bank_tick"] = int(intro_cfg.get("awakening_boost_per_bank_tick", 5))
	sanctum["ase_flame"] = flame

	var echo := OnboardingService.get_starter_echo(save_data)
	if not echo.is_empty():
		EmotionService.apply_morale_delta(echo, 1, "keeper_intro.awakening", logger, t)
		EmotionService.apply_fear_delta(echo, -1, "keeper_intro.awakening", 999, logger, t)
		match choice:
			"guard":
				EmotionService.apply_fear_delta(echo, -1, "keeper_intro.awakening.guard", 999, logger, t)
			"listen":
				EmotionService.apply_morale_delta(echo, 1, "keeper_intro.awakening.listen", logger, t)
			"return":
				var vector_key := get_selected_vector(save_data, cfg)
				if not vector_key.is_empty():
					VectorService.accumulate(echo, vector_key, 1, logger, t)


static func apply_first_weave(save_data: Dictionary, cfg: Dictionary, logger: StructuredLogger, t: int) -> void:
	_ensure_sanctum_intro_fields(save_data)
	var intro_cfg := get_intro_cfg(cfg)
	var echo := OnboardingService.get_starter_echo(save_data)
	if echo.is_empty():
		return
	var thread_id := FIRST_THREAD_ID
	WeavingRiteService.apply_outcome("accept", str(echo.get("id", "")), thread_id, save_data, logger, t)
	var storyweight_gain_cfg := float(intro_cfg.get("first_weave_storyweight", 10))
	var storyweight_gain := int(round(storyweight_gain_cfg))
	if storyweight_gain_cfg > 0.0 and storyweight_gain == 0:
		logger.warn(t, "keeper_intro.storyweight_gain.rounded_to_zero",
			"first_weave_storyweight is configured non-zero but rounds to 0 storyweight; no gain applied",
			{ "configured_value": storyweight_gain_cfg })
	if storyweight_gain > 0:
		var xp_before := int(echo.get("xp_total", 0))
		var story_before := int(echo.get("storyweight", xp_before))
		echo["xp_total"] = xp_before + storyweight_gain
		echo["storyweight"] = story_before + storyweight_gain
	var vector_key := get_selected_vector(save_data, cfg)
	if not vector_key.is_empty():
		VectorService.accumulate(echo, vector_key, 1, logger, t)


static func mark_complete(save_data: Dictionary, cfg: Dictionary) -> void:
	var onboarding := ensure_intro(save_data, cfg)
	onboarding["keeper_intro_complete"] = true
	onboarding["keeper_intro_step"] = STEP_COMPLETE


static func apply_ase_boost_from_save(save_data: Dictionary, cfg: Dictionary, delta_seconds: int) -> int:
	if delta_seconds <= 0:
		return 0
	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return 0
	var sanctum: Dictionary = sanctum_v
	var flame_v: Variant = sanctum.get("ase_flame", {})
	if not (flame_v is Dictionary):
		return 0
	var flame: Dictionary = flame_v
	if not bool(flame.get("awakened", false)):
		return 0
	var remaining := int(flame.get("boost_remaining_seconds", 0))
	if remaining <= 0:
		return 0
	var intro_cfg := get_intro_cfg(cfg)
	var bank_interval := int(intro_cfg.get("awakening_boost_bank_interval_seconds", 240))
	if bank_interval <= 0:
		bank_interval = 240
	var per_tick := int(flame.get("boost_per_bank_tick", intro_cfg.get("awakening_boost_per_bank_tick", 5)))
	var effective := mini(delta_seconds, remaining)
	var gain := int(floor(float(effective) / float(bank_interval) * float(per_tick)))
	flame["boost_remaining_seconds"] = maxi(0, remaining - delta_seconds)
	sanctum["ase_flame"] = flame
	save_data["sanctum"] = sanctum
	return gain


## Reads save_data.sanctum.ase_flame.awakened — Ase accrual (online settle + offline catch-up)
## is gated on the flame being awakened; the house is dormant before onboarding completes.
## V2-INFRA-003 Phase 4 Slice 7: moved off FlowRuntime (private _is_ase_flame_awakened) — reads
## save data for the ase_flame domain, which this file already owns (awaken_flame,
## apply_ase_boost_from_save above). Shared by EconomySettlementService.settle() (online) and
## OfflineAccrualService.apply_if_needed() (offline), same "true owner" reasoning as the
## get_institutions_cfg / get_buildings_cfg config getters.
static func is_ase_flame_awakened(save_data: Dictionary) -> bool:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return false
	var flame_v: Variant = (sanctum_v as Dictionary).get("ase_flame", {})
	var flame: Dictionary = flame_v if flame_v is Dictionary else {}
	return bool(flame.get("awakened", false))


## V2-INFRA-003 Phase 4 Slice 9 (Part B): moved verbatim from
## FlowRuntime._setup_keeper_intro_trial_encounter(t). Builds the 2-actor Keeper-intro first-
## trial encounter (starter Echo vs. the Fragment Wound) directly on flow_ctx.
##
## CORRECTION vs. the story brief: the brief listed this as one of the methods to move onto
## OnboardingController. It does not fit there — verified call sites are
## FlowRuntime._gate_state_for_keeper_intro() and the "flow.continue" case body in
## FlowRuntime.dispatch(), BOTH of which stay on FlowRuntime this slice (per the
## _gate_state_for_keeper_intro / flow.go_state "must survive exactly" requirement) and are NOT
## dispatched actions, so FlowRuntime calling into a controller from either site would violate
## "FlowRuntime must not call into a controller for a non-action." The third call site
## (keeper_intro.call.answer's handler) DOES move to OnboardingController. A helper used by both
## a controller and non-controller FlowRuntime code is exactly the "helper used by two or more
## domains has an owner" case from core/AGENTS.md — the owner is this file, which already holds
## every other piece of Keeper-intro trial-step domain knowledge (steps, phases, starter party,
## rewards). `cfg` replaces the original's own `config_service.get_balance()` call — callers
## already have the balance dict in hand at every call site.
static func setup_trial_encounter(flow_ctx: FlowContext, cfg: Dictionary, t: int) -> void:
	var echo := OnboardingService.get_starter_echo(flow_ctx.save_data)
	if echo.is_empty():
		return
	var bd: Dictionary = cfg.get("data", {})
	# V2-INFRA-003 Phase 6 Slice 6B: single owner for the { birth_stats, enemy_types } assembly.
	# The balance-dict variant is used because this function is handed `cfg` and holds no
	# ConfigService reference. Same dict, same keys as the longhand it replaces.
	var actor_cfg := ConfigService.get_enemy_actor_cfg_from_balance(cfg)
	var echo_actor := EchoActor.from_echo(echo)
	echo_actor["grid_pos"] = { "col": 0, "row": 2 }
	var onboarding_v: Variant = flow_ctx.save_data.get("onboarding", {})
	var onboarding: Dictionary = onboarding_v if onboarding_v is Dictionary else {}
	var rewind_used := bool(onboarding.get("keeper_trial_rewind_used", false))
	echo_actor["_bark_line"] = "The wound knows us. I can still stand." if not rewind_used else "Again, then. I remember the edge."
	echo_actor["_bark_context"] = "combat_taunt"
	echo_actor["_bark_tier"] = "nascent"
	var wound := EnemyActor.from_definition({
		"id": "fragment_wound",
		"name": "Fragment Wound",
		"type": "fragment_wound",
		"level": 1,
		"faction": "enemy",
	}, t, actor_cfg)
	wound["grid_pos"] = { "col": 4, "row": 2 }
	wound["stats"]["max_hp"] = 18 if rewind_used else 28
	wound["stats"]["atk"] = 10 if rewind_used else 18
	wound["stats"]["def"] = 0 if rewind_used else 1
	wound["stats"]["agi"] = 2
	wound["current_hp"] = int(wound["stats"]["max_hp"])
	wound["speed"] = 2
	flow_ctx.encounter_ctx = EncounterContext.new()
	flow_ctx.encounter_ctx.encounter_id = "keeper_intro.first_trial"
	flow_ctx.encounter_ctx.resolution_mode = EncounterResolutionModes.COMBAT
	flow_ctx.encounter_ctx.actors = [echo_actor, wound]
	flow_ctx.encounter_ctx.placement_seed = 0
	flow_ctx.encounter_machine = EncounterStateMachine.new()
	flow_ctx.encounter_machine.register_default_states()
	var combat_cfg: Dictionary = bd.get("combat", {})
	flow_ctx.encounter_ctx.initiative_cfg = combat_cfg.get("initiative_modifiers", {})
	flow_ctx.encounter_id = "keeper_intro.first_trial"
	flow_ctx.stage_id = ""
	flow_ctx.realm_id = ""


## V2-INFRA-003 Phase 4 Slice 9 (Part B): moved verbatim from
## FlowRuntime._is_keeper_intro_trial_active(). Shared by combat-round resolution
## (FlowRuntime._resolve_next_actor(), 3 call sites) AND OnboardingController.handle_trial_finish()
## (keeper_intro.trial.finish) — a helper used by two domains, hence its home here rather than on
## either caller. Also used internally by trial_lethal_echo_ids() / trial_enemy_defeated() below.
static func is_trial_active(flow_ctx: FlowContext) -> bool:
	return flow_ctx.encounter_ctx != null and flow_ctx.encounter_ctx.encounter_id == "keeper_intro.first_trial"


## Moved verbatim from FlowRuntime._keeper_intro_trial_lethal_echo_ids(). Combat-path-only
## caller: FlowRuntime._resolve_next_actor().
static func trial_lethal_echo_ids(flow_ctx: FlowContext) -> Array[String]:
	var lethal_ids: Array[String] = []
	if not is_trial_active(flow_ctx):
		return lethal_ids
	for actor_v in flow_ctx.encounter_ctx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if str(actor.get("faction", "")) != "echo":
			continue
		if int(actor.get("current_hp", 1)) <= 0 or bool(actor.get("is_dead", false)):
			lethal_ids.append(str(actor.get("id", "")))
	return lethal_ids


## Moved verbatim from FlowRuntime._keeper_intro_trial_enemy_defeated(). Only real caller is
## OnboardingController.handle_trial_finish() (keeper_intro.trial.finish is not on the combat
## path) — grouped here anyway alongside its sibling trial-state readers above/below, all of
## which share is_trial_active()'s read of encounter_ctx.actors and belong to this file's
## existing Keeper-intro-trial domain knowledge.
static func trial_enemy_defeated(flow_ctx: FlowContext) -> bool:
	if not is_trial_active(flow_ctx):
		return false
	for actor_v in flow_ctx.encounter_ctx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if str(actor.get("faction", "")) == "enemy" and bool(actor.get("is_dead", false)):
			return true
	return false


## Moved verbatim from FlowRuntime._keeper_intro_restore_echo_after_second_attempt(). Combat-
## path-only caller: FlowRuntime._resolve_next_actor(). Second-KO safety net: heals the lethal
## Echo(s) to 1 HP silently (no rewind, no rewards) — see apply_trial_rewind() below for the
## first-KO branch.
static func restore_echo_after_second_attempt(flow_ctx: FlowContext, logger: StructuredLogger, t: int, lethal_ids: Array[String]) -> void:
	for actor_v in flow_ctx.encounter_ctx.actors:
		if not (actor_v is Dictionary):
			continue
		var actor: Dictionary = actor_v
		if str(actor.get("id", "")) in lethal_ids:
			actor["current_hp"] = 1
			actor["is_dead"] = false
			actor["death_round"] = 0
			actor["_bark_line"] = "Still here. Finish it."
			actor["_bark_context"] = "combat_resilient"
			actor["_bark_tier"] = "nascent"
	logger.info(t, "keeper_intro.trial.second_attempt.protected", "Second attempt Echo KO prevented without granting rewards", {
		"lethal_echo_ids": lethal_ids,
	})


## Moved from FlowRuntime._handle_keeper_intro_trial_rewind(), MINUS its final
## flow_machine.transition(FlowStateIds.KEEPER_REWIND, ...) call. This file is a service, not a
## controller or flow state — per the Consequence-service convention documented on
## BondConsequenceService/EmotionConsequenceService/RecruitmentConsequenceService/
## VowConsequenceService ("No flow_machine reference — structurally cannot transition state"),
## it does not hold or call flow_machine. It mutates save_data and nulls the encounter context
## (the one-time-rewind safety net: sets keeper_trial_rewind_used so a second KO instead hits
## restore_echo_after_second_attempt() above); the caller performs the KEEPER_REWIND transition
## immediately afterward with the flow_machine it already holds. Two callers, both do this same
## two-step:
##   FlowRuntime._resolve_next_actor() (combat path, first KO)
##   tests/OnboardingTests.gd _t_keeper_trial_rewind_restarts_debuffed() (reflection-site rewrite
##   — the test previously called FlowRuntime._handle_keeper_intro_trial_rewind by string name)
static func apply_trial_rewind(flow_ctx: FlowContext, cfg: Dictionary, logger: StructuredLogger, t: int, lethal_ids: Array[String]) -> void:
	var onboarding: Dictionary = ensure_intro(flow_ctx.save_data, cfg)
	onboarding["keeper_trial_rewind_used"] = true
	onboarding["keeper_trial_phase"] = "rewind"
	set_step(flow_ctx.save_data, cfg, STEP_REWIND)
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	flow_ctx.encounter_id = ""
	flow_ctx.request_save("keeper_intro.trial.rewind")
	logger.info(t, "keeper_intro.trial.rewind", "Anansi rewinds the first trial", {
		"lethal_echo_ids": lethal_ids,
	})


static func _ensure_sanctum_intro_fields(save_data: Dictionary) -> void:
	if not save_data.has("sanctum") or not (save_data["sanctum"] is Dictionary):
		save_data["sanctum"] = {}
	var sanctum: Dictionary = save_data["sanctum"]
	if not sanctum.has("ase_flame") or not (sanctum["ase_flame"] is Dictionary):
		sanctum["ase_flame"] = {
			"awakened": false,
			"boost_remaining_seconds": 0,
			"boost_per_bank_tick": 0,
		}


static func _grant_first_thread_via_thread_service(save_data: Dictionary, cfg: Dictionary, virtue: String, logger: StructuredLogger, t: int) -> void:
	_prune_extra_first_threads(save_data)
	var sanctum_existing_v: Variant = save_data.get("sanctum", {})
	var sanctum_existing: Dictionary = sanctum_existing_v if sanctum_existing_v is Dictionary else {}
	var existing_threads_v: Variant = sanctum_existing.get("threads", {})
	var existing_threads: Dictionary = existing_threads_v if existing_threads_v is Dictionary else {}
	if existing_threads.has(FIRST_THREAD_ID):
		return

	var realms_v: Variant = save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	realms["prologue.first"] = {
		"id": "prologue.first",
		"virtue": virtue,
		"run_index": 0,
		"realm_recovery_segments": [
			{
				"id": "segment.prologue.first",
				"quality_tier": "clean",
				"source": "keeper_intro",
			}
		],
	}
	save_data["realms"] = realms

	var data_v: Variant = cfg.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var threads_cfg_v: Variant = data.get("threads", {})
	var threads_cfg: Dictionary = threads_cfg_v if threads_cfg_v is Dictionary else {}
	var prologue_threads_cfg := threads_cfg.duplicate(true)
	prologue_threads_cfg["count_thresholds"] = {
		"one": 0.0,
		"two": 2.0,
		"three": 3.0,
	}
	ThreadService.crystallize_threads("prologue.first", save_data, prologue_threads_cfg, t, logger)

	var sanctum_v: Variant = save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var threads_v: Variant = sanctum.get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	if threads.has(FIRST_THREAD_ID):
		var thread: Dictionary = threads[FIRST_THREAD_ID]
		thread["display_name"] = "First Thread"
		thread["prologue"] = true
		threads[FIRST_THREAD_ID] = thread
	sanctum["threads"] = threads
	save_data["sanctum"] = sanctum


static func _prune_extra_first_threads(save_data: Dictionary) -> void:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var threads_v: Variant = sanctum.get("threads", {})
	if not (threads_v is Dictionary):
		return
	var threads: Dictionary = threads_v
	for thread_id_v in threads.keys():
		var thread_id := str(thread_id_v)
		if thread_id.begins_with("thread.prologue.first.") and thread_id != FIRST_THREAD_ID:
			threads.erase(thread_id)
	sanctum["threads"] = threads
	save_data["sanctum"] = sanctum

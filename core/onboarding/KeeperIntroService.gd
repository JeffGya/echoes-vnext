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

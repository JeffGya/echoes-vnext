class_name FlowKeeperIntroState

extends State

const KeeperIntroServiceScript := preload("res://core/onboarding/KeeperIntroService.gd")

var _step: String


func _init(id: String, step: String) -> void:
	_step = step
	super(id)


func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	if _step == KeeperIntroServiceScript.STEP_TRIAL:
		flow_ctx.last_snapshot = build_trial_snapshot(flow_ctx, t)
	else:
		flow_ctx.last_snapshot = build_snapshot(flow_ctx, t, _step, get_id())


func exit(ctx: RefCounted, t: int) -> void:
	pass


static func build_snapshot(flow_ctx: FlowContext, t: int, step: String, flow_id: String) -> Dictionary:
	var cfg: Dictionary = flow_ctx.config_service.get_balance() if flow_ctx.config_service != null else {}
	var onboarding := KeeperIntroServiceScript.ensure_intro(flow_ctx.save_data, cfg)
	var data := _base_data(step, onboarding, flow_ctx.save_data, cfg)
	return {
		"type": flow_id,
		"meta": { "t": t },
		"data": data,
		"actions": _actions_for_step(step),
	}


static func build_trial_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	if flow_ctx.encounter_ctx != null:
		var encounter_snap := EncounterSnapshotBuilder.build_round_snapshot(flow_ctx, t)
		var data_v: Variant = encounter_snap.get("data", {})
		var data: Dictionary = data_v if data_v is Dictionary else {}
		data["title"] = "First Trial"
		data["tutorial_line"] = "Watch how %s moves, guards, and answers danger. This first trial is protected." % str(OnboardingService.get_starter_echo(flow_ctx.save_data).get("name", "your Echo"))
		encounter_snap["data"] = data
		return encounter_snap

	var data := {
		"title": "First Trial",
		"encounter_id": "keeper_intro.first_trial",
		"board_cols": 5,
		"board_rows": 5,
		"actors": [],
		"placement_seed": 0,
		"objective_state": { "type": "Survive the Wound", "shrine_hp": 0, "shrine_alive": false },
		"round": 0,
		"initiative_order": [],
		"active_initiative_index": 0,
		"action_results": [],
		"current_actor_id": "",
		"last_actor_action": {},
		"round_phase": "pre_combat",
		"combat_over": false,
		"retreat_eligible": false,
		"retreat_ase_cost": 0,
		"retreat_tier_label": "",
		"retreat_success_pct": 0,
		"tutorial_line": "The trial is forming.",
	}
	return {
		"type": FlowStateIds.KEEPER_TRIAL,
		"meta": { "t": t },
		"data": data,
		"actions": {},
	}


static func _base_data(step: String, onboarding: Dictionary, save_data: Dictionary, cfg: Dictionary) -> Dictionary:
	var echo := OnboardingService.get_starter_echo(save_data)
	var virtue := KeeperIntroServiceScript.get_selected_virtue(save_data, cfg)
	var sanctum_v: Variant = save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var flame_v: Variant = sanctum.get("ase_flame", {})
	var flame: Dictionary = flame_v if flame_v is Dictionary else {}
	return {
		"step": step,
		"title": _title_for_step(step),
		"lines": _lines_for_step(step, echo, virtue, flame),
		"starter_echo": FlowOnboardingState._echo_summary(echo),
		"selected_virtue": virtue,
		"first_thread_id": str(onboarding.get("first_thread_id", "")),
		"sanctum_layout": SanctumLayoutService.snapshot_layout(save_data),
		"sanctum_occupants": SanctumLayoutService.snapshot_occupants(save_data),
		"awakening_choices": _awakening_choices(),
		"ase_flame": flame.duplicate(true),
	}


static func _actions_for_step(step: String) -> Dictionary:
	match step:
		KeeperIntroServiceScript.STEP_CALL:
			return {
				"cta.continue": {
					"type": "keeper_intro.call.answer",
					"label": "Answer",
					"slot": "cta.continue",
				}
			}
		KeeperIntroServiceScript.STEP_THREAD_RETURN:
			return {
				"cta.continue": {
					"type": "keeper_intro.thread.continue",
					"label": "Carry It Home",
					"slot": "cta.continue",
				}
			}
		KeeperIntroServiceScript.STEP_REWIND:
			return {
				"cta.continue": {
					"type": "keeper_intro.rewind.continue",
					"label": "Continue",
					"slot": "cta.continue",
				}
			}
		KeeperIntroServiceScript.STEP_AWAKENING:
			return {
				"choice.guard": { "type": "keeper_intro.awakening.choose", "slot": "choice.guard", "label": "I will guard this flame.", "choice": "guard" },
				"choice.listen": { "type": "keeper_intro.awakening.choose", "slot": "choice.listen", "label": "I will listen before I lead.", "choice": "listen" },
				"choice.return": { "type": "keeper_intro.awakening.choose", "slot": "choice.return", "label": "I will bring what was stolen home.", "choice": "return" },
			}
		KeeperIntroServiceScript.STEP_WEAVING:
			return {
				"cta.continue": {
					"type": "keeper_intro.weave.complete",
					"label": "Weave the First Thread",
					"slot": "cta.continue",
				}
			}
		KeeperIntroServiceScript.STEP_KEEPING:
			return {
				"cta.continue": {
					"type": "keeper_intro.complete",
					"label": "Keep the House",
					"slot": "cta.continue",
				}
			}
	return {}


static func _title_for_step(step: String) -> String:
	match step:
		KeeperIntroServiceScript.STEP_CALL:
			return "Call of the Realm"
		KeeperIntroServiceScript.STEP_THREAD_RETURN:
			return "A Thread Returns"
		KeeperIntroServiceScript.STEP_REWIND:
			return "The Web Turns Back"
		KeeperIntroServiceScript.STEP_AWAKENING:
			return "Awakening Rite"
		KeeperIntroServiceScript.STEP_WEAVING:
			return "The First Weaving Rite"
		KeeperIntroServiceScript.STEP_KEEPING:
			return "Into the Keeping"
	return "The House Stirs"


static func _lines_for_step(step: String, echo: Dictionary, virtue: String, flame: Dictionary) -> Array:
	var echo_name := str(echo.get("name", "your Echo"))
	var virtue_label := str(OnboardingService.VIRTUE_LABELS.get(virtue, virtue.capitalize()))
	match step:
		KeeperIntroServiceScript.STEP_CALL:
			return [
				"The house has a name now. The Realm has heard it.",
				"A wound opens in the web, and %s feels it pull." % echo_name,
				"Go carefully, Keeper. This first answering will teach the house what it must become.",
			]
		KeeperIntroServiceScript.STEP_THREAD_RETURN:
			return [
				"The wound breaks, but not into silence.",
				"A First Thread returns carrying %s, ember-warm and unfinished." % virtue_label,
				"The house receives 40 Ase. The Thread now waits in reserve.",
			]
		KeeperIntroServiceScript.STEP_REWIND:
			return [
				"Ah. No, no. These stories have only just started.",
				"We cannot have you dying and failing already. Not yet. Not when the web has barely begun to shake.",
				"Let us do this story again. I have not been entertained enough.",
				"Reach further next time, little Keeper. The web is wider than this wound, and some stories are too heavy to drop on the first knot.",
			]
		KeeperIntroServiceScript.STEP_AWAKENING:
			return [
				"The ember belongs in the center of the house.",
				"Speak over it. What you promise now wakes the Ase Flame.",
			]
		KeeperIntroServiceScript.STEP_WEAVING:
			return [
				"The First Thread is not for the shelf.",
				"%s stands ready. Let the recovered story settle into them." % echo_name,
				"This weave grants Storyweight and deepens %s." % virtue_label,
			]
		KeeperIntroServiceScript.STEP_KEEPING:
			return [
				"The Flame holds.",
				"The Thread holds.",
				"The house is yours now, Keeper.",
			]
	return []


static func _awakening_choices() -> Array:
	return [
		{ "slot": "choice.guard", "label": "I will guard this flame." },
		{ "slot": "choice.listen", "label": "I will listen before I lead." },
		{ "slot": "choice.return", "label": "I will bring what was stolen home." },
	]

class_name FlowOnboardingState

extends State

var _step: String

func _init(id: String, step: String) -> void:
	_step = step
	super(id)

func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	flow_ctx.last_snapshot = build_snapshot(flow_ctx, t, _step, get_id())

func exit(ctx: RefCounted, t: int) -> void:
	pass

static func build_snapshot(flow_ctx: FlowContext, t: int, step: String, flow_id: String) -> Dictionary:
	var cfg: Dictionary = flow_ctx.config_service.get_balance() if flow_ctx.config_service != null else {}
	var onboarding := OnboardingService.ensure_onboarding(flow_ctx.save_data, cfg)
	var data := _base_data(step, onboarding, flow_ctx.save_data, cfg)
	return {
		"type": flow_id,
		"meta": { "t": t },
		"data": data,
		"actions": _actions_for_step(step, onboarding),
	}

static func _base_data(step: String, onboarding: Dictionary, save_data: Dictionary, cfg: Dictionary) -> Dictionary:
	var selected := OnboardingService.selected_fragment(save_data, cfg)
	var echo := OnboardingService.get_starter_echo(save_data)
	return {
		"step": step,
		"fragment_options": onboarding.get("fragment_options", []),
		"heard_fragments": onboarding.get("heard_fragments", []),
		"selected_fragment": str(onboarding.get("selected_fragment", "")),
		"selected_fragment_data": selected,
		"starter_echo": _echo_summary(echo),
		"name_options": onboarding.get("name_options", []),
		"sanctum_layout": SanctumLayoutService.snapshot_layout(save_data),
		"sanctum_occupants": SanctumLayoutService.snapshot_occupants(save_data),
	}

static func _actions_for_step(step: String, onboarding: Dictionary) -> Dictionary:
	match step:
		OnboardingService.STEP_INVOCATION:
			return {
				"cta.continue": {
					"type": "onboarding.advance",
					"label": "Begin",
					"slot": "cta.continue",
				}
			}
		OnboardingService.STEP_ANANSI:
			return {
				"cta.continue": {
					"type": "onboarding.advance",
					"label": "Continue",
					"slot": "cta.continue",
				}
			}
		OnboardingService.STEP_CHOOSE_NAME:
			var selected := str(onboarding.get("selected_fragment", ""))
			return {
				"cta.confirm": {
					"type": "onboarding.fragment.confirm",
					"label": "COMMIT TO ONE",
					"slot": "cta.confirm",
					"disabled": selected == "",
				}
			}
		OnboardingService.STEP_MEETING:
			return {
				"cta.continue": {
					"type": "onboarding.advance",
					"label": "Enter the Sanctum",
					"slot": "cta.continue",
				}
			}
		OnboardingService.STEP_EMPTY_SANCTUM:
			return {
				"cta.continue": {
					"type": "onboarding.advance",
					"label": "Name This Place",
					"slot": "cta.continue",
				}
			}
		OnboardingService.STEP_NAME_SANCTUM:
			return {
				"cta.confirm": {
					"type": "onboarding.name.confirm",
					"label": "Keep This Name",
					"slot": "cta.confirm",
					"disabled": false,
				}
			}
	return {}

static func _echo_summary(echo: Dictionary) -> Dictionary:
	if echo.is_empty():
		return {}
	var emo := EmotionService.get_emotion(echo)
	var stats_v: Variant = echo.get("stats", {})
	var stats: Dictionary = stats_v if stats_v is Dictionary else {}
	var traits_v: Variant = echo.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}
	return {
		"name": str(echo.get("name", "")),
		"archetype_birth": str(echo.get("archetype_birth", "")),
		"standing": int(echo.get("rank", 1)),
		"step": int(echo.get("level", 1)),
		"storyweight": int(echo.get("xp_total", 0)),
		"dominant_vector": str(echo.get("dominant_vector", "")),
		"calling_origin": str(echo.get("calling_origin", "")),
		"traits": traits.duplicate(true),
		"stats": stats.duplicate(true),
		"emotional_status": EmotionService.get_emotional_status(
			int(emo.get("morale_current", 50)),
			int(emo.get("fear_current", 0))
		),
	}

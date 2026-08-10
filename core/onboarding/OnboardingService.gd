extends RefCounted

class_name OnboardingService

const STEP_INVOCATION := "invocation"
const STEP_ANANSI := "anansi"
const STEP_CHOOSE_NAME := "choose_forgotten_name"
const STEP_MEETING := "meeting"
const STEP_EMPTY_SANCTUM := "empty_sanctum"
const STEP_NAME_SANCTUM := "name_sanctum"
const STEP_COMPLETE := "complete"

const STEPS := [
	STEP_INVOCATION,
	STEP_ANANSI,
	STEP_CHOOSE_NAME,
	STEP_MEETING,
	STEP_EMPTY_SANCTUM,
	STEP_NAME_SANCTUM,
]

const VIRTUE_LABELS := {
	"courage": "Courage",
	"wisdom": "Wisdom",
	"leadership": "Leadership",
	"acceptance": "Acceptance",
	"humility": "Humility",
	"forgiveness": "Forgiveness",
	"truth": "Truth",
	"generosity": "Generosity",
	"compassion": "Compassion",
	"empathy": "Empathy",
}

const FRAGMENT_NAMES := {
	"courage": "The Brave One",
	"wisdom": "The Wise One",
	"leadership": "The Proud One",
	"acceptance": "The Accepting One",
	"humility": "The Humble One",
	"forgiveness": "The Forgiving One",
	"truth": "The True One",
	"generosity": "The Generous One",
	"compassion": "The Compassionate One",
	"empathy": "The Empathic One",
}

const FRAGMENT_BARKS := {
	"courage": "I remember the place where fear became a doorway.",
	"wisdom": "I remember the question that waited longer than an answer.",
	"leadership": "I remember standing where others needed a voice.",
	"acceptance": "I remember the shape of what could not be changed.",
	"humility": "I remember kneeling without becoming small.",
	"forgiveness": "I remember the hand that opened after harm.",
	"truth": "I remember the word no shadow could keep.",
	"generosity": "I remember giving before I knew my own hunger.",
	"compassion": "I remember another wound as if it were mine.",
	"empathy": "I remember the feeling beneath another name.",
}

static func ensure_onboarding(save_data: Dictionary, cfg: Dictionary) -> Dictionary:
	if not save_data.has("onboarding") or not (save_data["onboarding"] is Dictionary):
		save_data["onboarding"] = {
			"chapter_one_complete": not bool(save_data.get("first_boot", true)),
		}

	var onboarding: Dictionary = save_data["onboarding"]
	if not onboarding.has("chapter_one_complete") or typeof(onboarding["chapter_one_complete"]) != TYPE_BOOL:
		onboarding["chapter_one_complete"] = false
	if not onboarding.has("chapter_one_step") or typeof(onboarding["chapter_one_step"]) != TYPE_STRING:
		onboarding["chapter_one_step"] = STEP_INVOCATION
	if not onboarding.has("heard_fragments") or not (onboarding["heard_fragments"] is Array):
		onboarding["heard_fragments"] = []
	if not onboarding.has("selected_fragment") or typeof(onboarding["selected_fragment"]) != TYPE_STRING:
		onboarding["selected_fragment"] = ""
	if not onboarding.has("fragment_options") or not (onboarding["fragment_options"] is Array) \
			or (onboarding["fragment_options"] as Array).size() != 3:
		onboarding["fragment_options"] = build_fragment_options(save_data, cfg)
	if not onboarding.has("name_options") or not (onboarding["name_options"] is Array) \
			or (onboarding["name_options"] as Array).size() != 3:
		onboarding["name_options"] = build_name_options(save_data)

	return onboarding

static func is_chapter_one_complete(save_data: Dictionary) -> bool:
	var onboarding_v: Variant = save_data.get("onboarding", {})
	var onboarding: Dictionary = onboarding_v if onboarding_v is Dictionary else {}
	return bool(onboarding.get("chapter_one_complete", false))

static func current_step(save_data: Dictionary, cfg: Dictionary) -> String:
	var onboarding := ensure_onboarding(save_data, cfg)
	if bool(onboarding.get("chapter_one_complete", false)):
		return STEP_COMPLETE
	var step := str(onboarding.get("chapter_one_step", STEP_INVOCATION))
	if step not in STEPS:
		step = STEP_INVOCATION
		onboarding["chapter_one_step"] = step
	return step

static func set_step(save_data: Dictionary, cfg: Dictionary, step: String) -> void:
	var onboarding := ensure_onboarding(save_data, cfg)
	onboarding["chapter_one_step"] = step if step in STEPS else STEP_INVOCATION

static func next_step(step: String) -> String:
	var idx := STEPS.find(step)
	if idx < 0:
		return STEP_INVOCATION
	if idx >= STEPS.size() - 1:
		return STEP_COMPLETE
	return str(STEPS[idx + 1])

static func mark_heard(save_data: Dictionary, cfg: Dictionary, virtue: String) -> void:
	var onboarding := ensure_onboarding(save_data, cfg)
	var heard: Array = onboarding.get("heard_fragments", [])
	if not virtue in heard:
		heard.append(virtue)
	onboarding["heard_fragments"] = heard

static func select_fragment(save_data: Dictionary, cfg: Dictionary, virtue: String) -> void:
	var onboarding := ensure_onboarding(save_data, cfg)
	if _has_fragment(onboarding, virtue):
		onboarding["selected_fragment"] = virtue

static func mark_complete(save_data: Dictionary, cfg: Dictionary) -> void:
	var onboarding := ensure_onboarding(save_data, cfg)
	onboarding["chapter_one_complete"] = true
	onboarding["chapter_one_step"] = STEP_COMPLETE

static func build_fragment_options(save_data: Dictionary, cfg: Dictionary) -> Array:
	var vector_to_virtue := get_vector_to_virtue(cfg)
	var virtues: Array = []
	for vector_key in vector_to_virtue:
		if str(vector_key).begins_with("_"):
			continue  # skip metadata keys (e.g. "_comment") — not a vector id
		var virtue := str(vector_to_virtue[vector_key])
		if virtue != "" and not virtue in virtues:
			virtues.append(virtue)
	virtues.sort()

	var camp_v: Variant = save_data.get("campaign", {})
	var camp: Dictionary = camp_v if camp_v is Dictionary else {}
	var seed := CampaignSeed.new(int(camp.get("root_seed", 0)))

	var picks: Array = []
	var available := virtues.duplicate()
	for i in range(3):
		if available.is_empty():
			break
		var s := int(seed.derive("onboarding.chapter_one.fragment.%d" % i))
		var idx := s % available.size()
		var virtue := str(available[idx])
		available.remove_at(idx)
		picks.append({
			"virtue": virtue,
			"vector": vector_for_virtue(cfg, virtue),
			"label": str(FRAGMENT_NAMES.get(virtue, "The Forgotten One")),
			"bark": str(FRAGMENT_BARKS.get(virtue, "I remember only that I was called.")),
		})
	return picks

static func build_name_options(save_data: Dictionary) -> Array:
	var camp_v: Variant = save_data.get("campaign", {})
	var camp: Dictionary = camp_v if camp_v is Dictionary else {}
	var seed := CampaignSeed.new(int(camp.get("root_seed", 0)))
	var out: Array = []
	for i in range(3):
		var name := SanctumNameService.suggest(seed, i)
		out.append({
			"name": name,
			"meaning": "Placeholder meaning",
			"omen": "Placeholder omen for %s." % name,
		})
	return out

## Returns the canonical virtue -> vector keying permutation (V2-PROG-012 Phase 9:
## data.contact.virtue_vector_key — relocated + renamed from
## data.weaving_rite.vector_to_virtue_primary). This is a bijection used ONLY to invert
## virtue -> vector for seeding (not a semantic composition claim — see its _comment).
static func get_vector_to_virtue(cfg: Dictionary) -> Dictionary:
	var data_v: Variant = cfg.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var contact_v: Variant = data.get("contact", {})
	var contact: Dictionary = contact_v if contact_v is Dictionary else {}
	var map_v: Variant = contact.get("virtue_vector_key", {})
	return map_v if map_v is Dictionary else {}

static func vector_for_virtue(cfg: Dictionary, virtue: String) -> String:
	var map := get_vector_to_virtue(cfg)
	for vector_key in map:
		if str(vector_key).begins_with("_"):
			continue  # skip metadata keys (e.g. "_comment") — not a vector id
		if str(map[vector_key]) == virtue:
			return str(vector_key)
	return ""

static func selected_fragment(save_data: Dictionary, cfg: Dictionary) -> Dictionary:
	var onboarding := ensure_onboarding(save_data, cfg)
	var selected := str(onboarding.get("selected_fragment", ""))
	for item_v in (onboarding.get("fragment_options", []) as Array):
		if item_v is Dictionary:
			var item: Dictionary = item_v
			if str(item.get("virtue", "")) == selected:
				return item
	return {}

static func get_starter_echo(save_data: Dictionary) -> Dictionary:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	if roster.is_empty():
		return {}
	var echo_v: Variant = roster[0]
	return echo_v if echo_v is Dictionary else {}

static func step_to_flow_id(step: String) -> String:
	match step:
		STEP_INVOCATION:
			return FlowStateIds.ONBOARDING_INVOCATION
		STEP_ANANSI:
			return FlowStateIds.ONBOARDING_ANANSI
		STEP_CHOOSE_NAME:
			return FlowStateIds.ONBOARDING_CHOOSE_NAME
		STEP_MEETING:
			return FlowStateIds.ONBOARDING_MEETING
		STEP_EMPTY_SANCTUM:
			return FlowStateIds.ONBOARDING_EMPTY_SANCTUM
		STEP_NAME_SANCTUM:
			return FlowStateIds.ONBOARDING_NAME_SANCTUM
	return FlowStateIds.ONBOARDING_INVOCATION

static func _has_fragment(onboarding: Dictionary, virtue: String) -> bool:
	for item_v in (onboarding.get("fragment_options", []) as Array):
		if item_v is Dictionary and str((item_v as Dictionary).get("virtue", "")) == virtue:
			return true
	return false

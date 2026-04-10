class_name DirectiveService
extends RefCounted

# V2-DIRECTIVE-001: Single choke point for all directive reads and mutations.
# Mirrors EconomyService pattern: instantiated in FlowRuntime.boot() with a save_data reference.
#
# Registry holds known directive definitions keyed by stable ID string.
# unlock_condition == "always"  → returned by get_available_directives() (player-selectable)
#
# intent_weights is a shared vocabulary Dictionary. Keys not present = 0 / neutral.
# Consumed by BehaviorArbiter via directive_action_muls translation table in balance.json.
#
# Each directive also carries:
#   pros  — Array[String] of 2 player-facing benefit labels (game-tone, not mechanical)
#   cons  — Array[String] of 2 player-facing risk labels (game-tone, not mechanical)

const _REGISTRY: Dictionary = {
	"directive.scout_carefully": {
		"id":          "directive.scout_carefully",
		"label":       "Scout Carefully",
		"description": "The land will speak if you give it time. Move with patience. Do not give more than the run asks of you.",
		"pros": [
			"Party more likely to return with what they know intact",
			"Stronger footing when a run fails or turns partial"
		],
		"cons": [
			"Progress toward objectives comes slower",
			"Less likely to surface signs that require exposure to find"
		],
		"intent_weights": {
			"survival_bias":       0.40,
			"avoid_overcommit":    0.30,
			"prefer_disengage":    0.20,
			"resource_efficiency": 0.10
		},
		"unlock_condition": "always"
	},
	"directive.seek_signs": {
		"id":          "directive.seek_signs",
		"label":       "Seek Signs",
		"description": "Something in this realm is waiting to be found. Push deeper. Stay alert. What is hidden will cost something to reach.",
		"pros": [
			"Higher chance of surfacing hidden readiness clues and omen-language",
			"Deeper intel when the run goes well"
		],
		"cons": [
			"Greater exposure to contact and open threat",
			"A bad run becomes costlier than it needed to be"
		],
		"intent_weights": {
			"clue_seeking_priority": 0.40,
			"reporting_priority":    0.30,
			"exposure_acceptance":   0.20,
			"survival_bias":         0.10
		},
		"unlock_condition": "always"
	}
	# ---- Expansion directives (deferred — do not build from these) ----
	# directive.protect, directive.push, directive.preserve, directive.focus
	# → superseded for Foundation; will be introduced in a future DIRECTIVE story.
}

var _save_ref: Dictionary

func _init(save_ref: Dictionary) -> void:
	_save_ref = save_ref


# Returns all directive definitions keyed by directive ID.
func get_registry() -> Dictionary:
	return _REGISTRY.duplicate(true)


# Returns a single directive definition by ID.
# Returns {} if the ID is not in the registry.
func get_directive(id: String) -> Dictionary:
	if _REGISTRY.has(id):
		return (_REGISTRY[id] as Dictionary).duplicate(true)
	return {}


# Writes active_directive_id to stage_context and logs directive.selected.
# Returns early with a warning if the ID is not in the registry.
func set_active_directive(id: String, logger: StructuredLogger, t: int) -> void:
	if not _REGISTRY.has(id):
		logger.info(t, "directive.select.invalid", "Unknown directive ID — ignoring", { "directive_id": id })
		return

	if not _save_ref.has("stage_context") or typeof(_save_ref["stage_context"]) != TYPE_DICTIONARY:
		_save_ref["stage_context"] = {}

	_save_ref["stage_context"]["active_directive_id"] = id

	logger.info(t, "directive.selected", "Directive selected", { "directive_id": id, "t": t })


# Returns the full definition of the currently active directive.
# Falls back to directive.none if the stored ID is missing or unknown.
func get_active_directive() -> Dictionary:
	var sc: Dictionary = _save_ref.get("stage_context", {})
	var id := str(sc.get("active_directive_id", "directive.scout_carefully"))
	var defn: Dictionary = get_directive(id)
	if defn.is_empty():
		return get_directive("directive.scout_carefully")
	return defn


# Returns the IDs of all directives with unlock_condition == "always".
# MVP result: ["directive.none", "directive.scout"]
# DIRECTIVE-002 will extend this with dynamic unlock logic.
func get_available_directives() -> Array:
	var result: Array = []
	for id in _REGISTRY:
		var defn: Dictionary = _REGISTRY[id]
		if str(defn.get("unlock_condition", "")) == "always":
			result.append(id)
	return result

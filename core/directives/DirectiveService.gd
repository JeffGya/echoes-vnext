class_name DirectiveService
extends RefCounted

# DIRECTIVE-001: Single choke point for all directive reads and mutations.
# Mirrors EconomyService pattern: instantiated in FlowRuntime.boot() with a save_data reference.
#
# Registry holds all known directive definitions keyed by stable ID string.
# unlock_condition == "always"  → returned by get_available_directives() (player-selectable)
# unlock_condition == "locked"  → in registry for contract validation; not yet selectable
#
# intent_weights is a shared vocabulary Dictionary. Keys not present = 0 / neutral.
# Consumed by Actor SM Layer 4 (Context Bias) — ACTOR-004+.

const _REGISTRY: Dictionary = {
	"directive.none": {
		"id":             "directive.none",
		"label":          "No Directive",
		"description":    "Baseline — no intent bias applied.",
		"intent_weights": {},
		"unlock_condition": "always"
	},
	"directive.scout": {
		"id":             "directive.scout",
		"label":          "Scout",
		"description":    "Survival-biased recon intent. Prioritise information gathering and safe withdrawal.",
		"intent_weights": {
			"survival_bias":       0.3,
			"avoid_overcommit":    0.3,
			"prefer_disengage":    0.2,
			"reporting_priority":  0.2
		},
		"unlock_condition": "always"
	},
	# ---- Future directives (unlock_condition: "locked") ----
	# Defined now to validate contract shape. unlock_condition change in DIRECTIVE-002+.
	"directive.protect": {
		"id":             "directive.protect",
		"label":          "Protect",
		"description":    "Shield the party — intercept threats to allies, guard formations, absorb hits.",
		"intent_weights": {
			"ally_protection_bias": 0.4,
			"threat_interception":  0.3,
			"formation_cohesion":   0.2,
			"survival_bias":        0.1
		},
		"unlock_condition": "locked"
	},
	"directive.push": {
		"id":             "directive.push",
		"label":          "Push",
		"description":    "Advance toward the stage objective. Engage only what blocks the path.",
		"intent_weights": {
			"objective_advance_priority": 0.5,
			"engage_only_blockers":       0.3,
			"avoid_side_engagement":      0.2
		},
		"unlock_condition": "locked"
	},
	"directive.preserve": {
		"id":             "directive.preserve",
		"label":          "Preserve",
		"description":    "Resource-conscious play. Use minimum force — avoid waste of HP, skills, or Ase.",
		"intent_weights": {
			"resource_efficiency":    0.4,
			"avoid_overcommit":       0.3,
			"retreat_on_disadvantage": 0.2,
			"survival_bias":          0.1
		},
		"unlock_condition": "locked"
	},
	"directive.focus": {
		"id":             "directive.focus",
		"label":          "Focus",
		"description":    "Single-skill mastery. Each Echo leans into their dominant skill or vector for optimised, predictable execution.",
		"intent_weights": {
			"dominant_skill_bias":       0.5,
			"consistency_priority":      0.3,
			"vector_alignment_priority": 0.2
		},
		"unlock_condition": "locked"
	}
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
	var id := str(sc.get("active_directive_id", "directive.none"))
	var defn: Dictionary = get_directive(id)
	if defn.is_empty():
		return get_directive("directive.none")
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

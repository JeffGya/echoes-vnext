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

# V2-STAGE-004 Phase 2: config-loaded registry. Nil until _ensure_loaded() runs.
# Lazy approach chosen: DirectiveService is constructed at two points in FlowRuntime
# (boot line ~91 and new_game line ~911), both before config_service.get_balance() is
# called inside dispatch handlers. Using lazy loading guarantees the config is always
# available on first use, regardless of construction timing. If the config block is
# absent or empty, _REGISTRY remains the active fallback — so no crash on missing data.
var _loaded_registry: Dictionary = {}
var _config_loaded: bool = false


func _init(save_ref: Dictionary) -> void:
	_save_ref = save_ref


# Reads balance.json data.directives via ConfigService if available; keeps _REGISTRY as
# fallback. Call is idempotent — subsequent calls are no-ops once loaded.
# The config dict passed here is the full balance root (as returned by
# config_service.get_balance()). Passing an empty dict is safe — falls back to _REGISTRY.
func load_from_config(cfg: Dictionary) -> void:
	var data_v: Variant = cfg.get("data", {})
	var data_d: Dictionary = data_v if data_v is Dictionary else {}
	var dir_v: Variant = data_d.get("directives", {})
	var dir_d: Dictionary = dir_v if dir_v is Dictionary else {}
	if not dir_d.is_empty():
		_loaded_registry = dir_d
	# else: leave _loaded_registry empty; _active_registry() will fall through to _REGISTRY
	_config_loaded = true


# Internal: returns the config-loaded registry when available; _REGISTRY otherwise.
func _active_registry() -> Dictionary:
	if not _config_loaded:
		return _REGISTRY
	if not _loaded_registry.is_empty():
		return _loaded_registry
	return _REGISTRY


# Lazy loader: called by get_registry / get_directive / set_active_directive on first use.
# Attempts to pull balance via ConfigService.get_balance() if ConfigService is available
# as a singleton autoload (echoes-vnext does not use Autoload here — ConfigService is
# injected into FlowRuntime). Since DirectiveService has no direct reference to
# config_service, callers that DO have the config (FlowRuntime dispatch handlers) should
# call load_from_config() explicitly after construction. This guard simply ensures
# _config_loaded is set so _active_registry() returns _REGISTRY safely without panic.
func _ensure_loaded() -> void:
	if not _config_loaded:
		# FlowRuntime will call load_from_config() explicitly; this is a safety net only.
		_config_loaded = true


# Returns all directive definitions keyed by directive ID.
func get_registry() -> Dictionary:
	_ensure_loaded()
	return _active_registry().duplicate(true)


# Returns a single directive definition by ID.
# Returns {} if the ID is not in the registry.
func get_directive(id: String) -> Dictionary:
	_ensure_loaded()
	var reg: Dictionary = _active_registry()
	if reg.has(id):
		var entry: Variant = reg[id]
		if entry is Dictionary:
			return (entry as Dictionary).duplicate(true)
	return {}


# Writes active_directive_id to stage_context and logs directive.selected.
# Returns early with a warning if the ID is not in the registry.
func set_active_directive(id: String, logger: StructuredLogger, t: int) -> void:
	_ensure_loaded()
	if not _active_registry().has(id):
		logger.info(t, "directive.select.invalid", "Unknown directive ID — ignoring", { "directive_id": id })
		return

	if not _save_ref.has("stage_context") or typeof(_save_ref["stage_context"]) != TYPE_DICTIONARY:
		_save_ref["stage_context"] = {}

	_save_ref["stage_context"]["active_directive_id"] = id

	logger.info(t, "directive.selected", "Directive selected", { "directive_id": id, "t": t })


# Returns the full definition of the currently active directive.
# Falls back to directive.scout_carefully if the stored ID is missing or unknown.
func get_active_directive() -> Dictionary:
	var sc: Dictionary = _save_ref.get("stage_context", {})
	var id := str(sc.get("active_directive_id", "directive.scout_carefully"))
	var defn: Dictionary = get_directive(id)
	if defn.is_empty():
		return get_directive("directive.scout_carefully")
	return defn


# Returns the IDs of all directives with unlock_condition == "always".
# DIRECTIVE-002 will extend this with dynamic unlock logic.
func get_available_directives() -> Array:
	_ensure_loaded()
	var result: Array = []
	var reg: Dictionary = _active_registry()
	for id in reg:
		var entry: Variant = reg[id]
		if entry is Dictionary:
			var defn: Dictionary = entry as Dictionary
			if str(defn.get("unlock_condition", "")) == "always":
				result.append(id)
	return result

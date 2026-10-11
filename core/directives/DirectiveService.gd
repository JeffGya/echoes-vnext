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

## V2-COMBAT-002 Slice 6 Phase 6A — the ONE step-budget fallback.
##
## The REAL value is always authored per directive in `data.directives.<id>.step_budget`
## (Scout Carefully 3, Seek Signs 6) and is read from balance.json by every consumer.
## This constant is ONLY the missing-key default for a directive dict that carries no
## `step_budget` at all — a malformed, partially-loaded, or legacy-save directive.
##
## It deliberately lives on this class rather than in balance.json: it is the fallback
## FOR a balance.json read, so sourcing it from the same file it guards would be
## circular — the case it exists to cover is precisely the case where that file did not
## supply the value. It also stays out of `core/movement/`, which is still dormant and
## must not acquire a production caller.
##
## `FlowRuntime` and `FlowStageExploreState` previously each hardcoded their own `3`
## and could silently diverge. Both now read this.
const DEFAULT_STEP_BUDGET: int = 3

## Fallback Directive when the stored id is missing or not in the registry.
const DEFAULT_DIRECTIVE_ID: String = "directive.scout_carefully"

## The only unlock_condition values the integrity guard accepts.
const KNOWN_UNLOCK_CONDITIONS: Array = ["always"]

## Directive entry schema: key -> value kind. Every key is required except those in OPTIONAL_KEYS.
const ENTRY_SCHEMA: Dictionary = {
	"id": "string", "label": "string", "description": "string",
	"intent_weights": "dict", "unlock_condition": "string", "pros": "array", "cons": "array",
	"step_budget": "number", "reveal_radius": "number", "passive_reveal": "bool",
	"passive_reveal_radius": "number", "target_preference": "dict", "precise_intel_bias": "number",
	"exposure_tolerance": "number", "escape_bonus": "number", "intel_retention": "bool",
	"intel_retention_bonus": "number", "contact_effects": "dict",
}
const OPTIONAL_KEYS: Array = ["contact_effects"]

## contact_effects key -> value kind. A new effect kind needs a reader in code, so it is listed here.
const CONTACT_EFFECT_KEYS: Dictionary = {
	"bid_suppression": "array", "bid_boost": "array",
	"witness_resonance_bonus": "number", "guide_reveal_bonus": "number",
}

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


# Stored active Directive id, or the default when missing or not a String.
# Reads stage_context only: flow.active_directive is a dead legacy key.
static func active_id(save: Dictionary) -> String:
	var sc_v: Variant = save.get("stage_context", {})
	var sc: Dictionary = sc_v if sc_v is Dictionary else {}
	var id_v: Variant = sc.get("active_directive_id", DEFAULT_DIRECTIVE_ID)
	return id_v if id_v is String and not (id_v as String).is_empty() else DEFAULT_DIRECTIVE_ID


# Active Directive entry from the given data.directives dict.
# An unknown id resolves to the default Directive. Pure read: builds nothing that writes the save.
static func resolve(save: Dictionary, directives_cfg: Dictionary) -> Dictionary:
	var reg: Dictionary = registry_of(directives_cfg)
	var entry_v: Variant = reg.get(active_id(save), reg.get(DEFAULT_DIRECTIVE_ID, _REGISTRY[DEFAULT_DIRECTIVE_ID]))
	var entry: Dictionary = entry_v if entry_v is Dictionary else _REGISTRY[DEFAULT_DIRECTIVE_ID]
	return entry.duplicate(true)


# The config registry, or the built-in fallback when the config has none.
static func registry_of(directives_cfg: Dictionary) -> Dictionary:
	return directives_cfg if not directives_cfg.is_empty() else _REGISTRY


# Ids of Directives with unlock_condition "always", in registry order.
static func available_ids(directives_cfg: Dictionary) -> Array:
	var reg: Dictionary = registry_of(directives_cfg)
	var result: Array = []
	for id in reg:
		var entry: Variant = reg[id]
		if entry is Dictionary and str((entry as Dictionary).get("unlock_condition", "")) == "always":
			result.append(id)
	return result


# Returns the full definition of the currently active directive.
func get_active_directive() -> Dictionary:
	_ensure_loaded()
	return DirectiveService.resolve(_save_ref, _active_registry())


# Returns the IDs of all directives with unlock_condition == "always".
func get_available_directives() -> Array:
	_ensure_loaded()
	return DirectiveService.available_ids(_active_registry())


## V2-PROG-012 Phase 6 Item 3(c) — config-integrity guard, same precedent as
## CallingService.validate_config_integrity() (called once at boot, alongside it,
## from ConfigService.load_balance()).
##
## Flags (logs a warning, does NOT fail the load) any directive whose
## intent_weights are degenerate in a way that would make it INVISIBLE to
## DivergenceDetector.gd forever, without anything crashing:
##   - empty intent_weights
##   - every weight <= 0.0 (BehaviorArbiter._directive_bonus() sums
##     dir_weight * directive_action_muls[action][key] * base_bonus — an
##     all-non-positive weight set can never push a directive_bonus above the
##     baseline for ANY action_type, so directive_pull, which requires
##     directive_preferred to OUT-bonus the chosen candidate, can never be
##     positive)
##   - every semantic key in intent_weights is ABSENT from every row of
##     data.actor.directive_action_muls (the translation table
##     _directive_bonus() reads) — a key with no translation entry contributes
##     0.0 to every action's bonus, so if NONE of a directive's keys have a
##     translation entry, directive_bonus is silently 0.0 for every action,
##     every turn, forever
##
## Any of these three shapes means the new directive can never be diverged
## against — GDD:1422's "Standing never buys obedience" becomes vacuously true
## for it because there is nothing to obey in the first place. This is exactly
## the designer's "the game should not break due to those being added" case:
## nothing crashes, but the seam silently goes dormant for that one directive.
## This check makes that loud at boot instead of silent forever.
static func validate_config_integrity(directives_cfg: Dictionary, actor_cfg: Dictionary, logger, t: int) -> bool:
	var all_valid := true
	var dir_muls_v: Variant = actor_cfg.get("directive_action_muls", {})
	var dir_muls_table: Dictionary = dir_muls_v if dir_muls_v is Dictionary else {}

	# Every semantic key referenced by ANY action_type's translation row —
	# a directive whose intent_weights keys are entirely outside this set has
	# no path to a nonzero directive_bonus for any action.
	var known_semantic_keys: Dictionary = {}
	for atype_v in dir_muls_table:
		var row_v: Variant = dir_muls_table[atype_v]
		var row: Dictionary = row_v if row_v is Dictionary else {}
		for key_v in row:
			known_semantic_keys[str(key_v)] = true

	for did_v in directives_cfg:
		var did: String = str(did_v)
		var directive_v: Variant = directives_cfg[did_v]
		var directive: Dictionary = directive_v if directive_v is Dictionary else {}
		var weights_v: Variant = directive.get("intent_weights", {})
		var weights: Dictionary = weights_v if weights_v is Dictionary else {}

		if weights.is_empty():
			if logger != null:
				logger.info(t, "directive.config.warn",
					"Directive '%s' has empty intent_weights — directive_bonus will be 0.0 for every action; DivergenceDetector can never register a meaningful directive preference for it." % did,
					{"directive_id": did})
			all_valid = false
			continue

		var any_positive := false
		var any_known_key := false
		for key_v in weights:
			var key: String = str(key_v)
			if float(weights[key_v]) > 0.0:
				any_positive = true
			if known_semantic_keys.has(key):
				any_known_key = true

		if not any_positive:
			if logger != null:
				logger.info(t, "directive.config.warn",
					"Directive '%s' intent_weights are all <= 0.0 — directive_bonus can never rise above baseline for any action; this directive can never win a directive_bonus contest." % did,
					{"directive_id": did, "intent_weights": weights})
			all_valid = false

		if not any_known_key:
			if logger != null:
				logger.info(t, "directive.config.warn",
					"Directive '%s' intent_weights reference NO semantic key present in any data.actor.directive_action_muls row — directive_bonus is silently 0.0 for every action_type, so this directive can never be diverged against." % did,
					{"directive_id": did, "intent_weights": weights})
			all_valid = false

	return all_valid


## Rejects any Directive entry with a missing required key, an unknown key, a wrong value type,
## an id that differs from its registry key, or an unlock_condition outside KNOWN_UNLOCK_CONDITIONS.
## Kept apart from validate_config_integrity (intent_weights health) so each fixture stays minimal.
static func validate_entry_schema(directives_cfg: Dictionary, logger, t: int) -> bool:
	var all_valid := true
	for did_v in directives_cfg:
		var did: String = str(did_v)
		if did.begins_with("_comment"):
			continue
		var problems: Array = []
		var entry_v: Variant = directives_cfg[did_v]
		if not (entry_v is Dictionary):
			problems.append("entry is not a Dictionary")
		else:
			var entry: Dictionary = entry_v
			for key in ENTRY_SCHEMA:
				if not entry.has(key):
					if key not in OPTIONAL_KEYS:
						problems.append("missing key '%s'" % key)
				elif not _kind_matches(entry[key], str(ENTRY_SCHEMA[key])):
					problems.append("key '%s' is not a %s" % [key, ENTRY_SCHEMA[key]])
			# The picker has two fixed slots per list and reads indices 0 and 1 (bounds-checked, blank when absent).
			for key in ["pros", "cons"]:
				if entry.get(key) is Array and not _is_picker_list(entry[key]):
					problems.append("key '%s' must hold 2 or more non-empty strings" % key)
			for key in entry:
				if not ENTRY_SCHEMA.has(key) and not str(key).begins_with("_comment"):
					problems.append("unknown key '%s'" % key)
			if entry.get("contact_effects") is Dictionary:
				var fx: Dictionary = entry["contact_effects"]
				for key in fx:
					if str(key).begins_with("_comment"):
						continue
					if not CONTACT_EFFECT_KEYS.has(key):
						problems.append("unknown contact_effects key '%s'" % key)
					elif not _kind_matches(fx[key], str(CONTACT_EFFECT_KEYS[key])):
						problems.append("contact_effects key '%s' is not a %s" % [key, CONTACT_EFFECT_KEYS[key]])
			if str(entry.get("id", "")) != did:
				problems.append("id '%s' does not match registry key" % str(entry.get("id", "")))
			if str(entry.get("unlock_condition", "")) not in KNOWN_UNLOCK_CONDITIONS:
				problems.append("unknown unlock_condition '%s'" % str(entry.get("unlock_condition", "")))
		if not problems.is_empty():
			all_valid = false
			if logger != null:
				logger.info(t, "directive.config.warn", "Directive '%s' is malformed: %s" % [did, "; ".join(problems)],
					{"directive_id": did, "problems": problems})
	return all_valid


static func _is_picker_list(list: Array) -> bool:
	if list.size() < 2:
		return false
	for v in list:
		if not (v is String) or (v as String).is_empty():
			return false
	return true


static func _kind_matches(v: Variant, kind: String) -> bool:
	match kind:
		"string": return v is String
		"number": return v is int or v is float
		"bool": return v is bool
		"dict": return v is Dictionary
		"array": return v is Array
	return false

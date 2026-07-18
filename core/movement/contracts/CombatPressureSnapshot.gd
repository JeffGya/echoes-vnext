class_name CombatPressureSnapshot
extends RefCounted

## Exact dormant combat pressure facts supplied by existing objective authority.

const V = preload("res://core/movement/contracts/MovementContractValidation.gd")

const MODES: Array = [
	"combat", "purify_shrine", "recover", "protect", "endure", "pursue", "guide_spirit",
]
const ALIGNMENTS: Array = ["party", "hostile", "objective"]
const FACTUAL_ROLES: Array = ["baseline", "purifier", "holder", "carrier", "quarry", "spirit"]
const REQUIRED_FIELDS: Array = [
	"mode", "guide_mode", "mover_alignment", "factual_role", "objective_known",
	"objective_id", "objective_position", "destination_region", "approach_region",
	"fallback_region", "search_region", "purifier_id", "holder_id", "carrier_id",
	"quarry_id", "spirit_id", "objective_health_ratio", "progress_current",
	"progress_required", "escort_started", "spirit_joins_battle", "totem_stolen",
	"pressure_sources",
]


static func build(
	mode: String,
	guide_mode: String,
	mover_alignment: String,
	factual_role: String,
	objective_known: bool,
	objective_id: String,
	objective_position: Dictionary,
	destination_region: Array,
	approach_region: Array,
	fallback_region: Array,
	search_region: Array,
	purifier_id: String,
	holder_id: String,
	carrier_id: String,
	quarry_id: String,
	spirit_id: String,
	objective_health_ratio: float,
	progress_current: int,
	progress_required: int,
	escort_started: bool,
	spirit_joins_battle: bool,
	totem_stolen: bool,
	pressure_sources: Array
) -> Dictionary:
	return {
		"mode": mode,
		"guide_mode": guide_mode,
		"mover_alignment": mover_alignment,
		"factual_role": factual_role,
		"objective_known": objective_known,
		"objective_id": objective_id,
		"objective_position": objective_position.duplicate(true),
		"destination_region": V.canonical_position_array(destination_region),
		"approach_region": V.canonical_position_array(approach_region),
		"fallback_region": V.canonical_position_array(fallback_region),
		"search_region": V.canonical_position_array(search_region),
		"purifier_id": purifier_id,
		"holder_id": holder_id,
		"carrier_id": carrier_id,
		"quarry_id": quarry_id,
		"spirit_id": spirit_id,
		"objective_health_ratio": objective_health_ratio,
		"progress_current": progress_current,
		"progress_required": progress_required,
		"escort_started": escort_started,
		"spirit_joins_battle": spirit_joins_battle,
		"totem_stolen": totem_stolen,
		"pressure_sources": V.canonical_string_array(pressure_sources),
	}


static func validate(value: Dictionary) -> Dictionary:
	var fields: Dictionary = V.validate_exact_fields(value, REQUIRED_FIELDS)
	if not bool(fields["valid"]):
		return fields
	for field: String in ["mode", "mover_alignment", "factual_role"]:
		var string_result: Dictionary = V.require_type(value, field, TYPE_STRING)
		if not bool(string_result["valid"]):
			return string_result
	if not MODES.has(str(value["mode"])):
		return V.failure("invalid_mode", "mode")
	if not ALIGNMENTS.has(str(value["mover_alignment"])):
		return V.failure("invalid_alignment", "mover_alignment")
	if not FACTUAL_ROLES.has(str(value["factual_role"])):
		return V.failure("invalid_factual_role", "factual_role")
	var guide_result: Dictionary = V.require_type(value, "guide_mode", TYPE_STRING)
	if not bool(guide_result["valid"]):
		return guide_result
	if str(value["mode"]) == "guide_spirit":
		if not str(value["guide_mode"]) in ["protect", "escort"]:
			return V.failure("invalid_guide_mode", "guide_mode")
	elif not str(value["guide_mode"]).is_empty():
		return V.failure("guide_mode_outside_guide", "guide_mode")
	for field: String in ["objective_known", "escort_started", "spirit_joins_battle", "totem_stolen"]:
		var bool_result: Dictionary = V.require_type(value, field, TYPE_BOOL)
		if not bool(bool_result["valid"]):
			return bool_result
	for field: String in [
		"objective_id", "purifier_id", "holder_id", "carrier_id", "quarry_id", "spirit_id",
	]:
		var id_result: Dictionary = V.require_type(value, field, TYPE_STRING)
		if not bool(id_result["valid"]):
			return id_result
	var objective_position_type: Dictionary = V.require_type(value, "objective_position", TYPE_DICTIONARY)
	if not bool(objective_position_type["valid"]):
		return objective_position_type
	if bool(value["objective_known"]):
		var objective_position_result: Dictionary = V.validate_position(
			value["objective_position"] as Dictionary,
			"objective_position"
		)
		if not bool(objective_position_result["valid"]):
			return objective_position_result
	elif not (value["objective_position"] as Dictionary).is_empty():
		return V.failure("unknown_objective_has_position", "objective_position")
	for field: String in ["destination_region", "approach_region", "fallback_region", "search_region"]:
		var region_result: Dictionary = V.require_canonical_position_array(value, field)
		if not bool(region_result["valid"]):
			return region_result
	if not bool(value["objective_known"]):
		for field: String in ["destination_region", "approach_region", "fallback_region"]:
			if not (value[field] as Array).is_empty():
				return V.failure("unknown_objective_has_region", field)
	var health_result: Dictionary = V.require_finite_number(value, "objective_health_ratio")
	if not bool(health_result["valid"]):
		return health_result
	if float(value["objective_health_ratio"]) < -1.0 or float(value["objective_health_ratio"]) > 1.0:
		return V.failure("number_out_of_range", "objective_health_ratio")
	if float(value["objective_health_ratio"]) > -1.0 and float(value["objective_health_ratio"]) < 0.0:
		return V.failure("invalid_unavailable_ratio", "objective_health_ratio")
	for field: String in ["progress_current", "progress_required"]:
		var progress_result: Dictionary = V.require_non_negative_int(value, field)
		if not bool(progress_result["valid"]):
			return progress_result
	var pressure_result: Dictionary = V.require_strictly_sorted_unique_strings(value, "pressure_sources")
	if not bool(pressure_result["valid"]):
		return pressure_result
	for source_value: Variant in value["pressure_sources"] as Array:
		if not V.is_semantic_token(str(source_value)):
			return V.failure("invalid_semantic_token", "pressure_sources")
	var role_id_field: String = "%s_id" % str(value["factual_role"])
	if str(value["factual_role"]) != "baseline" and str(value.get(role_id_field, "")).is_empty():
		return V.failure("factual_role_id_missing", role_id_field)
	return V.ok()

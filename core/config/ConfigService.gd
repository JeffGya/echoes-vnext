class_name ConfigService

extends RefCounted

const PATH_BALANCE := "res://data/balance.json"
const PATH_ACTORS := "res://data/actors.json"
const PATH_REALMS := "res://data/realms.json"

var _balance: Dictionary = {}
var _actors: Dictionary = {}
var _realms: Dictionary = {}

func load_balance(logger: StructuredLogger= null, t: int = -1) -> bool:
	var root := JsonFileLoader.load_dict(PATH_BALANCE, logger, t)
	if root.is_empty():
		return false
	if not ConfigValidator.validate_balance(root, logger, t):
		return false
	var data_v: Variant = root.get("data", {})
	var bal_data: Dictionary = data_v if data_v is Dictionary else {}
	var calling_cfg_v: Variant = bal_data.get("calling", {})
	var calling_cfg: Dictionary = calling_cfg_v if calling_cfg_v is Dictionary else {}
	CallingService.validate_config_integrity(calling_cfg, logger, t)
	CallingService.validate_count_integrity(calling_cfg, logger, t)
	# V2-PROG-012 Phase 6 Item 3(c): flags a directive whose intent_weights can
	# never produce a nonzero directive_bonus (empty / all non-positive / no
	# translated semantic key) — see DirectiveService.validate_config_integrity()'s
	# doc comment. Warns only; does not fail the load.
	var directives_cfg_v: Variant = bal_data.get("directives", {})
	var directives_cfg: Dictionary = directives_cfg_v if directives_cfg_v is Dictionary else {}
	var actor_cfg_v: Variant = bal_data.get("actor", {})
	var actor_cfg: Dictionary = actor_cfg_v if actor_cfg_v is Dictionary else {}
	DirectiveService.validate_config_integrity(directives_cfg, actor_cfg, logger, t)
	# V2-PROG-012 Phase 9: same precedent — validates the three canonical
	# vector/virtue/calling identity tables under data.contact (see
	# IdentityIntegrity.validate()'s doc comment). Warns only; does not fail the load.
	IdentityIntegrity.validate(bal_data, logger, t)
	_balance = root
	return true

func load_actors(logger: StructuredLogger= null, t: int = -1) -> bool:
	var root := JsonFileLoader.load_dict(PATH_ACTORS, logger, t)
	if root.is_empty():
		return false
	if not ConfigValidator.validate_actors(root, logger, t):
		return false
	_actors = root
	return true
	
func load_realms(logger: StructuredLogger= null, t: int = -1) -> bool:
	var root := JsonFileLoader.load_dict(PATH_REALMS, logger, t)
	if root.is_empty():
		return false
	if not ConfigValidator.validate_realms(root, logger, t):
		return false
	_realms = root
	return true
	
func get_balance() -> Dictionary:
	return _balance.duplicate(true)

func get_actors() -> Dictionary:
	return _actors.duplicate(true)

func get_realms() -> Dictionary:
	return _realms.duplicate(true)

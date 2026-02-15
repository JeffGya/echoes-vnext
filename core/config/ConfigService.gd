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

# res://tests/DirectiveLeaveFlagTests.gd
# DirectiveService.confirms_leave_items: the per-Directive "Leave these behind?" flag (D-35).

class_name DirectiveLeaveFlagTests
extends RefCounted

const SCOUT := "directive.scout_carefully"
const SEEK := "directive.seek_signs"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("directive_leave_flag/shipping_values", Callable(DirectiveLeaveFlagTests, "_t_shipping"))
	runner.register_test("directive_leave_flag/missing_unknown_and_bad_values", Callable(DirectiveLeaveFlagTests, "_t_fallbacks"))
	runner.register_test("directive_leave_flag/follows_config", Callable(DirectiveLeaveFlagTests, "_t_follows_config"))
	runner.register_test("directive_leave_flag/schema_accepts_bool_rejects_other", Callable(DirectiveLeaveFlagTests, "_t_schema"))


static func _shipping() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	return ConfigService.get_directives_cfg(cs).duplicate(true)


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


static func _t_shipping() -> Dictionary:
	var cfg := _shipping()
	var m: Array = []
	if not DirectiveService.confirms_leave_items(cfg, SCOUT):
		m.append("Scout Carefully must be true")
	if DirectiveService.confirms_leave_items(cfg, SEEK):
		m.append("Seek Signs must be false")
	# An empty config reads the built-in registry, which must carry the same values.
	if not DirectiveService.confirms_leave_items({}, SCOUT):
		m.append("built-in registry: Scout Carefully must be true")
	if DirectiveService.confirms_leave_items({}, SEEK):
		m.append("built-in registry: Seek Signs must be false")
	return _result(m)


static func _t_fallbacks() -> Dictionary:
	var m: Array = []
	var cfg := _shipping()
	var no_key: Dictionary = (cfg[SCOUT] as Dictionary).duplicate(true)
	no_key.erase("confirm_leave_items")
	if DirectiveService.confirms_leave_items({ SCOUT: no_key }, SCOUT):
		m.append("missing key must read false")
	if DirectiveService.confirms_leave_items(cfg, "directive.nope"):
		m.append("unknown id must read false")
	for bad in ["true", 1, 1.0, null, [], {}]:
		var e: Dictionary = no_key.duplicate(true)
		e["confirm_leave_items"] = bad
		if DirectiveService.confirms_leave_items({ SCOUT: e }, SCOUT):
			m.append("non-bool value %s must read false" % str(bad))
	return _result(m)


static func _t_follows_config() -> Dictionary:
	var m: Array = []
	var cfg := _shipping()
	var other: Dictionary = (cfg[SEEK] as Dictionary).duplicate(true)
	other["id"] = "directive.test_other"
	other["confirm_leave_items"] = true
	cfg["directive.test_other"] = other
	if not DirectiveService.confirms_leave_items(cfg, "directive.test_other"):
		m.append("a test Directive with the flag true must read true")
	cfg[SCOUT]["confirm_leave_items"] = false
	if DirectiveService.confirms_leave_items(cfg, SCOUT):
		m.append("changing Scout Carefully in config to false must read false")
	return _result(m)


static func _t_schema() -> Dictionary:
	var m: Array = []
	var cfg := _shipping()
	if not DirectiveService.validate_entry_schema(cfg, null, 0):
		m.append("shipping Directives with the flag failed the schema guard")
	var e: Dictionary = (cfg[SCOUT] as Dictionary).duplicate(true)
	e["confirm_leave_items"] = "yes"
	if DirectiveService.validate_entry_schema({ SCOUT: e }, null, 0):
		m.append("schema guard accepted a non-bool flag")
	e.erase("confirm_leave_items")
	if not DirectiveService.validate_entry_schema({ SCOUT: e }, null, 0):
		m.append("schema guard rejected a Directive without the flag")
	return _result(m)

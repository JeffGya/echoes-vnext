# res://tests/EconomyTests.gd
class_name EconomyTests
extends RefCounted

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("economy_add_spend", Callable(EconomyTests, "_test_add_spend"))
	runner.register_test("economy_denied_spend_no_mutation", Callable(EconomyTests, "_test_denied_spend"))
	# Roundtrip test can be added after we decide test save path strategy.

static func _test_add_spend() -> Dictionary:
	var save := { "economy": { "ase": 10, "ekwan": 0 } }
	var logger := StructuredLogger.new()
	logger.set_level("off") # tests don’t need log output

	var econ := EconomyService.new(save)
	econ.add_ase(5, "test.add", logger, 0)
	var ok := econ.spend_ase(3, "test.spend", logger, 1)

	var ase := int(save["economy"]["ase"])
	if ok != true:
		return { "ok": false, "error": "Expected spend_ase to return true" }
	if ase != 12:
		return { "ok": false, "error": "Expected ase=12, got %d" % ase }

	return { "ok": true }

static func _test_denied_spend() -> Dictionary:
	var save := { "economy": { "ase": 2, "ekwan": 0 } }
	var logger := StructuredLogger.new()
	logger.set_level("off")

	var econ := EconomyService.new(save)
	var ok := econ.spend_ase(999, "test.denied", logger, 0)

	var ase := int(save["economy"]["ase"])
	if ok != false:
		return { "ok": false, "error": "Expected spend_ase to return false" }
	if ase != 2:
		return { "ok": false, "error": "Expected ase unchanged (=2), got %d" % ase }

	return { "ok": true }
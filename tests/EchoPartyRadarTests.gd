extends RefCounted
class_name EchoPartyRadarTests


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("echo_party/radar_fixed_axis_maxima", Callable(EchoPartyRadarTests, "_test_fixed_axis_maxima"))
	runner.register_test("echo_party/radar_party_average_includes_selected", Callable(EchoPartyRadarTests, "_test_party_average"))
	runner.register_test("echo_party/radar_redundant_overlay_hidden_for_solo_party", Callable(EchoPartyRadarTests, "_test_redundant_overlay"))
	runner.register_test("echo_party/radar_normalization_safe_with_zero_maxima", Callable(EchoPartyRadarTests, "_test_normalization_safety"))


static func _test_fixed_axis_maxima() -> Dictionary:
	var screen_script: GDScript = load("res://ui/screens/sanctum/EchoPartyScreen.gd")
	var maxima: Dictionary = screen_script._fixed_axis_maxima()
	if int(maxima.get("atk", 0)) != 100:
		return { "ok": false, "error": "Expected atk max 100, got %s" % str(maxima.get("atk")) }
	if int(maxima.get("def", 0)) != 100:
		return { "ok": false, "error": "Expected def max 100, got %s" % str(maxima.get("def")) }
	if int(maxima.get("int", 0)) != 100:
		return { "ok": false, "error": "Expected int max 100, got %s" % str(maxima.get("int")) }
	if int(maxima.get("agi", 0)) != 100:
		return { "ok": false, "error": "Expected agi max 100, got %s" % str(maxima.get("agi")) }
	if int(maxima.get("cha", 0)) != 100:
		return { "ok": false, "error": "Expected cha max 100, got %s" % str(maxima.get("cha")) }
	if int(maxima.get("speed", 0)) != 100:
		return { "ok": false, "error": "Expected speed max 100, got %s" % str(maxima.get("speed")) }
	return { "ok": true }


static func _test_party_average() -> Dictionary:
	var screen_script: GDScript = load("res://ui/screens/sanctum/EchoPartyScreen.gd")
	var echoes: Array = [
		_make_echo({ "atk": 4, "def": 6, "int": 8, "agi": 10, "cha": 12, "speed": 14 }, true),
		_make_echo({ "atk": 8, "def": 10, "int": 12, "agi": 14, "cha": 16, "speed": 18 }, true),
		_make_echo({ "atk": 50, "def": 50, "int": 50, "agi": 50, "cha": 50, "speed": 50 }, false),
	]

	var averages: Dictionary = screen_script._compute_party_average_stats(echoes)
	if int(averages.get("atk", -1)) != 6:
		return { "ok": false, "error": "Expected atk average 6, got %s" % str(averages.get("atk")) }
	if int(averages.get("def", -1)) != 8:
		return { "ok": false, "error": "Expected def average 8, got %s" % str(averages.get("def")) }
	if int(averages.get("int", -1)) != 10:
		return { "ok": false, "error": "Expected int average 10, got %s" % str(averages.get("int")) }
	if int(averages.get("agi", -1)) != 12:
		return { "ok": false, "error": "Expected agi average 12, got %s" % str(averages.get("agi")) }
	if int(averages.get("cha", -1)) != 14:
		return { "ok": false, "error": "Expected cha average 14, got %s" % str(averages.get("cha")) }
	if int(averages.get("speed", -1)) != 16:
		return { "ok": false, "error": "Expected speed average 16, got %s" % str(averages.get("speed")) }
	return { "ok": true }


static func _test_redundant_overlay() -> Dictionary:
	var screen_script: GDScript = load("res://ui/screens/sanctum/EchoPartyScreen.gd")
	var selected: Dictionary = _make_echo({ "atk": 5, "def": 5, "int": 5, "agi": 5, "cha": 5, "speed": 5 }, true)
	var echoes: Array = [selected]

	if not bool(screen_script._is_redundant_party_average(selected, echoes)):
		return { "ok": false, "error": "Expected solo-party comparison to be redundant" }
	return { "ok": true }


static func _test_normalization_safety() -> Dictionary:
	var chart_script: GDScript = load("res://ui/components/RadarStatChart.gd")
	var normalized: Dictionary = chart_script.normalize_stats(
		{ "atk": 0, "def": 0, "int": 0, "agi": 0, "cha": 0, "speed": 0 },
		{ "atk": 0, "def": 0, "int": 0, "agi": 0, "cha": 0, "speed": 0 }
	)

	for key in ["atk", "def", "int", "agi", "cha", "speed"]:
		if abs(float(normalized.get(key, -1.0))) > 0.001:
			return { "ok": false, "error": "Expected %s normalized to 0, got %s" % [key, str(normalized.get(key))] }
	return { "ok": true }


static func _make_echo(stats: Dictionary, in_party: bool) -> Dictionary:
	return {
		"id": "echo_%d" % stats.hash(),
		"in_party": in_party,
		"stats": stats,
	}

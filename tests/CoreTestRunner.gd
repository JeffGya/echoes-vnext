# res://tests/CoreTestRunner.gd
class_name CoreTestRunner
extends RefCounted

var _tests: Array = [] # [{ "name": String, "fn": Callable }]

## Optional. Called with the test name just before each test runs. Used by tests/LegacyLedgerFile.gd.
var before_test_hook: Callable = Callable()

func register_test(name: String, fn: Callable) -> void:
	_tests.append({ "name": name, "fn": fn })

func run_all() -> Dictionary:
	var results: Array = []
	var passed := 0
	var failed := 0

	for t in _tests:
		var name := str(t["name"])
		var fn: Callable = t["fn"]

		var ok := true
		var err := ""
		if before_test_hook.is_valid():
			before_test_hook.call(name)
		var started_ms := Time.get_ticks_msec()

		# Catch runtime errors
		# (assert() failures in Godot often print + abort; so we use explicit checks in tests.)
		var out = fn.call()
		if typeof(out) == TYPE_DICTIONARY and out.has("ok"):
			ok = bool(out["ok"])
			err = str(out.get("error", ""))
		elif typeof(out) == TYPE_BOOL:
			ok = bool(out)
		else:
			# If a test returns nothing, treat as fail
			ok = false
			err = "Test returned no result"
		var elapsed_ms := Time.get_ticks_msec() - started_ms

		if ok:
			passed += 1
		else:
			failed += 1

		results.append({
			"name": name,
			"ok": ok,
			"error": err,
			"ms": elapsed_ms
		})

	return {
		"total": _tests.size(),
		"passed": passed,
		"failed": failed,
		"results": results
	}


## Timing report for a run: milliseconds per suite, then the slowest tests.
## A suite is the text before the first "/" in a test name.
## Every data line starts with "TIMING_SUITE" or "TIMING_TEST", so scripts can parse
## it from shard logs. It never prints the "Tests:" line.
static func format_timing_report(results: Array, top_n: int = 20) -> Array:
	var suite_ms: Dictionary = {}
	var suite_tests: Dictionary = {}
	var rows: Array = []
	for r in results:
		var name := str(r.get("name", "unnamed"))
		var ms := int(r.get("ms", 0))
		var slash_idx := name.find("/")
		var suite := name.substr(0, slash_idx) if slash_idx >= 0 else name
		suite_ms[suite] = int(suite_ms.get(suite, 0)) + ms
		suite_tests[suite] = int(suite_tests.get(suite, 0)) + 1
		rows.append({ "name": name, "ms": ms })

	var suites: Array = suite_ms.keys()
	suites.sort_custom(func(a, b):
		if suite_ms[a] != suite_ms[b]:
			return suite_ms[a] > suite_ms[b]
		return str(a) < str(b))
	rows.sort_custom(func(a, b):
		if a["ms"] != b["ms"]:
			return a["ms"] > b["ms"]
		return str(a["name"]) < str(b["name"]))

	var total_ms := 0
	for s in suites:
		total_ms += int(suite_ms[s])
	var lines: Array = []
	lines.append("Timing per suite, slowest first (%d suite(s), %d ms in tests):" % [suites.size(), total_ms])
	for s in suites:
		lines.append("TIMING_SUITE ms=%d tests=%d suite=%s" % [suite_ms[s], suite_tests[s], s])
	lines.append("Slowest %d test(s):" % mini(top_n, rows.size()))
	for i in range(mini(top_n, rows.size())):
		lines.append("TIMING_TEST ms=%d name=%s" % [rows[i]["ms"], rows[i]["name"]])
	return lines

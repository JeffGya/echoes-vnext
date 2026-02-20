# res://tests/CoreTestRunner.gd
class_name CoreTestRunner
extends RefCounted

var _tests: Array = [] # [{ "name": String, "fn": Callable }]

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

		if ok:
			passed += 1
		else:
			failed += 1

		results.append({
			"name": name,
			"ok": ok,
			"error": err
		})

	return {
		"total": _tests.size(),
		"passed": passed,
		"failed": failed,
		"results": results
	}
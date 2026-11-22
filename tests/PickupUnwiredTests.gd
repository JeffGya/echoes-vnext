# res://tests/PickupUnwiredTests.gd
# The unwired register of V2-ITEM-001b (D-62, D-65): code markers and docs/stories/v2-item-001b/follow-ups.md agree.
#
# THE RULE. Scan every .gd file under res://core and res://ui. A line that contains the word UNWIRED must be
# a well-formed marker:  # UNWIRED (target: <T>): <what>
#   Only whitespace may stand before the "#" (a marker is a comment line).
#   <T> is a story code (V2-AREA-NNN, optional lower-case letter) found in the backlog CSV, or NEW "<title>".
#   <what> is not empty.
# follow-ups.md has one table row per unwired part. After the header and separator, EVERY table line must be
# a row with a numeric id and six cells. Each row must satisfy:
#   - "Target story" holds a story code, a NEW "<title>", or starts with the word none and a reason.
#   - "Marker site" either starts with the word none and a reason (an exempt row: no code site), or names
#     at least one File.gd. An exempt row needs no marker.
#   - A row with File.gd names: each file has a marker whose <T> is in the row's "Target story", and each
#     story code and NEW title in the row's "Target story" is carried by a marker in one of those files.
#   - Every marker has a row that names its file and holds its <T>.
# The CSV is read from res://docs. When it cannot be read, only the code format is checked and a note is printed.
# The test new_titles_are_listed prints the distinct NEW titles with file:line, to create the Notion rows.

class_name PickupUnwiredTests
extends RefCounted

const FOLLOW_UPS := "res://docs/stories/v2-item-001b/follow-ups.md"
const SCAN_ROOTS: Array = ["res://core", "res://ui"]
const CODE_PATTERN := "^V2-[A-Z]+-[0-9]{3}[a-z]?$"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("pickup_unwired/markers_are_well_formed", Callable(PickupUnwiredTests, "_t_format"))
	runner.register_test("pickup_unwired/every_marker_has_a_follow_ups_row", Callable(PickupUnwiredTests, "_t_marker_has_row"))
	runner.register_test("pickup_unwired/every_follow_ups_site_has_a_marker", Callable(PickupUnwiredTests, "_t_row_has_marker"))
	runner.register_test("pickup_unwired/new_titles_are_listed", Callable(PickupUnwiredTests, "_t_new_titles"))


static func _result(m: Array) -> Dictionary:
	return { "ok": m.is_empty(), "error": "; ".join(m) }


# Returns { markers: [{ file, path, line, target, what }], errors: [String] }.
static func _scan() -> Dictionary:
	var markers: Array = []
	var errors: Array = []
	var paths: Array = []
	for root: String in SCAN_ROOTS:
		_collect(root, paths)
	paths.sort()
	for p: String in paths:
		var text := FileAccess.get_file_as_string(p)
		if not text.contains("UNWIRED"):
			continue
		var lines := text.split("\n")
		for i in lines.size():
			var line: String = lines[i]
			if not line.contains("UNWIRED"):
				continue
			var where := "%s:%d" % [p, i + 1]
			var parsed := _parse_marker(line)
			if not str(parsed.get("error", "")).is_empty():
				errors.append("%s: %s" % [where, parsed["error"]])
				continue
			markers.append({ "file": p.get_file(), "path": p, "line": i + 1,
				"target": parsed["target"], "what": parsed["what"] })
	return { "markers": markers, "errors": errors }


static func _collect(dir_path: String, out: Array) -> void:
	for sub in DirAccess.get_directories_at(dir_path):
		if not sub.begins_with("."):
			_collect(dir_path.path_join(sub), out)
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))


# Returns { target, what } or { error }.
static func _parse_marker(line: String) -> Dictionary:
	var at := line.find("# UNWIRED")
	if at == -1:
		return { "error": "the word UNWIRED is not in the form '# UNWIRED (target: <T>): <what>'" }
	if not line.substr(0, at).strip_edges().is_empty():
		return { "error": "a marker must be a comment line: only whitespace may stand before '# UNWIRED'" }
	var rest := line.substr(at + 9)
	if not rest.begins_with(" (target: "):
		return { "error": "no ' (target: ' after '# UNWIRED'" }
	rest = rest.substr(10)
	var target := ""
	if rest.begins_with("NEW \""):
		var close := rest.find("\"", 5)
		if close == -1:
			return { "error": "NEW title has no closing quote" }
		target = rest.substr(0, close + 1)
		rest = rest.substr(close + 1)
		if target.substr(5, target.length() - 6).strip_edges().is_empty():
			return { "error": "NEW title is empty" }
	else:
		var close := rest.find(")")
		if close == -1:
			return { "error": "target has no closing ')'" }
		target = rest.substr(0, close)
		rest = rest.substr(close)
		var re := RegEx.new()
		re.compile(CODE_PATTERN)
		if re.search(target) == null:
			return { "error": "target '%s' is neither a story code nor NEW \"<title>\"" % target }
	if not rest.begins_with("): "):
		return { "error": "target must be followed by '): <what>'" }
	var what := rest.substr(3).strip_edges()
	if what.is_empty():
		return { "error": "the marker has no description" }
	return { "target": target, "what": what }


# Returns { rows: [{ n, target, files, exempt, ids }], errors: [String] }. `files` = the .gd names in "Marker site".
# `ids` = the story codes and NEW titles in "Target story".
static func _rows() -> Dictionary:
	var rows: Array = []
	var errors: Array = []
	var text := FileAccess.get_file_as_string(FOLLOW_UPS)
	if text.is_empty():
		return { "rows": rows, "errors": ["cannot read " + FOLLOW_UPS] }
	var gd := RegEx.new()
	gd.compile("[A-Za-z0-9_]+\\.gd")
	var id_re := RegEx.new()
	id_re.compile("V2-[A-Z]+-[0-9]{3}[a-z]?|NEW \"[^\"]+\"")
	for line in text.split("\n"):
		if not line.begins_with("|"):
			continue
		var cells := line.split("|")
		var first := str(cells[1]).strip_edges() if cells.size() > 1 else ""
		if first == "#" or first.begins_with("-"):
			continue
		if cells.size() != 8 or not first.is_valid_int():
			errors.append("follow-ups line is not a row of six cells with a numeric id: " + line.left(80))
			continue
		var target := str(cells[4]).strip_edges()
		var site := str(cells[6]).strip_edges()
		var ids: Array = []
		for hit in id_re.search_all(target):
			if not ids.has(hit.get_string()):
				ids.append(hit.get_string())
		var exempt := _starts_with_none(site)
		var files: Array = []
		if not exempt:
			for hit in gd.search_all(site):
				if not files.has(hit.get_string()):
					files.append(hit.get_string())
			if files.is_empty():
				errors.append("row %s: Marker site must start with 'none' and a reason, or name a File.gd" % first)
		if ids.is_empty() and not _starts_with_none(target):
			errors.append("row %s: Target story needs a story code, a NEW \"title\", or 'none' and a reason" % first)
		rows.append({ "n": first, "target": target, "files": files, "exempt": exempt, "ids": ids })
	if rows.is_empty():
		errors.append("follow-ups.md has no register rows")
	return { "rows": rows, "errors": errors }


# The word none followed by a reason (at least three more characters).
static func _starts_with_none(cell: String) -> bool:
	return cell.begins_with("none") and cell.substr(4).strip_edges().length() >= 3


static func _csv_text() -> String:
	for f in DirAccess.get_files_at("res://docs"):
		if f.begins_with("Echoes vNext V2 Story Backlog") and f.ends_with("_all.csv"):
			return FileAccess.get_file_as_string("res://docs".path_join(f))
	return ""


static func _t_format() -> Dictionary:
	var scan := _scan()
	var m: Array = (scan["errors"] as Array).duplicate()
	var markers: Array = scan["markers"]
	if markers.is_empty():
		m.append("no markers found: the scan reads nothing")
	var csv := _csv_text()
	if csv.is_empty():
		print("pickup_unwired: backlog CSV not readable; story codes checked for format only")
	for mk: Dictionary in markers:
		var target := str(mk["target"])
		if not csv.is_empty() and not target.begins_with("NEW") and not csv.contains("," + target + ","):
			m.append("%s:%d: story code %s is not in the backlog CSV" % [mk["path"], mk["line"], target])
	return _result(m)


static func _t_marker_has_row() -> Dictionary:
	var scan := _scan()
	var rows_info := _rows()
	var m: Array = (rows_info["errors"] as Array).duplicate()
	for mk: Dictionary in scan["markers"]:
		var found := false
		for row: Dictionary in rows_info["rows"]:
			if (row["files"] as Array).has(mk["file"]) and str(row["target"]).contains(str(mk["target"])):
				found = true
				break
		if not found:
			m.append("%s:%d: marker %s has no follow-ups row (file and target)" % [mk["path"], mk["line"], mk["target"]])
	return _result(m)


static func _t_row_has_marker() -> Dictionary:
	var scan := _scan()
	var rows_info := _rows()
	var m: Array = (rows_info["errors"] as Array).duplicate()
	for row: Dictionary in rows_info["rows"]:
		for f: String in row["files"]:
			var found := false
			for mk: Dictionary in scan["markers"]:
				if mk["file"] == f and str(row["target"]).contains(str(mk["target"])):
					found = true
					break
			if not found:
				m.append("follow-ups row %s names %s but that file has no marker with a target of the row" % [row["n"], f])
		if row["exempt"]:
			continue
		for want: String in row["ids"]:
			var carried := false
			for mk: Dictionary in scan["markers"]:
				if mk["target"] == want and (row["files"] as Array).has(mk["file"]):
					carried = true
					break
			if not carried:
				m.append("follow-ups row %s holds %s in Target story but no marker in its files carries it" % [row["n"], want])
	return _result(m)


static func _t_new_titles() -> Dictionary:
	var scan := _scan()
	var titles: Dictionary = {}
	for mk: Dictionary in scan["markers"]:
		var target := str(mk["target"])
		if target.begins_with("NEW"):
			if not titles.has(target):
				titles[target] = []
			(titles[target] as Array).append("%s:%d" % [mk["path"], mk["line"]])
	print("pickup_unwired: %d distinct NEW titles (create a Notion row for each)" % titles.size())
	var keys: Array = titles.keys()
	keys.sort()
	for k: String in keys:
		print("  %s -> %s" % [k, ", ".join(titles[k] as Array)])
	return { "ok": true, "error": "" }

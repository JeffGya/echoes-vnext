# res://tests/TestSaveHarness.gd
#
# Shared save-file harness for every suite that boots a real FlowRuntime against /tmp.
#
# It exists to kill two harness defects that produced false failures indistinguishable from
# real regressions:
#
#  1. INCOMPLETE CLEANUP. SaveService writes six artifacts beside the primary save file
#     (.pending_a, .pending_b, .tmp, .bak1, .bak2, .bak3 — core/save/SaveService.gd:173-181),
#     and load_from_file() returns LOAD_MISSING only when NONE of them exists
#     (core/save/SaveService.gd:120). A helper that deletes only the primary therefore leaves a
#     recoverable backup behind: boot() takes the RECOVERED path instead of make_new_save(),
#     and the test silently resumes a PREVIOUS run's campaign — other balances, other XP,
#     another map, another fingerprint hash. The production behaviour is correct; recovering
#     from a backup is exactly what a crash-safe save system is for. The harness was wrong.
#
#  2. CROSS-PROCESS COLLISION. Every suite wrote into one shared directory, so two Godot
#     processes running at once contaminated each other. `dir()` scopes the directory per
#     process while keeping it stable WITHIN a process (paths change, seed and save content
#     do not). It stays under /tmp/echoes-vnext-tests/ so the documented
#     `rm -rf /tmp/echoes-vnext-tests` still clears everything.
#
# Use `fresh_save_path()` whenever a test needs boot() to create a brand-new save with the
# pinned literal seed. Use `remove_save_artifacts()` for teardown.

class_name TestSaveHarness
extends RefCounted

const ROOT := "/tmp/echoes-vnext-tests/"


## Per-process test save directory, created if absent. Deterministic within one process.
## `subdir` is optional and nests below the process directory.
static func dir(subdir: String = "") -> String:
	var d: String = "%sp%d/" % [ROOT, OS.get_process_id()]
	if subdir != "":
		d += subdir.trim_prefix("/").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(d)
	return d


## Every filename suffix SaveService can leave beside a save file.
## DERIVED, never copied: core/save/SaveService.gd::_artifact_paths() (lines 173-181) is the
## single source of truth for the recoverable chain, so a change there is picked up here for
## free. ".corrupt" is written separately by _archive_invalid_primary()
## (core/save/SaveService.gd:283-287) and is not part of that chain, so it is appended.
static func artifact_suffixes() -> Array:
	var suffixes: Array = []
	for entry_v in SaveService._artifact_paths(""):
		suffixes.append(str((entry_v as Dictionary).get("path", "")))
	suffixes.append(".corrupt")
	return suffixes


## Deletes the primary save AND every artifact beside it, so the path is genuinely missing.
static func remove_save_artifacts(save_path: String) -> void:
	for suffix_v in artifact_suffixes():
		var p: String = save_path + str(suffix_v)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Full path inside the per-process directory, guaranteed free of every save artifact.
static func fresh_save_path(file_name: String, subdir: String = "") -> String:
	var save_path: String = dir(subdir) + file_name
	remove_save_artifacts(save_path)
	return save_path

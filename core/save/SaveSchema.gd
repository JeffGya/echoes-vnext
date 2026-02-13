extends RefCounted

class_name SaveSchema

# Increment only when the meaning/structure of the save changes.
const SCHEMA_VERSION: int = 1

#Default save path (single-slot strategy, stored in a folder for autosave/backup support)
const DEFAULT_SAVE_PATH: String = "user://saves/slot_01.json"

static func make_new_save(root_seed: int, app_version: String = "vNext-dev") -> Dictionary:
	# Creates a new save dictionary that conforms to the schema.
	# Keep this stabel and addive over time (avoid breaking changes).
	var now := Time.get_unix_time_from_system()

	return {
		"schema_version": SCHEMA_VERSION,
		"meta": {
			"created_at_unix": now,
			"last_saved_at_unix": now,
			"app_version": app_version
		},
		"campaign": {
			"root_seed": root_seed,
			"tick": 0       
		},
		"flow": {
			"state": "boot",
			"context": {}
		},
		"sanctum": {
			"ase": 0,
			"roster": [],
			"active_party_ids": []
		}
	}

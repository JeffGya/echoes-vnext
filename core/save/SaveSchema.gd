extends RefCounted

class_name SaveSchema

# Increment only when the meaning/structure of the save changes.
const SCHEMA_VERSION: int = 1

#Default save path (single-slot strategy, stored in a folder for autosave/backup support)
const DEFAULT_SAVE_PATH: String = "user://saves/slot_01.json"

static func make_new_save(root_seed: int, app_version: String = "vNext-dev") -> Dictionary:
	# Creates a new save dictionary that conforms to the schema.
	# Keep this stabel and addive over time (avoid breaking changes).
	var now := int(Time.get_unix_time_from_system())

	return {
		"schema_version": SCHEMA_VERSION,
		"first_boot": true, # Used to determine if this is a new save or loaded save (for first-time user experience)
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
			"state": "flow.splash",
			"context": {}
		},
		"economy": {
			"ase": 0,
			"ekwan": 0,
			
			# ECONOMY-002 guards
			"last_settle_unix": now,
			"last_offline_unix": now
		},
		"sanctum": {
			"ase": 0, #legacy ignore. Backfill handled in repair function.
			"roster": [],
			"active_party_ids": [],
			"name": "",
			"name_roll_index": 0
		}
	}

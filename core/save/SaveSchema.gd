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
			"root_seed": root_seed, # legacy / still used by validate
			"tick": 0,
			"seed_root": "legacy:%d" % root_seed,
			"seed_source": "imported"
		},
		"flow": {
			"state": "flow.splash",
			"context": {}
		},
		"onboarding": {
			"chapter_one_complete": false,
			"chapter_one_step": "invocation",
			"fragment_options": [],
			"heard_fragments": [],
			"selected_fragment": "",
			"name_options": [],
			"keeper_intro_complete": false,
			"keeper_intro_step": "",
			"keeper_trial_phase": "ready",
			"keeper_trial_rewind_used": false,
			"first_thread_id": "",
			"first_trial_rewards_granted": false,
			"awakening_choice": "",
		},
		"economy": {
			"ase": 0,
			"ekwan": 0,

			# ECONOMY-002 guards
			"last_settle_unix": now,
			"last_offline_unix": now,
			# V2-SANCTUM-001: emotion recovery settlement timestamp (mirrors last_settle_unix)
			"last_emotion_settle_unix": now,

			# V2-MIG-002: additive V2 currency + visible state stubs
			"relics": 0,   # V2-ECONOMY-001+: rare artifact currency
			"faith": 0,    # V2-ECONOMY-001+: sanctum-level visible state
			"harmony": 0,  # V2-ECONOMY-001+: house social coherence state
			"favor": 0,    # V2-ECONOMY-001+: sanctum-level visible state
		},
		"sanctum": {
			"ase": 0, #legacy ignore. Backfill handled in repair function.
			"roster": [],
			"active_party_ids": [],
			"name": "",
			"name_roll_index": 0,
			"starter_granted": false,
			"summon_count": 0,
			"layout": SanctumLayoutService.make_starter_layout(),
			"occupants": [],
			"bonds": [],            # BOND-001: signed score edges {actor_a, actor_b, strength}
			"party_encounters": [], # BOND-001: canonical pairs who have shared a party slot
			"rival_incidents": [],  # BOND-002: canonical rival pairs that shared a stage (seed for SANCTUM-005)
			"active_vow": {},       # VOW-001: active vow dict {vow_id, tier, pledged_at_realm, runs_at_pledge} or {}
			"vows": {},             # VOW-001 canonical: Dict keyed by vow_id → {tier, discovered_realm}

			# V2-MIG-002: additive V2 sanctum stubs
			"continuity": 0,  # V2-SANCTUM-001+: Sanctum growth spine
			"threads": {},    # V2-WEAVE-001+: Thread reserve (keyed by thread_id)
			"ase_flame": {
				"awakened": false,
				"boost_remaining_seconds": 0,
				"boost_per_bank_tick": 0,
			},
		},
		# DIRECTIVE-001: stage-level context (directive, future: stage seed, objective state)
		"stage_context": {
			"active_directive_id": "directive.none",
			"intel": {},  # V2-MIG-002 / V2-INTEL-001+: stage-intel persistence stub
		},
		# REALM-001: generated realm models keyed by realm_id (e.g. "realm.01": { ...RealmModel fields })
		"realms": {}
	}

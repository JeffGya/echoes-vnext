# Echoes vNext — Conventions & Contracts

## Naming conventions

### Folders
- snake_case (e.g., core/state, ui/screens)

### Scripts
- PascalCase.gd for classes (e.g., FlowStateMachine.gd)
- One primary class per file whenever possible.

### Data files
- snake_case.json (e.g., actor_templates.json, realms.json)

### IDs
- snake_case strings (e.g., vale_of_dust, purify_shrine)

## Code boundaries (non-negotiable)

### Core simulation (res://core)
- Deterministic logic only.
- No direct UI node references.
- Outputs snapshots + logs.

### UI layer (res://ui)
- Renders snapshots.
- Sends actions.
- Must not read internal sim variables directly.

---

## Contracts
Contracts live in res://core/contracts/

### Snapshot (sim → UI)
Snapshots are the ONLY source of truth for UI rendering.

Shape:
{
  "type": String,         // e.g. "sanctum", "realm_select", "combat_round"
  "meta": Dictionary,     // timestamps, seed refs, debug flags, version
  "data": Dictionary      // state-specific payload
}

### Action (UI → sim)
Action ID format: domain.subdomain.verb_noun
UI triggers actions by ID, not by calling internal functions directly.

Shape:
{
  "id": String,           // e.g. "sanctum.summon_echo"
  "label": String,        // UI-facing label
  "enabled": bool,        // UI state
  "tooltip": String,      // explain why enabled/disabled
  "payload": Dictionary   // parameters (optional)
}

### LogEvent (sim → UI/QA)
Logs are structured, stable, and testable.

Shape:
{
  "t": int,               // monotonic tick or timestamp
  "type": String,         // e.g. "state.transition", "combat.attack"
  "msg": String,          // short human-readable line
  "data": Dictionary      // optional detailed payload
}

---

## Save Schema Versioning & Migrations
- Saves are JSON and must include schema_version (int).
-	Never change the meaning of an existing field without bumping schema_version.
-	Prefer additive changes:
    -	add new fields with safe defaults
    -	keep old fields until a migration is in place
-	Migrations must be explicit and ordered:
    -	migrate_v1_to_v2(data: Dictionary) -> Dictionary
    -	migrate_v2_to_v3(...)
-	SaveService.load_from_file() must: 
    -	parse JSON
    -	validate schema version
    -	run migrations (when implemented)
    -	return a valid vLatest dictionary or {}

### Save Files & Crash Safety
-	Default save path: user://saves/slot_01.json
-	Writes must be crash-safe:
	-	write to *.tmp
	-	rename to final

---

## Randomness Policy (Determinism)
- All randomness must derive from CampaignSeed
- Use dot-separated seed paths (case-sensitive) e.g. campaign.realm.01.stage.03.encounter.01.spawn.enemy.02
- Forbidden: randomize(), rand(), randf(), and global randomness.
- Forbidden: creating RandomNumberGenerator.new() directly in systems. (Only allowed insife CampaignSeed or future RandomProvider wrapper.)
- Each subsystem must request an RNG via:
  - CampaignSeed.get_rng(path) or
  - CampaignSeed.get_rng_from(parent_seed, path)

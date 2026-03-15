class_name EncounterContext

extends RefCounted

# Encounter identity
var encounter_id: String = ""
var resolution_mode: String = "" # e.g. "combat", "shrine", "event"

# Latest snapshot of the encounter state
var phase_snapshot: Dictionary = {}

# Local deterministic counters. (flow provides a global sim tick)
var encounter_step: int = 0
var phase_index: int = 0
var round_index: int = 0

# Save request signals (system-driven checkpoints)
var save_request: bool = false
var save_request_reason: String = ""

# COMBAT-001: placed actor list — stored after GridService.place_actors(); write-once.
var actors: Array = []
# COMBAT-001: placement seed — stored alongside actors for snapshot replay.
var placement_seed: int = 0
# COMBAT-001: combat state dict — set by EncounterRoundsState.enter() via combat.init.
var combat_state: Dictionary = {}

# Optional deterministic notes for debugging / temporary tests
var notes: Array[String] = []

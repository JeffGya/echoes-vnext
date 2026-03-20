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
# COMBAT-002: initiative config — set by FlowEncounterState.enter() from balance.json data.combat.initiative_modifiers.
var initiative_cfg: Dictionary = {}
# COMBAT-003: transient round action results — cleared at start of each round; NOT persisted.
var last_round_results: Array = []
# COMBAT-SEQ: most recent single actor action result — updated after each actor acts; {} between rounds.
var last_actor_action: Dictionary = {}
# COMBAT-005: transient combat result — set by FlowRuntime._end_round(); not persisted.
# Shape: { "victory": bool, "reason": String, "round_ended": int, "shrine_hp": int }
var combat_result: Dictionary = {}
# COMBAT-006: id of the designated purifier echo — set once at combat init; "" if no shrine objective.
var purifier_id: String = ""

# COMBAT-007: in-memory snapshot persistence — never written to disk.
# last_round_snapshot: set at each round_end; overwritten each round.
# final_snapshot: set once at combat_end (type "flow.resolve").
var last_round_snapshot: Dictionary = {}
var final_snapshot: Dictionary = {}

# Optional deterministic notes for debugging / temporary tests
var notes: Array[String] = []

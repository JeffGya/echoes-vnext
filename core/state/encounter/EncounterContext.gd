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

# PROG-003: per-echo action log — accumulated across all rounds; consumed at resolve for XP calc.
# S14a: widened into a general offensive contribution ledger — entries now exist for actors of
# ANY faction (echo/enemy/spirit/ally), keyed by actor id. melee_count/guard_count/kill_count/
# total_count remain echo-only (populated exclusively by the PROG-003 accumulator in
# FlowRuntime._resolve_next_actor, gated on faction == "echo"); damage_dealt/damage_taken/kills
# are populated for every actor at the single melee damage choke (same function, "melee_attack"
# branch) and are read by FlowEncounterState._project_actor() to build the "contribution"
# projected-actor field, and later by S14 for the recruit formula.
# Shape: { actor_id: {
#   melee_count: int, guard_count: int, kill_count: int, total_count: int,  # echo-only
#   damage_dealt: int, damage_taken: int, kills: int,                      # all factions
# } }
# Initialised fresh per EncounterContext instance (i.e. once per combat). Never persisted.
var echo_action_logs: Dictionary = {}

# V2-EMOTION-001: echo_id → morale_current at encounter entry. Populated by
# FlowEncounterState.enter(). Used by build_final_snapshot() for delta computation.
var pre_encounter_morale: Dictionary = {}

# V2-VOICE-001: round bark events — accumulated per round for reactive bark system.
# Shape: Array[{ "actor_id": String, "bark_context": String, "bark_tier": int, "grid_pos": Vector2i }]
# Reset to [] at the start of each round. Passed via ctx["round_bark_events"] to advance_turn().
var round_bark_events: Array = []

# V2-STAGE-004 P3a: irregular combat-board terrain — transient, never persisted.
# Shape: { bounds:{w,h}, plateaus:[…], bridges:[…], stragglers:[…] } or {} (legacy).
var terrain: Dictionary = {}

# V2-STAGE-004 P3: scaled objective parameters — transient, never persisted.
# Populated by FlowEncounterState.enter() for RECOVER/PROTECT/ENDURE modes; {} otherwise.
var objective_params: Dictionary = {}

# V2-STAGE-004 Phase 4 (S15 prep): true when S13's failed-charge pressure bump (see
# explore_map.hostile_charge_sit_id consumption in FlowEncounterState.enter()) was
# applied to THIS encounter's objective. Transient, never persisted. Default false.
var charge_pressure_applied: bool = false

# Optional deterministic notes for debugging / temporary tests
var notes: Array[String] = []

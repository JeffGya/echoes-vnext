class_name FlowContext

extends RefCounted

# Flow owns tick
var sim_tick: int = 0

# Last snapshot produced by Flow (UI renders this)
var last_snapshot: Dictionary = {}

# ---- UI-only vars (NOT saved) ----
# Used for summon reveal overlays (Summon screen only).
var pending_summon_reveals: Array = [] # Array[Dictionary] (Echo records or summaries)

# Used by flow.echo_party for immediate party selection state.
var pending_party_ids: Array = [] # Array[String] (Echo ids)

# PROG-009: skill loadout built during party prep on STAGE_MAP.
# Dict: echo_id → { slot_index_str → skill_id }. Persisted to save on flow.select_stage (cta.enter_stage).
var pending_equipped_skills: Dictionary = {}

# Selected summon grade for the current Summon screen visit.
# Reset to "uncalled" each time FlowSummonState.enter() runs — never persisted to save.
var selected_summon_grade: String = "uncalled"

# V2-WEAVE-002: selected Thread and Echo in the Weaving Rite flow.
var selected_weave_thread_id: String = ""
var selected_weave_echo_id: String = ""

# V2-WEAVE-002: commitment lock and rite result payload.
var weave_commit_locked: bool = false
var weave_resolution: Dictionary = {}

# ----

# Session / run metadata (placeholders; filled in later)
var realm_id: String = ""
var stage_id: String = ""
var encounter_id: String = ""

# Encounter runtime (active only while in flow.encounter)
var encounter_ctx: EncounterContext = null
var encounter_machine: EncounterStateMachine = null

# Save payload (pure data) + request mechanism
var save_data: Dictionary = {}
var save_request: bool = false
var save_request_reason: String = ""

# Optional core services (core-safe)
var config_service = null # ConfigService
var campaign_seed = null # CampaignSeed
var logger = null # StructuredLogger — injected by FlowRuntime; GRID-002 allows flow states to log
var flow_machine = null # FlowStateMachine — injected by FlowStateMachine.start(); allows states to trigger deferred transitions

# Debug / diagnostics
var last_error: String = ""
var last_transition_reason: String = ""

# COMBAT-006 dev toggle: overrides encounter objective when non-empty.
# Set via AppRoot debug command "combat_objective <mode>". Empty = use default.
var dev_combat_objective: String = ""

# V2-WEAVE-001: Threads crystallized from the most recently completed Realm (session-transient).
# Populated by FlowRuntime._handle_complete_stage() on realm_complete.
# Resets to [] on new game boot (FlowContext is freshly instantiated).
var last_realm_threads_earned: Array = []

# V2-VOW-002: transient vow consequence for resolve screen.
# Cleared on every stage enter (_apply_vow_stage_entry_condition).
# Set by _apply_vow_break_aftermath (break events) or _store_vow_benefit_preview (benefit probe).
var vow_outcome: Dictionary = {}

# V2-VOW-002: session-transient list of vows unlocked this session (for "Discovered" badge on
# VowScreen and "Vow Revealed" section on ResolveScreen).
# Populated by _check_vow_discovery when a vow is unlocked during a run.
# Resets on new FlowContext instantiation (new game boot).
var session_unlocked_vows: Array = []  # Array[Dictionary] {vow_id, vow_name, proverb_twi, proverb_en}

# V2-VOW-002: monotonic tick of the last vow stage-entry condition check.
# Guards against double-fire when re-entry paths both route through flow.go_state → STAGE_EXPLORE.
var vow_entry_check_t: int = -1

# V2-VOW-002: transient debuff chip shown in the Sanctum ActiveEffectsPanel after a vow breaks.
# Written by _apply_vow_break_aftermath; cleared on next stage entry.
var session_broken_vow_effect: Dictionary = {}
# Shape: { effect_id, label, direction, headline, body, duration_hint, source }

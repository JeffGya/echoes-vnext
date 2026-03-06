class_name FlowContext

extends RefCounted

# Flow owns tick
var sim_tick: int = 0

# Last snapshot produced by Flow (UI renders this)
var last_snapshot: Dictionary = {}

# ---- UI-only vars (NOT saved) ----
# Used for summon reveal overlays (Summon screen only).
var pending_summon_reveals: Array = [] # Array[Dictionary] (Echo records or summaries)

# Used while inside flow.party_manage before confirm.
var pending_party_ids: Array = [] # Array[String] (Echo ids)

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

# Debug / diagnostics
var last_error: String = ""
var last_transition_reason: String = ""

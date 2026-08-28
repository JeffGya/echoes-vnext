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

# V2-STAGE-004 P3c dev toggle: forces the GUIDE_SPIRIT guide_mode when non-empty.
# Set via AppRoot debug command "combat_objective guide_spirit [protect|escort] ...".
# "" = use the seeded 50/50 roll; "protect"/"escort" = forced. Draw-then-override:
# the seeded draw still runs so RNG draw order is identical with or without the override.
var dev_guide_mode: String = ""

# V2-STAGE-004 P3c dev toggle: forces whether an escort spirit joins battle when non-empty.
# Set via AppRoot debug command "combat_objective guide_spirit escort [join|nojoin]".
# "" = use the seeded 50/50 roll; "join"/"nojoin" = forced. Only meaningful in escort mode
# (same as the natural roll). Draw-then-override preserves RNG draw order.
var dev_guide_joins: String = ""

# V2-STAGE-004 Phase 4 (S14) dev toggle: forces the ally recruit-offer roll outcome when
# non-empty. Set via AppRoot debug command "force_recruit <success|fail|clear>".
# "" = use the seeded roll; "success"/"fail" = forced. Draw-then-override: the seeded
# roll in RecruitmentConsequenceService.compute_ally_recruit_offer_if_eligible always runs first (RNG
# draw order is byte-identical with or without the override) — only the boolean result
# is swapped afterward.
var dev_force_recruit: String = ""

# V2-STAGE-002: index into stage.objectives[] for the currently active encounter.
# Set by FlowRuntime when stage.engage_situation transitions to ENCOUNTER.
# Read by EncounterSetupService._resolve_mode_from_stage() to pick encounter resolution mode.
# Reset to -1 on flow.select_stage and after objective is marked complete.
var active_encounter_objective_index: int = -1

# V2-WEAVE-001: Threads crystallized from the most recently completed Realm (session-transient).
# Populated by FlowRuntime._handle_complete_stage() on realm_complete.
# Resets to [] on new game boot (FlowContext is freshly instantiated).
var last_realm_threads_earned: Array = []


# ECONOMY-005: one-shot Sanctum return notification payload, surfaced through the next
# flow.sanctum snapshot and then cleared.
var pending_return_notification: Dictionary = {}

# VOW-001 / V2-VOW-002: transient vow consequence for resolve screen.
# Cleared on every stage enter (VowConsequenceService.apply_vow_stage_entry_condition).
# Set by VowConsequenceService.apply_vow_break_aftermath (break events) or
# VowConsequenceService.store_vow_benefit_preview (benefit probe).
var vow_outcome: Dictionary = {}

# V2-VOW-002: session-transient list of vows unlocked this session (for "Discovered" badge on
# VowScreen and "Vow Revealed" section on ResolveScreen).
# Populated by VowConsequenceService.check_vow_discovery when a vow is unlocked during a run.
# Resets on new FlowContext instantiation (new game boot).
var session_unlocked_vows: Array = []  # Array[Dictionary] {vow_id, vow_name, proverb_twi, proverb_en}

# V2-VOW-002: monotonic tick of the last vow stage-entry condition check.
# Guards against double-fire when re-entry paths both route through flow.go_state → STAGE_EXPLORE.
var vow_entry_check_t: int = -1

# V2-VOW-002: transient debuff chip shown in the Sanctum ActiveEffectsPanel after a vow breaks.
# Written by VowConsequenceService.apply_vow_break_aftermath; cleared on next stage entry.
# Shape: { effect_id, label, direction, headline, body, duration_hint, source }
var session_broken_vow_effect: Dictionary = {}

# V2-ECONOMY-001: transient economy cadence flags (never persisted to save)
var pending_awakening_banner: bool = false         # true once after Ase Flame awakens
var pending_scout_return_ase: int = 0              # partial Ase earned on retreat/return_home
var pending_scout_return_intel_count: int = 0      # situations revealed on retreat/return_home

# V2-INFRA-003: single choke point for requesting a save. Sets save_request and, when a
# reason is given, accumulates it into save_request_reason (pipe-joined) so multiple
# mutations within one dispatch are all recorded. Callers outside FlowRuntime.gd that hold
# a FlowContext should call this instead of writing save_request(_reason) by hand.
# FlowRuntime._mark_save_requested() delegates here so there is exactly one implementation.
# reason == "" (default) flags a save without touching save_request_reason at all — used by
# the handful of call sites that never recorded a reason.
#
# CONTRACT (D58): call this ONLY from inside a FlowRuntime.dispatch(). FlowRuntime clears
# save_request_reason after each flush, so a reason queued outside a dispatch is not flushed on
# its own — it stays in the accumulator and is pipe-joined onto the NEXT dispatch's reason
# string. No caller does this today. It is not asserted because CombatBaselineTests pins the
# joined string per dispatch, so any guard that alters accumulation would move that baseline.
func request_save(reason: String = "") -> void:
	save_request = true
	if reason == "":
		return
	if save_request_reason != "":
		save_request_reason += "|" + reason
	else:
		save_request_reason = reason

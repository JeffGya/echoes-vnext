class_name ConfigService

extends RefCounted

const PATH_BALANCE := "res://data/balance.json"
const PATH_ACTORS := "res://data/actors.json"
const PATH_REALMS := "res://data/realms.json"

var _balance: Dictionary = {}
var _actors: Dictionary = {}
var _realms: Dictionary = {}

func load_balance(logger: StructuredLogger= null, t: int = -1) -> bool:
	var root := JsonFileLoader.load_dict(PATH_BALANCE, logger, t)
	if root.is_empty():
		return false
	if not ConfigValidator.validate_balance(root, logger, t):
		return false
	var data_v: Variant = root.get("data", {})
	var bal_data: Dictionary = data_v if data_v is Dictionary else {}
	var calling_cfg_v: Variant = bal_data.get("calling", {})
	var calling_cfg: Dictionary = calling_cfg_v if calling_cfg_v is Dictionary else {}
	CallingService.validate_config_integrity(calling_cfg, logger, t)
	CallingService.validate_count_integrity(calling_cfg, logger, t)
	# V2-PROG-012 Phase 6 Item 3(c): flags a directive whose intent_weights can
	# never produce a nonzero directive_bonus (empty / all non-positive / no
	# translated semantic key) — see DirectiveService.validate_config_integrity()'s
	# doc comment. Warns only; does not fail the load.
	var directives_cfg_v: Variant = bal_data.get("directives", {})
	var directives_cfg: Dictionary = directives_cfg_v if directives_cfg_v is Dictionary else {}
	var actor_cfg_v: Variant = bal_data.get("actor", {})
	var actor_cfg: Dictionary = actor_cfg_v if actor_cfg_v is Dictionary else {}
	DirectiveService.validate_config_integrity(directives_cfg, actor_cfg, logger, t)
	# V2-PROG-012 Phase 9: same precedent — validates the three canonical
	# vector/virtue/calling identity tables under data.contact (see
	# IdentityIntegrity.validate()'s doc comment). Warns only; does not fail the load.
	IdentityIntegrity.validate(bal_data, logger, t)
	_balance = root
	return true

func load_actors(logger: StructuredLogger= null, t: int = -1) -> bool:
	var root := JsonFileLoader.load_dict(PATH_ACTORS, logger, t)
	if root.is_empty():
		return false
	if not ConfigValidator.validate_actors(root, logger, t):
		return false
	_actors = root
	return true
	
func load_realms(logger: StructuredLogger= null, t: int = -1) -> bool:
	var root := JsonFileLoader.load_dict(PATH_REALMS, logger, t)
	if root.is_empty():
		return false
	if not ConfigValidator.validate_realms(root, logger, t):
		return false
	_realms = root
	return true
	
func get_balance() -> Dictionary:
	return _balance.duplicate(true)

func get_actors() -> Dictionary:
	return _actors.duplicate(true)

func get_realms() -> Dictionary:
	return _realms.duplicate(true)


# ---------------------------------------------------------------------------
# Named subtree accessors (V2-INFRA-003 Phase 4 Slice 1b)
# ConfigService is the sole reader of balance.json in this codebase. The
# domain services that consume these subtrees are deliberately pure — they
# take config dicts as arguments and never load ConfigService themselves
# (see SocialGraphService: "All functions receive data in and return data
# out"; MaturityExpressionService: "All config reads are from caller-supplied
# dicts (never loads ConfigService directly)"; EmotionService/ContinuityService
# mirror EconomyService, which never touches ConfigService either). So these
# accessors — moved out of FlowRuntime/WeaveController, which had duplicated
# them — live here instead of on any one domain service.
# Static + an explicit config_service param (rather than instance methods)
# so each function's original null-safety (some call sites guarded, some
# didn't) transcribes exactly; see each function.
# ---------------------------------------------------------------------------

## data.emotion.drift — combat/sanctum emotion drift tuning (EmotionService's
## setters take individual values, never this whole dict, so it has no home
## on EmotionService itself).
static func get_emotion_drift_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance := config_service.get_balance()
	if balance.is_empty():
		return {}
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var emo_v: Variant = data.get("emotion", {})
	var emo: Dictionary = emo_v if emo_v is Dictionary else {}
	var drift_v: Variant = emo.get("drift", {})
	return drift_v if drift_v is Dictionary else {}


## data.continuity — feeds ContinuityService.get_band()/add_points()/etc., which
## take this dict (or values derived from it) as arguments.
static func get_continuity_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var cont_v: Variant = data.get("continuity", {})
	return cont_v if cont_v is Dictionary else {}


## data.sanctum.bond_thresholds — feeds SocialGraphService.get_bond_type()/
## get_rival_pairs_in_party()/etc., which take this dict as an argument.
static func get_bond_thresholds_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_v: Variant = data.get("sanctum", {})
	var sanctum_cfg: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var thresholds_v: Variant = sanctum_cfg.get("bond_thresholds", {})
	return thresholds_v if thresholds_v is Dictionary else {}


## data.sanctum.party_max_size — the party slot cap.
## PR #61 review: this was read longhand at two sites with identical guards and the same
## default of 5 — SanctumController._get_party_max_size and
## FlowEchoPartyState._read_max_party_size. Same shape as D30 and D31. One owner now.
static func get_party_max_size(config_service: ConfigService, fallback: int = 5) -> int:
	if config_service == null:
		return fallback
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_v: Variant = data.get("sanctum", {})
	var sanctum_cfg: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	return int(sanctum_cfg.get("party_max_size", fallback))


## data.maturity_expression.band_by_standing — feeds
## MaturityExpressionService.get_expression_band()/get_expression_band_for_echo().
static func get_maturity_expression_band_by_standing(config_service: ConfigService) -> Dictionary:
	var bal: Dictionary = config_service.get_balance()
	var maturity_cfg: Dictionary = bal.get("data", {}).get("maturity_expression", {})
	var band_v: Variant = maturity_cfg.get("band_by_standing", {})
	return band_v if band_v is Dictionary else {}


## data.emotion.recovery — sibling of get_emotion_drift_cfg's data.emotion.drift.
## Feeds EmotionRecoveryService.apply_recovery_from_elapsed()/set_modifier(), which take
## this dict as an argument (never load ConfigService themselves).
## V2-INFRA-003 Phase 4 Slice 4: moved off EmotionConsequenceService (formerly FlowRuntime
## private _get_emotion_recovery_cfg) — a plain subtree read, same shape as the four getters
## above, so it belongs here rather than on the new service.
static func get_emotion_recovery_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance := config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var emo_v: Variant = data.get("emotion", {})
	var emo: Dictionary = emo_v if emo_v is Dictionary else {}
	var rec_v: Variant = emo.get("recovery", {})
	return rec_v if rec_v is Dictionary else {}


## data.sanctum.bond_triggers — combat bond score delta values. Feeds
## SocialGraphService.apply_score_delta() call sites in BondConsequenceService.
## V2-INFRA-003 Phase 4 Slice 4: moved off BondConsequenceService (formerly FlowRuntime
## private _get_bond_triggers_cfg) — a plain subtree read, sibling of get_bond_thresholds_cfg
## above (same data.sanctum parent), so it belongs here rather than on the new service.
static func get_bond_triggers_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_v: Variant = data.get("sanctum", {})
	var sanctum_cfg: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var triggers_v: Variant = sanctum_cfg.get("bond_triggers", {})
	return triggers_v if triggers_v is Dictionary else {}


## data.actor.bond_behavior — combat score bias values. Feeds the per-turn behavior
## ctx dict FlowRuntime builds for ActorStateMachine.advance_turn() (bond_behavior_cfg key).
## V2-INFRA-003 Phase 4 Slice 4: moved off BondConsequenceService (formerly FlowRuntime
## private _get_bond_behavior_cfg) — a plain subtree read.
static func get_bond_behavior_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var actor_v: Variant = data.get("actor", {})
	var actor_cfg: Dictionary = actor_v if actor_v is Dictionary else {}
	var behavior_v: Variant = actor_cfg.get("bond_behavior", {})
	return behavior_v if behavior_v is Dictionary else {}


## data.sanctum.rival_archetypes — rival archetype pairs list. Feeds
## SocialGraphService.is_rival_archetype_pair(), which takes this array as an argument.
## V2-INFRA-003 Phase 4 Slice 4: moved off BondConsequenceService (formerly FlowRuntime
## private _get_rival_archetypes_cfg) — a plain subtree read, sibling of
## get_bond_triggers_cfg above (same data.sanctum parent).
static func get_rival_archetypes_cfg(config_service: ConfigService) -> Array:
	if config_service == null:
		return []
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var sanctum_v: Variant = data.get("sanctum", {})
	var sanctum_cfg: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var pairs_v: Variant = sanctum_cfg.get("rival_archetypes", [])
	return pairs_v if pairs_v is Array else []


## data.emotion.recovery.bonds — grief/shared-survival recovery modifier values. Feeds
## EmotionRecoveryService.set_modifier() call sites in BondConsequenceService.
## V2-INFRA-003 Phase 4 Slice 4: moved off BondConsequenceService (formerly FlowRuntime
## private _get_bond_recovery_cfg) — a plain subtree read, nested under the same
## data.emotion.recovery parent as get_emotion_recovery_cfg above.
static func get_bond_recovery_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance: Dictionary = config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var emo_v: Variant = data.get("emotion", {})
	var emo_cfg: Dictionary = emo_v if emo_v is Dictionary else {}
	var rec_v: Variant = emo_cfg.get("recovery", {})
	var rec_cfg: Dictionary = rec_v if rec_v is Dictionary else {}
	var bonds_v: Variant = rec_cfg.get("bonds", {})
	return bonds_v if bonds_v is Dictionary else {}


## data.institutions — per-institution config (cost, capacity, condition thresholds).
## Feeds InstitutionService.establish()/assign_echo()/remove_echo()/update_condition()/
## apply_institution_modifiers(), which take this dict as an argument.
## V2-INFRA-003 Phase 4 Slice 4: moved off FlowRuntime (private _get_institutions_cfg) —
## a plain subtree read needed by both FlowRuntime's institution handlers and
## EmotionConsequenceService.apply_run_emotion_modifiers() (institution/run-outcome
## modifier composition), so neither owner-by-caller-count rule pointed at the new
## service; ConfigService is the shared true owner.
static func get_institutions_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var data_v: Variant = config_service.get_balance().get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var inst_v: Variant = data.get("institutions", {})
	return inst_v if inst_v is Dictionary else {}


## data.emotion.recovery.buildings — per-institution morale/fear recovery multipliers by
## condition. Feeds InstitutionService.apply_institution_modifiers() and
## EmotionConsequenceService.apply_run_emotion_modifiers() (same rationale as
## get_institutions_cfg above).
## V2-INFRA-003 Phase 4 Slice 4: moved off FlowRuntime (private _get_buildings_cfg).
static func get_buildings_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var data_v: Variant = config_service.get_balance().get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var emotion_v: Variant = (data.get("emotion", {}) as Dictionary).get("recovery", {})
	var recovery: Dictionary = emotion_v if emotion_v is Dictionary else {}
	var bldg_v: Variant = recovery.get("buildings", {})
	return bldg_v if bldg_v is Dictionary else {}


## data.economy — Ase accrual rate/cap tuning. Feeds EconomySettlementService.settle() (online
## bank-timer settle) and OfflineAccrualService.apply_if_needed() (offline catch-up on
## flow.continue; that block was still on FlowRuntime when this getter was created, and moved to
## core/economy/ in the Half A review correction C1). V2-INFRA-003 Phase 4 Slice 7: moved off FlowRuntime (private
## _get_balance_economy_cfg) — a plain subtree read shared by both callers, same "true owner"
## reasoning as get_institutions_cfg/get_buildings_cfg above.
static func get_economy_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var data_v: Variant = config_service.get_balance().get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var econ_v: Variant = data.get("economy", {})
	return econ_v if econ_v is Dictionary else {}


## data.rewards — stage/objective reward weights and partial-intel factor. Feeds
## FlowRuntime._handle_encounter_retreat (Phase 6 territory), FlowRuntime's return-home
## path, and ActiveStageService.get_stage_base_reward(). V2-INFRA-003 Phase 5
## Slice A: moved off FlowRuntime (private _get_balance_rewards_cfg) — a plain subtree read
## with callers in two different domains, so neither domain owns it; ConfigService does.
static func get_rewards_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance := config_service.get_balance()
	if balance.is_empty():
		return {}
	var data_v = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var rewards_v = data.get("rewards", {})
	return rewards_v if rewards_v is Dictionary else {}


## data.threads — the V2-WEAVE-001 Thread block (segment_quality_by_grade and the
## crystallization table). Two readers since V2-INFRA-003 D84: FlowRuntime._end_round()
## contributes the stage-clearing fight's segment, VentureController.handle_complete_stage()
## covers the no-encounter path and crystallizes on realm completion.
static func get_threads_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance := config_service.get_balance()
	if balance.is_empty():
		return {}
	var data_v = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var threads_v = data.get("threads", {})
	return threads_v if threads_v is Dictionary else {}


## data.stages.situation_category — maps a situation `type` to the directive
## target_preference category used by StagePartyMovementAdapter.select_objective_target().
## V2-INFRA-003 Phase 5 Slice A: moved off FlowRuntime (private
## _stage_situation_category_map). CORRECTION vs the story brief, which routed it onto
## ActiveStageService: it is a plain "read a named subtree of balance.json", which
## the established rule places here beside get_bond_thresholds_cfg and friends.
static func get_situation_category_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance_v: Variant = config_service.get_balance()
	var balance: Dictionary = balance_v if balance_v is Dictionary else {}
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var stages_v: Variant = data.get("stages", {})
	var stages: Dictionary = stages_v if stages_v is Dictionary else {}
	var category_v: Variant = stages.get("situation_category", {})
	return category_v if category_v is Dictionary else {}


## data.combat.objective_modes — per-mode objective tuning (recover / protect / endure /
## pursue / guide_spirit). Read by EncounterSetupService (scaled objective params),
## CombatTurnContextService (mode directive weights) and CombatRoundObjectiveService
## (PROTECT theft + guard radius) — three callers in one domain plus setup, so ConfigService
## owns the subtree read.
static func get_objective_modes_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance_v: Variant = config_service.get_balance()
	return get_objective_modes_cfg_from_balance(balance_v if balance_v is Dictionary else {})


## Balance-dict variant, for call sites that already hold the loaded balance dict.
static func get_objective_modes_cfg_from_balance(balance: Dictionary) -> Dictionary:
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var combat_v: Variant = data.get("combat", {})
	var combat: Dictionary = combat_v if combat_v is Dictionary else {}
	var modes_v: Variant = combat.get("objective_modes", {})
	return modes_v if modes_v is Dictionary else {}


## data.combat.objective_placement — depth-scale tuning for objective spawn placement
## (depth_min_frac, depth_max_frac, completion_full_at). All three keys are read together and
## can never disagree, so the subtree has one owner here rather than a longhand read per site.
static func get_objective_placement_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance_v: Variant = config_service.get_balance()
	return get_objective_placement_cfg_from_balance(balance_v if balance_v is Dictionary else {})


## Balance-dict variant, for call sites that already hold the loaded balance dict.
static func get_objective_placement_cfg_from_balance(balance: Dictionary) -> Dictionary:
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var combat_v: Variant = data.get("combat", {})
	var combat: Dictionary = combat_v if combat_v is Dictionary else {}
	var placement_v: Variant = combat.get("objective_placement", {})
	return placement_v if placement_v is Dictionary else {}


## data.combat.shrine — PURIFY_SHRINE drain/purify tuning. Read by
## CombatRoundShrineService, which passes it to ShrineService.apply_drain().
static func get_shrine_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance_v: Variant = config_service.get_balance()
	var balance: Dictionary = balance_v if balance_v is Dictionary else {}
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var combat_v: Variant = data.get("combat", {})
	var combat: Dictionary = combat_v if combat_v is Dictionary else {}
	var shrine_v: Variant = combat.get("shrine", {})
	return shrine_v if shrine_v is Dictionary else {}


## data.voice — bark budget, tier table and the reactive/sanctum bark parameters.
## Read by NarrativeVoiceService (round bark budget + sanctum barker selection) and by
## ActorStateMachine, which receives the whole balance dict in its context and reads the
## subtree inline rather than through this getter.
static func get_voice_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance_v: Variant = config_service.get_balance()
	var balance: Dictionary = balance_v if balance_v is Dictionary else {}
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var voice_v: Variant = data.get("voice", {})
	return voice_v if voice_v is Dictionary else {}


## data.combat.movement.slack — bounded detour allowance passed to
## StagePartyMovementAdapter.select_objective_target(). V2-INFRA-003 Phase 5 Slice A: moved
## off FlowRuntime (private _stage_movement_slack_config), same rationale as
## get_situation_category_cfg above.
static func get_movement_slack_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance_v: Variant = config_service.get_balance()
	var balance: Dictionary = balance_v if balance_v is Dictionary else {}
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var combat_v: Variant = data.get("combat", {})
	var combat: Dictionary = combat_v if combat_v is Dictionary else {}
	var movement_v: Variant = combat.get("movement", {})
	var movement: Dictionary = movement_v if movement_v is Dictionary else {}
	var slack_v: Variant = movement.get("slack", {})
	return slack_v if slack_v is Dictionary else {}


## data.summoning.birth_stats + data.actor.enemy_types — the two-key `cfg` dict that
## EnemyActor.from_definition() and ContactActorBuilder document as their required shape.
##
## V2-INFRA-003 Phase 6 Slice 6B: this assembly was written out longhand at four production
## sites — EncounterSetupService.setup() (initial roster), FlowRuntime._end_round() twice (the
## RECOVER reinforcement spawn and the ENDURE wave spawn, both carrying the comment "matching
## EncounterSetupService.setup() shape"), and KeeperIntroService.setup_trial_encounter(). Slice
## 6B moves two of those four out of FlowRuntime, which forced the ownership question: a
## helper used by two or more domains has an owner (AGENTS.md), and this one reads two named
## subtrees of balance.json, so the owner is a static getter here, beside get_bond_thresholds_cfg
## and get_movement_slack_cfg. All four call sites now read it from here; none was reimplemented
## inside the extracted service, and no lookalike API was substituted (AGENTS.md #19).
##
## Returns {} for a null ConfigService — byte-identical to the `if config_service != null`
## guard each call site used, and harmless downstream either way because EnemyActor reads both
## keys with .get(k, {}).
static func get_enemy_actor_cfg(config_service: ConfigService) -> Dictionary:
	if config_service == null:
		return {}
	var balance_v: Variant = config_service.get_balance()
	return get_enemy_actor_cfg_from_balance(balance_v if balance_v is Dictionary else {})


## Balance-dict variant, for the call sites that already hold the loaded balance dict and
## have no ConfigService reference (KeeperIntroService.setup_trial_encounter takes `cfg`).
static func get_enemy_actor_cfg_from_balance(balance: Dictionary) -> Dictionary:
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var summoning_v: Variant = data.get("summoning", {})
	var summoning: Dictionary = summoning_v if summoning_v is Dictionary else {}
	var actor_v: Variant = data.get("actor", {})
	var actor: Dictionary = actor_v if actor_v is Dictionary else {}
	return {
		"birth_stats": summoning.get("birth_stats", {}),
		"enemy_types": actor.get("enemy_types", {}),
	}


## V2-PROG-012 Phase 0 / V2-INFRA-003 Phase 6 Slice 6G: merges data.maturity_expression into
## data.actor for BehaviorArbiter's actor_cfg (data.actor wins on collision). Body moved
## verbatim from FlowRuntime._merge_actor_cfg; only its home changed. It belongs here because
## it combines two named balance.json subtrees and nothing else — the documented owner for a
## balance-subtree read (AGENTS.md, "Extract shared services"). Pure/stateless so
## MaturityExpressionTests can call this exact function instead of re-implementing the merge
## inline — a copy-pasted duplicate in the test would silently drift from production.
##
## The per-run MEMO of this result stays on FlowRuntime (_get_actor_cfg_merged /
## _actor_cfg_merged_cache) and deliberately did NOT move: its correct lifetime is one
## FlowRuntime, i.e. one campaign. A static cache here would be process-wide and two campaigns
## — or two test runs in one Godot process — could read each other's entries.
##
## Shallow duplicate() is correct here, not deep: BehaviorArbiter never writes to _cfg after
## construction (verified — no `_cfg[...] =` assignment anywhere in BehaviorArbiter.gd or
## ActorStateMachine.gd, only reads via _cfg_get()), and this merge only ever adds top-level
## keys, never mutates a nested value in place. A shallow copy is therefore both correct and
## far cheaper than deep-copying ~13KB of nested config (situational_muls alone serializes to
## 5.5KB) every time this is called.
static func merge_actor_cfg(actor_data_cfg: Dictionary, maturity_cfg: Dictionary) -> Dictionary:
	var merged: Dictionary = actor_data_cfg.duplicate()
	for k: String in maturity_cfg.keys():
		if not merged.has(k):
			merged[k] = maturity_cfg[k]
	return merged

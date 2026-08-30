# res://core/combat/CombatTurnContextService.gd
# V2-INFRA-003 Phase 6 Slice 6H: the PER-TURN CONTEXT BUILDER, moved verbatim out of
# core/runtime/FlowRuntime.gd::_resolve_next_actor (the contiguous block that sat at
# :1234-:1357, 124 lines).
#
# WHAT THIS IS. Everything that turns the live encounter plus save data plus balance.json into
# the single `ctx` Dictionary that ActorStateMachine.advance_turn() consumes, and the
# terrain-aware board_cfg that the same activation needs afterwards. Five things, in the order
# they ran before the move and still run now:
#
#   1. PURIFY_SHRINE shrine scan          -> shrine_alive / shrine_hp_ratio
#   2. VOW-001 active vow                 -> ctx.active_vow
#   3. BOND-002 social graph              -> ctx.bonds
#   4. STAGE-004 P3a terrain board_cfg    -> ctx.board_cfg AND the returned board_cfg
#   5. STAGE-004 §4-C mode directive      -> ctx.directive (a COPY; the shared player
#                                            directive dict is never mutated)
#
# It is a PURE BUILDER: it writes nothing. Not an actor dict, not combat_state, not save data,
# not a snapshot. Every effect it has is the dictionary it returns.
#
# WHY core/combat/. The consumer is the combat activation, and the five inputs are combat
# concerns (resolution mode, shrine, board, mode directive). It files beside the Phase 6
# siblings already carved out of this same spine.
#
# CONTRACT (same as every Phase 6 sibling):
#   - Typed RefCounted. Explicit typed dependencies at construction — no autoloads, no service
#     locator, no reaching back into FlowRuntime.
#   - NO flow_machine. This class cannot transition state or rebuild a snapshot.
#   - Never calls SaveService and never sets flow_ctx.save_request. The pre-extraction block
#     requested no save and must not start: FlowRuntime._mark_save_requested() joins reasons
#     with "|", so a save queued here would glue its reason onto the next dispatch's string.
#   - Calls no controller. It calls VowService/ConfigService/KeeperIntroService statically and
#     DirectiveService through the injected instance, exactly as the moved code did.
#
# CONSTRUCTOR DEPENDENCIES — FOUR, one more than the usual three. directive_service is a
# FlowRuntime member with no home on FlowContext, and the moved code reads it
# (`directive_service.get_active_directive()`) behind an explicit null guard. Passing it
# explicitly is the only honest option: reaching back into FlowRuntime is forbidden, and there
# is no other owner to read it from. The null guard is preserved, so a runtime built without a
# DirectiveService behaves exactly as before.
#
# WHAT IT TOUCHES — the complete read/write set, verified line by line:
#   READS   ectx.resolution_mode, ectx.actors (shrine scan, all_actors, party_size),
#           ectx.purifier_id, ectx.terrain, ectx.round_bark_events (shallow-copied into ctx so
#           no consumer can append to the live array), ectx.combat_state (totem_stolen,
#           totem_carrier_id, recover_holder_id);
#           flow_ctx.save_data (VowService.get_active_vow, sanctum.bonds),
#           flow_ctx itself (KeeperIntroService.is_trial_active);
#           config_service.get_balance() -> data.grid;
#           ConfigService.get_objective_modes_cfg_from_balance(balance);
#           ConfigService.get_bond_thresholds_cfg / get_bond_behavior_cfg;
#           directive_service.get_active_directive();
#           actor (id, faction, is_dead, is_spirit), `balance`, `round_number` and `t`, all
#           passed in.
#   WRITES  NOTHING. The returned dict is freshly built; ctx["directive"] is a deep duplicate
#           whenever mode weights apply, precisely so the shared directive is not mutated.
#
# DETERMINISM. No RNG and no OS time; `t` is injected and only stored into ctx. No dispatch is
# added or removed (the retreat roll's seed embeds the sim tick) and the round counter is read,
# never written (the theft roll's seed embeds the round counter).
#
# NO SHIM WAS LEFT ON FlowRuntime (AGENTS.md #20). There were no reflection call sites for this
# block: it was inline code with no name of its own.
#
# DEFECT NOTE — found during extraction, reported and deliberately NOT fixed here:
#   `party_size` still counts temporary allies (is_ally). Whether a one-battle companion is a
#   party member for the vow gate is a design question, not a code defect. Preserved verbatim.

class_name CombatTurnContextService
extends RefCounted

const KeeperIntroServiceScript := preload("res://core/onboarding/KeeperIntroService.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var directive_service: DirectiveService
var logger: StructuredLogger


func _init(
	_flow_ctx: FlowContext,
	_config_service: ConfigService,
	_directive_service: DirectiveService,
	_logger: StructuredLogger
) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	directive_service = _directive_service
	logger = _logger


## Builds the per-turn context handed to ActorStateMachine.advance_turn(), run once per
## activation from FlowRuntime._resolve_next_actor immediately AFTER the config reads and
## BEFORE the live movement preparation.
##
## Returns { "ctx": Dictionary, "board_cfg": Dictionary }. board_cfg is returned as well as
## being stored under ctx["board_cfg"] because the caller needs the SAME object three more
## times after this call — for the live movement preparation, for FleeBehaviorModule, and for
## the PURSUE escape bounds — and re-deriving it there would be a second copy of the terrain
## logic (AGENTS.md #19).
##
## `balance` and `bdata` are passed in rather than re-read so that ctx["cfg"] is the exact dict
## the caller read once at the top of the activation, and so this method makes no config read
## the pre-extraction code did not make.
func build_turn_context(
	actor: Dictionary,
	ectx: EncounterContext,
	balance: Dictionary,
	bdata: Dictionary,
	round_number: int,
	t: int
) -> Dictionary:
	var grid_cfg: Dictionary = bdata.get("grid", {})
	# COMBAT-006: find shrine and compute context fields for purify_shrine objective.
	var shrine_alive: bool    = false
	var shrine_hp_ratio: float = 1.0
	if ectx.resolution_mode == EncounterResolutionModes.PURIFY_SHRINE:
		for a_v in ectx.actors:
			if a_v is Dictionary and a_v.get("is_structure", false) and not a_v.get("is_dead", false):
				shrine_alive = true
				var s_max: int = int(a_v.get("stats", {}).get("max_hp", 0))
				if s_max > 0:
					shrine_hp_ratio = clampf(float(a_v.get("current_hp", s_max)) / float(s_max), 0.0, 1.0)
				break

	# VOW-001: pass active vow into per-turn context so BehaviorArbiter can apply vow bias.
	var _vow_ctx := VowService.get_active_vow(flow_ctx.save_data)

	# BOND-002: pass social graph into per-turn context for bond-aware behavior bias.
	var _bond_sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var _bond_sanctum: Dictionary = _bond_sanctum_v if _bond_sanctum_v is Dictionary else {}
	var _bonds_for_ctx: Array = _bond_sanctum.get("bonds", []) as Array

	# V2-STAGE-004 P3a: thread terrain walkable set + board dims into movement board_cfg.
	# Only when encounter_ctx.terrain is non-empty (i.e. irregular terrain was generated).
	# Absent terrain → board_cfg is the raw grid_cfg → legacy 10×10 behaviour unchanged.
	var movement_board_cfg: Dictionary = grid_cfg
	if ectx != null and not ectx.terrain.is_empty():
		var _mv_walkable: Dictionary = StageTerrain.walkable_set(ectx.terrain)
		var _mv_bounds: Dictionary   = ectx.terrain.get("bounds", {})
		movement_board_cfg = grid_cfg.duplicate(true)
		movement_board_cfg["walkable"]   = _mv_walkable
		if _mv_bounds.has("w"):
			movement_board_cfg["board_cols"] = int(_mv_bounds["w"])
		if _mv_bounds.has("h"):
			movement_board_cfg["board_rows"] = int(_mv_bounds["h"])

	# data.combat.objective_modes — read once here, used both for the mode directive injection
	# below and passed into ctx for BehaviorArbiter (D91: the arbiter holds no ConfigService,
	# so the subtree reaches it through the per-turn context).
	var objective_modes_cfg: Dictionary = ConfigService.get_objective_modes_cfg_from_balance(balance)

	# Build per-turn context — matches ActorStateMachine.advance_turn() contract.
	var ctx: Dictionary = {
		"actor":                   actor,
		"all_actors":              ectx.actors,
		"board_cfg":               movement_board_cfg,
		"cfg":                     balance,
		"t":                       t,
		"round":                   round_number,
		# COMBAT-006: shrine context fields for BehaviorArbiter + MeleeBehaviorModule.
		"purifier_id":             ectx.purifier_id,
		"is_purifier":             str(actor.get("id", "")) == ectx.purifier_id,
		"shrine_alive":            shrine_alive,
		"shrine_hp_ratio":         shrine_hp_ratio,
		"prefer_objective_target": actor.get("faction", "") == "enemy" \
			and (ectx.resolution_mode == EncounterResolutionModes.PURIFY_SHRINE \
				or ectx.resolution_mode == EncounterResolutionModes.PROTECT \
				or ectx.resolution_mode == EncounterResolutionModes.RECOVER \
				or ectx.resolution_mode == EncounterResolutionModes.GUIDE_SPIRIT),
		# VOW-001: active vow dict (or {}) for BehaviorArbiter vow bias layer.
		"active_vow":              _vow_ctx,
		# VOW-001: echo party size for tikoro_nko_agyina party-size gate.
		# Objective actors are not party members — same principle as the kill-share denominator.
		# is_spirit is the biting filter: a JOINED guide spirit is built as faction "echo" and
		# inflated this count by one. is_structure is belt-and-braces (every authored structure
		# carries faction "structure" today) so a structure can never be counted either.
		"party_size":              ectx.actors.filter(func(a): return str(a.get("faction","")) == "echo" \
			and not bool(a.get("is_dead", false)) \
			and not bool(a.get("is_structure", false)) \
			and not bool(a.get("is_spirit", false))).size(),
		# BOND-002: social graph for bond-aware behavior bias (BehaviorArbiter._apply_bond_bias).
		"bonds":                   _bonds_for_ctx,
		"bond_thresholds":         ConfigService.get_bond_thresholds_cfg(config_service),
		"bond_behavior_cfg":       ConfigService.get_bond_behavior_cfg(config_service),
		# V2-VOICE-001: reactive bark queue — actors read this to fire rally_ally barks.
		# Shallow copy so a consumer cannot append to (or clear) the live ectx array. The
		# entries themselves are read but never written. Reset each round, one entry per
		# activation, so the copy is a few small dicts.
		"round_bark_events":       ectx.round_bark_events.duplicate(),
		"directive":               {} if KeeperIntroServiceScript.is_trial_active(flow_ctx) else (directive_service.get_active_directive() if directive_service != null else {}),
		# V2-STAGE-004 Distinctiveness: mode identity + PROTECT theft context for BehaviorArbiter.
		"resolution_mode":         str(ectx.resolution_mode),
		"totem_stolen":            bool(ectx.combat_state.get("totem_stolen", false)),
		"totem_carrier_id":        str(ectx.combat_state.get("totem_carrier_id", "")),
		# data.combat.objective_modes for BehaviorArbiter._build_board_summary.
		"objective_modes_cfg":     objective_modes_cfg,
	}

	# V2-STAGE-004 Distinctiveness §4-C: mode directive injection.
	# Merge mode-specific directive_intent_weights into a COPY of the player directive —
	# never mutate the shared player directive dict.
	# Gate: skip during keeper-intro trial (mirrors the existing keeper-intro guard above).
	if not KeeperIntroServiceScript.is_trial_active(flow_ctx):
		var _mode_dw_src: Dictionary = {}
		var _di_mode: String = str(ectx.resolution_mode)
		var _di_mode_cfg: Dictionary = objective_modes_cfg.get(_di_mode, {})
		var _di_raw_dw: Variant = _di_mode_cfg.get("directive_intent_weights", {})
		if _di_raw_dw is Dictionary and not (_di_raw_dw as Dictionary).is_empty():
			# Determine whether this actor is eligible for mode directive injection.
			var _di_apply: bool = false
			match _di_mode:
				EncounterResolutionModes.RECOVER:
					# Only the designated holder receives mode directive weights.
					_di_apply = str(actor.get("id", "")) == str(ectx.combat_state.get("recover_holder_id", "")) \
						and str(actor.get("faction", "")) == "echo" \
						and not bool(actor.get("is_dead", false))
				EncounterResolutionModes.PROTECT:
					# All living echoes receive mode directive (interpose bias).
					_di_apply = str(actor.get("faction", "")) == "echo" \
						and not bool(actor.get("is_dead", false))
				EncounterResolutionModes.PURIFY_SHRINE:
					# All NON-purifier echoes receive mode directive.
					_di_apply = str(actor.get("faction", "")) == "echo" \
						and not bool(actor.get("is_dead", false)) \
						and not bool(ctx.get("is_purifier", false))
				EncounterResolutionModes.PURSUE:
					# All living echoes receive pursuit directive (fan-out and intercept bias).
					_di_apply = str(actor.get("faction", "")) == "echo" \
						and not bool(actor.get("is_dead", false))
				EncounterResolutionModes.GUIDE_SPIRIT:
					# All living echoes receive the guide directive (escort/protect bias).
					# The spirit itself never receives directive weights (movement is
					# fully owned by the _end_round escort/skittish step).
					_di_apply = str(actor.get("faction", "")) == "echo" \
						and not bool(actor.get("is_dead", false)) \
						and not bool(actor.get("is_spirit", false))
				_:
					_di_apply = false  # ENDURE / COMBAT: no mode directive.
			if _di_apply:
				_mode_dw_src = _di_raw_dw as Dictionary
		if not _mode_dw_src.is_empty():
			# Duplicate the player directive to avoid mutating the shared object.
			var _base_dir: Dictionary = ctx.get("directive", {})
			var _dir_copy: Dictionary = _base_dir.duplicate(true)
			if not _dir_copy.has("intent_weights"):
				_dir_copy["intent_weights"] = {}
			var _iw_copy: Dictionary = (_dir_copy["intent_weights"] as Dictionary).duplicate(true)
			for _dw_key in _mode_dw_src:
				_iw_copy[_dw_key] = float(_iw_copy.get(_dw_key, 0.0)) + float(_mode_dw_src[_dw_key])
			_dir_copy["intent_weights"] = _iw_copy
			ctx["directive"] = _dir_copy

	return {
		"ctx":       ctx,
		"board_cfg": movement_board_cfg,
	}

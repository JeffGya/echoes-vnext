# res://core/echoes/NarrativeVoiceService.gd
# V2-INFRA-003 Phase 4 Slice 3: bark/snippet/voice-selection orchestration extracted out of
# FlowRuntime.gd, following the WeaveController/VowConsequenceService extraction pattern (see
# core/runtime/controllers/WeaveController.gd for the full contract writeup).
#
# CONTRACT:
#   - Typed RefCounted. Explicit typed dependencies passed at construction — no autoloads,
#     no service locator, no reaching back into FlowRuntime.
#   - THIS IS A SERVICE, NOT A CONTROLLER: any controller or service may call it (unlike a
#     controller, which may never be called by another controller). It never calls
#     FlowRuntime, any controller, or SaveService, and holds no UI/scene-tree reference.
#     It does not transition state or rebuild a snapshot — callers own that.
#   - Mutates only: the actor/echo/explore_map dict handed to it by the caller (writing
#     _bark_line/_bark_context/_bark_tier or _sanctum_bark, or explore_map["travel_bark"] /
#     ["travel_snippet"]), flow_ctx.encounter_ctx.round_bark_events (append-only), and the
#     save-data roster Array passed in by reference — the same surface these methods mutated
#     as private FlowRuntime methods.
#
# Placed beside ShoutBank.gd (core/echoes/) rather than under core/runtime/services/: every
# method here is a flow-level orchestration layer on top of ShoutBank (deterministic content
# lookup) and the two bark JSON caches — the same "orchestration service sits next to the
# domain class it wraps" relationship VowConsequenceService (core/sanctum/) has with
# VowService (core/sanctum/). There is no core/runtime/services/ directory in the existing
# layout, and creating one for a single file would not match how VowConsequenceService was
# placed in Slice 2.
#
# Moved verbatim (behaviour unchanged) from FlowRuntime.gd:
#   _load_spirit_barks                         → _load_spirit_barks (private, own cache field)
#   _fire_spirit_bark                          → fire_spirit_bark
#   _load_ally_barks                           → _load_ally_barks (private, own cache field)
#   _fire_ally_bark                            → fire_ally_bark
#   _select_travel_beat                        → select_travel_beat
#   _select_travel_bark                        → _select_travel_bark (private, only called by
#                                                  select_travel_beat)
#   _fire_anansi_snippet                       → fire_anansi_snippet
#   _anansi_snippet_events_cfg                 → _anansi_snippet_events_cfg (private)
#   _select_sanctum_barkers                    → _select_sanctum_barkers (private, only called
#                                                  by select_arrival_barks_for_party)
#   _voice_urgency_score                       → _voice_urgency_score (private)
#   _select_sanctum_bark_for_actor_and_write   → select_sanctum_bark_for_actor_and_write
#   _select_sanctum_bark_for_echo_data_and_write → select_sanctum_bark_for_echo_data_and_write
#   _select_arrival_barks_for_party            → select_arrival_barks_for_party
#
# NOT moved (correction to the brief's list): _get_expression_band_for_echo was never on
# FlowRuntime by the time this slice started — it relocated to
# MaturityExpressionService.get_expression_band_for_echo() during Slice 1 (see
# WeaveController.gd's Slice 1b note). Confirmed by grep: no _get_expression_band_for_echo
# definition remains in FlowRuntime.gd.
#
# ONE SIGNATURE CHANGE (still behaviour-identical): select_travel_beat/_select_travel_bark
# took no party-echoes parameter on FlowRuntime — they called FlowRuntime._get_active_party_
# echoes() directly. That helper is a general save-data reader used by six other call sites
# across FlowRuntime (party morale application, stage/return-home logic, etc.), not a voice
# helper, so it stays on FlowRuntime rather than moving or being duplicated here. Since this
# service must not call back into FlowRuntime, select_travel_beat now takes the already-
# computed party_echoes Array as an explicit parameter; FlowRuntime's call site passes
# _get_active_party_echoes() (a pure, side-effect-free read) at the same call site it used to
# compute it from inside the old method. Same result, same order, same conditions.
#
# ALSO FIXED: core/sanctum/VowConsequenceService.gd had a private _write_sanctum_bark_for_echo
# that was a byte-for-byte scoped copy of FlowRuntime._select_sanctum_bark_for_echo_data_and_
# write (see its own doc-comment, which named this exact duplication as deliberate-for-now).
# It has been deleted; VowConsequenceService.apply_vow_stage_entry_condition() now calls this
# service's select_sanctum_bark_for_echo_data_and_write() instead.

class_name NarrativeVoiceService
extends RefCounted

const FlowStageExploreStateScript := preload("res://core/state/flow/states/venture/FlowStageExploreState.gd")

var flow_ctx: FlowContext
var config_service: ConfigService
var logger: StructuredLogger

# Lazy-loaded, session-cached bark JSON. Mirrors FlowRuntime's former _spirit_barks_cache /
# _ally_barks_cache fields — cached on the service instance, which FlowRuntime constructs
# per-call (see FlowRuntime._voice_service()), same cheap-RefCounted rationale as
# _weave_controller()/_vow_consequence_service(). Content is static JSON so per-dispatch
# reconstruction only means re-reading the file at most once per dispatch that fires a bark —
# no behavioural difference, since the data never changes within a session.
var _spirit_barks_cache: Dictionary = {}
var _ally_barks_cache: Dictionary = {}


func _init(_flow_ctx: FlowContext, _config_service: ConfigService, _logger: StructuredLogger) -> void:
	flow_ctx = _flow_ctx
	config_service = _config_service
	logger = _logger


# ── V2-STAGE-004 P3c: GUIDE_SPIRIT combat barks ──────────────────────────────

## Returns a lazy-loaded dict from data/bark/spirit_barks.json. Cached after first load on
## this instance. Pure read — no side effects.
func _load_spirit_barks() -> Dictionary:
	if not _spirit_barks_cache.is_empty():
		return _spirit_barks_cache
	var path := "res://data/bark/spirit_barks.json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_spirit_barks_cache = parsed
	return _spirit_barks_cache


## Selects a deterministic bark line for the given context and writes it onto the spirit
## actor dict (_bark_line / _bark_context / _bark_tier), then appends to ectx.round_bark_events
## so the reactive-bark pipeline (BarkPopupLayer) can surface it like other high-signal barks.
## variation_key follows the ShoutBank convention: (t + id.hash()) % N — deterministic, no RNG.
func fire_spirit_bark(spirit: Dictionary, context: String, t: int) -> void:
	var lines_v: Variant = _load_spirit_barks().get(context, [])
	var lines: Array = lines_v if lines_v is Array else []
	if lines.is_empty():
		return
	var spirit_id: String = str(spirit.get("id", ""))
	var vk: int = posmod(t + spirit_id.hash(), lines.size())
	var line: String = str(lines[vk])
	spirit["_bark_line"]    = line
	spirit["_bark_context"] = context
	spirit["_bark_tier"]    = "nascent"
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx != null:
		ectx.round_bark_events.append({
			"actor_id":     spirit_id,
			"faction":      str(spirit.get("faction", "")),
			"bark_context": context,
			"grid_pos":     spirit.get("grid_pos", {}),
		})
	logger.info(t, "combat.guide.bark", "GUIDE_SPIRIT bark fired", {
		"context":   context,
		"spirit_id": spirit_id,
		"line":      line,
	})


# ── V2-STAGE-004 Phase 4 (S15 UI-B): Temporary Ally combat barks ─────────────

## Returns a lazy-loaded dict from data/bark/ally_barks.json. Cached after first load on this
## instance. Pure read — no side effects. Mirrors _load_spirit_barks()/fire_spirit_bark() — the
## leanest wiring available.
func _load_ally_barks() -> Dictionary:
	if not _ally_barks_cache.is_empty():
		return _ally_barks_cache
	var path := "res://data/bark/ally_barks.json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_ally_barks_cache = parsed
	return _ally_barks_cache


## Selects a deterministic bark line for the given context and writes it onto the ally
## actor dict (_bark_line / _bark_context / _bark_tier), then appends to ectx.round_bark_events
## so the reactive-bark pipeline (BarkPopupLayer) can surface it like other high-signal barks.
## variation_key follows the ShoutBank convention: (t + id.hash()) % N — deterministic, no RNG.
func fire_ally_bark(ally: Dictionary, context: String, t: int) -> void:
	var lines_v: Variant = _load_ally_barks().get(context, [])
	var lines: Array = lines_v if lines_v is Array else []
	if lines.is_empty():
		return
	var ally_id: String = str(ally.get("id", ""))
	var vk: int = posmod(t + ally_id.hash(), lines.size())
	var line: String = str(lines[vk])
	ally["_bark_line"]    = line
	ally["_bark_context"] = context
	ally["_bark_tier"]    = "nascent"
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx != null:
		ectx.round_bark_events.append({
			"actor_id":     ally_id,
			"faction":      str(ally.get("faction", "")),
			"bark_context": context,
			"grid_pos":     ally.get("grid_pos", {}),
		})
	logger.info(t, "combat.ally.bark", "Ally death bark fired", {
		"context":  context,
		"ally_id":  ally_id,
		"line":     line,
	})


# ── V2-STAGE-004 Phase 5: travel-beat selection ───────────────────────────────
#
# Fires once per advance-turn, only when the party actually travelled this turn
# (caller gates on `stepped` being non-empty). Selects a party-echo journey bark
# (ShoutBank) on odd ticks — the echo-bark cadence is unchanged.
#
# V2-STAGE-004 P5 (playtest fix): Anansi narrator snippets are NO LONGER part of the
# travel cadence. Anansi is not a constant narrator; his snippets are now event-driven
# (first entry / objective revealed / objectives complete / return-home failed) and are
# fired at those moments via FlowStageExploreState.fire_anansi_snippet — see the call
# sites in FlowRuntime._handle_stage_advance_turn, _handle_stage_return_home, and the
# state's enter().
# Mutates explore_map in place: writes "travel_bark" ({actor_name,line} or {}). Transient
# — same lifecycle as last_traveled_path (overwritten every advance, wiped on session reset).
## party_echoes: Array of active party echo dicts, computed by the caller
## (FlowRuntime._get_active_party_echoes()) — this service never reaches back into
## FlowRuntime, so the already-computed list is passed in rather than recomputed here.
func select_travel_beat(explore_map: Dictionary, t: int, logger_ref: StructuredLogger, party_echoes: Array) -> void:
	# Echo travel barks keep the existing odd-t gate (cadence unchanged).
	if t % 2 != 0:
		_select_travel_bark(explore_map, t, logger_ref, party_echoes)


## Picks one living party echo deterministically, then selects a ShoutBank
## "journey.travel" line using that echo's archetype/expression-band/calling —
## same call convention as select_sanctum_bark_for_echo_data_and_write.
func _select_travel_bark(explore_map: Dictionary, t: int, logger_ref: StructuredLogger, party_echoes: Array) -> void:
	if party_echoes.is_empty():
		return
	var idx: int = posmod(t + str(flow_ctx.stage_id).hash(), party_echoes.size())
	var echo: Dictionary = party_echoes[idx] if party_echoes[idx] is Dictionary else {}
	if echo.is_empty():
		return
	var arch    := str(echo.get("archetype_birth", "loyal"))
	var calling := str(echo.get("calling_origin", ""))
	var band    := MaturityExpressionService.get_expression_band_for_echo(echo, ConfigService.get_maturity_expression_band_by_standing(config_service))
	var vk: int = posmod(t + str(echo.get("id", "")).hash(), 997)
	var line := ShoutBank.get_expression_shout("journey.travel", arch, band, calling, vk)
	# Fallback contract: ShoutBank.get_expression_shout always returns a non-empty
	# line (>= _FALLBACK "I'll do my part."), so no empty-line guard is needed here.
	explore_map["travel_bark"] = {
		"actor_name": str(echo.get("name", "")),
		"line":       line,
	}
	if logger_ref != null:
		logger_ref.debug(t, "stage.travel_beat", "Travel bark fired", {
			"layer":     "bark",
			"actor_id":  str(echo.get("id", "")),
			"stage_id":  str(flow_ctx.stage_id),
		})


# V2-STAGE-004 P5 (playtest fix): event-driven Anansi snippet firing.
# Thin instance wrapper over the shared static selector in FlowStageExploreState — reads
# the enabled-events config once, then delegates. Called at the narrative moments where
# the event is already computed (objective revealed, return-home failed).
func fire_anansi_snippet(explore_map: Dictionary, event_key: String, t: int) -> void:
	FlowStageExploreStateScript.fire_anansi_snippet(
		explore_map, event_key, _anansi_snippet_events_cfg(), t, logger, flow_ctx.stage_id
	)


# Reads data.stages.anansi_snippet_events from balance config (defensive: {} when absent).
func _anansi_snippet_events_cfg() -> Dictionary:
	if config_service == null:
		return {}
	var bal_v: Variant = config_service.get_balance()
	var bal: Dictionary = bal_v if bal_v is Dictionary else {}
	var bd_v: Variant = bal.get("data", {})
	var bd: Dictionary = bd_v if bd_v is Dictionary else {}
	var sc_v: Variant = bd.get("stages", {})
	var sc: Dictionary = sc_v if sc_v is Dictionary else {}
	var ev_v: Variant = sc.get("anansi_snippet_events", {})
	return ev_v if ev_v is Dictionary else {}


# ── V2-VOICE-001: Sanctum bark helpers ───────────────────────────────────────

## Selects up to `voice.sanctum_max_barkers` (default 2) party echoes to receive a sanctum bark.
## Step 1: event echo (most directly involved). Step 2: urgency tiebreaker.
## party_actors: Array of runtime actor dicts (faction=echo, from ectx.actors).
## Returns Array[Dictionary] of ≤2 actor dicts.
func _select_sanctum_barkers(party_actors: Array, event_echo_id: String, t: int) -> Array:
	var voice_cfg: Dictionary = config_service.get_balance().get("data", {}).get("voice", {})
	var max_barkers: int = int(voice_cfg.get("sanctum_max_barkers", 2))
	if party_actors.is_empty():
		return []

	var result: Array = []
	var remaining: Array = []

	# Step 1: prioritise the event echo.
	for a_v in party_actors:
		var a: Dictionary = a_v
		if str(a.get("id", "")) == event_echo_id:
			result.append(a)
		else:
			remaining.append(a)

	if result.is_empty():
		remaining = party_actors.duplicate()

	if result.size() >= max_barkers or remaining.is_empty():
		return result

	# Step 2: urgency tiebreaker — highest urgency score wins.
	var urgency_sorted: Array = remaining.duplicate()
	urgency_sorted.sort_custom(func(aa, bb):
		return _voice_urgency_score(aa) > _voice_urgency_score(bb)
	)
	result.append(urgency_sorted[0])
	return result


## Urgency score for sanctum barker selection.
## (morale_tier == "broken" ? 30 : 0) + fear_current - morale_current
func _voice_urgency_score(actor: Dictionary) -> int:
	var morale: int = int(actor.get("morale", 50))
	var fear: int   = int(actor.get("fear",   0))
	var broken_bonus: int = 30 if morale < 25 else 0
	return broken_bonus + fear - morale


## Selects a sanctum bark for a runtime actor dict and writes `_sanctum_bark` to
## the matching save-data roster entry.
## actor: runtime actor dict (has id, archetype_birth, calling_origin, morale, fear).
## roster: save-data Array (mutated in place).
func select_sanctum_bark_for_actor_and_write(actor: Dictionary, context_key: String, t: int, roster: Array) -> void:
	var arch    := str(actor.get("archetype_birth", "loyal"))
	var calling := str(actor.get("calling_origin", ""))
	var band    := str(actor.get("expression_band", "nascent"))
	var vk: int = (t + str(actor.get("id", "")).hash()) % 997
	var line    := ShoutBank.get_expression_shout(context_key, arch, band, calling, vk)
	if line.is_empty():
		return
	var bark := { "line": line, "context": context_key }
	var actor_id := str(actor.get("id", ""))
	for i in range(roster.size()):
		if roster[i] is Dictionary and str((roster[i] as Dictionary).get("id", "")) == actor_id:
			(roster[i] as Dictionary)["_sanctum_bark"] = bark
			return


## Selects a sanctum bark for a save-data echo dict and writes `_sanctum_bark` to
## the matching roster entry.
## echo_data: save-data echo dict (has id, archetype_birth, calling_origin, rank).
## roster: save-data Array (mutated in place).
func select_sanctum_bark_for_echo_data_and_write(echo_data: Dictionary, context_key: String, t: int, roster: Array) -> void:
	var arch    := str(echo_data.get("archetype_birth", "loyal"))
	var calling := str(echo_data.get("calling_origin", ""))
	var band    := MaturityExpressionService.get_expression_band_for_echo(echo_data, ConfigService.get_maturity_expression_band_by_standing(config_service))
	var vk: int = (t + str(echo_data.get("id", "")).hash()) % 997
	var line    := ShoutBank.get_expression_shout(context_key, arch, band, calling, vk)
	if line.is_empty():
		return
	var bark := { "line": line, "context": context_key }
	var echo_id := str(echo_data.get("id", ""))
	for i in range(roster.size()):
		if roster[i] is Dictionary and str((roster[i] as Dictionary).get("id", "")) == echo_id:
			(roster[i] as Dictionary)["_sanctum_bark"] = bark
			return


## Selects arrival barks for up to 2 party echoes and writes them to save-data roster entries.
## Called in FlowRuntime._end_round() BEFORE build_final_snapshot() so the snapshot can include
## arrival_bark.
## is_victory: true = victory context, false = defeat.
func select_arrival_barks_for_party(is_victory: bool, t: int) -> void:
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx == null:
		return
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v
	var roster_v: Variant  = sanctum.get("roster", [])
	var roster: Array      = roster_v if roster_v is Array else []
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array   = party_ids_v if party_ids_v is Array else []

	# Collect alive party echo actors from ectx (runtime, post-combat values).
	var party_actors: Array = []
	for a_v in ectx.actors:
		if not (a_v is Dictionary):
			continue
		var a: Dictionary = a_v
		if str(a.get("faction", "")) != "echo":
			continue
		if not (str(a.get("id", "")) in party_ids):
			continue
		party_actors.append(a)

	if party_actors.is_empty():
		return

	# Event echo: on defeat, the echo with highest fear; on victory, none (urgency only).
	var event_echo_id := ""
	if not is_victory:
		var max_fear := -1
		for a_v in party_actors:
			var a: Dictionary = a_v
			var f: int = int(a.get("fear", 0))
			if f > max_fear:
				max_fear = f
				event_echo_id = str(a.get("id", ""))

	var base_ctx := "sanctum.arrival_victory" if is_victory else "sanctum.arrival_defeat"
	var barkers: Array = _select_sanctum_barkers(party_actors, event_echo_id, t)

	for actor_v in barkers:
		var actor: Dictionary = actor_v
		# Overlay broken bark if morale < 25 (broken tier).
		var bark_ctx := base_ctx
		if int(actor.get("morale", 50)) < 25:
			bark_ctx = "sanctum.broken"
		select_sanctum_bark_for_actor_and_write(actor, bark_ctx, t, roster)

	sanctum["roster"] = roster
	flow_ctx.save_data["sanctum"] = sanctum
	logger.debug(t, "voice.arrival_barks_written", "Arrival barks written", {
		"is_victory":   is_victory,
		"barker_count": barkers.size(),
	})

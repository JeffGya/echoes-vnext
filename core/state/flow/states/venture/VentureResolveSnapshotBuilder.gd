class_name VentureResolveSnapshotBuilder

extends RefCounted

## V2-INFRA-003 Phase 5 Slice E — the two venture-domain flow.resolve PRODUCERS, split out
## of core/realms/ActiveStageService.gd when that file passed the ~1,000-line guard.
## Pure file organisation: both functions are byte-for-byte the ones Slice B composed, with
## only their surrounding comments re-homed.
##
## PRODUCER vs BLOCK LIBRARY — why this is a separate file from ResolveSnapshotBuilder.
## ResolveSnapshotBuilder is the BLOCK LIBRARY: fifteen add_* writers plus build(), and a
## purity contract that takes NO FlowContext at all. Producers are the callers that decide
## WHICH blocks a given resolve card emits. ResolveSnapshotBuilder's own header names the six
## producers A–F and locates each one outside itself (A/B on FlowEncounterState, C/D/E on
## FlowRuntime pre-Slice-D, F on FlowResolveState). Moving a producer INTO the block library
## would invert that model and put a FlowContext read inside the file whose whole point is
## that it has none. So the producers get their own file and the purity contract is untouched.
##
## PLACEMENT — core/state/flow/states/venture/, beside ResolveSnapshotBuilder (the blocks
## these two compose) and StageExploreSnapshotBuilder (the sibling projection builder).
## That directory is where builders live; it is also where producers A and B already live,
## on FlowEncounterState, so Phase 6 has a natural home to migrate them into.
##
## PRODUCER C KEEPS ITS FlowContext PARAMETER — deliberate, not an oversight.
## StageExploreSnapshotBuilder.build(flow_ctx, t) in this same directory already establishes
## that a producer/projection builder may READ FlowContext as long as it writes nothing. The
## alternative — hoisting pending_scout_return_ase / pending_scout_return_intel_count /
## SanctumService.get_party_actors_static(save_data) into the two call sites — would have
## copied the same three-line marshalling into VentureController and FlowRuntime, and it would
## have DESTROYED an existing guard: tests/VentureCharacterizationTests.gd calls this producer
## twice with the SAME FlowContext and asserts byte-identical payloads. That assertion is what
## proves the producer does not consume (zero) the two one-shot pending_* fields — see the
## Slice B note inside the function. Feed it pre-read plain ints instead and the test can no
## longer prove anything. The FlowContext read is therefore load-bearing evidence, not debt.
##
## Neither function writes save_data, mutates FlowContext, calls request_save(), or constructs
## a service whose constructor can write (in particular never SanctumService.new()).


## Producer C — the scout-return / withdrawal resolve card.
## Moved verbatim from FlowRuntime._build_scout_return_snapshot(). It has TWO callers in
## different domains: VentureController.handle_return_home() (successful escape) and
## FlowRuntime._handle_encounter_retreat() (successful retreat, Phase 6's domain). Per
## core/AGENTS.md a helper used by two or more domains needs one owner, and a producer that
## READS FlowContext cannot live on ResolveSnapshotBuilder — that builder's purity contract
## takes no FlowContext at all. It is the "party withdrew from the stage" card, so it belongs
## to this stage-session service, static with an explicit flow_ctx parameter exactly like
## count_revealed_situations() and get_stage_base_reward() above.
## Pure: two calls with the same arguments return byte-identical payloads.
static func build_scout_return_snapshot(flow_ctx_arg: FlowContext, t: int) -> Dictionary:
	var _ase   := flow_ctx_arg.pending_scout_return_ase
	var _intel := flow_ctx_arg.pending_scout_return_intel_count
	var breakdown: Array = []
	if _ase > 0:
		breakdown.append({ "label": "Scout return", "delta": _ase, "currency": "ase" })

	var actor_preview: Array = []
	# V2-INFRA-003 Phase 5 Slice B: was SanctumService.new(flow_ctx.save_data).get_party_actors().
	# That constructor can WRITE to save_data via SanctumState._ensure_sanctum_dict_exists(),
	# which this read-only producer must never do. The static twin reproduces the instance
	# method line for line, including PARTY iteration order (active_party_ids, not roster order)
	# and the EchoActor.from_echo() element shape — get_active_party_echoes() would have been
	# the lookalike substitution AGENTS.md #19 warns about. Order-equality is pinned by
	# tests/PartyTests.gd sanctum.party/get_party_actors_static_matches_instance.
	var _party_actors := SanctumService.get_party_actors_static(flow_ctx_arg.save_data)
	for _a_v in _party_actors:
		if not _a_v is Dictionary:
			continue
		var _a: Dictionary = _a_v
		# Register D07: read the FLATTENED fields. EchoActor.from_echo() writes emotion to
		# top-level "morale"/"fear" (EchoActor.gd:57-58) and emits no "emotion" key, so the
		# nested read this used to do always yielded {} and every preview rendered the constant
		# get_emotional_status(50, 0). The durable withdrawal result stores this array verbatim,
		# so correcting the card corrects the stored save.flow.pending_result copy too.
		actor_preview.append({
			"id":               str(_a.get("id", "")),
			"name":             str(_a.get("name", "")),
			"calling_origin":   str(_a.get("calling_origin", "")),
			"emotional_status": EmotionService.get_emotional_status(
				int(_a.get("morale", 50)),
				int(_a.get("fear",   0))
			),
		})

	# V2-INFRA-003 Phase 5 Slice B: the two one-shot fields used to be zeroed HERE, which made a
	# second call to this producer return different data. They are now consumed exactly once by
	# the gated closure at the end of dispatch(), after this snapshot has been published and
	# logged. Do not re-add a clear here — this function is pure.

	var _intel_plural := "s" if _intel != 1 else ""

	# V2-INFRA-003 Phase 5 Slice B: producer C, composed through ResolveSnapshotBuilder.
	#
	# APPROVED FIX (spec §6.1 / Q1): this producer emitted `meta: { "sim_tick": t }`.
	# FlowStateMachine._validate_snapshot() requires `meta` to be a Dictionary CONTAINING "t"
	# and calls assert(false) otherwise, so every successful encounter.retreat and
	# stage.return_home tripped an assertion in a debug build. ResolveSnapshotBuilder.build()
	# always writes { "t": t }.
	var _actions: Dictionary = {
		"cta.continue": {
			"type":  "flow.go_state",
			"to":    FlowStateIds.SANCTUM,
			"label": "Return to Sanctum",
			"slot":  "cta.continue",
		}
	}
	var _snap: Dictionary = ResolveSnapshotBuilder.build(t, _actions, "scout_return")
	var _data: Dictionary = _snap["data"]
	ResolveSnapshotBuilder.add_ledger(_data, _ase, breakdown)
	ResolveSnapshotBuilder.add_ekwan(_data, 0)
	ResolveSnapshotBuilder.add_scout_intel(_data, _intel)
	ResolveSnapshotBuilder.add_actors(_data, actor_preview)
	ResolveSnapshotBuilder.add_victory_flag(_data, false)
	ResolveSnapshotBuilder.add_grade_rank(_data, "")
	# P1 CLOSE: additive fields for unified Resolve component.
	ResolveSnapshotBuilder.add_banner(_data, "scout_return", "%d crossing%s mapped." % [_intel, _intel_plural])
	ResolveSnapshotBuilder.add_grade_verdict(_data, "")
	return _snap


## Producer E — the in-explore situation resolve card. Moved verbatim from
## FlowRuntime._build_situation_resolve_snapshot(). Reached from BOTH of the two situation
## handlers VentureController owns (engage_situation's acknowledge/take/leave exit and
## resolve_situation_choice), so it is shared venture-domain logic rather than one handler's
## private helper. Pure — takes no FlowContext.
static func build_situation_resolve_snapshot(
		sit: Dictionary,
		summary_line: String,
		emotion_summary: Array,
		effects: Array,
		ase_awarded: int,
		t: int
) -> Dictionary:
	var sit_type := str(sit.get("type", ""))

	# verdict: take-types → "carried"; acknowledge/leave (omen/ritual/npc) → "passed";
	# choice-resolved (obstacle/structure) → "passed".
	var _verdict: String
	match sit_type:
		SituationModel.TYPE_LOOT, SituationModel.TYPE_MONEY:
			_verdict = "carried"
		_:
			_verdict = "passed"

	var _breakdown: Array = []
	if ase_awarded > 0:
		_breakdown.append({ "label": "Found", "delta": ase_awarded, "currency": "ase" })

	# V2-INFRA-003 Phase 5 Slice B: producer E, composed through ResolveSnapshotBuilder.
	# Same nine keys as before. tests/UnifiedResolveTests.gd pins this producer end to end and
	# is the only suite that asserts key PRESENCE (data.has) rather than value — dropping
	# add_emotion or add_effects here fails it immediately.
	var _actions: Dictionary = {
		"cta.continue": {
			"type":  "flow.go_state",
			"to":    FlowStateIds.STAGE_EXPLORE,
			"label": "Return to Stage",
			"slot":  "cta.continue",
		},
	}
	var _snap: Dictionary = ResolveSnapshotBuilder.build(t, _actions, "situation_result")
	var _data: Dictionary = _snap["data"]
	ResolveSnapshotBuilder.add_banner(_data, sit_type, summary_line)
	ResolveSnapshotBuilder.add_grade_verdict(_data, _verdict)
	ResolveSnapshotBuilder.add_emotion(_data, emotion_summary)
	ResolveSnapshotBuilder.add_effects(_data, effects)
	ResolveSnapshotBuilder.add_ledger(_data, ase_awarded, _breakdown)
	ResolveSnapshotBuilder.add_ekwan(_data, 0)
	return _snap

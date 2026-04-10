# res://core/state/flow/states/sanctum/FlowWeavingRiteState.gd
# V2-WEAVE-002R: Echo-first foundation Weaving Rite flow state.

class_name FlowWeavingRiteState
extends State

const WeavingRiteServiceScript := preload("res://core/progression/WeavingRiteService.gd")


func _init(id: String = FlowStateIds.WEAVING_RITE) -> void:
	super(id)


func enter(ctx: RefCounted, t: int) -> void:
	var flow_ctx := ctx as FlowContext
	flow_ctx.last_snapshot = build_snapshot(flow_ctx, t)


func exit(ctx: RefCounted, t: int) -> void:
	pass


static func build_snapshot(flow_ctx: FlowContext, t: int) -> Dictionary:
	var sanctum_v: Variant = flow_ctx.save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}

	var threads_v: Variant = sanctum.get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var selected_echo_id := str(flow_ctx.selected_weave_echo_id).strip_edges()
	var selected_thread_id := str(flow_ctx.selected_weave_thread_id).strip_edges()
	var resolution_v: Variant = flow_ctx.weave_resolution
	var resolution: Dictionary = resolution_v if resolution_v is Dictionary else {}
	var is_locked := bool(flow_ctx.weave_commit_locked)

	var echo := _find_echo(roster, selected_echo_id)
	if echo.is_empty():
		selected_echo_id = ""
		selected_thread_id = ""

	var thread_reserve := _collect_thread_reserve(threads)
	var selected_thread := _find_thread(threads, selected_thread_id)
	if selected_thread.is_empty():
		selected_thread_id = ""

	var phase := "echo_missing"
	if not resolution.is_empty():
		phase = "aftermath"
	elif selected_echo_id.is_empty():
		phase = "echo_missing"
	elif selected_thread_id.is_empty():
		phase = "thread_select"
	else:
		phase = "invitation"

	var invitation_lines: Array = []
	if phase == "invitation":
		var rite_cfg := _get_rite_cfg(flow_ctx)
		invitation_lines = _build_invitation_lines(echo, selected_thread, flow_ctx.save_data, rite_cfg)

	var outcome := str(resolution.get("outcome", ""))
	var aftermath_lines_v: Variant = resolution.get("aftermath_lines", [])
	var aftermath_lines: Array = aftermath_lines_v if aftermath_lines_v is Array else []
	if aftermath_lines.is_empty() and not outcome.is_empty():
		aftermath_lines = _default_aftermath_lines(outcome, resolution)

	var non_chosen_raw_v: Variant = resolution.get("non_chosen", [])
	var non_chosen_raw: Array = non_chosen_raw_v if non_chosen_raw_v is Array else []
	var non_chosen: Array = []
	for item_v in non_chosen_raw:
		if not (item_v is Dictionary):
			continue
		var item: Dictionary = item_v
		var ripple_line := _non_chosen_ripple_line(item)
		non_chosen.append({
			"echo_id": str(item.get("echo_id", "")),
			"name": str(item.get("name", "")),
			"consequence_type": "social_ripple",
			"ripple_line": ripple_line,
		})
	if non_chosen.is_empty() and not outcome.is_empty():
		non_chosen.append({
			"echo_id": "",
			"name": "",
			"consequence_type": "social_ripple",
			"ripple_line": _no_ripple_line(outcome),
		})

	var begin_disabled := true
	if phase == "invitation":
		begin_disabled = false
	if is_locked:
		begin_disabled = true

	var actions: Dictionary = {
		"nav.back": {
			"type": "flow.go_state",
			"to": FlowStateIds.SANCTUM,
			"label": "Back",
			"slot": "nav.back",
			"disabled": is_locked,
		},
		"cta.begin_rite": {
			"type": "weave.begin_rite",
			"label": "Begin Rite",
			"slot": "cta.begin_rite",
			"disabled": begin_disabled,
		},
		"cta.confirm": {
			"type": "weave.confirm",
			"label": "Confirm",
			"slot": "cta.confirm",
			"disabled": phase != "aftermath",
		},
	}

	return {
		"type": FlowStateIds.WEAVING_RITE,
		"meta": { "t": t },
		"data": {
			"phase": phase,
			"selected_echo": _project_echo_view(echo),
			"thread_reserve": thread_reserve,
			"selected_thread_id": selected_thread_id,
			"invitation_lines": invitation_lines,
			"outcome": outcome,
			"aftermath_lines": aftermath_lines,
			"non_chosen": non_chosen,
		},
		"actions": actions,
	}


static func _project_echo_view(echo: Dictionary) -> Dictionary:
	if echo.is_empty():
		return {}
	return {
		"id": str(echo.get("id", "")),
		"name": str(echo.get("name", "")),
		"standing": int(echo.get("standing", echo.get("rank", 1))),
		"calling_origin": str(echo.get("calling_origin", "")),
	}


static func _collect_thread_reserve(threads: Dictionary) -> Array:
	var out: Array = []
	var ids := threads.keys()
	ids.sort()
	for tid_v in ids:
		var tid := str(tid_v)
		var th_v: Variant = threads.get(tid, {})
		if not (th_v is Dictionary):
			continue
		var th: Dictionary = th_v
		out.append({
			"id": tid,
			"virtue": str(th.get("virtue", "unknown")),
			"quality_tier": str(th.get("quality_tier", "broken")),
		})
	return out


static func _find_thread(threads: Dictionary, thread_id: String) -> Dictionary:
	if thread_id.is_empty():
		return {}
	var th_v: Variant = threads.get(thread_id, {})
	return th_v if th_v is Dictionary else {}


static func _find_echo(roster: Array, echo_id: String) -> Dictionary:
	if echo_id.is_empty():
		return {}
	for e_v in roster:
		if e_v is Dictionary and str(e_v.get("id", "")) == echo_id:
			return e_v
	return {}


static func _build_invitation_lines(echo: Dictionary, thread: Dictionary, save_data: Dictionary, cfg: Dictionary) -> Array:
	var thread_virtue := str(thread.get("virtue", "story"))
	var echo_name := str(echo.get("name", "This echo"))

	var candidates: Array = WeavingRiteServiceScript.get_candidates(thread, [echo], save_data, cfg)
	if candidates.is_empty():
		return [
			"%s stands before the %s thread." % [echo_name, thread_virtue],
			"The signs are difficult to read in this moment.",
		]

	var c_v: Variant = candidates[0]
	var c: Dictionary = c_v if c_v is Dictionary else {}
	var fit := str(c.get("fit_clue", "Resonant"))
	var readiness := str(c.get("readiness_clue", "Unsteady"))
	var strain := str(c.get("strain_clue", "Contested"))

	return [
		"%s steps toward the %s thread." % [echo_name, thread_virtue],
		"The pull feels %s, while their breath reads %s." % [fit, readiness],
		"The house around them feels %s." % strain,
	]


static func _get_rite_cfg(flow_ctx: FlowContext) -> Dictionary:
	if flow_ctx.config_service == null:
		return {}
	var balance: Dictionary = flow_ctx.config_service.get_balance()
	var data_v: Variant = balance.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var rite_v: Variant = data.get("weaving_rite", {})
	return rite_v if rite_v is Dictionary else {}


static func _default_aftermath_lines(outcome: String, resolution: Dictionary) -> Array:
	var echo_name := str(resolution.get("echo_name", "This echo"))
	var virtue := str(resolution.get("thread_virtue", "story"))
	match outcome:
		"accept":
			return [
				"%s accepts the %s thread." % [echo_name, virtue],
				"The weave settles and the house quiets for a breath.",
			]
		"reject":
			return [
				"%s rejects the %s thread." % [echo_name, virtue],
				"The refusal still redraws who they are becoming.",
			]
		"defer":
			return [
				"%s defers the %s thread." % [echo_name, virtue],
				"A mark remains, and the thread returns to reserve.",
			]
		_:
			return []


static func _non_chosen_ripple_line(item: Dictionary) -> String:
	var name := str(item.get("name", "Another Echo"))
	var morale_delta := int(item.get("morale_delta", 0))
	var fear_delta := int(item.get("fear_delta", 0))
	if morale_delta <= -10 or fear_delta >= 8:
		return "%s absorbs the aftermath sharply." % name
	if morale_delta < 0 or fear_delta > 0:
		return "%s leaves the rite unsettled." % name
	return "%s keeps composure, but the moment lingers." % name


static func _no_ripple_line(outcome: String) -> String:
	match outcome:
		"accept":
			return "No wider ripple surfaces in the house this time."
		"reject":
			return "The refusal remains mostly private, with little house-wide ripple."
		"defer":
			return "The deferment lingers quietly; no immediate ripple spreads."
		_:
			return "No immediate social ripple is visible."

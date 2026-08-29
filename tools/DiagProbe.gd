# DIAGNOSIS PROBE — scratchpad only, never committed.
# Run: godot --headless -s res://tools/DiagProbe.gd --path <checkout>
extends SceneTree


func _initialize() -> void:
	print("DIAGPROBE_BEGIN")
	var scen: String = "A"
	for a in OS.get_cmdline_user_args():
		scen = str(a)
	if scen == "A" or scen == "AB":
		_run_a()
	if scen == "B" or scen == "AB":
		_run_b()
	if scen == "C":
		_run_c()
	print("DIAGPROBE_END")
	quit(0)


func _boot(tag: String, mode: String) -> Dictionary:
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var config := ConfigService.new()
	var slot_path: String = "/tmp/echoes-vnext-tests/diag_%s.json" % tag
	for suffix in ["", ".tmp", ".bak1", ".bak2", ".bak3", ".pending_a", ".pending_b"]:
		DirAccess.remove_absolute(slot_path + suffix)
	var runtime := FlowRuntime.new(logger, config, slot_path)
	runtime.boot()
	var bal: Dictionary = (config._balance as Dictionary).get("data", {})
	var flow_ctx: FlowContext = runtime.flow_ctx
	var t: int = 0
	var pinned_root: String = "diagprobe:%s" % tag
	var pinned_seed: int = absi(pinned_root.hash())
	if not (flow_ctx.save_data.get("campaign", {}) is Dictionary):
		flow_ctx.save_data["campaign"] = {}
	var camp: Dictionary = flow_ctx.save_data["campaign"]
	camp["seed_root"] = pinned_root
	camp["root_seed"] = pinned_seed
	flow_ctx.campaign_seed = CampaignSeed.new(pinned_seed)
	flow_ctx.realm_id = "realm.01"
	if RealmService.get_or_create("realm.01", flow_ctx, t).is_empty():
		print("ERROR realm setup failed")
		return {}
	flow_ctx.stage_id = "stage.0"
	flow_ctx.encounter_id = "realm.01.stage.0.diag." + tag
	var summ_cfg: Dictionary = bal.get("summoning", {})
	var expr_cfg: Dictionary = bal.get("maturity_expression", {})
	var roster: Array = []
	var party_ids: Array = []
	for i in range(3):
		var echo: Dictionary = EchoFactory.generate(tag, "echo." + str(i), i, "summon", summ_cfg, expr_cfg)
		echo["id"] = "echo_%04d" % (i + 1)
		echo["rank"] = 1
		EmotionService.init_echo(echo, logger, t)
		VectorService.init_vectors(echo, bal.get("vectors", {}), logger, t)
		if not echo.has("emotion") or not (echo["emotion"] is Dictionary):
			echo["emotion"] = {}
		roster.append(echo)
		party_ids.append(str(echo["id"]))
	flow_ctx.save_data["sanctum"]["roster"] = roster
	flow_ctx.save_data["sanctum"]["active_party_ids"] = party_ids
	flow_ctx.dev_combat_objective = mode
	flow_ctx.encounter_ctx = null
	flow_ctx.encounter_machine = null
	var enc_state := FlowEncounterState.new()
	enc_state.enter(flow_ctx, t)
	var ectx: EncounterContext = flow_ctx.encounter_ctx
	if ectx == null:
		print("ERROR encounter setup failed")
		return {}
	return {"runtime": runtime, "ectx": ectx, "flow_ctx": flow_ctx}


func _find(ectx, id: String) -> Dictionary:
	for av in ectx.actors:
		if str((av as Dictionary).get("id", "")) == id:
			return av
	return {}


func _pos(a: Dictionary) -> String:
	var p: Dictionary = a.get("grid_pos", {})
	return "(%d,%d)" % [int(p.get("col", -9)), int(p.get("row", -9))]


func _dump(ectx: EncounterContext, label: String) -> void:
	var s: String = label
	for av in ectx.actors:
		var a: Dictionary = av
		if bool(a.get("is_dead", false)):
			continue
		s += " | %s %s%s%s hp=%d" % [
			str(a.get("id", "")), str(a.get("faction", "")), _pos(a),
			("[S]" if bool(a.get("is_structure", false)) else ""),
			int(a.get("current_hp", 0))]
	print(s)


# ── Symptom A: do actors close the distance? ────────────────────────────────
func _run_a() -> void:
	print("=== SCENARIO A: plain COMBAT, forced 10-column separation ===")
	var env: Dictionary = _boot("a", EncounterResolutionModes.COMBAT)
	if env.is_empty():
		return
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	var bw: int = 10
	var bh: int = 10
	if not ectx.terrain.is_empty():
		var b: Dictionary = ectx.terrain.get("bounds", {})
		bw = int(b.get("w", 10))
		bh = int(b.get("h", 10))
	print("board %dx%d  actors=%d" % [bw, bh, ectx.actors.size()])

	# Force the reported shape: one echo at (1,1), one enemy ten columns to its right.
	# Every other actor is removed from play so the two-body geometry is exact.
	var echo_seen: bool = false
	var enemy_seen: bool = false
	var enemy_col: int = mini(11, bw - 1)
	for av in ectx.actors:
		var a: Dictionary = av
		if str(a.get("faction", "")) == "echo" and not echo_seen:
			echo_seen = true
			a["grid_pos"] = {"col": 1, "row": 1}
		elif str(a.get("faction", "")) == "enemy" and not enemy_seen:
			enemy_seen = true
			a["grid_pos"] = {"col": enemy_col, "row": 0}
		else:
			a["is_dead"] = true
			a["current_hp"] = 0
	_dump(ectx, "start")

	runtime.dispatch({"type": "combat.init"})
	var idle_rounds: int = 0
	var any_move: bool = false
	var any_attack: bool = false
	for r in range(12):
		if bool(ectx.combat_state.get("combat_over", false)):
			print("combat_over at round %d" % r)
			break
		runtime.dispatch({"type": "combat.confirm_round"})
		var guard: int = 0
		var acts: Array = []
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)):
				break
			if str(cs.get("round_phase", "")) != "in_round":
				break
			var before: int = ectx.last_round_results.size()
			runtime.dispatch({"type": "combat.next_actor"})
			if ectx.last_round_results.size() > before:
				for i in range(before, ectx.last_round_results.size()):
					var rec: Dictionary = ectx.last_round_results[i]
					var aid: String = str(rec.get("actor_id", rec.get("id", "?")))
					var at: String = str(rec.get("action_type", rec.get("action", "?")))
					acts.append("%s:%s" % [aid, at])
					if at == "actor.move":
						any_move = true
					if at == "melee_attack":
						any_attack = true
		var nonidle: bool = false
		for x in acts:
			if not str(x).ends_with("actor.idle"):
				nonidle = true
		if not nonidle:
			idle_rounds += 1
		print("round %d: %s" % [r, ", ".join(acts)])
		_dump(ectx, "  pos")
	print("RESULT_A all_idle_rounds=%d any_move=%s any_attack=%s" % [idle_rounds, any_move, any_attack])


# ── Symptom B: guide-spirit escort ──────────────────────────────────────────
func _run_b() -> void:
	print("=== SCENARIO B: GUIDE_SPIRIT ===")
	var env: Dictionary = _boot("b", EncounterResolutionModes.GUIDE_SPIRIT)
	if env.is_empty():
		return
	var runtime: FlowRuntime = env["runtime"]
	var ectx: EncounterContext = env["ectx"]
	var cs: Dictionary = ectx.combat_state
	print("guide_mode=%s spirit_id=%s dest=(%s,%s) joins=%s" % [
		str(cs.get("guide_mode", "?")), str(cs.get("spirit_id", "?")),
		str(cs.get("destination_col", "?")), str(cs.get("destination_row", "?")),
		str(cs.get("spirit_joins_battle", "?"))])
	var spirit: Dictionary = _find(ectx, str(cs.get("spirit_id", "")))
	print("spirit is_structure=%s faction=%s is_spirit=%s pos=%s" % [
		str(spirit.get("is_structure", "?")), str(spirit.get("faction", "?")),
		str(spirit.get("is_spirit", "?")), _pos(spirit)])
	_dump(ectx, "start")
	runtime.dispatch({"type": "combat.init"})
	for r in range(20):
		if bool(ectx.combat_state.get("combat_over", false)):
			print("combat_over at round %d outcome=%s" % [r, str(ectx.combat_state.get("outcome", "?"))])
			break
		runtime.dispatch({"type": "combat.confirm_round"})
		var guard: int = 0
		while guard < 40:
			guard += 1
			var c2: Dictionary = ectx.combat_state
			if bool(c2.get("combat_over", false)):
				break
			if str(c2.get("round_phase", "")) != "in_round":
				break
			runtime.dispatch({"type": "combat.next_actor"})
		print("round %d escort_started=%s dest_reached=%s spirit=%s" % [
			r, str(ectx.combat_state.get("escort_started", false)),
			str(ectx.combat_state.get("destination_reached", false)), _pos(spirit)])
	print("RESULT_B over=%s outcome=%s escort_started=%s dest_reached=%s spirit_pos=%s" % [
		str(ectx.combat_state.get("combat_over", false)),
		str(ectx.combat_state.get("outcome", "?")),
		str(ectx.combat_state.get("escort_started", false)),
		str(ectx.combat_state.get("destination_reached", false)),
		_pos(spirit)])


# ── Scenario C: drive the REAL new campaign from boot() to its first encounter ──
func _run_c() -> void:
	print("=== SCENARIO C: real new campaign, auto-driven ===")
	var logger := StructuredLogger.new()
	logger.set_level("info")
	var config := ConfigService.new()
	var slot_path: String = "/tmp/echoes-vnext-tests/diag_c.json"
	for suffix in ["", ".tmp", ".bak1", ".bak2", ".bak3", ".pending_a", ".pending_b"]:
		DirAccess.remove_absolute(slot_path + suffix)
	var runtime := FlowRuntime.new(logger, config, slot_path)
	var snap: Dictionary = runtime.boot()
	var seen: Dictionary = {}
	for step in range(400):
		var stype: String = str(snap.get("type", ""))
		var acts: Dictionary = snap.get("actions", {}) as Dictionary
		if stype == "flow.encounter":
			print("step %d REACHED ENCOUNTER" % step)
			_drive_encounter(runtime, logger)
			return
		# choose an action: prefer primary/cta, never back
		var chosen: Dictionary = {}
		var keys: Array = acts.keys()
		keys.sort()
		for k in keys:
			var av: Variant = acts[k]
			if not (av is Dictionary):
				continue
			var a: Dictionary = av
			if bool(a.get("disabled", false)):
				continue
			var slot: String = str(k)
			if slot == "back" or slot.begins_with("nav."):
				continue
			var at: String = str(a.get("type", ""))
			if at == "flow.go_state" and str(a.get("to", "")) == "flow.main_menu":
				continue
			var sig: String = "%s|%s|%s" % [stype, slot, at]
			if int(seen.get(sig, 0)) > 3:
				continue
			seen[sig] = int(seen.get(sig, 0)) + 1
			chosen = a
			break
		if chosen.is_empty():
			print("step %d state=%s NO ACTION; actions=%s" % [step, stype, str(acts.keys())])
			return
		print("step %d state=%s -> %s" % [step, stype, str(chosen.get("type", ""))])
		snap = runtime.dispatch(chosen)
	print("scenario C: step budget exhausted, state=%s" % str(snap.get("type", "")))


func _drive_encounter(runtime, logger) -> void:
	var ectx = runtime.flow_ctx.encounter_ctx
	if ectx == null:
		print("no encounter ctx")
		return
	print("mode=%s actors=%d" % [str(ectx.resolution_mode), ectx.actors.size()])
	var bw: int = 10
	var bh: int = 10
	if not ectx.terrain.is_empty():
		var b: Dictionary = ectx.terrain.get("bounds", {})
		bw = int(b.get("w", 10))
		bh = int(b.get("h", 10))
	print("board %dx%d" % [bw, bh])
	_dump(ectx, "start")
	runtime.dispatch({"type": "combat.init"})
	var any_move: bool = false
	var any_attack: bool = false
	for r in range(14):
		if bool(ectx.combat_state.get("combat_over", false)):
			print("combat_over at round %d outcome=%s" % [r, str(ectx.combat_state.get("outcome", "?"))])
			break
		runtime.dispatch({"type": "combat.confirm_round"})
		var guard: int = 0
		var acts: Array = []
		while guard < 40:
			guard += 1
			var cs: Dictionary = ectx.combat_state
			if bool(cs.get("combat_over", false)):
				break
			if str(cs.get("round_phase", "")) != "in_round":
				break
			var before: int = ectx.last_round_results.size()
			runtime.dispatch({"type": "combat.next_actor"})
			for i in range(before, ectx.last_round_results.size()):
				var rec: Dictionary = ectx.last_round_results[i]
				acts.append("%s:%s" % [str(rec.get("actor_id", rec.get("id", "?"))), str(rec.get("action_type", rec.get("action", "?")))])
				var at2: String = str(rec.get("action_type", rec.get("action", "")))
				if at2 == "actor.move":
					any_move = true
				if at2 == "melee_attack":
					any_attack = true
		print("round %d: %s" % [r, ", ".join(acts)])
		_dump(ectx, "  pos")
	print("RESULT_C any_move=%s any_attack=%s over=%s" % [any_move, any_attack, str(ectx.combat_state.get("combat_over", false))])

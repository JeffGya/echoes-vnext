# res://tests/ContactBidScalingTests.gd
# V2-DIRECTIVE-002 S4b: contact bids scale by Judgment and fear through ONE bid function.
# Names start with `conversation_repair/` so the filter `tests conversation_repair` runs them.

extends RefCounted
class_name ContactBidScalingTests

const ContactModelScript := preload("res://core/realms/ContactModel.gd")
const SCOUT := "directive.scout_carefully"
const SEEK := "directive.seek_signs"


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("conversation_repair/bid_suppression_weakens_with_judgment", Callable(ContactBidScalingTests, "_t_judgment"))
	runner.register_test("conversation_repair/bid_suppression_weakens_with_fear", Callable(ContactBidScalingTests, "_t_fear"))
	runner.register_test("conversation_repair/bid_boost_refused_when_frightened", Callable(ContactBidScalingTests, "_t_boost"))
	runner.register_test("conversation_repair/bid_seek_unchanged", Callable(ContactBidScalingTests, "_t_seek"))
	runner.register_test("conversation_repair/bid_s4_standing_contrast", Callable(ContactBidScalingTests, "_t_standing"))
	runner.register_test("conversation_repair/bid_snapshot_matches_simulation", Callable(ContactBidScalingTests, "_t_parity"))


static func _fail(msg: String) -> Dictionary:
	return { "ok": false, "error": msg }


static func _cfg() -> ConfigService:
	var cs := ConfigService.new()
	cs.load_balance()
	return cs


static func _fx(cs: ConfigService, directive_id: String) -> Dictionary:
	var entry: Dictionary = ConfigService.get_directives_cfg(cs).get(directive_id, {})
	return entry.get("contact_effects", {})


static func _echo(id: String, calling: String, fear: int, rank: int = 1, storyweight: int = 10) -> Dictionary:
	var e := ConversationRepairTests._make_echo(id, storyweight, storyweight)
	e["calling"] = calling
	e["rank"] = rank
	e["emotion"]["fear_current"] = fear
	return e


# One bid for one Echo. contact role "claimant" aligns with aduro; "witness" aligns with neither
# aduro nor onyamesu.
static func _bid(cs: ConfigService, fx: Dictionary, calling: String, role: String, fear: int, width: float) -> String:
	var echo := _echo("e", calling, fear)
	var bids := ConversationService.compute_bids([echo], { "role": role }, fx, ConfigService.get_contact_bid_cfg(cs), { "e": width })
	return str(bids["e"])


# Shipped numbers: suppression releases when 1 - 1.0*width - 0.6*fear/100 < 0.45.
static func _t_judgment() -> Dictionary:
	var cs := _cfg()
	var fx := _fx(cs, SCOUT)
	var low := _bid(cs, fx, "aduro", "claimant", 10, 0.1)
	var high := _bid(cs, fx, "aduro", "claimant", 10, 0.9)
	if low != "" or high != "alignment":
		return _fail("expected silent at width 0.1 and alignment at width 0.9, got '%s' / '%s'" % [low, high])
	return { "ok": true }


static func _t_fear() -> Dictionary:
	var cs := _cfg()
	var fx := _fx(cs, SCOUT)
	var calm := _bid(cs, fx, "aduro", "claimant", 0, 0.4)
	var uneasy := _bid(cs, fx, "aduro", "claimant", 30, 0.4)
	if calm != "" or uneasy != "alignment":
		return _fail("width 0.4: expected silent at fear 0 and released at fear 30, got '%s' / '%s'" % [calm, uneasy])
	var held := _bid(cs, fx, "aduro", "claimant", 60, 0.0)
	var frightened := _bid(cs, fx, "aduro", "claimant", 60, 0.5)
	if held != "" or frightened != "reactive":
		return _fail("fear 60: expected strong suppression to hold and weak suppression to give reactive, got '%s' / '%s'" % [held, frightened])
	return { "ok": true }


static func _t_boost() -> Dictionary:
	var cs := _cfg()
	var fx := _fx(cs, SCOUT)
	var calm := _bid(cs, fx, "onyamesu", "witness", 0, 0.2)
	var shaken := _bid(cs, fx, "onyamesu", "witness", 50, 0.2)
	var terrified := _bid(cs, fx, "onyamesu", "witness", 60, 0.2)
	if calm != "alignment" or shaken != "" or terrified != "reactive":
		return _fail("boost: expected alignment / refused / reactive, got '%s' / '%s' / '%s'" % [calm, shaken, terrified])
	return { "ok": true }


# Old rule, written out: suppression, reactive, alignment, boost.
static func _old_bid(fx: Dictionary, calling: String, role: String, fear: int) -> String:
	if calling in fx.get("bid_suppression", []):
		return ""
	if fear >= 60:
		return "reactive"
	if ConversationService._is_calling_aligned(calling, role):
		return "alignment"
	if calling in fx.get("bid_boost", []):
		return "alignment"
	return ""


static func _t_seek() -> Dictionary:
	var cs := _cfg()
	var seek_fx := _fx(cs, SEEK)
	if seek_fx.has("bid_suppression") or seek_fx.has("bid_boost"):
		return _fail("Seek Signs now authors a bid list; this test needs an update")
	var party: Array = []
	for i in range(8):
		party.append(_echo("e%d" % i, ["aduro", "okofor", "onyamesu", "okomfo"][i % 4], [0, 20, 59, 60][i % 4] + (i / 4) * 5))
	var widths := { "e0": 0.9, "e1": 0.5, "e2": 0.1, "e3": 0.7 }
	for role in ["claimant", "witness", "charge"]:
		var contact := { "role": role }
		var plain := ConversationService.compute_bids(party, contact, seek_fx)
		var scaled := ConversationService.compute_bids(party, contact, seek_fx, ConfigService.get_contact_bid_cfg(cs), widths)
		if plain != scaled:
			return _fail("Seek bids moved with the bid config: %s vs %s" % [plain, scaled])
		for e: Dictionary in party:
			var want := _old_bid(seek_fx, str(e["calling"]), role, int(e["emotion"]["fear_current"]))
			if str(plain[e["id"]]) != want:
				return _fail("role %s echo %s: old rule '%s', got '%s'" % [role, e["id"], want, plain[e["id"]]])
	# Scout lists with the bid config missing keep today's bids.
	var scout_fx := _fx(cs, SCOUT)
	for e: Dictionary in party:
		var got := str(ConversationService.compute_bids(party, { "role": "claimant" }, scout_fx)[e["id"]])
		var want2 := _old_bid(scout_fx, str(e["calling"]), "claimant", int(e["emotion"]["fear_current"]))
		if got != want2:
			return _fail("Scout without bid config: echo %s old '%s', got '%s'" % [e["id"], want2, got])
	return { "ok": true }


static func _save(party: Array, bonds: Array) -> Dictionary:
	var ids: Array = []
	for e: Dictionary in party:
		ids.append(e["id"])
	return { "sanctum": { "roster": party, "active_party_ids": ids, "bonds": bonds } }


static func _t_standing() -> Dictionary:
	var cs := _cfg()
	var data := ConfigService.get_balance_data(cs)
	var fx := _fx(cs, SCOUT)
	var bid_cfg := ConfigService.get_contact_bid_cfg(cs)
	var party := [
		_echo("lo", "aduro", 10, 1, 10),
		_echo("hi", "aduro", 10, 6, 1000),
		_echo("fr", "okofor", 10, 3, 100),
	]
	var friend_edges: Array = [
		{ "actor_a": "fr", "actor_b": "hi", "strength": 60 },
		{ "actor_a": "fr", "actor_b": "lo", "strength": 60 },
		{ "actor_a": "hi", "actor_b": "lo", "strength": 60 },
	]
	var results: Dictionary = {}
	for label in ["bonded", "unbonded"]:
		var widths := ConversationService.party_widths(_save(party, friend_edges if label == "bonded" else []), data)
		var bids := ConversationService.compute_bids(party, { "role": "claimant" }, fx, bid_cfg, widths)
		results[label] = { "widths": widths, "bids": bids }
	for label in results:
		var r: Dictionary = results[label]
		if str(r["bids"]["lo"]) != "" or str(r["bids"]["hi"]) != "alignment":
			return _fail("%s: Standing 1 should be silent and Standing 6 should bid; widths %s bids %s" % [label, r["widths"], r["bids"]])
	if float(results["bonded"]["widths"]["lo"]) <= float(results["unbonded"]["widths"]["lo"]):
		return _fail("friend bonds did not raise the Standing 1 width: %s vs %s" % [results["bonded"]["widths"], results["unbonded"]["widths"]])
	return { "ok": true }


# Card and simulation for a 2-Echo party, one production engagement per Directive.
static func _card_vs_sim(directive_id: String) -> Dictionary:
	var bak := ConversationRepairTests._capture_save()
	var contact := ContactModelScript.make("contact.bp", "claimant", "courage", "wisdom", 24, 68, "bold", "Nana Adwoa", 2)
	var save := ConversationRepairTests._make_save_with_contact_situation(contact)
	save["stage_context"]["active_directive_id"] = directive_id
	var roster: Array = save["sanctum"]["roster"]
	roster.clear()
	roster.append(_echo("echo.a1", "aduro", 10, 1, 10))
	roster.append(_echo("echo.a2", "aduro", 10, 6, 1000))
	save["sanctum"]["active_party_ids"] = ["echo.a1", "echo.a2"]
	var runtime := ConversationRepairTests._make_runtime(save, ConversationRepairTests._make_logger("off"))
	var snap: Dictionary = runtime.dispatch({ "type": "stage.engage_situation", "situation_id": "sit.t1" })
	ConversationRepairTests._restore_save(bak)
	var sim: Dictionary = {}
	for r_v in FlowStageExploreState._get_current_stage(runtime.flow_ctx).get("explore_map", {}).get("contact_responses", []):
		sim[str(r_v.get("echo_id", ""))] = str(r_v.get("bid_type", ""))
	var card: Dictionary = {}
	for c_v in snap.get("data", {}).get("contact_echo_bids", []):
		card[str(c_v.get("echo_id", ""))] = str(c_v.get("bid_type", ""))
	return { "sim": sim, "card": card }


static func _t_parity() -> Dictionary:
	for pair in [[SCOUT, "echo.a1", ""], [SCOUT, "echo.a2", "alignment"], [SEEK, "echo.a1", "alignment"]]:
		var r := _card_vs_sim(pair[0])
		if r["sim"].size() != 2 or r["card"] != r["sim"]:
			return _fail("%s: card %s differs from simulation %s" % [pair[0], r["card"], r["sim"]])
		if str(r["card"].get(pair[1], "?")) != pair[2]:
			return _fail("%s: %s expected bid '%s', card %s" % [pair[0], pair[1], pair[2], r["card"]])
	return { "ok": true }

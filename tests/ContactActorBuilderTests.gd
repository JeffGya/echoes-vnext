# res://tests/ContactActorBuilderTests.gd
# V2-STAGE-004 Phase 4, S16a — Unit tests for ContactActorBuilder (pure-static;
# no RNG, no OS time, no side effects).
#
# Tests:
#   1. contact_actor/faction_is_echo             — built actor.faction == "echo"
#   2. contact_actor/is_ally_true                — built actor.is_ally == true
#   3. contact_actor/damage_mul_matches_cfg       — actor._ally_damage_mul == cfg damage_mul
#   4. contact_actor/name_from_contact            — actor.name == contact.name
#   5. contact_actor/id_non_empty                 — actor.id is a non-empty string
#   6. contact_actor/structurally_valid_actor      — passes ActorSchema.has_all_required_fields()
#   7. contact_actor/level_scaling_monotonic       — higher level → max_hp does not decrease
#
# Config is loaded from the real data/balance.json (data.contact.ally +
# data.summoning.birth_stats + data.actor.enemy_types) via ConfigService,
# matching the pattern in CallingTests.gd's _load_real_calling_cfg().

extends RefCounted
class_name ContactActorBuilderTests


# ─── Real-config loading ──────────────────────────────────────────────────────

static func _load_balance_data() -> Dictionary:
	var cs := ConfigService.new()
	cs.load_balance()
	var bal := cs.get_balance()
	var data_v: Variant = bal.get("data", {})
	return data_v if data_v is Dictionary else {}


## Returns the cfg dict ContactActorBuilder.build() expects: data.contact.ally
## fields plus an "actor_cfg" sub-dict of { birth_stats, enemy_types }.
static func _build_cfg() -> Dictionary:
	var data := _load_balance_data()

	var contact_v: Variant = data.get("contact", {})
	var contact: Dictionary = contact_v if contact_v is Dictionary else {}
	var ally_v: Variant = contact.get("ally", {})
	var ally_cfg: Dictionary = (ally_v if ally_v is Dictionary else {}).duplicate(true)

	var summoning_v: Variant = data.get("summoning", {})
	var summoning: Dictionary = summoning_v if summoning_v is Dictionary else {}
	var birth_stats_v: Variant = summoning.get("birth_stats", {})
	var birth_stats: Dictionary = birth_stats_v if birth_stats_v is Dictionary else {}

	var actor_v: Variant = data.get("actor", {})
	var actor: Dictionary = actor_v if actor_v is Dictionary else {}
	var enemy_types_v: Variant = actor.get("enemy_types", {})
	var enemy_types: Dictionary = enemy_types_v if enemy_types_v is Dictionary else {}

	ally_cfg["actor_cfg"] = {
		"birth_stats": birth_stats,
		"enemy_types": enemy_types,
	}
	return ally_cfg


static func _make_contact(overrides: Dictionary = {}) -> Dictionary:
	var c: Dictionary = { "id": "contact.ally.builder_test", "name": "Kwame" }
	for k in overrides:
		c[k] = overrides[k]
	return c


# ─── Registration ─────────────────────────────────────────────────────────────

static func register(runner: CoreTestRunner) -> void:
	runner.register_test("contact_actor/faction_is_echo",           Callable(ContactActorBuilderTests, "_t_faction_is_echo"))
	runner.register_test("contact_actor/is_ally_true",               Callable(ContactActorBuilderTests, "_t_is_ally_true"))
	runner.register_test("contact_actor/damage_mul_matches_cfg",     Callable(ContactActorBuilderTests, "_t_damage_mul_matches_cfg"))
	runner.register_test("contact_actor/name_from_contact",          Callable(ContactActorBuilderTests, "_t_name_from_contact"))
	runner.register_test("contact_actor/id_non_empty",               Callable(ContactActorBuilderTests, "_t_id_non_empty"))
	runner.register_test("contact_actor/structurally_valid_actor",   Callable(ContactActorBuilderTests, "_t_structurally_valid_actor"))
	runner.register_test("contact_actor/level_scaling_monotonic",    Callable(ContactActorBuilderTests, "_t_level_scaling_monotonic"))


# ─── Test 1 — faction == "echo" ──────────────────────────────────────────────
static func _t_faction_is_echo() -> Dictionary:
	var cfg := _build_cfg()
	var contact := _make_contact()
	var actor := ContactActorBuilder.build(contact, cfg, 0, 1)

	if str(actor.get("faction", "")) != "echo":
		return { "ok": false, "error": "expected faction 'echo', got '%s'" % str(actor.get("faction", "")) }
	return { "ok": true }


# ─── Test 2 — is_ally == true ─────────────────────────────────────────────────
static func _t_is_ally_true() -> Dictionary:
	var cfg := _build_cfg()
	var contact := _make_contact()
	var actor := ContactActorBuilder.build(contact, cfg, 0, 1)

	if not bool(actor.get("is_ally", false)):
		return { "ok": false, "error": "expected is_ally == true" }
	return { "ok": true }


# ─── Test 3 — _ally_damage_mul present and matches configured mul ───────────
static func _t_damage_mul_matches_cfg() -> Dictionary:
	var cfg := _build_cfg()
	var expected_mul: float = float(cfg.get("damage_mul", 0.75))
	var contact := _make_contact()
	var actor := ContactActorBuilder.build(contact, cfg, 0, 1)

	if not actor.has("_ally_damage_mul"):
		return { "ok": false, "error": "actor missing '_ally_damage_mul' field" }
	var actual_mul: float = float(actor.get("_ally_damage_mul", -1.0))
	if not is_equal_approx(actual_mul, expected_mul):
		return { "ok": false, "error": "expected _ally_damage_mul %f, got %f" % [expected_mul, actual_mul] }
	return { "ok": true }


# ─── Test 4 — name comes from the contact ────────────────────────────────────
static func _t_name_from_contact() -> Dictionary:
	var cfg := _build_cfg()
	var contact := _make_contact({ "name": "Adaeze" })
	var actor := ContactActorBuilder.build(contact, cfg, 0, 1)

	if str(actor.get("name", "")) != "Adaeze":
		return { "ok": false, "error": "expected name 'Adaeze', got '%s'" % str(actor.get("name", "")) }
	return { "ok": true }


# ─── Test 5 — id is a non-empty string ───────────────────────────────────────
static func _t_id_non_empty() -> Dictionary:
	var cfg := _build_cfg()
	var contact := _make_contact()
	var actor := ContactActorBuilder.build(contact, cfg, 0, 1)

	var id_val := str(actor.get("id", ""))
	if id_val.is_empty():
		return { "ok": false, "error": "actor id is empty" }
	return { "ok": true }


# ─── Test 6 — structurally valid actor dict ──────────────────────────────────
static func _t_structurally_valid_actor() -> Dictionary:
	var cfg := _build_cfg()
	var contact := _make_contact()
	var actor := ContactActorBuilder.build(contact, cfg, 0, 1)

	if not ActorSchema.has_all_required_fields(actor):
		return { "ok": false, "error": "ContactActorBuilder.build() output failed ActorSchema.has_all_required_fields()" }
	return { "ok": true }


# ─── Test 7 — level scaling: higher level does not decrease max_hp ──────────
static func _t_level_scaling_monotonic() -> Dictionary:
	var cfg := _build_cfg()
	var contact := _make_contact()

	var actor_lvl1 := ContactActorBuilder.build(contact, cfg, 0, 1)
	var actor_lvl3 := ContactActorBuilder.build(contact, cfg, 0, 3)

	var stats1_v: Variant = actor_lvl1.get("stats", {})
	var stats1: Dictionary = stats1_v if stats1_v is Dictionary else {}
	var stats3_v: Variant = actor_lvl3.get("stats", {})
	var stats3: Dictionary = stats3_v if stats3_v is Dictionary else {}

	var hp1 := int(stats1.get("max_hp", 0))
	var hp3 := int(stats3.get("max_hp", 0))

	if hp3 < hp1:
		return { "ok": false, "error": "level 3 max_hp (%d) is less than level 1 max_hp (%d) — expected monotonic scaling" % [hp3, hp1] }
	return { "ok": true }

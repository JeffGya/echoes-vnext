# res://core/progression/ProgressionService.gd
# PROG-003: XP accrual, level-up detection, and stat recomputation.
# PROG-004: Wisdom/faith virtue multipliers, rank-up eligibility, trait drift execution.
#
# Rules:
# - Pure static service. No RNG, no OS time, no side effects beyond mutating the
#   save_data roster ref that is passed in.
# - Deterministic: same inputs always produce the same outputs.
# - Mutations are performed directly on save_data["sanctum"]["roster"] entries.
#   Callers must set save_request = true after calling award_post_combat_xp() / execute_rank_up().
# - All thresholds and tuning values come from prog_cfg (data.progression in balance.json).
#
# XP sources (PROG-003):
#   kill_xp  = echo.kill_count × xp_kill_bonus
#   clear_xp = xp_stage_clear_base  (if victory, all party echoes)
#   realm_xp = xp_realm_completion_bonus  (if realm_completed, all party echoes)
#   raw_xp   = kill_xp + clear_xp + realm_xp
#   final_xp = round(raw_xp × (1.0 + virtue_multiplier))
#
# Virtue multipliers (PROG-004):
#   courage: melee_share × (courage / 100.0) × virtue_xp_multiplier_max
#   wisdom:  guard_share  × (wisdom  / 100.0) × wisdom_xp_multiplier_max
#   faith:   survived (1.0 or 0.0) × (faith / 100.0) × faith_xp_multiplier_max
#
# Rank-up (PROG-004):
#   Eligible when level == max_level_per_rank.
#   XP carry-over: new_xp_total = max(0, xp_total - level_thresholds[-1])
#   Trait drift: seeded weighted roll from vector_drift_weights[dominant_vector].
#   Seed path: campaign_seed.derive("echo.{id}.rank_up.rank_{new_rank}")
#   Magnitude: ±rank_up_trait_drift_magnitude (default ±1), clamped to [1, 100].
#   calling_eligible set to true when new rank == 3.
#
# Level threshold array (level_thresholds in balance.json):
#   index i = minimum cumulative XP to hold level (i+1)
#   e.g. [0, 100, 250, 450, 700] → level 1 = 0 XP, level 2 = 100 XP, etc.

class_name ProgressionService
extends RefCounted


# ────────────────────────────────────────────────────────────────────────────
# Public API
# ────────────────────────────────────────────────────────────────────────────

## Award post-combat XP to all party echoes that participated in the encounter.
## Mutates save_data["sanctum"]["roster"] directly.
## Returns an Array of XpEvent dicts (one per echo that received XP > 0).
##
## save_data           — FlowContext.save_data (live ref, not a copy)
## echo_action_logs    — EncounterContext.echo_action_logs
## victory             — bool; false → clear_xp not awarded
## realm_completed     — bool; true → realm_completion_bonus added
## prog_cfg            — data.progression dict from balance.json
## birth_stats_cfg     — data.summoning.birth_stats dict (for DerivedStatService)
## logger              — StructuredLogger instance (may be null)
## t                   — sim_tick injected by caller
static func award_post_combat_xp(
	save_data: Dictionary,
	echo_action_logs: Dictionary,
	victory: bool,
	realm_completed: bool,
	prog_cfg: Dictionary,
	birth_stats_cfg: Dictionary,
	logger,
	t: int,
	realm_xp_multiplier: float = 1.0,
	skip_kill_xp: bool = false
) -> Array:
	var xp_events: Array = []

	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return xp_events
	var sanctum: Dictionary = sanctum_v

	var roster_v: Variant = sanctum.get("roster", [])
	if not (roster_v is Array):
		return xp_events
	var roster: Array = roster_v

	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []

	var max_level: int   = int(prog_cfg.get("max_level_per_rank", 5))
	var kill_bonus: int  = int(prog_cfg.get("xp_kill_bonus", 25))
	var clear_base: int  = int(prog_cfg.get("xp_stage_clear_base", 40))
	var realm_bonus: int = int(prog_cfg.get("xp_realm_completion_bonus", 100))
	var virt_max: float  = float(prog_cfg.get("virtue_xp_multiplier_max", 0.20))

	for i in range(roster.size()):
		var echo_v: Variant = roster[i]
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v

		var echo_id: String = str(echo.get("id", ""))

		# Only award XP to echoes that were in the active party.
		if not (echo_id in party_ids):
			continue

		# Use rank-effective thresholds for this echo.
		var echo_rank: int      = int(echo.get("rank", 1))
		var eff_thresholds: Array = get_effective_thresholds(echo_rank, prog_cfg)

		# XP from kills (this echo's kills only).
		# skip_kill_xp = true when kills were already applied mid-combat in FlowRuntime.
		var alog: Dictionary = {}
		if echo_action_logs.has(echo_id):
			var alog_v: Variant = echo_action_logs[echo_id]
			alog = alog_v if alog_v is Dictionary else {}

		var kill_xp: int = 0
		if not skip_kill_xp:
			var kill_count: int = int(alog.get("kill_count", 0))
			kill_xp = kill_count * kill_bonus

		# XP from stage clear (victory only) — scaled by realm_xp_multiplier.
		var clear_xp: int = roundi(float(clear_base) * realm_xp_multiplier) if victory else 0

		# XP from realm completion (victory + final stage) — scaled by realm_xp_multiplier.
		var realm_xp: int = roundi(float(realm_bonus) * realm_xp_multiplier) if (victory and realm_completed) else 0

		var raw_xp: int = kill_xp + clear_xp + realm_xp
		if raw_xp <= 0:
			continue

		# Virtue multiplier (courage/wisdom/faith).
		var traits_v: Variant = echo.get("traits", {})
		var traits: Dictionary = traits_v if traits_v is Dictionary else {}
		var multiplier: float = compute_virtue_multiplier(traits, alog, virt_max, prog_cfg)
		var final_xp: int = int(round(float(raw_xp) * (1.0 + multiplier)))

		# Apply XP and check for level-up using effective thresholds.
		var old_xp: int    = int(echo.get("xp_total", 0))
		var old_level: int = int(echo.get("level", 1))
		var new_xp: int    = old_xp + final_xp
		var new_level: int = mini(get_level_for_xp(new_xp, eff_thresholds), max_level)

		# Mutate roster entry.
		roster[i]["xp_total"] = new_xp
		roster[i]["level"]    = new_level

		# Recompute derived stats on level-up.
		if new_level > old_level:
			var new_stats: Dictionary = DerivedStatService.compute_stats(traits, echo_rank, new_level, birth_stats_cfg)
			roster[i]["stats"] = new_stats
			if logger != null:
				logger.info(t, "progression.level_up",
					"%s levelled up to %d" % [echo.get("name", "?"), new_level],
					{
						"echo_id":   echo_id,
						"old_level": old_level,
						"new_level": new_level,
						"old_xp":    old_xp,
						"new_xp":    new_xp,
					})

		var xp_to_next: int = get_xp_to_next(new_xp, eff_thresholds, max_level)

		xp_events.append({
			"echo_id":             echo_id,
			"echo_name":           str(echo.get("name", "")),
			"storyweight_gained":  final_xp,
			"old_xp":              old_xp,
			"new_xp":              new_xp,
			"old_step":            old_level,
			"new_step":            new_level,
			"stepped_up":          new_level > old_level,
			"storyweight_to_next": xp_to_next,
		})

	return xp_events


# ────────────────────────────────────────────────────────────────────────────
# Pure helpers (no mutations)
# ────────────────────────────────────────────────────────────────────────────

## Returns the level (1-based) that corresponds to the given cumulative XP total.
## thresholds[i] = minimum XP needed to hold level (i+1).
## e.g. thresholds=[0,100,250,450,700]: xp=0→1, xp=99→1, xp=100→2, xp=700→5
static func get_level_for_xp(xp_total: int, thresholds: Array) -> int:
	if thresholds.is_empty():
		return 1
	var level: int = 1
	for i in range(thresholds.size()):
		if xp_total >= int(thresholds[i]):
			level = i + 1
		else:
			break
	return level


## Returns the XP still needed to reach the next level.
## Returns 0 if the echo is already at max_level (capped).
static func get_xp_to_next(xp_total: int, thresholds: Array, max_level: int = 5) -> int:
	var current_level: int = get_level_for_xp(xp_total, thresholds)
	if current_level >= max_level:
		return 0
	# next level threshold index = current_level (0-based: level 2 is at index 1)
	if current_level < thresholds.size():
		return maxi(0, int(thresholds[current_level]) - xp_total)
	return 0


## Computes the virtue-based XP multiplier for a single echo.
## PROG-003: courage (melee_share). PROG-004: wisdom (guard_share) + faith (survived).
## prog_cfg — full data.progression dict (contains all multiplier_max keys).
static func compute_virtue_multiplier(
	traits: Dictionary,
	action_log: Dictionary,
	max_mult: float,
	prog_cfg: Dictionary = {}
) -> float:
	var total: int = int(action_log.get("total_count", 0))
	if total == 0:
		return 0.0

	# ── Courage ──────────────────────────────────────────────────────────
	var melee: int   = int(action_log.get("melee_count", 0))
	var courage: float = float(traits.get("courage", 0)) / 100.0
	var melee_share: float = clampf(float(melee) / float(total), 0.0, 1.0)
	var courage_bonus: float = melee_share * courage * max_mult

	# ── Wisdom (PROG-004) ────────────────────────────────────────────────
	var wisdom_max: float = float(prog_cfg.get("wisdom_xp_multiplier_max", 0.0))
	var wisdom_bonus: float = 0.0
	if wisdom_max > 0.0:
		var guards: int  = int(action_log.get("guard_count", 0))
		var wisdom: float = float(traits.get("wisdom", 0)) / 100.0
		var guard_share: float = clampf(float(guards) / float(total), 0.0, 1.0)
		wisdom_bonus = guard_share * wisdom * wisdom_max

	# ── Faith (PROG-004) ─────────────────────────────────────────────────
	var faith_max: float = float(prog_cfg.get("faith_xp_multiplier_max", 0.0))
	var faith_bonus: float = 0.0
	if faith_max > 0.0:
		var survived: bool = bool(action_log.get("survived", true))
		var faith: float   = float(traits.get("faith", 0)) / 100.0
		faith_bonus = (1.0 if survived else 0.0) * faith * faith_max

	return courage_bonus + wisdom_bonus + faith_bonus


## XP tuning: the realm XP multiplier for `realm_id`, derived from that realm's campaign
## position (`run_index` = how many realms had ever been started when this one was generated).
## Returns 1.0 on every guard failure and whenever the configured rate is <= 0.
##
## V2-INFRA-003 Phase 6 Slice 6F: DEMOTED here from
## ProgressionController.get_realm_xp_multiplier() (itself moved from
## FlowRuntime._get_realm_xp_multiplier in Slice 6b). The body is verbatim; only the inputs
## changed from `flow_ctx.realm_id` / `flow_ctx.save_data` / a fresh
## `config_service.get_balance().data.progression` read to the three explicit parameters below.
##
## WHY IT MOVED. Its only caller is FlowRuntime._resolve_next_actor(), mid-combat, reaching it
## as `_progression_controller().get_realm_xp_multiplier()`. That call is the sole
## controller-to-controller blocker standing between _resolve_next_actor and a future
## CombatController, which AGENTS.md forbids outright ("Controllers must never call one
## another"). Demoting it removes the blocker: a service may be called from anywhere.
##
## WHY HERE rather than a new service or RealmService. AGENTS.md's extraction rule — "Reads save
## data for a domain → a static function on that domain's service." The domain is progression,
## not realms: the tuning key `realm_xp_multiplier_per_realm` is authored under
## `data.progression`, the value produced is an XP multiplier, and its only two consumers are
## the two functions directly below/above in this same file (apply_mid_combat_kill_xp and
## award_post_combat_xp, both of which already take `realm_xp_multiplier` as a parameter).
## `save_data["realms"]` is read only as the lookup for run_index — a field RealmModel already
## publishes. A new service was rejected because a pure, dependency-free read has no state to
## hold, and this file is already the static home of every other XP rule.
##
## realm_id  — FlowContext.realm_id (empty string → 1.0)
## save_data — FlowContext.save_data (live ref, not a copy); read-only here
## prog_cfg  — data.progression dict from balance.json
static func get_realm_xp_multiplier(realm_id: String, save_data: Dictionary, prog_cfg: Dictionary) -> float:
	if realm_id.is_empty():
		return 1.0
	var rate: float = float(prog_cfg.get("realm_xp_multiplier_per_realm", 0.0))
	if rate <= 0.0:
		return 1.0
	var realms_v: Variant = save_data.get("realms", {})
	if not realms_v is Dictionary:
		return 1.0
	var realm_entry_v: Variant = (realms_v as Dictionary).get(realm_id, {})
	if not realm_entry_v is Dictionary:
		return 1.0
	var run_idx: int = int((realm_entry_v as Dictionary).get("run_index", 0))
	return 1.0 + float(run_idx) * rate


# ────────────────────────────────────────────────────────────────────────────
# PROG-004: Rank-up eligibility and execution
# ────────────────────────────────────────────────────────────────────────────

## Returns true when the echo is eligible to rank up.
## Eligible = current level equals max_level_per_rank.
static func is_rank_up_eligible(echo: Dictionary, prog_cfg: Dictionary) -> bool:
	var level: int     = int(echo.get("level", 1))
	var max_level: int = int(prog_cfg.get("max_level_per_rank", 5))
	var rank: int      = int(echo.get("rank", 1))
	var max_rank: int  = 5  # MVP cap
	return level >= max_level and rank < max_rank


## Computes the trait drift that WOULD apply on rank-up — pure, no mutation.
## Returns { trait_key: String, direction: int (+1 or -1), narrative_key: String }
## Returns {} if not eligible or config is missing.
static func compute_trait_drift_preview(
	echo: Dictionary,
	campaign_seed,
	prog_cfg: Dictionary
) -> Dictionary:
	if not is_rank_up_eligible(echo, prog_cfg):
		return {}
	var dominant: String = str(echo.get("dominant_vector", ""))
	var new_rank: int    = int(echo.get("rank", 1)) + 1
	var echo_id: String  = str(echo.get("id", ""))
	return _compute_drift(dominant, new_rank, echo_id, campaign_seed, prog_cfg)


## Executes rank-up: increments rank, resets level, carries XP, applies trait drift,
## sets calling_eligible at rank 3, recomputes derived stats.
## Mutates echo dict in place. Returns a drift event dict for logging/UI.
##
## campaign_seed  — CampaignSeed instance (has derive(path) → int)
## prog_cfg       — data.progression from balance.json
## birth_stats_cfg — data.summoning.birth_stats from balance.json
## calling_cfg    — data.calling from balance.json (optional; pass {} to skip calling_options)
## logger         — StructuredLogger (may be null)
## t              — sim_tick
static func execute_rank_up(
	echo: Dictionary,
	campaign_seed,
	prog_cfg: Dictionary,
	birth_stats_cfg: Dictionary,
	calling_cfg: Dictionary,
	logger,
	t: int
) -> Dictionary:
	var old_rank: int = int(echo.get("rank", 1))
	var echo_id: String  = str(echo.get("id", ""))
	var echo_name: String = str(echo.get("name", "?"))

	# 1. Increment rank.
	var new_rank: int = old_rank + 1
	echo["rank"]     = new_rank
	echo["standing"] = new_rank  # V2-PROG-004: keep V2 bridge field in sync

	# 2. Reset level.
	echo["level"] = 1

	# 3. Carry XP overflow: subtract the last threshold of the OLD rank's effective curve.
	var thresholds: Array  = get_effective_thresholds(old_rank, prog_cfg)
	var max_threshold: int = int(thresholds.back()) if not thresholds.is_empty() else 1000
	var old_xp: int = int(echo.get("xp_total", 0))
	echo["xp_total"] = maxi(0, old_xp - max_threshold)

	# 4. Compute deterministic trait drift using dominant vector.
	var dominant: String = str(echo.get("dominant_vector", ""))
	var drift: Dictionary = _compute_drift(dominant, new_rank, echo_id, campaign_seed, prog_cfg)

	# 5. Apply trait drift.
	var trait_key: String = str(drift.get("trait_key", ""))
	var direction: int    = int(drift.get("direction", 1))
	var magnitude: int    = int(prog_cfg.get("rank_up_trait_drift_magnitude", 1))
	var traits_v: Variant = echo.get("traits", {})
	var traits: Dictionary = traits_v if traits_v is Dictionary else {}
	var old_trait_val: int = int(traits.get(trait_key, 0))
	var new_trait_val: int = clampi(old_trait_val + (direction * magnitude), 1, 100)
	if not trait_key.is_empty():
		traits[trait_key] = new_trait_val
		echo["traits"] = traits

	# 6. Set calling_eligible at rank 3; compute all calling options if cfg provided.
	var calling_eligible: bool = (new_rank == 3)
	if calling_eligible:
		echo["calling_eligible"] = true
		if not calling_cfg.is_empty():
			echo["calling_options"] = CallingService.compute_all_options(echo, calling_cfg)

	# 7. Recompute derived stats with new rank.
	var new_stats: Dictionary = DerivedStatService.compute_stats(traits, new_rank, 1, birth_stats_cfg)
	echo["stats"] = new_stats

	# 8. Log the event.
	var seed_ref: String = "echo.%s.rank_up.rank_%d" % [echo_id, new_rank]
	var event: Dictionary = {
		"echo_id":          echo_id,
		"echo_name":        echo_name,
		"old_standing":     old_rank,
		"new_standing":     new_rank,
		"trait_key":        trait_key,
		"direction":        direction,
		"old_trait_value":  old_trait_val,
		"new_trait_value":  new_trait_val,
		"calling_eligible": calling_eligible,
		"calling_options":  echo.get("calling_options", []),
		"seed_ref":         seed_ref,
		"narrative_key":    str(drift.get("narrative_key", "")),
	}
	if logger != null:
		logger.info(t, "progression.rank_up",
			"%s ascended to Standing %d" % [echo_name, new_rank],
			event)

	return event


# ────────────────────────────────────────────────────────────────────────────
# Private helpers
# ────────────────────────────────────────────────────────────────────────────

static func _get_thresholds(prog_cfg: Dictionary) -> Array:
	var t_v: Variant = prog_cfg.get("level_thresholds", [0, 100, 300, 600, 1000])
	return t_v if t_v is Array else [0, 100, 300, 600, 1000]


## Returns cumulative XP thresholds scaled for the given rank.
## Adds (rank-1) * rank_level_base_shift to each per-level step cost.
## Rank 1 returns base thresholds unchanged. Pure — no side effects.
## Example: rank=2, base=[0,100,300,600,1000], shift=50
##   step costs [100,200,300,400] → shifted [150,250,350,450] → result [0,150,400,750,1200]
static func get_effective_thresholds(rank: int, prog_cfg: Dictionary) -> Array:
	var base: Array    = _get_thresholds(prog_cfg)
	var shift: int     = int(prog_cfg.get("rank_level_base_shift", 0))
	if shift == 0 or rank <= 1 or base.size() < 2:
		return base
	var extra: int     = (rank - 1) * shift
	var result: Array  = [0]
	for i in range(1, base.size()):
		var step_cost: int     = int(base[i]) - int(base[i - 1])
		var shifted_cost: int  = step_cost + extra
		result.append(result.back() + shifted_cost)
	return result


## Applies kill XP immediately to an echo mid-combat.
## Mutates both the save_data roster entry (echo) and the live actor dict.
## Returns a level_up event dict if the echo levelled up, otherwise {}.
## Called from FlowRuntime._resolve_next_actor() after each kill.
static func apply_mid_combat_kill_xp(
	echo: Dictionary,
	actor: Dictionary,
	prog_cfg: Dictionary,
	birth_stats_cfg: Dictionary,
	realm_xp_multiplier: float,
	logger,
	t: int
) -> Dictionary:
	var kill_bonus: int  = int(prog_cfg.get("xp_kill_bonus", 25))
	var max_level: int   = int(prog_cfg.get("max_level_per_rank", 5))
	var kill_xp: int     = roundi(float(kill_bonus) * realm_xp_multiplier)
	if kill_xp <= 0:
		return {}

	var echo_rank: int        = int(echo.get("rank", 1))
	var eff_thresholds: Array = get_effective_thresholds(echo_rank, prog_cfg)
	var old_xp: int           = int(echo.get("xp_total", 0))
	var old_level: int        = int(echo.get("level", 1))
	var new_xp: int           = old_xp + kill_xp
	var new_level: int        = mini(get_level_for_xp(new_xp, eff_thresholds), max_level)

	echo["xp_total"] = new_xp

	if new_level <= old_level:
		return {}

	# Level-up — mutate save_data echo and sync live actor stats.
	echo["level"] = new_level
	var traits_v: Variant      = echo.get("traits", {})
	var traits: Dictionary     = traits_v if traits_v is Dictionary else {}
	var new_stats: Dictionary  = DerivedStatService.compute_stats(traits, echo_rank, new_level, birth_stats_cfg)
	echo["stats"] = new_stats

	# Sync live actor — top-level stat fields.
	var old_max_hp: int = int(actor.get("max_hp", 0))
	for stat_key in ["atk", "def", "agi", "int", "cha", "speed", "max_hp"]:
		if new_stats.has(stat_key):
			actor[stat_key] = new_stats[stat_key]

	# Partial heal: give the HP increase from max_hp bump.
	var new_max_hp: int  = int(new_stats.get("max_hp", old_max_hp))
	var hp_gained: int   = maxi(0, new_max_hp - old_max_hp)
	if hp_gained > 0:
		var cur_hp: int = int(actor.get("current_hp", old_max_hp))
		actor["current_hp"] = mini(cur_hp + hp_gained, new_max_hp)

	var echo_id: String   = str(echo.get("id", ""))
	var echo_name: String = str(echo.get("name", "?"))
	var event: Dictionary = {
		"echo_id":   echo_id,
		"echo_name": echo_name,
		"old_step":  old_level,
		"new_step":  new_level,
		"old_xp":    old_xp,
		"new_xp":    new_xp,
		"kill_xp":   kill_xp,
	}
	if logger != null:
		logger.info(t, "progression.level_up",
			"%s levelled up to Step %d (mid-combat)" % [echo_name, new_level],
			event)
	return event


## Pure helper: derives a deterministic trait drift from the echo's dominant vector.
## Uses CampaignSeed.derive(path) → int to seed a local RNG.
## Returns { trait_key, direction, narrative_key } or {} on failure.
static func _compute_drift(
	dominant_vector: String,
	new_rank: int,
	echo_id: String,
	campaign_seed,
	prog_cfg: Dictionary
) -> Dictionary:
	# Look up the drift weight table for this vector.
	var weights_v: Variant = prog_cfg.get("vector_drift_weights", {})
	if not (weights_v is Dictionary):
		return {}
	var weights_map: Dictionary = weights_v
	if not weights_map.has(dominant_vector):
		# Fallback: equal weights across all three traits.
		weights_map = { dominant_vector: { "courage": 0.34, "wisdom": 0.33, "faith": 0.33 } }

	var trait_weights_v: Variant = weights_map.get(dominant_vector, {})
	if not (trait_weights_v is Dictionary) or trait_weights_v.is_empty():
		return {}
	var trait_weights: Dictionary = trait_weights_v

	# Seed a local RNG deterministically.
	var seed_path: String = "echo.%s.rank_up.rank_%d" % [echo_id, new_rank]
	var seed_val: int = campaign_seed.derive(seed_path)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Weighted trait selection: roll [0, 1) and pick trait by cumulative weight.
	var trait_key: String = ""
	var roll: float = rng.randf()
	var cumulative: float = 0.0
	for tk in trait_weights:
		cumulative += float(trait_weights[tk])
		if roll < cumulative:
			trait_key = str(tk)
			break
	# Fallback to last key if floating-point rounding leaves us without a match.
	if trait_key.is_empty() and not trait_weights.is_empty():
		trait_key = str(trait_weights.keys().back())

	# Direction: +1 or -1 via second seeded roll.
	var direction: int = 1 if rng.randi() % 2 == 0 else -1

	# Narrative key: e.g. "courage_positive", "wisdom_negative"
	var dir_label: String = "positive" if direction > 0 else "negative"
	var narrative_key: String = "%s_%s" % [trait_key, dir_label]

	return {
		"trait_key":     trait_key,
		"direction":     direction,
		"narrative_key": narrative_key,
	}

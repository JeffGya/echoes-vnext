# res://core/progression/ProgressionService.gd
# PROG-003: XP accrual, level-up detection, and stat recomputation.
#
# Rules:
# - Pure static service. No RNG, no OS time, no side effects beyond mutating the
#   save_data roster ref that is passed in.
# - Deterministic: same inputs always produce the same outputs.
# - Mutations are performed directly on save_data["sanctum"]["roster"] entries.
#   Callers must set save_request = true after calling award_post_combat_xp().
# - All thresholds and tuning values come from prog_cfg (data.progression in balance.json).
#
# XP sources (PROG-003):
#   kill_xp  = echo.kill_count × xp_kill_bonus
#   clear_xp = xp_stage_clear_base  (if victory, all party echoes)
#   realm_xp = xp_realm_completion_bonus  (if realm_completed, all party echoes)
#   raw_xp   = kill_xp + clear_xp + realm_xp
#   final_xp = round(raw_xp × (1.0 + virtue_multiplier))
#
# Virtue multiplier (courage, PROG-003):
#   melee_share = (melee_count + kill_count) / max(total_count, 1)
#   multiplier  = melee_share × (traits.courage / 100.0) × virtue_xp_multiplier_max
#
# Level threshold array (level_thresholds in balance.json):
#   index i = minimum cumulative XP to hold level (i+1)
#   e.g. [0, 100, 250, 450, 700] → level 1 = 0 XP, level 2 = 100 XP, etc.
#
# Deferred to PROG-004: wisdom/faith virtue multipliers, rank-up, deeper vector feedback.

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
	t: int
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

	var thresholds: Array = _get_thresholds(prog_cfg)
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

		# XP from kills (this echo's kills only).
		var alog: Dictionary = {}
		if echo_action_logs.has(echo_id):
			var alog_v: Variant = echo_action_logs[echo_id]
			alog = alog_v if alog_v is Dictionary else {}

		var kill_count: int  = int(alog.get("kill_count", 0))
		var kill_xp: int     = kill_count * kill_bonus

		# XP from stage clear (victory only).
		var clear_xp: int = clear_base if victory else 0

		# XP from realm completion (victory + final stage).
		var realm_xp: int = realm_bonus if (victory and realm_completed) else 0

		var raw_xp: int = kill_xp + clear_xp + realm_xp
		if raw_xp <= 0:
			continue

		# Virtue multiplier (courage, PROG-003 only).
		var traits_v: Variant = echo.get("traits", {})
		var traits: Dictionary = traits_v if traits_v is Dictionary else {}
		var multiplier: float = compute_virtue_multiplier(traits, alog, virt_max)
		var final_xp: int = int(round(float(raw_xp) * (1.0 + multiplier)))

		# Apply XP and check for level-up.
		var old_xp: int    = int(echo.get("xp_total", 0))
		var old_level: int = int(echo.get("level", 1))
		var new_xp: int    = old_xp + final_xp
		var new_level: int = mini(get_level_for_xp(new_xp, thresholds), max_level)

		# Mutate roster entry.
		roster[i]["xp_total"] = new_xp
		roster[i]["level"]    = new_level

		# Recompute derived stats on level-up.
		if new_level > old_level:
			var rank: int = int(echo.get("rank", 1))
			var new_stats: Dictionary = DerivedStatService.compute_stats(traits, rank, new_level, birth_stats_cfg)
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

		var xp_to_next: int = get_xp_to_next(new_xp, thresholds, max_level)

		xp_events.append({
			"echo_id":    echo_id,
			"echo_name":  str(echo.get("name", "")),
			"xp_gained":  final_xp,
			"old_xp":     old_xp,
			"new_xp":     new_xp,
			"old_level":  old_level,
			"new_level":  new_level,
			"leveled_up": new_level > old_level,
			"xp_to_next": xp_to_next,
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
## MVP: courage only. melee_share drives the bonus.
## max_mult — from balance.json virtue_xp_multiplier_max (e.g. 0.20 = +20% max)
static func compute_virtue_multiplier(
	traits: Dictionary,
	action_log: Dictionary,
	max_mult: float
) -> float:
	var total: int  = int(action_log.get("total_count", 0))
	if total == 0:
		return 0.0

	var melee: int  = int(action_log.get("melee_count", 0))
	var kills: int  = int(action_log.get("kill_count", 0))
	var courage: float = float(traits.get("courage", 0)) / 100.0

	# melee_share: fraction of total actions that were aggressive (melee + kills counted once)
	var melee_share: float = clampf(float(melee) / float(total), 0.0, 1.0)

	# Multiplier scales with both how aggressively the echo fought AND their courage trait.
	return melee_share * courage * max_mult


# ────────────────────────────────────────────────────────────────────────────
# Private helpers
# ────────────────────────────────────────────────────────────────────────────

static func _get_thresholds(prog_cfg: Dictionary) -> Array:
	var t_v: Variant = prog_cfg.get("level_thresholds", [0, 100, 250, 450, 700])
	return t_v if t_v is Array else [0, 100, 250, 450, 700]

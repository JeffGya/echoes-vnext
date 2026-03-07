# res://core/actors/DerivedStatService.gd
# Pure static utility — computes the 6 base combat stats from traits, rank, and level.
#
# Contract:
# - No RNG, no OS time, no side effects.
# - Called by EchoFactory at birth (rank=1, level=1).
# - Called by progression handlers (PROG-003+) on level-up and rank-up.
# - EchoActor.from_echo() does NOT call this — it reads echo.stats as saved.
#
# Rank / Level offset design:
#   Growth terms use (rank - 1) and (level - 1) so that at birth (rank=1, level=1)
#   both offsets are 0. This means existing saved stats are already consistent with
#   the new formula — no migration or repair needed for existing echoes.
#
# Formula (multi-trait — same trait inputs as previous EchoFactory formula):
#   max_hp = round(hp_base + courage*hp_courage_mul + faith*hp_faith_mul
#                  + (rank-1)*hp_per_rank + (level-1)*hp_per_level),  min hp_min
#   atk    = round(atk_base + courage*atk_courage_mul + faith*atk_faith_mul
#                  + (rank-1)*atk_per_rank + (level-1)*atk_per_level),  min 1
#   def    = round(def_base + wisdom*def_wisdom_mul + faith*def_faith_mul
#                  + (rank-1)*def_per_rank + (level-1)*def_per_level),  min 0
#   agi    = round(agi_base + wisdom*agi_wisdom_mul + courage*agi_courage_mul
#                  + (rank-1)*agi_per_rank + (level-1)*agi_per_level),  min 0
#   int    = round(int_base + wisdom*int_wisdom_mul + courage*int_courage_mul
#                  + (rank-1)*int_per_rank + (level-1)*int_per_level),  min 0
#   cha    = round(cha_base + faith*cha_faith_mul + wisdom*cha_wisdom_mul
#                  + (rank-1)*cha_per_rank + (level-1)*cha_per_level),  min 0
#
# stat_cfg keys live under data.summoning.birth_stats in balance.json.
# All keys fall back to safe defaults — {} never crashes.

class_name DerivedStatService
extends RefCounted

## Computes the 6 base combat stats from traits, rank, level, and config.
##
## traits   — { "courage": int, "wisdom": int, "faith": int }
## rank     — int (1–10); must be >= 1
## level    — int (>= 1)
## stat_cfg — birth_stats config dict from balance.json (data.summoning.birth_stats)
##
## Returns: { "max_hp": int, "atk": int, "def": int, "agi": int, "int": int, "cha": int }
static func compute_stats(
	traits:   Dictionary,
	rank:     int,
	level:    int,
	stat_cfg: Dictionary
) -> Dictionary:
	var courage: int = int(traits.get("courage", 0))
	var wisdom:  int = int(traits.get("wisdom",  0))
	var faith:   int = int(traits.get("faith",   0))

	# (rank-1) and (level-1) are 0 at birth — no delta added, backward compat preserved.
	var rank_bonus:  int = max(0, rank  - 1)
	var level_bonus: int = max(0, level - 1)

	# ---- max_hp ----
	var hp_base:        float = float(stat_cfg.get("hp_base",        100))
	var hp_courage_mul: float = float(stat_cfg.get("hp_courage_mul", 0.25))
	var hp_faith_mul:   float = float(stat_cfg.get("hp_faith_mul",   0.15))
	var hp_per_rank:    float = float(stat_cfg.get("hp_per_rank",    10))
	var hp_per_level:   float = float(stat_cfg.get("hp_per_level",   5))
	var hp_min:         int   = int(stat_cfg.get("hp_min",           15))

	var max_hp: int = int(round(
		hp_base
		+ hp_courage_mul * float(courage)
		+ hp_faith_mul   * float(faith)
		+ hp_per_rank    * float(rank_bonus)
		+ hp_per_level   * float(level_bonus)
	))
	if max_hp < hp_min:
		max_hp = hp_min

	# ---- atk ----
	var atk_base:        float = float(stat_cfg.get("atk_base",        4))
	var atk_courage_mul: float = float(stat_cfg.get("atk_courage_mul", 0.12))
	var atk_faith_mul:   float = float(stat_cfg.get("atk_faith_mul",   0.05))
	var atk_per_rank:    float = float(stat_cfg.get("atk_per_rank",    2))
	var atk_per_level:   float = float(stat_cfg.get("atk_per_level",   1))

	var atk: int = int(round(
		atk_base
		+ atk_courage_mul * float(courage)
		+ atk_faith_mul   * float(faith)
		+ atk_per_rank    * float(rank_bonus)
		+ atk_per_level   * float(level_bonus)
	))
	if atk < 1:
		atk = 1

	# ---- def ----
	var def_base:       float = float(stat_cfg.get("def_base",        2))
	var def_wisdom_mul: float = float(stat_cfg.get("def_wisdom_mul",  0.12))
	var def_faith_mul:  float = float(stat_cfg.get("def_faith_mul",   0.08))
	var def_per_rank:   float = float(stat_cfg.get("def_per_rank",    1))
	var def_per_level:  float = float(stat_cfg.get("def_per_level",   0))

	var def_v: int = int(round(
		def_base
		+ def_wisdom_mul * float(wisdom)
		+ def_faith_mul  * float(faith)
		+ def_per_rank   * float(rank_bonus)
		+ def_per_level  * float(level_bonus)
	))
	if def_v < 0:
		def_v = 0

	# ---- agi ----
	var agi_base:        float = float(stat_cfg.get("agi_base",        2))
	var agi_wisdom_mul:  float = float(stat_cfg.get("agi_wisdom_mul",  0.08))
	var agi_courage_mul: float = float(stat_cfg.get("agi_courage_mul", 0.08))
	var agi_per_rank:    float = float(stat_cfg.get("agi_per_rank",    1))
	var agi_per_level:   float = float(stat_cfg.get("agi_per_level",   0))

	var agi: int = int(round(
		agi_base
		+ agi_wisdom_mul  * float(wisdom)
		+ agi_courage_mul * float(courage)
		+ agi_per_rank    * float(rank_bonus)
		+ agi_per_level   * float(level_bonus)
	))
	if agi < 0:
		agi = 0

	# ---- int ----
	var int_base:        float = float(stat_cfg.get("int_base",        4))
	var int_wisdom_mul:  float = float(stat_cfg.get("int_wisdom_mul",  0.22))
	var int_courage_mul: float = float(stat_cfg.get("int_courage_mul", 0.04))
	var int_per_rank:    float = float(stat_cfg.get("int_per_rank",    1))
	var int_per_level:   float = float(stat_cfg.get("int_per_level",   1))

	var intel: int = int(round(
		int_base
		+ int_wisdom_mul  * float(wisdom)
		+ int_courage_mul * float(courage)
		+ int_per_rank    * float(rank_bonus)
		+ int_per_level   * float(level_bonus)
	))
	if intel < 0:
		intel = 0

	# ---- cha ----
	var cha_base:       float = float(stat_cfg.get("cha_base",        1))
	var cha_faith_mul:  float = float(stat_cfg.get("cha_faith_mul",   0.08))
	var cha_wisdom_mul: float = float(stat_cfg.get("cha_wisdom_mul",  0.08))
	var cha_per_rank:   float = float(stat_cfg.get("cha_per_rank",    1))
	var cha_per_level:  float = float(stat_cfg.get("cha_per_level",   0))

	var cha: int = int(round(
		cha_base
		+ cha_faith_mul  * float(faith)
		+ cha_wisdom_mul * float(wisdom)
		+ cha_per_rank   * float(rank_bonus)
		+ cha_per_level  * float(level_bonus)
	))
	if cha < 0:
		cha = 0

	return {
		"max_hp": max_hp,
		"atk":    atk,
		"def":    def_v,
		"agi":    agi,
		"int":    intel,
		"cha":    cha,
	}

# SummonService.gd

extends RefCounted

class_name SummonService

const GRADES: Array[String] = ["uncalled", "called", "chosen"]
## The batch cap of one sanctum.summon action. The summon snapshot lists prices up to this count.
const MAX_BATCH := 10

## The one place that counts the village. Permadeath changes only this function.
static func living_count(save_data: Dictionary) -> int:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return 0
	var roster_v: Variant = (sanctum_v as Dictionary).get("roster", [])
	return (roster_v as Array).size() if roster_v is Array else 0


## The price of the Echo with number echo_number (living count + 1 when bought). The only price
## function: the handler, the grade select and the summon snapshot all call it.
## price_by_echo_number holds string keys; a number above village_ceiling pays the ceiling price.
static func price_for(summoning_cfg: Dictionary, grade: String, echo_number: int) -> int:
	var table_v: Variant = summoning_cfg.get("price_by_echo_number", {})
	var table: Dictionary = table_v if table_v is Dictionary else {}
	var n := mini(echo_number, village_ceiling(summoning_cfg))
	if table.is_empty():
		push_error("SummonService: data.summoning.price_by_echo_number is empty")
		return 0
	# Echo 1 is the free starter and has no entry: a number below the first entry pays the first price.
	var best_key := -1
	var low_key := 1 << 30
	var base := 0
	var low_base := 0
	for k: Variant in table.keys():
		var key_n := int(str(k))
		if key_n <= n and key_n > best_key:
			best_key = key_n
			base = int(table[k])
		if key_n < low_key:
			low_key = key_n
			low_base = int(table[k])
	if best_key < 0:
		base = low_base
	if grade == "uncalled":
		return base
	return base + int(summoning_cfg.get("%s_extra" % grade, 0))


static func village_ceiling(summoning_cfg: Dictionary) -> int:
	return int(summoning_cfg.get("village_ceiling", 14))


## Prices of summon 1..count in one action: summon i pays for Echo (living + i + 1).
static func batch_prices(summoning_cfg: Dictionary, grade: String, living: int, count: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(count):
		out.append(price_for(summoning_cfg, grade, living + i + 1))
	return out

static func summon_paid_one(
	save_data: Dictionary,
	seed_root: String,
	summoning_cfg: Dictionary,
	logger: StructuredLogger,
	t: int,
	expression_cfg: Dictionary = {}
) -> Dictionary:
	# Returns:
	# { ok: bool, reason: String, echo_id: String, echo: Dictionary }
	
	# Ensure sanctum dict
	if not save_data.has("sanctum") or typeof(save_data["sanctum"]) != TYPE_DICTIONARY:
		save_data["sanctum"] = {}
	var sanctum: Dictionary = save_data["sanctum"]
	
	# Ensure roster
	if not sanctum.has("roster") or typeof(sanctum["roster"]) != TYPE_ARRAY:
		sanctum["roster"] = []
	var roster: Array = sanctum["roster"] as Array
	
	# Ensure summon_count
	var summon_count := int(sanctum.get("summon_count", 0))
	
	# Seed path uses current count (then we increment)
	var seed_path := "campaign.summon.%d" % summon_count
	
	# Generate echo (id assigned by caller/service, not factory)
	var echo: Dictionary = EchoFactory.generate(seed_root, seed_path, summon_count, "summon", summoning_cfg, expression_cfg)
	
	var echo_id := "echo_%04d" % (roster.size() + 1)
	echo["id"] = echo_id
	
	# Persist
	roster.append(echo)
	sanctum["summon_count"] = summon_count + 1
	
	logger.info(t, "sanctum.summon.success", "Echo summoned", {
		"echo_id": echo_id,
		"seed_path": seed_path,
		"summon_index": summon_count,
		"roster_count_after": roster.size()
	})
	# actor.stats_init removed (EMOTION-001) — superseded by emotion.init in FlowRuntime
	
	return {
		"ok": true,
		"reason": "",
		"echo_id": echo_id,
		"echo": echo
	}
	
static func summon_paid_many(
	save_data: Dictionary,
	seed_root: String,
	summoning_cfg: Dictionary,
	count: int,
	logger: StructuredLogger,
	t: int,
	expression_cfg: Dictionary = {}
) -> Dictionary:
	# Returns:
	# { ok: bool, reason: String, echoes: Array, echo_ids: Array }

	if count <= 0:
		return { "ok": false, "reason": "count<=0", "echoes": [], "echo_ids": [] }

	# Ensure sanctum dict
	if not save_data.has("sanctum") or typeof(save_data["sanctum"]) != TYPE_DICTIONARY:
		save_data["sanctum"] = {}
	var sanctum: Dictionary = save_data["sanctum"]

	# Ensure roster
	if not sanctum.has("roster") or typeof(sanctum["roster"]) != TYPE_ARRAY:
		sanctum["roster"] = []
	var roster: Array = sanctum["roster"] as Array

	# Ensure summon_count
	var summon_count := int(sanctum.get("summon_count", 0))

	var out_echoes: Array = []
	var out_ids: Array = []

	for i in range(count):
		var idx := summon_count + i
		var seed_path := "campaign.summon.%d" % idx

		var echo: Dictionary = EchoFactory.generate(seed_root, seed_path, idx, "summon", summoning_cfg, expression_cfg)

		var echo_id := "echo_%04d" % (roster.size() + 1)
		echo["id"] = echo_id

		roster.append(echo)
		out_echoes.append(echo)
		out_ids.append(echo_id)
		# actor.stats_init removed (EMOTION-001) — superseded by emotion.init in FlowRuntime

	# increment once at the end (important: stable monotonic)
	sanctum["summon_count"] = summon_count + count

	logger.info(t, "sanctum.summon.success", "Echoes summoned", {
		"count": count,
		"summon_index_from": summon_count,
		"summon_index_to": summon_count + count - 1,
		"roster_count_after": roster.size()
	})

	return { "ok": true, "reason": "", "echoes": out_echoes, "echo_ids": out_ids }

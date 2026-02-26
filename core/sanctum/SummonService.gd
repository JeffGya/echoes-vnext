# SummonService.gd

extends RefCounted

class_name SummonService

static func summon_paid_one(
	save_data: Dictionary,
	seed_root: String,
	summoning_cfg: Dictionary,
	logger: StructuredLogger,
	t: int
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
	
	# Generate echo (id assigned by caller/servicem not factory)
	var echo: Dictionary= EchoFactory.generate(seed_root, seed_path, summon_count, "summon", summoning_cfg)
	
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
	t: int
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

		var echo: Dictionary = EchoFactory.generate(seed_root, seed_path, idx, "summon", summoning_cfg)

		var echo_id := "echo_%04d" % (roster.size() + 1)
		echo["id"] = echo_id

		roster.append(echo)
		out_echoes.append(echo)
		out_ids.append(echo_id)

	# increment once at the end (important: stable monotonic)
	sanctum["summon_count"] = summon_count + count

	logger.info(t, "sanctum.summon.success", "Echoes summoned", {
		"count": count,
		"summon_index_from": summon_count,
		"summon_index_to": summon_count + count - 1,
		"roster_count_after": roster.size()
	})

	return { "ok": true, "reason": "", "echoes": out_echoes, "echo_ids": out_ids }

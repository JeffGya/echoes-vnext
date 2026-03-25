class_name RealmService

extends RefCounted

# REALM-001: Single choke point for realm creation and access.
# All realm mutations go through this service — mirrors EconomyService style.
# Realm models are stored in save_data["realms"] keyed by realm_id.


# Get or create a RealmModel for the given realm_id.
#
# Three cases:
#   1. Not yet in save_data     → first ever selection; create fresh model (run_count=0)
#   2. Status "active"          → player returning; return cached model unchanged
#   3. Status "completed"       → re-run; create fresh model with incremented run_count
#
# Sets save_request on ctx in all creation cases.
static func get_or_create(realm_id: String, ctx: FlowContext, t: int) -> Dictionary:
	# Ensure realms dict exists
	if not ctx.save_data.has("realms") or typeof(ctx.save_data["realms"]) != TYPE_DICTIONARY:
		ctx.save_data["realms"] = {}

	var save_realms: Dictionary = ctx.save_data["realms"]

	# Case 2: already active — return cached
	if save_realms.has(realm_id):
		var existing_v: Variant = save_realms[realm_id]
		var existing: Dictionary = existing_v if existing_v is Dictionary else {}
		if existing.get("status", "") == RealmModel.STATUS_ACTIVE:
			return existing

	# Load realm config
	var realms_cfg: Dictionary = ctx.config_service.get_realms()
	var data_v: Variant = realms_cfg.get("data", {})
	var data: Dictionary = data_v if data_v is Dictionary else {}
	var realms_v: Variant = data.get("realms", {})
	var realms_map: Dictionary = realms_v if realms_v is Dictionary else {}

	if not realms_map.has(realm_id):
		ctx.logger.warn(t, "realm.create.fail", "Realm id not found in config", { "realm_id": realm_id })
		return {}

	var cfg_v: Variant = realms_map[realm_id]
	var cfg: Dictionary = cfg_v if cfg_v is Dictionary else {}

	var seed_namespace := str(cfg.get("seed_namespace", "campaign.realm." + realm_id))
	var stage_min   := int(cfg.get("stage_count_min", 3))
	var stage_max   := int(cfg.get("stage_count_max", 5))
	var obj_min     := int(cfg.get("obj_count_min", 1))
	var obj_max     := int(cfg.get("obj_count_max", 2))

	# Determine run_count (0 for new, old+1 for re-run)
	var run_count := 0
	if save_realms.has(realm_id):
		var old_v: Variant = save_realms[realm_id]
		var old: Dictionary = old_v if old_v is Dictionary else {}
		run_count = int(old.get("run_count", 0)) + 1

	# Derive deterministic realm seed (unique per run_count)
	var seed_path := seed_namespace + ".run." + str(run_count)
	var realm_seed: int = ctx.campaign_seed.derive(seed_path)

	# Pick stage_count deterministically from range
	var stage_rng := CampaignSeed.get_rng_from(realm_seed, "stage_count")
	var stage_count := stage_rng.randi_range(stage_min, stage_max)

	# Compute run_index: how many realms have ever been started (not_started excluded)
	var run_index := _count_started_realms(save_realms)

	# Build model
	var model := RealmModel.make(
		realm_id,
		str(cfg.get("name", realm_id)),
		str(cfg.get("virtue", "")),
		str(cfg.get("description", "")),
		realm_seed,
		stage_count,
		run_index,
		run_count
	)

	# Generate deterministic stages and wire them into the model
	var stages := RealmGenerator.generate(realm_seed, stage_count, obj_min, obj_max)
	model["stages"] = stages

	# Store in save_data
	ctx.save_data["realms"][realm_id] = model

	# Log creation — includes full stage_types + stage_seeds for run reconstruction
	ctx.logger.info(t, "realm.created", "Realm model created", {
		"realm_id":    realm_id,
		"virtue":      model["virtue"],
		"seed":        realm_seed,
		"stage_count": stage_count,
		"run_index":   run_index,
		"run_count":   run_count,
		"stage_types": stages.map(func(s: Dictionary) -> String: return str(s.get("type", ""))),
		"stage_seeds": stages.map(func(s: Dictionary) -> int:    return int(s.get("seed", 0))),
	})

	# Trigger save flush
	ctx.save_request = true
	if ctx.save_request_reason.is_empty():
		ctx.save_request_reason = "realm_create"
	else:
		ctx.save_request_reason += "|realm_create"

	return model


# Returns the active realm model (the one with status "active"), or {}.
static func get_active(ctx: FlowContext) -> Dictionary:
	var realms_v: Variant = ctx.save_data.get("realms", {})
	var realms: Dictionary = realms_v if realms_v is Dictionary else {}
	var model_v: Variant = realms.get(ctx.realm_id, {})
	return model_v if model_v is Dictionary else {}


# Compute per-realm locked status for the realm select snapshot.
#
# Returns a Dictionary keyed by realm_id → bool is_locked.
# Lock rule: if any realm has status "active", all "not_started" realms are locked.
# Config-level locked:true is a hard lock regardless of runtime state.
#
# realm_cfg_list: Array of realm config dicts (each has "id", "locked" etc.)
# save_realms:    save_data["realms"] dict
static func compute_runtime_locks(realm_cfg_list: Array, save_realms: Dictionary) -> Dictionary:
	# Check if any realm is currently active
	var any_active := false
	for rid in save_realms:
		var rm_v: Variant = save_realms[rid]
		var rm: Dictionary = rm_v if rm_v is Dictionary else {}
		if rm.get("status", "") == RealmModel.STATUS_ACTIVE:
			any_active = true
			break

	var locks: Dictionary = {}
	for cfg_v in realm_cfg_list:
		var cfg: Dictionary = cfg_v if cfg_v is Dictionary else {}
		var rid := str(cfg.get("id", ""))
		if rid.is_empty():
			continue

		# Hard lock from config
		if cfg.get("locked", false):
			locks[rid] = true
			continue

		# Runtime lock: not_started while another is active
		var saved_v: Variant = save_realms.get(rid, {})
		var saved: Dictionary = saved_v if saved_v is Dictionary else {}
		var status := str(saved.get("status", RealmModel.STATUS_NOT_STARTED))

		if any_active and status == RealmModel.STATUS_NOT_STARTED:
			locks[rid] = true
		else:
			locks[rid] = false

	return locks


# REALM-004: Increment current_stage_index for the active realm.
#
# On success:  returns the mutated model dict.
# On complete: marks realm is_completed=true, status="completed".
# Guards:      returns {} if no active model; skips if already completed (idempotent).
# Always:      sets save_request = true on any mutation.
static func advance_stage(ctx: FlowContext, t: int) -> Dictionary:
	var model := get_active(ctx)
	if model.is_empty():
		ctx.logger.warn(t, "realm.stage.advance.fail", "advance_stage called but no active realm found", {
			"realm_id": ctx.realm_id,
		})
		return {}

	# Idempotency guard — already completed
	if bool(model.get("is_completed", false)):
		ctx.logger.warn(t, "realm.stage.advance.skip", "Realm already completed — skipping advance", {
			"realm_id": ctx.realm_id,
		})
		return model

	var current_index := int(model.get("current_stage_index", 0))
	var stage_count   := int(model.get("stage_count", 1))
	var new_index     := current_index + 1

	# Write incremented index
	ctx.save_data["realms"][ctx.realm_id]["current_stage_index"] = new_index

	var stages_remaining := stage_count - new_index

	# Realm complete?
	if new_index >= stage_count:
		ctx.save_data["realms"][ctx.realm_id]["is_completed"] = true
		ctx.save_data["realms"][ctx.realm_id]["status"]       = RealmModel.STATUS_COMPLETED
		ctx.logger.info(t, "realm.complete", "Realm marked complete", {
			"realm_id":    ctx.realm_id,
			"stage_count": stage_count,
		})

	# Always log the advance
	ctx.logger.info(t, "realm.stage.advanced", "Stage index advanced", {
		"realm_id":        ctx.realm_id,
		"new_index":       new_index,
		"stages_remaining": stages_remaining,
	})

	# Trigger save flush
	ctx.save_request = true
	if ctx.save_request_reason.is_empty():
		ctx.save_request_reason = "realm.stage_advance"
	else:
		ctx.save_request_reason += "|realm.stage_advance"

	return ctx.save_data["realms"][ctx.realm_id]


# Count realms that have ever been started (status != "not_started").
static func _count_started_realms(save_realms: Dictionary) -> int:
	var count := 0
	for rid in save_realms:
		var rm_v: Variant = save_realms[rid]
		var rm: Dictionary = rm_v if rm_v is Dictionary else {}
		if rm.get("status", "") != RealmModel.STATUS_NOT_STARTED:
			count += 1
	return count

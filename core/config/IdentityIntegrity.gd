class_name IdentityIntegrity
extends RefCounted

## V2-PROG-012 Phase 9 — config-integrity guard for the three canonical
## vector/virtue/calling identity tables, same precedent as
## CallingService.validate_config_integrity() / DirectiveService.validate_config_integrity()
## (called once at boot, alongside them, from ConfigService.load_balance()).
##
## Canonical tables (all under data.contact — see balance.json's "_comment_identity"
## on that block for why they live there and not under data.weaving_rite):
##   vector_virtue_composition  — SEMANTIC. 10 vectors -> their 2 composing virtues.
##                                 Not invertible (empathy/forgiveness both live only
##                                 under "mediator"), never treated as a bijection.
##   virtue_vector_key          — KEYING PERMUTATION. A genuine bijection, 10 vectors
##                                 <-> 10 virtues, used ONLY to invert virtue -> vector
##                                 for recruit/starter-Echo seeding. Deliberately NOT
##                                 composition-faithful (see its own _comment).
##   calling_to_virtue_primary  — 6 callings -> a virtue, mechanically derived from
##                                 each calling's primary vector's primary composing
##                                 virtue. Collisions across callings are fine; this
##                                 table is never inverted.
##
## Logs a warning (does not fail the load) for each malformed shape found —
## matching CallingService's / DirectiveService's precedent of "loud at boot,
## not silent forever."
static func validate(data: Dictionary, logger, t: int) -> bool:
	var all_valid := true

	var contact_v: Variant = data.get("contact", {})
	var contact: Dictionary = contact_v if contact_v is Dictionary else {}

	var composition_v: Variant = contact.get("vector_virtue_composition", {})
	var composition: Dictionary = composition_v if composition_v is Dictionary else {}

	var key_table_v: Variant = contact.get("virtue_vector_key", {})
	var key_table: Dictionary = key_table_v if key_table_v is Dictionary else {}

	var calling_primary_v: Variant = contact.get("calling_to_virtue_primary", {})
	var calling_primary: Dictionary = calling_primary_v if calling_primary_v is Dictionary else {}

	var virtue_wheel_v: Variant = contact.get("virtue_wheel", [])
	var virtue_wheel: Array = virtue_wheel_v if virtue_wheel_v is Array else []
	var virtue_set: Dictionary = {}
	for v in virtue_wheel:
		virtue_set[str(v)] = true

	var vectors_v: Variant = data.get("vectors", {})
	var vectors: Dictionary = vectors_v if vectors_v is Dictionary else {}
	var archetype_init_v: Variant = vectors.get("archetype_init", {})
	var archetype_init: Dictionary = archetype_init_v if archetype_init_v is Dictionary else {}
	var vector_keyspace: Dictionary = {}
	for k in _real_keys(archetype_init):
		vector_keyspace[k] = true

	var calling_cfg_v: Variant = data.get("calling", {})
	var calling_cfg: Dictionary = calling_cfg_v if calling_cfg_v is Dictionary else {}
	var all_callings_v: Variant = calling_cfg.get("all_callings", [])
	var all_callings: Array = all_callings_v if all_callings_v is Array else []
	var defns_v: Variant = calling_cfg.get("definitions", {})
	var defns: Dictionary = defns_v if defns_v is Dictionary else {}

	# ── 1. composition keyspace matches canonical vector keyspace ──────────────
	var composition_keys: Array = _real_keys(composition)
	for vk in composition_keys:
		if not vector_keyspace.has(vk):
			_warn(logger, t, "vector_virtue_composition has entry '%s' not present in data.vectors.archetype_init" % vk, {"vector": vk})
			all_valid = false
	for vk in vector_keyspace:
		if not composition.has(vk):
			_warn(logger, t, "vector_virtue_composition is missing entry for vector '%s' (present in data.vectors.archetype_init)" % vk, {"vector": vk})
			all_valid = false

	# ── 2. every virtue named anywhere exists in the canonical virtue list ─────
	for vk in composition_keys:
		var pair_v: Variant = composition.get(vk, [])
		var pair: Array = pair_v if pair_v is Array else []
		for virtue_v in pair:
			var virtue := str(virtue_v)
			if not virtue_set.has(virtue):
				_warn(logger, t, "vector_virtue_composition['%s'] names unknown virtue '%s' (not in data.contact.virtue_wheel)" % [vk, virtue], {"vector": vk, "virtue": virtue})
				all_valid = false

	for vk in _real_keys(key_table):
		var virtue := str(key_table.get(vk, ""))
		if not virtue_set.has(virtue):
			_warn(logger, t, "virtue_vector_key['%s'] names unknown virtue '%s' (not in data.contact.virtue_wheel)" % [vk, virtue], {"vector": vk, "virtue": virtue})
			all_valid = false

	for cid in _real_keys(calling_primary):
		var virtue := str(calling_primary.get(cid, ""))
		if not virtue_set.has(virtue):
			_warn(logger, t, "calling_to_virtue_primary['%s'] names unknown virtue '%s' (not in data.contact.virtue_wheel)" % [cid, virtue], {"calling": cid, "virtue": virtue})
			all_valid = false

	# ── 3. virtue_vector_key is a genuine bijection onto the 10 canonical virtues ──
	var key_keys: Array = _real_keys(key_table)
	if key_keys.size() != vector_keyspace.size():
		_warn(logger, t, "virtue_vector_key has %d entries, expected %d (one per vector in data.vectors.archetype_init)" % [key_keys.size(), vector_keyspace.size()], {})
		all_valid = false
	else:
		for vk in key_keys:
			if not vector_keyspace.has(vk):
				_warn(logger, t, "virtue_vector_key has entry '%s' not present in data.vectors.archetype_init" % vk, {"vector": vk})
				all_valid = false

	var seen_virtues: Dictionary = {}
	var duplicate_found := false
	for vk in key_keys:
		var virtue := str(key_table.get(vk, ""))
		if seen_virtues.has(virtue):
			_warn(logger, t, "virtue_vector_key is not a bijection — virtue '%s' is claimed by both '%s' and '%s'" % [virtue, seen_virtues[virtue], vk], {"virtue": virtue})
			all_valid = false
			duplicate_found = true
		seen_virtues[virtue] = vk
	if not duplicate_found:
		for virtue in virtue_set:
			if not seen_virtues.has(virtue):
				_warn(logger, t, "virtue_vector_key is not onto — virtue '%s' is claimed by no vector" % virtue, {"virtue": virtue})
				all_valid = false

	# ── 4. calling_to_virtue_primary covers all 6 callings; each value lies within ──
	#       that calling's primary vector's composition
	for cid_v in all_callings:
		var cid := str(cid_v)
		if not calling_primary.has(cid):
			_warn(logger, t, "calling_to_virtue_primary is missing an entry for calling '%s'" % cid, {"calling": cid})
			all_valid = false
			continue
		var defn_v: Variant = defns.get(cid, {})
		var defn: Dictionary = defn_v if defn_v is Dictionary else {}
		var primary_vector := str(defn.get("vector", ""))
		var pair_v: Variant = composition.get(primary_vector, [])
		var pair: Array = pair_v if pair_v is Array else []
		var value := str(calling_primary.get(cid, ""))
		if not (value in pair):
			_warn(logger, t, "calling_to_virtue_primary['%s'] = '%s' is not in its primary vector's ('%s') composition %s" % [cid, value, primary_vector, str(pair)], {"calling": cid, "value": value, "primary_vector": primary_vector})
			all_valid = false

	# ── 5. never inverted — no consumer should treat calling_to_virtue_primary as a
	#       vector/virtue -> calling map. This is a static-shape check we CAN make:
	#       verify it is not accidentally a bijection being relied on elsewhere by
	#       confirming duplicate values are permitted (i.e. we do NOT flag them).
	#       (No-op check — documents the invariant; collisions are valid and expected.)

	# ── 6. the duplicate copy formerly in data.contact.recruitment (and the original
	#       formerly in data.weaving_rite) must be gone — regression guard so nobody
	#       reintroduces a second stored copy that can silently desync from canonical.
	var recruitment_v: Variant = contact.get("recruitment", {})
	var recruitment: Dictionary = recruitment_v if recruitment_v is Dictionary else {}
	if recruitment.has("vector_to_virtue_primary"):
		_warn(logger, t, "data.contact.recruitment has a 'vector_to_virtue_primary' copy — canonical location is data.contact.virtue_vector_key; duplicates are rejected to prevent silent desync", {})
		all_valid = false

	var weaving_v: Variant = data.get("weaving_rite", {})
	var weaving: Dictionary = weaving_v if weaving_v is Dictionary else {}
	if weaving.has("vector_to_virtue_primary"):
		_warn(logger, t, "data.weaving_rite has a 'vector_to_virtue_primary' copy — canonical location is data.contact.virtue_vector_key; duplicates are rejected to prevent silent desync", {})
		all_valid = false

	return all_valid


## Keys of dict, excluding any "_"-prefixed metadata keys (e.g. "_comment") —
## the same convention already used by ConversationService._pick_response_text()
## when walking calling-register content dicts.
static func _real_keys(dict: Dictionary) -> Array:
	var out: Array = []
	for k in dict:
		if not str(k).begins_with("_"):
			out.append(str(k))
	return out


static func _warn(logger, t: int, msg: String, payload: Dictionary) -> void:
	if logger != null:
		logger.info(t, "identity.config.warn", msg, payload)

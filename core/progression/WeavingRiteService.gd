class_name WeavingRiteService
extends RefCounted

# V2-WEAVE-002: foundation Weaving Rite resolution service.
# Deterministic, pure-static, no RNG, no OS time.

const _VIRTUE_WHEEL: Array = [
	"courage", "leadership", "truth", "wisdom", "humility",
	"acceptance", "forgiveness", "compassion", "empathy", "generosity"
]

const _OPPOSITE_PAIRS: Dictionary = {
	"acceptance|courage": true,
	"forgiveness|leadership": true,
	"compassion|truth": true,
	"empathy|wisdom": true,
	"generosity|humility": true,
}

const _CALLING_TO_VIRTUE: Dictionary = {
	"aduro": "courage",
	"okofor": "leadership",
	"okomfo": "wisdom",
	"onyamesu": "acceptance",
	"sum_okwanfo": "generosity",
	"kra_soro": "wisdom",
}


static func get_candidates(thread: Dictionary, roster: Array, save_data: Dictionary, cfg: Dictionary) -> Array:
	var out: Array = []
	for echo_v in roster:
		if not (echo_v is Dictionary):
			continue
		var echo: Dictionary = echo_v
		var fit_score := _compute_fit(echo, thread, save_data, cfg)
		var readiness_score := _compute_readiness(echo, thread, save_data)
		var strain_score := _compute_strain(echo, save_data)
		var fit_clue := _fit_clue(fit_score, cfg)
		var readiness_clue := _readiness_clue(readiness_score, cfg)
		var strain_clue := _strain_clue(strain_score, cfg)

		out.append({
			"echo_id": str(echo.get("id", "")),
			"name": str(echo.get("name", "")),
			"fit_score": fit_score,
			"readiness_score": readiness_score,
			"strain_score": strain_score,
			"fit_clue": fit_clue,
			"readiness_clue": readiness_clue,
			"strain_clue": strain_clue,
			"fit_line": "Fit: %s" % fit_clue,
			"readiness_line": "Readiness: %s" % readiness_clue,
			"strain_line": "Strain: %s" % strain_clue,
			"calling_origin": str(echo.get("calling_origin", "")),
			"standing": int(echo.get("standing", echo.get("rank", 1))),
		})

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var af := float(a.get("fit_score", 0.0))
		var bf := float(b.get("fit_score", 0.0))
		if not is_equal_approx(af, bf):
			return af > bf
		var ar := float(a.get("readiness_score", 0.0))
		var br := float(b.get("readiness_score", 0.0))
		if not is_equal_approx(ar, br):
			return ar > br
		return str(a.get("name", "")) < str(b.get("name", ""))
	)

	var max_candidates := int(cfg.get("max_candidates", 3))
	if max_candidates < 1:
		max_candidates = 1
	if out.size() > max_candidates:
		out = out.slice(0, max_candidates)
	return out


static func resolve_outcome(echo: Dictionary, thread: Dictionary, save_data: Dictionary, cfg: Dictionary) -> String:
	var fit_score := _compute_fit(echo, thread, save_data, cfg)
	var readiness_score := _compute_readiness(echo, thread, save_data)
	var accept_threshold := float(cfg.get("fit_threshold_accept", 0.55))
	var readiness_threshold := float(cfg.get("readiness_threshold_defer", 0.38))

	if fit_score >= accept_threshold:
		if readiness_score >= readiness_threshold:
			return "accept"
		return "defer"
	return "reject"


static func apply_outcome(outcome: String, echo_id: String, thread_id: String, save_data: Dictionary, logger, t: int) -> void:
	if outcome != "accept" and outcome != "reject" and outcome != "defer":
		if logger != null:
			logger.warn(t, "weave.apply.invalid_outcome", "Invalid weaving outcome", {
				"outcome": outcome,
				"echo_id": echo_id,
				"thread_id": thread_id,
			})
		return

	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return
	var sanctum: Dictionary = sanctum_v

	var threads_v: Variant = sanctum.get("threads", {})
	var threads: Dictionary = threads_v if threads_v is Dictionary else {}
	var thread_v: Variant = threads.get(thread_id, {})
	var thread: Dictionary = thread_v if thread_v is Dictionary else {}

	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []
	var echo: Dictionary = _find_echo_ref(roster, echo_id)

	if outcome == "accept":
		if not thread.is_empty() and not echo.is_empty():
			_ensure_echo_weave_fields(echo)
			var woven_threads_v: Variant = echo.get("woven_threads", [])
			var woven_threads: Array = woven_threads_v if woven_threads_v is Array else []
			woven_threads.append({
				"id": str(thread.get("id", thread_id)),
				"virtue": str(thread.get("virtue", "unknown")),
				"quality_tier": str(thread.get("quality_tier", "broken")),
			})
			echo["woven_threads"] = woven_threads
		_remove_thread(threads, thread_id)
	elif outcome == "reject":
		_remove_thread(threads, thread_id)
	elif outcome == "defer":
		if not echo.is_empty():
			_ensure_echo_weave_fields(echo)
			var marks_v: Variant = echo.get("weave_memory_marks", [])
			var marks: Array = marks_v if marks_v is Array else []
			marks.append({
				"thread_id": thread_id,
				"virtue": str(thread.get("virtue", "unknown")),
				"quality_tier": str(thread.get("quality_tier", "broken")),
				"t": t,
			})
			echo["weave_memory_marks"] = marks

	sanctum["threads"] = threads
	sanctum["roster"] = roster
	save_data["sanctum"] = sanctum

	if logger != null:
		logger.info(t, "weave.outcome.applied", "Weaving outcome applied", {
			"outcome": outcome,
			"echo_id": echo_id,
			"thread_id": thread_id,
		})


static func get_non_chosen_consequences(candidates: Array, chosen_id: String, outcome: String, cfg: Dictionary) -> Array:
	var outcome_multiplier := 0.0
	match outcome:
		"accept":
			outcome_multiplier = float(cfg.get("non_chosen_outcome_mult_accept", 1.0))
		"reject":
			outcome_multiplier = float(cfg.get("non_chosen_outcome_mult_reject", 0.75))
		"defer":
			outcome_multiplier = float(cfg.get("non_chosen_outcome_mult_defer", 0.40))
		_:
			outcome_multiplier = 0.0
	if outcome_multiplier <= 0.0:
		return []

	var out: Array = []
	var base_morale := int(cfg.get("non_chosen_consequence_base_morale_delta", -8))
	var base_fear := int(cfg.get("non_chosen_consequence_base_fear_delta", 5))
	var base_bond := int(cfg.get("non_chosen_consequence_base_bond_delta", -8))

	for c_v in candidates:
		if not (c_v is Dictionary):
			continue
		var c: Dictionary = c_v
		var eid := str(c.get("echo_id", ""))
		if eid.is_empty() or eid == chosen_id:
			continue

		var strain := float(c.get("strain_score", 0.5))
		var intensity := clampf(0.8 + (strain * 0.6), 0.6, 1.6)
		var scaled := intensity * outcome_multiplier

		var morale_delta := int(round(float(base_morale) * scaled))
		var fear_delta := int(round(float(base_fear) * scaled))
		var bond_delta := int(round(float(base_bond) * scaled))
		if morale_delta == 0 and fear_delta == 0 and bond_delta == 0:
			continue

		out.append({
			"echo_id": eid,
			"name": str(c.get("name", "")),
			"morale_delta": morale_delta,
			"fear_delta": fear_delta,
			"bond_delta": bond_delta,
		})

	return out


static func _compute_fit(echo: Dictionary, thread: Dictionary, save_data: Dictionary, cfg: Dictionary) -> float:
	var vector_to_virtue_v: Variant = cfg.get("vector_to_virtue_primary", {})
	var vector_to_virtue: Dictionary = vector_to_virtue_v if vector_to_virtue_v is Dictionary else {}

	var thread_virtue := _norm_virtue(thread.get("virtue", ""))
	var dominant_vector := str(echo.get("dominant_vector", ""))
	var primary_virtue := _norm_virtue(vector_to_virtue.get(dominant_vector, ""))

	var fit := 0.4
	if primary_virtue == thread_virtue and not thread_virtue.is_empty():
		fit = 1.0
	elif _is_adjacent(primary_virtue, thread_virtue):
		fit = 0.6
	elif _is_opposite(primary_virtue, thread_virtue):
		fit = 0.2

	var calling_virtue := _calling_virtue(echo, cfg)
	if not calling_virtue.is_empty():
		if calling_virtue == thread_virtue or _is_adjacent(calling_virtue, thread_virtue):
			fit += 0.1

	return clampf(fit, 0.0, 1.0)


static func _compute_readiness(echo: Dictionary, thread: Dictionary, save_data: Dictionary) -> float:
	var emo := EmotionService.get_emotion(echo)
	var fear := int(emo.get("fear_current", 0))
	var morale := int(emo.get("morale_current", 50))

	var fear_score := clampf(1.0 - (float(fear) / 100.0), 0.0, 1.0)
	var morale_score := clampf(float(morale) / 100.0, 0.0, 1.0)
	var readiness := (fear_score * 0.55) + (morale_score * 0.45)

	var rivals := _count_rivals_in_party(str(echo.get("id", "")), save_data)
	if rivals > 0:
		readiness -= 0.1

	var same_virtue := _count_woven_virtue(echo, _norm_virtue(thread.get("virtue", "")))
	if same_virtue >= 3:
		readiness -= 0.15

	if fear >= 80:
		readiness -= 0.1

	return clampf(readiness, 0.0, 1.0)


static func _compute_strain(echo: Dictionary, save_data: Dictionary) -> float:
	var woven_threads_v: Variant = echo.get("woven_threads", [])
	var woven_threads: Array = woven_threads_v if woven_threads_v is Array else []
	var rivals := _count_rivals_in_party(str(echo.get("id", "")), save_data)
	var emo := EmotionService.get_emotion(echo)
	var fear := int(emo.get("fear_current", 0))

	var woven_component := minf(0.7, float(woven_threads.size()) * 0.12)
	var rival_component := minf(0.6, float(rivals) * 0.2)
	var fear_component := clampf(float(fear) / 200.0, 0.0, 0.5)
	return clampf(woven_component + rival_component + fear_component, 0.0, 1.0)


static func _fit_clue(fit_score: float, cfg: Dictionary) -> String:
	var fit_vocab := _clue_bucket(cfg, "fit")
	if fit_score >= 0.70:
		return str(fit_vocab.get("high", "Drawn"))
	if fit_score >= 0.45:
		return str(fit_vocab.get("medium", "Resonant"))
	if fit_score >= 0.25:
		return str(fit_vocab.get("low", "Misaligned"))
	return str(fit_vocab.get("false", "FalsePull"))


static func _readiness_clue(readiness_score: float, cfg: Dictionary) -> String:
	var readiness_vocab := _clue_bucket(cfg, "readiness")
	if readiness_score >= 0.70:
		return str(readiness_vocab.get("high", "ClearEyed"))
	if readiness_score >= 0.45:
		return str(readiness_vocab.get("medium", "Unsteady"))
	if readiness_score >= 0.25:
		return str(readiness_vocab.get("low", "Trembling"))
	return str(readiness_vocab.get("blocked", "NotYet"))


static func _strain_clue(strain_score: float, cfg: Dictionary) -> String:
	var strain_vocab := _clue_bucket(cfg, "strain")
	if strain_score < 0.34:
		return str(strain_vocab.get("low", "Settled"))
	if strain_score < 0.67:
		return str(strain_vocab.get("medium", "Contested"))
	return str(strain_vocab.get("high", "Burdened"))


static func _clue_bucket(cfg: Dictionary, bucket: String) -> Dictionary:
	var vocab_v: Variant = cfg.get("clue_vocab", {})
	if not (vocab_v is Dictionary):
		return {}
	var vocab: Dictionary = vocab_v
	var bucket_v: Variant = vocab.get(bucket, {})
	return bucket_v if bucket_v is Dictionary else {}


static func _find_echo_ref(roster: Array, echo_id: String) -> Dictionary:
	for e_v in roster:
		if e_v is Dictionary and str(e_v.get("id", "")) == echo_id:
			return e_v
	return {}


static func _remove_thread(threads: Dictionary, thread_id: String) -> void:
	if threads.has(thread_id):
		threads.erase(thread_id)


static func _ensure_echo_weave_fields(echo: Dictionary) -> void:
	if not echo.has("woven_threads") or not (echo["woven_threads"] is Array):
		echo["woven_threads"] = []
	if not echo.has("weave_memory_marks") or not (echo["weave_memory_marks"] is Array):
		echo["weave_memory_marks"] = []


static func _count_rivals_in_party(echo_id: String, save_data: Dictionary) -> int:
	if echo_id.is_empty():
		return 0
	var sanctum_v: Variant = save_data.get("sanctum", {})
	var sanctum: Dictionary = sanctum_v if sanctum_v is Dictionary else {}
	var bonds_v: Variant = sanctum.get("bonds", [])
	var bonds: Array = bonds_v if bonds_v is Array else []
	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []
	if party_ids.is_empty():
		return 0

	var rivals := 0
	for pid_v in party_ids:
		var pid := str(pid_v)
		if pid == echo_id:
			continue
		var edge := SocialGraphService.get_edge(bonds, echo_id, pid)
		if edge.is_empty():
			continue
		if int(edge.get("strength", 0)) <= -30:
			rivals += 1
	return rivals


static func _count_woven_virtue(echo: Dictionary, virtue: String) -> int:
	if virtue.is_empty():
		return 0
	var woven_v: Variant = echo.get("woven_threads", [])
	var woven: Array = woven_v if woven_v is Array else []
	var count := 0
	for w_v in woven:
		if not (w_v is Dictionary):
			continue
		if _norm_virtue((w_v as Dictionary).get("virtue", "")) == virtue:
			count += 1
	return count


static func _norm_virtue(v: Variant) -> String:
	return str(v).strip_edges().to_lower()


static func _is_adjacent(a: String, b: String) -> bool:
	if a.is_empty() or b.is_empty() or a == b:
		return false
	var ai: int = _VIRTUE_WHEEL.find(a)
	var bi: int = _VIRTUE_WHEEL.find(b)
	if ai == -1 or bi == -1:
		return false
	var n: int = _VIRTUE_WHEEL.size()
	var diff: int = absi(ai - bi)
	return diff == 1 or diff == (n - 1)


static func _is_opposite(a: String, b: String) -> bool:
	if a.is_empty() or b.is_empty() or a == b:
		return false
	var pair := [a, b]
	pair.sort()
	var key := "%s|%s" % [pair[0], pair[1]]
	return bool(_OPPOSITE_PAIRS.get(key, false))


static func _calling_virtue(echo: Dictionary, cfg: Dictionary) -> String:
	var cfg_map_v: Variant = cfg.get("calling_to_virtue_primary", {})
	var cfg_map: Dictionary = cfg_map_v if cfg_map_v is Dictionary else {}
	var calling := str(echo.get("calling", "")).strip_edges().to_lower()
	if not calling.is_empty() and cfg_map.has(calling):
		return _norm_virtue(cfg_map[calling])
	if not calling.is_empty() and _CALLING_TO_VIRTUE.has(calling):
		return _norm_virtue(_CALLING_TO_VIRTUE[calling])

	# Fallback: if calling_origin is already a vector key, map via vector table.
	var origin := str(echo.get("calling_origin", "")).strip_edges().to_lower()
	var vector_to_virtue_v: Variant = cfg.get("vector_to_virtue_primary", {})
	var vector_to_virtue: Dictionary = vector_to_virtue_v if vector_to_virtue_v is Dictionary else {}
	if vector_to_virtue.has(origin):
		return _norm_virtue(vector_to_virtue[origin])

	return ""

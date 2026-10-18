extends RefCounted
## Party stance for one stage Advance (V2-DIRECTIVE-002 design 3 to 5). Pure and static.
## Dial = Directive baseline + sum(Echo lean) / party size, clamped to the dial bound. Readiness
## only lowers steps, for every Directive. A Directive with no `directive_profile` entry keeps its
## baseline dials and has no leans (D-54 N2).

const DIALS: Array = ["exposure_tolerance", "stop_willingness", "commitment_fraction", "escape_bonus"]

## Test observables: one Advance builds exactly one counted stance. Naming dry runs pass
## `counted = false` and raise `dry_builds`.
static var builds: int = 0
static var dry_builds: int = 0


## Lean inputs of one Echo. Judgment comes from the same reader combat uses (bonds included).
static func read_echo(actor: Dictionary, bonds: Array, living_ids: Dictionary, cfg_data: Dictionary) -> Dictionary:
	var thresholds := _d(_d(cfg_data.get("sanctum", {})).get("bond_thresholds", {}))
	var ctx := MaturityExpressionService.build_ctx_inputs(actor, bonds, living_ids, cfg_data, thresholds, {}, 0.0)
	var expr := MaturityExpressionService.derive_expression(actor, ctx, _d(cfg_data.get("maturity_expression", {})))
	var best := _best_style(actor, cfg_data)
	var echo := {
		"id": str(actor.get("id", "")),
		"family": str(ctx.get("calling_family", "")),
		"width": clampf(float(expr.get("judgment", 0.0)), 0.0, 1.0),
		"best_style": best["style"],
		"style_score": best["score"],
	}
	return restate(echo, int(actor.get("morale", 50)), int(actor.get("fear", 0)), int(actor.get("fear_base", 0)), cfg_data)


## Copy of `echo` with a new emotional state: the status and its band lean are re-read from the
## shared helper and table, so no caller can set the numbers and leave the status behind.
static func restate(echo: Dictionary, morale: int, fear: int, fear_base: int, cfg_data: Dictionary) -> Dictionary:
	var status := EmotionStatusLean.status_from(morale, fear, fear_base)
	var table := EmotionStatusLean.table_of(_d(_d(cfg_data.get("combat", {})).get("movement", {})))
	var out := echo.duplicate()
	out["morale"] = morale
	out["fear"] = fear
	out["fear_base"] = fear_base
	out["status"] = status
	out["lean"] = EmotionStatusLean.lean(status, table)
	return out


## The saved party as `read_echo` dicts, with the real save bonds (D-26). `exclude_id` drops one
## Echo and, through the living set, the bond edges that Echo gives the others.
static func read_party(save_data: Dictionary, cfg_data: Dictionary, exclude_id: String = "") -> Array:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	var bonds_v: Variant = (sanctum_v as Dictionary).get("bonds", []) if sanctum_v is Dictionary else []
	var actors: Array = []
	var living: Dictionary = {}
	for a in SanctumService.get_party_actors_static(save_data):
		if str(a.get("id", "")) != exclude_id:
			actors.append(a)
			living[str(a.get("id", ""))] = true
	var echoes: Array = []
	for a in actors:
		echoes.append(read_echo(a, bonds_v if bonds_v is Array else [], living, cfg_data))
	return echoes


## One Echo's signed lean on one dial, in dial units (coefficient x bound x strength).
## `category` selects one coefficient set inside a category dial (`category_weight`).
static func echo_lean(echo: Dictionary, dial: String, stance_cfg: Dictionary, category: String = "") -> float:
	var coeffs := _d(_d(stance_cfg.get("leans", {})).get(dial, {}))
	if category != "":
		coeffs = _d(coeffs.get(category, {}))
	var floor_ := _num(_d(stance_cfg.get("lean_strength", {})), "dispositional_floor")
	var strength := floor_ + (1.0 - floor_) * float(echo.get("width", 0.0))
	var state := float(echo.get("lean", 0.0))
	var afraid := EmotionStatusLean.afraid(state)
	# A dial with a fear term already counts the afraid side, so its morale term adds only the bold side.
	var fear_c := _num(coeffs, "fear")
	var sum := _num(coeffs, "calling_" + str(echo.get("family", ""))) * strength \
		+ fear_c * afraid \
		+ _num(coeffs, "morale") * (state if fear_c == 0.0 else EmotionStatusLean.bold(state)) \
		+ _num(coeffs, "morale_low") * afraid
	if dial == "exposure_tolerance":
		var ident := _d(stance_cfg.get("identity", {}))
		var by_style := _d(ident.get("tolerance_by_style", {}))
		var aligned := clampf(float(echo.get("style_score", 0.0)) * _num(ident, "alignment_gain"), -1.0, 1.0)
		sum += aligned * _num(by_style, str(echo.get("best_style", ""))) * strength
	return sum * _num(_d(stance_cfg.get("bounds", {})), dial)


## Steps the party loses to its emotional status: the status of the party's mean morale, fear and
## base fear, looked up in `readiness.status_steps_lost`, capped by `bounds.readiness_steps`.
static func readiness_steps_lost(echoes: Array, stance_cfg: Dictionary) -> int:
	if echoes.is_empty():
		return 0
	var morale := 0.0
	var fear := 0.0
	var fear_base := 0.0
	for e in echoes:
		morale += float(e.get("morale", 50.0))
		fear += float(e.get("fear", 0.0))
		fear_base += float(e.get("fear_base", 0.0))
	var n := float(echoes.size())
	var status := EmotionStatusLean.status_from(int(morale / n), int(fear / n), int(fear_base / n))
	var lost := int(_num(_d(_d(stance_cfg.get("readiness", {})).get("status_steps_lost", {})), status))
	return clampi(lost, 0, int(_num(_d(stance_cfg.get("bounds", {})), "readiness_steps")))


## Bend per situation category: mean of the Echoes' leans, clamped to `bounds.category_weight`.
## `echoes_leans` is {echo_id: {category: lean}}. Ranks after the authored weight, so it only breaks ties.
static func category_bend(echoes_leans: Dictionary, stance_cfg: Dictionary) -> Dictionary:
	var bound := _num(_d(stance_cfg.get("bounds", {})), "category_weight")
	var sums: Dictionary = {}
	for echo_id in echoes_leans.keys():
		var by_cat := _d(echoes_leans[echo_id])
		for cat in by_cat.keys():
			sums[cat] = float(sums.get(cat, 0.0)) + float(by_cat[cat])
	var bend: Dictionary = {}
	for cat in sums.keys():
		bend[cat] = clampf(float(sums[cat]) / maxf(echoes_leans.size(), 1), -bound, bound)
	return bend


## Bent return-safety bonus (whole points). Neutral when the Directive has no profile.
static func escape_bonus(echoes: Array, directive: Dictionary, stance_cfg: Dictionary) -> int:
	return roundi(float(build(echoes, directive, stance_cfg)["dials"]["escape_bonus"]))


## `echoes` are `read_echo` dicts, any order. Returns dials, effective_steps, commitment_depth,
## leans {echo_id: {dial: lean}} and candidates (ids with a non-zero lean).
static func build(echoes: Array, directive: Dictionary, stance_cfg: Dictionary, counted: bool = true) -> Dictionary:
	if counted:
		builds += 1
	else:
		dry_builds += 1
	var budget := int(directive.get("step_budget", DirectiveService.DEFAULT_STEP_BUDGET))
	var profile := _d(_d(stance_cfg.get("directive_profile", {})).get(str(directive.get("id", "")), {}))
	var base := {
		"exposure_tolerance": float(directive.get("exposure_tolerance", 1.0)),
		"stop_willingness": _num(profile, "stop_willingness"),
		"commitment_fraction": float(profile.get("commitment_fraction", 1.0)),
		"escape_bonus": float(directive.get("escape_bonus", 0.0)),
	}
	var effective := maxi(budget - readiness_steps_lost(echoes, stance_cfg), mini(1, budget))
	var stance := {"dials": base.duplicate(), "effective_steps": effective, "leans": {}, "candidates": [], "category_bend": {}}
	if profile.is_empty():
		stance["commitment_depth"] = effective
		return stance

	var sorted := echoes.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	var bounds := _d(stance_cfg.get("bounds", {}))
	var leans: Dictionary = {}
	for e in sorted:
		leans[str(e["id"])] = {}
	for dial in DIALS:
		var total := 0.0
		for e in sorted:
			var lean := echo_lean(e, dial, stance_cfg)
			leans[str(e["id"])][dial] = lean
			total += lean
		var bound := _num(bounds, dial)
		var v := clampf(float(base[dial]) + total / maxf(sorted.size(), 1), float(base[dial]) - bound, float(base[dial]) + bound)
		stance["dials"][dial] = maxf(v, 0.0) if dial == "escape_bonus" else clampf(v, 0.0, 1.0)
	for e in sorted:
		for lean in leans[str(e["id"])].values():
			if lean != 0.0:
				stance["candidates"].append(str(e["id"]))
				break
	stance["leans"] = leans
	var cat_leans: Dictionary = {}
	for e in sorted:
		cat_leans[str(e["id"])] = {}
		for cat in _d(_d(stance_cfg.get("leans", {})).get("category_weight", {})).keys():
			if not str(cat).begins_with("_"):
				cat_leans[str(e["id"])][cat] = echo_lean(e, "category_weight", stance_cfg, str(cat))
	stance["category_bend"] = category_bend(cat_leans, stance_cfg)

	stance["commitment_depth"] = mini(maxi(roundi(effective * float(stance["dials"]["commitment_fraction"])), 1), effective)
	return stance


# Vector term only (family "", not afraid, not bold): the stance already leans on those (design 2 rule 1).
static func _best_style(actor: Dictionary, cfg_data: Dictionary) -> Dictionary:
	var style_cfg := _d(_d(cfg_data.get("actor", {})).get("movement_style_weights", {}))
	var best := {"style": "", "score": 0.0}
	var first := true
	for style in MovementStyleService.STYLES:
		if not MovementStyleService.eligible_styles("reposition").has(style):
			continue
		var route := MovementStyleService.route_style_for(style)
		if route.is_empty():
			continue
		var score := MovementStyleService.style_alignment_score(
			route, "reposition", _d(actor.get("vector_scores", {})), "", {}, 0.0, 0.0, 0.0, 0.0, style_cfg)
		if first or score > float(best["score"]):
			best = {"style": style, "score": score}
			first = false
	return best


static func _d(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _num(d: Dictionary, key: String) -> float:
	var v: Variant = d.get(key, 0.0)
	return float(v) if v is int or v is float else 0.0

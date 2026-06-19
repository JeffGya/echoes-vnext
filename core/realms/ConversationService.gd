class_name ConversationService

extends RefCounted

# V2-STAGE-003: Pure-static conversation service.
# All functions are side-effect free — callers (FlowRuntime) apply any mutations.
# Response generation, resonance scoring, NPC reaction, outcome resolution, social effects.

# Virtue wheel adjacency for resonance scoring — must match balance.json data.contact.virtue_wheel
const _VIRTUE_WHEEL: Array = [
	"courage","leadership","truth","wisdom","humility",
	"acceptance","forgiveness","compassion","empathy","generosity",
]

# Stat textures derived from dominant stat (used on response card chip)
const _STAT_TEXTURE_BY_DOMINANT: Dictionary = {
	"atk":   "forceful",
	"def":   "grounding",
	"intel": "analytical",
	"wis":   "thoughtful",
	"agi":   "nimble",
	"cha":   "perceptive",
}

# Calling-to-virtue alignment (fallback only — dominant_vector always takes priority)
const _CALLING_VIRTUE_MAP: Dictionary = {
	"aduro":       "courage",
	"okofor":      "generosity",
	"onyamesu":    "compassion",
	"okomfo":      "wisdom",
	"kra_soro":    "truth",
	"sum_okwanfo": "forgiveness",
}

# S6 expression → S3 parent calling register
const _S6_TO_S3: Dictionary = {
	"okyefo_kesee": "okofor",   "asa_okyefo":  "okofor",
	"opanyin":      "onyamesu", "sunsum_kyere": "onyamesu",
	"asafo":        "aduro",    "twaese":       "aduro",
	"ntontamfafo":  "sum_okwanfo", "sunsum_ahoma": "sum_okwanfo",
	"kranimfo":     "okomfo",   "ogyafo":       "okomfo",
	"okwansoani":   "kra_soro", "wiemhwefo":    "kra_soro",
}

# S9 culmination → S3 parent calling register
const _S9_TO_S3: Dictionary = {
	"nyamedua_okyefo": "okofor",   "grove_bastion":   "okofor",
	"storm_crown":     "okofor",   "war_ward_sentinel":"okofor",
	"abosom_tena_ho":  "onyamesu", "root_elder":       "onyamesu",
	"samanfo_nkyen":   "onyamesu", "bridge_of_names":  "onyamesu",
	"asante_ohene_kobo":"aduro",   "asafohene":        "aduro",
	"red_fang":        "aduro",    "web_cleaver":      "aduro",
	"veiled_passage":  "sum_okwanfo","hidden_web":      "sum_okwanfo",
	"shadow_web":      "sum_okwanfo","whisper_knot":    "sum_okwanfo",
	"spirit_sage":     "okomfo",   "memory_listener":  "okomfo",
	"ananse_kasa":     "okomfo",   "flame_of_thresholds":"okomfo",
	"sankofa_wanderer":"kra_soro", "far_road_captain": "kra_soro",
	"star_watch":      "kra_soro", "horizon_judge":    "kra_soro",
}


# ──────────────────────────────────────────────────────────────────────────────
# Response generation
# ──────────────────────────────────────────────────────────────────────────────

# Generate one response option per consulted echo.
# echoes: Array of echo dicts (the consulted echoes for this turn, NOT full party)
# contact: current ContactModel dict
# cfg: balance.json data.contact
# response_data: parsed contact_responses.json dict
# Returns Array[Dict] — one entry per echo
static func generate_responses(
	echoes: Array,
	contact: Dictionary,
	cfg: Dictionary,
	response_data: Dictionary,
	t: int,
	bid_state: Dictionary = {}  # echo_id -> bid_type ("alignment"/"reactive"/"")
) -> Array:
	var results: Array = []
	var contact_role := str(contact.get("role", ""))
	var contact_disposition := str(contact.get("disposition", ""))
	var contact_fear := int(contact.get("fear", 50))
	var contact_morale := int(contact.get("morale", 50))
	var contact_virtue_primary := str(contact.get("virtue_primary", "courage"))
	var contact_virtue_secondary := str(contact.get("virtue_secondary", "courage"))

	for echo_v in echoes:
		var echo: Dictionary = echo_v if echo_v is Dictionary else {}
		var echo_id := str(echo.get("id", ""))
		var echo_name := str(echo.get("name", ""))
		var calling := str(echo.get("calling", ""))
		if calling.is_empty():
			calling = str(echo.get("calling_origin", ""))

		# Emotional status — canonical 10-tier system from EmotionService
		var emo_v: Variant = echo.get("emotion", {})
		var emo: Dictionary = emo_v if emo_v is Dictionary else {}
		var fear_current := int(emo.get("fear_current", 0))
		var morale_current := int(emo.get("morale_current", 50))
		var emotional_status := EmotionService.get_emotional_status(morale_current, fear_current)

		# Virtue alignment — dominant_vector always takes priority, calling is fallback
		var virtue_alignment := _calling_to_virtue(calling, echo)

		# Resonance score: 2-factor
		var resonance_score := compute_turn_score_from_virtue(
			virtue_alignment, contact_virtue_primary, contact_virtue_secondary,
			contact_disposition, contact_fear, contact_morale,
			emotional_status, cfg, contact_role
		)

		# Stat texture from dominant stat
		var stats_v: Variant = echo.get("stats", {})
		var stats: Dictionary = stats_v if stats_v is Dictionary else {}
		var stat_texture := _derive_stat_texture(stats)

		# Is calling aligned with NPC role?
		var is_calling_aligned := _is_calling_aligned(calling, contact_role)

		# Bid type
		var bid_type := str(bid_state.get(echo_id, ""))

		# NPC reaction word from previous turn (empty on turn 0)
		var npc_reaction_word := str(contact.get("npc_reaction_word", ""))
		var turn_current := int(contact.get("turn_current", 0))

		# Response text — priority chain driven by bid_type + npc_reaction_word
		var response_text := _pick_response_text(
			calling, emotional_status, virtue_alignment, response_data, t, echo_id,
			bid_type, npc_reaction_word if turn_current > 0 else ""
		)

		# Runtime pronoun substitution: content uses "She" as canonical form.
		# Replace with "He" for male echoes. Uncalled / first-person lines unaffected.
		var echo_gender := str(echo.get("gender", "female"))
		response_text = _substitute_pronouns(response_text, echo_gender)

		results.append({
			"echo_id":            echo_id,
			"echo_name":          echo_name,
			"calling":            calling,
			"response_text":      response_text,
			"virtue_alignment":   virtue_alignment,
			"resonance_score":    resonance_score,
			"emotional_status":   emotional_status,
			"stat_texture":       stat_texture,
			"is_calling_aligned": is_calling_aligned,
			"bid_type":           bid_type,
		})

	return results


# ──────────────────────────────────────────────────────────────────────────────
# Resonance scoring
# ──────────────────────────────────────────────────────────────────────────────

# Two-factor resonance score: virtue resonance + emotional fit modifier.
# Returns float in [0.0, 1.2]. Scores: >0.8 strong; 0.5–0.79 modest; 0.3–0.49 neutral; <0.3 negative.
static func compute_turn_score_from_virtue(
	virtue_alignment: String,
	virtue_primary: String,
	virtue_secondary: String,
	disposition: String,
	contact_fear: int,
	contact_morale: int,
	emotional_status: String,
	cfg: Dictionary,
	contact_role: String = ""
) -> float:
	var weights_v: Variant = cfg.get("resonance_weights", {})
	var weights: Dictionary = weights_v if weights_v is Dictionary else {}

	# Factor 1: virtue resonance
	var virtue_score := _compute_virtue_resonance(virtue_alignment, virtue_primary, virtue_secondary, weights)

	# Factor 2: emotional fit
	var emotional_fit := _compute_emotional_fit(
		disposition, contact_fear, contact_morale, emotional_status, cfg, contact_role
	)

	return clampf(virtue_score + emotional_fit, 0.0, 1.2)


# Virtue resonance: primary=1.0, adjacent=0.7, two_steps=0.4, opposite=0.1
static func compute_resonance(
	virtue_alignment: String,
	virtue_primary: String,
	virtue_secondary: String,
	weights: Dictionary
) -> float:
	return _compute_virtue_resonance(virtue_alignment, virtue_primary, virtue_secondary, weights)


static func _compute_virtue_resonance(
	virtue_alignment: String,
	virtue_primary: String,
	virtue_secondary: String,
	weights: Dictionary
) -> float:
	if virtue_alignment == virtue_primary:
		return float(weights.get("primary", 1.0))
	if virtue_alignment == virtue_secondary:
		return float(weights.get("secondary", 0.7))

	# Distance on virtue wheel
	var dist := _virtue_wheel_distance(virtue_alignment, virtue_primary)
	if dist == 2:
		return float(weights.get("two_steps", 0.4))
	# Opposite (5 steps on 10-wheel)
	if dist >= 5:
		return float(weights.get("opposite", 0.1))
	# 3–4 steps: between two_steps and opposite
	return float(weights.get("two_steps", 0.4)) * 0.7


# Distance between two virtues on the wheel (min of clockwise / counter-clockwise)
static func _virtue_wheel_distance(a: String, b: String) -> int:
	var ia: int = _VIRTUE_WHEEL.find(a)
	var ib: int = _VIRTUE_WHEEL.find(b)
	if ia < 0 or ib < 0:
		return 5  # Unknown → treat as opposite
	var size: int = _VIRTUE_WHEEL.size()
	var cw: int  = abs(ia - ib)
	var ccw: int = size - cw
	return mini(cw, ccw)


static func _compute_emotional_fit(
	disposition: String,
	contact_fear: int,
	contact_morale: int,
	emotional_status: String,
	cfg: Dictionary = {},
	contact_role: String = ""
) -> float:
	var mods_v: Variant = cfg.get("emotional_fit_modifiers", {})
	var mods: Dictionary = mods_v if mods_v is Dictionary else {}

	# Map canonical 10-tier status to 3 scoring bands used in disposition checks
	var band := _emotional_fit_band(emotional_status)

	var base := 0.0

	# Disposition fit: determine if this echo's band matches the disposition's preference
	match disposition:
		"bold":
			if band == "grounded":
				base += float(mods.get("bold", {}).get("direct", 0.2) if mods.get("bold", null) is Dictionary else 0.2)
			elif band == "broken":
				base += float(mods.get("bold", {}).get("excessive_gentle", -0.1) if mods.get("bold", null) is Dictionary else -0.1)
		"reflective":
			if band in ["grounded", "strained"]:
				base += float(mods.get("reflective", {}).get("layered", 0.2) if mods.get("reflective", null) is Dictionary else 0.2)
			elif band == "broken":
				base += float(mods.get("reflective", {}).get("bluntness", -0.2) if mods.get("reflective", null) is Dictionary else -0.2)
		"protective":
			if band in ["grounded", "strained"]:
				base += float(mods.get("protective", {}).get("grounding", 0.2) if mods.get("protective", null) is Dictionary else 0.2)
		"wary":
			if band == "grounded":
				base += float(mods.get("wary", {}).get("patient_firm", 0.2) if mods.get("wary", null) is Dictionary else 0.2)
			elif band == "strained":
				base += float(mods.get("wary", {}).get("patient_early", 0.1) if mods.get("wary", null) is Dictionary else 0.1)
		"grieving":
			if band in ["grounded", "strained"]:
				base += float(mods.get("grieving", {}).get("honest", 0.2) if mods.get("grieving", null) is Dictionary else 0.2)
			elif band == "broken":
				base += float(mods.get("grieving", {}).get("false_comfort", -0.2) if mods.get("grieving", null) is Dictionary else -0.2)
		"proud":
			if band == "grounded":
				base += float(mods.get("proud", {}).get("respectful", 0.2) if mods.get("proud", null) is Dictionary else 0.2)
			elif band == "broken":
				base += float(mods.get("proud", {}).get("condescension", -0.3) if mods.get("proud", null) is Dictionary else -0.3)

	# High-fear NPC bonus/penalty
	if contact_fear >= 60:
		if band in ["grounded", "strained"]:
			base += float(mods.get("high_fear_grounding_bonus", 0.1))
		elif band == "broken" and contact_role == "charge":
			# Near-collapse echo resonates with frightened NPC — like recognises like
			base += 0.2
		elif band == "grounded" and disposition == "bold":
			base += float(mods.get("high_fear_aggressive_penalty", -0.15))

	# Morale bonus for near-collapse speaker with broken NPC morale
	if contact_morale <= 20:
		if band == "broken":
			base += 0.1  # resonance of shared vulnerability

	return base


# ──────────────────────────────────────────────────────────────────────────────
# NPC reaction
# ──────────────────────────────────────────────────────────────────────────────

# Returns {fear_delta: int, morale_delta: int, next_state: String} — does NOT mutate contact.
# next_state: "" (continue) or "failed" (role threshold crossed)
static func apply_npc_reaction(contact: Dictionary, turn_score: float, cfg: Dictionary) -> Dictionary:
	var role := str(contact.get("role", ""))
	var fear := int(contact.get("fear", 50))
	var morale := int(contact.get("morale", 50))

	var fear_delta := 0
	var morale_delta := 0

	if turn_score > 0.8:
		fear_delta   = -10
		morale_delta = +8
	elif turn_score >= 0.5:
		fear_delta   = -4
		morale_delta = +4
	elif turn_score >= 0.3:
		fear_delta   = 0
		morale_delta = 0
	else:
		fear_delta   = +8
		morale_delta = -6

	# Clamp projected values
	var new_fear   := clampi(fear   + fear_delta,   0, 100)
	var new_morale := clampi(morale + morale_delta, 0, 100)

	# Check role failure threshold
	var next_state := ""
	var fail_cfgs_v: Variant = cfg.get("failure_thresholds_by_role", {})
	var fail_cfgs: Dictionary = fail_cfgs_v if fail_cfgs_v is Dictionary else {}
	var fail_cfg_v: Variant = fail_cfgs.get(role, {})
	var fail_cfg: Dictionary = fail_cfg_v if fail_cfg_v is Dictionary else {}

	var morale_floor := int(fail_cfg.get("morale_floor", -1))
	var fear_ceiling := int(fail_cfg.get("fear_ceiling", 101))

	if (morale_floor >= 0 and new_morale < morale_floor) \
		or (fear_ceiling <= 100 and new_fear >= fear_ceiling):
		next_state = "failed"

	return {
		"fear_delta":   fear_delta,
		"morale_delta": morale_delta,
		"next_state":   next_state,
	}


# ──────────────────────────────────────────────────────────────────────────────
# Outcome resolution
# ──────────────────────────────────────────────────────────────────────────────

# Read final NPC fear/morale → "good" / "partial" / "failed"
static func resolve_outcome(contact: Dictionary, cfg: Dictionary) -> String:
	var fear   := int(contact.get("fear",   50))
	var morale := int(contact.get("morale", 50))

	var thresholds_v: Variant = cfg.get("outcome_thresholds", {})
	var thresholds: Dictionary = thresholds_v if thresholds_v is Dictionary else {}

	var good_v: Variant = thresholds.get("good", {})
	var good: Dictionary = good_v if good_v is Dictionary else {}
	var partial_v: Variant = thresholds.get("partial", {})
	var partial: Dictionary = partial_v if partial_v is Dictionary else {}

	if fear <= int(good.get("npc_fear_max", 35)) and morale >= int(good.get("npc_morale_min", 60)):
		return "good"
	if fear <= int(partial.get("npc_fear_max", 60)) and morale >= int(partial.get("npc_morale_min", 35)):
		return "partial"
	return "failed"


# ──────────────────────────────────────────────────────────────────────────────
# Social effects
# ──────────────────────────────────────────────────────────────────────────────

# Returns Array[{echo_id, morale_delta, bond_target_id, bond_delta, reason}]
# Caller applies via EmotionService + SocialGraphService
static func get_social_effects(
	consulted_ids: Array,
	speaking_echo_id: String,
	not_consulted_ids: Array,
	all_party_echoes: Array,
	bonds: Array,
	cfg: Dictionary,
	turn_score: float = 0.5
) -> Array:
	var effects: Array = []
	var social_v: Variant = cfg.get("social_effects", {})
	var social: Dictionary = social_v if social_v is Dictionary else {}

	var consulted_delta := int(social.get("consulted_morale_delta", 3))
	var not_consulted_delta := int(social.get("not_consulted_morale_delta", -1))
	var speaker_delta := int(social.get("speaker_morale_delta", 5))
	var rival_jealousy_morale := int(social.get("rival_jealousy_morale_delta", -3))
	var friend_pride_morale  := int(social.get("friend_pride_morale_delta",  3))
	var rival_bond_delta     := int(social.get("rival_jealousy_bond_delta", -2))
	var friend_bond_delta    := int(social.get("friend_pride_bond_delta",    2))

	# A1/A3: consulted get morale boost; speaker gets additional boost
	for eid_v in consulted_ids:
		var eid := str(eid_v)
		var delta := consulted_delta
		if eid == speaking_echo_id:
			delta += speaker_delta
			# A4: strong positive outcome bonus
			if turn_score > 0.8:
				delta += int(social.get("speaker_good_outcome_bonus", 3))
		effects.append({ "echo_id": eid, "morale_delta": delta, "bond_target_id": "", "bond_delta": 0, "reason": "consulted" })

	# A2: not-consulted echoes get penalty
	for eid_v in not_consulted_ids:
		var eid := str(eid_v)
		effects.append({ "echo_id": eid, "morale_delta": not_consulted_delta, "bond_target_id": "", "bond_delta": 0, "reason": "not_consulted" })

	# B1/B2: rival/friend bond effects when both consulted
	for i in range(consulted_ids.size()):
		for j in range(i + 1, consulted_ids.size()):
			var a_id := str(consulted_ids[i])
			var b_id := str(consulted_ids[j])
			var bond_strength := _get_bond_strength(bonds, a_id, b_id)
			if bond_strength <= -30:
				# Rivals — one was chosen to speak
				if a_id == speaking_echo_id or b_id == speaking_echo_id:
					var jealous_id := b_id if a_id == speaking_echo_id else a_id
					effects.append({
						"echo_id": jealous_id, "morale_delta": rival_jealousy_morale,
						"bond_target_id": speaking_echo_id, "bond_delta": rival_bond_delta,
						"reason": "rival_jealousy"
					})
			elif bond_strength >= 30:
				# Friends — one was chosen to speak
				if a_id == speaking_echo_id or b_id == speaking_echo_id:
					var proud_id := b_id if a_id == speaking_echo_id else a_id
					effects.append({
						"echo_id": proud_id, "morale_delta": friend_pride_morale,
						"bond_target_id": speaking_echo_id, "bond_delta": friend_bond_delta,
						"reason": "friend_pride"
					})

	return effects


# ──────────────────────────────────────────────────────────────────────────────
# Proactive bid generation
# ──────────────────────────────────────────────────────────────────────────────

# Returns Dict keyed by echo_id -> bid_type ("alignment" / "reactive" / "")
# "alignment" = calling/vector naturally fits this NPC role
# "reactive"  = high-fear echo reacting emotionally
static func compute_bids(party_echoes: Array, contact: Dictionary, directive_id: String, cfg: Dictionary) -> Dictionary:
	var bids: Dictionary = {}
	var contact_role := str(contact.get("role", ""))
	var directive_effects_v: Variant = cfg.get("directive_effects", {})
	var directive_effects: Dictionary = directive_effects_v if directive_effects_v is Dictionary else {}

	# Map directive.scout_carefully / directive.seek_signs to short key
	var dir_key := ""
	if "seek_signs" in directive_id:
		dir_key = "seek_signs"
	elif "scout_carefully" in directive_id:
		dir_key = "scout_carefully"

	var dir_fx_v: Variant = directive_effects.get(dir_key, {})
	var dir_fx: Dictionary = dir_fx_v if dir_fx_v is Dictionary else {}
	var suppressed_callings_v: Variant = dir_fx.get("bid_suppression", [])
	var suppressed_callings: Array = suppressed_callings_v if suppressed_callings_v is Array else []
	var boosted_callings_v: Variant = dir_fx.get("bid_boost", [])
	var boosted_callings: Array = boosted_callings_v if boosted_callings_v is Array else []

	for echo_v in party_echoes:
		var echo: Dictionary = echo_v if echo_v is Dictionary else {}
		var echo_id := str(echo.get("id", ""))
		var calling := str(echo.get("calling", ""))
		if calling.is_empty():
			calling = str(echo.get("calling_origin", ""))

		# Suppression
		if calling in suppressed_callings:
			bids[echo_id] = ""
			continue

		var emo_v: Variant = echo.get("emotion", {})
		var emo: Dictionary = emo_v if emo_v is Dictionary else {}
		var fear_current := int(emo.get("fear_current", 0))

		# Reactive bid: high-fear echo
		if fear_current >= 60:
			bids[echo_id] = "reactive"
			continue

		# Alignment bid
		if _is_calling_aligned(calling, contact_role):
			bids[echo_id] = "alignment"
			continue

		# Directive boost
		if calling in boosted_callings:
			bids[echo_id] = "alignment"
			continue

		bids[echo_id] = ""

	return bids


# ──────────────────────────────────────────────────────────────────────────────
# Private helpers
# ──────────────────────────────────────────────────────────────────────────────

# Always use dominant_vector as primary signal — vector drifts are real and matter.
# Calling map is a fallback only when no vector data is available.
static func _calling_to_virtue(calling: String, echo: Dictionary) -> String:
	# Primary: dominant_vector field (written by VectorService)
	var dv := str(echo.get("dominant_vector", ""))
	if not dv.is_empty():
		match dv:
			"protector":   return "compassion"
			"vanguard":    return "courage"
			"seeker":      return "wisdom"
			"pillar":      return "acceptance"
			"opportunist": return "generosity"
			"strategist":  return "leadership"
			"skeptic":     return "truth"
			"devoted":     return "humility"
			"mediator":    return "forgiveness"
			"nurturer":    return "empathy"

	# Secondary: compute from vector_scores if dominant_vector not written yet
	var vscores_v: Variant = echo.get("vector_scores", {})
	var vscores: Dictionary = vscores_v if vscores_v is Dictionary else {}
	if not vscores.is_empty():
		var dominant := ""
		var best := -1
		for k in vscores:
			if int(vscores[k]) > best:
				best = int(vscores[k])
				dominant = str(k)
		match dominant:
			"protector":   return "compassion"
			"vanguard":    return "courage"
			"seeker":      return "wisdom"
			"pillar":      return "acceptance"
			"opportunist": return "generosity"
			"strategist":  return "leadership"
			"skeptic":     return "truth"
			"devoted":     return "humility"
			"mediator":    return "forgiveness"
			"nurturer":    return "empathy"

	# Tertiary: calling canonical virtue (no vector data at all)
	return str(_CALLING_VIRTUE_MAP.get(calling, "courage"))


# Resolve S6/S9 calling ID to its S3 parent register.
# An S6/S9 echo speaks in the same voice register as their S3 root calling.
static func _resolve_calling_register(calling: String) -> String:
	if calling in _S9_TO_S3:
		return str(_S9_TO_S3[calling])
	if calling in _S6_TO_S3:
		return str(_S6_TO_S3[calling])
	return calling  # already S3 or "uncalled"


# Map canonical 10-tier emotional_status to 3 scoring bands for resonance computation.
# Text selection uses the full 10 tiers. Resonance scoring uses these 3 bands.
static func _emotional_fit_band(status: String) -> String:
	match status:
		"radiant", "whole", "grounded", "uncertain": return "grounded"
		"hesitant", "burdened", "pressed", "strained": return "strained"
	return "broken"  # fraying, hollow


static func _is_calling_aligned(calling: String, contact_role: String) -> bool:
	match contact_role:
		"charge":         return calling in ["okofor", "onyamesu"]
		"witness":        return calling in ["okomfo", "kra_soro"]
		"guide":          return calling in ["okomfo", "kra_soro", "sum_okwanfo"]
		"claimant":       return calling in ["aduro", "okomfo"]
		"temporary_ally": return calling in ["aduro", "okofor"]
	return false


static func _derive_stat_texture(stats: Dictionary) -> String:
	var best_stat := "wis"
	var best_val  := -1
	for stat in ["atk","def","intel","agi","cha"]:
		var v := int(stats.get(stat, 0))
		if v > best_val:
			best_val  = v
			best_stat = stat
	return str(_STAT_TEXTURE_BY_DOMINANT.get(best_stat, "thoughtful"))


static func _pick_response_text(
	calling: String,
	emotional_status: String,
	virtue_alignment: String,
	response_data: Dictionary,
	t: int,
	echo_id: String,
	bid_type: String = "",
	npc_reaction_word: String = ""
) -> String:
	# Resolve S6/S9 calling to S3 parent voice register
	var register := _resolve_calling_register(calling)

	var calling_v: Variant = response_data.get(register, {})
	var calling_data: Dictionary = calling_v if calling_v is Dictionary else {}
	var status_v: Variant = calling_data.get(emotional_status, {})
	var status_data: Dictionary = status_v if status_v is Dictionary else {}

	var lines: Array = []
	var variation_key := (t + str(echo_id).hash()) % 997

	# --- Priority chain ---

	# 1. Reactive bid: high-fear echo speaking from instinct, not calling register
	if bid_type == "reactive":
		var reactive_v: Variant = status_data.get("_reactive", [])
		var reactive_lines: Array = reactive_v if reactive_v is Array else []
		if not reactive_lines.is_empty():
			return str(reactive_lines[variation_key % reactive_lines.size()])

	# 2. NPC withdrawn: echo pushes forward despite NPC pulling back (turn 1+)
	if npc_reaction_word == "Withdrawn":
		var withdrawn_v: Variant = status_data.get("_npc_withdrawn", [])
		var withdrawn_lines: Array = withdrawn_v if withdrawn_v is Array else []
		if not withdrawn_lines.is_empty():
			return str(withdrawn_lines[variation_key % withdrawn_lines.size()])

	# 3. Alignment bid: echo at their peak in-character confidence
	if bid_type == "alignment":
		var align_v: Variant = status_data.get("_alignment", {})
		if align_v is Dictionary:
			var align_pool_v: Variant = align_v.get(virtue_alignment, [])
			var align_lines: Array = align_pool_v if align_pool_v is Array else []
			if not align_lines.is_empty():
				return str(align_lines[variation_key % align_lines.size()])

	# 4. Primary: calling register × status tier × virtue path
	var virtue_v: Variant = status_data.get(virtue_alignment, [])
	lines = virtue_v if virtue_v is Array else []
	if not lines.is_empty():
		return str(lines[variation_key % lines.size()])

	# 5. Any virtue key in same calling × same tier (virtue path unavailable)
	for key in status_data:
		if str(key).begins_with("_"):
			continue  # skip registers
		var fallback_v: Variant = status_data.get(key, [])
		var fallback_lines: Array = fallback_v if fallback_v is Array else []
		if not fallback_lines.is_empty():
			return str(fallback_lines[variation_key % fallback_lines.size()])

	# 6. uncalled × same tier × virtue path
	var uncalled_v: Variant = response_data.get("uncalled", {})
	var uncalled_data: Dictionary = uncalled_v if uncalled_v is Dictionary else {}
	var uncalled_tier_v: Variant = uncalled_data.get(emotional_status, {})
	var uncalled_tier: Dictionary = uncalled_tier_v if uncalled_tier_v is Dictionary else {}
	var unc_virtue_v: Variant = uncalled_tier.get(virtue_alignment, [])
	var unc_lines: Array = unc_virtue_v if unc_virtue_v is Array else []
	if not unc_lines.is_empty():
		return str(unc_lines[variation_key % unc_lines.size()])

	# 7. Safe terminal: uncalled × grounded × virtue path (grounded is always populated)
	var unc_grounded_v: Variant = uncalled_data.get("grounded", {})
	var unc_grounded: Dictionary = unc_grounded_v if unc_grounded_v is Dictionary else {}
	var unc_gv_v: Variant = unc_grounded.get(virtue_alignment, [])
	var unc_gv_lines: Array = unc_gv_v if unc_gv_v is Array else []
	if not unc_gv_lines.is_empty():
		return str(unc_gv_lines[variation_key % unc_gv_lines.size()])

	# 8. Hardcoded fallback — should never be reached with full content library
	return "The Echo meets the moment with what they have."


# Runtime pronoun substitution.
# Content uses "She/her" as canonical. For male echoes, replace with "He/his/him/himself".
# First-person "I" lines and "The [Calling] says:" lines are unaffected.
static func _substitute_pronouns(text: String, gender: String) -> String:
	if gender != "male":
		return text
	return text \
		.replace("She says:", "He says:") \
		.replace("She says,", "He says,") \
		.replace("She says.", "He says.") \
		.replace("She says —", "He says —") \
		.replace("She says ", "He says ") \
		.replace("She speaks", "He speaks") \
		.replace("She breathes", "He breathes") \
		.replace("She exhales", "He exhales") \
		.replace("She pauses", "He pauses") \
		.replace("She presses", "He presses") \
		.replace("She grits", "He grits") \
		.replace("She tightens", "He tightens") \
		.replace("She steadies", "He steadies") \
		.replace("She catches", "He catches") \
		.replace("She shudders", "He shudders") \
		.replace("She fights", "He fights") \
		.replace("She does not", "He does not") \
		.replace("She does ", "He does ") \
		.replace("She is ", "He is ") \
		.replace("She has ", "He has ") \
		.replace("She will ", "He will ") \
		.replace("She would ", "He would ") \
		.replace("She can ", "He can ") \
		.replace("She could ", "He could ") \
		.replace("She keeps ", "He keeps ") \
		.replace("She holds ", "He holds ") \
		.replace("She moves ", "He moves ") \
		.replace("She looks ", "He looks ") \
		.replace("She turns ", "He turns ") \
		.replace("She stays ", "He stays ") \
		.replace("She remains ", "He remains ") \
		.replace("She meets ", "He meets ") \
		.replace("She comes ", "He comes ") \
		.replace("She knows ", "He knows ") \
		.replace("She feels ", "He feels ") \
		.replace("She nods ", "He nods ") \
		.replace("She — ", "He — ") \
		.replace("herself", "himself") \
		.replace("her voice", "his voice") \
		.replace("her eyes", "his eyes") \
		.replace("her own", "his own") \
		.replace("her hands", "his hands") \
		.replace("her jaw", "his jaw") \
		.replace("her body", "his body") \
		.replace("her teeth", "his teeth") \
		.replace("her breath", "his breath") \
		.replace("her face", "his face") \
		.replace("her words", "his words") \
		.replace("her line", "his line") \
		.replace("her back", "his back") \
		.replace("her position", "his position")


static func _get_bond_strength(bonds: Array, a_id: String, b_id: String) -> int:
	# Canonical key: alphabetical order
	var ka := a_id if a_id < b_id else b_id
	var kb := b_id if a_id < b_id else a_id
	for bond_v in bonds:
		var bond: Dictionary = bond_v if bond_v is Dictionary else {}
		if str(bond.get("actor_a", "")) == ka and str(bond.get("actor_b", "")) == kb:
			return int(bond.get("strength", 0))
	return 0

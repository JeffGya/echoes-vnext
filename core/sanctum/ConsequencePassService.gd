# ConsequencePassService — V2-SANCTUM-001
# Read-only. No mutations. Builds consequence groups for snapshot injection.
# Called by FlowRuntime at the three run-return insertion points:
#   - _handle_complete_stage (victory)
#   - flow.go_state(to=SANCTUM) from RESOLVE (defeat)
#   - _handle_encounter_retreat (withdrawal)
#
# Consequence group shape:
#   { type: String, label: String, entries: Array[{ summary, signal, delta }] }
#
# Return shape:
#   { run_outcome: String, groups: Array[consequence_group] }
#   {} when there is no run to report.

class_name ConsequencePassService

extends RefCounted


## Collects consequence groups for a completed run and returns the run_consequence dict.
## resolve_snap: ctx.last_snapshot at call time (flow.resolve or fallback).
## run_outcome: "victory" | "defeat" | "withdrawal".
## vow_released: true when VowService.release_vow() just fired for this transition.
## cfg: full balance.json dict (config_service.get_balance()).
static func collect(
	resolve_snap: Dictionary,
	run_outcome:  String,
	save_data:    Dictionary,
	vow_released: bool,
	cfg:          Dictionary
) -> Dictionary:
	var groups: Array = []

	var snap_data: Dictionary = {}
	if resolve_snap.has("data") and resolve_snap["data"] is Dictionary:
		snap_data = resolve_snap["data"]

	# --- Economy group (always present) ---
	var econ_group := _build_economy_group(snap_data, run_outcome)
	if not econ_group.is_empty():
		groups.append(econ_group)

	# --- Emotion group (always present) ---
	var emo_group := _build_emotion_group(save_data)
	if not emo_group.is_empty():
		groups.append(emo_group)

	# --- Vow group (conditional) ---
	var vow_group := _build_vow_group(save_data, vow_released, cfg)
	if not vow_group.is_empty():
		groups.append(vow_group)

	# --- Intel group (conditional) ---
	var intel_group := _build_intel_group(save_data)
	if not intel_group.is_empty():
		groups.append(intel_group)

	return {
		"run_outcome": run_outcome,
		"groups":      groups,
	}


# ---------------------------------------------------------------------------
# Group builders
# ---------------------------------------------------------------------------

static func _build_economy_group(snap_data: Dictionary, run_outcome: String) -> Dictionary:
	var ase_awarded := int(snap_data.get("ase_awarded", 0))
	var rank        := str(snap_data.get("rank", ""))
	var victory     := bool(snap_data.get("victory", false))

	var entries: Array = []

	if ase_awarded > 0:
		entries.append({
			"summary": "+%d Ase" % ase_awarded,
			"signal":  "gain",
			"delta":   ase_awarded,
		})
	elif not victory:
		entries.append({
			"summary": "No Ase earned",
			"signal":  "loss",
			"delta":   0,
		})
	else:
		entries.append({
			"summary": "0 Ase",
			"signal":  "neutral",
			"delta":   0,
		})

	if not rank.is_empty():
		entries.append({
			"summary": "Rank %s" % rank,
			"signal":  _rank_signal(rank),
			"delta":   0,
		})

	return { "type": "economy", "label": "Rewards", "entries": entries }


static func _build_emotion_group(save_data: Dictionary) -> Dictionary:
	var sanctum_v: Variant = save_data.get("sanctum", {})
	if not (sanctum_v is Dictionary):
		return {}
	var sanctum: Dictionary = sanctum_v

	var roster_v: Variant = sanctum.get("roster", [])
	var roster: Array = roster_v if roster_v is Array else []

	var party_ids_v: Variant = sanctum.get("active_party_ids", [])
	var party_ids: Array = party_ids_v if party_ids_v is Array else []

	if party_ids.is_empty():
		return {}

	var entries: Array = []

	for pid_v in party_ids:
		var pid := str(pid_v)
		if pid.is_empty():
			continue
		for echo_v in roster:
			if not (echo_v is Dictionary):
				continue
			var echo: Dictionary = echo_v
			if str(echo.get("id", "")) != pid:
				continue

			var emo_v: Variant = echo.get("emotion", {})
			var emo: Dictionary = emo_v if emo_v is Dictionary else {}
			var morale  := int(emo.get("morale_current", 50))
			var fear    := int(emo.get("fear_current",   0))
			var status  := EmotionService.get_emotional_status(morale, fear)
			var name    := str(echo.get("name", "Echo"))

			# Build signal from emotional status
			var signal_str := _emotional_status_to_signal(status)

			entries.append({
				"summary": "%s — %s" % [name, status],
				"signal":  signal_str,
				"delta":   0,
			})
			break

	if entries.is_empty():
		return {}

	return { "type": "emotion", "label": "The House", "entries": entries }


static func _build_vow_group(save_data: Dictionary, vow_released: bool, cfg: Dictionary) -> Dictionary:
	if vow_released:
		return {
			"type":  "vow",
			"label": "Vow",
			"entries": [{
				"summary": "Vow fulfilled",
				"signal":  "gain",
				"delta":   0,
			}],
		}

	var active_vow := VowService.get_active_vow(save_data)
	if active_vow.is_empty():
		return {}

	var vow_id  := str(active_vow.get("vow_id", ""))
	var defn    := VowService.get_definition(vow_id, cfg)
	var proverb := str(defn.get("proverb_twi", ""))
	if proverb.is_empty():
		proverb = str(defn.get("proverb_en", ""))
	if proverb.is_empty():
		return {}

	return {
		"type":  "vow",
		"label": "Vow",
		"entries": [{
			"summary": proverb,
			"signal":  "neutral",
			"delta":   0,
		}],
	}


static func _build_intel_group(save_data: Dictionary) -> Dictionary:
	# Find the active realm and its current stage's explore_map
	var realms_v: Variant = save_data.get("realms", {})
	if not (realms_v is Dictionary):
		return {}
	var realms: Dictionary = realms_v

	var active_realm: Dictionary = {}
	for rid in realms:
		var rm_v: Variant = realms[rid]
		if not (rm_v is Dictionary):
			continue
		var rm: Dictionary = rm_v
		if str(rm.get("status", "")) == RealmModel.STATUS_ACTIVE:
			active_realm = rm
			break

	if active_realm.is_empty():
		return {}

	var stage_index := int(active_realm.get("current_stage_index", 0))
	var stages_v: Variant = active_realm.get("stages", [])
	if not (stages_v is Array):
		return {}
	var stages: Array = stages_v

	if stage_index < 0 or stage_index >= stages.size():
		return {}

	var stage_v: Variant = stages[stage_index]
	if not (stage_v is Dictionary):
		return {}
	var stage: Dictionary = stage_v

	var em_v: Variant = stage.get("explore_map", {})
	if not (em_v is Dictionary):
		return {}
	var em: Dictionary = em_v

	var obj_found := int(em.get("objectives_found", 0))
	var obj_total := int(em.get("objectives_total", 0))

	if obj_total <= 0:
		return {}

	return {
		"type":  "intel",
		"label": "Signs Read",
		"entries": [{
			"summary": "%d / %d signs resolved" % [obj_found, obj_total],
			"signal":  "gain" if obj_found >= obj_total else "neutral",
			"delta":   0,
		}],
	}


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

static func _rank_signal(rank: String) -> String:
	match rank:
		"S", "A":
			return "gain"
		"B", "C":
			return "neutral"
		_:
			return "loss"


static func _emotional_status_to_signal(status: String) -> String:
	match status:
		"radiant", "whole":
			return "gain"
		"grounded", "uncertain":
			return "neutral"
		_:
			return "warning"

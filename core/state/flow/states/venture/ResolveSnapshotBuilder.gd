class_name ResolveSnapshotBuilder

extends RefCounted

## V2-INFRA-003 Phase 5 Slice B — composition model for the flow.resolve snapshot.
##
## Specification: docs/resolve-snapshot-block-spec.md (§4 API, §5 phase split).
##
## PURITY CONTRACT — stronger than SanctumSnapshotBuilder's.
## This builder takes NO FlowContext at all. Every input is a plain value the producer has
## already computed. It therefore cannot read save_data, cannot mutate FlowContext, cannot
## call request_save(), and cannot construct a service whose constructor can write (in
## particular never SanctumService.new(), whose SanctumState constructor can write to
## save_data via _ensure_sanctum_dict_exists()). Two calls with the same arguments produce
## byte-identical payloads — pinned by
## tests/FlowSnapshotFingerprintTests.gd snapshot_purity/resolve_builder_double_build_is_stable.
##
## COMPOSITION MODEL — no manifest, no flags.
## `build()` returns the skeleton; `data` starts empty except for `run_type` when non-empty.
## A producer declares which sections it emits by CALLING the add_* functions it wants, in
## any order. There is no `include_x: bool` anywhere, by design: the irregularity in the six
## measured payloads is absorbed by block granularity instead of by conditional logic inside
## a block. A missing `add_ekwan(...)` line is visible at the call site; a flipped default is
## not. See spec §2.3/§2.4 for the alternatives that were rejected and why.
##
## Every block writes into the `data` Dictionary returned inside the skeleton (GDScript
## Dictionaries are passed by reference) and returns void.
##
## The block library is the `add_*` functions below. Which producer emits which is the table in
## docs/resolve-snapshot-block-spec.md §4.3 — check it before removing a block that looks unused.


# ---------------------------------------------------------------------------
# Base
# ---------------------------------------------------------------------------

## Returns the flow.resolve skeleton.
##
## `actions` is stored BY REFERENCE — build the slot-keyed action Dictionary first and pass
## it in. It is never an Array (AGENTS.md common mistake #1).
##
## `run_type` is the one key that is not a screen section: it is the router
## ResolveScreen._render() branches on. It is written only when non-empty. No producer ever
## sets it to "", and A/B/F omit it entirely and fall through to the combat renderer, so the
## empty sentinel is safe. Never give it a non-empty default — that would silently re-route
## three producers to another renderer.
static func build(t: int, actions: Dictionary, run_type: String = "") -> Dictionary:
	var data: Dictionary = {}
	if not run_type.is_empty():
		data["run_type"] = run_type
	return {
		"type":    FlowStateIds.RESOLVE,
		"meta":    { "t": t },
		"data":    data,
		"actions": actions,
	}


# ---------------------------------------------------------------------------
# Blocks
# ---------------------------------------------------------------------------

## 1 — Banner + Summary zone. %BannerLabel / %SummaryLabel. Producers A, C, D, E.
static func add_banner(data: Dictionary, surface: String, summary_line: String) -> void:
	data["surface"]      = surface
	data["summary_line"] = summary_line


## 2 — Banner VICTORY/DEFEAT text (combat renderer only). Producers A, B, C, F.
static func add_victory_flag(data: Dictionary, victory: bool) -> void:
	data["victory"] = victory


## 3 — %RankBadge, S–F vocabulary. Producers A, B, C.
static func add_grade_rank(data: Dictionary, rank: String) -> void:
	data["rank"] = rank


## 4 — %RankBadge, carried/passed/good/partial/missed vocabulary. Same screen slot as #3,
## which is why they are two blocks rather than one. Producers C, D, E.
##
## KNOWN DEFECT (V2-INFRA-003 Phase 5 records; a later story fixes): producer D writes
## `verdict` and nothing ever reads it — ResolveScreen's contact renderer sets
## `_rank_badge.visible = false` unconditionally.
static func add_grade_verdict(data: Dictionary, verdict: String) -> void:
	data["verdict"] = verdict


## 5 — Reason line + stat readout. %ReasonLabel, %EnemiesDefeatedValue, %EchoesAliveValue,
## %RoundsValue. `encounter_id` and `objective_state` are not read by the UI (objective_state
## IS fingerprinted by FlowFingerprintTests). Producers A, B. Unused until Phase 6.
static func add_combat_stats(
		data: Dictionary,
		encounter_id: String,
		reason: String,
		round_ended: int,
		enemies_defeated: int,
		echoes_survived: int,
		objective_state: Dictionary
) -> void:
	data["encounter_id"]     = encounter_id
	data["reason"]           = reason
	data["round_ended"]      = round_ended
	data["enemies_defeated"] = enemies_defeated
	data["echoes_survived"]  = echoes_survived
	data["objective_state"]  = objective_state


## 6 — Echo stage / actor preview. Producers A, B, C.
##
## Deliberately SHAPE-AGNOSTIC: it takes an Array and writes it. A and B pass
## _project_actor() combat rows; C passes a four-field party preview under the same key.
## Those shapes are incompatible and that is the measured behaviour today — the shape stays
## the producer's business, exactly as before.
static func add_actors(data: Dictionary, actors: Array) -> void:
	data["actors"] = actors


## 7 — Ase value + breakdown + Ase EffectChip. Producers A, B, C, E.
## Deliberately excludes ekwan_awarded: B sets ase + breakdown but NOT ekwan. See #8.
static func add_ledger(data: Dictionary, ase_awarded: int, reward_breakdown: Array) -> void:
	data["ase_awarded"]      = ase_awarded
	data["reward_breakdown"] = reward_breakdown


## 7b — Whether the player has already seen a result ledger (`SaveSchema.ledger_seen`), so the
## UI opens the ledger only the first time. Read-only here; the dispatched action
## `resolve.ledger.mark_seen` writes it. Producers that emit a ledger call this beside add_ledger.
static func add_ledger_seen(data: Dictionary, seen: bool) -> void:
	data["ledger_seen"] = seen


## 7c — Preview of the stage payout the next `flow.complete_stage` will pay: Ase rows with
## `cause`/`params`, and the Ase and Ekwan totals (Ekwan has no rows). Only the card that offers
## that action carries it.
static func add_stage_payout(data: Dictionary, rows: Array, ase: int, ekwan: int) -> void:
	data["stage_payout_rows"]  = rows
	data["stage_payout_ase"]   = ase
	data["stage_payout_ekwan"] = ekwan


## 8 — %EkwanRow / %EkwanValue + Ekwan EffectChip, gated on `> 0` by the screen. Producers
## A, C, E. Its own block rather than a `ledger(include_ekwan)` flag because it is its own
## screen section AND because B omits it — see spec §2.3.
static func add_ekwan(data: Dictionary, ekwan_awarded: int) -> void:
	data["ekwan_awarded"] = ekwan_awarded


## 9 — %EmotionList rows via EmotionEntryItem. Producers A, B, E.
##
## A and B now emit the same eight keys, in the same order, from the same derivation.
## The block writes whatever Array it is given — the entry shape stays the producer's business.
static func add_emotion(data: Dictionary, emotion_summary: Array) -> void:
	data["emotion_summary"] = emotion_summary


## 10 — %VowOutcomeSection + %VowDiscoveredSection + vow EffectChip. Producer A.
## Unused until Phase 6.
static func add_vows(data: Dictionary, vow_outcome: Dictionary, newly_unlocked_vows: Array) -> void:
	data["vow_outcome"]         = vow_outcome
	data["newly_unlocked_vows"] = newly_unlocked_vows


## 11 — %EffectsRail extras. Producer E.
static func add_effects(data: Dictionary, effects: Array) -> void:
	data["effects"] = effects


## 12 — Data seam, NOT a screen section: ResolveScreen reads none of these three.
## `xp_events` is consumed elsewhere (EchoParty). Producers A, B. Unused until Phase 6.
static func add_progression(
		data: Dictionary,
		formula_inputs: Dictionary,
		relics: Array,
		xp_events: Array
) -> void:
	data["formula_inputs"] = formula_inputs
	data["relics"]         = relics
	data["xp_events"]      = xp_events


## 13 — Routing / future seams, NOT a screen section. `objectives_remaining` shapes A's own
## action set before the snapshot is built; `guide_spirit_protected` is a V2-ITEM-002 seam;
## `combat_intro_line` is S15 prep. Producer A. Unused until Phase 6.
static func add_combat_seams(
		data: Dictionary,
		objectives_remaining: int,
		guide_spirit_protected: bool,
		combat_intro_line: String
) -> void:
	data["objectives_remaining"]   = objectives_remaining
	data["guide_spirit_protected"] = guide_spirit_protected
	data["combat_intro_line"]      = combat_intro_line


## 14b — Situations a combat victory revealed during the fight. Written only when above 0, so a
## card that revealed nothing keeps the key list it had before this block existed.
static func add_intel_gained(data: Dictionary, gained: int) -> void:
	if gained > 0:
		data["intel_gained"] = gained


## 14c — Whether no party Echo has died in the stage so far (D-50). Combat victory card only.
static func add_thread_whole(data: Dictionary, whole: bool) -> void:
	data["thread_whole"] = whole


## 14d — The objective THIS fight overcame: { index, type, label }. Written only when one was.
static func add_objective_overcome(data: Dictionary, overcome: Dictionary) -> void:
	if not overcome.is_empty():
		data["objective_overcome"] = overcome


## 14f — Ase found on this card that now waits in the packs. It is NOT in `ase_awarded`: nothing reaches
## the balance until a leave or the path end. Written only when above 0. Situation and Claimant cards.
static func add_ase_gathered(data: Dictionary, gathered: int) -> void:
	if gathered > 0:
		data["ase_gathered"] = gathered


## 14g — What the item entries of a leave became: `{ kept: [row], lost: [row] }`, rows from
## `EarningsService.report_row` (type_id, kind, grade, quantity, reason_key, source, mark_index; no id).
## Written only when a row exists. Producers C and G (a return home). The caller passes a non-empty report.
static func add_items(data: Dictionary, items: Dictionary) -> void:
	if not items.is_empty():
		data["items"] = items.duplicate(true)


## 14 — %ReasonLabel, "%d situation%s revealed". Producer C.
static func add_scout_intel(data: Dictionary, intel_count: int) -> void:
	data["intel_count"] = intel_count


## 14e — The word for what a return home settled: "none", "some", "all" or "nothing_new". Producer C
## on a return home only. A word, never a share: the player sees no percent and no odds.
static func add_settle_outcome(data: Dictionary, outcome: String) -> void:
	data["settle_outcome"] = outcome


## 15 — Banner text + banner colour + %ReasonLabel on the contact renderer. Producer D.
static func add_contact_outcome(
		data: Dictionary,
		role: String,
		role_label: String,
		outcome: String,
		outcome_text: String
) -> void:
	data["role"]         = role
	data["role_label"]   = role_label
	data["outcome"]      = outcome
	data["outcome_text"] = outcome_text


## 16 — Pace result (docs/stories/pace-reward/design.md §6-§7). Producers A and G, pace-mode wins only:
## the call is the gate, so a no-pace fight or a defeat carries none of these keys.
## pace_changed_rank is true when the pace points moved the grade. Speed pays no Ase (D-49).
static func add_pace(data: Dictionary, pace_state: String, pace_changed_rank: bool) -> void:
	data["pace_state"]         = pace_state
	data["pace_changed_rank"]  = pace_changed_rank


## 17 — The standoff card (D-116). Producers H2 and G. Words and names only: no amount, no percent, no odds.
## `cause` is "froze", "blocked" or "unknown". Names are display names, at most two each.
static func add_standoff(data: Dictionary, standoff_count: int, can_go_sanctum: bool, cause: String,
		froze_names: Array, calmed_names: Array, fight_returns: bool = true) -> void:
	data["standoff_outcome"] = "nobody_moved"
	data["standoff_count"]   = standoff_count
	data["can_go_sanctum"]   = can_go_sanctum
	data["cause"]            = cause
	data["froze_names"]      = froze_names
	data["calmed_names"]     = calmed_names
	data["fight_returns"]    = fight_returns

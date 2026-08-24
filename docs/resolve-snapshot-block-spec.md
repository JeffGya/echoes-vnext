# `ResolveSnapshotBuilder` — block specification

> **Status:** design only. No code written. V2-INFRA-003 Phase 5 (producers C/D/E/F) + Phase 6 (A/B).
> **Source of truth:** measured by reading the six producers on branch
> `claude/v2-infra-003-proof-spine-b3c770`, 2026-08-16. Every table below is read off the source,
> not off any prior summary.

---

## 0. Line-number corrections to the brief

| # | Producer | Brief said | Actual | Note |
|---|---|---|---|---|
| A | Combat | `build_final_snapshot` return @ 1953–1988 | **1958–1998** | function starts 1612; return dict is 1958–1998 |
| B | Keeper trial | `_build_keeper_intro_final_snapshot` 2070–2122 | **2070–2127** | function starts 2070 ✓; return dict is 2090–2127 |
| C | Scout return | `_build_scout_return_snapshot` 4326–4381 | **4326–4381** ✓ | |
| D | Contact | `_build_contact_resolve_snapshot` 6070–6117 | **6070–6117** ✓ | |
| E | Situation | `_build_situation_resolve_snapshot` 6124–6169 | **6124–6169** ✓ | |
| F | Fallback | `FlowResolveState.enter` 19–34 | **19–35** | `meta` on 34, dict closes 35 |

**Verified claim:** producer C emits `"meta": { "sim_tick": t }`. All five others emit `{ "t": t }`.
The claim is **correct** — and it is worse than a cosmetic inconsistency. See §6.1.

---

## 1. Measured payloads

### 1.1 `meta` and `actions`

| P | `meta` | `actions` slots |
|---|---|---|
| A | `{ t: int }` | `_build_resolve_actions(victory, objectives_remaining)`: always `cta.continue`; plus `cta.next_stage` iff `victory and objectives_remaining == 0`. Types: victory+0 → `flow.complete_stage` (`destination` = SANCTUM) + `flow.complete_stage`; victory+n → `flow.go_state` → STAGE_EXPLORE; defeat → `flow.go_state` → SANCTUM |
| B | `{ t: int }` | `cta.continue` only. victory → `{type:"keeper_intro.trial.finish", label:"Carry It Home"}`; defeat → `{type:"flow.go_state", to:KEEPER_TRIAL, label:"Try Again"}` |
| C | **`{ sim_tick: int }`** | `cta.continue` = `flow.go_state` → SANCTUM, label `"Return to Sanctum"` |
| D | `{ t: int }` | `cta.continue` = `flow.go_state`; `to`/`label` = STAGE_EXPLORE/`"Return to Stage"` when `go_back_to_stage`, else SANCTUM/`"Return to Sanctum"` |
| E | `{ t: int }` | `cta.continue` = `flow.go_state` → STAGE_EXPLORE, label `"Return to Stage"` |
| F | `{ t: int }` | `cta.continue` = `flow.go_state` → SANCTUM, label `"Return to Sanctum"` |

Every action dict carries `slot: "cta.continue"` / `"cta.next_stage"`. No producer emits an Array.
Top-level key order differs (A/B/F: type,data,actions,meta — C/E: type,meta,data,actions —
D: type,data,actions,meta). **Order is not load-bearing**: no test JSON-hashes a whole resolve
snapshot, and `FlowFingerprintTests._final_fingerprint()` sorts `data_keys`.

### 1.2 `data` — full key matrix

`●` = set. Constants are given in the cell. Blank = **key absent**.

| Key | Type | A combat | B keeper | C scout | D contact | E situation | F fallback |
|---|---|---|---|---|---|---|---|
| `title` | String | `"Result"` | `"Result"` | | | | `"Resolve"` |
| `note` | String | | | | | | `"Result unavailable."` |
| `run_type` | String | | | `"scout_return"` | `"contact_result"` | `"situation_result"` | |
| `encounter_id` | String | ● | `"keeper_intro.first_trial"` | | | | |
| `actors` | Array[Dict] | ● *(combat projection)* | ● *(combat projection)* | ● *(party preview — different shape)* | | | |
| `objective_state` | Dictionary | ● | ● | | | | |
| `victory` | bool | ● | ● | `false` | | | `false` |
| `reason` | String | ● | ● | | | | |
| `round_ended` | int | ● | ● | | | | |
| `enemies_defeated` | int | ● | ● | | | | |
| `echoes_survived` | int | ● | ● | | | | |
| `rank` | String | ● (S–F) | `"A"` / `"F"` | `""` | | | |
| `ase_awarded` | int | ● | ● / `0` | ● | | ● | |
| `ekwan_awarded` | int | ● | | `0` | | `0` | |
| `reward_breakdown` | Array | ● | ● / `[]` | ● | | ● | |
| `formula_inputs` | Dictionary | ● | `{}` | | | | |
| `relics` | Array | `[]` | `[]` | | | | |
| `xp_events` | Array | ● | `[]` | | | | |
| `emotion_summary` | Array | ● *(+`direction`,`tag`)* | ● *(no `direction`/`tag`)* | | | ● *(+`direction`,`tag`,`bark`)* | |
| `vow_outcome` | Dictionary | ● | | | | | |
| `newly_unlocked_vows` | Array | ● | | | | | |
| `objectives_remaining` | int | ● | | | | | |
| `surface` | String | ● (obj type) | | `"scout_return"` | `"npc_contact"` | ● (situation type) | |
| `summary_line` | String | ● | | ● | ● (= `outcome_text`) | ● | |
| `verdict` | String | | | `""` | ● | ● | |
| `guide_spirit_protected` | bool | ● | | | | | |
| `combat_intro_line` | String | ● | | | | | |
| `intel_count` | int | | | ● | | | |
| `role` | String | | | | ● | | |
| `role_label` | String | | | | ● | | |
| `outcome` | String | | | | ● | | |
| `outcome_text` | String | | | | ● | | |
| `effects` | Array | | | | | ● | |
| **key count** | | **24** | **16** | **11** | **8** | **9** | **3** |

**The irregularities that constrain the design** (all confirmed against source, not inherited):

1. `ekwan_awarded` — A, C, E set it; **B omits it** while still setting `ase_awarded` and
   `reward_breakdown`. (Brief's example: confirmed.)
2. `run_type` — **A, B and F omit it entirely**; C/D/E set it. It is the UI's branch router (§3).
3. `verdict` vs `rank` — the same screen slot, two vocabularies. A/B/C set `rank`; C/D/E set
   `verdict`; **C sets both** (`rank:""`, `verdict:""`).
4. `victory` — A/B real; C and F emit constant `false`; **D and E omit it**.
5. `actors` — A/B carry `_project_actor()` combat rows; **C carries a four-field party preview
   under the same key**. Same key, incompatible shapes.
6. `emotion_summary` entry shape differs by producer: A adds `direction` + `tag`; **B has neither**;
   E has both plus `bark`.
7. `ase_awarded` — A, B, C, E set it; **D omits it**.
8. `title` / `note` are **dead**: no consumer anywhere in `ui/`, `core/` or `tests/` reads either.

---

## 2. Proposed block set

### 2.1 Design rule

One block per **distinct producer-subset**, named for the screen section it feeds where one exists.
This is the smallest set that satisfies the hard constraint **with zero opt-out flags** — the
irregularity is absorbed by block granularity instead of by conditional logic inside a block. A
producer declares its blocks by **calling the `add_*` functions it wants**, in any order. There is
no manifest, no flag, no `include_x: bool`.

`run_type` is the one exception: it is not a section, it is the router that selects which sections
render. It is an optional argument on `build()`, written only when non-empty (no producer ever sets
it to `""`, so the sentinel is safe).

### 2.2 The blocks

| # | Block | Keys | Producers | Screen section (§3) |
|---|---|---|---|---|
| — | `build` (base) | `type`, `meta.t`, empty `data`, `actions`, optional `run_type` | all 6 | routing only |
| 1 | `banner` | `surface`, `summary_line` | A, C, D, E | Banner + Summary zone |
| 2 | `victory_flag` | `victory` | A, B, C, F | Banner VICTORY/DEFEAT |
| 3 | `grade_rank` | `rank` | A, B, C | Rank badge |
| 4 | `grade_verdict` | `verdict` | C, D, E | Verdict badge (same slot as #3) |
| 5 | `combat_stats` | `encounter_id`, `reason`, `round_ended`, `enemies_defeated`, `echoes_survived`, `objective_state` | A, B | Reason line + stat readout |
| 6 | `actors` | `actors` | A, B, C | Echo stage / actor preview |
| 7 | `ledger` | `ase_awarded`, `reward_breakdown` | A, B, C, E | Ase value + breakdown + Ase chip |
| 8 | `ekwan` | `ekwan_awarded` | A, C, E | Ekwan row + Ekwan chip |
| 9 | `emotion` | `emotion_summary` | A, B, E | Echo stage rows |
| 10 | `vows` | `vow_outcome`, `newly_unlocked_vows` | A | Vow outcome + Vow discovered + vow chip |
| 11 | `effects` | `effects` | E | Effects rail extras |
| 12 | `progression` | `formula_inputs`, `relics`, `xp_events` | A, B | **none — not rendered** |
| 13 | `combat_seams` | `objectives_remaining`, `guide_spirit_protected`, `combat_intro_line` | A | **none — routing / future seams** |
| 14 | `scout_intel` | `intel_count` | C | Reason line ("N situations revealed") |
| 15 | `contact_outcome` | `role`, `role_label`, `outcome`, `outcome_text` | D | Banner colour + reason text |
| 16 | `legacy_title` | `title` | A, B, F | **none — dead key** |
| 17 | `legacy_note` | `note` | F | **none — dead key** |

### 2.3 Blocks that are partial or forced

Under this model **no block needs an opt-out flag**. Every place the brief expected one, the fix
was a finer boundary. Recorded here so the boundary is not "simplified" back later:

| Would-be flag | Exact key | Producer that forces it | Why the split is cleaner |
|---|---|---|---|
| `ledger(include_ekwan)` | `ekwan_awarded` | **B (keeper trial)** sets `ase_awarded` + `reward_breakdown` but not `ekwan_awarded` | Ekwan is its own effects-rail chip and its own `%EkwanRow`, gated independently on `> 0`. It is genuinely a separate section, so block #8 is a screen-truthful boundary, not a workaround. |
| `banner(include_run_type, include_verdict)` | `run_type`, `verdict` | **A (combat)** omits both while setting `surface` + `summary_line` | `run_type` is the router (base arg). `verdict` occupies the same badge slot as `rank` — two vocabularies for one section, so #3/#4 is the honest split. |
| `combat_stats(include_victory)` | `victory` | **C and F** set `victory` alone, with no other combat stat | `victory` is the banner's own input; the stat readout is a different row. Splitting #2 out of #5 is correct on the screen too. |
| `actors(shape)` | `actors` | **C** puts a 4-field preview under the key A/B use for combat rows | Block #6 is deliberately shape-agnostic — it takes an `Array` and writes it. The shape is the producer's business, exactly as today. |

### 2.4 Alternative considered and rejected

**Alternative: eight coarse "screen zone" blocks with boolean opt-outs** —
`banner(surface, summary_line, run_type := "", verdict := "")`,
`ledger(ase, breakdown, include_ekwan := true, ekwan := 0)`,
`outcome(victory, reason, rounds, …, include_stats := true)`, etc.

Rejected for three reasons:

1. **It loses the property the product owner asked for.** The stated intent is that a later story
   can add or remove a section *without touching the other producers*. With flags, the flag lives in
   a signature shared by four producers; changing what a flag means, or adding a fifth flag, edits a
   call site in every one of them. With fine-grained blocks, adding a section is one new `add_*` plus
   a call in the producers that want it, and removing one is deleting calls. Zero cross-talk.
2. **Flags make omission implicit.** `include_ekwan := true` means the exact behaviour under test —
   "B must not emit this key" — is expressed by a default that is easy to flip by accident and
   invisible at the call site. A missing `add_ekwan(...)` line is visible.
3. **It does not actually shrink the API.** Eight functions with fourteen flags is more surface than
   seventeen flat functions, and the flags are untyped intent while the functions are self-documenting.

The cost of the recommended model is honest and should be stated: **seventeen blocks, five of which
are single-key, and three of which map to no screen section at all** (#12, #13, #16/#17). Those are
not design failures — they are the measured shape of the payload made visible. #16 and #17 are
flagged for deletion (§7 Q3).

---

## 3. Blocks vs. screen sections

**The UI is `ui/screens/venture/ResolveScreen.gd`**, presented as modal id `realm.resolve`:
`RealmShell._show_overlay_for_type()` (line 204) keeps `flow.resolve` out of `_scene_by_flow_type`
and emits the modal; `AppRoot` mounts it through the layer-40 `ModalHost`.
`ResolveScreen._render()` branches on `data.run_type` into four renderers.

### 3.1 The critical question: is key ABSENCE load-bearing?

**No. Not anywhere in the current UI.** Every read in `ResolveScreen.gd` is
`data.get(key, <default>)` — there is not one `data.has(...)` call in the file. Absent and
"empty" are therefore indistinguishable to the screen for every key, with three defaults worth
naming:

| Key | Default on absence | Consequence |
|---|---|---|
| `rank` | **`"F"`** (line 163) — *not* `""` | F omits `rank`, so the fallback scaffold renders an "F" badge. That is semantically right for a failure scaffold, but it is a default doing work. |
| `role_label` | `"Contact"` | only D reaches that branch, and D always sets it |
| `outcome_text` | `"The conversation has ended."` | same — only D reaches it, and D always sets it |
| everything else | `""` / `0` / `false` / `[]` / `{}` | absence ≡ empty |

**Therefore key omission is currently cosmetic, not load-bearing — with one exception that is
*value*-bearing rather than absence-bearing:** `run_type`. `str(data.get("run_type",""))` picks the
renderer. A, B and F omit it and fall into the combat renderer by default. **If the builder ever
wrote `run_type` unconditionally — even as `""` — behaviour would still be identical**, because `""`
matches no branch. So `run_type` is the one key where the *value* selects a whole screen, and the
one place a careless default (e.g. writing `"combat"`) would silently break A, B and F.

Sections that show or hide do so on **value**, never on presence:
`_ekwan_row.visible = ekwan_awarded > 0`; `_effects_rail.visible = chips_added > 0`;
`_vow_section` returns early if `vow_outcome.is_empty()`; `_vow_discovered_section` returns early if
`newly_unlocked_vows.is_empty()`; `_summary_label.visible` set only when `summary_line` is non-empty;
`_rank_badge.visible = false` on the scout and contact branches regardless of the key.

Because of this, the fine-grained block model is **strictly safer than it needs to be for the UI** —
but it still has to hold, because `FlowFingerprintTests` pins A's exact `data_keys` set (§6.2).

### 3.2 Per-block mapping

| Block | Visible? | Where |
|---|---|---|
| 1 `banner` | yes | `%BannerLabel` (combat/scout/contact/situation all set it), `%SummaryLabel` |
| 2 `victory_flag` | yes (combat branch only) | banner text `"VICTORY"`/`"DEFEAT"` |
| 3 `grade_rank` | yes (combat branch only) | `%RankBadge` + `_rank_color()` |
| 4 `grade_verdict` | yes (situation branch only) | `%RankBadge` + `_verdict_color()`. **D sets `verdict` but the contact renderer hides the badge — D's `verdict` is currently unread.** |
| 5 `combat_stats` | partly | `%ReasonLabel`, `%EnemiesDefeatedValue`, `%EchoesAliveValue`, `%RoundsValue`. `encounter_id` and `objective_state` are **not read by the UI** (objective_state *is* fingerprinted). |
| 6 `actors` | yes | combat: `arrival_bark` lookup only, plus `RealmShell._update_echo_bar()` filters `data.actors`. scout: the actor preview label list. |
| 7 `ledger` | yes | `%AseValue`, `_build_breakdown()`, Ase `EffectChip` |
| 8 `ekwan` | yes | `%EkwanRow` / `%EkwanValue`, Ekwan `EffectChip` |
| 9 `emotion` | yes | `%EmotionList` rows via `EmotionEntryItem`; `direction`/`tag` drive token colour + cue + KO tag |
| 10 `vows` | yes | `%VowOutcomeSection`, `%VowDiscoveredSection`, vow `EffectChip` |
| 11 `effects` | yes | `%EffectsRail` extras |
| 12 `progression` | **no** | `formula_inputs`, `relics`, `xp_events` are never read by `ResolveScreen`. `xp_events` is consumed elsewhere (EchoParty). Data seam, not a section. |
| 13 `combat_seams` | **no** | `objectives_remaining` shapes A's own action set before the snapshot is built; `guide_spirit_protected` is a V2-ITEM-002 seam; `combat_intro_line` is S15 prep. |
| 14 `scout_intel` | yes | `%ReasonLabel` — `"%d situation%s revealed"` |
| 15 `contact_outcome` | yes | banner text + banner colour + `%ReasonLabel` |
| 16/17 `legacy_title`/`legacy_note` | **no** | zero consumers repo-wide |

---

## 4. API specification

Pattern taken from `core/state/flow/states/sanctum/SanctumSnapshotBuilder.gd`: a `class_name`
`RefCounted` holding only `static` functions, reading `flow_ctx`/`save_data` and writing nothing.

**File:** `core/state/flow/states/venture/ResolveSnapshotBuilder.gd`
(beside `FlowResolveState.gd`'s consumers and the venture states; it is the venture domain's builder).

### 4.1 Base

```gdscript
class_name ResolveSnapshotBuilder
extends RefCounted

## Returns the skeleton. `data` starts empty except for run_type when non-empty.
## `actions` is stored by reference — build it first, pass it in.
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
```

### 4.2 Block signatures

Every block takes the `data` dict returned inside the skeleton and writes into it (GDScript
Dictionaries are references). Every one returns `void`.

| # | Signature |
|---|---|
| 1 | `static func add_banner(data: Dictionary, surface: String, summary_line: String) -> void` |
| 2 | `static func add_victory_flag(data: Dictionary, victory: bool) -> void` |
| 3 | `static func add_grade_rank(data: Dictionary, rank: String) -> void` |
| 4 | `static func add_grade_verdict(data: Dictionary, verdict: String) -> void` |
| 5 | `static func add_combat_stats(data: Dictionary, encounter_id: String, reason: String, round_ended: int, enemies_defeated: int, echoes_survived: int, objective_state: Dictionary) -> void` |
| 6 | `static func add_actors(data: Dictionary, actors: Array) -> void` |
| 7 | `static func add_ledger(data: Dictionary, ase_awarded: int, reward_breakdown: Array) -> void` |
| 8 | `static func add_ekwan(data: Dictionary, ekwan_awarded: int) -> void` |
| 9 | `static func add_emotion(data: Dictionary, emotion_summary: Array) -> void` |
| 10 | `static func add_vows(data: Dictionary, vow_outcome: Dictionary, newly_unlocked_vows: Array) -> void` |
| 11 | `static func add_effects(data: Dictionary, effects: Array) -> void` |
| 12 | `static func add_progression(data: Dictionary, formula_inputs: Dictionary, relics: Array, xp_events: Array) -> void` |
| 13 | `static func add_combat_seams(data: Dictionary, objectives_remaining: int, guide_spirit_protected: bool, combat_intro_line: String) -> void` |
| 14 | `static func add_scout_intel(data: Dictionary, intel_count: int) -> void` |
| 15 | `static func add_contact_outcome(data: Dictionary, role: String, role_label: String, outcome: String, outcome_text: String) -> void` |
| 16 | `static func add_legacy_title(data: Dictionary, title: String) -> void` |
| 17 | `static func add_legacy_note(data: Dictionary, note: String) -> void` |

### 4.3 How a producer declares its blocks

By calling. Example — producer C, in full:

```gdscript
var snap := ResolveSnapshotBuilder.build(t, _scout_return_actions(), "scout_return")
var data: Dictionary = snap["data"]
ResolveSnapshotBuilder.add_banner(data, "scout_return", "%d crossing%s mapped." % [intel, plural])
ResolveSnapshotBuilder.add_victory_flag(data, false)
ResolveSnapshotBuilder.add_grade_rank(data, "")
ResolveSnapshotBuilder.add_grade_verdict(data, "")
ResolveSnapshotBuilder.add_actors(data, actor_preview)
ResolveSnapshotBuilder.add_ledger(data, ase, breakdown)
ResolveSnapshotBuilder.add_ekwan(data, 0)
ResolveSnapshotBuilder.add_scout_intel(data, intel)
return snap
```

Block call list per producer:

| P | Blocks called (base `run_type` in bold) |
|---|---|
| A | `banner`, `victory_flag`, `grade_rank`, `combat_stats`, `actors`, `ledger`, `ekwan`, `emotion`, `vows`, `progression`, `combat_seams`, `legacy_title` |
| B | `victory_flag`, `grade_rank`, `combat_stats`, `actors`, `ledger`, `emotion`, `progression`, `legacy_title` |
| C | **`scout_return`** + `banner`, `victory_flag`, `grade_rank`, `grade_verdict`, `actors`, `ledger`, `ekwan`, `scout_intel` |
| D | **`contact_result`** + `banner`, `grade_verdict`, `contact_outcome` |
| E | **`situation_result`** + `banner`, `grade_verdict`, `ledger`, `ekwan`, `emotion`, `effects` |
| F | `victory_flag`, `legacy_title`, `legacy_note` |

### 4.4 Purity contract

The builder **must be pure**: it may not write `save_data`, may not mutate `FlowContext`, may not
call `request_save()`, and may not construct any service whose constructor can write. It takes no
`FlowContext` at all — every input is a plain value passed by the producer. That is a stronger
guarantee than `SanctumSnapshotBuilder`'s (which reads `flow_ctx`) and it is affordable here because
every resolve input is already computed by the producer before the snapshot is assembled.

Two calls with the same arguments must produce byte-identical payloads (`JSON.stringify` equal) —
this is the `snapshot_purity/generic_double_build_is_stable` idiom already used for
`SanctumSnapshotBuilder`.

### 4.5 Where producer C's impurity moves

`_build_scout_return_snapshot()` today breaks purity three ways. Each has a specified destination.

**(a) It zeroes two `FlowContext` fields (lines 4352–4353).**
Move to the **dispatch transaction closure**, following the `pending_awakening_banner` precedent at
`FlowRuntime.gd:610–625` — consume once, *after* publication and logging, gated on the published
snapshot's type. Insert next to that block:

```gdscript
# Mirrors the pending_awakening_banner gate above. Consume the scout one-shots exactly once,
# after the snapshot that surfaced them has been published and logged. Gated on run_type as
# well as type: a combat resolve must never zero a scout value the player has not yet seen.
if str(out.get("type", "")) == FlowStateIds.RESOLVE \
		and str((out.get("data", {}) as Dictionary).get("run_type", "")) == "scout_return":
	flow_ctx.pending_scout_return_ase         = 0
	flow_ctx.pending_scout_return_intel_count = 0
```

The two setters (`FlowRuntime.gd:1120–1121` in `encounter.retreat`, and `4865–4866` in
`stage.return_home`) stay where they are and are unchanged.

**(b) It constructs `SanctumService.new(flow_ctx.save_data)` (line 4334)** — a constructor that can
write `save_data` via `SanctumState._ensure_sanctum_dict_exists()`. Per `AGENTS.md` ("Reads save data
for a domain → a **static** function on that domain's service"), add a static reader beside
`get_active_party_echoes` in `core/sanctum/SanctumService.gd`:

`static func get_party_actors_static(save_data: Dictionary) -> Array`

It must reproduce the instance method line-for-line, **including iteration order**:
`get_party_actors()` iterates `active_party_ids` and looks each up in the roster.
`get_active_party_echoes()` iterates the **roster**. These are different orders.
**Do not substitute `get_active_party_echoes()`** — that is exactly the lookalike-API substitution
`AGENTS.md` mistake #19 warns about, and it would also change the element shape (raw roster dicts
vs `EchoActor.from_echo()` actors).

The party-preview projection itself (the `for` loop at 4336–4350) moves into producer C's controller,
not into the builder — the builder receives the finished `Array` via `add_actors`.

**(c) `EchoActor.from_echo()` output has no `emotion` key — see §6.3.** Reproduce the current
(buggy) behaviour in Phase 5; do not fix it here.

---

## 5. Phase split

| Piece | Phase 5 (now) | Phase 6 (with `FlowEncounterState`) |
|---|---|---|
| `ResolveSnapshotBuilder.gd` with **all 17 blocks + base** | ✅ build now | — |
| Migrate C, D, E, F to the builder | ✅ | — |
| `SanctumService.get_party_actors_static()` | ✅ | — |
| Scout one-shot consumption in the dispatch closure | ✅ | — |
| Migrate A (combat) | — | ✅ |
| Migrate B (keeper trial) | — | ✅ |

**Build every block now, including the eight only A and/or B use** (`combat_stats`, `progression`,
`combat_seams`, `vows`, plus `emotion`/`actors`/`ledger`/`grade_rank` which C or E already share).
Reasons: they are ten- to twenty-line pure writers with no dependency on `FlowEncounterState`; the
key matrix in §1.2 is measured now and will not be re-measured in Phase 6; and building them now
means Phase 6 is a pure call-site migration with **no edit to `ResolveSnapshotBuilder.gd`** and
therefore no risk to the already-migrated C/D/E/F.

**Confirmation that Phase 6 cannot force a change to Phase 5 work.** Producers A and B introduce no
key that C/D/E/F also set except via blocks that already exist at the exact granularity A and B need
(`victory_flag`, `grade_rank`, `actors`, `ledger`, `emotion`). Because no block is shared *partially*
— every block is all-or-nothing per producer — A and B can only add whole blocks. The single place
Phase 6 touches shared code is `add_ledger`, and B's requirement (ase + breakdown, **no** ekwan) is
already what block #7 does; that is precisely why `ekwan` is block #8 rather than a flag.

Phase 5 should also add the double-build purity test (§6.4) so Phase 6 inherits the guard.

---

## 6. Risks, migration order, and test coverage

### 6.1 RISK — producer C violates the snapshot contract today

`FlowStateMachine._validate_snapshot()` (lines 136–145) requires `meta` to be a Dictionary
**containing `"t"`** and calls `assert(false)` otherwise. Producer C emits `{ "sim_tick": t }`.
Both C call sites (`encounter.retreat` success, `stage.return_home` success) assign
`flow_ctx.last_snapshot` and then `flow_machine.transition(RESOLVE, …)`, which runs
`_rebuild_snapshot()` → `_validate_snapshot()`. `FlowResolveState.enter()`'s pass-through guard
keeps the offending snapshot intact. **So every successful retreat and every successful return-home
trips an assertion in a debug build.** No test covers it: `SnapshotContractTests` has no
`flow.resolve` case, and `FlowFingerprintTests._final_fingerprint()` does not read `meta`.

`meta.sim_tick` is not read by any consumer (`ResolveScreen` never touches `meta`;
`SnapshotContractTests:191` already pins `sim_tick` as *retired* for `flow.vow_manage`, a defect this
same story fixed).

**Recommendation: emit `{ "t": t }` for C.** This is the one place the hard constraint and
correctness conflict, and the constraint's purpose (no observable behaviour change) is served by the
fix rather than by the reproduction. Needs product-owner sign-off (§7 Q1). If sign-off is withheld,
`build()` gains `legacy_meta_key: String = "t"` and C passes `"sim_tick"` — but that ships a known
assertion failure into the new builder, so it is the worse option.

### 6.2 What breaks if the design is implemented wrongly

| Test file | Detects | Verdict |
|---|---|---|
| **`tests/FlowFingerprintTests.gd`** | `_final_fingerprint()` (lines ~231–275) records **sorted `data_keys` and sorted `action_keys`** for producer A across all seven combat modes, plus `victory`, `reason`, `round_ended`, `enemies_defeated`, `echoes_survived`, `ase_awarded`, `ekwan_awarded`, `rank`, `objectives_remaining`, `surface`, `guide_spirit_protected`, and the whole `objective_state` dict. | **The strongest guard in the repo for producer A.** Any key added to or dropped from A's `data` drifts seven hashes at once. Will break on any Phase 6 mistake. Silent on C/D/E/F. |
| **`tests/UnifiedResolveTests.gd`** | Producer E end-to-end through `dispatch()`: `type`, `run_type == "situation_result"`, `surface` (loot/money/obstacle/omen/ritual), `verdict`, non-empty `summary_line`, `cta.continue.to == flow.stage_explore`, `ase_awarded > 0`, `reward_breakdown.size() >= 1`, and — using `data.has()` — **presence** of `emotion_summary` and `effects` plus per-entry `pre_emotional_status`/`post_emotional_status`/`direction`/`tag`. | **The only suite that asserts key PRESENCE rather than value.** Drops `add_emotion` or `add_effects` from E and it fails immediately. Primary Phase 5 guard. |
| **`tests/CombatSnapshotTests.gd`** | `_t_final_snapshot_has_required_fields` asserts A returns `type == "flow.resolve"` and `data.has()` for `victory`, `reason`, `round_ended`, `actors`, `objective_state`; `_t_actor_projection_fields` pins `_project_actor` output. | Catches a gross Phase 6 error (missing `victory_flag`/`combat_stats`/`actors`). Coarser than the fingerprints. |
| **`tests/SnapshotContractTests.gd`** | `_contract_violation()` requires `type`, `meta` Dict **with `t`**, `data` Dict, `actions` **Dict not Array**. `_t_vow_manage` pins `sim_tick` as retired. | **Covers no `flow.resolve` snapshot today** — which is why §6.1's defect survives. It will only catch a resolve regression if a case is added (recommended, §6.5). |
| `tests/FlowSnapshotFingerprintTests.gd` (not in the brief, but relevant) | `snapshot_purity/generic_double_build_is_stable` is the double-build idiom to copy; `snapshot_purity/build_final_snapshot_pays_rewards` is a **KNOWN DEFECT** probe asserting A still pays rewards. | If a later phase makes A pure, that probe's assertion must be *inverted*, not deleted. Out of Phase 5 scope. |

### 6.3 Live defects found while measuring — report, do not fix here

1. **§6.1 — C's `meta.sim_tick` trips `assert(false)` on every retreat / return-home.**
2. **C's `emotional_status` is a constant.** `get_party_actors()` returns `EchoActor.from_echo()`
   dicts, which **have no `emotion` key** — `from_echo` flattens it to top-level `morale`/`fear`.
   So `_a.get("emotion", {})` at `FlowRuntime.gd:4340` always yields `{}`, and every scout-return
   actor preview renders `get_emotional_status(50, 0)` regardless of the party's real state.
   Reproduce it verbatim in Phase 5 and label it
   `# KNOWN DEFECT (V2-INFRA-003 Phase 5 records; a later story fixes):`.
3. **D's `verdict` is written and never read** — the contact renderer sets
   `_rank_badge.visible = false` unconditionally.
4. **`title` and `note` are dead keys** — zero consumers repo-wide.
5. **B's `emotion_summary` entries lack `direction` and `tag`**, so the keeper-trial resolve renders
   grey default tokens and no direction cue while combat and situations render both.

### 6.4 Migration order

1. Land `ResolveSnapshotBuilder.gd` (base + all 17 blocks) with **no call sites**. Compile-check.
   Rebuild the class cache with `--headless --import` first — it is a new `class_name`.
2. Add the double-build purity test and a `flow.resolve` case to `SnapshotContractTests`
   (§6.5) **before** any producer moves, so the guard exists while the risk exists.
3. Add `SanctumService.get_party_actors_static()`. Prove it order-equal to `get_party_actors()`.
4. Migrate **F** first — three keys, no dependencies, and it is the only producer whose failure mode
   is visible without combat.
5. Migrate **D** — eight keys, no economy, no context mutation.
6. Migrate **E** — pinned hardest by `UnifiedResolveTests`; run `-- tests unified_resolve` after.
7. Migrate **C** last of Phase 5 — it carries the purity move, the static reader, and the `meta`
   decision. Do the `meta` change (if approved) as its own commit, separable from the migration.
8. Full suite once at the end. Baseline **1442 passing**; expect 1442 + the new purity/contract tests.

### 6.5 Coverage gaps to close in Phase 5

- `SnapshotContractTests` has no `flow.resolve` case. Add one per producer C/D/E/F —
  `_contract_violation()` alone would have caught §6.1 the day it shipped.
- No test asserts producer B **omits** `ekwan_awarded`. That is the single most fragile fact in this
  spec and it is currently unpinned. Add a Phase 6 characterization assertion for it.
- No test covers producer F at all.
- No test asserts C's `actors` preview shape.

---

## 7. Open questions for the product owner

**Q1 — May producer C's `meta` change from `{ sim_tick: t }` to `{ t: t }`?**
It currently violates `FlowStateMachine._validate_snapshot()` and trips `assert(false)` on every
successful retreat and return-home in a debug build. No consumer reads it; `sim_tick` was already
retired elsewhere in this same story. This is the only conflict between the hard constraint and
correctness. **Recommendation: yes, fix it, as its own commit.**

**Q2 — Should `verdict` and `rank` remain two keys, or become one graded slot?**
They occupy the same badge on screen with two vocabularies (S–F vs carried/passed/good/partial/missed),
and C emits both as empty strings. Merging them is a clean-break save-neutral change and would remove
one block. Out of scope for this refactor; worth its own story.

**Q3 — May `title` and `note` be deleted?**
Neither is read by any consumer in `ui/`, `core/` or `tests/`. Deleting them removes blocks #16 and
#17 and three keys. The only cost is that producer A's fingerprint `data_keys` drifts, so the seven
combat-mode fingerprint constants would need re-recording — cheap in Phase 6, gratuitous in Phase 5.
**Recommendation: keep now, delete in Phase 6 if approved.**

**Q4 — Should the keeper trial (B) gain `ekwan_awarded`, `direction` and `tag`?**
B is the only resolve surface that shows no Ekwan row and renders grey emotion tokens with no
direction cue. That looks like an oversight rather than a decision, but it is a behaviour change and
therefore out of scope. If the answer is "yes, later", block #8 stays as designed and B simply starts
calling it — one added line, no other producer touched. That is the composition model working.

**Q5 — Is the seventeen-block granularity acceptable?**
It is the minimum that reproduces all six payloads with zero opt-out flags, and it gives the
strongest version of the property requested (add or remove a section without touching other
producers). The cost is five single-key blocks and three blocks that map to no screen section. The
coarse alternative is in §2.4.

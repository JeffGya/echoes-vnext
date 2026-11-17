# Inventory and items — living design document

Status: living document. Sits BELOW `docs/Echoes vNext Working GDD.md`. First draft 2026-11-13.

## 0. Status, rules for contributors, change log

**Authority.** The Working GDD is the only design authority. This document never overrides it. If the GDD is silent, the point is Jeff's decision. GDD sections that apply:

| GDD section | What it says (quoted, short) | Use here |
|---|---|---|
| 19.3 | "The equipment model should stay light." Four slots: weapon, charm, armor, relic or consumable. | ITEM-003 owns slots. Not built. |
| 19.5 | Sources: crafting, Sanctum projects, rites, stage rewards, Realm rewards. | Section 3 |
| 19.7 | "anti-hoarding should come from inventory structure, not constant decay" | Sections 2 and 10 |
| 19.7 | "recycling should return `Ekwan` only" | Section 10 |
| 19.8 | Gear is "transferable at baseline". Claimed gear carries "a stronger emotional and surface effect". | Section 7 (OPEN link) |
| 21.1 | Still open: inventory cap structure, rarity ladder, item-grade spread. | Sections 2, 14 |

I found no GDD text on the emotion of an Echo who picks up items. That effect is Jeff's decision (section 7).

**Status tags.** Every section carries one tag.

| Tag | Meaning |
|---|---|
| BUILT | In the code. The section names the story, the files and the decision ids. |
| DESIGNED | Decided by Jeff. Not built. The section names the story that builds it. |
| OPEN | Not decided. Listed in section 14. |

**How a story contributes.**
1. Edit only the sections your story changes.
2. Keep the status tags true. Move a section from DESIGNED to BUILT when the code lands.
3. Add ONE line to the change log (section 15): story code, date, what changed.
4. Never delete a rule. Mark it SUPERSEDED. Give the reason and the id of the new decision.
5. Cite decisions. Do not copy long reasons.

**Where decisions live.** Story decisions: `docs/stories/<story>/decisions.md` (D-nn). Project-wide answers: `ANSWERS.md` (#nn).

**Follow-ups.** The unwired parts and their target stories are tracked in `docs/stories/v2-item-001b/follow-ups.md`.

**Word rules for player text.** ANSWERS #86: never "home", never "stage". Say Sanctum and path. What a party does not carry is "lost". ANSWERS #89: Jeff approves every player-facing line. Section 12 has details.

**Marking.** Every player-facing line in this document is `AGENT-WRITTEN (proposal)`. No line is final (D-56).

**Sources checked for this draft.** 001a: `docs/stories/v2-item-001/` (`decisions.md`, `handoff.md`, `step7-backend-moves-slots.md`, `step8-ui-build.md`). Removed files: git commit `11d566f`. CONVENTIONS section "Item Containers, Item Text and One-Shot Snapshot Fields (V2-ITEM-001a)" and "Recipe price records". Part B: `docs/stories/v2-economy-004/decisions.md` D-122 to D-149. 001b: `docs/stories/v2-item-001b/decisions.md` D-01 to D-56.

---

## 1. Item words

| Player word | Code word | Meaning |
|---|---|---|
| Storehouse | `sanctum` container (`inventory.items`, `inventory.stacks`) | The Sanctum inventory. Safe. Never shrinks. |
| Travel pack | `pack` container (`inventory.pack`, `inventory.pack_stacks`) | The party pack. Items here are at risk on a path. |
| slot | `slot` (saved integer on each entry) | One place in a container. One entry fills one slot. |
| piece | unique entry in `items` or `pack` | One gear or relic item with its own id. |
| stack | entry in `stacks` or `pack_stacks` | Consumables or materials of one type, with a quantity. |
| kind | `kind`: `gear`, `relic`, `consumable`, `material` | The class of an item. Four kinds. |
| grade | `grade` (ladder in `data.inventory.grades`) | The quality step. The ladder is empty in shipping. |
| twin | two entries of one type | Shown by the twin notch (`mark_index`). A twin never merges, unless both are stacks. |
| find | a row with `source: item` and a `find_id` | An item found on a path, gathered, not yet kept. |
| held | piece or stack already in the pack before the path started | At risk like a find (D-19 of 001a). |
| gathered | find in the packs of a live path | Owns one reserved pack slot. |
| left | find the Echo did not take | Shown only in the pickup event. Lost when the event ends (D-14, D-43). |
| field | the combat board during the pickup event | Items lie here in the event only (D-31). |
| event | the pickup event | A scene after a won fight, before Resolve (D-16). |
| destroy | `inventory.discard.apply`, `discard_used` | Removes an entry. Returns nothing. |
| swap | not built; saved flag proposed as `swap_used` | Trade one field item for one pack item. Once per path. |

Player words follow ANSWERS #86. The code words never appear in player text.

---

## 2. Containers and capacity — BUILT

**Story:** V2-ITEM-001a (merged). **Decisions:** 001a D-01, D-05, D-13, D-33, D-34, D-37, D-40. **Code:** `core/inventory/InventoryService.gd` (`box_size`, `pack_free`, `intake`, `move_entry`, `_layout`), `core/inventory/InventoryRules.gd` (`mode`, `move_block_reason`, `projection`), `core/runtime/controllers/InventoryController.gd` (`handle_move`, `handle_discard`).

| Rule | Detail | Source |
|---|---|---|
| Two containers | Storehouse and Travel pack. | 001a D-13 |
| Sizes | Config `data.inventory.unique_cap` = 20. Config `data.inventory.pack_capacity` = 4. Both are PROVISIONAL (Jeff tunes after play). Verified in `data/balance.json`. | 001a D-25, D-34 |
| Slot | Each entry has a saved `slot`. A piece and a stack each fill one slot. | 001a D-37 |
| Placement | An intake or a move takes the first free slot. A caller may give `to_slot`. | 001a D-40 |
| Stack limit | `data.inventory.stack_limit_default` = 20. A definition may override with `stack_limit`. | 001a D-05 |
| Merge | A stack dropped on a same-type stack merges up to the limit. A merge needs no free slot. A moved stack moves whole. | 001a D-34 |
| No swap by move | A move onto an occupied slot is refused (`slot_taken`). The player reorders into an empty slot. | 001a D-34, D-40 |
| Where a move is allowed | `flow.sanctum` and `flow.echo_party`, also with a saved path live. Refused on the path view (`path_open`). | 001a D-40 |
| Nothing moves alone | Not at path end, not after a leave, not at intake. The player moves things. | 001a D-42 |
| Panels | The Storehouse panel and the Travel pack panel are UI-local. No flow state. No `snapshot.actions` slot. | 001a D-33, D-35 |
| Free pack room | `pack_free` = capacity minus held entries minus open item rows of the whole save. | `record_found_items` doc |
| No pack penalty | A full pack has no mechanical penalty. The risk shows through marks and tone. | 001a D-36, D-17 |
| Reads never repair | `InventoryService.validate` lists problems. A stored slot above the size is kept. | CONVENTIONS |

**Not decided or not built.**

| Item | State | Owner |
|---|---|---|
| Pack size by Sanctum progression | Not built. Pack stays at the config size in 001b (001b D-52 a). | V2-CONTINUITY-002 |
| Pack size per Echo (each Echo adds a slot) | Not built. | V2-ITEM-003 |
| Pack shrink rule (pieces in closing slots move to the Storehouse; player chooses at party prep) | Designed in 001a D-41, not built. Never on a live path. | The story that shrinks packs |
| Pack grows with the finds cap | OPEN (001b D-46, section 14 Q7, first half). | Jeff |
| Storehouse `unique_cap` as anti-hoarding | GDD 19.7 lists "inventory cap". Size is PROVISIONAL. | Jeff, after play |

---

## 3. Where a find comes from — BUILT (seam, chance and cap); real drops OPEN

### 3.1 The source contract — BUILT

**Story:** V2-ITEM-001a. **Decisions:** 001a D-13, D-17, D-47, D-49; ANSWERS #87. **Code:** `core/realms/ActiveStageService.gd` (`record_found_items`), `core/economy/EarningsService.gd` (`record_item`, `item_id`, `open_item_rows_in_save`, `report_row`), `core/inventory/InventoryService.gd` (`take_in_order`, `check_entry`).

| Rule | Detail |
|---|---|
| Earnings rows | A find is an item row in the packs: `source: item`, id `item:<situation_id>:<find_id>`, 0 Ase, 0 Ekwan. |
| No direct payout | A source adds a row. It never pays into a container or a balance (ANSWERS #87). |
| Exactly once | The row id is the stamp. A repeat call with the same `find_id` writes nothing. |
| Input | `record_found_items(flow_ctx, situation_id, finds, t)`. Each find needs a unique `find_id` and must pass `InventoryService.check_entry`. |
| Refusals | `bad_entry`, a reason from `check_entry`, `duplicate_find` (the first copy stands). A refused find takes no slot. |
| Result | `{ taken, left, refused }`. `taken` and `left` are lists of `find_id`. |
| Default chooser | `take_in_order` takes the first free-room finds in find order. It returns `{ model: "find_order", chooser_id: "", taken, left, draws: 0 }`. A replacement chooser keeps this shape (the code comment says so; 001b uses it, section 4). |
| Left finds today | A find beyond the room is "not gathered and not lost" (code comment). 001b makes this the pickup event. |
| Save | The seam requests a save when it writes a row (`economy.earnings.items`). No RNG. |
| Debug producer | `inventory produce [direct\|gather]`, debug builds only (`DebugController.handle_inventory_produce`, data in `tests/fixtures/inventory_placeholders.json`). `gather` writes item rows on a live path. `direct` places items in the containers, Storehouse first. |

**Gap closed by 001b:** finds gathered on a path are not drawn in the pack panel and not counted by the pack button (001a handoff F8-02). 001b D-01 puts the gathered finds in the path pack view. Not built.

### 3.2 Real drops — OPEN

Nothing in the game calls `record_found_items` except the debug producer. V2-ITEM-002 builds real drops and the item catalogue (names, grades, images, descriptions). Who calls the seam for real drops is OPEN (001b "Open"; section 14 Q2). 001b D-49: ITEM-002 calls the same chance function as the debug producer. ITEM-002 may tune the numbers. It may not remove the key.

### 3.3 Finds cap and finds chance — BUILT (001b C1, C6, C10)

**Decisions:** 001b D-40, D-46 to D-51.

**Cap per event.** The cap on finds offered in one pickup event scales with the realm scale (`RewardCalc.realm_scale`).

| Realm scale | Cap | Status |
|---|---|---|
| 1.0 (realm.01, prologue) | 2 | Approved (D-46) |
| 1.25 (realm.02) | 3 | Approved (D-46) |
| 1.75 | 4 | PROPOSED DEFAULT, placeholder for a realm that does not exist |
| 2.5 | 5 | PROPOSED DEFAULT, placeholder |
| 3.5 | 6 | PROPOSED DEFAULT, placeholder |

Config key: `data.inventory.finds_cap_by_realm_scale` (an ordered list of bands). One helper gives the cap (name proposed: `InventoryService.finds_cap(cfg, realm_scale)`). The cap counts finds offered in the event (taken and left). One seam call per event.

**Cap enforcement (Option B, D-51).** The chance function respects the cap. The seam `record_found_items` refuses any find beyond the cap with the reason `over_cap` and logs it.

**Chance per find slot.** Jeff: "Each possible find ... rolls its own chance" (D-48). The first find is the most likely.

| Value | Setting | Source |
|---|---|---|
| Formula | `p_k = clamp(base_k + rank modifier, 0, max)`, integer percent | D-49 |
| `base_by_slot_pct` | 85, 60, 40, 25, 15, 8 | D-50, PROPOSED DEFAULT, tune after the probe |
| `rank_modifier_pct` | D -10, C 0, B +5, A +10, S +15 | D-50, PROPOSED DEFAULT |
| `max_pct` | 98 | D-50 |
| First-find floor | 60 at the lowest win rank (validator rule) | D-50 |
| Config key | `data.inventory.finds_chance` | D-49 |
| Rank | The fight rank of `RewardCalc` (F to S). A win scores 0.4, Echoes alive 0.4, pace 0.2 (D-47). Lowest win rank today is C, so D is unreachable. S needs no fallen Echo (`_compute_rank`, `any_death`). | D-47, D-50 |
| Rolls | One draw per slot. All `cap` draws are always made. Slot rolls are independent (assumed from "each rolls"; section 14 Q8). | D-49, D-50 |
| Stream | `inventory.finds.<stage_id>.<run_count>.<situation_id>`. Never `stage.settle`. | D-49 |
| Stored | The result is stored at the first draw. | D-49 |
| Loss or retreat | No rank, no finds roll, no event. | D-49 |

The finds config keys are in `data/balance.json` (`data.inventory.finds_cap_by_realm_scale` and `data.inventory.finds_chance`; built by 001b C1).

---

## 4. Who takes it: the chooser and the pick rule — BUILT (001b C4, C5)

**Story:** V2-ITEM-001b. **Decisions:** 001b D-05, D-06, D-09, D-12, D-39, D-43; ANSWERS #91. D-07 (freeze gate took finds in find order) is SUPERSEDED by D-39 and D-43.

### 4.1 The chooser draw

| Rule | Detail | Source |
|---|---|---|
| When | After each won fight with at least one find. The draw happens even when all finds fit. | D-05 |
| Who | One Echo, equal chance, from the Echoes that did not fall, in party order. | D-05 |
| Stream | `inventory.pick.<stage_id>.<run_count>.<situation_id>`. Never `stage.settle`. | D-05 |
| Exactly once | A saved pick stamp. The saved field name is OPEN (section 11; section 14 Q6). | D-05 |
| After the draw | No RNG. Ties go to the lower `find_id`. | D-06 |

### 4.2 The pick rule

The chooser scores each find. The player must be able to read the pattern across many choices (ANSWERS #91). A design that breaks this needs Jeff's approval first.

| Part | Inputs | Source |
|---|---|---|
| Identity | Calling family, vectors, traits, stats, archetype | D-06 |
| Sense | Grade, kind, quantity, scaled by Judgment | D-06 |
| State | Afraid, bold, Calling signature | D-06 |
| Not direct inputs | Standing, Storyweight, bonds, vows. They reach the pick only through Judgment and composure. | D-06 |

Score shape (D-12, from the `mid-game-designer` proposal Jeff approved on 2026-11-10):

```
score(find) = calling_pick[calling][kind] + archetype_pick[archetype][kind]
            + kind_weight[kind]
            + sense_term(grade_step, quantity_gain, worth_weight, sense_base, Judgment)
            + vector_pick_muls . vectors + trait_pick_muls . traits + stat_pick_muls . stats
            + state_term(afraid_pick, bold_pick, afraid_pick_signature[calling])
```

Headline values approved by Jeff (D-12). The columns are gear / relic / consumable / material.

| Table | Values |
|---|---|
| `calling_pick` okofor | 6, -2, 4, -8 |
| onyamesu | -4, 0, 8, -4 |
| aduro | 8, -4, -2, -2 |
| sum_okwanfo | -2, 6, -2, -2 |
| okomfo | -6, 8, 2, -4 |
| kra_soro | 2, -6, 4, 0 |
| `archetype_pick` valiant | 6, -2, -2, -2 |
| proud | 2, 6, -4, -4 |
| ambitious | 4, 2, -2, -4 |
| canny | -2, -4, 2, 4 |
| loyal | 2, -2, 4, -4 |
| stoic | 2, -4, 0, 2 |
| devout | -2, 6, 0, -4 |
| empathic | -4, 0, 6, -2 |
| reflective | -4, 4, -2, 2 |
| `kind_weight` | gear 3, relic 4, consumable 2, material 1 |
| Scalars | `grade_step` 1.5, `quantity_gain` 0.5 (cap 3), `worth_weight` 6, `sense_base` 0.0 (D-67: was 0.3; probe P2 failed the D-63 pass line at 0.3 and passed at 0.0; `worth_weight` stays 6), `freeze_at` 0.5 |
| `afraid_pick` | 4, -8, 16, -12 |
| `bold_pick` | 6, 10, -8, -8 |

Not copied here: `vector_pick_muls` (ten rows), `trait_pick_muls`, `stat_pick_muls` (six stats, no speed), `afraid_pick_signature` per Calling. The full tables are in `docs/stories/v2-item-001b/pick-numbers.md` and in `data.inventory.pick` (`data/balance.json`). Probe P2 ran at full size (D-67): with `sense_base` 0.0 it passes the D-63 pass line (M1 17.1%, M3 +0.609, M4 99.0%), a narrow pass.

Vector and trait sums scale by Judgment "as in combat" (D-12). `freeze_at` compares with the curved afraid value (D-12).

### 4.3 The frozen chooser

A chooser whose afraid value is at or above `freeze_at` (0.5) freezes. **A frozen chooser takes nothing** (D-39). No swap is offered (D-43). The items are revealed, then lost when the event ends. There is no emotion minus (D-39, D-34). The Swap button is hidden in the details, with no extra line (D-54).

### 4.4 Open links

Whether Standing 6 and 9 Callings resolve to a Calling family: OPEN (001b "Open"; section 14 Q3).

---

## 5. The pickup event — BUILT (backend, 001b C6 to C10); UI DESIGNED

**Story:** V2-ITEM-001b. **Decisions:** 001b D-16, D-20 to D-22, D-25, D-31, D-32, D-36, D-37, D-38, D-45. The spec for the playable mockup is `design-rules-v2.md` (session scratchpad, not in the repo). Where it conflicts with `decisions.md`, `decisions.md` wins.

**Concept.** Concept A: the end of combat, on the combat board (D-20). Jeff's playtest verdict on the mockup: "It feels like a real choice" (D-36).

**Where it sits.** The event runs right after the won fight and BEFORE Resolve. Resolve then shows the final items (D-16, D-26 a).

**Gate.** A won fight with at least one find. No finds, no event. A loss or retreat has no event.

**Sequence.**

| Step | What happens |
|---|---|
| 0 | The fight ends in a win. The finds roll, the chooser, the picks and the reaction class are decided. |
| 1 | Combat input stops. In a win without kills, enemies still alive withdraw. Fallen Echoes stay down and lie apart from the row. |
| 2 | Items appear on the field as hidden generic icons (D-31, D-37). |
| 3 | Standing Echoes walk into a row. |
| 4 | The pointer passes along the row, slows and rests on the chosen Echo (D-21). |
| 5 | The chosen Echo steps forward. The Travel pack panel comes up at the same time (D-22). |
| 6 | The Echo walks to each pick in pick order. The item is revealed when the Echo chooses it (D-37). |
| 7 | Each item goes into the first free slot at once. If a find does not fit, the Echo holds it up (D-55). |
| 8 | The reaction beat: one pose and one bark (section 7). |
| 9 | Idle. The field shows what is left, revealed after the picks. The pack shows what it holds. Continue is always present. |
| 10 | Swap, if the pack is full and a legal pair exists (section 6). |
| 11 | Continue. What is on the field is lost. Resolve opens. |

**Pointer rules (presentation only).** The pointer is a soft light, not a spinning icon (D-21). The glow is subtle (D-38). The result is decided before the pointer starts. It visits only standing Echoes. It only slows. Skip, reload and replay give the same Echo. No percentage is shown.

**Hidden items.** An item on the field shows as a generic icon, not a card (D-37). A hidden item cannot be selected (D-45). It becomes selectable when revealed.

**Skip and resume.** A tap during steps 1 to 8 jumps to idle. The result never changes. A reload or quit resumes at idle, with the swap allowance as saved. (Mockup spec; the saved shape is OPEN, section 11.)

**Pack panel in the event.** It shows held pieces, gathered items and free slots, with the three tones of 001a (plain, near full, full). It is the same panel as in section 9.

**Item details.** Any visible item can be selected: above the Echo, on the field, in the pack. Details float next to it (D-25). Section 9 lists the fields.

**Board rules.**
- Items appear on the board only when the event starts. Nothing is on the board during combat. Combat cells and AI do not change (D-31).
- Finds lie on free board tiles chosen by a seeded rule in core (`PickupPlacement`, D-72; section 8). The fall-cell rule and the objective anchors of D-32 are not used.
- The standing Echoes form a straight row of tiles near the party centre (D-72; section 8).

**Continue guard.** See section 6.

**Built in 001b C9 (backend) — BUILT.** Files: `FlowRuntime._open_pickup_event`, `PendingResultService`, `PickupController`, `FlowResolveState`, `ResolveSnapshotBuilder`, `StageSettlementService.refresh_card`. Decisions: D-16, D-58, D-66.

| Part | Rule |
|---|---|
| Hook | `FlowRuntime._end_round`, win branch, after the bond and Thread block, before `refresh_snapshot`. With an event, the dispatch publishes `flow.pickup` (intro). The Resolve card waits in `ectx.final_snapshot`. Without an event nothing changes. |
| Hold | A `flow.pickup` snapshot never consumes the pending result. It captures the held card, plus the top-level keys `terrain`, `placement_seed` (a String) and `bounds { w, h }`. |
| End mark | Continue sets `stage.pickup.phase` to "done" and requests a save. After it, every pickup action is refused with `ended`. |
| Continue | Publishes the held card with `data.pickup_result` (block 18). A stage-clearing card also gets a fresh stage payout and `items` block, because the event adds and loses item rows. The same keys go into the pending result. |
| Resume | After a reload the machine is in RESOLVE. If the saved event of the pending result's win (`win_t == created_t`) is not ended, `flow.pickup` resumes at idle. Otherwise Resolve shows. |

---

## 6. Capacity cases and the swap — BUILT (backend, 001b C5, C6, C8); UI DESIGNED

**Story:** V2-ITEM-001b. **Decisions:** 001b D-24, D-27, D-28, D-35, D-41 to D-44, D-54, D-55. SUPERSEDED: D-03 ("one left find in, one gathered find out; never a held piece"): changed by D-15, then D-24, D-27, D-28. D-15 ("swap in any event"): narrowed by D-24 to "only when the pack is full".

### 6.1 Capacity cases

F = finds the Echo picks. S = free pack slots.

| Case | Pack | Finds vs slots | Echo does | Left | Swap |
|---|---|---|---|---|---|
| C1 | empty | all fit | takes all | none | no |
| C2 | empty | some fit | takes S, holds the next one up | F - S | yes |
| C3 | partly full | all fit | takes all | none | no |
| C4 | partly full | 0 < S < F | takes S, holds the next one up | F - S | yes |
| C5 | full | none fit | holds one up | all | yes, if a legal pair exists |
| Frozen | any | none (D-39) | trembles, takes nothing | all | no (D-43, D-54) |

Sources: the mockup spec plus D-24, D-33, D-39, D-43, D-55. The reaction for each case is in section 7.

**Held-up item (D-55).** Whenever an item cannot go into the pack, the Echo holds the tried item up with its bark until the swap or Continue. It stays near the Echo (D-41). The bark says the pack is full. It does not say "hands are full" (D-41).

### 6.2 Swap rules

| Rule | Detail | Source |
|---|---|---|
| When offered | Only in a pickup event, only when the pack is full and items remain on the field. | D-24, D-27 |
| Count | ONE swap per path. Saved flag proposed as `swap_used`. | D-27, D-15 |
| What a swap does | The player trades one field item for one pack item. The pack item may be a gathered find or a held piece. | D-28 |
| Dropped item | It goes onto the field and is lost when the event ends. | Mockup spec, D-43 |
| Legal pair | One field item and one pack item. Never two pack items, never two field items, never two identical (twin) items. | Mockup spec |
| Hidden items | A hidden item cannot be chosen (D-45). | D-45 |
| Frozen chooser | No swap. The Swap button is hidden, with no extra line. | D-43, D-54 |
| Flow | Select an item, press Swap (in the details panel, D-25), pick the other item, see a preview, Confirm or Cancel. Cancel has focus. A confirmed swap commits at once. | D-25, spec |
| Swap and destroy tokens | An icon on the Travel pack shows the swap and the destroy that are left. There is no swap marker on the board. | D-42, D-44 |
| Destroy in the event | Not usable. The destroy works on the path view as in 001a (one per path). In the event the swap is the only tool. | D-44 |
| Reset | DECIDED. `swap_used` clears at an early leave, at defeat and at the path end, like 001a `discard_used`. Jeff approved this in the interview; it is the `swap_used` part of 001b D-04. The left-list part of D-04 is SUPERSEDED by D-14 (no persistent left list). Section 14 Q5 records the closure. | D-04, D-14 |

Refusal lines in the spec ("The swap is used.", "The pack has room.", "Nothing is left to swap.", "These two are the same."): `AGENT-WRITTEN (proposal)`.

### 6.3 Leave guard (D-35)

When the player presses Continue and a swap is still on offer and items remain:

| Directive | Behaviour |
|---|---|
| Scout Carefully | Asks once: "Leave these behind?" `AGENT-WRITTEN (proposal)` |
| Seek Signs | Does not ask |

The rule is one data field per Directive (name proposed: `confirm_leave_items`). Scout Carefully is true. Seek Signs is false. A future Directive sets its own value. No Directive name appears in `core/` logic (ANSWERS #81).

---

## 7. The Echo reaction — BUILT (class only, 001b C5); effect OPEN

**Decisions:** 001b D-23, D-29, D-33, D-34. D-23 is changed by D-33 (the plus applies in the partly-full case too).

**In 001b.** The core computes a reaction class. The UI plays one pose and one bark. There is no meter, no number, no chip animation. The status chip changes only if the band changes (mockup spec). 001b changes no emotion value.

| Case | Class | Source |
|---|---|---|
| Everything the Echo picks fits (empty or partly full pack) | plus | D-33 (Option Y) |
| Only some picks fit | none (the code key; earlier drafts said "neutral") | D-23 |
| Full pack, nothing fits | minus | D-23 |
| Full pack, Echo in a severe band (burdened or worse, or frozen) | no extra minus | D-34 |
| Frozen chooser | none. No minus. Items revealed and lost. | D-39, D-34 |

D-34: a severe-band Echo "may still get the plus when everything fits".

**Effect, later.** The later story "Pickup reaction effect" (no code yet) owns the real emotion change through `EmotionService`. It adds to the +10 morale of a win (`combat_exit_win_morale` 10.0, `data/balance.json`). Win fear (-5) is from D-33; it is not verified in config (section 14 Q16). Size of the plus and the minus: OPEN (section 14 Q4). GDD check: sections 19.3 to 19.8 and 21.1 say nothing on this effect. Jeff decides.

**Barks.** All `AGENT-WRITTEN (proposal)`. The mockup spec has a full-pack bark about the Echo's hands. It conflicts with D-41 (the bark must say the pack is full). Do not use it. Example directions only, not approved: full pack: "No room in the pack."; all fit: "Room for all of it."; some fit: "Took what I could carry."; frozen: "Just grab it. Grab it and go."

**Standing and the reaction.** Standing adds no new rule. Standing 1 hesitates and picks poorly. Standing 9 is calm and picks well (mockup spec). This shows through the pick rule (section 4), not through the reaction class.

---

## 8. Board placement — BUILT in 001b (D-72)

**Code:** `core/inventory/PickupPlacement.gd`, called by `PickupSnapshotBuilder`. **Decisions:** 001b D-66, D-72 (replaces D-29 "later placement story", D-32 and D-52 b).

| Topic | Rule or state |
|---|---|
| Items on the board | Only after the win, at the start of the event (D-31). |
| Snapshot keys | `row[].tile = {col,row}` for each standing Echo and `finds[].tile = {col,row}` for each find. `finds[].cell` stays the index in the record. The tiles are derived on every build and are not saved. |
| Walkable tiles | The largest connected walkable region of the terrain. The sentinel terrain (`{}`) means every cell of the board. |
| Echo row | A straight line of N adjacent region tiles along the col axis or the row axis. The line centre is as near as possible to the party anchor (the integer average of the standing Echoes' cells; the board centre if none has a cell). Ties: a seeded hash that includes the axis (so the hash picks the axis), then axis, then numeric col and row. Fallback: a connected chain of N region tiles (each touches the next by Chebyshev distance 1, no tile twice), grown from the tile nearest the anchor by always adding the unused neighbour of the last tile that is nearest the anchor; a start that dead-ends is skipped. Last: each Echo keeps its own tile. Echoes take the tiles in snapshot `row` order, screen-left to screen-right. |
| Finds | Region tiles that are not row tiles (only drawn tokens occupy a tile: dead enemies, fallen Echoes and the old start tiles of the row Echoes are free) at Chebyshev distance `near` to `far` from the row centre. Per find, in snapshot order: the lowest hash at least `spacing` from every earlier find. Fallbacks in order: spacing 1, wider `far`, any other non-row region tile, then a pile on the nearest taken tile. Every find has a tile. |
| Constants | `data.inventory.pickup.placement`: `near` 2, `far` 3, `spacing` 2 (proposed defaults). A missing key reads as 2, 3, 2. |
| Random numbers | None. One FNV-1a integer hash over `[placement_seed, situation_id, run_count, ...]`. It has the same algorithm as `PickupEventPlan.hash_of` in `ui/`. |
| Limit by free board cells | None. A pile takes the finds that no free tile can hold (the cell-limit half of section 14 Q7 is closed by this; the pack-growth half stays OPEN). |
| Piles | A pile is a rule fallback only. The fan-out look of a pile is a UI decision (section 14 Q11 stays open for the look). |
| Not built | Items that lie where the enemy fell, and objective anchors (D-32). Jeff may reopen them as a new story. |

---

## 9. Details and the glyph budget

### 9.1 Tiles and panels — BUILT (001a)

**Decisions:** 001a D-32, D-39, D-44, D-48, D-49, D-51. **Code:** `ui/components/ItemTile.*`, `ItemTileGlyphs.gd`, `ItemSlot.*`, `ItemResultRow.*`, `ItemLoadMark.gd`, `InventoryPanels.*`, `PartyPackButton.*`. The approved UI contract is `docs/visual-plans/inventory-ui-mockup-v2.html` (001a D-44).

| Rule | Detail |
|---|---|
| Kind shapes | One shape each for gear, relic, consumable, material. |
| Marks | At most 3 marks per tile. |
| Grade pips | 1 to 3 pips. No rarity colour. |
| Twin notch | Six shapes, set by `mark_index` = id number modulo `data.inventory.mark_count` (6). |
| Leaf glyphs | Two: held and gathered. |
| Lost tile | 35% fill, 60% marks (`_LOST_ART_ALPHA` 0.35, `_LOST_MARK_ALPHA` 0.6 in `ItemTileGlyphs.gd`). |
| Pack tones | Plain `#7A5B3E`, near full `#4F3B28`, full `#120E0C`. No decoration. |
| Counts | The Travel pack panel shows no counts and no bead gauge. The count is on the party pack button. |
| Names | `name` from the item definition. No definition means the kind word. No id as text. |
| Refusal | A one-shot `data.inventory.refused` in the next snapshot, never saved. |

I checked the constants named above in the code. I did not check each UI rule against rendering.

### 9.2 Event details and the glyph budget — DESIGNED

**Decisions:** 001b D-17, D-18, D-25, D-42.

| Rule | Detail |
|---|---|
| Details panel | Floats next to the selected item. Shows name, kind, grade pips, count, where ("On the ground", "Carried", "Pack"), an image and a description. Image and description are placeholders until ITEM-002 (D-29). |
| Swap button | At the bottom of the details, when a swap is legal. Hidden for a frozen chooser (D-54). |
| Marks budget | Grade pips, kind shape, twin notch. Three marks. The mockup spec allowed a fourth (a swap marker on the floor). D-42 removed it. |
| Swap and destroy | Shown by one icon on the Travel pack (D-42, D-44). |
| Not allowed | No reason icons. No left list outside the event (D-14). No history, habit strip or pick log (D-17). No spinning icon (D-21). |
| Pointer | A light, not a mark. |

---

## 10. Keep, lose and settle — BUILT

**Story:** V2-ITEM-001a; V2-ECONOMY-004 Part B for recipes. **Code:** `core/economy/StageSettlementService.gd` (leave draws, `_keeps`), `core/realms/ActiveStageService.gd` (`lose_unsettled_packs`), `core/inventory/InventoryRules.gd` (`mark_discard_used`, `clear_path_marks`), `core/economy/RecipeCostService.gd`, `core/economy/EconomyService.gd` (`pay_cost`).

### 10.1 Early leave, defeat, path end

| Event | Rule | Source |
|---|---|---|
| Early leave, outcome none | Items lost. | 001a D-03 |
| Early leave, outcome all | Items kept. | 001a D-03 |
| Early leave, outcome some | One seeded draw per find and per held piece, at the share `data.rewards.carry_shares.some` (0.5, verified in `data/balance.json`). Every early leave draws again. | 001a D-03, D-19, D-22 |
| Draw key | `inventory.leave.<stage_id>.<run_count>.<settle_count>.<row\|held>.<id>`. A held stack is named by type and order among same-type stacks, not by slot. The `stage.settle` stream is unchanged. | 001a D-43; `StageSettlementService` |
| Defeat | All finds and all held pieces are lost (reason `defeat`). `held_fates` records the lost pieces. | 001a D-20 |
| Path end | New finds go into the pack. Held pieces are not drawn. | 001a D-49 |
| Survivors | A kept find stays in the pack as a held piece. The Storehouse is never touched. Carried means at risk. The player moves it to the Storehouse to make it safe. | 001a D-49, D-53 |
| Overflow | A find is lost (`overflow`) only when no pack slot can hold it. A stack larger than one stack can lose units (accepted; ITEM-002 decides the leftover rule, section 14 Q9). | 001a D-46, D-50 |
| Result cards | Leave, defeat and path-end cards show one row of tiles: survivors kept, lost pieces as ghosts. | 001a D-23, D-30, D-42 |

### 10.2 Destroy

| Where | Rule | Source |
|---|---|---|
| Storehouse and party prep | Unlimited. Any entry, either container. A confirmation each time. A stack takes a count. | 001a D-33, D-34 |
| Path view | ONE per path, on a pack entry only. Saved stage field `discard_used`. Cleared at a successful early leave, at defeat and at the path end. | 001a D-33, D-34 |
| Confirmation | `Keep` has focus. Esc, Back, B and an outside tap mean Keep. 0.25 s open window. 0.6 s lock after confirm. No hold, swipe or drag to confirm. | 001a D-32 |
| Yield | **Destroy returns nothing.** | Part B D-126 |
| Recycle | Not built. Returns Ekwan only (GDD 19.7). Key `data.inventory.recycle_yield_ekwan` is `{}`. V2-ITEM-004 owns it. | Part B D-126, D-134 |

### 10.3 Recipes and prices — BUILT (Part B)

**Story:** V2-ECONOMY-004 Part B (merged). **Decisions:** Part B D-122 to D-149. **Contract:** CONVENTIONS "Recipe price records".

| Rule | Detail | Source |
|---|---|---|
| Shape | `data.inventory.recipes[<output type_id>][<grade key or ungraded>]["make"\|"upgrade"] = { inputs: [{type_id, count}], cost: {ekwan, ase} }` | D-124 |
| Shipping state | `recipes` is `{}`. Placeholder recipes live in `tests/fixtures/recipe_placeholders.json` only. | D-131 |
| No price on a definition | The old reserved `cost` on a definition was removed (D-137 replaces the "stays reserved" text of D-124). | D-137 |
| Lookup | `RecipeCostService.cost_of(inv_cfg, output_type, grade_key, route)` returns `{ reason_key, cost }`. It returns only `ok`, `unknown_recipe`, `bad_cost`. | CONVENTIONS |
| Afford and pay | `RecipeCostService.afford(...)` and `EconomyService.pay_cost(cost, reason, logger, t, context)` give `short_ase`, `short_ekwan`, `short_both`. `short_items` is reserved for ECONOMY-003, not in code. | D-132, D-145 |
| An item is never a currency | An item row keeps 0 Ase and 0 Ekwan. The inventory shows no worth. Items are made with Ekwan and Ase. They are never turned into them. | D-125 |
| Materials | Crafting inputs only: never a price, never sold, never a balance. | 001a D-06 |
| Relic | A relic cannot be made or upgraded. It may be an input. | D-143 |
| Upgrade | The old piece leaves the inventory. A new piece of the higher grade arrives with a new id. An equipped piece must be unequipped first. ECONOMY-003 builds this. | D-147 |
| Flat price | A recipe price is flat across realms. No scale field. | D-141 |
| No gate field | No Standing or Continuity gate yet. ECONOMY-003 adds it. | D-139 |
| Shipping test | A recipe with price 0 and 0 fails the shipping data test. | D-138 |
| Debug | `debug.recipe.run`, F1 command `recipe check\|pay ...`, debug builds only. | CONVENTIONS |
| Player parts | None. Price display, "cannot afford" text and feedback belong to ECONOMY-003. | D-133 |

---

## 11. Determinism and saved state

### 11.1 Built in 001a — BUILT

| Item | Detail | Source |
|---|---|---|
| Save block | `inventory { version, next_seq, items, stacks, pack, pack_stacks }`. A `slot` on each entry. | 001a `step7`; `handoff.md` |
| Stage fields | `held_fates`, `discard_used`. Item rows in `stage.earnings`. | 001a D-33 |
| Not saved | `FlowContext.pending_inventory_refusal`, panel open state. | 001a D-33, D-48 |
| Streams | Leave draws on `inventory.leave.*`. `stage.settle` is unchanged. | 001a D-43 |
| Fingerprint | The Sanctum fingerprint test erases `data.inventory` before it hashes. | 001a D-27 |
| No repair | No repairs or bridges for old saves until Jeff says a 1.0 version is live. | ANSWERS #88 |

### 11.2 Built in 001b — BUILT (C1 to C10)

| Item | Rule | Source |
|---|---|---|
| New streams | `inventory.finds.<stage_id>.<run_count>.<situation_id>` (finds chance). `inventory.pick.<stage_id>.<run_count>.<situation_id>` (chooser). Never `stage.settle`. | D-05, D-49 |
| Draw order | Finds chance: all `cap` slot draws, always. Chooser: one draw. The pick rule makes no further draw. | D-49, D-05, D-06 |
| Stamps | Finds result stored at the first draw. A saved pick stamp for the chooser. The saved field names are OPEN (section 14 Q6). 001a `decisions.md` section 8 names `stage.pick_stamps`. 001b `decisions.md` D-05 says "a saved pick stamp" without a name. | D-05, D-49 |
| Swap flag | Saved stage flag, proposed name `swap_used`. | D-03, D-27 |
| Event state | BUILT (C6, C9): the record `stage.pickup` (with `phase` "idle" or "done") rebuilds the field; the pending result holds the board keys. The event resumes at idle after a quit. | D-58, D-66 |
| Exactly once | The find row id stamp (section 3.1) and the pick stamp. A reload, retry or replay gives the same chooser, picks and finds. | ANSWERS #87 |
| Core vs UI | The UI never reads the save. It reads `snapshot` data only. | AGENTS.md |
| Config | All tunables in `data/balance.json` (ANSWERS #83). | D-09, D-46 |

---

## 12. Text rules

| Rule | Detail | Source |
|---|---|---|
| Voice | Natural, familiar, concrete. Short sentences. No GDD or code words ("Storyweight", "vector"). Echoes never explain the simulation. | Project voice |
| Word rules | Never "home", never "stage". Say Sanctum, path. What is not carried is "lost". | ANSWERS #86 |
| Approval | Jeff approves every player-facing line. An agent proposes and stops. | ANSWERS #89 |
| 001a text | All item text lives in `ui/components/ItemUiText.gd`. Approved lines carry `# APPROVED (Jeff <date>)`. The fixture `tests/fixtures/ItemUiApprovedCopy.json` holds them. A test compares word for word. To change a line: new approval, new string, new fixture, new date. | CONVENTIONS; 001a D-51 |
| 001b text | Pointer lines, barks, swap token lines ("1 swap left on this path.", "No swap left."), refusal lines and the Directive prompt are `AGENT-WRITTEN (proposal)`. Jeff reviews ALL copy in one pass at the end, after his playtest. Nothing ships as final before that. | D-10, D-56 |
| No ids | No id, key or number as text. A row shows `name` or the kind word. | CONVENTIONS |
| Scenes | A `.tscn` holds no item words. | CONVENTIONS |
| Barks | The pose carries the meaning. The bark stays short. A bark never explains the simulation. A full-pack bark says the pack is full (D-41). | Project voice; D-41 |

---

## 13. Stories and seams

Story codes below come from `docs/Echoes vNext V2 Story Backlog ..._all.csv`. The CSV can drift from Notion. **Codes marked (unverified) were not checked in Notion.**

### 13.1 Stories

| Story | Status | What it owns |
|---|---|---|
| V2-ITEM-001a | Done, merged | Containers, slots, moves, destroy, early-leave rules, item rows, panels, approved text (sections 2, 3.1, 9.1, 10) |
| V2-ECONOMY-004 Part B | Done, merged | Recipe price contract, `pay_cost`, removal of the definition `cost` (section 10.3) |
| V2-ITEM-001b | Backend built (C0 to C12, D-01 to D-67); UI steps U1 to U12 not built | Finds chance and cap, chooser, pick rule, event state before Resolve, pointer, pack panel and details in the event, swap, reaction class (not the effect), debug producer growth, path pack view of gathered finds (sections 3.3 to 7, 9.2) |
| V2-ITEM-002 (unverified) | Draft | Real drops, item catalogue, definitions, grades, images and descriptions. Calls the finds function. Seam S1. |
| V2-ITEM-003 (unverified) | Draft | Equipment, the four slots (GDD 19.3), pack size per Echo. Seams S4, S5. |
| V2-ITEM-004 (unverified) | Draft | Recycle (Ekwan only), recycle of a dropped item, the yield key. Seam S4. |
| V2-ITEM-005 (unverified) | Draft | Death-formed relic seam (CSV text). Duplicate rows exist (001a handoff). |
| V2-ECONOMY-003 (unverified) | Draft | Crafting screen, held-item check, item consumption, price display, `short_items`, use of materials. Seam S6. |
| V2-CONTINUITY-002 (unverified) | Draft | Pack size by Sanctum progression (note). Seam S5. |
| Pickup placement on the board | Built in 001b (D-72) | Section 8. Seam S2. |
| Pickup reaction effect | New, no code | Emotion change through `EmotionService` (section 7). Seam S3. |

### 13.2 Seams S1 to S6 (001b story split, D-29)

Source: Jeff's acceptance of the split as a working draft (001b D-29, 2026-11-12). The seam definitions below come from the story split in the design chat. D-29 lists the seam numbers but does not define them in the repo. This section is the first written record.

| Seam | Name | What 001b builds | What 001b must NOT build | Who takes the rest |
|---|---|---|---|---|
| S1 | Finds source | The call `record_found_items(finds)` (exists from 001a) and the pick function (chooser draw and pick rule, section 4). The finds chance and cap function (D-49) is built with the pick function. | No drop table, no loot source, no item catalogue. | V2-ITEM-002 |
| S2 | Placement | `PickupPlacement.place`: a board tile per standing Echo and per find, by a seeded hash rule (D-72; section 8). | No fall-cell logic and no objective anchors (D-32 is not used). | Nobody: built in 001b. Jeff may reopen D-32 as a new story. |
| S3 | Reaction | A reaction class on the pick result (plus, none, minus; section 7). | No `EmotionService` call. No emotion value changes. | The new "Pickup reaction effect" story |
| S4 | Swap legality | One function `swap_is_legal` (section 6.2). | No rules for equipped or in-use items. No recycle route for the dropped item. | V2-ITEM-003 (equipped items); V2-ITEM-004 (recycle of a dropped item) |
| S5 | Capacity | Reads the pack size from config and the pack service (`InventoryService.box_size`, `pack_free`). | No hard-coded 4. No pack size by progression or per Echo. | V2-CONTINUITY-002 (by progression); V2-ITEM-003 (per Echo) |
| S6 | Material use | Materials show as items only. | No use of materials. | V2-ECONOMY-003 |

The function names `swap_is_legal` and the S1 pick function are names from the story split. They are proposals until `mechanics-developer` builds them. No story code in this table has been checked in Notion.

---

## 14. Open questions

| No | Question | Who decides |
|---|---|---|
| Q1 | CLOSED (001b C4). The full tables are in `docs/stories/v2-item-001b/pick-numbers.md` and in `data.inventory.pick`. | none (decided) |
| Q2 | Who calls `record_found_items` for real drops, and where does the rule live? | Jeff (ITEM-002) |
| Q3 | Do Standing 6 and 9 Callings resolve to a Calling family? | Jeff |
| Q4 | The size of the emotion plus and minus. Which `EmotionService` values? Does the plus stack with the +10 win lift without a cap? | Jeff (Pickup reaction effect story) |
| Q5 | CLOSED. `swap_used` clears at an early leave, at defeat and at the path end, as `discard_used` does. Decided by 001b D-04 (Jeff approved it in the interview). The left-list part of D-04 is superseded by D-14. Kept here so the numbering holds. | none (decided) |
| Q6 | CLOSED (001b C6, C9). The saved record is `stage.pickup` (with `phase` idle or done); the saved swap flag is `stage.swap_used`. A reload resumes at idle. | none (decided) |
| Q7 | OPEN: does the pack grow with the finds cap? (CLOSED half: a limit by free board cells. D-72: there is none; a pile takes the finds that no free tile can hold.) | Jeff (D-46) |
| Q8 | Are slot rolls for finds independent or is it one count roll? (Assumed independent from D-50.) | Jeff |
| Q9 | The leftover rule for a stack larger than one stack. | Jeff (ITEM-002) |
| Q10 | The item catalogue: names, grades, rarity ladder (GDD 21.1 lists it as open). | Jeff (ITEM-002) |
| Q11 | The look of a pile (how finds that share a tile are drawn). The rule is built (D-72): a pile is the last fallback in `PickupPlacement`. | Jeff (UI) |
| Q12 | Panel placement of the Travel pack, small text size, and other UX points of the redesign (K1, K2, F11-03, F11-04). | Jeff (UX redesign) |
| Q13 | Notion rows: 001b, the reaction story, the catalogue. Each needs Jeff's yes. (D-72 built the placement in 001b: no placement story.) | Jeff |
| Q14 | The Directive field name `confirm_leave_items`, the `swap_used` name and the function names in section 13.2 are proposals. | Jeff, `mechanics-developer` |
| Q15 | A pack debuff stays closed (001a D-36). Revisit only if play shows nobody feels the pack. | Jeff |
| Q16 | The win fear of -5 (from D-33 text) is not verified in config. Which key holds it? | `mechanics-developer` |

---

## 15. Change log

One line per story. Newest last.

| Date | Story | Change |
|---|---|---|
| 2026-11-08 | V2-ITEM-001a | Built the containers, slots, moves, destroy, item rows and the early-leave rules. Approved item text and panels. |
| 2026-11-09 | V2-ECONOMY-004 Part B | Added the recipe price contract. Removed the definition `cost`. Added `EconomyService.pay_cost`. |
| 2026-11-10 to 2026-11-13 | V2-ITEM-001b design | Recorded D-01 to D-56 as DESIGNED: finds chance and cap, chooser, pick rule, pickup event, swap, reaction class. Defined seams S1 to S6 in section 13.2. |
| 2026-11-15 | V2-ITEM-001b C9 | Wired the pickup event into a won fight (backend): hook, pending-result hold, end mark, resume, Resolve block 18. |
| 2026-11-15 | V2-ITEM-001b C10 to C12 | Built the debug producer modes and scene check and apply (C10), probes P1 to P3 (C11) and the unwired-register test `pickup_unwired` (C12). `sense_base` 0.3 to 0.0 (D-67). Section tags moved to BUILT for the backend; the UI steps stay DESIGNED. The reaction key is `none`, not "neutral". |

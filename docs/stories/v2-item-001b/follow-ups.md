# V2-ITEM-001b: follow-ups and unwired register

Written in STE. Jeff's rule: no loose ends. Every part that 001b builds but does not wire has a clear note and a target story here. Each row has a code marker `# UNWIRED (target: <story code>): <what>` at the seam. The test `pickup_unwired` (backend step C12) fails if a marker names no story code, or if a row here has no marker. Story codes come from the backlog CSV. The CSV can lag Notion. Check each code in Notion before any row is changed. Nothing is written to Notion without Jeff's yes.

The design record is `decisions.md` (D-01 onward). The cross-story design is `docs/inventory-and-items-design.md`. The seams S1 to S6 are defined in its section 13.2.

| # | What is unwired | What exists in 001b | Target story | Wire it when | Marker site |
|---|---|---|---|---|---|
| 1 | Real finds in real fights | `PickupFinds.finds_for_win` returns none in shipping. Only debug `event` and `arm` produce finds. | V2-ITEM-002 (seam S1) | real drops exist | `PickupFinds.gd` |
| 2 | Real item names, grades, images, descriptions | placeholder definitions in the test fixture. Details show placeholders. | V2-ITEM-002 | the catalogue exists | details card, `ItemUiText` |
| 3 | Real placement (where enemies fell) and no-kill objective anchors | a simple row (`finds[].cell`) | new story "Pickup placement on the board" (S2); marker `NEW "Pickup placement on the board"` (D-65) | the placement story starts | `PickupEventService.open_after_win`, where the rows get `cell` |
| 4 | The emotion effect (plus and minus) | a reaction class only. No `EmotionService` call. | new story "Pickup reaction effect" (S3); marker `NEW "Pickup reaction effect"` (D-65) | that story starts | `PickupEventService.open_after_win`, where `reaction` is stored |
| 5 | Swap with equipped or in-use items | swap legality ignores equipment | V2-ITEM-003 (S4) | equipping exists | `PickupSwapRules.gd` |
| 6 | Recycle route for the dropped item | the dropped item is lost | V2-ITEM-004 (S4) | recycle exists | `PickupEventService.commit_swap` |
| 7 | Pack size by progression and per Echo | pack size is read from config only | V2-CONTINUITY-002 and V2-ITEM-003 (S5) | those stories start | cap and pack readers |
| 8 | Use of materials | materials show as items only | V2-ECONOMY-003 (S6) | crafting exists | none (no code) |
| 9 | `confirm_leave_items` on future Directives | set on Scout Carefully (true) and Seek Signs (false) | V2-DIRECTIVE-003 (new Directives) | a Directive is added | `DirectiveService` |
| 10 | Finds cap and chance numbers beyond realm.02 | bands 1.75, 2.5 and 3.5 are placeholders | V2-ITEM-002, or the story that adds realm 3 | realm 3 exists | `finds_cap_by_realm_scale` |
| 11 | Cell limit on the cap, and the piles rule | none | the placement story | the placement story starts | the cap helper |
| 12 | Repetition forms (short and brief intro) | Skip only | a feel pass after Jeff's playtests (no story yet: Jeff names it) | Jeff decides | `PickupEventPlan.gd` |
| 13 | Win emotion drift is skipped after a reload on the Resolve card (pre-existing). A reload during the pickup event also skips the win steps (emotion drift, `check_vow_discovery`, `clear_ally_fields_if_present`), because the machine is then in RESOLVE, not ENCOUNTER (found by C9 QA). | inherited, not fixed | no story: Jeff assigns (candidate: V2-ECONOMY-004 follow-ups) | Jeff decides | noted here only |
| 14 | UX redesign items: pack discoverability, text size, panel placement | not touched | Jeff's UX redesign | that redesign starts | design document Q12 |
| 15 | Debug producer, debug cap override, F1 scene menu | debug builds only | none: stays debug-only. Remove only if Jeff asks. | not applicable | `DebugController.gd` |
| 16 | A natural freeze in real play | the freeze path is built and tested. Probe P3 measures the rate. | the pick tuning (D-09) after P3 | the P3 result | `PickupPick.gd` |
| 17 | `realm.seed` is a 63-bit int stored as a JSON number. After a reload it can lose digits. Every seeded stream that reads it after a reload is affected. Found by C9 QA. Needs an opus determinism check. | not fixed (pre-existing, project-wide) | new story "Realm seed survives a save reload" | Jeff decides | `PickupEventService.open_after_win` (finds roll, chooser draw), `PickupSnapshotBuilder.build` (pointer) |

## Other open items (not unwired code)
- The pass line for the Standing 1 against Standing 9 probe (D-09). Needs a number from `mid-game-designer`, approved by Jeff, before step C4 closes.
- What Resolve shows for final items beyond the `data.pickup_result` block.
- The real sizes of the emotion plus and minus (the reaction story).
- Notion rows for 001b, the placement story, the reaction story and the catalogue. Each needs Jeff's yes.
- Short notes on the Notion rows of V2-ITEM-001, V2-ITEM-002 and the other target stories, pointing at the design document. Only with Jeff's yes.
- Jeff reviews ALL player-facing copy in one pass at the end (D-56).

## Convention for a new unwired part
1. Add one marker line at the seam: `# UNWIRED (target: <story code>): <what>`.
2. Add one row to this table with the trigger.
3. Add the target story to section 13 of the design document if it is not there.

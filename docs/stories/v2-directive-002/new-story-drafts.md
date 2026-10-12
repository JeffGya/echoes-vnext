# New story drafts for Jeff's approval

Source: decisions D-25 (bond interrupt) and D-31 (bridges and hazards) in `decisions.md`.
Status of this file: DRAFT. Nothing is written to Notion. Player-facing wording is Jeff's. This file proposes none.
Checked against Notion on 2026-10-11 (read only).

## 0. Codes and Order (both stories)

| Item | Finding |
|---|---|
| Next free BOND code | `V2-BOND-004`. Notion holds BOND-001, 002, 003 only. Docs and ANSWERS.md hold no BOND-004. |
| Next free STAGE code | `V2-STAGE-010`. Notion holds STAGE-001 to 006, 009, 101 to 103. 007 and 008 are unused, but 009 exists, so I skip the gap. Docs hold no STAGE-007, 008 or 010. |
| Order for bond interrupt | `254.5`. Right after V2-DIRECTIVE-002 (254). Both new stories depend on DIRECTIVE-002 B+C, so they must sort after it. |
| Order for hazards | `254.6`. Right after the bond interrupt. |
| Neighbours of 254.5 and 254.6 | 253 V2-COMBAT-003, 253.5 V2-COMBAT-003.5, 254 V2-DIRECTIVE-002, then 259 V2-ITEM-005 (Draft), 260 V2-ITEM-006 and V2-INFRA-003, 261 V2-INFRA-004, 262 V2-COMBAT-004 and V2-INFRA-005. No row uses 254.5 or 254.6. |
| Order clash seen | V2-INFRA-010 and V2-COMBAT-005 both use 262.9. Not in scope. Reported only. |

## 1. Story 1: Stage bond interrupt (V2-BOND-004)

### 1.1 Text

| Field | Draft |
|---|---|
| Summary | When a bonded Echo is in distress on the stage, the party stops and the Keeper must help or leave them. Bonds then change what a stage walk does, not only combat. |
| Story | Let a bonded Echo in distress stop the stage party and force a rescue-or-abandon choice, as one of the stage stop kinds, so that who is connected to whom changes what the party does on the map. |
| Definition of Done | One distress trigger rule, authored in config. A stage stop of the bond-interrupt kind. A rescue path and an abandon path, each with a defined consequence on the bond graph and on the Echo. A visible stop and choice on the stage screen. Tests build Echoes with real bonds. Bonds do not count twice in stage routes. |
| Exit Criteria | See 1.2. |
| Dependencies | V2-DIRECTIVE-002 (phase B+C: the stop-kind slot, decision D-25); V2-BOND-002 (Done); V2-EMOTION-001 (fear, refusal); V2-STAGE-004 (Done: situation and encounter model). Check also V2-DIRECTIVE-003 (soft, see 1.6). |

### 1.2 Exit criteria (checkable)

1. The bond-interrupt stop kind from phase B+C is the only stop slot used. No second slot is added.
2. A config value defines "distress". The rule has a test with one case that fires and one that does not.
3. A stage walk with a bonded Echo in distress ends with the bond-interrupt stop. The same walk with an unbonded Echo in the same state does not.
4. The Keeper can choose rescue or abandon. Each choice changes the save in a way a test can read (bond value, fear or morale, party state).
5. The interrupt fires at most once per distress event. A test proves no repeat loop and no soft-lock.
6. A test proves no double count of bonds: stage Judgment already includes the bond-support term (decision D-26). The interrupt reads the bond graph for the trigger and the consequence only. It adds nothing to Judgment, route score or profile.
7. Same save and same seed give the same result (determinism test). No new RNG draw is added to `EchoFactory`.
8. Both Directives (Scout Carefully, Seek Signs) honour the interrupt. Neither can skip it.
9. The stage screen shows the stop and the choice. No ID shows. Wording is Jeff's.
10. Compile check and the filtered suites named in 1.7 pass. Jeff tests in game.

### 1.3 Scope IN

- A distress trigger rule (after Jeff answers 1.5).
- The stop on the stage walk: fills the slot that B+C defines.
- Rescue and abandon outcomes and their save effects.
- A stage screen surface for the stop and the choice.
- Tests with real bonds.

### 1.4 Scope OUT

- The stop-kind slot itself (V2-DIRECTIVE-002 B+C, D-25).
- Bond support in stage Judgment (V2-DIRECTIVE-002, D-26). Not changed here.
- Combat bond events and bonded-danger in combat (V2-BOND-002, Done). Not changed here.
- The `regroup` goal source from bond events in combat (V2-COMBAT-004, D-07).
- Bond rupture, mediation, reconciliation (V2-BOND-003).
- Vows (V2-VOW-002) and equipment (V2-ITEM-003).
- New Directives or Directive unlock (V2-DIRECTIVE-003).

### 1.5 Open design questions for Jeff

| # | Question | Options and note |
|---|---|---|
| BQ1 | What counts as distress? | (a) Fear at or above the refusal level. (b) Fear at or above a lower "shaken" level. (c) A stage event hurts a bonded Echo (a situation result, not a number). (d) Any of these. Recommend (a) plus one named stage cause: it reuses an existing level and avoids a new number. Not Jeff-confirmed. |
| BQ2 | Which bond strength makes an Echo "bonded" for this trigger? | A threshold in config. Number is PROPOSED DEFAULT until Jeff sets it. Check the existing BOND-002 thresholds first and reuse them. |
| BQ3 | Who sees the distress: any party member bonded to the Echo, or the whole party? | Recommend: the party stops only if at least one party member holds a qualifying bond with the Echo. |
| BQ4 | Is the distressed Echo in the party or outside it? | The draft assumes in the active party. A bonded Echo left in the Sanctum is a different story. |
| BQ5 | What does "rescue" cost and what does "abandon" cost? | Steps, fear, morale, bond change, time? Jeff decides the numbers and the loss. |
| BQ6 | Is distress recoverable? | If the player ignores or abandons, can the Echo recover later in the same run, or is the loss permanent for the run? Permadeath links to V2-INFRA-005 (death ripple). Do not create a death path here without Jeff. |
| BQ7 | Can the interrupt fire on every Advance, or once per Echo per stage? | Recommend once per Echo per stage until Jeff says otherwise (soft-lock guard, criterion 5). |
| BQ8 | Does a bonded Echo at refusal also refuse to walk (existing fear rules)? | Check what fear refusal already does on stage. The interrupt must not duplicate it. |

### 1.6 Overlap and "must not overlap"

| Story | Relation |
|---|---|
| V2-DIRECTIVE-002 | Owns the slot and D-26. This story fills the slot. Must not change Judgment or add bond terms to routes. |
| V2-BOND-002 (Done) | Owns combat bond consequence. This story adds the stage consequence. Reuse its thresholds. Do not change combat. |
| V2-BOND-003 (Draft, Full Game) | Owns long-term bond change (rupture, reconciliation). This story may write the immediate bond effect of rescue or abandon only. Name the write points so BOND-003 can build on them. |
| V2-COMBAT-004 | Owns the `regroup` goal from bond events in combat. No shared code. If COMBAT-004 builds first, check its bond-event API before choosing the bond read path. |
| V2-DIRECTIVE-003 | Adds new Directives. Each new Directive must pass through the interrupt without a code change. Soft dependency only. |
| V2-ITEM-003 | No relation now. Equipment must not change the trigger. |

### 1.7 First subtasks

1. **Confirm contracts first.** Stage stop-kind slot from B+C (name, where declared, where consumed); the `StageExploreTurnService.advance_turn` stop path; `SocialGraphService` read API; fear refusal level in config and where `ContactController` or `EmotionService` reads it; the snapshot fields the stage screen reads; action types. Grep for the consumer of every config key before placing it in `data/balance.json`.
2. Backend: the distress rule (config, one reader).
3. Backend: the stop in the stage walk, once-per-event guard.
4. Backend: rescue and abandon actions (slot-keyed Dictionary actions) and their save effects.
5. Backend: stage snapshot fields for the stop and the choice.
6. Tests (`tests/` suite name to be fixed in subtask 1; propose a `stage_bond_interrupt` suite): trigger fires and does not fire; no repeat; no double count of bonds; determinism; both Directives.
7. Compile check and filtered test run. Backend complete before frontend starts.
8. Frontend: stage screen surface for the stop and the choice (ui-ux-designer designs; 48 dp targets; non-colour cue). Wording is Jeff's.
9. Jeff tests in game.
10. **Docs + Commit:** update `CONVENTIONS.md` (stop kinds, actions), `docs/canon-index.md` if sections move, `decisions.md`; one commit when Jeff asks.

### 1.8 Notion property values — NOT WRITTEN

| Property | Value |
|---|---|
| Code | `V2-BOND-004` |
| Story | (text in 1.1) |
| Summary | (text in 1.1) |
| Definition of Done | (text in 1.1) |
| Exit Criteria | (list in 1.2, as one text block) |
| Dependencies | `V2-DIRECTIVE-002, V2-BOND-002, V2-EMOTION-001, V2-STAGE-004` |
| Status | `Draft` |
| Type | `New` |
| Horizon | `Foundation` |
| Wave | `Foundation` |
| Order | `254.5` |
| Priority | `P1` (a core-work item per Jeff, D-25) |
| Spec State | `Open` (trigger rule undecided) |
| Prefix | `BOND` |
| System Area | `SANCTUM / BOND / VOW / VOICE` (same as BOND-002; the Prefix decides it) |
| Area | `Realm / Tactical` (play happens on the stage; BOND-002 used `Sanctum`. Jeff may prefer that) |
| Epic | `Echo Consequence Layer` (the epic of BOND-002) |
| Theme | `["Bonds","Stages"]` |
| Source GDD | `Echoes vNext Working GDD V2.5: bonds feed wholeness, risk, refusal and house consequence (as BOND-002). Movement model 10.5 (Bonds and vows) and 11.7 (Stage interruption). Decisions D-25, D-26 in docs/stories/v2-directive-002/decisions.md.` Exact GDD section numbers still to be confirmed by the design pass. |
| Repo Evidence | `docs/stories/v2-directive-002/decisions.md (D-25, D-26); design.md sections 2, 3a, 10; core/sanctum/SocialGraphService.gd; core/realms/StageExploreTurnService.gd; docs/movement-model.md 10.5, 11.7` |
| Legacy Source | empty |

## 2. Story 2: Stage hazards and exposure (V2-STAGE-010)

### 2.1 What the Notion V2-COMBAT-004 page says (quoted)

The page has "Obstacle and Hazard Foundation Addendum — 2026-07-17". Quotes:

- "Obstacles and hazards are part of the canonical Foundation tactical field. They are not optional decoration or late presentation polish."
- "Briefing reveals only terrain and hazards actually known through the production stage-intel contract."
- Closing line: "The persistent stage map and tactical combat field remain distinct spatial scales. Shared terrain, hazard, knowledge, cost, and result contracts may serve party exploration, but `V2-COMBAT-004` does not silently take ownership of stage-map topology or stage Obstacle situations."

So: the addendum makes combat-field hazards Foundation. It leaves stage-map hazards to another story. It allows shared contracts. This story is that other story. Note: the same page says hazards are "walkable cell/edge effects" and obstacles are projections of non-walkable topology. The stage map must follow the same collision rule (`walkable` is the only collision authority).

### 2.2 Text

| Field | Draft |
|---|---|
| Summary | Put hazards on the stage map. Some are known, some are hidden until the party learns of them. Known hazards price the party's route. A decision-critical hazard stops the party. |
| Story | Create hazard data on the stage map, with a reveal path, and write it to `known_hazards`, so that route scoring prices exposure, the party can stop for a hazard, and the combat approach receives the hazards the party learned. |
| Definition of Done | Stage generation places hazards by a deterministic rule. Hazards are known or concealed. A reveal path moves a hazard from concealed to known. Known hazards feed the exposure map that V2-DIRECTIVE-002 B+C reads. A decision-critical hazard produces a stage stop. `known_hazards` is written and the combat approach reads it. The bridge question has a recorded answer. |
| Exit Criteria | See 2.3. |
| Dependencies | V2-DIRECTIVE-002 (phase B+C: the exposure seam, D-02 and D-31); V2-STAGE-001 (Done: hides exact hazard detail); V2-STAGE-004 (Done: obstacle role and encounter model); V2-COMBAT-002 (Done: hazard grammar in `MovementHazardService`). Check also V2-INTEL-001 and V2-INTEL-002 for the reveal path. |

### 2.3 Exit criteria (checkable)

1. Stage generation places hazards by a deterministic rule. Same seed gives the same hazards. A test proves it. No reordered `EchoFactory` draw.
2. Every hazard has a state: concealed or known. A concealed hazard never reaches route scoring, the snapshot, the stop logic or the combat approach (test: the exposure map is identical with and without a concealed hazard).
3. A reveal path moves a hazard from concealed to known. At least one reveal source exists and has a test (Jeff chooses the source, see 2.5).
4. `known_hazards` in `stage_context.encounter_approach` is written from the known stage hazards. A test shows `LiveMovementContextService` (about line 690, `_live_combat_known_hazards`) reads a non-empty list from a real stage walk.
5. Known hazards fill the exposure map source. The same board with and without a known hazard gives a different route or price, under at least one Directive. With no hazards, route scores equal the B+C values (empty-seam test stays green).
6. A decision-critical hazard stops the party. Which hazards are decision-critical is a Jeff decision (2.5). The stop uses an existing stop slot, or a slot added with a recorded reason.
7. Hazard rules reuse `MovementHazardService` (unstable, binding, burning). No second hazard resolver exists. A grep test blocks a duplicate.
8. The bridge question is answered and recorded as a decision: bridge cells are exposed ground or not, and hazards sit on bridges or not. The code follows the answer.
9. No hazard blocks the only route to the objective (reachability check). No generated stage is a soft-lock.
10. `walkable` stays the only collision authority. A hazard never changes collision.
11. The stage screen shows known hazards by pattern or icon, not colour alone. No ID shows. Wording is Jeff's.
12. Compile check and filtered suites pass. Jeff tests in game.

### 2.4 Scope IN and OUT

Scope IN:

- Hazard data on the stage map: placement, known versus concealed state.
- A reveal path.
- Writing `known_hazards` (today read, never written).
- The decision-critical hazard interrupt.
- Known hazards as an exposure-map source for route scoring.
- The bridge and hazard question (D-31).
- Stage hazard display.

Scope OUT:

- Combat-board hazards, board generation, hazard validation, and combat hazard readability (V2-COMBAT-004 slice 004B and 004D).
- The exposure seam and route pricing code (V2-DIRECTIVE-002 B+C). This story fills the source. It does not rebuild the seam.
- Stage obstacle topology and the obstacle situation role beyond what hazards need (V2-STAGE-004, Done). The COMBAT-004 page says it does not take these. Decide in subtask 1 whether any part belongs here.
- New hazard types beyond unstable, binding, burning.
- Realm hazard identity and ecology (V2-STAGE-102, V2-STAGE-101).
- Stop-short Directive cause (V2-DIRECTIVE-002 phase D).

### 2.5 Reusable grammar from combat

`core/movement/MovementHazardService.gd` (pure, stateless, deterministic, config injected). Today it is called by `MovementExecutor` and combat only.

| Item | Detail |
|---|---|
| Types | `HAZARD_TYPES = ["unstable", "binding", "burning"]` |
| Fact shape | `{ id, position{col,row}, hazard_type }` (`MovementKnownHazardFact.build()`) |
| Config | `data.combat.movement.hazards`, injected by the caller |
| Order per activation | cell entry, then unstable displacement or fallback damage, then binding stop; burning at end of activation only |
| Ledger | each type triggers once per activation (`hazard_ctx`) |
| Terrain | uses `StageTerrain.is_legal_edge` and the `walkable` set |

Questions for subtask 1: does the stage walk have "activations", so the ledger and the "burning at end" rule map? What is a hazard's effect on a party walk (damage, forced step, lost steps), or is it only a price and a stop? The header comment of this file says DORMANT and "NOT wired into live combat/flow". Verify before reuse (comments are not evidence).

### 2.6 Open design questions for Jeff

| # | Question | Note |
|---|---|---|
| HQ1 | Are bridge crossings exposed ground? Do hazards sit on bridges? | D-31: Jeff could not answer yet. The answer decides whether bridge cells join the exposure map. Default until then: bridges are not exposure. `StageTerrain.bridge_cell_set` already gives the cells. Options: (a) bridges exposed, no hazards on them; (b) bridges exposed and hazards allowed; (c) bridges not exposed, hazards allowed; (d) neither. |
| HQ2 | What reveals a hazard? | Candidates: Scout Carefully walking, Seek Signs, intel, an Echo with a Sight Calling, stepping next to it, a failed step. Jeff chooses; it must fit Directive contrast (D-08). |
| HQ3 | Which hazards are decision-critical (stop the party)? | Recommend: a known hazard on the only way forward, or a binding or burning hazard the walk is about to enter. Jeff decides. |
| HQ4 | Can the party walk into a hazard on purpose? | Costs and effects per type on a party walk. |
| HQ5 | Do hazards persist per stage (stage is locked on first entry, STAGE-001)? | Recommend: yes, generated once and saved with the stage. |
| HQ6 | Does concealed mean never seen until triggered, or revealed by a rule? | Same as HQ2. |
| HQ7 | Are hazards Foundation content for all realms, or only the first realm? | Scope control for test count. |

### 2.7 Wave and Horizon: proposal

| Option | Reasons |
|---|---|
| **Foundation (recommended), Order 254.6, P2** | (1) V2-DIRECTIVE-002 B+C ships an exposure seam that stays empty until this story. An empty seam in Foundation is unfinished work. (2) The COMBAT-004 addendum calls hazards Foundation for the combat field and says briefing reveals "only terrain and hazards actually known through the production stage-intel contract". That contract does not exist until stage hazards are written. (3) `known_hazards` is read in combat and never written: a half-built path. (4) V2-STAGE-001 (Done) already promises hidden hazard detail. |
| Expansion (Horizon `Post-Foundation`), Order about 545 | (1) The stage works without hazards today. (2) V2-STAGE-101 (540) and V2-STAGE-102 (Full Game) own ecology and hazard mix. (3) The open bridge question and the reveal source are not decided. (4) The story is large: generation, reveal, interrupt, display. |

Recommendation rests on reason (1) and (2). If Jeff prefers a smaller Foundation story, cut the display and the decision-critical interrupt to a follow-up and keep: data, reveal, `known_hazards` write, exposure source.

### 2.8 Overlap and "must not overlap"

| Story | Relation |
|---|---|
| V2-COMBAT-004 | Slice 004B owns combat-board hazards. This story owns the stage map. Shared: hazard facts and `MovementHazardService`. COMBAT-004 must receive `known_hazards` from the approach, not generate its own stage knowledge. Agree the fact shape in subtask 1. Do not change the combat board field. |
| V2-DIRECTIVE-002 B+C | Owns the exposure seam. This story is the source. Must not change route price scale `(1 - effective tolerance)`. |
| V2-BOND-004 (Story 1) | Both add a stage stop reason. Do not build two stop slots. Whichever builds second reuses the first stop plumbing. |
| V2-DIRECTIVE-003 | New Directives must read hazards through the same exposure map. No Directive id literal in `core/` (ANSWERS #81). |
| V2-ITEM-003 | Equipment (for example boots or a charm) could change hazard effects later. Not in this story. Leave a config seam only if cheap. |
| V2-STAGE-004 (Done) | The obstacle situation role exists. Do not rework it. Decide in subtask 1 if hazards use situation types or a separate list. |
| V2-STAGE-101, V2-STAGE-102 | Ecology and hazard mix per realm. Later. This story gives them the mechanism. |

### 2.9 First subtasks

1. **Confirm contracts first.** `StageTerrain` (walkable, bridge cells, legal edges); stage generation (where content is placed, where `stage_context` is built); the exposure seam signature from B+C; `encounter_approach.known_hazards` write point and the read in `LiveMovementContextService`; `MovementKnownHazardFact` shape; `MovementHazardService` live call sites and config key `data.combat.movement.hazards`; whether the stage has hazard keys in `data/balance.json` (grep each key's consumer before placing it); stage-intel contract in V2-INTEL-001.
2. Record the bridge decision (HQ1) and the reveal source (HQ2) in `decisions.md` before code.
3. Backend: hazard data model and deterministic placement, with reachability check.
4. Backend: known versus concealed state and the reveal path.
5. Backend: write `known_hazards` to the approach; prove the combat read.
6. Backend: exposure-map source from known hazards (fills the B+C seam).
7. Backend: decision-critical hazard stop.
8. Tests (propose `stage_hazards` suite, fixed in subtask 1): determinism; concealed never leaks; reveal; `known_hazards` write and read; route change with and without hazard; empty seam unchanged; reachability; no duplicate resolver.
9. Compile check and filtered test run. Backend complete before frontend starts.
10. Frontend: stage hazard display (pattern or icon, tooltip rule, non-colour cue) and the stop surface. ui-ux-designer and sr-game-artist design. Wording is Jeff's.
11. Jeff tests in game.
12. **Docs + Commit:** `CONVENTIONS.md`, `docs/canon-index.md`, `decisions.md`; update the COMBAT-004 page link to this story (Notion write, needs Jeff's yes); commit when Jeff asks.

### 2.10 Notion property values — NOT WRITTEN

| Property | Value |
|---|---|
| Code | `V2-STAGE-010` |
| Story | (text in 2.2) |
| Summary | (text in 2.2) |
| Definition of Done | (text in 2.2) |
| Exit Criteria | (list in 2.3, as one text block) |
| Dependencies | `V2-DIRECTIVE-002, V2-STAGE-001, V2-STAGE-004, V2-COMBAT-002` (add V2-INTEL-001 if subtask 1 confirms it) |
| Status | `Draft` |
| Type | `New` |
| Horizon | `Foundation` (if Expansion: `Post-Foundation`) |
| Wave | `Foundation` (if Expansion: `Expansion`) |
| Order | `254.6` (if Expansion: about `545`, after V2-STAGE-101 at 540) |
| Priority | `P2` |
| Spec State | `Open` (bridge and reveal questions undecided) |
| Prefix | `STAGE` |
| System Area | `DIRECTIVE / INTEL / STAGE` |
| Area | `Realm / Tactical` |
| Epic | `Stage Influence Layer` |
| Theme | `["Stages","Intel"]` |
| Source GDD | `Echoes vNext Working GDD V2.5: stage framework, persistent stage and hidden hazard detail (as STAGE-001, STAGE-004). Notion V2-COMBAT-004 Obstacle and Hazard Foundation Addendum (2026-07-17), closing line on stage-map topology. Movement model 11.7. Decisions D-02, D-31 in docs/stories/v2-directive-002/decisions.md.` Exact GDD section numbers still to be confirmed by the design pass. |
| Repo Evidence | `docs/stories/v2-directive-002/decisions.md (D-02, D-31); design.md sections 3b, 10, 13; core/movement/LiveMovementContextService.gd (about line 690, _live_combat_known_hazards); core/movement/MovementHazardService.gd; core/realms/StageTerrain.gd (bridge_cell_set); core/realms/StageExploreTurnService.gd` |
| Legacy Source | empty |

## 3. Cross-story note

- Both stories add a stage stop reason. Build the shared stop plumbing once (B+C). Do not let two stories each add a slot.
- Both stay out of V2-COMBAT-004 files. V2-COMBAT-004 is Ready at Order 262 and depends on V2-DIRECTIVE-002 and V2-INFRA-004. Neither new story is a COMBAT-004 dependency. Say so in Notion if Jeff wants no hidden link.
- A side effect of D-26 for Story 1: "Stage passes NO bonds into `derive_expression`" in design.md section 2 is now stale (D-26 amends D-03). Design.md section 2 (Bonds row) and section 10 (last "must NOT touch" row) need an edit when B+C starts. I did not edit them (scope).

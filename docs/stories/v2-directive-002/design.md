# V2-DIRECTIVE-002 phases B+C — Design: profile-sensitive Directives on the stage map

Revised 2026-10-12 with D-25 to D-43.

Visual reference: `mockups/v3/index.html` (approved look, marker style 3) and `mockups/review/real-stage-maps.json` (the real stage maps the mockup uses).

Status: Approved by Jeff 2026-10-12 (D-43). Notion Spec State set to Locked 2026-10-12. No number in this file is final. Every proposed number is `PROPOSED DEFAULT, to be authored` by `mid-game-designer`. Numbers already authored in `data/balance.json` are quoted as authored.
Decisions D-00 to D-43 are final and are not re-opened here. Section 12 lists what is resolved and what is still open.
Terms: **Advance** = one stage move command. **Dial** = one named party setting the Directive owns. **Lean** = the push one Echo gives a dial. **Effective steps** = capacity after readiness (D-13).

## 1. Player experience goal

| Item | Rule |
|---|---|
| Feel | "I told them what kind of run this is. They walked it their way, and I can see how." |
| Decision | The player picks Scout Carefully or Seek Signs, and picks who is in the party. Both choices change the route, the stop and the depth. |
| Not the feel | Not a speed switch (3 steps or 6). Not obedience. Not a random result. |
| Visible proof | Same board, same seed, two different parties: a different route, stop or commitment. A quiet stop glyph shows how the party stopped and who held it (section 8). The player can ask for a short "why" (section 8). |
| Ignored Directive | The party still walks sensibly. The default Directive stays playable (section 9). |
| Echo interiority | An Echo reads the order through who they are. The order sets purpose. The Echo sets manner. |

## 2. Profile inputs (D-03 as amended by D-26, ANSWERS #82)

Source of the Echo data: `SanctumService.get_active_party_echoes(save)`. Build each Echo's actor view with the same mapping combat uses (`EchoActor.from_echo`: `rank`, `vector_scores`, `fear` from `emotion.fear_current`, `morale` from `emotion.morale_current`, `fear_base`). Stage and contact read the Echo through ONE shared reader, so a number is never derived twice.

| Input | Carrier for stage traversal | May bend | Bound / limit |
|---|---|---|---|
| Calling family | `data.calling.definitions.<calling_origin>.family` (anchor, edge, sight). Same lookup as `ActorStateMachine.gd:166`. | Anchor: route character, return safety. Edge: exposure tolerance, commitment. Sight: destination weights, stopping. Two effects per family. | Lean only. Never sets a cell or a destination. |
| Virtue domains | Only through the implemented identity state: `vector_scores`, `dominant_vector`. Read by `MovementStyleService.style_alignment_score` (it already holds `vector_bias`, `calling_family_bias`, `fear_weight`, `morale_bias`). | Which route style reads true for the Echo (direct, careful, low_exposure, lateral, forceful). | No new direct ten-virtue multiplier (movement model 10.4). Stage reuses the `MovementStyleService` tables (D-35). No stage-only table. |
| Standing band and Judgment | `MaturityExpressionService.derive_expression` gives `judgment`. `interpretation_width` is the single number derived from it (as combat does). Stage passes the Echo's bonds, as combat does (D-26). | Scales how hard the Echo's dispositional leans (Calling, identity) pull against the Directive. Reduces noise stops (movement model 10.6). | Floor above zero, so a Standing-1 Echo still leans (D-08). Never raises capacity. Never raises obedience. Never lowers path cost. |
| Fear | `fear` and `fear_base` on the actor view. | Exposure tolerance down (primary). Stop willingness up. Readiness band (calm, uneasy, shaken). | NOT scaled by Judgment. Judgment already subtracts fear (`fear_pressure_weight`); scaling fear by Judgment again counts it twice. |
| Morale | `morale` on the actor view. | Commitment (follow-through, primary). Return safety (secondary, low morale only). | Never lifts commitment above effective steps. |
| Bonds | Social graph edges. | Two paths. (1) Judgment support: `bond_support_weight` inside `derive_expression`, the same as combat (D-26). (2) Interrupt (rescue, abandon): a seam only in B+C (D-25). | The bond interrupt has no trigger on stage today. A new Foundation story, "Stage bond interrupt", owns the trigger and the behaviour. B+C builds no bond event. |
| Vows, equipment, injury | Not carried. | Nothing. | Vows wait for V2-VOW-002, equipment for V2-ITEM-003. The Echo save holds no injury field (`EchoActor.gd:56`, hp resets to max at spawn), so "injury" in movement model 11.2 has no stage source. |

Rules for all inputs:
1. Each input bends at most two effects as primary. A fear value does not also move capacity continuously (see section 5).
2. Dispositional leans (Calling, identity) are scaled by Judgment. State leans (fear, morale) are not.
3. No input reads concealed content. Inputs read the Echo and the known board only.
4. Same Echo, same board, same Directive gives the same lean. No RNG.
5. **Bond rule for tests (D-26).** A stage fixture that tests Judgment, a lean or a contrast must give the Echoes real bonds, built through the production path. A fixture with empty bonds hides the bond term and proves nothing about it. At least one contrast (S4 or K4) runs once with bonds and once without, and shows the Standing effect.

## 3. The six effects

Common hard limits (every effect):
- **No exact route.** The Directive and the profile weight options. They never name a cell.
- **No hazard immunity.** Tolerance changes willingness. It never removes a hazard cost or consequence.
- **Concealed content never affects scoring.** Only revealed situations, explored terrain and known facts are inputs. Hidden positions are not read.
- **Directive ordering holds.** For any party, Seek's bent value is at least Scout's bent value on: tolerance, effective steps, commitment depth. Scout's bent value is at least Seek's on: return safety, stop willingness. Each bound is smaller than half the gap between the two authored baselines. A test proves it for every dial.
- **Tier order changes in one place only (D-28).** The old tier 1 (revealed objective first) is replaced by the pool rule in E1. Order after the change: weighted pool (finds and the revealed objective), frontier, passed objective (tier 4 stays). Profile bends utility inside the pool. It does not reorder the remaining tiers.

| # | Effect | Scout Carefully | Seek Signs | How the party profile bends it (bounded) |
|---|---|---|---|---|
| E1 | Destination utility | Intel and reward categories weigh most; combat least (`target_preference` intel 1.4, reward 1.2, combat 0.4). The objective weighs 1.2. Frontier choice prefers cells that keep the road home explored. | Combat and objective weigh most; intel and reward least (combat 1.4, objective 1.6, intel 0.9, reward 0.9). Frontier choice prefers continuing the heading, deeper. | Sight lean raises the intel weight. Edge lean raises the combat weight. Anchor lean lowers it. Fear lowers the combat weight. Per-category bend stays inside a band around the authored weight. The category ranking the Directive authored is never inverted. A bend decides only a tie between two authored weights, and only among targets inside the slack envelope (`_slack_envelope`) (D-44). |
| E2 | Route character | Among routes within the existing slack envelope, pays a high price for exposed cells: a lower-exposure route wins when one exists. Prefers explored ground. | Pays a low price for exposed cells: the direct route wins unless the exposure is large. | Anchor lean raises the price (cohesive, careful). Edge lean lowers it. Identity style table picks the flavour (careful vs lateral vs direct). Fear raises the price. The detour is never longer than the slack envelope. Exposure is a price, never a wall: a target stays reachable. |
| E3 | Exposure tolerance (the ONE exposure input; D-05) | Authored 0.3. Low. | Authored 0.8. High. | Party value = authored value bent by: fear (down), morale (up, small), Edge lean (up), Anchor and Sight lean (down). Clamped inside the bound. Range 0 to 1. E2, E4 and E6 read this dial. They do not read fear a second time. |
| E4 | Stopping behaviour | Stops for any new find its walk reveals (section 3a, D-29). Stops before stepping into a high-exposure cell when tolerance is low. | Stops only for an objective or a hostile situation (section 3a). Passes through other finds. | Sight lean raises stop willingness (reads before committing). Edge lean lowers it. Fear raises it. Judgment removes stops caused by irrelevant finds (noise), never stops caused by relevant ones. The Directive sets which finds count. The profile sets how willing the party is within that set. |
| E5 | Return safety | Authored `escape_bonus` 20 and `intel_retention` true. Strong. | Authored 0 and false. Weak. | Party bends `escape_bonus` inside the bound: Anchor and Sight lean raise it; low morale and an exposed known road home lower it. `intel_retention` and its bonus stay Directive-owned flags. The profile cannot flip them. Only the threshold moves. The escape draw path (`stage.escape.<stage>.<turn_count>`, `VentureController.gd:337`) and the `turn_count` order do not change. Escape is never certain and never impossible. |
| E6 | Commitment | Reassess early. Commitment depth stays at or below effective steps and is cut by E4 stops. | Reassess late. Spend most of effective steps before reassessing. | Morale sets follow-through (low morale: shorter, high: persists). Edge lean deepens. Anchor and Sight lean shorten. Commitment never exceeds effective steps. Commitment is behaviour. Capacity is physical (movement model 7.1, 7.2). |

### 3.1 E1 in plain terms: the objective joins the pool (D-28)

Today the stage picks a destination in strict tiers. A revealed objective always wins (tier 1) and uses no weights. `target_preference.objective` is authored for both Directives, but nothing reads it. Weights decide only among finds (tier 2).

New rule: the revealed objective is one more candidate in the weighted pool, with its authored `objective` weight. Every candidate, find or objective, gets the same weighted choice inside the same slack envelope. The slack envelope is built around the nearest candidate.

| Case | Result |
|---|---|
| Scout, intel find near, objective farther, both inside the envelope | Scout takes the intel find first. Intel weighs 1.4, the objective 1.2. Scout reads the ground before it commits. |
| Seek, objective and a find both inside the envelope | Seek takes the objective. It weighs 1.6, more than the intel 0.9. |
| Seek, a find much closer than the objective | The objective falls outside the envelope. Seek takes the close find first. The objective is delayed, not lost. |
| Objective outside the envelope for any Directive | Same: delayed, not lost. The party takes the nearer candidates, then the objective comes inside the envelope. |
| Only the objective is revealed | The pool holds one candidate. The party goes to it, as today. |
| Objective passed (tier 4) | Unchanged. The party can still return to a passed objective. |

Guards:
1. The objective stays reachable. A rule that lets finds starve the objective forever fails a test. Finds are finite and resolve, so the objective comes inside the envelope.
2. The profile bend on the `objective` weight follows the same band rule as other categories (section 3 E1).
3. This change is the largest recorded-value move in B+C. It is a stage-wide change, and it lands as its own re-record step (section 11).
4. `TIER_PRESSURE_SOURCE` (`StagePartyMovementAdapter.gd:197`) names `state.tier_objective`. `mechanics-developer` decides whether that source token is kept or retired.

Stage tests and recorded values this moves (`mechanics-developer` confirms the exact list): `tests/StagePartyMovementTests.gd` and `tests/TraversalModelTests.gd` (both reference the tier-1 objective pick); `snapshot_fingerprint/stage_explore`; any `seam` expectation that fixes a destination on a board with a revealed objective and a find.

### 3a. Stop kinds and "new information" (D-29, D-36)
Stage today reveals content in one sweep after the walk (`StageExploreTurnService.gd:309`). A mid-walk stop needs the party to know what each step revealed. That is a seam, not a new rule: the party only stops for content its own fog-lift made known.

| Stop kind (what the player sees) | Proposed internal name | Trigger | Both Directives? |
|---|---|---|---|
| Arrived | `arrived_at` | Target cell reached. | Yes. Replaces `reached_destination` in the player-visible kind. |
| Spent | `capacity_spent` | Effective steps used. | Yes. (`commitment_spent` is valid in `MovementResult.STOP_REASONS` and unused by stage.) |
| Met something | `interrupted` | Party entered an unresolved situation. | Yes. |
| Spotted ahead | `spotted_ahead` | The walk revealed an objective or a hostile situation (decision-critical, movement model 11.7). | Yes. |
| Paused to read | `paused_to_read` | The walk revealed any other new situation, or the next cell is highly exposed. | Scout only for new finds. Seek passes through, except for the two decision-critical kinds. |
| No way | `no_route` | No reachable route. | Yes. |

Rules:
- Jeff kept both "found" kinds (D-36): one for decisive finds, one for optional finds. The names `spotted_ahead` and `paused_to_read` are chosen so the two do not read as near-twins. The two kinds must also look different as glyphs (section 8). Player-facing wording stays Jeff's.
- All internal names are PROPOSED. `mechanics-developer` may rename them. They never reach the player.
- Scout can pause often on a board with many finds. A pause cap per Advance, or merging reveals made in one step into one pause, is decided from measurement: `game-feel-developer` builds the measurement. The main chat runs it (section 11, RUN REQUEST outline). Pauses per Advance and why frequency on the shipped boards are measured before the value is authored (D-40 item 5).
- Combat stop-short and its Directive cause are phase D. Stage "paused to read" shares no code with `StopShortService`.
- A detour refused for exceeding the slack limit is not a stop. It has no stop kind. It records the terrain cause (section 8, D-48).

### 3b. The exposure seam (D-02)
Route scoring reads one **exposure map**: cell key to a non-negative exposure value, built from named sources.

| Source | State today | Rule |
|---|---|---|
| Known hostile situation (revealed, unresolved, combat type): closeness of the cell | Live | Counts. Hidden situations never count. Passed or resolved ones do not count. |
| Narrow crossing (bridge cells, `StageTerrain.bridge_cell_set`) | Live data | NOT counted in B+C (D-31). The new story "Stage hazards and exposure" decides whether bridges carry exposure, because that depends on where hazards sit. |
| Known hazard (`known_hazards`) | EMPTY. Read, never written. | Seam only. The map accepts the source and the code path runs with it empty. No hazard data is created in this story. The new story "Stage hazards and exposure" creates it. |

The exposure map becomes a path price through `MovementPathService.shortest_path` arguments `terrain_costs` and `edge_costs`. The stage call passes `{}` for both today (`StageExploreTurnService.gd:214`). The price scale is `(1 - effective tolerance)`. With an empty map, E2 changes nothing, and tests must prove it.

## 4. Party aggregation (D-04, movement model 11.1 to 11.3)

One Advance builds one party profile, one party intent, one ordered path and one party result.

Rules:
1. **One aggregation.** The party stance is computed once, at the start of the Advance. Each dial = Directive baseline + sum of Echo leans, each lean weighted by one share of the party, then clamped inside the dial's bound. Party size alone never moves a dial.
2. **Internal replans are allowed only as movement model 11.7 says.** Same intent, no decision-critical find, only a frontier chain, a local continuation or a blocked-cell detour. A replan reuses the same party stance. It does not aggregate again. The live loop today re-plans each step, builds a profile, goal, route and intent each time, and drops the result (`StageExploreTurnService.gd:196-258`; the `build_result` return value is not stored). Phase C keeps exactly one result and returns it.
3. **Replan cap.** The path replan count per Advance has a hard cap: PROPOSED DEFAULT, to be authored (a small multiple of effective steps, never unbounded). Hitting the cap ends the Advance with a visible stop. It is logged.
4. **Counterfactual naming.** After the real plan is made, the system re-plans once per candidate Echo with that Echo removed, same board, same Directive, same origin, on a copy. No state is written. An Echo is a *deciding Echo* only if removing them changes at least one of: the ordered path, the effective steps or commitment depth, the stop kind. Judgment includes bond support (D-26), so the counterfactual removes the Echo together with the bond edges that Echo supplies to the others.
5. **Candidate cap.** Only Echoes whose lean on some dial is non-zero are candidates. Total counterfactual replans per Advance = one per candidate, plus one per input class for the single named Echo (to find the reason class). Cap = party size + number of input classes: PROPOSED DEFAULT, to be authored.
6. **Who is named.** `contributor_ids` = all deciding Echoes. `decisive_contributor_id` = the deciding Echo whose removal changes the most of {path, commitment, stop}; then the largest absolute dial contribution; then the lowest Echo id by string order. The why line names at most the decisive one. The lowest-id tie-break can pin one Echo as the named Echo every time on a tied board. `mechanics-developer` checks this (section 12, feasibility).
7. **No Echo is named** when removing every candidate in turn changes nothing. The journey entry then shows the cause (D-40 item 7). The cause is `directive` when the Directive alone decided, otherwise the terrain (only one route exists), the objective or situation (the destination was fixed by the pool), or the party baseline. When the Directive alone decided, the entry shows "Directive" as the cause and names no Echo. Wording is Jeff's. Leave-one-out misses two Echoes who are only decisive together. The cause is then "party", and no Echo is named. This is accepted.
8. **"Materially changes" (testable).** Path: the ordered list of entered cells differs. Commitment: the commitment depth or effective steps differ. Stop: the stop kind or the stop cell differs. A change in score only, with the same path, steps and stop, is NOT material.
9. **Determinism.** No RNG draw is added. Allowed inputs: seed, board, Echo state, bonds, Directive, objective state, explored set. Frontier tie-break keeps the existing salted hash (`stage_movement_salt`: realm id and stage index). The Echo tie-break is Echo id string order, and Echo order in the party array never matters (a test shuffles party order and expects an identical result). Any new hash salt must use a path named under `CampaignSeed` rules in `AGENTS.md`, and needs Jeff's approval. This design needs none.
10. **Hidden content.** Relocating hidden situations outside known cells must not change goal, path, effective steps, commitment or the why. Only the walk itself may end sooner if it enters an unrevealed situation (existing reveal-on-arrival). The test compares the plan made before the first step.

## 5. Capacity (D-13, D-27)

| Item | Rule |
|---|---|
| Baseline | `step_budget` of the Directive (`build_profile`, source `directive.step_budget`). |
| Readiness inputs | Fear band of the party (calm, uneasy, shaken) and morale band. These are the only two stage sources today. Speed, burden, injury and equipment have no stage source (Section 13). |
| Direction | Readiness LOWERS effective steps only (D-27). A shaken or low-morale party walks fewer steps. A calm party walks the Directive baseline. Readiness never raises steps. |
| Bound | Small: PROPOSED DEFAULT, to be authored (order of magnitude: one step). |
| Invariants | (a) Effective steps stay between the minimum capacity (1) and the system cap (6, `MAX_EXPRESSIBLE_CAPACITY`). (b) The bound is smaller than half the gap between the two Directives' baselines, so Seek's effective steps are never below Scout's. (c) Standing never adds steps (movement model 7.1, 10.6). (d) Readiness uses bands, not a continuous fear curve. This prevents fear counting twice (E3 and E4 read fear). (e) Effective steps never reach zero. A shaken party still moves one step or stops with a named stop. |
| Seek at the cap | Seek's baseline is already the cap (6). With lower-only readiness this is consistent: the cap is never exceeded. |
| Hostile contact | Reaching a hostile situation ends the Advance (existing `interrupted`; movement model 11.7). Control returns to the player. Unspent steps are lost (movement model 11.9). No hostile engagement zone exists on stage. No per-Echo engagement movement exists. If roaming stage actors come later, hostile control is evaluated once between group tokens and modifies the party result. |
| Single-Advance rule | Effective steps are fixed at the start of the Advance. A mid-walk fear change does not change them. The next Advance rebuilds the stance from current state. |

## 6. Contact bids and the resonance bonus (D-11, D-16, D-24, D-33)

Current rules (`ConversationService.compute_bids`, `ConversationService.gd:458-499`): a suppressed Calling gives no bid; fear 60 or more gives a reactive bid; a Calling aligned with the contact role gives an alignment bid; a boosted Calling gives an alignment bid. Order: suppression, then fear, then alignment, then boost. The 60 is a literal in code.

### 6a. Scaling bid effects by Judgment and fear

| Case | New rule (plain language) |
|---|---|
| Suppression | The Directive asks a Calling to hold back. A low-Judgment Echo follows it. A high-Judgment Echo weighs it less and may still speak when the role fits their Calling. Fear weakens it too: a frightened Echo speaks from fear (reactive) even when the Calling is suppressed. Today suppression wins over fear. |
| Boost | The Directive nudges a Calling to speak. A low-Judgment Echo takes the nudge. A high-Judgment Echo speaks only if their own read fits the contact. A frightened Echo does not take the nudge. They speak from fear or stay quiet. |
| Both | Each effect has a **strength** per Echo that falls as Judgment rises and as fear rises. Below a strength threshold the effect does not apply. The threshold and the curve are PROPOSED DEFAULT, to be authored. |
| Reactive threshold | Moves from the literal 60 to `data/balance.json`, same value (D-33, ANSWERS #83). Behaviour does not change from the move. The snapshot builder holds a second copy of the same rule (Section 13, row 13). Both read the one config key. |
| Seek Signs | Authors no suppression and no boost today. Bid scaling still runs and changes nothing for Seek. Seek's contact payoff is the resonance bonus. |

Result at each Standing: Standing 1: the Directive's lists decide, so Calling gives contrast. Standing 6: the same lists loosen. Standing 9: lists barely bind. This is "Standing widens reinterpretation, never obedience".

### 6b. `conversation_resonance_bonus` (D-16, D-24)
- Effect: +0.1 (PROPOSED DEFAULT) on the turn resonance score of EVERY response, for EVERY Echo, in EVERY conversation, while Seek Signs is active.
- Where: `compute_turn_score_from_virtue` (`ConversationService.gd:162`). Apply BEFORE the clamp, so the documented range 0 to 1.2 holds (`ConversationService.gd:184`).
- What it does: the chosen response's score drives the NPC reaction (`ContactController.gd:256`, `apply_npc_reaction`) and social effects. A higher score gives a better NPC fear and morale change. It lifts every Echo equally. It does not change which Echo is best. It changes outcomes, not the picker order.
- Risk: a flat bonus is not profile-sensitive. It is Seek's reward for choosing conversation. It must stay small, or Scout players lose the contact game (section 9).
- Name: the key is renamed from `witness_resonance_bonus` in the B+C backend step (D-24).

## 7. Contrast cases the tests must show (D-08)

Board rule for all cases: one board, one seed, one Directive, same objective state. Only the named Echo differs. The test builds each side from real Echo dicts, including real bonds (rule 5 of section 2), through the production reader, not from hand-set dials (LESSONS on probe fidelity).

### 7a. Scout Carefully: four Echo contrasts

| # | Contrast | Observable that differs |
|---|---|---|
| S1 | Sight-family vs Edge-family Echo, both Standing 1, solo party | Route: Sight takes the lower-exposure route, Edge the more direct one, on a board with two routes inside the slack envelope. |
| S2 | Anchor vs Edge, Standing 1 | Stop: Anchor pauses before an exposed cell. Edge walks to it. |
| S3 | Same Echo calm vs high fear | Commitment and stop: the frightened Echo gives a shorter depth or an earlier stop. Named Echo: the frightened one, reason class "fear". |
| S4 | Standing 1 vs Standing 6, same Calling, same fear, same bonds | Bid or destination: the Standing-6 Echo leans harder on its own Calling. Bid: a suppressed Calling at Standing 6 bids when the role fits. At Standing 1 it stays silent. |

### 7b. Seek Signs: four Echo contrasts

| # | Contrast | Observable that differs |
|---|---|---|
| K1 | Edge vs Anchor, Standing 1 | Commitment: Edge spends more of the effective steps before reassessing. Anchor stops sooner. |
| K2 | Sight vs Edge, Standing 1, Seek | Destination: a reward find and an intel find, both inside the slack envelope, both weigh 0.9 (a tie). The reward find is nearer. Sight picks the intel find, because its lean breaks the tie. Edge picks the reward find, because the tie falls to the nearest candidate. A bend breaks ties only. It never flips the authored ranking (D-44). |
| K3 | Same Echo steady morale vs low morale | Commitment: low morale shortens the depth. |
| K4 | Standing 1 vs Standing 6, same Calling | Route or destination: the Standing-6 Echo shows more of its own lean. Standing 6 never exceeds the Directive's bound. |

### 7c. Whole-party contrasts (one board, one seed)

| # | Contrast | Observable |
|---|---|---|
| P1 | Party A (Anchor and Sight, calm) vs party B (Edge-heavy, calm), Scout | Route or stop differs. Named Echo is one whose removal changes it. |
| P2 | Same two parties, Seek | Commitment or destination differs. Directive ordering still holds: Seek's steps and tolerance are at least Scout's for each party. |

### 7d. Cases that must show NO name and NO change, and the pool cases

| # | Case | Expected |
|---|---|---|
| N1 | One route exists (terrain decides) | No Echo named. Cause "terrain". |
| N2 | Only the objective is revealed, and every Echo gives the same path | No Echo named. Cause "objective". |
| N3 | Directive alone decides (identical Echoes, route differs between Scout and Seek) | No Echo named. Cause `directive`. The journey entry shows "Directive" as the cause (D-40 item 7). |
| N4 | Party order shuffled | Identical result and identical name. |
| N5 | Hidden content moved to other unrevealed cells | Identical goal, path, steps, commitment and why before the first step (section 4, rule 10). |
| N6 | Empty exposure map | E2 gives the plain shortest-path route (Section 3b). |
| N7 | Wrong reason | A why that names an Echo who did not decide fails a test (the fingerprint does not hash the reason). |
| O1 | Scout, intel find near, objective farther (section 3.1) | Scout takes the find first. |
| O2 | Seek, same board | Seek takes the objective first. |
| O3 | Seek, find much closer than the objective | Seek takes the find, then the objective. The objective is reached. |

## 8. What the player sees (D-12, D-32)

Surface: the existing `flow.stage_explore` snapshot, `data` dict, built in `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd` (next to `travel_bark`, `travel_snippet`, `traveled_path`). UI: `ui/screens/venture/StageExploreScreen.gd`. No new screen. No pre-commit preview. D-12 narrows movement model 11.12 (Section 13).

Two layers:

| Layer | When | Content |
|---|---|---|
| Picture | After EVERY Advance (D-32, D-38, D-41) | Picture first. The traveled path on the board. The board shows nothing extra for the stop. A small kind glyph sits on the named Echo's card in the Echo bar: six shapes, one per kind in section 3a (D-36). The glyph needs no text. |
| Why line | On demand only (D-32) | A short line the player asks for. It is the content of the journey entry: the entry holds the why of the last Advance. |

### 8.1 The stop mark: marker style 3 (D-41, D-42)
Jeff approved marker style 3 on 2026-10-12. It replaces the head, pole and ring of D-38 item 1 and D-40 items 10 and 14. The mockup is `mockups/v3/index.html`.

| Item | Rule |
|---|---|
| Board | Shows nothing extra for the stop. No head, no pole, no ring, no footprint change. |
| Glyph, Echo named | A small kind glyph sits on the named Echo's card in the Echo bar (`EchoBar`, card `EchoCardItem`). |
| Glyph, no Echo named | A party chip beside the Echo cards holds the glyph (D-42). The chip exists only when no Echo is named (Directive cause, party cause, terrain, edge stop, shaken party with no deciding Echo). It never shows next to a glyph on a card. |
| Six kinds | Six shapes, one per kind in section 3a (D-36). Arrived: round. Spent: rounded block with three bars. Met something: hexagon. Spotted ahead: arrow-head. Paused to read: capsule with two bars. No way: octagon with a slash. Shape carries the kind. Colour never does. |
| Source | Drawn from the result of the last Advance (`stop`). It is not a timer. |
| Lifetime | Stays until the next Advance starts. Then it fades and the new walk starts. The player can open it at any time before then. |
| After reload | The glyph returns after save and load (section 8a). |
| Portrait ring | Not drawn in this style. The portrait pulse of D-38 item 1 is not part of this look; `game-feel-developer` decides in the feel pass whether any pulse stays. |
| Text | None on the glyph or chip. |

Trigger (D-41): a tap on the glyph, on the named Echo's card, or on the party chip opens the why card. The party token is an alias: a tap on the token opens the same card in every case (D-40 item 10, kept by the mockup). An Echo card opens nothing else today (Jeff confirmed), so the card tap is free for the why. The card closes on a second tap, an outside tap or Escape. There is no button. A player who never opens the why still sees the route and the glyph, and the game works. The why must not carry rules the player needs. `ui-ux-designer` tests whether a new player finds the tap.

Hit areas and placement (D-39, D-42):
1. Each tap area is at least 48 x 48 units, with 8 units to the next area.
2. The glyph tap area is the glyph, or the whole card; the card tap is the larger area. `ui-ux-designer` decides which, and states it.
3. The party chip sits beside the Echo cards, inside the safe area. It must not cover an Echo card, and it must not shrink a card below its minimum width. `ui-ux-designer` places it.
4. The why card opens clear of the Echo bar and the Advance button, inside the board area.
5. Checked at 1280x720 and 1920x1080.

Presentation rules:
1. **Shaken beat (D-38 item 2, D-41).** When a shaken party's steps drop, the party token and the step bar shake once. PROPOSAL from the mockup, for `game-feel-developer` to measure and Jeff to approve (D-37): about 0.22 s, 2 to 3 small oscillations, then still, starting with the cross-outs (about 0.60 s after the Advance starts in the mockup). It plays once, never loops. Under reduced motion it is skipped; the crosses still appear. No number here is final.
2. **Repeat filter (D-38 item 3).** The journey entry does not show the same Echo with the same reason class twice in a row. The filter lives in the journey entry only. The simulation and the counterfactual stay unfiltered.
3. **Copy rule (D-40 item 4).** A fear or morale reason never reads as a fault of the Echo. Wording is Jeff's.
4. **Seek payoff (D-40 item 6).** At least one Seek Signs payoff is visible on the board. The wider balance stays under ANSWERS #46.
5. **Step bar and Advance (D-40 item 8, D-41).** The old mockup look stays: the old Advance button, the big step diamonds, a red cross on each lost step. The bar shows the BASELINE steps (`step_budget`) as diamonds. Steps lost to a shaken party (`step_budget` minus `effective_steps`) are crossed out. The two numbers are shown as shapes: the diamonds are the baseline, the crosses are the loss. A cross is a shape cue, so colour is never the only signal. The step row shows diamonds only. No count text is shown (D-43). The live count label (`StepFractionLabel`, "n/n") is deleted in the build. The bar adds no number and no new text. The live layout is otherwise unchanged. The blank Advance label is a live defect and a separate task, not part of this story.
6. **Tint and glyph (D-40 item 11).** `sr-game-artist` names the tint tokens and the glyph rule. `mid-game-designer` authors the data keys. `ui-ux-designer` deletes `_label_for_directive` (`StageExploreScreen.gd:1243`) and `_TINT_BY_ID`.
7. Snapshot and UI field details are left to `mechanics-developer` and `ui-ux-designer` (D-40 item 9).

### Touch-first (D-39)
Target devices: mobile smartphone, tablet and laptop. Landscape mostly. At least 1080 wide. The smallest layout is the 1280x720 logical base. Check also 1920x1080.

| Rule | Detail |
|---|---|
| No hover | No meaning or control depends on hover. Every control works by tap. |
| Tap targets | 48-unit minimum. 8-unit spacing between neighbours. |
| Thumb reach | Frequent controls sit where a thumb reaches in landscape. |
| Phone edges | Keep controls inside the safe edges and clear of the notch. |
| Overlap | The glyph, the Echo card, the party chip and the party token tap areas keep to the safe edges. The party chip never covers an Echo card. The party token must not sit under the `EchoBar`. |

The why line carries (content slots only; the wording is Jeff's):

| Slot | Content | Allowed values |
|---|---|---|
| Purpose | What the party was doing. | One of the Read, Advance, Reposition families (movement model 18.2). |
| Route character | How they went. | cautious/low-exposure, direct, skirted a known danger, only way. |
| Stop | Why they ended there. | The stop kinds of section 3a. |
| Cause | Who decided. | Directive (shown as "Directive" when it alone decided), terrain, objective, a known situation, the party, or one named Echo. Terrain also covers a detour refused for exceeding the slack limit. The ground forced the route, not the Directive. A refused detour never shows the Directive cause (D-48). Player wording: [Jeff's wording]. |
| Echo name | Display name of the decisive Echo. | Only when section 4 names one. |
| Echo reason class | What about them. | Calling, temperament, fear, morale. Found by the counterfactual. |

It must NEVER carry: IDs, movement points, step counts as a mechanic, weights, tolerance values, Judgment, fear or morale numbers, the words "dial", "lean", "stance", or any fact about unrevealed content. It must never claim a cause the counterfactual did not confirm. Barks stay flavour (movement model 18.3).

Snapshot fields core must provide (backend first; PROPOSED names, `mechanics-developer` may rename):

| Field | Shape | Rule |
|---|---|---|
| `stop` | Dict: `kind`, `col`, `row` | Set after every Advance. Drives the glyph on the Echo card or the party chip. `kind` is one of the section 3a kinds. Saved (section 8a). |
| `travel_why` | Dict: `cause`, `purpose_family`, `route_character`, `stop_kind`, `named_echo_name` (empty when none), `echo_reason_class` | Sanitised. Set per Advance. It is the content of the journey entry. It stays until the next Advance replaces it. It is saved (section 8a). |
| `step_budget` | int | The Directive baseline. The step bar draws it. |
| `effective_steps` | int | Steps after readiness. The bar crosses out `step_budget` minus `effective_steps` steps. |
| Contact: `contact_echo_bids` | unchanged shape | Values now carry the scaled bid. |
| `directive` | `id`, `label`, plus tint and glyph keys read from the Directive data entry | See section 10 and item 6 above. |

### 8a. Save change: the journey entry and the stop are saved (D-40 item 16, D-41)
The journey entry survives save and load. The `stop` result also survives, so the glyph returns after a reload (D-41). This is a save-schema change.

| Item | Rule |
|---|---|
| Field | One additive field on the stage state. Name PROPOSED (`travel_why`); `mechanics-developer` decides the name and the place. |
| Content | Sanitised content only: no IDs, no numbers, no weights. The same sanitiser as the snapshot field. |
| `stop` | `stop` (`kind`, `col`, `row`) is saved with the journey entry, so the glyph or the party chip returns after save and load. `mechanics-developer` decides whether it is a second additive field or part of the same one. Also needed on reload: which Echo the glyph sits on, taken from the saved named Echo of the entry. |
| Lifetime (PROPOSED) | Kept across reload within the stage. Cleared on a new stage entry. Replaced by the next Advance. The glyph follows the same lifetime. |
| Old saves | Repair rule: a missing field means empty. An old save loads with no entry, no glyph and no chip, and no error. |
| Schema | No field is removed or renamed. |
| Review | An `opus` save-schema pass before the build merges. The pass covers the journey entry and `stop` together. |
| Tests | Round trip (save, load, same entry, same `stop`, glyph returns). Old-save load (no field, empty entry, no glyph, no error). Sanitiser (no ID, no number). |
| Leg-start length (C1, D-48) | One more saved number. It is the plain length from the leg start, and it fixes the detour limit for that leg. It is built in the same save pass as the journey entry. `mechanics-developer` (`opus`) sets its lifetime, its reset rules and its old-save repair rule. |

## 9. Failure modes

| Mode | What happens | Design answer |
|---|---|---|
| Directive ignored (player never opens the picker) | Default is Scout Carefully. | Profile still gives each party its own manner. No dead choice. |
| Why never opened | The player never asks for the why. | The route and the stop glyph carry the meaning. Nothing the player needs for a decision lives only in the why. |
| Exploit: always Scout | Safe, retains intel, more escape. Seek has little friction (ANSWERS #46: 4 divergences in 535 turns). | Seek must pay in things Scout cannot get: the resonance bonus (6b), deeper reach, objective-side priority (3.1). Bounds keep the ordering. Rebalance of Seek payoffs is flagged in follow-ups, not solved here. |
| Scout delays the objective | With the pool rule (3.1), Scout takes nearby finds first. | Delay, not loss. Test O1. Finds are finite. |
| Party tuned to one Directive | Leans push against the Directive. | Bounds are under half the baseline gap. The Directive still wins on every dial. The party can soften the Directive, never invert it. |
| Standing 1 | Judgment low: dispositional leans are small, floor above zero. Fear and morale leans are full. | Contrast comes from Calling, identity and state (D-08). The Directive is followed closely. |
| Standing 6 | Mid width. | More of the Echo's own manner shows. Bid lists loosen. Still bounded. |
| Standing 9 | Widest reinterpretation. | Never more steps, never more obedience, never shorter paths for free. Noise stops are rare; relevant stops remain. |
| Fear spike (freeze risk) | A shaken party could stop every Advance and soft-lock. | Effective steps never reach zero. "Return home" is always available. A fear stop always names a stop kind. Test: all-shaken party, both Directives, still makes progress or states a stop. |
| Scout pause spam | Scout stops for any new find (D-29). A board with many finds could stop Scout again and again. | Measured before a cap or a merge is authored (section 3a). |
| Double counting with combat Judgment | Combat already scales Directive pull by `directive_interpretation_mul` and identity by `identity_weight_scale`, budgeted by `interpretation_swing_max` (V2-PROG-012). | Stage reads `interpretation_width` only. It adds no multiplier to `BehaviorArbiter`. Stage's own per-dial bound is its budget, with its own config-integrity test like `compute_interpretation_swing`. Phase D must not feed the stage bound into combat. |
| Counterfactual cost | Many dry runs per Advance. | Candidate cap (section 4). Feasibility check for `mechanics-developer`. |
| Flat resonance bonus | Seek wins every talk. | Keep it small; flagged (6b). |
| Wrong why | A true path with a false reason. | Section 7d N7. |
| Glyph missed | A player looks only at the board and sees nothing for the stop. | Accepted (Jeff chose a subtle mark). The path and the Advance result still show on the board. `ui-ux-designer` tests whether a new player finds the glyph. |
| Small or touch screen | The party chip crowds the Echo cards, or controls sit under the `EchoBar` or the safe edges. | Touch-first rules (section 8). Checked at 1280x720 and 1920x1080. |
| Old save | A save from before B+C has no journey entry and no `stop`. | Missing field means empty: no glyph, no chip (section 8a). |

## 10. Seams and boundaries

B+C touches:

| Area | Service or file | Change |
|---|---|---|
| Stage turn | `core/realms/StageExploreTurnService.gd` (`advance_turn`) | One stance, intent, path, result per Advance. Exposure map into `shortest_path`. Stop kinds. Keep the result. |
| Adapter | `core/movement/StagePartyMovementAdapter.gd` (`build_profile`, `build_goal`, `build_intent`, `build_result`, `select_objective_target`, `select_frontier`) | Party profile input; category-weight bend; objective in the pool; frontier ranking. Header comment "DORMANT" is stale (Section 13). |
| Target pick | `core/realms/ActiveStageService.gd` (`find_explore_target`, tier 1 at `:429-433`, tier 4 at `:500-502`) | Objective joins the tier 2 pool. Receives bent weights. |
| Directive data | `core/directives/DirectiveService.gd`, `data.directives.<id>` | Revive `exposure_tolerance`. Fix the guard nits. Add display keys (label, tint, glyph) only after Jeff approves. |
| Identity | `MaturityExpressionService`, `MovementStyleService`, `EchoActor` | Read only. Stage passes bonds into `derive_expression` (D-26). |
| Return | `core/runtime/controllers/VentureController.gd` (`handle_return_home`) | Threshold reads the bent `escape_bonus`. Draw path unchanged. |
| Contact | `ConversationService.compute_bids`, `compute_turn_score_from_virtue`; `ContactController`, `ContactConversationService` | Bid scaling, reactive threshold from config, the resonance bonus. |
| Snapshot | `StageExploreSnapshotBuilder` | `stop` (glyph and chip source), `travel_why`, `step_budget`, `effective_steps`, Directive display keys. Its own bid-type rule reads the config key. |
| Save | Stage state save and its repair path (`mechanics-developer` names the file) | Additive field(s) for the journey entry and `stop` (section 8a). |
| UI | `StageExploreScreen`; shell `RealmShell` (`EchoBarFrame`, `EchoBar`); card `ui/components/EchoCardItem.tscn` | Kind glyph on the named Echo card; party chip beside the cards when no Echo is named; tap trigger on glyph, card, chip and token; why card; step bar with crossed-out steps; shaken shake. Directive label read from the snapshot. The glyph, chip and any extra Labels are authored in the `.tscn`, not built in code. No stop marker on the board layer. `ui-ux-designer` decides how the shell-owned Echo bar receives the glyph (the shell must not read flow state directly). |

B+C must NOT touch:

| Item | Owner |
|---|---|
| Combat arbitration, `directive_exposure_acceptance`, stop-short Directive cause and its text bank | Phase D (D-10). |
| Ping and guidance code, a shared influence function, `reposition` and `regroup` goal sources | V2-COMBAT-004 (D-07, D-09). |
| Stage hazard data, concealment, hazard interrupt, whether bridges count as exposure | New story "Stage hazards and exposure" (D-02, D-31). |
| Bond rescue or abandon trigger and behaviour | New Foundation story "Stage bond interrupt" (D-25). |
| Press the Path, Hold the Circle, Directive unlock rules | V2-DIRECTIVE-003 (D-06). |
| Vows, equipment, injury | V2-VOW-002, V2-ITEM-003. |
| Contact window card fixes | Separate story (D-22). |
| Seek Signs payoff rebalance | Follow-up (ANSWERS #46). |
| Letting a strong optional find divert from a revealed objective beyond the pool rule | V2-DIRECTIVE-003, if play shows a need. |
| No Directive id literal in `core/` (ANSWERS #81) | Stays enforced by the `directive_char` scan. |

### 10.1 Hard-coded tunables in the code B+C touches (ANSWERS #83, D-33)

Scan: literal numbers in the files of the table above. Layout constants in the UI (sizes, margins, colours) are scene geometry and are not tunables. Lines may move when code changes. `mechanics-developer` re-checks with a grep before the edit.

| File:line | Value | Verdict |
|---|---|---|
| `core/realms/ConversationService.gd:483` | Reactive bid fear threshold 60 | Move to config, same value (D-33). |
| `core/state/flow/states/venture/StageExploreSnapshotBuilder.gd:191` | Second copy of the same reactive rule (`fear2 >= 60`) | Move to config. Read the same key as `ConversationService`, or read the bid type from `compute_bids` (Section 13, row 13). |
| `core/realms/ConversationService.gd:287` | NPC fear 60 gates the grounding bonus and aggressive penalty in the turn score | Move to config, own key, same value. B+C edits this function (resonance bonus). |
| `core/realms/ContactConversationService.gd:74,76` | NPC fear above 60 shortens, NPC morale below 30 lengthens the turn count | Move to config, same values. The file is on the B+C contact path. |
| `ui/screens/venture/StageExploreScreen.gd:71` | `_TRAVEL_DURATION` 0.5 s walk time | Move to config (D-37). `game-feel-developer` measures and proposes the value. Jeff approves after seeing it. |
| `ui/screens/venture/StageExploreScreen.gd:1211-1213` | Snippet fade in 0.4 s, hold 2.1 s, fade out 0.5 s (3.0 s in total) | Move to config. The on-demand why replaces the timed hold for the why. `game-feel-developer` sets the values for the remaining snippet. |
| `ui/screens/venture/StageExploreScreen.gd:57,430-431,1239-1240,1286` | Other presentation timings: zoom 0.35 s, fades 0.25 s, flash 0.1 s, reaction fade 0.35 s | Move to config in the same timing pass as the two rows above (D-40 item 14). The shaken-beat timings (section 8) are born in config too. `game-feel-developer` sets the values; Jeff approves after seeing them. |
| `core/movement/StagePartyMovementAdapter.gd:262-263` | `SLACK_FLOOR` 2, `SLACK_FRACTION` 0.25 | Stay. Reason: contract floor shared with `MovementOption.validate` (`normal_slack_limit`). `data.combat.movement.slack` may only narrow it (`:255-261`, `:893`). |
| `core/movement/StagePartyMovementAdapter.gd:214-216` | `MIN_EXPRESSIBLE_CAPACITY` 1, `AUTHORED_OVERRIDE_THRESHOLD` 2, `MAX_EXPRESSIBLE_CAPACITY` 6 | Stay. Reason: contract ceiling and floor of `MovementProfile.validate` and `MovementContractValidation.require_capacity` (`:204-208`). |
| `core/movement/StagePartyMovementAdapter.gd:246` | `DEFAULT_TARGET_WEIGHT` 1.0 | Stays. Reason: a neutral weight means "no preference" for a category the Directive does not list. It is an identity value, not a tuning. Revisit if Jeff wants a missing key to be an error. |
| `core/movement/StagePartyMovementAdapter.gd:271-272` | FNV-1a offset basis and prime | Stay. Reason: hash algorithm parameters, fixed by the algorithm. |
| `core/directives/DirectiveService.gd:32` | `DEFAULT_STEP_BUDGET` 3 | Stays. Reason: one shared fallback for a Directive entry with no budget; two callers read it so they cannot diverge. |
| `core/runtime/controllers/ContactController.gd:615` | Claimant good-outcome Ase reward 20 | Not B+C's subject. The sweep covers only lines B+C edits (D-40 item 15). This line goes on the follow-up list. |
| `ContactController.gd:170,422`; `ContactConversationService.gd:116`; `StageExploreSnapshotBuilder.gd:258,346` | Party-size comparisons (3, 5) | Not classified. `mechanics-developer` states whether each is a structural limit (stays, with the reason) or a tunable (moves). |
| New values B+C adds | Pause cap, replan cap, candidate cap, bend bounds, readiness bound, resonance bonus, bid strength curve | Born in `data/balance.json`. None is a literal in code. |

## 11. Test plan skeleton

| Suite | Extend with |
|---|---|
| `traversal` (`TraversalModelTests.gd`) | Section 7 contrasts S1 to S4, K1 to K4, P1, P2; N1 to N7; O1 to O3; one result per Advance; effective-steps invariants; shaken-party progress. Fixtures use real bonds (section 2, rule 5). |
| `movement` (`StagePartyMovementTests.gd`) | Profile inputs; bound and ordering invariants per dial; objective in the pool; exposure-map pricing with an empty map; replan cap; determinism with shuffled party order. |
| `seam` (`Stage004SeamTests.gd`) | Stop kinds; return safety draw path unchanged. |
| `directive` / `directive_char` | Exposure tolerance has a reader; guard nits; synthetic third Directive passes the new dials without a logic change (D-14); no hard-coded tunable left in the section 10.1 "move" rows. |
| `explore`, `explore_p5` | The `stop`, `travel_why`, `step_budget` and `effective_steps` fields; N7 wrong-reason test; sanitiser test (no IDs, no numbers). A refused detour records the terrain cause and the why never shows a Directive cause for it (D-48). |
| Save (suite name set by `mechanics-developer`) | Journey entry and `stop` round trip; old-save load with a missing field; no field removed or renamed. |
| Config text | A test checks that the picker text in `data/balance.json` equals the text in D-34. |
| Screen check | The stage screen at 1280x720 and 1920x1080: tap targets, spacing, no overlap with the `EchoBar` or safe edges. Hit-area check: glyph, Echo card, party chip and token are each at least 48 x 48 units, 8 units apart. Safe-area check: all four inside the safe edges. The party chip covers no Echo card. |
| Stop glyph | A glyph is present for each of the six kinds, and the six shapes differ. The chip shows only when no Echo is named, and never together with a card glyph. The glyph returns after save and load (same kind, same Echo or chip). A tap on the glyph, on the Echo card, on the chip and on the party token each open the why card. An Echo card tap opens nothing else. The mark stays until the next Advance starts, then clears. The board layer holds no stop marker. |
| Shaken shake | The shake plays once on the token and the step bar in a shaken run, then stops (token and bar at rest). It does not play in a calm run. Under reduced motion it does not play, and the crosses still appear. |
| `conversation_repair` | Bid scaling; reactive threshold read from config (both copies agree); resonance bonus range 0 to 1.2. |
| `snapshot_fingerprint/stage_explore` | Re-record. |
| New suite (only if Jeff agrees) | `party_stance` for the pure aggregation and counterfactual functions. Otherwise put them under `movement`. |

Recorded values that will move: `snapshot_fingerprint/stage_explore`; fingerprints and expectations in `traversal`, `seam`, `movement` stage-party tests (the pool change moves the most, section 3.1); conversation tests that fix bid or score values. No combat fingerprint should move in B+C. A moved combat hash is a defect.

Re-record rule (D-01, LESSONS):
1. Serial. One cause per step. Order: (1) exposure map and one-result refactor with Directive logic unchanged, (2) objective joins the pool, (3) profile bends, (4) stop kinds, (5) bid scaling and the threshold move to config, (6) resonance bonus.
2. Each step names the one cause. `opus` attributes each move.
3. Each re-record is a RUN REQUEST. It states: the exact command with `timeout` and `alarm` (3600 s alarm for the full serial run, D-20); expected duration; every file the run edits and the `trap` that restores it; how to verify the restore (`cmp` against the saved copy); which output to read back (the `Tests:` line and the raw failing names).
4. **Measurement run (D-40 item 5).** `game-feel-developer` builds a probe. The main chat runs it. RUN REQUEST outline: (a) the probe command with `timeout` and `alarm`; (b) expected duration; (c) files the run edits, if any, and the `trap` that restores them; (d) restore check by `cmp`; (e) output to read back: pauses per Advance and why frequency, per shipped board, for both Directives. The result sets the pause cap before values are authored.
5. The phase gate is ONE full serial run (D-20). Agents run only filtered suites and the compile check. A filtered run must print a `Tests:` line, or the filter matched nothing.

## 12. Decisions and open items

### 12a. Resolved

| Q | Answer | Decision |
|---|---|---|
| Q1 Bond interrupt | Seam only in B+C. New Foundation story "Stage bond interrupt" owns it. | D-25 |
| Q2 Stage Judgment and bonds | Same as combat, bonds included. Amends D-03. | D-26 |
| Q3 Readiness raises steps? | Lower only. | D-27 |
| Q4 Objective weight | Joins the weighted pool. Tier 4 stays. | D-28 |
| Q5 Which finds stop the walk | Scout: any new find. Seek: objective or hostile only. Pause cap or merge decided by measurement. | D-29 |
| Q6 Rename the resonance key | `conversation_resonance_bonus`. | D-24 |
| Q7 Bonus before or after clamp | Before. | D-30 |
| Q8 Bridges as exposure | Not counted. New story "Stage hazards and exposure" decides. | D-31 |
| Q9 When the why shows | On demand only. Picture after every Advance. | D-32 |
| Q10 Reactive threshold | Move 60 to config, same value. | D-33 |
| Q11 Picker wording | Jeff wrote both lines (D-34). Script copy into `data/balance.json` in the data step. A test checks config text equals picker text. | D-34 |
| Q12 Identity source | Reuse `MovementStyleService`. | D-35 |
| N1 Two find kinds | Keep both. Wording differs. | D-36 |
| N3 Walk time | Move to config. `game-feel-developer` proposes. Jeff approves after seeing it. | D-37 |
| 1 Picture first | Option 1 chosen in D-38, then replaced by marker style 3 (D-41): path on the board, six kind glyphs on the Echo card. | D-38, D-41 |
| 2 Shaken beat | One short beat. Now: token and step bar shake once, about 0.22 s, PROPOSAL for measurement; skipped under reduced motion. | D-38, D-41 |
| 3 Repeat filter | In the journey entry only. | D-38 |
| 4 Copy rule | Fear and morale reasons never read as fault. | D-40 |
| 5 Measure pauses | Before values are authored. Long run through the main chat. | D-40 |
| 6 Seek payoff | At least one is visible on the board. | D-40 |
| 7 Directive-only cause | The entry shows "Directive". Section 4 rule 7, section 8, N3. | D-40 |
| 8 Step bar | Baseline steps; lost steps crossed out. Snapshot has `step_budget` and `effective_steps`. | D-40 |
| 9 Field details | `mechanics-developer` and `ui-ux-designer`. | D-40 |
| 10 Why trigger | Tap the glyph, the Echo card or the party chip. The party token is an alias. No button. Replaces "tap the stop marker". | D-40, D-41, D-42 |
| 11 Tint and glyph | `sr-game-artist` names tokens and glyph rule. `mid-game-designer` authors keys. `ui-ux-designer` deletes `_label_for_directive` and `_TINT_BY_ID`. | D-40 |
| 14 Other timing literals | Move to config in the same pass. The portrait-pulse part is replaced by D-41. | D-40, D-41 |
| 15 Sweep width | Only lines B+C edits. Rest on a follow-up list. | D-40 |
| 16 Journey entry saved | Yes. Additive field, repair rule, `opus` save-schema pass (section 8a). `stop` is saved too (D-41). | D-40, D-41 |
| Screen rule | Touch-first. 1280x720 and 1920x1080. 960x540 dropped. | D-39 |
| Marker form | Marker style 3. Board shows nothing extra. Kind glyph on the named Echo's card. Six shapes. No head, pole or ring. Re-openable at any time until the next Advance. | D-41 |
| Look of Advance and step bar | The old mockup's Advance button, big step diamonds with red crosses, and Echo band. Improvements 5 and 10 of the v3 list are not used. | D-41 |
| Echo card tap | Opens nothing today (Jeff confirmed). Free for the why. | D-41 |
| Real stage maps | The mockup board uses the real maps (`mockups/review/real-stage-maps.json`). | D-41 |
| Advance label | The blank live label is a real defect. A separate task. | D-41 |
| No Echo named | A party chip beside the Echo cards holds the glyph. It exists only when no Echo is named. Tap opens the why. `ui-ux-designer` places it. | D-42 |
| Step count label | Removed. The step row shows diamonds only; lost steps are crossed out. The build deletes the live count label (`StepFractionLabel`). | D-43 |
| K2 bend and authored ranking | The ranking holds. A party bend only decides ties. K2 uses a tie case (reward and intel at 0.9 each in Seek). Per-Directive party numbers live in `data.stages.party_stance.directive_profile.<id>`. | D-44 |
| Q1 Detour limit rule | Keep the per-step rule (option B, as committed in S1b). Option A (per Advance) is not built. Build C1 later: a limit fixed per leg from the plain length at the leg start. C1 needs one saved number and joins the journey-entry save pass (section 8a). | D-48 |
| Q2 Refused-detour cause | Yes. A refused detour records the terrain cause. The why never shows a Directive cause for it. Wording is Jeff's. Work lands in S3 (cause value) and S5 (saved field). | D-48 |

### 12b. Still open

Answered since the last revision and removed from this list: the marker form, the shaken beat's form, the portrait ring, the terracotta rule and the no-Echo-named home (D-41, D-42).

1. Walk time and snippet timing values (D-37). `game-feel-developer` proposes. Jeff approves after seeing them.
2. The shaken beat's timing and size (section 8, PROPOSAL). `game-feel-developer` measures. Jeff approves after seeing it.
3. Whether any portrait pulse stays in marker style 3 (`game-feel-developer`, with `sr-game-artist`). The "last-journey entry sits" detail is closed: the entry is in the why card.
4. The tint token names and the glyph contrast on the Echo card (`sr-game-artist`).
5. Measurement results that set the pause cap (section 11, RUN REQUEST outline).
6. The player wording of every line (Jeff).
7. The `AGENTS.md` 960x540 contract (section 13, row 16). Jeff decides.
8. The party chip placement, the glyph tap area (glyph or whole card) and how the shell-owned Echo bar gets the glyph (`ui-ux-designer`).
9. The on-screen size of the party token tap area (36 across before scale; `ui-ux-designer` confirms it reaches 48 units).
10. The feasibility checks below (`mechanics-developer`).

Feasibility checks for `mechanics-developer` (not for Jeff):
1. Cost of counterfactual dry runs on a copy of the explore state. `find_explore_target` is a known performance hazard. Fallback: a first-plan-only comparison.
2. Whether per-step reveal can run inside the walk without moving the `_reveal_explored_situations_static` order.
3. Whether the stop kinds fit `MovementResult.STOP_REASONS` or need new tokens.
4. Maximum party size, to size the candidate cap.
5. The lowest-id tie-break (section 4, rule 6) can pin one Echo as the named Echo every time on a tied board. Propose a fix that adds no RNG, or confirm the pin cannot happen.
6. How the bond edges reach stage Judgment (D-26): the same input path as combat, with no second derivation.
7. Whether `TIER_PRESSURE_SOURCE` keeps `state.tier_objective` once the objective is in the pool.
8. Classification of the party-size literals (section 10.1).

## 13. Where the repo contradicts the plan, the brief or the canon

| # | Claim | Source A | Source B (verified) |
|---|---|---|---|
| 1 | Turn service path | Brief: `core/state/flow/states/venture/StageExploreTurnService.gd` | File is `core/realms/StageExploreTurnService.gd`. |
| 2 | Plan line cites | Plan: stage loop `StageExploreTurnService.gd:212-258`; `ActiveStageService.gd:429-504` | Loop is `:196-258`. `find_explore_target` is `ActiveStageService.gd:401-516`. |
| 3 | Adapter is dormant | `StagePartyMovementAdapter.gd:2-4` ("DORMANT", "Nothing in production calls this file"); `data/balance.json:1733` ("STILL DORMANT") | `StageExploreTurnService.gd:197-258` calls it every step. Both comments are stale. |
| 4 | One path per Advance | Movement model 11.1, plan, D-04 | Live code re-plans each step and drops `build_result` (`:258`). Movement model 11.7 allows internal replans in a frontier chain. This design reads "one path" as "one stance, one intent, one returned result, capped internal replans". |
| 5 | Pre-commit preview | Movement model 11.12 (non-mutating broad preview) | D-12: no pre-commit preview. D-12 narrows the model. A dated note on 11.12 is a docs-pass item. |
| 6 | Directive influences objectives | Authored `target_preference.objective` 1.2 and 1.6 | `select_objective_target` is called with `{}` for tiers 1 and 4 (`ActiveStageService.gd:429-431`, `:500-502`). No category maps to `objective`. The key has no effect. RESOLVED by D-28 for tier 1: the objective joins the pool and the key gets a reader. Tier 4 stays as it is. |
| 7 | Bonds "interrupt only" vs Judgment | D-03, ANSWERS #82 | `derive_expression` includes `bond_support_weight` in Judgment. RESOLVED by D-26: stage includes bond support. ANSWERS #82 still says "Bonds act as an interrupt only". It now needs a dated amendment (docs-pass item). |
| 8 | Injury as capacity input | Movement model 11.2 (injury, burden) | No stage source: the Echo save holds no injury; `EchoActor.gd:56` sets hp to max. |
| 9 | Return safety needs wiring | Plan: "`escape_bonus` read by the party profile" | `escape_bonus` and `intel_retention` are already read (`VentureController.gd:337,374`). B+C only bends the value. |
| 10 | Picker wording | D-18: Jeff rewrites before B+C | `data/balance.json` descriptions still hold the old text. Jeff's text is now known (D-34). It goes in by script copy in the data step. |
| 11 | Bid suppression vs fear | Movement model 10.1 (fear is hesitation) | `compute_bids` checks suppression BEFORE fear, so a suppressed frightened Echo never bids reactive. Section 6a changes this. |
| 12 | Terrain "open or uncertain ground" | Movement model 11.4 (Seek crosses open ground) | Stage terrain is walkable or not, plus bridge cells (`StageTerrain.gd`). It has no cost classes. Exposure comes from known hostile situations only (Section 3b). Bridges are not counted (D-31). |
| 13 | One reactive-bid rule | `ConversationService.compute_bids` is the bid rule (`ConversationService.gd:483`, `fear_current >= 60`) | `StageExploreSnapshotBuilder.gd:191` re-derives the bid type with its own `fear2 >= 60`. Moving only one literal to config makes the card and the sim disagree. Both read one key (D-33). |
| 14 | One meaning of "60" in the conversation code | D-33 names "the reactive threshold 60" | The same file holds a second, different 60: NPC fear in the turn score (`ConversationService.gd:287`), and a third in `ContactConversationService.gd:74`. Each needs its own config key, not the reactive key. |
| 15 | D-29 on stop timing | D-29: Scout stops for any new find | Stage reveals in one sweep after the walk (`StageExploreTurnService.gd:309`). The stop rule needs a per-step reveal. This is feasibility check 2, not a decision change. |
| 16 | Minimum window size | `AGENTS.md` says desktop windows may shrink to 960x540 | D-39: B+C is designed and checked at 1280x720 and 1920x1080. `AGENTS.md` is not edited here. OPEN item for Jeff. |
| 17 | Step bar draws no second number | Earlier text of section 8 item 5 and `uiux-notes.md` (cut the fraction) | RESOLVED by D-43: the step row shows diamonds only and lost steps are crossed out. The live count label (`StepFractionLabel`, "n/n") is deleted in the build. |
| 18 | Two uses of "glyph" | Section 8 item 6 (D-40 item 11): the Directive tint and glyph | Section 8.1: the stop kind glyph. Different things. Item 6 means the Directive's own mark. |

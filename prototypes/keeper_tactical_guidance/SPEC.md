# Keeper Tactical Guidance Prototype Spec

**Status:** Local experimental prototype  
**Version:** 0.6  
**Owner:** Jeff  
**Location:** `prototypes/keeper_tactical_guidance/`  
**Commit policy:** Entire folder is intentionally ignored by Git.  
**Canon status:** Non-canonical experiment. It does not change the Working GDD unless the playtest succeeds and Jeff explicitly promotes the design.

### Production Baseline

This prototype is a representation of the current game, not a separate combat design. Unless this document explicitly labels a rule as a **prototype addition**, behavior must match the production game and its authored combat modes.

Production sources of truth:

- `docs/combat-modes.md` for combat-mode rules.
- `core/combat/CombatState.gd` and the production encounter runtime for implemented resolution behavior.
- `StageTerrain` and `GridService` for deterministic irregular walkable terrain and movement.
- `BehaviorArbiter`, Calling behavior, maturity expression, fear, morale, bonds, skills, and directives for Echo autonomy.
- The Working GDD for Guidance over Control and the meaning of Standing.

The only deliberate prototype additions are:

- Keeper pre-positioning before combat.
- Two additional prototype Directives for testing broader party intent.
- Limited mid-combat priority pings.
- Spatial ping scopes, local Echo responses, and a renewable scope-gated Ping Charge.
- Generated tactical hazards and the board-validation rules needed to make terrain strategically meaningful.

These additions must be tested on top of production behavior. They must not replace it with simplified tactical units or custom mission rules.

### v0.6 Iteration Contract (Frozen)

Version 0.6 responds to the first integrated playtest. Where older wording in this document conflicts with this section, the v0.6 rule wins and the older behavior is removed rather than retained as an alternative.

- Combat is player-facing **automatic-only**. There is no manual step, pause, ping-pause, request-pause, or resume control. The Keeper may choose only `slow`, `normal`, or `fast` playback speed.
- Ping browsing, spatial preview, cancellation, and confirmation do not pause automatic playback. Commands commit only between atomic actor turns, after movement, damage, hazards, theft/custody, counters, objectives, and end-condition updates finish.
- Ping Charge starts at 0, has a starting maximum of 5, and gains exactly +1 after each fully completed round. It never increases per actor turn.
- Confirmed recipients and positional subject are snapshotted immediately at confirmation. Responses are not evaluated in the confirmation round. A ping confirmed in round `r` activates in round `r + 1`.
- Each living snapshotted recipient remains visibly `pending` until immediately before their first living turn in the activation round. At that moment `Align`, `Interpret`, `Hesitate`, `Object`, or `Refuse` and its reason are shown, then that same turn's first movement/action visibly expresses or rejects the guidance.
- Preparation has one Echo assignment interaction: select one Echo in the single party roster, then select one deployment slot on the board. Board tokens show position but are not a second Echo-selection surface.
- Every ping exposes its suggestion, mechanical influence, recipient mode, subject/area rule, eligible recipients, charge requirement, expected activation/duration, availability state, and invalid reason before confirmation.
- Board obstacles use filled, raised silhouettes rather than icons alone. Route and chokepoint lines are optional explained overlays; unexplained decorative or tactical lines are not shown.
- Movement and attacks are animated from structured turn results so target, source, damage, and response-to-guidance are readable without consulting the event log.

These rules preserve all four Directives, all five pings with their exclusive recipient modes, both production-aligned objectives, deterministic simulation, and prototype isolation.

## 1. Purpose

Test whether Realm combat becomes more engaging when the Keeper can prepare the party and issue limited tactical guidance during an otherwise autonomous battle.

The prototype must preserve the central Echoes idea: Echoes are people whose identity, fear, morale, bonds, Standing, Calling, and current condition affect how they interpret guidance. The Keeper influences the battle but does not directly move each Echo or choose every attack.

The prototype is successful only if generated terrain creates meaningful tactical problems and Keeper decisions visibly alter how Echoes respond to those problems.

## 2. Design Question

> Can preparation, tactical terrain, and limited priority pings make combat feel actively strategic while preserving readable Echo autonomy?

This prototype is not intended to prove that Echoes should become a full turn-based tactics game. It tests the strongest middle path between passive observation and direct squad command.

## 3. Target Player Experience

The player should:

1. Read the board and identify a tactical problem.
2. Prepare a formation or broad plan before combat.
3. Watch Echoes act autonomously according to their identities.
4. Recognize a change or danger during combat.
5. Place a spatial intervention to influence the Echoes and tactical problem in a specific part of the board.
6. See each Echo align, reinterpret, hesitate, object, or refuse for understandable reasons.
7. Be able to explain how their preparation, ping, the board, and Echo traits affected the result.

The desired feeling is **responsible influence under uncertainty**, not perfect execution.

## 4. Prototype Boundaries

### In Scope

- One standalone combat sandbox launched independently from the production campaign flow.
- Deterministic board generation from a visible seed.
- Generated hazards, chokepoints, open routes, and objective locations.
- A short preparation phase before combat.
- Autonomous Echo and enemy turns.
- A small set of Keeper priority pings during combat.
- Echo interpretation of preparation and pings.
- Readable explanations of why an Echo responded as they did.
- Combat objectives that make terrain matter.
- Fast restart with the same seed and reroll with a new seed.
- A compact post-battle report for comparing decisions and outcomes.

### Explicitly Out of Scope

- Directly selecting an Echo and commanding an exact move, target, or skill.
- Action points, full cover percentages, flanking, overwatch, reaction fire, or XCOM-style hit calculations.
- Campaign saves, rewards, progression, economy, Sanctum integration, or Realm flow integration.
- Final UI, final animation, final audio, production art, or accessibility completion.
- New Echo progression systems, Callings, emotions, bonds, or relationship models.
- Full procedural level-generation tooling or hand-authored board editor.
- All seven production combat modes. The prototype uses two existing modes: `RECOVER` and `PROTECT`.
- Refactoring production combat architecture to accommodate the experiment.

If an idea does not directly test the design question, it is deferred.

## 5. Core Loop

1. **Generate:** Enter a seed and generate a board, objective, hazards, party, and enemies.
2. **Read:** Inspect terrain, objective, known hazards, Echo tendencies, and predicted enemy pressure.
3. **Prepare:** Choose formation positions and one persistent Directive.
4. **Resolve:** Start autonomous combat.
5. **Intervene:** Use limited Keeper priority pings at meaningful moments.
6. **Interpret:** Observe Echo responses and inspect the reason for each response.
7. **Review:** Compare the outcome, intervention history, Echo responses, and objective result.
8. **Retry:** Replay the same seed with different choices or generate another board.

Target battle length is a **starting value of 4-7 minutes**, including preparation. Adjust only after observing whether decisions become repetitive or too difficult to read.

## 6. Battle Structure

### Phase A: Board Briefing

The player sees:

- Objective and failure condition.
- Entire board geometry.
- Known hazards and their rules.
- Party deployment zone.
- Known enemy entry or deployment zones.
- Each Echo's tactical tendency and current emotional condition.
- Board seed and a regenerate control.

Hidden information is out of scope for the first prototype. The first test must isolate tactical decision quality before testing scouting uncertainty.

### Phase B: Preparation

The Keeper may:

- Assign each Echo to one generated deployment slot within the party deployment zone through one interaction only: select an Echo in the single party roster, then select an empty deployment slot on the board.
- Review a short prediction for each Echo: likely behavior tendency, objective affinity, relevant fear or morale risk, and likely response to the selected priority.

Preparation does not permit skill loadout changes, stat changes, consumables, or exact queued actions.

The party roster is the only Echo selection surface in preparation. It contains exactly one row/card per fixture Echo and shows name, Calling, Standing, maturity expression, fear, morale, tendency, and assigned slot. The board shows each assigned Echo as a positional token, but those tokens do not select, cycle, or reassign Echoes. Do not repeat the party as a second card list, initiative list, assignment matrix, or duplicate set of selectable portraits. Selecting a different roster row changes the pending assignee; selecting an occupied slot swaps the two assignments deterministically. This retains detailed inspection without providing multiple ways to perform the same operation.

The selected Directive remains active during preparation and combat. There is no opening ping because charge starts at 0. Any later priority ping is a temporary tactical emphasis layered on top of the Directive; it does not replace or rename it.

### Phase C: Autonomous Combat

- Actors resolve through initiative order.
- Echoes select movement, targets, and abilities autonomously.
- Enemies use the same board constraints and hazard rules.
- Playback starts automatically when combat begins and remains automatic until review.
- The Keeper may switch among `slow`, `normal`, and `fast` playback without changing simulation ordering or deterministic results.
- Ping selection and spatial preview remain interactive while playback continues.
- A preview or confirmation command received during an actor animation is revalidated and committed at the next atomic actor boundary. Playback proceeds into the next actor without a ping-caused pause.
- No player-facing control advances one actor, pauses combat, requests a pause, or resumes combat.

### Phase D: Review

The report shows:

- Objective result and rounds elapsed.
- Echoes downed or endangered.
- Preparation choice.
- Every ping, its target area or subject, and its cost.
- Each Echo's response and stated reason.
- Hazard damage and forced movement.
- A simple timeline of major tactical events.

## 7. Prototype Directive Set

The prototype offers four Directives. The first two are the existing production Directives. The additional two are **prototype additions** designed to test tactical variety using the existing party-wide intent model.

Directives are selected before preparation and remain active for the whole battle. They bias autonomous decisions but never assign a specific Echo, cell, target, route, skill, or action. Echoes continue to filter the Directive through Calling, maturity expression, fear, morale, bonds, traits, and immediate pressure.

| Directive | Status | Broad intent | Main tradeoff |
|---|---|---|---|
| **Scout Carefully** | Production | Preserve the party, avoid overcommitment, and retain what is learned | Slower objective progress and less willingness to accept exposure |
| **Seek Signs** | Production | Surface hidden meaning, press into uncertainty, and accept contact | Greater exposure and cost when the run goes badly |
| **Press the Path** | Prototype addition | Commit toward the objective and deal with threats that block progress | Greater risk of separation, hazardous exposure, and missed rescue needs |
| **Hold the Circle** | Prototype addition | Maintain cohesion, intercept threats, and protect vulnerable allies or entrusted objects | Slower progress and weaker pursuit of distant opportunities |

### Press the Path

**Intent:** “The purpose is ahead. Make a way toward it. Do not spend yourselves on every fight.”

Use these starting intent weights:

| Intent key | Starting weight | Expected effect |
|---|---:|---|
| `objective_advance_priority` | 0.40 | Raises movement and action choices that advance the authored objective |
| `engage_only_blockers` | 0.30 | Favors dealing with enemies obstructing progress over chasing unrelated threats |
| `exposure_acceptance` | 0.20 | Makes dangerous routes and positions more acceptable |
| `fan_out_bias` | 0.10 | Reduces clustering when several approaches or lanes exist |

Expected expression:

- In `RECOVER`, an objective-suited Echo should be more likely to break toward the relic while others engage blockers.
- In `PROTECT`, the party should be more willing to recover a stolen totem or move custody toward a viable defensive position.
- Fear, bonds, Calling contradiction, hazardous exposure, or an immediate rescue need may cause hesitation, reinterpretation, or refusal.

### Hold the Circle

**Intent:** “Keep one another within reach. Meet the danger before it takes what is in our care.”

Use these starting intent weights:

| Intent key | Starting weight | Expected effect |
|---|---:|---|
| `ally_protection_bias` | 0.40 | Raises guarding, interposition, and protection of threatened allies |
| `threat_interception` | 0.30 | Favors meeting threats approaching the party or protected objective |
| `avoid_overcommit` | 0.20 | Reduces distant pursuit and risky separation |
| `survival_bias` | 0.10 | Slightly favors stable defensive choices under pressure |

Expected expression:

- In `RECOVER`, the party should screen and support the Echo holding the relic, but may reach the relic more slowly.
- In `PROTECT`, Echoes should more readily interpose around the totem and respond to endangered allies or custody threats.
- An Edge-aligned Echo, urgent objective pressure, a distant thief, or severe Calling contradiction may produce reinterpretation or objection rather than uniform defensive behavior.

### Directive Rules

- Exactly one Directive is active for a battle.
- Directive selection is locked once preparation begins.
- A Directive persists until battle resolution and does not use or reset Ping Charge.
- Priority pings temporarily emphasize a tactical need but do not replace the active Directive.
- When a ping conflicts with the Directive, the Echo response model resolves the conflict; the ping does not automatically win.
- The two prototype Directives use only intent keys already understood by the production behavior system.
- The prototype must show the active Directive and make its influence distinguishable from the active priority ping.

### Directive Variety Test

Run the same seed, party, objective mode, preparation positions, and ping schedule once with each Directive.

Pass if:

- Each Directive produces a recognizable difference in route choice, exposure, cohesion, target selection, or objective timing.
- `Press the Path` does not collapse into generic aggression or duplicate `Seek Signs`.
- `Hold the Circle` does not make every Echo guard in place or duplicate `Scout Carefully`.
- Echo identity remains visible within every Directive.

Fail if the Directives differ mainly in text, if one dominates both prototype modes, or if they override Echo identity strongly enough that all party members behave alike.

## 8. Ping Charge and Availability

**Prototype addition:** Pings are asynchronous interventions layered onto automatic combat. They are constrained by renewable, round-based Ping Charge rather than a fixed Guidance pool or intervention windows.

### Availability

- The ping library remains inspectable throughout combat. Locked pings can still be selected to read their explanation and preview their legal footprint, but cannot be confirmed.
- The player may select, aim, preview, cancel, or confirm a ping without stopping automatic playback.
- Simulation mutation occurs only at atomic actor boundaries. A confirm input received during an actor's animated turn is buffered, then revalidated and committed after that turn's movement, action, damage, hazards, theft/custody, counters, objectives, and end conditions finish.
- Preview data refreshes whenever actor positions or board state change. A moving recipient or subject may therefore change eligibility before the buffered confirmation commits.
- Ping Charge starts at 0. The first Echo-specific ping can become available after round 2 completes.
- Availability is controlled only by stored charge, unresolved-ping state, subject validity, recipient validity, and atomic-boundary revalidation.
- Ping interaction never changes playback speed and never introduces an intervention window.

### Charge Generation and Costs

Ping Charge is generated by **fully completed rounds**, not actor turns. This keeps the Keeper's intervention cadence tied to battle time instead of party/enemy count.

| Recipient mode | Starting charge requirement | Reason |
|---|---:|---|
| Echo-specific | 2 charge | Precise influence on exactly one recipient becomes available quickly |
| Area-based | 3 charge | Several nearby Echoes or a tactical route require more waiting |
| Party-wide | 5 charge | Broad influence requires a fully charged meter |

- Ping Charge has a starting maximum of 5.
- After the final living actor entry in a round, resolve its full turn, round-end objective/hold/guard/custody updates, and end conditions. If the round completes, add exactly +1 charge, capped at 5.
- A round produces at most one charge regardless of living actor count. Dead/skipped actors and structures neither add nor remove charge.
- Charge persists across round boundaries.
- Confirming any ping consumes all stored charge and resets the meter to 0. Unspent charge cannot be banked after a ping.
- Cancelling ping placement consumes no charge.
- At 2 charge, only valid Echo-specific pings are enabled.
- At 3 or 4 charge, valid Echo-specific and area-based pings are enabled.
- At 5 charge, all valid ping recipient modes are enabled.
- The meter remains visible at all times and previews how many fully completed rounds are still needed for each locked ping.
- Charge may rebuild while a confirmed ping waits for or resolves during its activation round, but the unresolved ping still blocks confirmation of another ping.
- These requirements are starting values. Test Echo-specific at 2-3, area-based at 3-4, and party-wide at 4-6 charge before promotion.

## 9. Priority Pings

**Prototype addition:** Priority pings are not new Directives and are not production combat actions. They are short-lived spatial influences applied through the same weighted behavior philosophy as the existing directive system.

The prototype includes exactly five pings.

| Ping | Recipient mode | Positional subject or footprint | Behavioral influence |
|---|---|---|---|
| **Hold Ground** | Echo-specific | Select exactly one living Echo and an anchor tile within 1 tile of its current position | That Echo prefers guarding, protecting nearby allies, and remaining in or returning to the anchor |
| **Break Through** | Area-based | A contiguous lane up to 5 tiles long and 1 tile wide; recipients are living Echoes on the lane or within 1 tile of its starting tile | Recipients prefer movement through the marked lane and engagement with enemies obstructing it |
| **Focus Threat** | Party-wide | Select one visible enemy or enemy totem carrier as the subject; every living Echo is a recipient | Recipients increase priority for the marked enemy while still allowing rescue, survival, Calling, or objective pressure to override |
| **Regroup** | Area-based | Select a rally tile with radius 3; recipients are living Echoes currently inside that radius | Recipients prefer movement toward the rally tile, proximity to affected allies, protection, and leaving hazardous exposure |
| **Secure Objective** | Party-wide | The current production objective is the subject; every living Echo is a recipient | Recipients prefer entering, interacting with, holding, or defending the objective according to its mode rules |

Each ping card must explain the Keeper's suggestion in plain language before the player aims it:

| Ping | Player-facing suggestion | Targeting instruction |
|---|---|---|
| **Hold Ground** | “Ask one Echo to defend this nearby position and protect allies within reach.” | Select one living Echo, then an anchor no more than 1 tile away. |
| **Break Through** | “Mark a short lane and ask nearby Echoes to push through it and confront blockers.” | Select the lane start and end; maximum 5 contiguous tiles. |
| **Focus Threat** | “Ask the whole party to treat one visible enemy as the urgent threat.” | Select one living visible enemy or enemy totem carrier. |
| **Regroup** | “Call Echoes already near this point to gather, protect one another, and leave danger.” | Select a rally tile; the radius-3 footprint determines recipients. |
| **Secure Objective** | “Ask the whole party to prioritize the current RECOVER or PROTECT objective.” | The current objective is selected automatically. |

These explanations describe influence, never guaranteed exact movement, attacks, skills, or obedience.

### Ping Rules

- Every ping has exactly one recipient mode: `party_wide`, `area_based`, or `echo_specific`.
- Recipient modes are mutually exclusive. A ping cannot combine modes or add individually selected Echoes to an area-based or party-wide recipient set.
- `party_wide` snapshots every living Echo as a recipient.
- `area_based` snapshots only living Echoes currently inside the confirmed tile, radius, or lane footprint.
- `echo_specific` requires exactly one living Echo recipient.
- A ping may also have a positional subject such as an anchor tile, lane, rally point, objective, or enemy. The subject defines what the guidance concerns; it never changes the ping's recipient mode.
- A ping targets the tile, area, lane, objective, or enemy defined by its positional rule.
- Before confirmation, the UI shows the ping's suggestion, mechanical influence, recipient mode, targeting instruction, full footprint, positional subject, eligible Echo names, charge requirement, activation round, expected duration, availability state, and invalid-target reason.
- Every ping has exactly one availability state: `available`, `insufficient_charge`, `blocked_unresolved`, `invalid_subject`, or `no_eligible_recipients`. Availability uses text plus shape/icon, not color alone. `available` means it can commit at the next atomic boundary if revalidation still passes.
- The footprint and eligible recipients remain visible while aiming even when charge is insufficient; the confirm control is disabled and the exact missing-round/charge reason is shown.
- Recipient membership is snapshotted at confirmation. An Echo entering the area later is not retroactively affected; an affected Echo leaving the area still carries the guidance until its response resolves.
- Confirmation in round `r` records `confirmed_round = r` and `activation_round = r + 1`. It immediately snapshots subject, footprint, and recipients, consumes all stored charge, and marks every living recipient `pending`.
- No recipient evaluates or reveals a response during the confirmation round, even if their initiative entry has not yet occurred.
- On each snapshotted recipient's first living turn in the activation round, reveal their response and reason immediately before autonomous intent selection, then resolve and animate that first action using the resulting influence.
- The ping expires for that Echo after its first activation-round turn. The placement expires globally when all living snapshotted recipients have completed that turn, or at activation-round end after dead recipients are removed.
- `Focus Threat` and `Secure Objective` are the party-wide pings in this prototype.
- Pings modify intent and target-priority scores for their snapshotted recipients; they never guarantee exact movement, targets, or actions.
- An Echo response is evaluated locally only on that recipient's first living turn in `activation_round`, never at confirmation and never in `confirmed_round`.
- Echoes outside the recipient set do not evaluate or respond to the ping.
- A ping with no eligible living Echo recipient cannot be confirmed.
- Invalid targets cannot be confirmed and must show a reason.
- Only one ping placement may be unresolved at a time. Charge may begin rebuilding while recipients resolve, but another ping cannot be placed until the current placement expires.

## 10. Echo Response Model

Each affected Echo responds to the local ping using existing identity and state where practical. The prototype may use simplified adapters or fixture data, but it must not invent a second competing identity system. Unaffected Echoes continue resolving the active Directive and production behavior normally.

### Response Outcomes

| Outcome | Meaning | Mechanical result |
|---|---|---|
| **Align** | The guidance fits the Echo and current situation | Full ping influence |
| **Interpret** | The Echo accepts the goal but pursues it in their own way | Partial influence with Calling or behavior preference emphasized |
| **Hesitate** | Fear, low morale, danger, or conflict slows commitment | Reduced influence for this turn; may choose safety first |
| **Object** | The Echo believes another priority matters more | Ping influence is strongly reduced; objection is surfaced before acting |
| **Refuse** | The guidance exceeds what this Echo will currently accept | No ping influence for this turn; autonomous baseline behavior continues |

### Inputs to Response

Use these existing systems together. Their conflict resolution must remain state-sensitive, as defined by the Working GDD; this list is not a fixed global priority order:

1. Immediate survival state: current health, nearby danger, hazardous exposure.
2. Fear and morale.
3. Calling or mature expression fit with the ping.
4. Bonds and protectiveness toward endangered allies.
5. Standing and maturity expression, which shape how strongly and coherently the Echo interprets or asserts their own judgment. Higher Standing must not be treated as greater obedience.
6. Baseline behavioral preferences and current objective pressure.

The first implementation should use clear threshold rules before adding probabilistic variation. The same seed and same decisions must produce the same outcome.

### Required Explanation

Every non-align response must expose one primary reason and may expose one secondary reason. Examples:

- "Ama hesitated: fear is high and the marked lane is burning."
- "Kojo interpreted Regroup as protecting Abena because of their bond."
- "Esi objected: the totem is one turn from being lost."

The explanation is part of the mechanic, not optional flavor. If the player cannot understand resistance, autonomy will feel like ignored input.

### Response Readability States

Each snapshotted recipient has one player-facing guidance state, shown on its board token and its single combat roster row:

- `pending`: confirmed guidance has been received but cannot be judged until this Echo's first turn in the activation round. Show the ping glyph, “Considering”, and `Acts in round N`; do not predict an outcome.
- `listening`: the revealed outcome is `align` or `interpret`. Show the named outcome and concise reason/interpretation in a positive, non-obedience-coded treatment.
- `resisting`: the revealed outcome is `hesitate` or `object`. Show the named outcome and primary reason in an amber treatment.
- `rejecting`: the revealed outcome is `refuse`. Show “Refuse” and the primary reason in a distinct red treatment.
- `unaffected`: the Echo was not in the immutable recipient snapshot; show no response badge or speech cue.

Color is secondary to text, icon shape, token pulse/outline, and the immediate action. At reveal, the Echo receives a short response callout before their action. The subsequent movement/attack animation must be readable as the first behavioral evidence: toward/within the subject when following, a Calling-shaped alternative when interpreting, safety/competing priority when resisting, or autonomous baseline when refusing. The UI must never label an unaffected Echo as refusing.

## 11. Generated Board Rules

### Board Goal

Every valid board must present at least two plausible routes or tactical plans, with terrain that changes the value of preparation and pings. The board should feel like a natural West African landscape — irregular, organic, and inhabited — rather than a clean tactical grid.

### Starting Dimensions

- Board bounds: 10x10 to 14x10 cells, but the usable board footprint may be irregular and uneven.
- Walkable cells: 55-75% of board footprint.
- Party deployment zone: 4-6 valid slots.
- Enemy deployment or entry zones: at least 2 separated groups or directions.
- Objective zones: 1 primary zone; optional secondary tactical anchor.

These are starting values, not production commitments.

### Required Features Per Board

Each generated board must contain:

- An irregular outer shape or broken edge profile; no perfect rectangle is required.
- At least 1 meaningful chokepoint, 1-2 cells wide.
- At least 2 routes between deployment and objective, unless the objective is specifically a hold scenario.
- At least 2 hazard zones using at least 2 hazard types.
- At least 1 open area where concentrated enemies create exposure risk.
- At least 1 defensible or stabilizing area.
- At least 1 differentiated terrain patch expressed through existing walkable topology or one of the prototype hazards.
- At least 1 landmark or objective structure that helps the player read position and routes.
- A connected path from every deployment slot to the objective.
- No objective or required route completely blocked by unavoidable lethal hazards.

The board should resemble a battle site that could exist in Akan-influenced West African terrain: broken ground, ridges, carved paths, stream crossings, brush, stones, termite mounds, village remnants, shrine structures, or other grounded landscape features. For this prototype, those descriptions are visual and topological language only. Do not add elevation, line-of-sight, climbing, cover, or water simulation unless a defined hazard explicitly supplies the mechanical rule.

### Chokepoint Definition

A chokepoint is not merely a narrow visual gap. It is a traversable section whose blockage or control changes path choice or delays access to the objective. The generator must validate that removing or occupying its key cell or cells meaningfully changes shortest-path distance or route availability.

### Route Diversity Rule

For standard objective boards, the party must have at least two viable paths from deployment to objective. The routes should differ in at least one of:

- Length.
- Hazard exposure.
- Enemy pressure.
- Width and ability to support multiple Echoes.
- Access to a defensible area.
- Interaction with a chokepoint, bridge, irregular plateau, landmark, or hazard zone.

Boards where one route is obviously superior in all respects fail validation.

## 12. Hazard Set

**Prototype addition:** Production combat currently supports irregular walkable terrain but does not implement these hazard effects. Hazards are intentionally part of this test because the prototype must determine whether generated boards can create stronger tactical decisions. They use the production walkable grid and affect the existing actors and objectives; they do not create a replacement combat model.

The prototype includes exactly three hazards.

| Hazard | Rule | Tactical purpose |
|---|---|---|
| **Burning Ground** | Deals fixed damage after an actor ends a turn on it | Punishes stationary defense and makes route timing matter |
| **Unstable Ground** | On entry, pushes the actor one valid cell away from the hazard center; if no cell is valid, deals fixed damage instead | Disrupts formation and creates positional risk |
| **Binding Growth** | Entering ends remaining movement for that turn | Makes chokepoints and retreats costly without adding damage |

### Hazard Rules

- Hazards affect Echoes and enemies by the same rules.
- Hazard cells are visible during briefing.
- Entry and end-turn effects must be clearly previewed.
- A hazard cannot trigger more than once per actor turn unless explicitly stated.
- Forced movement cannot place an actor outside the walkable set or onto an occupied cell.
- If multiple hazard effects could resolve, use a fixed deterministic order.
- Hazard damage values are tuning placeholders and must be low enough that one mistake does not decide the battle alone.

## 13. Prototype Objectives

Use exactly two existing production combat modes so terrain can be tested in different strategic contexts without inventing parallel mission rules. All mode parameters must come from the production objective configuration or use the same defaults and completion-order scaling.

Killing all enemies remains a universal victory path where production currently allows it. The prototype is specifically testing whether board topology, hazards, preparation, and priority pings make the authored objective the strategically interesting path rather than scenery around a generic kill-all battle.

### Mode A: RECOVER

Use the existing `RECOVER` rules:

- A relic structure is placed deep on the board with enemies between the party and the relic.
- Win when a living Echo remains adjacent to the relic for the configured consecutive `hold_rounds`.
- The hold counter resets when no living Echo is adjacent at round end.
- Lose when all Echoes are dead.
- Preserve the production universal kill-all victory behavior.

For this prototype, RECOVER boards should place the relic beyond a meaningful chokepoint with at least two viable approaches. The approaches must differ in distance, hazard exposure, width, or enemy pressure. The relic and hold rules do not change.

This mode tests route choice, the ability to establish and maintain adjacency under pressure, the value of `Break Through`, `Regroup`, and `Secure Objective`, and whether different Echoes naturally divide into holder and screening behaviors.

### Mode B: PROTECT

Use the existing `PROTECT` rules:

- A totem structure must remain alive.
- The protection counter advances at round end only while at least one living Echo is within the configured guard radius.
- The protection counter resets when no living Echo is within that radius.
- Win when the configured `duration_turns` is reached while the totem has not been stolen.
- Lose immediately if the totem is destroyed or all Echoes are dead.
- If the enemy holds the totem when the duration expires, lose with the production `totem_taken` outcome.
- Preserve the production carryable roll, holder debuff, enemy theft, recovery, and enemy-carrier double-damage behavior.
- Preserve the production universal kill-all victory behavior.

For this prototype, PROTECT boards should place the totem where at least two enemy approach lanes create competing defensive pressure, with a defensible fallback position available when the seeded totem is carryable. Hazards may make one lane or fallback temporarily undesirable, but may not make protection impossible.

This mode tests pre-positioning, multi-lane defense, custody and repositioning, `Hold Ground`, `Focus Threat`, and `Regroup`, and whether Calling, bonds, fear, morale, and maturity visibly affect who protects, intercepts, carries, or pursues a thief.

### Why These Two Modes

`RECOVER` asks the party to cross dangerous ground and establish control at a deep fixed objective. `PROTECT` asks the party to maintain custody while pressure approaches from several directions. Together they test opposing terrain problems using combat rules already present in Echoes.

## 14. Ping Timing and Attention Cues

There are no fixed intervention windows and pings do not pause combat. Charge is earned at round end, but a funded ping may be browsed, aimed, or submitted at any time during automatic playback.

The expected interaction is:

1. Combat resolves and animates actors continuously at the selected playback speed.
2. Each fully completed round adds +1 Ping Charge, up to 5; threshold cues announce newly fundable scopes without stopping playback.
3. The Keeper opens or changes a ping preview while combat continues. The board continuously shows its exact footprint/subject and eligible recipients.
4. Confirm input is acknowledged immediately as `queued` if an actor is resolving. At the next atomic boundary, the simulation revalidates the subject, recipients, charge, and unresolved state.
5. On successful commit, all stored charge is consumed; subject, footprint, and recipients are snapshotted; those recipients become `pending`; automatic playback continues.
6. No response occurs in the confirmation round. In the activation round, each recipient's response and reason appear immediately before that recipient's first turn, followed by the animated first action expressing or rejecting it.
7. The unresolved ping clears after all living recipients act in the activation round or at that round's end. Charge may have rebuilt meanwhile, but another ping cannot commit until the prior one clears.

### Attention Cues

The interface may call attention to high-signal changes without forcing a pause:

- Ping Charge reaches a new recipient-mode threshold or becomes full.
- An Echo becomes critically wounded or is downed.
- The relic hold is broken or nearly complete.
- The totem becomes threatened, carried, stolen, recovered, or near destruction.
- A hazard changes an expected route or displaces an actor.
- Several Echoes become separated across different tactical areas.

These cues are informational. They do not grant charge, bypass a charge requirement, create an extra ping, or become the only moments when the Keeper may act. Multiple simultaneous cues combine into one concise alert.

## 15. Required UI and Feedback

This is a functional test interface, but decision-critical information cannot be placeholder text hidden in logs.

The prototype must show:

- Board, walkable cells, hazards, chokepoints, routes, objective, deployment zones, and actors.
- Current objective status.
- Current Directive and its broad intent.
- Current unresolved ping, its confirmed and activation rounds, recipient mode, footprint/subject, snapshotted recipients, and pending recipients.
- Ping Charge, maximum charge, round-based gain rule, and the rounds/charge still required by locked ping modes.
- Current actor and initiative order.
- A persistent `Slow | Normal | Fast` speed control; no pause, resume, or manual-step control.
- Selectable ping cards with plain-language suggestion, mechanical influence, targeting instruction, recipient mode, charge, availability state, and invalid reason.
- A pre-confirmation board preview that distinguishes subject/footprint, eligible recipient tokens, ineligible Echoes, and confirmation validity without relying only on color.
- Each recipient's `pending`, `listening`, `resisting`, or `rejecting` state and response reason at the defined activation timing.
- The strongest reason behind autonomous behavior when it conflicts with a ping.
- Hazard and objective consequences on the board and in the event timeline.
- Same-seed restart and new-seed generation.

Temporary debug overlays may expose route scoring, intent weights, and generator validation. They should be toggleable so readability can also be tested without them.

### Board Visual Language

- Non-walkable obstacles are opaque, filled, raised isometric forms with a visible footprint and side faces. Use distinct silhouettes for rock/ruin, vegetation, and landmark blockers where data permits; an icon may supplement but never replace occupied volume.
- Hazards remain walkable floor effects with distinct fill/pattern plus an icon and tooltip/legend rule: flame/heat for Burning Ground, fractured displacement arrows for Unstable Ground, and dense binding vines for Binding Growth.
- Normal tile borders are quiet and uniform. Remove decorative interior tile seams that can be mistaken for paths or barriers.
- Routes are optional translucent directional ribbons with arrowheads and route labels, visible only when the `Routes` overlay is enabled.
- Chokepoints are optional bracket/gate markers over the validated cells, visible only when the `Chokepoints` overlay is enabled.
- Deployment uses a filled zone tint and numbered slot markers. Ping footprints use a separate pulsing fill/outline and recipient markers.
- An always-available compact legend explains obstacle, each hazard, objective, deployment, pending ping, route overlay, and chokepoint overlay. No tactical line or fill may appear without a legend entry or direct label.

### Animation Acceptance Criteria

Simulation remains discrete and deterministic; presentation consumes a structured `last_turn_result` and never reconstructs attacks from prose timeline entries.

- Movement animates the acting token through its ordered path rather than teleporting. Starting value: 180 ms per tile at Normal speed, clamped to keep a multi-tile move readable.
- Melee/attack presentation names source and target spatially: starting values are 140 ms anticipation, 100 ms lunge/swing toward the target, 160 ms target punch/flash, then 120 ms recovery.
- Damage appears at the target with a floating signed number, HP-bar change, and target hit reaction. Starting value: 450 ms number lifetime.
- Hazard entry/end-turn effects animate at the affected cell and actor after movement; forced movement visibly continues from entered cell to final cell.
- Response reveal appears immediately before the recipient's activation-round turn for a starting value of 500 ms, then the action animation follows without another actor intervening.
- `Slow`, `Normal`, and `Fast` scale presentation duration only. Starting multipliers are `0.6x`, `1.0x`, and `1.8x`; simulation results and ordering are identical.
- Important actions use at least two feedback channels: motion plus flash/outline/text. Audio is optional in this prototype.
- A fresh observer must identify who moved, who attacked whom, whether damage landed, and whether a guided Echo listened or rejected in at least 8 of 10 sampled turns without opening the event log.
- Respect a local reduced-motion toggle if present: replace lunge/punch displacement with outline/flash while retaining timing order and text.

All timing and multiplier numbers above are **starting values**. Tune only from playtest evidence; shorten if combat becomes unreadably queued, lengthen if observers cannot identify source/target or response before the next actor.

## 16. Technical Isolation Rules

- All new prototype files remain inside `prototypes/keeper_tactical_guidance/`.
- Do not modify production `core/`, `ui/`, `data/`, tests, campaign saves, or flow states for the first prototype.
- Reuse by copying minimal logic or loading read-only production definitions only when this does not create production dependencies on the prototype.
- The prototype may depend on production code; production code must never depend on the prototype.
- Use a dedicated deterministic seed namespace for all prototype generation and resolution.
- Do not write to the production save path.
- Prefer fixture parties and explicit test Echoes over campaign integration.
- Any candidate production change discovered during prototyping must be recorded in `FINDINGS.md`, not implemented in production.

## 17. Minimum Test Roster

Use four fixture Echoes with deliberately different behavior profiles:

1. A steady protector who favors allies and holding ground.
2. A bold pursuer who favors pressure and direct routes.
3. A cautious seeker who avoids hazards and favors safer paths.
4. A volatile or fearful Echo whose response changes sharply under pressure.

Fixtures should map to existing Echo fields and Calling/expression concepts. They are test instruments, not new canonical characters.

## 18. Playtest Matrix

### Test 1: Board Strategy

- Play the same seed twice with different deployment and opening priorities.
- Pass if the two plans produce visibly different routes, pressure points, or objective timing.
- Fail if actors converge on the same behavior regardless of preparation.

### Test 2: Directive Variety

- Replay the same seed with all four Directives while holding preparation and ping use constant.
- Pass if each Directive creates a recognizable strategic pattern and neither prototype Directive dominates both modes.
- Fail if the two new Directives merely duplicate the production pair or suppress Echo identity.

### Test 3: Mid-Combat Agency

- Play once without pings and once using at least three pings deliberately across different recipient modes.
- Pass if at least two pings visibly change recipient behavior or prevent/create a tactical consequence.
- Observe the choice at 2-4 charge: use a narrower ping now or wait for broader influence.
- Pass if different tactical situations make both spending early and waiting for full charge defensible choices.
- Fail if pings only change hidden scores or produce cosmetic feedback.
- Fail if players always spend immediately at 2 charge or always wait for 5 regardless of board state.
- Pass only if browsing, aiming, confirming, and observing the intervention never requires or causes a combat pause.
- Confirm one ping after its intended recipient has already acted in round `r`; pass if the Echo remains pending, reveals no response in `r`, then reveals and expresses the response on its first turn in `r + 1`.

### Test 4: Echo Identity

- Issue the same ping to the same party under at least two emotional states.
- Pass if responses differ for legible character reasons while remaining deterministic.
- Fail if all Echoes align identically or resistance appears arbitrary.

### Test 5: Chokepoint Value

- Generate 10 boards for each prototype mode.
- Pass if at least 8 of 10 contain a validated chokepoint that affects movement or control.
- Fail any board with disconnected deployment, unreachable objective, or mandatory lethal path.

### Test 6: Route Choice

- On 10 standard boards, compare route costs and actor use.
- Pass if at least 8 provide two viable routes with a real tradeoff.
- Fail if one route dominates on safety, distance, and objective access simultaneously.

### Test 7: Readability

- Ask a player or observer why an Echo did not follow a ping.
- Pass if they can identify the main reason in 8 of 10 observed cases.
- Fail if they must inspect logs or know internal formulas.
- Ask what each ping suggests before use and which Echoes its preview affects. Pass if a new player answers correctly for 4 of 5 pings without opening debug data.
- Sample 10 turns containing movement or damage. Pass if an observer identifies source, target, and result in at least 8 without the timeline.

### Test 8: Enjoyment and Attention

- After three battles, ask when the player felt they were making a decision rather than waiting.
- Pass if they name preparation, at least one mid-combat intervention, and at least one board-reading decision.
- Warning if they spend most resolution time waiting for charge, cannot interact before the moment has passed, or treat speed controls as a substitute for tactical attention.

### Test 9: Preparation Consolidation

- Give a new player the task “put Adwoa in slot 3, then swap her with Kwame.”
- Pass if they use the single roster-to-board assignment path without first trying a duplicate portrait, initiative entry, or board token as a second selector.
- Fail if the party appears as multiple selectable lists or if two controls can perform the same assignment.

### Test 10: Overlay and Obstacle Clarity

- With overlays off, ask which cells are blocked and which contain hazards. Pass at least 8 of 10 samples without relying on icons alone.
- Enable Routes and Chokepoints separately. Pass if an observer names the purpose of each line from its legend and does not identify it as an obstacle.

## 19. Prototype Success Criteria

The prototype is worth developing further only if all of the following are true:

- Preparation changes a meaningful battle outcome in at least 60% of paired same-seed tests.
- All four Directives produce distinguishable behavior, and no Directive is the best choice across both prototype modes and most tested boards.
- At least 70% of used pings cause a visible behavioral change on the recipient's first living activation-round turn.
- Partial charge creates a meaningful spend-now-versus-wait decision rather than one consistently correct timing rule.
- Players correctly explain non-aligned Echo responses at least 80% of the time.
- At least 80% of generated boards pass connectivity, chokepoint, and route-diversity validation.
- Players report at least three meaningful decisions in a typical battle.
- Echo personality remains noticeable without making outcomes feel random.
- The player wants to retry a seed to test a different plan.

These thresholds are starting hypotheses. Record results before changing them.

## 20. Stop Conditions

Stop or redesign the prototype if any of these persist after one focused tuning pass:

- Pings require direct movement commands to feel useful.
- Echo refusal is consistently experienced as input failure rather than character expression.
- Generated hazards add visual noise but do not change decisions.
- Board validation requires extensive hand-authored exceptions.
- The autonomous resolution remains mostly waiting for charge, or ping interaction distracts from observing combat despite never pausing it.
- Preparation predicts the whole battle so strongly that mid-combat decisions are unnecessary.
- One Directive dominates both `RECOVER` and `PROTECT`, or the two additions cannot be distinguished from the production pair.
- Mid-combat pings overwhelm identity and make all Echoes behave alike.
- The prototype starts requiring campaign, economy, progression, or production UI work to answer its core question.

## 21. Decision After Testing

Choose one outcome based on evidence:

### Promote

The middle path works. Write a canonical GDD proposal and an architecture plan for integrating tactical board generation, preparation, and Keeper pings into production.

### Iterate Once

The core interaction works, but one specific weakness blocks judgment. Define one narrow second experiment with a measurable target. Do not expand feature scope.

### Reject

The added agency does not justify its complexity, damages Echo autonomy, or still feels passive. Preserve useful board-generation findings and return to the existing combat direction.

### Explore Direct Control Separately

Only choose this if playtests consistently show that players understand the systems but still require exact unit control to enjoy combat. Treat that as a new prototype with a new design question, not a scope extension of this one.

## 22. Build Order

1. Standalone sandbox entry and deterministic fixture battle.
2. Board generator with connectivity, chokepoint, route, and hazard validation.
3. Board briefing and deployment preparation.
4. Autonomous battle using fixture Echo tendencies.
5. Four-Directive selection and intent-weight comparison.
6. Automatic-only playback with three presentation speeds and structured turn animations.
7. Non-pausing ping browsing/preview/confirmation, round-based Ping Charge, three exclusive recipient modes, and five priority pings.
8. Next-round pending/response outcomes and readable reasons.
9. Consolidated preparation assignment and explained board overlays/obstacles.
10. Two production modes and post-battle comparison report.
11. Same-seed test harness and playtest logging.

Do not begin the next step until the current step is playable and answers its smaller test question.

## 23. Open Design Questions

These questions are intentionally deferred until the baseline prototype is playable:

- Whether pings should be party-wide, area-based, or addressed to one Echo in production.
- Whether `Press the Path` or `Hold the Circle` deserves promotion into the full Directive library after testing.
- How Standing and maturity expression should change interpretation and self-assertion without becoming an obedience bonus.
- Whether scouting should hide hazards, enemy positions, or routes.
- Whether hazards should be static, timed, spreading, or Realm-specific.
- Whether a later production version needs a costly emergency charge advance or requirement bypass for critical situations.
- Whether preparation belongs on StageMap, the stage briefing, or another production surface.

None of these should block the first prototype.

# Keeper Tactical Guidance — Production Design Proposal

**Status:** Approved design reference — interaction model promoted into GDD V2.5  
**Source experiment:** `prototypes/keeper_tactical_guidance/` v0.6  
**Primary evidence:** `prototypes/keeper_tactical_guidance/FINDINGS.md`  
**Canonical authority:** `docs/Echoes vNext Working GDD.md`  
**Purpose:** Elaborate the approved player-facing design promoted from the successful prototype. GDD V2.5 is canonical; this reference does not itself implement production combat or tuning.

## 1. Executive Decision

The **Keeper Tactical Guidance interaction model** is the approved direction for production Realm combat. Implementation remains subject to the validation and production gates in this document.

The promoted direction is a middle path between passive autobattle and direct tactical command:

- combat resolves continuously and automatically;
- the Keeper prepares the party, reads the board, and sets broad intent;
- the Keeper issues limited spatial pings while combat continues;
- Echoes interpret guidance through who they are and what is happening to them;
- terrain, hazards, objectives, emotions, relationships, and identity create legible consequences;
- the Keeper never chooses an exact move, attack, skill, or target for an Echo.

This proposal promotes the interaction model, not every prototype value or implementation shortcut. The prototype supplies strong qualitative evidence that the model can produce meaningful choices, challenge, tactical attention, and concern for Echoes. It does not yet satisfy every quantitative success threshold or prove the design across all combat modes, parties, Realms, and board families.

## 2. Player Fantasy and Desired Experience

The player is an Ase Keeper who knows and guides people rather than commanding pieces.

The central combat fantasy is:

> I read the trial, prepare Echoes I understand, guide them when the situation changes, and trust or confront what they choose to become under pressure.

The target feeling is **responsible influence under uncertainty**. The Keeper should be able to explain why a choice mattered without being able to guarantee perfect execution.

The intended emotional sequence is:

1. **Anticipation:** read the objective, terrain, hazards, and party fit.
2. **Commitment:** choose a formation and Directive with real tradeoffs.
3. **Attention:** watch an automatic battle for developing pressure.
4. **Intervention:** spend scarce guidance on a timely, spatial suggestion.
5. **Character revelation:** see each affected Echo consider, interpret, resist, or refuse.
6. **Consequence:** recognize the Echo's first action as an expression of that response.
7. **Reflection:** understand how preparation, identity, board state, and intervention shaped the result.

The design succeeds when the player cares about both tactical outcomes and what those outcomes reveal about an Echo.

## 3. Design Principles

### 3.1 Guidance over control must remain playable

Indirect control is not permission for opaque or ineffectual input. The Keeper must have meaningful influence; the game must acknowledge the input immediately; and behavior, resistance, and consequences must be readable.

### 3.2 Echoes are people, not tactical units

Guidance changes weighted intent. It never guarantees an exact path, target, skill, or action. Calling, fear, morale, bonds, Standing, maturity expression, immediate danger, objective pressure, and hazard exposure remain able to shape or override the suggestion.

### 3.3 Automatic combat creates the attention test

Combat is player-facing automatic-only. The Keeper may change presentation speed but may not pause, manually advance actors, or enter a command phase. Pings must reward observing a live situation rather than turning combat into chess.

### 3.4 Character friction must preserve agency

Echo resistance should usually modify, reinterpret, delay, or substitute an intended behavior before escalating to hard refusal. Every non-aligned response requires a clear primary reason. Higher Standing means stronger self-command and more coherent interpretation, not greater obedience.

### 3.5 Tactical information must be learnable

The board, objective, hazards, current intent, ping footprint, eligible recipients, response state, action source, target, and consequence must be legible without consulting a debug log. Ambiguity may protect character interpretation; it may not conceal decision-critical rules.

### 3.6 Preparation and intervention must solve different problems

Preparation establishes a broad plan. A Directive remains the persistent party-wide intent. Pings respond to a changing local situation. Neither should make the other redundant.

Preparation must also present the party once. One visible party representation and one Echo-selection path are the rule; making a second representation non-interactive does not solve the duplication problem.

### 3.7 Determinism supports learning

Same seed plus the same decisions must produce the same simulation result. Same-seed replay should let the player compare formation, Directive, roster, and ping timing rather than wonder whether hidden randomness caused the difference.

## 4. Final Core Loop

1. **Brief:** inspect the authored objective rules, irregular board, known hazards, deployment, likely pressure, and party state.
2. **Prepare:** choose one Directive and assign each Echo to one deployment slot.
3. **Commit:** begin automatic combat; formation and Directive lock for the encounter.
4. **Observe:** read movement, objective pressure, fear, morale, bonds, hazards, and enemy intent as actors resolve continuously.
5. **Guide:** browse and preview pings without pausing; choose whether to spend narrower guidance now or wait for broader scope.
6. **Anticipate:** confirmed recipients remain visibly pending until their first turn in the next round.
7. **Witness:** immediately before that turn, see the Echo's response and reason, followed by the first action that expresses or rejects the guidance.
8. **Review:** read the outcome, major decisions, guidance history, responses, hazard effects, and objective events.
9. **Retry:** replay the same seed with different choices or continue to a new trial.

Production battle duration, round count, and charge cadence remain tuning questions. The prototype's 4–7 minute battle target is evidence-gathering scaffolding, not a final commitment.

## 5. Automatic Combat and Playback

- Combat begins automatically after preparation and remains automatic until resolution.
- The Keeper has `Slow`, `Normal`, and `Fast` presentation speeds only.
- Speed changes presentation timing, never initiative order, simulation decisions, charge, or results.
- There is no pause, resume, manual-step, fixed intervention window, or ping-caused pause.
- Actor resolution remains atomic. Movement, action, damage, counters, hazards, objective updates, custody/theft, and end conditions complete before a buffered ping confirmation mutates simulation state.
- Ping browsing, aiming, cancellation, and confirmation remain available during playback.
- Input is acknowledged immediately. A confirmation made during an animation is visibly queued, then revalidated at the next safe actor boundary.

This keeps the Keeper active as an observer and guide while protecting deterministic state and readable presentation.

## 6. Preparation

Preparation must provide consequential planning without becoming a loadout spreadsheet or a second command game.

The Keeper may:

- inspect the objective, visible terrain, hazards, deployment zone, and known pressure;
- inspect each Echo's name, Calling, Standing, maturity expression, fear, morale, tactical tendency, objective affinity, and relevant warning;
- choose exactly one persistent Directive;
- assign each party Echo to one valid generated deployment slot.

Preparation uses exactly one visible party representation and one Echo-selection path:

1. select an Echo in the single party roster;
2. select a deployment slot on the board;
3. selecting an occupied slot swaps assignments deterministically.

During briefing and deployment, `RealmShell` must hide or collapse its persistent EchoBar so the preparation roster is the only visible party representation. The EchoBar returns when combat begins, where it serves live party status rather than deployment selection. Board tokens remain necessary positional feedback, not portraits/cards and not a second selection surface. Do not duplicate the party as another portrait strip, initiative selector, assignment matrix, card list, or parallel roster—even if the duplicate cannot be clicked.

Preparation does not allow exact queued actions, skill targets, movement paths, consumable timing, or stat manipulation. Skill-loadout and broader party management remain separate systems and must not be folded into this flow merely because they also occur before combat.

### 6.1 Directive set proposed for production validation

| Directive | Broad intent | Primary tradeoff |
|---|---|---|
| **Scout Carefully** | Preserve the party, avoid overcommitment, and retain what is learned | Slower objective progress and lower exposure tolerance |
| **Seek Signs** | Surface hidden meaning, press into uncertainty, and accept contact | Greater exposure and higher cost when the run goes badly |
| **Press the Path** | Commit toward the objective and confront threats blocking progress | Separation, hazard exposure, and missed rescue pressure |
| **Hold the Circle** | Maintain cohesion, intercept threats, and protect allies or entrusted objects | Slower progress and weaker distant pursuit |

`Scout Carefully` and `Seek Signs` are established production-aligned Directives. `Press the Path` and `Hold the Circle` remain promotion candidates until controlled comparison shows that they are distinct from the production pair and neither dominates across objectives and boards.

Exactly one Directive is active for the full battle. It biases intent and never specifies a recipient, tile, route, skill, target, or exact action. A ping layers a temporary tactical emphasis over the Directive; it does not replace it.

## 7. Round-Based Charge, Continuous Pings

Ping Charge controls intervention scope; rounds control charge generation; neither creates an intervention window.

### 7.1 Charge rules

- Starts at `0`.
- Starting maximum is `5`.
- Gains exactly `+1` after a fully completed round, capped at `5`.
- A round grants at most one charge regardless of living actor count.
- Structures, dead actors, and skipped initiative entries do not generate charge.
- Charge persists across round boundaries.
- Cancelling an unconfirmed ping consumes nothing.
- Confirming any ping consumes all stored charge and resets it to `0`.
- Charge may rebuild while a confirmed ping awaits or completes next-round resolution.
- Only one ping may remain unresolved; rebuilt charge cannot fund another until the prior placement clears.

Starting scope requirements:

| Recipient mode | Charge | Tactical question |
|---|---:|---|
| `echo_specific` | 2 | Is precise help now worth giving up broader influence later? |
| `area_based` | 3 | Is this local formation or route the decisive pressure point? |
| `party_wide` | 5 | Is a battle-wide priority worth waiting for? |

These are starting values. Promotion into final tuning requires evidence that both early spending and waiting are defensible in different situations.

### 7.2 Continuous timing and safe commitment

- The ping library remains inspectable at all times, including while a ping lacks charge.
- Preview continuously updates as actor positions and board state change.
- The Keeper may submit a ping at any time during playback.
- A submission during an actor animation commits only after the current atomic turn completes.
- At that boundary, charge, subject, footprint, recipients, and unresolved state are revalidated.
- Failure to commit shows the exact current reason and consumes no charge.

## 8. Five Pings and Exclusive Targeting

Every ping has exactly one mutually exclusive recipient mode. A positional subject describes what the advice concerns; it never creates a hybrid recipient mode.

| Ping | Recipient mode | Subject / footprint | Suggestion and influence |
|---|---|---|---|
| **Hold Ground** | `echo_specific` | One living Echo and an anchor within 1 tile | Ask that Echo to defend the nearby position, protect allies within reach, and remain at or return to the anchor. |
| **Break Through** | `area_based` | Contiguous lane up to 5 tiles long and 1 tile wide | Ask Echoes in or beside the lane's start to push through it and confront blockers. |
| **Focus Threat** | `party_wide` | One visible living enemy or enemy totem carrier | Ask every living Echo to treat that subject as urgent while allowing survival, rescue, Calling, and objective pressure to override. |
| **Regroup** | `area_based` | Rally tile with radius 3 | Ask living Echoes currently inside the footprint to gather, protect one another, and leave dangerous exposure. |
| **Secure Objective** | `party_wide` | Current authored combat objective | Ask every living Echo to prioritize entering, interacting with, holding, defending, or recovering the objective according to its existing mode rules. |

Recipient rules:

- `party_wide` snapshots every living party Echo.
- `area_based` snapshots only living party Echoes inside the confirmed footprint.
- `echo_specific` snapshots exactly one selected living Echo.
- No ping may add individually selected Echoes to an area or party recipient set.
- Entering a footprint after confirmation does not add an Echo.
- Leaving after confirmation does not remove a living recipient.
- A ping with no eligible living recipient cannot be confirmed.

Before confirmation, every ping must show:

- plain-language suggestion;
- mechanical influence, explicitly framed as weighted guidance rather than guaranteed obedience;
- recipient mode;
- targeting instruction and subject;
- exact area, lane, anchor, or objective footprint;
- eligible Echoes and visually distinct ineligible Echoes;
- charge requirement and current availability;
- confirmation round, expected activation round, and expected duration;
- invalid-target or blocked reason.

## 9. Next-Round Echo Responses

A confirmed ping in round `r` activates in round `r + 1`.

At confirmation:

- subject, footprint, and recipients are snapshotted;
- all living recipients become `pending`;
- no response is evaluated or revealed during the confirmation round;
- the board and roster identify the ping, `Considering`, and the activation round.

On each snapshotted recipient's first living turn in the activation round:

1. evaluate that Echo's response immediately before autonomous intent selection;
2. reveal the named response and a concise reason;
3. resolve and animate the same turn's first movement or action as behavioral evidence;
4. expire the guidance for that Echo after the turn.

The placement clears when all living snapshotted recipients have acted or at activation-round end after dead recipients are removed. Unaffected Echoes do not evaluate, display, or imply a response.

### 9.1 Response ladder

| Outcome | Meaning | Influence |
|---|---|---|
| **Align** | The suggestion fits the Echo and situation | Full intended influence |
| **Interpret** | The Echo accepts the purpose but expresses it through their own identity | Partial, Calling-shaped influence |
| **Hesitate** | Fear, morale, danger, or contradiction slows commitment | Reduced influence; safety may come first |
| **Object** | The Echo judges another responsibility more important | Strongly reduced influence; competing priority is surfaced |
| **Refuse** | The suggestion crosses what the Echo will currently accept | No ping influence; autonomous baseline continues |

Presentation groups may use `listening` for Align/Interpret, `resisting` for Hesitate/Object, and `rejecting` for Refuse, but the named outcome and reason must also be shown. Absence of a response always means unaffected, never refusal.

Every non-Align response exposes one clear primary reason. A secondary reason is optional. The response reveal is part of the mechanic, not flavor text.

## 10. Identity and State Inputs

Responses and autonomous action selection use the existing Echo self rather than a separate ping-personality system.

Inputs are state-sensitive rather than globally ranked:

- immediate survival, current danger, health, and hazard exposure;
- fear as immediate threat response;
- morale as follow-through, persistence, and recovery pressure;
- Calling family and expression as identity-consistency pressure;
- bonds and rivalries as protection, rescue, interception, repositioning, and emotional priority;
- Standing, Storyweight maturity, and hidden maturity expression as coherent judgment and self-assertion;
- archetype, virtue profile, vows, prior behavior, and current instability where production already exposes them;
- active Directive, objective pressure, and baseline tactical tendency.

Higher Standing must not increase compliance. Lower-Standing or unstable Echoes may be interrupted more by fear and bonds. Higher-Standing Echoes should more coherently interpret, object, or refuse when guidance contradicts claimed identity. Hard refusal is credible under severe identity mismatch, vow contradiction, bond emergency, collapse, or extreme fear, but should not become the default response texture.

The intended character dynamic is learnable unpredictability: the player gets better at knowing an Echo, not at commanding a deterministic puppet through a hidden obedience stat.

## 11. Terrain, Hazards, and Board Variety

Production boards should use irregular walkable topology to create at least two plausible plans with meaningful tradeoffs. Terrain must change the value of formation, Directives, pings, and Echo identity.

Each applicable tactical board should provide:

- an irregular, organic footprint rather than a clean rectangle;
- connected deployment and accessible objectives;
- at least one meaningful chokepoint whose control changes route cost or access;
- route diversity through distance, width, hazards, enemy pressure, objective access, or defensible ground;
- visible deployment, enemy pressure, objectives, landmarks, and tactical zones;
- no unavoidable lethal route;
- deterministic same-seed output.

The prototype proved that readable topology can matter but also showed that boards remain too similar. Production promotion therefore requires a board-variety plan, not merely higher random variance. Variation should come from distinct topology families, objective-pressure patterns, route relationships, landmarks, hazard compositions, and deployment/enemy arrangements while retaining bounded validation and avoiding extensive hand-authored exceptions.

### 11.1 Proposed hazard set

| Hazard | Rule | Tactical purpose |
|---|---|---|
| **Burning Ground** | Fixed damage after an actor ends a turn on it | Punishes static defense and changes route timing |
| **Unstable Ground** | On entry, push one valid cell away from its center; if impossible, deal fixed damage | Disrupts formation and makes positioning risky |
| **Binding Growth** | Entering ends remaining movement for that turn | Makes chokepoints and retreats costly without direct damage |

Hazards affect Echoes and enemies equally, are visible before commitment where scouting rules permit, trigger at most once per actor turn, and resolve in a fixed deterministic order. Values must not let one hazard mistake decide a battle alone. Realm-specific presentation or later hazard evolution may be explored only after these core rules prove legible and strategically distinct.

## 12. Objectives

The proposal does not invent or redefine combat objectives. Foundation tactical guidance covers every currently authored production combat objective—`COMBAT`, `PURIFY_SHRINE`, `RECOVER`, `PROTECT`, `ENDURE`, `PURSUE`, and `GUIDE_SPIRIT`—and must preserve each mode's configured win, loss, hold, guard, carrying, theft, structure, scaling, and universal kill-all behavior.

The prototype directly validated only `RECOVER` and `PROTECT`. Their detailed evidence below informs the promotion, but it does not narrow the production Foundation scope. The other currently authored modes require production compatibility design and mode-specific verification as part of Foundation completion.

### 12.1 `RECOVER`

- Preserve the production relic placement and adjacent-hold objective.
- Preserve configured consecutive hold behavior, reset behavior, defeat behavior, and universal kill-all victory.
- Boards should offer at least two viable approaches to the deep objective with a meaningful difference in exposure, distance, width, enemy pressure, or defensive support.
- The tactical test is reaching, establishing, and maintaining objective control while autonomous Echoes divide holding and screening responsibilities.

### 12.2 `PROTECT`

- Preserve the authored production rules: the totem has a seeded `60%` chance to be carryable; carrying burdens its holder; specific classes/states mitigate that burden; enemies can steal the totem and then deal double damage; and totem survival, defeat behavior, reward seams, and universal kill-all victory remain intact.
- Preserve configured protection/guard logic rather than replacing it with prototype-only mission rules.
- Boards should present at least two enemy approach pressures and, where carrying permits, a viable fallback position.
- The tactical test is custody, protection, interception, repositioning, and pursuit under pressure.

These carrying, holder, mitigation, theft, and double-damage rules are authored canon in `docs/combat-modes.md`, not optional mechanics or tuning questions. Where the current production runtime does not yet implement the complete holder/carry lifecycle, that is an implementation gap the promoted production slice must close. `PROTECT` acceptance must verify deterministic carryability, pickup/custody state, holder burden and mitigation, enemy theft, recovery/custody changes, double damage while an enemy carries the totem, save/re-entry where applicable, and correct win/loss resolution. The prototype's local adaptation is evidence, not a substitute for closing the production gap.

The prototype showed `PROTECT` as meaningfully more difficult when the protected subject began under enemy pressure. That supports objective-specific roster and Directive choices, but production placement must be tuned so difficulty is intentional and fair rather than a forced opening failure.

For `COMBAT`, `PURIFY_SHRINE`, `ENDURE`, `PURSUE`, and `GUIDE_SPIRIT`, tactical fields, guidance subjects, previews, Echo interpretation, and readability must fit the existing objective rules documented in `docs/combat-modes.md`. Their production validation begins from authored behavior rather than assuming that the two prototype scenarios generalize unchanged.

## 13. UI and Feedback Requirements

### 13.1 Information hierarchy

Always visible and glanceable during combat:

- objective state and urgent failure pressure;
- current actor and initiative sequence;
- active Directive;
- Ping Charge and next scope thresholds;
- unresolved ping, activation round, and pending recipients;
- each affected Echo's response state;
- speed controls.

Available on demand without halting combat:

- complete ping explanations and targeting previews;
- Echo identity/state detail and response reasons;
- hazard and objective rules;
- route/chokepoint overlays and legend where appropriate;
- structured event history and comparison report.

### 13.2 Board language

- Ground tiles establish the walkable surface.
- Actors and combat feedback render over ground.
- Raised obstacles render as opaque filled volumes over actors when spatial depth requires occlusion.
- Obstacles use footprint, mass, side faces, and silhouette; icons may supplement but never replace occupied volume.
- Hazards are walkable floor treatments with distinct fill/pattern, icon, and rule.
- Ordinary tiles have no unexplained interior lines.
- Routes are optional labeled directional ribbons, not barriers.
- Chokepoints are optional labeled gate/bracket markers, not hazards or obstacles.
- Deployment and ping footprints use distinct treatments and non-color-only recipient markers.
- Every tactical line, fill, icon, and state has a legend entry or direct label.

### 13.3 Guidance feedback

- Selecting a ping explains what it suggests before asking for a target.
- Preview shows availability, exact footprint/subject, eligible recipients, cost, activation timing, and invalid reason.
- Confirmation receives immediate acknowledgment without stopping combat.
- Pending recipients remain clearly highlighted until activation.
- Response reveal precedes the Echo's turn and names Align, Interpret, Hesitate, Object, or Refuse.
- The first resulting action must make following, reinterpretation, resistance, or rejection spatially understandable.

Important outcomes use at least two channels—such as motion plus flash, outline, glyph, callout, number, or HP change—and never rely on color alone.

## 14. Animation and Combat Readability

Presentation consumes structured simulation results and never reconstructs action meaning from timeline prose.

Required beats:

- movement interpolates through the resolved path instead of teleporting;
- attacks identify source and target through anticipation, lunge or swing, target reaction, damage feedback, and recovery;
- hazard entry, forced movement, and end-turn effects animate in deterministic order;
- objective custody, theft, recovery, hold, guard, and destruction have visible state changes;
- response callouts appear immediately before the affected Echo acts;
- actor and obstacle depth order communicates real spatial occlusion;
- reduced-motion presentation substitutes outline, flash, and text for displacement while preserving sequence and meaning.

Animation timing is presentation-only. It may gate when the next discrete result is shown but may not alter simulation order or outcome. Final timings require observation at all playback speeds and compact/desktop layouts.

## 15. Why This Direction Merits Promotion

The successful prototype playtest produced the following qualitative evidence:

- combat felt substantially more engaging and presented a real challenge;
- preparation, Directive choice, roster fit, and pings were experienced as consequential;
- automatic continuous combat encouraged attention rather than chess-like command;
- `PROTECT` produced a distinct tactical problem and made poor preparation costly;
- fear became readable at the moment it affected the party and created genuine concern for the Echoes;
- Echo identity remained relevant to tactical outcomes;
- isometric terrain, visible hazards, raised obstacles, and clearer overlays made the board understandable;
- the player wanted to reason about different choices rather than dismiss the outcome as passive or random.

These observations support the intended aesthetics of challenge, care, character revelation, and strategic expression. They are especially important because fear and resistance produced attachment rather than input failure.

Automated prototype verification also established deterministic same-seed behavior, board validation, hazard resolution, objective seams, ping recipient exclusivity, round-based charge, delayed responses, automatic playback, and structured presentation. Those checks demonstrate feasibility inside the prototype; they do not substitute for production integration tests or human comprehension measurements.

## 16. Evidence Not Yet Established

Do not claim the following thresholds as passed:

- preparation changes meaningful outcomes in at least 60% of paired same-seed tests;
- all four Directives remain distinguishable with no dominant choice across modes and board families;
- at least 70% of used pings visibly change recipient behavior on activation;
- partial charge reliably creates both defensible early-spend and wait-for-scope decisions;
- players explain non-aligned responses correctly at least 80% of the time;
- new players explain at least 4 of 5 pings and identify recipients without debug information;
- human observers read source, target, damage, obstacles, hazards, routes, and chokepoints at the specified rates;
- typical battles consistently produce at least three named meaningful decisions across multiple players;
- generated topology has sufficient long-term variety;
- the design remains legible with production parties, skills, all Realm pressures, and longer-term progression.

The current evidence is a strong promotion signal from one qualitative playtest plus automated prototype checks, not broad validation.

## 17. Production Scope Boundaries

### 17.1 Initial production slice

The first production slice should include only what is necessary to validate the promoted loop end to end across every currently authored combat objective:

- deterministic tactical board data and mode-appropriate validation for `COMBAT`, `PURIFY_SHRINE`, `RECOVER`, `PROTECT`, `ENDURE`, `PURSUE`, and `GUIDE_SPIRIT`;
- consolidated board briefing and deployment preparation;
- one visible preparation roster with the `RealmShell` EchoBar collapsed until combat;
- one persistent Directive from the approved production set;
- automatic-only playback with presentation speeds;
- round-based Ping Charge;
- five inspectable, spatially previewed pings with exclusive recipient modes;
- immutable recipients and next-round Echo responses;
- identity/state integration through existing behavior seams;
- readable board, objective, hazard, response, movement, and damage presentation;
- post-battle guidance and objective report;
- deterministic tests and same-seed comparison instrumentation.

### 17.2 Explicitly deferred

- exact control of Echo movement, targets, skills, or attacks;
- action points, cover percentages, flanking, overwatch, and direct-tactics subsystems;
- new Callings, virtues, bonds, emotions, progression tracks, or obedience stats;
- hidden-information/scouting expansion;
- dynamic, spreading, timed, or extensive Realm-specific hazard families;
- production board editor or broad procedural-generation tooling;
- economy, rewards, items, saves, and campaign progression beyond existing objective seams;
- final art, audio, accessibility completion, or content-scale tuning before the interaction slice proves itself.

Production code must not depend on prototype code. Promotion means implementing production-owned services and contracts, not moving prototype scripts into `core/` unchanged.

## 18. Tuning and Open Questions

### 18.1 Values requiring controlled tests

- maximum charge of 5;
- Echo-specific cost at 2, area-based at 3, party-wide at 5;
- consuming all stored charge on any ping;
- one unresolved ping at a time;
- next-round, first-turn activation duration;
- movement, attack, response-reveal, and speed timings;
- hazard damage and forced-movement severity;
- target battle length and number of useful intervention opportunities;
- `PROTECT` opening pressure and fallback accessibility;
- board dimensions, density, route count, and topology-family frequency.

### 18.2 Design questions

- Do all five pings remain necessary after production behavior integration, or does one overlap an existing Directive/skill too strongly?
- Do `Press the Path` and `Hold the Circle` join the production Directive library after controlled comparison?
- Should all stored charge always be consumed, or does that erase too much partial-charge strategy?
- Is next-round activation sufficiently responsive at Slow, Normal, and Fast speeds?
- How should dead, downed, carried, or temporarily unavailable snapshotted recipients affect ping expiry?
- Which identity factors may be explained directly, and which should remain clue-based to preserve the fantasy of knowing an Echo?
- How should Calling-family grammar—Anchor, Edge, Sight—shape interpretation without flattening individual Callings?
- How much pre-battle prediction supports good judgment before it predicts the whole battle?
- Which board topology families create genuine variety without making validation brittle?
- Where should preparation live in the production journey: StageMap, stage briefing, or another approved surface? This requires Jeff's UX decision before implementation.
- Which currently authored combat modes need mode-specific guidance subjects or ping constraints, and which future combat objectives need new compatibility design?

## 19. Risks and Abuse Cases

| Risk | Player-facing failure | Required response |
|---|---|---|
| Always spend at 2 | Charge has a dominant timing rule | Rebalance costs, scope value, or situation frequency |
| Always wait for 5 | Early scopes feel wasteful | Strengthen precision/local urgency without making it direct control |
| Pings rarely alter action | Keeper input feels cosmetic | Improve influence, subject relevance, or preview; do not add exact commands |
| Pings override identity | Echoes become interchangeable units | Reduce influence and restore Calling/state/bond priority |
| Resistance is opaque | Autonomy feels like ignored input | Improve pre-signal, named outcome, reason, and action evidence |
| Preparation predicts everything | Watching and pings become unnecessary | Reduce pre-battle certainty or increase evolving board pressure |
| Automatic combat becomes waiting | Keeper disengages between charges | Improve attention cues, pace, objective volatility, and meaningful observation |
| Board validation yields samey maps | Tactical reading becomes routine | Add authored topology families and pressure patterns before random noise |
| `PROTECT` begins unwinnably | Challenge reads as seeded unfairness | Enforce opening survivability, route, and fallback validation |
| Visual effects obscure state | Spectacle destroys mastery | Preserve hierarchy, scale feedback, and support reduced motion |

## 20. Promotion Gates

### Gate A — Canon approval (complete July 12, 2026)

Jeff approved this proposal's player fantasy, combat loop, charge model, five pings, response timing, preparation boundary, and all-current-objective Foundation scope. The agreed design rules are incorporated into GDD V2.5.

### Gate B — Backlog and dependency placement (complete July 12, 2026)

The work was placed relative to active V2 stories after checking current Notion status and dependencies; six relevant pages were updated.

### Gate C — Architecture approval (complete July 12, 2026)

The approved production architecture plan fits deterministic core simulation, `FlowRuntime.dispatch(action)`, snapshot-driven UI, existing encounter/objective services, StageTerrain/GridService, BehaviorArbiter, Calling/maturity-expression seams, and additive save discipline without creating prototype dependencies.

### Gate D — Measured design validation

Run controlled same-seed and human-readability tests against the unmeasured thresholds in section 16. At minimum, validate every currently authored combat objective, all proposed Directives, all five pings, partial-charge decisions, response explanations, and board variety. The prototype supplies direct comparison evidence only for `RECOVER` and `PROTECT`; the remaining modes need equivalent production evidence. `PROTECT` cannot pass this gate until the production runtime—not only the prototype—proves the authored carryability, holder burden/mitigation, theft, enemy-carrier double-damage, custody/recovery, and resolution lifecycle end to end.

### Gate E — Vertical production slice

Ship a playable, visible end-to-end production path for every currently authored combat objective. Each must include briefing, consolidated preparation, automatic combat, continuous pinging, next-round responses, objective resolution, and review. Backend-only completion does not satisfy this gate.

### Gate F — Jeff's in-game signoff

After automated verification, pause for Jeff to test the production slice in-game. Documentation and commit follow only after that approval, in accordance with the project workflow.

## 21. Backlog Placement

The live backlog review found an exact existing home: refine and split [V2-COMBAT-004](https://app.notion.com/p/339c3d1ede92819ab2a3cdf32df96731), whose stated scope already covers tactical pre-positioning and richer mid-battle guidance without invalidating indirect command. Do not create a competing epic and do not expand active [V2-STAGE-004](https://app.notion.com/p/339c3d1ede928111b43af78e2c44f7ee). `V2-STAGE-004` should finish the encounter/objective, persistence, seed-context, logging, and resolution handoff it already owns; deployment, Charge, pings, Echo responses, combat animation, and board interaction remain combat concerns.

Recommended order:

1. Finish and sign off `V2-STAGE-004` without adding tactical-guidance scope.
2. Immediately afterward, take the `V2-COMBAT-004A` architecture/contract slice (planning label; exact split to be assigned in Notion). Lock production state, actions, snapshots, logging, deterministic namespaces, safe-boundary input, re-entry behavior, and the boundary with the completed encounter spine. This is specification and architecture work, not premature full implementation.
3. After the stage contract stabilizes, [V2-COMBAT-002](https://app.notion.com/p/339c3d1ede92817bac21e0a822ced6c8) can proceed with objective/stage-shaped enemy pressure; it does not need to wait for final ping implementation.
4. Before full Keeper-guidance implementation, complete the identity/interpretation dependency chain in order: [V2-PROG-012](https://app.notion.com/p/339c3d1ede928111a2bfc5ad27720596) for autonomy-threshold tuning, then [V2-COMBAT-003](https://app.notion.com/p/339c3d1ede928190ad52ce3f2a0620c8) for deterministic pressure collision and reason-bearing outcomes, then [V2-DIRECTIVE-002](https://app.notion.com/p/339c3d1ede9281039faacf423c3e61ba) for identity-sensitive interpretation of shared influence. Pings must enter these shared behavior seams rather than create a parallel obedience system.
5. Implement `V2-COMBAT-004` as bounded, visible slices: tactical field and preparation; asynchronous Keeper guidance; combat readability and post-battle reporting.
6. Coordinate the single consolidated pre-battle readiness information architecture with [V2-INFRA-004](https://app.notion.com/p/339c3d1ede928133b08af6877b4b5be3). `V2-INFRA-004` owns consolidation of Directive, intel, prep, loadout, fear, and morale information; `V2-COMBAT-004` owns tactical deployment rules and board interaction. Together they must hide/collapse the `RealmShell` EchoBar during briefing/deployment, use the preparation roster as the sole visible party representation and selection path, then restore the EchoBar for live combat status.
7. Defer broad topology/ecology variety to later Realm-content work under [V2-STAGE-101](https://app.notion.com/p/339c3d1ede92816c9e8ee8b897441a0a) and [V2-STAGE-102](https://app.notion.com/p/339c3d1ede92810caf85edeed948513b). The first production generator must still meet tactical accessibility and variety acceptance criteria, but content breadth should not block the promoted interaction slice.

This placement promotes the prototype evidence without enlarging Jeff's active stage story, duplicating an existing canonical backlog home, or implementing pings before their behavior dependencies are stable. The GDD amendment and backlog refinement were approved and applied July 12, 2026; implementation remains unshipped.

## 22. Canonical Amendment Record

GDD V2.5 incorporates the approved rules through a deliberate amendment rather than copying this document wholesale. The amendment places rules in the relevant canonical sections:

- Guidance over Control: meaningful, legible indirect influence;
- Realm/tactical layer: preparation, automatic resolution, terrain, and objectives;
- behavior/autonomy: pings, response ladder, identity inputs, and higher-Standing self-assertion;
- Directives: persistent intent versus temporary tactical emphasis;
- combat presentation: source/target, response, hazard, objective, and animation readability;
- architecture-preservation principles: deterministic simulation, state-first resolution, snapshot-driven UI, and core/presentation separation.

Any proposal value that remains under tuning must be labeled as a starting value in canon rather than presented as final balance.

# Keeper Tactical Guidance — Playtest Findings

**Prototype version:** 0.6  
**Evidence status:** Successful qualitative playtest; promotion candidate  
**Canon status:** Non-canonical. These findings do not change the Working GDD, production architecture, or production combat.  
**Decision gate:** Await explicit Jeff promotion before any GDD or architecture work.

## Outcome

The prototype answered its central design question positively in this playtest: preparation, tactical terrain, and limited Keeper guidance made autonomous combat feel more engaging while keeping Echo identity emotionally legible. The player reported that choices had a real effect, that the battle presented a genuine challenge, and that they felt worried when fear affected the party while still understanding what was happening.

This is strong evidence that the experiment is worth considering for promotion. It is not yet a canonical production decision. The current evidence is one qualitative playtest report rather than a completed measurement set against every threshold in `SPEC.md`.

## Observed Evidence

### Meaningful preparation and consequences

- The player could see that their choices changed battle outcomes.
- Choosing the wrong Directive or bringing Echoes poorly suited to the situation was experienced as a meaningful mistake rather than a cosmetic choice.
- `PROTECT` created a distinct and difficult tactical problem because the protected subject could begin amid enemy pressure. Directive choice and roster fit became especially important in that mode.
- Combat was described as a “real challenge,” supporting the target experience of responsible influence under uncertainty.

This qualitatively supports Playtest Matrix tests 1, 2, and 8, plus the success criterion that players report meaningful decisions. It does not establish the specified paired-test rate of 60%, confirm all four Directives across controlled replays, or prove that no Directive dominates across modes and boards.

### Continuous automatic combat and pings

- Automatic combat with Keeper interventions was more engaging than the earlier pausing interaction.
- The player felt active and attentive while watching the battle rather than positioned as a chess player issuing exact unit commands.
- The revised ping cadence contributed to a combat flow in which Keeper decisions remained consequential without replacing Echo autonomy.

This qualitatively supports the non-pausing requirement in Playtest Matrix test 3 and argues against the stop condition that autonomous resolution is mostly waiting. It does not yet measure the percentage of pings that visibly change behavior, the spend-now-versus-wait decision at partial charge, or whether all five ping explanations are understood by a new observer.

### Echo identity, fear, and emotional readability

- Fear was noticeable at the moment it affected the party.
- The player understood the change rather than experiencing it as unexplained randomness.
- That understanding produced an emotional response: concern for the party.
- Echo suitability mattered alongside Directive and objective pressure, indicating that character identity remained relevant to tactical outcomes.

This is direct qualitative evidence for the target experience, Playtest Matrix test 4, and the success criterion that Echo personality remains noticeable without making outcomes feel random. The formal 80% explanation threshold for non-aligned responses remains unmeasured.

### Tactical board and objective pressure

- The isometric presentation and clarified board made the combat substantially more readable and engaging.
- `PROTECT` exposed a meaningful relationship among objective placement, enemy pressure, Directive selection, and roster composition.
- The player recognized that the board created tactical consequences rather than merely decorating autonomous combat.

This qualitatively supports the core requirement that terrain create meaningful tactical problems. Generator validation is covered by the automated harness, but this playtest does not independently establish the human-observed chokepoint and route-choice thresholds.

## Remaining Limitations

### Board variety

Boards still feel too similar and could be designed with stronger variation. This is accepted as a prototype limitation, not evidence that the central interaction failed. Before production promotion, future design work would need to determine whether greater topology, route, objective-pressure, and hazard variation can be achieved without extensive hand-authored exceptions.

### Actor and obstacle depth order

The remaining visual polish issue is actor/obstacle composition. The desired board draw order is:

1. Ground tiles
2. Actors
3. Visual obstacles

Actors should therefore be occluded when they pass behind obstacle volumes. This is a presentation correction being applied to the prototype; it does not alter simulation, pathfinding, or board contracts.

### Unmeasured success thresholds

The following `SPEC.md` thresholds should not be claimed as passed from this report alone:

- Preparation changes outcomes in at least 60% of paired same-seed tests.
- All four Directives are distinguishable with no dominant choice across both modes.
- At least 70% of used pings visibly change recipient behavior on activation.
- Partial charge supports both defensible early spending and waiting.
- Players explain non-aligned responses correctly at least 80% of the time.
- A new player explains 4 of 5 pings and their affected recipients without debug data.
- Human observation confirms the specified route, chokepoint, animation, and obstacle-readability rates.
- A typical battle consistently contains at least three named meaningful decisions across multiple players.

Automated deterministic and generator checks remain implementation evidence, not substitutes for these human playtest measurements.

## Production Implication

The playtest indicates that production combat likely needs major redesign or tuning to capture the engagement, tactical consequence, and emotional readability demonstrated here. That is a finding, not an implementation instruction. No production system, GDD rule, Directive library, objective rule, or architecture should change from this document alone.

The prototype should be treated as a **promotion candidate**.

## Recommended Next Decision

**Await explicit Jeff promotion before GDD/architecture work.**

If Jeff promotes the experiment, the next work should begin as a separate canonical design proposal and architecture assessment grounded in these findings and additional measured playtests. Until that explicit decision, preserve the prototype and findings as isolated evidence and do not modify production combat.

# Echoes vNext — Movement Model

> **Version:** 1.0
> **Status:** Final and approved for implementation.
> **Approved:** 2026-07-16
> **Authority:** This is the approved movement-system design. `docs/Echoes vNext Working GDD.md` remains primary game canon and `docs/combat-modes.md` remains authoritative for the seven authored combat objectives. New movement rules defined here are v1 implementation requirements unless they directly conflict with those higher authorities.
> **Scope:** Stage exploration, combat movement, movement-facing identity expression, terrain interaction, future equipment seams, player-facing explanations, tuning, and validation.
> **Out of scope:** Direct unit control, visible action-point micromanagement, final elevation/facing rules, final item numbers, and implementation code.

### Decision-status language

This document uses five status levels:

- **CANON:** already required by the Working GDD or `combat-modes.md`;
- **EXISTING:** current production behavior or contract that should be preserved unless explicitly replaced;
- **V1 DECISION:** approved movement-model direction required for implementation;
- **TUNING:** approved rule with starting numeric values that may move through testing;
- **DEFERRED:** useful future capability outside the first movement implementation.

Unless a rule is explicitly marked **CANON**, **EXISTING**, **TUNING**, or **DEFERRED**, new mechanical rules in this document are **V1 DECISIONS**.

### Alignment anchors

This model was checked against:

- Working GDD `7.3` — Guidance over control;
- Echo identity, vectors, bonds, Calling, maturity, and expressed will;
- skill-family movement grammar under Ward, Break, Veil, Path, Rite, and Root;
- Working GDD `19.3–19.4` — light, expressive equipment;
- Working GDD `20.8–20.10` — stage exploration, hidden information, reruns, withdrawal, initiative, and enemy pressure roles;
- Working GDD Foundation tactical-guidance chain;
- `docs/combat-modes.md` for COMBAT, PURIFY_SHRINE, RECOVER, PROTECT, ENDURE, PURSUE, and GUIDE_SPIRIT;
- current stage and combat implementation contracts;
- the Keeper Tactical Guidance prototype and promotion/architecture findings.

---

## 1. Purpose

Movement should be the clearest physical expression of what an Echo, enemy, or traveling party is trying to accomplish.

The player should not need to read hidden weights or count movement points to understand the action. They should be able to see:

- where the mover is trying to go;
- what tactical or exploratory purpose the movement serves;
- why this Echo chose that expression;
- what changed because of the movement;
- when another pressure overruled the obvious objective.

The target experience is:

> **I understand what this person is trying to do, I understand why it makes sense for them, and I can see whether it helped or endangered the objective.**

Movement is not merely translation between cells. It is:

- commitment;
- caution;
- protection;
- pursuit;
- interpretation;
- withdrawal;
- curiosity;
- obligation;
- overreach;
- spatial evidence of personhood.

---

## 2. Why the Current Model Must Change

### Combat

Current combat collapses purpose, route, expenditure, action, and presentation into one `actor.move` intent followed by one-cell mutation.

This creates several player-facing failures:

- identity changes whether an actor moves more often than it changes how or why they move;
- objective pressure usually does not produce an objective destination;
- actors select geometrically near targets without understanding actual route cost;
- protective, retreating, and repositioning actions can have no spatial effect;
- every actor is constrained to one cell even when the board and objective demand decisive travel;
- a turn often reads only as `Move → target`, even when bonds, fear, Calling, vows, or objectives affected the decision;
- battles spend too many rounds on approach without producing meaningful pressure.

### Stage exploration

Current exploration already supports ordered multi-cell travel, but it is governed mainly by fixed Directive step budgets.

This creates different failures:

- `Scout Carefully` and `Seek Signs` are expressed mostly as three versus six cells rather than safer versus more exposed route judgment;
- raw step-budget diamonds are more visible than destination or purpose;
- optional-situation preference is functionally suppressed by the current score threshold;
- frontier selection has a deterministic top-left bias;
- travel barks are selected by cadence rather than the actual movement decision;
- Calling movement actions can be surfaced without a dispatch implementation;
- equipment, burden, identity, terrain difficulty, and party composition do not affect travel.

The new model must preserve what already works:

- deterministic simulation;
- irregular walkable terrain;
- ordered stage travel paths;
- per-step fog discovery;
- mid-path situation interruption;
- objective and situation persistence;
- automatic combat;
- one shared behavior authority for Echo identity and pressure.

---

## 3. Design Pillars

### 3.1 Guidance over control

The Keeper may shape preparation, broad Directive, equipment, party composition, deployment, and limited guidance.

The Keeper does not choose:

- an exact route;
- an exact destination cell;
- exact movement expenditure;
- an exact target;
- an exact movement skill;
- an exact attack sequence.

Movement must remain autonomous but interpretable.

### 3.2 Capability and intent are different

An actor can be physically capable of moving far without choosing to do so.

- **Mobility capacity** answers: how far and through what terrain could this mover travel?
- **Movement commitment** answers: how much of that capability does this mover choose to use now?
- **Movement intent** answers: what purpose is that commitment serving?

This separation is required for identity expression.

### 3.3 The shortest route is a baseline, not a command

Route distance must be understood so actors do not chase geometrically near but topologically distant targets.

However, every mover should not automatically select the same shortest route.

The planner should generate several bounded viable options such as:

- direct;
- safer;
- cohesive;
- low-exposure;
- intercepting;
- lateral;
- objective-focused;
- concealed, when supported;
- vantage-seeking, when supported;
- low-burden;
- low-congestion.

Identity and situation choose among viable routes.

### 3.4 Movement must be causally explainable

Player-facing text must come from the actual winning purpose, option, and decisive pressure.

The UI may say:

- `Ama rushes to break the enemy line.`
- `Kojo hangs back to read the danger ahead.`
- `Esi moves between the hunter and Abena.`
- `Yaw circles around the blocker, looking for an opening.`

It must not claim:

- higher ground when elevation has no mechanical meaning;
- a flank when no flank state exists;
- a back attack when facing or awareness has not been resolved;
- fear as the reason when fear did not change the selected plan;
- Calling as the reason when objective urgency actually forced the move.

### 3.5 Growth should widen expression more than raw distance

Progression should mainly unlock:

- new movement verbs;
- new route capabilities;
- better terrain interpretation;
- stronger role expression;
- more coherent movement-action combinations.

Standing should not produce unbounded movement range or universally better tactical AI.

### 3.6 Shared model does not mean identical domain logic

Stage exploration and combat should share:

- terrain and edge legality;
- movement costs;
- route generation;
- capability tags;
- deterministic route diversity;
- ordered path results;
- movement interruptions;
- explanation contracts.

They should not share:

- target-selection policy;
- objective consequences;
- fog logic;
- initiative rules;
- actor-versus-party aggregation;
- combat threat and range evaluation.

### 3.7 Mover scale and decision authority

Every mover uses the same physical legality and ordered-result contract, but not the same decision model.

| Mover kind | Scale | Decision authority |
|---|---|---|
| Stage party | Group | Party/Directive traversal authority |
| Future roaming stage enemy or NPC | Group token unless separately promoted | Stage role and perception authority |
| Echo in combat | Individual | Full identity and behavior authority |
| Enemy in combat | Individual | Objective pressure + battlefield role + local state |
| NPC, spirit, or temporary ally in combat | Individual | Authored role + limited emotional/survival state |
| Structure | Stationary by default | Moves only through an explicit objective rule |

One stage Advance creates exactly one party Movement Intent, one ordered path, and one Movement Result.

Individual Echoes do not:

- spend separate stage capacity;
- select separate stage routes;
- occupy separate stage cells;
- receive hidden individual stage movement turns.

An optional identified contributor explains why the party plan changed only when their contribution was materially decisive. It does not imply that the Echo traveled separately or directly commanded the group.

---

## 4. Player Goal and Aesthetic

### Primary player fantasy

The Keeper watches people they know interpret danger, duty, terrain, and guidance through their own developing identities.

### Desired dynamics

- the player learns which Echoes overcommit, protect, observe, pursue, or hold;
- party composition changes how a route or battle unfolds;
- bonds create memorable rescue, screening, and regrouping decisions;
- Directives produce broad but non-uniform movement;
- equipment changes opportunity and burden without replacing identity;
- enemy roles become readable through movement before their internal tag is known;
- a bad movement decision can be understandable, emotionally credible, and consequential.

### Primary aesthetics

1. **Expression:** Echoes reveal who they are through spatial behavior.
2. **Challenge:** the Keeper prepares for and interprets autonomous tactical decisions.
3. **Narrative:** movement creates small stories of courage, caution, loyalty, fear, and overreach.
4. **Discovery:** stage travel and combat terrain reveal routes, danger, opportunity, and hidden intent.

---

## 5. Core Movement Pipeline

The shared pipeline is:

```text
Domain pressure + mover perception
→ movement context and mobility profile
→ movement goals and tactical regions
→ viable route options
→ identity / Directive / pressure arbitration
→ movement intent and commitment
→ ordered movement plan
→ per-cell execution and interruption
→ primary action / objective consequence
→ structured movement result
→ player-facing explanation and animation
```

### 5.1 Domain pressure

The domain supplies what matters now.

Combat examples:

- reach the RECOVER relic;
- screen the holder;
- intercept a totem threat;
- cut off the quarry;
- remain near the spirit;
- hold a defensible ENDURE region.

`Screen`, `intercept`, `block`, and `cut off` require spatial consequences.

They do not merely describe destination flavor. They create or exploit hostile-control regions:

- a screen places an actor where an approaching hostile must detour or pay engagement cost;
- an interceptor enters a projected route before the hostile crosses it;
- a blocker controls one or more viable approach edges around their occupied cell;
- a cutoff position raises the cost of the quarry's useful escape routes without requiring every pursuer to occupy the same destination.

The domain adapter must therefore publish objective pressure together with relevant hostile-control, protection, and route-crossing regions.

Stage examples:

- approach a revealed objective;
- investigate a known situation;
- seek an unexplored frontier;
- avoid known danger;
- preserve a return route;
- follow stronger omen evidence.

### 5.2 Knowledge and perception

Movement planning consumes a mover-specific perception state, never unrestricted simulation truth.

- Stage parties use discovered terrain, revealed situations, known hazards, known objectives, and generic frontier geometry.
- Echoes use currently available combat information.
- Enemies know their authored objective and only the battlefield information permitted by their role.
- NPC knowledge comes from authored role and state.
- Omniscience requires an explicit, surfaced capability.

Hidden stage situations, concealed hazards, and unrevealed objectives may interrupt execution when discovered. They may not secretly improve or penalize route scoring before discovery.

### 5.3 Tactical regions, not compulsory cells

Goals should normally produce a region or set of valid tactical cells.

Examples:

- cells adjacent to the relic;
- cells between a threat and the totem;
- an escort ring around the spirit;
- projected interception cells ahead of a quarry;
- safe cells with useful attack range;
- frontier cells satisfying the Directive’s exposure tolerance.

This prevents every actor from being ordered toward one identical coordinate.

### 5.4 Route options

The route generator produces mechanically truthful alternatives without reading personality.

The behavior authority then interprets those alternatives through:

- Calling and family grammar;
- implemented vector/identity direction;
- traits and archetype;
- fear and morale;
- bonds and vows;
- maturity expression;
- objective urgency;
- Directive and Keeper guidance;
- equipment and burden;
- current danger and hazards.

### 5.5 Execution

An ordered plan executes one cell at a time.

Per-cell order:

```text
validate next edge and cell
→ calculate terrain and hostile-engagement cost
→ enter cell
→ resolve entry hazard
→ resolve forced displacement
→ resolve objective / custody interaction
→ check interruption and remaining commitment
→ continue or stop
```

After the final cell:

```text
resolve primary action if legal
→ resolve follow-up / counter / objective effects
→ resolve end-turn hazard
→ publish result
```

---

## 6. Shared Data Contracts

These are design contracts, not final class names.

### 6.1 Movement Context

Contains only the state this mover is allowed to use for planning.

```gdscript
{
  "domain": String,                    # combat | stage
  "mover_kind": String,                # party | echo | enemy | npc | structure
  "decision_model": String,
  "perception_state": Dictionary,
  "terrain_graph": Dictionary,
  "occupancy": Dictionary,
  "relationships": Dictionary,
  "hostile_control": Dictionary,
  "known_hazards": Array[Dictionary],
  "known_objectives": Array[Dictionary],
  "domain_state": Dictionary,
  "seed_context": String,
  "tick": int
}
```

`perception_state` is intentionally separate from authoritative world state.

### 6.2 Movement Profile

Describes capability, not intent.

```gdscript
{
  "mover_id": String,
  "mover_kind": String,
  "decision_model": String,
  "domain": String,                    # combat | stage
  "party_actor_ids": Array[String],
  "physical_baseline_units": int,
  "development_modifiers": Array[Dictionary],
  "temporary_modifiers": Array[Dictionary],
  "capacity_units": int,
  "system_capacity_cap_units": int,
  "capabilities": Array[String],       # walk; future climb, drop, vault, slip
  "terrain_cost_modifiers": Dictionary,
  "burden": Dictionary,
  "status_modifiers": Dictionary
}
```

Combat builds one profile per actor.

Stage exploration builds one party profile plus optional contributor attribution.

### 6.3 Movement Goal

Generated by combat-mode or stage-traversal authority.

```gdscript
{
  "goal_id": String,
  "purpose": String,
  "role": String,
  "subject_kind": String,
  "subject_id": String,
  "anchor_id": String,
  "target_region": Array[Dictionary],
  "desired_range": Dictionary,
  "urgency": float,
  "constraints": Dictionary,
  "completion_conditions": Array[String]
}
```

### 6.4 Movement Option

A mechanically viable route and endpoint.

```gdscript
{
  "option_id": String,
  "goal_id": String,
  "route_style": String,
  "destination": Dictionary,
  "path": Array[Dictionary],
  "base_movement_cost": int,
  "engagement_cost": int,
  "movement_cost": int,
  "metrics": {
    "objective_progress": float,
    "exposure": float,
    "hazard_cost": float,
    "congestion": float,
    "cohesion_delta": float,
    "backtrack": float,
    "combat": {
      "future_action_value": float,
      "protection_reach": float,
      "hostile_control_cost": float,
      "hostile_adjacency_count": int
    },
    "stage": {
      "information_value": float,
      "return_safety": float
    }
  }
}
```

Only metrics relevant to the current domain and implemented mechanics may be populated or scored.

`information_value` means expected information from observable geometry, known evidence, or generic frontier exploration. It must not read hidden content.

Avoid double-counting:

- objective urgency enters through the goal contract once;
- burden and terrain modifiers alter legality/cost before arbitration;
- equipment influences preference only when it creates an additional declared behavioral tradeoff;
- one identity layer must not be scored again under a compatibility alias.

### 6.5 Movement Intent

The behavior authority’s selected purpose and expression.

```gdscript
{
  "intent_id": String,
  "movement_style": String,
  "goal_id": String,
  "movement_option_id": String,
  "commitment": String,                # minimal | measured | full | overcommit
  "planned_action": Dictionary,
  "guidance_expression": String,
  "decision_trace": Dictionary
}
```

### 6.6 Decision Trace

The authoritative explanation source.

```gdscript
{
  "primary": {
    "code": String,
    "source": String,                  # hard_rule | objective | danger | bond | vow |
                                      # calling | vector | emotion | directive |
                                      # guidance | equipment | baseline
    "subject_id": String,
    "causal_kind": String,             # hard_override | co_decisive | baseline
    "material": bool,
    "strength_band": String
  },
  "supporting": Array[Dictionary],
  "purpose": String,
  "message_key": String,
  "message_args": Dictionary,
  "voice_tone": String,
  "debug_components": Dictionary
}
```

Player-facing surfaces never show `debug_components`.

The primary reason must be causal:

- a hard override that selected the plan; or
- a contribution whose removal would change the winning option, movement style, or commitment band; or
- the baseline tactical purpose when no identity pressure was decisive.

Runtime should record normal score/contribution decomposition. Counterfactual removal is primarily a validation technique and may be reserved for tests or high-signal decisions rather than recomputed for every routine movement.

Minor tie-breaking contributions are not automatically promoted into grand character explanations. A surfaced reason must be materially relevant to the selected option, style, or commitment.

Core/logging may retain the complete trace. Snapshot builders must project a sanitized player-safe explanation containing only:

- reason code and source;
- subject;
- purpose;
- message key and arguments;
- voice tone.

Raw scores, weights, trait values, vector totals, and `debug_components` never enter normal player-facing snapshots.

### 6.7 Movement Result

Shared presentation and logging seam.

```gdscript
{
  "tick": int,
  "domain": String,
  "mover_id": String,
  "action_type": String,
  "intent_id": String,
  "movement_style": String,
  "from_pos": Dictionary,
  "to_pos": Dictionary,
  "path": Array[Dictionary],
  "capacity_units": int,
  "commitment_limit_units": int,
  "planned_cost_units": int,
  "cost_spent_units": int,
  "engagement_cost_units": int,
  "interrupted_at_index": int,
  "target_id": String,
  "goal_id": String,
  "player_explanation": Dictionary,
  "events": Array[Dictionary],         # each event has a monotonic sequence field
  "stop_reason": String,
  "contributor_ids": Array[String],
  "decisive_contributor_id": String
}
```

Stage exploration’s existing `traveled_path` should migrate into this shared ordered-path contract.

Path convention:

- `from_pos` is the starting cell;
- `path` contains each resolved destination cell in chronological order;
- `to_pos` is the final resolved cell;
- the starting cell is not repeated inside `path`;
- voluntary and forced displacement cells appear in the same chronological path;
- every event carries a monotonic `sequence` so movement, hazards, forced movement, custody, objectives, attacks, and follow-ups can be reconstructed exactly.

Filtered event projections such as `hazard_events` may be built for convenience, but `events` remains the authoritative order.

---

## 7. Capacity, Commitment, and Movement Cost

### 7.1 Capacity

Capacity is physical and situational.

Primary inputs:

- agility;
- current physical condition;
- terrain capability;
- burden or carried objective;
- equipment;
- explicit movement skills or statuses.

Speed should remain primarily an initiative/readiness input. It may contribute lightly to mobility, but it must not create a large initiative-plus-distance double advantage.

Standing never increases movement cost.

Capacity should be assembled from:

```text
physical baseline
+ persistent progression modifiers
+ developed Calling / skill modifiers
+ temporary technique and status modifiers
- burden, injury, and equipment modifiers
→ clamp to the current system capacity cap
```

Standing gates access to Calling development and movement techniques. It does not directly apply a universal `+1 capacity` at every milestone.

Persistent capacity growth is expected during an Echo's development.

The default target is:

- foundational Echo: usually `2` capacity;
- developed Echo: ordinarily `3` capacity;
- advanced/high-Standing Echo: ordinarily `4` capacity unless their spatial power develops in a deliberately different form;
- movement-oriented Calling or major technique: may reach `5`;
- culmination, exceptional mobility, or a temporary signature technique: may reach the v1 starting `6`-unit system cap.

A high-Standing Echo remaining below the expected `3–4` ordinary-capacity band must reflect an intentional Calling expression or a current equipment, injury, burden, or status penalty. Calling-shaped reductions should be compensated through meaningful spatial power such as interposition, control, reaction movement, burden handling, or cost efficiency.

Every high-Standing Echo should not automatically become a six-tile runner merely because they matured.

The physical baseline is derived from the Echo's current physical profile. It is not an immutable maximum assigned at birth.

`system_capacity_cap_units` is a board-scale and balance safeguard shared by the ruleset. It is not an individual Echo's predetermined potential.

Starting formula:

```text
effective capacity
= clamp(
  physical baseline
  + persistent progression modifiers
  + developed capacity modifiers
  + temporary capacity modifiers
  - burden / injury penalties,
  minimum participation capacity,
  current system capacity cap
)
```

Named edge-cost reductions are resolved separately. A technique should not increase capacity and reduce the same cost unless both benefits are explicitly part of its power budget.

### 7.2 Commitment

Commitment is behavioral.

Primary inputs:

- objective urgency;
- Calling and family grammar;
- implemented vector/identity direction;
- traits and archetype;
- fear and morale;
- bonds and vows;
- maturity expression;
- Directive and guidance;
- hazard and exposure evaluation.

### 7.3 Starting combat envelope — TUNING

These are approved v1 starting values for testing. Their exact numbers remain tunable.

| Value | Starting value | Adjustment test |
|---|---:|---|
| Foundational physical capacity | 2 movement-cost units | Raise only if approach still dominates battle time |
| Expected developed capacity | 3 movement-cost units | Confirm high-Standing Echoes no longer feel spatially static |
| Advanced/high-Standing capacity | 4 movement-cost units | Confirm growth is meaningful without flattening Calling differences |
| Movement-oriented Calling/technique capacity | 5 movement-cost units | Confirm mobility creates new choices rather than universal objective skipping |
| Starting system capacity cap | 6 movement-cost units | Reserve for culmination, exceptional mobility, or temporary signature movement |
| Minimum after burden/status | 1 movement-cost unit | Preserve basic participation |
| Rush extension | +1 temporary unit | Remove or restrict if rush dominates |
| Carried-objective burden | −1 capacity unit | Tune against PROTECT custody viability |
| Normal tile | 1 cost | Preserve current 8-direction step language |
| Difficult tile | 2 cost | Requires additive terrain metadata |
| Hostile-controlled edge | +1 cost once per edge | Tune if engagement becomes irrelevant or creates excessive pinning |

Capacity is measured in movement-cost units, not cells. A two-cell path may cost more than two units when terrain or edges are difficult.

The `2`-unit value is not a permanent cap for every Echo and is not the expected final expression of every high-Standing Echo.

#### Cost-to-tile translation

One normal, unmodified movement edge costs `1` unit.

In the current eight-direction grid:

- one orthogonal tile on normal ground costs `1`;
- one diagonal tile on normal ground also costs `1`;
- adjacency to a friendly or neutral actor does not change that cost;
- a normal edge affected by hostile control costs `2`: `1` base + `1` engagement;
- a difficult edge costs `2`;
- a difficult edge affected by hostile control costs `3`: `2` base + `1` engagement;
- an impassable edge cannot be bought with any amount of normal capacity.

Therefore `1 cost` means “one normal unmodified tile transition,” not “one tile under every condition.”

Example translations:

| Capacity | Route | Tiles resolved |
|---:|---|---:|
| 2 | Two normal open edges: `1 + 1` | 2 |
| 2 | One normal hostile-controlled edge: `1 + 1 engagement` | 1 |
| 2 | One difficult edge: `2` | 1 |
| 3 | Three normal open edges: `1 + 1 + 1` | 3 |
| 3 | One open edge, then one controlled edge: `1 + 2` | 2 |
| 3 | One difficult edge, then one normal edge: `2 + 1` | 2 |
| 3 | One difficult controlled edge: `2 + 1 engagement` | 1 |
| 4 | Four normal open edges: `1 + 1 + 1 + 1` | 4 |
| 4 | Two normal controlled edges: `2 + 2` | 2 |
| 5 | Five normal open edges | 5 |
| 5 | Two controlled edges, then one open edge: `2 + 2 + 1` | 3 |
| 6 | Six normal open edges | 6 |
| 6 | Three normal controlled edges: `2 + 2 + 2` | 3 |

The planner sums the ordered edge costs. It may resolve only the longest legal path prefix whose total cost fits within the selected commitment and physical capacity.

This is also the future obstacle seam:

- rubble may add cost;
- a narrow passage may add a conditional cost;
- a climb may require both additional cost and a capability;
- a wall remains impassable;
- a skill may reduce or ignore only the costs named by its contract.

Raw capacity does not guarantee a fixed number of tiles. It guarantees a fixed amount of movement effort.

### 7.4 Route slack — V1 DECISION / TUNING

Route diversity must remain bounded.

A starting eligibility rule:

```text
candidate route cost
≤ shortest valid route cost
  + max(2, ceil(shortest valid route cost × 0.25))
```

This allows expressive detours without irrational wandering.

The slack comparison uses capacity-spending route cost:

```text
base terrain and edge cost
+ hostile-engagement cost
```

Exposure, hazard consequence, information value, and tactical utility are scored separately.

A safer route may exceed the normal slack when the direct route violates a hard risk ceiling or capability constraint. That exception must be explicit and bounded.

Route generation must also use deterministic computation limits:

- cap shortlisted goals;
- cap candidate endpoints per goal;
- cap route styles per endpoint;
- stop evaluating options that cannot beat the current legal shortlist.

The exact slack should be tuned by:

- board scale;
- route variety;
- objective urgency;
- movement style;
- known hazards;
- party or actor capability.

### 7.5 Unused capacity — V1 DECISION

Unused capacity is not banked by default.

A careful Echo should stop early because the destination is tactically better, then do something meaningful:

- observe;
- guard;
- mark;
- stabilize;
- maintain desired range;
- preserve a formation;
- keep a return route;
- prepare an intercept.

Stopping early without a benefit reads as incompetence, not caution.

### 7.6 Hostile engagement and spatial control — V1 DECISION / TUNING

The direction is approved for v1. The starting numeric cost and exception list remain tuning values to validate during implementation and playtesting.

Adjacency to an active antagonistic or enemy actor reduces effective movement reach.

This is the mechanical foundation for:

- screening;
- blocking;
- interposition;
- cutoff;
- protecting an objective or ally;
- cautious avoidance of premature engagement;
- deliberate commitment into a contested line.

#### Relationship rule

Every occupied cell remains unavailable as a destination regardless of relationship.

Additional movement friction depends on relationship:

| Adjacent actor relationship | Movement effect |
|---|---|
| Friendly / allied | No additional movement cost |
| Neutral / non-antagonistic | No additional movement cost |
| Antagonistic / enemy / hostile | Creates hostile control and engagement cost |

Friendly and neutral actors may still create ordinary congestion because their occupied cells cannot be shared. They do not reduce capacity merely by standing beside the mover.

A hidden or unrevealed hostile relationship may not silently alter route scoring. It must first be perceived, revealed through contact, or resolved as an explicit interruption.

#### Starting engagement-cost rule

Use eight-direction adjacency to match the current movement graph.

For each voluntary movement edge:

```text
resolved movement cost
= base terrain / edge cost
+ 1 hostile-engagement unit
  when the starting or destination cell is adjacent
  to one or more active hostile controllers
```

The hostile-engagement unit is applied once per edge, not once per adjacent hostile.

This means:

- entering hostile adjacency costs more;
- circling while adjacent to a hostile costs more;
- leaving hostile adjacency costs more;
- starting an activation beside a hostile reduces effective reachable distance;
- several surrounding hostiles increase danger, target pressure, and route scarcity without multiplying the movement tax into automatic immobility.

An actor creates hostile control only while physically able to contest movement. Dead, KO, removed, or explicitly non-controlling actors do not create it. Incapacitating statuses must state whether they suppress control.

Hostile control:

- consumes normal movement commitment and capacity;
- does not automatically deal damage;
- does not grant a free reaction attack in the foundation implementation;
- does not permit entry into the controller's occupied cell;
- does not affect forced movement cost, because forced movement does not spend voluntary capacity;
- does affect any voluntary movement that resumes after forced displacement;
- is ignored only by an explicit, surfaced capability such as future phasing, leap, slip, disengage, or breakthrough rules.

Rush pays the same hostile-engagement cost and normally stops on its first hostile-adjacent destination. Passing through an enemy line requires an explicit movement capability rather than Rush alone.

#### Behavioral interpretation

The physical rule is shared. The willingness to enter hostile control is behavioral.

- a cautious Echo treats hostile-controlled edges as a serious exposure and commitment cost;
- a fearful or injured Echo may avoid them unless protection, escape, or objective urgency requires engagement;
- an aggressive, rash, or highly committed Echo may accept the cost early;
- a protective Echo may deliberately enter control to screen an ally or objective;
- a calculating Echo may stop outside control, observe, and commit on a later activation;
- Directive and Keeper guidance may raise or lower the willingness to engage, but do not remove the physical cost;
- objective urgency may justify crossing control while still surfacing the danger and reason.

Enemy and NPC decision adapters use the same cost:

- Blockers and Breakers deliberately project control onto useful routes;
- Hunters accept control when pursuit or isolation pressure justifies it;
- Watchers usually avoid hostile control to maintain range;
- Charges and non-combatant NPCs avoid it unless no safe route remains;
- temporary allies may screen or intercept according to their authored role.

The explanation must distinguish physical cause from behavioral choice:

- `Ama stops short of the enemy line, watching for a safer opening.`
- `Kojo enters the hunter's reach to keep it away from Abena.`
- `The blocker narrows the passage, forcing Esi to slow or go around.`

---

## 8. Action Economy

### 8.1 Combat activation — V1 DECISION

```text
movement commitment
→ one primary action if legal
→ follow-up / counter / objective consequences
```

Normal movement may be followed by one legal action.

Unrestricted move–attack–move is deferred.

### 8.2 Stage Advance — EXISTING DIRECTION

Stage arrival or discovery does not automatically resolve a primary action.

A Stage Advance:

```text
resolves one party movement plan
→ stops on decision-critical discovery or arrival
→ surfaces the situation
→ returns control for Engage, Ignore, choice, or withdrawal
```

Shared movement execution must never make the party auto-engage stage content.

### 8.3 Movement expressions

| Expression | Movement rule | Action consequence |
|---|---|---|
| Measured | Uses only the movement needed to reach a useful position | Retains normal action options |
| Full commitment | Uses available capacity toward the selected purpose | Retains legal action if the plan permits |
| Rush | Gains temporary reach and accepts exposure | Limited to basic engage/attack/interact; no defensive follow-up |
| Screen | Ends where the mover's hostile control taxes or redirects an approach | Enables real interposition/protection |
| Withdraw | Increases safety and disengagement | Usually forfeits attack or limits follow-up |
| Observe | Stops at a reading position | Performs observation, mark, reveal, or preparation |
| Hold | Uses little or no movement | Gains position-specific guard/objective value |
| Skill movement | Uses a capability such as leap, slip, vault, or forced reposition | Defined by the skill contract |

### 8.4 Rush — V1 DECISION / TUNING

Rush must be tempting but dangerous.

Potential consequences:

- `exposed` until the next activation;
- no guard or defensive follow-up;
- increased enemy target priority;
- limited turning or route correction;
- higher hazard acceptance;
- forced stop on engagement.

Rush may create stories such as:

> `Ama rushes into the line, committing past the safer position.`

It should not become the universally optimal way to gain movement and attack.

Emotion language such as anger may only be used when an implemented active state actually contains that cause.

### 8.5 Action revalidation

The planned primary action is revalidated after movement.

It may become invalid because:

- a hazard stopped or displaced the mover;
- the mover died;
- the target died or moved out of legal range;
- custody or objective state changed;
- the required capability or line no longer exists.

Fallback policy must be bounded:

1. resolve the planned action if still legal;
2. resolve a declared closely related fallback from the same tactical purpose;
3. otherwise stop, guard, or observe according to the original intent;
4. do not rerun unrestricted full arbitration and produce an unrelated action.

The fallback and its reason are included in the ordered event stream.

### 8.6 Forced movement

Starting rule:

- forced movement does not consume voluntary movement capacity;
- forced cells still appear in the authoritative chronological path;
- entry hazards normally trigger at most once per actor turn unless explicitly authored otherwise;
- Binding Growth ends remaining voluntary movement;
- an actor killed during forced movement performs no primary action;
- voluntary movement resumes only when the forcing effect permits it and no stop rule fired;
- forced movement cannot enter void or an occupied cell.
- a forced destination may place the actor in hostile control; any later voluntary edge pays the normal engagement cost.

Exact forced-movement exceptions belong to their effect definitions.

---

## 9. Movement Intent Vocabulary

The vocabulary should stay small enough to learn and broad enough to serve both stage and combat.

| Intent | Meaning |
|---|---|
| `advance` | Reduce route distance to an authored objective or priority subject |
| `engage` | Close with a threat directly blocking progress |
| `intercept` | Enter a threat’s route before it reaches an ally or objective |
| `protect` | Move into useful support or guard reach of an entrusted subject |
| `hold` | Establish or maintain an anchor, lane, objective, or formation |
| `pursue` | Maintain pressure on a moving or withdrawing subject |
| `cut_off` | Move toward a projected interception cell rather than the subject’s current cell |
| `reposition` | Improve range, angle, route access, concealment, or future options |
| `regroup` | Restore useful proximity and formation coherence |
| `withdraw` | Increase safety while preserving future participation |
| `read` | Move cautiously to expose information, danger, routes, or omen-relevant ground |
| `escort` | Maintain a moving protection relationship |
| `carry` | Relocate an objective or burden-bearing subject |

Movement styles describe how the intent is expressed:

- direct;
- measured;
- careful;
- forceful;
- cohesive;
- low-exposure;
- lateral;
- intercepting;
- retreating;
- overcommitted.

An intent and style may combine:

- careful advance;
- forceful engage;
- low-exposure reposition;
- cohesive regroup;
- lateral cut-off;
- measured escort.

---

## 10. Identity and Pressure Grammar

### 10.1 Responsibility by layer

| Input | Primary movement effect |
|---|---|
| Agility / physical state | Capacity and difficult movement |
| Speed | Readiness; at most a small capacity contribution |
| Calling / skill families | Movement verbs, tactical roles, route capabilities |
| Implemented vector/identity direction | Motive, style, commitment, role preference |
| Traits / archetype | Tone, tie-breaks, stress response |
| Fear | Exposure avoidance, hesitation, withdrawal, route caution |
| Morale | Follow-through, persistence, willingness to commit |
| Bonds | Protection, rescue, proximity, regrouping, target priority |
| Vows | Doctrine-shaped movement and visible strain |
| Standing / maturity | Coherence and specificity of judgment, not obedience |
| Equipment | Burden, desired range, capability, route cost |
| Directive / guidance | Broad purpose and emphasis, never exact path |
| Objective pressure | Valid goals, urgency, and failure risk |

### 10.2 Calling-family grammar

#### Anchor

Biases:

- protect;
- intercept;
- hold;
- regroup;
- return to entrusted subjects;
- carry burden;
- preserve cohesion.

#### Edge

Biases:

- advance;
- engage;
- pursue;
- break through;
- decisive redirection;
- full commitment;
- risk-taking under urgency.

#### Sight

Biases:

- read;
- reposition;
- cut off;
- hazard-aware pathing;
- route denial;
- desired-range control;
- delayed or measured commitment.

### 10.3 Calling expression

| Calling | Movement expression |
|---|---|
| Okofor | Physically interposes, accepts dangerous anchor cells, returns to threatened allies |
| Aduro | Commits through blockers, preserves momentum, breaches lines |
| Sum-Okwanfo | Uses lateral, patient, or surgical approaches; concealment requires a supported capability |
| Kra-Soro | Reads route cost, distance, interception geometry, exits, and changing ground |
| Okomfo | Repositions around thresholds, objectives, danger, wards, and revealed meaning |
| Onyamesu | Maintains communal reach, stabilizing positions, burden sharing, and cohesion |

### 10.4 Vector and virtue boundary

Dominant and secondary vectors may directly bias movement once that integration is implemented.

Virtue or Thread influence enters movement only through an already implemented identity/integration state. The first movement slice does not create a second direct ten-virtue movement multiplier layer.

| Direction | Movement tendency |
|---|---|
| Vanguard | First commitment, pressure, advance |
| Protector | Intercept, screen, rescue |
| Seeker | Read, scout, investigate |
| Strategist | Efficient route, formation, timing |
| Skeptic | Verify, delay premature commitment, test safer options |
| Pillar | Hold, anchor, endure |
| Devoted | Fulfil duty, carry burden, remain with entrusted subject |
| Opportunist | Exploit openings, use lateral approaches, redirect |
| Mediator | Regroup, reduce separation, stabilize formation |
| Nurturer | Remain in support reach, escort, preserve vulnerable allies |

These are biases, not deterministic assignments.

Two Echoes with the same direction should still diverge through:

- Calling;
- archetype;
- traits;
- bonds;
- fear and morale;
- vow state;
- equipment;
- current objective and terrain.

### 10.5 Bonds and vows

Bonds should first affect:

- intercepting;
- screening;
- rescue movement;
- reluctance to separate;
- regrouping;
- target priority after a bonded ally is harmed.

Full abandonment of the objective should be possible but uncommon and clearly explained.

Vows should change doctrine and strain, not silently add a small numeric bonus.

### 10.6 Maturity

Higher maturity should produce:

- more coherent reinterpretation;
- more specific role-truth;
- stronger ability to maintain a chosen purpose through noise;
- sharper objection when identity is crossed.

It should not produce:

- universally shorter paths;
- higher obedience;
- automatic tactical perfection;
- unconditional extra capacity.

---

## 11. Stage Exploration Movement

### 11.1 Unit of movement

Stage exploration continues to use one party token.

The Movement Model does not require individual Echo tokens on the stage map.

One Advance creates exactly:

- one party Movement Profile;
- one party Movement Intent;
- one ordered party path;
- one party Movement Result.

The party plan should identify:

- optional decisive contributors;
- party capability;
- burden and cohesion;
- Directive commitment;
- destination purpose;
- ordered path;
- interruptions and discoveries.

### 11.2 Party movement profile

Party capacity should not simply equal:

- the fastest Echo;
- the slowest Echo;
- the average of every movement stat.

Recommended model:

- Directive defines the desired commitment posture;
- party physical readiness defines a bounded capacity;
- a Path-family capability may improve route access or difficult-terrain handling;
- a Sight-family tendency may improve interpretation, warning, or commitment judgment;
- burden and injury may reduce commitment or available options;
- Ward/Root capability may reduce the cost of keeping the group coherent;
- equipment may alter burden or unlock route capabilities;
- one or more contributors may be named when their contribution materially changed the result.

### 11.3 Party movement authority

Stage traversal needs a party-specific authority using the same semantic pressure vocabulary as combat without running one hidden BehaviorArbiter turn per Echo.

It receives:

- Directive;
- objective and known-situation pressure;
- party physical profile;
- candidate contributors;
- injury, fear, morale, burden, and cohesion;
- relevant Calling-family capabilities;
- known terrain and hazards;
- withdrawal and return requirements.

It returns one party intent and one causal trace.

Contributor rules:

- `contributor_ids` may contain several Echoes;
- `decisive_contributor_id` is optional;
- an Echo is named only when removing their capability or pressure would change the route, commitment, or stopping decision;
- when the Directive, objective, terrain, or party baseline was decisive, explanation is attributed to the party or Directive rather than a random spokesperson.

### 11.4 Directive expression

#### Scout Carefully

Should mean:

- lower commitment before reassessment;
- safer route preference;
- wider observation;
- avoidance of known combat or hazards where possible;
- stronger return-path preservation;
- greater willingness to stop early when new information appears;
- improved chance of returning with retained intel.

It should not mean only “move three cells.”

#### Seek Signs

Should mean:

- stronger clue and objective-evidence priority;
- deeper commitment before reassessment;
- greater exposure tolerance;
- willingness to cross open or uncertain ground for meaningful information;
- narrower but more precise/deep discovery;
- weaker return safety when the run goes badly.

It should not mean only “move six cells.”

The existing three- and six-step values may remain as starting internal commitment limits until tuned. They should not be the primary player-facing explanation.

### 11.5 Stage goal policy

The stage adapter generates all currently eligible goals with explicit fields for:

- required versus optional;
- objective versus situation versus frontier versus return;
- revealed versus unknown;
- passed versus unresolved;
- urgency;
- Directive compatibility;
- known route risk;
- return feasibility.

The Directive modifies goal utility and commitment. It does not directly name an exact route.

Required-objective preservation:

- a fully explored stage re-offers unresolved required objectives;
- passed optional situations remain dismissed unless an authored rule reactivates them;
- an objective is not automatically an unconditional hard priority unless its urgency requires it;
- optional known situations may genuinely divert the party when their utility and Directive fit justify it.

### 11.6 Stage movement intents

- reconnoitre cautiously;
- press toward a revealed objective;
- seek signs;
- investigate a known opportunity;
- skirt known danger;
- find a lower-exposure route;
- read the terrain;
- force passage;
- find another route;
- withdraw with what has been learned;
- carry or escort a burdened subject.

### 11.7 Stage interruption and internal replanning

Movement stops when:

- the selected goal is reached;
- an unresolved, unpassed situation is entered;
- new information invalidates the route;
- a hazard or obstacle prevents continuation;
- the party elects to stop after achieving the intended information gain;
- withdrawal or return conditions are reached.

Current stage contacts do not create hidden per-Echo engagement zones.

The stage party remains one token. Reaching a hostile contact interrupts the party Advance and returns control according to the stage encounter contract. If roaming stage actors are introduced later, hostile control is evaluated once between group-scale tokens and modifies the party Movement Result; it is never multiplied once for every Echo inside the party.

Unused commitment after a meaningful interruption is not automatically redirected.

Internal deterministic replanning is allowed within one atomic Advance only when:

- the high-level movement intent remains unchanged;
- no decision-critical information was revealed;
- the replan is a local continuation, frontier chain, or blocked-cell detour.

Revealing an objective, hazard, contact, or route fact that changes purpose or risk stops movement and returns control.

### 11.8 Withdrawal

**V1 DECISION:** withdrawal becomes a movement goal toward a known entry/exit region rather than remaining entirely detached from spatial state.

- known safe paths improve return safety;
- exposure, interruption, injury, and burden may worsen return risk;
- Scout Carefully improves return-path preservation and intel retention;
- Seek Signs accepts weaker return safety for deeper information;
- withdrawal can still resolve through a bounded escape check where immediate physical travel would be unnecessarily repetitive.

The exact relationship between exit travel and the existing escape roll remains an open implementation decision.

### 11.9 Excursion persistence

The model must distinguish:

- continuing the same excursion after combat or a situation;
- returning home and beginning a new attempt.

Recommended rule:

- same excursion preserves party position and durable route/goal history required for continuation;
- a new excursion resets party position to entry;
- terrain, explored cells, revealed information, resolved situations, and learned objective state persist according to the GDD.

Unspent capacity or commitment never persists across a combat, situation, save/load, or later Advance. Every new Advance rebuilds the party profile and intent.

The last Movement Result may be retained for the current snapshot/presentation, but must not replay after load.

### 11.10 Stage-to-combat approach handoff

The final stage Movement Result produces a truthful `EncounterApproach` payload.

Potential fields:

```gdscript
{
  "approach_style": String,
  "contact_revealed": bool,
  "exposure_state": String,
  "entry_direction": String,
  "entry_region": String,
  "route_condition": Array[String],
  "party_cohesion": String,
  "known_pressure": Array[String],
  "known_hazards": Array[String],
  "directive_id": String
}
```

This is how stage movement can affect:

- combat entry region;
- surprise or readiness pressure;
- truthful briefing intel;
- cohesion;
- known hazards or approach lanes;
- risk from a rushed or exposed approach.

The stage map and combat board do not have to be the same coordinate instance. When they differ, the briefing translates learned approach and terrain meaning truthfully rather than claiming exact coordinate continuity.

### 11.11 Stage explanation

Current random travel barks should not be the authoritative movement explanation.

Examples:

- `Ama slows the party to read the broken ridge before they commit.`
- `Kojo urges the group onward; the newly revealed sign matters more than the safer route.`
- `Esi finds a lower-exposure route around the disturbance.`
- `Yaw keeps the group close after Abena begins to falter.`

The responsible Echo must have actually changed the route, commitment, or stop decision.

### 11.12 Stage UI direction

Player-facing priority:

1. movement purpose;
2. chosen route character;
3. destination or unknown-search direction;
4. interruption or discovery;
5. contributing Echo and reason.

Raw capacity and spent movement remain debug/internal.

The current step diamonds may be removed or reframed as travel cadence rather than the primary tactical explanation.

Before the player commits an Advance, the snapshot should show a non-mutating broad preview:

- current purpose;
- known subject or search direction;
- likely route character;
- expected commitment posture.

It does not reveal hidden targets or guarantee an exact path. Decision-critical discoveries may still interrupt it.

---

## 12. Combat Movement

### 12.1 Unit of movement

Combat resolves one actor activation at a time according to fixed encounter initiative.

Multi-step movement remains one atomic activation.

The player may watch the ordered animation, but cannot intervene between cells.

One plan is built for each mobile acting actor:

- Echo: full identity authority;
- enemy: pressure-role authority;
- joined NPC/spirit/temporary ally: authored allied role authority;
- structure: no plan unless the mode explicitly moves it.

### 12.2 Role and goal selection

Before path planning, combat supplies tactical roles and valid regions.

Examples:

- runner;
- holder;
- screen;
- interceptor;
- carrier;
- escort;
- rear guard;
- vanguard;
- pursuer;
- cutoff;
- ranged watcher;
- blocker.

Role selection should emerge from the behavior authority and current pressure, not be a permanent class assignment.

Role regions must account for hostile control:

- screen and blocker regions intersect likely hostile routes;
- intercept regions are reachable before the protected subject is reached;
- cutoff regions raise the quarry's useful escape cost;
- cautious approach regions remain outside hostile control where tactically viable;
- engage regions intentionally enter hostile control.

### 12.3 Early stopping

An actor stops before spending full capacity when:

- the tactical goal is achieved;
- desired range is reached;
- a valid intercept or screen position is established;
- an objective interaction becomes available;
- a hazard stops movement;
- the route is blocked and no legal local alternative remains;
- the selected careful/observe plan reaches its intended position;
- continuing would violate the selected commitment.

### 12.4 Congestion and route diversity

Combat movement should:

- plan through temporarily occupied cells so allies are not treated as permanent walls;
- validate every immediate step;
- penalize congestion;
- include hostile-engagement cost in route legality and reachable distance;
- treat hostile occupied cells as impassable and hostile-adjacent edges as controlled;
- allow bounded lateral detours;
- reserve or diversify role destinations where appropriate;
- stop with a named reason if movement becomes invalid;
- avoid repeated backtracking and oscillation.

Route diversity should come first from:

- different goals;
- different role regions;
- different desired ranges;
- congestion;
- hostile control;
- cohesion;
- hazards;
- identity preferences;
- movement history.

Seeded variation should be a final deterministic tie-break, not the main source of difference.

### 12.5 Objective timing preservation — CANON

Multi-step movement does not silently redefine authored win/loss timing.

Movement, action, hazards, custody, and immediate objective interactions complete during the actor activation.

Unless `combat-modes.md` is explicitly amended, the existing round-end authority remains responsible for:

- RECOVER hold progress and reset;
- PROTECT guard progress, theft/custody checks, and clock-out state;
- ENDURE wave and duration progress;
- PURSUE containment progress;
- GUIDE_SPIRIT protection/escort progress and authored objective movement.

Universal kill-all victory remains legal in every authored combat mode.

Reinforcements append according to the mode contract and do not silently re-sort established initiative.

---

## 13. Combat-Mode Movement Requirements

| Mode | Echo movement requirements | Enemy movement requirements |
|---|---|---|
| COMBAT | Engage, maintain useful range, pressure wounded targets, screen allies, reposition around terrain | Pressure roles shape target and movement pattern |
| PURIFY_SHRINE | Reach/find shrine where applicable, grant purifier access, ring-defend, intercept approach lanes | Seek and destroy shrine through authored lanes |
| RECOVER | Runner reaches relic, holder maintains adjacency, others screen lane and engage blockers | Reinforce and pressure holder/relic lane |
| PROTECT | Anchor, intercept, carry/reposition when allowed, fall back, recover stolen totem | Approach objective, create theft opportunity, escape or fight as carrier |
| ENDURE | Hold useful ground, press when viable, avoid distant bait, fall back under collapse | Waves pressure anchors from authored directions |
| PURSUE | Direct chase, fan-out, cutoff, containment ring, route denial | Quarry uses the same exit definition as placement and resolution |
| GUIDE_SPIRIT | Close escort, front screen, rear guard, moving-anchor response | Pressure spirit, isolate escort, contest route |

### 13.1 COMBAT

COMBAT remains the baseline mode.

Movement identity comes from:

- terrain;
- desired engagement range;
- enemy pressure role;
- ally protection;
- actor Calling and current state.

### 13.2 PURIFY_SHRINE

Movement must support:

- shrine discovery when combat begins without sufficient stage intel;
- purifier approach and access;
- non-purifier perimeter positions;
- interception of threats moving toward the shrine;
- controlled return when the shrine becomes endangered.

The implementation must explicitly distinguish:

- shrine location already known from stage intel;
- shrine hidden at combat start and represented by search/reveal regions;
- what enemies know while the shrine remains hidden;
- when the purifier is allowed to target or path toward it.

Combat search is a prerequisite perception/reveal system, not merely a destination flag.

### 13.3 RECOVER

The holder must be selected before the first relevant activation.

Goals:

- runner reaches a valid adjacent relic cell;
- holder maintains adjacency;
- screeners occupy reinforcement and blocker lanes;
- aggressive Echoes engage actual blockers rather than unrelated enemies;
- cautious runners may take a safer viable route;
- the relic remains invulnerable as authored.

Enemies may pressure the holder and relic lane. They may not attack or damage the RECOVER relic.

Preserve:

- holder assignment before the first relevant activation;
- adjacency to the relic rather than entry into its occupied cell;
- authored hold-counter reset semantics;
- reinforcement timing.

### 13.4 PROTECT

Protection must become spatial.

Goals:

- occupy intercept cells;
- maintain a defensible ring or lane;
- carry and reposition a carryable totem;
- apply holder burden;
- recover a stolen totem;
- focus or cut off the enemy carrier;
- move toward fallback terrain when current custody is failing.

Custody requires an explicit ordered contract:

- define whether pickup, recovery, and theft are automatic entry effects or primary interactions;
- move the totem after every voluntary and forced carrier step;
- apply carrier burden at the declared pickup boundary;
- define drop and recovery cell selection;
- define enemy-carrier movement/action restrictions and double damage;
- resolve hazards while carrying rather than allowing the objective to bypass terrain consequences.

### 13.5 ENDURE

ENDURE should not force universal defensive behavior.

Movement should allow:

- aggressive parties to clear waves;
- durable parties to hold and conserve;
- controlled fallback;
- rotation around a defensible feature;
- refusal to chase distant bait;
- pressure-role reactions when the line breaks.

Because ENDURE has no objective actor, the adapter constructs defensive and fallback regions from:

- deployment;
- topology;
- wave approach directions;
- chokepoints;
- reachable fallback access.

### 13.6 PURSUE

Do not send every Echo to the quarry’s current cell.

Goals:

- direct pursuit;
- projected cutoff;
- fan-out to distinct interception regions;
- containment-ring formation;
- route denial;
- quarry escape toward the single authored far-end definition.

The PURSUE contract must also define:

- quarry capacity and action economy;
- whether quarry and Echoes share the same normal capacity envelope;
- escape timing after quarry activation versus round end;
- containment timing at round end;
- cutoff projection from the quarry's traversable escape graph rather than geometric direction.

### 13.7 GUIDE_SPIRIT

The spirit is a moving anchor.

Goals:

- close escort;
- front screen;
- rear guard;
- route clearing;
- moving interposition;
- regroup when the formation stretches;
- spirit movement published through the same structured result contract, even if resolved at round end.

Two spirit models remain distinct:

- non-joining objective spirit: authored objective-phase movement and pace;
- joined spirit: normal allied NPC activation.

The shared model does not automatically increase the non-joining spirit from its authored one-cell round-end pace to the v1 2–6-unit combat envelope. Changing that pace requires an explicit mode decision.

---

## 14. Enemy Movement Grammar

Enemies use the same physical rules and route planner but a simpler decision model.

Enemy identity priority:

1. objective pressure;
2. battlefield role;
3. Realm skin and distortion flavor.

| Pressure role | Movement grammar |
|---|---|
| Blocker | Occupy chokepoints, lanes, exits, and objective approaches |
| Hunter | Pursue isolated, wounded, fleeing, or designated subjects |
| Breaker | Rush anchors, structures, carriers, and formations |
| Watcher | Maintain range, observe crossings, and punish exposed routes |
| Swarm | Surround exposed subjects and exploit congestion |
| Ritualist | Reach or maintain charged zones and objective thresholds |

Players should be able to identify the broad role through movement before reading an internal role tag.

Enemies should be more predictable than Echoes because they do not need the full Echo identity stack.

### 14.1 Physical and information fairness

Equivalent physical profiles receive equivalent legal route options regardless of faction.

Enemies obey:

- the same terrain and edge costs;
- the same occupancy and congestion;
- the same relationship-aware hostile-control cost;
- the same capacity envelope for equivalent profiles;
- the same per-cell hazard timing;
- the same physical route bounds;
- the same move/action restrictions;
- the same Rush or Withdraw consequences when using those expressions;
- the same ordered result contract.

Enemy simplicity must not grant hidden physical advantages.

Friendly and neutral adjacency never taxes enemy movement either. Relationship fairness is symmetric: only an active opposing or antagonistic actor creates control for the mover.

Any exception such as flight, phasing, burrowing, hazard immunity, objective teleport, or unusual capacity must exist as an explicit capability/status and be visible enough for the player to learn.

Enemies plan from their declared knowledge scope. They do not read concealed stage information, hidden player routes, or hazards their role is not permitted to know.

### 14.2 NPC, spirit, and allied movement

NPCs share physical execution but use authored role/state authorities rather than fabricated Calling, vector, bond, Standing, or maturity data.

| NPC role | Movement grammar |
|---|---|
| Witness | Preserve a useful observation position or seek safety |
| Guide | Maintain a readable route relationship and lead toward known passage or objective information |
| Charge | Seek safety and remain within protection reach |
| Claimant | Approach, contest, or hold claim-relevant ground |
| Temporary Ally | Use a simple allied combat role and current survival state |
| Joined Spirit | Use an allied escort/support/combat role |
| Non-joining Spirit | Follow authored GUIDE_SPIRIT objective-phase movement |

NPC rules:

- use the same terrain costs, occupancy, hazards, capacity, and event sequencing;
- use only fields they actually own;
- do not receive Echo-only ping responses unless canon explicitly makes them eligible;
- use authored fear, morale, disposition, objective, and survival state where present;
- explain movement through role and current need, not invented Echo-like inner identity.

Structures have zero normal capacity and move only through an authored objective rule.

Current stage enemies and NPCs are situations or contacts, not independently moving actors.

If roaming stage actors are added later:

- they use party/group-scale tokens and a stage-specific role/perception adapter;
- they do not run individual combat movement inside party traversal;
- hostile group-token adjacency uses the same relationship-aware engagement rule;
- friendly and neutral group-token adjacency adds no movement penalty;
- an escorted NPC normally joins the party profile as an anchor or burden rather than becoming a second stage token;
- a separate moving token requires explicit promotion and interaction rules.

---

## 15. Terrain, Elevation, and Movement Capabilities

### 15.1 Foundation terrain

Current production terrain is binary walkable topology.

The first movement implementation may support:

- walkable versus blocked cells;
- terrain movement cost;
- hazards;
- route tags;
- congestion;
- objective and formation regions.

Stage Situations such as obstacle, omen, contact, or structure remain stage nodes/events. They are not automatically converted into generic per-cell terrain hazards.

Terrain hazards are cell/edge effects resolved by the shared movement executor.

### 15.2 Diagonal movement

Current production uses eight-direction movement with one-cost diagonals.

Before richer blocking geometry ships, implementation must explicitly decide whether a diagonal may pass between two blocked orthogonal neighbors.

Recommended direction:

- forbid implicit corner cutting for solid raised obstacles;
- represent unusual diagonal passage as an authored edge/capability;
- use the same edge rule for party, Echo, enemy, and NPC movement.

### 15.3 Required additive terrain data

Higher ground, climbing, jumping, dropping, and true vantage require additive metadata such as:

```gdscript
{
  "cells": {
    "col,row": {
      "terrain_type": String,
      "height": int,
      "movement_cost": int,
      "tags": Array[String]
    }
  },
  "edges": {
    "from>to": {
      "edge_type": String,             # walk | climb | drop | jump | vault
      "cost": int,
      "required_capabilities": Array[String],
      "risk_tags": Array[String]
    }
  }
}
```

### 15.4 Capability-gated vocabulary

The design may reserve:

- climb;
- jump down;
- vault;
- leap;
- slip;
- dodge;
- back attack;
- vantage.

These words must not appear in player-facing output until the supporting mechanics exist.

Specific requirements:

- **Higher ground** requires height and an actual tactical benefit.
- **Flanking** requires a mechanically defined relationship between attacker, target, allies, or facing.
- **Backstab** requires facing, awareness, concealment, or another explicit rear-attack contract.
- **Dodge** requires a reaction or interrupt timing contract.

Until then, use truthful phrases such as:

- `circles toward a better angle`;
- `moves around the enemy line`;
- `finds a safer approach`;
- `moves to cut off the route`.

---

## 16. Equipment Seam

The equipment model remains light and expressive.

Equipment changes options and tradeoffs; it does not replace identity.

### 16.1 Weapon

May affect:

- desired engagement range;
- movement-action combinations;
- engagement and approach profile;
- reach;
- whether repositioning is valuable.

Calling fit remains soft.

Desired-range precedence:

1. current action or skill requirement;
2. equipped weapon profile;
3. actor baseline.

Before `V2-ITEM-003`, movement uses a neutral equipment profile and must not invent implicit gear modifiers.

### 16.2 Armor / clothes

May affect:

- burden;
- difficult-terrain cost;
- rush exposure;
- forced-movement resistance;
- holding and bracing;
- survival after overcommitment.

Heavy equipment must provide a clear advantage. If it only reduces mobility, it becomes universally undesirable.

### 16.3 Charm

May affect:

- fear stability;
- exposure interpretation;
- route-reading confidence;
- small terrain or omen exceptions;
- commitment under identity strain only when the explicit item effect is surfaced and does not silently erase Calling, vow contradiction, or refusal rules.

### 16.4 Relic / consumable

May provide:

- rare route exceptions;
- one-use escape or reposition;
- temporary terrain capability;
- objective interaction;
- movement protection or sacrifice.

### 16.5 Recommended internal equipment language

Avoid kilograms and a large visible encumbrance calculation.

Potential internal bands:

- light;
- standard;
- heavy;
- burdened;
- objective carrier.

Potential preparation language:

- `Light: easier to reposition.`
- `Heavy: slower through difficult ground, steadier when holding.`
- `Long reach: prefers to keep one step of distance.`
- `Concealable: supports concealment routes.` **DEFERRED until concealment exists.**

Exact range, reach, weight, and equipment numbers belong to `V2-ITEM-003`.

---

## 17. Progression and Movement Unlocks

**V1 DIRECTION / DEFERRED capability map**

Progression should create new movement decisions.

### Standing, Calling, and movement growth

Movement cost belongs to the board and current relationships. It does not increase because an Echo gains Standing.

Movement growth can improve five different things:

1. **Capacity:** more movement-cost units in a fitting context.
2. **Efficiency:** reduce a named terrain, burden, or hostile-control cost.
3. **Capability:** unlock a new edge or movement verb.
4. **Control:** make a position exert stronger protection, interception, or route denial.
5. **Action economy:** combine a fitting movement with an action, reaction, or preparation.

Standing `3 / 6 / 9` gates core technique, deepening, and culmination. The Calling and chosen skill expression determine which form of movement growth appears.

Most Echoes should receive at least one persistent ordinary-capacity increase between their foundational state and high Standing.

**Starting progression candidate:** reach ordinary capacity `3` by Standing `6`, unless an explicit Calling or condition deliberately converts that growth into equivalent spatial power.

The v1 direction requires persistent growth. Standing `6` is the starting tuning target rather than an immutable milestone. It should be tested against board size, encounter duration, Calling differentiation, and the Standing progression pace.

Proposed long-term curve:

| Development state | Expected capacity expression |
|---|---|
| Foundational / Uncalled | `2`, or `3` from an unusually mobile physical profile |
| Standing 3 core technique | Usually `2–3`; mobility-oriented techniques may establish reliable `3–4` movement |
| Standing 6 deepening | Usually `3–4`; movement-oriented Calling paths may reach `5` |
| Standing 9 culmination | Usually `4`; explicit mobility culminations or signature techniques may reach `5–6` |

This is not a guaranteed flat increase at every milestone.

- a Calling may unlock capacity earlier but only under a fitting movement intent;
- another Calling may receive ordinary growth later while first gaining control, reaction movement, or cost efficiency;
- capacity `5–6` always requires an explicit developed source;
- agility at birth cannot by itself assign permanent access to the top capacity bands;
- temporary signature movement may reach `6` without making `6` the Echo's permanent ordinary capacity.

Proposed expression by Calling:

| Calling | Likely movement growth |
|---|---|
| Okofor | Interposition, protection reach, control projection, and reduced engagement cost when moving to protect |
| Aduro | Rush reach, momentum, breakthrough, and situational capacity while committing into danger |
| Onyamesu | Cohesive regrouping, burden sharing, escort stability, and movement that preserves communal reach |
| Okomfo | Threshold repositioning, objective access, hazard interpretation, and ritual movement capabilities |
| Kra-Soro | Higher general route capacity, difficult-ground efficiency, pursuit, cutoff, and field adaptation |
| Sum-Okwanfo | Lateral route efficiency, slipping control under explicit conditions, unseen approach, and surgical repositioning |

These are movement-growth directions, not automatic passive bonuses.

Examples:

- a high-Standing Kra-Soro may normally operate at `4–5` capacity and reach `6` through a fitting culmination or signature Path technique;
- a high-Standing Aduro may operate at `3–4` normal capacity but gain temporary capacity or engagement-cost relief while using a committed breakthrough;
- a high-Standing Okofor may operate at `3` ordinary capacity while much stronger interposition, protection control, or reaction movement carries the rest of their spatial power;
- a high-Standing Sum-Okwanfo may operate at `4–5`, spending less to cross specifically supported controlled or concealed routes rather than simply outrunning the Kra-Soro in open ground;
- a high-Standing Onyamesu may operate at `3–4` while moving the party or burdened allies more efficiently;
- a high-Standing Okomfo may operate at `4` while gaining meaningful threshold or objective repositioning rather than specializing in maximum running distance.

The question at each milestone is not only:

> How many more tiles can this Echo move?

It is:

> What new spatial decision can this Echo now make because of who they have become?

### Ward

- interpose;
- brace;
- ally reposition;
- threat draw;
- wider protection region.

### Break

- engage leap;
- momentum;
- forced movement;
- opening punish;
- rush recovery.

### Veil

- slip path;
- concealment route;
- vanish;
- decoy movement;
- surgical approach.

### Path

- pursuit;
- angle exploitation;
- difficult-route efficiency;
- route denial;
- cutoff;
- field reading.

### Rite

- objective ward;
- threshold control;
- hazard or danger revelation;
- charged-ground interpretation.

### Root

- regroup;
- rally;
- burden sharing;
- cohesion movement;
- stabilizing escort.

Standing milestones should unlock or deepen these expressions.

Standing should not automatically add one movement cell at every milestone.

Skill families determine where movement techniques belong. Individual skills unlock capabilities through their own progression contracts.

Standing:

- gates access and deepening;
- is expected to produce at least one persistent capacity increase across normal development for most Echoes;
- may unlock techniques that grant fitting capacity, efficiency, control, or movement-action combinations;
- does not independently grant universal leap, vanish, route denial, forced movement, or climb;
- capacity beyond the expected development increase requires an explicit physical, Calling, skill, equipment, or status source;
- does not automatically grant every technique listed in this section.

---

## 18. Player-Facing Explanation

### 18.1 Explanation hierarchy

1. brief pre-movement intent label or glyph;
2. visible spatial subject, anchor, region, or route;
3. ordered movement animation;
4. result text;
5. primary reason at the cadence required below;
6. optional bark for high-signal emotional expression.

When hostile control materially shortens or redirects movement, presentation should make the contested relationship visible through at least two restrained signals:

- path preview/animation bends around or slows at the controlled edge;
- the controlling actor or contested edge receives a brief highlight;
- result text names the block, screen, engagement, or detour;
- an engagement/contested icon appears without showing numeric movement cost.

The player should understand that another actor constrained the route without needing to see `+1 movement cost`.

Reason cadence:

- routine autonomous movement: intent before movement; reason available on demand;
- `Interpret`, `Hesitate`, `Object`, or `Refuse`: response and primary reason immediately before movement;
- bond rescue, vow contradiction, and objective-critical override: brief reason before or with the plan change.

### 18.2 Player-facing intent families

The internal intent vocabulary maps to a smaller stable icon/visual family:

| Visual family | Internal examples |
|---|---|
| Advance | advance, pursue, escort |
| Engage | engage, cut off |
| Protect | protect, intercept, carry |
| Hold | hold, regroup |
| Reposition | reposition, withdraw |
| Read | read, stage reconnoitre, seek signs |

Context text retains the more precise internal meaning.

### 18.3 System explanation versus bark

The structured result is authoritative.

A bark is:

- character voice;
- emotion;
- interpretation;
- reaction;
- emphasis.

A bark is not:

- the only reason available;
- guaranteed to explain routine pathing;
- allowed to contradict the actual decision trace.

Use barks for:

- guidance response;
- fear spike;
- bond rescue;
- vow conflict;
- objective emergency;
- signature movement skill;
- major overcommitment;
- major refusal or reinterpretation.

### 18.4 Explanation grammar

Base:

```text
[Echo] [movement expression] [purpose].
```

Optional causal clause:

```text
[Primary reason] shapes the decision.
```

Examples:

- `Ama rushes to break the enemy line, committing beyond the safer position.`
- `Kojo hangs back to observe the hunter's approach.`
- `Esi moves between the totem and its attacker, refusing to leave it exposed.`
- `Yaw circles around the blocker, looking for an opening.`
- `Abena returns to Kojo after their bond pulls her away from the objective.`
- `Kofi takes the lower-exposure route after fear makes the open ground feel too dangerous.`
- `The party presses toward the omen despite the exposed crossing.`
- `Ama slows the group to preserve a safe route home.`

Capability-gated future examples:

- `Esi climbs to higher ground to watch the eastern approach.`
- `Yaw slips behind the distracted hunter and strikes from its blind side.`

These may only be emitted when elevation, awareness, and attack rules validate them.

### 18.5 Cadence

Routine movement should be understandable visually without a sentence every activation.

Full prose is reserved for:

- a changed plan;
- objective-critical movement;
- identity contradiction;
- guidance response;
- major bond intervention;
- rush/withdrawal with meaningful risk;
- signature movement technique.

---

## 19. Five-Component Evaluation

| Component | Requirement |
|---|---|
| Clarity | A new observer identifies immediate movement purpose in at least 8/10 sampled movements |
| Motivation | Movement changes objective safety, survival, intel, positioning, or attachment stakes |
| Response | Preparation, Directive, guidance, equipment, and party composition create visible movement differences |
| Satisfaction | Strong movement outcomes use spatial animation plus text/icon/audio feedback |
| Fit | Movement reads as autonomous judgment in a mythic character-driven strategy game, not player-issued unit orders |

Causal truthfulness and basic clarity are acceptance gates.

Among designs that pass those gates, prioritize:

1. Response;
2. Fit;
3. Satisfaction;
4. Motivation tuning.

---

## 20. Determinism and Persistence

### 20.1 Determinism

Same:

- seed;
- board;
- mover state;
- party state;
- Directive;
- objective state;
- equipment;
- guidance;
- movement history;
- declared perception state;

must produce the same:

- goals;
- route options;
- selected intent;
- ordered path;
- interruptions;
- explanation;
- final result.

Deterministic route diversity should use stable inputs such as:

- actor ID;
- encounter/stage seed;
- goal ID;
- route style;
- movement history.

No global randomness or OS time.

Relocating hidden stage content outside the mover's known cells must not change the selected plan.

### 20.2 Atomicity

One combat activation or one stage Advance is one atomic simulation result.

The UI may animate each cell, but cannot mutate or re-decide the plan during presentation.

### 20.3 Save and re-entry

Persistent movement state must be additive and explicit.

Potential persisted stage fields:

- party position;
- excursion ID/state;
- explored cells;
- revealed information;
- selected or last goal;
- minimal route history only where required for deterministic continuation or anti-oscillation;
- movement interruption state.

Do not persist:

- unspent capacity;
- unspent commitment;
- transient candidate options;
- full debug score decompositions;
- presentation animation progress.

Combat movement state remains in the encounter context and structured snapshots unless a combat-save story requires deeper persistence.

---

## 21. Principal Risks and Safeguards

| Risk | Safeguard |
|---|---|
| Speed controls initiative and mobility | Keep speed contribution to capacity small; agility and explicit mobility do more |
| Rush dominates | Exposure, limited follow-up, forced commitment, stronger enemy attention |
| Multi-step movement trivializes boards | Capacity cap, terrain cost, role regions, larger boards only when justified |
| Capacity 5–6 skips late-game objectives | Require explicit developed sources, test spawn-to-objective reach, and scale later boards/terrain with the progression curve |
| Hostile control makes melee inescapable | One tax per edge rather than per hostile, no automatic reaction attack, explicit withdrawal/disengage options |
| Hostile control slows combat back to ten-round approaches | Apply the tax only near active hostiles; tune against contact and objective-round targets |
| Friendly formations punish movement | Friendly and neutral adjacency never adds engagement cost |
| Every actor still takes the same route | Multiple goal regions, congestion, desired range, route styles, identity scoring |
| Route diversity becomes random wandering | Near-optimal route bound and causal route preferences |
| Careful Echoes look inactive | Careful stops must produce observe, guard, range, cohesion, or return-safety value |
| Calling becomes stereotype | Calling is one layer; situation, bonds, emotion, traits, equipment, and objective still matter |
| Objective pressure creates robots | Allow surfaced competing pressures and role variation |
| Bonds constantly ruin objectives | Rescue overrides are high-signal and bounded |
| Higher Standing becomes better AI | Standing improves coherence and self-expression, not universal optimality |
| Gear replaces identity | Gear changes capabilities and action profile; Calling fit stays soft |
| Heavy gear is always bad | Pair mobility cost with holding, defense, reach, or forced-movement benefits |
| Ranged kiting dominates | Desired-range rules, interception, terrain, pressure roles, and movement-action limits |
| Long paths become unreadable | Presentation speed, per-tile timing, path emphasis, total animation clamp |
| Prose explains the wrong reason | Primary reason derived from the actual winning trace |
| Explanation spam | Tiered cadence; visual evidence handles routine movement |
| Stage party controlled by slowest member | Party profile uses roles, burden, and bounded readiness rather than a single minimum |
| Permadeath volatility rises | Rush and exposure telegraphed before consequence; objective urgency remains legible |

---

## 22. Validation

### 22.1 Core deterministic tests

- same input produces identical goals, options, intent, path, explanation, and result;
- every entered cell and edge is legal;
- path cost does not exceed commitment or capacity;
- hostile-controlled edges add the declared cost exactly once regardless of adjacent-hostile count;
- friendly and neutral adjacency adds no movement cost;
- dead, KO, removed, and explicitly non-controlling actors project no control;
- hidden hostility cannot alter planning before perception or contact;
- movement stops when the tactical goal is reached;
- no actor enters void or shares a living actor's cell;
- local congestion produces a legal detour or named stop;
- mirrored boards do not create arbitrary row/column bias;
- repeated-cell and immediate-backtrack penalties work;
- equipment and burden modify only declared fields;
- unsupported capability language cannot be emitted;
- path excludes the start cell and preserves every voluntary/forced destination in order;
- diagonal corner legality is identical across mover kinds;
- candidate shortlists remain within deterministic computation caps;
- identical physical profiles and goals generate identical legal options regardless of Echo, enemy, or NPC faction;
- only the declared decision adapter changes selection;
- hidden information outside perception cannot alter goals, routes, or explanation;
- player-safe snapshots contain no raw weights or debug trace.

### 22.2 Identity tests

- contrasting Echo profiles select different viable routes or endpoints on the same board;
- every selected route still makes defensible objective or survival progress;
- cautious Echoes avoid hostile control when a defensible alternative exists;
- aggressive or protective Echoes enter hostile control when engagement or screening pressure justifies it;
- Directive changes willingness to engage without removing the shared physical cost;
- changing fear, morale, bond emergency, or objective urgency changes movement with a matching reason;
- Anchor, Edge, and Sight are distinguishable without becoming deterministic;
- removing the surfaced primary factor changes the selected option, style, or commitment in counterfactual tests;
- higher Standing produces more coherent explanation, not automatic compliance.
- most developed/high-Standing Echoes reach at least `3` ordinary capacity;
- advanced/high-Standing Echoes ordinarily express around `4` capacity or an explicitly equivalent spatial advantage;
- a high-Standing Echo remaining below the expected band has an explicit, testable compensating spatial advantage or current penalty;
- movement-oriented Calling development can reach `5–6` without making every Calling equally fast.

### 22.3 Stage tests

- Scout Carefully chooses lower-exposure routes where viable;
- Scout may stop before maximum commitment for visible information or safety value;
- Seek Signs accepts greater exposure for meaningful evidence;
- discovered optional situations can actually alter destination;
- known danger can be avoided where topology permits;
- frontier selection is orientation-neutral and continuity-aware;
- situations interrupt movement immediately;
- same-excursion re-entry preserves position;
- new excursion resets position but preserves terrain and intel;
- every surfaced Calling movement action dispatches and changes state;
- named contributor text matches an actual decisive contributor;
- no Echo is named when Directive, objective, terrain, or party baseline was decisive;
- stage contact stops for player reassessment and is never auto-engaged;
- frontier chaining continues only under unchanged search intent;
- decision-critical discovery stops the Advance;
- withdrawal uses return/exit safety consistently and preserves learned intel;
- EncounterApproach payload is deterministic, truthful, and creates a visible combat difference;
- moving hidden content outside known cells does not change the plan;
- the stage is understandable without raw step diamonds.

### 22.4 Combat tests

- initiative remains fixed;
- multi-step movement resolves as one atomic activation;
- move then attack resolves in order;
- rush consequence applies before later actors respond;
- retreat, withdraw, interpose, protect, and carry physically move;
- a screen or blocker measurably increases an opposing route's cost or forces a detour;
- entering, circling within, and leaving hostile adjacency reduce effective reach;
- multiple adjacent hostiles do not stack the physical movement tax beyond once per edge;
- forced movement ignores voluntary engagement cost, but resumed voluntary movement does not;
- structures remain non-movers unless explicitly authored;
- per-cell hazards resolve in contract order;
- movement result path survives snapshot projection unchanged;
- no actor has more than two consecutive pure-movement activations without tactical progress unless the mode explicitly requires it;
- invalid post-movement actions use only the declared bounded fallback;
- enemy and NPC capability exceptions are explicit in result data;
- equivalent Echo/enemy/NPC profiles obey equivalent cost, hazard, occupancy, Rush, and action-economy rules;
- NPCs cannot consume Echo-only identity fields or ping-response states without explicit eligibility;
- reinforcements append without re-sorting initiative;
- universal kill-all remains valid in every mode;
- every round-end objective counter retains authored timing.

### 22.5 Mode tests

- RECOVER holder reaches and holds the relic while other Echoes screen;
- enemies cannot attack or damage the RECOVER relic;
- PROTECT produces distinct anchor, interceptor, and carrier behavior;
- PROTECT custody preserves carrier movement, burden, hazards, theft, recovery, and drop order;
- PURIFY produces purifier access and perimeter defense;
- hidden PURIFY shrine knowledge follows declared perception rules;
- ENDURE does not universally chase distant enemies;
- PURSUE produces distinct cutoff destinations;
- PURSUE escape, containment, capacity, and far-end timing remain fair after mobility changes;
- GUIDE roles remain with or ahead/behind the moving spirit;
- non-joining spirit preserves authored objective-phase pace and obeys terrain, occupancy, and hazards;
- joined spirit follows allied NPC movement;
- enemy pressure roles choose objective-consistent regions.

### 22.6 Pacing targets

Starting validation targets:

- meaningful contact or objective pressure by rounds 2–3;
- standard COMBAT median around 5–7 rounds;
- longer objective modes justify their extra rounds through changing pressure;
- no movement style dominates all seven modes;
- ordered multi-cell movement remains readable at Slow, Normal, and Fast;
- at Normal speed, a typical movement presentation should not dominate the full activation;
- the promoted prototype's `180 ms per tile` is the initial presentation reference, subject to total-duration clamping and playtest.

Stage pacing measurements:

- Advances to first meaningful new information;
- Advances to first objective reveal or contact;
- percentage of Advances producing discovery, route change, or purposeful stop;
- useful no-battle scout-and-return length;
- repeated frontier-sweep Advances before player reassessment.

The stage model should not replace ten-round combat drift with ten-click exploration drift.

### 22.7 Player tests

#### New observer

Watch ten movements without opening debug information.

Pass:

- immediate purpose identified correctly at least 8/10 times;
- major reason identified correctly at least 8/10 times when surfaced;
- the observer identifies which hostile actor constrained or redirected movement at least 8/10 times;
- friendly or neutral adjacency is not misread as hostile control;
- objective progress or interruption understood.

#### Stress

Test:

- crowded chokepoints;
- multiple bonds under threat;
- high fear;
- heavy equipment;
- carried objective;
- hazards;
- long routes;
- reinforcements;
- contradictory guidance.

Pass:

- no softlock;
- no impossible route claim;
- no unexplained oscillation;
- no misleading text.

#### Abuse

Attempt:

- universal rush;
- ranged kiting;
- spawn camping in ENDURE;
- mobility stacking;
- heavy-gear avoidance;
- bond rescue exploitation;
- repeated route cycling;
- objective bypass.

Pass:

- the exploit is impossible, costly, situational, or not dominant.

---

## 23. Implementation Boundaries

### Shared

- terrain and edge legality;
- cost calculation;
- capability validation;
- route generation;
- route metrics;
- deterministic route diversity;
- ordered plan execution;
- movement events;
- explanation/result shape.

### Stage-specific

- party aggregation;
- optional contributor selection;
- Directive commitment;
- fog and intel;
- frontier and situation targeting;
- encounter avoidance/contact;
- withdrawal and return;
- excursion persistence.

### Combat-specific

- initiative;
- individual occupancy;
- desired range;
- threat and control regions;
- objective roles;
- attack and movement chaining;
- custody;
- combat hazards;
- enemy pressure roles.

### Enemy and NPC adapters

- enemy objective-pressure and battlefield-role authority;
- NPC/spirit/temporary-ally authored role authority;
- declared knowledge scopes;
- equivalent physical fairness;
- explicit capability exceptions;
- future roaming stage group-token authority.

### Identity authority

The existing behavior authority remains the single place where combat identity pressures resolve.

The stage party authority aggregates existing actor state and the same semantic pressure vocabulary into one party decision. It must not invent a separate hidden personality model or run independent secret turns for each Echo.

The Movement Model must not create:

- a separate obedience score;
- a separate movement personality;
- a separate objective AI that silently overrides identity;
- a presentation reason disconnected from arbitration.

---

## 24. Recommended Delivery Sequence

These are planning slices under existing canonical stories, not new canonical story IDs.

### Slice A — correctness and contract

Home: `V2-COMBAT-002` plus relevant stage fixes.

- objective movement goals and regions;
- RECOVER relic safety;
- terrain-aware target distance;
- traversal preference threshold;
- frontier bias;
- Pursue exit consistency;
- canonical Calling lookup;
- shared Movement Profile / Goal / Option / Intent / Result contract.

### Slice B — multi-step movement foundation

Home: `V2-COMBAT-002`.

- bounded capacity and commitment;
- route options;
- ordered path execution;
- movement plus primary action;
- congestion and history;
- real retreat/interpose/protect/carry movement;
- stage adapter using the shared route/result contract.

### Slice C — reason-bearing arbitration

Home: `V2-COMBAT-003`.

- decision trace;
- causal primary reason;
- objective, identity, emotion, bond, vow, hazard, Directive, and guidance collision;
- structured logs and snapshots.

### Slice D — profile-sensitive Directives

Home: `V2-DIRECTIVE-002`.

- Scout Carefully and Seek Signs produce different route/commitment expression across Echo profiles;
- stage and combat use the same semantic movement vocabulary.

### Slice E — equipment

Home: `V2-ITEM-003`.

- desired range;
- weapon approach profile;
- light/standard/heavy burden;
- armor tradeoffs;
- charms and relic exceptions.

### Slice F — tactical guidance and presentation

Home: `V2-COMBAT-004`.

- spatial pings influence existing movement goals and options;
- response appears before movement;
- ordered path and purpose become visible evidence;
- movement review explains consequence without exposing weights.

### Later capability slices

- elevation;
- climbing;
- drops and jumps;
- facing;
- true flanking/back attacks;
- dodge/reaction timing;
- broader equipment and terrain families.

---

## 25. Explicit Decisions and Open Questions

### V1 approved decisions

These define the approved v1 movement implementation direction. Numeric starting values remain subject to the tuning and validation rules in this document.

- movement capacity is internal and replenishes per activation/Advance;
- capacity is expected to grow persistently during normal Echo development;
- movement commitment is selected behaviorally and may be lower than capacity;
- hostile adjacency creates relationship-aware movement friction, while friendly and neutral adjacency does not;
- normal combat movement may be followed by one primary action;
- unrestricted move–attack–move is not part of the first implementation;
- foundational combat capacity usually begins at `2`, developed Echoes ordinarily reach `3–4`, movement-oriented expressions may reach `5`, and culmination/signature movement may reach the v1 starting `6`-unit cap;
- route distance is a baseline cost, not the sole route-selection rule;
- route options use tactical regions rather than one compulsory cell;
- implemented vector/identity direction primarily affects motive and commitment, not raw movement units;
- Callings and skill families primarily unlock movement verbs and route capability;
- Standing improves coherence and expression, not obedience or unbounded speed;
- equipment changes burden, range, and options without replacing identity;
- player-facing explanations show intent and causal reason, not spent points;
- barks remain emotional expression rather than authoritative system explanation;
- stage and combat share spatial contracts, not decision policy.

### Open implementation, tuning, and GDD-integration questions

- exact capacity formula and stat thresholds;
- exact milestone for the expected persistent increase to `3`; Standing `6` is the starting candidate;
- exact ordinary-capacity expectation at Standing `3 / 6 / 9`;
- exact unlock contracts for capacity `5` and `6`;
- exact compensating spatial-power requirement for a high-Standing Echo that remains below its expected capacity band;
- exact hostile-engagement cost after testing the +1-per-edge starting value;
- exact statuses and capabilities that suppress, ignore, or project hostile control;
- exact party capacity aggregation and contributor selection;
- exact contribution of speed to mobility;
- exact rush exposure and action restriction;
- exact desired-range bands;
- exact equipment burden rules;
- whether unspent combat capacity can later enable reactions;
- precise reason-collision ordering under multiple decisive pressures;
- bond rescue override frequency;
- movement verb unlocks at Standing 3/6/9;
- exact party disagreement/cohesion resolution;
- exact knowledge scopes for each enemy and NPC role;
- exact diagonal corner rule before solid edge geometry ships;
- exact stage withdrawal relationship between physical exit travel and escape resolution;
- exact stage-to-combat EncounterApproach effects;
- enemy role distributions by Realm;
- elevation generation and tactical effects;
- facing, awareness, flanking, and back-attack rules;
- dodge and reaction timing;
- final player-facing cadence for routine movement explanations;
- whether stage movement reasons remain transient or enter a persistent journey history.

---

## 26. Success Definition

The Movement Model succeeds when:

- movement makes objectives more legible rather than less;
- combat spends fewer rounds on empty approach;
- Echoes use different viable routes for understandable reasons;
- stage travel expresses Directive, risk, identity, and information seeking;
- exploration remains one party movement plan while combat remains individual-actor movement;
- enemies and NPCs obey fair shared physical rules through simpler role-appropriate authorities;
- movement options grow through Callings, skills, and light equipment without becoming a visible point-management game;
- players recognize who is rash, protective, cautious, opportunistic, devoted, or afraid from what they do in space;
- the player can say what an Echo was trying to do and why, even when the decision was costly;
- deterministic autonomy produces attachment and learning rather than unexplained drift.

---

## 27. Version History

| Version | Date | Status | Summary |
|---|---|---|---|
| 1.0 | 2026-07-16 | Final | Approved shared movement model for party exploration, individual combat actors, hostile spatial control, progression, counterparts, explanation, and implementation planning |

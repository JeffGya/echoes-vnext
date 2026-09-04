# Gate 3 contract — New arrivals change the village

Gate 3 completes the approved Slice 2 summoning gate and applies the repository-wide
visual-first communication rule. Everything remains prototype-local and in memory.
Production saves, startup, economy, Echo generation, and later systems remain closed.

## Experience target

Adding an Echo must feel like a person entering an inhabited village. The player sees
the circle prepare, witnesses react, a returned person emerge, the Keeper welcome
them, and the newcomer choose where to go. Population change must be visible beyond a
roster count.

## Population and authored arrivals

- Keep the starting six and add three distinct authored newcomers, maximum nine.
- Consume newcomers once each in a deterministic seed-derived order.
- Every one of the nine Echoes receives a distinct mock portrait/bust aligned with
  their markings, palette, personality, and emotional presentation.
- Portraits support reaction and result surfaces. World tokens remain the spatial
  source of truth and never disappear during an embodied beat.
- Newcomers begin without bonds, encounters, or impressions.

## Summoning state and economy

- Start with 60 Ase, cap at 120, recover 60 per completed village day.
- One grade, one cost: 60 Ase. Payment and arrival creation are one atomic operation.
- The Flame visibly communicates unavailable, ready, committing, and recovering
  states before text is opened.
- Cancellation before commitment spends nothing. Repeated commitment cannot spend or
  create twice. Another summon is unavailable until the current arrival completes.
- Reset restores six Echoes, initial Ase, seeded order, and no pending arrival.

## Place-first arrival grammar

Use the spec's signature order:

`signal -> focus -> approach -> gather -> prepare -> perform -> interpret -> aftermath -> release`

1. Select the visible Flame/circle and read charge, cost, and witness availability in
   the world plus a compact confirmation.
2. Commit once. Protect the circle with the shared camera rule; nonessential chrome
   recedes without pausing village simulation.
3. Existing Echoes approach, watch, turn away, or keep distance from actual identity,
   emotion, needs, commitments, and reachability.
4. Build Flame light and circle marks, then manifest the newcomer in-world before any
   profile dominates.
5. Reveal name, portrait, archetype, plain emotional state, and two fragmentary
   tendencies through a participant-first reaction composition.
6. Require one untimed welcome choice while the newcomer remains at the circle.
   Choices signal likely direction visually and in a short cue without raw values or
   guaranteed outcomes. Other Echoes and simulation time continue.
7. Resolve the welcome once, show the newcomer's visible reaction, then let them choose
   an initial person, place, or withdrawal route from actual preferences and context.
8. Record manifestation, welcome, witness reactions, first intention, and arrival at
   the destination as one folded first-arrival memory with structured causes.

## Visual information contract

For summoning and the existing incident result surface:

- Lead with people: busts, names, markings, expression/pose, and spatial relationship.
- Show relationship direction with line/shape/color plus an accessible label.
- Show emotion and need direction through icons, posture, and bounded visual states;
  no raw numbers outside the Lab.
- Show next behavior as a destination/place emblem and route or action cue.
- Show eased versus unresolved causes through a distinct closed/open visual state.
- Keep plain-language sentences subordinate and optional detail scrollable.
- Important outcomes use at least two channels: world behavior plus portrait, spatial
  cue, VFX, sound-ready presentation data, or persistent world change.
- Portraits cannot cover the active circle, participants, paths, or witness reactions.
- Reduced motion keeps causal order using cuts, fades, light states, orientation, and
  portrait changes.

The incident result becomes participant-first during Gate 3: two busts, a central
relationship/outcome axis, visual emotional changes, next-place cues, and a clear
eased/unresolved cause emblem. Preserve its non-pausing behavior.

## Simulation and interface

- Extend the existing authoritative `RefCounted`; do not add economy, summon, memory,
  or incident services.
- Add Ase, recovery accounting, newcomer order/consumption, arrival stage, witness
  responses, required welcome, and first destination.
- Fixed 250 ms steps and stable resolution order remain unchanged.
- Commands cover confirmation, commitment, welcome, and legal cancellation/dismissal.
  Results resolve once and snapshots remain independent copies.
- UI emits `action_requested(action)` and renders structured outcomes; it cannot infer
  witness or newcomer reactions from text.
- A pending incident result prevents starting a summon; an arrival prevents joining
  another Keeper interaction.

## Verification and stop gate

- Same seed, setup, steps, tuning, and commands reproduce newcomer order, witnesses,
  welcome outcome, first route, and history.
- Payment, capacity, recovery, cancellation, repeated clicks, stale replies, reset,
  and required welcome are idempotent.
- Background life continues during confirmation, reveal, and welcome; only explicitly
  reserved arrival participants wait.
- Every arrival route is reachable for every placement combination.
- Newcomers have empty social state before actual encounters.
- Portraits exist for all nine and remain distinguishable without relying only on
  color. Layouts pass 1920×1080 first, then 1600×900, 1280×720, and 960×540, including
  nine-Echo crowding and reduced motion.
- A three-second glance identifies the newcomer, witness direction, welcome direction,
  next destination, and unresolved state without reading all prose.

Run backend, prototype integration, standalone smoke, and the full repository suite
under the 200-second watchdog. Then stop for Jeff's in-game Gate 3 test. Update
findings and run instructions; do not commit before signoff.

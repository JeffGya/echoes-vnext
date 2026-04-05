# Echoes vNext GDD V2 Context

**Status:** Companion context doc  
**Purpose:** Fast handoff and orientation doc for future AI conversations. This is the compact continuity layer for ongoing GDD V2 work. It should let a new chat continue design work without reconstructing decisions from prior conversation history.  
**Read next:** [Echoes vNext Working GDD.md](/Users/jeffreygyamfi/Sites/echoes-vnext/docs/Echoes%20vNext%20Working%20GDD.md)  
**Reference only:** [Legacy Never Dies Game Design Document.md](/Users/jeffreygyamfi/Sites/echoes-vnext/docs/Legacy%20Never%20Dies%20Game%20Design%20Document.md)

---

# 1. Core Concept & Vision

## Project status

- this is now the **final-stretch phase of Game Design Document V2**
- the original GDD remains reference material, not final authority
- the new working GDD is concept-first and should grow section by section
- do not restart the project from zero; steer the existing game and codebase

## High-level concept

**Echoes is a mythic house-and-trials strategy game where the Ase Keeper restores fractured Echoes, living fragments of stolen stories and returning names, and guides them through relationships, rituals, and dangerous Realm trials to reclaim lost memory from Anansi’s web. As Echoes recover stolen stories and live new ones, they become more coherent, forming deeper bonds, stronger wills, richer behaviors, and eventually ascending into myths in their own right.**

## Precise concept correction

Important correction to older framing:

- Echoes do not simply recover an original self
- wholeness is not pure restoration
- Echoes become whole through layered recomposition:
  - recovered past
  - new lived experience
  - social shaping
  - fear, morale, and distortion pressure

## Core experience goals

- **Stolen stories as backbone:** Anansi and story theft remain structural, not decorative.
- **Balanced house-and-trials structure:** Sanctum and Realms should feel close in importance across the full game.
- **Guidance over control:** the player influences, interprets, and mentors rather than directly commanding every action.
- **Relationships as progression:** Echo interplay is core to becoming whole, not flavor.
- **Myth as system:** Akan / Ghanaian / Ivorian grounding must shape mechanics and meaning, not just art direction or lore names.
- **Transformation, not purity:** Echoes should become more coherent, not simply “reset” into pristine originals.
- **Not life-sim first:** Sanctum life exists to build attachment, interpretation, and payoff for Realm stages.

## Player role and fantasy

The player is the **Ase Keeper**:

- caretaker of a living house of memory
- guide of incomplete Echoes
- interpreter of signs, relationships, and spiritual tension
- not a general
- not a passive observer

Primary player fantasy:

**I help incomplete beings recover and assemble who they are, then I trust what they have become when it matters most.**

## Genre direction

- Primary: mythic house-and-trials strategy game
- Combat structure: indirect-control tactical / autobattler-influenced stage resolution
- Social structure: relationship-driven Sanctum life with expressive, surprising interplay
- Meta structure: story recovery, Echo growth, Sanctum growth, and long-term mythic progression

Important non-goals:

- not life-sim first
- not pure autobattler first
- not pure lineage sim
- not watch-only AI theatre

## Emotional and narrative themes

- remembrance versus oblivion
- fractured identity versus coherent selfhood
- recovered inheritance versus newly lived experience
- fear, morale, and pressure as shaping forces
- communal memory and social becoming
- care, contradiction, sacrifice, and distortion
- cultural continuity worth carrying versus peace in forgetting

---

# 2. World, Lore & Player Role

## Setting backbone

The world remains anchored in:

- Nyamedua / the world-tree cosmology
- the Ase Flame
- Anansi’s web of stories
- Odo Agyanka as the force of erasure and silence
- the Ase Keeper as the force of restoration and meaning

These should remain central in GDD V2.

## Anansi’s role

Anansi is not background lore.

He is:

- keeper of stories
- manipulator of the web
- ally, tempter, and antagonist at once
- the force making this game possible and dangerous

He should remain structurally central:

- stolen stories exist because of the web
- recovery happens through the web
- uncertainty, bargains, irony, contradiction, and misleading fragments are part of his influence

Anansi should not be reduced to narrator or mascot. He is a system-shaping presence.

## The Echoes

Echoes are:

- returning names
- fragments of stolen stories
- incomplete selves at summon
- not blank slates

They arrive with some anchor of identity, but not enough coherence to be fully whole.

Their growth should not mean only:

- leveling up
- getting stronger
- filling a class slot

It should mean:

- recovering Threads from stolen stories
- learning through lived experience
- being shaped by bonds, duties, and conflict
- stabilizing or failing under fear and morale pressure
- claiming a clearer self

## The Sanctum

The Sanctum is not only a menu hub.

It is:

- a living house of memory
- a social and spiritual environment
- the place where Echoes become more person-like
- the place where hierarchy, institutions, rituals, and communal life can emerge

Current structure:

- Echo progression: becoming a person
- Sanctum progression: becoming a society
- Realm progression: recovering the stolen stories that feed both

This implies the Sanctum itself must have a meaningful social and cultural growth spine, not only buildings unlocked by generic resources.

## Cultural intent

The game should carry the emotional logic of reconnection with lost, stolen, distant, or fragmented story.

For diaspora players, this should connect to cultural return, distance, hybridity, and the tension between inherited identity and new formation.

For all players, it should still work as a story about:

- becoming through memory and experience
- carrying contradiction
- being shaped by community
- deciding what deserves to endure

## Current wholeness direction

Wholeness is understood as layered recomposition rather than pure restoration.

The six current layers are:

1. Returned Name
2. Recovered Story
3. Shaped Direction
4. Living Bonds
5. Claimed Calling and Knowledge
6. Expressed Will

Important correction:

- earlier versions leaned too hard on recovery alone
- current direction must also account for:
  - new learning
  - hybrid identity formation
  - conflicting worldviews and pressures
  - fear, morale, and negative distortion

An Echo becomes whole not by returning to an untouched original self, but by integrating:

- what was recovered
- what was newly learned
- what was socially reinforced or challenged
- what was distorted by pressure

## Current progression direction

The progression backbone is now broadly locked:

- core traits remain `Courage`, `Wisdom`, and `Faith`
- archetype remains the Echo’s static flavor anchor
- vectors are canon directional identity layers, not disposable tuning tags
- the player-facing progression spine is:
  - `Storyweight`
  - `Standing`
  - `Step`
- `Continuity` is the Sanctum progression spine and should be treated in implementation terms as house `XP + level`, even though it should not read that way to the player
- callings now use a six-calling foundational set:
  - `Okofor`
  - `Aduro`
  - `Onyamesu`
  - `Okomfo`
  - `Kra-Soro`
  - `Sum-Okwanfo`
- the calling system now uses a three-ring lattice:
  - rank 3 = foundational recognition
  - rank 6 = limited drift and deepening
  - rank 9 = culmination and adjacent synthesis
- skills now use a six-family progression model:
  - `Ward`
  - `Break`
  - `Veil`
  - `Path`
  - `Rite`
  - `Root`
- each calling aligns to 2 strong skill families plus 1 light adjacent family
- each calling milestone grants:
  - 1 active
  - 1 passive
  - 1 utility
- vows are Keeper promises to the house expressed as temporary doctrine overlays for a run; they bias other systems but do not unlock skills directly
- mythic status remains separate from rank

---

# 3. Core Gameplay Loop

## High-level loop summary

The old broad loop still works as a scaffold:

**Summon -> Guide -> Venture -> Resolve -> Reflect -> Legacy**

But GDD V2 should reinterpret each phase through the new Weave-driven core concept.

## Current intended loop meaning

### Summon

The Keeper calls Echoes as incomplete selves:

- observe the fragment that has returned
- identify early traits, temperament, and instability
- place the Echo into the life of the Sanctum

### Guide

The player shapes Echoes in the Sanctum through:

- rituals
- jobs
- social proximity
- mentorship
- vows
- conversation and conflict
- Weaving Rites

This phase should generate:

- attachment
- interpretive play
- minor but meaningful growth and shaping
- cultural growth for the Sanctum itself

### Venture

The player prepares and sends Echoes into stages and Realm trials where:

- stolen stories are confronted and reclaimed
- Threads are returned
- fear, morale, bond strain, and will are tested
- prior Sanctum choices are paid off under pressure

### Resolve

The aftermath should determine:

- what Threads returned
- who resonates with them
- how the Weaving Rite plays out
- how the Echoes, bonds, and Sanctum change

### Reflect

The player reads consequences through:

- Storyweight growth
- relationship shifts
- behavioral changes
- morale / fear changes
- vow outcomes
- Continuity growth

### Legacy

Long-term progress should reflect:

- what kinds of selves the player has helped Echoes become
- what kind of society the Sanctum has become
- what stories have been returned to the world
- which Echoes become memorable or mythic

## Sanctum and Realm balance

The game must not become life-sim first.

The Sanctum exists to build attachment, identity, and interpretive play that pays off in the Realms.

The Realms exist to test, reveal, and recover what the Sanctum has shaped.

Across the full game:

- Sanctum creates meaning
- Realms cash that meaning out and return new material for the Weave

If either side can be removed without collapsing the game’s emotional identity, the concept is off-balance.

---

# 4. Locked System Backbone

## Locked naming

- `Weave`: umbrella system for recovery, shaping, contradiction, and integration
- `Storyweight`: main visible Echo progression spine
- `Threads`: recovered story-fragments crystallized from Realm recovery
- `Continuity`: Sanctum progression spine

## Structure

- Echo progression: becoming a person
- Sanctum progression: becoming a society
- Realm progression: recovering the stolen stories that feed both

## Storyweight

`Storyweight` replaces generic player-facing XP framing for Echoes.

It should mean:

- increasing narrative/personhood weight
- not just combat reward
- not just generic grind progression

Sanctum and Realm actions can both contribute, but not every meaningful outcome should flatten into one number.

## Continuity

`Continuity` is one visible Sanctum progression spine with hidden sublayers:

- Memory
- Social Fabric
- Institutional Pattern

Continuity should unlock cultural readiness, not generic base level.
Buildings, roles, rites, and institutions are expressions of a house that has become ready, not Continuity itself.

---

# 5. Threads, Recovery, and the Weaving Rite

## What a Thread is

Threads are:

- singular and scarce
- Realm-aligned and virtue-aligned
- symbolic story-fragments, not mini-NPCs
- held in reserve only once fully crystallized

A full Thread should carry:

- domain / source Realm
- one expression family within that virtue
- intensity
- corruption / distortion pressure

Short prose + tags is enough surface. Not every Thread needs a full authored story.

## Thread domains

The ten current domains remain:

1. Courage
2. Wisdom
3. Leadership
4. Acceptance
5. Humility
6. Forgiveness
7. Truth
8. Generosity
9. Compassion
10. Empathy

Each domain should:

- restore one part of selfhood
- pressure one failure mode or contradiction

## Expression families

Each virtue should have roughly 3 to 5 recurring expression families.
Same-domain Threads should therefore differ meaningfully, not only by strength or cleanliness.

## Realm recovery model

Stages do **not** drop full Threads directly.

Current locked direction:

- one Realm active at a time
- each stage contributes a recovery segment to that Realm’s recovery track
- stage quality matters
- `F` results create broken/compromised segments
- special stage events can add a bonus segment
- Realm completion crystallizes `1 to 3` full Threads
- every completed Realm guarantees at least `1` usable full Thread

Partial recoveries are not inventory items.
They are state on the active Realm recovery track.

## Omen / preview use

Partial recovery can be used before Realm completion only in limited ways:

- stronger readiness clues
- omen / preview rites

This should cost recovery quality, not a separate shard currency.
Current direction: downgrade a random segment by one quality step.

## Weaving Rite structure

Threads are assigned through the **Weaving Rite**.

Current agreed behavior:

- only full Threads enter reserve
- multiple Echoes can resonate with or contest the same Thread
- the Keeper chooses which Echo receives it
- non-chosen contenders can suffer negative consequences

The rite should have two readable phases:

1. invitation
2. resolution

Once the rite begins, it must be seen through.
The point is interpretive tension, not a cancel button.

## Integration outcomes

Current full-system outcome set:

- Accept
- Partially Integrate
- Reject
- Distort
- Defer

Important distinctions:

- `Reject` is not always simple failure; it can be meaningful self-definition
- `Defer` is the early-stop outcome
- `Partial` persists until acted on
- `Distort` is a recurring core outcome, not a rare edge-case

## Hidden resolution order

Current agreed hybrid order:

1. fit and resonance
2. state and readiness
3. distortion pressure

Interpretation:

- fit problems tend toward Reject or Distort
- timing/state problems tend toward Defer or Partial
- strong fit + good state tends toward Accept

## Readiness philosophy

Do not show exact success percentages.

The player should read readiness through clues, behavior, Sanctum events, barks, and history.
State should be readable enough for judgment.
Meaning should remain partly ambiguous.

## Compatibility priority

Current priority direction:

1. social context
2. fear and morale state
3. virtue temperament profile from vector/calling/archetype
4. prior Threads and Storyweight maturity
5. Anansi distortion pressure / instability

---

# 6. Virtue Affinity, Repetition, and Distortion

## Hidden virtue affinity map

There is now a hidden virtue wheel used for system logic, not for direct player display.

Current first-pass wheel order:

1. Courage
2. Leadership
3. Truth
4. Wisdom
5. Humility
6. Acceptance
7. Forgiveness
8. Compassion
9. Empathy
10. Generosity

Same virtue = strongest direct fit but highest overgrowth risk when stacked.
Adjacent virtues = most common balancing/remedy paths.
Opposite tensions exist but should not behave like a visible hard-counter chart.

## Hidden virtue temperament profile

Each Echo has a hidden virtue temperament profile derived from:

- vectors
- calling
- archetype
- prior Thread history
- bonds and rivalry patterns
- fear and morale history
- recent Realm experiences
- current role and obligations

High-level hidden tendencies:

- anchor virtues
- balancing virtues
- risk virtues
- current instability around certain domains

## Repeated same-virtue investment

Current design arc:

- first major repeat = deepening
- second = specialization
- third = main overgrowth fork point

At the third major same-virtue investment:

- supported specialization can become disciplined mastery
- unsupported specialization bends toward overgrowth

Primary overgrowth pressures:

- narrowed compatibility
- social strain

Balancing support should usually require all three:

- adjacent/balancing virtues
- stable bonds / relationship care
- low fear and decent morale

Repeated virtue investment should visibly change dialogue, behavior drift, and duty obsession.

## Distortion

Distortion should not touch every system layer equally.

Current primary targets:

- Thread expression
- morale/fear sensitivity
- combat/action tendencies

Current secondary surfaces:

- dialogue tone
- bonds / relationships

Each distortion should usually create:

- one major warped effect
- up to two minor echoes

Distortions are internally named conditions with hidden severity tiers.
Player-facing surface should use short atmospheric tags plus prose.

## Distortion persistence

- contamination / Anansi distortions can sometimes be softened but leave scars
- overgrowth distortions are more ingrained and must be lived with or adapted around

## Priority distortion families currently locked

- Courage -> Bravado
- Humility -> Self-Erasure
- Wisdom -> Cold Abstraction

Preferred remedies:

- Bravado -> Humility primary; Acceptance/Wisdom secondary
- Self-Erasure -> Truth primary; Generosity/Acceptance secondary
- Cold Abstraction -> Empathy primary; Compassion/Truth secondary

Mythic Echoes may carry scar tissue.
They should not carry severe unresolved active distortion.

---

# 7. Continuity, Mythic Echoes, and Economy

## Continuity

Continuity should be treated as the house becoming a culture.

Implementation meaning:

- it is the visible Sanctum progression resource
- structurally it behaves like house `XP + level`
- it is fed by stories brought home, social development, rites, positive institution beats, and stabilized customs
- it should not be presented to the player as a generic base-XP meter

Priority feed order:

1. what stories are brought home
2. who lives in the house and how they relate
3. what the house repeatedly practices

Buildings/rooms are not Continuity itself.
They are expressions of cultural readiness.

Current Sanctum pulse direction:

- a `Sanctum pulse` is the pacing unit where accumulated house state is checked and surfaced
- pulses can surface ambient microbeats, warnings, positive institution beats, incidental events, and major incidents
- pulses are one major way the house converts lived state into visible play, but they are not the only source of `Continuity`
- unresolved pressure should usually mutate into worse or differently shaped incidents rather than cooling off on its own

Different houses should be able to achieve high Continuity through different shapes:

- smaller house via strong Memory / Institutional Pattern
- larger house via stronger Social Fabric / role structure

Fraying should come from:

- broken vows
- failure to bring stories home
- severe social fragmentation

Unlocked institutions should usually weaken/fray rather than disappear outright.

## Mythic Echoes

Mythic status is now understood as:

- not ownership
- not a simple rank-up
- social recognition of a cohered self

Mythic status should **not** fire automatically the instant hidden criteria are met.
The stronger direction is:

- Echo becomes mythic-ready through lived growth
- a formalizing rite followed by house recognition becomes possible
- mythic recognition can fail even if the Echo accepts the rite and the house attempts recognition
- the Echo can refuse or redirect recognition if the house recognizes them in the wrong shape

Baseline mythic direction:

- strong signature virtue or pair
- minimum Storyweight / mature wholeness
- meaningful bond footprint
- fully claimed role/calling path
- defining remembered act
- no severe unresolved active distortion

Rarity target:

- valid full run can end with no mythics
- one mythic in a strong run should feel substantial
- multiple mythics should be possible but rare

Mythic Echoes remain playable but become more self-directed and socially burdensome.
They should not become freely deployable “best units.”

Current burden direction:

- stronger social obligation is the main meaning layer
- stronger institutional pressure and rivalry are the next major burdens
- deployment cost is the main anti-“best unit forever” control
- multi-mythic pressure should default first to competing house-shape pressure, then to office/authority overlap

Mythics can leave if the house no longer fits what they became.

## Economy split

Current locked economy split:

### Spendable currencies

- `Ase`
- `Ekwan`
- `Relics`

### Visible states, not spendables

- `Faith`
- `Harmony`
- `Favor`

### Progression/readiness state

- `Continuity`
- `Threads`
- active Realm recovery track state

### Currency roles

- `Ase`: summoning, rites, Thread handling
- `Ekwan`: rooms/buildings, crafting, research/preparation
- `Relics`: rare equippable artifacts, sometimes catalyst-level inputs

## Items and equipment

Current slot model:

1. Weapon
2. Charm
3. Armor / Clothes
4. Relic or Consumable

Direction:

- gear is real loadout, but not the main identity spine
- weapons affect action profile, role behavior, visuals, and some stats
- charms are the main place for emotion modifiers, virtue/Thread synergy, and small rule-bending
- armor/clothes are mostly defensive/survival gear
- consumables are limited and one-use
- relics are rare and one-per-Echo

Anti-hoarding direction:

- no normal durability on ordinary gear
- inventory cap
- offering items into rites
- recycling into `Ekwan`
- upgrades fold old gear into stronger gear

Relics should be mostly found.
Some can form from Echo death under special remembrance conditions, but this must stay rare enough that death never becomes the main relic economy.

---

# 8. Starter Flow, Tutorial, and Current Next Steps

## Opening slice

Current framing:

- `start + tutorial` = everything before summoning opens
- the game meaningfully opens once summoning becomes available

Opening structure currently agreed:

1. dormant Sanctum + one unsettled pre-summoned Echo
2. awakening rite
3. reassure/guide Echo + tend broken house
4. protected mini-trial to recover ember
5. return with ember, some Ase, partial recovery/intel, small reward
6. Ase Flame core visibly awakens
7. one more stabilizing action / second simple rite
8. summoning unlocks

Starter Echo should always begin unsettled, but not always in the same flavor.

## Starter Realm and first proper stage

Current direction:

- use a fixed starter/prologue Realm for the opening slice
- this can function like an eleventh opening Realm if needed
- do not offer free Realm choice immediately

First proper stage direction:

- first lead is only a rough target area: scout the corrupted outskirts
- exact path / placements / some triggers hidden
- deterministic and scoutable, not chaotic
- stages are procedurally generated before first entry
- once a stage is first entered, that exact instance should lock until cleared/abandoned
- reruns of unresolved stage preserve player learning
- after Realm clear and later replay, a new stage instance can generate and lock again on first entry

Current stage structure direction:

- each Realm should contain roughly `4 to 6` deterministically generated stages
- stage difficulty should scale primarily by completed Realm count, secondarily by roster/house strength
- a stage can contain up to `3` objectives total
- early/foundation stages should usually use:
  - `1` primary objective
  - `0 to 2` linked secondary objectives or complications
- objective clusters should be built through:
  - hard-authored adjacency anchors
  - tag-based compatibility rules
- good intel should reliably reveal:
  - objective type
  - objective location
- some encounters should be objective-tied set pieces
- some encounters should be semi-random roaming contacts the player can discover, avoid, or run into by chance
- stages should often require multiple runs to fully understand unless the player brings a very strong, prepared, intel-capable party

Current foundation anchor objective set:

- `Scout / Reveal`
- `Recover / Retrieve`
- `Find / Protect / Escort`
- `Endure / Escape`
- `Pursue / Hunt`

Current enemy framework:

- enemies should be built first around stage/objective pressure, then role, then flavor
- small reusable enemy grammar with strong Realm variation is preferred over huge bespoke rosters
- first-pass pressure-role set:
  - `Blocker`
  - `Hunter`
  - `Breaker`
  - `Watcher`
  - `Swarm`
  - `Ritualist`
- Realm identity should vary enemies through:
  - movement
  - target priority
  - pressure effect
  - hazard/objective interaction

Current NPC framework:

- no permanent Sanctum NPC cast is required
- stage/NPC roles should primarily be:
  - `Witness`
  - `Guide`
  - `Charge`
  - `Claimant`
  - `Temporary Ally`
- NPCs should appear most often in objective-linked stages, but can also surface as optional discoveries or complications

Current failure valve:

- map-level withdrawal for uncalled Echoes from the start
- no fake wipe protection if permadeath is core
- failed-but-useful run should still return intel, revealed objective requirements, and sometimes objective location or pressure-type knowledge

## Opening directives

Protected mini-trial should not use directives.
First proper stage should introduce only 1 to 2 real full-game directives:

- `Scout Carefully`
- `Seek Signs`

## First 30 minutes target

By roughly first 30 minutes:

- 2 Echoes
- basic understanding of partial recovery track
- at least one meaningful Echo-to-Echo social beat
- at least one real stage attempted, likely 1 to 3 stages into opening Realm

Crafting can unlock slightly later.

## Current next sparring targets

The large conceptual gaps have now been substantially reduced.
The most important unresolved work for the next chat is now mostly exact tuning, content mapping, and implementation alignment:

1. exact early-game economy and inventory pressure
2. exact Weave/rite surfacing:
   - reserve caps
   - overflow UX
   - stable clue vocabulary
   - hidden rite thresholds
   - contested fallout tables
3. exact Continuity mapping:
   - numeric thresholds
   - institution / rite / custom content placement
   - Memory / Social Fabric / Institutional Pattern weighting
4. exact mythic and naming cleanup:
   - failure / retry thresholds
   - deployment-cost and departure tuning
   - weak rank-9 replacement set
   - validated Twi counterparts for final names
5. exact stage/enemy/NPC content library:
   - objective adjacency map
   - enemy pressure-role content
   - NPC trigger and payoff rules
6. then compare the built systems/code against the updated GDD and steer implementation to match

---

# 9. Working Constraints For Future AI

## Working method

The current collaboration style is:

- stay in sparring / critique mode until a section survives pressure
- challenge weak assumptions directly
- do not draft vague filler just to make progress
- once a section is coherent enough, write it back into the Working GDD

The next chat should continue in that mode.

The next chat should not jump straight into code or implementation audit yet.

Current intended order:

1. tune early economy and inventory pressure
2. finalize exact Weave/rite surfacing values and vocabulary
3. finalize exact Continuity thresholds and content mapping
4. finalize mythic threshold/burden tuning and high-end naming replacements
5. finalize stage objective adjacency, enemy role content, and NPC payoff rules
6. only then compare the built game against the new GDD and steer implementation to match

## Steer, do not rebuild

The codebase already contains real systems and constraints.
Do not casually propose rebuilding the game from scratch.

Important implementation areas already exist:

- deterministic simulation
- state-first architecture
- snapshot-driven UI
- Flow and Encounter state machines
- Sanctum and Realm screens
- summoning, roster, and party flow
- directives
- social graph / bonds
- vows
- progression / rank / level / callings / vectors
- Sanctum spatial rendering
- combat board / encounter sequencing
- economy and emotion services

Design work should reinterpret and improve these systems where possible rather than pretending none of them exist.

## Visibility philosophy

`Storyweight` should remain the main visible growth spine.
Most other systems should be clue-rich rather than fully transparent.

The player should have enough information to infer and learn, but not enough to spreadsheet every Echo.

Player-facing progression language now uses:

- `Storyweight`
- `Standing`
- `Step`

## Roster scale

Current working cap remains roughly:

- about 25 Echoes

Reason:

- enough variety for social interplay
- small enough to remember and care about individuals
- supports ambiguity and learning without overload

---

# 10. Main Open Questions

These are now final-stretch tuning / surfacing / content-mapping questions, not broad concept questions:

- exact early-game economy tuning and inventory pressure
- exact Sanctum pulse frequency, warning language, passive values, and job scaling
- exact autonomy thresholds, warning phrases, and directive-behavior conflict resolution
- exact Thread reserve caps, overflow UX, clue wording, and integration thresholds
- exact Continuity milestone thresholds, content mapping, and sublayer weighting
- exact mythic recognition thresholds, burdens, and multi-mythic/departure events
- first-pass replacement set for weak rank-9 names plus validated Twi-facing counterparts
- exact stage objective library, adjacency map, enemy pressure-role content, and NPC trigger/payoff rules

## 10.1 Highest-priority next sparring targets

The next chat should prioritize these in this order unless a better dependency order becomes obvious:

1. early-game economy tuning:
   - summon cost
   - first-stage reward cadence
   - early Ase / Ekwan flow
   - inventory cap pressure
   - rarity ladder
   - death-formed relic conditions
2. exact Weave/rite surfacing:
   - reserve caps and expansion cadence
   - stable clue vocabulary
   - hidden resolution thresholds
   - contested fallout tables
3. exact Continuity mapping:
   - numeric thresholds
   - institution/rite/custom content placement
   - sublayer weighting
4. exact mythic and naming cleanup:
   - failure and retry thresholds
   - deployment-cost and departure tuning
   - weak rank-9 replacements
   - validated Twi counterparts for final names
5. exact stage/enemy/NPC content library:
   - objective adjacency map
   - enemy role content
   - NPC role triggers and payoffs
6. after those are stronger, inspect the current implementation and adjust it toward the new GDD

## 10.2 What should not be reopened casually

These are no longer broad concept questions and should not be reset without a strong reason:

- the wholeness model as layered recomposition
- Threads as recovered story-fragments rather than generic progression currency
- the Realm recovery track and `1 to 3` Thread yield structure
- the reduced foundation Rite outcome set of `Accept`, `Reject`, and `Defer`
- the hidden virtue wheel and virtue temperament profile direction
- repeated same-virtue investment as deepening -> specialization -> overgrowth fork
- distortion as a constrained, recurring system rather than a rare edge case
- Continuity as the Sanctum becoming a culture
- `Continuity` as the visible Sanctum progression resource with house `XP + level` implementation meaning
- `Sanctum pulse` as the pacing unit for surfacing house life, warnings, and incidents
- mythic status as social recognition of a cohered self
- mythic recognition as a multi-step, fallible transition rather than auto-promotion
- the three-currency economy split
- the opening slice structure built around one pre-summoned Echo, ember recovery, then summoning unlock
- the foundation cutline as a broad early-game base rather than a tiny pitch MVP
- the six foundational callings and their adjacency ring:
  - `Okofor`
  - `Aduro`
  - `Sum-Okwanfo`
  - `Kra-Soro`
  - `Okomfo`
  - `Onyamesu`
- the three-ring calling lattice:
  - rank 3 recognition
  - rank 6 limited drift
  - rank 9 culmination / adjacent synthesis
- the six global skill families:
  - `Ward`
  - `Break`
  - `Veil`
  - `Path`
  - `Rite`
  - `Root`
- vows as Keeper promises / run-length doctrine overlays rather than Echo-owned skill unlocks
- stage structure as partially unknown, procedurally generated, lock-on-entry exploratory spaces
- enemy design as stage/objective pressure first, then role, then flavor
- core traits as `Courage`, `Wisdom`, and `Faith`
- player-facing progression language as `Storyweight`, `Standing`, and `Step`

## 10.3 Implementation follow-up rule

When the next chat eventually turns to the built game, the first move should be:

- inspect what already exists
- identify where the lived experience diverges from the new GDD
- steer and reinterpret existing systems where possible

Do not recommend a rebuild-first approach unless the current implementation makes a specific feature impossible.

## 10.4 Final Stretch Rule

The Working GDD should now be treated as being in its final stretch.

That means:

- stop reopening solved backbone questions casually
- focus on major remaining gaps only
- finish the last tuning / surfacing / institution / mythic questions cleanly
- then move into codebase alignment, refactor, and foundational implementation work

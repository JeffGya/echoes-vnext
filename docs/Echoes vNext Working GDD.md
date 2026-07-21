# Echoes vNext GDD V2.5

**Status:** V2.5 canonical spec — approved July 12, 2026

**Revision date:** July 12, 2026

**Revision record:** V2.5 promotes the minimum Keeper Tactical Guidance loop into Foundation scope, defines its system-level design boundaries, and narrows the corresponding Post-Foundation boundary.

**Purpose:** Concept-first Game Design Document V2.5 for Echoes vNext. This document is now the primary design authority for the project and should be used as the base knowledge for implementation, content planning, UX work, and future system expansion.

**Current scope:** Core concept, player fantasy, story backbone, foundation cutline, progression backbone, implementation-facing constraints, the full current V2 design direction, and the V2.5 Keeper Tactical Guidance foundation amendment.

---

# 1. What This Document Is

This is the main V2.5 design backbone for Echoes.

It exists to:

- lock the full-game concept and foundation cutline
- preserve the strongest parts of the original story
- keep vNext implementation principles and built systems in play
- steer the current codebase instead of restarting from zero
- establish the major identity, progression, and world-shaping systems as the new source of truth

## 1.1 V2.5 amendment scope and evidence

V2.5 makes one scoped change to the V2 foundation cutline: the minimum **Keeper Tactical Guidance** loop is now Foundation work rather than a Post-Foundation combat expansion.

This amendment is grounded in:

- the playable [Keeper Tactical Guidance prototype specification](../prototypes/keeper_tactical_guidance/SPEC.md)
- the successful qualitative [prototype playtest findings](../prototypes/keeper_tactical_guidance/FINDINGS.md)
- the resulting [production design proposal](proposals/keeper-tactical-guidance-promotion.md)
- the accompanying [production architecture plan](proposals/keeper-tactical-guidance-architecture.md)

The prototype showed that preparation, readable terrain, continuous automatic combat, limited guidance, and legible Echo resistance can make combat more engaging while strengthening concern for Echoes. This is bounded evidence from one qualitative playtest plus deterministic prototype verification, not validation of every tuning value, board family, Directive, or combat mode.

V2.5 canonizes the **interaction model and Foundation responsibility**, not a direct transfer of prototype code or balance values. Detailed design and production contracts remain in the linked proposal and architecture plan.

---

# 2. Core Concept

**Echoes is a mythic house-and-trials strategy game where the Ase Keeper restores fractured Echoes, living fragments of stolen stories and returning names, and guides them through relationships, rituals, and dangerous Realm trials to reclaim lost memory from Anansi’s web. As Echoes recover stolen stories and live new ones, they become more coherent, forming deeper bonds, stronger wills, richer behaviors, and eventually ascending into myths in their own right.**

## Short player-facing pitch

You do not command heroes.

You help broken stories become people through recovery, contradiction, and new lived experience, then risk those people in corrupted Realms to bring stolen memory back into the world.

---

# 3. Story Backbone

The story backbone remains non-negotiable:

- Anansi is central, not decorative
- stolen stories are the progression spine
- Odo Agyanka remains the force of erasure, silence, and consumed names
- the Keeper’s work is restoration, not conquest
- every Realm is part of the struggle between remembrance and oblivion

## Anansi’s role

Anansi is not just a narrator, mascot, or lore wrapper.

He is:

- keeper of stories
- manipulator of the web
- ally, tempter, and antagonist at once
- the force making this game possible and dangerous

He plays with the Keeper and the Echoes.
He is part of the reason stories can be recovered, and part of the reason recovery is never clean.

## Cultural intent

At the deepest level, the game is about reconnection with stories that were lost, scattered, stolen, or made distant.

For diaspora players, this should carry the emotional weight of reconnecting with Akan, Ghanaian, and Ivorian cultural memory.

For non-diaspora players, it must still read clearly at a high level as:

- recovering what was taken
- rebuilding identity through memory
- caring for people who are not yet whole
- deciding whether legacy is worth its pain

The culture should shape mechanics, symbolism, values, ritual logic, names, and emotional structure, not just visuals and lore terms.

---

# 4. Player Role and Fantasy

## Player role

The player is the **Ase Keeper**:

- caretaker of a living house of memory
- guide of incomplete Echoes
- interpreter of signs, relationships, and spiritual tension
- not a general issuing direct orders
- not a passive observer

## Primary fantasy

The player fantasy is:

**I help incomplete beings recover and assemble who they are, then I trust what they have become when it matters most.**

## Secondary fantasies

- I rebuild a house strong enough to remember
- I recover stolen stories from mythic danger
- I shape bonds, tensions, and destinies between Echoes
- I watch fractured Echoes become vivid, willful, unforgettable people
- I raise some Echoes beyond personhood into myth

---

# 5. Sanctum and Realms

The game must not become life-sim first.

The Sanctum exists to build attachment, identity, and interpretive play that pays off in the Realms.

The Realms exist to test, reveal, and recover what the Sanctum has shaped.

## Sanctum

The Sanctum is where:

- Echoes are summoned as fragments
- relationships form and mutate
- rituals, jobs, vows, and teachings shape them
- Threads are interpreted and offered through Weaving Rites
- emotional and social life becomes legible
- the player learns who Echoes are becoming
- the house itself grows in Continuity

The Sanctum is not downtime decoration.
It is the house where fragments become people.

## Realms

The Realms are where:

- stolen stories are confronted and reclaimed as Threads
- player preparation is tested under pressure
- Echoes reveal their will, fear, trust, and growth
- bonds and fractures have mechanical consequences
- risk creates attachment payoff

The Realms are not just combat content.
They are trials of memory, interpretation, sacrifice, and recovery.

## Balance target

Over a full play cycle, Sanctum and Realm play should feel close in importance.

Not necessarily equal by the minute in every session, but equal in design weight:

- Sanctum creates meaning
- Realms cash that meaning out and return new material for the Weave

If either side can be removed without collapsing the game’s emotional identity, the concept is off-balance.

---

# 6. Echoes as Returning Names

Echoes are not complete people at summon.

They are:

- fragments of stolen stories
- partial selves
- returning names without full continuity
- living memory trying to become whole again

This is the core premise that should unify progression, behavior, social systems, and long-term attachment.

## What “becoming whole” should mean

Becoming whole must never mean only:

- more Storyweight
- better stats
- a higher Standing label

It should mean that an Echo progressively assembles and integrates:

- identity
- recovered memory
- new lived experience
- convictions
- preferences
- social ties
- emotional stability or productive instability
- access to deeper skills and callings
- the ability to act with clearer will

At the highest end, some Echoes should become **mythic**:

- not just maxed units
- but beings whose story has become coherent, memorable, and powerful enough to change others

This is the bridge from Echo to legend.

---

# 7. Design Priorities

## 7.1 Stolen stories are the true progression spine

Growth should be interpreted through the Weave:

- `Storyweight` as the main visible Echo progression spine
- `Threads` as recovered story fragments returned from stages and Realms
- `Continuity` as the Sanctum’s social and cultural growth spine

Story recovery remains central, but growth also includes lived experience, social shaping, and distortion under pressure.

## 7.2 Relationships are core progression, not flavor

Echo interplay must matter mechanically and emotionally.

The game should preserve some of the spark associated with Tomodachi-like social surprise:

- strange pairings
- affection
- rivalry
- protectiveness
- awkwardness
- admiration
- emotional collisions

But this energy must serve the larger premise of recovering personhood, not become random comedy disconnected from stakes.

## 7.3 Guidance over control must stay playable

Indirect control only works if:

- the player has meaningful influence
- outcomes are legible
- Echo behavior is interpretable
- refusal and autonomy reveal character rather than remove agency

The minimum playable combat chain is:

**Observe -> guide -> Echo interprets -> visible consequence.**

Combat remains automatic. The Keeper may prepare a formation, set broad party intent, adjust playback speed, and issue limited spatial guidance while the battle continues. The Keeper does not pause combat to choose an exact move, attack, skill, path, or target for an Echo.

Guidance must acknowledge the Keeper's input, identify who is affected, reveal whether each affected Echo aligns, interprets, hesitates, objects, or refuses, and make the Echo's next behavior legible as a consequence. Unaffected Echoes do not produce a response. Resistance without a readable reason is not character autonomy; it is lost player agency.

## 7.4 Myth must be systemic

Akan / Ghanaian / Ivorian cultural grounding and the mythic layer must shape:

- progression meaning
- obligation and vows
- symbolism and names
- story recovery logic
- relationship stakes
- ritual structure
- how truth, trickery, and remembrance operate

## 7.5 The game must steer, not restart

The current vNext codebase already contains real systems and constraints.
The new GDD must guide their evolution rather than pretend nothing exists.

---

# 8. vNext Principles To Preserve

The new GDD should explicitly retain these implementation-level principles:

- deterministic simulation
- state-first architecture
- snapshot-driven UI
- action dispatch instead of UI-owned game logic
- Flow and Encounter state machines as authoritative progression layers
- core logic isolated from presentation

These are not temporary technical decisions.
They are part of how the design stays explainable, testable, and scalable.

---

# 9. Existing vNext Systems To Keep Available

The following systems already exist in the project and should be treated as steerable assets, not disposable experiments.

## Flow and UI structure

- Sanctum flow states
- Realm selection and stage map flow
- Encounter/combat flow
- Resolve/aftermath flow
- dedicated Sanctum and Realm screen shells

## Sanctum layer

- summoning
- roster and active party management
- Sanctum naming and identity
- Sanctum spatial renderer
- vows screen and vow service
- social graph / bond edges

## Realm and tactical layer

- realm generation/service
- stage progression
- encounter phases
- combat board screen
- directives as intent layer

## Echo progression layer

- Storyweight / XP and level progression
- Standing gain logic
- vectors / dominant vector behavior shaping
- callings and calling choice logic
- derived stats and skills

## Economy and support systems

- save/load schema and single-save campaign model
- economy services
- emotion services
- structured logging
- tests across core systems

The new concept should reinterpret and redirect these systems when needed, but not erase them casually.

---

# 10. Immediate Design Consequences

If the concept above is correct, several things follow:

## 10.1 Storyweight is no longer generic progression

The main visible Echo progression spine must be understood as recovery, integration, lived formation, and growing narrative weight.

## 10.2 Bonds are part of wholeness

Relationships should help complete, distort, pressure, or stabilize Echo identity.

## 10.3 Vectors are part of self-shape

Vectors should represent directional becoming, not only hidden tuning.

## 10.4 Callings are remembered or claimed identity

Callings should feel like emergent selfhood, not class promotion only.

## 10.5 Mythic status is a narrative-mechanical threshold

A mythic Echo should feel culturally, socially, and mechanically transformed.

## 10.6 Recovered stories must have visible consequences

Story recovery must alter:

- Echo growth
- house state
- future options
- relationship possibilities
- Realm meaning

If recovered stories are only reward text, the concept fails.

---

# 11. The Wholeness Model

Wholeness is the core identity and progression model of Echoes.

It explains what an Echo is at summon, how an Echo changes, why social interplay matters, why story recovery matters, and what separates a powerful Echo from a mythic one.

## 11.1 Core principle

Wholeness must **not** be a single hidden power bar.

It is a layered process of becoming more complete.

An Echo becomes whole by recovering and integrating multiple parts of self:

- story
- direction
- bonds
- calling
- knowledge
- will

That means the game’s existing progression systems should be interpreted as parts of one larger identity model, not as unrelated feature tracks.

## 11.2 What an Echo is at summon

At summon, an Echo is a **returned name**, not a complete person.

They arrive with:

- a name or name-fragment
- a birth archetype / initial soul shape
- three core traits: `Courage`, `Wisdom`, and `Faith`
- emotional volatility
- a fragmentary behavioral pattern
- incomplete memory
- no fully claimed role
- no deep social place in the house

They are not blank slates.
They are incomplete selves.

This distinction matters:

- a blank slate is authored from zero
- a fragmented self is recovered, interpreted, and completed

Current progression direction:

- `Courage`, `Wisdom`, and `Faith` remain the deep stable trait substrate
- derived stats should continue to come from those three traits rather than from the full ten-virtue wheel directly
- archetype is the Echo’s first stable expression: the anchoring flavor that still shapes how they speak, react, and are read even as vectors, Threads, callings, and Storyweight change them
- traits plus archetype should help seed an Echo’s hidden virtue temperament profile, but they should not turn the game into a direct ten-domain matching grid

Current core archetype set:

- `Loyal`: a steady relational Echo who anchors through commitment, duty, and attachment
- `Proud`: a self-asserting Echo who resists diminishment and wants to be recognized on their own terms
- `Reflective`: a searching inward Echo who hesitates to commit before understanding what something means
- `Valiant`: a forward-driving Echo who meets danger with force of will and visible resolve
- `Canny`: a perceptive adaptive Echo who reads angles, leverage, and hidden advantage
- `Devout`: a conviction-shaped Echo whose center comes from belief, duty, reverence, or inner oath
- `Stoic`: a controlled withholding Echo who stabilizes through restraint and endurance
- `Empathic`: an attuned Echo who reads and absorbs the states of others quickly and deeply
- `Ambitious`: an upward-driving Echo who wants to become more, do more, or claim more shape in the world

## 11.3 What restores wholeness

Wholeness is shaped through both halves of the game.

### Sanctum shapes through:

- relationships
- ritual
- jobs and responsibilities
- vows and obligations
- teaching and preparation
- repeated social presence

### Realms restore and test through:

- recovered stories
- trial under pressure
- remembered action
- sacrifice
- survival
- confrontation with stolen or distorted memory

An Echo cannot become fully whole in the Sanctum alone.
An Echo cannot become fully whole in the Realms alone.

The house gives identity shape.
The trials prove, restore, and complicate it.

## 11.4 The six layers of wholeness

The working model is six connected layers.

### 1. Returned Name

This is the Echo’s anchor of existence.

It answers:

- who has come back
- what fragment is being called into the world
- what symbolic memory the Echo is tied to

At summon, this is present but incomplete.
The Echo has identity enough to exist, but not enough to be fully coherent.

### 2. Recovered Story

This is the Echo’s regained memory and narrative mass.

It answers:

- what parts of the self have been recovered
- what experiences have become integrated
- how much of the lost story now belongs to the Echo again

This is the primary meaning of Storyweight and major advancement.

Design rule:

- XP is not generic training experience
- XP is the return and integration of story

Step gain means an Echo is integrating more reclaimed story.
Standing gain means an Echo has crossed a major threshold of self-recovery.

### 3. Shaped Direction

This is the Echo’s becoming.

It answers:

- what kind of person this Echo is turning into
- how recovered story is being interpreted in practice
- what directional identity now dominates the self

This is what vectors are for.

Vectors should be treated as the **shape of recovering selfhood**, not only hidden behavior tuning.

Current vector set:

- `Vanguard` -> `Courage + Leadership`: pushes toward decisive forward action, pressure, and initiative-taking
- `Protector` -> `Courage + Compassion`: pushes toward shielding others, intervening under threat, and taking risk for another’s sake
- `Seeker` -> `Wisdom + Truth`: pushes toward reading signs, pursuing understanding, and moving toward hidden meaning
- `Strategist` -> `Wisdom + Leadership`: pushes toward coordination, planning, and acting through structure rather than impulse
- `Skeptic` -> `Truth + Humility`: pushes toward doubt, testing, and resistance to easy certainty
- `Pillar` -> `Acceptance + Humility`: pushes toward steadiness, endurance, and becoming something others can rely on
- `Devoted` -> `Acceptance + Generosity`: pushes toward service, offering, and sustained commitment to a chosen duty
- `Opportunist` -> `Courage + Wisdom`: pushes toward timing, leverage, and taking the opening that appears in uncertainty
- `Mediator` -> `Empathy + Forgiveness`: pushes toward reducing friction, reconciling strain, and restoring social coherence
- `Nurturer` -> `Generosity + Compassion`: pushes toward care, maintenance, and helping others grow or recover

Important rule:

- vectors are canon identity directions, not disposable tuning tags
- two Echoes with the same dominant vector should still differ because archetype, trait ratio, emotional state, bonds, Threads, and calling all change why that vector manifests the way it does

An Echo’s vector is not just preference.
It is the emerging direction of who they are becoming.

Current vector interpretation layers:

- `behavior bias`: what kinds of actions or choices this Echo tends toward under pressure
- `work-role affinity`: what kinds of duties, jobs, offices, or institutions this Echo tends to fit naturally
- `incident tendency`: what kinds of social or house events this Echo is likely to create, intensify, or resolve
- `calling pull`: which claimed identities this direction most naturally feeds if reinforced over time

These layers should stay broad enough to scale beyond the current opening institutions.
Vectors should not be hard-bound only to the first five buildings or to a tiny fixed incident list.

Current work-role categories should be read broadly as patterns such as:

- challenge / initiation / forward-driving roles
- care / tending / restoration roles
- governance / mediation / coordination roles
- craft / shaping / material problem-solving roles
- ritual / omen / memory stewardship roles

Likewise, incident tendencies should be treated as broad categories rather than one-off authored scenes:

- conflict escalation
- protective intervention
- omen or meaning-seeking
- institutional strain
- social repair
- care labor, exhaustion, or uneven burden
- opportunistic leverage
- discipline, duty, or sacrificial pressure

Current vector effect directions:

#### Vanguard

- behavior bias: favors initiative, pressure, first commitment, and lower hesitation under threat
- work-role affinity: strongest in challenge, initiation, and forward-driving roles; weakest in quiet maintenance
- incident tendency: tends to create dares, status clashes, reckless inspiration, and forceful momentum
- calling pull: strongest toward `Aduro`, secondary toward `Kra-Soro`

#### Protector

- behavior bias: favors guarding, interposing, and answering danger to others first
- work-role affinity: strongest in guarding, stabilizing, and protective support roles
- incident tendency: tends to create loyalty tests, shielding behavior, blame-taking, and intervention arcs
- calling pull: strongest toward `Okofor`, secondary toward `Onyamesu`

#### Seeker

- behavior bias: favors clue-reading, curiosity, scouting, and interpretive action over blunt commitment
- work-role affinity: strongest in omen, archive, scouting, and memory-reading roles
- incident tendency: tends to create hidden-pattern discovery, unsettling questions, ritual curiosity, and omen fixation
- calling pull: strongest toward `Okomfo`, secondary toward `Kra-Soro`

#### Strategist

- behavior bias: favors structure, timing, planning, and collective efficiency over impulse
- work-role affinity: strongest in coordination, governance, and structured production roles
- incident tendency: tends to create planning conflicts, doctrine disputes, efficiency arguments, and controlled ambition
- calling pull: strongest toward `Onyamesu`, secondary toward `Okomfo`

#### Skeptic

- behavior bias: favors doubt, testing, caution around easy readings, and slower commitment
- work-role affinity: strongest in inspection, verification, critique, and risk-checking roles
- incident tendency: tends to create mistrust, exposed weak logic, challenged rites, and friction around certainty
- calling pull: tends toward `Sum-Okwanfo` or `Okomfo` depending emotional profile and surrounding pressures

#### Pillar

- behavior bias: favors steadiness, endurance, and holding through pressure with low volatility
- work-role affinity: strongest in maintenance, continuity, and institution-anchoring roles
- incident tendency: tends to create burden-bearing, quiet stabilization, being taken for granted, and house-anchoring presence
- calling pull: strongest toward `Onyamesu`, secondary toward `Okofor`

#### Devoted

- behavior bias: favors service, obligation, follow-through, and willingly bearing cost for chosen duty
- work-role affinity: strongest in ritual commitment, care, and long-duty service roles
- incident tendency: tends to create vow intensity, sacrificial overreach, duty conflict, and strain when service is not returned
- calling pull: strongest toward `Onyamesu`, with `Okomfo` or `Okofor` as secondary expressions depending form

#### Opportunist

- behavior bias: favors timing, leverage, adaptability, and taking openings in uncertainty
- work-role affinity: strongest in trade, tactical shaping, improvisational, and leverage-driven roles
- incident tendency: tends to create shortcut-taking, rivalry escalation, tactical manipulation, and impressive but suspect saves
- calling pull: strongest toward `Kra-Soro`, secondary toward `Aduro`

#### Mediator

- behavior bias: favors de-escalation, reconciliation, and reducing relational damage
- work-role affinity: strongest in hospitality, social coordination, and conflict-repair roles
- incident tendency: tends to create peacemaking, emotional triangulation, repair fatigue, and uneven burden around keeping the peace
- calling pull: strongest toward `Onyamesu`, secondary toward `Okomfo`

#### Nurturer

- behavior bias: favors tending, recovery, encouragement, and growth-support over direct assertion
- work-role affinity: strongest in recovery, care, teaching-support, and growth-tending roles
- incident tendency: tends to create attachment deepening, burnout, quiet support arcs, and resentment from uneven care labor
- calling pull: strongest toward `Onyamesu`, secondary toward `Okofor`

Design rule:

- dominant vector provides the strongest direction of bias
- secondary vector changes motive, flavor, and stress response
- archetype changes tone
- emotion changes intensity
- calling changes expression once identity is more fully claimed

Current institution examples such as `Hearth`, `Training Grounds`, `Council Hall`, `Smith / Crafter`, and `Old Great Tree` should read through these broader affinity patterns rather than replacing them.

### 4. Living Bonds

This is the Echo’s social reality.

It answers:

- who recognizes them
- who stabilizes them
- who distorts them
- who helps complete them
- who threatens their coherence

Bonds are part of wholeness, not side flavor.

An Echo becomes more real through:

- affection
- trust
- rivalry
- mutual dependence
- admiration
- resentment

This is where Tomodachi-like spark belongs:

- surprising pairings
- emotionally legible collisions
- social warmth and friction
- everyday expressive interplay that later matters under pressure

### 5. Claimed Calling and Knowledge

This is the Echo’s role, craft, and remembered capability.

It answers:

- what role the Echo claims in the world
- what they know how to do
- what kind of contribution they can make deliberately

This is where callings and skills belong.

Callings should not read as class upgrades only.
They should read as an Echo reaching a more coherent answer to:

- who am I becoming
- what am I for
- how do I act in service of that self

Before this threshold, every Echo is `Uncalled`.

Current Standing-3 calling direction:

- callings are part combat/exploration role and part the recognizable shape of an Echo becoming their fuller story
- Standing 3 should be the clearest vector-alignment layer
- Standing 6 and Standing 9 should loosen this structure and allow more drift, synthesis, and movement across adjacent or complementary tracks without treating that movement as a punishment
- calling pull should be strong, but callings should never be determined by vectors alone
- the current steering model remains:
  - the system computes the strongest eligible calling paths
  - the Echo has preference
  - the Keeper can steer within or against that preference
  - forcing a poor fit should create emotional and behavioral strain rather than reading as a neutral class swap

### Current skill direction

Skills should not use a classical sprawling RPG skill-tree model.

Current direction:

- skills should be organized into global **skill families**
- callings should align to those families rather than hard-owning isolated private trees
- skill progression should become personalized through continuity and drift across calling milestones
- the player should feel that Standing 3 / 6 / 9 changes not only the Echo's title, but also the kinds of techniques the Echo can meaningfully develop

Current skill-family rule:

- the game should use `6` global skill families
- each family should have three depth tiers aligned to the calling milestones:
  - Standing `3` = core technique
  - Standing `6` = deepening
  - Standing `9` = culmination
- each calling should align to:
  - `2` strong families
  - `1` light adjacent family

Current family set:

#### `Ward`

Protection through interception, guarding, holding, and answering danger before it breaks the line.
This family is about keeping others standing, absorbing pressure, and stabilizing danger without surrendering ground.

Current shape:

- active focus: intercept, guard, answer pressure, hold the line
- passive focus: ally protection, steadiness under focus, counterpressure while holding
- utility focus: ally reposition, bracing, threat draw

#### `Break`

Pressure through force, disruption, momentum, and opening-making.
This family is about striking decisively, cracking formations, forcing movement, and turning courage into tactical rupture.

Current shape:

- active focus: burst strike, guard-breaking, forced movement, opening punish
- passive focus: momentum, follow-through, target pressure
- utility focus: engage leap, commit stance, tempo surge

#### `Veil`

Concealment through misdirection, hidden intervention, sabotage, and surgical timing.
This family is about acting from obscurity, crossing unnoticed, severing weak points, and shaping the fight from the edge of visibility.

Current shape:

- active focus: sabotage, hidden strike, weakness marking, timing disruption
- passive focus: concealment, opportunistic damage, low-profile repositioning
- utility focus: vanish, decoy, slip-path movement

#### `Path`

Mastery through route-reading, pursuit, angle control, repositioning, and field sense.
This family is about reading terrain, chasing openings, controlling approach lines, and knowing where movement should resolve.

Current shape:

- active focus: pursuit, angle exploitation, movement punish, route denial
- passive focus: range and angle advantage, chase pressure, terrain reading
- utility focus: scout reveal, repositioning, sightline control

#### `Rite`

Influence through omen-reading, thresholds, sacred procedure, revelation, and spirit authority.
This family is about reading what lies beneath events, acting at charged moments, and shaping outcomes through ritual intelligence rather than brute force.

Current shape:

- active focus: omen marks, threshold binding, revelation, ritual pressure, stabilization
- passive focus: ritual timing, omen sensitivity, threshold advantage
- utility focus: intent reading, hidden-state reveal, zone or objective warding

#### `Root`

Endurance through care, morale, recovery, continuity, and communal steadiness.
This family is about restoring others, carrying burden without collapse, reinforcing cohesion, and making the house harder to uproot.

Current shape:

- active focus: restore, steady morale, burden-share, reinforce an ally
- passive focus: recovery, cohesion, resilience under strain
- utility focus: comfort pulse, rally, fear-edge or instability stabilization

Current family-name note:

- these are current English-facing scaffolds for player readability
- final player-facing family names should also receive validated Twi counterparts before ship
- new Twi family names should not be created through crude literal back-translation

Current calling-family matrix:

- `Okofor`: strong `Ward`, strong `Root`, light `Break`
- `Aduro`: strong `Break`, strong `Ward`, light `Veil`
- `Sum-Okwanfo`: strong `Veil`, strong `Break`, light `Path`
- `Kra-Soro`: strong `Path`, strong `Veil`, light `Rite`
- `Okomfo`: strong `Rite`, strong `Path`, light `Root`
- `Onyamesu`: strong `Root`, strong `Ward`, light `Rite`

Current milestone package direction:

- each calling milestone should grant:
  - `1` active
  - `1` passive
  - `1` utility
- this means a fully developed Echo can carry:
  - `3` actives
  - `3` passives
  - `3` utility skills
- the player should choose within the eligible family options for that milestone rather than receiving a fully forced package

Current unlock rule:

- there should be no separate skill-point currency
- skill unlocks should require:
  - the relevant calling milestone
  - Storyweight thresholds
  - specific lived conditions where appropriate, such as:
    - accepted Thread relation or count
    - bonds
    - other remembered acts or progression conditions
- unlocks should be paid for with `Ase`

Current drift rule:

- if an Echo drifts into a different family line at a later calling milestone, already unlocked earlier-family skills should remain available
- deeper future unlocks in the abandoned family line should no longer be available
- this is how personalized skill progression should record identity continuity and drift rather than flatten into a generic list
- effective repeated use of an old-family skill can make that skill feel more natural again over time and can lightly reinforce calling pull back toward that line

### Current vow-family alignment direction

Vows should not unlock skills or replace family progression.
They should act as doctrine overlays that bias how family strengths and strains express themselves during a run.

Current direction:

- vow mismatch should show up primarily through intent-weight skew and hesitation around family-defining actions
- some vow-family pairs can produce stronger short-term output with later backlash, but that should be the exception rather than the default
- utility-heavy families should show doctrine alignment especially clearly in preparation, warning language, and non-damage choices

Current first-pass alignment map:

#### Party doctrine

- reinforces: `Root`, `Ward`
- strains: `Veil`
- current read: stronger shared-duty behavior, greater cohesion pressure, and less tolerance for isolated hidden action
- `Veil` under this doctrine should feel constrained but still useful rather than distrusted by default

#### Truth / restraint doctrine

- reinforces: `Rite`, `Path`
- strains: `Break`, lightly `Root`
- current read: slower commitment, stronger checking and interpretation, less tolerance for reckless expenditure
- `Break` under this doctrine should feel suppressed more than redirected
- `Root` can show light strain here because comfort and continuity can sometimes hide unresolved strain

#### Protection doctrine

- reinforces: `Ward`, `Root`
- strains: `Break`, some `Veil`
- current read: more interposition, ally-preservation, and protective intervention pressure across Sanctum and battle
- `Veil` should remain useful, but with narrowed expression under this doctrine

#### Pace / patience doctrine

- reinforces: `Path`, `Rite`, some `Veil`
- strains: `Break`
- current read: delayed commitment, stronger timing windows, more waiting and reading before force
- `Break` under this doctrine should feel held back rather than elegantly redirected

Current foundational Standing-3 calling set:

#### `Okofor`

- English scaffold: `Warder`
- identity: the Echo who becomes true by bearing danger for others and refusing to let the line break
- system tags: protection, interception, steadiness, burden-bearing
- strongest pull: `Protector`
- secondary pull: `Pillar`
- Standing-3 short description: bears danger for others and refuses collapse

#### `Aduro`

- English scaffold: `Blade`
- identity: the Echo who becomes true by meeting danger directly and creating momentum through force, courage, and decisive action
- system tags: pressure, momentum, confrontation, decisive action
- strongest pull: `Vanguard`
- secondary pull: `Opportunist`
- Standing-3 short description: meets danger directly and turns courage into momentum

#### `Onyamesu`

- English scaffold: `Steward`
- identity: the Echo who becomes true by tending life, holding communal morale together, and sustaining others through care and presence
- system tags: anchoring, care, morale, restoration, communal stability
- strongest pull: `Pillar`
- secondary pull: `Nurturer`
- Standing-3 short description: sustains life, morale, and communal steadiness

#### `Okomfo`

- English scaffold: `Seer`
- identity: the Echo who becomes true by reading spirit, sign, and hidden pattern, then acting from deeper understanding
- system tags: omen-reading, interpretation, hidden knowledge, ritual perception
- strongest pull: `Seeker`
- secondary pull: `Strategist`
- Standing-3 short description: reads spirit, sign, and hidden meaning

#### `Kra-Soro`

- English scaffold: `Ranger`
- identity: the Echo who becomes true by reading path, distance, angle, and changing ground
- system tags: scouting, positioning, movement, field sense, adaptive survival
- strongest pull: `Seeker`
- secondary pull: `Opportunist`
- Standing-3 short description: reads path, distance, and shifting ground

#### `Sum-Okwanfo`

- English scaffold: `Veilrunner`
- identity: the Echo who becomes true through concealment, exact timing, and unseen approach, acting at the break in the weave
- system tags: stealth, misdirection, surgical strike, quiet watchfulness, hidden intervention
- strongest pull: `Opportunist`
- secondary pull: `Skeptic`
- Standing-3 short description: moves through concealment, timing, and unseen openings

Important distinctions:

- `Okomfo` knows the unseen through spirit, omen, and interpretation
- `Kra-Soro` navigates the field through path, distance, and movement
- `Sum-Okwanfo` enters through concealment, timing, and hidden approach
- `Onyamesu` should not collapse into a generic healer class; it is the communal anchor and sustaining-presence calling

Current calling-family structure:

- `Anchor`: `Okofor`, `Onyamesu`
- `Edge`: `Aduro`, `Sum-Okwanfo`
- `Sight`: `Okomfo`, `Kra-Soro`

These families should be understood as ways an Echo becomes, not only as combat-role groupings.

Current calling adjacency ring:

`Okofor <-> Aduro <-> Sum-Okwanfo <-> Kra-Soro <-> Okomfo <-> Onyamesu <-> Okofor`

This ring governs limited drift and synthesis.
The current design should not allow arbitrary movement into distant incompatible callings.

Current calling-lattice rule:

- the calling system uses a three-ring structure: Standing 3, Standing 6, Standing 9
- Standing 3 is the foundational recognition layer
- Standing 6 and Standing 9 should each expose a six-option window from the Echo’s current perspective rather than reopening the whole board equally

Current Standing-3 visibility rule:

- all six foundational callings should be visible and choosable
- the player should see:
  - the Echo’s preferred path
  - strongest compatibility
  - weakest compatibility
  - the Echo’s own pull or preference
- the Keeper may choose any of the six, but poor fit should create visible emotional and behavioral strain

Current Standing-6 drift rule:

- Standing 6 is limited drift, not a full reset
- from the Echo’s current calling, the available Standing-6 options are built from:
  - the current calling
  - the left-adjacent calling
  - the right-adjacent calling
- each of those three sources contributes two Standing-6 expressions
- total visible options at Standing 6 = 6

Current Standing-9 rule:

- Standing 9 should use the same broad structural logic as Standing 6
- from the Echo’s current Standing-6 position, the system again exposes a six-option window based on deepening and adjacent synthesis
- the movement rule should stay local rather than opening into arbitrary full-board reclassification
- Standing 9 remains calling culmination and adjacent synthesis, not mythic status

Current drift and steering rule from `Uncalled`:

- `Uncalled` means unresolved direction, not emptiness
- the system should track:
  - dominant vector
  - secondary vector
  - core traits
  - archetype
  - emotional history
  - role and duty repetition
  - bond history
  - Thread history
  - directive exposure
- from that, the system computes:
  - strongest calling pull
  - secondary compatible pulls
  - strained but possible pulls
- drift is what happens if the Keeper does not deliberately shape the Echo
- steering is what the Keeper does through jobs, directives, party role, bonds, Threads, tools, and emotional management to bias that outcome without instantly overriding it

Current choice outcome direction:

- preferred path chosen -> coherence boost, better morale stabilization, and cleaner identity consolidation
- compatible alternate chosen -> workable friction and slower stabilization
- weak-fit or least-fit path chosen -> stronger emotional strain, slower recovery, more hesitation or refusal, and higher incident pressure

Current Standing-6 expression set:

#### From `Okofor`

- `Ɔkyɛfo Kɛseɛ` / `Great Ward`: deepening expression of larger-scale protection, interception, and safeguarding
  - descriptor line: deepens into greater protection and wider safeguarding
- `Asa-Ɔkyɛfo` / `Storm Guard`: outward-leaning expression where protection hardens into forceful answer and counter-pressure
  - descriptor line: hardens protection into forceful answer and counter-pressure

#### From `Aduro`

- `Asafo`: deepening expression of war-company momentum, collective courage, and escalating battlefield force
  - descriptor line: deepens into collective courage and war-company momentum
- `Twaesɛ` / `Splitfang`: outward-leaning expression of timing, disruption, and cracking openings through applied force
  - descriptor line: turns force toward disruption, timing, and opening-breaking

#### From `Sum-Okwanfo`

- `Ntontamfafo` / `Web-Passer`: deepening expression of web-path movement, concealment, and unseen passage
  - descriptor line: deepens concealment into web-path mastery and unseen passage
- `Sunsum Ahoma` / `Shadow Thread`: outward-leaning expression of sabotage, hidden intervention, and surgical disruption
  - descriptor line: leans into sabotage, hidden intervention, and surgical disruption

#### From `Kra-Soro`

- `Ɔkwansoani` / `Pathfinder`: deepening expression of route mastery, recon precision, and adaptive field intelligence
  - descriptor line: deepens field-reading into route mastery and recon precision
- `Wiemhwɛfo` / `Sky Watcher`: outward-leaning expression of anticipation, range control, and reading movement before it resolves
  - descriptor line: turns field sense toward anticipation, range control, and far-seeing watch

#### From `Okomfo`

- `Kranimfo` / `Spirit Knower`: deepening expression of omen authority, spirit-reading, and hidden-truth interpretation
  - descriptor line: deepens spirit-reading into omen authority and hidden-truth knowing
- `Ogyafo` / `Flame Keeper`: outward-leaning expression of ritual stabilization, threshold reading, and sacred procedural control
  - descriptor line: turns insight toward sacred thresholds, ritual control, and keeping the flame

#### From `Onyamesu`

- `Opanyin` / `Elder`: deepening expression of social root, communal memory, and moral authority
  - descriptor line: deepens care into communal memory, moral weight, and elder presence
- `Sunsum Kyerɛ` / `Soulbinder`: outward-leaning expression of tending the threshold between living, dead, memory, and rite
  - descriptor line: turns sustaining care toward memory-binding, threshold tending, and the living-dead bridge

Current Standing-9 culmination set:

- from `Ɔkyɛfo Kɛseɛ`:
  - `Nyamedua Ɔkyɛfo` / `Nyamedua's Ward`
  - `Grove Bastion`
- from `Asa-Ɔkyɛfo`:
  - `Storm Crown`
  - `War-Ward Sentinel`
- from `Asafo`:
  - `Asante Ɔhene Kɔbɔ` / `Asante War-Chief`
  - `Asafohene` / `War Captain`
- from `Twaesɛ`:
  - `Red Fang`
  - `Web-Cleaver`
- from `Ntontamfafo`:
  - `Veiled Passage`
  - `Hidden Web`
- from `Sunsum Ahoma`:
  - `Shadow Web`
  - `Whisper Knot`
- from `Ɔkwansoani`:
  - `Sankofa Wanderer`
  - `Far Road Captain`
- from `Wiemhwɛfo`:
  - `Star Watch`
  - `Horizon Judge`
- from `Kranimfo`:
  - `Spirit Sage`
  - `Memory Listener`
- from `Ogyafo`:
  - `Ananse Kasa` / `Anansi's Voice`
  - `Flame of Thresholds`
- from `Opanyin`:
  - `Abosom Tena Hɔ` / `Abosom Anchor`
  - `Root Elder`
- from `Sunsum Kyerɛ`:
  - `Samanfo Nkyɛn` / `Ancestor Vessel`
  - `Bridge of Names`

Current Standing-9 matrix rule:

- from the current Standing-6 path, the player should again see 6 local options
- those 6 options are built from:
  - 2 culmination options from the current Standing-6 path
  - 2 from the left-adjacent Standing-6 path
  - 2 from the right-adjacent Standing-6 path
- this preserves unique calling ladders for individual Echoes while keeping drift local and readable

Current Standing-9 naming note:

- the Standing-9 structure is now locked
- several Standing-9 names are good enough to work with now, but some remain subject to later refinement
- this should not block the calling lattice from being treated as structurally settled

Current Standing-9 naming rule:

- final high-end naming should be Akan/Twi-facing first, with English used mainly as scaffold
- every final English-facing high-end name should have a Twi-facing counterpart by ship
- naming mode should be branch-specific rather than globally uniform
- final names should feel like titles, relations, or epithets the world of Echoes would actually speak
- avoid generic fantasy noun-pairs where possible
- avoid overclaiming direct proxy language around Anansi
- avoid objectifying container language for mythic elder or threshold identities
- do not create new Twi-facing names through crude literal back-translation from English
- where Twi is not yet settled, the English scaffold can remain provisional, but the Twi side should be marked as needing proper linguistic and cultural validation

Current branch-style direction:

- stealth / web branches should lean first toward sabotage and disruption, second toward unseen passage
- path / watch branches should lean first toward route mastery, second toward far-seeing witness
- spirit / rite branches should remain mixed by sub-branch, but each path should have one dominant sacred-relation mode

Current calling-selection UI direction:

- the calling screen should remain a simple overlay rather than expanding into a full planner screen
- it should feel like recognition and consequence, not class optimization

Current Standing-3 overlay rule:

- show 6 calling options
- each option should display:
  - calling name
  - short description
  - compatibility state
  - Echo preference marker when relevant
- current Standing-3 compatibility language:
  - `Strong Pull`
  - `Near Fit`
  - `Distant`
  - `Resisted`

Current Standing-6 and Standing-9 overlay rule:

- keep the same six-option overlay structure
- each option should display:
  - calling name
  - short description or descriptor line
  - fit state
  - Echo preference marker when relevant
  - one prose line describing deepening or drift direction
- current Standing-6 and Standing-9 fit language:
  - `Natural Deepening`
  - `Open Drift`
  - `Strained Drift`
  - `Ill-Fitted`

Current UI communication rule:

- use prose and direction rather than numbers
- the player should understand what the Echo is being pulled toward, what feels safer, and what may create strain
- do not expose raw formulas, exact weight values, or full hidden compatibility math

Skills are not merely combat tools.
They are remembered techniques, disciplines, or expressions of recovered identity.

### 6. Expressed Will

This is the Echo’s ability to act as a person rather than a fragment.

It answers:

- how clearly the Echo can choose
- how consistently they can refuse
- how strongly they can follow conviction
- how much their autonomy feels like character rather than noise

This is where behavior, refusal, emotional reaction, and situational choice become meaningful.

At low wholeness:

- behavior is unstable
- reactions are shallow or inconsistent
- refusal is blunt or underdeveloped

At higher wholeness:

- preferences sharpen
- refusals become more intelligible
- emotional reactions feel earned
- choices reveal personhood

An autonomous Echo should become more interpretable and more willful as wholeness rises.

## 11.5 System mapping to current vNext work

The wholeness model should steer the systems already in the codebase as follows:

### Storyweight, Step, Standing

- mapped to **Recovered Story**
- represent reclaimed and integrated story, not generic grind progress
- current player-facing progression language should be:
  - `Storyweight` = the main visible growth spine
  - `Standing` = the major maturity threshold currently tracked internally as rank
  - `Step` = the sub-progress within a Standing currently tracked internally as level
- each Standing should contain `5 to 10` Steps
- each Step is made from Storyweight gain and should be visible to the player rather than treated as a purely hidden internal value

### Trait drift at Standing gain

- mapped to **Recovered Story + Shaped Direction**
- recovery changes the self; it does not only add power

### Vectors

- mapped to **Shaped Direction**
- express the emerging direction of selfhood

### Bonds / social graph

- mapped to **Living Bonds**
- social ties complete, pressure, or distort the self

### Callings

- mapped to **Claimed Calling and Knowledge**
- should feel like identity consolidation, not only role assignment

### Skills

- mapped to **Claimed Calling and Knowledge**
- remembered techniques unlocked by a more coherent self

### Vows

- mapped primarily to **Expressed Will**
- vows give structure, pressure, and moral shape
- they can stabilize or strain wholeness depending on fit

### Behavior / refusal / autonomy

- mapped to **Expressed Will**
- should become more specific and readable as wholeness grows
- autonomy should not simply diminish as an Echo matures; it should change shape with wholeness

Current behavior / autonomy direction:

- directives are party-wide intent, not direct obedience
- Keeper pings are temporary recipient-scoped influence, not direct obedience and not a second behavior system
- each Echo filters that intent through traits, bonds, fear, morale, calling pressure, and current instability
- most autonomy friction should modify planned action rather than replace it
- player-facing incoherence should be foreshadowed before a run and paid off more clearly under pressure during battle or crisis

Current refusal texture:

- the most common refusal forms should be hesitation, delay, safer substitution, and warped execution
- hard refusal should remain regular enough to matter, but it should not be the default texture
- hard refusal should be most credible under:
  - extreme fear
  - severe morale collapse
  - calling or identity contradiction

Current pressure roles:

- `fear` should shape immediate threat response
- `morale` should shape follow-through, persistence, and recovery
- `bonds` should bend priorities toward protection, rescue, and emotional reaction
- `calling` should create identity-consistency pressure around what feels right or wrong for this Echo to do

Current priority direction under pressure:

- this should be state-sensitive rather than globally fixed
- lower-wholeness or more unstable Echoes should be interrupted more often by fear and bond pressure
- higher-wholeness Echoes should be more likely to let calling / identity consistency lead
- when identity consistency wins over fear, it should most often read as calm refusal or sacrificing tactical correctness for role-truth rather than simple recklessness

Current bond-impact direction:

- strong bonds should first change guard, intercept, and protective intervention behavior
- secondary effects should include repositioning, morale spikes or collapse, and altered target priority
- full abandonment of the directive to rescue another Echo should happen sometimes, not constantly

Current self-initiated behavior direction:

- self-initiated behavior should be common enough to make Echoes feel willful, but not so common that player influence collapses
- the dominant early-to-mid behavior families should include:
  - pursuing clues or omens
  - settling rivalries or starting confrontations
  - withdrawing or self-preserving
  - overperforming a duty
  - chasing status or recognition
- later wholeness should not erase autonomy, but should mature it toward:
  - guidance
  - teaching
  - hierarchy conflict
  - stronger institutional or role-shaped expression

Current pre-run readability direction:

- party incoherence should be shown before departure through short warning phrases plus prose
- the internal autonomy-readiness ladder can remain something like:
  - aligned
  - strained
  - hesitant
  - refusing
- this ladder should remain hidden and should support warning language, not replace it on the player-facing surface

The pre-run autonomy-readiness ladder and the in-combat ping-response vocabulary are related but distinct. `aligned / strained / hesitant / refusing` is a hidden forecast of party coherence. `Align / Interpret / Hesitate / Object / Refuse` is an event-local, player-facing explanation of how one Echo fixed as a recipient when the ping is confirmed responds to that ping. A ping response is not a permanent personality label, a new emotion tier, or an obedience score.

### Hidden maturity-expression layer

The current build has implementation-facing behavior scaffolding that should be retained in concept, but re-framed in this GDD.

This should **not** be treated as a separate named player-facing system.
It is part of Echo behavior.

Implementation note:

- older code terminology such as `smartness` should be treated as temporary implementation language, not as final design language

Current design rule:

- Echoes should have a hidden maturity-expression layer derived from the whole weave of the self rather than from a separate level-up track
- this layer should manifest in both Sanctum and Realm behavior
- `Standing` is the main maturity gate for how strongly this layer can assert itself
- this layer should not be framed as generic combat intelligence or passive-perk accumulation

This hidden layer currently has two internal outputs:

- `Judgment`: how strongly the Echo can hold, interpret, and assert self under pressure
- `Presence`: how strongly that current state presses onto nearby or bonded others

Current direction:

- low-Standing Echoes should feel more externally authored
- high-Standing Echoes should feel more internally authored
- higher Standing should not mean more obedient, more tactically optimal, or more generally compliant
- it should mean more self-command, more interpretation, more opinion, and more consequence when identity is crossed
- higher-Standing Echoes should be less casually swayable by noise, but more sharply affected by true contradiction

This layer should be derived primarily from:

- Standing and Storyweight maturity
- archetype
- trait balance
- calling family and calling accent
- bonds and rivalries
- vow state
- fear and morale
- current instability / distortion pressure

Current response ladder when pressure and identity clash:

1. internal strain
2. objection or request for adjustment
3. reinterpretation
4. fallout if overruled
5. refusal or break

This ladder should apply in both Sanctum and Realm.

Current response texture:

- outright refusal should exist, but should not be the default first response
- some Echoes should enter the ladder more bluntly than others, but bluntness should not bypass the ladder entirely
- higher-Standing Echoes should try to assert interpretation before they simply defy
- if there is time and social room, objection or request for adjustment should come before divergence
- if there is no time, or the contradiction is too severe, divergence can occur directly

Current Sanctum direction:

- higher-Standing Echoes should be more likely to resist poor-fit duty, role misuse, or repeated disrespect
- the most common first outputs should be friction, commentary, mood shift, incident pressure, bond strain, or sharper role assertion
- explicit refusal should become most credible when mismatch is repeated, degrading, vow-contradictory, or socially insulting
- if things go against the Echo's identity truth, the consequence should land harder than it would for a less-formed Echo

Current Realm direction:

- directives remain party-wide intent, not direct control
- Keeper pings remain temporary tactical emphasis layered onto the active Directive; they never guarantee an exact action
- higher-Standing Echoes should be more willing to ask for adjustment, object, or reinterpret rather than silently obey
- most contradiction should first appear as reinterpretation, hesitation, substitution, or altered emphasis
- full refusal mid-run should remain possible under severe identity mismatch, vow contradiction, bond emergency, collapse, or extreme fear
- occasional Keeper-facing prompts, reactions, or adjustment requests during stage exploration and encounters are valid, but should remain high-signal rather than constant

Current in-combat guidance direction:

- only Echoes fixed as recipients when a ping is confirmed evaluate that ping
- each affected Echo independently produces `Align`, `Interpret`, `Hesitate`, `Object`, or `Refuse`, with one clear primary reason for every result other than `Align`
- the response appears immediately before the affected Echo's activation turn, and the first movement or action on that turn must provide visible evidence of following, reshaping, resisting, or rejecting the guidance
- active Directive, guidance, Calling, fear, morale, bonds, Standing, maturity expression, current danger, objective pressure, and hazard exposure resolve through one deterministic behavior authority
- higher Standing means more coherent judgment and self-assertion, never increased obedience

Current Presence direction:

- Presence should work mainly through proximity, relationship, and social weight rather than as a flat global aura
- it should be strongest across bonds, rivalries, role proximity, and house standing
- Presence should be able to stabilize, steady, and clarify others
- Presence should also be able to spread rivalry pressure, pride, dread, hesitation, or social fracture when the Echo is in a bad state

Current calling-family behavior grammar:

- `Anchor` should bias steadiness, protection, burden-taking, continuity, and holding
- `Edge` should bias initiative, breach, pursuit, decisive redirection, and forceful commitment
- `Sight` should bias interpretation, warning, omen-reading, hidden-truth response, and knowledge-shaped caution or insistence
- specific callings should color this grammar, not replace it with large bespoke passive kits

Current scope rule:

- this layer should primarily shape behavior selection, directive interpretation, refusal thresholds, social spillover, incident shaping, and aftermath/emotional consequence
- it should not become a broad hidden stat-bonus tree
- later design passes may allow this same hidden maturity-expression layer to influence Weaving and ritual interpretation outcomes, but it should remain part of behavior rather than becoming a separate surfaced meter
## 11.6 Wholeness is social, not only individual

An Echo should not become whole by solo stat growth alone.

Wholeness should require some combination of:

- recovered story
- repeated action under pressure
- social recognition
- chosen role
- tested conviction

This is why Sanctum interplay must matter.

The player should feel:

- I am not just upgrading an Echo
- I am helping an Echo become someone

## 11.7 What a “whole” Echo is

A whole Echo is not a finished human being in an absolute sense.

A whole Echo is one whose layers have become meaningfully integrated.

That means:

- enough story has been recovered to support a coherent self
- their vector is legible
- their bonds matter and are not interchangeable
- they have claimed a calling
- their skills feel like their own
- their autonomy expresses a recognizable person

At this stage, the player should be able to describe the Echo as someone, not just as a build.

## 11.8 What makes an Echo mythic

A mythic Echo is not just:

- max Step progression
- max Standing
- top stats

Those are necessary progression conditions, but not sufficient design conditions.

A mythic Echo should be one whose wholeness has become powerful enough to affect the wider house, future Echoes, and the player’s memory of the run.

Mythic status should require:

- deep recovered story
- strong directional coherence
- socially meaningful bonds
- a fully claimed role
- tested will under real stakes
- at least one defining remembered act

A mythic Echo should feel like:

- a legend in the making
- a recovered story now capable of shaping other stories

Current mythic direction:

- mythic status is not ownership
- mythic status is not a simple Standing gain
- mythic status is social recognition of a cohered self

Mythic Echoes remain people with agency.
They are not upgraded property of the Sanctum.

### Recognition, not automatic promotion

Mythic status should not fire automatically the instant hidden criteria are met.

Current direction:

- an Echo may become mythic-ready through their lived growth
- that readiness should open the possibility for a formalizing rite followed by house recognition
- the final transition should be social and ceremonial rather than purely invisible
- the Keeper should be able to steer or propose recognition, but not force the final shape alone

This should feel closer to recognition than to a checkbox reward.

### Current mythic flow

The working mythic transition should use a multi-step structure:

1. `mythic-ready`
2. `recognition proposed`
3. `rite undertaken`
4. `house recognition offered`
5. `affirmation or failure`

Current direction:

- mythic readiness is not visible promotion by itself
- the normal path should combine a formal rite with social confirmation from the house
- the offered form of recognition should reflect what the Echo actually became, not just what the Keeper prefers
- recognition can be redirected toward a different rite, office, or house shape if the first proposal is wrong
- mythic recognition should be able to fail even if the Echo accepts the rite and the house attempts recognition

Current likely failure causes:

- the house recognized the wrong shape
- the Echo accepted, but the self is not stable enough to hold that recognition
- unresolved contradiction remains between the Echo's becoming and the communal role being offered
- institutional or multi-mythic pressure destabilizes the transition
- the Echo's defining story is strong, but not yet integrated enough to sustain mythic affirmation

### Baseline mythic requirements

Beyond simple progression metrics, mythic readiness should require:

- minimum Storyweight and mature wholeness
- a strong signature virtue or strong signature pair
- socially meaningful bonds and house footprint
- a fully claimed role or calling path
- tested will under real stakes
- at least one defining remembered act in Realm or Sanctum life
- no severe unresolved active distortion

Mythic Echoes may still carry scar tissue from earlier distortion.
What they should not carry is severe unresolved distortion still dominating the self.

### Mythic recognition can be refused

Not every Echo who becomes mythic-ready should accept the house’s recognition automatically.

Current direction:

- the Echo can refuse if the Sanctum tries to formalize them in the wrong shape
- the house must recognize what the Echo actually became, not just what the Keeper wants to celebrate
- failed recognition should reveal mismatch between house culture and Echo selfhood rather than reading as a bug or edge case
- the most common correction path after refusal or mismatch should be:
  - perform a different rite
  - offer a different office or recognition frame
  - reshape house custom or institution support first and try again later

This matters because mythic status is supposed to affirm personhood, not flatten it.

### Rarity target

Mythic status should be a meaningful long-run payoff, but not a guaranteed run output.

Current direction:

- a full run can validly end with no mythic Echoes
- one mythic Echo in a strong run should feel substantial
- multiple mythic Echoes in a single house should be possible but rare

If mythic status becomes expected every run, it loses cultural weight.
If it becomes nearly impossible, it stops being a real endpoint design.

### Life after becoming mythic

Mythic Echoes should remain playable, but not simply as “the best unit.”

Current direction:

- mythic Echoes should become more self-directed
- they should carry stronger office, rite, or symbolic obligations
- they should not be freely deployable without cost or social consequence
- they should face some risk of estrangement from ordinary Echo life because of their elevated status

Current burden direction:

- stronger social obligation should be the main meaning layer of mythic status
- stronger institutional pressure and rivalry should be the next major burden
- deployment cost should be the main anti-"best unit forever" control
- deployment cost should be expressed as a combination of:
  - house strain or institutional disruption
  - practical resource cost such as `Ase`
- mythic Echoes should remain usable, but ordinary day-to-day deployment should be meaningfully restricted unless the situation justifies it

This helps keep mythic status from collapsing into pure power inflation.

### Departure risk

Mythic Echoes should be able to leave if the house no longer fits what they became.

Current likely causes:

- mismatch between the Echo’s realized self and the house’s direction
- neglect
- being treated as a tool instead of a person

This should be part of the stewardship burden.
The player is not merely collecting legends.
They are sustaining a house those legends may still choose to belong to.

### Mythics in relation to each other

Multiple mythic Echoes can exist in one house, but they should create pressure by default rather than automatic harmony.

Current direction:

- mythics can be nurtured toward harmony or rivalry through rites, offices, and house culture
- multiple mythic presences should create strong social and institutional pressure
- this pressure should be legible and manageable, not pure chaos

Current multi-mythic pressure direction:

- the dominant default tension should be competing house-shape pressure
- office or authority overlap should be the next strongest default tension
- symbolic rivalry should still occur, but it should more often be an expression of deeper house-shape conflict than the whole point by itself

### Mythic function in the overall game

A mythic Echo should most strongly do two things:

- become a powerful anchor in party and society behavior
- unlock a unique rite-path variant or office expression

Narratively, their deeds should become:

- templates
- warnings
- stories told inside the Sanctum

That is how mythics should reshape future life without becoming runaway “best unit forever” outcomes.

## 11.9 Design constraints for implementation

The wholeness model must not create an unreadable tangle of hidden variables.

So the design rule is:

- multiple layers in simulation
- a compact readable surface in UI

The player does not need to see every number.
But the player must be able to understand:

- what an Echo is missing
- what is being recovered
- why the Echo is changing
- why the Echo behaves differently now

## 11.10 What this means for future sections

The next design sections should use the wholeness model as the organizing spine.

That includes:

- core loop
- recurring player decisions
- Sanctum role definition
- Realm reward structure
- calling design
- bond design
- vow design
- mythic ascension

Wholeness is now the main conceptual bridge between:

- story
- progression
- autonomy
- attachment
- system interplay

---

# 12. The Weave System

The **Weave** is the umbrella progression and identity system connecting:

- story recovery
- Echo growth
- Sanctum growth
- Realm reward structure
- social shaping
- distortion and contradiction

It is the main system that turns the game’s themes into playable structure.

## 12.1 Core terms

### Storyweight

`Storyweight` is the main visible progression spine for an Echo.

It replaces generic XP in the player-facing design.

Storyweight represents the growing narrative and personal mass of an Echo:

- recovered story
- lived experience
- interpreted meaning
- increasingly coherent personhood

It should feel like:

- this Echo is becoming more real
- this Echo is carrying more of a self
- this Echo matters more in the world

### Threads

`Threads` are recovered story-fragments crystallized from Realm recovery.

A Thread is not generic loot and not a miniature NPC.
It is a singular, scarce fragment of remembered story tied to the virtue of the Realm where it was recovered.

At the fiction level, Threads are part of the world’s stolen remembrance:

- memories
- legends
- cultural inheritance
- fragments of personhood and meaning that belong in living people and living society

At the system level, a full Thread is:

- Realm-aligned and virtue-aligned
- singular rather than stackable
- held in reserve until used
- assignable only through ritual and interpretation
- able to integrate cleanly, partially, falsely, or in distorted form

Important structure:

- stages do not award full Threads directly
- stages contribute to Realm recovery
- Realm completion crystallizes full Threads from that recovery

This keeps Threads rare enough to matter while still letting the player feel story recovery building across the Realm arc.

### Continuity

`Continuity` is the Sanctum’s growth spine.

If Echo progression is becoming a person, Sanctum progression is becoming a society.

Continuity measures the rootedness and cultural maturity of the house through:

- rituals
- vow adherence
- recovered Threads brought home
- relationship growth
- Echo presence and social density

Continuity should not feel like generic base level.
It should feel like the house becoming more established, more patterned, and more culturally alive.

## 12.2 High-level structure

The Weave currently has three progression layers:

- **Echo progression:** becoming a person
- **Sanctum progression:** becoming a society
- **Realm progression:** recovering the stolen stories that feed both

This is the current locked structure.

## 12.3 Progression model choice

Echoes uses a hybrid progression model:

- one visible main progression spine
- several shaping tracks underneath

### Visible spine

For Echoes, the visible spine is `Storyweight`.

### Shaping tracks underneath

Other systems still shape what growth means:

- bonds
- vectors
- fear and morale history
- vows
- callings
- skills
- recovered and distorted Threads

The player should feel a clear sense of progression without having perfect transparency into every shaping force.

That ambiguity is intentional.

---

# 13. Thread Domains and Structure

Threads are Realm-aligned and virtue-aligned.

They should stay consistent with the ten Realm virtues from the original design direction.

## 13.1 Current Thread domains

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

## 13.2 What a Thread is as a design object

A Thread is a symbolic story-fragment with a small, readable payload rather than a fully authored story object.

Not every Thread needs to expose a complete literal story.
A short prose fragment plus tags is enough.
Prose can be reused across multiple instances if the state and implication differ.

Each full Thread should carry a compact mandatory payload:

- domain / source Realm
- one expression family within that virtue
- intensity
- corruption / distortion pressure

Optional flavor surface can include:

- a short prose fragment
- state tags
- signs of contamination, instability, or incompleteness

Effect structure should stay constrained.
A Thread should usually produce:

- one primary expression in its virtue domain
- up to two limited secondary spillovers into related parts of the Echo’s Weave

It should not behave like a freeform cloud of broad stat changes.
If Threads affect everything at once, compatibility, distortion, and readability all collapse.

## 13.3 Expression families within a virtue

Each virtue domain should contain a small set of recurring expression families.

Current direction:

- roughly 3 to 5 expression families per virtue
- same-domain Threads can therefore be meaningfully different from each other
- Echo compatibility should depend partly on which expression family a Thread carries, not only the virtue label

Example:

- two Courage Echoes may both want Courage Threads
- one may resonate with standing fast under fear
- another may resonate with protective boldness or reckless forward action

This is important.
It prevents the virtue domains from becoming flat buckets while still keeping them readable.

## 13.4 Why Threads are Realm-aligned

Keeping Threads aligned to Realms gives Realms stronger identity and replay value.

This means:

- replaying a Realm is a deliberate pursuit of a Thread type
- each Realm restores a distinct category of personhood
- each Realm also pressures or destabilizes a distinct category of personhood

Realms are therefore not just content buckets or emotional biomes.
They are sources of specific self-restoring and self-testing material.

## 13.5 Virtue pattern

Each Thread domain should do two things:

- restore one part of selfhood
- pressure one failure mode, contradiction, or distortion tendency

This keeps virtues from becoming one-note positive upgrades.

## 13.6 Current restore / pressure direction

### Courage

- Restore: resolve, action under fear, risk tolerance
- Pressure: recklessness, overreach, defiant pride

### Wisdom

- Restore: discernment, interpretation, patience, judgment
- Pressure: hesitation, emotional distance, over-analysis

### Leadership

- Restore: responsibility, guidance, social steadiness, influence
- Pressure: control, ego, burden, domination

### Acceptance

- Restore: grief processing, surrender to reality, peace with loss
- Pressure: passivity, fatalism, premature surrender

### Humility

- Restore: perspective, teachability, respect for limits and others
- Pressure: self-erasure, timidity, reduced self-worth

### Forgiveness

- Restore: release, repair, continuation after harm
- Pressure: naivety, repeated injury, unresolved resentment

### Truth

- Restore: clarity, self-recognition, honesty, reality contact
- Pressure: shame, rupture, unbearable revelation

### Generosity

- Restore: offering, reciprocity, communal orientation, trust
- Pressure: depletion, exploitation, self-neglect

### Compassion

- Restore: care for suffering, tenderness, protective warmth
- Pressure: exhaustion, over-identification, refusal of necessary hardness

### Empathy

- Restore: attunement, emotional understanding, relational recognition
- Pressure: blurred boundaries, emotional contagion, indecision

These are current design anchors, not final tuning.

## 13.7 Working virtue affinity map

The virtue domains should not behave as isolated buckets.
They need a hidden relation map so that Threads, vectors, callings, archetypes, bonds, and distortion all pull in the same broad direction.

This map is for system logic and design coherence first.
It is not meant to be shown to the player as a solved chart.

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

This order is a working affinity ring, not a final public-facing canon object.
It exists so that the hidden model can reason about:

- adjacency
- balancing tendencies
- strain distance
- overgrowth
- distortion and remedy

Current interpretation rules:

- the same virtue is the strongest direct fit, but also carries the highest overgrowth risk when stacked repeatedly
- adjacent virtues are the most common non-identical affinities and the most common balancing or remedy paths
- virtues two steps away are compatible but more conditional
- virtues on the opposite side of the wheel are high-risk counterweights that can mature stable Echoes but often strain unstable ones

Current opposite-pair tensions:

- Courage <-> Acceptance
- Leadership <-> Forgiveness
- Truth <-> Compassion
- Wisdom <-> Empathy
- Humility <-> Generosity

These oppositions should not be treated as simple hard counters.
They are tension pairs.
A stable Echo may benefit from an opposite-side correction that would distort or destabilize a fragile Echo.

## 13.8 Hidden virtue temperament profile

The wheel should feed a hidden virtue temperament profile for each Echo.

This profile should be derived from several existing and future systems together rather than from any one stat line alone:

- core traits
- vectors
- calling
- archetype
- prior Thread history
- bonds and rivalry patterns
- fear and morale history
- recent Realm experiences
- current role and obligations in the Sanctum

This is the synthesis layer that keeps the design from fragmenting into disconnected subsystems.

At a high level, each Echo should have hidden tendencies such as:

- anchor virtues
- balancing virtues
- risk virtues
- current instability around certain virtue domains

The player should not see the full profile directly.
The game should surface it indirectly through:

- ritual clues
- Sanctum events
- behavior
- dialogue
- changing compatibility signals over time

---

# 14. Thread Recovery and the Weaving Rite

The ritual through which Threads are offered to Echoes is called the **Weaving Rite**.

This should not feel like inventory assignment.
It should feel like interpretation, ceremony, and social consequence.

## 14.1 Realm recovery track

One Realm is active at a time.
The player does not run concurrent Realm arcs.

During that Realm, stages contribute to a single Realm recovery track for that domain.
This track is the in-progress state that will later crystallize into full Threads.

Important rules:

- stages do not drop full Threads directly
- each stage contributes a recovery segment to the active Realm track
- a stage always contributes something, even on a poor result
- an `F` stage result should create a broken or badly compromised segment rather than nothing
- special stage events can add a bonus segment

This is intentionally not a shard inventory.
The player is tracking the Realm’s recovery state, not hoarding tiny items.

## 14.2 Why partial recoveries are not inventory items

This creates:

- a stronger sense of Realm-scale recovery
- fewer meaningless sub-items in the player’s inventory
- room for quality and contamination to build across the Realm arc
- a cleaner bridge between stage performance and final Thread yield

If partial recoveries became standalone spendable objects, they would risk turning into a third currency.
That is not the goal.

## 14.3 Segment quality and Realm performance

The recovery track should use a segment-quality model rather than invisible points.

Current working direction:

- each stage contributes one segment to the Realm recovery track
- segment quality is shaped by stage performance
- better stage results improve clarity and yield potential
- worse stage results increase compromise, contamination, or instability

Current interpretation of performance:

- the existing stage and battle grading model can influence segment quality
- `S` to `A` results should support stronger or clearer segments
- low results should weaken segments
- an `F` result should produce a broken segment

Realm performance should also be affected by what happened during the run, not only the letter grade.
Deaths, collapse, contamination events, and other failures should contribute to lower recovery quality and higher distortion pressure.

## 14.4 From Realm recovery to full Threads

On Realm completion, the recovery track crystallizes into full Threads.

Current locked direction:

- a completed Realm produces 1 to 3 full Threads
- every completed Realm guarantees at least 1 usable full Thread
- poor completion should still return something, but likely weaker or more contaminated
- stronger completion can return 2 or 3 Threads
- all Threads produced by that Realm stay within that Realm’s virtue domain

Thread count should be driven primarily by hitting recovery thresholds on the track, not only by adding up hidden score.

The quality of the segments should shape the quality of the resulting Threads:

- intensity
- clarity
- corruption / distortion pressure

This is one of the main reasons the stage-to-stage Realm arc matters.
A bad Realm run should not only reduce quantity.
It should also change what kind of remembered material the player brings home.

## 14.5 Omen rites and preview use

Partial recovery can be used before Realm completion, but only in limited ways.

Current supported use cases:

- reveal stronger readiness clues for some Echoes
- perform a minor omen ritual or preview rite

Partial recovery should not be assignable as a half-Thread and should not produce permanent growth on its own.

Using omen or preview actions should create a real tradeoff:

- spend some recovery quality now to gain better information
- preserve recovery quality for stronger Thread yield later

Current direction for cost:

- stronger previews should cost more
- the cost should not create a separate currency
- instead, a preview should downgrade a random recovery segment by one quality step

That cost lets the player buy foresight at the price of final Thread quality or quantity.

## 14.6 High-level flow

1. The player enters a Realm and begins building that Realm’s recovery track.
2. Each completed stage contributes a recovery segment.
3. Optional omen or preview rites may spend recovery quality for information.
4. Realm completion crystallizes the track into 1 to 3 full Threads.
5. Those full Threads enter the Sanctum reserve.
6. During a Weaving Rite, one Thread is offered.
7. One or more Echoes may resonate with or contest that Thread.
8. The Keeper chooses which Echo receives it.
9. Integration resolves.
10. Echoes not chosen may react negatively if they strongly contested the Thread.

## 14.7 Threads in reserve

Only full Threads belong in reserve.
Partial recoveries belong to the active Realm track, not to the long-term inventory.

Reserve matters because:

- the player should not be forced to assign every Thread immediately
- readiness and context matter
- delayed interpretation is part of the design

Current reserve direction:

- reserve should feel limited, but not harshly punitive
- the base model should use one flat reserve cap rather than domain-specific storage
- later `Continuity` growth can provide a small number of reserve expansions
- stored Threads should remain mostly stable while in reserve

Reserve pressure should primarily feel like:

- spiritual unease and house tension
- secondarily, looming ritual urgency

Current storage-risk direction:

- Threads in reserve should not passively decay like normal inventory
- a strained or contaminated reserve can still generate warnings, incident pressure, or omen unease
- this should create tension without turning storage into constant attrition management

### Overflow direction

If the reserve is full when a new Thread would enter it, the game should not immediately auto-delete or auto-discard the Thread.

Current direction:

- the new Thread should enter a strained overflow state
- overflow should grant one `Sanctum pulse` of warning before stronger escalation begins
- the player should then be pushed toward a decision rather than being allowed to sit on overflow indefinitely

Current overflow escalation priority:

1. Sanctum unease or omen incident
2. increased contamination or reserve-strain risk
3. a Thread becoming harder to read or harder to weave safely

This keeps reserve pressure meaningful without turning it into abrupt inventory punishment

Still open:

- exact reserve capacity
- whether stored Threads can decay or attract contamination
- what exact storage UX best communicates state without clutter

## 14.8 Resonance and contest

A Thread may resonate with more than one Echo.

That means:

- multiple Echoes can want or be drawn toward the same Thread
- the Keeper must decide who receives it
- the decision can create resentment, sadness, rivalry, or destabilization in others

This is intentional.
Threads are not neutral upgrades.

Current compatibility priority should lean toward:

- social context, including bonds, rivalries, role pressures, and current house situation
- fear and morale state
- vector, calling, and archetype fit
- prior Threads and Storyweight maturity

This keeps the Weaving Rite grounded in who the Echo currently is in relation to others, not just in abstract build logic.

## 14.9 Detrimental effects for non-chosen Echoes

If an Echo strongly contests a Thread and is not chosen, they may suffer a negative consequence.

Current likely consequence categories:

- morale dip
- fear increase
- bond strain
- rivalry escalation
- temporary instability around similar future Threads

Current fallout direction:

- the most common non-chosen fallout should be social and emotional first rather than heavy numeric punishment
- bond strain and rivalry flare-up should be the most common outcomes
- morale dip or sadness should be the next most common outcomes
- temporary instability around similar future Threads should be present, but less common than direct social fallout
- acting out, refusal, or stronger downstream disruption should be rarer and should depend on personality and severity

Current timing direction:

- non-chosen fallout can surface immediately in the rite aftermath or later through a future `Sanctum pulse`
- immediate fallout is stronger for jealousy, hurt, or visible disappointment
- delayed fallout is stronger for resentment, instability, or cooled-over tension that mutates later

Exact tuning remains open.

---

# 15. Thread Integration Outcomes

When a Thread is offered through a Weaving Rite, the outcome is not binary.

The current five outcome states are:

1. Accept
2. Partially Integrate
3. Reject
4. Distort
5. Defer

These are part of the full system vision.
For the current foundation cutline, the reduced shipped outcome set is:

- Accept
- Reject
- Defer

`Partially Integrate` and `Distort` remain part of the full system vision and should be treated as later expansion work rather than removed conceptually.

## 15.1 Accept

The Echo takes in the Thread cleanly.

Effects:

- strong integration
- clear gain
- positive identity or behavior shift in the Thread’s domain

## 15.2 Partially Integrate

The Thread enters unevenly.

Effects:

- mixed or weaker gain
- friction remains
- the Echo changes, but not cleanly

Partially integrated Threads should persist until acted on.
They should not quietly self-correct over time.

Current direction:

- a Partial creates unstable or uneven growth around that virtue
- similar future Threads may become riskier in the short term
- proper remedy can later convert that instability into stronger future readiness

## 15.3 Reject

The Echo refuses the Thread.

Effects:

- no clean integration
- potential emotional or social consequence
- tells the player something meaningful about the Echo

Reject should not always be framed as a simple failure.

A rejection can mean:

- the Echo was too unstable to hold the Thread
- the Echo clearly understood that the Thread was not theirs

That second form of rejection is meaningful self-definition.
A more coherent Echo should sometimes be better at refusing the wrong story.

Current direction:

- the player sees only `Reject` as the top-level outcome
- the emotional reading of that rejection can still vary
- a rejected Thread is consumed rather than returned to reserve

## 15.4 Distort

The Thread enters, but in a warped form.

Effects:

- partial Storyweight gain
- malformed or redirected growth
- identity complication
- possible mutation of part of the Echo’s Weave

Distortion may:

- redirect growth
- alter interpretation
- shift vector temporarily or permanently
- create player confusion intentionally through partial ambiguity

The player should not always receive complete explanation.

Distort should not be treated as a rare edge-case failure.
It is a core recurring part of the Weave.

Current direction:

- contamination pressure should bias toward Distort
- overspecialization and same-virtue overgrowth should also bias toward Distort
- Distort can include real upside with dangerous consequences rather than being purely punitive

Distortion should come from constrained families tied to virtue and expression, not from broad unreadable randomness.

Current first-pass distortion family examples:

- Courage: bravado, compulsion to escalate, martyr spiral
- Wisdom: paralysis through over-reading, cold abstraction, manipulative certainty
- Leadership: domination, burden fixation, savior complex
- Acceptance: passivity, emotional numbing, surrender addiction
- Humility: self-erasure, deference lock, unworthiness spiral
- Forgiveness: boundary collapse, repeated exposure to harm, forced reconciliation
- Truth: fixation, exposure compulsion, shame collapse
- Generosity: depletion, transactional giving, self-neglect
- Compassion: over-identification, exhaustion, refusal of necessary hardness
- Empathy: emotional contagion, boundary bleed, indecision through too much attunement

Different causes of distortion should also have different texture.

- contamination distortion should feel foreign, misleading, and Anansi-tainted
- overspecialization distortion should feel overgrown, imbalanced, and self-bending

## 15.4.1 What distortion is allowed to touch

Distortion should not be allowed to mutate every system layer equally.
If it touches everything at once, it becomes unreadable and impossible to tune.

Current primary distortion targets:

- Thread expression
- morale and fear sensitivity
- combat and action tendencies

Current secondary spillover surfaces:

- dialogue tone
- bonds and relationships

This distinction matters.
Dialogue and relationship shifts should often be how the player feels distortion, but not always the deepest mechanical slot being mutated.

## 15.4.2 Distortion structure per event

Each distortion instance should usually create:

- one major warped effect
- up to two minor echoes

This keeps distortion legible enough to learn while still allowing it to feel alive and dangerous.

Internally, distortions should be named conditions.
The player does not need the system label in full, but the game should know what the distortion is.

Examples:

- Bravado
- Self-Erasure
- Cold Abstraction

## 15.4.3 Distortion severity and persistence

Distortions should have hidden severity tiers internally, even if the player does not see clean category labels such as `minor`, `major`, or `severe`.

The player-facing layer should instead use short atmospheric tags plus prose.

Current direction:

- the player should know that distortion occurred
- the player should not immediately know the full shape of that distortion
- severity should reveal itself through behavior, outcomes, and remedy difficulty over time

Persistence should differ by source:

- contamination or Anansi-based distortions can sometimes be softened or partially cleansed
- even when softened, contamination should usually leave a mark or scar
- overgrowth-based distortions should be more ingrained and not simply “fixed”
- overgrowth distortions are something the Echo must live with, adapt to, or mature around

## 15.4.4 Preferred remedy logic

Distortion remedies should stay context-dependent, but they should not be fully mushy.

Current direction:

- each distortion family should have one preferred remedy route
- each should also allow one or two secondary remedies
- context, relationship state, and current instability can still complicate the result

This keeps the system learnable without collapsing into a visible hard-counter chart.

## 15.4.5 Priority distortion families

The first implementation pressure-testing should focus on:

- Courage -> Bravado
- Humility -> Self-Erasure
- Wisdom -> Cold Abstraction

### Courage -> Bravado

Core warp:

- overconfidence
- escalation pressure
- refusal to yield

Likely player-facing surfaces:

- inflated self-reading
- excessive sparring
- role jealousy
- complaints about not being seen as central or important enough

Preferred remedy:

- Humility

Secondary remedies:

- Acceptance
- Wisdom

### Humility -> Self-Erasure

Core warp:

- shrinking the self out of rightful presence

Likely player-facing surfaces:

- withdrawal
- misreading status
- refusing credit
- over-serving without healthy self-position

Preferred remedy:

- Truth

Secondary remedies:

- Generosity
- Acceptance

### Wisdom -> Cold Abstraction

Core warp:

- interpreting others without remaining emotionally with them

Likely player-facing surfaces:

- relational chill
- subtle control from the back rather than overt command
- treating other Echoes like cases, problems, or patterns to manage

Preferred remedy:

- Empathy

Secondary remedies:

- Compassion
- Truth

This must remain distinct from distorted Leadership.
Cold Abstraction should control by distance, detachment, and interpretation, not by openly taking command.

## 15.4.6 Distortion in ongoing play

Distortion should affect lived play beyond the rite itself.

Current direction:

- it should bias role temptation and role risk rather than hard-locking Echoes out of battle, jobs, or duties
- it should influence battle barks, refusals, and shouts
- it should influence Sanctum events, especially confrontations, withdrawal, duty failure, or misguided overcommitment
- severe distortions should be able to trigger special Sanctum incidents

Softened contamination should leave a visible scar mark on the Echo’s sheet or history surface, even if the game does not fully explain it.

Badly contaminated Threads can still be woven.
They do not always need to be purified first.

Later Sanctum growth may add limited ways to improve Thread quality, stabilize risk, or soften contamination, but that should be an enhancement layer rather than a requirement for using the system at all.

## 15.5 Defer

The Echo is not ready to integrate the Thread yet.

Effects:

- no full integration now
- possible future readiness
- allows delay without forcing rejection or distortion

Defer should be the early-stop outcome.
It means the process halted before deep intake went too far.

Current direction:

- a deferred Thread is not consumed
- that Thread can still be offered to another Echo
- the Echo who deferred should keep a memory mark from the attempt
- future similar Threads should become easier to read for that Echo even if they are not guaranteed to integrate cleanly

## 15.6 Remedy and recovery direction

The game needs ways to respond to Partial and Distort outcomes without turning every problem into a clean reset puzzle.

Current primary remedy routes:

- balancing virtues
- Sanctum rites
- relationship care

These should do most of the work.
Changed duty, altered environment, and role shifts should usually be consequences of those remedies rather than standalone remedy systems.

Current working logic:

- the wheel is the main background source for balancing and remedy tendencies
- adjacent virtues are the most common balancing routes
- other systems layer on top and complicate or adjust the result
- not every wound should disappear cleanly
- some distortions should remain scars, tendencies, or part of the Echo’s future shape

---

# 16. Readiness, Resolution, and Ambiguity

The game should not show raw success percentages for Thread integration.

The player should read Echo readiness through clues, not exact formulas.

## 16.1 Why clue-based readability

This preserves:

- ambiguity
- player interpretation
- attachment through observation
- the challenge of actually knowing one’s Echoes

## 16.2 Rite phases: invitation and resolution

The Weaving Rite should have two readable phases:

1. invitation
2. resolution

This should not become a separate minigame where the player can freely back out once commitment starts.
The point is not to offer a cancel button.
The point is to give the player a readable emotional and interpretive arc.

Invitation phase purpose:

- surface live clues about this Echo and this Thread right now
- create dread, hope, and interpretive tension
- let the player sense whether the rite is leaning toward openness, resistance, instability, or stoppage

Resolution phase purpose:

- commit the outcome
- transform the Echo and the Thread state
- create aftermath and social consequences

Current commitment rule:

- once the rite has begun, it must be seen through
- the player may hope for Defer if the invitation phase reveals poor timing
- the player may not simply cancel without consequence

## 16.3 Hidden resolution order

The working hybrid logic should resolve in this order:

1. fit and resonance
2. state and readiness
3. distortion pressure

### 1. Fit and resonance

This asks:

- is this Thread aligned with the Echo’s virtue temperament profile
- is the expression family compatible with who this Echo actually is
- is this a meaningful fit, a balancing fit, a strained fit, or a false fit

### 2. State and readiness

This asks:

- can this Echo safely take this in right now
- is their current social and emotional state stable enough
- is the moment right, even if the fit is real

### 3. Distortion pressure

This asks:

- is contamination pushing this toward misleading intake
- is overspecialization or prior overgrowth bending the result
- is Anansi pressure nudging a false or dangerous resolution

This sequence is important because it keeps different failure types legible:

- fit problems tend toward Reject or Distort
- timing and state problems tend toward Defer or Partial
- strong fit with good state tends toward Accept

## 16.4 Current readiness factors and priority

Readiness and rejection should depend on a combination of factors, but not all with equal weight.

Current priority direction:

1. social context, including bonds, rivalries, recent conflict, and role pressure
2. fear and morale state
3. virtue temperament profile, including vector, calling, and archetype fit
4. prior Threads and Storyweight maturity
5. Anansi distortion pressure and current instability

This is deliberate.
The Weaving Rite should care first about who the Echo currently is in relation to others and to the house, not only about a hidden build sheet.

## 16.5 Outcome tendencies

The exact formulas remain open, but the current direction is:

- strong fit + decent state + manageable distortion pressure -> Accept
- strong fit + weak state -> Defer or Partial, with Defer generally more likely
- misaligned but stable -> Reject generally more likely than Distort
- misaligned + heavy contamination or false fit pressure -> Distort
- repeated same-virtue overgrowth can also bias toward Distort

This keeps Distort present and meaningful without letting it swallow every failed or strained rite.

Current foundation weighting with the reduced outcome set:

- `Accept` should be driven primarily by fit, with readiness as the secondary gate
- `Reject` should be driven primarily by poor fit, but strain should be able to harden or push a rejection
- `Defer` should be driven primarily by readiness and timing rather than by pure incompatibility

## 16.6 Player-facing clue surface

Instead of numbers, the player should receive ritual and behavioral clues during Weaving Rites.

Examples of clue language:

- Drawn
- Strong Pull
- Unsteady
- Resistant
- Contested
- Burdened
- Clear-Eyed
- Misaligned
- Trembling

Final wording remains open.

The important rule is:

- enough information to make a meaningful judgment
- not enough information to fully solve the system

Current clue-surface direction:

- the rite should use a small stable vocabulary rather than endlessly varying bespoke labels
- clue language should be organized into three buckets:
  - `fit`
  - `readiness`
  - `strain`
- each bucket should use roughly `4 to 5` stable terms at most
- those stable terms should be wrapped in short prose that reflects the tone and personality of the Echo involved
- foundation readability should make openness versus resistance reasonably legible without turning the rite into a solved prediction puzzle

Outside the rite itself, Thread state should still be made reasonably legible in reserve and on recovery tracks.
The player should be able to read state such as:

- intensity band
- compromise or contamination
- likely abundance or scarcity of recovery
- short prose fragment and tags

What should remain ambiguous is not whether a Thread is compromised.
What should remain ambiguous is what that Thread will mean when a specific Echo tries to live with it.

The underlying system can use more standardized hidden phase signals such as:

- open
- wavering
- guarded
- recoiling

But the player-facing layer should remain prose-driven rather than exposing those states directly as tidy UI labels.

Ritual clues should also be reinforced outside the rite through:

- Sanctum dialogue
- battle barks and shouts
- relationship behavior
- house events
- remembered Realm history

## 16.7 Weaving Rite aftermath

The rite should always communicate aftermath clearly enough that the player can learn.

Minimum aftermath surface:

- emotional reaction lines
- a result summary
- changed trait, vector, calling, or Weave indicators when applicable

Possible follow-on aftermath:

- relationship fallout
- rivalry flare-up
- care event
- lingering uncertainty

These follow-on consequences should not feel arbitrary.
They should be seeded by:

- contest intensity
- bond state
- outcome severity
- current social tension in the house

## 16.8 Repeated virtue Threads

An Echo can accept multiple Threads of the same virtue.

This should deepen the Echo’s relation to that virtue.

However, one-sided accumulation should not remain purely positive forever.

At some point, same-virtue concentration should:

- deepen
- intensify
- complicate
- destabilize if overcommitted

Rounded Echoes should generally be healthier and more coherent than single-track Echoes.

Current design arc:

### First major same-virtue investment: deepening

The first repeated investment in the same virtue should usually feel legitimate and strong.

This is not yet a warning sign.
It is the point where a virtue stops being a passing influence and starts becoming part of the Echo’s recognizable self.

Expected effects:

- stronger identity expression in that virtue
- clearer preference patterns
- stronger compatibility with Threads of that same virtue
- more obvious behavioral flavor in dialogue, decisions, and social presence

### Second major same-virtue investment: specialization

The second major investment should usually still be more safe than dangerous, but it should no longer feel neutral.

This is where the Echo becomes specialized rather than merely deepened.

Expected effects:

- stronger fit inside that virtue
- narrower compatibility outside that virtue
- more pronounced personality expression
- more obvious need for balancing support later

Current direction:

- the second same-virtue investment should still usually resolve as a valid growth path rather than an immediate mistake
- however, it should begin to load the Echo toward overgrowth risk if the player continues without balancing support

### Third major same-virtue investment: fork point

The third major investment in the same virtue should be the main danger threshold.

This is where the path forks:

- supported specialization can become disciplined mastery
- unsupported specialization bends toward overgrowth

Primary overgrowth pressures:

- narrowed compatibility
- social strain

Additional likely pressures:

- higher distortion risk
- stronger resistance to balancing virtues
- more brittle or extreme role expression

This threshold should matter because Echoes are not supposed to become better simply by absorbing more of the same story forever.
At some point, a virtue must either mature in relation to others or begin consuming the shape of the person.

## 16.9 What balancing support means

Same-virtue specialization should not be stabilized by one factor alone.

Current direction:

- adjacent or balancing virtues on the wheel
- stable bonds and relationship care
- low fear and decent morale

All three should matter.

This does not mean every stable Echo must look evenly distributed.
It means strong specialization needs supporting context if it is going to remain healthy.

Balancing support should often create:

- short-term friction
- adjustment difficulty
- temporary instability
- longer-term health and coherence if the process succeeds

This should be readable to the player as digestion and change, not as a mysterious random penalty.

## 16.10 Resistance to balancing Threads

A heavily concentrated Echo should sometimes resist the very balancing virtues they need.

Current direction:

- invitation-phase resistance should increase when the balancing Thread challenges an overgrown dominant virtue
- that resistance should not mean balancing is impossible
- successful balancing should feel harder in the short term but healthier in the long term

This matters because correction should be dramatic, not frictionless.
An Echo whose identity has overgrown around one virtue should not calmly accept every corrective Thread as if it were obvious medicine.

## 16.11 Visible player-facing consequences

Repeated same-virtue investment must be visible in lived play, not only in hidden compatibility math.

Most important visible signals:

- more extreme dialogue
- behavior drift
- job or duty obsession

Other valid surfaces:

- relationship tension
- ritual instability
- stronger reactions to certain Realm outcomes
- stronger refusal or attraction patterns during Weaving Rites

If the player cannot feel repeated virtue concentration socially and behaviorally, the system will read as spreadsheet tuning rather than person-shaping.

## 16.12 Relation to mythic shaping

Repeated virtue investment should contribute to mythic formation, but not by itself.

Current direction:

- mythic Echoes should have a strong signature virtue or a strong signature pair
- mythic Echoes should not have unresolved severe distortion
- pure overgrowth in one virtue should not be enough to become mythic

This is important.
Mythic status should not mean a lopsided maxed-out unit.
It should mean a culturally legible figure whose defining strengths have matured into a recognizable legend within the Sanctum.

In practice, this means:

- same-virtue repetition can help produce a signature
- balancing maturity prevents that signature from collapsing into brittleness or self-warping
- mythic Echoes should feel asymmetrical and memorable, not evenly distributed and bland

Mythic Echoes may still carry scar tissue from prior distortion.
What they should not carry is severe unresolved active distortion that is still dominating the shape of the self.

---

# 17. Fear and Morale in the Weave

Fear and morale are not only behavioral combat modifiers.

They also affect how Echoes process story, contradiction, and selfhood.

## 17.1 Fear

Fear should be able to:

- reduce readiness
- increase rejection
- increase distortion risk
- destabilize interpretation
- push an Echo toward false certainty, retreat, lashing out, or refusal

## 17.2 Morale

Morale should affect:

- openness to integration
- stability under conflicting input
- capacity to hold contradiction
- willingness to stay engaged in self-formation

High morale should support cleaner integration.
Low morale should make integration more fragile and unstable.

## 17.3 Why this matters

This prevents the game from becoming cozy or purely restorative.

Recovery is risky.
Growth is not always clean.
Some truths arrive at the wrong time.

---

# 18. Continuity: Sanctum Progression

`Continuity` is the current working name for the Sanctum’s progression spine.

If Echoes become persons, the Sanctum becomes a society.

## 18.1 What Continuity measures

Continuity measures the cultural and social establishment of the house through:

- rituals performed
- vow adherence
- recovered Threads brought home
- relationship growth
- Echo presence and social density

Current working direction:

- buildings should help make Continuity visible
- institutions should help make Continuity legible
- the Sanctum should gradually feel more like a living culture than a static hub

Primary emotional target:

- this place has history now
- Echoes belong to something larger than themselves

## 18.2 What Continuity should not be

Continuity should not read as:

- generic town hall level
- base XP
- pure building progression

It should feel like:

- more cultural depth
- more established patterns
- stronger institutions
- thicker communal memory
- a house that has become rooted and recognizable

### Player-facing meaning vs implementation meaning

For player-facing framing, `Continuity` should read as the Sanctum becoming rooted, culturally coherent, and socially real.

For implementation purposes, `Continuity` should be treated more bluntly as the Sanctum's primary progression resource:

- it functions as house `XP + level`
- it is one visible progression spine for Sanctum growth
- it gates unlocks for institutions, rooms, rites, offices, customs, and related house growth
- it should not be presented to the player as a generic base-XP meter even though it behaves that way structurally

## 18.3 Feed sources currently agreed

Current agreed sources feeding Continuity:

- recovered Threads
- relationship growth
- Echo presence and social density
- rituals and repeated house practice
- positive institution beats
- major Sanctum incident resolution
- stabilized customs and institutional patterns

Current priority order:

1. what stories are brought home
2. who lives in the house and how they relate
3. what the house repeatedly practices

This ordering matters.
The house should be shaped first by what remembered material it carries, then by the life built around that material, and only then by routine alone.

Current contribution profile:

- recovered Threads should provide the strongest single gains
- stabilized customs and institutional patterns should provide the next strongest gains
- major incident resolution should provide medium gains
- positive minor beats should provide small gains
- ambient routine alone should provide little to no direct gain unless it repeats long enough to become a recognizable pattern

## 18.4 One visible spine, hidden sublayers

Continuity should remain one visible progression value to the player.

Underneath that visible spine, the system should track hidden sublayers so the Sanctum does not flatten into one generic number.

Current hidden sublayers:

- Memory
- Social Fabric
- Institutional Pattern

### Memory

Memory tracks what stories have actually been brought home and retained.

This should be shaped by:

- recovered Threads
- Realm history
- remembered names
- story-bearing rites and archives

### Social Fabric

Social Fabric tracks whether the house actually lives as a society rather than as a storage place for units.

This should be shaped by:

- bonds
- rivalry management
- social density
- care patterns
- who meaningfully shares life with whom

Severe fragmentation should hurt this layer.
Ordinary tension should not.
The house does not need universal friendship to be culturally alive.

### Institutional Pattern

Institutional Pattern tracks whether the house has developed recognizable ways of doing things.

This should be shaped by:

- repeated rites
- offices and roles
- vow structures
- rooms and spaces used in culturally meaningful ways
- recurring customs and obligations

These sublayers are mainly for system logic and design coherence.
The player does not need all of them surfaced as full separate bars.

### Sanctum pulse

The house should not rely on Realm completion alone to surface meaningful life.

A **Sanctum pulse** is the pacing unit where accumulated house state is checked and surfaced.

Implementation meaning:

- a pulse is a state-check and surfacing tick for Sanctum life
- it is one of the major ways the house converts lived state into visible play
- it is not the only source of `Continuity`

A pulse may surface:

- ambient microbeats
- light warnings
- positive institution beats
- incidental events
- major incidents

Pulses can be triggered by:

- repeated pressure over time
- bond threshold crossings
- duty failure or overperformance
- institution strain or mismatch
- stage return or wider Realm pressure
- omen or spiritual unease reaching a threshold

This means the Sanctum remains a land of its own rather than a simple aftermath station.
Realm pressure is one major input, but not the sole scheduling spine of house life.

Current pulse rule:

- pulses surface consequences and choices
- pulse outcomes can change bonds, fear, morale, institution strain, duty state, hidden sublayers, and `Continuity`
- a pulse should not grant `Continuity` merely because it occurred
- `Continuity` gain should come from how pressure is handled, repeated, stabilized, or allowed to mutate

Current mutation rule:

- unresolved pressure should not usually cool down on its own
- if ignored, it should mutate into a worse or differently shaped incident
- player action can be positive, deflective, or actively harmful

### Foundation incident categories

The current foundation Sanctum incident set should prioritize:

- care / recovery
- rivalry flare-up
- recognition / praise / jealousy
- protective intervention
- omen / unease

These categories are broad reusable incident families, not one-off scenes.
They should be able to appear as ambient signals, surfaced incidents, or mutated escalations depending on house state.

## 18.5 Buildings, rooms, and institutions

Buildings and rooms should not be treated as Continuity itself.
They should be expressions of a house that has become culturally ready for them.

Current direction:

- Continuity is the readiness spine
- institutions, rooms, and rites are expressions of that readiness
- new spaces should feel earned by the house becoming a certain kind of place

This is important because the Sanctum should be treated like another playable character, not like a neutral town screen.

Current institution rule:

- buildings create social gravity
- jobs create obligation
- Realm pressure, bond pressure, and house custom determine how that gravity is expressed

Institutions should therefore generate both:

- positive signature beats when they are healthy or well-matched
- failure incidents when they are strained, misrun, contradictory, or overloaded

## 18.6 Unlock logic

New institutions should not unlock from a Continuity threshold alone.

Current direction:

- unlocks should require a Continuity threshold
- unlocks should also require story or virtue prerequisites
- unlocks should also be shaped by hidden sublayer support
- visible unlock candidates should not appear as a single fixed progression rail

This helps prevent every successful Sanctum from converging into the same shape.
Two houses with similar total Continuity should still feel different if they brought home different stories and cultivated different strengths.

Foundation exception:

- in the opening game, `Hearth` and `Training Grounds` should appear early as spatial anchors before the larger role-and-office priority fully takes over
- this is an onboarding and legibility exception, not a reversal of the broader Continuity logic

### Continuity bands and candidate unlocks

The game should use `5 to 6` visible Continuity bands rather than only a handful of large jumps.

Current direction:

- `Continuity` rises continuously
- visible bands mark cultural phases of the house
- each band contains smaller internal thresholds
- unlocks should happen inside bands, not only at the moment of entering a new band

Current implementation rule:

- the current `Continuity` band determines what kinds of growth are now possible
- internal thresholds determine when new candidates can surface
- hidden sublayers determine which candidates appear
- story or virtue readiness determines whether those candidates can actually open
- contradiction, strain, or house weakness can delay or complicate access

Current surfacing rule:

- the player should usually see `2 to 3` candidate unlocks rather than a single fixed next unlock
- before surfacing, candidate logic can remain fluid as house state changes
- once surfaced, candidates should stay mostly stable until resolved
- if a candidate is not yet available, it should still be shown as visible but unavailable rather than hidden again
- blocked candidates should use short reason phrases plus prose rather than exact formula readouts

Current blocker priority:

1. weak hidden sublayer support
2. wrong story or virtue readiness
3. insufficient raw `Continuity`

Current building and job rule:

- buildings and jobs should remain tightly linked
- building-first should be the norm
- job-before-room should be a rare exception rather than a standard unlock pattern

### Current six-band cadence direction

The current working six-band cadence is:

1. `Awakening`
2. `Habit`
3. `Role`
4. `Governance`
5. `Differentiation`
6. `Cultural Maturity`

These are cultural phase labels, not hard promises that every band unlocks the same amount of content.

Current intended read:

- `Awakening`: the house becomes legible; first spaces, first pulses, first visible routine
- `Habit`: repeated patterns form; early jobs and institution-colored incident growth become visible
- `Role`: duties and office identity sharpen; broader unlock candidates begin to appear
- `Governance`: mediation, recognition pressure, and clearer house rules deepen through broader institutional maturity
- `Differentiation`: sublayers and story domains bend the house into more distinct shapes
- `Cultural Maturity`: stronger custom identity, institution variants, and higher-end Sanctum differentiation become available

## 18.7 Virtue-shaped development

Different story domains should push the Sanctum in different directions.

Current direction:

- structures and rites should be grouped into broader shared categories
- virtues should influence the expression or variant within those categories
- mythic Echoes should add rare branch variants rather than exploding the whole system into separate parallel trees

Example direction:

- Courage-heavy houses may push initiatory, martial, or trial-oriented expressions
- Wisdom-heavy houses may push teaching, interpretation, or reflective expressions
- other virtues should likewise bend shared institution categories toward different cultural flavor and function

This keeps the house varied without creating impossible content debt.

## 18.8 High Continuity through different house shapes

High Continuity should be possible in more than one kind of house.

Current direction:

- a smaller house can achieve high Continuity through strong Memory and Institutional Pattern
- a larger house can achieve high Continuity through broader Social Fabric and richer role structure
- population count alone should not define whether a house feels culturally mature

This matters because the player should be able to express different forms of stewardship without being forced into one ideal population model.

## 18.9 Fraying, stagnation, and damage

Continuity should be maintainable, but it should not behave like a flat upkeep meter.

Current direction:

- ordinary neglect should more often cause stagnation or weakened expression than catastrophic loss
- serious Continuity damage should come from contradiction and breakdown, not just time passing

Current strongest harm sources:

- broken vows
- failing to bring stories home
- severe social fragmentation

This means institutions should usually fray, weaken, or become less effective before they disappear.
Unlocked institutions should not normally be removed outright.

## 18.10 What Continuity primarily unlocks

Current priority order for Continuity unlock expression:

1. new house roles and offices
2. new spatial wings and rooms
3. new ritual actions
4. new social rules and house customs

These should not all unlock at the same rate or in the same amounts.
The important point is that Continuity should change how the house lives, not just how many bonuses it has.

## 18.11 Mythic Echoes and Continuity

Mythic Echoes should not merely contribute raw Continuity.
They should be able to reshape or guide it.

Current direction:

- a mythic Echo can bend the house sideways rather than simply pushing it farther along the same line
- the most common mythic effects should be new rite-path variants or new offices
- fully unique rooms should be rarer than rite or office variation

This should allow mythic Echoes to become cultural reference points inside the house.

Likely effects:

- changing the weighting of existing house patterns
- unlocking a rare variant of an institution tied to one of their dominant virtues
- becoming a reference point for future Echoes, rites, or expectations

Mythic influence should also be uneven.
Different mythic Echoes should not reshape the house in identical ways.
Their dominant virtues, vectors, callings, and remembered acts should all matter.

## 18.12 Open Continuity questions

Still open:

- exact milestone thresholds
- exact visible milestone language
- exact formulas linking the hidden sublayers to the visible Continuity spine
- exact relation to resource generation and other support systems
- exact set of institution categories and which virtues can variant them

These should be solved later without changing the core meaning of Continuity.

---

# 19. Currencies, Items, and Equipment

The economy should support the Weave, the Sanctum, and combat expression without replacing them.

This means:

- currencies should stay few and legible
- house-state values should not be mistaken for spendable wallet resources
- gear should support identity and tactics rather than becoming the main identity system
- anti-hoarding should come from structure and circulation, not from constant item decay

## 19.1 Core economy split

The current economy split should be:

- explicit spendable currencies
- visible house or social states
- progression and readiness states

### Explicit spendable currencies

The current core spendables are:

- `Ase`
- `Ekwan`
- `Relics`

### Visible states, not normal currencies

The following should be treated as states or levers rather than normal spendables:

- `Faith`
- `Harmony`
- `Favor`

These belong in the same general family as fear, morale, contamination pressure, and related house conditions.
They influence decisions, outcomes, and atmosphere.
They should not primarily read like wallet numbers.

### Progression and readiness states

The following are not normal spendables:

- `Continuity`
- `Threads`
- active Realm recovery track state

These should be grown, leveraged, interpreted, or risked.
They should not normally be spent like money.

## 19.2 Currency roles

### Ase

`Ase` is the life-source currency.
It should be paid when the player performs actions that animate, invoke, shape, or spiritually enact change.

Current primary uses:

- summoning
- rites
- Thread handling, including Weaving Rite actions and related sanctified work

Ase should feel like living spiritual force spent to make things happen.

Current offline accrual direction:

- offline Ase accrual should exist
- it should begin only after the `Ase Flame` has awakened
- it should not be framed as generic passive income or Echo labor producing currency
- it should be framed as the living flame and Sanctum retaining and slowly gathering charge while the Keeper is away
- there should always be a modest base trickle at first, but it should taper and die down over time because the Keeper is absent
- offline accrual should be claimed automatically on return and acknowledged with a short return message rather than a separate claim step

Current stability rule:

- Sanctum stability should determine how much of that offline recovery is retained
- `Continuity`, house order, and broader Realm recovery should improve offline Ase indirectly by making the flame steadier and more resilient in the Keeper's absence
- strain, vow fracture, neglect, social instability, and spiritual unease should weaken offline recovery toward near-zero
- this should almost never become literal zero unless the house is in severe disorder

Current economic rule:

- offline Ase should support return cadence, not replace active play
- it should never become the primary source of Ase
- buildings, jobs, and Realm recovery should improve it indirectly through retention and stability rather than through raw production multipliers
- baseline Realm entry should generally not cost Ase
- Ase should usually gate how the player shapes a run, sanctifies an action, or invokes extra force, not whether the player is allowed to attempt the core Realm loop at all

### Ekwan

`Ekwan` should not read as generic gold.
It is better understood as shaped matter, stored labor, and build capacity.

Current primary uses:

- rooms and buildings
- crafting
- research and preparation

Ekwan is the main material and construction-facing economy layer.

### Relics

`Relics` are the rare artifact layer.

Current direction:

- relics are primarily equippable special artifacts
- relics can also act as rare catalysts in important projects or rites
- relics should remain scarce enough that they still feel like remembrance and weight, not standard loot

## 19.3 Item categories and slots

The equipment model should stay light.
Echo identity is already carried by Threads, callings, virtues, bonds, distortion, and rites.
Items should sharpen or support that expression, not replace it.

Current slot model:

1. Weapon
2. Charm
3. Armor / Clothes
4. Relic or Consumable

This is enough room for tactical and expressive loadout play without turning Echoes into paper-doll inventory puzzles.

## 19.4 Item role by category

### Weapon

Weapons should matter through:

- visual identity
- action profile
- role behavior
- some stat influence

Stat modifiers should exist, but they should matter less than the way a weapon changes what the Echo tends to do and how they fight.

Calling fit should be soft rather than hard-locked.
Early Echoes without a settled calling should still be able to use a wide range of items, while better callings-and-weapon fit should improve performance and expression.

### Charm

Charms are the clearest place for:

- emotion modifiers
- virtue or Thread synergy
- small rule-bending effects

They should help shape readiness, stability, and expressive play more than they shape raw power.

### Armor / Clothes

Armor and clothing should remain mostly defensive and survival-oriented.
They can carry flavor and visual identity, but they should not become a separate heavy social simulation system.

### Relic or Consumable slot

This slot should create meaningful tension:

- equip a rare lasting artifact
- or carry a one-use tactical tool

Consumables should be strict and limited.
Current direction:

- one consumable slot per Echo
- consumables are held by Echoes in the active party
- consumables are one-use

## 19.5 Item sources and cadence

Items should come from multiple sources so the player does not hit an early downward spiral and so late-game equipment distribution remains manageable.

Current sources:

- crafting
- Sanctum projects
- rites or recognition outcomes
- stage rewards
- Realm rewards

Current reward cadence direction:

- semi-common low-tier gear
- occasional meaningful gear
- very rare relics

Realm rewards alone are too infrequent to carry the whole equipment loop.

## 19.6 Crafting and upgrade baseline

Crafting should not balloon into hundreds of recipes.
The stronger direction is a tighter list of meaningful archetypal items that can exist in different grades.

Current baseline:

- lean recipe list
- item grades or rarity bands are acceptable and can be explicitly shown if kept restrained
- crafting and upgrading should usually require `item + Ekwan + Ase`

This keeps the economy legible:

- Ekwan pays the material and build cost
- Ase pays the shaping and attunement cost

Relics should not be a default cost in ordinary crafting.
They should appear mainly in rarer catalyst-level work.

## 19.7 Anti-hoarding structure

Normal gear should not use broad durability attrition.
That would create too much maintenance noise for a game already carrying Threads, rites, distortion, bonds, and Sanctum states.

Current direction:

- no normal durability on ordinary gear
- consumables remain one-use
- anti-hoarding should come from inventory structure, not constant decay

Current anti-hoarding tools:

- inventory cap
- offering items into rites
- recycling items into crafting value
- upgrades that fold older gear into stronger gear instead of leaving it to rot in storage

Current recycle direction:

- recycling should return `Ekwan` only

Offering items into rites should support both:

- empowering specific rites
- sacrificing value for house-state or ritual influence

## 19.8 Claimed gear and emotional attachment

Gear should remain transferable at baseline.
The player needs to be able to spread, repurpose, and reuse items across the house.

At the same time, Echoes should be able to form attachment to gear over time.

Current direction:

- some gear can become claimed or named through Echo choice events
- claimed gear should carry a small mechanical effect
- claimed gear should carry a stronger emotional and surface effect than a raw power spike

This supports attachment without locking the whole inventory into hard ownership too early.

## 19.9 Relics and remembrance

Relics should be mostly found rather than mass-crafted.

Current direction:

- most relics come from Realm or rare reward structures
- some relics can form from Echo death, but only under specific conditions

Death-formed relics should be a special remembrance category, not the primary relic economy.
Otherwise death starts looking economically desirable in the wrong way.

Current direction for death-formed relic requirements:

- they should require specific conditions
- those conditions should inform what the relic is and what it does
- they should remain rare enough to avoid flooding the house with remembrance artifacts

## 19.10 Open economy questions

Still open:

- exact inventory cap structure
- exact item grade and rarity ladder
- exact crafting list and project counts
- exact rite-offering effects by item type
- exact death-formed relic conditions

These should be tuned later without changing the core economy split.

---

# 20. Starter Flow, Tutorial, and Early Game

The opening slice should not try to prove every major system at once.
Its job is to teach the player what Echoes are, what the Sanctum is, and why Realm risk matters before the game fully opens up.

Current framing:

- `start + tutorial` is everything before summoning opens
- the game truly opens up once summoning becomes available
- the first 30 minutes should establish the emotional and systemic backbone, not explain every later layer in full

## 20.1 Opening design goals

The opening should establish these truths first:

- Echoes are people, not units
- the Keeper guides rather than commands
- the Sanctum is a living house, not a menu shell
- story recovery changes future growth

The player does not need to fully understand:

- the full Weaving Rite
- formal calling progression
- mythic material
- broad skill complexity
- vows as a managed system
- office or custom complexity

Those can arrive later.

## 20.2 Starting state

Current starting state:

- one pre-summoned Echo
- a dormant or broken Sanctum
- no permanent Sanctum NPC cast required

The starter Echo should begin in an unsettled state.
They have been summoned into a strange place and should not feel immediately stable or obedient.

Important refinement:

- unsettled does not always mean the same emotional presentation
- the exact flavor should vary by archetype, early stats, vector tendencies, and personality direction

Possible early expressions include:

- suspicious
- frightened
- defensive
- disoriented
- hollow-curious
- angry at being called back

## 20.3 Opening sequence

Current opening structure:

1. The player begins in the dormant Sanctum with one unsettled starter Echo.
2. The player performs a small awakening rite.
3. The player reassures or guides the Echo while tending the broken house.
4. A protected mini-trial occurs as a pre-stage tied to the first Realm.
5. The player returns with an ember, some Ase, partial recovery or intel, and a small reward.
6. The Ase Flame core visibly awakens.
7. The player performs one more stabilizing action in the newly awakened house.
8. Summoning unlocks.
9. The early game begins.

This is still all part of the opening slice.
Summoning is the point where the game meaningfully opens up.

## 20.4 First rite and first player choice

The first meaningful player choice should be about:

- how to reassure the starter Echo
- how to conduct the first rite

This is important because the opening should begin by teaching interpretation and stewardship rather than tactical optimization.

The second simple rite or stabilizing action after the ember return should also matter.
This is the first point where the player begins to set the tone of Sanctum culture.

## 20.5 Tutorial mini-trial

The tutorial should include one protected mini-trial rather than beginning immediately with a full normal stage.

Current purpose of the mini-trial:

- recover a spark or ember for the Sanctum
- teach the feel of survival and combat
- prove the will of the starter Echo
- connect Realm action directly to house restoration

Current tutorial rules:

- no permanent death in the tutorial mini-trial
- formal directives are not introduced here
- tactical deployment and Keeper pings are not introduced here
- the mini-trial should be constrained and guided
- it should still use the normal game language and not feel like a disconnected fake mode

The player should leave the mini-trial understanding:

- Realms are dangerous
- recovery brings something back to the house
- the starter Echo is a person under pressure, not an obedient pawn

## 20.6 Starter Realm

The tutorial and early opening should use a fixed starter Realm rather than offering free Realm choice immediately.

This is a deliberate starter-slice exception to the broader non-sequential Realm structure.

Current direction:

- use a dedicated starter Realm or prologue Realm
- this can function as an eleventh opening Realm if needed
- it may bend normal difficulty and onboarding rules slightly
- it should still teach the true shape of Realm play rather than a fake tutorial-only ruleset

This avoids early branching before the player understands:

- what a Realm is
- what a stage is
- what scouting means
- why recovery matters to the house

## 20.7 First proper Realm stage

After summoning unlocks and the second Echo joins the house, the player should enter the first proper stage of the fixed opening Realm.

This stage should be a real stage, not another protected onboarding fakeout.

Current direction:

- only a rough lead or target area should be known at first
- the exact path, encounter placement, and some objective details are hidden
- stage difficulty is lower than the midgame target
- the player should still feel the full game logic in reduced complexity

Current broad purpose for the first proper stage:

- scout the corrupted outskirts

The player should know why they are there, but not fully know what they will find.

## 20.8 Stage structure, scouting, and reruns

Stages should be treated as explorable lands or spaces, not only as fixed battle cards.

Current direction:

- stage objectives may begin partially unknown
- the first party can enter, scout, and return with information
- directives matter because the player is learning how to approach the stage, not only how to win one battle
- unnecessary encounters should be avoidable or at least strategically managed
- a no-battle intel run should be possible when the party is cautious, lucky, or skillfully built for discovery
- Echo skills should be able to reveal meaningful stage information over time
- some stage information should also be discovered through chance contact rather than explicit scanning only

The key feel should be:

- hidden, not random
- deterministic, not chaotic
- learnable through repeated exposure

Current persistence rule:

- stages should be procedurally generated before first entry
- once a stage is first entered, that exact stage instance should lock
- reruns of that unresolved stage should preserve what the player is learning
- after the Realm is cleared and replayed later, a new stage instance can be generated

This prevents reruns from feeling like slot-machine churn and makes scouting meaningful.

### Current generation model

Current stage generation should use:

- one generated stage instance per stage slot
- deterministic generation using the Realm/stage seed
- lock-on-entry persistence for the unresolved instance
- fresh generation only when the larger Realm is later replayed

Each Realm should contain roughly `4 to 6` deterministically generated stages.

Realm order remains player-chosen, but overall difficulty should scale through:

- completed Realm count as the dominant factor
- roster and house strength as a secondary smoothing factor

### Current objective structure

Stages should not be treated as single-objective mission cards by default.

Current direction:

- a stage can contain up to `3` objectives total
- early/foundation stages should usually use:
  - `1` primary objective
  - `0 to 2` linked secondary objectives or complications
- later or harder stages can use more tightly linked multi-objective structures without becoming unreadable

Objective clusters should be built through:

- hard-authored adjacency anchors and chains
- tag-based compatibility rules

This is important so objective combinations form a legible stage story rather than a random pile of tasks.

Current foundation anchor objective types:

- `Scout / Reveal`
- `Recover / Retrieve`
- `Find / Protect / Escort`
- `Endure / Escape`
- `Pursue / Hunt`

Additional objective types such as `Rite / Stabilize` and `Judge / Choose` should remain available as the objective library grows, but the foundation should anchor around the set above.

### Current intel-reveal rule

The stage should initially feel unknown.
The player should usually begin with only:

- a lead, rumor, or target area

Good intel should reliably reveal:

- objective type
- objective location

The tactical combat briefing must respect this stage-intel contract. The prototype's fully revealed board was an experimental shortcut used to isolate tactical decision quality; it is not the production hidden-information rule. Production preparation shows known terrain, hazards, pressure, and objective information according to what the party has actually learned. Unknown information may remain concealed, but anything shown as decision-critical must be readable and truthful.

Other elements can be revealed in uneven amounts over time:

- encounter locations
- hazard zones
- NPC presence
- items or objective-linked objects
- event triggers or complication states

Intel can be gained through:

- directives and scouting choices
- Echo skills
- observation and repeated runs
- accidental contact or chance discovery

This is one of the reasons a stage should be learnable across multiple runs rather than being a one-and-done blind mission.

### Current encounter structure

Encounters should be mixed rather than fully fixed or fully random.

Current direction:

- some encounters should be set pieces tied to objective state, NPCs, or major pressure beats
- some encounters should be semi-random roaming contacts, more like pressure pockets the player can discover, avoid, or run into by chance
- a stage should usually complete through the objective rather than through kill-all by default
- some stages should still culminate in decisive battle, but not every stage should require that

### Current initiative direction

Initiative should not be treated as raw speed alone.
It is the encounter's opening readiness to act under pressure.

Current rule:

- initiative applies to all encounter actors, not just Echoes
- it should be determined once at encounter start and remain stable for that encounter unless an explicit effect breaks that rule
- it should remain deterministic and mostly readable from observed turn order rather than from exposed formula text

Current readiness hierarchy:

- physical quickness and practical readiness should remain the main backbone
- identity, role, and emotional state may tilt initiative, but should not dominate obvious physical differences
- initiative decides who enters the moment first
- deeper personality expression should happen mainly after initiative through action choice, interpretation, hesitation, intervention, and refusal

Current actor-type direction:

- Echoes may have initiative lightly tilted by family grammar and emotional state
- enemies should use the same broad readiness logic, but with stronger emphasis on enemy type and combat role
- allied NPCs, spirits, or other non-Echo actors should use simpler role-shaped readiness rather than full Echo identity logic
- structures should usually sit outside normal initiative unless the encounter mode explicitly requires them to act

Current family-grammar direction:

- `Edge` should tend toward earlier commitment and first action
- `Anchor` should tend toward later but steadier opening commitment
- `Sight` should tend toward warned, aware, or interpretive timing rather than raw speed alone

Current emotional direction:

- fear may delay, disrupt, or blunt opening readiness
- morale may sharpen, steady, or reinforce readiness
- emotional influence on initiative should remain modest compared with physical readiness
- emotional effects may exist for all living actors, but should be weighted differently by actor type

Current exclusion rule:

- directives should not directly change initiative order
- bonds, `Presence`, and most social influence should not normally determine turn order
- those systems should matter more after initiative, in protection, rescue, hesitation, target choice, social spillover, and fallout

Current player-facing rule:

- the player should mostly infer initiative from observed turn order
- light explanatory language is acceptable, but initiative should not read like a fully surfaced math problem
- the system should never imply that Echoes are structurally meant to act before other actor types just because they are Echoes

## 20.9 First-stage hidden information

On the first proper stage, the player should not be blind to everything.

Current direction:

- only a rough target area or lead should be known at first
- exact encounter placements can be hidden
- environmental hazards can be partially hidden
- event triggers and some exact objective requirements can be hidden

The player should feel:

- I know where I should begin looking
- I do not yet know exactly what is waiting

## 20.10 Failure and withdrawal in early stage play

Because permadeath is core to the concept, the opening should not rely on fake wipes with no consequence.

Current early-stage safety valve:

- map-level withdrawal for uncalled Echoes should be available from the start
- combat retreat can remain unavailable or much more limited early on

Acceptable early failure outcomes:

- retreat from the stage map with intel
- morale collapse leading to forced withdrawal
- partial objective understanding without stage completion
- no-battle return with useful information

The minimum useful failed run should still be able to return:

- intel
- revealed objective requirements
- objective location

This makes reruns part of learning rather than pure punishment.

### Current enemy framework

Enemies should not be defined only by faction fantasy.
They should first be readable as pressures on the stage objective.

Current enemy model:

1. Realm skin
2. pressure role
3. behavior pattern

Current direction:

- the enemy grammar should stay relatively small and reusable
- variation should come from Realm identity, stage pressure, movement style, and behavior profile rather than only from raw roster count
- enemy identity should be built first around stage/objective pressure, second around battlefield role, and third around faction or distortion flavor

Current first-pass pressure-role set:

- `Blocker`
- `Hunter`
- `Breaker`
- `Watcher`
- `Swarm`
- `Ritualist`

Realm identity should then change those roles through:

- movement pattern
- target priority
- pressure effect
- hazard interaction
- objective interaction

### Current NPC framework

NPCs should not appear only as escort payloads.
They should be another way stages become interpretable and socially meaningful.

Current first-pass NPC role set:

- `Witness`
- `Guide`
- `Charge`
- `Claimant`
- `Temporary Ally`

Current direction:

- NPCs should appear most often in objective-linked stages
- NPCs can also appear as optional discoveries or complications in broader exploration stages
- guides and witnesses should be especially important because they help turn unknown space into readable objective play

## 20.11 Directives in the opening slice

Directives should not appear in the protected mini-trial.

They should appear in the first proper stage in a reduced form.

Current opening directive direction:

- 1 to 2 starter directives only
- these are real full-game directives, not tutorial-only fake options
- more directive complexity unlocks later

Current starting directive tones:

- `Scout Carefully`
- `Seek Signs`

These fit the early scouting and information-recovery focus better than aggressive tactical posture directives.

## 20.12 Summoning unlock timing

Summoning should not open the instant the ember returns.

Current direction:

- the player returns from the mini-trial
- the Ase Flame core awakens
- the player performs one more stabilizing action or second simple rite
- summoning then unlocks

This gives the player one more beat to bond with the starter Echo and feel the house wake up before the broader roster loop begins.

Current Ase direction:

- the opening should grant almost enough Ase to summon
- the player should likely need one proper stage reward to comfortably continue the early growth loop
- the awakening itself should grant a meaningful one-time Ase amount so the player can act immediately rather than waiting for the first offline trickle
- offline Ase recovery should begin only after this awakening

## 20.13 First social beat

The first meaningful Echo-to-Echo social beat should happen after the second Echo exists.

Current direction:

- the first bond or social interaction should happen back in the Sanctum after the first proper stage, whether that stage was completed or failed

Current likely tone:

- suspicion
- territorial tension
- disagreement with the Keeper

This fits the fiction.
Newly summoned or recently awakened Echoes should not behave like an immediately cohesive family.

## 20.14 First 30 minutes target

By roughly the first 30 minutes, the player should likely have:

- 2 Echoes
- understanding of the partial recovery track at a basic level
- at least one meaningful Echo-to-Echo social beat
- at least one real stage attempted, and likely 1 to 3 stages into the opening Realm

Possible but lower-priority progress by that point:

- first simple crafted item

The player does not need to fully understand full Thread integration or the later Weaving Rite by this point.
They only need to understand:

- something was recovered
- the house changed because of it
- this will matter later

## 20.15 Early-game unlock layering

Current layering direction:

- Ase Flame core awakens during the tutorial return
- the rite space is the next meaningful house activation
- summoning unlocks after the second stabilizing action
- crafting unlocks later, after enough Continuity and cultural establishment have been generated, not immediately
- early UI can show locked future systems, but they should remain visibly inaccessible until the house is ready

Current early unlock priorities:

1. summoning
2. first proper Realm stage flow
3. first bond/social pressure
4. simple crafting slightly later

## 20.16 Opening slice and foundation implications

The opening slice should help define foundation scope.

Current foundation-facing lesson:

- every major system does not need to be fully playable in the first hour
- every major system should still have a clear place in the progression shape
- the foundation cutline can prove the fantasy through a narrow early slice before exposing wider systemic depth

This supports the implementation goal:

- build core systems broadly enough that they exist
- focus the playable slice on the start, tutorial, and early game
- let later systems remain visible but gated until the house and player are ready for them

## 20.17 Current foundation cutline

A pitch slice can imply a deliberately tiny proof.
That is not the current target.

The current target is a **foundation cutline**:

- an enjoyable and playable early-game base
- broad enough that the core systems are real
- narrow enough that later expansion does not require rethinking the whole structure
- something that can be rapidly built on and improved rather than a fake vertical slice

This means the goal is not “everything fully complete.”
It is “every core layer exists in a meaningful enough form that the early game already feels like the real game.”

### Current foundation priorities

The early foundation still needs to prove:

- Echoes are people, not units
- the Keeper guides rather than directly commands
- story recovery changes future growth
- Sanctum and Realm play meaningfully feed each other
- loss, fear, morale, and social consequence are real

### Current system-by-system foundation target

#### Summoning

- lightly playable
- basic summoning available in foundation scope
- higher summon tiers and wider summon complexity can remain later expansion

#### Sanctum life

- lightly playable, but visibly alive
- the Sanctum should use spatial visualization, ambient incidents, assignable jobs, and lightweight routine presentation
- Echoes should be visible in the house and able to interact with each other and the Keeper
- full life-sim density or heavy routine simulation is not required in the current foundation cutline

#### Bonds

- fully playable
- bonded Echoes should protect each other more readily
- refusal or hesitation should change when a bonded Echo is endangered
- rivals should create tension in Sanctum incidents

#### Callings and identity shaping

- identity shaping should be fully active
- first calling confirmation should be available in the foundation, but it should not be forced into a specific session or early pacing beat
- Standing 3 should arrive when player performance and progression pacing earn it, not because the foundation scope artificially compresses the game
- second and third calling milestones remain later expansion

#### Threads and story recovery

- fully playable
- the Realm recovery track remains the partial-recovery structure
- stages contribute recovery segments, not full Thread items
- partial recovery should matter through readiness clues and omen / preview use before final Realm completion
- full Threads still only crystallize on Realm completion and then enter reserve

#### Weaving Rite

- fully playable in reduced form
- for the current foundation cutline, the shipped outcome set is `Accept`, `Reject`, and `Defer`
- `Partially Integrate` and `Distort` remain planned future system states rather than abandoned ideas
- the Rite still happens after Realm completion, not at the stage level
- `Distort` should not be an active foundation-cutline Rite outcome
- distortion pressure, contamination, omen unease, and future instability may still be foreshadowed in the recovery track and surrounding fiction, but the full distortion outcome system belongs to later expansion work

#### Realm stages

- fully playable
- the starter Realm remains a special opening exception
- after the starter Realm, broader Realm choice returns and should remain non-sequential
- the current foundation should include 2 fully playable post-starter Realms
- those Realms should feel clearly different in tone, pressure, and restoration logic and should not collapse into near-duplicates

#### Directives and scouting

- lightly playable, but they must be real decisions
- the starting directive pair is enough for the current foundation:
  - `Scout Carefully`
  - `Seek Signs`
- both focus on information gathering, but with different risk profiles
- `Scout Carefully` should support safer pathing, lower commitment, and better survival / intel retention
- `Seek Signs` should push stronger clue-seeking and higher chance of more accurate or deeper intel at greater exposure risk
- `Scout Carefully` should also be the stronger choice for returning with useful information from a failed or partial run
- `Seek Signs` should be the stronger choice for revealing hidden objective requirements, omen language, and readiness clues, while being worse on safety if the run goes bad

#### Keeper tactical guidance

- fully playable in a deliberately bounded Foundation form, though not necessarily exposed in the first session
- combat is player-facing automatic-only once preparation commits; playback speed may change, but the Keeper may not pause, manually advance actors, or enter a command phase
- preparation provides one visible party representation and one Echo-selection path for deployment
- the Foundation tactical field uses readable irregular terrain, obstacles, hazards, and meaningful route tradeoffs so deployment and guidance respond to the board rather than only to actor stats
- the active Directive remains broad party intent; limited pings are temporary, round-earned tactical emphasis and never replace the Directive
- each ping uses exactly one recipient scope: Echo-specific, area-based, or party-wide; spatial subjects and footprints never create hybrid recipient modes
- before confirmation, the player can understand what the ping suggests, which Echoes it affects, when it matters, and why it is unavailable
- recipients are fixed at confirmation, then independently interpret the guidance on their first relevant turn in the next round; unaffected Echoes do not respond
- the response appears before that turn and the Echo's next movement or action makes following, reshaping, resisting, or rejecting the guidance legible
- the Foundation scope covers every currently authored production combat objective—`COMBAT`, `PURIFY_SHRINE`, `RECOVER`, `PROTECT`, `ENDURE`, `PURSUE`, and `GUIDE_SPIRIT`—preserving each objective's rules rather than redefining them

The Foundation experience chain is:

**Read -> prepare -> observe -> guide -> Echo interprets -> visible action -> review.**

The Foundation loop includes this complete chain so the player can understand how preparation, Directive, guidance, Echo identity, emotional state, battlefield pressure, and the objective affect the result.

#### Vows

- lightly playable
- a small number of vows should be unlockable in the foundation
- the rest can remain later expansion

#### Crafting and equipment

- lightly playable
- basic loot, early equipment slots, and simple early crafting should all be present
- deeper crafting ladders and wider gear complexity can remain later

#### Continuity and Sanctum growth

- available and meaningful from the early game onward
- Continuity remains core to the game and should not be treated as optional polish
- early visible unlock direction should begin with the `Hearth` and `Training Grounds`
- those spaces should exist before the full wider institution set is unlocked

#### Death, withdrawal, and loss

- fully playable
- permadeath remains core
- map-level withdrawal and useful failed runs remain part of the early-game safety valve
- the current minimum death ripple package is:
  - Echo removed from roster
  - morale / fear ripple
  - bond fallout and grieving response
  - possible Sanctum incident
- rarer branches such as hateful celebration and relic formation should still exist when the relationship state supports them

#### Economy

- fully playable

#### Sanctum buildings and jobs

- part of the foundation scope
- the full foundation target is 5 buildings and 5 corresponding jobs / offices:
  - Training Grounds -> Trainer
  - Council Hall -> Mayor
  - Hearth -> Cook / Bartender
  - Smith / Crafter -> Armorer / Smith
  - Old Great Tree -> Caretaker / Spirit Guide
- all 5 should exist within the full foundation scope because player choice across institutions matters
- only 2 should be available in the opening / early game, with the rest unlocking later through Continuity and cultural readiness
- buildings are not identical to jobs:
  - buildings provide their own buffs, deficits, and house expression
  - jobs modify those variables further and can broaden or intensify their effects across the Sanctum
- institution behavior should be read through `Sanctum pulses` rather than only through passive values
- jobs should do three things at once:
  - shift hidden weights and incident odds
  - change where Echoes physically spend time in the Sanctum
  - create duties that can be fulfilled, failed, or overperformed

Current foundation routine direction:

- routine presentation should be primarily ambient
- Echoes should be seen moving, lingering, working, resting, watching, arguing, or withdrawing in legible places
- lightweight warnings should surface before major institution failures fire
- full schedule optimization is not required in foundation scope

### Current unlock direction for institutions

The current early visible institution direction is:

- `Hearth`
- `Training Grounds`

Those should appear first as part of the house becoming legible.
Wider institution and job access should unlock later through Continuity plus story / virtue readiness rather than from a flat threshold alone.

Current follow-up unlock direction:

1. `Hearth` and `Training Grounds` appear first as spaces with passive building effects
2. `Cook / Bartender` and `Trainer` unlock after that
3. stronger Sanctum incident expression and clearer routine / custom texture deepen the house
4. `Council Hall` unlocks after the early care-and-formation layer is established
5. `Mayor` follows later as part of broader house governance and institutional maturity

This keeps the early house focused first on care, recovery, and formation before it broadens into governance and wider structure.

### Opening institution behavior direction

The first two institutions should establish different pressure textures.

#### `Hearth`

Primary role:

- recovery / morale
- social mixing

Current behavior direction:

- `Hearth` should be the higher-frequency social pressure and social-softening institution in the foundation
- it should produce more surfaced incidents than `Training Grounds`
- healthy `Hearth` behavior should create positive beats around comfort, reconnection, relief, and informal social binding

Current failure direction:

- hollow comfort that hides real strain
- rumor distortion that slowly mutates bonds negatively

#### `Training Grounds`

Primary role:

- readiness / preparation
- secondary rivalry and status pressure

Current behavior direction:

- `Training Grounds` should produce fewer but sharper incidents than `Hearth`
- healthy `Training Grounds` behavior should improve readiness, courage expression, and disciplined preparation

Current failure direction:

- overtraining / depletion, including lower Storyweight gain
- hierarchy hardening, including bond strain and party refusal around standing gaps
- status humiliation that changes Echo behavior

### Current death-and-grief flavor direction

Death response should not flatten into one generic sadness state.

Current intended range includes:

- grief and morale collapse around bonded loss
- bond fallout across the roster
- Sanctum incidents triggered by social rupture
- rare hostile or celebratory response when a relationship was bad enough to support it

This should remain mechanically meaningful, but the hostile-celebration branch should stay rare in the early game.

---

# 21. Remaining Open Questions

GDD V2.5 is now in the finalization phase.

The core concept, Wholeness Model, Realm recovery model, foundation cutline, progression backbone, and calling lattice are sufficiently locked.

The remaining work is no longer broad reconcepting.
It is mostly:

- tuning
- implementation-facing content definition
- surfacing language
- threshold setting
- high-end progression cleanup

## 21.1 Early economy and inventory pressure

Still open:

1. exact summon cost and early Ase cadence
2. exact early Ekwan cadence
3. inventory cap structure
4. rarity ladder and item-grade spread
5. death-formed relic conditions

## 21.2 Sanctum incidents, routines, and institutions

Still open:

6. exact pulse frequency, threshold timing, and event-budget rules
7. exact warning surface for rising institution strain and social pressure
8. exact passive values for the first institutions
9. exact job effects and scaling rules
10. exact expansion rules for incident pools across Continuity, bonds, institution state, and Realm pressure

## 21.3 Behavior and autonomy pressure-testing

Still open:

11. exact weighting and threshold rules inside the hidden autonomy ladder
12. exact pre-run warning language for party incoherence, overcommitment, and likely refusal
13. exact conflict-resolution rules when directive, bond protection, fear, morale, and calling pressure all collide
14. exact behavior modifications produced by directives and scouting stances across different Echo profiles

V2.5 leaves exact Charge cadence and costs, ping breadth, response thresholds and language, tactical-field variety, and additional Directives open to controlled validation.

## 21.4 Thread reserve, rite surfacing, and integration tuning

Still open:

15. exact reserve cap numbers, expansion cadence, and overflow UX details
16. exact stable clue vocabulary for rite fit / readiness / strain
17. exact weighting and thresholds inside the hidden resolution order for foundation and post-foundation states
18. exact fallout tables and severity rules for contested non-chosen Echoes

## 21.5 Continuity milestones and institution cadence

Still open:

19. exact numeric thresholds for the six visible Continuity bands and their internal sub-thresholds
20. exact content mapping for institutions, rites, offices, and customs across those bands
21. exact weighting of Memory / Social Fabric / Institutional Pattern in candidate surfacing and blocker strength

## 21.6 Mythic and high-end progression

Still open:

22. exact mythic-recognition thresholds, failure rules, and retry / redirection cadence
23. exact deployment-cost tuning, departure pressure thresholds, and multi-mythic strain effects
24. first-pass replacement set for weak Standing-9 names while keeping the Standing-9 structure intact

## 21.7 Final stretch sequence

The most important remaining work for completing this GDD is:

1. early economy and inventory pressure
2. Sanctum incidents, routines, and institution behavior
3. behavior / autonomy pressure-testing
4. Continuity milestone and unlock cadence
5. rite surfacing and reserve/clue tuning
6. mythic flow and remaining high-end naming cleanup
7. then implementation alignment and codebase steering

---

# 22. Current Build Reality (April 4, 2026)

This section is implementation-aware.
It records what the current build actually supports so the V2.5 GDD can steer the game that exists rather than drift into a parallel paper design.

Current verification snapshot:

- headless test run completed on **April 4, 2026**
- `316` tests total
- `305` passed
- `11` failed
- current failures cluster around:
  - party toggle persistence
  - actor intent/action logging
  - fear / morale / guard weighting behavior

The build is real and broad.
It is not concept-complete.
The main design job now is to decide what the first shippable proof should emphasize, then align the existing systems to that proof.

## 22.1 Current playable loop in the build

The current build already supports a concrete loop:

1. boot to splash / main menu
2. enter Sanctum
3. manage roster, party, summoning, and vows
4. select one active Realm
5. review sequential stage map and prepare called Echo skills
6. enter stage
7. run deterministic encounter on the combat board
8. resolve rewards, XP, and stage advancement
9. return to Sanctum or continue deeper into the Realm

This means the present game is already strongest as a **Sanctum -> Realm -> Encounter -> Resolve** strategy loop.
That loop should be treated as the immediate backbone for foundation proof.

## 22.2 Systems already real enough to design around

The following are already materially implemented and should be treated as real constraints, not speculative wishes:

- deterministic simulation and state-first architecture
- snapshot-driven screen flow and shell routing
- Sanctum hub, naming, roster preview, and party management
- paid summoning with grade-based cost and reveal flow
- emotion state including morale, fear, and recovery drift
- social graph foundations for bonds and rivalries
- vows with unlock, pledge, release, and break penalties
- Echo progression, XP, levels/ranks as current implementation aliases for Step/Standing, trait drift, and calling eligibility
- calling confirmation, calling passives, and per-calling skill loadout
- Realm selection, one-active-Realm rule, deterministic stage generation, and stage advancement
- encounter flow with retreat checks, initiative order, shrine/combat objectives, and resolve payouts
- reward and economy services for `Ase` and `Ekwan`
- Sanctum spatial rendering as a read-only embodiment layer

These are enough to support a genuine early-game vertical slice without inventing major new architecture first.

## 22.2.1 Technical rails to accept as implementation infrastructure

The following should be treated as technical rails, not concept systems to be re-opened in this GDD:

- structured logging
- snapshot renderer / snapshot UI plumbing
- save repair and schema/version migration support
- low-level config validation and loading safeguards

These matter for reliability, debugging, and iteration speed.
They should continue to evolve in implementation as needed.
They do **not** need to be re-designed at the game-concept layer unless they begin constraining player-facing design in a meaningful way.

## 22.3 Highest mismatches between target fantasy and current build

The biggest design gap is not lack of systems.
It is that the implemented loop is currently more legible as a deterministic combat/progression game than as a story-recovery and person-shaping game.

Current highest mismatches:

- the **Weave** is conceptually central in this GDD, but full Thread recovery, Thread reserve handling, Weaving Rite invitation/resolution play, and integration outcomes are not yet the live gameplay spine
- `Continuity` is defined as the Sanctum becoming a culture, but the current Sanctum is still much closer to a functional hub than a socially evolving house
- bonds, vows, morale, and fear exist, but their player-facing consequences are still lighter and less dramatic than the intended attachment fantasy
- directives and scouting exist in direction, but the live build still offers a narrower player-influence layer than the GDD’s long-term promise
- mythic recognition, institutional growth, and layered wholeness consequences are still mostly design territory rather than shipped loop territory
- behavior reliability is not fully trustworthy yet, as shown by the current failing test cluster around fear, morale, guarding, and intent logging

This should change scope decisions immediately:

- the first shipped proof should not try to prove the entire Weave
- it should prove that Echoes feel like unstable people under guidance, not just autonomous combat pieces

## 22.4 Foundation cutline and first-session proof

The foundation cutline should prove one thing clearly:

**The Keeper can bring incomplete Echoes into a living house, influence who they become, and feel that identity matter in a dangerous Realm run.**

The smallest strong proof of that is:

1. one pre-summoned starter Echo in a dormant Sanctum
2. one protected ember-recovery mini-trial
3. Sanctum awakening
4. summon of the second Echo
5. one fixed opening Realm
6. one real proper stage with limited directives and hidden information
7. one visible post-stage consequence pass back in Sanctum
8. one early social beat between Echoes

This first-session sequence does not need to expose the entire Keeper Tactical Guidance system. The protected mini-trial excludes formal Directives and pings, and the first proper stage may introduce the tactical loop in a reduced, paced form.

For first-session proof, the player must be able to feel all of the following:

- Echoes are not obedient units
- morale / fear / calling direction already shape what happens
- the house changes when a run succeeds or fails
- Realm play returns meaningful material to future growth
- a failed run can still teach, reveal, or reshape

The foundation cutline does **not** need full versions of every later system to prove this.

The full Foundation includes the bounded tactical-guidance loop across every currently authored production combat objective. First-session exposure and Foundation scope are separate decisions: onboarding may sequence the system gradually, but the system may not be deferred out of Foundation.

## 22.5 Systems that should be treated as post-foundation expansion

The following should remain in the V2.5 GDD as real future structure, but they are not required for Foundation completion:

- full multi-Thread reserve strategy
- contested Weaving Rite depth
- full distortion family spread beyond the first priority set
- full `Continuity` institution tree and house-shape differentiation
- deep Sanctum jobs / pillars / office politics
- mythic recognition rites and departure pressure
- crafting / research breadth beyond minimal hooks
- tactical-guidance expansion beyond the Foundation loop: future combat objectives, wider ping or Directive libraries, deeper mode-specific board topology/ecology and content breadth, and final animation/reporting breadth
- multi-zone Sanctum growth

These systems matter.
They are just not the first proof.

---

# 23. Immediate Steering Priorities

The next V2 work should now be guided by build reality rather than abstract completeness.

## 23.1 What should be strengthened first

Priority order:

1. define the first-session proof with hard cutlines
2. strengthen early economy cadence so summoning, first-stage risk, and retreat all feel meaningful
3. tighten the player-influence layer already closest to implementation:
   - directives
   - stage intel
   - party preparation
   - fear / morale readability
   - Keeper guidance and Echo-response readability
4. make Sanctum consequences more legible after runs:
   - bond movement
   - vow consequences
   - roster emotional state
   - visible house recovery/change
5. only after those feel coherent, expand deeper Weave systems

## 23.2 Current implementation steering rule

When a design idea conflicts with the current build, the first question should be:

**Can the existing flow, services, and UI shells be reinterpreted to support the intended experience?**

Only if the answer is clearly no should the design push for fresh architecture.

In practice this means:

- use the existing Sanctum / Realm / Resolve loop as the skeleton
- use existing emotion, vow, calling, bond, and progression systems as the first person-shaping layer
- integrate Keeper guidance through the same deterministic behavior and objective authority while preserving the hidden-intel contract
- treat Weave, Continuity, and mythic systems as the next major layer to connect onto that skeleton

## 23.3 Current design warning

The largest risk right now is false depth.

If V2 keeps adding Thread, distortion, Continuity, and mythic theory without first making the early playable slice emotionally legible, the design will grow broader on paper while the actual game remains thinner in lived play.

The next successful revision should therefore prefer:

- sharper first-session proof
- stronger visible consequence
- fewer but clearer player influence decisions
- more readable Echo identity under pressure

That is the cleanest path from the current build toward the intended V2 game.

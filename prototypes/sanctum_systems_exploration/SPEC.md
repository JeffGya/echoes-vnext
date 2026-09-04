# Sanctum Living House Prototype Spec

**Status:** Blueprint for a local experimental prototype
**Version:** 0.2
**Owner:** Jeff
**Location:** `prototypes/sanctum_systems_exploration/`
**Canon status:** Non-canonical experiment. It tests the Working GDD and does not replace it. Canon changes require playtest evidence and Jeff's explicit approval.
**Primary canon:** `docs/Echoes vNext Working GDD.md`

## 1. Purpose

Build a standalone Sanctum simulation sandbox that tests whether the player's house can feel like a serious, grounded, inhabited home.

The reference feeling is the attachment, recognition, routine, visitation, collection, and social surprise associated with character-life games such as *Tomodachi Life* and *Animal Crossing*. The prototype must translate that appeal into Echoes' own identity:

- Echoes are returning names and incomplete people, not comic dolls or collectible villagers.
- The Keeper is a steward, host, witness, and guide, not an all-powerful decorator or puppeteer.
- Domestic life has warmth and occasional humor, but its emotional foundation is recovery, belonging, obligation, disagreement, memory, and preparation for real danger.
- The house remembers. Rooms, relationships, rituals, losses, and repeated practices accumulate into visible history.
- Realm pressure enters the home, and what happens at home later changes Realm behavior.

This prototype is successful only if the player begins to think of the Sanctum as **our home** and of its Echoes as **specific people who live here**.

The house itself is the interaction surface. Important actions must begin from a visible person, place, object, or event in the Sanctum and resolve through the world. A menu may clarify, compare, or confirm an action; it must not substitute for that action happening somewhere.

### v0.2 Place-First Interaction Contract

Version 0.2 adds the following hard requirements:

- Summoning happens at a visible summoning place around the Ase Flame, not from a navigation menu.
- The Weaving Rite happens at a dedicated visible rite space, with the Thread, chosen Echo, witnesses, and aftermath staged there.
- Echoes, institutions, activity signals, objects, candidate building sites, and the departure threshold are directly clickable/tappable.
- Clicking the world moves the camera or focus to the subject and exposes only the actions relevant to that subject and moment.
- Significant actions animate participants gathering, performing, responding, and dispersing or remaining changed.
- The world remains visible during interaction whenever spatial context or Echo reactions matter.
- Full-screen menus are reserved for dense reference, accessibility, settings, debug tools, and exceptional comparisons that cannot remain legible in the world.
- The central Sanctum view is the critical focus area. Permanent UI may not cover or visually compete with the active place, participating Echoes, or current beat.

## 2. Primary Design Question

> Can a deterministic, directly interactive Sanctum create the feeling of building a home with incomplete but increasingly recognizable people, while giving the Keeper meaningful influence without turning Echoes into obedient units, the house into a task list, or its places into menu shortcuts?

Supporting questions:

1. Can short routines and incidents create attachment without a dense life-sim schedule?
2. Can the player learn an Echo through observation, conversation, care, and consequence rather than through profile statistics alone?
3. Can buildings and jobs become socially meaningful places rather than passive bonus dispensers?
4. Can preparation for Realms emerge naturally from house life?
5. Can the Sanctum remain interesting when no urgent incident is active?
6. Can serious emotional stakes coexist with warmth, surprise, quiet humor, and ordinary domestic moments?
7. Can the player perform the major Sanctum loop primarily by reading and clicking the inhabited world rather than navigating feature menus?

## 3. Target Player Fantasy

The player fantasy is:

> I am restoring a living house of memory. I welcome incomplete people into it, learn who they are, help them find a place among others, and shape customs that outlast any one expedition. I cannot decide who they become, but my care, choices, and absences matter.

The player should regularly feel:

- **Recognition:** “I know why they chose that.”
- **Curiosity:** “What are they doing, and what does it reveal?”
- **Care:** “I want to help, but I may not know the best way.”
- **Belonging:** “This room, routine, and relationship now has history.”
- **Stewardship:** “My priorities shape the house without controlling every person.”
- **Anticipation:** “This domestic choice may matter when they leave for the Realm.”
- **Return:** “I want to come home and see what changed.”

The desired emotional register is warm, reflective, and occasionally tense. The game may produce gentle absurdity through incompatible personalities and awkward situations, but it should not trivialize grief, cultural memory, fractured identity, vows, or recovered stories.

## 4. Design Pillars

### 4.1 People before units

Every major system must reveal or change who an Echo is becoming. A bonus without behavior, expression, memory, or consequence is insufficient.

### 4.2 Home before hub

The Sanctum is the primary play and navigation surface, not decorative space behind menus. Echoes occupy places, move with intent, seek one another out, avoid one another, work, rest, prepare, and leave traces. The player reaches people and systems through that visible life.

### 4.3 Influence before control

The Keeper creates conditions, makes offers, assigns responsibilities, mediates, prepares, and interprets. Echoes may align, reinterpret, hesitate, object, refuse, or initiate something themselves.

### 4.4 History before content churn

Repetition becomes meaningful when context changes. A familiar meal after a victory, after an argument, and after a death must not feel like the same event.

### 4.5 Legibility before mystery

Hidden factors may create ambiguity, but the player must see enough signals to form and revise a theory about an Echo. Unexplained randomness does not create personhood.

### 4.6 Sanctum and Realm form one loop

House life prepares, stabilizes, strains, and reveals Echoes. Realm outcomes return stories, wounds, fear, pride, grief, resources, and unresolved pressure to the house.

### 4.7 Place before panel

Every consequential Sanctum verb needs a home in the world. The player should click the flame to summon, the rite space to weave, the Hearth to join a social beat, the Training Grounds to practice, an Echo to approach them, and the departure threshold to prepare a party. Contextual UI supports these encounters; it does not teleport the player into a disconnected feature screen.

This does not require a unique building for every verb. A coherent place should bundle related activities, acquire new functions as the house grows, and remain socially inhabited between uses.

## 5. Aesthetic Direction (MDA)

Primary aesthetics:

1. **Fellowship:** living among a changing household.
2. **Narrative:** stories emerge from routines, conflicts, recoveries, and remembered acts.
3. **Discovery:** learning who an Echo is and what the house is becoming.

Secondary aesthetics:

4. **Expression:** shaping house customs, spatial priorities, roles, preparations, and ritual choices.
5. **Submission:** quiet observation and familiar home rhythms between consequential choices.
6. **Challenge:** stewardship under limited attention, resources, contradictory needs, and imperfect knowledge.

The prototype must not optimize primarily for completion, collection, or efficiency. Those dynamics may exist, but they cannot replace attachment and interpretation.

## 6. Production Baseline

The prototype represents the current Echoes design rather than inventing a separate home-life game.

Production-aligned systems already available include:

- deterministic Echo generation and summoning;
- roster and active-party management;
- fear, morale, archetype, traits, virtues, Storyweight, Standing, Step, callings, skills, and maturity expression;
- bonds, rivalries, shared encounters, vows, and readable autonomy;
- Thread reserve and the foundation Weaving Rite;
- Continuity bands;
- Hearth and Training Grounds institution foundations;
- spatial Sanctum layout and occupants;
- Ase and Ekwan economies;
- run-return consequence summaries, companion invitations, and Sanctum barks.

The GDD additionally defines or reserves:

- Sanctum pulses, routines, ambient beats, incidents, warnings, and escalation;
- jobs, duties, offices, customs, and institution strain;
- Council Hall, Smith/Crafter, and Old Great Tree institution directions;
- care, recovery, rivalry, recognition, jealousy, protective intervention, omen, and unease incidents;
- deeper Thread contest, partial integration, distortion, reserve strain, and overflow;
- grief, death ripples, relic formation, mythic recognition, offices, obligations, multi-mythic pressure, and departure risk;
- crafting, equipment, relics, and material preparation.

The prototype may model all of these system families, but it must clearly label whether each rule is:

- **Production-aligned:** mirrors an implemented or canon-locked rule.
- **Prototype hypothesis:** proposed to make the simulation testable.
- **Accelerated horizon:** represents a later-game system through a fixture or shortcut rather than implementing its full campaign path.

## 7. Prototype Scope Strategy

The prototype uses **broad system coverage with shallow content depth**.

“Include all possible systems” means every major Sanctum system family can participate in the sandbox and collide with at least one other family. It does not mean writing a production-sized event library, full campaign progression, final narrative content, or complete economy balance.

### In scope

- One standalone deterministic Sanctum sandbox.
- A visible, directly clickable/tappable house with spatially located Echoes, institutions, objects, candidate sites, and activity cues.
- Place-first entry into summoning, ritual, preparation, crafting, institution, relationship, and Echo interactions.
- In-world staging and animation for every significant beat.
- A controllable Sanctum pulse clock with pause, normal, fast, and advance-to-next-beat controls.
- Summoning, arrival, settling, naming, and first social placement.
- Ambient routines with readable intent.
- Direct Keeper-to-Echo interactions.
- Echo-initiated requests, bids, observations, refusals, and conversations.
- Echo-to-Echo social beats and relationship change.
- Emotional recovery, strain, grief, pride, jealousy, and unease.
- Institution placement, establishment, jobs, duties, condition, and incident pressure.
- House customs and vow pressure.
- Party selection and preparation emerging from current house state.
- Thread reserve, resonance, Weaving Rite, contest, and aftermath.
- Continuity and house-shape development.
- Ase, Ekwan, light crafting/equipment, and meaningful resource tradeoffs.
- Simulated Realm departure and return packages rather than a second combat prototype.
- Death, recruitment, mythic, and departure scenarios through accelerated fixtures.
- Same-seed replay, debug explanations, event history, and playtest metrics.

### Explicitly out of scope

- Production campaign integration or production save writes.
- A full Realm, exploration, or combat simulation.
- Free-roam Keeper avatar movement.
- Direct control of Echo movement or minute-by-minute schedules.
- A free-roaming Keeper avatar; direct world selection is the prototype input model.
- Player-authored architectural construction or a full decorating system.
- Final art, final animation, final audio, final dialogue, or final cultural terminology.
- A large bespoke narrative-event library.
- Real-world timers, appointment mechanics, daily login pressure, or punishments for not playing.
- Online visits, multiplayer, gifts from other players, or live-service systems.
- A full crafting tree, inventory catalogue, fashion system, or equipment balance pass.
- Production implementation of post-foundation systems.
- Refactoring production systems to serve the prototype.

## 8. Core Experience Loop

The repeating Sanctum loop is:

1. **Return or awaken:** enter the house with current people, pressure, resources, and remembered outcomes.
2. **Observe:** read where Echoes are, what they are doing, who is near whom, and what needs attention in the visible house.
3. **Approach:** click/tap an Echo, place, object, relationship beat, or active signal; the camera and contextual interaction follow that subject.
4. **Interpret:** infer desire, strain, compatibility, risk, and opportunity from stable clues.
5. **Influence:** act through the selected person or place—converse, reassure, challenge, mediate, assign, invite, offer, prepare, build, craft, vow, or begin a rite.
6. **Participate:** watch the relevant Echoes travel, gather, perform, interpret, and respond in the place where the action belongs.
7. **Remember:** record a beat, relationship change, fulfilled duty, unresolved pressure, or defining act.
8. **Prepare:** form a party and make material, social, and doctrinal preparations for a Realm.
9. **Depart and return:** resolve a configurable Realm outcome package.
10. **Re-enter changed:** see emotional, social, spatial, economic, and story consequences enter house life.

The key feel loop is:

**Notice in the world -> click/approach -> act through a place -> Echo interprets -> embodied response -> house remembers.**

## 9. Session Shape

A target prototype session lasts **12 to 20 minutes**.

Starting session arc:

| Time | Expected experience |
|---|---|
| 0-2 min | Reorient to the house; notice one ambient beat and one pressure signal. |
| 2-6 min | Follow or approach Echoes; perform one direct interaction; inspect one relationship or institution. |
| 6-10 min | Resolve, defer, or worsen one surfaced incident or request. |
| 10-14 min | Make one shaping decision: assignment, custom, vow, rite, build, craft, or preparation. |
| 14-18 min | Send a party and apply a simulated Realm return package. |
| 18-20 min | Read the changed house and choose whether to continue, replay the seed, or review the history. |

The clock is a prototype tool, not canon time. The sandbox should support:

- pause for inspection;
- normal pulse flow;
- fast presentation;
- advance to next meaningful beat;
- same-seed reset;
- jump to a prepared scenario.

No important consequence should occur only because the player waited through dead time.

## 10. Sanctum Simulation Model

### 10.1 Deterministic pulse

A **Sanctum pulse** is the atomic house-life simulation step.

On each pulse, resolve in this order:

1. apply queued Realm-return or ritual aftermath;
2. update needs, duties, emotion recovery, strain, and institution condition;
3. evaluate Echo intentions;
4. resolve movement destinations;
5. detect proximity and relationship opportunities;
6. select ambient beats, requests, warnings, or incidents;
7. resolve unblocked autonomous behavior;
8. apply direct consequences;
9. update memory and escalating unresolved pressure;
10. build a read-only presentation snapshot and event explanation.

Every random choice uses a visible sandbox seed plus a stable namespace. Replaying the same seed with the same player choices must reproduce the same results.

### 10.2 Activity states

An Echo may be in one primary activity state:

| State | Meaning | Typical place |
|---|---|---|
| `arriving` | Entering and orienting to the house | Ase Flame / threshold |
| `idle` | Available but not empty of personality | familiar safe place |
| `roaming` | Moving toward a chosen interest or person | paths / courtyard |
| `working` | Fulfilling an assigned duty | institution |
| `practicing` | Preparing, teaching, or testing capability | Training Grounds / rite space |
| `caring` | Supporting another Echo | Hearth / bedside / nearby |
| `socializing` | Seeking or sustaining company | Hearth / shared space |
| `arguing` | Expressing active social pressure | shared or contested place |
| `withdrawing` | Creating distance under fear, hurt, or overload | edge / quiet space |
| `resting` | Recovering from strain or a Realm | Hearth / personal anchor |
| `ritual_ready` | Drawn to a vow, omen, Thread, or rite | Ase Flame / rite space |
| `preparing` | Packing, equipping, or gathering with a party | departure area |
| `absent` | Away in a Realm or departed from the house | not placed |
| `memorialized` | Dead or departed, present through a trace | memorial/object/history only |

The state must always expose a short player-facing reason such as “seeking quiet after the failed return” or “checking on Abena after their quarrel.” Raw intent weights remain debug-only.

### 10.3 Intention selection

Each Echo evaluates a small candidate set rather than a full schedule. Candidate scoring may use:

- immediate fear and morale;
- fatigue, recovery, social appetite, and spiritual unease prototype needs;
- archetype and virtue temperament;
- Calling and maturity expression;
- bonds, rivalry, recent conflict, grief, jealousy, gratitude, and obligation;
- active vow and house custom;
- assigned job and missed/overperformed duty;
- institution condition and compatibility;
- recent Realm history and remembered acts;
- Thread pull, contest, distortion, or reserve pressure;
- Keeper attention and recent intervention;
- preparation or departure state.

The simulation should generate at most three plausible high-level intentions per Echo per pulse, choose deterministically, and record the strongest positive reason and strongest competing reason.

### 10.4 Needs as behavior pressure, not chores

Prototype needs exist only if they create a decision or reveal character.

Use four broad hidden pressures:

- **Rest:** bodily and emotional recovery.
- **Company:** desire for recognition, warmth, challenge, or distance.
- **Purpose:** need to contribute, practice, learn, or uphold a responsibility.
- **Coherence:** stability of identity under memory, vow, Thread, and contradiction pressure.

Do not add hunger, hygiene, bladder, sleep schedules, or maintenance meters unless a later experiment proves they create Echo-specific stories. The Keeper should care for people, not clear status icons.

## 11. Spatial Home Model

### 11.1 Home as readable social geography

Space must affect behavior and memory.

The house begins with:

- the **Ase Flame** as spiritual and visual center;
- a modest shared floor/courtyard;
- a departure and return threshold;
- the early **Hearth** and **Training Grounds** anchors, that the player can add;
- visibly unavailable future places.

Later scenario fixtures may add:

- Council Hall;
- Smith/Crafter workshop;
- Old Great Tree;
- a dedicated Weaving Court / rite space;
- a Thread Alcove / reserve;
- memorial trace;
- personal or calling-shaped anchors.

`Weaving Court`, `Thread Alcove`, and the exact separation between the Ase Flame's summoning circle and other ritual spaces are **prototype working labels**, not final canon names. The prototype must test their spatial and experiential roles before naming or production placement is locked.

### 11.2 What places do

Every institution or room must create all five:

1. **A function:** what becomes possible here.
2. **Social gravity:** who comes here and who avoids it.
3. **Routine:** what repeated behavior occurs here.
4. **Pressure:** how it can fail, distort, or exclude.
5. **Memory:** what history the place accumulates and later recalls.

A room that provides only a passive percentage bonus fails the prototype.

### 11.3 Placement and home-building

The player establishes major places in authored valid locations. Placement should change:

- travel and encounter frequency;
- which spaces share social spillover;
- visibility of warnings and incidents;
- how the house reads as a home;
- the story attached to a location.

The prototype tests meaningful placement among a small set of positions, not freeform construction.

Home-building also needs visible personal authorship. The prototype should offer a small set of memory-bearing objects, institution variants, and shared-space accents that can be placed or dedicated. These choices need not grant bonuses. Their first job is to let the player see, “we chose to make this place ours,” and give Echoes something they can use, prefer, contest, or remember.

### 11.4 Home traces

The house should retain a bounded set of visible traces:

- the place where a first arrival settled;
- an Echo's preferred place;
- a repeated pair routine;
- a fulfilled or failed duty;
- a resolved argument;
- a crafted or claimed object;
- a Thread rite aftermath;
- a memorial or departure token;
- a house custom associated with a place.

Each place keeps up to three active traces. Older traces enter the house chronicle instead of cluttering the spatial view.

### 11.5 Place-to-system map

Important systems must have a visible spatial subject. The first prototype mapping is:

| System / verb | Primary world subject | What the player clicks | Required embodied beat | Supporting UI |
|---|---|---|---|---|
| Summon | Ase Flame summoning circle | flame/circle when charged | nearby Echoes gather or watch; flame responds; new form manifests; household reacts; newcomer chooses first movement | compact grade/cost confirmation and reveal details |
| Approach an Echo | Echo in their current location | Echo token/body | Echo acknowledges attention before the contextual choices appear | small identity/action card near a safe edge |
| Inspect a bond | two Echoes sharing a beat, or one selected Echo's relationship trace | Echo, then visible partner/relationship cue | camera frames both and shows current proximity/avoidance behavior | compact relationship context; deeper history on demand |
| Care / reassure | selected Echo, normally at Hearth, rest place, or current location | Echo or active care signal | Keeper offer is acknowledged; carer/recipient move or orient; acceptance, reinterpretation, or refusal plays | 2-4 contextual choices and consequence clue |
| Practice / teach | Training Grounds | grounds, trainer, or active practice beat | participants gather, perform a short exchange, and show fatigue/confidence/rivalry response | session choice, participant summary, outcome text |
| Assign a duty | relevant institution | institution or its worker marker | candidate visits the place, considers the role, then claims, conditions, or refuses it | candidate comparison only after entering place focus |
| Establish a place | visible candidate site | site marker in the world | site previews its footprint; confirmation produces a short founding/construction beat; first visitors react | cost and blocker confirmation |
| Craft / repair / equip | Smithy and physical object | workshop, crafter, or object | material/object appears at workbench; assigned Echo works; recipient claims, equips, lends, or rejects | recipe/reference panel anchored to Smithy focus |
| Pledge / review a vow | Ase Flame, Old Great Tree, or Council Hall according to vow context | active vow/rite marker at place | participants gather; words/gesture are witnessed; house reacts | vow text, obligations, costs, confirmation |
| Inspect reserve | Thread Alcove | visible Thread presence/object | Threads respond through light, motion, sound, and interested Echo behavior | reserve list appears only while Alcove is focused |
| Begin Weaving Rite | Weaving Court | court after selecting an Echo/Thread, or an Echo's ritual bid | chosen Echo and Thread travel to the space; witnesses approach/avoid; invitation and resolution occur there; aftermath changes positions and behavior | focused clue/choice surface; no disconnected rite screen |
| Mediate conflict | live participants and their current place | conflict signal or one participant | camera frames participants; Keeper choice interrupts or enters the beat; each Echo responds separately | compact intervention choices and reason summaries |
| Prepare party | departure threshold / staging ground | threshold or announced departure signal | selected Echoes gather with gear; non-party Echoes may assist, object, or say farewell | roster comparison and preparation detail appear around this context |
| Depart / return | house threshold | assembled party / threshold | departure formation leaves; returning group physically arrives before consequences unfold | minimal confirmation; return summary after spatial reactions begin |
| Review Continuity growth | Ase Flame and changed house places | flame, new growth signal, or candidate site | flame/house responds; eligible sites or institution variants become visible in the world | concise band/candidate explanation |
| Remember / grieve | memorial trace, preferred place, Old Great Tree, or claimed object | visible absence/trace | visitors approach or avoid; routine interruption and grief response play spatially | chronicle entry and optional deeper history |
| Mythic recognition | fitting rite/office/place chosen by house state | recognition signal at that place | house gathers; proposal, acceptance/refusal, and changed social positions are visible | ceremonial choices and aftermath summary |

This table is a prototype interaction map, not final screen architecture. A place may own several related verbs. Avoid turning the Sanctum into a feature theme park with one kiosk per system.

### 11.6 Direct world interaction model

The default input loop is:

1. **Point:** hover, focus, or touch reveals a restrained affordance on an Echo, place, object, or live beat.
2. **Select:** click/tap acknowledges the subject and eases the camera into a readable focus composition.
3. **Read:** the subject's current action, strongest relevant clue, and available verbs appear.
4. **Choose:** a compact contextual control exposes only the choices relevant now.
5. **Stage:** participants move, orient, gather, handle objects, or prepare the space.
6. **Commit:** the last reversible confirmation occurs before resource spend or irreversible ritual resolution.
7. **Resolve:** animation, spatial reaction, state change, and short text communicate the result.
8. **Release:** the contextual UI withdraws; the altered world remains.

Rules:

- Empty-space input pans/recenters the house; it does not open a general navigation menu.
- Selecting a moving Echo follows or focuses that Echo without stopping the pulse unless a direct interaction requires a short decision pause.
- Selection never teleports an Echo to a feature. Movement to the place is part of the beat.
- If a required participant is absent, unavailable, unwilling, or blocked, the place shows why and offers any legitimate next step.
- Repeated clicks do not stack duplicate interactions.
- Camera movement must preserve orientation. A player should always understand where the focused place sits in the wider home.
- `Back` first collapses contextual UI, then returns to house overview; it does not discard a committed atomic resolution.
- Keyboard/controller focus order must reach every clickable world subject through a spatial cursor or equivalent focus graph.

### 11.7 Embodied beat grammar

Every significant action uses some or all of this reusable presentation grammar:

`signal -> focus -> approach -> gather -> prepare -> perform -> interpret -> aftermath -> release`

Starting presentation targets:

- focus acknowledgement: immediate, within 100 ms;
- camera settle: 250-450 ms;
- short approach/gather: 0.5-2 seconds depending on distance;
- major action beat: 3-8 seconds at normal speed before optional detailed aftermath;
- important response appears before participants disperse;
- fast presentation shortens travel and holds, not the causal order;
- reduced motion uses cuts, fades, orientation changes, and clear spatial markers instead of long travel or camera sweeps.

These are starting values. Shorten them if place use feels ceremonial every time; lengthen only if observers cannot identify who participated, where the action happened, or what changed.

### 11.8 Required signature beats

#### Summoning at the Ase Flame

1. The player selects the visible flame/circle.
2. The world signals charge, cost, availability, and current witnesses.
3. A compact confirmation names the grade and Ase commitment.
4. On confirmation, the camera protects the circle as the critical focus area.
5. Nearby Echoes approach, keep distance, or turn to watch according to identity and current state.
6. The flame builds; a form and returned name emerge in the circle.
7. The newcomer reacts before any profile panel dominates the view.
8. Existing Echoes produce restrained spatial reactions.
9. The newcomer chooses an initial person, place, or withdrawal path.
10. The reveal/reference surface becomes available after the arrival has landed in the world.

#### Weaving at the Rite Space

1. Thread interest becomes visible at the Alcove and on resonating Echoes.
2. The player focuses the Alcove or responds to an Echo's ritual bid.
3. The selected Thread and Echo are confirmed with fit/readiness/strain clues.
4. The Thread presence and Echo travel to the Weaving Court.
5. Witnesses gather, observe from a distance, object, or withdraw.
6. Invitation signals play through body orientation, voice/text, Thread response, and the place itself.
7. Once committed, resolution remains atomic even if presentation is accelerated.
8. Accept, Reject, or Defer changes the selected Echo and the behavior of witnesses before a summary appears.
9. The Thread settles into the Echo, returns to the Alcove, or leaves a visible ritual trace.

If these sequences are replaced by a button, transition, and result modal, the prototype has failed its place-first contract even if the simulation result is correct.

## 12. Echo Readability and Learning

The player learns an Echo through four layers:

1. **At a glance:** name, Calling state, emotional read, activity, urgent signal.
2. **By observing:** preferences, proximity choices, avoidance, work style, reactions, and routine.
3. **By approaching:** conversation, offer, question, care, challenge, mediation, or preparation.
4. **By history:** relationships, remembered acts, Thread changes, duties, vows, and prior Keeper choices.

The Echo detail surface should answer:

- Who are they now?
- What are they doing and why?
- What are they drawn toward or resisting?
- Who matters to them?
- What changed recently?
- What might they need before departure?
- What remains unknown or incomplete?

It must not reduce the Echo to raw numbers. Debug mode may expose scores, but normal mode uses stable clues and short attributed explanations.

The default Echo detail is contextual and keeps the Echo visible. A full reference view may exist for comparing progression, skills, equipment, or long history, but opening it is an explicit deeper-inspection action rather than the consequence of every click.

## 13. Keeper Interaction Vocabulary

The prototype supports a small, reusable verb set.

| Verb | Purpose | Possible interpretation |
|---|---|---|
| **Observe** | Learn without interrupting | Echo notices or does not notice attention |
| **Speak** | Invite a short exchange | opens, deflects, questions, objects, withdraws |
| **Reassure** | Reduce acute strain | accepts care, asks for space, becomes dependent, feels patronized |
| **Challenge** | Push reflection or readiness | grows, resents, clarifies, refuses |
| **Ask** | Seek opinion, memory, or preference | reveals clue, uncertainty, bias, or bid |
| **Invite** | Suggest person, place, work, rite, or activity | accepts, modifies, delays, rejects |
| **Mediate** | Enter a live social tension | repairs, redirects, chooses a side, worsens pressure |
| **Assign** | Offer a duty or office | claims, tries, strains, refuses |
| **Teach / Practice** | Prepare or share knowledge | skill growth, bond movement, fatigue, rivalry |
| **Offer** | Present Thread, object, role, or recognition | resonance, contest, attachment, rejection |
| **Release** | Remove duty, vow, role, or expectation | relief, fear, hurt, loss of purpose |
| **Remember** | Mark a beat as house-significant | creates a chronicle entry or future callback |

Not every verb is available in every context. The selected Echo, place, or live beat determines which verbs exist. UI must explain why a visible choice is unavailable.

Important interactions acknowledge input immediately, show the Echo's response, and reveal a visible state or future consequence. Dialogue without systemic consequence may exist as ambience, but it cannot carry the prototype alone.

The contextual action surface should normally contain no more than four first-level choices. Less common verbs belong behind a clearly named `More`/detail affordance or a deeper reference view, not in a permanent action bar.

## 14. Social Life and Bonds

### 14.1 Social beat structure

Every authored or generated social beat uses:

1. **Trigger:** why these Echoes meet now.
2. **Want:** what each participant is seeking or protecting.
3. **Friction:** why the wants do not align cleanly.
4. **Keeper window:** what the player may observe or influence.
5. **Echo response:** how each participant interprets the intervention.
6. **Consequence:** emotion, bond, duty, place, memory, vow, or future-behavior change.
7. **Echo:** a possible callback in later house or Realm play.

### 14.2 Foundation incident families

The prototype includes at least one reusable template for each canon family:

- care / recovery;
- rivalry flare-up;
- recognition / praise / jealousy;
- protective intervention;
- omen / unease.

Add home-life templates for:

- welcome / territorial tension;
- teaching / impatience;
- shared work / uneven burden;
- quiet companionship / unwanted attention;
- preparation disagreement;
- return celebration / survivor discomfort;
- remembrance / grief avoidance.

### 14.3 Relationship shape

Bonds are not a single friendship ladder. The prototype may retain one underlying strength value for production alignment, but presentation and behavior should distinguish:

- trust;
- affection;
- admiration;
- dependence;
- rivalry;
- resentment;
- protectiveness;
- unresolved obligation.

These may be tags or recent-memory qualifiers rather than full independent meters. The goal is differentiated behavior, not more bars.

### 14.4 Social surprise constraints

Surprise is welcome when it follows recognizable inputs. A strange pairing should make sense after the player notices shared place, complementary need, mutual history, or productive disagreement.

Fail conditions:

- random comedy disconnected from identity;
- repeated scenes with names swapped;
- universal friendship as the optimal house;
- rivalry that is only a penalty;
- every incident waiting for the Keeper to solve it.

## 15. Incident, Warning, and Escalation Model

Pressure progresses through:

`ambient signal -> warning -> surfaced incident -> unresolved mutation -> aftermath`

Rules:

- Ambient signals do not block play.
- Warnings identify who or what is under pressure and provide at least one plausible cause.
- A surfaced incident creates a meaningful choice, not a compulsory click.
- Ignored pressure does not simply vanish; it mutates after a visible grace period.
- The player may help, defer, decline involvement, choose a side, or act harmfully when fiction permits.
- Echoes can resolve some incidents without the Keeper, especially at higher maturity.
- Autonomous resolution still produces a visible result and may not match the Keeper's preferred outcome.

Only one blocking incident may demand resolution at a time. Other pressure remains spatially visible and queued. This prevents the home from becoming a notification cascade.

## 16. Institutions, Jobs, and Duties

### 16.1 Foundation institution set

| Institution | Job / office | Healthy expression | Failure pressure |
|---|---|---|---|
| Hearth | Cook / Bartender | recovery, social mixing, relief, reconnection | hollow comfort, rumor distortion, hidden strain |
| Training Grounds | Trainer | readiness, disciplined practice, courage | depletion, humiliation, hierarchy hardening |
| Council Hall | Mayor | mediation, recognition, house rules | favoritism, procedural distance, authority conflict |
| Smith / Crafter | Armorer / Smith | repair, preparation, material expression | overwork, unequal access, tool/status envy |
| Old Great Tree | Caretaker / Spirit Guide | remembrance, omen reading, spiritual care | unease, burden concentration, false interpretation |

The first two are production-aligned early anchors. The remaining three are accelerated horizon fixtures based on the GDD foundation direction.

### 16.2 Assignment rules

- A building exists before its formal job normally becomes available.
- The Keeper offers an assignment; the Echo may accept, try under strain, request conditions, or refuse.
- Compatibility comes from living identity, not birth archetype alone.
- A duty changes where the Echo spends time and which incidents they can create or resolve.
- Fulfilling, failing, and overperforming are all meaningful states.
- Removing a well-fitting duty may create loss, anger, fear, or relief.
- An institution's health depends on use, fit, social context, Realm pressure, and support—not only elapsed time.

### 16.3 Duty cycle

`unassigned -> offered -> claimed/trial -> active -> fulfilled | strained | failed | overperformed -> renewed/released`

Overperformance is not always optimal. It can build Continuity and recognition while creating exhaustion, resentment, dependence, or institutional imbalance.

## 17. Summoning and Arrival

Summoning is an act of welcome and responsibility, not only roster acquisition.

Prototype flow:

1. Select the visible Ase Flame summoning circle.
2. Read its charge/availability in the world and open a compact grade/Ase confirmation.
3. Commit and perform the summoning at the circle.
4. Reveal the returned name, archetype, emotional state, and fragmentary tendencies only after the new Echo has visibly emerged.
5. Let existing Echoes approach, watch, avoid, or react according to density, bonds, duties, status pressure, and house condition.
6. Give the Keeper one first-response choice while the newcomer remains present in the circle.
7. Let the new Echo choose an initial place, person, or withdrawal behavior and move there.
8. Create a first-arrival memory attached to the summoning place and initial destination.

The prototype must test whether adding an Echo feels like changing the household, not receiving a card.

Arrival risks include:

- territorial tension;
- lack of social place;
- competition for work, recognition, or care;
- pressure on strained institutions;
- mismatched expectations from the Keeper;
- immediate resonance with a person, room, vow, or Thread.

## 18. Emotion, Care, and Recovery

Fear and morale remain authoritative production-aligned states. Prototype needs and incident tags contextualize them rather than replacing them.

Care can come from:

- rest and safety;
- proximity to a trusted Echo;
- a well-matched Hearth or caretaker;
- being heard by the Keeper;
- useful work;
- successful practice;
- ritual or omen clarity;
- preparation that addresses a known fear;
- time after a Realm return.

Care can fail when:

- the Keeper chooses the wrong intervention;
- attention feels controlling or patronizing;
- a caretaker is overburdened;
- comfort conceals a conflict;
- a vow or duty demands the opposite;
- social presence is itself the source of strain.

Important rule: “reassure” is not a universal morale button. Care is an interpretive act.

## 19. Vows, Customs, and House Culture

### 19.1 Vows

Vows act as doctrine overlays across the house and Realm loop.

In the Sanctum they should influence:

- what behavior is praised or questioned;
- which duties feel coherent or strained;
- what preparation Echoes request;
- incident interpretation;
- who feels recognized or constrained;
- the emotional and Continuity cost of breaking the vow.

### 19.2 Customs

Prototype house customs are repeated decisions that stabilize into a recognizable pattern.

Example custom seeds:

- everyone gathers at the Hearth after a return;
- the returning party reports before resting;
- rivals train together under supervision;
- a recovered Thread is never woven on the day it returns;
- no one leaves while a household conflict is openly unresolved;

A custom emerges only after the player repeats or affirms the pattern. Once stabilized, it:

- changes intention and incident weights;
- contributes to Institutional Pattern;
- creates expectation and possible violation;
- gives the home a player-shaped identity.

The prototype uses three custom slots and a small fixed library. It does not implement freeform rule authoring.

## 20. Threads, Reserve, and the Weaving Rite

### 20.1 Reserve life

Threads in reserve are spiritually present in the home. They can:

- draw particular Echoes near;
- produce omen or unease signals;
- create contest and jealousy;
- make some places feel charged;
- become harder to read under overflow or contamination pressure.

The reserve is not a passive inventory list.

### 20.2 Rite flow

Use the canon foundation flow:

1. notice Thread interest in the visible house;
2. approach a resonating Echo or select the Thread Alcove;
3. inspect the reserve through that Echo's possible relationship to it;
4. choose a Thread and read fit, readiness, and strain clues;
5. confirm the participants and move them to the visible Weaving Court;
6. begin the invitation phase in the world;
7. commit once begun;
8. resolve foundation outcomes `Accept`, `Reject`, or `Defer` at the rite space;
9. show immediate personal and witness aftermath before opening a summary;
10. leave consequences and any ritual trace in house life.

Accelerated horizon scenarios may enable `Partially Integrate` and `Distort`, clearly marked as non-foundation outcome tests.

### 20.3 Contest

Other Echoes who strongly resonate with the Thread may visibly approach, watch, withdraw, object, or react later. The Keeper chooses a recipient but does not erase other claims.

Non-chosen fallout should be social and emotional first:

- bond strain;
- rivalry;
- sadness or morale loss;
- future hesitation;
- rare acting out or refusal.

### 20.4 Rite success condition

The player should be able to explain:

- why they chose this Echo;
- which clues suggested readiness or danger;
- how the chosen Echo responded;
- why another Echo reacted;
- what visibly changed in the house afterward.

## 21. Continuity and Building a Home

Continuity is the visible house progression spine: the Sanctum becoming a society.

The prototype tracks:

- visible Continuity;
- hidden Memory;
- hidden Social Fabric;
- hidden Institutional Pattern.

### 21.1 Contribution priorities

1. Recovered and integrated stories provide the strongest individual gains.
2. Stabilized customs and institutional patterns provide the next strongest gains.
3. Meaningful relationship growth and incident resolution provide medium gains.
4. Positive minor beats provide small gains.
5. Ambient routine alone provides no gain unless repetition becomes a stable pattern.

### 21.2 Six accelerated bands

The sandbox can jump among the canon bands:

1. Awakening
2. Habit
3. Role
4. Governance
5. Differentiation
6. Cultural Maturity

Each band changes more than a label. It should affect:

- which spaces and roles are possible;
- how independently Echoes manage social life;
- which incidents can appear;
- how much history the house can carry;
- which customs and rites can stabilize;
- how clearly the house expresses a particular cultural shape.

### 21.3 Unlock candidates

Show two or three candidate developments based on:

- Continuity band and internal threshold;
- Memory, Social Fabric, and Institutional Pattern;
- recovered story/virtue state;
- current contradiction and strain.

Blocked candidates remain visible with a short reason. The player should understand what kind of house is becoming possible without seeing exact formulas.

## 22. Economy, Crafting, Objects, and Gifts

### 22.1 Currency roles

- **Ase:** summoning, rites, Thread handling, spiritual enactment, and significant assignment acts.
- **Ekwan:** institutions, construction, crafting, repair, and material preparation.
- **Relics:** rare artifacts, equipment, catalysts, and memory-bearing objects.

Continuity and Threads are not spendable wallet currencies.

### 22.2 Light crafting

The prototype includes one recipe in each useful category:

- a weapon or training tool;
- a charm affecting readiness or emotional stability;
- a protective garment/armor item;
- a one-use Realm preparation item;
- one memory-bearing furnishing or institution object.

Crafting should involve at least one choice between:

- immediate party readiness;
- institution health;
- an Echo's personal attachment;
- saving Ekwan for house growth.

### 22.3 Claimed objects

An Echo may ask for, prefer, avoid, share, lend, damage, repair, or claim an object. Claimed gear can become a home trace and later a grief, relic, rivalry, or recognition hook.

The prototype does not need a gift-every-day affection loop. Giving matters when it responds to an observed person or situation.

## 23. Preparation and Departure

Party preparation begins in the house rather than in an abstract loadout spreadsheet.

The player should:

1. select the visible departure threshold and signal an intended Realm departure;
2. see who is available, recovering, committed to duty, eager, fearful, or resistant in their current places;
3. ask Echoes for their read of the party and known pressure;
4. choose the party through a focused comparison while the house remains the context;
5. review social coherence, likely protection, rivalry, vow fit, and preparation gaps;
6. assign light equipment or complete one preparation action;
7. confirm departure;
8. watch party members move from their current places, gather at the threshold, equip or assist one another, and depart while others react.

The prototype uses simulated Realm result packages:

- strong victory;
- costly victory;
- partial/withdrawal with intel;
- defeat with survivors;
- death;
- companion recruitment opportunity;
- Thread-bearing Realm completion.

The same selected party and preparation should produce deterministic return consequences for a given result seed.

## 24. Return, Consequence, and Reintegration

Returning home is a playable transition, not a reward popup followed by reset.

Resolve in this order:

1. the party appears at the threshold;
2. urgent injury, death, companion, Thread, vow, and overflow states are signaled;
3. non-party Echoes react based on bonds, rivalry, duties, and house condition;
4. the Keeper chooses one immediate priority when several needs conflict;
5. the house absorbs economic and emotional consequences;
6. one return-specific beat may surface;
7. affected Echoes choose recovery, company, work, withdrawal, argument, or rite interest;
8. the next normal pulse begins with this altered state.

Pass if the player can see that the same Realm outcome would land differently in a different house.

## 25. Death, Grief, and Absence

Death must change the home spatially and socially.

Minimum death ripple:

- remove the Echo from active presence and roster availability;
- create a visible absence at a familiar place or duty;
- apply fear/morale and bond-shaped grief responses;
- create an unfilled job or broken routine if applicable;
- surface at least one Sanctum incident;
- preserve a chronicle entry and possible object/memorial trace.

Responses may include grief, numbness, anger, guilt, relief, hostile satisfaction, or silence when relationship history supports it. Hostile or celebratory reactions must be rare and legible, not shock content.

Accelerated scenarios may test relic formation from a claimed object or defining act.

## 26. Mythic Recognition and Departure (Accelerated Horizon)

The prototype does not implement the full mythic progression path. It provides one mature fixture Echo and a scenario launcher for:

`mythic-ready -> recognition proposed -> rite undertaken -> house recognition offered -> affirmation/failure`

The scenario tests whether:

- the house recognizes what the Echo actually became;
- an offered office or rite can fit or mismatch;
- the Echo may refuse recognition;
- other Echoes react to elevated status;
- the house's routines and institutions change;
- mythic presence creates obligation and pressure, not only power;
- later departure feels like agency and consequence rather than content deletion.

This is included to test the Sanctum's long-term emotional promise, not to validate final mythic balance.

## 27. Required Prototype Scenarios

The sandbox includes scenario presets:

1. **Dormant House:** one unsettled starter Echo, Ase Flame not fully awake.
2. **Second Arrival:** summon a new Echo into a two-person household.
3. **Warm but Strained:** Hearth healthy, one caregiver overburdened, one quiet conflict.
4. **Training Rivalry:** Training Grounds healthy, status pressure rising between two Echoes.
5. **Return With Fear:** party returns from failure with useful intel and uneven emotional fallout.
6. **Return With a Thread:** reserve gains a contested Thread and several Echoes respond.
7. **Weaving Aftermath:** run Accept, Reject, and Defer variants from the same house state.
8. **Broken Vow:** house culture and multiple relationships react to a breach.
9. **Death in the House:** a familiar Echo is absent; duty, place, bonds, and routine are disrupted.
10. **Growing Institution:** choose between two candidate developments and observe different house patterns.
11. **Cultural Maturity:** mature house with several roles, customs, accumulated traces, and conflicting obligations.
12. **Recognition:** a mythic-ready Echo receives a fitting or mismatched recognition proposal.

Each scenario must support same-seed replay and at least two materially different Keeper choices.

## 28. Minimum Fixture Household

Use six deliberately differentiated fixture Echoes:

1. A steady protector who seeks responsibility and watches vulnerable housemates.
2. A proud training-focused Echo who needs recognition and resists pity.
3. A reflective seeker drawn to Threads, quiet places, and uncertain meanings.
4. An empathic caregiver vulnerable to overwork and emotional spillover.
5. A canny social adapter who can mediate, gossip, or redirect pressure.
6. A fearful or volatile newcomer whose sense of belonging changes visibly.

Across fixtures, vary:

- Standing and maturity band;
- archetype;
- dominant virtue direction;
- Calling state;
- fear and morale;
- bonds and rivalry;
- job fit;
- recent Realm history;
- vow fit;
- Thread resonance;
- preferred and avoided places.

Fixtures are instruments, not canonical characters.

## 29. Required UI and Feedback

The main viewport is a clickable spatial home, not a dashboard and not a simulation playing behind an interface.

The UI direction follows the review questions in Nicolas Kraj's [Designing Efficient User Interfaces for Games](https://medium.com/@nicolaskraj/designing-efficient-user-interfaces-for-games-be20b516f1c2): first ask whether UI is needed, use signs and feedback beyond icons and panels, protect the experience's critical focus area, show information only in the context where it matters, minimize eye travel along the player's actual flow, and test the worst-case density.

This is not a “no UI” rule. Fully diegetic presentation can be expensive, slow, missable, or less accessible. The prototype should deliberately combine world, spatial, meta, and conventional interface techniques according to what communicates each fact most clearly.

### 29.1 Information channel policy

Use the lightest effective channel in this priority order:

1. **World behavior:** Echo movement, posture, orientation, proximity, object use, place condition, lighting, VFX, environmental change, and animation.
2. **Spatial UI:** restrained labels, outlines, pips, speech/thought cues, route/focus markers, and warning symbols anchored to the relevant person or place.
3. **Contextual UI:** a compact edge card or action ribbon shown only after focus or during a decision.
4. **Reference UI:** a larger panel or full view for dense history, comparison, inventory, progression, help, accessibility, settings, and debug data.

Do not use an icon when an Echo can visibly perform the behavior. Do not use animation alone when the state is decision-critical but subtle. Important information may use more than one channel.

### 29.2 Critical focus area

The critical focus area is the active place, all participating Echoes, the space between them, and any object or path needed to understand the beat.

Rules:

- Permanent UI stays at safe edges and remains visually subordinate to the house.
- Contextual UI is placed near the player's current eye flow but outside the active action when possible.
- The camera may recompose to create a safe edge for choices rather than laying a panel over participants.
- During summoning, rites, return, conflict, grief, and recognition, nonessential status and navigation recede.
- A world-space cue may not obscure the face/body/object behavior it explains.
- Wide-screen surplus belongs primarily to the visible house and its surrounding life, not larger panels.

### 29.3 Context states

#### House overview

Visible:

- the Ase Flame and house layout;
- all present Echoes at their current places;
- ambient activity through motion, pose, object use, and restrained spatial cues;
- current Ase, Ekwan, Continuity band, pulse state, and any genuinely urgent house signal;
- lightweight affordances for selectable places and people.

Hidden or collapsed:

- full roster;
- full Thread reserve;
- all institution statistics;
- full relationship graph;
- full chronicle;
- detailed progression and equipment;
- unavailable actions unrelated to the current subject.

#### Person/place focus

Visible:

- selected subject and its spatial context;
- current action/condition and strongest relevant clue;
- normally 2-4 contextual verbs;
- one compact detail surface;
- nearby people or objects that materially affect the decision.

#### Active beat

Visible:

- participants, location, relevant object, response state, and decision if one exists;
- only the resource/cost/risk information needed before commitment;
- short aftermath once the embodied response has landed.

Nonessential HUD and unrelated signals recede until the beat releases focus.

#### Reference view

A deeper panel or full view is appropriate for:

- comparing several Echoes for a party, job, or equipment decision;
- reading long history or the chronicle;
- examining full skill/progression detail;
- inventory and recipe browsing at the relevant place;
- rules/help, accessibility, settings, and debug tools.

Reference views are entered from a world subject or an explicit utility action. Closing them returns the player to the same place, camera, selection, and pulse context.

### 29.4 World affordance states

Every interactive world subject uses a shared readable state grammar:

| State | Required signal |
|---|---|
| Idle | natural animation/silhouette; no permanent outline required |
| Hovered / focused | restrained outline, lift, name, or local light response |
| Selected | clear focus ring/marker and contextual acknowledgement |
| Has a quiet beat | subtle activity or relationship cue anchored to subject |
| Requests attention | distinct but non-urgent bid signal |
| Warning | stronger place/person signal with time-to-mutation clue |
| Urgent / blocking | unique highest-priority signal; only one at a time |
| Unavailable | remains visible in-world with concise blocker on focus |
| Committing | input lock/commit cue attached to subject and place |
| Changed | short aftermath signal followed by a persistent world-state difference |

Affordances must work with mouse, touch, keyboard, and controller. Color cannot be the sole differentiator.

### 29.5 Persistent UI budget

Prototype starting constraint:

- one restrained persistent status/chrome region at the safe edge;
- one contextual choice/detail surface at a time;
- up to three simultaneous non-urgent spatial signals;
- one urgent/blocking signal at a time;
- transient barks or consequence text capped so they cannot cover a subject or input target;
- debug UI excluded from normal-mode readability tests.

The exact count may change through playtest, but adding a second permanent panel requires removing or collapsing something else.

The persistent region may contain:

- Ase and Ekwan;
- Continuity band/progress in a compact form;
- pulse state and prototype speed controls;
- a single current priority or unresolved urgent state;
- explicit utility access to reference, help, settings, and debug.

It should not contain permanent buttons for Summon, Weave, Craft, Train, Vows, Institutions, Party, or individual Echoes. Those verbs begin from their places and people.

### 29.6 Attention hierarchy

1. Blocking return/rite/death/recognition aftermath.
2. Urgent incident or imminent mutation.
3. Echo request or institution warning.
4. Ambient social beat.
5. Routine and decorative life.

No more than one layer may visually demand immediate action.

### 29.7 Feedback rules

- Player input receives immediate acknowledgment.
- An Echo response appears before the resulting behavior change.
- Important outcomes use at least two channels: spatial behavior plus text, sound, VFX, object, or world-state change.
- Bond or emotion changes identify the triggering beat in plain language when inspected; raw deltas need not float over the world.
- A changed routine, place, relationship, or preparation becomes visible in the house within one pulse.
- Hover/focus/selection can reveal detail, but critical warnings cannot rely on hover.
- Contextual UI appears near the relevant player flow and disappears when no longer needed.
- UI never reconstructs a beat that the world failed to show.
- Reduced-motion mode replaces travel flourishes with clear state transitions.

### 29.8 Worst-case safeguards

Test at minimum:

- six Echoes clustered around one place;
- three simultaneous ambient beats plus one warning;
- a return with a Thread, companion offer, vow consequence, emotional fallout, and institution pressure;
- compact 960x540 layout;
- longest expected names and localized copy expansion;
- controller focus while Echoes move;
- world subjects partially occluded by other subjects;
- no ambient activity and no warning, ensuring remaining UI does not look detached or empty.

If signals collide, prioritize by the attention hierarchy, cluster low-priority cues at their place, and defer summaries to the chronicle. Never stack notifications over critical world input.

### 29.9 Chronicle

The chronicle records only significant beats:

- arrival;
- relationship threshold or defining conflict;
- claimed duty or office;
- vow pledge/break;
- Thread outcome;
- defining Realm act;
- death or departure;
- institution founding;
- stabilized custom;
- mythic recognition.

It is not a raw event log. Debug mode owns the complete log.

## 30. Five-Component Experience Requirements

| Component | Prototype requirement | Acceptance check |
|---|---|---|
| Clarity | Intent, pressure, response, and consequence have visible signals. | A new player explains 8/10 sampled beats without debug data. |
| Motivation | Interactions affect people, home, preparation, or future risk. | Players voluntarily follow at least two non-urgent Echo activities per session. |
| Response | Keeper choices can redirect, deepen, defer, or worsen situations. | At least 70% of deliberate interactions create a visible change within one pulse. |
| Satisfaction | Home growth and relationship outcomes have spatial and narrative payoff. | Players can name three things that made the house feel more “theirs.” |
| Fit | Tone and mechanics express stewardship, recovery, memory, and personhood. | Players describe the experience as a living home, not a base-management screen. |

## 31. Anti-Chore and Retention Ethics

The prototype must not use:

- daily streaks;
- expiring gifts or mail;
- affection decay from real-world absence;
- arbitrary chores needed to keep everyone content;
- constant red notification badges;
- manipulative scarcity around ordinary social contact;
- rewards for repeatedly exhausting every dialogue option;
- real-time waiting as a substitute for gameplay.

Reasons to return should be:

- affection for specific Echoes;
- curiosity about unresolved pressure;
- desire to see the house change;
- mastery of stewardship;
- anticipation of Realm consequences;
- discovery of routines, relationships, memories, and cultural shape.

Offline Ase may be represented as a scenario input, but real-world offline timing is outside this prototype.

## 32. Debug and Instrumentation

Normal mode shows player-facing explanations. Debug mode may show:

- seed and pulse index;
- intention candidates and scores;
- chosen primary and competing reason;
- need pressures;
- relationship and incident triggers;
- institution compatibility and strain;
- Continuity contributions and hidden sublayers;
- event eligibility, cooldown, and budget;
- rite fit/readiness/strain inputs;
- before/after save-state diff;
- deterministic hash of the simulation state.

Log these playtest metrics:

- time spent interacting with the world vs inside reference/management UI;
- percentage of major system entries initiated from a visible world subject;
- world subjects selected and contextual actions taken;
- contextual UI open time and full-screen reference-view time;
- ambient beats voluntarily followed;
- interactions initiated per session;
- interventions accepted, reinterpreted, refused, or ignored;
- incidents helped, deferred, declined, autonomously resolved, or worsened;
- repeated routines recognized by the player;
- relationship changes correctly explained;
- meaningful choices named after play;
- number of blocking interruptions;
- same-seed divergence caused by player choice;
- preparation choices that visibly affect return state;
- desire to revisit the household.

## 33. Playtest Matrix

### Test 1: Does it feel like home?

- Play for 15 minutes, then hide the interface.
- Ask the player to describe the house, its important places, and who belongs where.
- Pass if they describe at least three place-person-history associations without referring mainly to bonuses.

### Test 2: Echo recognition

- Observe ten autonomous choices across the fixture household.
- Ask why each Echo acted.
- Pass if the main reason is correctly inferred in at least eight cases.
- Fail if answers are “random” or based only on class/build.

### Test 3: Quiet-life interest

- Provide five minutes with no blocking incident.
- Pass if the player voluntarily follows at least two Echo activities or relationships.
- Fail if the house feels like waiting for a notification.

### Test 4: Serious social surprise

- Trigger three unusual pairings or reactions.
- Pass if at least two are surprising but retrospectively understandable.
- Fail if they feel like interchangeable comedy sketches.

### Test 5: Keeper influence

- Replay one seed with two different interaction choices.
- Pass if the resulting relationship, activity, duty, or preparation differs visibly within three pulses.
- Fail if choices only change dialogue.

### Test 6: Autonomy without helplessness

- Issue fitting and conflicting invitations to several Echoes.
- Pass if align/reinterpret/refuse outcomes are understandable and give the player a next option.
- Fail if refusal feels like lost input or if every Echo obeys.

### Test 7: Institution as place

- Establish or activate the Hearth and Training Grounds.
- Pass if each changes who gathers, what happens, and which pressure emerges—not only a stat.

### Test 8: Arrival changes the household

- Summon a new Echo into an existing house.
- Pass if at least three visible states change: spatial behavior, social response, duty/institution pressure, routine, resource pressure, or preparation.

### Test 9: Return reintegration

- Apply the same costly-victory package to two different house presets.
- Pass if the resulting social and recovery patterns differ for legible reasons.

### Test 10: Rite consequence

- Resolve Accept, Reject, and Defer from matched starting states.
- Pass if each outcome changes both the chosen Echo and wider house life.

### Test 11: Chore resistance

- Let several minor pressures coexist.
- Pass if the player can ignore, delegate, or defer them without a cascade of arbitrary punishment.
- Fail if optimal play becomes clearing every icon.

### Test 12: Memory and continuity

- Advance an accelerated household across several scenarios.
- Pass if the player can identify at least four persistent traces of prior decisions and one distinct house cultural pattern.

### Test 13: Grief and absence

- Apply a death package to a known fixture Echo.
- Pass if the loss changes place, routine, duty, relationships, and mood without becoming melodramatic notification spam.

### Test 14: Preparation payoff

- Prepare the same party in two different ways, then apply the same seeded Realm pressure.
- Pass if the return report and reintegration visibly reflect at least one social and one material preparation difference.

### Test 15: Long-horizon promise

- Run the recognition scenario.
- Pass if the player understands why the recognition fits or fails and can name how it would change home life.

### Test 16: Place-first system access

- Ask a new player to summon, inspect a strained relationship, assign a trainer, prepare a party, inspect a Thread, and begin a rite.
- Pass if at least five of six are initiated by selecting the correct person, place, object, or live signal without opening a general feature menu.
- Fail if the player searches a permanent navigation bar for the system.

### Test 17: UI balance

- Run house overview, person focus, summoning, crowded incident, preparation, and rite contexts.
- Pass if players can identify the next useful action, necessary resource/risk, and affected subject without the UI obscuring the active place or participants.
- Fail if removing a panel makes the world incomprehensible, or if UI is so hidden that players hunt for basic actions.

### Test 18: Embodied causal chain

- Sample ten significant actions.
- Ask an observer who initiated the action, where it happened, who participated, what the response was, and what changed.
- Pass if at least eight are explained correctly before opening a result summary.
- Fail if the summary carries information the staged beat did not communicate.

## 34. Prototype Success Criteria

The prototype is worth developing further only if:

- at least 80% of sampled autonomous beats are explainable without debug data;
- at least 80% of major Sanctum system entries originate from a visible person, place, object, or event;
- players voluntarily observe non-urgent life at least twice in a 15-minute session;
- each session produces at least three remembered person/place/history associations;
- at least 70% of deliberate Keeper interactions visibly affect behavior or state within one pulse;
- at least two institutions create distinguishable social rhythms and failure pressures;
- summoning visibly changes the household beyond roster count;
- Realm return creates at least one personal, one social, and one house-level consequence;
- players can identify at least three persistent traces of their choices;
- players can point to at least one visible, non-stat choice that made this house feel like their version of home;
- observers correctly identify the place, participants, response, and consequence of at least 8/10 significant staged actions without relying on a result panel;
- full-screen reference/management UI occupies less time than direct world interaction in a typical session;
- refusal is read as character expression rather than broken control in at least 8/10 cases;
- incident management does not collapse into clearing icons;
- players describe the Sanctum as a home or household more often than as a hub, menu, or base;
- players want to revisit the same household to see what happens next.

These thresholds are starting hypotheses and may change only after results are recorded.

## 35. Stop Conditions

Stop or redesign after one focused tuning pass if:

- the spatial house can be removed without changing decisions;
- major systems are faster or clearer to reach through a permanent feature bar than through their places;
- summoning, Weaving, preparation, crafting, or institutional work resolves primarily inside a panel while the world waits behind it;
- Echoes differ mainly through dialogue flavor or stat labels;
- the player spends more time in management/reference panels than selecting and influencing the house itself;
- minimizing UI makes the experience unusable because the world has insufficient signs and feedback;
- spatial or diegetic cues are repeatedly missed and the design refuses conventional UI support for purity's sake;
- routines are decorative loops with no contextual meaning;
- incidents become compulsory chores or notification whack-a-mole;
- refusal is arbitrary, constant, or has no productive follow-up;
- the optimal strategy is universal friendship, constant reassurance, or assigning only perfect job fits;
- institutions function mainly as resource generators or passive buffs;
- serious beats and light beats feel tonally disconnected;
- Realm return does not materially change the home;
- accelerated advanced systems obscure the core early-house question;
- the prototype requires production campaign integration to answer its design question.

## 36. Technical Isolation Rules

- All prototype files remain inside `prototypes/sanctum_systems_exploration/`.
- Do not modify production `core/`, `ui/`, `data/`, tests, flow states, or campaign saves for the first experiment.
- The prototype may read production definitions and copy minimal deterministic logic where useful.
- Production code must never depend on prototype code.
- Use fixture households and a dedicated save path.
- Never read or write the player's production save.
- Use deterministic pulse indices and derived RNG namespaces; never use wall-clock time for simulation resolution.
- Keep simulation, presentation snapshot, UI, and playtest metrics separate.
- World selection requests actions through the prototype controller; clickable nodes never mutate simulation state directly.
- Significant resolutions emit structured beat data containing place, participants, approach paths, object use, response, aftermath, and persistent traces. Presentation must not reconstruct the event from log prose.
- Camera and beat presentation consume snapshots/results only and cannot decide outcomes.
- Build UI structure in `.tscn`; scripts render values and apply responsive profile values.
- Use slot-keyed action dictionaries if the prototype adopts production snapshot conventions.
- Do not add permanent feature-navigation buttons for systems represented by world places.
- Any candidate production change discovered during prototyping belongs in a later `FINDINGS.md`, not in production code.

## 37. Proposed Prototype Architecture

```text
prototypes/sanctum_systems_exploration/
  SPEC.md
  CONTRACTS.md                 # frozen after the first implementation pass
  FINDINGS.md                  # playtest evidence and candidate canon changes
  RUN.md
  SanctumLivingHouse.tscn
  PrototypeController.gd
  simulation/
    PrototypeHouseState.gd
    PrototypePulseService.gd
    PrototypeIntentService.gd
    PrototypeIncidentService.gd
    PrototypeMemoryService.gd
    PrototypeScenarioFactory.gd
  data/
    fixture_echoes.json
    prototype_events.json
    prototype_scenarios.json
  ui/
    PrototypeHouseView.tscn
    PrototypeHouseView.gd
    PrototypeWorldInteractionRouter.gd
    PrototypeCameraDirector.gd
    PrototypeBeatPresenter.gd
    PrototypeDetailPanel.tscn
    PrototypeDetailPanel.gd
    PrototypeChronicle.tscn
    PrototypeChronicle.gd
    PrototypeTheme.tres
  tests/
    PrototypeTestSuite.gd
    PrototypeTestRunner.gd
    PlaytestMetrics.gd
```

This is a proposed structure, not authorization to create all files during the spec phase.

## 38. Build Order

### Slice 1: A home worth inhabiting

1. Standalone scene, deterministic fixture household, pulse controls, and same-seed reset.
2. Clickable spatial house with Ase Flame, summoning circle, Hearth, Training Grounds, six Echoes, and readable activity states.
3. Camera overview/focus states, shared world affordances, contextual action surface, and protected critical focus area.
4. Intention selection with reasons, movement, quiet routines, and recent-history access.
5. Observe and Speak interactions with approach, orientation, response, and release staging.

**Gate:** the player can navigate, learn about, and influence the house for five minutes through world selection without needing a feature menu or blocking incident.

### Slice 2: People affect one another

6. Bonds, proximity, social bids, care, rivalry, and two-person beats.
7. Warning, incident, deferral, mutation, and autonomous resolution.
8. First-arrival summoning scenario staged fully at the Ase Flame circle.

**Gate:** players recognize specific Echoes, can explain social outcomes, and understand summoning as an event that happened in their home.

### Slice 3: The house develops roles

9. Institution condition, job offer/claim/refusal, duty cycle, and compatibility through place focus.
10. Hearth and Training Grounds healthy/failure rhythms.
11. Continuity, hidden sublayers, visible candidate sites, home traces, and one stabilized custom.

**Gate:** buildings feel like social places and the house acquires a distinct history.

### Slice 4: Home prepares for danger

12. Party gathering, preparation, vow pressure, light objects/crafting, and threshold departure.
13. Simulated Realm outcome packages and spatial return reintegration.
14. Death/grief and companion-arrival variants.

**Gate:** home state changes Realm preparation, and return changes home state.

### Slice 5: Recovered stories enter the home

15. Thread Alcove presence, resonance, contest, and omen pressure.
16. Weaving Court interaction, participant gathering, foundation outcomes, and house aftermath.
17. Reserve strain/overflow accelerated scenario.

**Gate:** Threads feel like contested remembered stories, not inventory upgrades.

### Slice 6: Long-house promise

18. Council Hall, Smith/Crafter, and Old Great Tree accelerated clickable fixtures.
19. Mature Continuity-band scenario and multiple house customs.
20. Mythic recognition/refusal/departure scenario staged at a fitting house place.

**Gate:** the player can imagine a long-lived, culturally distinct home without the prototype becoming a full campaign.

Do not begin the next slice until the current gate has been playtested. Later slices may be cut if earlier evidence rejects the central premise.

## 39. Promotion Decision

After playtesting, choose one evidence-backed outcome.

### Promote

The living-house loop works. Write a canonical proposal describing:

- the minimal production Sanctum pulse;
- routine and intention contracts;
- incident and escalation rules;
- spatial interaction boundaries;
- institution/job integration;
- the return-reintegration sequence;
- which prototype systems belong in Foundation and which remain later.

### Iterate once

The home feeling works, but one weakness prevents judgment. Run one narrow follow-up focused on that weakness, with new success criteria and no scope expansion.

### Narrow

The full breadth is too noisy, but one strong loop works. Preserve that loop—for example observation/social beats, institutions, or return reintegration—and remove unsupported systems from the prototype proposal.

### Reject

The simulation creates chores, noise, or opaque randomness and does not deepen attachment. Preserve useful presentation and instrumentation findings, but do not promote the living-house model.

## 40. Open Design Questions

These remain intentionally unresolved until the first playable slices provide evidence:

1. How many pulses should pass between meaningful beats?
2. How many simultaneous ambient signals remain readable?
3. Should the player move a cursor/camera freely, jump between signals, or use both?
4. How often should Echoes directly seek the Keeper?
5. Which interactions can be initiated at any time, and which require a live context?
6. How much personal space should each Echo accumulate without becoming a decorating game?
7. How much of relationship shape should be surfaced beyond the current bond tier?
8. When does a repeated routine become a stable custom?
9. How often should Echoes resolve tension without the Keeper?
10. What makes a duty feel owned by an Echo rather than assigned by the player?
11. How should absence during a Realm affect duties and relationships at home?
12. Which return consequences deserve immediate blocking presentation?
13. How should serious grief coexist with ordinary house rhythms over subsequent pulses?
14. How much Thread unease is atmospheric before it becomes a decision?
15. Which home traces remain spatially visible, and when do they move to the chronicle?
16. What level of warm humor fits Echoes without weakening its cultural and emotional grounding?
17. Which later systems genuinely deepen the home fantasy and which are false depth?

None of these should block Slice 1.

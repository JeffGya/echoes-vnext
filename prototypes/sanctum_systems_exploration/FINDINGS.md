# Sanctum Living House — Playtest Findings

## Slice 1 feedback — 2026-08-28

**Source:** Jeff's manual playtest. Qualitative feedback, not measured validation of every success criterion.

### Framing clarification: the Sanctum is a village

Jeff explicitly clarified that the Sanctum should be understood as a **village, not a house**. Use this framing when interpreting the feedback and planning subsequent slices. "Home" can describe belonging to the community; it should not imply a single domestic building or room-based life simulation.

Read the observations below through village life: Echoes travel between distinct places for understandable reasons, spend time in activities, and continue their lives while the Keeper focuses elsewhere. Closer selection should bring the player into a person or place within that wider village. The requested sense of elapsed time concerns life across the settlement.

Earlier house/household wording and the existing prototype title are retained as historical context, not a physical design constraint. This clarification does not authorize immediate code changes, file renames, additional systems, or a rewrite of the Working GDD.

### What worked

Jeff reported that the prototype looks good and feels good.

In follow-up feedback, Jeff said the first beat works and gives him a sense of peering into the Echoes' lives while they do their own thing. This is positive qualitative evidence for Slice 1's central observation-and-autonomy premise: the household feels active independently of the Keeper's input.

Preserve that feeling when adding social interactions and history. This feedback does not establish that every playtest threshold was measured or authorize starting the next slice.

### Missing history and memory

Jeff wants to look back at what an Echo has done and how they have been feeling without having to observe everything live. The Recent moments view does not currently record autonomous visits or activities at places such as the Hearth and Training Grounds. It also does not provide insight into communication that happened outside the Keeper's observation.

Implementation context: Recent moments currently records committed Keeper conversations. Echo-to-Echo conversations are not simulated in Slice 1; those belong to the planned social-life slice. History must describe actual simulated events, not imply that unseen exchanges already occurred.

### Motivation and access to an Echo's inner life

Jeff wants to understand what an Echo is thinking and why they act without having to start a conversation. Although autonomous life is appealing, movement currently feels random or insufficiently anchored. He needs visible evidence such as an Echo's stats, virtue/vector direction, or other stable characteristics to interpret their choices.

Deeper access to thoughts could potentially become an unlock later; Jeff raised this as a possibility, not an agreed progression rule. The level of immediate insight and later unlocks remains to be designed.

Implementation context: the current sandbox scores Rest, Company, and Purpose using prototype pressures, authored biases, fear/morale, place preferences, occupancy, and distance. It does not currently use canonical virtue-vector data. Future explanations must identify inputs that actually affect the decision, rather than decorating the UI with unrelated stats or invented thought text.

Design recommendation to discuss next: make a basic causal clue readable immediately, with deeper inner-life detail potentially unlockable. The test is whether Jeff can connect a visible personal characteristic or current state to an intention, destination, and activity without conversation or debug scores.

### Selection, camera, and uninterrupted life

Jeff finds movement and navigation seamless and smooth. Preserve that quality. Selecting an Echo or building should produce a noticeably closer, more dramatic zoom, rather than only a mild reframing of the overview.

Jeff also reports that the game often appears to pause on selection and wants life to continue during inspection. Treat this as an unresolved observed problem, not intended behavior.

Code inspection: ordinary subject selection does not explicitly change playback speed. Next Beat does intentionally leave playback paused. Selection currently changes camera framing but does not request a closer zoom level. The cause of the reported selection pauses has not been reproduced or established.

### Pulse as lived time, not a movement round

Jeff experiences pulses as rounds that set up the next movement. He is unsure about that rhythm. A pulse should feel like a day or another meaningful measure of elapsed house time, not a round granting movement. No day length or replacement time model has been agreed.

Implementation context: the controller advances all Echoes together on a shared pulse. At the default three-second interval, movement animation is capped at 1.2 seconds, leaving gaps between travel steps. This is a plausible contributor to the round-like feeling, not a confirmed explanation for the selection-pause report.

Design recommendation to discuss next: distinguish continuous-looking travel and activity from the slower passage of house time. Deterministic internal steps can remain an implementation detail; merely relabeling the pulse counter would not address the experienced cadence.

### Decision

**Deferred for the next slice. No immediate fix requested.** Jeff explicitly clarified that this is feedback to retain, not authorization to expand Slice 1 now.

When planning Slice 2, revisit activity memory, emotional context, and remembered autonomous communication alongside the social-beat work. Agree on that scope before implementing it. Do not treat the feedback as a request for a full Chronicle or persistence system.

Also revisit motivation visibility, closer selection framing, the reported selection pauses, and the meaning and presentation of house time before expanding the simulation. These are recorded follow-up design and verification topics, not authorization to implement changes now.

No gameplay changes were made in response to this feedback.

## Slice 2 Gate 1 playtest — 2026-08-29

**Source:** Jeff's manual Gate 1 playtest. These are qualitative observations;
they do not validate the later relationship or summoning gates.

### What improved

Recent activity on buildings is useful and provides the missing ability to inspect
what happened while attention was elsewhere. The underlying enacted history should
be preserved, but its local presentation becomes spammy quickly because routine
starts and completions each create a visible line.

### Focused revision before signoff

- Bundle consecutive routine records into one visit summary for an Echo at a place.
  A new visible line should represent a new visit, Keeper response, or another
  significant event rather than every routine boundary. Do not discard the bounded
  raw session events or invent unseen interactions.
- Clicking empty village space should clear ordinary selection and close its panel.
  An uncommitted conversation may cancel; a committed response remains protected.
- Selection did not feel visibly closer in Jeff's playtest. Strengthen and verify
  person and place focus against the overview rather than relying on an internal
  zoom value alone.
- Express day phase visually with a smooth village palette shift, especially a
  readable evening and night state. This is presentation only.

### Need-value interpretation

Jeff saw Company fall while Echoes gathered and asked whether this was inverted.
It is working as modeled: the displayed values are **unmet pressure**. High Company
means company is needed; Company falls while that need is being satisfied. This
direction needs clearer wording in any future player-facing treatment.

The prototype may continue showing numeric values for diagnosis. For the full game,
Jeff wants qualitative language and behavior to carry this information whenever
possible rather than straight meters and numbers.

### Conversation voice

The current questions and answers can mismatch, and their voice is too lofty and
vague. Jeff considers that acceptable for this systems prototype, so dialogue text
is not part of this focused revision. Before production adoption, rewrite the
templates in ordinary, context-matched language.

### Gate decision

Gate 1 remains open for one focused revision covering visit summaries, click-away
dismissal, stronger focus, and day/night color. Relationships, incidents, summoning,
production dialogue, and qualitative need presentation remain deferred.

### Focused revision result

The focused revision is implemented and technically verified:

- Recent now projects consecutive activity records for one Echo at one place as a
  visit summary while retaining the bounded raw session events. A five-minute seeded
  audit reduced 101 raw events to 28 visible visit summaries (72.3% fewer lines).
- Clicking empty village space closes ordinary person and place inspection. It also
  cancels an uncommitted approach or choice without discarding a committed response.
- Person and place selection now use a materially closer frame. At 960x540, the
  measured focus zoom was about 6.4 times the overview zoom while keeping the subject
  clear of the contextual panel.
- Morning, afternoon, evening, and night now have distinct, smoothly changing
  presentation palettes. Calendar color does not alter simulation outcomes.

Verification passed 162/162 prototype integration checks, the standalone entry-scene
smoke check, and 1401/1401 repository tests under the 200-second watchdog. The macOS
headless scene smoke still reports the existing system CA-certificate warning; it
does not produce a script error or failed exit.

Gate 1 remains paused for Jeff's in-game confirmation. Do not begin Gate 2 until he
signs off on this revision.

### Scope expectation and feedback handling

Jeff did not encounter Keeper interruptions or intervention moments during this
playtest. This is expected at Gate 1: warnings, social incidents, timed Keeper
interventions, and autonomous incident resolution belong to Gate 2 and have not
been implemented yet. Preserve this observation so the eventual Gate 2 playtest
explicitly checks whether those moments occur often enough to be noticed.

Workflow correction from Jeff: treat playtest observations as findings first. Record
and discuss them before changing the prototype unless Jeff explicitly requests an
immediate implementation. Do not infer authorization to build from feedback alone.

### Final Gate 1 camera note

Jeff reports that the focused revision is mostly right and that no immediate changes
are needed. Selection could eventually move even closer for a more intimate view.
When manually zooming back out, preserve the current camera position instead of
automatically anchoring the village to the overview center. Treat these as future
camera refinements, not authorization for another implementation pass.

This is strong qualitative support for Gate 1, but it does not authorize starting
Gate 2 without an explicit go-ahead.

## Slice 2 Gate 2 technical handoff — 2026-08-30

**Status:** implemented and technically verified; awaiting Jeff's in-game playtest.
Gate 3 summoning has not started.

### Reused foundation

- Production `SocialGraphService` still defines canonical shared pairs, the
  -100..100 strength clamp, eleven tier names, and friend/neutral/rival thresholds.
- The prototype owns all bond arrays, encounter knowledge and simulation state. It
  does not invoke production runtime, campaign state, economy, or saves.
- Gate 1 continuous time, movement, selection, history bundling, camera, day phase,
  conversations and five tuning controls remain intact.

### Gate 2 experiments

- Actual co-located encounters create village relationship knowledge; proximity by
  itself grants nothing.
- Companionship, care and practice resolve participant-specific effects against one
  explicit shared bond consequence.
- Directional impressions such as challenged, crowded or protected affect later
  decisions for one committed village-day duration without becoming another bond
  meter.
- Tense enacted exchanges can become warnings, open incidents, joined Keeper
  interventions, deferred issues, or autonomous resolutions. Closing a joined panel
  does not stop or replenish its simulation deadline.
- Friendly competition is a focused pacing experiment: the first neutral-bond
  practice involving a Proud Echo can create productive tension, satisfy Purpose,
  leave challenged impressions, and add +1 bond while opening one warning. Because
  the bond is then +1, the same pair falls back to ordinary nonwarning practice and
  cannot farm repeated warnings from that predicate.
- The Ase Flame exposes the village-wide significant history. Raw impression,
  emotion and bond consequence records remain in memory, while visible history
  folds them into their parent social or incident row to avoid spam.

### Measured pacing

The original default audit produced no practice exchanges across four twelve-minute
runs, and Training placement had no observed effect. A focused preference change
makes Training a truthful Purpose destination for Kweku while preserving his Company
preferences, identity, traits, pressures and emotions.

At the final default seed, all four placement combinations produced companionship,
care, practice and an open incident within five simulation minutes. Practice counts
were 4/3/4/3; Friendly competition occurred exactly once in each, followed by
ordinary shared practice. First open incidents appeared at 103.75--119.5 seconds.

A variance audit over seeds 41--44 and all four placements produced all three social
families and an open incident within five minutes in all 16 cases. This is bounded
prototype evidence, not a production probability guarantee.

### Verification

- Backend harness: 141/141 passed.
- Full prototype integration: 245/245 passed.
- Repository suite: 1401/1401 passed under the 200-second watchdog.
- Standalone entry smoke and explicit prototype parsing passed.
- Deterministic replay, snapshot isolation and reset clearing passed.
- Real-scene captures were inspected at 1600x900, 1280x720 and 960x540 for social
  engagement, Echo relationships, warning/open/joined/resolved incidents, Flame
  history and all eight tuning controls.

The macOS headless CA-certificate warning remains present and unrelated to the
prototype. No production save was accessed by the prototype.

### Jeff's Gate 2 questions

- Are relationships recognizable through behavior before reading their panel?
- Do shared bond tiers and different personal impressions remain understandable?
- Are warnings and Keeper opportunities noticeable without feeling constant?
- Does ignoring, deferring or answering an incident produce a clear aftermath?
- Can the Flame summary explain meaningful events that happened elsewhere without
  returning to the earlier history spam?
- Do companionship, care and practice feel distinct, and does Training placement
  visibly affect village life?

Record Jeff's observations before making another focused revision. Do not start
Gate 3 until he explicitly approves it.

## Slice 2 Gate 2 playtest findings — 2026-08-30

**Source:** Jeff's manual Gate 2 playtest. Record only; these observations do not
authorize implementation changes or Gate 3 work.

### Social events do not persist physically

Events currently feel strange because their participants separate immediately after
the exchange. When something unresolved occurs, the Echoes should remain together
with the issue long enough for it to feel present in village life. Their continued
position, orientation and behavior should communicate that the moment is still
active. Immediate separation makes a warning or incident feel detached from the
people who caused it.

The aftermath is also not noticeable. Although consequences exist in simulation
state and text, Jeff cannot perceive what changed after the moment resolves. A future
revision must make the transition from issue to consequence visible in the Echoes'
behavior, positioning, expression and next action, rather than relying on a history
entry or result paragraph.

### Relationship information relies too heavily on text and numbers

Shared bonds and relationships are understandable, but the presentation depends far
too much on numeric values and written explanation. This is useful for prototype
diagnosis but is not an acceptable player-facing information language.

Future presentation work should study the combat/movement prototype and the current
game UI, then express needs, bonds, impressions, emotional changes and consequences
through bars, shapes, states, spatial relationships and other visual elements. Text
should clarify a visual model instead of carrying the entire model. Do not respond by
placing the same numbers inside decorative elements.

### Incident cues blend into Echoes

Warnings and incident markers are understandable once noticed, but their circular,
outlined styling is too similar to Echo tokens. They blend into crowded gatherings
instead of reading as a distinct layer of village information. Future exploration
needs a separate silhouette, scale, motion or spatial treatment for issues while
preserving participant association.

### Overall interface scale is too small

Text, buttons, Echoes and supporting elements are all too small. Player-facing text
should be at least 16 px at the intended viewing resolution, with controls, spacing,
tokens and information graphics scaled coherently around that baseline. Meeting a
48 px hit-target test is not sufficient if the resulting presentation still feels
visually small.

### Close-up framing is still not close enough

Selection zoom remains too distant. Jeff wants a true Echo or location close-up in
which the selected subject fills the available world area and becomes the dominant
image on screen. Treat this as a distinct inspection composition, not another small
increment to the overview zoom value.

### Screenshot and viewport methodology

The visual review relied too heavily on the smallest supported 960x540 window. That
edge-case layout is not representative of Jeff's actual play environment and should
not drive the primary composition or visual judgment.

Before another presentation pass, confirm Jeff's normal playtest resolution. Use
that resolution as the primary design and screenshot target, then verify 1600x900,
1280x720 and 960x540 as secondary responsive cases. Do not present small-window
captures as evidence that the normal experience has the intended scale or impact.

### Gate decision

No implementation changes were requested. Gate 2 findings are recorded for later
discussion. Gate 3 remains closed.

## Focused Gate 2 revision authorization — 2026-08-31

Jeff subsequently authorized fixing the recorded Gate 2 findings. His normal
playtest target is **fullscreen 1920x1080**. This is the primary composition and
screenshot target; 1600x900 and 1280x720 are secondary responsive checks, and
960x540 remains an edge-case fit check.

The authorized revision is limited to persistent physical issues, readable
aftermath, qualitative visual presentation of needs and relationships, a distinct
incident silhouette, coherent interface scaling with 16 px minimum player-facing
text, and true Echo/place/incident close-up framing. Dialogue rewriting and Gate 3
summoning remain out of scope. Stop again for Jeff's in-game test after technical
verification; do not commit before signoff.

## Focused Gate 2 revision result — 2026-08-31

**Status:** technically verified and paused for Jeff's in-game test. Gate 3 remains
closed. No commit has been made.

### Persistent issues and aftermath

- A warning now holds its participants physically in the issue after the short
  social cue ends. They remain at reached waypoints, face one another, use a
  family-specific issue activity, and cannot begin conflicting interactions.
- Deferring relinquishes Keeper involvement without releasing the Echoes or
  replenishing the original deadline. Unrelated village life continues.
- Every Keeper and autonomous resolution now owns structured participant effects,
  shared bond tier transitions, and a six-second aftermath behavior. The affected
  Echoes visibly orient toward or away, remain with the consequence, and then commit
  the configured next intention through normal destination scoring.

### Player-facing presentation

- Echo Current uses qualitative segmented Rest, Company, and Purpose rails. Raw
  values, bond strength, encounter counts, signed deltas, and candidate scores stay
  in the Lab.
- Relationships use a spatial map with bond lines and directional impression labels.
  Folded history cards retain relationship consequences instead of losing them
  behind lower-priority detail.
- Incidents use a large non-circular split-standard silhouette, participant tethers,
  distinct warning/open/joined/resolved states, and a structured aftermath surface.
- Player-facing text is at least 16 px and actionable controls at least 48 px across
  1920x1080, 1600x900, 1280x720, and the 960x540 edge profile.
- Echo selection now fills at least 35% of usable world height. Place selection uses
  a dominant named place composition and suppresses competing Echo tokens; incident
  selection frames both participants and the issue. Manual pan/zoom remains an
  override.

### Verification evidence

- Backend harness: **165/165 passed**.
- Full prototype integration: **292/292 passed**.
- Repository suite: **1401/1401 passed** under the 200-second watchdog.
- Deterministic 2400-step replay, snapshot isolation, reset clearing, deadlines,
  defer behavior, and all-placement five-minute social pacing passed.
- The 1920x1080 capture sequence was judged first. An adversarial pass initially
  rejected a truncated `Challenged` label and a place frame that enlarged generic
  terrain instead of the selected place. Both were corrected and recaptured before
  final approval. Secondary profiles then passed fit, font, target, and framing
  checks.

The repository suite still emits intentional error-path messages from existing
tests, and prototype smoke checks emit the known macOS CA-certificate warning; final
counts and exit statuses are clean.

### Jeff's focused playtest

Confirm in the running build:

- Does an unresolved issue feel physically present between the Echoes?
- Can you notice aftermath through posture, activity, and the next action without
  depending on the result paragraph?
- Do needs and relationships read primarily through the new visual grammar?
- Is the incident marker unmistakably separate from Echo tokens?
- Do Echo and location inspection now feel like true closeups at fullscreen
  1920x1080?

Record observations before further changes. Do not start summoning or commit until
Jeff explicitly signs off.

## Focused Gate 2 playtest finding — selection is enlargement, not zoom

**Source:** Jeff's fullscreen 1920x1080 playtest after the focused Gate 2 revision.
Record only; agree on replacement framing before implementation.

The current selection treatment is fundamentally wrong. Selecting the Flame, a
location, or an Echo enlarges the selected drawing independently instead of moving
and zooming the world camera. This turns the subject into an oversized interface
element, destroys its spatial relationship to the village, hides nearby Echoes, and
makes it impossible to retain an overview of activity at the selected location.

The earlier occupancy checks validated screen coverage but failed to distinguish
camera magnification from per-subject visual scaling. Those checks are therefore
insufficient and must be replaced.

A future correction should preserve one world-space scale relationship for Echoes,
places, fixtures, paths, and incident cues. Selection should frame a world-space
region by changing camera position and zoom only:

- Echo inspection keeps the selected Echo prominent while retaining nearby Echoes
  and enough of the surrounding place to understand the social context.
- Place and Flame inspection frames the whole meaningful location and its occupants,
  rather than replacing it with a giant place marker.
- Incident inspection frames both participants, the incident cue, and their shared
  location without presentation-only participant displacement or token enlargement.
- Manual pan and wheel zoom continue from the current camera position without a
  recenter jump.

Verification must compare selected and unselected subjects under the same camera:
their relative world-space sizes must remain constant. Framing tests should measure
the selected world region and visible contextual subjects, not the isolated token's
screen occupancy. The 1920x1080 capture review remains primary.

### Blocking camera correction result — 2026-09-01

**Status:** corrected, technically verified, and ready for Jeff to resume the same
Gate 2 playtest. Gate 3 remains closed and no commit has been made.

- Removed every selection-only Echo/place scale, the giant focused-place renderer,
  contextual Echo suppression, and presentation-only incident participant offsets.
- Selection now fits one world-space focus region through the shared camera transform.
  Echo focus includes the Echo, current place, occupants, and bounded connected-path
  context. Place/Flame focus includes the normal marker and occupants. Incident focus
  includes both participants, cue, and shared place.
- Manual wheel zoom starts from the effective camera zoom. The first zoom-out notch
  works even at the maximum focus clamp and preserves the cursor's world point.
- Reduced motion reaches the same camera endpoint without interpolation.

The new verification rejects per-subject enlargement by recovering every projected
subject through the inverse camera transform and comparing authored positions and
normalized sizes before and after selection. The explicit 0.001 world-unit tolerance
only covers observed floating-point inversion drift (about 0.0001 position units and
0.000005 normalized diameter), not visible displacement or scaling.

Final evidence:

- Prototype backend: **165/165 passed**.
- Prototype integration: **306/306 passed**.
- Repository suite: **1401/1401 passed** under the 200-second watchdog.
- At 1920x1080, 1600x900, 1280x720, and 960x540, Echo, place, Flame, and incident
  focus retain required contextual subjects and keep them hit-selectable.
- The first manual wheel-down step changes effective zoom from 2.600 to 2.314 with
  zero measured cursor-anchor error.
- Final 1920 captures show Kojo, Esi, and Training Grounds together at one scale;
  Quiet edge with Yaw and surrounding terrain at one scale; and unchanged participant
  positions/sizes throughout warning, open, joined, and resolved incident stages.

The camera correction fixes the implementation error; only Jeff's in-game use can
confirm that selection now preserves the desired village overview and feels natural.

## Camera consistency correction — 2026-09-01

**Source:** Jeff's follow-up playtest. Record only; do not implement yet.

Echo and location selection currently produce different zoom levels because the
prototype gives each subject type a different focus-region rule. That distinction
was an implementation assumption, not an approved design decision. Jeff wants
selection types treated the same and does not want separate design reasoning applied
to their zoom behavior.

A future camera adjustment must use one consistent zoom rule for Echoes, locations,
the Ase Flame, and incidents. Subject type may determine what is highlighted and
what the contextual panel shows, but it must not independently determine the camera
zoom. Confirm the exact shared framing rule with Jeff before changing it.

## Practice friction warning has incident-level visual weight — 2026-09-01

**Source:** Jeff's follow-up playtest. Record only; do not implement yet.

The Practice friction cue is massive, overlaps the Echoes and their location, and
reads like a full Keeper incident. At this warning stage the Keeper cannot act on it,
so that visual weight and obstruction are misleading.

The current renderer uses the large incident-standard treatment throughout the
warning/open/joined/resolved lifecycle. It anchors the warning near the participants'
shared world position; when they are co-located and the camera is close, the pole and
blades cover the Echo tokens and place marker instead of hanging clearly above the
moment.

Jeff expects a non-actionable friction warning to behave as a small notification
tidbit: noticeable, associated with the people involved, and spatially out of their
way. It should not occupy the full incident silhouette or suggest an unavailable
Keeper action. Reserve stronger world presence for a state where the issue has become
actionable or otherwise demands attention. Confirm the exact escalation treatment
before implementation.

Jeff preferred the previous compact rendering for this warning. The large pole was
introduced by over-applying his earlier request that incidents be more distinct from
Echo tokens: the implementation treated every lifecycle stage as needing incident-
level prominence. That reasoning failed to preserve the difference between a small,
non-actionable friction notice and an open Keeper incident. When this is revised,
start from the earlier compact warning treatment rather than trying to justify or
decorate the current oversized pole.

## Conflict context and outcome are not legible at the moment — 2026-09-01

**Source:** Jeff's follow-up Gate 2 playtest. Record only; do not implement yet.

Apart from the oversized incident marker, the current revision feels fine. The
relationship tree is useful and pleasant at the current six-Echo population. It may
become difficult to navigate with many more Echoes, but no scalability change is
needed for this prototype gate.

Conflict itself is not understandable enough. Jeff cannot readily tell why Echoes
are in conflict or when the situation has become okay. The information exists partly
in Recent, but requiring the player to leave the live moment and search history is
the wrong hierarchy.

Selecting an active conflict should immediately explain:

- what is happening now;
- why it began, using the actual needs, relationship context, impressions, place,
  and triggering exchange that mattered;
- whether it is only friction, open for Keeper involvement, waiting for a reply, or
  resolving autonomously;
- what the Keeper can do at this stage, including a clear statement when nothing is
  actionable yet.

When a conflict ends, its selected context should visibly persist long enough to
show:

- the concrete outcome;
- each Echo's individual reaction and current feeling toward the other;
- whether their shared bond improved, worsened, or stayed in the same tier;
- the relevant emotional aftermath and next behavior;
- how each participant now regards the Keeper, if the Keeper intervened.

The current prototype has structured participant effects, shared bond transitions,
emotions, impressions, and aftermath behaviors, but the live result does not assemble
them into this explanation clearly enough. It also does **not** currently own a
persistent Echo-to-Keeper feeling or relationship state. Do not fabricate that answer
from dialogue tone or general emotion. Before implementation, decide whether this
slice needs a bounded incident-specific Keeper reaction or a durable Keeper-facing
relationship model, then project it as explicit structured state.

Recent remains useful for later discovery and review, but it should reinforce a
conflict that was already understandable when selected, not serve as the only place
where its cause and outcome make sense.

## Voice feels distant, abstract, and falsely mythic — 2026-09-01

**Source:** Jeff's Gate 2 playtest, with the same concern applying to the full game.
Record only; do not rewrite content yet.

The current writing does not sound like people speaking or like a family remembering
its history. Echoes routinely sound like philosophers, an old play, or a status
overview instead of lost people trying to live with one another. Difficult words,
abstract concepts, and repeated mythic language create emotional distance.

This is both a voice problem and an information-design problem. System terms such as
Purpose, pressure, emotional-state labels, relationship tiers, boundaries, and
aftermath are being asked to carry human moments. The interface then explains those
moments through more prose instead of showing the behavior and using a few familiar
words to clarify it.

The intended voice is natural, familiar, and concrete:

- Echoes speak in short everyday sentences about what happened, what they want, who
  bothered or helped them, and what they will do next.
- They sound displaced, uncertain, proud, scared, warm, defensive, tired, or annoyed
  according to the person and moment. Distinction comes from rhythm, directness,
  avoidance, humor, and what they notice—not uniformly elevated vocabulary.
- Routine speech should permit incomplete thoughts, simple disagreement, hesitation,
  and ordinary phrasing. Echoes do not explain the simulation model to the player.
- History should read like a family tree or family record: who was there, what they
  did, what changed between them, and what people remember about it.
- Mythic language belongs to rare sacred, ritual, ancestral, or truly extraordinary
  moments. It should not coat everyday training, rest, irritation, care, or small
  conversations.
- Visual behavior and relationship presentation should carry more meaning so text can
  stay brief. Player-facing copy should not become a prose substitute for missing
  visualization.

Example direction, not approved final copy:

- Instead of “Their Purpose needs and the conditions for shared practice shaped the
  exchange”: “Kweku wanted to train. Yaw kept pushing. It got tense.”
- Instead of “The boundary is heard and the village makes room”: “Yaw asked for
  space. Kweku backed off.”

Before a rewrite, define a small voice guide that separates spoken dialogue, live
observation, family-history narration, system labels, and rare ritual language. Then
rewrite bounded prototype templates from actual context while preserving each Echo's
individual voice. Treat this prototype finding as evidence for a later full-game
writing pass, not authorization to change production copy now.

## Menus and Recent are not scannable — 2026-09-01

**Source:** Jeff's Gate 2 playtest. Record only; do not redesign yet.

The prototype makes almost every piece of information look like another row of text.
Headlines, people, causes, current state, outcomes, and supporting explanation blend
together. Jeff has to read and parse the whole panel to find what happened, especially
in Recent. None of the contextual menus currently support natural human scanning.

This is separate from the tone-of-voice problem. Even perfectly rewritten sentences
would remain tiring if every fact has the same typography, spacing, and structure.
The interface must provide recognition before detailed reading.

At a glance, a recent event should communicate:

- what kind of moment it was;
- who was involved;
- the concrete action or problem;
- whether it ended well, badly, or remains unresolved;
- what changed;
- when and where it happened;
- whether the Keeper can or should act.

Future exploration should use a visual event grammar rather than prose rows: distinct
event silhouettes or icons, participant marks and names, a short human headline, a
clear outcome/change treatment, and quieter time/place metadata. Group related events
into one readable moment and reveal cause or full detail only when selected. Names,
actions, unresolved states, and meaningful changes should carry the strongest visual
weight.

Current panels need the same hierarchy. “What is happening now?” and “What can I do?”
must be immediately visible; traits, explanations, history, and diagnostic detail can
follow. Sections alone are insufficient when every section still consists of similar
text rows.

A useful later acceptance check is a short glance test: after roughly three seconds,
Jeff should be able to identify the newest meaningful event, its participants, its
outcome or unresolved state, and where to open more detail without reading the whole
panel. Do not solve this by adding more labels or shortening every sentence while
retaining the same list-of-text presentation.

## Gate 2 findings correction implemented — 2026-09-01

The authorized correction now uses one camera zoom rule for Echoes, places, the
Flame, and incidents. Warning-stage friction is a small notification above its
participants; the larger incident standard begins only when Keeper action becomes
available.

Selected conflicts lead with **Now**, **Why**, **Status**, and **Action**. Resolved
conflicts retain the concrete outcome, both Echoes' views, the shared bond direction,
emotional effects, next behavior, and incident-specific reactions to the Keeper.
Autonomous outcomes retain both personal views but correctly have no Keeper reaction.

Current and Recent now use stronger visual hierarchy and one folded card per
meaningful event. Local prototype copy was rewritten in plainer language, and the
player-facing Purpose label is **Something to do**. Canonical internal state remains
unchanged.

**Technical status:** backend **165/165**, prototype integration **309/309**,
standalone scene smoke passed, and repository regression suite **1401/1401**. The
headless capture batch was not used because Godot's renderer stalled; fullscreen
visual judgment remains part of Jeff's in-game playtest. Gate 3 remains closed.

## Incident resolution lacks a clear ending — 2026-09-01

**Source:** Jeff's Gate 2 playtest. Authorized correction.

The current selected-incident aftermath is too easy to miss. A conflict can resolve
without a clear sense that the moment ended, what the Keeper's choice changed, or why
the same two Echoes later clash again.

Resolution should use a full-screen result surface while village life remains visible
and continues behind it. The result persists until dismissed and must not pause,
reserve, or otherwise change simulation time. It should show the concrete outcome,
each participant's response, relationship and emotional direction, next behavior,
and a plain explanation when the underlying cause remains likely to return.

Reply choices should communicate likely direction through wording and visual tone,
without exposing exact values or promising a guaranteed result. Recurring conflict
must be traceable to actual surviving needs, impressions, relationship context, or
cooldown state rather than appearing as an unexplained replay.

**Implemented:** Keeper resolutions now open a persistent full-screen result while
the village continues behind it. The surface shows the outcome, both viewpoints and
Keeper reactions, qualitative relationship and emotional direction, next behavior,
and whether the original cause eased or may return. Reply choices show a short
authored direction before commitment without exposing values or guarantees.

Resolved pairs receive a two-minute same-pair, same-family cooldown. This prevents an
immediate replay while still allowing later tension when the cause remains. The
result survives the simulation's incident release; dismissing it changes no
simulation state and returns focus to the incident's location.

**Technical status:** backend **165/165**, prototype integration **310/310**,
standalone scene smoke passed, and repository regression suite **1401/1401**. Ready
for Jeff's fullscreen playtest. Gate 3 remains closed.

## Visualize state before explaining it — Gate 3 direction — 2026-09-01

**Source:** Jeff's final Gate 2 feedback. Planning direction for Gate 3; do not patch
Gate 2 separately before Gate 3.

The incident result is understandable but still asks the player to parse too much
text. This repeats a wider risk across the prototype: information is often technically
present but carried by headings and sentences instead of visible behavior, shape,
position, expression, relationship, and change.

Gate 3 must apply the original specification's information-channel order throughout:
world behavior first, spatial UI second, compact contextual UI third, and dense text
only for optional reference. Important outcomes use at least two channels. Text
clarifies what the player can already begin to read visually.

For the incident result, explore a participant-first composition with recognizable
Echo marks, visible relationship direction, emotional and need changes, next-action
cues, and a distinct eased-versus-unresolved cause state. Keep the plain-language
summary subordinate. Apply the same rule to summoning charge, witness reactions,
welcome choices, newcomer emotion, first destination, and the household's changed
state after arrival.

Gate 3 review must judge the primary 1920x1080 composition first and use a short
glance test: without reading every sentence, the player should identify who changed,
the direction of change, what happens next, and whether anything remains unresolved.

Jeff approved mock portrait/bust art for reaction and result surfaces. Following the
UI reference used by the original spec, Gate 3 should mix channels by context rather
than treating overlays as the default: protect the active world area, show only what
matters during the current beat, group related information along the player's eye
flow, give UI elements visual weight proportional to urgency, and test the most
crowded nine-Echo state. Portraits connect consequences to recognizable people; they
must not replace visible approach, watching, avoidance, welcome, or first movement in
the village.

## Gate 3 technical handoff — 2026-09-02

Gate 3 is implemented and ready for Jeff's in-game test. The implementation keeps
summoning in the prototype-owned simulation and does not access production campaign
state or saves.

Three authored newcomers—Adwoa, Mensah, and Sena—are consumed once each in a seeded
order. A return costs 60 Ase, begins only after confirmation, and proceeds through
manifestation, identity reveal, a required untimed welcome, first destination, and a
folded arrival memory. Existing Echoes visibly approach, watch, or avoid the return;
ordinary village life continues during the welcome. Newcomers enter without bonds,
encounters, or impressions, so their relationships begin through actual village
experience.

All nine Echoes have distinct mock portrait busts. They are used in arrival and
incident-result surfaces while world behavior continues to carry the first layer of
meaning. Incident results were recomposed around the two participants, a central
relationship direction, emotional and next-action cues, and a clear eased or
unresolved cause state. Supporting prose remains available but visually subordinate.

The responsive pass found and corrected vertical clipping in the incident result at
1600x900, 1280x720, and 960x540, plus the welcome reveal at 960x540. Automated checks
now cover the complete ready-to-arrival UI path, cancellation and single-spend rules,
portrait reveal timing, background progress, required welcome, stale/reset handling,
visual incident result contracts, and a real selectable nine-Echo crowd at all four
supported sizes.

**Technical status:** backend **183/183**, prototype integration **354/354**,
standalone scene smoke passed, repository compile passed, and repository regression
suite **1401/1401**. The headless renderer still stalls while saving prototype
screenshots, so fullscreen visual judgment remains part of Jeff's in-game gate. No
commit should be made until signoff.

## Gate 3 playtest findings — 2026-09-02

**Source:** Jeff's Gate 3 playtest. Record only; do not change implementation yet.

The clearer outcome presentation works. Summoning feels good, all three newcomers
are distinct, and the nine-Echo village remains easy to read and select.

Witness and participant reactions still do not read in the village itself. The data
is present, but Jeff has to read a panel to understand it. A future pass should make
the direction of a reaction visible through movement, facing, distance, pose,
expression, a short-lived world cue, or another spatial change. A panel can explain
the detail after the world has communicated the basic response.

The writing remains vague and generic. Much of it could apply to any Echo or event,
so it does not reveal a concrete want, action, disagreement, choice, or consequence.
Future copy should name who did what, what each person wanted, what changed, and what
they will do next. Character distinction must come from specific observations and
speech habits rather than interchangeable elevated language.

Current social incidents are intentionally limited to two primary participants. This
was a Slice 2 prototype boundary built around pairwise shared bond edges, two
individual reactions, and one deduplicated bond consequence. It keeps causal tuning
and result presentation inspectable, and follows the specification's staged
foundation of pair routines and two-person beats. It is not a rule that all future
Sanctum incidents must involve only two people. The wider specification already uses
general participant sets, witnesses, and group rites. Before production adoption,
test a model with a primary pair plus affected witnesses or clearly assigned group
roles so multi-person consequences do not become ambiguous or multiply bond changes.

## Visible reaction and point-of-view correction — 2026-09-03

The approved correction is implemented without expanding into unrestricted group
incidents or a narrative framework.

Social exchanges now emit deterministic, time-bounded presentation instructions for
six responses: welcomed, appreciative, uncomfortable, crowded, challenged, and hurt.
The world renders them through facing, small pose accents, and restrained marks above
or between people. Reduced motion removes displacement while retaining orientation
and shape. Cue expiry is presentation cleanup and does not stop Next Meaningful Beat.

Live notifications use present-tense narration and name the people involved. Echo
Current uses first-person present language, Echo Recent uses the newest authored
first-person memory, and place/Flame records use past tense. Completed actions use
past tense while continuing feelings and next behavior remain present. Internal/GDD
language is restricted to Lab. Existing scan-first Current sections remain after the
leading personal view.

Warning-producing practice exchanges may select up to three deterministic witnesses.
Each receives a visible `support`, `side`, `watch`, or `leave` response and one
first-person memory. Witnesses remain unreserved, proximity alone produces nothing,
and their response cannot duplicate the primary pair's bond consequence. Other social
families retain two primary participants without witnesses in this experiment.

**Technical status:** backend **193/193**, prototype integration **373/373**,
standalone scene smoke passed, repository compile passed, and repository regression
suite **1401/1401**. Fullscreen visual readability remains Jeff's playtest gate. No
commit should be made until signoff.

## Incident cause arrives after the decision — 2026-09-04

**Source:** Jeff's playtest after the visible-reaction and point-of-view correction.
Record only; do not change implementation yet.

The revised text is clearer, but the actual exchange that causes an incident is most
readable after resolution. The Keeper is therefore asked to choose without first
seeing what each Echo said or did. Warning and open states must expose the enacted
conversation before intervention: a short live exchange in the world, plus each
participant's current first-person line when the incident is selected. Joining should
enter an exchange already in progress, not unlock the missing premise.

The current simulation can resolve an open or joined incident autonomously when its
deadline expires, using the Echoes' rest, fear, wisdom, bond, and impressions. It may
settle with no bond loss or end frustrated with a negative bond change. However, every
warning still progresses into the same mechanically Keeper-actionable open state.
This is not only a presentation problem. Some incidents must never permit the Keeper
to join because the Echoes are handling it privately, reject involvement, or do not
consider the Keeper part of the moment. Inspecting an incident does not grant a right
to intervene.

A later focused correction should distinguish three social postures without adding
a new incident system:

- **Handling it:** the simulation sets the incident as non-joinable; no Keeper action
  exists, and dispatching a stale or fabricated join command is rejected.
- **Open to help:** the Keeper may join, but neither Echo requests intervention.
- **Asking for help:** one Echo visibly appeals to the Keeper.

The posture is authoritative simulation state selected deterministically from the
existing traits, current state, bond, impressions, and incident context. `can_join`
must derive from that state rather than from warning/open status alone. Ignoring an
open or requested moment remains a valid choice. Echoes may settle it, worsen it,
refuse the Keeper, or decide they dislike one another; the Keeper discovers and
manages the fallout later. The pre-intervention exchange, posture, deadline, and later
result must remain visible in world behavior and history without turning incidents
into compulsory notifications.

## Incident access and visible premise implemented — 2026-09-04

The correction now makes permission authoritative simulation state. Each warning is
assigned immutable `private`, `open`, or `appeal` access from existing courage,
wisdom, fear, rest, bond, impressions, archetype, and incident family. No Keeper
relationship system was added. In the untouched starting-six matrix across every
pair and family, the initial tuning yields 20 private cases, 24 open cases, and one
appeal; these are experiment results rather than desired production percentages.

Private incidents never project `can_join`. Direct, stale, fabricated, and repeated
join commands are rejected before changing participants, reservations, deadlines,
history, or the existing accepted-command audit. Open and appeal incidents remain
optional and resolve autonomously when ignored. Autonomous outcomes retain their
existing ability to settle or worsen relationships and subsequent behavior without
inventing a Keeper reaction.

Every incident family now stores a two-line first-person present exchange at warning
creation. The exchange is visible near its speakers and leads the selected incident
surface before Status, Why, and Action. Joining retains the same premise. Private
issues use a compact non-actionable treatment, open issues offer **Step in**, and an
appeal names the Echo asking. None pause or auto-focus the village.

**Technical status:** backend **200/200**, prototype integration **392/392**,
standalone scene smoke passed, repository compile passed, and repository regression
suite **1401/1401**. Fullscreen readability and whether the access distribution feels
credible remain Jeff's playtest gate. No commit should be made until signoff.

## Echo Recent card formatting correction — 2026-09-04

Jeff approved the incident access pass and reported that Echo Recent cards contained
large gaps and sometimes appeared to omit part of their text. The card reused a
168-pixel minimum height designed for denser village-history entries even when a
first-person memory had no people, time, cause, aftermath, badge, or consequences.

The card now hides every absent field, uses a compact horizontal header, and derives
its height from visible content. Long authored first-person memories remain intact
and wrap across **1920×1080**, **1280×720**, and **960×540**. The prototype integration
harness is now **393/393** and the full repository suite remains **1401/1401**.

## Gate 3 signoff — 2026-09-04

Jeff approved Gate 3 after testing the visible incident premise, private/open/appeal
access, autonomous resolution, summoning, nine-Echo readability, and corrected Echo
Recent formatting. Slice 2 is complete. Its strongest evidence is that the village
now feels inhabited by distinct people whose relationships and disagreements can
continue without requiring the Keeper, while important causes and outcomes remain
discoverable. The remaining ideas in this document are inputs to later slice plans,
not unfinished Gate 3 requirements.

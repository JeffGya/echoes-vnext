# Slice 2 implementation contracts

## Focused Gate 2 revision contract — 2026-08-31

This revision responds only to Jeff's Gate 2 findings. Gate 3 remains closed. The
primary design and capture target is fullscreen **1920x1080**. Verify 1600x900 and
1280x720 afterward; treat 960x540 as a supported edge case rather than the visual
reference for scale or composition.

### Persistent issue and visible aftermath

An incident owns its participants from warning creation through resolution. The
short social-engagement cue may finish, but it must not release them while the
underlying issue remains. Each participating Echo exposes `incident_id` and a
structured `behavior` projection:

```gdscript
{
  "kind": "issue" | "aftermath",
  "source_id": String,
  "partner_id": String,
  "activity": String,
  "orientation": "toward" | "away",
  "started_ms": int,
  "duration_ms": int,
  "remaining_ms": int,
  "next_intention": Dictionary,
}
```

While a warning or open incident persists, both Echoes stay at reached waypoints,
remain reserved by that incident, use a family-specific issue activity, and face
one another. If they share an exact position, stable pair ordering supplies opposite
facings. They do not gain or relieve pressures, count down routines, begin Speak,
or enter another social exchange. Unrelated Echoes continue normally. Joining the
same incident is legal even though its participants are already reserved.

`prototype.incident.defer` relinquishes the Keeper's joined interaction and returns
the incident to `open`; it does **not** release its participants, clear the issue,
or replenish the original incident deadline. Closing the panel remains presentation
only. Autonomous resolution, a committed reply, reset, or the bounded resolved
transition is what ends the issue.

Resolution immediately assigns each participant a data-authored aftermath behavior.
The result includes `aftermath_behaviors`, one entry per participant, and each reply
or autonomous outcome owns its activities, orientations, and next intention families.
Initial mappings may use toward/company or purpose for repair and renewed engagement,
and away/rest for space, cooling down, or frustration. These behaviors add no hidden
need, emotion, or bond consequence beyond the already resolved result and create no
fabricated significant event.

Aftermath lasts **6000 simulation ms** as a starting hypothesis, including the
existing 1500 ms protected result display. After the incident leaves active state,
the remaining aftermath still reserves the affected Echo and stays visible. At its
expiry, the Echo commits the configured Rest, Company, Purpose, or autonomous family
through the existing deterministic destination scorer. On the expiry step, do not
apply an unrelated pressure update before that causal next choice.

Incident participant effects include exact `before` and `after` projections for
Rest, Company, Purpose, and canonical emotional status. The single shared bond
consequence includes `tier_before`, `tier_after`, `tier_name_before`, and
`tier_name_after`. Presentation uses these fields directly and never infers change
from prose.

### Player-facing visual language

The normal interface must not display raw need values, bond strength, encounter
counts, signed deltas, timers as bare numbers, or candidate scores. Those remain in
the Lab/debug surface. Player-facing inspection uses authored visual components:

- `NeedPressureDisplay`: Rest, Company, and Purpose icons with segmented qualitative
  rails and plain-language states. Higher fill means greater unmet pressure.
- `RelationshipMap`: the selected Echo and known partners connected by bond-tone and
  bond-weight lines, the canonical tier name, and directional impression markers.
- `IncidentContext`: a clear warning/open/joined/resolved stage treatment, cause,
  replies, simulation-time urgency, and structured before/after aftermath display.
- `HistoryMomentCard`: a compact typed event card with participants, place/time,
  cause, and consequence glyphs; folded parent events stay one card.

These are prototype-local `.tscn` structures with scripts that render snapshot data.
They may reuse production semantics and palette references, but do not import
production runtime state or copy an unrelated screen wholesale. Text clarifies the
graphics rather than carrying the whole model.

World incidents use a large, non-circular silhouette with a ground tether and
participant connectors. At 1920x1080 the issue footprint is at least 1.5 times an
overview Echo and visually distinct through shape, contrast, and state. Warning,
open, joined, and resolved treatments must remain distinguishable without relying
on their label. Reduced motion keeps the same static state distinctions.

### Scale and inspection composition

At every supported profile, player-facing text is at least 16 px, actionable targets
are at least 48x48, primary choices are at least 56 px high, and adjacent targets
retain at least 8 px separation. At 1920x1080, overview Echoes are at least 64 px in
diameter and incident cues at least 80 px. Supporting panels, spacing, and icons
scale around that baseline rather than merely increasing font overrides.

Selection enters a true inspection composition based on screen occupancy, not a
fixed zoom multiplier. At 1920x1080 an Echo occupies at least 35% of usable world
height, a place at least 60% of usable world width, and an incident frames both
participants plus the issue across at least 60% of usable world width. Subjects stay
inside the central 60% of the panel-safe world area without clipping. Manual pan and
zoom still override automatic follow; zooming out preserves the current world point.
Reduced motion removes the transition but applies the same final framing.

### Revision acceptance and capture order

Verification samples warning midpoint, open midpoint, joined, deferred-open,
resolved, protected-result end, and aftermath expiry. It proves participant position,
orientation, activity, reservation ownership, unrelated-Echo progress, original
deadline preservation, exact-once consequences, configured next intention, replay,
pause, reset, and snapshot independence.

Visual capture runs **1920x1080 first**: overview, social exchange, warning midpoint,
open, joined, resolved aftermath, post-release behavior, relationship/impressions,
crowded incident, Echo close-up, and place close-up. Capture metadata records subject
bounds and usable-area occupancy, minimum visible font size, participant position,
facing, activity, issue state, and relationship descriptors. Secondary profiles then
verify recomposition and the 960x540 edge case verifies fit without redefining the
primary composition.

Backend and its tests must pass before presentation implementation begins. This
focused revision ends with technical verification and another Jeff playtest; it does
not authorize summoning or a commit.

### Blocking camera correction — world zoom, never subject enlargement

Jeff's fullscreen playtest rejected the focused selection treatment because it
enlarges the selected drawing independently and destroys spatial context. This is a
blocking Gate 2 correction and supersedes the isolated-subject occupancy targets
above.

Selection changes only the shared world camera transform. Echo tokens, place
markers, fixtures, incident cues, paths, trees, and labels retain the same authored
world-space dimensions and relative scale whether selected or not. Do not draw a
larger selected variant, suppress contextual Echoes, displace participants for
framing, or replace a location with a screen-sized inspection symbol.

Camera focus regions are world-space bounds with stable padding:

- Echo: selected Echo, its current place marker or footprint, and every Echo
  currently occupying that place. If this region is too small to explain context,
  include a bounded surrounding portion of the connected paths.
- Place or Ase Flame: the place footprint or marker and all current occupants. The
  selected location remains identified through an outline or emphasis at its normal
  world scale.
- Incident: both participants, the incident cue, and the shared place marker.

The camera fits the relevant region inside the panel-safe world rect while preserving
aspect ratio. One uniform zoom applies to the entire renderer. Nearby contextual
subjects remain visible and selectable. Selection never alters authoritative or
presentation positions. Reduced motion snaps to the same final camera; normal motion
interpolates the camera only. Manual pan and wheel zoom begin from the current camera
transform, and zooming out keeps the current world point instead of recentering.

Verification must prove relative-scale invariance: under one camera transform, the
screen-size ratio between any two world subjects is unchanged by which one is
selected. Selection captures must show the required subject set and shared location,
not merely satisfy a large isolated bounding box. Review fullscreen 1920x1080 first,
then 1600x900, 1280x720, and 960x540. This correction must pass before Jeff resumes
Gate 2 playtesting.

## Gate 2 findings correction — natural, scannable village moments

This authorized correction covers the remaining playtest findings only. Keep the
relationship map at its current six-Echo scope. Gate 3 and production copy remain
closed.

### One selection camera rule

Echoes, places, the Flame, and incidents use one shared focus zoom target at a given
viewport. Subject type may choose the pan centre and highlight, but cannot change the
zoom amount. Use one responsive `overview_zoom * shared_focus_multiplier` rule with
the existing global clamp. Manual zoom remains an override and keeps its anchor.

### Warning versus actionable incident

`warning` is non-actionable friction. Render it as a compact notification above the
participants, with a small distinct glyph and no pole, blades, participant-covering
geometry, or implied Keeper action. Its selected panel says plainly that nothing can
be chosen yet. The larger incident standard begins at `open`; joined and resolved
retain their stronger stage distinctions.

### Truthful conflict context and outcome

Selecting any conflict shows a structured live summary before supporting prose:

- `Now`: a short concrete description of what the participants are doing.
- `Why`: the actual triggering exchange and relevant human cause in plain language.
- `Status`: watching, open for help, waiting for the Keeper, or settled.
- `Action`: a direct available action or “Nothing to choose yet.”

Resolved incidents persist with a scannable outcome: what happened, each Echo's view
of the other, shared relationship direction/tier, emotional change, next behavior,
and each participant's incident-specific reaction to the Keeper when intervention
occurred.

Do not add a durable Keeper relationship engine. Add bounded, data-authored
`participant_views` and `keeper_reactions` to each Keeper resolution. Store them in
the incident result and retained parent history event. Autonomous results have no
Keeper reaction. These fields describe this intervention only and never masquerade
as a permanent relationship score.

### Natural voice

Keep internal keys and canonical simulation state unchanged. Player-facing copy uses
short, concrete, familiar language. Echoes talk like displaced people with individual
rhythm, not philosophers or system explainers. Family history says who did what and
what changed. Reserve mythic language for the Flame, ritual, and rare sacred moments.

Do not expose internal words such as pressure, delta, participant effect, aftermath,
or candidate. Present the internal Purpose need as **Something to do**. Map canonical
emotional states to plain display phrases while retaining the canonical value in
debug data. Rewrite local bounded dialogue, social cues, conflict causes/outcomes,
activities, and controller-generated copy; do not build a narrative framework or
touch production copy.

### Scannable Current and Recent

Current surfaces lead with `Now`, `Why`, and `What you can do` or the equivalent
visual state. Supporting traits, needs, relationships, and history follow with lower
weight.

Recent uses one visual card per meaningful moment, not equal-weight prose rows. Each
card exposes at a glance: event kind glyph/tone, participants, one human headline,
outcome or unresolved badge, relationship/emotional change glyphs, and quiet
day/place metadata. Cause and secondary detail are visually subordinate. Keep folded
social/incident consequences in the parent card. Reduce the page density if needed;
do not solve scanning with more labels.

Acceptance uses 1920x1080 first. A three-second visual judge must identify the newest
meaningful event, participants, outcome/unresolved state, and actionability without
reading the full panel. Verify warning obstruction, all incident stages, Echo/place/
Flame Current and Recent, natural copy guardrails, keyboard navigation, and 1600x900,
1280x720, and 960x540 fit. The orchestrator alone runs final integration, capture
matrix, and repository suite once after both implementation domains freeze.

## Scope and ownership

Gate 2 implementation is frozen for Jeff's playtest: it preserves Gate 1 continuous
village life and adds relationships, autonomous social exchanges, personal reactions,
warnings/incidents, Keeper intervention, and the Ase Flame village summary. Gate 3
summoning remains closed until Jeff's separate Gate 2 signoff. Do not scaffold
newcomers or economy yet.

Persistent agent domains (reuse these same agents for subsequent gates):

| Owner | Files / responsibilities |
|---|---|
| `sanctum_simulation` | `simulation/`, `data/`; all authoritative state and projection |
| `sanctum_presentation` | `PrototypeController.gd`, entry scene, `ui/`; scheduling, camera and scene-authored UI |
| `bond_behavior_audit` (persistent verification role) | `tests/`; harness, fixtures, integration and capture checks |
| Main orchestrator | Markdown contracts/run guidance/findings, coordination, review, final verification and commits |

One owner per file. Send cross-domain requests to its owner. Presentation may
inspect/review before backend passes, but may not implement until the orchestrator
opens that gate. All implementation stays in this prototype; production and the
combat prototype remain unchanged. Follow root AGENTS.md and relevant skills.

## Simulation API (Gate 2 contract v2)

One RefCounted authority, no scene tree or wall clock. Keep existing setup commands
and `reset(seed_value, placements={}, tuning={})`, `get_state()` (deep copy for
tests), `get_definition()` (deep copy), `place_node(id)`, and deterministic `route`.

- `const STEP_MS := 250`
- `get_step() -> int`, `is_living() -> bool`: inexpensive scheduling queries.
- `apply_action(action: Dictionary, t: int) -> bool`: t must equal current step.
- `advance_step(t: int) -> bool`: t must equal current step + 1 and phase living;
  returns whether a meaningful activity, arrival, response or release occurred.
- `build_snapshot_data(debug_enabled: bool = false) -> Dictionary`: independent
  projection; no UI access to mutable state.
- Remove prototype `advance_pulse`, `pulse_seconds`, `routine_pulses` consumers;
  this isolated sandbox needs no legacy aliases.

State has `step`, `elapsed_ms`, `phase` (setup/living), `seed`, `placements`,
`tuning`, `echoes`, `conversation`, `events`, `beats`, `commands`, `initial`, metrics,
plus prototype-owned `bonds`, `encounters`, active `impressions`, pair/template
cooldowns, autonomous social engagements, active incidents, and at most one joined
incident interaction. These remain one simulation's private mutable state.
Accepted commands record `{step, order, action}`. Reset clears all session state,
including history and reservations, even though fixture IDs repeat. Definition
and initial seed/placements/tuning plus ordered commands suffice for replay.

Calendar starts Day 1 morning. Store day number and elapsed cycle separately from
monotonic simulation time. Four equal phases: morning, afternoon, evening, night.
Day-length tuning preserves current cycle fraction and changes only future cycle
speed. It does not rescale travel, routine commitments or release deadlines.

## Projection used by controller/UI

Keep the envelope `{type, meta, data, actions}`; `meta.t` is now step index.
Actions are slot-keyed Dictionaries. Keep existing prototype action type strings
except the obsolete external conversation-release command (release is now timed
inside the simulation). UI still emits `action_requested(action)`.

Data retains definition projections (`places` with resolved nodes, `waypoints`,
`sites`, `topics`, `tuning_ranges`) and includes:

- `step`, `elapsed_ms`, `step_ms: 250`, `next_beat_steps: 240`.
- `clock: {day, phase, progress, phase_progress, day_minutes}`; fractions 0..1.
- `echoes`: existing identity/name/color/mark/standing/calling/dialogue plus
  `traits: {courage,wisdom,faith}`, canonical `archetype`, `emotional_status`.
- Each Echo has `node` (last reached waypoint), `position: [x,y]` in authored world
  coordinates, `moving: bool`, `path` (remaining waypoint IDs), `facing: [x,y]`,
  `family`, `activity`, `destination`, `reason`, `remaining_ms`, `reserved`.
- Each Echo has `needs: {rest: {value,max,label}, company: {...}, purpose: {...}}`.
  Higher values mean greater unmet pressure; labels must agree with values.
- Each Echo has `bonds`, projected only from actual village encounters and shared
  canonical bond edges, and active directional `impressions` with cause and expiry.
- Each Echo has `history`, newest-first projection of actual events. `place_history`
  maps place IDs to newest-first visit summaries. Arrays are bounded by event
  retention and can be paginated by the contextual UI (12 entries per page).
- `events`: bounded authoritative event projection; `beats`: bounded presentation
  cues carrying kind/participants/place/path/text/aftermath as applicable.
- `incidents`: stable-ID warning/open/joining/joined incident projections with
  family, participants, place, cause, stage deadline and intervention deadline.
- `social_engagements`: active presentation commitments; each has `{id, family,
  template_id, participants, place, cue, started_ms, duration_ms, remaining_ms}`.
  Participating Echoes expose the same non-empty `engagement_id`. Beats announce
  boundaries, but this collection is the authoritative persistent world cue.
- `bonds`: canonical shared projections `{actor_a, actor_b, strength, tier,
  tier_name, bond_type, encounter_count, last_event_id}`. Each Echo's `bonds` uses
  `{other_id, name, strength, tier, tier_name, bond_type, encounter_count,
  last_event_id}`. Stable order is tier, then displayed name, then ID.
- `joined_incident_id`: empty or the sole incident owned by the current Keeper
  intervention. The incident itself remains authoritative for status and deadline.
- `village_history`: newest-first significant social, Keeper, bond, emotional and
  incident summaries derived from the same retained events. It is shown through
  Ase Flame inspection and does not fabricate conversations.

Normal projection excludes raw fear/morale, internal pressures/bias/preferences,
candidate scores, competing reasons, exchange guards, commands and initial replay
state. Debug projection includes candidate `{family, place, score, reason}` entries,
contributing factors and competing reason. Player reasons must describe actual
contributing needs, identity, emotion, day phase or destination conditions.

Controller adds selection/panel/observation/speed/reduced-motion/notices/metrics.
Camera and presentation interpolation never determine simulated position/outcomes.
Occupancy and 'Here now' exclude moving Echoes whose last node is that place.

Controller test seams: `advance_elapsed(delta: float)` and
`set_application_focused(focused: bool)`. A controller-only `session_serial` in
the projection invalidates visual interpolation and page state after reset; it is
not authoritative simulation state. Context navigation additionally uses
`prototype.view.current` and `prototype.view.history.page` actions.
Likewise, `observation_serial` marks an explicit Observe/Refocus request so manual
pan can be overridden intentionally; ordinary snapshots do not recapture the camera.

## Travel, routines and conversations

Travel consumes world distance continuously across authored edges, with stable
routing. No node teleport followed by an unrelated tween. Routine duration starts
on arrival; seed duration variation and initial decisions to avoid lockstep.
Pressure updates scale by elapsed simulation time, not render frames. Day biases
are soft and apply at decision opportunities, never forcing a phase-boundary move.

Speaking to a stationary Echo enters `choosing`. Speaking to a moving Echo enters
`approaching`: finish its current edge, then hold at that waypoint and enter
`choosing`. Topics/replies are disabled during approach. No teleport and no waiting
pressure/reward accumulation. Only that Echo is held; others continue.

Conversation `{echo_id, status, topic}` statuses: approaching, choosing, resolved.
Committed result adds outcome/reason/line and `release_at_ms`; simulation releases
after 1500 ms (six steps), independent of reduced motion. Pause freezes release.
Cancel while approaching/choosing applies no intervention. A resolved reply cannot
be cancelled, discarded by Back/selection, or applied twice. Repeated exchanges
cannot repeatedly grant benefits within the same autonomous decision context;
after a new autonomous decision, the same suggestion can be evaluated against the
new circumstances. Opening/closing conversations does not reset that guard.
Keep the existing three topics and two replies.

Keeper conversation and a joined incident are mutually exclusive. Beginning Speak
or joining an incident fails while the other interaction is active. Selection,
Observe and history inspection never reserve an Echo or alter playback.

## Gate 2 relationships and autonomous social exchanges

Use `SocialGraphService` pure helpers against prototype-owned arrays. Never call the
production runtime, campaign state, or save layer. Preserve its canonical shared
pair, -100..100 clamp, eleven tiers, and friend/neutral/rival thresholds (+30/-30).
All fixtures start with no edges or encounter pairs. Proximity alone never creates
an edge, encounter, impression, pressure reward, or history line.

An eligible exchange requires two stationary, unreserved Echoes at the same actual
place, a social family/template, and an expired pair/template cooldown. Evaluate
both participant reactions from the same pre-event state, then apply participant
effects and exactly one explicit shared bond delta. Record the encounter even when
the delta is zero; never create a bond edge for a zero delta. Stable pair/template
ordering and namespaced seed draws decide ties. Autonomous engagement prevents a
participant from entering a conflicting exchange until the bounded presentation
commitment resolves; unrelated Echoes continue.

Initial reusable families and outcomes:

- `companionship`: welcome company, quiet company, unwanted attention.
- `care`: accepted support, declined help, protective response, caregiver strain.
- `practice`: shared practice, encouragement, recognition, impatience, rivalry.

Needs, traits, archetype, canonical emotional status inputs, location, shared bond,
and active impressions must reach actual participation/reaction choices. Respectful
refusal does not automatically damage a bond. Care may help the receiver and tire
the giver. Productive competition may satisfy Purpose with neutral or positive bond
movement while creating a `challenged` impression. Ordinary positive deltas remain
small; salient incident outcomes may be larger. Data owns template deltas,
participant effects, durations, cooldowns and bounded impression influence.

An impression is directional context, not a second relationship meter:
`{owner_id, other_id, family, tag, cause_event_id, cause, created_ms, expires_ms,
influence}`. A later relevant interaction replaces the same owner/other/family
impression. Its decision influence ends after one current village-day duration even
if day length changes later; retained history remains until normal event pruning.
History pruning cannot reset bond strength, delete encounter knowledge, or leave an
active impression without enough copied cause text to explain it.

## Gate 2 incidents and Keeper intervention

Implement the bounded lifecycle `ambient friction -> warning -> open incident ->
unresolved mutation/autonomous resolution -> aftermath`. An enacted tense social
exchange may create a warning according to local rules; there is no random warning
without participants, place and cause. Warning expiry changes stage rather than
silently resolving. An open incident invites intervention without changing playback
or focus. Its unattended deadline uses simulation time.

Actions are:

- `prototype.incident.join` with `{incident_id}`.
- `prototype.incident.reply` with `{incident_id, reply_id}`.
- `prototype.incident.defer` with `{incident_id}`.

Joining is idempotent and takes Keeper ownership of participants already held at
reached waypoints by the incident.
The joined deadline is the smaller of the configured intervention window and the
remaining incident lifetime. Pause freezes every deadline; Fast advances them at
the same 3x simulation rate. Closing/reopening UI cannot replenish time. Deferring
releases Keeper ownership once without clearing the underlying issue or releasing
its participants; expiry removes
the influence opportunity and resolves from actual pre-resolution traits, needs,
emotions, bond and impressions. Frustration is conditional, not an automatic timeout
penalty. An ignored issue may change expression at its stage boundary. Reply,
deferral, expiry and release are guarded by incident ID/status and resolve once.

Incident results separate `participant_effects` from one `shared_bond` consequence
and carry participants, place, response, cause and aftermath. Presentation never
infers an outcome from prose. Next Beat is disabled while a joined Keeper reply is
pending and stops on warning, incident, exchange, intervention or aftermath changes.

Incident projection is exact: `{id, family, template_id, label, status,
participants, place, cause, created_ms, stage_started_ms, stage_deadline_ms,
intervention_deadline_ms, remaining_ms, can_join, reply_choices, result,
release_at_ms}`. `reply_choices` is an Array of `{id,label}` only when joined;
`result` is empty until resolved, then contains `{response, participant_effects,
shared_bond, aftermath, aftermath_behaviors}`. Statuses are `warning`, `open`,
`joined`, `resolved`.
A resolved result remains protected and visible for the existing 1500 ms release
period, then the incident leaves active state. Warning cues are selectable but cannot
be joined. Joining an open incident automatically selects/focuses it in presentation.
Back or empty-click during `joined`/`resolved` only closes the panel; it does not
defer, release, replenish time, or discard a result. Defer is explicit and joined-only.

Significant history records use exact kinds `social_exchange`, `impression`,
`emotion_change`, `bond_change`, `incident_warning`, `incident_open`,
`incident_mutation`, `incident_intervention`, and `incident_resolved`, alongside
existing `response` and visit source kinds. Each significant record includes a short
player-facing `title`; social and incident records may additionally carry structured
`participant_effects` and `shared_bond`. Local and Flame formatters select structure
from `kind` and fields, never parse prose to infer the event type or outcome.

Raw auxiliary consequence records remain test/debug evidence, but visible history
must not turn one exchange into separate social, impression, emotion and bond rows.
Echo/place Recent and `village_history` show one `social_exchange` row with its
participant effects, impression changes and shared bond consequence folded into that
summary. Incident resolution rows likewise carry their effects and shared bond;
auxiliary `impression`, `emotion_change`, and `bond_change` records are omitted as
standalone visible rows when their `source_event_id` points to a retained parent.
Warnings, opening, explicit intervention/deferral, mutation and final resolution are
separate visible stages because each changes what the Keeper can understand or do.

## Session history

One bounded event collection, maximum 512. Preserve actual activity arrivals,
completed routines and committed non-repeated Keeper replies. Gate 2 additionally
records enacted social exchanges, participant reactions/effects, impression changes,
shared bond changes, warning/incident transitions, interventions, emotional-state
changes, and autonomous outcomes. Do not log every motion step or invent unseen
dialogue that was not resolved by the simulation.
Records: `{id, step, elapsed_ms, day, day_phase, kind, participants, place, text,
cause, aftermath, significant}`. History is projected from these shared records.
Record actual location, not intended destination before arrival.
Starting or continuing an activity without travel is an `activity_started` event,
not a physical arrival. Decisions use shared occupancy after this step's travel.

### Gate 1 playtest adjustment: readable recent history

The authoritative `events` collection remains a maximum of 512 enacted records.
Echo and place history projections summarize those records into visits so routine
starts and completions do not create a new visible line every time. A visit groups
one Echo's consecutive activity records at one place until that Echo records an
activity at another place. The summary retains `source_ids`, first/latest time,
activity count, actual cause, and latest aftermath; it never fabricates dialogue.

Keeper responses remain their own visible entries. Later significant social and
incident events will also remain standalone. Completing or changing a routine at
the same place updates the visit summary instead of appending another line. Raw
events remain available to deterministic tests/debug projection and are not
discarded by UI bundling.

Gate 1 preserves fixture fear/morale; it does not add autonomous recovery rewards.
Canonical emotional status is a truthful projection and emotion affects decisions.
Emotional-change events will be introduced with the real social effects in Gate 2,
not as unused emission hooks now.

Future production constraint: history/memories belong to a save/campaign instance.
Deleting/replacing a save must invalidate its history and caches. Never use global
memory keyed only by Echo ID. Bounded recent history plus compact enduring memories
requires a production save lifecycle design before promotion; no persistence now.

## Gate 2 tuning and presentation

Eight live controls exist in Gate 2, all with actual consumers:

| Key | Default | Range / step |
|---|---|---|
| `day_minutes` | 12 | 3..24 / 1 |
| `routine_seconds` | 30 | 10..90 / 5 |
| `rest_weight` | 1 | 0..3 / 0.1 |
| `company_weight` | 1 | 0..3 / 0.1 |
| `purpose_weight` | 1 | 0..3 / 0.1 |
| `social_frequency` | 1 | 0..3 / 0.1 |
| `warning_seconds` | 60 | 15..180 / 5 |
| `intervention_seconds` | 45 | 15..90 / 5 |

Routine seeded variation ±20%; trait persistence may add a bounded contribution.
Fixture triples must derive intended canonical archetypes: Kojo Loyal, Abena Proud,
Esi Reflective, Ama Empathic, Kweku Canny, Yaw Stoic. Current fear is not archetype.
Preserve their distinctive preferences and original emotional starting values.

Normal delivers 250 ms steps, Fast 3x. Retain fractional time; cap work per frame
without dropping ordinary elapsed simulation time. Pausing/focus loss discards
wall-time catch-up; selection does not. Next Beat advances at most 240 steps, stops
on meaningful change, then stays paused; unavailable throughout a conversation.

One context surface; separate Current/Recent views on people and places, pagination
for history. The Flame's Recent view is the village-wide significant summary; its
Current view explains the slice boundary. Closer selection focus, safe
panel framing, manual pan override, smooth following; reduced-motion option.
Primary layout and capture target: fullscreen 1920x1080. Secondary verification:
1600x900 and 1280x720. Keep 960x540 as a supported edge case. Keep tokens
distinguishable by marking/name.

Autonomous social exchanges use explicit participant orientation and a concise cue.
Warnings and open incidents are visible in world and context without forcing focus
or pausing. Joining frames both participants; manual pan override still works.
Incident UI shows cause, remaining simulation time, contextual reply choices and
structured aftermath. Do not add a permanent incident menu, roster, or Chronicle.

Clicking empty world space closes ordinary selection and its context panel. It
cancels an uncommitted conversation but cannot discard a committed response.
Person and place selection use a clearly stronger close focus than overview.
Morning, afternoon, evening, and night apply a smooth presentation-only village
palette shift; calendar color never changes simulation outcomes.

## Verification / delivery

Tests own their fixtures and only access prototype state. Cover deterministic
replay with tuning, travel/occupancy, calendar tuning, all placement combinations,
canonical emotional status, trait and tuning reachability, bounded real history,
reservations/cancel/commit/repeat/reset, paused release, frame partitions, speed,
selection, Next Beat, snapshot independence, keyboard and responsive integration.
Godot commands use `/usr/bin/perl -e 'alarm shift; exec @ARGV' 200` watchdog.
Run prototype harness + scene smoke + repository compile + full suite. Inspect
outputs and completion, not exit code alone. Root reviews and visually checks.
Gate 2 verification additionally covers empty starting bonds, canonical shared edges
from both lookup directions, participant-specific reactions, single bond application,
impression replacement/expiry/behavior influence, cooldown anti-farming, meaningful
social history, incident stage/timeout/deferral/idempotency, background continuity,
pause/Fast deadline equivalence, and Flame summary discovery. Stop for Jeff's Gate 2
in-game test; no Gate 3 and no commit before signoff.

### Verification safety finding

On this checkout, the prescribed repository command `--check-only --quit` without
`--script` starts the production entry scene. Gate 1 agent runs reported both
validated-save loading and transactional-save writes. Do not repeat that command
as a supposedly inert parser check. No save restoration was attempted.

Use the same 200-second watchdog with an explicit prototype script for parsing,
and the explicit prototype scene for smoke checks. The full repository suite uses
`-- tests`, whose AppRoot initialization selects
`/tmp/echoes-vnext-tests/headless_runtime_slot.json`. This verification caveat does
not authorize changing production startup, saves, or repository-wide instructions.

## Gate 2 incident result overlay correction

After a joined incident resolves, project one pending presentation result. The UI
opens a full-screen non-pausing result overlay above the village. Simulation time and
unrelated village life continue behind it. The overlay persists until the player
dismisses it; dismissal changes presentation state only and resolves exactly once.
It must not extend incident ownership, participant reservation, deadlines, or the
bounded simulation aftermath.

The result leads with a concrete outcome and shows participant reactions, qualitative
bond direction/tier, emotional direction, next behavior, and whether the underlying
cause eased or remains. If recurrence remains possible, name the surviving human
cause in plain language. Do not expose raw deltas, pressure scores, cooldown values,
or internal rule names.

Each Keeper reply provides a short qualitative consequence cue before commitment.
The cue communicates a likely direction through familiar wording and visual tone,
without stating exact effects or guaranteeing the outcome. It is structured data,
not inferred from the reply label.

Only one result overlay may be pending. Later autonomous events continue to enter
history while it is open, but cannot replace the pending Keeper result. Back or the
explicit continue action dismisses it and restores the prior world context. Reset
clears it. Stale dismissals do nothing.

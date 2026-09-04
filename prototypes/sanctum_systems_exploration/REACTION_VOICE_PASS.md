# Gate 3 correction — visible reactions and point of view

This is a bounded correction before the next Sanctum slice. It does not add a new
relationship model, unrestricted group incidents, persistence, or a narrative
scripting framework.

## Player-facing language contract

Every player-facing string has an explicit speaker and time relationship:

- Live notifications use a brief neutral narrator in present tense.
- An Echo's Current view uses that Echo's first-person present perspective.
- An Echo's Recent view uses that Echo's first-person remembered perspective.
- Place Recent and the Ase Flame summary use concise past-tense village history.
- Incident choices are direct Keeper actions with a short possible-direction hint.
- Results use past tense for the completed action and present tense for feelings,
  relationships, unresolved causes, and next behavior.
- Conversation is direct first-person speech.
- Internal/GDD terms are restricted to Lab. Player-facing copy names people, wants,
  observable actions, responses, consequences, places, and next actions.

Copy remains bounded and authored in local prototype data. Templates may substitute
participant and place names, but cannot produce generic prose from system labels.
Each Echo may have a compact voice profile for directness, sentence length, conflict
style, and what they notice. This presents their current view without exposing
otherwise hidden mechanics.

## Visible reaction contract

The simulation authors transient structured reaction data; presentation never
infers a result from prose:

```gdscript
{
  "kind": "welcomed|appreciative|uncomfortable|crowded|challenged|hurt",
  "target_id": String,
  "motion": "closer|acknowledge|angle_away|step_back|square_up|withdraw",
  "started_ms": int,
  "duration_ms": int
}
```

Reaction state is deterministic, clears after its authored duration, survives Pause,
and advances with simulation time. It changes no bond or need by itself. A cue is a
presentation instruction attached to an enacted exchange or consequence.

World presentation combines facing, a small pose or position accent, and one
restrained cue above or between participants. It must not cover Echoes, resemble an
actionable incident, or require text. The response remains readable briefly before
the Echo begins an unrelated activity. Reduced motion uses orientation, shape, and
opacity instead of displacement.

## Bounded witness experiment

Only warning-producing practice exchanges may recruit witnesses in this pass.

- Keep two primary participants and their single shared bond consequence.
- Select at most three available non-participants through deterministic stable order
  and authored eligibility.
- Witness roles are `support`, `side`, `watch`, or `leave`, with an explicit target
  where relevant and one of the six reaction cues.
- Witnesses are not reserved and do not become incident participants.
- Proximity alone grants no bond, impression, need change, or history.
- A selected witness performs a visible response and receives one concise personal
  memory/perspective. Witness responses never multiply the primary pair's bond delta.
- No other social family gains witnesses in this pass.

Incident and event projections expose `witnesses` as structured entries containing
`echo_id`, `role`, `target_id`, `reaction`, and first-person `perspective`.

## Surface scope

Rewrite only Echo Current/Recent, live social notifications, incident warning and
choices, incident result, summoning reactions, and place/Flame Recent. Preserve the
existing information architecture, simulation rules, and action contracts.

## Acceptance

- With panels closed, an observer can identify the initiator, each primary Echo's
  positive/negative direction, and the immediate aftermath for at least 8/10 staged
  exchanges.
- Selecting either participant shows distinct first-person current language.
- Completed actions, ongoing feelings, and next behavior use appropriate tense.
- Player-facing surfaces contain no exposed internal/GDD vocabulary; Lab may retain
  it.
- One practice conflict can show up to three non-blocking witnesses without changing
  the pair's bond consequence or creating proximity rewards.
- Existing deterministic replay, Pause, reset, responsiveness, and nine-Echo
  selection contracts remain intact.

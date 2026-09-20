# Gate 3 correction — incident access and visible premise

This is a bounded correction to the existing Slice 2 incident system. It does not
add a second incident engine, Keeper reputation system, unrestricted group events,
or a general dialogue framework.

## Authoritative Keeper access

Every incident receives an immutable `keeper_access` when its warning is created:

- `private`: the Echoes do not permit Keeper intervention.
- `open`: the Keeper may step in, but neither Echo asks.
- `appeal`: one Echo explicitly asks the Keeper for help.

The simulation stores `keeper_access`, `appeal_echo_id`, and a concise authored
`access_reason`. Access is selected deterministically from existing courage, wisdom,
fear, rest, shared bond, impressions, archetypes, and incident family. Initial local
thresholds and archetype biases live in prototype data and remain debug-visible.
Do not add a Keeper relationship score for this pass.

Incident lifecycle remains `warning -> open -> resolved`. Access is separate from
stage. `can_join` is true only while status is `open`, access is `open` or `appeal`,
and existing reservation/interaction requirements pass. `_join_incident()` repeats
the same authoritative access check. Private, stale, fabricated, repeated, or
otherwise invalid join commands change no state, reservation, deadline, or history.

Private incidents always resolve autonomously. Ignored open incidents and ignored
appeals also resolve autonomously at their existing deadlines. Autonomous outcomes
may settle, worsen bonds, create impressions, change emotions, and alter subsequent
behavior. No Keeper reaction is invented when the Keeper did not participate.

## Visible premise before action

Each incident family authors one compact two-line exchange in local data. At warning
creation, the simulation formats and stores:

```gdscript
"exchange_lines": [
  {"speaker_id": String, "text": String},
  {"speaker_id": String, "text": String}
]
```

Lines are first-person, present-tense, concrete, and name no internal/GDD systems.
They describe the actual disagreement that produced this incident. They exist during
warning and open states, before any join command, and remain attached to its history
and result. Joining enters the exchange already underway; it never unlocks the
premise retroactively.

## Presentation

- World: briefly show the two authored lines near their speakers during warning/open
  without pausing, reserving additional Echoes, or covering tokens.
- Selected incident order: **What they are saying -> Status -> Why -> Action**.
- `private`: compact non-actionable treatment, “They are handling this,” no join CTA.
- `open`: optional treatment, “You can step in,” with a `Step in` CTA.
- `appeal`: the named Echo visibly asks for help, with an `Answer <name>` CTA.
- Warning never shows an intervention CTA, regardless of access.
- Private incidents cannot use the same visual weight as an appeal. None auto-focus,
  pause the village, or open a full-screen result when the Keeper did not participate.
- Reduced motion preserves speaker identity, line order, access state, and action
  availability without animated displacement.

Use existing contextual surfaces and world drawing. Add `.tscn` structure only if a
new persistent UI relationship is necessary; do not construct hierarchy in script.

## Acceptance

- Controlled fixtures reach all three access states deterministically.
- Equal seed/state creates identical access, appeal speaker, exchange, resolution,
  and history.
- Private incidents never expose `can_join`; direct join commands are rejected and
  leave state byte-for-byte unchanged apart from command audit behavior already
  required by the prototype contract.
- Open and appeal incidents remain optional and autonomously resolve when ignored.
- At least one ignored outcome worsens the pair and affects later behavior.
- The complete two-line premise is readable before join in world and incident focus.
- Join retains the same premise and resolves exactly once through existing replies.
- Selection/inspection never changes access, deadlines, reservations, or playback.
- Pause, Fast, Next Beat, reset, stale actions, reduced motion, responsive layouts,
  and nine-Echo selection retain their existing contracts.
- Production state and saves remain untouched.

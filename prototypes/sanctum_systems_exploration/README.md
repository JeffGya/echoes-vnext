# Sanctum systems exploration

This standalone Godot scene is an in-memory systems prototype. It does not load or
write production campaign saves.

## Run

```bash
/opt/homebrew/bin/godot --path /Users/jeffreygyamfi/Sites/echoes-vnext res://prototypes/sanctum_systems_exploration/SanctumLivingHouse.tscn
```

Place the Hearth and Training Grounds, then choose **Let the village live**.

Gate 2 adds autonomous companionship, care and practice; shared bonds and personal
impressions; warnings and timed Keeper interventions; and the village-wide Recent
summary on the Ase Flame. Pause freezes simulation deadlines. Fast runs simulation
time at 3x. Selection and inspection do not pause the village.

The focused Gate 2 revision keeps unresolved participants together through the
issue, then presents a bounded visible aftermath before their next intention. Echo
needs and relationships use qualitative visual components; raw values remain in the
Lab. Early friction appears as a compact notification; the larger incident standard
begins only when Keeper action becomes available. Selecting a conflict shows what is
happening, why, whether action is possible, and what changed afterward. Recent uses
folded visual event cards and plainer family-history language.

A committed Keeper reply opens a full-screen result while village life continues
behind it. It shows the direction of the relationship and emotional consequences,
what each Echo thinks, what they do next, and whether the cause may return. Reply
choices signal their likely direction before commitment without showing exact
values. A same-pair conflict family cannot immediately repeat after resolution.

Echo, place, Flame, and incident selection all use the same responsive camera zoom.
Selection never enlarges an individual token or hides contextual occupants.
Fullscreen 1920x1080 is the primary playtest target; 1600x900, 1280x720, and 960x540
remain supported.

The **Lab** exposes prototype diagnostics and eight live tuning controls. Numeric
values and current dialogue are diagnostic prototype presentation, not final game UI
or writing.

Gate 3 adds three repeatable, authored returns through the Ase Flame. The village
starts with 60 Ase, recovers 60 per village day up to 120, and spends 60 only when a
summon is committed. Each return moves through a visible manifestation, a portrait
and identity reveal, an untimed required welcome, and the newcomer's first choice of
where to go. Existing Echoes approach, watch, or keep their distance while village
life continues. The three newcomers are consumed once each in deterministic seeded
order, bringing the population from six to nine.

All nine Echoes now have distinct mock portrait busts for arrival, reaction, and
result surfaces. Incident results use the same portrait-first language: participants,
relationship direction, emotional response, next behavior, and unresolved cause are
visible before the supporting explanation. Social exchanges also author six small
world reaction cues—welcomed, appreciative, uncomfortable, crowded, challenged, and
hurt—through facing, pose accents, and restrained marks above or between Echoes.
Practice warnings may draw up to three non-blocking witnesses without adding another
pair bond consequence.

Live notifications use present-tense narration with participant names. Selecting an
Echo leads with their first-person current view; their Recent view uses first-person
memory, while place and Flame history remain concise past-tense records. Internal
prototype language stays in Lab. The layouts are verified at 1920x1080, 1600x900,
1280x720, and 960x540 with at least 16px text and 48px targets.

Incidents now separate visibility from Keeper authority. Each warning is assigned an
immutable **private**, **open**, or **appeal** access state from the Echoes' existing
traits and circumstances. Private incidents cannot be joined, open incidents permit
optional help, and appeals name the Echo asking. Every incident exposes its two-line
exchange before intervention, and ignored incidents continue to resolve through the
Echoes' own attributes with lasting fallout.

Gate 3 technical status: prototype backend **200/200**, full prototype integration
**393/393**, standalone scene smoke passed, repository compile passed, and repository
regression suite **1401/1401**. Jeff approved Gate 3 after the incident-access and
Echo Recent corrections. Slice 2 is complete and ready for its scoped commit.

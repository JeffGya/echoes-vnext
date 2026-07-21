# Keeper Tactical Guidance Prototype

## Launch

From the repository root, launch the isolated entry scene without changing `project.godot`:

```bash
/opt/homebrew/bin/godot --path /Users/jeffreygyamfi/Sites/echoes-vnext res://prototypes/keeper_tactical_guidance/KeeperTacticalGuidance.tscn
```

For a headless scene-load smoke check:

```bash
HOME=/tmp /opt/homebrew/bin/godot --headless --path /Users/jeffreygyamfi/Sites/echoes-vnext res://prototypes/keeper_tactical_guidance/KeeperTacticalGuidance.tscn --quit-after 3
```

`HOME=/tmp` avoids a macOS headless logger crash if the normal Godot `user://logs` directory is unavailable. It does not alter prototype behavior or seeds.

## Automated verification

Run the prototype harness:

```bash
HOME=/tmp /opt/homebrew/bin/godot --headless --path /Users/jeffreygyamfi/Sites/echoes-vnext --script res://prototypes/keeper_tactical_guidance/tests/PrototypeTestRunner.gd
```

Run the repository compile check:

```bash
HOME=/tmp /opt/homebrew/bin/godot --headless --check-only --quit --path /Users/jeffreygyamfi/Sites/echoes-vnext
```

The v0.6 harness runs deterministic batches for both `RECOVER` and `PROTECT`, board topology, raised obstacle projection and renderer fallback, route/chokepoint validation, all three hazards, objective win/loss seams, round-only Ping Charge rules, all five exclusive recipient-mode pings, delayed activation and response isolation, all five response outcomes, all four Directives, automatic-only controller playback, all three speed intervals, live ping browsing/confirmation, replay equality, structured movement/damage animation data, and an instantiated automatic journey from briefing to review. A non-zero process exit means at least one check failed.

Optional deterministic layout captures for visual review:

```bash
HOME=/tmp /opt/homebrew/bin/godot --rendering-method gl_compatibility --path /Users/jeffreygyamfi/Sites/echoes-vnext --script res://prototypes/keeper_tactical_guidance/tests/VisualCapture.gd -- --width=1440 --height=900 --output=/tmp/keeper_tactical_guidance_desktop.png
HOME=/tmp /opt/homebrew/bin/godot --rendering-method gl_compatibility --path /Users/jeffreygyamfi/Sites/echoes-vnext --script res://prototypes/keeper_tactical_guidance/tests/VisualCapture.gd -- --width=1024 --height=720 --output=/tmp/keeper_tactical_guidance_compact.png
```

## Manual playtest

1. On Briefing, enter a seed, switch between `RECOVER` and `PROTECT`, and inspect routes, hazards, deployment, and objective rules. Use New Seed once, then return to the original seed for comparison.
2. Continue to Preparation. Select one of `Scout Carefully`, `Seek Signs`, `Press the Path`, or `Hold the Circle`. Confirm there is one detailed party roster: select an Echo there, then choose a cyan board slot. Select an occupied slot and verify the two assignments swap. Board tokens are positional and must not provide a second Echo-selection method.
3. Start combat. Playback begins and remains automatic. Switch among Slow, Normal, and Fast; confirm only presentation speed changes and there are no pause, resume, or manual-step controls.
4. Verify Ping Charge starts at 0 and gains exactly +1 only after a complete round, regardless of how many living actors took turns. The thresholds are Echo-specific at 2, area-based at 3, and party-wide at 5.
5. Browse every ping while combat continues. Before confirming, read its suggestion, mechanical influence, exclusive recipient mode, target instruction, footprint/AOE, eligible Echoes, charge requirement, next-round activation, availability, and any invalid reason. Cancel once and confirm charge is unchanged.
6. Confirm a valid ping. It should commit after the current atomic turn without pausing playback or immediately producing responses. Confirm its snapshotted recipients remain visibly highlighted as `pending` through the confirmation round.
7. In the next round, watch each pending recipient's first living turn. Immediately before that action, the UI must show Align, Interpret, Hesitate, Object, or Refuse and a clear reason. The movement/guard/attack that follows in the same turn should visibly express or reject the guidance. Unaffected Echoes must not respond.
8. Watch movement interpolation, attack anticipation/lunge, target punch/flash, damage number, and recovery. Source and target should be understandable without reading the timeline.
9. Confirm hazards and filled raised obstacles are readable on the isometric board. Routes and chokepoints are labeled optional overlays during briefing/preparation and are hidden during combat; ordinary tiles have no unexplained lines.
10. Finish the battle and review objective result, rounds, downed/endangered Echoes, pings, responses, hazard effects, and event timeline.
11. Restart Same Seed, change the Directive/deployment/ping timing, and compare the report. Then run a New Seed battle in the other objective mode.

## Metrics and debug instrumentation

The combat/review snapshots expose `data.metrics`, generator diagnostics in `data.board.validation`, attention cues, response feedback, and the structured timeline. The UI's debug/metrics presentation reads these real snapshot values. `tests/PlaytestMetrics.gd` is a read-only formatter for turns, rounds, pings, response outcomes, hazard damage/forced movement, objective events, and timeline length; it never changes simulation behavior.

For a playtest, record whether the Keeper can identify at least three meaningful decisions, explain what every ping suggests before using it, distinguish listening/resisting/rejecting feedback, recognize the ping's influence in each recipient's first next-round action, and distinguish the four Directive replays on the same seed. Also note invalid board diagnostics, confusing footprints, waiting-only stretches, unreadable attack source/target pairs, duplicate Echo-selection affordances, unexplained board marks, and any ping that overwhelms Echo identity.

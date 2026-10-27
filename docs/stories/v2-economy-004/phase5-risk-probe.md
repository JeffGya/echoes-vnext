# Phase 5 risk probe: can the player trade speed for safety?

Decision: D-52. Probe only. No game change. No file under `core/` or `data/` was edited.
Probe file: `tests/RiskProbeTests.gd`, suite name `risk_probe`.

## 1. The question

Which player choices change (a) the pace outcome and (b) the Echo loss rate?

- Pace outcome: `pace_state` (full, partial, none) and the pace fraction.
- Echo loss rate: dead Echoes at the end of a fight. Win rate is also recorded.

## 2. Player levers (found by reading)

| Lever | Status | Evidence | Reachable in the harness |
|---|---|---|---|
| Directive: `directive.scout_carefully`, `directive.seek_signs` | BUILT | `data/balance.json:5` and `:40` (registry); action `directive.select` at `core/runtime/FlowRuntime.gd:610`; combat reads `exposure_tolerance` (`data/balance.json:30`) in `BehaviorArbiter` and `StopShortService` | Yes. Dispatch `directive.select` before the encounter, as `FlowFingerprintTests._setup_encounter` does (`tests/FlowFingerprintTests.gd:141`). |
| Keeper guidance (spatial suggestion) | STUB. Headless debug seam only. | `flow_ctx.dev_guidance` (`core/state/flow/FlowContext.gd:89`, comment names V2-COMBAT-004 as the real interface); action `debug.guidance.set` (`core/runtime/FlowRuntime.gd:594`, `core/runtime/controllers/DebugController.gd:355`); read by combat at `core/combat/CombatTurnContextService.gd:200`; five presets in `ui/AppRoot.gd:1192`. No player-facing ping exists. | Yes, through `debug.guidance.set`. This is a debug command, not a shipped player action. |
| Formation / deployment (assign Echoes to start slots) | NOT BUILT | Start cells come from `GridService.place_actors` (`core/grid/GridService.gd:290`), which sorts Echoes by `_placement_score` (`:606`) with an id tiebreak. No input reaches it (`core/combat/EncounterSetupService.gd:407`). GDD §7.3 (`docs/Echoes vNext Working GDD.md:257`) and `docs/proposals/keeper-tactical-guidance-promotion.md:81` describe it as a goal. | No. |
| Party size and members | BUILT (Sanctum) | `sanctum.party.toggle` (`core/runtime/controllers/SanctumController.gd:294`), cap `data.sanctum.party_max_size` = 5 (`data/balance.json:173`) | Yes. The probe builds the party directly, as the harness does. |
| Standing (rank) of the Echoes | BUILT (Sanctum) | `ProgressionService.execute_rank_up`, used by `FlowFingerprintTests._promote_echo_rank` (`tests/FlowFingerprintTests.gd:217`) | Yes. |
| Objective mode | Not a player choice in play. The stage sets it. | `core/combat/EncounterSetupService.gd:181` (dev override `dev_combat_objective`) | Used as the table axis only. |
| Retreat | BUILT | `encounter.retreat` (`core/runtime/FlowRuntime.gd:466`) | Not measured. A retreat ends the fight without a win. |
| Vows (party-size and calling conditions at stage entry) | BUILT | `core/sanctum/VowService.gd:447`, called at stage entry (`core/sanctum/VowConsequenceService.gd:167`) | No. The harness starts after stage entry. |
| Playback speed | Display only | GDD §7.3 | No effect on the simulation. |

Result: three levers act inside a fight and can be measured: Directive, guidance (debug only) and the party (size, Standing).
The two levers the GDD promises for combat, formation and shipped pings, do not exist.

## 3. Probe design

- Each fight runs through the production path of the fingerprint harness: `FlowRuntime.boot`, `FlowEncounterState.enter`, `combat.init`, `combat.confirm_round`, `combat.next_actor`.
- The seed is the `seed_tag` `rp_<mode>_<index>`. The campaign seed is pinned to 12346. The same (mode, index) gives the same party and board in every row, so rows are paired.
- One lever changes per row. Baseline row: `directive.scout_carefully`, no guidance, five Echoes, Standing 1.

| Row id | Change from baseline |
|---|---|
| `directive.scout_carefully` | none (baseline) |
| `directive.seek_signs` | Directive |
| `guidance.hold`, `guidance.advance`, `guidance.protect`, `guidance.withdraw`, `guidance.engage` | one `debug.guidance.set` preset, sent to every Echo |
| `party.size_3` | the first three of the same five Echoes |
| `party.standing_3` | all five Echoes raised to Standing 3 |

- Modes: `combat`, `purify_shrine`, `recover`, `pursue`, `guide_escort` (GUIDE_SPIRIT, `escort`, `nojoin`).
- `_setup` in the probe is a copy of `FlowFingerprintTests._setup_encounter` plus party size, Standing and Directive. The harness cannot take a party size and this change may not edit it. The test `risk_probe/mirrors_fingerprint_harness` runs the baseline once through the probe and once through the harness. It fails if the final fingerprint or the final actors differ. This guards the copy.
- Dead Echoes: party Echoes (faction `echo`, not `is_ally`, not `is_spirit`) with `is_dead` true at the end. This is the same set the reward tally uses (`core/state/flow/states/venture/FlowEncounterState.gd:127`). A downed Echo is not dead (D-45).
- Pace: `pace_state` comes from the resolve snapshot (`core/state/flow/states/venture/ResolveSnapshotBuilder.gd:221`). It exists on a pace-mode win only. The fraction is not in the snapshot. The probe recomputes it with `PaceService.bonus_fraction` from `combat_state` (`par_rounds`, `pace_full_ratio`, `pace_zero_ratio`).
- `answers`: for each fight, the count of Echo answers to the guidance by `consent` value. It shows whether the guidance reached the Echoes.

### Tests and what they assert

| Test | Asserts |
|---|---|
| `risk_probe/matrix` | Every fight finished within 60 rounds. Nothing else. No design number. |
| `risk_probe/deterministic` | The `guidance.withdraw` cell on `recover` run twice gives an identical record. |
| `risk_probe/mirrors_fingerprint_harness` | The probe setup and driver equal the harness (see above). |

### Size

| Variable | Default | Meaning |
|---|---|---|
| `RISK_PROBE_SEEDS` | 1 | Seeds per mode and row |
| `RISK_PROBE_SEED_START` | 0 | First seed index (to split a large run into slices) |
| `RISK_PROBE_MODES` | `recover` | Comma list, or `all` |
| `RISK_PROBE_ROWS` | `directive.scout_carefully,directive.seek_signs,guidance.engage,party.size_3` | Comma list of row ids, or `all` |

The default is a smoke run, not a measurement. Measured on the dev machine: 48 s of test time, 55 s wall-clock, 4 fights plus 4 more for the two guard tests.
Cost is about 0.3 s per actor turn. One fight took: `recover` 6.6 s, `combat` 6.9 s, `purify_shrine` about 9 s, `pursue` 65 s, `guide_escort` more than 105 s (not finished).
The full matrix is 9 rows x 5 modes x N seeds.

## 4. How to read the output

Per fight (one line each, use these for your own aggregation):

```
RISK_FIGHT <row> | <mode> | seed=<i> | win=<bool> | reason=<end reason> | rounds=<n> | par=<x> | pace=<full|partial|none|-> | frac=<0..1 or -1.00> | started=<n> | dead=<n> | answers={...}
```

Summary table (stable format):

```
RISK_TABLE row | mode | fights | win_rate | mean_rounds | pace full/partial/none | mean_dead | mean_frac
```

Last line: `RISK_PROBE total fights: <n>`. The `Tests:` line is the only pass evidence.

How to compare:

1. Compare a row with the baseline row in the same mode. The seeds are paired.
2. A lever "trades speed for safety" only if, in the same mode, it lowers `mean_rounds` (or raises `mean_frac`) AND raises `mean_dead`, or the reverse. A lever that moves only one of the two is not a trade.
3. `pace=-` with `frac=-1.00` means a loss or a no-pace result. A loss has no pace outcome.
4. `answers={}` on a guidance row means the suggestion reached no Echo in that fight. Read the row as "no effect because no delivery", not as "guidance does not matter".
5. Read `frac` before `pace`. `pace_state` is set from the Ase paid (`core/combat/PaceService.gd:pace_state`). With the harness stage base the maximum bonus is 1 Ase, so a fraction of 0.82 still reads `full`. The state hides most gradations. The fraction does not.

## 5. What the probe cannot show

- Formation and deployment: NOT BUILT. No row exists for them.
- Shipped player pings: NOT BUILT. The guidance rows use the debug seam. They show what a future ping lever could do. They do not show what the player can do today.
- Vows, retreat, items and Sanctum buildings: not driven.
- Only one stage setup (`realm.01`, `stage.0`). The par and stage base come from it. Other stages can differ.
- With few seeds, any difference is an anecdote. The default size shows only that the probe runs.
- My short runs (seed 0 only: `recover` 4 rows, `combat` 6 rows) gave the same win, rounds and zero dead Echoes in every row, except `party.size_3` on `combat` (7 rounds, not 6). This is one seed. Do not read it as a result. Guidance did reach the Echoes in `combat` (`engage`: 30 `align` answers, `hold`: 4 `hesitate`). `withdraw` reached none.
- `guide_escort` was not finished in 105 s on the dev machine, so its pace output and end are unverified.
- `pursue` with seed 0 lost on `window_expired` in the baseline. The fingerprint harness tag wins. The probe reports what its own seeds do.

## 6. RUN REQUEST (main chat)

Subagent rule: a subagent does not run a command that can take longer than 2 minutes. These runs are for the main chat.

1. Command, one slice at a time (set `MODES`, `ROWS`, `SEEDS`, `START` per slice). Full matrix, 5 seeds:

```bash
cd <checkout>
rm -rf /tmp/echoes-econ004-probe
ECHOES_TEST_SAVE_DIR=/tmp/echoes-econ004-probe RISK_PROBE_MODES=all RISK_PROBE_ROWS=all RISK_PROBE_SEEDS=5 \
  /usr/bin/perl -e 'alarm shift; exec @ARGV' 3600 /opt/homebrew/bin/godot --headless --quit --path <checkout> -- tests =risk_probe \
  > /tmp/echoes-econ004-risk-full.log 2>&1
```

   Pass `timeout: 3700000` on the Bash call.

2. Expected duration. From the per-fight costs above, 5 seeds x 9 rows costs about: `combat` 5 min, `recover` 5 min, `purify_shrine` 7 min, `pursue` 50 min, `guide_escort` more than 80 min (estimate, unmeasured). Run `guide_escort` and `pursue` as their own slices in parallel, each with its own `ECHOES_TEST_SAVE_DIR` (a different directory per process). The three guard tests add about 25 s per run. Do not run two processes on the same directory.
   Suggested first run, to verify `guide_escort` ends: `RISK_PROBE_MODES=guide_escort RISK_PROBE_ROWS=directive.scout_carefully RISK_PROBE_SEEDS=1`, alarm 600.
3. Files edited by the run: none. The run writes only under `ECHOES_TEST_SAVE_DIR`. Delete that directory before each run.
4. Restore check: `git status --short` shows no change beyond the files of this change (`tests/RiskProbeTests.gd`, `ui/AppRoot.gd`, `scripts/test-shard-map.sh`, `AGENTS.md`, this doc). `data/` and `core/` are untouched: `git diff --stat -- core data` is empty.
5. Output to read back: `grep -E "RISK_|Tests:" <log>`. Read the `Tests:` line first (it must show 3 total, 3 passed). Then the `RISK_TABLE` lines and `RISK_PROBE total fights`. Keep the `RISK_FIGHT` lines for the paired comparison.

Do not run the `risk_probe` suite in a normal sharded run with `RISK_PROBE_*` set. Without the variables it runs the smoke size.

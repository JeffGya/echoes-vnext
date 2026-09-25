# Pace reward: follow-up tasks

Work found during the pace-reward story (decisions.md D-01 to D-06, ANSWERS.md #63, #64) that is **not** part of this story.
Each item says where it came from and who owns it today.

This story absorbs two follow-up tasks from `docs/stories/v2-combat-003.5/followup-tasks.md`:
**#2** "Review PURSUE reward payout after board-size increase" (`task_0a287277`) and **#4** "Check
if speed_bonus_threshold needs to scale with board size" (`task_1868ffd0`) (decisions.md D-01).

---

## 1. Decide what the combat rank must measure

**Decided as a separate story:** decisions.md D-04.
**Why:** measured over 336 probe fights (stage 0, Standing-1 parties). Without the old speed term,
almost every win is rank S, and every loss is F. The old speed cliff was what spread wins across
S, A and B. A fair pace term does not restore a meaningful spread.
**Also relevant:** the rank feeds Thread recovery quality through `RealmService.contribute_segment`
(`core/realms/RealmService.gd:281-309`, `data.threads.segment_quality_by_grade`: S and A give
"clean", B to D give "compromised", F gives "broken"). A rank redesign changes Threads.
**Owner:** sr-game-designer with game-feel-developer.

## 2. Move existing story documents into `docs/stories/` — DONE

**Done in this story (Jeff, 2026-09-25):** 9 story documents moved with `git mv` into
`docs/stories/v2-combat-003/`, `docs/stories/v2-combat-003.5/` and `docs/stories/v2-infra-003/`,
and every reference updated. Kept at the top of `docs/` by Jeff's decision: `v2-migration-map.md`,
`resolve-snapshot-block-spec.md`, `combat-modes-distinctiveness.md`, `project_systems_audit.md`.
**Still open:** the Notion backlog export (`Echoes vNext V2 Story Backlog …_all.csv` and 22
`.translation` files) at the top of `docs/`. Godot imports the `.csv`, and the `.csv` still holds
old document paths. Handle it as a separate task.

## 3. GUIDE_SPIRIT escort is never won by escort

**Measured:** 0 of 48 escort fights in the probe ended with `spirit_escorted`. They ended when all
enemies died, when the spirit died, or after the probe's 30-round limit.
**Partly known:** `docs/stories/v2-infra-003/defect-register.md:265`: a non-joining escort spirit is built
as an immobile structure (approx. 1 in 4 GUIDE_SPIRIT fights cannot be won). Owner: V2-COMBAT-004.
**Not explained:** the joining-spirit half of the escort fights also never won by escort. The probe
did not record which spirits joined.
**Effect on this story:** escort has no pace term until the escort win is reachable.

## 4. Fights that do not end within 30 rounds

**Measured:** 19 to 23 of 336 fights did not end within the probe's 30-round limit, mostly
PURIFY_SHRINE and GUIDE_SPIRIT in realm.02. The game itself has no round limit.
**Partly known:** no round cap exists (`docs/stories/v2-infra-003/defect-register.md:267`, V2-COMBAT-004).
Possible cause: an Echo stands still when its goal cannot be reached
(`docs/stories/v2-combat-003.5/followup-tasks.md` #8, `task_c8dfaa47`). Not confirmed.

## 5. The forced-retreat result does not state the reason

**What:** when the no-progress check stops a fight, the result screen shows one fixed line ("The
fight did not end. The party pulled back. Nothing was gained."). The snapshot data has no
`reason` field and no `round_ended` (`VentureResolveSnapshotBuilder.gd:58-131`), and the internal
`combat_result.reason` is also empty on this path.
**Owner:** game-feel-developer advised a separate story (one story, one subject). Copy is Jeff's.

## 6. "Reached the party" must change when ranged attacks exist

**What:** this story defines "reached" as Chebyshev distance 1, because all attacks are melee today
(`CombatService.gd:70`). `data.actor.situational_muls` already has inactive placeholders for
extended reach and ranged attacks (`_stub_weapon_extended_reach`, `_stub_actor_has_ranged_skill`,
`_stub_enemy_type_ranged`). When one becomes active, the reach rule in this story must use the
attacker's real reach.

## 7. Pace measured on stage 0 only

**What:** all probe data comes from stage 0, where most fights have one enemy and the fight ends
about when the two sides meet (COMBAT: rounds ÷ travel rounds ≈ 1.1 on both boards). So a travel
par mostly measures walking time there. Later stages were not measured (decisions.md D-02, accepted
risk). Measure a later stage after the story ships, and check that the pace bonus still means
something.

## 8. Small stale documentation

- `core/combat/EncounterSetupService.gd:808`: the docstring of `resolve_objective_params` says it
  returns `{}` for modes other than RECOVER, PROTECT and ENDURE. GUIDE_SPIRIT is also handled
  (`:867-872`).
- Stale "ANSWERS.md #63 / #65 / #66" citations: these mean `docs/stories/v2-combat-003.5/decisions.md`
  #2 / #4 / #5. Fixed in this story (Jeff, 2026-09-25) in `docs/stories/v2-combat-003.5/followup-tasks.md`,
  `data/balance.json`, `tests/CombatBaselineTests.gd` and `tests/FlowFingerprintTests.gd`.
  ANSWERS.md #63 now holds a different, project-wide decision.

## 9. Cloud environment: Godot is not installed by default

**What:** the cloud container has no Godot. This session installed Godot 4.6.1 by hand into
`/usr/local/bin/godot`. AGENTS.md gives the macOS path `/opt/homebrew/bin/godot`.
**Action for Jeff:** add the install commands to the cloud environment's setup script, so every
new session can run tests.

## 10. Reduce Ase output across the economy

**What:** Jeff plans to reduce Ase output heavily, so that Ase becomes meaningful (2026-09-25,
with decisions.md D-15). Ase flows too much today. This story sets a small pace bonus (max 5% of
the stage base) but does not change any other Ase source (kill and survivor bonuses, stage base,
virtue bonus, scout return).
**Owner:** mid-game-designer, with Jeff deciding the values.

## 11. `movement_arbiter/avoid_overcommit_stays_proportionate` is red on purpose — NO ACTION

**Correction (2026-09-25):** an earlier version of this item suggested a Linux-only tie-break as
the cause. That was wrong. The test is red on purpose: the comment above it
(`tests/MovementArbitrationTests.gd:786`) cites V2-COMBAT-003.5 decisions #29 and #38 in
`docs/stories/v2-combat-003.5/decisions.md`. It fails on every platform, before and after this
story. No action for this story.

## 12. Two lookups for the stage base reward

**What:** `ActiveStageService.get_stage_base_reward()` finds the stage by its list position.
`FlowEncounterState` (around line 158-171) finds it by the stage's `index` field. Both exist from
before this story. They give the same stage while the stages keep their creation order. The pace
bonus avoids the risk with one captured value (decisions.md D-21). Unify the two lookups in a
separate change, following AGENTS.md "Never duplicate a helper".

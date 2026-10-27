# Phase 7 side question: what a forced retreat does

Author: sr-game-designer. Round 1 of a design round (game-feel agent reviews in round 2).
Status: PROPOSAL. Jeff decides. Every number is a PROPOSED DEFAULT for `mid-game-designer`.
Player text is marked PROPOSAL and follows the word rules (ANSWERS #86): no "home", no "stage";
say "path" and "Sanctum"; "lost" only for what is not carried.

Jeff's question: "Does the party return to the stage like a normal retreat, or because this is
forced do we count it as a death? How to handle this properly?"

Short answer: it is neither. It is not a death (nobody died and nobody chose). It is not a normal
retreat (nobody paid, nobody rolled). Call it a **standoff**: nobody would move, so the party
stepped back onto the path. The packs stay whole. The exit is NOT free, because the party does
not leave the path at all.

---

## 0. What the code does today (READ FROM CODE)

| Fact | Where |
|---|---|
| Trigger: `no_progress_streak >= 15` rounds. A round counts as progress if any damage was dealt OR the board reached a state this fight never had. | `CombatState.gd:352-356`, `FlowRuntime.gd:1640-1660`, `balance.json` `data.combat.stalemate.no_progress_round_limit` = 15 |
| Typical cause (config comment): both sides refuse (fear), guard, or otherwise land no hit. | `balance.json:1829` |
| Result: encounter dropped, ally fields cleared, `pending_scout_return_*` forced to 0, card built by `build_scout_return_snapshot(..., "forced_retreat")`, flow goes to RESOLVE. Button goes to the Sanctum. | `FlowRuntime.gd:1259-1278`, `VentureResolveSnapshotBuilder.gd:83,155-158` |
| No Ase cost, no pay, no `withdrawal` emotion modifier, no vow check, no pass mark, no turn used. | `FlowRuntime.gd:1241-1257` |
| The path is NOT closed: `party_state` is not set to `escaped`, the map stays locked, position and turn count are kept. A later entry resumes at the same cell with the fight still unresolved. | `FlowStageExploreState.gd:60-135` (the map is rebuilt as exploring, locked, same position) |
| Packs (`earnings` rows) are untouched. | `EarningsService.gd` (no call from `_resolve_forced_retreat`) |
| The `withdrawal` / `defeat` emotion modifiers are RECOVERY MULTIPLIERS for later Sanctum ticks (morale recovery x1.25; defeat: fear recovery x0.5). They change no fear or morale value now. | `EmotionConsequenceService.gd:259-268` |
| A chosen retreat (D-106): costs 10 Ase, one turn, puts the party back on the path. Normal fight marked passed and re-offered later (D-109). Objective fight stays open and is offered again at once. Settles nothing. | `FlowRuntime.gd:1166-1235`, `ActiveStageService.apply_retreat_return` (`:595`) |
| Defeat (D-115 option C): loses every unsettled pack row except the objective consolation. | `EarningsService.mark_lost` |

So today the forced retreat is a free Sanctum exit with the packs intact and the path still open.
That is "a free exit with no roll" (Jeff's words). It is also a dead-end card (all zeros).

## 1. What a forced retreat is: fiction and rules

Design pressure first: the cause is mostly an Echo-level event (fear, refusal, guarding), not a
player decision. The player can still shape it before the fight (party, directive). So the response
must be felt, but must not punish the player like a loss.

| Option | Fiction | Rule in one line | Verdict |
|---|---|---|---|
| **F1 Standoff (pick)** | Nobody would move first. The party stepped back. | An unchosen withdrawal to the path. Packs whole. One turn. No Ase. Fight stays open and comes back later. | Best fit. Not a death, not a payout, not a free exit. |
| F2 Free retreat | Same as a successful chosen retreat, without the 10 Ase. | Reuse the D-106 route exactly. | Rank 2. Simplest code. But the fight is offered again at once, so an identical stall can repeat with no change. |
| F3 Rout (count as defeat) | The party broke and ran. | Defeat rules: lose unsettled packs (D-115 C), defeat modifiers. | Reject. Nobody lost. Echoes froze, which is their interiority, not the player's failure. At Standing 1 it can wipe a whole path of earnings for a stall the player could not read. Also it would make a stall worse than a real loss of a fight the party was winning. |
| F4 Keep today's Sanctum exit | The party gives up. | Packs intact, path open, no roll. | Reject. It is a free exit that beats the roll (see section 4). |

"Count it as a death" has no meaning today: no death exists (D-66). When permadeath arrives, a
standoff must never kill an Echo. Write that into the permadeath story as a rule.

### Rules of the Standoff (state and transitions named)

1. ROUNDS -> `standoff` when the streak reaches the limit (reason string stays `no_progress_forced_retreat`; it is a log key, not player text).
2. `standoff` -> RESOLVE card "Standoff" with one button, "Back to the path" (see section 6).
3. Button -> STAGE_EXPLORE, same cell, turn count +1 (same call as a chosen retreat).
4. The fight: see section 4.
5. No Ase is spent, so the Ase denial (D-79) can never trap a poor player in a stall.

## 2. Where the party ends up

| Option | Rule | Verdict |
|---|---|---|
| **P1 Path only (pick)** | The card has one button, back to the path. The player can still go to the Sanctum from the path screen with the normal return home (escape check, then the settle roll). | Keeps one exit with one price (the roll). Minimal new rules. |
| P2 Path or Sanctum on the card | Two buttons. The Sanctum button runs the normal return home action (with its roll). | Rank 2. Helps a player whose Echoes are afraid, because the Sanctum is where fear recovers. Adds a decision on the card, but the same button already exists one screen later. Worth it only if feel review says the player does not find the exit. |
| P3 Sanctum with no roll | Today's behaviour. | Reject (free exit). |
| P4 Sanctum settled by the roll, no escape check | The stall acts as a leave. | Reject. The player did not choose to leave. It also lets a stall act as an exit with a better price than the real one. |

## 3. The packs (D-114 / D-115)

| Option | Rule | Effect after a won fight earlier on the same path | Verdict |
|---|---|---|---|
| **K1 Kept whole, party stays on the path (pick)** | Nothing settles, nothing is lost. The packs are exactly as before. | The earlier fight's 6 Ase is still in the packs. It is still at risk when the player later leaves by the roll, or banked when the path is cleared. The exit is not free because there is no exit. | Matches D-106 item 2 (a step back settles nothing). |
| K2 Settled by the roll | Same as an early leave. | The party is forced to gamble. | Reject. Only valid together with P4. |
| K3 All unsettled rows lost | Defeat rule. | Wipes a path of earnings for a stall. | Reject (F3). |
| K4 A small toll lost | For example a share of the unsettled rows. | Adds a penalty with no way for the player to see why. | Rank 3. If Jeff wants the standoff to sting, prefer a time cost (section 5) before a pack cost. A pack toll is hard to explain in words without a number. |

A stalled fight pays nothing: the fight row is written only when the fight is won
(`phase7-encounter-pay-design.md`, section 1.3), so no row is created. Nothing to remove.

Why this closes the exploit: the "free exit with packs intact" existed only because the old route
ended the visit at the Sanctum. With P1 the party never leaves the path, so a stall has no exit
value at all.

## 4. The fight and the situation

| Option | Rule | Verdict |
|---|---|---|
| S1 Offered again at once (as a chosen retreat does for an objective fight) | Same fight, same place, next screen. | Reject for a standoff. The combat is deterministic from the same inputs, so the same stall can repeat with no new input. This is the loop that `phase6-2-build.md` finding 3(a) warned about. |
| **S2 Open, offered later (pick)** | Normal fight AND objective fight both get the `retreat_pass_turn` marker (as D-109 gives a passed normal fight). Tier 4 of `find_explore_target` offers them again after the other targets. If it is the only target left, it still comes back (D-110 F2 fix). | The party must do something else first, which gives the player a reason and time to change the plan. No fight is lost for good. |
| S3 Passed for good (as `ignore_situation`) | Never offered again. | Reject. An objective fight would become unreachable, so the path could never be cleared. That is a soft-lock. |
| S4 A new saved state "standoff" on the situation | A flag plus a count. | Not needed as a rule. Keep one optional saved number, `standoff_count`, only to change the hint line and for the log. No new state in the fight model. |

The code needs one new switch on `apply_retreat_return`: "re-offer later, even for an objective
fight". That is a mechanics question (BLOCKED below).

### Soft-lock check and the passive-play exploit

- **A fight that stalls every time.** The party cannot clear the path with this setup. The valve is
  the existing return home (escape check, then the roll). The loop is not a hard lock: each pass
  costs a turn and shows a hint, and the player can leave. This is an honest result: the path asks
  for something this party cannot do yet.
- **Does it still stall after the step back?** Only if nothing changes. What can change: the party
  (summon, swap), the directive (Scout Carefully, Seek Signs and the rest), the Echoes' fear, or the
  turn the fight returns. See section 5 for the one fear option.
- **Forcing a stall on purpose.** Gain for the player: none in packs (no exit, no pay). A normal
  fight can already be skipped free with `ignore_situation`, so skipping is not a new gain. An objective
  fight stays open, so nothing is skipped. The only new gain is the small fear option in section 5,
  which has a cap.
- **UNVERIFIED:** whether the path has a turn limit. If it has none, the delay is free. Then the
  Standoff is a delay with a hint, and the decision is "change the plan or leave". I rate that
  acceptable for Standing 1 and 6. At Standing 9 it needs a re-check.

## 5. Costs

| Cost | Pick | Reason |
|---|---|---|
| Ase | None. | Not chosen. D-79 denial would trap poor players. |
| Turn | One turn (same as a chosen retreat). | A real, readable cost. Time passes on the path. |
| Fight pay | None. | Nothing was won. |
| Packs | Untouched (K1). | Section 3. |
| Withdrawal bonus | Not granted. | The bonus is a morale recovery multiplier for the Sanctum. The party did not withdraw by choice and did not survive a fight it chose. |
| Defeat modifier | Not applied. | Nobody lost. |
| Vow release (`check_vow_release_condition`) | Not called. | The path is not over. A chosen retreat calls it because the retreat ends the visit in the old design; here the party stays. |
| Thread (GDD 14.3) | Nothing now. | The path is not finished, so no segment is formed. Deferred option: a saved `standoff_count` per path that lowers segment quality at path end (GDD 14.3 says failures lower quality). Not recommended before a playtest shows stalls are common. |
| Fear / morale (direct) | See options. | The existing modifiers do nothing on the path (recovery multipliers only). |

Fear option (the stall is mostly fear refusal, so it should touch fear or it bypasses emotion):

| Option | Rule | Verdict |
|---|---|---|
| **E1 Ease the Echoes that froze (pick)** | A small one-time fear drop for each Echo that refused or held during the stall. First standoff of a given fight only. Magnitude PROPOSED DEFAULT: about half of the existing `fear_on_witness_refuse` (4) as a fall; `mid-game-designer` authors it. Fiction: stepping back lets them breathe. | Makes the next attempt able to differ. Honours interiority. Risk: farming by forcing stalls; the "first standoff per fight" cap and the turn cost limit it. Needs an out-of-combat fear delta API (BLOCKED). |
| E2 No emotional change | Fall back if E1 has no API. | Rank 2. Then the only change between attempts is the player's plan. |
| E3 A new `standoff` run modifier | Same pattern as `withdrawal` (recovery multiplier for the Sanctum ticks). | Rank 3. Does nothing until the Sanctum, so it adds config for no felt effect. |

## 6. What the player must see

Principles: no percent, no odds, no zero amounts, no ledger rows, no banner that says "nothing was
gained" (it hides that the packs are safe). Show that the packs are unchanged. The outcome is
carried by the card shape and one image line: the party steps back from a fight where nobody has
struck. The card reuses the retreat card shape (`retreat_return`, `can_reenter` false for "later").

Round 2 questions for game-feel: the pacing of the step back, a quiet (not failure) sound, a small
posture change on the Echoes that froze, and whether the card needs more than two lines.

PROPOSAL copy (Jeff chooses; none of it is approved):

| Element | Proposal A | Proposal B |
|---|---|---|
| Title | `Standoff` | `Nobody moved` |
| Body | `Neither side would strike. The party stepped back.` | `Nobody wanted to go first. The party backed off.` |
| Packs line | `Their packs are as they were.` | `Nothing in the packs changed.` |
| Open fight line (objective) | `The task is still there.` | `We are not done here.` |
| Repeat hint (second standoff on the same fight) | `It went the same way last time.` | `This is not working.` |
| Third and later (points at rest or a different party) | `Maybe they need rest.` | `Maybe try it another way.` |
| Button | `Back to the path` | `Continue` |

Notes: "Back to the path" is a plain label and follows ANSWERS #86. The packs line must not say
"lost" (nothing is lost). The repeat hints use the saved `standoff_count`. They do not name a cause,
because the game must not explain the simulation. An optional Echo line from the Echo that froze
(for example a bark in that Echo's voice) is an idea for the language story, not for this card.

Retire these strings: banner `Forced Retreat`, `The fight did not end. The party pulled back. Nothing
was gained.`, button `Return to Sanctum` on this card.

## 7. Code changes (list only)

| File | Change |
|---|---|
| `core/runtime/FlowRuntime.gd` `_resolve_forced_retreat` (`:1259`) | Read the objective index before teardown; call `ActiveStageService.apply_retreat_return` with the "re-offer later" switch; apply the fear option (E1); build the new card; stop forcing the `pending_scout_return_*` zeros (the standoff does not touch them); no `withdrawal`, no vow call. |
| `core/realms/ActiveStageService.gd` `apply_retreat_return` (`:595`) | New parameter: re-offer later for an objective fight (sets `retreat_pass_turn`, not `retreat_reoffer_id`). Optional `standoff_count` on the situation. |
| `core/state/flow/states/venture/VentureResolveSnapshotBuilder.gd` | `build_retreat_return_snapshot` gains an outcome (`standoff`) and the hint level; remove the `forced_retreat` branches in `build_scout_return_snapshot` (`:83`, `:155`). |
| `core/state/flow/PendingResultService.gd` (`:97`, `:163`) | Remove the `forced_retreat` run type, or leave it unused. Check that a reload on the card still works (chosen retreat card is the model). |
| `ui/screens/venture/ResolveScreen.gd` (`:224-226`, `:887-893`) | Remove the `forced_retreat` banner and branch; render the standoff variant of the retreat card. |
| `data/balance.json` | Fear option magnitude under `data.emotion` or `data.combat.stalemate` (PROPOSED DEFAULT). `no_progress_round_limit` stays 15. |
| Out-of-combat fear delta | Possible new method on `EmotionConsequenceService` (E1). |

Tests and recorded values that move (list only):

- `tests/RetreatTests.gd` `retreat/forced_retreat_still_ends_at_sanctum` (`:442`): rewrite to pin the new route (back to the path, one turn, packs unchanged, fight open and offered later, no Ase change).
- `tests/CombatRoundtripIntegrationTests.gd` `no_progress_stalemate_ends_as_forced_retreat` and `forced_retreat_grants_nothing` (`:578`, `:617`): `run_type` and destination change.
- `tests/EconomyCharacterizationTests.gd` (`:1293`, `forced_retreat carries rows`): the producer branch is removed.
- `tests/ResolvePayoutUITests.gd` (`:774`): the `forced_retreat` card.
- `tests/CombatStateTests.gd` (`:353`, `:372`): unchanged (the reason string stays).
- New tests: packs unchanged after a standoff (including a won fight earlier on the path); objective fight returns later; fight is not lost for good when it is the only target; `standoff_count` hint level; no card amounts.
- Recorded values: no `combat_baseline` value should move, because the trigger and the combat sim do not change. UNVERIFIED: I did not search the baselines for a stalemate fixture. Docs: `phase6-2-build.md` finding 3 and follow-up 46 close; D-106 item 2 gets an addendum; CONVENTIONS.md and `docs/integration-map.md` rows for the forced retreat.

## 8. GDD conflicts and gaps (list; the GDD is not edited)

1. The GDD has no stalemate or standoff concept (grep of the Working GDD finds none). The term "forced retreat" exists only in code. A new GDD line is needed if Jeff accepts "standoff".
2. GDD 20.10 lists "morale collapse leading to forced withdrawal" as an acceptable early failure. A stalemate is not a morale collapse. The two should stay separate. No conflict if the standoff is not called "forced withdrawal". Name this in the GDD note.
3. GDD 20.10: "the minimum useful failed run should still return intel, revealed objective requirements, objective location." The old card returned zero intel. The standoff keeps the party on the path where the intel already sits, so it satisfies the line. No conflict.
4. GDD 14.3: failures and collapse should lower segment quality. The standoff does nothing to the Thread yet. This is a gap, deferred on purpose (section 5).
5. GDD "Death, withdrawal, and loss" (permadeath is core, with a death ripple): the standoff must NOT trigger the ripple. The GDD conflict is only with D-66 (no permadeath yet), which already exists. Record the rule for the permadeath story.
6. D-106 item 3 uses "Back to the stage" and "retreat returns to the stage map". Word rules (ANSWERS #86) replace it with "path". This design uses "path".

## 9. Research (comparable games)

Most sources are forum or fan wiki posts. I found no official rules unless said. Mark UNVERIFIED where noted.

| Game | Finding | Source |
|---|---|---|
| XCOM 2 | Evacuating early from a supply raid forfeits the loot; a soldier not evacuated at a turn limit is captured; a captured soldier can be rescued later. Player reports. UNVERIFIED (no Firaxis text). | steamcommunity.com/app/268500 threads; xcom.fandom.com Council Missions (XCOM 2) |
| XCOM: Chimera Squad | Some missions offer a penalty-free Evacuate; an agent cannot die permanently in the field (the mission fails or restarts instead). UNVERIFIED for aborted-mission rewards. | gamespot.com "XCOM: Chimera Squad Removes Permadeath..." ; ufopaedia.org Agents (Chimera) |
| Gears Tactics | No retreat or stalemate timer found. Some missions use turn limits (one with 15 turns); a hero's death fails the mission. | primagames.com mission types; segmentnext.com Act 3 Ch.5 |
| Battle Brothers | Nothing found on loot or wounded on a retreat. A surrender mid-fight cost heavy wounds and money (one player). Morale breaks make troops flee on their own. UNVERIFIED. | forums.operationsports.com t-92741; store.steampowered.com/app/365360 |
| Darkest Dungeon | Retreat from an unfinished quest keeps the loot you carry; heroes get a stress penalty. One fan wiki says a random hero dies; other sources do not. Conflict between sources. UNVERIFIED. | twinfinite.net (white flag guide); darkestdungeon.fandom.com; steamcommunity.com/app/262060 |
| Wartales | Enemy leaders fleeing cost the best drops (loot table, not loot amount). Nothing found on your own party retreating. UNVERIFIED. | steamcommunity.com/app/1527950 threads |
| Fire Emblem | Gaiden battles with a turn limit end by themselves when the limit runs out (the Let's Play author says it can favour the player). Three Houses: 99-turn hard cap ends in a loss. Echoes: Retreat is only available after three turns. | lparchive.org Fire Emblem Gaiden Update 32; fireemblemwiki.org/wiki/Turn; twinfinite.net (Echoes retreat) |
| Mario+Rabbids | Kingdom Battle: nothing found. Sparks of Hope: Flee to Planet returns to the pre-fight spot with no penalty. | twinfinite.net (Sparks of Hope exit) |
| Into the Breach | Nothing found on aborting a mission. Unspent reputation is lost between islands. UNVERIFIED for abort. | gamepressure.com beginner guide |
| Disco-style "dig in" stalemates | No source found. UNVERIFIED. | none |

Lessons I take from this (my reading, not facts):

1. Games that let a squad leave an unfinished task usually keep what is already carried and charge in a different currency: stress (Darkest Dungeon), a lost mission reward (XCOM 2), time. That supports K1 plus a time cost.
2. Games with a turn limit end the stall by rule, not by punishing the player (Fire Emblem Gaiden). The standoff does the same: it ends the stall and does not count a loss.
3. Where the retreat is unavoidable, games soften the penalty when a soldier cannot be lost (Chimera Squad). Echoes cannot be lost yet (D-66).

## Pressure check (answers on record)

| Question | Answer |
|---|---|
| Legible without a number? | Yes. The card says nobody moved and the packs are as they were. |
| Survives a player who never reads it? | Yes. One tap returns to the path. Nothing is lost. The cost is a turn. |
| Decision or delay? | A decision only if the hint reads. The player chooses: change the party or plan, do other targets, or leave by the roll. Otherwise a delay with a turn cost (see the UNVERIFIED turn limit). |
| Interacts with fear and emotion? | Yes, through E1. Without E1 it bypasses them. |
| Standing 1 | Stalls are likely more frequent when fear refusal fires. UNVERIFIED (I did not check band thresholds for Standing 1). Gentle cost: no Ase, no pack loss. |
| Standing 6 | The player has more levers (directives, callings). The hint should point at them. |
| Standing 9 | Stalls come from guards and positions more than fear. A free delay may be too cheap. Re-check with a playtest. |

## Deferrals

- Dying or injury on a stall: the permadeath story (D-66, D-108).
- The Thread / segment quality link (GDD 14.3): a later story, after a playtest counts how often stalls happen.
- Fixing the cause of stalls (combat AI, guard behaviour): not a design question here.
- An Echo bark for the Echo that froze: the language story.
- "Set aside this objective" (a hard soft-lock valve): only if a playtest shows a stall that no change can break.
- Other encounter kinds' stalls (shrine, spirit): they use the same trigger; no extra rule here.

## OPEN — questions and assumptions
ASSUMED: The player has a way to leave the path from the path screen at any time (return home with escape check and settle roll) | WHY: `handle_return_home` exists in `VentureController.gd:324` and the old card pointed to the Sanctum | WRONG IF: a fight in progress or a locked state blocks the return home button after a standoff
ASSUMED: A rerun of the same stalled fight with unchanged inputs stalls again | WHY: D-109 notes the same `encounter_id` gives the same terrain and spawn, and combat is deterministic | WRONG IF: the combat seed includes the turn count or a counter, so a rerun differs on its own (then S1 would be fine)
ASSUMED: Tier 4 of `find_explore_target` can re-offer an unresolved OBJECTIVE fight that carries `retreat_pass_turn` (D-109 says "as for passed objectives") | WHY: D-109 and the D-110 F2 fix describe it | WRONG IF: `retreat_pass_turn` is read only for non-objective situations
ASSUMED: Fear refusal is the usual cause of a stall | WHY: `balance.json:1829` comment (both sides refuse) and the reported bug | WRONG IF: logs show most stalls come from guard behaviour or positions
BLOCKED: Is there an out-of-combat API to lower an Echo's fear by a fixed amount (needed by E1)? | CHECKED: `EmotionConsequenceService.apply_run_emotion_modifiers` only sets recovery multipliers | NEED: `mechanics-developer`
BLOCKED: Does the path have a turn limit, and what happens when it ends? | CHECKED: `ActiveStageService.apply_retreat_return` increments `turn_count`; no limit seen in the files I read | NEED: `mechanics-developer`
BLOCKED: Is the stalled fight deterministic when rerun with unchanged inputs? | CHECKED: D-109 note on `encounter_id` | NEED: `mechanics-developer` (one probe)
BLOCKED: Jeff's decision on the Standoff name and the card copy (section 6) | CHECKED: word rules ANSWERS #86, D-107, D-111 | NEED: Jeff
BLOCKED: Jeff's pick between P1 (path only) and P2 (path or Sanctum on the card) | CHECKED: phase6-2-build.md finding 3, follow-up 46 | NEED: Jeff
BLOCKED: Does the stale pending-result record for `forced_retreat` survive a reload on the card? | CHECKED: `PendingResultService.gd:97,163` names the run type | NEED: `mechanics-developer`

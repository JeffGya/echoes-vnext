# Combat visual and UI inventory

Inventory and suggested treatments for Jeffrey's visual brief — 10 October 2026. Retain the prototype token style. Suggestions are proposals for review, not an approved visual design or implementation specification.

Review sequence: Shared Actions is done for this mockup review, using the restored rigid-line iteration. Move is mostly current; Skills is deferred. The [Feel mockup](combat-feel-mockup.html) covers FEEL-01–18 for the next review, including explicit reuse/skip decisions and changed-versus-unchanged comparisons.

Initial research and proposals used the `sr-game-artist`, `ui-ux-designer`, and `game-feel-developer` archetypes on Luna, plus source review by the parent agent. Shared-action visual direction and affected reuse descriptions were subsequently revised by the Sol `sr-game-artist` from Jeffrey’s review of the HTML mockup. No simulation, UI, balance, canon, or backlog changes were made. Verification is static source tracing; the game was not launched for this inventory.

## Reading the status

- **Current:** present in the main checkout at `58f295d`, including its existing local changes. A simulation effect can be current while its visual treatment is missing.
- **Reference:** present in the supplied mockup's worktree, whose checked-out commit is `d5dc190` and which also has local changes. This does not establish integration into the main checkout.
- **Partial:** authored or selectable, but some effect, feedback, or runtime wiring is missing.
- **Mockup:** illustrated by the supplied HTML; does not establish that the game implements it.
- **Future:** canon/design requirement without a current player-facing production surface found in these checkouts.

Main source paths below are relative to the repository. **W/** means `.claude/worktrees/section-7-5-unused-capacity-882fe1/`. All short names in this document are inventory labels for discussion, not approved player-facing copy.

## Reading the suggestions

The last column holds short animation/UI proposals. Actor and movement columns remain empty for Jeffrey's direction. **Reuse** means use the referenced treatment without adding another cue; **Skip** means no separate treatment is recommended, with the reason stated. **Future only** proposals depend on the corresponding mechanic and player-facing surface existing; the status column always describes the present implementation.

The initial suggestion set was cross-reviewed by all three agents. Jeffrey’s later shared-action feedback supersedes the original conservative motion, normal-Guard and Mark/Reveal lifetime proposals; these Sol revisions are not a claim of renewed joint-agent approval. Each proposal remains at most two sentences, and repeated features reuse one treatment.

Keep the active actor, its subject and the outcome as the main focus. Use expressive anticipation, commitment and weighted settling, grounded in the inspected storybook concept art’s warm ink, cloth rhythm and material shapes, without turning every event into a simultaneous effect. Normal omnidirectional Guard uses an above-token shield; directional stop-short Guard, full Hold, dashed Observe, active-turn ring and spirit nimbus remain distinct. Damage leaves the actor in red and exposed HP recovery draws inward in green; the above-token bar and existing Echo card share the same resolved value. Near-death emphasis does not repeat on confirmed death. At fast playback, keep contact and outcome readable; reduced motion settles to static results, and presentation never changes simulation outcomes.

An emotion “chip” means the existing initiative emotion label or its proposed compact replacement: its actual change uses a brief lift, bold text and strong contrast, never a second status. Combine support outcomes into one source commitment and one update per changed recipient; unchanged ticks get no effect. Mark holds its bracket while the exposed state matters to others, whereas Reveal uses that same bracket briefly at action completion; overlapping flags never stack outlines. Proposed entrances bring Echoes, enemies and joined allies from a board edge with a fading step, while objective spirit and structures fade in place; production spawn routing remains unresolved and unchanged. The standalone [shared-action mockup](combat-shared-actions-mockup.html) includes an explicitly illustrative person-recovery feedback study, not a newly discovered healing skill.

## 1. Actors and objects

Every relevant action below must be considered for the appropriate actor class. Do not apply Echo personality, barks, movement, or death treatment to a stationary shrine simply because it shares the actor dictionary.

| ID | Actor / object | Variants to cover | Status | Animation / UI description |
|---|---|---|---|---|
| ACT-01 | Party Echo | Uncalled and called; name/initials; health; alive, guarding, dead/inactive; active turn | Current |  |
| ACT-02 | Calling identity | Okofor, Onyamesu, Aduro, Sum-Okwanfo, Okomfo, Kra-Soro; higher Standing expressions; differences in tendencies rather than exclusive actions | Current |  |
| ACT-03 | Temporary allied NPC | Joined from a contact; ally ring; reduced damage; active/dead; distinct from permanent party member | Current |  |
| ACT-04 | Enemy | All ordinary enemy types; active turn, injury, guard, refusal, movement, damage, death | Current |  |
| ACT-05 | Dust Wanderer | Authored enemy template and production group spawns | Current |  |
| ACT-06 | Dust Sentinel | Authored enemy template and production group spawns | Current |  |
| ACT-07 | Vale Brute | Heavy enemy template; do not infer a separate attack animation from its tag | Current |  |
| ACT-08 | Ashen Revenant | Authored as ranged in content; current attack resolution remains melee | Current / partial content promise |  |
| ACT-09 | Ashen Wraith | Fast enemy template; speed/stat distinction does not establish a separate run animation | Current |  |
| ACT-10 | Hollow Golem | Heavy/boss-tagged enemy template; current shared combat grammar | Current |  |
| ACT-11 | Guardian | Fallback encounter enemy; keep distinct from the six authored group templates | Current fallback |  |
| ACT-12 | Pursuit quarry | Fleeing target; gold diamond; contained, fleeing, escaping, defeated | Current |  |
| ACT-13 | Guided spirit — noncombatant | Named spirit with gold halo; stationary protect variant or escort movement; fear, HP, safety, death | Current |  |
| ACT-14 | Guided spirit — combatant | Escort variant may join battle; halo plus combatant token; reduced damage; continues objective role | Current |  |
| ACT-15 | Shrine | Ancestral Shrine runtime objective; stationary, targeted, damaged, purification stacks, restored, destroyed | Current |  |
| ACT-16 | Relic | Severed Relic runtime objective; stationary/invulnerable; held/unheld; holder loss/replacement; no ordinary HP bar | Current |  |
| ACT-17 | Protected entity / totem | The Charge runtime structure; HP; guarded, unguarded, stolen, recovered, destroyed | Current |  |
| ACT-18 | Corrupted Shrine template | `structure.corrupted_shrine` in actors.json; do not substitute its description for the runtime shrine rules | Authored; runtime uses balance definition |  |
| ACT-19 | Ancient Totem template | `structure.ancient_totem` in actors.json; carryable description exceeds the live round-based theft surface | Authored; richer custody partial |  |
| ACT-20 | Lost Wanderer template | `spirit.lost_wanderer` content; runtime spirit gets a generated name/configuration | Authored; runtime uses objective spawn path |  |
| ACT-21 | Reinforcement / wave arrival | RECOVER reinforcements and ENDURE waves; newly spawned enemies use the same actor/token pipeline | Current |  |
| ACT-22 | Battlefield terrain / hazard | Floor, bridge, void, obstacle footprint, hazard region; these are board data, not automatically actor tokens | Current terrain; hazard presentation gap |  |
| ACT-23 | Fragment Wound | Actual Keeper introduction opponent; shared combat grammar in the introductory trial | Current |  |
| ACT-24 | Shadow | Balance enemy type exists; no normal production spawn confirmed by this scan | Authored type; not a confirmed current roster entry |  |

Sources: `data/actors.json`; `data/balance.json:313` (enemy types), `:398` (runtime structures); `core/combat/EncounterSetupService.gd:261`; `core/combat/EncounterObjectiveSpawnService.gd:135`, `:204`; `core/combat/CombatRoundSpawnService.gd:180`; `ui/screens/combat/CombatTokenLayer.gd:11`; `core/onboarding/KeeperIntroService.gd:294`.

## 2. Shared actions and actor states

| ID | Feature to brief | Applies to / distinction | Status | Animation / UI description |
|---|---|---|---|---|
| ACTION-01 | Appearing / entering combat | Party, enemies, ally, spirit and structures at setup; separate from later reinforcements | Current state; dedicated entrance animation not found | Proposed presentation: Echoes, enemies and joined allies fade and step into the board from its edge, while objective spirits and structures fade in place. Keep actual arrival timing and location authoritative; an edge entrance route is not evidence of a changed production spawn contract. |
| ACTION-02 | Waiting for a turn | Living combatants between activations | Current state | Keep waiting actors visually still; the synchronized active-turn ring and initiative-row cue identify whose turn it is. Avoid idle loops across the board. |
| ACTION-03 | Active turn / ready to act | Current actor ring and initiative highlight | Current | Synchronize the existing active ring and initiative-row highlight as one current-actor cue. Keep it limited to the acting token and distinct from Guard, Hold, Observe, ally, or spirit marks. |
| ACTION-04 | Thinking / deliberating | User-requested visual beat; no dedicated `think` simulation action found | Visual brief item, not a separate current mechanic | If deliberation is shown, keep the ACTION-03 ring steady while the chosen action resolves; do not add a thinking icon or simulated mechanic. |
| ACTION-05 | Idle / choosing not to act | `actor.idle`; distinguish purposeful stillness, fallback, and unavailable action | Current | Leave an idle actor's flat token settled. Use only the existing reason/bark when the simulation supplies one; no looping pose or persistent idle badge. |
| ACTION-06 | Melee attack | Attacker, intended target, contact, damage result; Echo/enemy/eligible ally/spirit | Current | Give the attacker an expressive wind-up, adjacent contact and weighted follow-through; keep the intended subject clear. ACTION-08/09 owns the resulting hit, HP and card feedback, with route cues only when movement actually occurs. |
| ACTION-07 | Follow-up pressure / Press | `actor.press`; distinct candidate from normal melee; missing dedicated damage resolution | Partial | Skip for now: Press has no dedicated damage resolution, so a follow-up strike animation would depict an unimplemented effect. |
| ACTION-08 | Receiving a hit | Victim feedback, HP change, fear gain; also structures when targeted | Current effect; limited token feedback | After contact, recoil the combatant, send a red signed HP loss outward and mirror that same loss with a brief red response on its existing card; update a changed emotion chip afterward. Keep structures stationary with surface fractures, and use green inward signed feedback for exposed HP recovery without implying a new healing action. |
| ACTION-09 | Zero-damage hit | Guard/defence may leave HP unchanged; distinguish contact from successful damage | Current | Show committed contact and leave HP unchanged; when Guard caused the result, let the normal Guard shield catch the hit. Keep block and damage distinct, with no red loss when the resolved delta is zero. |
| ACTION-10 | Guard | `actor.guard`, defensive state, reduced incoming damage, expire/reset | Current | Show normal omnidirectional Guard as a shield above the actor, with expressive entry and clearing at the round boundary. Keep it distinct from the directional stop-short Guard half arc (MOVE-25), full Hold ring (MOVE-26), dashed Observe ring (MOVE-27), active-turn ring and spirit halo. |
| ACTION-11 | Guard absorbs a hit | Guarded actor survives damage; associated morale response | Current | At contact, push the held shield farther than the actor in the same direction away from the attacker and briefly crack its surface. ACTION-08 owns reduced damage and its matching card response; the shield returns intact without implying Guard was consumed or permanently broken. |
| ACTION-12 | Protect an ally | `protect_ally`; movement/proximity purpose; do not equate it with granting Guard | Current movement; direct resolver is a stub | Skip for now: the direct protection resolver is a stub. Represent only any actual movement/proximity using the existing MOVE cues; do not imply Guard or damage interception. |
| ACTION-13 | Interpose | `actor.interpose` grants Guard to an ally and morale to the interposer | Current skill effect | Let the interposer wind up and commit under the current action cue, then raise the recipient shield under ACTION-10. Emphasize the source emotion chip only if its displayed status changes, with no persistent link or extra ring. |
| ACTION-14 | Hold Ground | `actor.hold_ground` supports nearby morale; separate from stop-short Hold | Current skill effect | After the source action resolves, give nearby affected allies a bold, brief lift and contrast change in their existing emotion chip only where displayed status changes. Do not borrow the stop-short Hold ring (MOVE-26) or draw a persistent radius. |
| ACTION-15 | Steady Call | Nearby fear relief; one use per combat | Current skill effect | Let the caller commit under its current action cue, then boldly emphasize affected existing emotion chips only where projected status changes. Keep the response event-bound with no lasting area marker or raw fear display. |
| ACTION-16 | Mark a target | `actor.mark`; source/target relationship and temporary mark | Current simulation; weak/missing main token feedback | Use one shared target-attention bracket that persists for the exposed Mark state, because it remains relevant to subsequent Echoes; optionally keep its source in compact detail. Do not stack a second outline when Reveal also applies or compete with the active-turn ring. |
| ACTION-17 | Reveal a target | `actor.reveal`; temporary revealed flag increases Echo melee scoring; do not imply implemented stealth removal | Current scoring effect; main visual feedback absent | Reuse the shared target-attention bracket briefly for the Reveal action, then remove that event cue when the action completes, retaining any valid Mark bracket. This does not depict concealment removal or imply that the underlying scoring flag expired with its presentation cue. |
| ACTION-18 | Read the field | `actor.read_field`; streak/cooldown; do not imply a full battlefield-reveal effect | Current candidate/state; broader effect partial | Skip for now: the broader field-read/reveal effect is not established. If streak or cooldown detail is exposed in compact UI, keep it there; do not animate a battlefield scan. |
| ACTION-19 | Refuse through fear | `actor.refuse`; fearful living combatant cannot act | Current; distinct from guidance Refuse | Give the living actor a quick tremor or small backward flinch, then one supplied fear-refusal bark alongside its existing emotion presentation. Keep this distinct from guidance Refuse and settle afterward without implying stun, death or collapse. |
| ACTION-20 | Diverge from broad intent | Echo chooses differently; reason/bark and observable action | Current decision/explanation | Let the actual chosen action carry the emphasis; show a supplied divergence reason only after that action resolves, never as a command label. |
| ACTION-21 | Purify shrine | Reach shrine, perform purification, stack progress, tick restoration | Current | Show the named purifier wind up and commit, then carry a brief warm ink-like flow from that actor into the stationary shrine before its confirmed progress and restoration resolve. Reuse the green inward signed HP gain for exposed restoration and structure-specific surface damage or destruction, with no bodily recoil or new healing skill. |
| ACTION-22 | Kill / defeat another actor | Attacker result, victim death, nearby emotional consequences | Current | Use ACTION-06 contact, ACTION-08 red loss and ACTION-24 death as one expressive defeat sequence; FEEL-06 owns only confirmed recipient status changes afterward. Add no second kill flash, screen shake or repeated low-HP glow. |
| ACTION-23 | Near death | Low HP first crossing, fear/morale response, urgent vulnerability | Current | At the first low-health crossing, strongly emphasize the existing above-token HP bar and mirror the actual damage on its card. A changed emotion chip follows afterward; do not repeat the low-HP emphasis on confirmed death or add a permanent badge. |
| ACTION-24 | Death / inactive actor | Combat projection uses dead/guarding/alive, with no separate downed state; distinguish combat death from persistent Echo loss rules | Current | On confirmed person death, dim that circle while retaining identity and cell, remove dead eligibility and keep focus on the living current actor; do not repeat the near-death HP emphasis. Structures fracture in place under OBJ-02/04 and never receive a downed pose or bodily collapse. |
| ACTION-25 | Death of an ally / bond partner | Witness fear/morale change and possible bark; stronger personal meaning for Echoes | Current | Mirror any exposed ally or partner HP loss with the shared brief red card response; on death, show only confirmed witness emotion changes and supplied barks. Keep focus on the surviving active actor without a global death flash or relationship link. |
| ACTION-26 | Last Echo standing | Behaviour/refusal threshold and last-stand bark | Current | On the actual last-Echo-standing trigger, reuse the active turn ring and supplied last-stand bark/reason; do not add a permanent badge or imply a new combat stance. |
| ACTION-27 | Invalidated action / fallback | Intended target/path no longer valid; bounded fallback or idle | Current | Resolve a stale route/target cue cleanly, then show only the actual fallback or idle outcome and its supplied reason. Avoid an error icon unless the game already exposes one. |

Sources: `core/actors/ActorStateMachine.gd:121`, `:1220`; `core/actors/behaviors/BehaviorArbiter.gd:1525`, `:1688`; `core/combat/CombatTurnActionService.gd:115`; `core/combat/CombatService.gd:44`; `core/movement/CombatActivationService.gd:64`; `ui/screens/combat/CombatBoardScreen.gd:959`.

## 3. Movement

| ID | Feature to brief | Distinction | Status | Animation / UI description |
|---|---|---|---|---|
| MOVE-01 | Start moving | Move telegraph before token leaves its cell | Current |  |
| MOVE-02 | Walk / ordinary traversal | Token follows committed waypoints, not just destination interpolation | Current |  |
| MOVE-03 | Run / urgent traversal | No distinct walk/run action or gait animation found; user can describe an intended visual variant | Visual brief item |  |
| MOVE-04 | Arrive / settle / stop | End movement; only then communicate an outcome that belongs after landing | Current; richer stop settling Reference |  |
| MOVE-05 | Advance / engage | Close distance; movement and adjacent attack are distinct parts of an activation | Current |  |
| MOVE-06 | Pursue / cut off | Quarry chase and interception of a route | Current |  |
| MOVE-07 | Protect / escort / screen | Stay relevant to ally or objective; spirit escort proximity | Current |  |
| MOVE-08 | Reposition / regroup | Change position without implying an attack | Current |  |
| MOVE-09 | Withdraw / flee | Actor-level disengagement; separate from whole-party retreat | Current |  |
| MOVE-10 | Direct route | Route shape | Current |  |
| MOVE-11 | Safe / careful route | Hazard/exposure-aware route; not a slow gait by definition | Current; named expressive style Reference |  |
| MOVE-12 | Conservative / restrained route | Lower commitment | Current; named expressive style Reference |  |
| MOVE-13 | Cohesive route | Stay near allies | Current |  |
| MOVE-14 | Lateral route | Sideways approach | Current |  |
| MOVE-15 | Screen route | Protect/escort route shape | Current |  |
| MOVE-16 | Intercepting route | Intercept route shape | Current |  |
| MOVE-17 | Forceful route | Expressive movement style | Reference |  |
| MOVE-18 | Low-exposure route | Expressive movement style | Reference |  |
| MOVE-19 | Retreating route | Expressive movement style | Reference |  |
| MOVE-20 | Overcommitted route | Expressive movement style | Reference |  |
| MOVE-21 | Capacity / shortened traversal | Reach, capacity, terrain and obstruction affect where a move ends | Current |  |
| MOVE-22 | Replan / blocked path / no valid cell | Avoid presenting a deliberate stance as a navigation failure | Current |  |
| MOVE-23 | Forced displacement | Unstable Ground; displaced cell, interrupted route, fallback damage | Current resolver; production visual gap |  |
| MOVE-24 | Binding stop | Binding Growth interrupts traversal | Current resolver; production visual gap |  |
| MOVE-25 | Stop short — Guard / Braces | Echo deliberately stops before full route; Guard benefit | Reference PR1 |  |
| MOVE-26 | Stop short — Hold / Holds | Remain near allies; same defence action as Guard but different benefit/read | Reference PR1 |  |
| MOVE-27 | Stop short — Observe / Watches | Watch a hostile; dashed stance and subject relation | Reference PR1 |  |
| MOVE-28 | Stop-short cause / reason | Fear or identity cause; badge, compact chip/bark after settlement | Reference PR1 |  |
| MOVE-29 | Hold links | Ally tie, knot, attachment/retraction | Mockup PR2; confirmation still open in supplied page |  |
| MOVE-30 | Return-to-safer-ground hint | Faded floor dashes and open chevron toward return cell | Mockup PR2 |  |

Sources: `core/movement/contracts/MovementGoal.gd`; `core/movement/MovementOptionService.gd`; `core/movement/MovementExecutor.gd`; `core/movement/MovementHazardService.gd`; `ui/screens/combat/CombatTokenPresentationState.gd:39`; **W/**`core/actors/behaviors/MovementStyleService.gd:26`; **W/**`core/actors/behaviors/StopShortService.gd:11`; **W/**`ui/screens/combat/CombatStopShortMotion.gd`; supplied V54 HTML.

The supplied V54 page explicitly removes dotted remainder, end cap, and end diamond, and uses reason-after-landing timing. Its slow/normal/fast controls and three-second demonstration rest are reference-player behaviour, not new combat rules.

## 4. Authored skills — all 14 definitions

These skill names are readable forms of existing IDs. Equipped skills are selected autonomously; this list does not imply a player command bar. There is currently one equipped slot. Family is separate from Calling identity.

| ID | Authored skill key / readable name | Family | Actual surface / limitation | Animation / UI description |
|---|---|---|---|---|
| SKILL-01 | `blade_resolve` — Blade Resolve | Break | `actor.press` candidate; authored follow-up strike has no dedicated damage resolution | Skip for now: Blade Resolve's authored follow-up maps to Press, whose dedicated damage resolution is missing; do not animate a second strike. |
| SKILL-02 | `warders_vigil` — Warder's Vigil | Ward | Interpose; grant Guard to ally; interposer morale | Reuse ACTION-13 for expressive Interpose and ACTION-10 for the recipient’s above-token Guard shield, distinct from the directional stop-short arc. Emphasize the interposer’s existing chip only when its displayed emotion changes. |
| SKILL-03 | `stewards_ground` — Steward's Ground | Ward | Hold Ground; nearby ally morale; not a new collision/control zone | Reuse ACTION-14’s bold, brief nearby emotion-chip change only where a displayed status changes. Do not use the stop-short Hold ring (MOVE-26), since this skill does not create that stance. |
| SKILL-04 | `stewards_call` — Steward's Call | Root | Steady Call; nearby fear relief; once per combat | Reuse ACTION-15’s caller commitment and bold recipient-chip response only where an eligible ally’s displayed emotion changes. Leave no persistent area marker. |
| SKILL-05 | `rangers_mark` — Ranger's Mark | Path | Mark target; temporary state boosts Echo melee scoring; feedback incomplete in main | Reuse ACTION-16’s single bracket while the exposed Mark state remains relevant to subsequent Echoes. Add no separate source-to-target graphic, and keep its persistence distinct from Reveal’s brief event cue. |
| SKILL-06 | `rangers_withdraw` — Ranger's Withdraw | Veil | Withdraw candidate; cooldown; movement/action distinction needs attention | If the withdraw candidate actually commits, reuse ordinary MOVE-09; do not imply teleport or a special pose. Show cooldown only if it is exposed on an existing player-facing surface. |
| SKILL-07 | `seers_sight` — Seer's Sight | Rite | Read Field candidate and streak/cooldown state; full reveal/read effect not established | Skip for now: the full Read Field effect is not established; do not add a scan pulse or battlefield reveal. If streak or cooldown detail is exposed in compact UI, keep it there. |
| SKILL-08 | `seers_reveal` — Seer's Reveal | Rite | Temporary revealed flag boosts Echo melee scoring; once per combat; no implemented concealment system found | Reuse ACTION-17’s brief Reveal bracket and remove that cue on action completion without implying the scoring flag has expired. Preserve any valid Mark bracket and do not depict concealment removal or a hidden target. |
| SKILL-09 | `okofor_steadfast_hold` — Steadfast Hold | Ward | Authored passive maps to idle; no distinct skill effect dispatch found | Skip for now: the authored passive currently maps to idle and has no distinct skill-effect dispatch. |
| SKILL-10 | `aduro_iron_momentum` — Iron Momentum | Break | Authored passive maps to idle; separate from innate Calling momentum | Skip for now: the authored passive currently maps to idle; do not borrow the separate innate Calling momentum effect. |
| SKILL-11 | `sum_okwanfo_shadow_step` — Shadow Step | Veil | Authored utility maps to idle; not a teleport or stealth animation requirement yet | Skip for now: the authored utility currently maps to idle; no teleport or stealth effect is wired. |
| SKILL-12 | `kra_soro_open_ground` — Open Ground | Path | Equipped skill adds movement capacity; authored action itself maps to idle | Skip for now: the authored action maps to idle; when its movement-capacity bonus changes a legal route, show only the ordinary MOVE telegraph and destination. |
| SKILL-13 | `okomfo_spirit_sight` — Spirit Sight | Rite | Authored passive maps to idle; not evidence of a new reveal effect | Skip for now: the authored passive currently maps to idle and does not establish a new reveal effect. |
| SKILL-14 | `onyamesu_steadfast_care` — Steadfast Care | Root | Authored passive maps to idle; not evidence of healing | Skip for now: the authored passive currently maps to idle and does not establish healing. |

Also brief **equipped / unequipped**, **available / unavailable**, **cooldown / ready**, **used once / still available**, and **effect start / effect expiry** where the current skill supports those distinctions. No separate healing, resurrection, projectile attack, teleport, or area-damage action was established by this scan.

Sources: `data/balance.json:2291`, `:2377`; `core/progression/SkillDefinition.gd:26`; `core/progression/SkillLoadoutService.gd`; `core/actors/behaviors/BehaviorArbiter.gd:1688`; `core/actors/ActorStateMachine.gd:1220`; `core/movement/MovementProfileService.gd:50`; `core/combat/CombatTurnActionService.gd:160`.

## 5. Emotion, identity and support

| ID | Feature to brief | State / relationship to show | Status | Animation / UI description |
|---|---|---|---|---|
| FEEL-01 | Emotion status | Radiant, Whole, Grounded, Uncertain, Hesitant, Burdened, Pressed, Strained, Fraying, Hollow | Current UI vocabulary | On a meaningful projected emotion change, flash the existing chip in that emotion's shared Sanctum colour with a short lift, contrasting bold state text, then settle it. Keep one status per actor and no persistent emotion halo. |
| FEEL-02 | Morale tier | Inspired, Steady, Shaken, Broken; separate axis from ten emotion statuses | Current | Skip a separate morale chip; preserve the ten-state emotion chip, and use FEEL-01 only when its projected status changes. |
| FEEL-03 | Fear | Accumulation, relief, persistent floor, refusal threshold | Current | For a projected emotion change caused by fear, reuse FEEL-01’s bold shared chip response; actual refusal additionally uses ACTION-19’s quick flinch and supplied bark. Do not add a fear meter. |
| FEEL-04 | Fear gain from hit / nearby threat | Changed actor and cause | Current | After contact, recoil and the signed HP/card result, reuse FEEL-01’s bold chip response only if the projected emotion status changes. Add no separate fear popup or danger aura. |
| FEEL-05 | Pressure / surrounded / endangered ally | Spatial pressure affects decisions and emotion | Current | Let nearby enemies and constrained spacing carry the pressure read; when pressure changes the projected emotion, reuse FEEL-01’s single status cue instead of adding a surround ring. |
| FEEL-06 | Kill relief / morale ripple | Killer and living party recipients; threat importance affects relief | Current | After the kill result, update only confirmed affected recipients’ existing status chips when their projected emotion status actually changes. Reuse ACTION-06 for source emphasis; add no separate cue. |
| FEEL-07 | Ally death / fear contagion | Witnesses, relation to lost actor, blocked/dampened contagion | Current | Keep death on the actor under ACTION-24 and actual injury mirrored on its existing card under ACTION-08; a witness chip changes boldly only when its projected status changes. Add no grief link, contagion marker or repeated health glow on death. |
| FEEL-08 | Rally / inspiring presence | Source leader and affected allies | Current | For a confirmed leadership event with a supplied source action, visibly wind up and commit that actor, then let changed recipients recover their balance alongside FEEL-01's chip response. Add no source rim or persistent ring, and skip an unexposed event or outcome. |
| FEEL-09 | Calming / steady presence | Fear relief or morale support; distinguish passive aura from skill activation | Current | When projected emotion changes through calming, let the recipient visibly ease and settle alongside FEEL-01's chip response; unchanged outcomes stay quiet. Passive presence invents no source action or aura, while Steady Call reuses its supplied source action. |
| FEEL-10 | Self-regulation / resilience | Self Regulate increases morale; Resist Fear dampens applicable fear gains; panic suppression changes refusal threshold | Current | Pair a projected status change with a deliberate grounded actor settle and FEEL-01's single chip update. This is expressive presentation, not HP recovery or a new stance; unchanged displayed status stays quiet. |
| FEEL-11 | Last stand / refusal resistance | Personal vulnerability versus willingness to continue | Current | Skip a standalone last-stand badge: show willingness through the actual continued action or refusal outcome and the actor’s existing status cue. |
| FEEL-12 | Bonds / rivalry / vows | Change tendencies and the meaning of support/loss; not visible tactical commands | Current influence | Skip persistent bond, rivalry, and vow marks on combat tokens; let their influence appear only through the resulting action or an already-authored relevant bark. |
| FEEL-13 | Maturity expression | Nascent, Forming, Grounded, Whole; strength of identity, resilience and leadership | Current | Skip a separate maturity combat overlay because the current entry establishes influence, not a distinct combat event; retain any approved identity expression on the actor itself. |
| FEEL-14 | Calling passive state | Anchoring while stationary, momentum, movement streak, rest/steadiness, field-reading streak, withdraw cooldown, idle fear aura | Current; separate from SKILL-09–14 | Skip a generic Calling aura: show passive effects through the actual movement, stance, or action they influence, with no extra Calling badge on the token. |
| FEEL-15 | Displacement immunity | Position Lock on owner; Anchor Presence affecting allies | Current resolver; hazard visual gap | When displacement is actually prevented, give the affected person a brief grounded settle at their cell; show no permanent immunity ring, and do not imply enemies or structures have this trait. |
| FEEL-16 | Leadership influence on decisions | Aggression, mark emphasis, safer path, hold formation, threat reading, cover, directive amplification/echo | Current influence; no separate action implied | Skip a leadership-stat overlay; let the influenced choice read through its resulting action or route, with a bark only when one is already supplied. |
| FEEL-17 | Morale forecasting / lock | Temporary prevention of morale fall where the trait applies | Current | Skip a cue for an invisible prevented morale drop; if a projected emotion status changes, reuse FEEL-01’s single chip update. Add no forecast emblem or Guard-like ring. |
| FEEL-18 | Bark / reaction / reason | Attack, movement, guard, fear, last stand, resilience, kill, taunt, decline, divergence, reactive reply | Current; a taunt bark does not establish a taunt combat action | Reveal each supplied bark progressively as if spoken, restarting at the new line's event while keeping one bubble per speaker in reaction order. Playback controls govern the reveal, rest/reduced motion show complete text, and no trait-reason label or extra bubble is added. |

Sources: `ui/components/EmotionPresentation.gd:6`; `core/emotion/EmotionService.gd`; `core/combat/CombatRoundEmotionService.gd`; `core/combat/LeadershipEmotionService.gd`; `core/actors/ActorStateMachine.gd:230`, `:804`, `:1075`, `:1220`; `core/actors/behaviors/BehaviorArbiter.gd:57`; `core/movement/LiveMovementContextService.gd:230`; `data/shouts/`.

Exact authored trait keys for individual briefing:

| ID | Trait keys | Current meaning / status | Animation / UI description |
|---|---|---|---|
| TRAIT-01 | `resist_fear` | Dampens applicable fear gains past Nascent; channels must preserve actual gating | Skip a trait marker; when resistance changes a projected emotion status through a fear outcome, reuse FEEL-03’s single chip update. Do not imply the trait is always active. |
| TRAIT-02 | `self_regulate` | Morale recovery past Nascent | Do not equate morale recovery with an emotion-status change; if a projected status changes, reuse FEEL-01’s single chip update. Add no persistent trait icon. |
| TRAIT-03 | `suppress_panic_spiral` | Higher refusal threshold past Nascent | Skip a threshold badge; let an actual refusal or continued action carry the result, reusing FEEL-11’s read. |
| TRAIT-04 | `ignore_broken_allies` | Authored resilience pool entry; no core consumer found — dormant | Skip for now: `ignore_broken_allies` has no core consumer in the inventoried source, so there is no live effect to animate or signal. |
| TRAIT-05 | `inspire_aura`, `steady_presence` | Nearby morale support | For a confirmed nearby support effect, reuse FEEL-08’s recipient status update and source action cue; otherwise add no separate cue. |
| TRAIT-06 | `calm_fear`, `fear_read` | Relief to most fearful nearby eligible ally | When fear relief produces a projected status change, reuse FEEL-09’s shared chip response. Do not add a fear icon or radius ring. |
| TRAIT-07 | `rally_call` | Morale boost; once-per-combat gating where configured | For a confirmed Rally Call effect, reuse FEEL-08’s recipient status update and source action cue; otherwise add no separate cue. |
| TRAIT-08 | `morale_forecast` | Temporary morale lock | Skip a cue for an invisible prevented morale drop; if a projected emotion status changes, reuse FEEL-01’s single chip update. Add no forecast emblem. |
| TRAIT-09 | `morale_anchor`, `calm_transmission`, `block_contagion` | Dampening/relief/contagion protection through emotion services | Keep blocked contagion silent unless a projected witness status changes; then reuse FEEL-07’s shared status treatment. Add no persistent protection mark or all-faction implication. |
| TRAIT-10 | `kill_momentum` | Kill event supports nearby eligible allies | When a kill produces the configured support effect, reuse FEEL-06’s source emphasis and confirmed recipient status update. Skip a separate cue when no visible outcome is supplied. |
| TRAIT-11 | `aggression_field`, `mark_target`, `challenge_call` | Decision-score influence; not three new action types | Skip trait-specific target, aggression, or challenge badges; if a distinct mark is actually applied, use the shared mark treatment from the action brief, otherwise show only the resulting choice. |
| TRAIT-12 | `safe_path_read`, `cover_positioning`, `hold_formation`, `threat_read` | Movement/defence/withdrawal decision influence | Skip passive route and cover overlays; show the chosen route or Guard outcome under its movement/stance entry, without attributing an unexposed cause. |
| TRAIT-13 | `directive_amplify`, `directive_echo` | Directive influence | Skip a persistent directive aura; let the interpreted action or route carry the effect, and use a bark only if the snapshot already provides one. |
| TRAIT-14 | `position_lock` | Owner displacement immunity | When Position Lock visibly prevents displacement, reuse FEEL-15’s brief grounded settle on its owner; no permanent lock icon. |
| TRAIT-15 | `anchor_presence` | Nearby eligible allies' displacement immunity | When Anchor Presence visibly prevents an ally’s displacement, reuse FEEL-15’s settle on that ally; show no radius or always-on halo. |

Leadership traits are gated by Whole expression. Enemy and structure factories initialize empty resilience/leadership trait arrays; do not imply every faction currently emits these effects. Personality archetypes (Loyal, Proud, Reflective, Valiant, Canny, Devout, Stoic, Empathic, Ambitious) influence behaviour and voice; they are not nine additional token action types.

Sources: `data/balance.json:1245`, `:1284`, `:1329`; `core/emotion/EmotionService.gd:260`; `core/actors/ActorStateMachine.gd:297`, `:315`, `:1075`; `core/echoes/PersonalityArchetype.gd:13`; `core/actors/EnemyActor.gd`; `core/actors/StructureActor.gd`.

## 6. Objectives and object interactions

| ID | Mode / event | Elements and outcomes to brief | Status | Animation / UI description |
|---|---|---|---|---|
| OBJ-01 | Combat | Remaining opposition; elimination; party defeat | Current | Keep remaining opposition legible through the actors on the board rather than a kill counter; let the final elimination or party defeat resolve through the existing combat result surface. |
| OBJ-02 | Purify Shrine | Shrine location/HP, corruption/decay pressure, purifiers, stacks, restoration, enemy interference, restored/destroyed result | Current | Keep the shrine square stationary while the named purifier commits and a brief warm flow connects source to shrine before confirmed progress resolves. Exposed restoration uses green inward HP gain and a warm material change; damage or destruction fractures its surface without person recoil or a death glow. |
| OBJ-03 | Recover | Relic location, eligible holder/proximity, hold counter, interrupted hold, reinforcements, completion | Current | Keep the invulnerable relic stationary with no HP bar or carried motion; let the banner’s hold progress advance alongside a restrained change in the relic’s base light. |
| OBJ-04 | Protect | Protected entity location/HP, guard progress, nearby protector, threat, theft, return, destruction | Current | Keep the totem stationary, show actual red HP loss and surface fractures, and leave guard progress in the objective banner. Retain the urgent stolen banner and mark a carrier only when its identity is exposed. |
| OBJ-05 | Endure | Duration, rounds remaining, wave timing/arrival, survival | Current | Keep rounds remaining and wave count in the objective banner, and reuse ACTION-01 for each confirmed enemy arrival. Skip a full-board alarm that competes with the new actors. |
| OBJ-06 | Pursue | Quarry badge, chase, containment counter/window, distance to exit, escape/death | Current | Retain the quarry’s gold diamond and existing distance pips; let the banner become urgent at the exit edge, then show containment, escape, or defeat once without duplicating the chase cue. |
| OBJ-07 | Guide Spirit — protect | Named spirit/halo, safety/fear/HP, keep calm, protected/dead result | Current | Keep the spirit’s gold halo distinct from active-turn and stance marks; show only exposed name, alive/HP, mode, and progress in existing surfaces. Skip fear/safety indicators unless their values are projected, and use no escort trail in protect mode. |
| OBJ-08 | Guide Spirit — escort | Named spirit/halo, destination, escort proximity, movement/interruption, possible combat participation, arrival/death | Current | Keep the destination readable on the board and escort proximity spatial; if the spirit joins combat, retain its halo alongside its combatant token, without stacking another role badge or status label. |
| OBJ-09 | Relic holder change | Holder designation, holder loss, successor; does not establish carried-token motion | Current round bookkeeping; direct attachment feedback absent | If the holder name is supplied for display, briefly highlight that name when ownership changes while keeping the relic in place. Skip transfer motion and a second ownership label. |
| OBJ-10 | Totem theft / enemy carrier | Stolen state, carrier identity, doubled damage, carrier defeat and recovery | Current simulation; main banner says STOLEN but carrier attachment absent | Use the existing urgent stolen banner; outline the actual enemy carrier only if the snapshot identifies it, then clear that cue on recovery or resolution without inventing a carried-object animation. |
| OBJ-11 | Carry / pickup / transfer custody | Richer mover pickup, carried object and carrier penalty services | Partial/dormant; do not infer live gameplay from template | Skip for now: richer pickup, carrying, and custody transfer are partial/dormant; limit any current holder cue to OBJ-09 and do not imply live pickup gameplay. |
| OBJ-12 | Charge pressure | A prior encounter consequence modifies pressure; banner marker | Current | Show the existing charge-pressure marker once in the objective banner for affected encounters; skip an ambient danger ring or repeated warning pulse. |
| OBJ-13 | Retreat | Availability, chance tier, attempt, success/failure, continue/withdraw result | Current prebattle path | Keep retreat availability and chance in UI-02; show the outcome through the supplied result flow, with no movement cue before success is resolved. |
| OBJ-14 | Pace reward | Full/partial/none pace state, colour transitions on round/objective display, reward/rank consequence in resolve | Reference | Conditional reference treatment: if pace fields are integrated into the snapshot, shift the existing round/objective display calmly between full, partial, and none, then carry the outcome into Resolve; no flashing urgency or invented timing. |

Sources: `core/state/encounter/EncounterResolutionModes.gd:6`; `core/combat/ShrineService.gd`; `core/combat/CombatRoundShrineService.gd`; `core/combat/CombatRoundObjectiveService.gd:148`; `core/combat/CombatRoundGuideSpiritService.gd`; `core/combat/RetreatService.gd:17`; `core/combat/CombatState.gd:206`; `ui/screens/combat/CombatBoardScreen.gd:425`; **W/**`core/combat/PaceService.gd`; **W/**`ui/screens/combat/CombatBoardScreen.gd:524`.

## 7. Battlefield and persistent overlays

| ID | Feature to brief | Variants / caution | Status | Animation / UI description |
|---|---|---|---|---|
| BOARD-01 | Combat floor and grid | Irregular walkable cells, readable cell edges, board extent | Current | Keep walkable-cell edges quiet and the irregular board silhouette clear; let the existing floor treatment carry most of the field so the grid does not compete with actors. |
| BOARD-02 | Void / blocked cell | No legal occupancy or route; distinguish from merely dark ground | Current topology | Keep void visibly absent and blocked footprints explicit where authored; darkness alone should not read as impassable terrain. |
| BOARD-03 | Bridge / narrow crossing | Tinted bridge floor, chokepoint, actor traffic | Current | Carry the existing bridge-floor distinction across the full crossing, with cell edges still readable at narrow points; avoid adding a second chokepoint marker. |
| BOARD-04 | Objective / spawn layout | Party entry, opposition, structure, spirit destination, quarry exit | Current | Use the existing objective actor and board positions as the primary landmarks; keep entry, destination, and escape markers brief and remove their labels from the field once they are no longer immediately useful. |
| BOARD-05 | Obstacles / landmarks / occlusion | Readable physical footprint follows actual walkability | Future production presentation | Future only: add low-profile obstacle silhouettes whose footprint matches walkability and whose overlap does not hide token identity or movement paths. |
| BOARD-06 | Burning Ground | End-activation damage; zone and affected actor | Current resolver/fixtures; live production presentation gap | Future only, once the hazard footprint and result are exposed: show Burning Ground as a bounded patch and reuse ACTION-08’s signed loss and matching card HP when damage resolves. Avoid a second persistent warning over the token. |
| BOARD-07 | Unstable Ground | Forced displacement or damage fallback | Current resolver/fixtures; live production presentation gap | Future only, once the footprint and result are exposed: show affected Unstable Ground cells and the resolved displacement or ACTION-08 fallback damage feedback. Do not imply the player chose the route or add a second damage treatment. |
| BOARD-08 | Binding Growth | Stops movement on entry | Current resolver/fixtures; live production presentation gap | Future only, once the hazard footprint and result are exposed in the player-facing snapshot: mark the Binding Growth footprint and let stopped movement communicate the effect. Avoid a persistent restraint badge after the interruption. |
| BOARD-09 | Move destination telegraph | Cell cue before committed traversal | Current | Reuse MOVE-01's single destination telegraph; avoid a duplicate marker from the objective or route layer. |
| BOARD-10 | Route / direction / intent | Actual committed path, target relation, arrival; not an exact player order | Current data; visual breadth varies | Show only the currently committed route with a faint floor trace that clears after arrival. Keep it quieter than the target relation and never style it as an exact player-issued command. |
| BOARD-11 | Control / threat / reach | Spatial facts used by movement; don't imply all are currently overlayed | Current simulation; broader overlays Future | Future only: do not keep broad reach or threat fields lit; if approved later, surface only the immediate spatial fact needed to read an actor's current behavior. |
| BOARD-12 | Known / unknown battlefield information | Truthful discovered terrain/objective/hazard briefing | Future canonical requirement | Future only: show discovered terrain and objective facts from confirmed snapshot data; leave unknown ground unmarked rather than implying guessed threats. |
| BOARD-13 | Distance rulers | Shared all-actor distance overlay in current render path; development intent differs from visibility | Current prototype surface | Skip in the player reference: the currently visible distance ruler adds dense diagnostic labels. Keep it available only in a separate debug example if needed. |
| BOARD-14 | Overlap priority | HP, stance, halo, active ring, mark, bark, target relation, damage pop at once | Required composite reference case | Use a clear overlap order: active actor, target relation, outcome feedback, then optional detail. Let less urgent marks yield when several states coincide instead of keeping every overlay equally bright. |

Sources: `core/realms/StageTerrain.gd`; `core/movement/MovementHazardService.gd:68`; `core/movement/MovementHazardFixtures.gd`; `core/combat/EncounterSetupService.gd:304`; `ui/screens/combat/CombatBoardScreen.gd:547`; `ui/screens/combat/CombatDistanceLayer.gd`; `ui/screens/combat/CombatMoveTelegraphLayer.gd`; GDD tactical-field and intel sections.

## 8. UI, controls and the combat journey

| ID | Surface / feature | States to brief | Status | Animation / UI description |
|---|---|---|---|---|
| UI-01 | Prebattle panel | Objective instruction, optional introduction line, Enter Combat and eligible Retreat; no party/opposition summary in current modal | Current | Let the objective instruction and optional intro line lead, with Enter Combat and any eligible Retreat kept distinct. Do not imply a party or opposition summary exists in the current modal. |
| UI-02 | Retreat offer | Available/unavailable; chance tier; result | Current | When Retreat is eligible, keep its existing cost and chance tier together; when unavailable, retain a clear disabled state. Let the existing result flow report success or failure without duplicating it over the board. |
| UI-03 | Round and phase header | Before combat, actor turn, round end; active round | Current | Keep round and phase information in one compact header. Synchronize the initiative-row highlight and board ring as one current-actor read instead of repeating the actor name across headers. |
| UI-04 | Objective banner | Instruction, progress, urgency, completion; all seven modes | Current | Keep one objective instruction and its relevant progress in the banner; promote urgency only when the snapshot state changes, then return visual weight to the active actor and board. |
| UI-05 | Initiative / actor list | Every combat actor, turn order, current actor, action result, HP/emotion where applicable | Current | Keep initiative rows scannable with a synchronized current-actor cue, concise result and projected emotion where present. Reuse the bold chip change and actual HP result from the shared treatment rather than adding competing highlights. |
| UI-06 | Party / EchoBar | Echo identity/status; belongs to RealmShell; extra ally/spirit card and spirit-progress treatments occur in newer worktree | Current party surface; extended cards Reference | Keep RealmShell’s EchoBar as the single persistent party strip, mirror exposed HP deltas there with a brief red loss or green gain response, and keep the same HP values above tokens. Treat newer ally/spirit cards and spirit progress as reference-worktree extensions, not main-checkout surfaces or permission to duplicate cards inside the screen. |
| UI-07 | Token identity | Circle/square, faction, short initials, shadow; colour alone should not own meaning | Current prototype | Preserve the prototype's circle/square distinction and short identity marks; keep faction readable through shape and label as well as colour, without adding a permanent legend over the field. |
| UI-08 | HP bar | Full, injured, low, zero; omit on invulnerable relic | Current | Place HP bars above eligible characters and on their existing Echo cards, preserve the green/yellow/red health roles and update both from the same resolved HP value. Strongly emphasize the first low-health crossing but not confirmed death, and retain no HP bar on an invulnerable relic. |
| UI-09 | Damage pop | Damaged actor, number, timing; distinguish from ongoing HP bar | Current | Send a red minus-number outward from the hurt actor and draw a green plus-number inward for exposed HP gain, with every signed value matching the actual bar and card delta. Let contact and physical response lead, then the HP result and any changed emotion; this feedback does not establish a healing action. |
| UI-10 | Active ring | Active turn; separate from spirit halo, ally ring and stance | Current | Keep the synchronized current-actor ring unmistakable and preserve distinct identities for ally ring, spirit nimbus, normal Guard shield and directional stop-short stance marks. Mark persists while relevant; Reveal uses the same bracket briefly without stacking another outline. |
| UI-11 | Bark bubble and tail | Speaker, placement, expiry, overlapping speakers, reactive answer | Current | Reuse FEEL-18's progressive spoken reveal in one bubble per speaker with a legible tail and ordered reactions, clear of HP, shields and objective cues. Fear refusal may lead with ACTION-19's brief tremor; rest/reduced motion show complete supplied text. |
| UI-12 | Slow / Normal / Fast | Playback changes; readable effects at each speed | Current | Retain the existing Slow, Normal, and Fast playback choices; keep action identity and outcome readable at each speed without adding new timing controls. |
| UI-13 | Auto / Manual / step CTA | Existing prototype controls; manual actor advancement conflicts with current automatic-only canon | Current prototype; not final UX endorsement | Do not carry Manual or step advancement forward as final combat UX: the GDD keeps combat automatic. If retained in the reference as a prototype control, label it as exploratory rather than implying exact player commands. |
| UI-14 | Pan / zoom / recenter | Mouse/touch navigation, board clamp, return to party | Current; camera refactor Reference | Keep current pan and zoom behavior, with the existing recenter path easy to find after navigation; preserve the wider camera refactor as reference-only until it is in main. |
| UI-15 | Select/focus actor | Token tap, initiative row, EchoBar; enemy/structure/spirit eligible; dead ignored; empty tap clears | Reference; camera focus, not attack targeting | Reference only: actor selection recenters the camera and is indicated only in the selected initiative/EchoBar row; add no board ring or bracket, keeping it distinct from active turn and Mark/Reveal. Clearing selection changes focus only, not target or command state. |
| UI-16 | Camera follow | Existing Pursue quarry follow; newer free view, party follow and actor follow; interruption by navigation | Current quarry follow; broader modes Reference | Keep the existing quarry follow distinct from the newer reference follow modes; in either case, user navigation should read as temporary camera ownership, not a change in simulation intent. |
| UI-17 | Hover / target inspection | No dedicated current actor-hover surface established | Visual brief item if desired | Skip: no current hover inspection surface or snapshot detail is established; use the read-only focus reference rather than inventing a targeting or detail panel. |
| UI-18 | End Combat / Back | Availability by phase/context; keeper intro exception | Current prototype | Keep Back and End Combat visually distinct and show only the action valid for the current phase; do not let one control silently change meaning. |
| UI-19 | Round boundary | Cleared defensive states, objective ticks, emotional updates, wave arrival | Current; dedicated transition treatment not found | Group round-end updates into one readable transition: objective progress and any wave arrival, then return focus to the next active actor. Avoid separate persistent notices for each system update. |
| UI-20 | Resolve outcome | Victory/defeat/reason; separate resolve screen | Current | Lead the existing resolve surface with victory or defeat and its reason; keep the outcome visually ahead of secondary reward detail. |
| UI-21 | Resolve rewards | Ase/rewards, enemies defeated, survivors, round count, per-Echo progression, voice/emotion, vows/effects | Current | Keep campaign reward summary separate from per-Echo contribution/progression detail; let changed Echo progress stand out without turning every unchanged field into a callout. |
| UI-22 | Resolve pace bonus | Round-stat colour, reward/rank consequence, rank-cause label when pace changed rank | Reference | Reference only: preserve the compact in-combat pace-state treatment and show its reward/rank consequence once on Resolve; use the rank-cause label only when pace changed rank. |
| UI-23 | Combat emotion debug | Callback exists; main token setter is a no-op; don't infer a live emotion overlay | Debug gap | Skip: combat emotion debug has no live player-facing overlay; keep diagnostic state out of the visual reference. |
| UI-24 | Dense / compact composition | Judge at 1920×1080; also compact viewport, many actors, multiple statuses and barks | Reference acceptance case | For dense examples, preserve the hierarchy actor → target → outcome → optional detail; let secondary labels yield instead of lighting every overlay at once. Check the same composition at 1920×1080 and the compact viewport. |

Sources: `core/state/flow/states/venture/EncounterSnapshotBuilder.gd:73`, `:144`, `:348`; `ui/screens/combat/CombatBoardScreen.gd:308`, `:650`, `:900`, `:1004`, `:1134`; `ui/shells/RealmShell.gd`; `ui/screens/venture/ResolveScreen.gd:132`; **W/**`ui/screens/combat/CombatBoardScreen.gd:1297`; **W/**`ui/shared/BoardCamera.gd`.

## 9. Keeper guidance — separate planned surfaces

The current main runtime has a developer/headless guidance seam. It does not have the player-facing ping/deployment workflow described by the latest GDD. Keep these in a separate reference section so they cannot be mistaken for existing controls.

| ID | Feature to brief later | Required distinction | Status | Animation / UI description |
|---|---|---|---|---|
| GUIDE-01 | Deployment / formation preparation | One party representation and selection path | Future production surface | Skip for now: formation preparation is a future production surface and its selection/placement rules are not established in the current build. |
| GUIDE-02 | Broad Directive | Scout Carefully / Seek Signs remain broad intent | Current influence; combat guidance UI expansion Future | Future only: show Scout Carefully or Seek Signs as one broad party intent in its approved context; never repeat it as an exact order on each Echo. |
| GUIDE-03 | Ping resource and availability | Round-earned, temporary emphasis; why unavailable | Future player-facing surface | Skip for now: the player-facing resource and availability rules are not implemented, so a gauge or disabled-state treatment would invent feedback. |
| GUIDE-04 | Recipient preview | Echo-specific, area-based, party-wide; exactly one scope per ping | Future player-facing surface | Future only: before confirmation, preview the exact Echo, area, or party recipient scope; freeze that recipient set on confirm. Keep unaffected Echoes visually quiet. |
| GUIDE-05 | Confirm / input acknowledgement | Fixed recipients, subject/footprint, next-round timing | Future player-facing surface | Future only: acknowledge confirmation once with its fixed recipients, subject, and next-round timing; do not add a pause or a duplicate confirmation control. |
| GUIDE-06 | Align | Accept guidance | Existing response seam; full UI Future | Future only: show Align as a brief acknowledgement for a fixed recipient, then let the next action provide the evidence; avoid a persistent obedience/status badge. |
| GUIDE-07 | Interpret | Reshape guidance | Existing response seam; full UI Future | Future only: show Interpret as a compact, event-local response with its primary reason, then let the changed behavior carry the meaning; do not turn it into a permanent trait. |
| GUIDE-08 | Hesitate | Delay/weak commitment; not permanent emotion status | Existing response seam; full UI Future | Future only: keep Hesitate event-local and distinct from emotion status; let delayed or weakened commitment appear through the next action rather than a lasting label. |
| GUIDE-09 | Object | Resist with a primary reason | Existing response seam; full UI Future | Future only: show Object with one clear reason for the fixed recipient; keep it separate from fear-based inability to act. |
| GUIDE-10 | Refuse guidance | Reject suggestion; distinct from fear-based inability to act | Existing response seam; full UI Future | Future only: show Refuse guidance with its reason and keep it distinct from fear-based refusal to act; the following behavior should confirm the consequence. |
| GUIDE-11 | Guidance consequence / review | Response before relevant turn, then movement/action reveals consequence | Future complete production loop | Future only: show each response immediately before that recipient’s activation, then let the first movement/action provide evidence. Keep this pre-turn response distinct from MOVE-28’s stop-short cause shown after landing. |

Sources: `core/actors/behaviors/GuidanceContribution.gd:49`; `core/runtime/controllers/DebugController.gd:339`; GDD `:253`, `:1338`, `:1416`, `:4298`.

## 10. How to supply the visual brief

Use an ID or a group of IDs. Describe the behaviour you want to see without needing to choose a technical implementation.

```text
Feature: ACTION-10 Guard
Applies to: Echoes, allies, enemies; structure treatment separately if relevant
Token / world appearance:
Animation: entry → held state → outcome → exit
Spatial UI / icon / links:
Compact text, if needed:
Sound, if needed:
What can overlap / what takes priority:
Slow / normal / fast / reduced-motion behaviour:
Existing reference to preserve:
```

After Jeffrey reviews the suggestions and supplies those decisions, the artist can build an animated reference page in the supplied HTML's style: isolated examples, all actor variants, entry/held/outcome/exit states, playback controls, combined battlefield examples, and a clear division between current and proposed treatments. Suggestions in this inventory remain unapproved until Jeffrey chooses them.

## OPEN — questions and assumptions

ASSUMED: “Combat as a whole” includes setup, battlefield, all actor classes, objectives, and immediate resolve. Wider Sanctum/exploration features enter only where they affect combat. | WHY: These are the boundaries of the referenced feature and requested combat polish. | WRONG IF: Jeffrey wants an inventory of the entire game's noncombat screens too.

ASSUMED: Both main and the supplied worktree matter. | WHY: The supplied worktree has newer code and a mockup not present in main. | WRONG IF: Only one branch is intended as the future implementation baseline.

BLOCKED: None for the inventory. The visual treatments and eventual implementation baseline remain Jeffrey's decisions. Existing Hold-link uncertainty from V54 is preserved, not resolved here.

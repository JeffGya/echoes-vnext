# Combat Distinctiveness Design Spec — Seven Modes

> **Status:** Design proposal. No code. Build ON `docs/combat-modes.md` (authored mechanics canon) and the GDD.
> **Anchored to GDD canon:** Pillar 1 *Guidance over Control* ("Player influences; Echoes interpret; never command"); Pillar 3 *Autonomous Companions* (Echoes have will, must be understood not exploited); Directives as **weighted preference** (Scout Carefully / Seek Signs), not commands; Realms as *"prior Sanctum choices tested."*
> **Design lenses applied:** `echoes-sankofa-gdd` (canon foundation), `game-design` + `game-mechanics-designer` (MDA, player fantasy, mechanic clarity, tension/reward), `systems-story-designer` (why the implemented experience reads flat and how the objective actor becomes a *character/stake* rather than furniture).
> **Implementation surfaces referenced** (so this stays buildable, not abstract):
> - `BehaviorArbiter` data-driven scoring — `directive_action_muls` (semantic keys), `situational_muls` (per-condition flat bonuses; several dormant stubs already exist: `near_friendly_structure`, `near_hostile_structure`, `_stub_objective_in_range`, `_stub_enemy_bodyguard`), `_generate_candidates` (situation-gated candidate pool), `intent_weights_by_calling_origin`.
> - `EncounterResolutionModes` (7 modes), `CombatState.check_end_condition` (win-priority ladder), `ShrineService`, `FleeBehaviorModule` (PURSUE), `StageTerrain` (irregular boards), `GridService` (walkable pathing), per-mode tuning under `balance.json → data.combat.objective_modes.<mode>`.

---

## 0. Root cause: why all seven play identically today

Three structural facts collapse every mode into "kill the nearest enemy":

1. **Kill-all is the universal *and dominant* win.** It is listed as a win in every mode AND it is the **easiest** path because echoes already auto-target enemies and enemy counts are finite. The special condition never gets a chance to matter — you win before it's relevant.
2. **The objective actor has no agency or fragility loop.** Relic/totem/spirit are `StructureActor`s that *sit there*. Nothing forces the player to orient around them. A passive object that cannot be lost, moved, or hurt fast = scenery.
3. **Echo autonomous behavior is mode-blind.** The arbiter scores the same way regardless of objective type. No mode injects a directive-weight context or a situational condition that makes an echo *peel off, interpose, carry, or escort*. The dormant stubs prove the seam exists but is unused.

**The fix is a triad, applied per mode** (this is the spine of every section below):
- **(A) Make kill-all impractical-by-default but still legal** (GDD: kill-all stays a possible path). Lever: **enemy replenishment / pressure** so the enemy set is effectively non-finite within the round budget, OR a **timer that beats the kill rate**. Clearing is then a *heroic outlier line*, not the default.
- **(B) Give the objective actor a fragility/agency loop** that resolves the stage if ignored (dies fast, drifts, gets stolen, flees, must travel).
- **(C) Bias echo autonomy per mode** via existing arbiter seams (directive-weight context + activated situational conditions), so echoes *interpret* the mode without the player commanding them — Guidance over Control.

Everything below is the per-mode instantiation of that triad.

---

## Cross-mode differentiation matrix (read this first)

| Mode | Echo autonomous behavior (vs "attack nearest") | Objective actor role | Dominant win path | Primary tension |
|---|---|---|---|---|
| **COMBAT** | Attack nearest; press wounded; formation pull | None | Defeat the set | Attrition / positioning on terrain |
| **PURIFY_SHRINE** | Find shrine, then ring-defend; purifier peels to heal it <50% | Fixed, fragile-under-drain, you restore it | Shrine survives waves (≥1 echo alive) | Split focus: heal vs intercept |
| **RECOVER** | One echo **breaks off to reach & hold** the relic; others screen the lane | Fixed, **deep behind a chokepoint**, must be *held* not killed | **Hold adjacency N rounds** through reinforcements | Reach-and-hold vs being peeled away |
| **PROTECT** | Echoes **interpose** between threats and totem; a carrier **picks it up & repositions** under debuff | **Carryable, debuffs holder, stealable → enemies double-damage** | Totem alive + ≥1 echo, denying theft | Custody & body-blocking; the object *moves with you* |
| **ENDURE** | Attack to whittle the waves down OR conserve and outlast — both viable depending on echo kit (NO forced defense) | None (you are the objective) | **Survive N rounds OR defeat all waves** | Out-survive vs. out-kill; "can we last, or can we clear them?" |
| **PURSUE** | Echoes **fan out to cut off & corner** a fleeing quarry; flankers herd | **Mobile, flees, actively escaping** | **Contain (hold adjacent) before window closes** | Chase / interception geometry & timing |
| **GUIDE_SPIRIT** | Echoes **escort-screen** a moving ward along a path; vanguard scouts ahead, rear guards | **Mobile ally that travels (or is held) & may join at 75% debuff** | Reach destination (or protect in place) + ≥1 echo | Moving-protectee logistics on a long board |

The matrix must stay legible at a glance: **objective role** is the strongest differentiator (none / fixed-fragile / fixed-held / carryable / none / fleeing / traveling), and **echo behavior** follows from it.

---

## COMBAT — baseline (brief)

1. **Fantasy / feel.** A clean trial of arms. "Can my house's people stand and win a straight fight on this ground?" The control mode against which the others are *felt as different*.
2. **Core distinct mechanic.** Defeat a **set** (not waves). It is the only mode where kill-all is *meant* to be the path. Distinctiveness comes from terrain, not objective.
3. **Echo autonomy.** Current behavior is correct here: nearest-enemy, press wounded (Forming+), formation pull (Grounded+). No change.
4. **Objective actor.** None.
5. **Why objective drives outcome.** N/A — the enemy set *is* the objective.
6. **Map / placement.** Use `StageTerrain` chokepoints/bridges to create approach decisions; spawn enemies so a bridge or plateau lip is the natural fight line.
7. **Failure & stakes.** All echoes down. Standard.
8. **Tuning.** Enemy count scales by realm completion order; ~4–7 at low order. Single set, no replenishment.
9. **Foundation vs later.** Foundation: already live. This mode is the *reference baseline* — keep it pure so contrast is visible.

---

## PURIFY_SHRINE — find-and-tend (brief; already live, sharpen)

1. **Fantasy / feel.** Okomfo/Onyamesu fantasy: a sacred site is bleeding and your people must *find it, then keep it lit* while enemies try to snuff it. Tending, not slaying.
2. **Core distinct mechanic.** Shrine at a hidden/found location; **drain** pushes HP down; an echo with the right profile **purifies** (restores) — but *only while shrine <50%*, so the player feels the site genuinely at risk before the save. (Honors `combat-modes.md`.)
3. **Echo autonomy.** Already partly built: `is_purifier` override (score 9999), shrine-HP-aware movement, `near_friendly_structure` (echoes get defensive bias + `actor.purify_shrine` weight near the structure), enemies get `near_hostile_structure` aggression toward it. **Sharpen:** non-purifier echoes should *ring-defend* — bias toward intercepting enemies on the shrine-approach lane rather than wandering to the farthest enemy. Use the dormant **`_stub_enemy_bodyguard`** seam inverted for echoes: an echo bodyguards the shrine (treat shrine as a "priority ally" for `protect_ally`/interpose scoring when an enemy is closing on it).
4. **Objective actor.** Fixed, fragile-under-drain, **restorable** — the restorability is what makes it a *tended* object, not a totem.
5. **Why objective drives outcome.** Enemy waves out-pace kill-all; the dominant question is "does the shrine survive?" Keep waves so the player can't simply clear faster than drain.
6. **Map / placement.** Shrine on a defensible plateau with 1–2 approach bridges → natural choke for ring defense; reward Scout-Carefully discovery.
7. **Failure & stakes.** Shrine HP hits 0 — the site goes dark; the stolen story stays corrupted. Felt as a *desecration*, not a unit loss.
8. **Tuning.** Drain per enemy-in-range scales by completion order; purify restore tuned so one purifier can hold one shrine against ~2 attackers, not 4. Waves: 2–3 at low order.
9. **Foundation vs later.** Foundation: shrine find + drain + purify already live; ring-defense bias is a small arbiter addition.

---

## RECOVER — the deep relic (PRIMARY)

1. **Player fantasy / feel.** *Reach into the corrupted dark and bring a piece of a stolen story home.* This is the Realm thesis in miniature (GDD: "recover Threads, bring stolen stories home"). It should feel like a **smash-and-grab under fire**: the relic is *far, exposed, and guarded*, and the moment of holding it is the moment of maximum danger. Today it "looks like a shrine stage" precisely because the relic is passive and central and kill-all wins first. It must instead feel like a *salient reach*.

2. **The core distinct mechanic — HOLD, don't kill.** Win = **hold an echo adjacent to the relic for `hold_rounds`** (canon). The distinct verb is **hold under pressure**: the relic does not fight, cannot be "completed" by killing, and is placed where you cannot trivially clear to it. The counter to kill-all is **continuous enemy replenishment toward the relic lane** (see #5) so that "kill them all first" is mathematically slower than "send one in and hold while the rest screen." Reaching is easy; *staying* is the game.

3. **Echo autonomous behavior (no player command).** The mode must produce a **self-organizing split**:
   - **One echo peels off to reach + hold the relic.** Implement via a **mode directive-weight context** injected by the resolution mode into the arbiter `directive`: high `objective_advance_priority` + `engage_only_blockers` for the *single best-suited* echo (highest speed/Path/seeker, or lowest current threat). This reuses existing `directive_action_muls` keys (`actor.move`/`melee_attack`: `objective_advance_priority`, `engage_only_blockers`). The "only blockers" semantic is exactly right: the holder fights *only* enemies between it and the relic, then sits.
   - **Activate `_stub_objective_in_range`** (already present) so the holder, once adjacent, *intensifies holding* (down-weight move/idle, this is the hold turn).
   - **The rest screen the lane.** Remaining echoes keep nearest-enemy aggression but receive a soft pull (formation-style) toward the relic→spawn corridor so they body-block reinforcements instead of chasing strays into corners. Reuse the formation-pull seam, re-centered on the relic lane.
   - Selection of *who* peels off is **emergent from stats/calling, not chosen by the player** — Guidance over Control. The player's Directive (Scout Carefully vs Seek Signs) nudges how cautiously the holder advances.

4. **Objective actor role.** Fixed `StructureActor`, **placed deep behind a chokepoint**, **invulnerable** (cannot be destroyed — it is a prize, not a shrine). Tension comes not from its fragility but from its **position + the hold timer**: it is the thing you must *get to and not be torn away from*.

5. **Why the objective (not kill-all) drives the outcome.** **Relic-seeking reinforcement.** Each round (or every k rounds, scaling with completion order) a small enemy reinforcement spawns from the far edge and is given `prefer_objective_target` toward the relic lane / the holder. This makes the enemy set *effectively non-finite within `hold_rounds`*, so clearing-first is impractical — yet a very strong party *can* still race the kill and win the legal kill-all line (GDD compliance). The dominant path becomes: secure → hold → endure the trickle. **Lose:** all echoes dead (canon).

6. **Map / placement setup.** Relic at the **end of a narrow bridge or single-mouth plateau** (terrain signature already supports plateaus/bridges/void). Party spawns across a gap; enemies spawn *between* party and relic AND trickle from behind the relic. The chokepoint is what lets a small screen hold the lane — it makes the self-organizing split *legible* to the player watching it happen.

7. **Failure & stakes.** All echoes fall before the hold completes — the relic stays lost in the dark; the Thread is not recovered this run. Emotionally: "we touched it and couldn't keep our grip." Stronger than a generic wipe because the player *saw* the prize.

8. **Tuning direction.** Short-to-medium, high-intensity. Suggested starting numbers (low completion order): `hold_rounds` = 3; initial enemies = 3–4; reinforcement = +1 every 2 rounds from far edge; relic ~6–8 tiles deep behind one choke. Scale with completion order: longer hold (3→5), denser trickle, deeper placement.

9. **Foundation vs later.** **Foundation:** invulnerable relic + hold-timer win + chokepoint placement + the peel-off directive context (reuses existing arbiter keys) + activating `_stub_objective_in_range`. **Later:** relic-carries-a-debuff variant, relic that must be *carried back* to spawn (converges toward GUIDE_SPIRIT — keep them distinct for now), Thread-distortion if the hold is sloppy.

---

## PROTECT — custody of the totem (PRIMARY)

1. **Player fantasy / feel.** *Your body between the world and the thing that matters.* Okofor/Onyamesu (Warder/Steward) fantasy made literal. Today it's "an object that just stands there with no sense of protecting" — the fix is to make protection **physical and spatial**: echoes throw themselves in the way, and the totem is something you can *pick up and reposition* when a corner gets too hot. Custody, not babysitting a prop.

2. **The core distinct mechanic — interpose + custody.** Two distinct verbs no other mode has:
   - **Interpose:** echoes move to *occupy the cell between an incoming enemy and the totem* (body-block), not just attack the nearest enemy.
   - **Custody:** the totem is **carryable (60% chance per canon)**; an echo can **pick it up and relocate it** to safer ground, accepting the **holder debuff** (canon), and **enemies can steal it → then deal double damage** (canon). The totem *moving through the party's hands* is the signature image.

3. **Echo autonomous behavior (no player command).**
   - **Interposition:** activate the dormant **`near_friendly_structure`** + a new active condition `objective_threatened` (enemy within k tiles of totem on an approach vector). Inject a directive context with high `threat_interception` + `ally_protection_bias` (existing `protect_ally` directive keys) **treating the totem as a protectee**. Echoes then score `protect_ally`/`actor.interpose` toward the totem-threat line. This is the same machinery that already protects wounded allies — pointed at the object.
   - **Pick-up / reposition:** add a gated candidate `actor.carry_objective` (mirrors how `actor.purify_shrine` is gated by `is_purifier` + adjacency). Trigger bias: when the totem's current cell is *surrounded / on the losing side of the board*, the nearest sturdy echo (Okofor/high faith, or one who least suffers the debuff per canon "specific classes reduce the debuff") scores carry highly and walks it to friendlier terrain.
   - **Theft response:** when an enemy holds the totem, echoes converge on the *carrier* (highest-priority target) to recover it — reuse the `_stub_enemy_bodyguard`/priority-target seam so the thief becomes the focus-fire target, overriding nearest-enemy.
   - All emergent: the player never says "you, carry it." Guidance over Control.

4. **Objective actor role.** **Carryable, fragile, debuffing, stealable.** It is the most *active* object of any mode precisely because it changes whose hands it's in and warps that holder. Tension = a hot-potato of responsibility: holding it makes you weaker, dropping it risks theft, theft makes the enemy stronger.

5. **Why the objective (not kill-all) drives the outcome.** Enemy waves specifically **path to the totem** (`prefer_objective_target` on the totem), and **theft → double-damage** makes ignoring custody catastrophic — a stolen totem can wipe a screen that was "winning" the kill count. So the dominant path is *custody management*, while a dominant party can still legally clear (GDD). **Win:** totem alive + ≥1 echo (canon). **Post-stage:** chance totem becomes a player item (canon, V2-ITEM-002 seam) — a reward that ties the protected thing to the Sanctum.

6. **Map / placement setup.** Totem starts **central with multiple approach lanes** (the opposite of RECOVER's single choke) — multi-lane is what *creates the need to interpose and to reposition*, because the party cannot wall off every lane at once. Safer "fallback" terrain (a defensible plateau) exists off-center so carrying it there is a real, readable option.

7. **Failure & stakes.** Totem destroyed (or held by the enemy at clock-out) — the protected memory is shattered/taken. Worse-feeling than a wipe because *it was in your care*. If stolen-then-lost, it reads as a theft, echoing Odo Agyanka (erasure).

8. **Tuning direction.** Medium length. Low completion order: totem HP modest; carry debuff = noticeable but survivable (e.g. −speed/−def on holder); theft chance only when an enemy ends adjacent to an unguarded totem; double-damage on enemy carrier; 2–3 lanes. Scale: more lanes, faster enemy pathing, higher carryable chance with completion order.

9. **Foundation vs later.** **Foundation:** interposition bias (reuses `protect_ally` directive keys + activate `near_friendly_structure`/`objective_threatened`), totem pathing for enemies, theft → double-damage, win/lose. **Later:** full carry/debuff/class-mitigation loop (`actor.carry_objective` candidate), the post-stage item reward, distinct "carry to safety" terrain heuristics.

---

## ENDURE — outlast the tide (PRIMARY; the designer's favorite — preserve & deepen)

1. **Player fantasy / feel.** *Brace. Hold. Just be alive at the end.* The designer already likes this because it is the one mode where the *win condition itself* (survive) reorganizes behavior. The party **is** the objective. Keep its purity; deepen the *pressure curve* so it stays the gold standard the others aim at.

2. **The core distinct mechanic — TWO viable win paths (designer direction).** Win = **survive to round N (≥1 echo alive)** OR **defeat all waves** (clear everything that has spawned, once the final wave is out). Neither is forced: a hard-hitting party can race to out-kill the tide; a durable party can ration HP/morale and outlast it. The distinctiveness is the *strategic fork* — both endurance AND aggression are legitimate, chosen by the echoes' abilities, not dictated by the mode.

3. **Echo autonomy — attack by default, no forced defense (designer correction).** Echoes behave like normal combatants: they target and whittle down the waves. Do NOT impose a `defensive_anchor`/survival bias by default — that removes the aggressive line the designer wants. Defensive play emerges only from the existing situational conditions (`outnumbered`, `last_echo_standing`, `own_hp_low/critical`) when a fight actually goes badly, exactly as in normal combat. The party decides between pressing the attack and conserving based on how the fight is going + their kit, with no mode-level thumb on the scale.

4. **Objective actor.** None — and that is correct. The *absence* of an object is itself a differentiator; ENDURE is the one mode that is purely about the party's own persistence.

5. **Why the objective drives outcome.** The **wave schedule + round clock** is the objective, and it resolves on EITHER condition: the round clock reaching N (survive) OR every wave having spawned and been cleared (defeat all waves). The transient lull between waves is NOT a win — clear-all only counts once the final wave is out and down. Tuning sets how close the two paths are: waves should be beatable by a strong offensive party within N rounds, yet punishing enough that a softer party is better off surviving. Both lines stay open.

6. **Map / placement.** A board with **one strong defensible feature** (a plateau with a single bridge mouth) so "where do we hold?" is the core decision. Waves spawn from the open edges, funneling toward the choke.

7. **Failure & stakes.** Whole party falls before the final wave — overwhelmed. Clean, legible loss; the tension is the *visible countdown* of waves remaining.

8. **Tuning direction.** Length defined by waves, not kills. Low completion order: 3 waves, cadence every 2–3 rounds, wave size 2–3. Scale: more waves (3→5), tighter cadence, larger waves, with a *rising* size curve so the last wave is the spike. Surface "waves remaining" so endurance is felt.

9. **Foundation vs later.** **Foundation:** dual win condition (survive-to-N OR defeat-all-waves, with the transient-lull guard so clear-all only fires after the final wave); rising-wave curve; waves-remaining surfacing; NO defensive-default bias. **Later:** wave modifiers (a "breather" wave, an elite finisher), morale-collapse cascades as a distinct fail-feel.

---

## PURSUE — corner the quarry (brief)

1. **Fantasy / feel.** *Don't let it get away.* Kra-Soro/Sum-Okwanfo (Ranger/Veilrunner) fantasy: read the ground, cut the angles, close the net. The only mode where the enemy is *running from you*.
2. **Core distinct mechanic.** A fleeing quarry (`FleeBehaviorModule`); win = **contain (hold an echo adjacent) for `contain_rounds` before the escape `window_turns` closes** (canon). Verb = **corner**, not kill.
3. **Echo autonomy.** Inject a **pursuit directive context**: high `objective_advance_priority` toward the quarry's *projected* cell, and a **fan-out heuristic** so echoes don't stack on one tile — bias different echoes toward different interception cells (flank). Reuse formation/`actor.move` weighting re-centered on the quarry; fastest echoes (Path/speed) lead.
4. **Objective actor.** **Mobile, evasive, actively escaping** — the only adversarial *objective*. Its motion creates the tension entirely.
5. **Why objective drives outcome.** The **`window_turns` timer** beats kill-all by default (quarry may be un-killable or flees faster than focus allows); containment is the path. **Lose:** window hits 0 or all echoes dead (canon).
6. **Map / placement.** Open-ish board with **terrain pockets/dead-ends** the quarry can be herded into; bridges become cut-off points. Quarry spawns far from the party.
7. **Failure & stakes.** It escapes — the lead is lost, the trail goes cold (Odo Agyanka erasure beat).
8. **Tuning.** `contain_rounds` 2–3; `window_turns` short enough to bite (e.g. 6–8) at low order; quarry speed ≥ party average. Scale: faster quarry, shorter window, larger board.
9. **Foundation vs later.** **Foundation:** flee module + containment win + pursuit directive context. **Later:** fan-out/herding interception heuristics (the elegant version), quarry that calls escorts.

---

## GUIDE_SPIRIT (escort) — walk it home (brief)

1. **Fantasy / feel.** *Shepherd a frightened thing through danger.* The most tender mode — a vulnerable spirit that must be brought through, embodying the caretaker core of the Ase Keeper.
2. **Core distinct mechanic.** Find the spirit, then **protect-in-place OR escort to a destination**; on escort, **50% chance it joins at a 75% damage debuff** (canon). Verb = **escort a moving protectee**.
3. **Echo autonomy.** Inject an **escort directive context**: a **vanguard** echo scouts ahead along the path (high `objective_advance_priority`), **rear/flank guards** keep `threat_interception` toward the spirit's *current* cell, and the formation re-centers on the *moving* spirit rather than a fixed point. Reuse PROTECT's interposition machinery but with a **moving anchor**.
4. **Objective actor.** **Mobile ally that travels** (or is held) and may fight at 75%-reduced damage — part protectee, part fragile companion.
5. **Why objective drives outcome.** The spirit advances toward the destination on a **long/winding board** (canon), so enemies along the route make "just kill everything" impossible to stay ahead of; the path *is* the clock. **Win:** spirit + ≥1 echo alive, OR successful escort + ≥1 echo (canon). **Reward:** chance the spirit becomes a **free summon if protected successfully** (canon) — directly feeding the Sanctum.
6. **Map / placement.** **Long, winding path** with ambush pockets; spirit travels start→destination; enemies seeded along the route, not in one clump.
7. **Failure & stakes.** Spirit dies en route — a death you were entrusted to prevent; the heaviest emotional loss of the seven.
8. **Tuning.** Path length + spirit move rate set the clock; ambush count along route scales with completion order. Spirit HP low (it relies on the screen). Join-chance/debuff per canon.
9. **Foundation vs later.** **Foundation:** find + protect-in-place + escort-to-destination win, moving-anchor screen (reuses PROTECT seams). **Later:** the 50% join + 75% debuff combat participation, free-summon reward wiring, vanguard/rear-guard role assignment heuristics.

---

## Implementation seam summary (so each mode is buildable, not just described)

All distinctiveness routes through **two existing arbiter seams** plus **per-mode encounter setup** — no new scoring engine:

1. **Mode directive-weight context.** Each resolution mode injects a `directive` dict into the arbiter context (the same channel Scout/Seek Signs use) keyed on the existing semantic keys (`objective_advance_priority`, `engage_only_blockers`, `threat_interception`, `ally_protection_bias`, `survival_bias`, `avoid_overcommit`). This is how echoes *interpret* the mode without being commanded — and it preserves Guidance over Control because the player's actual Directive still rides on top additively.
2. **Activate situational conditions.** Turn on the dormant stubs per mode: `near_friendly_structure`/`near_hostile_structure` (PURIFY/RECOVER/PROTECT), `_stub_objective_in_range` → `objective_in_range` (RECOVER hold), a new `objective_threatened` (PROTECT/GUIDE interpose), `_stub_enemy_bodyguard` → priority-target focus on a thief/blocker (PROTECT theft, RECOVER blockers).
3. **Per-mode encounter setup** in the resolution mode: objective actor type (invulnerable / carryable / mobile), placement vs chokepoint/lanes/path, and **reinforcement schedule** (the lever that makes kill-all impractical-by-default while still legal). All values live in `balance.json → data.combat.objective_modes.<mode>`, scaling by realm completion order.
4. **A few gated candidates** for the deep versions: `actor.carry_objective` (PROTECT), holder/escort move-targeting (RECOVER/PURSUE/GUIDE) — each gated exactly like the existing `actor.purify_shrine` override.

**The single highest-leverage change across all modes:** add **objective-seeking reinforcement** so the special condition (hold / survive / contain / escort / protect) is the *path of least resistance*, not the afterthought — turning the objective from scenery into the spine of the encounter.

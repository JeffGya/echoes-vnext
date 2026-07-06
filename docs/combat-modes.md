# Combat Resolution Modes — Design Spec

> The seven combat resolution modes are one family under the `combat` parent. Constants + terse comments
> live in `core/state/encounter/EncounterResolutionModes.gd`; the **authored design mechanics** live here.
> All seven play on **irregular landscape boards** (reusing `StageTerrain`) sized/scaled by **realm
> completion order**. Killing all enemies is a **universal win** in every mode. Introduced/expanded by
> V2-STAGE-004 Phase 3 (sub-phases 3a → 3 → 3b → 3c).

| Mode (const = value) | Objective type | Sub-phase |
|---|---|---|
| `COMBAT` = "combat" | combat | 3a (already live) |
| `PURIFY_SHRINE` = "purify_shrine" | shrine | already live |
| `RECOVER` = "recover" | recover | 3 |
| `PROTECT` = "protect" | protect | 3 |
| `ENDURE` = "endure" | endure | 3 |
| `PURSUE` = "pursue" | pursue | 3b |
| `GUIDE_SPIRIT` = "guide_spirit" | guide/escort | 3c (live) |

## Mode mechanics (authored design canon)

- **COMBAT** — not wave-based; beat a set of enemies. **Win:** all enemies defeated.

- **ENDURE** (was `SURVIVAL`) — survive a number of enemy waves; kill-all is **not** required. **Win:** at
  least one echo survives to the final round.

- **PURIFY_SHRINE** — a shrine sits at a random/hidden location; echoes must **first find** the hidden
  shrine, then protect it from enemy waves trying to destroy it. **Win:** shrine HP > 0 **and** ≥1 echo
  alive after all waves. Echoes with the right stats can **purify** (restore shrine health) as an action
  instead of attacking/defending — **only while the shrine is below 50% health**.

- **PROTECT** (was `PROTECT_TOTEM`) — like purify-shrine, but a **totem** that **can be carried (60% chance
  it is carryable)**. The carried totem **debuffs its holder**; specific classes/states **reduce the
  debuff**. Enemy waves try to destroy the totem, and **enemies can steal it — then deal double damage**.
  A game of placement and defence. **Win:** totem has health **and** ≥1 echo alive. After the stage there
  is a **chance the totem is rewarded to the player as an item** (V2-ITEM-002 seam).

- **PURSUE** (new, 3b) — a fleeing quarry (`FleeBehaviorModule`) runs from the party across a **4× long-dimension board** (randomised wide or tall per encounter seed; same `StageTerrain` organic rules). **No regular enemy group** spawns — the quarry is the only adversarial actor. The quarry wears a **gold diamond badge** overlay so it is immediately identifiable from regular echo/enemy tokens. Camera auto-follows the quarry; players can pan/zoom to override (resumes after ~3 s). Escape condition: quarry reaches the **far end of the long axis** (not any edge — short sides don't count) **or** `window_turns` timer expires — whichever fires first.
  **Win:** contain it (hold an echo adjacent) for `contain_rounds` consecutive rounds before the escape window closes.
  **Lose:** window hits 0, quarry escapes off the far-end edge, or all echoes dead.

- **GUIDE_SPIRIT** / escort (new, 3c — **live as shipped**) — find a **NameBank-named spirit**
  (`is_spirit: true`), then either **protect it in place** or **escort it to a destination**. The mode
  (protect|escort) and whether the spirit **joins the battle** are each a **seeded 50/50** roll per
  encounter. When it joins, the spirit is a **fully-active ally** (driven by `BehaviorArbiter`) with a
  **75% outgoing-damage debuff** (`spirit_damage_mul` 0.75); a joined spirit is excluded from the
  `all_echoes_dead` check and its HP bar is not suppressed.
  - **Protect (guard-to-count):** a **skittish** spirit flees 1 deterministic step away when an enemy is
    within `skittish_radius` (3) and no echo is adjacent. **Win:** `guide_protect_counter ≥ duration_turns`,
    where the counter advances **only** on rounds a living echo is within `escort_radius` (2) of the living
    spirit and **never resets** — a bare round timer no longer wins, so the party must actually **reach and
    stay by** the spirit. On this win the final snapshot sets `guide_spirit_protected: true` — the **free-summon
    reward seam** (V2-ITEM-002; flag only, reward wiring deferred).
  - **Escort:** the spirit steps 1 cell/round via `StageTerrain.next_step` toward a **seeded random walkable
    edge destination** — but **only** once `escort_started` (a first-adjacency latch) AND a living echo is
    within `escort_radius`; it waits if the next cell is occupied. **Win:** `destination_reached`
    (`spirit_escorted`), taking priority over `all_enemies_defeated`.
  - **Both:** spirit death → **immediate defeat** (`spirit_killed`, priority over the kill-win). The board is
    long/winding — `data.combat.board.guide_spirit_override.long_multiplier` (5.0), randomised wide or tall
    per encounter seed, scaled to realm completion order.

- **RECOVER** (new, 3) — a relic (`StructureActor`) is placed deep with enemies between. **Win:** hold an
  echo adjacent to the relic for `hold_rounds`. **Lose:** all echoes dead.

## Surprise (unscouted approach)
On an **unrevealed** approach (`stage_context.encounter_approach.situation_was_revealed == false`), apply a
small **party-fear bump at combat start** (`data.combat.encounter_approach.surprise_fear`). It degrades
readiness/intent through existing fear mechanics — **no initiative re-sort** (readiness is computed once,
V2-COMBAT-001).

## Tuning
Per-mode tuning lives in `balance.json → data.combat.objective_modes.<mode>` (read by resolution mode at
encounter start; a populated `ObjectiveModel.params` overrides it), with values scaling by realm completion
order. Board size/shape comes from `StageTerrain` + `data.stages.map_shape.by_virtue` + `data.combat.board`
(completion-order sizing).

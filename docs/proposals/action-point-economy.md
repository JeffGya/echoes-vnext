# Action-Point Economy — Unified Movement + Action Budget

**Status:** Proposed, **deferred to its own story**. Not rejected — deferred on sequencing grounds.
**Raised by:** Jeff, during V2-COMBAT-002 Slice 4
**Deferred:** 2026-07-20, at Slice-4 acceptance (suite 1233/1233)
**Current rule this would replace:** `docs/movement-model.md` §8.1 — "movement followed by a legal primary action"
**Affects:** V2-COMBAT-002 Slices 1–3 (merged), Slice 4 (dormant), Slices 5–6 (unstarted)

---

## 1. The idea

Today an activation has **two separate budgets**:

- **Capacity** governs movement only. It is derived by `MovementProfileService` under a frozen formula and spent per edge by `MovementExecutor`.
- **One primary action** follows movement — attack, purify, defend, pickup, guard — and is granted unconditionally, regardless of how far the actor moved.

The proposal is to collapse these into **one unified action-point (AP) pool**. Steps *and* actions would draw from the same budget: a step costs AP, an attack costs AP, a totem pickup costs AP, a purify costs AP. Running the pool dry would mean the actor **cannot act** — moving far would be a genuine, priced decision to forfeit acting.

## 2. Why it is a good idea

The current model has a real design weakness, and this proposal names it correctly.

- **Movement is currently almost free of opportunity cost.** An actor who sprints the full length of its capacity still gets the same full action as one that stood still. Distance is priced against *other movement*, never against *acting*.
- **It would make positioning a genuine tradeoff.** "Close the gap this turn and swing next turn" versus "step once and swing now" becomes a decision the simulation can express, rather than a foregone conclusion.
- **It unifies a vocabulary that is already half-unified.** Slice 4 made pickup a *primary action* rather than a free side effect of moving (`protect.totem_pickup`). That decision leans in the same direction the AP model points: things that cost the actor something should be priced in one currency.
- **It reads well against the game's tone.** A burdened carrier, a fear-strained Echo, or a spirit at the edge of its nerve should plausibly run out of *doing*, not just out of *walking*.

## 3. What it would change

This is not a tuning pass. It redefines a frozen contract.

**Contract-level:**
- `MovementProfile.capacity` currently means *movement capacity*, validated as a 0–6 envelope with a frozen derivation (`final = clamp(max(standing_capacity, aptitude_capacity), 2, 6)`). Under AP it would mean *total action budget*, and the 0–6 envelope would almost certainly be wrong — an AP pool must be large enough to price both steps and actions.
- `MovementIntent` carries a planned primary action and a declared fallback on the assumption that an action is always available. Under AP, "can I still act after this route?" becomes a route-validity question, not a post-hoc one.
- `MovementResult` would need to report AP spend, not just `voluntary_cost` and `remaining_capacity`.

**Service-level:**
- `MovementExecutor` — the per-edge spend loop, the `+1` hostile-control surcharge, the free-forced-displacement rule, and the Slice-4 authored-override step-allowance would all need re-derivation against a shared pool.
- `CombatActivationService` — the ordered pipeline (executor → revalidation → fallback → declared action) currently assumes the action stage is always reachable. Under AP it can legitimately be unreachable, which is a new terminal outcome, not an error.
- `MovementOptionService` / `BehaviorArbiter` — route scoring would have to weigh "this route leaves me unable to act", which is a materially different scoring problem from today's progress/exposure/cohesion metrics.
- `ProtectCustodyService` — the carrying burden is currently −1 *movement* capacity. Under AP, a burden is a tax on everything, including the attack that steals the totem back.

**Config:** `data.combat.movement.capacity` would need a full re-authoring, plus new per-action AP costs that do not exist anywhere today.

## 4. Ripple and risk surface

The honest reason this is not a Slice-4 change:

1. **It rewrites merged, accepted work.** Slices 1–3 are on `main` (PRs #45 / #46 / #47) with a frozen capacity formula that was explicitly negotiated and pinned. Slice 4 is dormant on top of it. An AP retrofit reopens all four.
2. **The test surface is large.** The suite is at 1233 tests. The movement contract, executor, activation, profile, option, arbiter, pressure, custody, and guide-spirit suites all encode capacity-as-movement semantics either directly or in fixtures. A retrofit invalidates a substantial share of them at once — which makes it impossible to tell a design change from a regression.
3. **It contradicts a stated design rule.** `docs/movement-model.md` §8.1 says every actor gets a primary action after movement. That is not incidental phrasing; it is the rule the whole activation pipeline is shaped around. Changing it is a design decision that deserves its own approval, not a side effect of a custody slice.
4. **The early-game math is genuinely bad without new tuning.** An actor at capacity 2 (Standing 1–2, no aptitude bonuses) would, under a naive AP pool, spend most of its budget taking a step or two and would **barely act at all**. The current model's floor exists precisely so that low-Standing Echoes remain participants. AP without a re-derived floor makes the early game worse, not deeper.
5. **It collides with the live cutover.** Slice 6 is a behavior-preserving cutover against a live baseline. Landing a semantics change in the same window would destroy the ability to attribute any behavior difference.

## 5. Open questions for the dedicated story

- What is the AP pool size, and does it still derive from Standing and aptitude, or from something new?
- What does a step cost relative to an attack? Is a step always 1 AP, or does terrain cost still apply on top?
- Does the hostile-control `+1` surcharge remain, and does it now potentially cost an actor its action?
- Is there a **guaranteed floor** — e.g. every actor may always take one action even at 0 AP — to protect the early game? If yes, how is that different from today's model in practice?
- How do burdens compose? Carrying is −1 today; is it −1 AP, a flat multiplier, or a per-action tax?
- Do free forced displacements stay free? (They must, or hazards start silently eating actions.)
- Does the arbiter need an explicit "reserve AP to act" preference, and is that identity-neutral or Calling-flavored?
- How is this presented to the player in Slice 6? A single pool is easier to read than two budgets — or harder, if actions have varying costs.
- What happens to `MovementProfile`'s frozen 0–6 envelope and its provenance fields?

## 6. Recommendation

Take it as its own story, sequenced **after** the Slice-6 live cutover.

The cutover needs a clean behavior-preserving baseline to prove itself against. Once live movement is running on the shared executor and the current model's weaknesses are observable in an actual played build, the AP question can be evaluated against real evidence — including whether low-Standing actors really do feel free-moving, and whether positioning really is as costless as it looks on paper.

Deferring it also means the AP story gets to do the tuning work properly: pool sizes, per-action costs, the early-game floor, and the presentation model, all in one pass, with a test suite rewritten deliberately rather than repaired under pressure.

**Nothing about the deferral is a judgment on the idea.** It is a good observation about a real gap in the current economy. It is being sequenced, not shelved.

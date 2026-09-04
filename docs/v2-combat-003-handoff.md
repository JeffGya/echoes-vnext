# V2-COMBAT-003 — Handoff

> **Status: phases 1, 2a and 2c are complete. The terrain work is approved and started.**
> Branch `claude/v2-combat-003-arbitration`, cut from `4b45b3e` on `main`.
> Worktree `.claude/worktrees/echoes-vnext-docs-review-e631bf`. Pass this path to `--path`.
> Plan file: `~/.claude/plans/mellow-cuddling-puddle.md`.
> Written 2026-08-31.

---

## 1. What this story is

One deterministic behavior-arbitration and explanation authority, and then the work to make its
output legible. The scope is the **sum** of the prompt scope and the live Notion scope. Jeff
approved that sum, and approved doing Half B first.

**Half A.** One authority resolves Align, Interpret, Hesitate, Object and Refuse. It consumes the
V2-PROG-012 outputs and derives none of them. It emits a typed causal Decision Trace.

**Half B (Movement Model Slice C).** The four deferrals from V2-COMBAT-002: the three inert scorer
fields, PURIFY_SHRINE positioning, the engage-region rule, and the `health_ratio` ladders.

Notion page `339c3d1e-de92-8190-ad52-ce3f2a0620c8`. Spec State **Open**, so the guidance-response
contract is not locked and must be confirmed before implementation.

---

## 2. Current state

| Metric | Value |
|---|---|
| Baseline at branch start | `Tests: 1519 total, 1519 passed, 0 failed`, 94 suites |
| Now | `Tests: 1536 total, 1536 passed, 0 failed`, 95 suites |
| Commits | 8 (6 story, 2 process) |

| Commit | Content |
|---|---|
| `207e5b4` | Phase 1 — characterization of eight defects |
| `6ef736f` | The sub-agent model-tier rule |
| `b04bd12` | The agent orchestration rules |
| `44671aa` | Phase 2a — the fingerprints watch each round's first actor |
| `1128417` | The handoff record |
| `4799e3f` | The configurable test save directory |
| `1b3badc` | Phase 2c — the placement guard (single isolated cell) |
| `1438789` | The region guard — supersedes the single-cell test |

**Tree is clean.** Every commit above is verified independently, not on a builder's report.

---

## 3. Approved decisions

Each decision came from Jeff in this session. Phase 13 writes each one to `ANSWERS.md`.

| # | Decision |
|---|---|
| 1 | **Scope.** Do all the work in one story: the prompt scope plus the Notion scope. Do **Half B first**. |
| 2 | **The five responses** use a **headless guidance source** — an internal contribution that only tests and one debug command operate. V2-COMBAT-004 later connects the real ping UI to the same interface. |
| 3 | **D97.** Limit the Absolute Fear Rule to `faction == "echo"`. An enemy keeps fear as an input to the score and never stops permanently. |
| 4 | **The movement stall** is corrected first, before all other behavior work. |
| 5 | **The visual is temporary.** Show Object and Refuse through the **existing** `BarkPopupDivergence` template. V2-COMBAT-004 removes it and puts a new UI in its place. **Add nothing to the Resolve screen** — it would crowd that screen. |
| 6 | **The bark budget.** Put the two new response contexts in tier 1. Keep `max_barks_per_round` at 3, mark it `PROPOSED DEFAULT`, and Jeff sets the final number during the manual test. Config only, so V2-COMBAT-004 re-tunes rather than deletes. |
| 7 | **The legacy selector.** Keep it, write a clear log for each use, and **make any use fail the test suite**. |
| 8 | **The action vocabulary.** Correct the label, and namespace the two unprefixed strings: `melee_attack` becomes `actor.strike`, `protect_ally` becomes `actor.protect`. |
| 9 | **The baseline may move.** The game is not live and the saves are disposable. Do not pay the additive-only cost. Prefer the correct foundation. |
| 10 | **The stranding defect.** Correct **both** causes — the placement function and the terrain generator — **placement first**, as separate commits. |
| 11 | **The fingerprint blind spot.** Correct it immediately, before phase 3, so no later re-record pins an incomplete guard. |
| 12 | **The Seer aura.** Measure the effect first, then decide. Do not compensate speculatively. |
| 13 | **Orchestration.** Model tier follows the difficulty of the work. Parallelize when safe. Verification is central and never self. Recorded in `AGENTS.md` and both `CLAUDE.md` files. |
| 14 | **Islands are a design feature. Keep them.** Do not filter them out of the generator. Removing them would make every realm board look the same. **This supersedes the original phase 2d.** |
| 15 | **Every island gets a moat.** No island may touch any other region, not even at a corner. A corner touch is the ambiguous case and it is being removed. |
| 16 | **Bridges are their own tile**, not an ordinary combat tile. Art comes later; a placeholder is acceptable now. |
| 17 | **The bridge threshold starts at 6 cells.** An island of 6 or more may be bridged, on a per-realm chance. Below 6 an island is always pure scenery. |
| 18 | **An island of 20 or more may get extra bridges** — up to one per side, each reaching a different neighbouring region, which may be another island. |
| 19 | **A bridge lands anywhere along an edge**, never fixed at the midpoint. |
| 20 | **Island size scales to board area.** Minimum 4. Some realms may reach 50. |
| 21 | **`straggler_*` config keys become `island_*`**, plus new size and bridge-chance keys. `relief` is preserved exactly — `CONVENTIONS.md` marks it as a reserved art seam. |
| 22 | **Nothing spawns outside the host region** — no Echo, no enemy, no objective. Floating island clusters are allowed and are pure scenery. |
| 23 | **The host region is chosen by playability, not size.** It must hold the party, the enemies and the objective, all mutually reachable. Largest is usually the answer but is not the rule. |
| 24 | **A static objective needs 8 free neighbouring tiles.** This is a **minimum, not a target** — prefer a more open spot when one exists. It doubles as the test of whether a region can host an objective at all. |
| 25 | **If no region can host an objective, the generator builds one** — a 9-tile site, one centre with eight around it. Log every occurrence as a count, so a realm whose island sizes are wrong shows up as a number. |
| 26 | **Combat board scaling is out of scope** for this story. Recorded as a follow-up. |

---

## 4. Corrections to the source documents

**Read this section before trusting a claim from Notion or the defect register.** Each item below
was verified in the code.

| Claim, and where it is written | The truth |
|---|---|
| Notion: "Do D27 first" — log the movement decision | **Already fixed.** V2-INFRA-003 pass 7 logs `goal_id` and `option_id` on `actor.moved` at `LiveMovementContextService.gd:552-553`. The register, written later, supersedes the Notion note. |
| Register D97: an enemy "never gets a rank" | **Wrong mechanism.** `EnemyActor.gd:56` sets `rank` to 1. The conclusion still holds: rank 1 gives the band `nascent` and therefore the raw threshold 65, against a grounded Echo's 80. |
| Register: the stall happens when a goal is "not routable **within its 2-cell capacity**" | **Wrong mechanism.** The truncation helper is sound. The real cause is that **no route exists at all**, because the actor stands on unreachable ground. Refer to section 5. |
| `CONVENTIONS.md`: `BarkPopupLayer.enqueue_barks(Array)` | **No such function.** The real one is `show_barks(bark_events)`. Phase 13 corrects the document. |
| The prompt: align the action types to `docs/movement-model.md` §9 | **§9 is the PURPOSE vocabulary, not the action vocabulary, and it is already implemented.** All thirteen words are the keys of `_PURPOSE_FALLBACK_ALLOW` at `CombatActivationService.gd:110` and ride live as `movement_purpose`. `action_type` is a different layer: §9 is why the actor moved, `action_type` is what it did on arrival. Renaming one onto the other would collide two vocabularies. One collision already exists — `actor.withdraw` is a Ranger skill and `withdraw` is a §9 purpose. |
| Notion: the 2026-08-29 addendum has three parts | It has **two** findings: the movement stall, and D97. |
| `AGENTS.md`: 90 registered suite names | There are **95** now. |

---

## 5. Measured findings

None of these came from a passing test.

### 5.1 An actor can be placed on ground it can never leave

The chain, each link verified:

1. `StageTerrain.gd:323-334` mints "straggler" cells from the 8-direction neighbours of walkable
   ground, **without applying its own edge rule**.
2. `StageTerrain.is_legal_edge` at `:432-463` rejects a diagonal whose two orthogonal side cells are
   both solid. A straggler placed diagonally off a plateau corner therefore has **no legal edge**.
3. `GridService.place_actors` at `:242-289` fills each faction from walkable cells in sorted order
   **with no connectivity check**, so an Echo takes the leftmost column first — where such a cell
   sits.
4. The movement layer is then **correct**. No route exists, so it truthfully returns no option.

Measurements:

| Measurement | Result |
|---|---|
| Boards with at least one disconnected cell, 60 for each shape | 34 to 46 of 60 |
| Live encounter setups that stranded a real Echo | 2 of 45 |
| The stranded encounter, driven through real dispatch | 15 rounds, `goals=3, options=0`, zero cells moved, morale 41 down to 1 |

**RESOLVED 2026-09-01, and two of these numbers were wrong.** The caution was justified. Re-measured
under the legal-edge rule:

- The "34 to 46 of 60" figure came from boards generated with **no realm setting at all** — the probe
  built `ConfigService` fresh, which returns an empty balance, so it exercised the generic fallback
  and described a board type the game never makes. **Do not use that number.**
- A second measurement gave 30 of 280 (11 %) through the real path — but sampled **realm.01 Courage
  only**, which the per-virtue table later showed is one of the two least island-prone settings.
  **Also unrepresentative.**
- The components are **not** all one cell. Cut-off regions reach 86, 97, 104 and 115 cells — that is
  half a board, not an island.

The authoritative measurement is section 12.1: 1,800 boards, all ten virtue settings. Islands are
common on Wisdom and Humility and rare on Acceptance and Truth. **The lesson repeats one already in
memory: a probe that does not mirror production construction invalidates its own headline.**

### 5.2 Unreachable ground has three sources, not one

| Source | Mechanism |
|---|---|
| Stragglers | `_adjacent_candidates` at `:1035-1058` applies no edge rule |
| Plateau erosion | `_is_8_connected` at `:1002-1028` is a plain flood fill, so erosion can leave two cells joined only by a diagonal with both corners removed |
| Bridging | `_flood_fill_components` at `:807-853` is also plain 8-direction, so two plateaus touching only at a corner count as connected and are never bridged |

Bridges themselves are safe. The "at least two cells wide" guarantee **does** hold in
`_make_bridge_rects` at `:855-914`, and the test that asserts it is a true assertion.

**SUPERSEDED 2026-09-01 by decision 14.** Unreachable ground is now a *feature* and will not be
eliminated. The three sources still matter, but their treatment changed: an accidental split
(erosion, bridging) is **repaired**, while a deliberate island is **kept and moated**. See section 12.

### 5.3 Phase 2d moves no RNG draw

Each straggler derives its **own** stream, `prefix + ".straggler.%d" % sk`, at `:328`, and makes
exactly one draw at `:332`. Filtering the candidate list changes which cell that draw selects. It
does not change the number of draws and it does not touch any other stream.

**Therefore: filter the candidates. Never redraw.** A reject-and-redraw loop would consume an
unbounded, data-dependent number of draws and would move the seed sequence.

### 5.4 The `actor.idle` label, separated at last

| Board | Turns labelled `actor.idle` | Turns with no position change |
|---|---|---|
| Healthy | 15 | **6** |
| Stranded | 15 | **15** |

So on a healthy board, 9 of 15 labels are false. The cause is `LiveMovementContextService.gd:556-557`,
which sets `action_type` to `actor.idle` whenever no primary action resolves — even though
`actor.moved` logged a real path ten lines above.

### 5.5 The fingerprints had a blind spot

`combat.confirm_round` resolves the **first** actor of the round itself. `_drive_and_capture`
dispatched it and then sampled only `combat.next_actor`, so the first actor of every round was
simulated and never captured. One Echo was first in initiative every round of a four-round trace
and appeared in **zero** captured turns.

Corrected in `44671aa`. Turns gained: COMBAT +5, PURIFY_SHRINE +4, RECOVER +2, PROTECT +4,
ENDURE +5, PURSUE +5, GUIDE_SPIRIT +9 — one for each round. The move was proven additive.

### 5.6 The four inert scoring terms — THREE FIXED in phase 6, the fourth measured

`_spatial_utility` has 11 terms. The live producer sent literal `0.0` for `exposure`, `congestion`
and `cohesion`, which also killed a fourth term, because `directive_exposure_acceptance` multiplies
`exposure`.

Phase 6 connected the three fields to the existing `MovementOptionService._exposure`,
`._congestion` and `._cohesion` — no new implementation was written. Measured on the current tree,
across all seven modes:

| Term | Weight | Before | After | Decisions it changes |
|---|---:|---|---|---|
| `exposure` | −6.0 | 0.0 on every option | 0.0 or 1.0 (2 samples of 0.5 in 454) | 29 turn lines |
| `cohesion` | 4.0 | 0.0 on every option | 5 distinct values, 0.0–1.0 | 22 turn lines |
| `congestion` | −2.0 | 0.0 on every option | 5 distinct values, 0.0–0.5 | 19 turn lines |
| `directive_exposure_acceptance` | 2.0 | inert by consequence | now multiplies a live `exposure` | **0** |

**`exposure` is very nearly binary in live combat.** Routes near contact are one step long and
capacity floors at 2, so the ratio `controlled_edges / path.size()` collapses to 0 or 1. The −6.0
weight is therefore a flat "this route enters hostile control" penalty, not a gradient.

**`directive_exposure_acceptance` is still decision-inert, and the field being filled is not the
reason.** `exposure_acceptance` is authored on `directive.seek_signs` only (0.20); the default
`directive.scout_carefully` does not carry the key at all. Forcing `seek_signs` and then zeroing
`directive_exposure_acceptance_weight` changed **zero** turns across all seven modes: at
2.0 × 0.20 × 1.0 the term is worth at most +0.40 against `exposure`'s −6.0 and
`objective_progress`'s 8.0, so it never flips a ranking. The term is connected and honest; it is
too small to decide anything. Left alone — phase 10 owns tuning.

**No weight was changed.** Every mode still resolves in every arm (base, exposure off, cohesion
off, congestion off, acceptance off, seek_signs), so nothing met the revert condition, and there is
no measurement that would justify moving an authored value.

**One agent reported these terms as live.** It had read the pure service and missed the live
producer. Do not repeat that error.

Reproduce any of this with `tools/SpatialTermProbe.gd`: `-- tests spatialprobe <arm>`.

### 5.7 `terrain_costs` is empty in live combat

`LiveMovementContextService.gd:160` passes `{}` as the 10th argument to `MovementContext.build`,
which is `terrain_costs`. Every cell entry therefore costs the default 1.

**This is not a defect.** `docs/movement-model.md` §15.1 states that production terrain is still
binary walkable, so empty is truthful. It is load-bearing for section 5.3's reasoning, because with
no terrain cost and a capacity floor of 2, the first step of any route is always affordable.

---

## 6. Findings recorded, not yet owned

Each is pre-existing and outside the stated scope. **Do not correct one quietly inside another
change.** Bring the numbers to Jeff and let him place it.

| Finding | Evidence |
|---|---|
| **The contribution ledger counts five action types only.** All eight skill actions, plus `protect_ally`, `actor.purify_shrine`, `actor.taunt` and `actor.retreat`, increment **nothing — not even `total_count`**. A turn spent on a signature calling skill is erased from the denominator of `melee_share` and `guard_share`, which inflates both and distorts courage and wisdom experience. | `ContributionLedgerService.gd:191-196` |
| **The taunt bonus is unreachable.** `CONVENTIONS.md` documents a +25 pull toward a taunting Echo. `taunted_by` is **read** in two places and **written nowhere** in `core/` or `ui/`. | `BehaviorArbiter.gd:2208-2211` |
| **An enemy can be placed on an Echo's cell.** `_assign_walkable_faction` builds a fresh `assigned` dictionary for each call, so the Echo pass and the enemy pass cannot see each other's cells. | `GridService.gd:305` |
| **An actor with a live option can still stand still.** Measured: 3 turns of 19 on a healthy board, with `options=1` every turn. The winning candidate was not isolated. This is a **different defect** from the stranding, and it produces the same screen. It belongs to the phase 8 arbitration work. | Not isolated |
| **`actor.interact` is dead.** Zero producers anywhere in the tree. | `CombatService.gd:58` |
| **Two fixtures are not production-shaped.** They skip `EmotionService.init_echo` and `VectorService.init_vectors`, which is the `ANSWERS.md` entry 50 defect. Phase 2b corrects them. | `FlowFingerprintTests._setup_encounter`, `BehaviorCharacterizationTests._echo_actor` |

---

## 7. The phases

| Phase | Work | Tier | State |
|---|---|---|---|
| 1 | Characterization, eight defects pinned | `sonnet` | **Done** `207e5b4` |
| 2a | The fingerprints watch each round's first actor | `sonnet` | **Done** `44671aa` |
| — | The configurable test save directory | `sonnet` | **Verified, not committed** |
| 2b | Production-shaped fixtures | `sonnet` | Queued |
| 2c | The placement guard (single cell) | `sonnet` | **Done** `1b3badc`, superseded by the region guard `1438789` |
| 2d | The terrain generator | — | **Superseded.** Replaced by the terrain design in section 12 |
| 3 | The Whole-band baseline scenario | `sonnet` | Not started |
| 4 | Limit the refusal to an Echo | `sonnet` | Not started |
| 5 | The action vocabulary | `opus` table, then `haiku` rename | Table produced, needs approval |
| 6 | The three inert terms | `opus` | **Done** — three connected, the fourth measured and left |
| 7 | Purify, engage region, `health_ratio`, the step before an attack | `opus` | Not started |
| 8 | The arbitration and explanation authority | `opus` | Design produced |
| 9 | The temporary visual and the bark budget | `sonnet` | Not started |
| 10 | Tuning, the legacy selector, D57 | `opus` | Not started |
| 11 | Reviews and the full regression | `opus` | Not started |
| 12 | The manual test with Jeff | — | Blocks the commit |
| 13 | Documentation, Notion, commit, PR | `sonnet` | Not started |

### The immediate next steps

1. **Terrain commit 2** — connectivity by shared side. See section 12.7.
2. **Terrain commits 3, 4 and 5**, serial, each with its own attribution.
3. **Phase 2b**, the production-shaped fixtures.
4. Then phases 3 onward, unchanged.

---

## 8. The phase 2c and 2d designs

### 2c — the placement guard

Use `StageTerrain.legal_neighbors(cell, walkable, bounds)` at `:466-484`. It already delegates to
`is_legal_edge`, and the movement layer already uses it, so a guard built on it cannot disagree with
movement. **Do not write a third helper.**

`GridService` already has everything it needs. `walkable` is read at `:242`, and bounds are the two
values already computed at `:220-221`. Note the key names differ: `StageTerrain` uses `w` and `h`,
`board_cfg` uses `board_cols` and `board_rows`.

Change `_assign_walkable_faction` at `:292-336` to a three-pass fill:

1. The existing ordered pass, but skip a cell whose `legal_neighbors` is empty.
2. The existing sorted drain, with the same filter.
3. **A new final pass with no filter**, so an actor is never dropped when every remaining cell is
   isolated. Placing an actor somewhere it cannot walk is bad. Dropping it from the encounter is
   worse.

`GridService` is pure static and has no logger, so the warning belongs at the call site,
`EncounterSetupService.gd:392`, which has `logger` in scope. That warning should be silent in
practice, so it doubles as a live alarm for phase 2d.

**The guard adds zero RNG draws**, so `CONVENTIONS.md`'s guarantee that the walkable branch makes no
draw stays literally true. Assert it directly: record `rng.state` before and after and require it to
be unchanged.

### 2d — the generator

Filter inside `_adjacent_candidates`. Evaluate a candidate against `walkable_cells` **plus the
candidate**, because `is_legal_edge` requires the source cell to be walkable. A post-hoc filter over
the built set is wrong: it would either shrink the straggler count below the authored range, or
require a redraw.

The filter is conservative and never wrong in the unsafe direction, because adding cells only ever
adds edges. A cell accepted at step `k` cannot be made illegal by a later straggler.

**The order is correct as approved, on one condition: phase 2d's probe must measure the terrain,
not a played encounter.** The placement guard sits downstream of generation and cannot influence a
terrain-only probe. Measured the wrong way, the guard would hide the generator defect.

The generator fix alone would **not** make the placement guard unnecessary. `GridService` is a public
pure-static service that accepts any walkable dictionary from any caller, and two of the three
sources of unreachable ground are not addressed by the straggler filter.

---

## 9. Environment facts and traps

- **The suite takes about 7 minutes.** Pass `timeout: 600000` on the Bash call. `300000` truncates a
  healthy run and looks like a hang.
- **The runner always exits 0.** Only the `Tests:` line is evidence, and **the logger adds a prefix
  to it**. Do not anchor a search pattern to the start of the line. I nearly declared a healthy run
  truncated for exactly this reason.
- **Rebuild the import cache before believing any fingerprint failure.**
- **Delete the save directory before every run.**
- **`ECHOES_TEST_SAVE_DIR`** now sets the save root, and the default reproduces today's behavior
  exactly. **It does not make every parallel Godot run safe.** Two processes in one worktree still
  share the `.godot/` import cache, and a run that registers a new `class_name` writes to it. An
  agent that adds a new `class_name` must still run alone.
- **The retreat roll is tick-bound.** Any change to the dispatch count on the path into an encounter
  re-rolls every retreat in the game.
- **Do not drive `flow.new_game` in a test.** It uses `Crypto.generate_random_bytes()`. Drive from
  `boot()`, which uses the pinned seed.

---

## 10. How the work is being run

- **Model tier follows the difficulty of the work**, not a build-versus-review split.
- **Parallelize when three conditions hold:** disjoint files, no shared exclusive resource, and
  disjoint recorded values. The third matters even when the files differ — two agents re-recording
  the same constants destroy attribution.
- **A builder never verifies its own work.** An independent agent verifies where two agents' work
  merges.
- **Never accept a completion report as evidence.** Audit the tree.
- **After any agent stops, killed or completed, audit read-only before re-dispatching.** One agent
  was killed mid-task and left a file whose own comment claimed seven constants had been re-recorded
  when they had not.

### What this produced today

- A `sonnet` agent concluded the reported stall did not exist. An `opus` verifier then reproduced it
  and found the real cause. **Both steps were necessary.**
- An agent reported the three scoring terms as live. It had read the pure service and missed the live
  producer. Verified false.
- Two of the orchestrator's own briefs contained errors that agents caught: phase 5 was sent out on a
  misreading of the movement model, and the phase 2 diagnosis was given to the wrong tier.

---

## 11. Not yet decided

| Question | Who decides |
|---|---|
| The ten per-realm island settings in section 12.5 | Jeff, in play. They are proposed defaults |
| The Seer `idle_fear_aura`, once the label is corrected | Jeff, after the fear measurement |
| Where the contribution-ledger coverage gap belongs | Jeff, when phase 5 reaches that code |
| The final `max_barks_per_round` | Jeff, during the manual test |
| The five `response_thresholds` values | Measure the guidance-contest distribution first |
| The four commitment band cut points | No measured basis exists yet. Flag to the reviewer. |

---

## 12. The terrain design — approved 2026-09-01

This section supersedes the original phase 2d. That phase was going to filter islands out of the
generator. **Jeff rejected that**: islands are variety, and removing them makes every realm board
look the same. The defect was never that islands exist. It was that actors were placed on them, and
that the generator called things islands which were not.

### 12.1 What the measurement showed

Measured across 1,800 generated boards, ten virtue settings, connectivity judged by a **full shared
side** (Jeff's rule — a corner touch does not count).

| Island size | Count |
|---|---:|
| 1 cell | 819 |
| 2 cells | 17 |
| 3 to 5 cells | 3 |
| **6 to 10 cells** | **0** |
| 11 to 25 cells | 3 |
| 26 to 50 cells | 8 |
| 51 to 100 cells | 15 |

**838 of 865 islands (97 %) touch the main ground at a corner. Only 27 are true islands.**

Two conclusions follow, and both drove the design.

**The threshold chose itself.** The distribution is bimodal with an empty 6-to-10 bucket. 839 islands
are 5 cells or smaller; 26 are 11 or larger. Any threshold from 6 to 10 gives the same split. 6 was
taken.

**Realms do not differentiate today.** The only per-realm control is *how many* single-cell bumps to
add. There is no control over size or shape, so every realm produces the same feature in different
quantities. Jeff called this out directly.

### 12.2 Why 97 % touch at a corner — the root cause

A "straggler" today is **one cell, chosen from the 8-direction neighbours of existing walkable
ground** (`_adjacent_candidates`, `StageTerrain.gd:1035`). By construction it always touches the
board. It can never be an island. That single choice produces all 819 of them.

### 12.3 The generation order

Order is what makes an accidental split separable from a deliberate island. No heuristic is needed.

1. Plateaus are built.
2. **Accidental splits are repaired — always.** A board erosion broke in half is bridged back
   together. This guarantee already exists in the code and **never fires**, because
   `_flood_fill_components` (`:807`) uses plain 8-direction adjacency, so two halves touching at one
   corner are counted as already connected. Correcting that adjacency to a shared side is the fix.
3. Decorative extra bridges, as today (`bridge_density`).
4. **Islands are placed last** — moated by construction, sized per realm.
5. An island of 6 or more is bridged on a per-realm chance.

### 12.4 The reachability guarantee, and why it is free

Jeff requires that a route always exists to the region holding the objective — which in survival and
ordinary combat is the enemy spawn.

This holds **by construction**:

- A bridged island becomes part of the host region. That is what bridging means, and it chains:
  if B bridges to A and A bridges to the mainland, B is reachable too.
- Everything that spawns is placed in the host region (commit `1438789`).

Therefore an unbridged island can never hold an objective or a spawn. **The bridge chance is free to
be random**, because no random outcome can make a battle unwinnable. This is worth keeping in mind:
if bridging were the thing guaranteeing reachability, a low chance would sometimes break a map.

### 12.5 The proposed per-realm settings

**PROPOSED DEFAULTS.** Jeff tunes these in play. Minimum size is 4 everywhere.

| Virtue | Character | Islands | Size | Bridge chance |
|---|---|---|---|---|
| Acceptance | settled plains | 0–1 | 4–6 | 0.0 |
| Truth | stark expanse | 0–1 | 6–12 | 0.2 |
| Courage | open flats | 1–2 | 4–8 | 0.3 |
| Forgiveness | two shores | 1–2 | 12–30 | 0.8 |
| Leadership | central hub | 2–3 | 5–12 | 0.7 |
| Generosity | — | 2–3 | 4–10 | 0.6 |
| Compassion | — | 2–3 | 6–16 | 0.6 |
| Empathy | — | 3–4 | 5–14 | 0.5 |
| Wisdom | sunken archipelago | 4–6 | 8–50 | 0.6 |
| Humility | scattered low | 5–7 | 4–20 | 0.4 |

### 12.6 Downstream consumers — check every one

**The terrain generator does not only make combat boards.** The same terrain drives the venture and
explore screen (`FlowStageState.gd:163`, `StageExploreScreen.gd:823`). An objective on a moated
island is unreachable **in exploration** exactly as it would be in combat. Both must be covered.

**Terrain is persisted.** `FlowStageExploreState.gd:68` calls it "permanent geometry — must survive
session reset", and `SaveService.gd:1294` repairs it. An old save holds an old-rules board. Saves are
disposable, so this is a clean break — but state it, do not discover it.

**Two traps for the rename:**

- `walkable_set` (`:380-410`) builds the walkable set from **three** keys — plateaus, bridges,
  stragglers. Rename the key without updating that function and **every island silently vanishes**
  from the walkable set. Nothing fails loudly.
- `CONVENTIONS.md:961` marks `relief` as **reserved** for future per-realm art, keyed on realm id and
  virtue. Do not lose or rename it.

**Bridges are already distinct in the data** — the terrain dict keeps `plateaus`, `bridges` and
`stragglers` as separate lists. They lose their identity only at render time: `walkable_set` flattens
all three, and `CombatBoardScreen._draw_board` paints every walkable cell with one tile. Making a
bridge a special tile is therefore **additive**, not a new system.

### 12.7 The remaining commits

Each moves recorded board values. Each is its own commit with its own attribution. **Serial, never
parallel** — two at once would make it impossible to say which change caused which movement.

| # | Change | Tier | State |
|---|---|---|---|
| 1 | Region-based spawn guard; the two warning causes split | `sonnet` | **Done** `1438789` |
| 2 | Connectivity by shared side; accidental splits repaired | `opus` | **Done** |
| 3 | Islands replace stragglers — moated, sized, per realm; config rename | `opus` | **Done** |
| 4 | Bridges as their own tile; extra bridges per side above 20; edge placement | `sonnet` | Queued |
| 5 | Host region by playability; objective clearance; the 9-tile compensation | `opus` | **Done** |

### Commit 2 — what it did, and what it measured

`_flood_fill_components` now joins two cells only when they share a full side, the repair
anchors on the **host** region (largest, ties by numerically lowest col,row — the same rule
`GridService._largest_walkable_region` uses), and it bridges every cut-off region of
`connect_min_region_cells` (**6**, authored on all eleven `map_shape` entries) or more. The
threshold is a real signature key, not a constant: a test drives it to 999999 and watches
split boards reappear.

Measured with `tools/TerrainRegionProbe.gd` (`-- tests terrainprobe`), 1,800 boards per
regime, ten virtue signatures, before and after:

| Regime | Boards | Cut-off region >= 6 cells, before | After |
|---|---:|---:|---:|
| Combat board, 12x12..22x22 | 1,800 | 10 (humility 8, wisdom 2; max 42 cells) | **0** |
| Explore map, 30x30..50x40 | 1,800 | 93 (every virtue; max 176 cells) | **0** |

Small islands survive as designed: 1,143 cut-off regions of 1–2 cells remain on the combat
regime and 1,601 on the explore regime.

**One recorded value moved: `GUIDE_SPIRIT_ROUNDS_HASH`.** Six of the seven mode fingerprints
did not. On that board (60×12) the two plateaus were disconnected under both the old and the
new rule, so the bridge count is unchanged — the repair simply picks a different cell pair
now, moving the L-bridge and adding 8 walkable cells, which shifts the ordered placement fill.
`FINAL_HASH` and `SAVE_HASH` did not move. `traversal/fog_scout_wider_than_seek` also needed
a repair, and it was a defect in the test: its own comment said an early Scout arrival is an
acceptable degenerate case, but only the mirror case (Seek arriving early) was implemented.
The reshaped board made the unimplemented branch reachable.

**Commit 2 carried a termination risk, and it is discharged.** The repair loop bridges until
every substantial region is joined. Under the corrected adjacency rule it had to be **proven**
that a 2-wide bridge really connects. It does: the two legs of an L-bridge do not merely touch
at the corner. The horizontal leg always contains row `ar` and the vertical leg always
contains column `bc` — the rect clamp can only pull a span toward its endpoint, never past it
— so cell `(bc, ar)` lies in BOTH legs. They share a cell, so their union is shared-side
connected and contains both endpoints. `terrain/bridge_connects_shared_side` sweeps every
relative orientation, both board edges, bridge widths 2 and 3 and both corner orders — 2,880
cases — and asserts exactly one region containing both endpoints. Non-host regions can never
gain a cell (every bridge cell touches the host), so the count of substantial non-host regions
strictly falls each pass. The ceiling survives as a safety net and now `push_error`s instead
of quietly returning a split board.

### Commit 3 — what it did, and what it measured

A straggler was **one cell taken from the 8-direction neighbours of existing ground**, so by
construction it touched the board and could never be an island. That single choice produced all
of it: 819 of 865 cut-off regions were a single cell, and 838 of 865 touched the main ground at a
corner. Islands now replace them.

**Three properties, each by construction and each asserted by a test.** *Moated:* an island may
only occupy cells outside the 8-direction **dilation** of everything walkable so far, recomputed
before each island, so no island cell touches any other region — mainland or island — at a side
or a corner. *Multi-cell:* growth adds only cells sharing a full side, minimum **4**, and a blob
that cannot reach 4 is **discarded rather than emitted**. *Sized to the board:* authored size is
a **request**, clamped to `area/16` per island and `area/4` for all islands together, floor 4 —
so wisdom's authored 8–50 gives at most 9 cells per island on a 12×12 board and its full range on
an explore map. Compactness comes from preferring the frontier cell with the most 8-direction
contacts; the RNG only breaks ties, so islands are blobs and not one-cell-wide worms.

Config renamed on all eleven `map_shape` entries and in `_FALLBACK_SIGNATURE`
(`straggler_count_min/max` → `island_count_min/max`, plus `island_size_min/max`, all **PROPOSED
DEFAULT**). RNG namespace `{prefix}.straggler.*` → `{prefix}.island.*`; an island makes several
draws where a straggler made one, but every draw stays on **its own** stream. `relief` is
untouched on all eleven entries. `GridService` is untouched.

**`walkable_set` still reads the legacy `stragglers` key**, deliberately. Not to preserve an old
campaign — saves are disposable — but because dropping it is **silent**: an already-saved board
would simply lose ground, with no error and no failing test.

Measured with `tools/TerrainRegionProbe.gd` (`-- tests terrainprobe`), 1,800 boards per regime,
ten virtue signatures, combat bounds now **including the doubled 12×48 and 60×12** shapes:

| Island size bucket | Before (cut-off regions) | After, combat | After, explore |
|---|---:|---:|---:|
| 1 cell | 1,104 | **0** | **0** |
| 2–3 cells | 43 | **0** | **0** |
| 4–5 | 3 | 504 | 543 |
| 6–10 | 0 | 1,624 | 1,788 |
| 11–25 | 0 | 1,327 | 1,782 |
| 26–50 | 0 | 88 | 589 |

**Realms differentiate by size, not only by count.** Mean island size, combat regime: acceptance
4.9 (max 6), courage 5.9 (max 8), generosity 6.9, leadership 8.3, truth 8.8 (**min 6** — it never
makes a small one), empathy 8.9, compassion 10.2, humility 10.2 (1,008 islands, the most),
wisdom 14.3 (max 44), forgiveness 18.0 (max 30). Wisdom's max of 44 rather than 50 **is the
area clamp visible in the data**.

| Acceptance criterion | Result |
|---|---|
| Islands touching any other region at a corner **or** a side | **0** of 3,543 combat and 4,702 explore islands |
| Cut-off regions of ≥ 6 cells among **plateaus and bridges** — commit 2's guarantee | **0**, both regimes |
| Islands below 4 cells | **0** — impossible by construction |
| Actors stranded (existing region guard, `GridService`) | Unchanged; nothing spawns off the host region |

**One recorded value moved: `STAGE_EXPLORE_FINGERPRINT_HASH`.** All seven combat mode
fingerprints, `FINAL_HASH`, `SAVE_HASH` and `SANCTUM_FINGERPRINT_HASH` did **not**. On that board
the payload diff is exactly one pair of lines — `terrain.stragglers` (one cell at 22,4) replaced
by `terrain.islands` (two 2×2 blobs) — while `terrain.plateaus` and `terrain.bridges` are
**byte-identical**, which is the direct evidence that no earlier RNG stream and no part of the
repair moved. The combat fingerprints hold for a structural reason: an island never joins the
host region, and `GridService` places every actor inside the host region, so combat placement is
now driven purely by plateaus and bridges.

### One scope addition, measured before it was made: `entry_cell`

`StageTerrain.entry_cell` took the leftmost column of the **whole** walkable set. That was safe
only by accident — a straggler touched ground at a corner, and the explore layer's own
reachability rule (`bfs_distance_field`) is a plain 8-direction fill, so a corner touch was
genuinely walkable in exploration even though the generator's stricter shared-side rule called it
cut off. **A moated island is cut off under both rules.** Plateaus never occupy column 0
(`_BORDER_MARGIN`); islands may.

Measured A/B on the same 1,800 boards per regime, before and after the island rewrite:

| Entry cell lands off the host region | Combat bounds | Explore bounds |
|---|---:|---:|
| Before commit 3 | 158 / 1,800 (all 8-direction reachable, all harmless) | 144 / 1,800 |
| After commit 3, old `entry_cell` rule | **766 / 1,800** | **867 / 1,800** — every one a dead start |
| After commit 3, host-anchored `entry_cell` | **0** | **0** |

`entry_cell` now anchors to the host region — the same rule the repair and
`GridService._largest_walkable_region` use. It makes **no RNG draw**, before or after. The
`stage_explore` fingerprint board demonstrates it concretely: the full set's minimum column moved
from 8 to 0 because an island occupies (0,19)–(1,20), and `party_pos` stayed at (8,13).

### Left open by commit 3 — for commit 5, stated not discovered

`RealmGenerator._place_situations` places a situation on **any** walkable cell. Commit 3 raises
the share of walkable cells lying off the host region to **10.8 %** (combat bounds) and **11.9 %**
(explore bounds) — and, unlike before, those cells are now genuinely unreachable under the explore
layer's 8-direction fill as well. That is the per-situation probability of landing somewhere the
party cannot reach, **objectives included**, which makes a stage uncompleteable. Commit 3 does not
fix it; decisions 22–25 assign host-region placement and objective clearance to **commit 5**, and
commit 4's bridging will reduce it further. It is a real gap in the tree between commit 3 and
commit 5 and should not be rediscovered as a surprise.

### Commit 5 — what it did, and what it measured

Decisions 22, 24 and 25, on **both** consumers. Terrain commit 3 left a stated gap: 10.8 % of
walkable cells (combat bounds) and 11.9 % (explore bounds) lay off the host region, and two
placement paths ignored it. `RealmGenerator._place_situations` picked any walkable cell —
**objectives included**, which makes a stage uncompleteable — and `GridService.place_on_terrain`
sorted free cells by distance to a target column with no connectivity check at all.

**One host-region authority, not two.** `GridService._largest_walkable_region` became public as
`largest_walkable_region` and `RealmGenerator` calls it. No third region helper was written.
Measured: a shared-side host cell outside the legal-edge host on **0 of 1,800** boards per
regime, so `StageTerrain.entry_cell`'s shared-side host always sits inside the region situations
are placed in.

**Decision 24 is a ranking, not a veto.** Eight walkable free neighbours is the minimum; the
depth intent still chooses among the cells that clear it, and openness over the 5×5
neighbourhood breaks the distance tie the bare `(col,row)` tie-break used to settle arbitrarily.
The ally gets the host filter and **no** clearance context — it is a combatant that wants the
cell nearest the party, not the most open one.

**Determinism.** Not one RNG path was added, removed or reordered. `_place_situations` keeps its
`pos.P` → `wpos.P` → `fallback` + `fallback_walkable` structure exactly; only what a tier
*accepts* changed, and each tier derives its own stream from its own fixed path string, so a
tightened predicate cannot shift any other draw. The `fallback_walkable` pool is now **sorted
numerically** by `(col,row)`; it used to be raw Dictionary key order, which leaked generation
order into the output. `place_on_terrain` and the objective-site chooser make **no** draw at all.

Measured with `tools/TerrainRegionProbe.gd` (`-- tests terrainprobe`), 1,800 boards per regime,
ten virtue signatures, combat bounds including the doubled 12×48 and 60×12, driving the **real**
`_place_situations` and the real `collect_unoccupied_cells` → `place_on_terrain` pattern:

| Acceptance criterion | Combat before | Combat after | Explore before | Explore after |
|---|---:|---:|---:|---:|
| Situations off the host region | 1,146 / 9,000 | **0** | 1,110 / 9,000 | **0** |
| Objective situations off the host region | 392 / 3,600 | **0** | 408 / 3,600 | **0** |
| Objective situations without 8 walkable neighbours | 1,629 / 3,600 | **0** | 2,059 / 3,600 | **0** |
| Combat objectives off the host region | 33 / 1,800 | **0** | 137 / 1,800 | **0** |
| Combat objectives without 8 walkable free neighbours | 331 / 1,800 | **0** | 1,376 / 1,800 | **0** |

**Rule 25 fired 0 times, on all ten virtues, on all 3,600 boards.** That is the number the owner
asked for and it is a real finding, not a missing measurement: every generated board already
offers a legal objective site, so the compensation is a guarantee rather than a repair in daily
use. It is worth keeping precisely because the next island-size tuning pass could change that,
and the count is how the owner would see it.

**Two recorded values moved, each attributed on a concrete board.**

`GUIDE_SPIRIT_ROUNDS_HASH` / `GUIDE_SPIRIT_FINAL_HASH`, and with them
`combat_baseline/emotion_trace_guide_spirit`. Measured with a temporary print in
`_run_mode_fingerprint`, run on this tree and on `b4dd797`: the **terrain did not move** —
223 walkable cells both, identical plateaus, identical bridges, identical islands, no
`objective_site_built` key — and every Echo (col 9, rows 8/5/1/6/2) and the enemy (47,3) keep
their exact cells. **One actor moved**: the guide spirit, (23,1) → (17,5). The cause is decision
24 alone: on that board (23,1) has `clearance=false` and (17,5) has `clearance=true`, while the
host filter is inert because the host region is all 223 walkable cells. Six columns closer to a
party at col 9 means the spirit is protected three rounds sooner, so the emotion trace went from
nine rounds to six — and **the six that remain are byte-identical to the first six recorded
before**, a strict prefix. `SAVE_HASH` did not move; the outcome is still `spirit_protected`.

`STAGE_EXPLORE_FINGERPRINT_HASH`. The payload diff is exactly one hunk: `situations` goes from
`[]` to one entry — `sit.1`, type `loot`, non-objective, now at (11,10) and therefore inside the
party's opening reveal radius. Every other line, terrain included, is byte-identical.

**The other six combat mode fingerprints, `FINAL_HASH`, `SAVE_HASH` and
`SANCTUM_FINGERPRINT_HASH` did not move.**

**What could not be proved.** The combat objective defect is still **not observed in a real
encounter** — it never was; section 12.7 recorded it as possible, not triggered. The
`combat_terrain/objective_never_lands_on_island` test reproduces the mechanism directly on a
hand-built moated board (it asserts the unfiltered call *does* return the island, then that the
filtered one does not), but that test cannot compile against `b4dd797` because it calls the new
API. The two tests that **do** fail against `b4dd797` are the explore-path ones, and their real
output is pasted in the commit message. Decision 24 is also implemented as a preference only on
the combat path, where a ranking already exists; on the explore path an accepted objective site
always meets the full 8/8 minimum, but among equally legal sites the draw stays uniform rather
than preferring the more open one.

### 12.8 Independent verification of terrain commit 2 (orchestrator, not the builder)

The builder measured combat bounds as **12x12 to 22x22 only**. That range **excludes the doubled
boards** — PURSUE uses 12x48 and GUIDE_SPIRIT uses 60x12 — which are exactly the shapes where the
86, 97, 104 and 115 cell splits were originally found. Its combat incidence figure is therefore
understated, and its "splits are rarer than section 12.1 implies" caveat applies to standard boards
only.

Re-measured on the doubled shapes after the fix: **1,800 boards, all ten virtues, zero cut-off
regions of 6 or more cells, worst case 0.** The repair holds on the shapes that motivated it.

**Both measurements are right about different populations.** Standard combat boards rarely split;
doubled and explore-scale boards split often. Quote the shape along with the number.

Structural checks done directly on the commit, not taken from the report: `core/realms/StageTerrain.gd`
is the only `core/` file touched, `GridService.gd` is untouched, and exactly one recorded constant
moved (`GUIDE_SPIRIT_ROUNDS_HASH`).

### 12.9 The bridge rate defect, and two pieces of scope held back

**Jeff rejected the first bridge rates: forgiveness configured 80 % delivered 44 %, leadership 70 %
delivered 50 %.** A configured chance that cannot be met is a broken control, not a tuning knob.

**Cause, measured across 1,800 boards.** The moat guarantees a gap of at least one void cell, so a
gap of exactly **one** is the commonest island geometry there is — not a rare edge. But
`_ISLAND_BRIDGE_MIN_SPAN` was 2, so an island one cell offshore could not be bridged on any ray.
Share of unbridged eligible islands sitting at gap 1: **forgiveness 90 %, wisdom 92 %, leadership
83 %, humility 80 %**. The floor was the whole shortfall.

**Why the floor existed.** `terrain/bridge_width_min2` asserted `min(w, h) >= 2` on every bridge
rect, and a one-cell span produces a `1 x bridge_width` rect. **That assertion conflated two
different rules.** A crossing's WIDTH (across it) must be at least two — that is the traversability
guarantee. Its LENGTH (along it) may be one; the cells still share full sides with both ends. The
L-shaped connectivity bridges still need two in both dimensions, because their corner-sharing
termination proof depends on it.

**Fix:** span floor 1; island bridge rects carry an explicit `across` field; the test asserts the
width rule on island bridges and the both-dimensions rule on connectivity bridges.

| Virtue | Configured | Before | After |
|---|---:|---:|---:|
| forgiveness | 80 % | 44 % | **78 %** |
| leadership | 70 % | 50 % | **65 %** |
| wisdom | 60 % | 43 % | 56 % |
| generosity | 60 % | 61 % | 70 % |
| compassion | 50 % | 49 % | 55 % |
| empathy | 50 % | 40 % | 49 % |
| humility | 40 % | 32 % | 40 % |
| courage | 30 % | 20 % | 23 % |
| truth | 20 % | 13 % | 16 % |

Extra bridges on islands of 20 or more rose from 37 to 66 on wisdom — those islands were hitting the
same wall. No recorded value moved: the fingerprint boards draw no island bridge.

### 12.10 HELD SCOPE — two decisions from Jeff, deliberately not built

Jeff stated both while the rate defect was being fixed, and said to hold them if they grow the scope.
They do. **Neither is built. Both need a story.**

| Held item | What Jeff said | Why it is not in this story |
|---|---|---|
| **Per-realm moat width** | "a moat of 1 is just a threshold — moats can and should be bigger depending on the realm" | A new authored design dimension. Needs a config key per realm, changes island placement everywhere, and moves every board value again. It is a feature, not a repair. |
| **Bridges of any length and shape** | "bridges can be as long as they need to be and shaped however they need to be" | Island bridges are straight axis rays cast from four sides. Arbitrary routing — L-shapes, dog-legs, longer spans around obstacles — is a routing problem, not a threshold change. It would also raise the bridge rates further on the realms still under target. |

The length half of "as long as they need to be" is **partly** addressed: the minimum is now honest.
The maximum is still whatever a straight ray finds, and no ray bends.

---

## Approved 2026-09-03: calling-aligned maturity bands + re-spaced refusal thresholds

Jeff's three answers, all approved:
1. Fix the virtue-domain reader gap inside V2-COMBAT-003 (not a separate story).
2. Adopt the calling-aligned bands, AND re-space the thresholds ("relabel and re-space").
3. Defer the presence inversion to phase 10.

### Why the bands changed

`band_by_standing` was NOT from the GDD. The GDD contains no maturity bands at all -- no
nascent/forming/grounded/whole. GDD 11.4/11.5 describe wholeness as a continuous rise:
"an autonomous Echo should become more interpretable and more willful as wholeness rises."

The old table saturated at Standing 4: ranks 4-9 were ALL "whole". Its own config comment
says ranks 6-9 were BACKFILLED by V2-PROG-012 because only 1-5 were ever defined and a
fallback was silently covering the gap. So "whole at 4" was never designed -- it was the
edge of an unfinished table.

Supporting evidence for the calling alignment: `data.combat.movement.capacity.standing_bands`
is ALREADY aligned to the calling ladder (min_standing 1 -> 3 -> 6). The maturity bands were
the outlier, not the model.

Correction to a common assumption: the ladder is **9**, not 10. `rank_strength_scale.max_rank`
is 9; rank_strength = (rank-1)/8. Ten realms and ten virtue domains, nine Standings.

### The approved values (mark both PROPOSED DEFAULT)

band_by_standing:  1-2 nascent | 3-5 forming | 6-8 grounded | 9 whole
refusal_thresholds_by_band:  nascent 65 | forming 80 | grounded 88 | whole 95
  (was 65 | 72 | 80 | 90)

Measured effect of the COMBINED change (relabel alone was rejected -- it moved 7 of 9
standings ALL toward easier refusal, up to -18):

  Std 1  65 -> 65   (--)
  Std 2  72 -> 65   (-7)
  Std 3  80 -> 80   (unchanged -- the re-spacing protects it)
  Std 4  90 -> 80   (-10)
  Std 5  90 -> 80   (-10)
  Std 6  90 -> 88   (-2)
  Std 7  90 -> 88   (-2)
  Std 8  90 -> 88   (-2)
  Std 9  90 -> 95   (+5, HARDER -- 'whole' finally means something unique)

Largest single movement 10 points, against 18 under relabel-alone.

### KNOWN CONSEQUENCE -- accepted by Jeff, revisit after a play test

`data.voice.reactive_min_expression_band` is "forming". Today that gates reactive barks at
Standing 2+. Under the new mapping it becomes Standing 3+.

Jeff's ruling: "Note the barks consequence for now, we might need to change this after a
test. You are right we should not have nascent and forming echoes be barking the whole time
and having tons of opinions."

So: keep the gate value as-is, ship the shift, and re-examine after the phase 12 manual test.

---

## Approved 2026-09-03: finish V2-PROG-004 inside V2-COMBAT-003

Jeff: "Do it inside this story." The sweep grew the piece from five dead passives into
completing a story that was marked Done too early.

### The record was wrong
`docs/v2-migration-map.md:169` says V2-PROG-004 is Done with "6 V2 IDs active in all backend
systems". FALSE. Marked wrong in the map rather than editing history.

### Five commits, serial, each its own blast radius
1. The two duplicate `_dominant_key` copies (CombatState.gd:331 initiative, ShrineService.gd:147
   purify). Same defect `1bf2730` fixed in GridService. Plus the concealing tests.
2. `data.combat.initiative_modifiers.by_calling_origin` V1 -> V2.
3. The five dead per-calling passives (ActorStateMachine V1 calling match).
4. The stale Ranger "Scout Ahead" (`data.stages.calling_action_bonuses.ranger` + code).
5. Migration map corrections.

### Commit 2 needs no invented values -- except one
The V1 initiative table maps 1:1 by identity onto the already-migrated placement sibling,
values unchanged: blade->aduro 3.0, warder->okofor -1.0, ranger->kra_soro 1.0,
steward->onyamesu -2.0, seer->okomfo 0.0, uncalled 0.0.

Only `sum_okwanfo` is new (the sixth calling did not exist in V1).

**JEFF'S DECISION: sum_okwanfo initiative = 3.5, the FASTEST calling.**
His words: "sum_okwanfo should be a bit quicker I see the calling as assasin/rogue type. So
speed and agility is important here." Grounded in the GDD, which describes Sum-Okwanfo as
moving "through concealment and timing" -- timing IS initiative. 3.5 places it above Aduro's
3.0 and inside the system's range (archetypes reach 4.0). Mark PROPOSED DEFAULT.

**Deliberately NOT changed:** sum_okwanfo's *placement* modifier stays 2.0. Placement decides
the starting column, not speed. Flagged to Jeff as a separate call rather than swept in.

### Note: the vector half of initiative was already migrated
`initiative_modifiers.by_dominant_vector` already lists all ten V2 vectors with a ten-way
tiebreak comment. So "initiative is dead" is too broad -- only the CALLING term scores zero
for every V2 calling. It also shows the commit-1 defect from the other side: the config
documented ten vectors while CombatState.gd:139 passed the legacy four to the reader.

### Tests that CONCEAL these defects -- fix with the code they cover
`GridTests.gd:338` and `CombatStateTests.gd:216-238` author their OWN V1 `by_calling_origin`
tables, so they stay green after balance.json is corrected. Nothing in 1,559 tests could have
caught the initiative gap. Also: CombatSupportLedgerTests.gd:203, CooldownTests.gd (5 sites),
BehaviorArbiterTests.gd:458, StageObjectiveTests.gd (5 sites) construct V1 calling ids directly.

### No fourth family
Archetypes (9 V2 ids both sides), directives, vector_to_calling, traits, morale tiers -- all
verified clean. Damage bounded to vectors and callings.

---

## TODO before the story closes: comment cleanup pass (Jeff, 2026-09-03)

"Keep a note that we need to clean up the comments in earlier phase 2/3 work towards the end.
That is way too much comments against actual code."

Rule now recorded as AGENTS.md entry 28 (commit `705c12e`). This pass applies it retroactively
to work committed BEFORE that entry existed.

**Measured — added lines in .gd files per commit:**

    commit    comment+  code+  ratio  subject
    3a554f8       27      12   2.25   a bridge may be one cell long
    44671aa       52      25   2.08   fingerprints watch the first actor
    1bf2730       56      27   2.07   a dominant key is picked from scores
    20f0124       71      56   1.26   fixtures get the vector init
    70ffa81      100     188   0.53   a Whole-band Echo exists in the suite
    55f0b3d       69     129   0.53   second and third dominant-key copies
    1438789      159     323   0.49   the region guard
    1b3badc      107     224   0.47   the placement guard
    b4dd797      286     635   0.45   islands replace stragglers
    483c26d      349     779   0.44   bridges are their own tile
    94bfc9c       29      67   0.43   Absolute Fear Rule / enemy gate
    3ad5e6a      261     623   0.41   connectivity by shared side
    207e5b4      134     325   0.41   phase 1 characterization
    95895a0      223     667   0.33   nothing spawns off the host region

    TOTAL ~1,923 comment lines added on the branch.

**Priority: the four above 1.0.** More comment than code is indefensible at any complexity.

**What to strip, per entry 28:**
- The same point at the call site AND in the docstring -> keep it once, at the authority.
- Sentences restating the next line.
- Story-id narrative ("V2-PROG-003 grew the vectors from 4 to 10") -> commit message only.
- Measurement tables inside source -> handoff/docs, with the comment pointing there.

**What to KEEP -- do not strip these:**
- The ring-guard rule (b) explanation in StageTerrain: a bridged island is still an island. A
  future edit would plausibly "simplify" it back into the bug.
- `_ISLAND_BRIDGE_MIN_SPAN`'s width-vs-length distinction: the test previously conflated them.
- `directive_bonus` must stay OUTSIDE the fear/calling bracket in BehaviorArbiter._score() --
  divergence detection depends on it and no test would fail.
- `_dominant_key`'s "tiebreak only, every key is a candidate" -- once, in the docstring.

The large terrain commits (~0.4) are lower priority: generation invariants are genuinely subtle
and the comments mostly earn their place. Judge each, do not sweep by ratio alone.

---

## 14. The V2 calling migration, finished inside this story

Five commits. The sweep that found them started as a one-function fix.

| Commit | What |
|---|---|
| `1bf2730` | `GridService._dominant_key` reads the scores, not the tiebreak list |
| `55f0b3d` | The second and third copies of that defect (`CombatState`, `ShrineService`) |
| `c444662` | `initiative_modifiers.by_calling_origin` V1 → V2; `sum_okwanfo` 3.5 |
| `fcb5cf0` | Five per-calling passives finally match callings that exist |
| `20d922d` | Kra-Soro Scout Ahead reachable in config and code |

### Skills were NOT affected — checked, not assumed

`SkillDefinition.gd` records that **V2-PROG-005 removed `calling_requirement`; the V2 axis is
`skill_family`.** Skills are keyed by one of six families, and `calling_constellation` maps callings
to families in fully V2 terms. There is no calling id for production to fail to match, which is
exactly why this defect class never reached them.

The eight V1-sounding skill ids (`warders_vigil`, `seers_sight`, `rangers_mark` …) are **legacy
names, not stale references** — each carries a correct `skill_family` and is reachable today.
Presenting "Warder's Vigil" to an Okofor is a lore/UX inconsistency for Jeff, not a defect.

### Findings recorded, deliberately not fixed

| Finding | Evidence |
|---|---|
| **Onyamesu `_stationary_rounds` has no reader anywhere.** Grows unbounded (1,2,3…90). Its comment calls it "soft-taunt eligibility" — a feature never built. Write-only forever. | `fcb5cf0` probe |
| **Kra-Soro `_withdraw_cooldown` never blocks.** The turn-start decrement runs before the reader checks it, so it has always cleared. Pre-existing in already-V2 code. | `fcb5cf0` probe |
| **The Okomfo aura fires EVERY idle round**, no cooldown. Ally fear 40 → 0 in ~13 rounds. | `fcb5cf0` probe |

### A conclusion of mine that the aura finding overturned

During phase 5 research I told Jeff the `actor.idle` label fix would be **fear-neutral**, because
`idle_fear_aura` fired zero times. That was true then and is **false now** — `fcb5cf0` made it live.

The aura fires on `action == "actor.idle"`, and 53 % of those labels are false (a moving turn wrongly
labelled idle). **So the label fix now genuinely removes fear relief, and Jeff's original instruction
— measure the fear curve before and after, then decide — stands.** Do that when phase 5 lands.

---

## 15. Scope drift, and what is deferred — Jeff, 2026-09-04

> "I want the current story to be focused, we have drifted a lot."

**Measured on the branch: 27 commits. 8 terrain, 6 V2 calling migration, 6 docs/process.
Roughly 7 are the story's own phases.** Every detour was approved and each fixed a real defect that
the story's own work stands on — but the story is named *one deterministic behavior-arbitration and
explanation authority*, and **none of that has been built yet.** Phases 5 to 13 remain.

**No further scope may be added without Jeff's explicit approval.** A defect found from here is
recorded here and filed, not fixed in passing.

### 15.1 DEFERRED — the bark side-chat, at the END of this story

Jeff: *"let's start a side chat for barks at the end of this story to tackle these and other issues
that might arrive."* **This is the full bark backlog. Add to it rather than fixing in passing.**

**The surface that exists today** — do not rebuild it, it works:

| Piece | Where |
|---|---|
| `BarkPopupLayer.show_barks(bark_events)` | `ui/screens/combat/BarkPopupLayer.gd:56` |
| `resolve_template_kind(bark_context, is_response)` | `BarkPopupLayer.gd:129` |
| Three authored templates — `BarkPopupOriginal`, `BarkPopupReaction`, **`BarkPopupDivergence`** | `BarkPopupLayer.tscn` |
| `NarrativeVoiceService.apply_round_bark_budget()` | `core/echoes/NarrativeVoiceService.gd:289` |
| `ActorStateMachine._check_reactive_bark()` — V2-VOICE-001 same-faction ally response | `ActorStateMachine.gd:841` |
| Config: `max_barks_per_round` 3, `bark_tiers` 1-3, `reactive_range`, `reactive_high_signal_contexts`, `reactions_exceed_cap`, `max_reactions_per_original`, `sanctum_max_barkers` | `data.voice` |

**The backlog:**

| # | Item | Evidence |
|---|---|---|
| B1 | **`reactive_min_expression_band` is dead config.** Authored in `data.voice`, **read nowhere**. The real gate is hardcoded `if _expression_band == "nascent": return` in `_check_reactive_bark()`. Same family as the Okomfo aura — authored intent nothing reads. | verified 2026-09-04 |
| B2 | **The reactive gate shifted Standing 2+ → 3+** as a side effect of the band remap. Jeff accepted it — *"we should not have nascent and forming echoes be barking the whole time and having tons of opinions"* — and wants it re-examined after a play test. | `c01509e` |
| ~~B3~~ | **BACK IN THE STORY (Jeff, 2026-09-04): phase 9 stays.** *"Keep phase 9 in the story, if that requires us to do more extensive bark work then we have to do it."* **Phase 9's temporary visual.** Object and Refuse route to the **existing** `BarkPopupDivergence` template via a set test in `resolve_template_kind()`. Marked temporary; V2-COMBAT-004 removes it. **Nothing on the Resolve screen** — it would crowd it. | decision 5 |
| ~~B4~~ | **BACK IN THE STORY — see B3.** **The bark budget.** Two response contexts into **tier 1**, so a response always shows and outranks emotional or situational barks. `max_barks_per_round` stays 3, marked PROPOSED DEFAULT. **Jeff sets the final number during the phase 12 manual test.** Requirement: more than one response must be possible in a round. | decision 6 |
| ~~B5~~ | **MOOT.** It only mattered if `melee_attack` were renamed, and Jeff **dropped the rename** on 2026-09-04. `combat_attack` and `combat_inspired` keep working untouched. | phase 5 decision |
| B6 | **Fold into phase 13**, which already updates the documentation. **`CONVENTIONS.md` documents an API that does not exist** — `BarkPopupLayer.enqueue_barks(Array)`. The real function is `show_barks(bark_events)`. Phase 13 corrects the document. | handoff §4 |
| B7 | **The Okomfo `idle_fear_aura` writes a bark-adjacent log** (`actor.fear_idle_aura`) and now fires **every** idle round with no cooldown. Whether it should announce itself, and how often, is a voice question. | `fcb5cf0` |

**Revised 2026-09-04.** Jeff kept phase 9 in the story, so **B3 and B4 return to it**, B5 is moot
because the rename was dropped, and B6 folds into phase 13's documentation pass. **Three items
remain for the side chat: B1, B2 and B7.**

B2 gets its evidence for free — phase 12 *is* the play test after which Jeff wanted the reactive
gate re-examined.

The consequence of keeping phase 9: the story now delivers both halves — the arbitration authority
**and** a player who can see it. That is the story as written. It also means the bark surface gets
touched here rather than later, so anything phase 9 needs from B1 is fair to pull forward.

### 15.2 Leadership — LEFT AS IS

The band remap moved `is_whole_leader()` from Standing 4+ to Standing 9 only, because it tests for
the `whole` band. Jeff considered a graduated model (always at 9, weaker and rarer below) and ruled:
**"leadership seems to work as expected"** — no change. Recorded so the shift is not re-discovered
later and mistaken for a defect.

### 15.3 APPROVED, pending — extend fear relief to `forming`

**Why.** Veteran refusals rose (B3: 0 → 3, peak fear 62 → 100) after the band remap. Jeff's test was
*why*: **"If it is fear based then its not good. If it is about choices or actions or directives not
aligning with them then it is better."**

It is fear. **The Absolute Fear Rule is the only refusal path in the game** — `fear >= threshold`.
No directive-misalignment refusal exists yet; that is what phase 8 builds.

The cause is a double hit on Standing 3-5, which were `whole` and are now `forming`:

| Relief | Gate |
|---|---|
| `self_regulate` +3 morale/round | `grounded` or `whole` |
| `suppress_panic_spiral` +5 threshold | `grounded` or `whole` |
| Last-stand threshold bonus | `grounded` or `whole` |

They lost every one **and** dropped from threshold 90 to 80. They are not braver; they lost their
support and broke.

**Approved fix:** extend the relief gates to include `forming`. **Keep the approved thresholds
unchanged.** This separates how resistant an Echo is from whether it gets help — only the first
should scale steeply. Sites: `ActorStateMachine.gd` ~:257, ~:264, and `EmotionService.gd` ~:281.

---

## 16. FINDING — `resist_fear` cannot reach combat fear (recorded 2026-09-04, not fixed)

Found while verifying `9fb369e`. **Pre-existing, not caused by that commit.** Jeff's instruction
stands: no further scope without approval, so this is recorded, not actioned.

### The gap

`resist_fear` reduces an incoming fear delta by 40 %. **Exactly one function reads it** —
`EmotionService.apply_fear_delta()` (`:283`).

Combat's per-hit fear does not go through that function. `CombatTurnActionService.gd:190-193`
calls `LeadershipEmotionService.apply_fear_gain()` and then writes `target["fear"]` directly:

```gdscript
var hit_fear_applied := LeadershipEmotionServiceScript.apply_fear_gain(
    target, fear_per_hit, ectx.actors, leadership_expr_cfg)
target["fear"] = mini(100, _fear_before + hit_fear_applied)
```

`apply_fear_gain` never consults `resilience_traits` or `expression_band`.

**So an Echo with `resist_fear` gets its reduction on contact-fail bleed, weave, vow and Sanctum
ticks — and nothing at all on being hit in a fight, which is where nearly all combat fear comes
from.** The trait reads as protective and is decorative in the place that matters most.

This is the **mid-combat direct write** that `AGENTS.md` documents as the one approved exception to
`EmotionService` being the emotion choke point. The exception is now bypassing two things: the choke
point, and a trait that only the choke point can apply.

### Same family as two other findings on this branch

| Finding | Shape |
|---|---|
| Okomfo `idle_fear_aura` (fixed, `fcb5cf0`) | Authored config a V1/V2 name mismatch made unreachable |
| `reactive_min_expression_band` (deferred, B1) | Authored config **read nowhere**; the real gate is hardcoded |
| **`resist_fear` (this)** | Trait read by one function that combat's main fear source never calls |

All three are authored intent that never reaches the thing it was written for, and **none produced a
failing test** — the suite cannot see a trait that silently does nothing.

### Why B3 could not demonstrate the fear-relief fix

Recorded so the null result is not later read as the fix failing. `9fb369e` widened three relief
gates to `forming`. Scenario B3's deterministic party carries `self_regulate` x3 and `resist_fear`
x2, **no** `suppress_panic_spiral`, and never reaches last-stand. Two gates had nothing to attach to,
and the third cannot reach melee fear at all. A3 *did* move — peak fear 32 → 25, three of five Echoes
at threshold 85 instead of 80, which is `suppress_panic_spiral` firing at `forming` for the first
time.

**Compounding factor: the probe cannot vary party composition.** `EchoFactory.generate(seed_tag, …)`
makes the party a function of the first two characters of the seed tag, so `seed_variant` — the
documented way to sample several campaigns — does **not** resample traits or callings. Every
per-trait and per-calling measurement on this branch rests on one party per label.

### Three questions for Jeff, when he wants them

1. Should `resist_fear` apply to combat hits? It is currently decorative where it matters most.
2. Is the mid-combat direct write still the right exception, now that it bypasses a trait as well as
   the choke point?
3. Should the probe be able to vary party composition? It caps the evidence for every trait and
   calling measurement we take.

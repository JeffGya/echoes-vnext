# V2-COMBAT-002 Slice 6 — Delivered Work & Decisions (6A → 6E)

> **HISTORICAL — record only, nothing here is executable.**
> V2-COMBAT-002 is closed. Slice 6 shipped via PR #51 (6A), PR #52 (6B+6C) and PR #53
> (6D+6E); `d1df649` is the story-close commit.

Written 2026-07-23, after Phase 6A shipped, as a handoff to the agent picking up 6B–6E.
The execution plan it carried (build steps, branch names, verify commands, gotchas) was
spent once the story closed and has been removed — several of those instructions had
gone actively wrong. What remains is the part with lasting value: what 6A delivered and
the design decisions taken at the time.

**For what actually landed** — which differs from the 6A-era plan in places — see
`docs/project_systems_audit.md` § combat, `docs/movement-model.md`, and PRs #51–#53.
**For current conventions**, `AGENTS.md` and `CONVENTIONS.md` are authoritative.

---

## State at the time of writing

- Story V2-COMBAT-002, final slice (Slice 6 = live cutover of the movement layer).
- Slices 1–5 shipped. The movement layer under `core/movement/` was fully DORMANT.
- **Phase 6A done, in PR #51** (`feat/v2-combat-002-slice-6a`, commits `46ed833` +
  `886a9a3`). Dormant contract + config prep. Suite at that point: 1274/1274, 0 failed.

## What 6A delivered

- `MovementGoal` purpose/plan rules fixed: place-directed `advance` (empty target +
  `objective.<semantic>` source, semantic-token-gated per the Codex fix in `886a9a3`);
  `escort`/`protect` accept `protect_ally` or untargeted `actor.guard`; `withdraw`
  admits guard/idle (the §8.3 "forfeit" attribution was RETRACTED — it stays UNOWNED,
  belongs at action resolution, carry it if you touch withdraw).
- `GuideSpiritActivationService` emits validatable goals (escort→`advance`/`actor.move`,
  protect→`withdraw`/`actor.move`, no-step→`hold`/`actor.guard`). Behaviour unchanged.
- Config seams live in `data.combat.movement.pressure` and `.slack`; `step_budget`
  fallback unified on `DirectiveService.DEFAULT_STEP_BUDGET`.
- **Pulled forward from 6C's original scope:** manhattan criterion removed; the biased
  lexicographic tie-break replaced by a salted **FNV-1a/32** hash (`_salted_cell_hash`,
  `select_frontier(..., salt: String = "")`); the old characterisation test deleted and
  replaced with a no-systematic-compass-bias + replay-determinism test. `select_frontier`
  took both `heading` and `salt` parameters but was not yet fed from live state — 6B/6C
  subsequently wired that up.

## Decisions taken (do NOT re-litigate)

1. Stage chaining **re-plans per hop** (fog lifts before the next hop plans).
2. Cold-start bias fixed via the **mirror-covariant / salted-hash guard** (done in 6A).
   The honest caveat holds: two candidates related by a mirror of both board and party
   are genuinely indistinguishable; the goal is removing *systematic* compass preference.
3. `select_frontier` returning `{}` **maps explicitly to Tier 4**.
4. **ENDURE** is served by the generic ordinary-combat path + board fallback under
   `COLLAPSE_HEALTH`; NO `_add_endure`. Add a test pinning board fallback as health collapses.
5. Slack: contract keeps 2/0.25 as the invariant floor; only the adapter is seamed
   (done in 6A). Config may NARROW, never widen.
6. Presentation is a **MINIMAL STOPGAP ONLY** — the sole goal is "tokens must not cut
   through walls." NO hazard feedback, NO activity text, NO death beat. The full
   treatment stays with COMBAT-004. (Jeff chose the stopgap, not the fuller §3 option.)
7. Three PRs.

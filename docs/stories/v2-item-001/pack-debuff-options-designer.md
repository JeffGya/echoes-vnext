# Pack debuff options (designer view)

Written in STE. Everything here is a PROPOSAL except the cited facts. Jeff decides.

## Facts that bound the question

| Fact | Source |
|---|---|
| A full pack already limits Echo choices on the next path. "The real pressure is lost room." | `decisions.md` D-17 |
| A carried pack is "a deliberate disadvantage": fewer free slots. | `decisions.md` D-16 |
| Held pieces draw again on an early leave. A defeat empties the pack. | `decisions.md` D-19, D-20 |
| Pack size is 4 and is config. Warning levels exist: 0 none, 1 light, 2 heavy, 3 full. | `data/balance.json:3742`, `InventoryService.gd:59-72` |
| Pieces can move between pack and Sanctum anywhere in the Sanctum. One discard per path. | `decisions.md` D-33 |
| Research: DD2 stops the run on a full cart; XCOM 2 states the loss before the commit. No game found with a stat penalty for a full pack. Evidence level is LOW. | `research-comparison.md` pitfalls table |

Key insight: the player can empty the pack for free before a path (D-33 moves). So any penalty on a full pack is a penalty the player chose to keep. This makes a penalty less needed and easier to feel unfair.

## Option A: no mechanical penalty (adds zero systems)

Rule: a full pack only costs what D-16, D-17, D-19 and D-20 already cost.

What carries the tension instead:
1. Lost room. With a full pack, a new find has no slot. The player must discard or skip.
2. Risk of loss. Held pieces roll again on an early leave and vanish on defeat. The Sanctum is the only safe place.
3. Pack size. 4 slots makes each slot a real choice.
4. Warning. The existing level 2 and level 3 states show the risk before departure.

Proposal to make it work with no new rule: on the party prep pack, show held pieces with an "at stake" mark. Show the line "These can be lost on a defeat or an early leave." once at departure.

What the player feels: "I am carrying something I could lose." This is a choice about greed, not a handicap. The player never feels the game punished a mistake. The cost is only felt if the player does not read the mark.

Failure mode: the player parks pieces in the pack and never feels a cost until a defeat. The loss then feels late. Fix is the mark and the line, not a rule.

Build cost: near zero. Copy and one mark. Already half built (`pack_load`).

## Option B: morale nudge at path start (one new number)

Rule: when the party leaves with a pack at level 3 (full), each Echo starts the path with a small morale loss.

- Reuses: `EmotionService.apply_morale_delta` (`core/emotion/EmotionService.gd:244`), which is the only valid morale entry. The status tier is derived from morale, so no new display (`CONVENTIONS.md` 378-417 range).
- New state and numbers: one config value (`pack_full_morale_delta`, for example -5) and one cause string `pack_full`. No new save field if applied once at path start.
- Player learns it: the existing emotional status tier of each Echo drops, and the departure line says "A full pack weighs on the party."
- Failure mode: it duplicates the `burdened` tier name (fear 45 or more). The words will confuse players. It also hits all Echoes for one player choice, and a small morale change may flip a tier boundary that is not visible. A quiet exploit: move one piece out, leave at 3 of 4.
- Build cost: small. One call in the path-start flow, one config value, one cause string, tests for the draw order not changing (no RNG used). Needs a copy decision from Jeff.

## Option C: carried pieces shift the leave roll (two new numbers)

Rule: each held piece from an earlier path lowers the weight of the "all" outcome on an early leave a little.

- Reuses: `data.rewards.carry_odds` weights and `carry_shares`, settled by `StageSettlementService.settle_leave` (`CONVENTIONS.md:925`). Scout already multiplies those weights and renormalises, so a modifier path exists.
- New numbers: a per-held-piece weight shift and a floor. Odds stay hidden from the player (existing rule, `CONVENTIONS.md:925`).
- Player learns it: only by feel. The leave screen would say "A heavy pack makes a clean exit harder." Hidden odds make this hard to read.
- Failure mode: worst of the three. It stacks a second penalty on D-19, which already rolls each held piece. The player is taxed twice for one choice. Hidden odds make it feel like bad luck, not a cost. It also changes the recorded roll weights, so fixtures re-record.
- Build cost: medium. Touches the settlement choke point and the golden fixtures. Needs opus-level attribution under the project rules.

## Option D: step budget cost (not recommended)

Rule: a full pack lowers the directive `step_budget` by 1.

- Reuses: the directive `step_budget` (Scout Carefully 3, Seek Signs 6) in `core/movement/StagePartyMovementAdapter.gd` (`CONVENTIONS.md:840`).
- Failure mode: a budget below 2 gives an `authored_override` (same line). Scout Carefully at 3 would hit that edge at once. It also adds movement tuning to an inventory story.
- Build cost: medium to high. Listed for completeness only.

## Ranking by new systems added

| Rank | Option | New systems | New numbers |
|---|---|---|---|
| 1 | A: none | 0 | 0 |
| 2 | B: morale nudge | 0 (reuses emotion) | 1 |
| 3 | C: roll shift | 0, but touches a choke point | 2 |
| 4 | D: step budget | 0, but touches movement | 1 |

## Recommendation

Choose Option A. Reason: D-16 to D-20 already make a full pack cost room and risk, and D-33 lets the player empty the pack for free, so a stat penalty would punish a choice the player can undo at no cost. Option A adds the least to a systems-heavy game. If play shows nobody feels the pack, add Option B as the first step, because it reuses one existing service and one number.

## Proposed test of Option A in play (no code)

1. Play three paths with a full pack at 4 slots.
2. Ask: did you ever leave a piece in the pack on purpose? Did a loss surprise you?
3. If most losses surprise the player, the fix is the "at stake" mark and the departure line. If the player ignores the pack, consider Option B.

## OPEN — questions and assumptions

- ASSUMED: The Sanctum-to-pack move is free before a path (D-33), so a full pack is always a player choice.
- ASSUMED: The pack size of 4 and the warn levels stay as in `data/balance.json:3742-3747` for the play test.
- ASSUMED: Jeff wants no new player-facing copy decided here. All copy above is a proposal.
- BLOCKED: No data on how often a player carries a full pack into a path. Only a play test answers this.
- BLOCKED: Whether the "at stake" mark and the departure line already exist in the prototype v2 or v3. I did not read the mockups.
- BLOCKED: The research evidence is LOW level (search summaries only). No source shows a stat penalty for a full pack.

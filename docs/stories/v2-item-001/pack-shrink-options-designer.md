# Pack shrink with a full Sanctum (designer view)

Written in STE. Everything here is a PROPOSAL except the cited facts. Jeff decides.

## Facts that bound the question

| Fact | Source |
|---|---|
| The Sanctum never shrinks. Only the pack can shrink. | `decisions.md` D-40 |
| Sanctum has 20 slots, pack has 4 slots. Both sizes are config and can grow. | D-34 |
| Pieces move both ways between pack and Sanctum, anywhere in the Sanctum or party prep. | D-33 |
| Discard in the Sanctum is unlimited, with a confirmation. | D-21, D-33 |
| A pack piece has a saved slot index. A shrink must leave a valid place. | D-37 |
| Stacks fill one slot. | D-40 |
| No mechanical pack penalty exists. | D-36 |
| Loss is a rare, visible event (reasons `overflow`, `defeat`, early leave). | D-16, D-19, D-20 |
| Old saves need no repair. Jeff makes a new save. | D-38 |
| `canon-index.md` has no entry for party size or party composition. | grep, 0 hits |

## 1. When can the pack shrink, and how likely is a full Sanctum?

| Trigger | Who starts it | Can the game warn first? |
|---|---|---|
| T1. A config or balance cut | Developer | Yes. No player is in the flow. |
| T2. An Echo leaves the party (later story: pack size per Echo, D-34) | Player, at party prep | Yes. Party prep is a stop point. |
| T3. A debuff that cuts the pack | Nobody. D-36 closes this. | Not applicable |
| T4. Mid path | Nobody. The party cannot change on a path (D-34, D-40). | Not applicable |

Result: every real shrink happens at a stop point. The player can see it coming.

How likely is a full Sanctum at that moment? Three reasons, in order:
1. The Sanctum has 20 slots (D-34). The player can discard without limit in the Sanctum (D-21). A full Sanctum is a state the player can fix in seconds.
2. Pieces enter the pack by the Echo choice (D-17) or stay as held pieces (D-16). Held pieces exist BECAUSE the Sanctum was full on an earlier path (D-24).
3. So the two states are linked. A full Sanctum and a pack with pieces occur together more often than chance.

My estimate (unmeasured): rare overall, but not independent. It concentrates on players who hoard and carry. Nobody has data on it. A play test is the only proof.

The overflow size is small. A cut from 4 slots to 3 moves at most 1 piece. A cut to 2 moves at most 2 pieces.

## 2. Options (fewest new systems first)

### Option A: move to the Sanctum; if full, the shrink waits (core rule)

- Rule: a shrink applies only when the Sanctum has room for every overflow piece; otherwise the shrink is refused and names the missing room.
- Reuses: the D-33 move action, the D-21 discard, the D-40 `slot_taken` style refusal.
- New state: none. One refusal reason (for example `sanctum_full`).
- Player learns it: the refusal states "Free 1 Sanctum slot to continue." The player uses the normal move or discard.
- Failure mode: it cannot block T1 (a config cut with no player). A saved game may hold a pack over the new size. Needs a rule for that load case (see Option B as the fallback).
- Build cost: small. One check, one reason, one test.

### Option D: party prep forces the player to empty the doomed slots first (UI flow on top of A)

- Rule: party prep marks the slots that will vanish, and the confirm button stays off until those slots are empty.
- Reuses: the party-prep screen, D-33 moves, D-37 slot positions (the highest indices vanish first).
- New state: none. One preview of the future size.
- Player learns it: the doomed slots show a clear mark before the change. The player sees which pieces are at stake.
- Failure mode: the player feels forced to discard at a bad time. Also T1 still has no player to ask.
- Build cost: small to medium. UI work only. It needs A underneath, so D is an add-on, not a rival.

### Option B: move to the Sanctum; if full, the extra pieces are lost with a report

- Rule: overflow pieces go to the Sanctum; pieces with no room are lost, and a report lists each lost piece.
- Reuses: loss reason list (add `shrink`), the result-card lanes (D-34), the D-23 tile row.
- New state: one loss reason, one report entry type.
- Player learns it: a loss report after the change. Better: a preview before it.
- Failure mode: the loss is a punishment for something the player may not control (T1, T2). It breaks the rule that loss is rare and caused by the player's own risk (D-19, D-20). The first loss will feel like a bug.
- Build cost: small to medium. Copy, report, tests. Prefer a preview, which then makes B equal to A.

### Option C: overflow pieces wait in a temporary overflow slot

- Rule: pieces beyond the new size sit in an overflow slot until the player resolves them.
- Reuses: the pack panel, the held-piece draw rules (D-19, D-22).
- New state: a saved overflow list, plus rules for it.
- Player learns it: a new slot type on the pack panel.
- Failure mode: it is a hidden pack size. It does not shrink the pack. Open questions follow: does it roll on an early leave? Is it lost on a defeat? Does it count in the Sanctum cap? Each answer adds a rule.
- Build cost: highest. New save field, new UI, new roll rules, new tests.

## Comparison

| Option | New systems | New saved state | Silent loss | Handles T1 |
|---|---|---|---|---|
| A | 0 | 0 | No | No |
| D | 0 (UI only) | 0 | No | No |
| B | 0 | 0 | No, if preview exists | Yes |
| C | 1 | 1 | No | Yes |

## 3. Recommendation (proposal)

Build Option A as the core rule. Add Option D as the UI in the party prep step.

Reason: A uses only the move, discard and refusal rules that D-33 and D-40 already set, adds no saved state, and loses nothing, so it keeps loss rare and visible (D-19, D-20).

For T1, avoid the case instead of handling it:
1. Treat a config cut as a developer act. D-38 means a new save absorbs it.
2. Apply a size change only at party prep, never on a path.
3. Show the new size and the doomed slots before the player confirms.
4. Cut the pack in small steps (one slot at a time) so the overflow is at most 1 piece.
5. The Sanctum only grows, so room exists more often over time.

If a later story needs a shrink with no player stop point (an unblockable shrink), decide Option B for that story. Add the preview first, so the loss is never a surprise.

## OPEN — questions and assumptions

- ASSUMED: Slots vanish from the highest index down. Pieces in those slots are the ones that must move (D-37).
- ASSUMED: A shrink never happens on a live path. A live path with the party in the Sanctum counts as the Sanctum (D-40), so moves are allowed there.
- ASSUMED: A pack piece moved to the Sanctum takes the first free Sanctum slot (D-34).
- ASSUMED: A stack counts as one piece and moves whole (D-40).
- ASSUMED: The "pack size depends on the Echoes in the party" story lets the player change the party only at party prep.
- ASSUMED: My likelihood reasoning (rare, but linked to held pieces) is an estimate with no data.
- BLOCKED: `canon-index.md` returned no party composition rules. I could not check whether a party can lose an Echo outside party prep (for example in a defeat or an early leave).
- BLOCKED: No data on how often a player holds a full Sanctum while carrying pack pieces. Only a play test answers this.
- BLOCKED: Jeff decides whether the Echo-leaves case (T2) may ever force a shrink with no player action. If yes, A alone is not enough and B is needed as a fallback.
- BLOCKED: Player-facing copy for the refusal message and the loss report is Jeff's. None is final here.

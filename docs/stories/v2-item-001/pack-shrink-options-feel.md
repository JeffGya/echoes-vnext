# Pack shrink: feel options (game-feel-developer, PROPOSAL)

Everything below is a proposal. Jeff decides. Sound and haptic items are hints only: the project has no audio layer.
Sources: D-16, D-17, D-19, D-20, D-33, D-36, D-37, D-39, D-40; `design-feel-game-feel-developer-v2.md` section 3.3 (lost motion); `pack-debuff-options-feel.md`; `research-ui-best-practices.md` sections 2 and 5.
Word rules (ANSWERS #86): say Sanctum, pack, lost. All player text here is a placeholder. Jeff writes final text.

## 1. How the player experiences a shrink today, and what makes a loss fair

Nothing is built. D-40 says core builds no shrink rule yet. If a shrink happened in the prototype today:
- The pack panel would show fewer slots. Pieces in the removed slots would have no place (D-37 gap).
- The player would see no cause, no report and no choice. A piece would vanish or sit in a slot that does not exist.
- Because D-39 removed the pack counts, the party details pack button is the only fill signal. It would change number with no explanation.

A loss feels fair when all five hold:

| Test | Meaning |
|---|---|
| Foreseen | The player saw it coming before it happened. |
| Caused | The player chose the action that led to it (or can see the cause). |
| Told | A line names the piece and the reason. Never silent. |
| Located | The player knows where a kept piece went. |
| Avoidable | The player had a way to prevent it (free a Sanctum slot, drop a piece first). |

A loss feels unfair when it happens while the player is away, with no preview, to a piece the player did not choose. The research names silent loss as the top complaint (Battle Brothers, Stardew).
Key point: a move to the Sanctum is not a loss. Only the full-Sanctum case is a loss. The design should make that split clear: most shrinks cost nothing.

## 2. Options, fewest new systems first

All three reuse the existing lost-tile motion (design v2 3.3): fade to 0.35 over 0.5 s, `EASE_OUT`, lift 8 units (the piece was in the pack), no red, no shake, no strike-through, no sound on defeat. Tone: a leaf let go.

### Option A: The shrink waits for the player (guided step in party prep) - PROPOSAL

The pack keeps its old size until the surplus slots are empty. The cause is shown first. Applied when the player confirms.

- Sees: the pack panel marks the slots that will go (dashed edge, a small "closing" mark: shape, not colour). One line: `The pack will have 3 slots. Move 1 piece out.` The party details pack button shows the pending change.
- The player drags the piece to the Sanctum (D-33 move) or taps `Move to Sanctum`. When the last marked slot is empty, the slot closes: fade to 0.35 over 0.25 s, then the neighbours shift (0.25 s). Total 0.5 s.
- If the Sanctum is full, the line says so: `The Sanctum is full. Let go of a piece, or free room.` The player picks which piece to let go (existing `Let it go` action, existing lost motion, 0.5 s). The player chooses the loser. That is the fairest loss.
- Report: inline in the pack panel and the party details pack button. No toast, no result card. The guide is a state, not a message chain.
- Failure mode: nagging, and a stuck state. If the cause is not undoable (a house level), the player cannot depart until the step is done. Mitigation: a departure is blocked only for the surplus pieces; the line stays one sentence; no modal.
- Hole: the shrink must never happen while the player is away. If the size drops with no party-prep visit (for example a house level on a result screen), the step opens at the next party prep.
- Reduced motion: no fade or shift. The slot closes with a 0.15 s fade (`RM_FADE_MS`). The "closing" mark is shape and text, so it works without motion. Focus moves to the first marked piece; the line is a live region for screen readers; every move has a button path, not drag only.
- New systems: a "pending size" state saved in the snapshot, and the departure check. This is the most new state.

### Option B: Automatic move, quiet report, loss report only when the Sanctum is full - PROPOSAL

The shrink applies at once. Surplus pieces go to the first free Sanctum slots (D-37 rule).

- Moved case (the common case). Sees: the marked pieces glide from the closing slots toward the Sanctum glyph (0.4 s, stagger 0.15 s, cap 1.0 s), then the slots close (0.25 s). One quiet line on the party details pack button and pack panel for the rest of the visit: `2 pieces moved to the Sanctum.` No toast. No sound.
- Lost case. Sees: the same glide, but a piece with no room uses the lost motion with lift (0.5 s) at its slot. A loss line replaces the quiet line: `The Sanctum was full. Lost: Moss Charm.` The line names every lost piece (cap 3 names, then a count). It stays until the player leaves the screen.
- Report place: the pack panel line plus a one-time row on the next result card or party-prep entry if the shrink happened away from the screen. A loss is never shown only on a toast: toasts vanish.
- Failure mode: surprise loss. The player never chose it. Worst case: the player opens the game and finds a piece gone. Mitigations: show a preview line before the size change when the cause is a player action (party change: `This party has 3 slots. 1 piece will move to the Sanctum, 1 will be lost.`); keep the loss line until dismissed; add a recovery lane as in the open question below.
- Reduced motion: no glide. Moved pieces fade out of the pack and into the Sanctum grid with a 0.15 s fade. Lost pieces fade 0.15 s, no lift. The line carries the meaning. Never use colour alone.
- New systems: none beyond D-40 and a report string. This is the fewest.

### Option C: A temporary overflow slot - PROPOSAL

The surplus pieces stay in one extra "waiting" slot per lost slot until the player resolves them. The pack looks as small as the new size, with a tray beside it.

- Sees: a labelled tray (`Waiting`) next to the pack, showing the pieces with no place. The player moves them to the Sanctum or lets them go at any time. A tray piece is not in the pack for a path: it does not come on the path.
- Report: the tray is the report. A small mark on the party details pack button. No toast.
- Failure mode: unclear and heavy. The player must learn a third container. A tray that never empties becomes clutter. The question "does a tray piece count as carried and at stake (D-19, D-20)?" needs a rule. Peak-moment chores (research section 2) get worse.
- Timing: the tray appears with a 0.25 s fade. Removing a piece uses the existing move glide (0.4 s) or lost motion.
- Reduced motion: 0.15 s fades. Tray text and a count word carry the state.
- New systems: a third container, its save field, its size rule and its path rule. This is the most new systems and it adds a concept the player does not need.

## 3. What to avoid

| Pattern | Why |
|---|---|
| Silent loss | The top complaint in the research. A loss always names the piece and the reason. |
| Loss while the player is away | The player cannot foresee or avoid it. Resolve a loss only on a screen the player is watching, or hold it until the player returns. |
| A modal chain (one dialog per piece) | Click-through by habit (GNOME HIG note). Use one inline line and one list. |
| Choosing the loser for the player with no preview | Unfair. If a loss is needed, preview it or let the player choose. |
| Red, shake, sting, strike-through | Breaks the loss tone (a leaf let go). |
| A toast as the only loss report | A toast vanishes before the player reads it. |
| Loss on a live path | The path view allows no moves (D-33). A shrink must not apply on the path view. |
| Repeating the line | Show it once per shrink. No loop, no nag. |

## 4. Recommendation - PROPOSAL

Build option B, with one addition: a preview line before the shrink when a player action causes it, and a kept loss line when a piece is lost.

Reason: it is the fewest-systems option, and the move case (almost every shrink) costs the player nothing, so only the rare full-Sanctum case needs a loss moment.

If Jeff wants no surprise loss at all, option A is the safe alternative. It costs one saved "pending size" state. Do not build option C.

## OPEN — questions and assumptions

- ASSUMED: the shrink has a visible cause (a party change or a house level) and happens on Sanctum or party-prep screens, never inside the path view.
- ASSUMED: Jeff's "lost or destroyed" means the same state as `lost` with a reason such as `shrink`. I use one word, lost, in all text (ANSWERS #86).
- ASSUMED: a shrink caused by a party change in prep can be undone by the player (put the Echo back). If true, a preview line is enough for option B.
- ASSUMED: carried pieces moved by a shrink lose their loose-leaf glyph on landing in the Sanctum (design v2 section 5.2).
- BLOCKED: who chooses which piece is lost when the Sanctum has less room than the surplus? Options: the player (option A), the highest slot index first (option B default), the lowest grade first. Jeff decides. This changes the failure mode.
- BLOCKED: does a shrink that happens away from the screen (house level on a result card) wait for the next party prep, or apply at once? Jeff and the designer decide.
- BLOCKED: should a lost piece stay recoverable for the rest of the visit (a one-tap undo on the loss line)? This is a recovery lane (research section 5, Stardew Marlon). It adds one small state and is my addition, not a request.

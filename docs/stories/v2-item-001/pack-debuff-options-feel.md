# Pack debuff: feel options (game-feel-developer, PROPOSAL)

Everything below is a proposal. Jeff decides. Sound and haptic items are hints only: the project has no audio layer.
Sources: D-04, D-16, D-17, D-19, D-20, D-33, D-34; `design-feel-game-feel-developer-v2.md` sections 2.2, 3.3, 3.5; `research-ui-best-practices.md` sections 2, 3, 9; `inventory-ui-mockup-v2.html`.

## 1. How the player learns about pack risk today

| Channel | What exists | Source |
|---|---|---|
| Pack gauge | Bead string, 4 beads. Text `Load n of 4`. At full: gold fill, ink keyline, word `Full`. Last bead pulses once (scale 1.15, 400 ms), once per session. | Prototype v2 `gaugePack`, `pulseIfFull` |
| Departure chip | Designed (neutral ink, count, loose-leaf glyph, gold outline when room is low). In prototype v2 it is only a CSS swatch. No live departure flow is shown. | Design v2 2.2; mockup line 1064 |
| Leave panel line | `They may lose 3 pieces. 1 was carried from before.` Designed, number only. | Design v2 2.3 |
| Refusal | `The pack is full. Free a socket first.` Shown only when the player tries a move. | Prototype `rPackFull` |

Honest assessment: it is a good notice, not yet a cost.
- The gauge says "full". It does not say "this has a price".
- The pulse fires once per session. After that, a full pack is silent.
- Loss risk (D-19, D-20) is told only at the leave panel. That is late, and the research shows players dislike late loss (section 2 and 9 of the research file).
- The real cost is already strong: carried pieces can vanish. But the player meets it only as an event, never as a state they carry.
- A full pack today feels like "no room", not "heavy". Nothing in the party looks changed by the load.

## 2. Options, ranked by new systems (fewest first)

### Option A: Feedback only (no new rule, no new state) - PROPOSAL

Make the existing risk visible as a state. Four small changes:

| Change | Detail |
|---|---|
| Heavy gauge | At full, beads sit 2 units lower and one tone darker (design v2 3.5 "socket posture"). Gold stays only for actionable things, so full uses a dark leather tone plus a thin strap line, not more gold. |
| Standing risk glyph | The loose-leaf glyph from design v2 2.1 stays on every carried tile, also on the path card. The pack always shows what is at risk. |
| Wording | Replace `Full` with a consequence word. Examples: `Full. Nothing more fits.` on a path, `Heavy. They may lose what they carry.` at prep. One sentence each. Jeff writes final text. |
| Gauge behaviour | The pulse runs at every transition into full, not once per session. One 400 ms pulse, then still. No loop. |

- Sees and feels: the pack looks loaded, like a satchel with a strap pulled tight. The cost is a look, not a number.
- Timing: pulse 0.4 s on the transition only. Tone change fades in 0.25 s.
- Hint only: one soft thud on the transition; one short vibration on a handheld.
- Failure mode: unclear. If the player never opens party prep, the state may go unseen. It cannot punish.
- Reduced motion: no pulse. Tone and glyph change by a 0.15 s fade (matches `RM_FADE_MS`). Meaning is carried by shape, wording and tone, never by motion or colour alone.

### Option B: Presentational consequence (no number changes) - PROPOSAL

The party visibly carries the load. It changes how the party looks and moves, not how it fights.

| Level (existing `pack_load.level` hook, design v2 3.5) | What the player sees |
|---|---|
| 0 and 1 | Nothing. Normal walk. |
| 2 (heavy) | Party idle sits 2 px lower. Walk cycle is 8 percent slower in the Sanctum and on the path map only. Satchel glyph `LoadMark` shows a bulge. |
| 3 (full) | Same as 2, plus the satchel strap creaks once on entering the path (0.4 s) and a small `Heavy` tag sits on the party card. |

- Sees and feels: "we are loaded down". Dropping one piece lifts the party (a 0.3 s rise). That reward is the point: freeing a socket feels like relief.
- Rule: combat speed, animation timing and input never change. Only walk and idle in non-combat views. The slow walk must never lengthen a wait.
- Failure mode: annoying. A slow walk can read as lag or as a bug. It can also read as a hidden speed penalty. Mitigation: the `Heavy` tag explains it, and the effect is subtle and capped.
- Reduced motion: keep the 2 px posture and the tag. Remove the walk-speed change. The creak is replaced by a 0.15 s fade. Never rely on the slow walk to convey state.
- Cost: needs `level` in the snapshot (already proposed as a data hook) and one art state. No new rule.

### Option C: Small mechanical hook on an existing system - PROPOSAL

Reuse the early-leave roll (D-03, D-19). Do not add a stat.

- Idea: the pack size sets how much the roll "weighs" in the player's view only, or, if Jeff accepts one rule: a full pack at departure gives the leave panel a stricter default label (`some` shown first). Mechanically nothing new is read, because the draw already exists.
- Lighter variant, one number: when the pack is full at path end, the first gathered item that has no socket goes to a "dropped on the road" card with a 1-tap swap against a held piece. This reuses the D-16 safety net (reason `overflow`) and the existing lanes. No debuff.
- Sees and feels: a full pack now creates a decision at a peak moment (keep the new piece or the old one). Research sections 2 and 9 warn that peak-moment inventory chores feel bad. This is the main risk.
- Timing: swap card uses the existing 0.25 s guard. No extra animation.
- Failure mode: punishing and nagging. It adds a prompt after a win. Keep it to one card, skippable, never repeated.
- Reduced motion: no new motion. Card fades 0.15 s.
- Cost: one swap action and one card. This is still a new rule, so it ranks last.

## 3. What to avoid

| Pattern | Why |
|---|---|
| Repeating warnings (toast every time the pack is full) | Reads as nagging. One pulse per transition is the limit. |
| Red or flashing full state | Reads as an error and fails colour-blind players. Use shape, tone, wording. |
| Silent loss at a rush moment | The research names it as the top complaint (Battle Brothers, Stardew). |
| A modal at departure | D-17 design: no modal at departure. It blocks the main action. |
| A hidden speed or stat drop with no label | Reads as a bug (Wartales weight confusion, research section 2). |
| Slow input or slow combat from load | Changes pace the player did not choose. |
| Shaming wording (`You are overloaded`) | Punishes a choice the player made on purpose. |
| Stacking cost on cost | Loss risk (D-19) is already a heavy cost. Add feel, not a second penalty. |

## 4. Recommendation

Do option A now. Add option B later only if play tests show the pack still feels free.

Reason: the real cost (D-19, D-20) already exists, and option A makes the player feel it before they depart, with no new system, rule or number.

Option A is also the least-systems choice. Option B reuses the `level` hook that design v2 3.5 already proposes. Option C adds a rule and a peak-moment prompt, so I do not recommend it.

Play test question for Jeff: after a full pack at prep, does the player say "I should drop something" without being told?

## OPEN — questions and assumptions

- ASSUMED: "pack debuff" means any cost beyond the D-19/D-20 loss risk, in numbers or in play.
- ASSUMED: the departure chip will be built as designed in design v2 2.2. Prototype v2 shows only its style, not a live flow. I could not confirm chip behaviour by clicking.
- ASSUMED: gold stays reserved for actionable things. A heavy tone for "full" is my proposal.
- ASSUMED: art can supply one extra party idle state and a satchel bulge for option B. Not checked with the artist.
- BLOCKED: none. Final wording and any number are Jeff's.

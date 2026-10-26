# Phase 6 — UX copy proposals (early leave and retreat)

Status: ALL TEXT BELOW IS A PROPOSAL. Jeff owns the wording (CLAUDE.md, D-84). Nothing here is built.
Player-facing text follows the game voice, not STE. The notes outside the quoted copy are in STE.
Rules behind the copy: D-104, D-105, D-106. Amounts always come from the snapshot. No percent, no odds,
no fraction ("half") in any line (D-104 addendum).

Voice kept from the shipped placeholders (`CarriedHomePresentation.gd`, `PayoutCausePresentation.gd`):
short plain sentences; "earned" for Ase and Ekwan; "the stage waits"; the party as "they" or "the party".

## 0. Words that need your decision first

| # | Problem | Options |
|---|---|---|
| W1 | The shipped word rule says "carried, never lost". D-105 makes a real loss. Which word names what is not carried? | A. "left behind" (soft, fits "carried") · B. "lost" (honest, hard) · C. "gone" (short, plain) |
| W2 | `RETURN_COST` = "Going home costs nothing." is now FALSE. | Remove, or replace with a line from section 1 |
| W3 | `ADVANCE_NOTE` = "The rest is earned when the stage is finished." is now FALSE. | Remove; replaced by the risk line in section 1 |
| W4 | `carried_advance` cause text ("taken off the stage payout, so nothing is earned twice") no longer exists. | Remove; replaced by section 3 |
| W5 | `partial_return_home` / `partial_retreat` cause text says "keeps a small part". Now the share is nothing, some or everything. | Replaced by section 2 (return) and removed for retreat (the retreat pays nothing) |

Sections below use W1 option A ("left behind") as the default. Swap the word if you pick B or C.

## 1. Confirmation panel (before "Go home")

Fixed (your words, unchanged): **"Escaping might be more difficult than expected. It might not be possible."**
Fixed: question **"Take the party home?"** · no subtitle.

Gathered line (amounts from the snapshot):

| Option | Copy | Tone |
|---|---|---|
| A | "The party has gathered 74 Ase and 12 Ekwan here." | neutral, factual |
| B | "Gathered so far: 74 Ase, 12 Ekwan." | shortest |
| C | "In their packs: 74 Ase and 12 Ekwan." | in-world |

Risk line (what the roll means, no odds):

| Option | Copy | Tone |
|---|---|---|
| A | "They might get all of it out, some of it, or none. What is left behind is gone." | clear, honest |
| B | "Leaving now, they may carry all of it, a part, or nothing. What stays behind is lost." | plain |
| C | "Not all of it will survive the way home. Anything they cannot carry is left behind." | softer, no "none" shown |

Note on C: it hides that "none" is possible. Honesty: A and B name it. Recommended: A.

Stage-keeps line (objectives stay overcome, W2 replacement):

| Option | Copy |
|---|---|
| A | "The stage waits. What they have overcome stays overcome." |
| B | "The stage waits for them." |

Buttons: keep **"Go home"** / **"Stay"** (no change).
Recommended panel: gathered A + risk A + stage-keeps A + your escape line.

## 2. Resolve card after a successful return home

Row label (replaces "Carried home"): proposals —
A. "Brought home" · B. "Settled when you left" (design file) · C. "Carried out"

Outcome lines (one shows; no percent):

| Outcome | Option A | Option B |
|---|---|---|
| Everything | "They got everything out." | "Nothing was left behind. Everything came home." |
| Some | "They got some of it out. The rest is left behind." | "Part of it came home. The rest stayed behind." |
| Nothing | "They got nothing out. It is left behind." | "Nothing came home. All of it stayed behind." |
| Nothing new | "There was nothing new to carry." | "They had gathered nothing new since last time." |

Rules: the "nothing" outcome ALWAYS shows its +0 row, so the player sees the result. The amounts that arrive show
as "+N Ase" and "+N Ekwan" (existing format). The card does not print any share.
Recommended: A for all four.

## 3. Stage-end ledger (after the stage is finished)

New memo row (zero change, explains a smaller base row). Label: **"Settled when you left"**; value: the Ase and Ekwan
already settled.

Cause text under the row:

| Option | Copy |
|---|---|
| A | "These were already settled when the party left. They are not earned again." |
| B | "Settled on the way home. Not earned twice." |

Recommended: A. Remove the old `carried_advance` negative row and its cause text.
The base row cause stays: "Only objectives the party found and overcame earn Ase."
(add nothing; "N of M" still counts all completed objectives).

## 4. Combat retreat (back to the stage)

Retreat button (existing format): `Retreat (10 Ase)` + second line. Second line options:
A. "Back to the stage. Uses a turn." · B. "Step back. Costs a turn." · C. "Withdraw. One turn."

Denied (existing, keep): "Retreating takes 10 Ase. The party has 4."

Result card after a successful retreat:

| Element | Option A | Option B |
|---|---|---|
| Title | "The party falls back" | "Pulled back" |
| Body | "They withdrew from the fight. Nothing is lost, and nothing is earned. The stage waits." | "They stepped back. Nothing was lost. The stage waits." |
| Button | "Back to the stage" (your wording) | "Back to the stage" |

Body lines for the two re-entry rules (shown only when relevant):

| Case | Copy |
|---|---|
| Normal fight (cannot re-enter at once) | "The way to that fight is closed for now." |
| Objective fight (can re-enter) | "The objective is still there when they are ready." |

Failed retreat (existing flow, fight begins): no new copy.

## 5. Where each line goes (for the UI step)

| Surface | Lines used |
|---|---|
| Confirmation panel (`ReturnHomeModal`) | section 1 |
| Resolve card, scout-return branch | section 2 |
| Resolve card, stage end, ledger | section 3 |
| Combat board retreat button, retreat card | section 4 |

## 6. Localization notes

- Avoid idioms: "left behind" and "got out" are plain and translate well. "Pulled back" and "falls back" are mild idioms (military); prefer "withdrew".
- Numbers and "Ase"/"Ekwan" stay as tokens. Amounts are inserted by the UI.
- Keep each line under 90 characters in the panel; lines may wrap on the compact profile.
- Do not state "some" as a fraction in any language.

## 7. Questions for Jeff

1. W1: which word names what is not carried?
2. Pick one option per element in sections 1 to 4 (recommended picks are marked).
3. Should the card name the outcome as three separate states, or one neutral line plus the amounts only?

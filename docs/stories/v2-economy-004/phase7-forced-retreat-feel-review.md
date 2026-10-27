# Phase 7 side question: forced retreat (standoff), feel review

Author: game-feel-developer. Round 2 of a design round. It builds on `phase7-forced-retreat-design.md` (round 1) and does not repeat it.
Written in STE. Player text is PROPOSAL only and follows the game voice (not STE) and the word rules (ANSWERS #86): no "home", no "stage"; "path", "Sanctum"; "lost" only for what is not carried.
I ran no code and no Godot. Tags: READ = from a file I opened. COMPUTED = my arithmetic. ASSUMED = not verified.
Jeff decides. Nothing here is approved.

## 0. Findings first

1. **The brief's premise needs a correction.** The player has NO tactic lever during a running fight. READ: `CombatBoardScreen.gd` has speed buttons and a manual-step toggle only. The retreat button lives in the prebattle modal (`:1195-1205`, `encounter.retreat` is handled before combat starts, `FlowRuntime.gd:1166-1235`). So a warning cannot let the player "change tactics" in the fight. Its job is different: explain what is happening, give patience, and prepare the choice at the next prebattle screen. This changes the spec in section 2.
2. **Today the stall is silent and long.** READ: 15 damage-free rounds, no snapshot field carries the streak (`no_progress_streak` appears only in `CombatState.gd` and `FlowRuntime.gd`; no `ui/` file reads it). READ: auto-play step delay is 1.5 s at Normal, 3.0 s at Slow, 0.5 s at Fast (`CombatBoardScreen.gd:107-109`). COMPUTED example: a party of 4 against 3 enemies is 7 actor steps per round; 15 rounds is 105 steps, about 2.6 minutes at Normal, about 52 s at Fast. ASSUMED: one step per actor per round; I did not count steps in a real stall. The player watches minutes of nothing, then the board swaps to a card. The unfair part is not the sudden end. It is the long unexplained wait and the cut with no reason.
3. **The cut is instant.** READ: `_resolve_forced_retreat` goes straight to RESOLVE. There is no beat between "nothing moved" and the card. The retreat card (`pulled_back`) has the same instant swap, but there the player pressed a button, so the swap is an answer. In a standoff nobody pressed anything, so the swap is a surprise.
4. **I agree with F1, P1 (first time), K1, S2, E1 in direction. I change three of them** (section 3): P1 becomes progressive (a Sanctum button appears from the second standoff); E1 must be visible or it is farming without a felt reason; K1 plus S2 is a real "free reset" risk and needs one visible counter-weight.
5. **The card may name the cause in words, without numbers.** It teaches the player what to change. Rules in section 4.
6. **No persistent mark on the Echoes.** The record of a standoff belongs in the history (a family record line), not on a badge. Reasons in section 3.5.
7. **Word collision found (existing, not fixed here):** the chosen-retreat button says `Leave` (D-107 item 4) but it returns the party to the PATH. Early leave to the Sanctum also reads as "leave". Report it; the standoff card must not use `Leave`.

---

## 1. How the standoff feels from the player's seat (as built today)

| Phase | What the player sees and feels | Read | Verdict |
|---|---|---|---|
| Before (rounds 1 to ~8) | The fight plays. Round label counts up. Echoes and enemies move, refuse, guard. Barks show on refusals (bark budget applies). | Normal. A refusal bark is the only hint that something is off. | FEELS RIGHT. Nothing to add. |
| Before (rounds ~9 to 15) | No damage. Tokens shuffle or hold. The round number keeps rising. Nothing says "this is stuck". | The player guesses: is it a bug, is it slow, should I press something? Many will tap Fast or Manual and press harder on a screen that cannot help. | WRONG. Anticipation is missing. The player gets no read and no reason to be patient. |
| The moment it fires | Board is replaced by the card in one frame. | Feels like a crash or a cut, not a consequence. | WRONG. No feedback beat. |
| After | One tap on the card. Back on the path. | The consequence is unclear: why, what now, did I lose anything. | RISKY. Round 1 fixes the "nothing was gained" banner. It does not yet tell the player what to change. |

Is a silent auto-end after N rounds fair? **No, not silent.** The rule itself is fair (it ends a loop, costs a turn, takes nothing). The silence is the unfair part. Fire Emblem Gaiden (round 1 research) ends a stall by a visible turn limit. The player there can see it coming.

Should the game warn? **Yes, but with two steps and no number.** The warning is not a countdown. It is a change of mood that says "this has gone quiet".

---

## 2. Warning cue and feel spec (PROPOSAL)

### 2.1 What the cue is for

Not a lever (finding 1). It has three jobs:
1. Tell the player the game knows. Remove "is it broken".
2. Prepare the card. The ending then reads as a consequence, not a cut.
3. Point at the next decision: the prebattle screen (party, directive, retreat).

### 2.2 Data needed (mechanics task, read-only, no outcome change)

A new snapshot field `stall_level`: 0, 1 or 2. Derived in core from `no_progress_streak` and `no_progress_round_limit`. The UI never sees the streak or the limit, so no number can leak.
Proposed thresholds as a share of the limit (config, `mid-game-designer` authors): level 1 at about two thirds (round 10 of 15), level 2 at about eight tenths to nine tenths (round 12 or 13 of 15). Level resets to 0 on any progress. ASSUMED: derivation from streak is cheap and deterministic; it must not touch combat state.
Also needed for the card (section 4): a short `stall_cause` word (`froze`, `guarded`, `none`) and the names of up to two Echoes that refused in the last rounds. Saved with the pending result so a reload shows the same card (round 1 BLOCKED item on `forced_retreat` pending record).

### 2.3 The two steps

| Step | Trigger | What the player sees | Text (PROPOSAL, optional) |
|---|---|---|---|
| Level 1: "gone quiet" | `stall_level` 1 | The round label and objective banner stay as they are. A thin soft line under the banner fades in. Tokens keep their motion but the idle breathing of Echo tokens slows a little. Board edge gets a very light vignette. No colour alarm. | `Nobody is moving.` |
| Level 2: "held breath" | `stall_level` 2 | Same line changes. Vignette a little stronger. The Echo that froze (the last refuser) gets one bark in their own voice, once. | `Nobody wants to go first.` |

Rules:
- No percent, no countdown, no "rounds left", no pace-colour reuse. Pace colours (full, partial, none) belong to pace fights only (`PacePresentation`). Reusing them would tell the player a pace objective is failing.
- The line is not a button. It takes no input. It does not change the layout (it sits in space already reserved under the banner).
- It clears on progress, with a quick fade out. The player then sees that the fight moved again. That is feedback that the cue was true.
- Do not use Error red or Warning orange. A standoff is not a failure and not a danger. Use the Info family (soft blue `#7AB5C8` on the dark board) for the line, the same family as the retreat card title (`#315E6D` on the panel). READ: Living Grove semantic colours, `docs/Living_Grove_Design_System.md:35-40`. ASSUMED: `#7AB5C8` reaches body-text contrast on the dark board; I did not compute it. Check with `accessibility-review` at build time. Secondary text tan `#8B7355` on base `#3D5A47` is likely too low; do not use it for the line.

### 2.4 Timing and easing

| Item | Spec | Reason |
|---|---|---|
| Line fade in | 0.4 s, `TRANS_SINE`, `EASE_IN_OUT` | Same family as the pace blend (`_pace_tween`, `TRANS_SINE`, `EASE_IN_OUT`). Reads as the same calm family. |
| Vignette | 0.6 s, same easing | Slower than the text, so the text lands first. |
| Token breathing slow | Change over 0.6 s, small amplitude | Motion is felt, not noticed. Honour a reduced-motion setting if one exists (ASSUMED: none found; flag). |
| Clear on progress | 0.25 s, `EASE_OUT` | Quick relief. |
| Bark (level 2) | Once per fight, through the existing bark layer and budget | No new system. Wording belongs to the language story. |
| Repeat | Each level shows once per fight. Do not re-trigger on a streak that recovers and falls again within the same fight. | Avoids a flashing cue. |

All values scale with the speed setting where they are tied to step delay. At Fast the fade-in may shorten to 0.25 s. They never change when the simulation advances.

### 2.5 Optional: finish the quiet rounds faster (pure pacing)

Once `stall_level` is 2, the remaining rounds can play at Fast speed whatever the player picked, with the cue still showing. The player then does not sit through the last minute of nothing. This is presentation only: the rounds, the order and the result stay the same. It needs Jeff's yes, because it overrides the speed the player chose. Rank: do it only if the playtest shows the wait is the main complaint.

### 2.6 The moment it fires (card entry)

| Beat | Spec |
|---|---|
| 1. Settle | Board holds still. Tokens ease to rest. Hold = 0.5 x the current step delay, clamped to 0.3 to 1.0 s (about 0.75 s at Normal). Vignette stays. No flash, no shake, no red. |
| 2. Swap | Cross-fade from board to card, 0.35 s, `TRANS_SINE`, `EASE_IN_OUT`. Not a cut. |
| 3. Reveal | Title first. Body 0.15 s later. Packs and open-fight lines 0.3 s after the title. The button is tappable from the first frame of the card (a touch answers at once, even when lines are still arriving). |
| 4. Sound (hint only) | ASSUMED: no audio layer found in `ui/` or `core/` (my grep for audio and haptic terms in those folders returned nothing). If audio exists later: one soft low tone that falls, no chime, no sting. Never the defeat sound. |
| 5. Haptic (hint only) | One short light tap when the card lands. None on the warning. Nothing on the button press beyond the project default. |
| 6. Card shape | Reuse the compact retreat card (`_compact_card`, banner colour `#315E6D`, one outcome line, one button of height 56). READ: `ResolveScreen._render_retreat_return` (`:942-957`). Add the cause line and keep to three text lines at most. |

Frame budget: only one label, one overlay rect and two tweens. ASSUMED within budget on the minimum window; not measured. `qa-verifier` should measure.

### 2.7 The prebattle screen is the real lever moment

The player makes the next choice at the prebattle modal. It should say, in the same quiet voice, that the party has been here: a small line `They stalled here before.` (second time: `It went the same way twice.`). No count shown as a number. This is where the card's hint lands. READ: the retreat button and its denied reason live there. This needs a snapshot flag on the situation (`standoff_count`, which round 1 already proposes). Round 1 did not name this surface; it is the most useful place for the hint.

---

## 3. Challenge to each round-1 pick

### 3.1 F1 Standoff: AGREE, with a caution on the name

- Feel reason to agree: the fiction is "nobody moved", which is neutral. Not a death, not a payout. It matches the cue ("Nobody is moving") so the warning, the card and the name are one story.
- Caution: "Standoff" is a card title, not a word the player has been taught. It is familiar English, so it is acceptable. Alternatives that avoid a game-word feel: `Nobody moved` (round 1 B), `Stuck`, `Held`. I rank `Nobody moved` above `Standoff` for the Echoes voice (a family record says what happened), and `Standoff` second. Jeff decides.
- Contrast with `Pulled back` (the chosen retreat): that is an act of the party. The standoff is a state of the fight. Keep them different in grammar: past tense act vs. a plain statement.

### 3.2 P1 Path only: AGREE for the first standoff, CHANGE for repeats

- One button for the first time is right. A new player must not face a decision on a card they did not cause.
- But a player who hits the same standoff a second time may want out. The round-1 note says the Sanctum exit exists one screen later. That is true, but the player in a loop reads "stuck" and wants the exit on the card.
- **Change:** from the second standoff on the same fight, add a quiet second button: `To the Sanctum` (Jeff's own D-107 confirm words). It runs the normal return home action, with its confirmation, escape check and roll (so no free exit). The primary gold button stays `Back to the path`. The secondary has a gold border and terra outline per the design system. Both at least 48 high; the primary 56; gap at least 8.
- This answers the boredom risk in 3.4 without adding a free exit.

### 3.3 K1 Packs kept whole and S2 fight returns later: AGREE on rules, RISKY together

Feel risk: **a stalemate feels like a free reset.** The player learns: when a fight looks hard, let it stall. Cost: one turn. The fight stays and the packs are safe. Nothing is lost, nothing is paid. For an objective fight this is a pause button; for a normal fight it is the same as `ignore_situation`, which already exists, so no new gain there.

What decides if it feels free is the turn cost. UNVERIFIED (round 1 BLOCKED): the path may have no turn limit. If none, the delay costs nothing and the standoff is "free" in the plain sense.

Feel-side counter-weights (cheap, no number):
1. The wait itself is a cost. Section 1 shows the player sits minutes watching nothing. That is a real price in play time, so the player will not choose a stall on purpose. (If I add 2.5, I shorten this price; then the free-reset risk grows. Pick one: either keep the wait as the price, or fast-forward it and accept the risk. I lean to keep the wait short with the cue and not remove it.)
2. The fear option E1 must not reward stalling (3.5).
3. The card must not say "Nothing was lost" in a relieved tone. Round 1's packs line is neutral and good.

I agree K1 and S2 are right for fairness (the player did not choose this). The risk is named, not removed. Flag for the playtest: count how often a player stalls and then wins on the next attempt with the same party. If often, stalls are working as a free retry.

### 3.4 Soft-lock and boredom loop: what does the player DO next?

Scenario: an objective fight stalls every time with this party (S2 brings it back, same seed, ASSUMED same stall).
The loop: card, path, other targets, fight offered again, prebattle, watch 15 quiet rounds, card. Each lap costs minutes of watching and nothing else. This is the worst feel case in the whole proposal. It is a boredom lock, not a hard lock.

What the player can DO (all must be visible, none by number):
1. Change the party (summon, swap). Visible lever, but only if the card or the prebattle line points at it.
2. Change the directive. Same.
3. Rest or let fear fall, then come back. E1 helps only if the player sees it.
4. Leave by the roll. Needs the progressive Sanctum button (3.2).

Proposed escalation of the card hint (words only, from `standoff_count`):
- 1st: says what happened (cause line).
- 2nd: says it went the same way, names a lever in words (`Maybe a different party.`), adds the Sanctum button.
- 3rd and later: same, shorter, and the prebattle screen leads with `They stalled here twice.`

I do not recommend a hard "set this aside" valve now (round 1 defers it). I agree: wait for the playtest. But I make the Sanctum button the guaranteed valve, so the loop has an exit that the player can always find within two laps.

### 3.5 E1 Fear drop: AGREE only if visible

- Feel problem: a small fear drop on one Echo is invisible. The status band may not change (ten emotional statuses, ANSWERS #66). The player gets a hidden effect and cannot learn from it.
- Farming problem: if stalling lowers fear, it becomes a hidden rest action. Round 1 caps it at the first standoff per fight. Good. The player still gets one free calm per fight.
- **Change:** show it in words on the card, only when true: `Kweku breathed out.` / `Kweku calmed down a little.` The name comes from the Echo whose fear really dropped. If the drop does not move a visible band, say nothing and do not claim it.
- If the API does not exist (round 1 BLOCKED), E2 (no change) is acceptable. Then the card must not hint at calm.

### 3.6 "A forced retreat is not a death": does it need a visible mark on the Echoes?

Short answer: **no persistent mark.**
- A badge says "something happened to you". The Echoes did nothing wrong, and the pillar is that Echoes grow over time. A permanent mark reads as a scar. It contradicts "not a death" and "not a loss".
- The Echo's emotion display already carries the real change (their fear, via E1). That is a mark, and a true one.
- The record belongs in the history. READ: voice rule "History reads like a family record". One line per standoff, with who froze and who stayed. The language story writes it. Example direction: `Kweku could not move first. Yaw stayed by him.` (not final copy).
- A short one-time mark is fine on the board: the Echo that froze lowers or dims for the settle beat (2.6 beat 1). It is posture, not a badge. It fades with the card.
- Permadeath rule (round 1): a standoff never kills an Echo. Agreed.

### 3.7 Should the card name the likely cause in words?

**Yes, in a family-record voice, only when the log really shows it.** Reasons:
- It teaches the player the link: fear leads to refusal leads to stall. The game never explains the model; it tells what happened to a person. `Kweku was too scared to start it.` is what happened. It is not a system explanation.
- It makes the lever readable: a scared Echo points at rest or a different party; guarding points at a different approach.
- Danger: a wrong cause misleads. So: name a cause only from a recorded event (a refusal in the last rounds, or a guard action). If neither, use the generic line. Never guess.
- No numbers. At most two names.

---

## 4. Card copy (PROPOSAL; Jeff chooses; not STE)

Voice: short, everyday, concrete. First person plural is already used on the retreat card (`Our task is not done.`). The cause lines are narration about people. No system words ("fear", "refuse" as a stat). "Fear" as a plain word for a feeling is fine in speech, but I use "scared" and "froze".

### Title (one per card)
| Option | Note |
|---|---|
| A. `Nobody moved` | Matches the warning line. Plain. My first pick. |
| B. `Standoff` | Round 1 pick A. Familiar. Second. |
| C. `Held back` | Close to `Pulled back`. Too easy to confuse with the chosen retreat. Not recommended. |

### Body (what happened; pick by cause)
| Cause | Option 1 | Option 2 | Option 3 |
|---|---|---|---|
| Generic (no recorded cause) | `Nobody wanted to go first. The party backed off.` | `Neither side would start it. The party stepped back.` | `Nothing happened for too long. The party backed off.` |
| An Echo froze | `Kweku froze. Nobody else would start it. The party backed off.` | `Kweku was too scared to go first. The party stepped back.` | `Kweku could not move. The party backed off.` |
| Guarding | `Both sides stood their ground. Nothing moved. The party stepped back.` | `They kept guarding. So did the enemy. The party backed off.` | `Nobody gave an inch. The party stepped back.` |
| Two Echoes froze | `Kweku and Yaw froze. The party backed off.` | `Kweku and Yaw were too scared to start it. The party stepped back.` | (use the generic line) |

### Packs line
| Option 1 | Option 2 | Option 3 |
|---|---|---|
| `They still carry what they carried.` | `What they gathered is still with them.` | `Their packs are as they were.` (round 1) |

Rule kept from round 1: never say "lost" here and never say "nothing was gained".

### Open-fight line
| Fight | Option 1 | Option 2 | Option 3 |
|---|---|---|---|
| Objective | `Our task is not done.` (Jeff's D-107 words, shortened; use his full line `Our task is not done. This story is not over yet.` if he prefers) | `This is not over.` | `We still have to do this.` |
| Normal | `It's not smart to re-enter this quickly.` (Jeff's D-107 line, reused as written) | `We can try again later.` | `It will wait for us.` |

### Calm line (only when E1 really lowered fear)
| Option 1 | Option 2 |
|---|---|
| `Kweku breathed out.` | `Kweku calmed down a little.` |

### Repeat hint (from `standoff_count`)
| Count | Option 1 | Option 2 | Option 3 |
|---|---|---|---|
| 2nd | `It went the same way last time.` | `Same as before.` | `We were here before.` |
| 2nd, with a lever | `Maybe a different party.` | `Maybe they need to rest first.` | `Maybe try it another way.` |
| 3rd and later | `This is not working.` | `We keep ending up here.` | `Not like this again.` |

### Buttons
| Role | Option 1 | Option 2 | Option 3 |
|---|---|---|---|
| Primary | `Back to the path` | `Continue` (D-111 next-button word) | `Step back` |
| Secondary (2nd standoff on) | `To the Sanctum` (Jeff's D-107 confirm word) | | |

Do not use `Leave` (finding 7). Note: Jeff removed second lines on buttons (D-107 addendum 2); I add none. I add no "uses a turn" text.

### Warning cue lines (on the board; short)
| Level | Option 1 | Option 2 | Option 3 |
|---|---|---|---|
| 1 | `Nobody is moving.` | `It has gone quiet.` | `Both sides are waiting.` |
| 2 | `Nobody wants to go first.` | `This is going nowhere.` | `Neither side will start it.` |

### Prebattle line (second visit)
| Option 1 | Option 2 | Option 3 |
|---|---|---|
| `They stalled here before.` | `It went quiet here last time.` | `Nothing moved here last time.` |

### Coherence check against Jeff's retreat words
| Jeff's chosen retreat | The standoff | Relation |
|---|---|---|
| `Pulled back` | `Nobody moved` | Contrast on purpose: act vs. state. |
| `Withdrawing. Back to the path.` | `The party backed off.` / `Back to the path` | Same destination, same word `path`. Contrast: not a decision. |
| `Leave` | `Back to the path` / `Continue` | Do not reuse `Leave`. |
| `It's not smart to re-enter this quickly.` | Same line for a normal fight | Reuse for consistency. |
| `Our task is not done...` | Same line for an objective fight | Reuse for consistency. |

---

## 5. Smaller points

- Save/reload: all card text must come from saved fields (cause word, names, count), not from live combat state, which `_resolve_forced_retreat` drops. READ: `FlowRuntime.gd:1259-1278`.
- Accessibility: the cue is text plus a soft visual change, never colour alone. Card text must be readable by screen reader. Target sizes as in 3.2.
- Engine: Tween APIs above (`create_tween`, `set_trans`, `set_ease`, `tween_method`) are already used in `CombatBoardScreen.gd`. I read `config/features` is not part of this review; confirm 4.6 API only, no 4.7 changes adopted.
- Scope: this file proposes. No code, no `.tscn`, no theme change. Structure goes in `.tscn`, reusable treatments in `LivingTreeSystem.tres` when built.
- Not in scope (report only): a mid-fight lever for the player (for example "call a pause"); the Echo bark text; the history line text; the GDD line for "standoff".

---

## 6. Ranked recommendation for Jeff (5 lines)

1. **Add a two-step quiet warning (`stall_level` 1 and 2), no numbers, no lever.** It explains the wait and prepares the card. Without it the standoff is a silent cut after minutes of nothing.
2. **Fire it with a short settle beat and a cross-fade into the compact retreat card.** Reuse the card shape, the blue-grey title, the 56-high button. No red, no shake.
3. **Name the cause in words when the log shows one** (`Kweku froze.`). Show a calm line only when fear really fell. No badge on the Echoes. The history holds the record.
4. **Keep F1, K1, S2 as round 1 says. Make P1 progressive:** a `To the Sanctum` button from the second standoff. Mark the fight at the prebattle screen (`They stalled here before.`). This is the answer to the boredom loop.
5. **Do not fast-forward the quiet rounds yet.** Keep the wait as the natural price against the free-reset risk. Revisit after a playtest that counts stalls per path.

### Questions only Jeff can answer
1. Do you want the quiet warning at all, given the player cannot act in the fight?
2. May the card name the cause (`Kweku froze.`)? It teaches the player. It is not a number.
3. May the Sanctum button appear from the second standoff?
4. Title: `Nobody moved` or `Standoff`?
5. Should the last quiet rounds play at Fast regardless of the player's speed choice?
6. Do you want audio and haptic hints at all (no audio layer found)?
7. Should a mid-fight player lever exist (a design task, not feel)?

---

## OPEN — questions and assumptions
ASSUMED: The player has no tactic lever during a running fight (only speed and manual step) | WHY: `CombatBoardScreen.gd` shows speed and manual buttons; `cta.retreat` is wired in the prebattle modal (`:1195-1205`) and `encounter.retreat` is handled before combat | WRONG IF: another action (a mid-fight command) exists in a screen I did not read, or the directive can change during combat
ASSUMED: There is no audio or haptic layer in the project | WHY: my grep for audio and haptic terms in `ui/` and `core/` returned no file | WRONG IF: a layer exists under another name or outside those folders; then the sound and haptic hints in 2.6 should use it
ASSUMED: A 15-round stall is minutes of play at Normal speed (about 105 steps, about 2.6 minutes in my example) | WHY: step delay 1.5 s (READ), 7 actors in my example, one step per actor per round | WRONG IF: a round resolves in fewer visible steps, or real stall fights have fewer actors; measure one real stall
ASSUMED: `#7AB5C8` (Info blue) gives readable contrast for a text line on the dark board | WHY: it is the Living Grove Info colour for bright, visible text | WRONG IF: the board background under the line is light or busy; compute contrast at build
ASSUMED: A repeat of the stalled fight stalls again (round 1 assumption kept) | WHY: round 1 and D-109 describe the same `encounter_id` and deterministic combat | WRONG IF: a rerun differs; then the boredom loop in 3.4 is weaker
ASSUMED: The cause of a stall can be read from recorded events (refusal or guard actions in the last rounds) | WHY: `CombatService.gd` returns `refused: true` in action results; guard actions exist | WRONG IF: events are not kept per round, or the cause is a position block with no event; then only the generic line is possible
BLOCKED: Does the path have a turn limit? Without one, K1 plus S2 is a free delay | CHECKED: round 1 file (also BLOCKED), `ActiveStageService.apply_retreat_return` per round 1 | NEED: `mechanics-developer`
BLOCKED: Is there an out-of-combat fear change API for E1, and does a small drop change a visible emotion band? | CHECKED: round 1 (no API found) | NEED: `mechanics-developer`; `mid-game-designer` for the size
BLOCKED: Does passive time income (`economy.settle_time`) grow with turns? If yes, a free delay pays | CHECKED: D-113, D-114 only name it; not examined | NEED: `mechanics-developer` or Jeff
BLOCKED: Jeff's answers to the seven questions in section 6 | CHECKED: `ANSWERS.md` word rules (#86, #87), D-107, D-111, D-115 | NEED: Jeff

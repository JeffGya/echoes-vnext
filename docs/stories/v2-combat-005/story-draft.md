# V2-COMBAT-005 Combat visual language (PARKED DRAFT)

**Status of this file:** the story is in the backlog as a Draft (Notion page and CSV row, 2026-10-10).
Jeff approves wording, order and wave before it becomes Ready. Every value below is a **PROPOSAL** unless it carries a source.
Design inputs: `mockups/stop-short-pr1-shipped-tell.html` (the tell that shipped in follow-up #6 PR1) and `mockups/stop-short-pr2-parked-visuals.html` (the Hold links, the Return route hint and the rejected dotted remainder, parked here).
Working name: "Combat visual language". Date: 2026-10-10.

Jeff's brief (2026-10-10): a story where he digs deeper into the UI and visual language of
combat and objectives. It works together with skills, statuses, the damage indicator, the order
(initiative) panel and the other combat UI, feel and art. Reason: combat's UI and visual language
is sparse. Example: how to show that an Echo feels safer around allies WITHOUT suggesting that its
defense gets a bonus. A Hold link was rejected because it implies a bonus (decisions.md V55).

---

## 1. Backlog row (CSV shape)

| Column | Proposal |
|---|---|
| **Story** | Define and build one visual language for combat and its objectives, so the player can read skills, statuses, damage, turn order, objective state and each Echo's reasons on a phone screen, without any word or shape that suggests a rule the simulation does not have. |
| **Code** | V2-COMBAT-005 |
| **Summary** | Combat shows what happens, but its visual language is sparse and grew one tell at a time. This story designs the whole set together: marks, statuses, damage indicators, the order panel, objective cues and the cues for an Echo's state of mind. It then builds them in rounds, so the player reads the fight without reading numbers. |
| **Area** | Realm / Tactical (same as V2-COMBAT-003.5; V2-COMBAT-004 uses Economy / Support) |
| **Theme** | Combat |
| **Type** | New |
| **Priority** | P2 (PROPOSAL; V2-COMBAT-003.5 is P2, V2-COMBAT-004 is P1) |
| **Wave** | Foundation (PROPOSAL; Jeff decides. The CSV has only Foundation and Expansion.) |
| **Horizon** | Foundation (PROPOSAL) |
| **Epic** | Tactical Guidance (PROPOSAL; same epic as V2-COMBAT-003.5) |
| **System Area** | COMBAT / UI (PROPOSAL; check the allowed values in Notion first) |
| **Prefix** | COMBAT |
| **Legacy Source** | (empty) |
| **Order** | 262.9 (PROPOSAL). V2-COMBAT-004 is 262. V2-INFRA-009 (Godot 4.7 migration) is 262.8. Jeff said other stories in movement-model order come before this one, so the number may need to move later. Jeff decides. |
| **Status** | Draft (not Ready, because the design pass is not done) |
| **Spec State** | Open (PROPOSAL). The scope is clear. The visual rules are not designed. |
| **Dependencies** | V2-COMBAT-003.5 (the stop-short tell is the first set of rules). V2-COMBAT-004 (see section 4: it reads "each Echo's response" and must consume this language, or this story must restyle what it ships). V2-INFRA-009 is a soft dependency (see carry-in 7). |
| **Source GDD** | To be filled by the design pass. Candidates to check: Working GDD sections on combat readability, emotion display and objectives (grep `docs/canon-index.md`). `docs/movement-model.md` section 7.5 and section 19 for the stop-short rules. Not read for this draft. |
| **Repo Evidence** | See section 7. |

### Definition of Done (PROPOSAL)

1. A written visual-language specification exists for combat. It covers: skill marks, statuses, damage indicators, the order panel, objective cues, and the cue for an Echo that feels safer near allies.
2. The specification has a "no false rule" check. No cue suggests a game rule that the simulation does not have (for example a defense bonus).
3. Every cue has a live trigger in play, or it is not built (no dead-end visuals).
4. The cues are built in rounds, backend before frontend. Each round ends with a compile check and a filtered test run.
5. The order panel works on a phone (carry-in 8).
6. Every carry-in item in section 3 is either done, or moved to a named later story by Jeff.
7. Full suite green. Docs and CONVENTIONS updated. Jeff has play-tested on a phone-size window.

### Exit Criteria (PROPOSAL; each one is checkable)

| # | Check | Who checks |
|---|---|---|
| E1 | Order panel rows are at least 48 px high and tappable at 844x390. No row is hidden. No action text is clipped. Render fixture `combat_initiative_full` (8 rows) with `scripts/screenshot.gd` to prove it. | Play test, QA |
| E2 | No raw action id (for example `actor.refuse`) shows in any row, at any size. A test lists every action type and checks its row text. | QA |
| E3 | The left turn list and the bottom Echo cards do not hide any Echo at 844x390 or at one tall phone size. | Play test |
| E4 | The cue for "feels safer near allies" shows in play. A reader who is shown the cue and asked "does this Echo get stronger defense?" answers "no" (Jeff judges in the play test). | Jeff |
| E5 | The cause of a stop is visible without selecting the Echo, or Jeff records that the reason bubble and the bark are enough (open question Q5). | Jeff |
| E6 | With the stop-short flag OFF and the new cues OFF, the board looks exactly as before. | QA |
| E7 | Every mark follows the rules from decisions.md #109: rare marks, shape not colour alone, Cream with a charcoal edge. If Jeff changes a rule, the change is recorded. | QA |
| E8 | A frame-cost measurement of the combat draw calls exists, before and after, on the same fight. | QA (measurement run by the main chat) |
| E9 | The HP bar draw order is decided and written down (carry-in 5). | Jeff |
| E10 | The Godot 4.7 check passes for every API this story uses, or the story lists what changed. | QA |
| E11 | No ID and no code word shows in player text. Player text follows the project voice, not STE. | Jeff |

---

## 2. Scope

### In scope (PROPOSAL)

- Skills: how a skill, its reach and its mark read on the board.
- Statuses: Guard, Hold, Observe marks, effect chips and any other status. One consistent set of shapes, words and rest poses.
- Damage indicator: the number, its position, and how it avoids the HP bar and the marks.
- Order (initiative) panel: redesign for phones (follow-up #16).
- Objectives: how the banner and board cues show the objective and its state, for COMBAT, PURIFY_SHRINE, RECOVER, PROTECT, ENDURE, PURSUE and GUIDE_SPIRIT. Which objectives need a new cue is a design-pass question.
- State-of-mind cues: how to show that an Echo feels safer near allies, with no defense-bonus meaning.
- The Return route hint (R-A: faded floor hint, three dashes, open chevron) and its `return_cell` snapshot field. These were parked here by V55.
- Motion, art and audio direction for the cues above (placeholder first, final art pass at the end).
- The carry-in items in section 3.

### Out of scope (PROPOSAL)

- Combat rules, tuning and `data/balance.json` values. If a cue needs a new rule, the design pass stops and reports (this is an `sr-game-designer` decision).
- New stop-short behaviours (Range is deferred to the weapons story).
- New guidance pings and the Echo response loop (that is V2-COMBAT-004).
- A telegraph of intended locations. Jeff rejected the dotted remainder: the game does not show an intended location for one actor, unless it shows it for all actors (V54). This story keeps that rule. It may reopen it only if Jeff asks.
- Hold links, and any line or tie between allies that suggests a bonus (V55). Not built. The `anchor_actor_ids` field is not built.
- Planned-remainder snapshot fields (`planned_end_cell`, `planned_remainder`). Not built (V54).
- Non-combat screens.
- Enemy-side visual language, unless Jeff adds it (open question Q7).
- The Godot 4.7 migration itself (V2-INFRA-009 owns it).

### Rules this story keeps (source: decisions.md #109, V52, V54, V55)

1. Marks are rare. A common event gets no new mark.
2. Shape carries the meaning. Colour alone never does.
3. Cream with a charcoal edge. No new hue until Jeff decides.
4. The marker sits outside the Echo. The HP bar draws on top of marks (V52), pending carry-in 5.
5. No hop for a selected Echo, or at Fast speed.
6. The game does not show an intended place for one actor unless it shows it for all.
7. A cue must not suggest a rule the simulation does not have.
8. Echoes never explain the simulation to the player. Text is short and everyday. Mythic words are rare.

---

## 3. Carry-in items

Each item has its source. Each is a PROPOSAL for what this story does with it. Jeff can move any item out.

| # | Item | Source | Proposed handling |
|---|---|---|---|
| 1 | Guard motion on EVERY guard, without the hop when it is not a stop-short. | Jeff, V51 (3), play test 2026-10-09. V41 kept ordinary guards unchanged for follow-up #6. | In scope. Needs a rule for when a plain guard shows the lean and the ring, and whether that breaks "marks are rare". Decide in the design pass. |
| 2 | Older defect: `_format_action` leaks raw action ids. The fallback is `return atype`. | decisions V42. Code: `ui/screens/combat/CombatBoardScreen.gd` (function `_format_action`, near line 1130). | In scope as a **bug**, not an enhancement. Per your working rule, bugs are fixed promptly. Option: Jeff moves it to a small bug PR now. See Q2. |
| 3 | The left turn list and the bottom Echo cards hide Echoes (camera safe area). | Needs a source. Not found in the files read. It matches follow-up #16 problem 2 ("rows 7 and 8 are hidden") and Jeff's play tests. | In scope. Source line for this item is **unverified**; see OPEN. |
| 4 | The cause shows only in the reason bubble and the bark, since the cause badge was removed for Guard and Hold. Observe keeps its badge. | decisions #109 (Word chip). | In scope. Decide whether the cause needs a second place (E5, Q5). |
| 5 | The HP bar draws after all tokens, also with the feature off. A Guard arc passes behind it. | V52 (bar on top), V53 (accepted, QA F2). | In scope as a decision: keep, or change. Jeff accepted it for now. |
| 6 | The frame cost of the draw calls is not measured. | Design record for follow-up #6 (draw code is not covered by any test, decisions #109). | In scope. A measurement run, planned by a subagent and run by the main chat (CLAUDE.md "Long runs"). Needs a before and after. |
| 7 | Godot 4.7 check. | `project.godot` `config/features` says 4.6. V2-INFRA-009 (order 262.8) owns the migration. | In scope as a check only. Confirm that every draw API the story uses is not deprecated or renamed in 4.7. Do not migrate here. |
| 8 | Redesign the initiative panel for phones. Measured: rows are 21 px high with 4 px gaps (target is 48 px); at 844x390 the panel overlaps the Echo cards and rows 7 and 8 are hidden; action text is clipped at every size; the emotion label is font 11 and may fail contrast. | `docs/stories/v2-combat-003.5/followup-tasks.md` item 16, task `task_initiative_panel_phone`. Jeff kept the layout unchanged in Story 2 (decisions #75). | In scope. Rows stay tappable, because they lock the camera on an actor. Load the `game-ui-ux-echoes` skill. No `core/` change. |
| 9 | Final art pass items from design 11.4 "Later (final art, #16)": `StopShortLayer` (`.tscn`), Hold links, dotted remainder, "Moments", audio, narration style, second row line, screen-space badge, floor and badge ripples. | `followup-6-design.md` section 11.4. | In scope with two changes: Hold links and dotted remainder are **dropped** (V55, V54). `StopShortLayer` `.tscn`, screen-space marks, audio and narration stay. "Moments", the second row line, the screen-space badge and the ripples need a design-pass decision. |
| 10 | Return route R-A hint and `return_cell`. | V54 (2), V55 (3). | In scope. Needs core to expose `return_cell`, so this has a backend subtask first. It only exists if V2-COMBAT-003.5 or a later story builds the Return route benefit (see OPEN). |

---

## 4. Where it could fit instead (V2-COMBAT-004), and why a separate story is recommended

**Option A: fold into V2-COMBAT-004.** V2-COMBAT-004 already says "read each Echo's response and understand the consequence" and "visible action consequences". Its Definition of Done lists "readable tactical preparation" and "visible action consequences". Part of this story is therefore a natural part of it.

**Option B (recommended): a separate story after V2-COMBAT-004.**

Reasons:

1. **One story, one subject.** V2-COMBAT-004 is the guidance loop: briefing, pings, Ping Charge, recipients, response, review. This story is the visual language. Two subjects in one branch is a named cause of rework (CLAUDE.md).
2. **Size.** V2-COMBAT-004 is already large: seven objectives, five pings, snapshots, review. Adding a full visual redesign makes it larger.
3. **Different owners.** V2-COMBAT-004 is mostly `core/` and flow. This story is mostly `ui/`, art and feel, with a small backend part.
4. **Design before build.** The language needs a design pass across skills, statuses, damage, order panel and objectives. V2-COMBAT-004 cannot wait for it.
5. **Risk of mixing.** V2-COMBAT-004 needs a state-of-mind cue and a "response reason" cue. If it invents them alone, they will not match the stop-short tell.

Cost of the separate story: V2-COMBAT-004 ships first with visuals that this story may restyle.

Proposed mitigation (PROPOSAL):

- V2-COMBAT-004 uses the rules in section 2 (the seven kept rules) for any new cue, and builds its cues as placeholders. The V2-COMBAT-004 story note should say: "placeholder visuals; V2-COMBAT-005 owns the final language".
- V2-COMBAT-004 does not build a new status mark, damage indicator or order panel change without asking whether it belongs here.
- Jeff may choose to pull only the cues that V2-COMBAT-004 itself needs (the response reason cue) into V2-COMBAT-004, and keep the rest here. Jeff decides (Q1).

---

## 5. Open questions for Jeff

| # | Question | Why it matters |
|---|---|---|
| Q1 | Does the "response reason" cue for V2-COMBAT-004 stay in V2-COMBAT-004, or does it wait for this story? | Decides whether 004 ships with placeholders. |
| Q2 | Is the `_format_action` raw-id leak a bug to fix now in a small PR, or does it stay in this story? | Your rule: fix bugs promptly. It is visible to players today when the flag is off. |
| Q3 | Wave and order. Is Foundation, order 262.9, right? Or later, after the other movement-model stories? | The CSV only has Foundation and Expansion. |
| Q4 | Which Echo state of mind does the "safer near allies" cue show? The Echo's feeling only, or also the fact that allies are close? Must it show on the board, in the order panel, or only in the reason line? | The rejected Hold link showed the allies. The cue must show a feeling and not a stat. |
| Q5 | Is the reason bubble plus the bark enough to show the cause, or do you want a second, always-visible place? | Carry-in 4. |
| Q6 | Colour: do you keep "Cream with a charcoal edge, no new hue", or does this story open a small palette for statuses? | Shape-not-colour-alone still holds. |
| Q7 | Does the language also cover enemies (their statuses and intent), or only Echoes and the board? | Rule 6: show intent for all actors or for none. This story must keep that rule. |
| Q8 | Does this story include objective cues for all seven objectives, or only those with a known readability gap? | Decides size. |
| Q9 | The Return route R-A hint needs a Return route benefit in core. Which story builds the benefit? PR2 of follow-up #6 now builds only the prefix-cell search (V55 (3)). | Without the benefit, the hint has no trigger (dead-end visual). |
| Q10 | Who writes the player text for new chips and lines? The proposal is: agents propose, you approve each line. | Player-facing copy is your decision. |
| Q11 | Should the final art pass (audio, `StopShortLayer` `.tscn`, narration) be a second story, so this story ends at "placeholder language, playable"? | One story, one subject. Final art may be a different subject. |

---

## 6. First three subtasks (PROPOSAL)

Rules: backend before frontend. One story, one subject. Every story's first subtask confirms contracts. The story ends with a Docs + Commit subtask.

1. **Contracts and design pass** (`sr-game-designer`, with `mid-game-designer` for the spec).
   - Confirm contracts first: snapshot fields that combat UI reads (`last_actor_action`, `stop_short`, `is_marked`, `mark_kind`, `PLAYER_SAFE_FIELDS`), the `CombatTokenLayer` draw order, and the action types behind `_format_action`.
   - Inventory every cue that exists today (skill, status, damage, order panel, objective banner). Mark each as live or dead-end.
   - Write the language rules: what each cue means, what it never means (the "no false rule" check), and how it behaves at each zoom and speed.
   - Decide the open questions with Jeff. Stop if a cue needs a new simulation rule.
   - Decide the `return_cell` backend need (carry-in 10) and list any backend subtask.

2. **Art, feel and UI pass with cross-review** (`sr-game-artist`, `game-feel-developer`, `ui-ux-designer`, in rounds).
   - Each agent reads the others' notes and builds on them. No isolated parallel reports.
   - Output: a mockup of the language, a motion table, and a UI structure note. Include the phone order panel and the "safer near allies" cue.
   - Jeff reviews the mockup before any build starts, as he did for the stop-short work.

3. **Build in rounds** (`mechanics-developer` first, then `ui-ux-designer` and `game-feel-developer`).
   - Round 0, backend: any snapshot field the design needs (for example `return_cell`). Compile check and filtered tests. No `ui/` work starts before this passes.
   - Round 1, bug and layout: `_format_action` raw ids, order panel for phones, hidden Echoes.
   - Round 2, cues: status and state-of-mind cues, damage indicator, objective cues.
   - Round 3, motion, then measurement of frame cost (RUN REQUEST to the main chat), then the Godot 4.7 check.
   - Last subtask: Docs + Commit.

QA (`qa-verifier`) verifies each round. The builder never verifies its own work.

---

## 7. Repo evidence (file paths)

- `ui/screens/combat/CombatBoardScreen.gd` (`_format_action`, reason bubble, bark popups)
- `ui/screens/combat/CombatBoardScreen.tscn`
- `ui/screens/combat/CombatTokenLayer.gd` (draw order: shadow, body, label, rings, stance pass, HP bar)
- `ui/screens/combat/CombatTokenPresentationState.gd`
- `ui/screens/combat/CombatTokenVisualConfig.gd`
- `ui/screens/combat/CombatStopShortMotion.gd`
- `ui/screens/combat/CombatMoveTelegraphLayer.gd`
- `ui/screens/combat/CombatDistanceLayer.gd`
- `ui/screens/combat/BarkPopupLayer.gd`
- `ui/components/InitiativeRowItem.gd` and `.tscn`
- `ui/components/ObjectiveItem.gd` and `.tscn`
- `ui/components/EffectChip.gd`, `EmotionChip.gd`, `EchoCardItem.gd`
- `data/shouts/stop_short_text.json` and `core/echoes/StopShortText.gd` (proposed names in design 11.4; confirm they shipped)
- `docs/stories/v2-combat-003.5/decisions.md` (#75, #108, #109)
- `docs/stories/v2-combat-003.5/followup-tasks.md` (item 16)
- `docs/stories/v2-combat-005/mockups/stop-short-pr1-shipped-tell.html` (the tell that shipped) and `stop-short-pr2-parked-visuals.html` (the parked Hold links and Return hint, and the rejected dotted remainder)

Note: the `followup-6-*` working files (design spec V1 to V58, probe results, art, feel and UI pass results) were deleted after follow-up #6 closed. What survives is `decisions.md` #108 and #109 and the two mockups. References above to "V41 to V55" mean the decision numbers of that spec; their content is summarized in #109 and in the rules section of this draft.

---

## OPEN — questions and assumptions

ASSUMED: The Wave value "Foundation", Priority P2, Order 262.9, Status Draft, Spec State Open, Epic "Tactical Guidance" | WHY: the CSV has only Foundation and Expansion; V2-COMBAT-003.5 uses these values and sits next to this story in order | WRONG IF: Jeff wants this after the other movement-model stories (then the order is higher) or in Expansion
ASSUMED: Carry-in 3 (hidden Echoes under the left turn list and bottom cards) is the same defect as follow-up #16 problem 2 | WHY: both describe Echoes or rows hidden at 844x390 | WRONG IF: the camera safe-area defect is a separate bug with its own cause
ASSUMED: "Wave" in Jeff's brief means the CSV Wave column | WHY: the row shape lists it | WRONG IF: he means a delivery wave of another kind
ASSUMED: The Return route benefit is not built yet, so carry-in 10 has no live trigger today | WHY: V55 (3) says PR2 builds only the prefix-cell search | WRONG IF: another story already builds the benefit
BLOCKED: Source for carry-in 3 (hidden Echoes, camera safe area) | CHECKED: followup-tasks.md item 16 and the follow-up #6 design files (grep for safe area, hide); only item 16 matches in spirit | NEED: Jeff or the Story 2 (Combat camera) notes name the exact finding
BLOCKED: Source GDD sections for the Source GDD column | CHECKED: not looked up (no `canon-index.md` grep done; the brief did not name sections) | NEED: the design pass greps `docs/canon-index.md` for combat readability and objectives, then fills the column
BLOCKED: Allowed values for System Area and Epic in Notion | CHECKED: the CSV only; Notion not touched, as instructed | NEED: Jeff or the main chat to confirm before entry
NOTE: Items I did not verify in code: the `data/shouts/stop_short_text.json` and `core/echoes/StopShortText.gd` file names (taken from the PR1 design record and the `_format_action` code, which imports `StopShortText`), and the line number of `_format_action` (found at line 1130 in this worktree). Other claims come from decisions.md #108/#109, design V41 to V55, followup-tasks.md item 16 and the CSV rows. I did not open the mockups or the full art/feel/UI files; I read only the lines that matched my searches.
NOTE: Skills used: none loaded (the repo files answered every question). No Notion call made. No other file edited.

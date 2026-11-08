# V2-ITEM-001a play-test plan (for Jeff)

Branch `claude/vibrant-tesla-x3ejvi`. Code is at `30942c6`; the latest commit `b516f1b` adds this plan. Written in STE. This plan tests the inventory: two panels over the Sanctum, the party pack, moves, discard, and the result cards. All wording in the game is placeholder.

How to use it: do Part 0 once. Then do Parts A to K in order. Mark each item Pass, Fail or Skip. The same list is on a private page with tick boxes (the link is in the chat).

## Part 0. Set up on your machine

### Get the branch as a separate copy (your own folder stays untouched)

1. In your repository folder run: `git fetch origin claude/vibrant-tesla-x3ejvi`
2. Run: `git worktree add --detach ../echoes-vnext-playtest origin/claude/vibrant-tesla-x3ejvi`
3. Check: `git -C ../echoes-vnext-playtest log --oneline -3`. The top line starts with `b516f1b`. The list includes `30942c6`.
4. When you finish the play test, remove the copy with: `git worktree remove ../echoes-vnext-playtest`

### Protect your save before you start

1. Both folders use the project name `echoes-vnext`, so they share one save location (`user://saves/`, file `slot_01.json`).
2. In the Godot editor use Project, then Open User Data Folder. On a Mac I believe it is `~/Library/Application Support/Godot/app_userdata/echoes-vnext/`. I have not verified that on your machine.
3. Copy the `saves` folder somewhere safe if you want to keep an existing save. A New Game can overwrite the slot.

### Open and run the game

1. Start Godot 4.6 and import the folder `../echoes-vnext-playtest` (the one that has `project.godot`). Do not open your own repository folder for this test.
2. The first open re-imports the project and can take a minute. Missing-import errors in the first seconds are normal.
3. Press F5 (Run Project). The game starts at the splash screen.
4. Use a NEW game. Old saves are not supported (ANSWERS #88).
5. Use a window you can resize. You check 1280x720 and 1920x1080.

### The debug console (F1)

1. Press F1 in the running game. The debug panel opens. Press F1 again to close it.
2. Type a command in the panel and press Enter. Log lines print in the same panel.
3. `ase add 500` and `summon 4` give you currency and echoes. I have not run this exact route in the real game: if a command is refused, copy the log line and send it to me.
4. `inventory produce direct` adds 4 placeholder items: a weapon, a charm, a relic and one consumable. It works in debug builds only. Run it again to add more.
5. `inventory produce gather` adds the same 4 items as finds of the path you are on. It needs a live path.
6. `rankup`, `emotion`, `vow`, `force_claimant_combat`, `force_charge_pressure` and `force_recruit` also exist. You do not need them for this plan.

## Known gaps (not bugs)

Do not report these as new problems. Tell me only if they behave worse than described.

- All wording is PLACEHOLDER. Judge layout, behaviour and feel, not the words.
- The shipping config has NO item definitions yet. So the producer's items show only their kind word (for example `Gear`), not `Placeholder weapon A`. Names on tap will show the kind word. Real names arrive with the item catalogue.
- For the same reason, stacks made by the producer hold 3 at most when they are created, but a stack you merge by hand can grow to 20 (the default stack limit). This is a side effect of the missing definitions, not the final rule.
- Finds gathered on a path are NOT drawn in the pack panel and not counted by the pack button (QA finding F8-02, deferred by you in D-48 to the finds story). The pack can read full while it shows empty sockets on a path.
- The producer cannot make materials, armor or other types from the console. Only weapon, charm, relic and consumable.
- There is no debug command that forces a defeat. Part H needs a real lost fight.
- There is no pack shrink, no pack debuff, no recycling, no equipping, no 001b choice of pickups (D-36, D-41).
- One old test prints `Nonexistent function 'warn' in base 'Nil'` in the test log. It is not part of this story.
- QA did not view motion in real time, the real bottom HUD buttons, or a real touch drag. Part K asks you to judge motion.

## Part A. First look and the rail

Checks the new rail button and where it is enabled (D-34).

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | A1 | Get to the Sanctum screen after the first-run steps. Look at the bottom rail. | A new button (placeholder label, shown as `Stores`) is the FIRST button of the rail, before Party. It has the same selected look as the others. |  |
| [ ] | A2 | Press the new button. | Only the Sanctum inventory panel opens. The party pack and party details do not open (D-35). |  |
| [ ] | A3 | Press the new button again. | The panel closes. |  |
| [ ] | A4 | Open Party. Look at the new button. | It is still enabled on the party screen. Pressing it adds the Sanctum panel beside party details. |  |
| [ ] | A5 | Go to Choose Realm and into a path. Look at the rail or HUD. | The new rail button is not available on the path. The path shows its own pack button on the HUD. |  |

## Part B. Fill the Sanctum and the pack

Checks slots, the Sanctum gauge and the overflow chain (D-16, D-45).

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | B1 | Open the Sanctum panel. Press F1 and run `inventory produce direct` once. Close F1. | 4 tiles appear: weapon, charm, relic (distinct shapes) and one consumable with a count capsule. The gauge counts slots (you expect 4 of 20 after the first call: three pieces and one stack). |  |
| [ ] | B2 | Run `inventory produce direct` five more times (six calls in total). | By my reading each call adds 3 pieces and a consumable (stacks of 3). After 6 calls the Sanctum shows 20 of 20 slots and reads full. Tell me the real number if it differs. |  |
| [ ] | B3 | Run `inventory produce direct` a seventh time. | The Sanctum is full, so the new items go to the party pack (4 slots). Open the pack (Show pack, or Party and the pack button) and check they are there. |  |
| [ ] | B4 | Run `inventory produce direct` an eighth time. | Both containers are full. The new items are lost (overflow). Nothing appears. Check the log lines say they were refused or lost. |  |
| [ ] | B5 | Look at the pack panel when it is full. | It looks heavy: a darker panel, a solid strap line and a consequence line. There is NO count and NO bead gauge in the pack panel (D-36, D-39). The count is only on the party pack button in party details. |  |

## Part C. Panels open alone

Checks D-35 and the layout.

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | C1 | From the Sanctum screen open the Sanctum panel only. Then use `Show pack`. | The pack opens to the right of the Sanctum panel. Both are visible and do not overlap. |  |
| [ ] | C2 | Close both. Open Party. Press the party pack button. | The pack opens to the RIGHT of party details. |  |
| [ ] | C3 | With the pack open in party details, press the new rail button. | The Sanctum panel opens too. Check that all three panels fit in the window. Nothing is cut off at 1280x720. |  |
| [ ] | C4 | Leave the screen and come back. | No panel starts open. Every screen starts with all panels closed. |  |
| [ ] | C5 | Resize the window to 1920x1080 and repeat C1 to C3. | The layout still fits. Tile sizes grow, text stays readable. |  |

## Part D. Move, reorder, merge

Checks `inventory.move.apply` and the drop rules (D-33, D-34, D-37).

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | D1 | Select a piece in the Sanctum panel (click). Read the details area. | The details show the kind, grade, count and where it is. `Move to pack` and `Let it go` buttons are there. |  |
| [ ] | D2 | With the pack open and a free slot, press `Move to pack`. | The piece moves to the first free pack slot. The Sanctum slot becomes empty. Nothing is created or lost. |  |
| [ ] | D3 | Drag a piece from the pack to an EMPTY Sanctum slot. | It lands in that exact slot. |  |
| [ ] | D4 | Drag a piece onto a slot that already holds another piece (inside one panel). | Refused. The piece goes back. A reason line says the slot is taken. No swap happens. |  |
| [ ] | D5 | Drag a piece into a slot of the other panel that is occupied. | Refused with a reason line. |  |
| [ ] | D6 | Reorder: drag a piece to an empty slot in the same panel. | It moves there. Close and reopen the panel: it stays there (positions are saved). |  |
| [ ] | D7 | Fill the pack (4 of 4) and press `Move to pack` on a Sanctum piece. | Refused. The reason line says the pack is full. The Move button also looks disabled or the refusal line shows. |  |
| [ ] | D8 | Merge: drag one consumable stack onto another consumable stack. | They merge into one stack with the summed count (for example x6). The emptied slot is free. (The limit is 20 here, see the known gaps.) |  |
| [ ] | D9 | Move a stack with `Move to pack`. | The whole stack moves, not one item (D-40). |  |
| [ ] | D10 | Use the keyboard: Tab to a tile, Enter to select, then the Move button. | Everything you did with the mouse also works with the keyboard. |  |

## Part E. Discard in the Sanctum

Checks `Let it go`, the modal and the count picker (D-21, D-34, D-33).

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | E1 | Select a piece in the Sanctum panel. Press `Let it go`. | A confirmation opens. The focused button is `Keep it`. |  |
| [ ] | E2 | Press Esc, Back, B (controller) or tap outside the confirmation. | Each means `Keep it`. The confirmation closes and nothing is lost. |  |
| [ ] | E3 | Open it again and press `Let it go` inside the first 0.25 s. | The button does not react in the first 0.25 s (open window). After that it works. |  |
| [ ] | E4 | Confirm the discard. Then try to open another discard at once. | The piece fades away (a leaf let go: fade, small lift, no red, no shake). For about 0.6 s you cannot confirm again. |  |
| [ ] | E5 | Discard from a stack of 3 or more. | The confirmation has a count picker (minus, plus). The default is the whole stack and the minimum is 1. |  |
| [ ] | E6 | Pick a count of 1 and confirm. | The stack drops by 1 and keeps its slot. |  |
| [ ] | E7 | Discard a pack piece in the Sanctum or in party details. | It works, with as many discards as you want (no limit in the Sanctum). |  |
| [ ] | E8 | Look for any way to hold, swipe or drag to confirm. | There is none. Only the button confirms. |  |

## Part F. On a path: read-only pack, one discard

Checks D-33, D-40 and the saved discard mark.

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | F1 | Make sure the pack holds at least 2 pieces (a stack counts as one). Choose a realm and enter a path. | The path shows a pack button on the HUD with one count. |  |
| [ ] | F2 | Open the pack on the path. | It is read-only: a lock line says so, and a token shows `1 left this path`. |  |
| [ ] | F3 | Try to drag a piece out of the pack. | Refused with a reason line. Nothing moves. |  |
| [ ] | F4 | Select a pack piece and press `Let it go`. Confirm. | It is let go. The token changes to used. |  |
| [ ] | F5 | Select another pack piece. Look at `Let it go`. | It looks disabled and the reason line says the one discard is used. |  |
| [ ] | F6 | Press the disabled `Let it go` anyway. | Nothing happens except the reason line. |  |
| [ ] | F7 | Quit the game on the path and use Continue. | The used mark is still used. You do not get a second discard (the mark is saved). |  |
| [ ] | F8 | Check the path layout at 1280x720 and 1920x1080 with the pack open. | The `To the Sanctum` button is not covered. Pack and details sit side by side. |  |
| [ ] | F9 | While on the path, run `inventory produce gather` in F1. | Finds are added to the packs of the path. The pack panel does not draw them (known gap F8-02). |  |

## Part G. Leave early

Checks the leave confirmation and the result card (D-23, D-42).

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | G1 | On a path with pieces in the pack, ask to leave. | A confirmation opens. `Stay` is focused. A row of tiles shows what is at risk, each with the leaf mark. The text names no place. |  |
| [ ] | G2 | The `To the Sanctum` confirm button: press it inside the first 0.25 s. | It does not react in the first 0.25 s. |  |
| [ ] | G3 | Confirm the leave. | A result card opens with ONE row of tiles. Survivors have a solid, heavier border. Lost pieces fade to a dashed ghost with a small lift. There are no lane titles and no place words. |  |
| [ ] | G4 | Tap once while the tiles animate. | The first tap finishes the animation. A second tap on Continue moves on. Continue ignores taps for 0.25 s after the last state. |  |
| [ ] | G5 | Tap or focus a tile on the result card. | A line shows the tile. Today it shows the kind word and the state (survived or lost), because no definitions exist (see known gaps). |  |
| [ ] | G6 | Back in the Sanctum or party screen: open the pack. | Pieces that survived are STILL in the pack. Nothing moved to the Sanctum by itself (D-42). |  |
| [ ] | G7 | Repeat the leave a few times with the same pack (different outcomes may happen). | Each leave rolls every pack piece again. Some are lost, some stay. A piece never moves by itself. |  |

## Part H. Defeat

Checks the defeat card (D-20). There is no cheat for this part.

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | H1 | Enter a path with items in the pack. Lose a fight (send a weak party, or let the party fall). | The defeat card shows one row of tiles. Everything that was in the pack is lost: all tiles fade to ghosts. No sound, no red, no shake. |  |
| [ ] | H2 | After the card, open the pack. | The pack is empty. |  |

## Part I. Finish a path

Checks the stage-clear card and intake (D-30, D-42, D-45).

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | I1 | Fill the pack with 2 pieces. Enter a path and use `inventory produce gather` for new finds. Finish the path. | The stage-clear card shows one row with a small read-only mark (a preview). It names no place. |  |
| [ ] | I2 | Press Continue. | Carried pieces stay in the pack. New finds go to the Sanctum first (free slots), then to a free pack slot, and are lost only if both are full. |  |
| [ ] | I3 | Open the Sanctum panel and the pack. | Check the pieces are where this rule says. Tell me if a carried piece moved by itself. |  |

## Part J. Save and Continue

Checks saved slots and the saved discard mark (D-37, D-33).

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | J1 | Arrange the Sanctum panel (put pieces in chosen slots, leave gaps). Quit the game. Start it again and press Continue. | Every piece is in the same slot. The gaps are still there. |  |
| [ ] | J2 | Quit with the pack holding pieces. Continue. | The pack holds the same pieces in the same slots. |  |

## Part K. Feel

Your judgement on look and motion. There is no right answer: note what you see.

| Done | Id | What to do | What you should see | Result (Pass / Fail / Skip) and notes |
|---|---|---|---|---|
| [ ] | K1 | Is it clear which panel is the Sanctum and which is the pack, at a glance? | They should look clearly different (a light storage chest and a dark leather pack). Say if they look too alike. |  |
| [ ] | K2 | Do the stack counts, the leaf mark and the grade pips stay readable at 1280x720? | No clipped or overlapping text. Say where text is too small. |  |
| [ ] | K3 | Does a lost piece feel calm (no red, no shake) and still clear? | Say if the loss is too quiet or too hidden. |  |
| [ ] | K4 | Does the heavy full-pack look make the risk of carrying clear? | It should read as risk without a number. Say if it is missed or too loud. |  |
| [ ] | K5 | Is the drag and drop comfortable? Do you ever miss a drop target? | Note anything that feels fiddly. |  |
| [ ] | K6 | Turn on the game's reduced motion option if you have one. | Fades become 0.15 s. I do not know where the option lives in the game: tell me if you cannot find it. |  |
| [ ] | K7 | Is anything missing, confusing or surprising? | Free text. This is the most useful line. |  |

## How to report back

- For each item write Pass, Fail or Skip. If Fail, write what you saw in one or two sentences.
- Send me the part letter and the item id (for example `D4`). I can then reproduce it.
- A screenshot helps for any layout problem. Press F1 and copy the last log lines for any error or refusal you cannot explain.
- Tell me the window size and the operating system when it is a layout problem.
- Do not fix anything yourself. Send me the list and I plan the fixes with you.

## Sources

Rules come from `docs/stories/v2-item-001/decisions.md` (D-33 to D-48). The interactive design is `docs/visual-plans/inventory-ui-mockup-v2.html`. Test reports: `step7-qa-report*.md` and `step8-qa-report*.md` in the same folder as this file.

# V2-ITEM-001a play-test plan, second round (for Jeff)

Branch `claude/vibrant-tesla-x3ejvi`, build `a59a23d`. Written in STE. This plan tests the inventory with your approved wording: the Storehouse panel and the Travel pack over the Sanctum, moves, Destroy, and the result cards. New finds now stay in the pack.

How to use it: do Part 0 once. Then do Parts A to K in order. Mark each item Pass, Fail or Skip.

## Part 0. Set up on your machine

### Update your separate copy of the branch (your own folder stays untouched)

1. In your repository folder run: `git fetch origin claude/vibrant-tesla-x3ejvi`
2. If `../echoes-vnext-playtest` still exists, run: `git -C ../echoes-vnext-playtest checkout --detach origin/claude/vibrant-tesla-x3ejvi`
3. If it does not exist any more, run: `git worktree add --detach ../echoes-vnext-playtest origin/claude/vibrant-tesla-x3ejvi`
4. Check: `git -C ../echoes-vnext-playtest log --oneline -1`. The line must start with `a59a23d`. If not, tell me what it shows.
5. When you finish the play test: `git worktree remove ../echoes-vnext-playtest`

### Protect your save before you start

1. Both folders use the project name `echoes-vnext`, so they share one save location (`user://saves/`, file `slot_01.json`).
2. In the Godot editor use Project, then Open User Data Folder. On a Mac I believe it is `~/Library/Application Support/Godot/app_userdata/echoes-vnext/`. I have not verified that on your machine.
3. Copy the `saves` folder somewhere safe if you want to keep an existing save. A New Game can overwrite the slot.

### Run the game from Terminal in a window

1. In Terminal, in your `echoes-vnext` repo folder, set the path to Godot (once per Terminal window): `GODOT="/Applications/Godot.app/Contents/MacOS/Godot"`. Change the path if your app is elsewhere. `"$GODOT" --version` must print a 4.6 version.
2. Import the project again, because the build added files: `"$GODOT" --headless --import --path ../echoes-vnext-playtest`. It takes about a minute and opens no window. If it prints errors, run it once more.
3. Run the game: `"$GODOT" --path ../echoes-vnext-playtest --windowed --resolution 1280x720`
4. For the 1920x1080 checks (C5, F8) close the game and run: `"$GODOT" --path ../echoes-vnext-playtest --windowed --resolution 1920x1080`
5. Use a NEW game. Old saves are not supported (ANSWERS #88). Terminal prints the game's log lines. Copy them if you report an error. Stop the game by closing the window or pressing Ctrl+C.

### The debug console (press F1 in the game, F1 again to close)

1. Type a command in the panel and press Enter. Log lines print in the same panel.
2. `ase add 500` and `summon 4` give you currency and echoes. If a command is refused, copy the log line and send it to me.
3. `inventory produce direct` adds 4 placeholder items: a weapon, a charm, a relic and one consumable. Run it again to add more. Debug builds only.
4. `inventory produce gather` adds the same 4 items as finds of the path you are on. It needs a live path.

## Known gaps (not bugs)

- All wording is your approved copy. Judge layout, behaviour and feel. If you see a line you did not approve, report it (it is a bug).
- The shipping config has no item definitions yet. Items from the producer show only their kind word (Gear, Relic, Supply, Material), not a name. Real names arrive with the item catalogue.
- For the same reason a stack you merge by hand can grow to 20 (the default limit). The producer makes stacks of 3.
- Finds gathered on a path are not drawn in the pack panel and not counted by the pack button while the path is live (F8-02, deferred to the finds story). You see them on the result card when the path ends. After that they stay in the pack.
- Nothing moves by itself between the pack and the Storehouse. New finds that survive a path end up in the PACK (D-49). You move them yourself.
- A move shows no message. The tile moves, and that is the only feedback (the move message was deleted, D-52).
- Spoken labels for screen readers on the leaf mark and on the tile row are removed. You cannot test them in a play test.
- Panel placement, hierarchy, pack discoverability and text size on large and small screens belong to your larger UX redesign. Do not report them as new bugs.
- On a path with the destroy action used, two refusal lines sit under two disabled buttons (F11-03). On the dark path the full pack tone has a weak edge (F11-04). Both are left for the redesign.
- The producer cannot make materials or armor. No debug command forces a defeat. Part H needs a real lost fight.
- Not built: pack shrink, pack debuff, recycling, equipping, the Echoes' choice of pickups (001b).

## Part A. First look and the rail

Checks the new rail button and where it is enabled (D-34, D-35).

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | A1 | Get to the Sanctum screen after the first-run steps. Look at the bottom rail. | A new button labelled `Storehouse` is the FIRST button, before Party. It has the same selected look as the others. |  |
| [ ] | A2 | Press the new button. | Only the Storehouse panel opens (title `Storehouse`, no line under the title). No pack and no party details. |  |
| [ ] | A3 | Press it again. | The panel closes. |  |
| [ ] | A4 | Open Party, then press the new button. | It is still enabled. The Storehouse panel opens beside party details. |  |
| [ ] | A5 | Enter a path. | The new button is not available. The path HUD has its own `Travel pack` button. |  |

## Part B. Fill the Storehouse and the pack

Checks slots, the gauge and the overflow chain (D-16, D-45).

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | B1 | Open the Storehouse panel. In F1 run `inventory produce direct` once. | 4 tiles: weapon, charm, relic (distinct shapes) and a consumable with a count capsule. The gauge reads `4 / 20 spots filled`. |  |
| [ ] | B2 | Run it five more times (six in total). | By my reading each call adds 3 pieces and a consumable stack of 3. After 6 calls the gauge reads `20 / 20 spots filled`. Tell me the real number if it differs. |  |
| [ ] | B3 | Run it a seventh time. | The Storehouse is full, so the new items go to the pack (4 slots). Open the pack (`Open pack`) and check. |  |
| [ ] | B4 | Run it an eighth time. | Both containers are full. The new items are lost. Nothing appears. The log says refused or lost. |  |
| [ ] | B5 | Look at the pack panel at plain, almost full and full (empty it with Destroy or moves to change levels). | Three tones: lighter brown (plain), darker (almost full), near-black (full). The pack panel shows NO count and NO bead gauge. The count `n / 4 spots filled` is on the pack button in party details. No risk line `Heavy` exists any more. In the path view the pack panel says `Almost full.` or `Pack is full. Nothing else fits.` |  |
| [ ] | B6 | Put a piece in the pack and look above the pack button in party details. | A line says `There are items in the travel pack. Items can be lost.` With an empty pack the line is not there. |  |

## Part C. Panels open alone

Checks D-35 and the layout.

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | C1 | From the Sanctum screen open the Storehouse panel only. Then press `Open pack`. | The pack (`Travel pack`) opens to the right of it. Both are visible and do not overlap. The button now says `Close pack`. |  |
| [ ] | C2 | Close both. Open Party and press the pack button. | The pack opens to the RIGHT of party details. |  |
| [ ] | C3 | With the pack open in party details, press the new rail button. | The Storehouse panel opens too. All three panels fit at 1280x720. |  |
| [ ] | C4 | Leave the screen and come back. | No panel starts open. |  |
| [ ] | C5 | Run the game at 1920x1080 and repeat C1 to C3. | The layout fits. Tiles and text stay readable. |  |

## Part D. Move, reorder, merge

Checks `inventory.move.apply` and the drop rules (D-33, D-34, D-37).

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | D1 | Click a piece in the Storehouse panel. | The details show `Kind`, `Grade` and `Count: 1`, where it is (`Storehouse`), and the buttons `Put in pack` and `Destroy`. There is no details title and no hint line. |  |
| [ ] | D2 | With a free pack slot press `Put in pack`. | It takes the first free pack slot. Nothing is created or lost. No message shows. |  |
| [ ] | D3 | Drag a piece from the pack to an EMPTY Storehouse slot. | It lands in that exact slot. While dragging, hints show: `Drop to place`, `Move to storehouse`. |  |
| [ ] | D4 | Drag a piece onto a slot that holds another piece (one panel). | Refused. The piece goes back. The line says `This spot is taken. Choose an empty spot.` No swap. |  |
| [ ] | D5 | Drag onto an occupied slot of the other panel. | Refused with the same line. |  |
| [ ] | D6 | Drag a piece to an empty slot in the same panel. | It moves there. Close and reopen the panel: it stays. |  |
| [ ] | D7 | Fill the pack (4 of 4) and press `Put in pack` on a Storehouse piece. | Refused. The line says `The pack is full.` (only that line, no button name). |  |
| [ ] | D8 | Drag one consumable stack onto another consumable stack. | They merge into one stack with the summed count (for example x6). While dragging the hint says `Drop to combine`. |  |
| [ ] | D9 | Drag a consumable stack onto a gear piece. | Refused: `Only similar items can be joined.` |  |
| [ ] | D10 | Merge until a stack reaches 20, then try to merge more. | Refused: `This stack is already full.` The details show `Full stack` for it. |  |
| [ ] | D11 | Move a stack with `Put in pack`. | The whole stack moves, not one item. |  |
| [ ] | D12 | Use only the keyboard: Tab to a tile, Enter to select, then a Move button. | Everything the mouse does also works. |  |

## Part E. Destroy in the Storehouse

Checks the Destroy confirmation and the count picker (D-21, D-33, D-34, D-51).

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | E1 | Select a piece and press `Destroy`. | A confirmation opens: title `Are you sure?`, the piece, and two buttons `Keep` and `Destroy`. `Keep` is focused. There is no extra line about the place. |  |
| [ ] | E2 | Press Esc, Back, B (controller) or tap outside. | Each means `Keep`. Nothing is lost. |  |
| [ ] | E3 | Open it again and press `Destroy` inside the first 0.25 s. | No reaction in the first 0.25 s. After that it works. |  |
| [ ] | E4 | Confirm, then try to confirm another destroy at once. | The piece fades (calm, small lift, no red, no shake). For about 0.6 s you cannot confirm again. |  |
| [ ] | E5 | Destroy from a stack of 3 or more. | The confirmation has a count picker: `How many?`, minus and plus. The default is the whole stack and the minimum is 1. |  |
| [ ] | E6 | Pick 1 and confirm. | The stack drops by 1 and keeps its slot. |  |
| [ ] | E7 | Destroy a pack piece from the Storehouse screen or from party details. | It works, with no limit. |  |
| [ ] | E8 | Look for any way to hold, swipe or drag to confirm. | There is none. Only the button confirms. |  |

## Part F. On a path: read-only pack, one destroy

Checks D-33, D-40 and the saved mark.

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | F1 | With at least 2 pieces in the pack, enter a path. | The path HUD shows a `Travel pack` button with one count. |  |
| [ ] | F2 | Open the pack on the path. | It is read-only. A token says `1 destroy action left on this path.` There is no lock line. |  |
| [ ] | F3 | Try to drag a piece out of the pack. | Refused: `While on the move you can't organize your pack.` |  |
| [ ] | F4 | Select a pack piece, `Destroy`, confirm. The confirmation says `There is only 1 chance to destroy on this path.` | It is destroyed. The token says `No destroy action left.` |  |
| [ ] | F5 | Select another pack piece. | `Destroy` looks disabled. The line says `No destroy actions left.` |  |
| [ ] | F6 | Press the disabled `Destroy` anyway. | Only the reason line shows. |  |
| [ ] | F7 | Quit on the path and use Continue. | The destroy is still used. No second one. |  |
| [ ] | F8 | Check the path at 1280x720 and 1920x1080 with the pack open. | `To the Sanctum` is not covered. Pack and details sit side by side. With nothing selected the details say `While on the move you can't reorganize your pack.` |  |
| [ ] | F9 | Run `inventory produce gather`. | Finds are added to the path. The pack panel does not draw them (known gap). You see them on the result card at the end. |  |

## Part G. Leave early

Checks the leave confirmation and the result card (D-23, D-42).

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | G1 | On a path with pack pieces, ask to leave. | A confirmation opens. A row of tiles with the leaf mark shows what is at risk, with a line like `3 items can be lost` or `1 item can be lost.` No place words. |  |
| [ ] | G2 | Press the confirm button inside the first 0.25 s. | No reaction in the first 0.25 s. |  |
| [ ] | G3 | Confirm the leave. | A result card with ONE row of tiles. Survivors have a solid heavier border. Lost pieces fade to a dashed ghost with a small lift. No lane titles, no preview mark. |  |
| [ ] | G4 | Tap once while the tiles animate. | The first tap finishes the animation. Then Continue. Continue ignores taps for 0.25 s. |  |
| [ ] | G5 | Tap or focus a tile. | A line shows the kind word and grade and then `Made it through.` or `Lost`. (No names yet.) |  |
| [ ] | G6 | Open the pack afterwards. | Pieces that survived are STILL in the pack. Finds from this path that survived are in the PACK too, not in the Storehouse. Nothing moved by itself. |  |
| [ ] | G7 | Repeat the leave a few times. | Each leave rolls every pack piece again, including finds you kept. Some are lost, some stay. A piece never moves by itself. |  |

## Part H. Defeat

Checks the defeat card (D-20). There is no cheat for this part.

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | H1 | Enter a path with items in the pack. Lose a fight. | The defeat card shows one row of tiles. Everything in the pack is lost: all tiles fade to ghosts. No sound, red or shake. |  |
| [ ] | H2 | After the card, open the pack. | It is empty. |  |

## Part I. Finish a path

Checks the clear card and where finds end up (D-30, D-42, D-49).

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | I1 | Put 1 piece in the pack (3 slots stay free). Enter a path, run `inventory produce gather` once (4 items), finish the path. | The clear card shows one row of tiles and no preview mark. Tell me how many tiles the row shows. I do not know how many of the 4 finds fit. |  |
| [ ] | I2 | Press Continue and open the pack. | The carried piece and the surviving finds are in the pack (4 slots). Nothing from this path is in the Storehouse. |  |
| [ ] | I3 | Move a find to the Storehouse with `Place in storehouse`. | It moves. Only you move it. |  |
| [ ] | I4 | Try the same with a full pack: 4 pieces in the pack, then gather and finish. | Tell me what you see: I expect finds without a free pack slot to be lost or not recorded. This case is not decided yet. |  |

## Part J. Save and Continue

Checks saved slots and the saved destroy mark (D-33, D-37).

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | J1 | Arrange the Storehouse panel with gaps. Quit. Start again and press Continue. | Every piece is in the same slot. The gaps remain. |  |
| [ ] | J2 | Quit with pieces in the pack. Continue. | The pack holds the same pieces in the same slots. |  |

## Part K. Feel

Your judgement. There is no right answer: note what you see.

| Done | Id | What to do | What you should see | Result and notes |
|---|---|---|---|---|
| [ ] | K1 | Look at the pack panel tones: plain, almost full, full. Can you tell them apart at a glance? | You chose near-black for full. Say if almost full and full look too alike, or if full looks too dark. |  |
| [ ] | K2 | Check the full tone on the dark path view. | The panel edge is weak there (known, F11-04). Say if it bothers you. |  |
| [ ] | K3 | Does a lost piece feel calm and still clear? | Say if the loss is too quiet or too hidden. |  |
| [ ] | K4 | Does a full pack make the risk of carrying clear without a risk line? | Only the tone, the departure line and the path words say it now. Say if it is enough. |  |
| [ ] | K5 | Is drag and drop comfortable? Do you miss drop targets? | Note anything fiddly. |  |
| [ ] | K6 | Does the pack button label and the departure line look dim in party details (F11-07)? | In the screenshots they looked about 40 percent dimmer than other text. Tell me if you see it in the game. |  |
| [ ] | K7 | Anything missing, confusing or surprising? | Free text. This is the most useful line. |  |

## How to report back

- For each item write Pass, Fail or Skip. For a Fail write what you saw in one or two sentences.
- Send me the item id (for example `D4`). I can then reproduce it.
- A screenshot helps for any layout problem. For an error or an unexplained refusal, copy the last log lines from Terminal or the F1 panel.
- Add the window size and operating system for a layout problem.
- Report any text you did not approve. It is a bug.
- Do not fix anything yourself. Send me the list and I plan the fixes with you.

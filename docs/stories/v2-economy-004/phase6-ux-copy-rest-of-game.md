# Phase 6 — other player strings with "home" or "stage" (proposals)

Status: ALL TEXT BELOW IS A PROPOSAL. Jeff owns the wording. Nothing is changed in the game.
Rule (Jeff, D-107, D-110): no word "home" (use "Sanctum" or another word); no word "stage" (use "path"). Jeff chose "all player-facing text".
Source: final QA of steps 6.4 and 6.5 (BLOCKED item) plus an audit grep of `ui/` and `core/`.
Notes outside the quotes are in STE.

## A. Buttons and labels

| # | Where (file) | Now | Option A | Option B | Option C |
|---|---|---|---|---|---|
| 1 | Path map screen subtitle (all done), `StageMapScreen.gd:89` | "Realm complete — all stages cleared." | "Realm complete — all paths finished." | "Realm complete. Every path is done." | "The realm is finished." |
| 2 | Path map counter, `StageMapScreen.gd:91` | "(%d/%d) stages completed" | "(%d/%d) paths finished" | "%d of %d paths finished" | "(%d/%d) done" |
| 3 | Path map, all done label, `StageMapScreen.tscn:124` | "All stages complete." | "All paths finished." | "Every path is done." | "Nothing left to walk." |
| 4 | Path map, enter button, `StageMapScreen.tscn:185` | "Enter next stage" | "Enter the next path" | "Walk the next path" | "Next path" |
| 5 | Path map title, `FlowStageMapState.gd:203` | "Stage Map" | "Path Map" | "The Paths" | "Paths" |
| 6 | Path row name, `FlowStageMapState.gd:83` | "Stage %d — %s" | "Path %d — %s" | "%s — path %d" (swap args) | "%s" (type only) |
| 7 | Path row placeholder, `StageRowItem.tscn:24` (hidden placeholder, code overwrites) | "Stage Name" | "Path Name" | (empty) | |
| 8 | Sanctum button into a path, `SanctumSnapshotBuilder.gd:91` | "Enter Stage" | "Enter the path" | "Set out" | "Walk the path" |
| 9 | Explore screen, last objective done, `StageExploreSnapshotBuilder.gd:371` and `StageExploreScreen.tscn:367` | "Stage Complete" | "Path finished" | "The path is done" | "Finished" |
| 10 | Explore screen return button, `StageExploreSnapshotBuilder.gd:301` | "Return Home" | "To the Sanctum" (same as the panel confirm) | "Go back to the Sanctum" | "Leave the path" |
| 11 | Resolve action (go back to the path), `VentureResolveSnapshotBuilder.gd:201` | "Return to Stage" | "Back to the path" | "Return to the path" | "Continue" |
| 12 | Combat reward choice, `EncounterSnapshotBuilder.gd:613`, `FlowKeeperIntroState.gd:114` | "Carry It Home" | "Carry it back" | "Take it to the Sanctum" | "Carry it" |
| 13 | Vow cooldown line, `VowScreen.gd:247` | "Complete %d more stage%s before pledging again." | "Finish %d more path%s before pledging again." | "Walk %d more path%s before pledging again." | "%d more path%s until you can pledge again." |
| 14 | Vow effect hint, `VowConsequenceService.gd:439` | "Clears when you re-enter a stage." | "Clears when you enter a path again." | "Clears when you set out again." | "Clears on your next path." |
| 15 | Vow effect hint with count, `FlowSanctumState.gd:369` | "%d stage%s honored. Active until the run ends." | "%d path%s finished. Active until the run ends." (same as the count on the vow screen) | "%d path%s honored. Active until the run ends." | "%d path%s finished." |

## B. Story voice (Keeper intro, `FlowKeeperIntroState.gd:130` and `:215`)

| # | Now | Option A | Option B | Option C |
|---|---|---|---|---|
| 16 | "I will bring what was stolen home." | "I will bring back what was stolen." | "I will return what was stolen to the Sanctum." | keep as it is |

Note on row 16: this is a character line in the story voice. The word "home" may be right here. Pick "keep" if you agree.

## C. Notes

- Rows 4, 8, 9, 10, 11 and 12 take their label from the core (snapshot `label`). A new word means a small core edit as well as the UI default and the scene text. Tests that pin the old label move with it.
- Row 10: the same button is called "To the Sanctum" on the confirmation panel. Option A keeps one name for the same action.
- Row 15: the part "Active until the run ends." has no "home" or "stage" and stays unless you change it.
- Do the rules apply to the `Stage` word in internal ids, keys and file names? No. Only text the player sees.

## D. Questions for Jeff

1. One option per row (or your own words).
2. Row 16: keep the story line or change it?

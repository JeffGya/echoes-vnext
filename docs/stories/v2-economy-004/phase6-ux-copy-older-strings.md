# Phase 6 — older player strings with "home" or "stage" (proposals)

Status: ALL TEXT BELOW IS A PROPOSAL. Jeff owns the wording. Nothing is changed in the game.
Rules from Jeff (D-107): no word "home" (use "Sanctum" or another word); no word "stage" (use "path").
"lost" is allowed (Jeff chose it for what is not carried).
Player-facing text follows the game voice; the notes outside the quotes are in STE.
Source: final QA finding F7 (D-110). "Now" is the text in the game today.

| # | Where | Now | Option A | Option B | Option C |
|---|---|---|---|---|---|
| 1 | Stage-end ledger, Echoes row label (`echoes_alive`) | "Echoes home" | "Echoes who made it back" | "Echoes safe" | "Echoes at the Sanctum" |
| 2 | Tooltip of that row | "Each Echo that comes home earns Ase." | "Each Echo that makes it back earns Ase." | "Each Echo that stays alive earns Ase." | "Each Echo that returns to the Sanctum earns Ase." |
| 3 | Small tag on an Echo row | "home" | "safe" | "back" | "alive" |
| 4 | Line when an Echo died | "%s did not come home." | "%s did not make it back." | "%s is gone." | "%s did not return." |
| 5 | Replay tooltip (whole path) | "The party has been here before. The whole stage earns less Ase and Ekwan." | "The party has been here before. The whole path earns less Ase and Ekwan." | "The party walked this path before. Everything here earns less Ase and Ekwan." | "The party has been here before. All of it earns less." |
| 6 | Intel line | "Something new is known about the stage." | "Something new is known about the path." | "The party learned something new about the path." | "The path holds fewer secrets now." |
| 7 | Ledger count | "%d stage(s) honored" | "%d path(s) honored" | "%d path(s) finished" | "%d path(s) kept" |
| 8 | Ledger group header (static) | "Stage" | "Path" | "This path" | "The path" |
| 9 | Button to the next one (`cta.next_stage`, label from the snapshot, default text in `ResolveScreen.gd`) | "Next Stage" | "Next path" | "On to the next path" | "Continue" |
| 10 | Defeat tooltip (uses "lost" as in "lost the fight") | "The party lost, but the fight still earns a small part." | keep as it is | "The party was beaten, but the fight still earns a small part." | "The fight was lost, but it still earns a small part." |

Notes:
- Rows 1 to 4 describe Echoes that survived or died. Option A keeps "made it back"; it does not name the Sanctum and avoids "home". Row 4 option B ("is gone") is the hardest, and it is the only one that says the Echo is dead. Tell me if you want that.
- Row 9: the label comes from the core in the snapshot (`cta.next_stage`). If you pick a new word, the core string also changes (a small backend edit), and any test that pins it moves.
- Row 10 is a different meaning of "lost" (losing a fight). It is allowed by your rule. Pick "keep" if you agree.
- A static node text ("Stage", "home") must be replaced in the scene file as well as in the script.

Questions for Jeff:
1. One option per row (or your own words).
2. Is "path" the right word for the whole level that the game calls a "stage" internally, in rows 5, 7, 8 and 9?

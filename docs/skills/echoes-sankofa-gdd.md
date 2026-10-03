# GDD Routing — Echoes vNext Design Canon

The Working GDD (`docs/Echoes vNext Working GDD.md`) is the only design canon. This file does not copy it. It tells you where to look.

**Claude Code:** the skill `echoes-sankofa-gdd` points here. **Codex / any agent:** read this file, then follow the steps below.

## When to read this file
- A task needs a design term, a rule, a definition or the reason behind a system.
- You must check a doc or a skill against the design canon.

## How to look up a term
1. Grep `docs/canon-index.md` for the term. It returns a line range.
2. Read only that range of the GDD (`sed -n 'A,Bp'`). The GDD is about 43,000 tokens. Never read it whole.
3. If a doc and the GDD disagree, the GDD wins. Report the difference. Do not fix it unasked.

Design numbers, scope and player-facing wording are the user's decisions. Propose them. Do not decide them.

## Where each topic lives
Search for the heading text in `docs/canon-index.md`. Three headings are not in the index: "Storyweight, Step, Standing", "Callings" and "Sanctum pulse". Grep the GDD for those.

| Topic | GDD heading |
|---|---|
| Design priorities | 7. Design Priorities |
| Core loop of the current build | 22.1 Current playable loop in the build |
| Storyweight, Step, Standing | Storyweight, Step, Standing; 10.1 Storyweight is no longer generic progression |
| Vectors and virtue domains | 10.3 Vectors are part of self-shape; 13. Thread Domains and Structure; 13.1 Current Thread domains |
| Callings | 10.4 Callings are remembered or claimed identity; Callings |
| Mythic Echoes | 10.5 Mythic status is a narrative-mechanical threshold; 11.8 What makes an Echo mythic |
| The Weave | 12. The Weave System |
| Threads | 13.2 What a Thread is as a design object |
| Weaving Rite | 14. Thread Recovery and the Weaving Rite; 16.7 Weaving Rite aftermath |
| Distortion | 15.4 (distortion families, severity, persistence) |
| Fear and morale | 17. Fear and Morale in the Weave |
| Continuity | 18. Continuity: Sanctum Progression |
| Currencies, items, equipment | 19. Currencies, Items, and Equipment |
| Sanctum pulse | Sanctum pulse |
| Anansi frame | Anansi’s role (the GDD uses a curly apostrophe; grep "Anansi") |

The six callings are Okofor, Aduro, Onyamesu, Okomfo, Kra-Soro and Sum-Okwanfo. The GDD names them in its vector sections and its calling-family matrix. Code ids: `docs/calling-reference.md`.

## Where the numbers live
- Game values: `data/balance.json`. Not the GDD, and not this file.
- Calling ids in code: `docs/calling-reference.md`.
- V1 to V2 term map: `docs/v2-migration-map.md`.

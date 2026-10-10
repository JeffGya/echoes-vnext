# V2-INFRA-010 — Decision Log

| # | Slug | Decision | Date |
|---|------|----------|------|
| D-01 | saves-stay-as-they-are | Do not skip, defer or batch saves during auto-run. Jeff: this goes against the fundamentals of the game. A change to the cost of one save is allowed only if every safety step stays, and only with Jeff's approval. | 2026-10-06 |
| D-02 | equivalence-break-stops | If the old-versus-new check finds one different path or cost, or a recorded fingerprint moves, stop and report. Wait for Jeff. No re-record without a yes. | 2026-10-06 |
| D-03 | measure-before-fix | The story starts from measured numbers (probe run of 2026-10-06). Board repaint, render, logger and camera are measured as not causal and are out of scope. | 2026-10-06 |
| D-04 | probe-patch-kept | The `TEMP-PROBE` timers are kept as `stutter-probe.patch` in this folder. They are removed from the tree before any commit. | 2026-10-06 |
| D-05 | evidence-saved-reconfirm-at-pickup | The probe logs are saved as evidence (`evidence-2026-10-06.md` and the Notion story). Re-confirm them when the story is picked up. The story may reintroduce the probe timers. | 2026-10-06 |
| D-06 | targets-and-priority-confirmed | Targets confirmed: Stage advance at most 50 ms, Combat step at most 30 ms, excluding the save flush. Priority P1 confirmed. | 2026-10-06 |
| D-07 | no-export-build-yet | No export build exists. The project has no final assets yet. The baseline and the targets use a debug run until an export build exists. | 2026-10-06 |
| D-08 | equivalence-check-removed-after-story | The old-versus-new equivalence check is temporary. Remove it before the PR, as PR #58 did. | 2026-10-06 |
| D-09 | not-picked-up | The story is not picked up now. The probe code was removed from the working tree. The patch file stays in this folder. | 2026-10-06 |

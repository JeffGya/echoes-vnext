# V2-INFRA-011 — Decision Log

| # | Slug | Decision | Date |
|---|------|----------|------|
| D-01 | one-story-for-all-fixes | Jeff: the movement-option cost fixes (cheaper `legal_neighbors`, neighbor cache, `_build_control` once, search-loop overhead, merge analysis) are worth one story. Do not split them. | 2026-10-18 |
| D-02 | equivalence-break-stops | Proposed (same rule as V2-INFRA-010 D-02): if the old-versus-new check finds one different path or cost, or a recorded fingerprint moves, stop and report. No re-record without Jeff's yes. | pending Jeff |
| D-03 | measure-before-fix | The story starts from the measured profile of 2026-10-18 (`evidence-2026-10-18.md`). Re-confirm it at pickup. | 2026-10-18 |
| D-04 | probe-kept-in-folder | The profile scripts are kept in `probe/` and are never committed into `core/` or `tests/`. | 2026-10-18 |

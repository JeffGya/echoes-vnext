# V2-INFRA-009 — Decision Log

| # | Slug | Decision | Date |
|---|------|----------|------|
| D-01 | side-by-side-install | Download 4.7.2 side by side. 4.6.1 stays at `/opt/homebrew/bin/godot` until the cut-over. | 2026-10-03 |
| D-02 | wait-for-pr-92 | The migration starts only after PR 92 is merged. PR 94 must also be merged first. | 2026-10-03 |
| D-03 | fingerprint-moves-stop | If a recorded fingerprint value moves, stop and report. Wait for Jeff. No re-record without a yes. | 2026-10-03 |
| D-04 | target-4-7-no-patch | Target 4.7, tested on the newest patch (4.7.2). Write no patch number in docs or `config/features`. | 2026-10-03 |

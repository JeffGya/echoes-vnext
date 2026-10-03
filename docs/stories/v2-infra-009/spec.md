# V2-INFRA-009 — Godot 4.6.1 to 4.7 migration

Status: Ready. Starts after PR 92 is merged. PR 94 (renderer) is already merged.

## Goal

Move the project from Godot 4.6.1 to Godot 4.7, tested on the newest 4.7 patch (4.7.2 on 2026-10-03).
No behaviour change. No recorded value moves without a named cause.

## Why now

Godot 4.7 released on 2026-06-18. The project declares 4.6.x in `config/features`.
The PR 94 renderer change (GL Compatibility) is merged, so the baseline is stable.

## Out of scope

- Adoption of new 4.7 features.
- iOS and Android export presets.
- The story that removes UI built in `.gd` files (separate story).

## Known breaking changes (confirmed in the 4.7 sources)

| Change | Where it may hit this project |
|---|---|
| Overridden methods need explicit return types | `ui/AppRoot.gd:89` `_ready()` needs `-> void` |
| Packed-array element assignment no longer calls the setter | search `core/` and `ui/` for packed-array writes |
| `Object.is_class` takes `StringName` | search for `is_class(` |
| RichTextLabel image API renames | search for `add_image`, `update_image` |
| `accessibility_live` enum moved | search for `accessibility_live` |
| `CanvasItem` line antialiasing feather removed | 13 antialiased line sites in `ui/` (see list below) |
| `ResourceImporterDynamicFont.hinting` default 1 to 3 | 26 font imports store `hinting=1` |
| Mouse and keyboard device ID constants | search for `DEVICE_ID_` |

Antialiased line sites: `SanctumOccupantLayer.gd`, `SanctumBuildingLayer.gd`, `SanctumPlacementLayer.gd`,
`CombatTokenLayer.gd`, `PartyTokenLayer.gd`, `SituationMarkerDraw.gd`, `VirtueOrbControl.gd`, `WebDrawControl.gd`.

Unconfirmed in the sources. The 4.7 compile check settles them:
the `CONFUSABLE_TEMPORARY_MODIFICATION` warning, return-type inference changes,
and any change to the `.tscn`, `.tres`, `.uid` or autoload formats.

## Phases

1. **Gates.** PR 92 and PR 94 are merged. The tree is clean.
2. **Baseline on 4.6.1.** Run the import, the compile check and the full suite. Record the `Tests:` line.
3. **Install 4.7.2 side by side.** Keep 4.6.1 at `/opt/homebrew/bin/godot`. Do not replace it yet (D-01).
4. **Branch and import.** Run `--headless --import` with 4.7.2. Commit the re-import changes (`.import`, `.uid`) as a separate commit.
5. **Compile check.** Run `--check-only`. Fix `core/` first, then `ui/`. Review every new warning.
6. **Full suite.** Compare with the baseline. If a recorded fingerprint value moves, stop and report (D-03).
7. **Visual test by Jeff.** Check the 13 line sites, the 26 font imports and every screen. Read the terminal for errors. Compare with 4.6.1.
8. **Docs and config.** Set `config/features` to `"4.7"`. Update the version text in `CLAUDE.md`, `CONVENTIONS.md`, `README.md`, `docs/CONTEXT.md`, `docs/MEMORY.md`, `docs/screens.md` and the run commands in `AGENTS.md`. Add an `ANSWERS.md` entry. Use no patch number (D-04).
9. **Cut-over.** Run `brew upgrade godot`. Repeat the compile check with the default binary.
10. **Verification and PR.** One independent `qa-verifier` checks the combined tree. Open the PR.

## Risks

| Risk | Control |
|---|---|
| Determinism: a moved `RandomNumberGenerator` result via `CampaignSeed` | D-03. Stop and report. No re-record without a yes from Jeff. |
| A file-format change in `.tscn`, `.tres`, `.uid` or autoload | Review `git diff` of those files after the import. |
| New compile warnings | Review each one. Do not silence a warning without a reason. |
| Visual change (hinting, line antialiasing) | Phase 7, Jeff's visual test. |
| A stale import cache gives false fingerprint failures | Clear `.godot/` before the baseline and before the 4.7 run. |
| Tool parity (Codex and Claude use different binaries) | Check both resolve to the same version at the cut-over. |

## Cost

The full suite takes about 18 minutes and runs twice. Godot is an exclusive resource: no parallel runs.

## Exit criteria

- The compile check passes on 4.7.x with no new unexplained warning.
- The `Tests:` line matches the 4.6.1 baseline.
- Jeff signs off the visual test.
- `config/features` and the docs name 4.7 with no patch number.
- One independent verifier confirms the combined tree.

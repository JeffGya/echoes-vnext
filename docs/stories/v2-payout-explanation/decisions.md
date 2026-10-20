# Payout explanation — decisions (Jeff, 2026-10-20)

| ID | Decision |
|---|---|
| D-01 | The result screen uses the compact layout, Option 1 (`mockups/resolve-compact.html`): one earnings line, the ledger one tap away, Echo list and vow visible at once. |
| D-02 | Row causes show in a floating tooltip with an arrow (hover, focus or tap), not an inline panel. Each (i) target is 48x48. |
| D-03 | The ledger starts open the first time the player sees a result, then closed. Needs a saved "seen" flag (backend request). |
| D-04 | Word rule: Ase and Ekwan are "earned", not "paid". Objectives are "found and overcome", not "won". |
| D-05 | Stat chips: "Enemies defeated", "Echoes alive", "Rounds" (plus Rank). |
| D-06 | Tooltip voice: option A, told about "the party". The player is the Keeper who observes, so no "you". |
| D-07 | Row names: "Bonus" (not "Pace bonus"), "Replay" (not "Redo penalty" or "Repeat run"). "Replay" shows only when it applies. |
| D-08 | Objectives row tooltip stays as written. No note about earning twice (objective fight and stage). |
| D-09 | A repeat defeat shows a zero row in the same style as the other rows. |
| D-10 | Realm has no payout of its own in the code. Realm only shapes "Replay" and "Realm virtue". Skip a realm-end payout for now (Jeff). |
| D-11 | No "Sanctum share" row or tooltip. Ekwan shows only as "Ekwan earned" with its amount, no (i). |
| D-12 | The stage payout shows on the Resolve card (Jeff, via the backend session). The ledger has two groups, "This fight" and "Stage". One total adds both. Decided: mid-stage cards show fight rows only. The Stage group shows only on the stage-ending card (Jeff). |
| D-13 | No mid-stage stage preview. The UI shows the Stage group only when `stage_payout_rows` exists in the snapshot. No `stage_payout_final` flag. |

## Final tooltip text (PROPOSAL until Jeff reads it in game)

| Row | Text |
|---|---|
| Enemies defeated | Each enemy the party defeats earns Ase. |
| Echoes alive | Each Echo still standing when the fight ends earns Ase. |
| Bonus (zero) | The party was not quick enough to earn a bonus. |
| Bonus (earned) | The party was quick enough to earn a bonus. |
| Replay | The party has been here before. It earns less. |
| Objectives overcome | Only objectives the party found and overcame earn Ase. 2 of 3 so far. |
| Realm virtue | The realm rewards the virtue the party showed here. |
| Consolation | The party lost, but the fight still earns a small part. |
| Carried home | The party left early. It keeps a small part of what it overcame. |
| Carried home (zero) | The party has not overcome anything yet. Nothing is earned. |
| Repeat defeat (zero) | The party already earned the consolation for this. Another loss earns nothing. |

Backend cause ids: `objectives_overcome` (params `overcome`, `total`), `bonus_earned`, `bonus_missed`, `replay`, `realm_virtue`, `defeat_consolation`, `partial_retreat`, `partial_return_home`, `nothing_overcome_yet`, `repeat_defeat`; plus a saved flag for "ledger seen".


Stage-level Replay tooltip (PROPOSAL): The party has been here before. The whole stage earns less.
Proposed keys: `stage_payout_rows`, `stage_payout_ase` (present only on the stage-ending card; names for the backend to confirm).

## Backend contract received (2026-10-20, from the ECONOMY-004 session; uncommitted there)

- Row shape: `{label, delta, currency, cause, params}`.
- Causes: `enemies_defeated`, `echoes_alive`, `bonus_earned`, `bonus_missed`, `replay` (absent when not applicable), `defeat_consolation` (two rows: `params.part` = base or penalty), `repeat_defeat`, `objectives_overcome`, `realm_virtue`, `partial_retreat`, `partial_return_home`, `nothing_overcome_yet`.
- "Found" row and Ekwan row have no cause. The UI shows every Ekwan row as "Ekwan earned", no (i).
- Stage rows: `data.stage_payout_rows`, `data.stage_payout_ase`, only on the stage-ending victory card.
- Ledger flag: save `ui_flags.result_ledger_seen`; action `resolve.ledger.mark_seen`; snapshot `data.ledger_seen`.
- Amounts still move (Phase 4, Phase 5). The UI hard-codes no amounts.

### UI points to settle before the build

1. DECIDED (Jeff): the UI nets the two `defeat_consolation` rows (`params.part` base and penalty) into one "Consolation" row. The (i) tooltip uses the `defeat_consolation` text.
2. Total: the UI sums `delta` of Ase rows, or reads `ase_awarded` plus `stage_payout_ase`. Prefer the data total, not a UI sum.
3. Build waits for Jeff's go and his commit and branch order for the backend work.
| D-14 | Consolation: the UI nets the base and penalty rows into one "Consolation" row (Jeff). Build still held until Jeff says go. |
| D-15 | Ekwan (backend D-28 to D-32, Jeff): fights earn none. Fight cards show Ase only, no Ekwan row or chip. The stage-ending card shows "Ekwan earned" with its amount (`stage_payout_ekwan`, name unconfirmed), no (i), outside the Ase total. No "Sanctum share" row exists. |

Stage Replay tooltip (DECIDED, Jeff): "The party has been here before. The whole stage earns less Ase and Ekwan."

## Build status (UI, 2026-10-21)

- Built: PayoutCausePresentation, CauseTooltip, RewardEntryItem (i) button, Resolve card Option 1 (FightStrip, EarningsSummary, Ledger).
- Tests: `payout_ui` suite (16 tests). Screenshots: `screenshots/<fixture>_<profile>.png`.
- Rows come from snapshot data only. A cause with no row is an unused tooltip entry. An unknown cause shows no (i).
- Row name for `repeat_defeat` is "Consolation" (assumption, Jeff to confirm).
- The theme got additive Payout* variations (`assets/theme/LivingTreeSystem.tres`).

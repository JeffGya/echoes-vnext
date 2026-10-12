# V2-DIRECTIVE-002 phases B+C: numbers

Author: `mid-game-designer`, 2026-10-12. Source: `design.md` (D-43). File edited: `data/balance.json`.
Every new value is PROPOSED DEFAULT unless the Status column says otherwise. Jeff owns the final values.
"Reader pending" means no code reads the key yet. Code was not changed. `mechanics-developer` adds each reader.
All paths start at `data.`. Line numbers were checked on 2026-10-12.

## 0. Three things Jeff must see first

1. **Per-Directive numbers are not inside `data.directives.<id>`.** `DirectiveService.ENTRY_SCHEMA` (`DirectiveService.gd:41`) rejects unknown entry keys. `ConfigService.gd:29` then aborts the load. They sit in `stages.party_stance.directive_profile.<id>`. One small code change moves them (add an optional `party_stance` dict key to `ENTRY_SCHEMA`; cut and paste the two blocks).
2. **`witness_resonance_bonus` is NOT renamed.** The new name inside `contact_effects` is also rejected (`CONTACT_EFFECT_KEYS`, `DirectiveService.gd:52`; error at `:353`). The value is already 0.1, as D-30 wants. The rename is a `mechanics-developer` change (D-24).
3. **Resolved (D-44). Design test K2 conflicted with the "never invert" rule.** K2 wants a Seek party with a Sight Echo to take an intel find over a combat find (authored 0.9 against 1.4). The rule in design section 3 E1 says a bend never inverts the authored ranking. Both cannot hold. Jeff kept the ranking (D-44): a bend only decides ties. K2 is rewritten to a tie case.

## 1. Existing literals moved to config (same value, no behaviour change)

| Key | Value | Why | Consumer (literal today) | Status |
|---|---|---|---|---|
| `contact.bid.reactive_fear_min` | 60 | Same as the literal. Compare `>=`. One key for both copies. | `ConversationService.gd:483`; second copy `StageExploreSnapshotBuilder.gd:191` | reader pending |
| `contact.emotional_fit_modifiers.high_fear_npc_min` | 60 | NPC fear gate in the turn score. A different rule from the bid. Compare `>=`. | `ConversationService.gd:287` (cfg is `data.contact`, see `:247`) | reader pending |
| `contact.turn_count_modifiers.npc_fear_above` | 60 | Literal. Compare `>`. | `ContactConversationService.gd:74` | reader pending |
| `contact.turn_count_modifiers.npc_morale_below` | 30 | Literal. Compare `<`. | `ContactConversationService.gd:76` | reader pending |
| `contact.max_voices_per_turn` | 3 | Most Echoes that speak in one contact turn (D-47 J5). Same value as the literal. Authored in `balance.json` after `turn_count_modifiers`. | `ContactController.gd:170-171` (trim), `ContactController.gd:422` (`<= 3` auto-responses), `ContactConversationService.gd:116` (`<= 3` auto-responses). Reader pending. | PROPOSED DEFAULT |
| `contact.emotional_fit_modifiers.high_fear_broken_charge_bonus` | 0.2 | Bonus for a broken speaker with a frightened `charge` NPC (D-47 J6). Same value. | `ConversationService.gd:292` (`base += 0.2`). Reader pending. | PROPOSED DEFAULT |
| `contact.emotional_fit_modifiers.low_morale_npc_max` | 20 | NPC morale limit for the shared-vulnerability bonus. Compare `<=`. Same value. | `ConversationService.gd:298` (`contact_morale <= 20`). Reader pending. | PROPOSED DEFAULT |
| `contact.emotional_fit_modifiers.low_morale_broken_bonus` | 0.1 | Bonus for a broken speaker when NPC morale is at or below the limit. Same value. | `ConversationService.gd:299` (`base += 0.1`). Reader pending. | PROPOSED DEFAULT |
| `stages.presentation.walk_seconds` | 0.5 | Literal `_TRAVEL_DURATION`. | `StageExploreScreen.gd:71` | reader pending |
| `stages.presentation.snippet_fade_in_seconds` | 0.4 | Literal. | `StageExploreScreen.gd:1211` | reader pending |
| `stages.presentation.snippet_hold_seconds` | 2.1 | Literal. | `StageExploreScreen.gd:1212` | reader pending |
| `stages.presentation.snippet_fade_out_seconds` | 0.5 | Literal. | `StageExploreScreen.gd:1213` | reader pending |
| `stages.presentation.zoom_seconds` | 0.35 | Literal `_ZOOM_DURATION`. Design 10.1 row "other timings". | `StageExploreScreen.gd:56` | reader pending |
| `stages.presentation.preview_fade_seconds` | 0.25 | Literal (two tweens). | `StageExploreScreen.gd:430-431` | reader pending |
| `stages.presentation.flash_half_seconds` | 0.1 | Literal (in and out, one half each). | `StageExploreScreen.gd:1239-1240` | reader pending |
| `stages.presentation.reaction_fade_in_seconds` | 0.35 | Literal. | `StageExploreScreen.gd:1286` | reader pending |

Notes:
- The UI reads no config today (`grep` of `ui/` finds only `AppRoot.gd`). The timing path (snapshot field or `ConfigService` getter) is for `mechanics-developer` and `ui-ux-designer`.
- `stages.party_return_fear_threshold` (60) and `stages.cautious_advance_fear_threshold` (50) already exist. Their readers are `FlowStageExploreState.gd:474` and `:360`. They are not touched. They are a third and fourth "60 and 50", with their own meaning.
- The NPC turn-score numbers (0.2, 0.1, morale 20) are now moved (D-47 J6). Line numbers are as of 2026-10-12 and differ from `backend-plan.md` S4a.
- No key for party size. The snapshot check of 5 (`StageExploreSnapshotBuilder.gd:258`, `party_preview.size() >= 5`) reads the existing `data.sanctum.party_max_size` (5.0) through `ConfigService.get_party_max_size` (`ConfigService.gd:146`). Reader pending (D-47 J5).
- `high_fear_npc_min` is unchanged. Its code still uses the literal 60 at `ConversationService.gd:287`. The reader is pending.

## 2. Picker text (D-34)

| Key | Value | Why | Consumer | Status |
|---|---|---|---|---|
| `directives.directive.scout_carefully.description` | Jeff's Scout line | Copied by script from `decisions.md` D-34, then checked equal after JSON parse. | `ui/screens/venture/DirectiveSelectOverlay.gd:102` | done |
| `directives.directive.seek_signs.description` | Jeff's Seek line | Same. | same | done |

Picker today: it reads `description` from the config entry at runtime. The text in `DirectiveSelectOverlay.tscn:118` is a placeholder that code overwrites. Tests that read `description` pass (`directive`, `directive_cfg`, `directive_char`: 35 of 35).
Finding: the code fallback `_REGISTRY` in `DirectiveService.gd:61,81` still holds the OLD text. It shows only when the config registry is empty. I did not edit `core/`.

## 3. Dial bounds and party aggregation (design 4 rule 1, section 3 "Directive ordering")

Bound = the largest total bend a party can apply to one dial. Rule: bound is under half the gap between Scout and Seek.
Party dial = Directive baseline + sum of (Echo lean / party size), then clamp to the bound. Party size alone never moves a dial.

| Key (under `stages.party_stance.bounds`) | Value | Gap Scout to Seek (half) | Result range Scout / Seek | Consumer | Status |
|---|---|---|---|---|---|
| `exposure_tolerance` | 0.12 | 0.5 (0.25) | 0.18 to 0.42 / 0.68 to 0.92 | reader pending (baseline `directives.<id>.exposure_tolerance` has no reader either) | PROPOSED DEFAULT |
| `stop_willingness` | 0.12 | 0.4 (0.2) | 0.58 to 0.82 / 0.18 to 0.42 | reader pending | PROPOSED DEFAULT |
| `commitment_fraction` | 0.10 | 0.35 (0.175) | 0.40 to 0.60 / 0.75 to 0.95 | reader pending | PROPOSED DEFAULT |
| `escape_bonus` | 6 | 20 (10) | 14 to 26 / 0 to 6 (Seek clamps at 0) | `VentureController.gd:337` reads the Directive value today | PROPOSED DEFAULT |
| `category_weight` | 0.09 | smallest non-zero gap inside one Directive is 0.2 (0.1). The bound now decides ties only (D-44). | each weight moves at most 0.09 | `ActiveStageService.gd:438` (`target_preference`) | PROPOSED DEFAULT |
| `readiness_steps` | 1 | step_budget gap 3 (1.5) | Scout 2 to 3 / Seek 5 to 6 | reader pending | PROPOSED DEFAULT |

Ordering check (Seek is at least Scout on tolerance, steps, commitment; Scout is at least Seek on escape and stop willingness): worst Seek is still above best Scout on every row. The test `mechanics-developer` writes should read these bounds from config.

## 4. Per-Directive stage numbers (see section 0, item 1)

| Key (under `stages.party_stance.directive_profile.<id>`) | Scout | Seek | Why | Consumer | Status |
|---|---|---|---|---|---|
| `commitment_fraction` | 0.5 | 0.85 | Scout reassesses halfway. Seek spends most of its steps (E6). | reader pending | PROPOSED DEFAULT |
| `stop_willingness` | 0.7 | 0.3 | Scout stops readily. Seek passes through (E4). | reader pending | PROPOSED DEFAULT |
| `reveal_stop_kinds` | spotted_ahead, paused_to_read | spotted_ahead | D-29. Scout stops for any new find. Seek stops for an objective or hostile only. Data, so no Directive id in code. | reader pending | PROPOSED DEFAULT |

Unchanged baselines that these bend (already authored): `step_budget` 3 / 6, `exposure_tolerance` 0.3 / 0.8, `escape_bonus` 20 / 0, `target_preference` per Directive. I added a `_comment_exposure_tolerance` to both entries (PROPOSED DEFAULT, reader pending, now the one exposure input per D-05).

## 5. Leans per input (design section 2)

Lean of one Echo = coefficient x dial bound x strength. Coefficient 1.0 = primary lean. 0.5 and 0.25 = secondary.
Strength: Calling and identity leans = `dispositional_floor + (1 - dispositional_floor) x interpretation_width`. Fear and morale = 1.0 (not scaled; fear already lowers Judgment).
Leans are the same for both Directives. The Directive supplies the baseline. Reader pending for all rows. Status: PROPOSED DEFAULT for all rows.

| Key | Value | Why |
|---|---|---|
| `lean_strength.dispositional_floor` | 0.35 | A Standing-1 Echo still leans (D-08). Width comes from `MaturityExpressionService.gd:196` and `BehaviorArbiter.gd:349`. |
| `leans.exposure_tolerance` | anchor -1.0, edge +1.0, sight -0.5, fear -1.0, morale +0.25 | E3. Anchor and Edge primary. Fear primary. Morale small. |
| `leans.stop_willingness` | sight +1.0, edge -0.5, fear +1.0 | E4. Sight and fear primary. |
| `leans.commitment_fraction` | edge +1.0, anchor -0.5, sight -0.5, morale +1.0 | E6. Edge and morale primary. |
| `leans.escape_bonus` | anchor +1.0, sight +0.5, morale_low -0.5 | E5. Anchor primary. Low morale only lowers. |
| `leans.category_weight.intel` | sight +1.0 | E1. |
| `leans.category_weight.combat` | edge +0.5, anchor -0.5 | E1. Fear does not bend combat weight (fear has two primaries already). |
| `state_ramps` | fear 20 to 70; morale neutral 50; low-morale escape lean below 35 | Fear lean 0 at 20, full at 70. Morale lean is signed around 50. Fear scale: `fear_base` max 40, a hard fight reaches 46+. |
| `identity.alignment_gain` | 0.33 | `style_alignment_score` is about 3 at most (`alignment_weight` 0.06 x about 50). Gain 0.33 maps that to 1.0. |
| `identity.tolerance_by_style` | direct +0.5, careful -0.5, low_exposure -1.0, lateral 0, forceful +1.0 | The one mapping from a route style to the tolerance dial. See OPEN (D-35). |

## 6. Capacity and readiness (D-13, D-27)

| Key (`stages.party_stance.readiness`) | Value | Why | Consumer | Status |
|---|---|---|---|---|
| `fear_uneasy_at` | 35 | Party mean fear. Below `fear_base` max (40) is calm. | reader pending | PROPOSED DEFAULT |
| `fear_shaken_at` | 55 | Under the party-return gate (60) so the band shows before the return request. | reader pending | PROPOSED DEFAULT |
| `morale_low_below` | 40 | Inside the EmotionService "shaken" morale tier (25 to 49). | reader pending | PROPOSED DEFAULT |
| `steps_lost` | calm 0, uneasy 0, shaken 1 | Lower only. Uneasy feeds stop willingness through fear lean, not steps (no double count). | reader pending | PROPOSED DEFAULT |
| `low_morale_steps_lost` | 1 | One step. Total loss is capped by `bounds.readiness_steps` (1). | reader pending | PROPOSED DEFAULT |

Effective steps = baseline minus loss, never below 1, never above 6 (code floors stay: `StagePartyMovementAdapter.gd:214-216`).

## 7. Exposure price and stop knobs (E2, E4, D-29)

| Key | Value | Why | Consumer | Status |
|---|---|---|---|---|
| `party_stance.exposure.hostile_radius` | 2 | A known hostile marks cells within 2. | reader pending (path call `StageExploreTurnService.gd:214` passes `{}` today) | PROPOSED DEFAULT |
| `party_stance.exposure.hostile_peak` | 1.0 | Exposure 1.0 at the hostile cell, 0.67 at 1, 0.33 at 2. | reader pending | PROPOSED DEFAULT |
| `party_stance.exposure.price_scale` | 4 | Entry cost = 1 + round(exposure x (1 - tolerance) x 4). Scout at peak pays +3, so a 2-cell detour wins. Seek pays +1, so direct wins. Costs must be int >= 1 (`MovementPathService.gd:269-275`). | reader pending | PROPOSED DEFAULT |
| `party_stance.exposure.pause_trigger` | 0.25 | Pause when exposure x (1 - tolerance) x stop_willingness >= 0.25. Scout at peak: 0.49, pauses above exposure 0.51. Seek at peak: 0.06, never. | reader pending | PROPOSED DEFAULT |
| `party_stance.stop.noise_width_min` | 0.5 | A party with Judgment width at or above 0.5 drops noise stops. | reader pending | PROPOSED DEFAULT |
| `party_stance.stop.noise_weight_max` | 1.3 | Noise = optional find whose category weight is below 1.3. Scout: reward (1.2) can be noise. Intel (1.4) never. Objective and hostile never. | reader pending | PROPOSED DEFAULT |
| `party_stance.stop.pause_cap_per_advance` | 2 (D-45, probe result) | Unused safety key. A pause ends the Advance (D-46), so there is at most one pause per Advance and the cap has no job today. Probe 2026-10-12: no shipped Advance reached 3 pauses. `mechanics-developer` decides: keep or drop. | none (unused); backend decides keep or drop | PROPOSED DEFAULT |

## 8. Counterfactual caps (D-04)

| Key (`stages.party_stance.counterfactual`) | Value | Why | Consumer | Status |
|---|---|---|---|---|
| `replan_cap_per_effective_step` | 3 | Cap = 3 x effective steps (at most 18). Small multiple, never unbounded. | reader pending | PROPOSED DEFAULT |
| `extra_replans_per_reason_class` | 1 | One extra dry run per reason class for the named Echo. | reader pending | PROPOSED DEFAULT |
| `reason_classes` | calling, temperament, fear, morale | The four classes of design section 8. Count is derived from the list. | reader pending | PROPOSED DEFAULT |

Candidate cap = party size + 1 x 4. Party max is 5 (`sanctum.party_max_size`, read by `ConfigService.get_party_max_size`, `ConfigService.gd:146`), so at most 9 dry runs.

## 9. Contact bids (D-11, D-33)

strength = 1 - judgment_weight x width - fear_weight x fear / 100. The effect applies only if strength >= apply_threshold.

| Key (`contact.bid`) | Value | Why | Consumer | Status |
|---|---|---|---|---|
| `suppression.judgment_weight` | 1.0 | At calm fear a wise Echo (width above 0.55) is released from suppression. | `ConversationService.gd:458` (`compute_bids`, no cfg argument yet) | reader pending |
| `suppression.fear_weight` | 0.6 | Fear 50 alone removes 0.3 of strength. | same | reader pending |
| `suppression.apply_threshold` | 0.45 | See above. | same | reader pending |
| `boost.judgment_weight` | 1.0 | Same shape. | same | reader pending |
| `boost.fear_weight` | 0.8 | A frightened Echo refuses the nudge more strongly. | same | reader pending |
| `boost.apply_threshold` | 0.45 | See above. | same | reader pending |

Status for all: PROPOSED DEFAULT. Seek authors no suppression or boost, so these change nothing for Seek.
Check against S4: width 0.3 and fear 10 gives 0.64 (applies, Standing 1 stays silent). Width 0.6 gives 0.34 (released, Standing 6 bids if the role fits). The real width per Standing is not known to me. `qa-verifier` should compute it.

## 10. Resonance bonus (D-16, D-24, D-30)

| Key | Value | Why | Consumer | Status |
|---|---|---|---|---|
| `directives.directive.seek_signs.contact_effects.witness_resonance_bonus` | 0.1 (unchanged) | D-30 value. Applied before the 1.2 clamp at `ConversationService.gd:184`. Name not changed (section 0, item 2). | schema `DirectiveService.gd:54`; no reader in `core/` for the value yet (`grep` finds none) | PROPOSED DEFAULT, reader pending |

## 11. Objective weight in the pool (D-28)

No change. The authored weights already give the right order and margins. Weight leads inside the slack envelope (`StagePartyMovementAdapter.gd`, tie-break list at the top of the file). Envelope = candidates within `max(2, ceil(0.25 x nearest distance))` extra cells of the nearest.

| Case | Numbers | Result |
|---|---|---|
| O1 Scout: intel find at 3, objective at 5 | nearest 3, limit max(2, 1) = 2, cutoff 5. Both inside. Intel 1.4 > objective 1.2. Margin 0.2 is above 2 x 0.09. | Find first. A bend cannot flip it. |
| O2 Seek: same board, find is intel | Objective 1.6 > intel 0.9. Margin 0.7. | Objective first. |
| O2b Seek: find is combat | Objective 1.6 > combat 1.4. Margin 0.2 is above 2 x 0.09. | Objective first. A bend cannot flip it. |
| O3 Seek: find at 2, objective at 7 | nearest 2, limit max(2, 1) = 2, cutoff 4. Objective is outside. | Find first. When the find resolves, the objective is the only candidate. It is reached. |

Watch: Scout objective (1.2) ties Scout reward (1.2). A tie falls to the nearest candidate. If Jeff wants Scout to prefer rewards over the objective, lower Scout `objective` to 1.1 (still under intel 1.4).

## 12. Reserved key names, no value (D-37: game-feel proposes, Jeff approves)

Not in `balance.json`. Suggested home: `stages.presentation`.

| Key name | Status |
|---|---|
| `shaken_shake_seconds` | value pending game-feel (mockup proposal about 0.22 s) |
| `shaken_shake_oscillations` | value pending game-feel (mockup proposal 2 to 3) |
| `shaken_shake_delay_seconds` | value pending game-feel (mockup proposal about 0.60 s) |
| `glyph_settle_seconds` | value pending game-feel |
| `glyph_fade_seconds` | value pending game-feel |
| `chip_settle_seconds` | value pending game-feel |

## 13. Checks run

- JSON parses. `ConfigService.load_balance` accepts it (compile check, exit 0, "Config validation OK").
- Filtered runs, each with a `Tests:` line: `directive` (35 of 35, suites directive, directive_cfg, directive_char), `conversation` (7 of 7), `contact` (22 of 22), `identity` (22 of 22), `explore` (31 of 31).
- Picker text equals D-34, checked by script after parse.
- No full suite run. No command over 2 minutes. No `core/`, `ui/` or `tests/` file changed.

## 14. Rows affected by D-46 and D-47

| Decision | Rows affected |
|---|---|
| D-46 A1 (pause ends the Advance) | Section 7 `pause_cap_per_advance` (unused). Section 7 `pause_trigger` (at most one pause per Advance; the trigger still decides when). Section 4 `reveal_stop_kinds` (a stop ends the Advance). |
| D-46 A2 (first-plan-only naming) | Section 8 `replan_cap_per_effective_step`, `extra_replans_per_reason_class`, `reason_classes`: the dry runs now cover the first plan only. The caps stay as upper bounds. Re-check the 9-dry-run line under the table. |
| D-47 J5 | Section 1 new row `contact.max_voices_per_turn`. Section 8 note on party max 5 (same `party_max_size`). |
| D-47 J6 | Section 1 three new `emotional_fit_modifiers` rows. The old 'Not moved' note is replaced. |
| D-47 J3, J4, J7 | No numbers row. J4 adds a snapshot copy of `stages.presentation` (section 1 timing rows, consumer path). |

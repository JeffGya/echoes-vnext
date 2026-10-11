# V2-DIRECTIVE-002 — Follow-ups

Findings from phase A that are not part of phase A. Each item names its source and its owner today.
Jeff decides scope. Nothing here is fixed unless it says so.

## Contact window (screenshot review, 2026-10-11)

**Decision (Jeff, 2026-10-11, D-22): these are a separate story for later, not part of V2-DIRECTIVE-002. Pick them up another time.** A candidate title: "Contact window: readable Echo cards". Nothing is fixed. No Notion story exists yet; create one only when Jeff asks.

Source: the hand-built fixture screenshot of the Contact window picker (ui/overlays/realm/ContactModal). All four are old. None comes from this story. Owner: not assigned.

| # | Finding | Where |
|---|---|---|
| 1 | Raw calling ids ("onyamesu", "okomfo", "aduro", "sum_okwanfo") show on the Echo cards. This breaks "no IDs in player-facing display". | `ui/overlays/realm/ContactModal.gd` (card `calling` field) |
| 2 | With four Echoes, three cards fit in a row. The fourth card falls below the scroll fold and is cut off. | `ui/overlays/realm/ContactModal.tscn` |
| 3 | The bid badge is a tiny diamond with no text. Colour is the only carrier of the alignment versus fear difference (accessibility rule: colour is never the only meaning). A grey "no bid" badge is not visible. | `ContactModal.gd` `_bid_badge_text`, `_bid_badge_color` |
| 4 | "Hear Them Out" is greyed out until a card is picked and has weak contrast. Probably intended. | `ContactModal.tscn` |

## Phase A QA nits (2026-10-11)

Owner: phase B+C, which edits the same guard.

- `DirectiveService.validate_entry_schema` skips keys with `begins_with("_comment")`. A real key such as `_commentary_x` would be skipped silently. Use `_comment_` or an exact match.
- Guard log text says "is not a array". Use "is not of kind %s".
- The F3 test comment hard-codes "177 .gd files". The number goes stale.
- `ConfigService.get_balance()` returns a deep copy. Phase A added one more call per snapshot in `SanctumSnapshotBuilder` and `FlowStageState`. Cost only.
- The fallback `_REGISTRY` entries in `DirectiveService` have no `contact_effects`. With an empty config the fallback gives Scout no bid boost. Production always has config.

## Open items for Jeff

- **Picker wording (D-18).** Config `description` holds today's picker text for now. Rewrite both lines in the project voice before phase B+C. Notes from the review: "Do not give more than the run asks of you" reads as a hard limit; "Something in this realm is waiting to be found" promises a sure find while the pro says "Higher chance"; both lines are mythic on a routine choice; aim for a short spoken order to people (about 15 words or fewer), no jargon such as "intel", intent and not result, no repeat of pros and cons.
- **`witness_resonance_bonus` (D-16).** Value 0.1 is PROPOSED DEFAULT. It has no reader yet. Phase B+C wires it: +0.1 on the turn resonance score of every conversation under Seek Signs. The key name says "witness" but the effect is broad. Renaming it is allowed under the AGENTS.md exception (no reader exists) and needs Jeff's yes.
- **`encounter_approach.directive_id`.** Phase A writes the right Directive id. Nothing reads the field yet, so players cannot see it.
- **UI per-id label and colour.** `StageExploreScreen.gd` `_label_for_directive` and `DirectiveBadge.gd` match by id. A third Directive shows an empty label there. Phase B+C frontend step reads label and colour from the Directive entry or the theme.
- **Seek Signs friction** (ANSWERS #46: 4 divergences in 535 turns). Players may always pick Scout Carefully. It needs payoffs only Seek Signs gives.
- **Known red test** `movement_arbiter/avoid_overcommit_stays_proportionate` (pace-reward follow-up #11, v2-combat-003.5 decisions #29/#38). Not part of this story.

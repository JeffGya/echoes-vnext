# V2-DIRECTIVE-002 — Decision Log

Source: planning interview with Jeff, 2026-10-10. Plan file: `~/.claude/plans/jolly-cooking-crescent.md`.
Background: the session first planned V2-COMBAT-004. Its dependencies V2-DIRECTIVE-002 and V2-INFRA-004 are not built. INFRA-004 also needs V2-ITEM-002 and V2-ITEM-003. Jeff switched to V2-DIRECTIVE-002 first (D-00).

| # | Slug | Decision | Date |
|---|------|----------|------|
| D-00 | switch-from-combat-004 | Plan V2-DIRECTIVE-002 before V2-COMBAT-004. DIRECTIVE-002 dependencies are all Done. INFRA-004 stays unbuilt and out of scope. The COMBAT-004 recon stays on file. | 2026-10-10 |
| D-01 | three-phases-one-story | Three phases, one PR each, all in this story: A (one accessor + the legacy-key bug), B+C (profile interpretation + stage expression), D (combat expression). C and D never re-record the same values in parallel. | 2026-10-10 |
| D-02 | hazard-addendum-seam-only | The hazard addendum is out. Build the seam only: route scoring reads an exposure input that is empty today. Stage hazard data, concealment and the hazard interrupt wait for the story that creates hazard data. | 2026-10-10 |
| D-03 | profile-inputs | Profile inputs: Calling family, virtue domains (only through the implemented identity state), Standing/maturity band and Judgment, fear, morale. Bonds are an interrupt only (rescue or abandon). Vows wait for V2-VOW-002. Equipment waits for V2-ITEM-003. | 2026-10-10 |
| D-04 | party-profile-bounded-modifiers | Stage party profile uses bounded modifiers plus counterfactual naming. An Echo is named only if removing them would change the route, commitment or stop. The replan per candidate is capped and deterministic. | 2026-10-10 |
| D-05 | revive-exposure-tolerance | Revive `exposure_tolerance` as the one exposure input. Values 0.3 and 0.8 stay PROPOSED DEFAULT. Combat phase D may feed it into `directive_exposure_acceptance`. | 2026-10-10 |
| D-06 | pair-only | Only Scout Carefully and Seek Signs. Press the Path and Hold the Circle need more design and stay out. More stances go to V2-DIRECTIVE-003. | 2026-10-10 |
| D-07 | reposition-regroup-to-combat-004 | `reposition` and `regroup` goal sources belong to V2-COMBAT-004. This story does not create them. | 2026-10-10 |
| D-08 | contrast-at-every-standing | Contrast is required at every Standing. Tests show a Standing-1 and a Standing-6 contrast under each Directive. Standing widens reinterpretation, never obedience. | 2026-10-10 |
| D-09 | directive-only-no-shared-function | Directive only. No shared "influence" function and no ping or guidance code. V2-COMBAT-004 decides how a ping shares the profile terms. | 2026-10-10 |
| D-10 | stop-short-directive-cause | Phase D registers a Directive cause in stop-short (stop-short decision #108). Route scores do not change. New text-bank wording needs Jeff's approval. | 2026-10-10 |
| D-11 | contact-bids-scale-by-profile | Contact bid effects also scale by Judgment and fear. Jeff chose this against the recommendation (read the correct Directive only). Extra risk: new design numbers and moved conversation tests. | 2026-10-10 |
| D-12 | visible-result-why-line | Visible result: a stage "why" line plus a visible route, stop or commitment difference. No new screen and no pre-commit preview. Wording is Jeff's. | 2026-10-10 |
| D-13 | stage-capacity-bound | `step_budget` is the Directive's baseline. Party readiness (for example fear) may lower or raise the effective steps inside a small bound, never beyond the Directive's limits. | 2026-10-10 |
| D-14 | future-directives-data-only | A new Directive must be addable as a data entry plus tests, with no logic change. Unlock stays the existing `unlock_condition: "always"` seam. No unlock vocabulary now. Proof: a test-only synthetic third Directive passes through every consumer, and a grep test blocks Directive id literals in `core/`. | 2026-10-10 |
| D-15 | bad-directive-entry-fails-load | The extended Directive integrity guard makes `ConfigService.load_balance` fail loudly on a malformed Directive entry (missing field, unknown key, unknown unlock condition). The two shipped Directives must pass first. Today the guard only warns and the loader ignores its result. | 2026-10-10 |
| D-16 | wire-witness-resonance-bonus | Wire `witness_resonance_bonus` (0.1, Seek Signs, PROPOSED DEFAULT): +0.1 to the conversation turn resonance score for EVERY conversation under Seek Signs, not only witness contacts. Belongs to phase B+C beside D-11. Open: the key name says "witness" but the effect is broad; renaming it is allowed under the AGENTS.md exception (no reader exists) and needs Jeff's yes. | 2026-10-10 |
| D-17 | accessor-shape | The accessor is a static function that takes the save dict AND the `data.directives` config dict. A save-only static would read the thin fallback registry and lose traversal fields. The instance method `get_active_directive()` delegates to it. Source: phase A subtask 1 contract check. | 2026-10-10 |
| D-18 | picker-text-one-field | The Directive picker shows ONE description field, read from config. No second field. For Phase A, config `description` is set to today's picker text word for word (no visible change). Jeff rewrites both lines in project voice before phase B+C. Reviewed by ui-ux-designer and game-feel-developer (both with the game-design skill, two rounds); both agreed on one field. Wording notes for Jeff: "Do not give more than the run asks of you" reads as a hard limit; "Something in this realm is waiting to be found" promises a sure find while the pro says "Higher chance"; both poetic lines are mythic on a routine choice; the rewrite should be a short spoken order to people (about 15 words or fewer), no jargon such as "intel", intent not result, no repeat of pros and cons. | 2026-10-11 |
| D-19 | degenerate-weights-warn-only | A Directive with degenerate `intent_weights` stays a warning (today's behaviour). Only a malformed entry shape (D-15) aborts the config load. A stage-only Directive with no combat weights stays possible. Only Jeff authors Directives, so the check protects the author, not players. | 2026-10-11 |
| D-20 | one-full-run-serial-alarm-3600 | Phase gate = ONE full serial run. No sharded run on top of it. When the serial run hits its alarm, raise the alarm and run it again. AGENTS.md alarm raised 1500 to 3600 s and timeout hint to 3700000. Phase A serial result: 2043 tests, 2042 passed, 1 failed (the known red test), 53 minutes. | 2026-10-11 |
| D-21 | contract-edits-and-follow-ups | Approved by Jeff: AGENTS.md alarm change, `directive_char` added to the shard map in `scripts/run-tests-sharded.sh` (shard5), suite count 128 to 129 in AGENTS.md, and the four contact-window findings filed in `follow-ups.md` (not fixed). | 2026-10-11 |
| D-22 | contact-window-issues-separate-story | The four contact-window findings (raw calling ids on Echo cards, fourth card below the fold, colour-only bid badge, weak contrast on "Hear Them Out") are a separate story for later. They are not part of V2-DIRECTIVE-002. They are filed in `follow-ups.md`. No Notion story is created until Jeff asks. | 2026-10-11 |
| D-23 | pr106-review-fixes | PR #106 review (Codex): (P1) the `data.directives` subtree is read by `ConfigService.get_directives_cfg`, not by `DirectiveService`; `directives_cfg_of` and `resolve_active` are removed and all callers migrated (AGENTS.md owner rule). (P2) the entry guard requires `pros` and `cons` to hold 2 or more non-empty strings, because the picker has two fixed slots per list. Both fixed under the Auto-fix authorization. | 2026-10-11 |
| D-24 | rename-resonance-bonus | Rename `witness_resonance_bonus` to `conversation_resonance_bonus` when phase B+C wires it. The effect (+0.1 on the turn resonance score of every conversation under Seek Signs, PROPOSED DEFAULT) is not limited to witness contacts. The data entry, `CONTACT_EFFECT_KEYS` in `DirectiveService`, the tests and the docs change in the same step. No reader exists today, so no consumer needs migrating. | 2026-10-11 |
| D-25 | bond-interrupt-seam-only (Q1) | Phase B+C defines the stop-kind slot for a bond interrupt only. No trigger is built. A NEW Foundation backlog story, "Stage bond interrupt", owns the trigger. Jeff: this is part of the core work. Story text is drafted for Jeff's approval before any Notion write. | 2026-10-11 |
| D-26 | stage-judgment-includes-bonds (Q2) | Stage Judgment equals combat Judgment, bond-support term included. AMENDS D-03: bonds are an interrupt AND enter stage routes quietly through Judgment. Stage tests build Echoes with real bonds. | 2026-10-11 |
| D-27 | readiness-lowers-only (Q3) | Party readiness (fear and morale bands) may only LOWER effective steps. A calm party walks the Directive baseline. | 2026-10-11 |
| D-28 | objective-joins-weighted-pool (Q4) | The `objective` weight (Scout 1.2, Seek 1.6) joins the Tier 2 weighted pool inside the slack envelope. Tier 1 no longer pre-empts every find. Scout prefers a nearby intel find to the objective; Seek prefers the objective but may take a much closer find first. An objective outside the envelope is delayed, not lost (Tier 4 stays). Moves recorded stage values with one named cause. mid-game-designer tunes the weights. | 2026-10-11 |
| D-29 | stop-triggers (Q5) | Scout stops for any new find. Seek stops only for an objective or a hostile situation. Pauses per Advance are measured on shipped boards. A cap or merged reveals is added if Scout feels slow. | 2026-10-11 |
| D-30 | bonus-before-clamp (Q7) | The +0.1 conversation resonance bonus applies before the clamp to 1.2. The range 0 to 1.2 holds. | 2026-10-11 |
| D-31 | bridges-deferred-to-hazard-story (Q8) | Bridges are NOT counted as exposure in B+C (default, not Jeff's decision: whether bridges are exposed depends on where hazards go). A NEW backlog story, "Stage hazards and exposure", owns hazards on the stage map and this decision. It fills the D-02 gap. Text drafted for Jeff's approval. | 2026-10-11 |
| D-32 | why-line-on-demand (Q9) | The stage "why" line shows ON DEMAND ONLY (against the recommendation). A stop marker stays visible after every Advance. The on-demand surface also serves as the persistent journey entry, so keyboard and screen-reader users can read it. The trigger (tap the marker, the party token or a button) is designed by ui-ux-designer and approved by Jeff with the design. D-12 stays: a why line plus a visible route and stop difference. | 2026-10-11 |
| D-33 | reactive-threshold-to-config (Q10) | The reactive-bid fear threshold 60 moves to config with the same value. Project rule (ANSWERS #83): no hard-coded tunable values; they live in config unless there is a documented reason. | 2026-10-11 |
| D-34 | picker-wording-now (Q11) | Jeff rewrote the two picker description lines (2026-10-11). They go into `data/balance.json` (`data.directives.<id>.description`) in the data step, character for character:
Scout Carefully: "Watch your step before you move. Proceed with patience. Do not ask more than needed and return back safely"
Seek Signs: "There is much to discover. Push ahead, stay alert but beware the danger. Wanting too much can cost."
Not yet applied to data. Scout line corrected by Jeff on 2026-10-11 ("your step"; "of the run" removed). | 2026-10-11 |
| D-35 | identity-reuses-combat-tables (Q12) | Stage identity leans reuse `MovementStyleService` tables. No new multiplier layer and no stage-only table. | 2026-10-11 |
| D-36 | two-stop-kinds-different-names (N1) | Keep both stop kinds. Internal names proposed: `arrived_at` (walked into a situation), `spotted_ahead` (the walk revealed an objective or hostile), `paused_to_read`. Player wording is Jeff's. | 2026-10-11 |
| D-37 | walk-time-to-config (N3) | The 0.5 s stage walk time moves to config. game-feel-developer measures and proposes a timing in the frontend step. Jeff approves it after seeing it. | 2026-10-11 |
| D-38 | review-items-1-3 | Design 12b items 1 to 3. (1) Picture first: path, stop marker per stop kind (six shapes) and a portrait pulse for a named Echo; Jeff chose option 1 after the mockup `mockups/stage-stop-marker-mockup.html`. (2) A short visible beat when a shaken party's steps drop; game-feel-developer proposes it, Jeff approves after seeing it. (3) A repeat filter on naming: the same Echo and reason are not shown twice in a row, in the journey entry only; the sim and the counterfactual stay unfiltered. | 2026-10-11 |
| D-39 | target-screens-touch-first | Target devices: mobile smartphone, tablet and laptop, landscape mostly, at least 1080 (Jeff). B+C screens are designed and checked at 1280x720 logical (the existing responsive base) and 1920x1080. The 960x540 check is dropped for B+C. Design is touch-first: no hover, 48 unit tap targets, thumb reach, phone safe edges. AGENTS.md still says desktop windows may shrink to 960x540; that contract is NOT changed here (open item for Jeff). | 2026-10-11 |
| D-40 | review-items-4-to-16 | Design 12b items 4 to 16. (4) A copy rule: fear and morale reasons never read as a fault of the Echo. (5) Measure pauses per Advance and why frequency on shipped boards before values are authored (a long run through the main chat). (6) Make at least one Seek Signs payoff visible on the board; the wider balance stays under ANSWERS #46. (7) When the Directive alone decided, the journey entry shows "Directive" as the cause (against the recommendation; wording is Jeff's). (8) The step bar shows the baseline (maximum) steps; steps lost to a shaken party are scratched out (crossed, a shape cue). The snapshot carries baseline and effective steps. (9) Snapshot and UI field details are left to mechanics-developer and ui-ux-designer. (10) The why opens by tapping the stop marker; the party token is an alias. (11) sr-game-artist names tint tokens and the glyph rule; mid-game-designer authors the data keys; ui-ux-designer deletes `_label_for_directive` and `_TINT_BY_ID`. (14) Other timing literals in the stage screen move to config in the same pass. (15) The ANSWERS #83 sweep covers only the lines B+C edits; the rest goes on a follow-up list. (16) The journey entry IS saved (against the recommendation): an additive save field with a repair rule, an opus save-schema pass, no field removed or renamed. | 2026-10-11 |

---

## Detail

### D-00. switch-from-combat-004
**Q:** V2-COMBAT-004 depends on V2-DIRECTIVE-002 and V2-INFRA-004. Neither is built. What should the session plan?
**A:** V2-DIRECTIVE-002 first. INFRA-004 needs the item chain (ITEM-002, then ITEM-003) and is out of scope. Notion lists only V2-DIRECTIVE-001 as an INFRA-004 dependency; its page text already reads the Directive through the accessor DIRECTIVE-002 creates. Fixing that dependency list is a Notion write that needs Jeff's yes.

### D-01. three-phases-one-story
**Q:** The story holds four subjects (accessor + bug, profile interpretation, stage expression, combat expression). How should it be cut?
**A:** Three phases in this story, one PR each: A, then B+C, then D. Phase A is small and fixes a live bug. C and D share `balance.json` and both move recorded values, so they run one after the other.

### D-02. hazard-addendum-seam-only
**Q:** The hazard addendum needs stage hazard data. No such data exists (`known_hazards` is read and never written). How should the story handle it?
**A:** Out. This story builds the seam only. Profile contrast uses terrain, intel value and contact exposure, which exist today.

### D-03. profile-inputs
**Q:** Which Echo inputs may bend how a Directive plays out?
**A:** Identity and state. Bonds act as an interrupt only. This follows movement model 10.1, 10.4 and 10.6.

### D-04. party-profile-bounded-modifiers
**Q:** Stage has one party movement profile per Advance. How do Echo profiles combine into it?
**A:** Bounded modifiers plus counterfactual naming (movement model 11.2, 11.3, test 22.3). Average and lead-Echo options were rejected.

### D-05. revive-exposure-tolerance
**Q:** `exposure_tolerance` is authored on both Directives (0.3 and 0.8) and read by nothing. What now?
**A:** Revive it as the one exposure input for stage. Combat phase D can feed the same key into `directive_exposure_acceptance`.

### D-06. pair-only
**Q:** Do Press the Path and Hold the Circle belong here?
**A:** No. Jeff: "Those need to be designed more, before we can add them." Docs that assign them to DIRECTIVE-002 are stale (`keeper-tactical-guidance-promotion.md:134,459`, `architecture.md:923`).

### D-07. reposition-regroup-to-combat-004
**Q:** Movement model line 1051 lists directive stances as a source of live `reposition` goals. Does this story create them?
**A:** No. V2-COMBAT-004 owns both goal sources. A dated note goes on movement model line 1051.

### D-08. contrast-at-every-standing
**Q:** Must two Standing-1 Echoes with different Callings behave differently under one Directive?
**A:** Yes. Calling, virtue identity and fear give contrast at every Standing.

### D-09. directive-only-no-shared-function
**Q:** How much of the "shared influence" idea does this story build for V2-COMBAT-004?
**A:** None. It reuses the existing profile terms (Judgment, `directive_interpretation_mul`, Calling `directive_mul`).

### D-10. stop-short-directive-cause
**Q:** Register a Directive cause for stop-short in phase D?
**A:** Yes. Four pieces: a registry row, a `cause_strength` arm, a context field, and config. A lone Directive is not a cause today (veto `no_cause`).

### D-11. contact-bids-scale-by-profile
**Q:** Do contact bids vary by Echo profile, or only read the right Directive?
**A:** They scale by Judgment and fear. Recommendation was the other option; this is Jeff's choice. Risk recorded in the plan.

### D-12. visible-result-why-line
**Q:** What visible result closes the story?
**A:** A stage "why" line plus a visible route, stop or commitment difference. The line names an Echo only if the counterfactual says that Echo decided. No numbers.

### D-13. stage-capacity-bound
**Q:** Where does stage capacity come from?
**A:** Directive sets posture. Party readiness bounds the effective steps (movement model 11.2, "Recommended").

### D-14. future-directives-data-only
**Q:** Does the plan account for future Directives?
**A:** It does, after Part A. Blocks found by grep: the load repair in `SaveService.gd:1161-1164` resets any unknown Directive id to Scout; the picker lists in `SanctumSnapshotBuilder.gd:467` and `FlowStageState.gd:122` are literal; substring matches in `ConversationService.gd:466-468` and `ContactController.gd:555`; UI label and colour per id (`StageExploreScreen.gd:1245`, `DirectiveBadge.gd:17`). Part A removes them. Unlock stays `always` (Jeff: keep the seam, no unlock logic now).

### D-15. bad-directive-entry-fails-load
**Q:** The extended integrity guard only warns today. What should a bad Directive entry do?
**A:** Fail the config load loudly (Jeff accepted the recommendation). `ConfigService.gd:33` ignores the guard result today, and `ConfigValidator` has no Directive schema. Phase A must make the loader act on the result.

### D-16. wire-witness-resonance-bonus
**Q:** `witness_resonance_bonus` (0.1, under Seek Signs) has no reader. What should it do?
**A:** Wire it as +0.1 on the turn resonance score of every conversation under Seek Signs. Jeff chose the broad option over "witness contacts only". The repo has no design text for this key (only `data/balance.json:3384`). The effect lands in `ConversationService` turn scoring (`compute_turn_score_from_virtue`), phase B+C.

### D-17. accessor-shape
**Q:** What does the accessor take?
**A:** `static func active_id(save)` and `static func resolve(save, directives_cfg)`. The caller passes `config_service.get_balance().data.directives`. The service held by `FlowRuntime` keeps a save reference from boot; tests that swap `flow_ctx.save_data` left it stale. A static read over the live save avoids that.

### D-18. picker-text-one-field
**Q:** Which text should the Directive picker show after Part A? Today it shows the fallback text from `DirectiveService._REGISTRY`; a registry-driven picker would read config, which has different text. The description is shown only in the picker (HUD and badge show the label only).
**A:** One field read from config. Config `description` holds today's picker text for now; Jeff rewrites it. Reviewers: game feel first preferred a separate `flavor` field; after UX showed the scroll-fold and drift cost, both agreed on one field written in an intent frame. Correction: the orchestrator first said the explore HUD showed the config text; that was wrong.

### D-19. degenerate-weights-warn-only
**Q:** Should degenerate `intent_weights` abort the config load?
**A:** No. Warn-only, as before Part A. Phase A code step had made it fatal by accident; it is reverted to a warning.

### D-20. one-full-run-serial-alarm-3600
**Q:** The serial full suite was killed by its 1500 s alarm. What now?
**A:** Run the serial suite again with a higher alarm; run only one full mode. Jeff: the sharded and serial runs cover the same suites, so doing both is repeated work (LESSONS #34). Result: 2043 total, 2042 passed, 1 failed (known red `movement_arbiter/avoid_overcommit_stays_proportionate`), godot exit 0, 01:29:38 to 02:22:25. No fingerprint or baseline moved; nothing was re-recorded.

### D-21. contract-edits-and-follow-ups
**Q:** May the docs pass change the alarm, the shard map and the suite count, and file the contact-window findings?
**A:** Yes, all four.

### D-22. contact-window-issues-separate-story
**Q:** Where do the contact-window findings go?
**A:** A separate story, later. Jeff: "The conversation UI issues can be a different story for later; note it and we can pick that up another time."

### D-23. pr106-review-fixes
**Q:** Codex flagged two items on PR #106. What was done?
**A:** Both were valid and fixed. P1: a balance subtree getter belongs on `ConfigService` (AGENTS.md lines 479-484); the new `ConfigService.get_directives_cfg` has the same shape as `get_bond_thresholds_cfg`. P2: `validate_entry_schema` now rejects a `pros` or `cons` list with fewer than two entries or any non-string or empty element. No recorded value moved.

### D-24. rename-resonance-bonus
**Q:** What should the key `witness_resonance_bonus` be called once it is wired?
**A:** `conversation_resonance_bonus` (Jeff accepted the recommendation). Allowed under the AGENTS.md exception: the value had no reader, so no consumer is migrated. Do the rename in the phase B+C backend step, with the guard key list, the data entry, tests and docs in one change.

### D-25 to D-37. design questions Q1 to Q12 and N1, N3
Jeff answered the design questions one at a time on 2026-10-11 (Q6 was D-24). Reasons given:
- Q1: "I rather not have things floating around." The bond interrupt gets a Foundation story. "This is part of the core work we need."
- Q2: chose same Judgment as combat, bonds included (not the recommendation). This amends D-03.
- Q4: asked what the `objective` weight was meant to do. Code and docs show it is a fourth category in `target_preference` that tier 1 bypasses. After a worked example, Jeff chose to let it join the pool.
- Q8: "This depends on whether the hazards are also on bridges or not. I can't answer this now." A new story owns it.
- Q9: chose on demand only (not the recommendation).
- Q10: "I would rather not have hardcoded values whenever possible. These should live in config unless there is a good reason."
- N1: "Keep both kinds but tweak wording so it does not feel so similar."
- N3: "Move to config and let game feel developer measure and propose a timing, that I can approve after seeing."

### D-38. review-items-1-3
**Q:** Items 1 to 3 of design section 12b (review proposals).
**A:** Item 1: option 1 after seeing the mockup. Item 2: yes, a short beat. Item 3: yes, a presentation-only repeat filter. The artist's three small assumptions (a faint ring stays on the portrait until the next move; terracotta for 'no way'; where the last-journey entry sits) stay open as frontend details.

### D-39. target-screens-touch-first
**Q:** What is the smallest landscape size B+C must be designed for?
**A:** Jeff: "The game will never be run at 950x540. It will always be a mobile smartphone, tablet or laptop. 1080 at least. Landscape mostly." Keep the 1280x720 logical base as the smallest layout and also check 1920x1080. Drop 960x540 for B+C. Touch-first rules apply. The AGENTS.md rule (resize down to 960x540) is a repo contract and is not edited without Jeff's yes.

### D-40. review-items-4-to-16
**Q:** The remaining open items of design section 12b.
**A:** Answered one at a time on 2026-10-11 (see the row above). Choices against the recommendation: item 7 (show 'Directive' as the cause), item 8 (show max steps with lost steps crossed out; the review had advised no baseline ghosts), item 16 (the journey entry is saved). Item 8 consequence: the step bar needs both numbers. Item 16 consequence: a save-schema change; mechanics-developer decides the field name and lifetime (cleared on a new stage entry is the proposal) and runs the save pass as opus.

### D-41. mockup-v3-approved
**Q:** Which look and motion does the stage stop mockup (`mockups/v3/`) fix for the build?
**A:** Jeff approved v3 on 2026-10-12 and said the build can continue. His choices, with his reasons:
- The stick with the icon and the circle are not wanted. He wanted something subtler that the player can recall at any time, that follows show-don't-tell, and where a click gives more detail.
- **Marker style 3 (Echo bar glyph) is approved.** The board shows nothing extra. A small kind glyph sits on the named Echo's card. A tap on the card or the glyph opens the why card. This replaces the stop marker head, pole and ring of D-38 item 1 and D-40 items 10 and 14. The six stop kinds stay six shapes (D-36).
- Jeff prefers the OLD mockup's Advance button, step icons (big diamonds, red cross for lost steps) and Echo band. Improvements 5 and 10 of the v3 list are not used. D-40 item 8 stays: both numbers shown, lost steps crossed out.
- The shaken run gets the little shake back (D-38 item 2): token and step bar, about 0.22 s, 2 to 3 small oscillations, then still, off under reduced motion. Timing is a PROPOSAL for `game-feel-developer` to measure and Jeff to approve (D-37).
- The board must use real stage maps, not an invented square board. Source: `mockups/review/real-stage-maps.json`.
- Tapping an Echo card opens nothing today, so the card tap is free for the why. Jeff confirmed this.
- The Advance button label is blank in the live game. Jeff confirmed a real defect. It is a separate task, not part of this story.
**Consequences:** `design.md` sections 3a, 8, 8a, 12a and 13 need an edit (marker form, trigger, hit areas, no-Echo-named case). Style 3 needs a home when no Echo is named (open: asked to Jeff). The `stop` field must survive save and load so the glyph returns after a reload (mechanics-developer decides; opus save pass with the journey entry).

### D-42. no-echo-named-party-chip
**Q:** Style 3 shows the stop glyph on the named Echo's card. Where does it go when a stop names no Echo (Directive cause, shaken party, edge stop)?
**A:** A party chip (Jeff, 2026-10-12, the recommended option). A small chip beside the Echo cards holds the glyph. It exists only when no Echo is named. A tap opens the why card. The chip is new UI: `ui-ux-designer` places it so it stays inside the safe area and does not cover the Echo cards.

### D-43. design-approved-and-step-count-removed
**Q:** Is the updated `design.md` (D-00 to D-42) the spec for the B+C build? Does the live step count text (n/n) stay?
**A:** Jeff approved `design.md` on 2026-10-12 (the recommended option). The count text is removed: the step row shows diamonds only, with lost steps crossed out. This keeps design item 5 (no second number) and D-40 item 8. `design.md` section 8 rule 5 and section 13 row 17 follow this answer (the designer edits them). Next: ask Jeff before setting Notion Spec State to Locked.

### D-44. numbers-step-answers
**Q1:** Design test K2 (a Seek party with a Sight Echo picks an intel find over a combat find) conflicts with design section 3 E1 (a party bend never flips the authored ranking). Which wins?
**A1:** The ranking holds (Jeff, 2026-10-12, the recommended option). A bend only decides ties. The category-weight bound stays under half the smallest gap (0.09 against a gap of 0.2). K2 is rewritten to use a tie case (reward against intel at 0.9 each, or Scout objective against reward at 1.2 each).
**Q2:** Where do the per-Directive party numbers live?
**A2:** In `data.stages.party_stance.directive_profile.<id>` (Jeff, the recommended option). No core change. A new Directive needs an entry in `data.directives` and one in `party_stance`. The Directive entry schema is not extended.
**Numbers:** authored as PROPOSED DEFAULT in `data/balance.json`, table in `numbers.md`. Jeff owns the final values.

### D-45. pause-cap-and-probe
**Q:** What is `pause_cap_per_advance` (most stops in one Advance)?
**A:** 2 (Jeff, 2026-10-12, the recommended option). Evidence: the pause probe ran on 3 seeds, realm.01 and realm.02, all shipped stages, both Directives, authored baselines only (605 / 907 / 513 Scout Advances and 466 / 638 / 405 Seek Advances). Pauses per Advance: Scout mean 0.12 to 0.19, max 2; Seek mean 0.04 to 0.06, max 2 once, else 1. Advances with 3 or more pauses: 0%. A cap of 2 never binds on shipped boards today. It is a safety cap for the party bends the backend adds. Why would show on 14% to 22% (Scout) and 14% to 20% (Seek) of Advances (a lower bound: Echo-named and Directive-cause whys are not measurable yet). Probe limits: no party bends, every situation ignored, prologue realm not covered. Re-measure after the backend lands.

### D-46. pause-ends-advance-and-first-plan-naming
**Q1 (J2):** When the party pauses for a find, does the Advance end there?
**A1:** Yes (Jeff, 2026-10-12, the recommended option). A stop returns control and unspent steps are lost (movement model 11.7, 11.9). There is at most one pause per Advance. `pause_cap_per_advance` (D-45, value 2) therefore has no job today. It stays as an unused safety key, or the backend drops it: `mechanics-developer` reports which in the plan. The probe's 'steps cut by pause' column shows the cost (Scout about 0.17 steps per Advance).
**Q2 (J1):** How does the game name the deciding Echo?
**A2:** First-plan-only (Jeff, the recommended option). Compare only the first plan, with the reachable region shared through one optional argument. An Echo is named only when removing them changes that first plan. A full re-walk costs about 3.8 s per Advance on large maps (V2-INFRA-010 evidence).

### D-47. backend-plan-answers-j3-to-j6
**Q:** The four open items of `backend-plan.md` section 5.
**A:** (J3) Ship the lowest-id pick for a tied naming (Jeff, recommended). (J4) The stage snapshot carries a copy of `stages.presentation`; the UI reads the snapshot only (recommended). (J5) Move the three 'voices per contact turn' literals (3) to a new key `data.contact.max_voices_per_turn` = 3, and read the existing `party_max_size` for the snapshot check of 5; same values (recommended). (J6) Move the two NPC turn-score numbers (0.2 and 0.1) and the morale limit 20 in `ConversationService` to config; same values (recommended). (J7) Follows D-46: the reachable region is shared through one minimal optional argument in `find_explore_target`. All moves keep today's behaviour (ANSWERS #83).

### D-48. detour-limit-rule-and-terrain-cause
**Q1:** The stage re-plans every step and the detour limit (slack envelope) shrinks with the distance left, so a Scout detour can fail late and the party walks into a hostile. Which rule?
**A1:** Keep the per-step rule (option B) as committed in S1b, and build C1 later (Jeff, 2026-10-12, the recommended option). C1 fixes the limit per leg from the plain length when the destination was chosen. It needs one saved number, so it joins the journey-entry save change (S5, one `opus` save-schema pass). Option A (per Advance) is not built: it does not fix a flip that falls between Advances. Evidence: `slack-gate-options.md`; on a real map with a placed hostile, 2 true flips in 395 Scout journeys; most bad journeys (38 of 40) never fitted a detour at all (a cliff that neither A nor C1 changes). The designer's Python copy of the route search is not the engine: re-check with the engine before authoring any value.
**Q2:** Record a terrain cause when a detour is refused?
**A2:** Yes (Jeff, the recommended option). The journey entry records that the terrain forced the route, so the why never gives a false Directive reason. Wording is Jeff's. Work lands in S3 (cause value) and S5 (saved field).

### D-49. pool-rule-accepted-with-watch-note
**Q:** After S1c, a revealed hostile that is the nearest candidate can pull a cautious Scout away from a far objective (the objective lies outside the slack envelope, so the weights never decide). Accept the pool rule (D-28) as built, or guard it?
**A:** Accept as is (Jeff, 2026-10-12), and leave a note in V2-STAGE-010 and in other stories that add content which could make it appear. Evidence: the pool probe on 3 seeds, realm.01 and realm.02, both Directives (720 to 880 Advances per Directive per seed). Eligible Advances (objective revealed and reachable at the start): 9 to 15 per Directive per seed. Diverted to a hostile: 0 in all runs. Diverted to a non-objective at all: 2 (both Scout, one reward and one intel, lost by weight). Limits: the walk follows the S1c rule; counts are made at Advance start only. The attribution in the code: the envelope filter runs before the weight rank (`StagePartyMovementAdapter.select_objective_target`, pass 2). Watch note: any story that adds hostile content or hazards near routes (V2-STAGE-010, V2-STAGE-101, V2-STAGE-102) must re-run the pool probe (`docs/stories/v2-directive-002/probes/pool_probe.gd.txt`; copy it out and rename to .gd to run) and re-judge.

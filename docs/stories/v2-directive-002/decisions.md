# V2-DIRECTIVE-002 — Decision Log

Source: planning interview with Jeff, 2026-10-10. Plan file: `~/.claude/plans/jolly-cooking-crescent.md`.
Background: the session first planned V2-COMBAT-004. Its dependencies V2-DIRECTIVE-002 and V2-INFRA-004 are not built. INFRA-004 also needs V2-ITEM-002 and V2-ITEM-003. Jeff switched to V2-DIRECTIVE-002 first (D-00).

Files named in this log that are not in this folder were removed on the cleanup (D-92). They stay in git history.

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
- **Amended by D-69 Q2:** `exposure_tolerance` drives movement; `intent_weights.exposure_acceptance` stays for action choice, so two exposure inputs remain.

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

### D-50. commitment-numbers-and-fog-meaning
**Q1:** Which commitment numbers and rounding does the stage Advance use? S2b attribution (opus) proved commitment depth alone moved five traversal tests: Scout 3 x 0.5 rounds to 2 steps, Seek 6 x 0.85 rounds to 5. Scout 0.5 sits exactly on the 1-step and 2-step boundary: any net negative lean gives 1 step.
**A1:** Option A' (Jeff, 2026-10-12, the recommended option): keep `roundi` and Seek 0.85; raise the Scout base `commitment_fraction` to 0.6 (range 0.5 to 0.7), so Scout is 2 steps under every lean. Smoke on 8 real stage walks (seed 101): Scout steps per Advance 2.78 to 1.88, cells revealed per Advance 11.28 to 7.73, Advances to the objective 11.5 to 16.8; Seek 4.61 to 4.20 steps, 11.39 to 10.07 cells, 12.2 to 17.8 Advances. The numbers stay PROPOSED DEFAULT; the in-game test decides.
**Q2:** Does 'Scout reveals wider' mean per step or per Advance?
**A2:** Per step (Jeff, the recommended option). The fog test compares cells revealed per step (Scout about 4.1 against Seek about 2.4 on real stages). Scout is careful: fewer steps, each one reveals more.
**Effect on tests:** the five traversal tests are re-recorded after the attribution (cause: commitment depth, proved by running with fraction 1.0 and by byte-compare with the pre-S2b commit). `fog_scout_wider_than_seek` changes meaning to per step.
**Findings kept open:** a Scout reveal radius change altered a Seek walk in one smoke variant (mechanism not traced); the stale '(radius 3 vs 1)' fog-test comment.

### D-51. frontier-route-character-deferred
**Q:** Slice S2c listed a frontier `route_character` rank key in `select_frontier` (Scout prefers cells that keep the road home explored; Seek prefers continuing the heading) with no weights and no config keys. Build it in this phase?
**A:** Defer (Jeff, 2026-10-12, the recommended option). Evidence in `route-character-options.md` (sr-game-designer): the design goals are met by commitment depth, fog per step (D-50), exposure, the category bend and stops (D-45); the frontier rank would only choose between two fog-edge cells; Seek's heading preference already exists as shared code; a live-stage re-record would be large. Revisit with V2-STAGE-010 (hazards): there definition C (low added exposure) matches the one-exposure-input rule (D-05). Consequence: `travel_why.route_character` has no frontier source and stays empty on frontier walks. The worked-example counts came from a Python copy of the search, not the engine: re-check before any value is authored.

### D-52. s3-findings-answers
**Q:** The opus review of S3 left findings F1 to F7 (follow-ups.md). Jeff decided on 2026-10-13 (all the recommended options):
**A:**
- **F1:** exempt the whole route when the target is the exposure source. If the party walks to the hostile on purpose, there is no exposure pause on the way. A pause happens only for exposure the party did not choose. The first-step exemption stays (design 9: an Advance always makes progress).
- **F2:** `reveal_stop_kinds` is the switch, also for `spotted_ahead`. The code reads the list, so a data-only Directive can turn the stop off (ANSWERS #81). Both shipped Directives keep it on.
- **F4:** the party width for the noise filter is the mean `interpretation_width`.
- **F5:** the terrain cause overrides only when the FIRST leg refused a detour, to match first-plan-only naming (D-46).
- **F3 (doc fix):** D-36 defines `arrived_at` as 'walked into a situation'; design 3a defines it as 'target reached' and the code follows 3a. The D-36 wording is superseded here: `arrived_at` = target reached; `met something` (reason `interrupted`) = entered a non-target unresolved situation.
- **F6 (defect):** strip `_comment*` keys from the `presentation` snapshot key. The stage fingerprint moves once more.
- **F7:** accepted as is. The player kind tells the two meanings of the shared reason `interrupted` apart.
**Work:** slice S3b (opus): F1, F2, F5, F6 in code with one named cause per moved value.

### D-53. journey-entry-lifetime-approved
**Q:** Lifetime and reset rules for the saved journey entry (`last_stop`, `travel_why`, `last_effective_steps`), proposed in the S5 report?
**A:** Approved (Jeff, 2026-10-13). First entry of a stage: empty. Return from combat or a contact, or a reload: kept. After a successful return home (`party_state` escaped), then a later entry: cleared. Final objective won, then re-entry: kept. The next Advance, including a retarget: replaced. Return home failed: kept. Stage switch: each stage keeps its own entry. The plan rule 'carry only when `locked`' is replaced by the `party_state` rule (the lock always runs before the reset). Open follow-ups: an encounter retreat does not set `escaped`; a carried `last_effective_steps` can exceed a new `step_budget` after a Directive change; the stale comment at `FlowStageExploreState.gd:91-94`.

### D-54. qa-backend-findings-answers
**Q:** The opus QA pass over the combined backend (no blockers, 7 should-fix, 9 notes) left decisions. Jeff answered on 2026-10-13:
**A:**
- **S1 (false Echo name):** depth counts only when it cuts the path. A different commitment depth is material only when the depth is less than the steps to the stop. Design 4 rule 8 is amended accordingly.
- **S2 (named Echo without a reason class):** add a fifth reason class for the 'steadied the party' case (the Echo is named only because they lift the party mean). Token: `steadied` (internal; the wording is Jeff's). The class list stays in config.
- **N2 (readiness):** readiness applies to every Directive, also one with no `directive_profile` entry (D-13, D-27). A profile-less Directive stays neutral for the dials, not for readiness. A5 is amended.
- **Fix list:** S3 (add the four missing guard tests), S6 (move the escape base threshold 40 to config, same value), S4 (drop the unused `replan_cap_per_effective_step` key and the design 4 rule 3 promise; the loop is already bounded), S7 and the stale comments and doc rows (commit `StageStopPolicy.gd.uid`; fix the READER PENDING markers, the DORMANT header, plan and numbers.md rows). Comments follow the AGENTS.md rule: fewer comments; delete noise comments while fixing stale ones.
- **Not selected:** S5 (shard map entry for `contact_cfg` and the `AGENTS.md` suite count 129 to 130). It waits for the docs pass; `AGENTS.md` needs Jeff's yes. N1, N3 to N6 and N8 are noted and not fixed now.
**Order:** package A (opus: S1, S2, N2), package B (S3 tests, S6, S4), package C (S7 and comments and docs). One commit each.

### D-55. naming-check-and-advance-speed
**Q1:** The naming test runs use a small model of the walk. The model base plan can differ from the real walk (QA note N1). What do we do?
**A1:** Option 2 (Jeff, 2026-10-13). Before naming an Echo, compare the model base plan with the real walk. If they differ, name nobody; the cause shows without a name. The model is not extended (option 3 not chosen). Package D builds it.
**Q2:** Speed. The measurement (M2 Mac, headless, 1152 Advances, 576 on/off pairs; walk identical in all pairs): whole dispatch mean 321 to 346 ms (Scout) and 463 to 562 ms (Seek); worst 5% about 600 ms (Scout) and about 1 s (Seek); max 1276 ms. Naming alone 71 to 104 ms mean (grows with party size); share of the dispatch 15% to 30%. The step loop is the main cost (Seek without naming 341 to 364 ms; one path search about 58 to 70 ms; 5 to 6 searches per Advance). A phone or tablet is slower.
**A2:** Trim now and schedule V2-INFRA-010 (Jeff, the recommended option). A short package E trims the naming cost. Target: naming under 50 ms mean and mean Advance under 500 ms with 5 Echoes (desktop, headless). Threads are not used (Jeff: only if it helps; the main chain is sequential). V2-INFRA-010 (a cheaper path search) is scheduled after this story; the Notion edit needs Jeff's yes and a preview first.

### D-56. dropped-names-accepted
**Q:** The naming check drops 13% of proposed names on test boards with a hostile near the start (6.5% of Advances), all from equal-cost route ties under per-step replanning. Accept, or match the live tie rule in the model?
**A:** Accept the drop rate (Jeff, 2026-10-13, the recommended option). A wrong name never appears. The cause shows without a name. The model is not changed. Package E (speed) starts next.

### D-57. frontend-timings-approved
**Q:** The game-feel timing proposal (`timings-proposal.md`): approve as starting values? Overlay wait? Reduced motion?
**A:** (Jeff, 2026-10-13, all recommended options)
- **Timings:** approved as starting values. They go into `stages.presentation` as PROPOSED DEFAULT. Jeff tunes them in the game after the build. First tests: the shake size, the glyph overshoot, the pulse peak, the 0.85 s input-ready point.
- **O1:** the contact, situation and choice overlays wait 0.35 s (`overlay_hold_seconds`) so the glyph lands first.
- **O2:** a reduced-motion setting is NOT in this story. The code reads one flag that defaults to off, and each effect has its reduced form ready. A later settings story adds the switch.
- **O3 (open):** is a still pressed button enough when the Advance tail is about 1 s or more on a phone? Decide after a phone measurement.
- Reserved keys `shaken_shake_delay_seconds` and `shaken_shake_oscillations` are replaced by `stop_rest_seconds` and `shaken_shake_offsets_px` (nothing read the old names).

### D-58. directive-badge-one-neutral-colour
**Q:** The Directive badge has no colour data (the per-Directive colour code was removed from the UI). One neutral colour, or a colour per Directive in config?
**A:** One neutral colour (Jeff, 2026-10-14, the recommended option). The badge keeps its dark pill and the label from the snapshot. The optional `directive.tint` read stays in the UI and stays unused. A new Directive needs no colour work.
**Open backend items from the UI build (F1):** add an Echo `id` to each `party_preview` row of the stage snapshot (the UI matches the named Echo by display name today); add the `presentation` key to the preview snapshot (`flow.stage`, built in FlowStageState). Both are small core changes; they may move snapshot fingerprints.

### D-59. frontend-qa-answers
**Q:** The frontend QA pass (no blockers; 5 should-fix, 13 notes) left decisions. Jeff answered on 2026-10-14:
**A:**
- **Chip place (S1, S2):** no new decision. D-42 and design 8.1 item 3 already settle it: the chip sits beside the Echo cards, inside the safe area, never covers a card, never shrinks a card below its minimum width. The build broke this with 4 or 5 Echoes (the chip was off screen) and shifted the cards by 36 px. The fix follows D-42: reserve a fixed slot beside the cards, always inside the safe area, so the cards never shift. The cards scroll in the remaining width. `ui-ux-designer` places it.
- **Overlay hold (S3):** wait for the mark. The contact, situation and choice overlays open after the stop beat ends (the beat plan `ready_at`), so the mark always lands first. This replaces the fixed 0.35 s hold of D-57 O1.
- **Token tap (N3):** a second tap on the party token closes the why card; a tap outside the card closes it too (design 8.1).
- **Small fixes:** fix the single-quote gap of the Directive-literal test (also scan `.tscn`), the two stale comments, the doubled focus colour (one shared source) and the same-holder fade.
- **Not now:** S4 (walk reduced-motion form; D-57 O2 stands: no switch in this story), N2 (the double-press guard has no headless test; the windowed probe shows it works), S5 (docs: part of the docs pass), the close button (kept: the design 'no button' means no opener button).

### D-60. play-test-findings-answers
**Context:** Jeff played the build on 2026-10-14 (his terminal log shows about one Advance per second). The measurement is in `play-findings-report.md`. Findings: the Advance button is off about 975 ms after a press (calm) and about 1200 ms (shaken), against about 240 ms before the motion step; at a 0.5 s click rhythm 22 of 49 clicks are ignored; the chip sits far from the cards; the why card opens at the top left; the step row cannot show commitment (the snapshot carries no commitment depth); 0 of 606 real Advances named an Echo.
**Process note:** the builders stated their assumptions (they followed their role rule). The orchestrator did not turn the UX-changing `ASSUMED` lines into questions for Jeff, summarised the click lock as a gain, left the old Advance button and the old Echo band out of the F1 brief (D-41), and did not compare the build with the approved mockup. From now on: every `ASSUMED` line that changes what Jeff sees or feels is asked before the next step; UI briefs carry a mockup checklist; every UI step ends with a build-next-to-mockup screenshot that Jeff approves before the commit; a timing that blocks input is stated as 'blocks clicks for X seconds' and compared with today.
**A:**
- **Click lock:** Advance is ready again when the walk ends. It is off only during the compute and the walk (about 0.75 s). The stop beats after the walk (glyph settle, pulse, shake, cross-outs, snippet) never block a click; a press cuts them. This replaces the 0.85 s input-ready point of D-57 and `timings-proposal.md`.
- **Step row:** keep the baseline diamonds. Cross out every step the Advance cannot use: lost to readiness or cut by commitment. Seek with capacity 6 and commitment 5 shows 6 diamonds with the 6th crossed out. This amends D-40 item 8 and D-43. It needs the commitment depth in the stage snapshot (additive; carried and repaired like `last_effective_steps`).
- **Look:** keep the live look. The old mockup's narrow Advance button and dark Echo band (D-41) are NOT built. D-41 is amended: only the step icons of the old mockup are used. The blank Advance label stays its own task.
- **Why card place:** it opens right above the tapped glyph, card or chip, inside the safe area, and it does not cover the Advance button. This replaces design 8.1 item 4 ('inside the board area').
- **Chip and glyph place (follows the approved mockup, D-42):** the chip sits directly left of the cards (about 58 px gap), in the same centred group, with a slot that is always reserved so the cards never shift; with a long party the chip stays pinned at the left of the scroll area. The glyph sits on the portrait corner of the named card.
**Open:** the Echo naming rarely fires (0 of 606 Advances). Jeff decides next (stronger party bends, or accept).

### D-61. glyph-always-on-a-card
**Q:** The stop glyph sat on the named Echo's card when an Echo was named, and in a chip beside the cards when none was named. Jeff found this inconsistent (2026-10-15). Where should it sit?
**A:** Option B: always on a card (Jeff). The chip becomes a first 'party card' in the Echo bar with the card look. The stop glyph sits on the named Echo's card, or on the party card when no Echo is named. This amends D-41 and D-42 (the chip is a card now) and D-59 (chip place). The party card exists on the stage screen at all times (the glyph shows only after a stop). Open details Jeff approves on a mockup before any code: the party card width (same as an Echo card or compact), what its portrait shows (the blue party token 'P' is a candidate), its label (player text: Jeff's wording), what a tap does when no mark exists, and how it behaves with 5 Echoes (6 cards, scroll, pinned first).

### D-62. party-card-details
**Q:** Details of the party card (D-61), shown on the sheets in `mockups/v4/` (Jeff, 2026-10-15):
**A:**
- **Width:** V3, compact with a short label (about 168 wide, 58 high). The label is one short word of 13 characters or fewer, at about 14 px. The word is Jeff's wording (placeholder in the text bank until he writes it).
- **Portrait:** the blue party token 'P' from the board (no party icon art exists).
- **Tap with no stop mark:** open the last journey entry if one exists. If no entry exists, nothing happens.
- **Gap:** about 32 px between the party card and the first Echo card (a visible separation; other cards stay 16 px apart).
- **Glyph corner:** top-left of the portrait, on every card (a named Echo's card and the party card). This moves the glyph from the top-right corner used in the first build.
- **Echo bar with many Echoes:** the party card is pinned first at the left and does not scroll. Only the Echo cards scroll.
- Kept from earlier answers (D-60): the live look for the Advance bar and the cards; the lost-step cross style is still open (red X today; the mockup used a small slash).

### D-63. party-card-approved
**Q:** Does the party card build match what Jeff approved? What does a tap on the party token do when no stop mark exists?
**A:** Approved (Jeff, 2026-10-15). A tap on the party token with no stop mark opens the last journey entry, like the party card (when no entry exists, nothing happens). The why card opens centred above the whole tapped card, also for Echo cards. The party card label stays the placeholder until Jeff writes the word. The lost-step cross style is still open (red X today; the mockup used a small slash).

### D-64. cross-style-config-key-party-word
**Q:** Which cross style marks a lost step? Is the config key `chip_settle_seconds` renamed? What is the party card word?
**A:** (Jeff, 2026-10-15)
- **Lost-step cross:** red X. It stays as built. The mockup's small slash is dropped.
- **Config key `chip_settle_seconds`:** keep the name. No rename.
- **Party card word:** "The party" (9 characters, inside the 13-character limit). It replaces the placeholder in `data/ui/stage_why_text.json` (`party_card_label`).

### D-65. bend-strength-keep-v0
**Q:** The bend matrix (4 variants, 40 slices) showed no difference in who is named. Which variant does Jeff choose?
**A:** Option 1: keep V0 (Jeff, 2026-10-15). No number changes. `data/balance.json` stays as it is.
- **Evidence:** named share is identical in V0, V3, V1 and V2. The category bend changed no pool pick (`bend_changed` = 0). Naming follows party state: stressed mixed parties 26 to 55%, all other sets 0%.
- **Open finding (not in this decision):** 137 of 266 proposed names (52%) are dropped by `confirm_walk`. The target was 15% or less. Naming for calm parties and your own party is also open. Both stay as follow-ups for Jeff to scope.
- **Speed:** worst mean Advance 222 ms, worst 95th percentile 417 ms. Both are under 500 ms. No multithreading work.

### D-66. wording-questions-answered
**Q:** Three questions from the proposed-wording report.
**A:** (Jeff, 2026-10-15)
1. **`cause.directive`:** the word "Directive" is NOT allowed in player text. The voice rule stands. The design text for the Cause row (section 8) and rule 7 (section 4) must change to match. The line names the order in plain words, with no code word.
2. **`purpose.hold`:** an agent checks whether `hold` can reach the player. The result decides if the line is needed.
3. **New route keys ("cautious", "only way"):** not added. The data keeps `direct` and `skirted`. No schema change.

### D-67. purpose-hold-removed
**Q:** Can `hold` reach the player as a stop purpose?
**A:** Option 2 (Jeff, 2026-10-15): `hold` is removed from the allowed stop purposes (`StageStopPolicy.PURPOSES`) and `purpose.hold` is removed from `data/ui/stage_why_text.json`. `hold` is reachable only in a broken stage state. Movement code is unchanged.

### D-68. why-card-wording-final
**Q:** Which wording goes into `data/ui/stage_why_text.json`?
**A:** Jeff's column D lines, with these fixes (Jeff, 2026-10-15): "lies" for "lays"; "This problem is known"; two short sentences for the two route lines; present tense for `cause.directive`, `ui.echo_named`, `stop.paused_to_read` and `stop.capacity_spent`.
- **Spelling:** UK ("honoured").
- **"Keeper":** the word Echoes use for the player. It is allowed in player text.
- **"Purpose" in `cause.objective`:** allowed. It means the Echoes' purpose.
- **`steadied` line:** has no `{name}:` prefix, on purpose.
- **`purpose.hold`:** no line (D-67).

## Phase D (combat expression and stop-short Directive cause)

### D-69. phase-d-design-answers
**Q:** Five design questions from the phase D recon (read-only report, 2026-10-16).
**A:** (Jeff, 2026-10-16)
1. **Exposure map (Q1):** option A. Combat acceptance = `exposure_tolerance` minus 0.5 (Scout -0.2, Seek +0.3). The offset is a config key (ANSWERS #83). Scout moves the recorded hashes, so an `opus` agent attributes each move.
2. **Old number (Q2):** option A. `intent_weights.exposure_acceptance` stays for action choice (melee, guard, idle rows). Tolerance drives movement only. Two exposure inputs remain, and the docs say so (D-05 is amended).
3. **Stop favour (Q3):** option A. The Directive stop cause is `(1 - exposure_tolerance) x affinity[benefit]`. Guard and hold get a larger affinity. Observe gets a small affinity. No new Directive key (ANSWERS #81). The numbers are PROPOSED DEFAULT in config.
4. **Standing (Q4):** option B (Jeff chose against the advice). Judgment scales the Directive stop cause down: higher Standing obeys less. The scaling must sit inside `interpretation_swing_max`. A new config-integrity test proves it. The design must show no double count with `_directive_bonus` and the identity cause (design.md:320).
5. **Route scores (Q5):** option A. The route scoring formula stays. The Directive cause adds the normal stop bias (`stop_short_weight x strength`), like fear and identity.
- **Open:** Q6, the player-facing text lines for the Directive cause. They are Jeff's wording. They are proposed after the code exists.
- **Rules kept:** the stage bound (`interpretation_width`, `party_stance`) never enters combat (D-09). `StageStopPolicy.CAUSES` and `StopShortService` stay separate.

### D-70. phase-d-design-answers-j1-to-j5
**Q:** Five questions from `phase-d-design.md` section 7.
**A:** (Jeff, 2026-10-16)
- **J1:** option B. Raise the acceptance weight to a probe-measured value (range 8 to 14, below the attractor limit at 20). A probe sweep sets it.
- **J2:** both B and C, inside phase D. Jeff: "I don't want to follow up, I want it added here. It should be both." Pillar reason: Echo growth must show in movement exposure as well as in stops. So:
  - **Fear lean (B):** fear lowers combat exposure acceptance. A frightened Echo shies from exposure. This matches the stage rule (design.md:31).
  - **Judgment scale (C):** Judgment scales the Directive part of acceptance. A seasoned Echo uses its own exposure habit. This needs a Judgment argument in `_spatial_utility` and its own row in the swing budget.
  - **Attribution:** the orchestrator keeps one named cause per recorded-value move by landing the causes in separate slices, with a re-record between them: (1) base acceptance map, (2) fear lean, (3) Judgment scale on acceptance, (4) Directive stop cause with its Judgment scale.
- **J3:** option A. Accept. Fear lowers Judgment, so a shaken veteran leans back on orders.
- **J4:** option A. Floor 0.55 to 0.6 (start 0.6). `interpretation_swing_max` stays 2.0. The probe checks if edge growth is visible. The budget changes only with Jeff's approval.
- **J5:** option A. Accept. Seek rarely has a Directive stop.
- **Open:** Q6, the player text for the Directive stop cause (after the code exists). The design note must be extended for J2 B and C before any code.

### D-71. phase-d-open-questions-o1-o2
**Q:** The two open questions of `phase-d-design.md` (section 7, after the J2 extension).
**A:** (Jeff, 2026-10-16)
- **O1:** fear lean bound 0.12, the same as the stage. Exposure stays a cost for a very afraid Echo. The value is PROPOSED DEFAULT in config and the probe may change it.
- **O2:** option A. A seasoned Echo shows its own exposure habit through the existing movement style (style alignment). No new Calling habit term in phase D.
- **Next:** `mid-game-designer` proposes the config numbers in `docs/stories/v2-directive-002/phase-d-numbers.md`. Jeff approves the design note and the numbers before any code starts.

### D-72. phase-d-numbers-approved
**Q:** Three number choices from `phase-d-numbers.md`, and approval of the phase D design note and numbers.
**A:** (Jeff, 2026-10-16)
- **Hold affinity:** 0.8 (guard 1.0, observe 0.3). PROPOSED DEFAULT. The probe may change it.
- **Exposure weight:** start at 11. The probe sweep (2, 8, 11, 14) shows the real effect. Jeff decides after the probe if the weight goes up. No guess now.
- **Row order:** the Directive row goes after fear and identity in `CAUSE_ROWS`. The Echo's own cause wins a tie.
- **Approval:** `phase-d-design.md` and `phase-d-numbers.md` are approved as the build basis. Slice 1 starts (base exposure rule and weight). Slices 2, 3 and 4 follow, one at a time, with a re-record and an `opus` attribution after each.
- **Still open:** Q6 (player text for the Directive stop cause), after the code exists. Final values of the weight, the fear bound, the floors and the affinities come from the probe runs.

### D-73. exposure-weight-17
**Q:** Which exposure weight ships in slice 1? The probe sweep (14 runs of 7 fixed combat fixtures, 2026-10-16) showed the term is silent below weight 14.
**A:** 17 (Jeff, 2026-10-16, the recommended option). PROPOSED DEFAULT. It is inside the legal limit (weight x acceptance < 6: Seek 17 x 0.3 = 5.1, Scout 17 x 0.2 = 3.4).
- **Evidence (differing moves vs weight 0, the term off):** Scout 0 of 384 at weights 2, 8 and 11; 2 at 14, 17 and 19 (`purify_shrine`). Seek 0 of 355 at 2 to 14; 16 at 17 and 19 (14 in `endure`, 2 in `purify_shrine`). Weight 19 adds nothing over 17.
- **Limits:** the probe plays 7 fixed fights. The effect is still small at 17 because the base exposure cost (`exposure_weight` -6.0) is large. A stronger felt difference may need a change to that base cost. That is a larger design change and is not in phase D.
- D-73 replaces the D-70 J1 probe range (8 to 14) and the D-72 start value 11.
- Limit: at weight 17 the exposure term becomes an attractor for any Directive with exposure_tolerance of 0.853 or more (0.5 + 6/17). The config-integrity test (`directive_cfg/exposure_acceptance_never_attractor`) catches a new Directive that breaks this.

### D-74. seek-fingerprint-suite-and-qa-fixes
**Q:** (Q-A) Should a Seek combat fingerprint suite come before slices 2 to 4? And what happens to the QA findings after slice 1?
**A:** (Jeff, 2026-10-16)
- **Q-A:** yes. Add a Seek combat fingerprint suite BEFORE slices 2 to 4, so each slice shows its effect on Seek in a saved value. The probe showed Seek moving in two fixed fights: `endure` and `purify_shrine`. The suite is built next, as a new suite.
- **QA fixes:** QA findings 4, 5, 6 and 8 are fixed together with slice 1.

### D-75. fear-lean-scope
**Q:** When does fear lower combat exposure acceptance? (Slice 2 builder assumption 1 against design 2a and test J6.)
**A:** Option B (Jeff, 2026-10-16, the recommended option). Fear lowers acceptance for any actor whose Directive is non-empty. A Directive without `exposure_tolerance` gets D = 0 and still takes the fear lean: `acceptance = clamp(0 - F, -1, 1)`. An empty Directive (`{}`: enemies, the keeper trial) gets acceptance 0 and no fear lean. This matches design 2a and test J6 for a data-only Directive and keeps enemies and the trial unchanged.

### D-76. weak-fear-lean-study-base-cost
**Q:** The slice 2 fear lean changes no move in the 7 probe fights. What now?
**CORRECTION (QA check, 2026-10-16):** only the two fear-45 pairs are valid (Scout 0 of 369, Seek 0 of 362 differ). In the two fear-70 pairs every Echo turn was `actor.refuse` (nascent refusal threshold 65, `data.actor` refusal bands), so no Echo movement was scored and those pairs cannot show the lean. The probe also set `fear_base` 70, outside the legal range 0 to 40. At fear 45 the ramp is 0.5, so the lean is 0.06 (about 1.0 score points). No pair tested the lean near the top of the ramp. A new probe arm at fear about 60 with `fear_base` at most 40 is needed. The orchestrator reported the fear-70 pairs as valid before the QA check; that was wrong.
**A:** Option A (Jeff, 2026-10-16, the recommended option). Commit slice 2 as built (no recorded value moved: 43 of 43 suites incl. `fingerprint_seek`). Slices 3 and 4 go on. Before the final combined check, a designer studies the base exposure cost (`exposure_weight` -6.0 in `spatial_utility`), the lever that makes exposure matter. The study is `docs/stories/v2-directive-002/exposure-lever-study.md`. Any change to that cost is Jeff's decision and moves many recorded values.
- **Limits that apply:** fear bound at most about 0.165 (a larger bound lets a frightened Seek Echo go below 0, rejected in D-71); weight at most 19 (slice 1 uses 17).

### D-77. slice-2-qa-fixes
**Q:** Fix the slice 2 QA findings before the commit? (QA check, 2026-10-16.)
**A:** Yes, fix all (Jeff, 2026-10-16, the recommended option): (1) a probe at fear 60 with `fear_base` at most 40, lean on against lean off, because fear-70 Echoes refuse every turn; (2) a wiring test from the combat turn context to the arbiter; (3) design tests F3 (`fear_lean_not_scaled_by_judgment`), F6 (`directive_cfg/fear_lean_bound_exceeds_fear_judgment_path`) and the Judgment dimension of F5 move to slice 3, because they need the Judgment floor (`floor_a`); (5) the config comment for `fear_lean_bound` gives the upper limit; (6) the `_fear_lean` doc comment is reworded. Finding 4 (the C14 scan is narrower than the design row) is accepted as a note.
- **Result of the fear 50 and 60 probe (2026-10-17, valid arms):** Echoes still move (fear 50: 61 Scout and 100 Seek Echo moves, no refusals; fear 60: 52 and 76 moves, 32 and 36 refusals). Lean on against lean off: Scout fear 50 differs in 0 of 374 moves, Scout fear 60 in 0 of 410, Seek fear 50 in 0 of 355, Seek fear 60 in 0 of 410. The lean (up to 0.12 x ramp x 17 = 1.2 to 1.6 score points) changes no move in the 7 fixed fights. `data/balance.json` unchanged by the runs.

### D-78. measure-exposure-choices-before-slice-3
**Q:** Before slice 3, measure first whether real exposure choices exist, or build slice 3 now? (Study `exposure-lever-study.md`: only 4.8 to 7.3 percent of Echo decisions in the probe fights offer an exposed and an unexposed route; the probe logs no score parts.)
**A:** Measure first, then slice 3 (Jeff, 2026-10-17, the recommended option). Step 1: a print-only change to `tools/SpatialTermProbe.gd` logs the spatial parts, total score, chosen flag and margin for every route option, for the 7 fights, Scout and Seek, calm and fear 50 (study section 2.3). Step 2: 3 to 5 production-path fixture boards with real route choices (an exposed and an unexposed route of similar progress), to learn whether the effects of slices 1 to 3 can be seen at all. No recorded value moves. Slice 3 starts after the result, with Jeff's decision on what the result means.

### D-79. pace-no-more-probes
**Q:** The measuring takes too long. How do we finish phase D faster? (Jeff, 2026-10-17: "I feel like we are in a measuring loop that is taking a lot of time.")
**A:** Run the D-78 measurement ONCE, then build slices 3 and 4 with no more probes (Jeff, 2026-10-17, the recommended option). Slices 3 and 4 are built one after the other. Each gets unit tests and one recorded-value run, with one named cause per slice. No weight sweeps and no fear probes. The final combined QA check and one full serial suite run once at the end. The measurement result informs Jeff's view of the exposure channel; it does not block slices 3 and 4.

### D-80. measurement-hook-yes
**Q:** The `parts` log of the D-78 measurement needs a 4-line hook in `core/runtime/FlowRuntime.gd` (`behavior_module_factory`, unset by default, so behaviour is identical). Add it?
**A:** Yes (Jeff, 2026-10-17). The boards probe (D-78 step 2, commit `888f6e5`) showed the Directive exposure effect is visible when a choice exists: on the 5 boards Seek takes the exposed route at 0.4 to 1.6 cells of extra progress, Scout at 2.8 to over 6 cells or never, the cost alone at 1.8 to 4.4; the fear lean moves the Seek threshold by 0.3 to 0.8 cells. The count of real mixed decisions in the 7 fights is measured once, with 4 arms run in parallel (each with its own `ECHOES_TEST_SAVE_DIR`). Per D-79 this is the last probe of phase D.
- **Result of the D-80 count (2026-10-17; 4 arms in parallel, 7 minutes; Echo route decisions in the 7 fixed fights, purifier passes excluded: 5 per arm):**

| Arm | Echo passes | Passes with route options | Mixed (exposed and unexposed option) | Mixed with margin under 10 | Choice changes if exposure terms removed |
|---|---|---|---|---|---|
| Scout, calm | 276 | 243 | 3 | 0 | 0 |
| Seek, calm | 255 | 233 | 5 | 2 | 1 |
| Scout, fear 50 | 268 | 247 | 4 | 0 | 0 |
| Seek, fear 50 | 258 | 234 | 6 | 3 | 1 |

  Mixed decisions are 1 to 2 percent of Echo passes. The Directive exposure term and the fear lean decide 0 (Scout) or 1 (Seek) decision in about 260. The effect is real on the boards (D-80) and almost never asked for in these fights. The cause is the input (how often a fight offers an exposure choice), not the weights. Whether real stages offer more choices is not known. This is a follow-up question for Jeff, not a blocker for slices 3 and 4 (D-79).

### D-81. proceed-slice-3-and-make-state-systems-matter
**Q:** The count (D-80) shows exposure choices are 1 to 2 percent of Echo decisions in the 7 fixed fights. Proceed with slice 3? Should exposure matter more?
**A:** (Jeff, 2026-10-17) Proceed with slice 3 as designed (D-70). And yes, exposure should matter more: "we want fear, judgement, moral and other systems to actually have an effect." So:
- Slice 3 (Judgment scale on exposure acceptance) is built now, with unit tests and one recorded-value run. No more probes (D-79).
- A designer studies how the Echo state systems (fear, Judgment/Standing, morale, and the other state inputs the arbiter already reads) can have a felt effect on movement, beyond the exposure channel alone. The study starts from `exposure-lever-study.md` and the D-80 count. It proposes options for Jeff. It changes nothing. The result decides a new slice or story. It is in the scope of the pillar (Echoes show growth and emotion in how they move).

### D-82. state-systems-movement-answers
**Q:** Eight questions from `state-systems-movement-study.md` (section 5). Jeff answered on 2026-10-17.
**A:**
- **Q1 (what fear shows as):** stay near allies and push less (A1) plus shorter steps (B1). Fall back to the group (B3) goes to V2-COMBAT-004.
- **Q2 (morale):** fear and morale. A high-morale Echo advances more and drifts from the group, with bounds.
- **Q3 (composure):** yes, for all leans. A seasoned Echo shows less fear in its movement (composure softens the lean by up to 40 percent). This amends D-70 J3 for the new leans: they are scaled by composure.
- **Q4 (strength):** clear, about 6 to 10 percent of decisions change. `mid-game-designer` authors the bounds.
- **Q5 (budget):** YES, `interpretation_swing_max` may rise up to 2.5, with a new config-integrity test. Jeff chose this against the advice (keep 2.0). Standing may then scale the Echo's own movement style (study option B4). The raise loosens the guard of the action layer too (now at 1.80); the design must show all layers inside the new value.
- **Q6 (capacity):** yes, after a feasibility check by `mechanics-developer` (is capacity computed per activation and not saved or fixed by the COMBAT-002 contract). Standing 1 is already at the floor of 2, so only the bonus side acts there. If the check fails, stop and bring options.
- **Q7 (arenas):** yes, in parallel. Authored set-piece arenas with real route choices (study option C1). Content, not code. Jeff approves the arenas.
- **Q8 (fall-back goal):** goes to V2-COMBAT-004 as a requirement (D-07).
- **Slice plan:** slice 3 (Judgment scale on exposure) in verification; slice 4 (Directive stop cause); slice 5 (A1: state-scaled progress and cohesion weights, bounded, softened by composure); slice 6 (B1: capacity from fear and morale); slice 7 (B4: Standing-scaled style, with the raised budget); arenas (C1) in parallel. Per D-79: no fight probes; unit tests plus the 30-second boards probe, and one recorded-value run per slice.

### D-83. slice-3-qa-answers
**Q:** Slice 3 QA check (2026-10-17): three questions.
**A:** (Jeff, 2026-10-17)
- **A (fear rule, finding 3):** bounded rise, derive the window. Keep the rule 'more fear never makes exposure more acceptable, except a tiny rise just above `fear_start`' (real peak 0.006 for Seek; design F5 text is corrected to say this). The fixed window of 5 fear points in the F5 test is replaced by a window derived from the config (the fear point where the lean overtakes the Judgment path). Test F6 is replaced by a slope rule: `fear_lean_bound / (fear_full - fear_start) >= (1 - floor) x fear_pressure_weight x max abs(D) / 100`, plus a bound on the rise before `fear_start`.
- **B (floor 0.5, finding 5):** the lowest allowed `judgment_floor` is 0.55 (matches J4: 0.55 to 0.6). The validator rejects below 0.55. Test J9 and the config comment match. At 0.5 the swing would have no headroom.
- **C (Judgment default, finding 8):** make `judgment` REQUIRED on the movement path (Jeff chose this against the advice to defer). A missing `judgment` in the context of `select_movement_intent` fails validation (loud). Production always supplies it (`ActorStateMachine.gd:355`). Fixtures that call the arbiter without `judgment` get an explicit value. This is design J8, kept. The action layer (`_directive_bonus`) keeps its own default unless the same check is needed there; the builder reports.
- **Verified later (2026-10-17):** the rise above `fear_full` is also bounded by `judgment_slope` per point (0.0003, about 0.009 in total for Seek); the F5 test derives its window from config. F6 is the slope rule, plus the pre-start bound (0.01), plus the old total bound `fear_lean_bound >= (1 - floor) x fear_pressure_weight x max abs(D)` (0.03 at shipped values). The slope rule alone fails only below a bound of 0.015.
- **QA fixes:** findings 1, 2, 4, 5, 6, 7, 9, 13 are fixed with slice 3. Finding 12 (bonds in `_production_judgment`) is optional.

### D-84. no-authored-arenas-procedural-only
**Q:** Build authored (hand-made) set-piece arenas with route choices (study option C1, Q7 of D-82)?
**A:** No (Jeff, 2026-10-17). D-82 Q7 is WITHDRAWN. Authored arenas go against the game: stages and combat boards are procedural and deterministic by seed (GDD, 'Current generation model', "stages should be procedurally generated before first entry", "deterministic generation using the Realm/stage seed"). The GDD also states the goal in the right place: "the Foundation tactical field uses readable irregular terrain, obstacles, hazards, and meaningful route tradeoffs" (GDD line ~4302). So the exposure systems must show up through the procedural generator, not through authored maps. The draft `arenas-draft.md` stays only as history of the withdrawn idea; its test boards (the `boards` probe) stay as TEST FIXTURES only, which they always were. Next: a designer studies how the procedural terrain generation (`StageTerrain.generate`, placement rules) can produce meaningful route tradeoffs (an exposed and an unexposed route of similar progress) often enough, with fixed seeds, inside the GDD. V2-STAGE-010 (hazards) may be the owner story. The study proposes; Jeff decides.

### D-85. scope-answers-after-arenas
**Q:** After D-84, where do slices 5 to 7 belong, and which Notion notes are allowed?
**A:** (Jeff, 2026-10-17) Slices 5 to 7 STAY in V2-DIRECTIVE-002 (against the orchestrator's advice to move them to a new story). The GDD is not changed (Jeff: "You are not allowed to change GDD"). Notion: only a watch note on V2-STAGE-010 is allowed; no new-story draft. The note was written on 2026-10-17 (section 'Watch note: exposure choices are rare on generated boards'). It names the overlap with V2-COMBAT-004 slices 004B and 004D (combat-board generation is out of V2-STAGE-010 scope on that page) for Jeff to settle.

### D-86. fewer-runs-and-one-run-for-slices-5-to-7
**Q:** The recorded-value runs took too long (Jeff, 2026-10-17: "reduce the amount of runs"). Can slices 5 to 7 share one recorded-value run? This changes D-79 (one run per slice).
**A:** Yes (Jeff, 2026-10-17). Slices 5, 6 and 7 are built one after another with unit tests only, then ONE recorded-value run covers all three. Each slice has its own config switch so one OFF arm switches all three off. If the old values return, the moves come from slices 5 to 7 together. A moved value is narrowed to one slice with one more arm only if needed. Other cuts (orchestrator): no separate re-run after the slice 4 re-record (the values come from the ON logs, a script checks each against the log, the final full suite checks them once); no more probes; after a small fix only the one or two suites it touches are re-run; QA agents run no tests; one full serial suite at the end of phase D.

### D-87. one-reading-per-system
**Q:** (Jeff, 2026-10-17, after the slices 5 to 7 note took the larger of fear and low morale instead of the Sanctum emotional state.) Rule: 'I don't want multiple reinterpretations of the same systems. This is 1 game. Things need to work well together and build off each other. Otherwise it gets confusing for a player.'
**A:** Binding design rule for this story and later ones. Each game system has ONE definition, and every part of the game reads that definition: fear and morale together are the Sanctum emotional state (`EmotionService.get_emotional_status(morale, fear)`, ten ordered bands); Judgment is one value; composure is one value; exposure tolerance is one value. New work builds on these. It adds no second reading. The slices 5 to 7 note is reworked around the emotional state and carries an audit table of every place these systems reach a combat movement, step or stop decision (keep / merge / conflict). Reworks of committed slices 2, 3 and 4 are options for Jeff, not done by agents on their own.

### D-88. slice-4-qa-answers
**Q:** Slice 4 QA check (2026-10-17): stop rate, floor keys, stop line wording, small fixes. Jeff answered:
**A:** (Jeff, 2026-10-17)
- **Stop rate (F5):** add a stop-rate check to the one combined run for slices 5 to 7 (D-86): print stop counts per Echo; if a calm Echo's stop rate is above the 25 percent measured ceiling of stop-short decision #108, lower the guard affinity. No extra run now and no new code limit.
- **Floor keys (N2, F4):** ONE shared Directive Judgment floor key in config for the acceptance scale and the stop scale (rule D-87), plus the minimum bound as a config key (`judgment_floor_min`, 0.55, D-83 B). No bound literal in code or tests. One shared helper for the scale and the swing (N3).
- **Stop line:** proposal C, `cause_clause.directive_order` = "I follow what I was told." (No screen shows it yet.)
- **Small fixes:** fix all (F1, F2, F3, F6, N7), and clean the comments: 'Reduce comments to what is needed and update. Shorter is better. Avoid referring to stories or hard coded numbers. Rather refer to config.' Applies to the code, test and config comments phase D added or rewrote.
- **Not decided here:** N4 (does the Directive stop bias count as the Echo's own judgment in the divergence probe) stays open; it is checked in the final combined QA.

### D-89. slices-5-to-7-design-answers
**Q:** The reworked note `phase-d-design-5-7.md` (shared emotional state, one reading per system, D-87): Q1 to Q5.
**A:** (Jeff, 2026-10-17)
- **Q5 (rework of committed code):** take C1 to C5 now, inside the one run (D-86). C1 chip input uses `max(fear, fear_base)`; C2 slice 2 fear lean reads the emotional status band; C3 composure softens that lean; C4 fear lowers Judgment through the band; C5 stop-short fear and morale read the band (the second fear ramp and `morale_strength` go). C6 and C7 (style, action layer) wait for a later story. C8: `_DEFAULTS` swing value follows config.
- **Q1:** keep the +1 step for a radiant Echo (high morale, low fear).
- **Q2:** radiant lean +0.7.
- **Q3:** per-layer swing ceilings of 2.0 for the action layer and the stop layer; shared budget 2.5; the Directive Judgment floor minimum may need to follow the budget test (the note says 0.56 at 2.5; the config key `judgment_floor_min` is the one place to change).
- **Q4:** accept that slice 7 is quiet and has no neutral point; it reuses `identity_weight_scale`.
- **Build basis:** the note is the build basis; its numbers are PROPOSED DEFAULT in config. Build order (one builder at a time, they share files): (a) shared status-lean module + C1 to C5 + C8; (b) slice 5; (c) slice 6; (d) slice 7. Unit tests only. Then ONE recorded-value run. Attribution: one OFF arm sets the three `enabled` switches of slices 5 to 7 to false; values that still move come from C1 to C5, the rest from slices 5 to 7. The stop-rate check of D-88 is part of that run.

### D-90. stop-rate-check-result
**Q:** Stop-rate check (D-88): how often do Echoes stop short with the shipped Directive stop cause and slices 5 to 7?
**A:** Measured 2026-10-17 with the `parts` arm (7 fixed fights, Echo route-deciding turns, purifier turns excluded; two arms in parallel). Scout: 23 stops in 263 turns (8.7 percent). Seek: 20 stops in 265 turns (7.5 percent). By fight (Scout, stops/turns): combat 2/31, purify_shrine 2/32, recover 2/10, protect 3/25, endure 1/25, pursue 0/20, guide_spirit 13/120. No Echo with 5 or more turns is above 25 percent except in samples of 5 to 7 turns (protect 2 of 5 for one Echo; Seek combat 2 of 7). The feared 'a stop every other turn' did not appear. The 25 percent reference of stop-short decision #108 is not a config key; the probe prints rates only. No change to the guard affinity. The probe's STOPRATE_SUMMARY and STOPCAUSE lines did not appear in the output (only the per-Echo lines); who stops (Directive, fear or identity) is not measured. Not a blocker.

### D-91. final-qa-answers
**Q:** Final combined QA (2026-10-17): one blocker (slice 7 not wired into the style call), several should-fix items, and three questions for Jeff.
**A:** (Jeff, 2026-10-17)
- **Fix all** the findings (B1 slice 7 wiring plus a decision-level test; S2 divergence label: subtract the Directive acceptance part and the Directive stop bias; S3 record the swing convention explicitly; S4 move the felt-state validator ranges to config and use config defaults for fallbacks; S5 false comments; N2 widen the guard scan and document the stage Judgment change; N3 validate only enabled felt-state sections; N7 include composure in the fear rule test; N8 one Echo-only gate for slices 5 and 6). Then ONE more ON run, a re-record, and one last full serial suite.
- **S1 (fear input of the one status):** everywhere the larger of fear and base fear (the simulation reading). One helper for every status reader, the Sanctum builders, party, stage preview and explore snapshots included. The resolve screen's `pre_status` uses the same input as `post_status`.
- **Stage ramp (D-09 against D-87):** ALIGN THE STAGE NOW (Jeff chose this against the advice to keep D-09 as a recorded exception). The stage party leans read the emotional status through the same band table, in place of the two raw fear and morale ramps in `data.stages.party_stance.state_ramps`. This moves stage recorded values (stage_explore fingerprint, traversal expectations); the next ON run covers the stage suites. Stage numbers: PROPOSED DEFAULT; the lean weights per dial stay in config.
- **Convention for the swing budget (S3):** 'multiplier at J = 1' stays the convention of the approved note; the test says so and passes the own side explicitly.

### D-92. story-folder-cleanup-after-merge
**Q:** Clean up `docs/stories/v2-directive-002/` (32 MB) so that only necessary files stay? (Jeff, 2026-10-18: "only keep necessary files, work files and temp files can be removed.")
**A:** The list is approved. Delete ONLY AFTER PR 108 is merged (Jeff, 2026-10-18). Then do it on a new branch from main, as one docs-only commit and a small PR, and patch every link that points to a removed file.
- **Keep:** `decisions.md`, `design.md`, `phase-d-design.md`, `phase-d-design-5-7.md`, `numbers.md`, `phase-d-numbers.md`, `follow-ups.md`, `exposure-lever-study.md`, `state-systems-movement-study.md`, `glyph-ai-prompts.md`, `glyph-shapes.md`, `probes/` (both files), `mockups/README.md` (update it), `mockups/v3/` (README, index.html, assets), `mockups/v4/` (all).
- **Remove:** `backend-plan.md`, `bend-strength-proposal.md`, `route-character-options.md`, `slack-gate-options.md`, `new-story-drafts.md`, `play-findings-report.md`, `timings-proposal.md`, `handoff.md`, `handover.md`, `post-compaction-prompt.md`, `proposed-wording.md`, `proposed-wording-stop-cause.md`, `mockups/v2/`, `mockups/review/`, `mockups/stage-stop-marker-mockup.*`, `mockups/stage-stop-marker-mockup-preview.png*`, `mockups/stage-stop-glyph-sheet.png`, the 38 preview images in `mockups/v3/` and every `.import` file next to a removed image.
- **Links to patch:** `docs/integration-map.md`, `docs/MEMORY.md`, `docs/LESSONS.md`, `docs/project_systems_audit.md`, `docs/stories/v2-combat-005/story-draft.md`, and any file that cites a removed path (grep `v2-directive-002/` first).
- **Also in that commit:** the stale suite-count comments (`AGENTS.md` ~203 and ~291, `scripts/run-tests-sharded.sh` ~22, ~93, ~267) need Jeff's yes for the AGENTS.md lines.
- **Order of work after the merge:** (1) refresh main; (2) new branch; (3) remove; (4) patch links; (5) `grep` that no link is dead; (6) commit and open the PR. Git history keeps every removed file.

### D-93. finished-glyphs
**Q:** Jeff supplied six finished stop glyphs (2026-10-18; images 3.1 to 3.6 in the order arrived_at, capacity_spent, interrupted, spotted_ahead, paused_to_read, no_route; each with a proverb source and a meaning). How do they go into the game?
**A:** (Jeff, 2026-10-18)
- **Small sizes:** options A and B together. 28 px is the practical minimum size (why card title 28 px; Echo card and party card 24 px). The 24 px glyph gets a thin cream rim so the brown outline reads on the dark portrait square.
- **Closed outline:** `interrupted` and `no_route` must have a CLOSED outline. The supplied images cut the path off flat at the bottom with no outline. The closing is made in the processing step; if image processing cannot do it cleanly, Jeff regenerates those two images.
- **When:** a separate small PR after PR 108 is merged (one subject per PR). The cleanup PR (D-92) is another small PR.
- **Work files:** the scratchpad folder with the glyph work (processed PNGs, preview sheets, a Python venv with Pillow) is cleaned when the glyph PR is done.
- **Integration needs (for that PR):** `StopGlyphs.gd` load path from `.svg` to `.png`; six PNGs with mipmaps on; delete the six draft SVGs and their `.import` files; update the docs that name the `.svg` path; a visual check at 960x540 on a real card; no tint (modulate stays white).
- **Closed outlines accepted as made (Jeff, 2026-10-18):** the processed outlines of `interrupted` and `no_route` are accepted. Known limits seen only at 256 px or more: the new bottom stroke is slightly thinner than the side strokes, its corners are tighter, it has no thin dashed light line, and `no_route` has a small notch at the bottom-left join. No regeneration. Ship set: six 256x256 RGBA PNGs with the cream rim (`stop_<kind>.png`); the game must not crop the texture. Capacity_spent and spotted_ahead stay marginal at 24 px (still read as a pouch and an eye).

### D-94. cleanup-done
**Q:** What did the story folder cleanup (D-92) leave?
**A:** The removed files are gone, the kept files are patched, and the glyph path is now `.png`. See D-92 and D-93.

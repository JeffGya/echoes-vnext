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

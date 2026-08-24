# res://core/realms/ContactResponseService.gd
# V2-INFRA-003 Phase 5 Slice C: the authored-contact-dialogue DATA LOADER extracted out of
# FlowRuntime.gd (FlowRuntime._load_contact_responses + its _contact_responses_cache member).
#
# WHY A SERVICE AND NOT A ContactController METHOD.
# After this slice the loader has callers in TWO owners: ContactController (consult_echoes,
# speak_response's follow-up-line lookup, and _build_contact_resolve_snapshot's outcome_texts
# lookup) and FlowRuntime._start_contact_conversation, which stays on FlowRuntime because its
# only caller is the stage.engage_situation handler that ContactController does not own (see
# ContactController.gd's STEP 0 section). core/AGENTS.md: "A helper used by two or more domains
# has an owner. Find it." A controller may not be reached as a bare mid-handler subroutine
# (the _repair_echo_schema precedent recorded in SanctumController.gd), so the loader cannot
# live on the controller.
#
# CORRECTED BY SLICE 5D — the sentence above ("stays on FlowRuntime") is left standing on
# purpose, so it is clear what was believed and where it was wrong. _start_contact_conversation
# did NOT stay on FlowRuntime: Slice 5D moved it to
# core/realms/ContactConversationService.gd::start_conversation(), and extracted
# stage.engage_situation itself to VentureController.handle_engage_situation(). The claimed
# blocker — that a service cannot host it because services take no flow_machine — was wrong;
# the only flow_machine work on the path was a trailing assign-then-refresh that the calling
# handler now returns as a FlowActionOutcome. See ContactController.gd's STEP 0 section for the
# full correction and ContactConversationService.gd for the destination's own reasoning.
#
# THE CONCLUSION OF THIS SECTION IS UNCHANGED, and is now better supported, not worse: the
# loader still has callers in two owners — ContactController and, since 5D,
# ContactConversationService (also a service, not FlowRuntime). "A helper used by two or more
# domains has an owner" still puts it here rather than on either caller.
#
# WHY core/realms/ AND NOT core/data/ OR core/conversation/.
# core/AGENTS.md: "Wraps a domain class -> a service placed BESIDE that class." The domain class
# for this data is ConversationService (core/realms/ConversationService.gd) — it is
# ConversationService.generate_responses() that consumes the parsed dictionary, and the
# `role -> lines` shape of contact_responses.json is ConversationService's input contract.
# Slice A placed ActiveStageService in core/realms/ by the same reasoning (its domain
# classes StageExploreModel/SituationModel live there), rather than under core/runtime/.
# There is no core/conversation/ package — ConversationService itself lives in core/realms/.
#
# WHY THE CACHE IS `static var` AND NOT AN INSTANCE MEMBER.
# Pre-extraction the cache was a per-FlowRuntime instance member. This service is reached
# statically (no construction), so an instance member would either vanish — re-reading and
# re-parsing the JSON on every one of the ~5 call sites per conversation turn — or force
# callers to hold a service instance, which the FlowRuntime call site cannot do without
# reintroducing exactly the member this slice removes. A process-wide cache is safe here
# because the source is a read-only res:// file with no writer anywhere in the codebase: the
# parsed value is byte-identical for every FlowRuntime instance in the process. Semantics that
# ARE preserved verbatim: missing file / unopenable file / non-Dictionary parse all return the
# (empty) cache WITHOUT populating it, so a later successful read still wins.
#
# PURE READ — no side effects, no save_data access, no logging, no RNG, no flow_machine.

class_name ContactResponseService

extends RefCounted

const RESPONSES_PATH := "res://data/conversations/contact_responses.json"

static var _contact_responses_cache: Dictionary = {}


## Returns the lazy-loaded, cached dictionary parsed from
## data/conversations/contact_responses.json. Moved verbatim from
## FlowRuntime._load_contact_responses (only the cache's storage location changed — see header).
static func load_responses() -> Dictionary:
	if not _contact_responses_cache.is_empty():
		return _contact_responses_cache
	if not FileAccess.file_exists(RESPONSES_PATH):
		return {}
	var f := FileAccess.open(RESPONSES_PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_contact_responses_cache = parsed
	return _contact_responses_cache

# res://core/onboarding/OpeningRealmService.gd
#
# V2-INFRA-003 Phase 8C — the opening-Realm gate.
#
# WHAT THIS OWNS
# The two save fields `onboarding.opening_realm_id` and `onboarding.opening_realm_status`, which
# were added to `SaveSchema` (with defaults and repair) in earlier Phase 8 groundwork and until
# now were read and written by nothing. This file is their single owner. Documented status
# values, unchanged from the schema comment: "locked" | "realm_ready" | "active" | "complete".
#
# THE ARC IT ENCODES
#   locked        the first session has not earned the opening Realm yet
#   realm_ready   the Flame is lit AND the stabilizing rite is done — the Realm may open
#   active        the prologue run exists and is being played
#   complete      the prologue is finished; the normal Realms open, in any order
#
# WHY THE GATE IS AWAKENING + FIRST WEAVE, AND NOT THE SECOND ECHO — RECORDED DIVERGENCE
# GDD §20.7 puts the second summon before the opening Realm. That ordering assumes an Ase grant
# at the awakening, which does NOT exist: `data.economy.awakening_ase_grant` has never had a
# consumer and is deferred to V2-ECONOMY-002. The player leaves the keeper intro with exactly the
# 40 Ase the first trial pays, against a 60 Ase summon cost, so gating the opening Realm on a
# second Echo would stall the arc at its first beat with nothing to do. The gate is therefore the
# two beats the player HAS just completed — the awakening and the stabilizing rite. This
# divergence is deliberate and is recorded here and in the defect register; do not "fix" it back
# without the awakening grant landing first.
#
# SUMMONING GATES NOTHING. It unlocks as a capability at the same moment and is limited only by
# what the player can afford (`FlowSummonState` computes `summon_disabled` from
# `ase_balance < selected_cost` and nothing else). No code in this file touches it.
#
# CONTRACT
#   - Static-only service. No flow_machine, no controller calls, no SaveService.
#   - Save intent is requested through `flow_ctx.request_save(reason)`, per the controller/service
#     rules in AGENTS.md.

class_name OpeningRealmService
extends RefCounted

const STATUS_LOCKED := "locked"
const STATUS_REALM_READY := "realm_ready"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETE := "complete"


static func _onboarding(save_data: Dictionary) -> Dictionary:
	if not save_data.has("onboarding") or not (save_data["onboarding"] is Dictionary):
		save_data["onboarding"] = {}
	return save_data["onboarding"]


static func get_status(save_data: Dictionary) -> String:
	var ob_v: Variant = save_data.get("onboarding", {})
	var ob: Dictionary = ob_v if ob_v is Dictionary else {}
	return str(ob.get("opening_realm_status", STATUS_LOCKED))


static func get_realm_id(save_data: Dictionary) -> String:
	var ob_v: Variant = save_data.get("onboarding", {})
	var ob: Dictionary = ob_v if ob_v is Dictionary else {}
	return str(ob.get("opening_realm_id", ""))


## True once the prologue has been finished and the normal Realms are open in any order.
##
## An OLD SAVE READS FALSE and would be stranded — a campaign written before this slice has the
## schema default "locked" with the keeper intro long since complete. `KeeperIntroService
## .is_complete()` is therefore accepted as an equivalent: a player who already finished the
## intro under the old build has, by definition, passed every beat this gate measures.
static func normal_realms_unlocked(save_data: Dictionary) -> bool:
	if get_status(save_data) == STATUS_COMPLETE:
		return true
	if get_status(save_data) == STATUS_LOCKED and KeeperIntroService.is_complete(save_data):
		return true
	return false


## Awakening + first Weave are both done — the opening Realm may now open.
## Idempotent, and only ever advances "locked" -> "realm_ready"; a later beat never rewinds.
static func mark_realm_ready(save_data: Dictionary, logger: StructuredLogger, t: int) -> void:
	var ob := _onboarding(save_data)
	if str(ob.get("opening_realm_status", STATUS_LOCKED)) != STATUS_LOCKED:
		return
	if not KeeperIntroService.is_ase_flame_awakened(save_data):
		return
	ob["opening_realm_id"] = RealmService.PROLOGUE_REALM_ID
	ob["opening_realm_status"] = STATUS_REALM_READY
	if logger != null:
		logger.info(t, "onboarding.opening_realm.ready", "Opening Realm unlocked by awakening + first Weave", {
			"opening_realm_id": RealmService.PROLOGUE_REALM_ID,
		})


## Creates the prologue run and makes it the active Realm. No-op unless the status is exactly
## "realm_ready", so a replayed or repeated `keeper_intro.complete` cannot open it twice.
##
## Returns true if the run was opened by this call.
##
## NO EXTRA DISPATCH. This runs inside the `keeper_intro.complete` dispatch that already exists;
## `RealmService.get_or_create` requests its own save on the same tick. The retreat roll seeds on
## the simulation tick, so adding a dispatch here would change every retreat result in the game.
##
## The seed path is a NEW namespace ("campaign.realm.prologue.run.0"). `CampaignSeed.derive`
## hashes the whole path, so a new namespace cannot reorder or perturb any existing one.
static func open_prologue(flow_ctx: FlowContext, t: int) -> bool:
	if get_status(flow_ctx.save_data) != STATUS_REALM_READY:
		return false
	var cfg: Dictionary = flow_ctx.config_service.get_balance() if flow_ctx.config_service != null else {}
	var virtue := KeeperIntroService.get_selected_virtue(flow_ctx.save_data, cfg)
	if virtue.is_empty():
		virtue = "courage"
	var model := RealmService.get_or_create(
		RealmService.PROLOGUE_REALM_ID, flow_ctx, t, { "virtue": virtue }
	)
	if model.is_empty():
		# get_or_create already logged realm.create.fail. Leave the status at "realm_ready" so a
		# later attempt can still succeed rather than stranding the player behind a dead gate.
		return false
	flow_ctx.realm_id = RealmService.PROLOGUE_REALM_ID
	var ob := _onboarding(flow_ctx.save_data)
	ob["opening_realm_id"] = RealmService.PROLOGUE_REALM_ID
	ob["opening_realm_status"] = STATUS_ACTIVE
	flow_ctx.request_save("onboarding.opening_realm.open")
	flow_ctx.logger.info(t, "onboarding.opening_realm.open", "Opening Realm opened", {
		"realm_id": RealmService.PROLOGUE_REALM_ID,
		"virtue": virtue,
		"stage_count": int(model.get("stage_count", 0)),
	})
	return true


## The prologue is finished — the normal Realms open, in any order.
## Idempotent; only advances "active" -> "complete".
static func mark_complete(save_data: Dictionary, logger: StructuredLogger, t: int) -> void:
	var ob := _onboarding(save_data)
	if str(ob.get("opening_realm_status", STATUS_LOCKED)) != STATUS_ACTIVE:
		return
	ob["opening_realm_status"] = STATUS_COMPLETE
	if logger != null:
		logger.info(t, "onboarding.opening_realm.complete", "Opening Realm complete; normal Realms open", {})

# res://tests/RealmRewardTests.gd
# The realm virtue, the stage index and the realm order pay no Ase (D-40). The stage payout is
# the objective base, the realm scale and the replay factor only.
#
# Tests:
#   1. realm_reward/stage_payout_is_base_only      — one Ase row, no virtue row, no virtue term
#   2. realm_reward/virtue_helper_removed          — RealmService no longer has calculate_stage_reward
#   3. realm_reward/stage_payout_rows_pure        — same inputs give the same rows; no stage means no preview

extends RefCounted
class_name RealmRewardTests


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("realm_reward/stage_payout_is_base_only",   Callable(RealmRewardTests, "_t_base_only"))
	runner.register_test("realm_reward/virtue_helper_removed",       Callable(RealmRewardTests, "_t_helper_removed"))
	runner.register_test("realm_reward/stage_payout_rows_pure",     Callable(RealmRewardTests, "_t_rows_pure"))


static func _t_base_only() -> Dictionary:
	var rows := EconomyService.stage_payout_rows(25, 1.0, 1.0, { "overcome": 2, "total": 2 }, 8)
	var breakdown: Array = rows["breakdown"]
	if int(rows["ase"]) != 25 or int(rows["ekwan"]) != 8 or breakdown.size() != 1:
		return { "ok": false, "error": "expected 25 Ase, 8 Ekwan, one row; got %s" % str(rows) }
	if str((breakdown[0] as Dictionary).get("cause", "")) != "objectives_overcome":
		return { "ok": false, "error": "the only row must be objectives_overcome: %s" % str(breakdown) }
	return { "ok": true }


static func _t_helper_removed() -> Dictionary:
	for m_v in (RealmService as GDScript).get_script_method_list():
		if str((m_v as Dictionary).get("name", "")) == "calculate_stage_reward":
			return { "ok": false, "error": "RealmService.calculate_stage_reward still exists" }
	return { "ok": true }


## The payer takes no realm input, so the same base, scale and factor give the same Ase and rows.
static func _t_rows_pure() -> Dictionary:
	var first := EconomyService.stage_payout_rows(16, 1.0, 0.9, { "overcome": 1, "total": 1 }, 3)
	var second := EconomyService.stage_payout_rows(16, 1.0, 0.9, { "overcome": 1, "total": 1 }, 3)
	if JSON.stringify(first) != JSON.stringify(second):
		return { "ok": false, "error": "non-deterministic payout rows" }
	if int(first["ase"]) != 14:
		return { "ok": false, "error": "16 x 0.9 must pay 14, got %d" % int(first["ase"]) }
	var plan := StageSettlementService.new(FlowContext.new(), null, null, null)
	if plan.preview() != {}:
		return { "ok": false, "error": "a context with no stage must preview nothing" }
	return { "ok": true }

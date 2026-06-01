# res://ui/components/EchoSkillRow.gd
# PROG-009: Per-echo skill picker row in StageMap party prep bar.
# Shows echo name + calling + OptionButton with available calling skills.
# Emits skill_selected(echo_id, skill_id) when the Keeper picks a skill.

class_name EchoSkillRow
extends PanelContainer

signal skill_selected(echo_id: String, skill_id: String)

@onready var _name_label:   Label        = %NameLabel
@onready var _calling_label: Label       = %CallingLabel
@onready var _skill_picker: OptionButton = %SkillPicker

var _echo_id: String = ""
var _skill_ids: Array = []  # parallel to OptionButton items

func setup(prep_entry: Dictionary) -> void:
	_echo_id = str(prep_entry.get("echo_id", ""))
	_name_label.text    = str(prep_entry.get("echo_name",  "Echo"))
	# V2-PROG-002/005: confirmed calling id lives in calling_id, not calling_origin
	_calling_label.text = str(prep_entry.get("calling_id", "—")).capitalize()

	var skills_v: Variant = prep_entry.get("available_skills", [])
	var skills: Array = skills_v if skills_v is Array else []

	# PROG-009 fix: if echo has no unlocked skills, disable picker with a clear prompt.
	var has_unlocked: bool = bool(prep_entry.get("has_unlocked_skills", not skills.is_empty()))
	_skill_picker.clear()
	_skill_ids.clear()
	if not has_unlocked:
		_skill_picker.add_item("No skills unlocked", 0)
		_skill_ids.append("")
		_skill_picker.disabled = true
		return

	_skill_picker.disabled = false
	_skill_picker.add_item("Pick skill", 0)
	_skill_ids.append("")  # index 0 = no selection

	for i in range(skills.size()):
		var s: Dictionary = skills[i] if skills[i] is Dictionary else {}
		var display := str(s.get("display_name", "?"))
		var sid     := str(s.get("skill_id",     ""))
		# V2-PROG-005: append family label so the Keeper sees which family the skill belongs to
		var family  := str(s.get("skill_family", ""))
		if not family.is_empty():
			display = "%s [%s]" % [display, family.capitalize()]
		_skill_picker.add_item(display, i + 1)
		_skill_ids.append(sid)

	# Restore in-session selection if one exists
	var equipped_id := str(prep_entry.get("equipped_skill_id", ""))
	if not equipped_id.is_empty():
		for idx in range(_skill_ids.size()):
			if _skill_ids[idx] == equipped_id:
				_skill_picker.select(idx)
				break

	if not _skill_picker.item_selected.is_connected(_on_skill_picked):
		_skill_picker.item_selected.connect(_on_skill_picked)

func _on_skill_picked(index: int) -> void:
	if index < 0 or index >= _skill_ids.size():
		return
	var sid : Variant = _skill_ids[index]
	skill_selected.emit(_echo_id, sid)

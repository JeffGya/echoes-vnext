# res://ui/components/CarriedHomePanel.gd
# The "carried home" comparator on the return-home and retreat decisions. Shows the carried line
# only when Ase or Ekwan is above 0, and then always with the party, the stage-waits line and the
# advance note. All structure is in the .tscn; this script sets values and visibility.

class_name CarriedHomePanel
extends VBoxContainer

const Strings := preload("res://ui/components/CarriedHomePresentation.gd")

@onready var _carried_block: VBoxContainer = %CarriedBlock
@onready var _title: Label = %CarriedTitle
@onready var _advance_note: Label = %AdvanceNote
@onready var _party_header: Label = %PartyHeader
@onready var _ase_line: Label = %AseLine
@onready var _ekwan_line: Label = %EkwanLine
@onready var _party_block: VBoxContainer = %PartyBlock
@onready var _party_list: Label = %PartyList
@onready var _waits_line: Label = %WaitsLine
@onready var _cost_line: Label = %CostLine


## carry is { ase, ekwan, overcome, total }. party is [{ name, emotional_status }]. cost_text is ""
## when the decision has no cost line. `total` is never shown.
## always_comparator is true on the return-home confirmation: the people, the stage-waits line and the
## cost show even when nothing is carried. Only the carried lines stay tied to Ase or Ekwan above 0.
func present(carry: Dictionary, party: Array, cost_text: String = "", always_comparator: bool = false) -> void:
	_title.text = Strings.CARRIED
	_advance_note.text = Strings.ADVANCE_NOTE
	_party_header.text = Strings.WITH_PARTY
	_waits_line.text = Strings.STAGE_WAITS
	var ase := int(carry.get("ase", 0))
	var ekwan := int(carry.get("ekwan", 0))
	var carried := ase > 0 or ekwan > 0
	_carried_block.visible = carried
	_ase_line.text = Strings.ase_line(ase)
	_ase_line.visible = ase > 0
	_ekwan_line.text = Strings.ekwan_line(ekwan)
	_ekwan_line.visible = ekwan > 0
	var lines: Array[String] = []
	for entry_v in party:
		if entry_v is Dictionary:
			var line := Strings.party_line(entry_v)
			if not line.is_empty():
				lines.append(line)
	_party_list.text = "\n".join(lines)
	_party_block.visible = (carried or always_comparator) and not lines.is_empty()
	_waits_line.visible = always_comparator or int(carry.get("overcome", 0)) > 0
	_cost_line.text = cost_text
	_cost_line.visible = not cost_text.is_empty() and (carried or _waits_line.visible)
	visible = _carried_block.visible or _waits_line.visible or _party_block.visible

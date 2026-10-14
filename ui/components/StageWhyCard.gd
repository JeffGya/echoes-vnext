class_name StageWhyCard
extends PanelContainer
## The journey entry of the last Advance, shown on demand (D-32). Parchment card, at most four rows.
## RealmShell opens and closes it. F2 hooks: open() and close() are the only places that show or hide it.

signal closed

@onready var _glyph: TextureRect = %HeaderGlyph
@onready var _title: Label = %TitleLabel
@onready var _close: Button = %CloseButton
@onready var _rows: Array[Label] = [%RowCause, %RowPurpose, %RowRoute, %RowEcho]


func _ready() -> void:
	_close.pressed.connect(close)
	_close.accessibility_name = StageWhyText.text("ui", "close_why")


## Fills the card from a snapshot `travel_why` and shows it.
func open(why: Dictionary) -> void:
	var content := StageWhyText.compose(why)
	var kind := str(why.get("stop_kind", ""))
	_glyph.texture = StopGlyphs.texture(kind)
	_title.text = str(content["title"])
	var lines: Array = content["rows"]
	for i in _rows.size():
		_rows[i].text = str(lines[i]) if i < lines.size() else ""
		_rows[i].visible = i < lines.size()
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()

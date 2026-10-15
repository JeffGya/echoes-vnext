class_name StageWhyCard
extends PanelContainer
## The journey entry of the last Advance, shown on demand (D-32). Parchment card, at most four rows.
## RealmShell opens and closes it. open() and close() are the only places that show or hide it.

signal closed

@onready var _glyph: TextureRect = %HeaderGlyph
@onready var _title: Label = %TitleLabel
@onready var _close: Button = %CloseButton
## Fade times in seconds, set by RealmShell from the snapshot.
var open_seconds := 0.15
var close_seconds := 0.1
var _tween: Tween
var _closing := false

@onready var _rows: Array[Label] = [%RowCause, %RowPurpose, %RowRoute, %RowEcho]


func _ready() -> void:
	_close.pressed.connect(close)
	_close.accessibility_name = StageWhyText.text("ui", "close_why")


## Fills the card from a snapshot `travel_why` and shows it.
func open(why: Dictionary) -> void:
	var fresh := not is_open()
	var content := StageWhyText.compose(why)
	var kind := str(why.get("stop_kind", ""))
	_glyph.texture = StopGlyphs.texture(kind)
	_title.text = str(content["title"])
	var lines: Array = content["rows"]
	for i in _rows.size():
		_rows[i].text = str(lines[i]) if i < lines.size() else ""
		_rows[i].visible = i < lines.size()
	if not fresh:
		return
	_kill_tween()
	modulate.a = 0.0
	visible = true
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, open_seconds)


## True from the tap that opens it to the tap that closes it, also while it fades out.
func is_open() -> bool:
	return visible and not _closing


func close() -> void:
	if not is_open():
		return
	_kill_tween()
	_closing = true
	closed.emit()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, close_seconds)
	_tween.tween_callback(_finish_close)


func _finish_close() -> void:
	visible = false
	_closing = false


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_closing = false

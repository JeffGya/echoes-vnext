class_name RealmRecoveryCord
extends VBoxContainer

# V2-WEAVE-001: Segmented horizontal strip showing per-stage recovery quality.
# One cell per stage. Filled cells rendered with virtue-palette colors by quality tier.
# Persistent mini-legend always visible below: [●] Strong  [≋] Compromised  [✕] Weak
# Read-only — no dispatch.

# Shares the same palette as ThreadSlotItem (same source: Art Direction Bible v2).
const VIRTUE_PALETTE: Dictionary = {
	"courage":     { "clean": Color("#E8D5B0"), "compromised": Color("#C8A55A"), "broken": Color("#A67848"), "border": Color("#6B5A4A") },
	"wisdom":      { "clean": Color("#E8EDE8"), "compromised": Color("#B0B8B0"), "broken": Color("#A0B8C0"), "border": Color("#8BA888") },
	"leadership":  { "clean": Color("#E8D8C8"), "compromised": Color("#E86830"), "broken": Color("#B83028"), "border": Color("#8A7870") },
	"acceptance":  { "clean": Color("#78A0B0"), "compromised": Color("#C8D8E0"), "broken": Color("#3A4A58"), "border": Color("#5A7060") },
	"humility":    { "clean": Color("#F8F4E8"), "compromised": Color("#F0D060"), "broken": Color("#D0E0F0"), "border": Color("#C8D0D8") },
	"forgiveness": { "clean": Color("#C08890"), "compromised": Color("#908090"), "broken": Color("#607890"), "border": Color("#7860A0") },
	"truth":       { "clean": Color("#E0A8A0"), "compromised": Color("#F0F4F8"), "broken": Color("#4878B8"), "border": Color("#D0B858") },
	"generosity":  { "clean": Color("#E8E0D8"), "compromised": Color("#E06848"), "broken": Color("#A87830"), "border": Color("#286888") },
	"compassion":  { "clean": Color("#E8F0F0"), "compromised": Color("#A0C0D0"), "broken": Color("#909090"), "border": Color("#E88030") },
	"empathy":     { "clean": Color("#F8F8FC"), "compromised": Color("#D8ECF4"), "broken": Color("#90B8C8"), "border": Color("#506878") },
}

const DEFAULT_BORDER: Color = Color("#3A3A4A")
const CELL_WIDTH:  float = 40.0
const CELL_HEIGHT: float = 16.0

@onready var _cord_cells: HBoxContainer = %CordCells

var _virtue: String = ""


## Setup cord from stage count, completed segments, and active Realm's virtue.
## stage_count: total stages in this Realm
## segments: Array[{stage_index, quality_tier}] from snapshot data
## virtue: Realm's virtue string (e.g. "courage") — drives palette selection
func setup(stage_count: int, segments: Array, virtue: String) -> void:
	_virtue = virtue.to_lower()
	_rebuild_cells(stage_count, segments)


func _rebuild_cells(stage_count: int, segments: Array) -> void:
	if _cord_cells == null:
		return
	for c in _cord_cells.get_children():
		c.queue_free()

	# Build a lookup: stage_index → quality_tier
	var seg_map: Dictionary = {}
	for seg_v in segments:
		var seg: Dictionary = seg_v if seg_v is Dictionary else {}
		seg_map[int(seg.get("stage_index", -1))] = str(seg.get("quality_tier", "broken"))

	for i in range(stage_count):
		var quality_tier: String = seg_map.get(i, "") if seg_map.has(i) else ""
		var cell := _CordCell.new(_virtue, quality_tier, CELL_WIDTH, CELL_HEIGHT, VIRTUE_PALETTE, DEFAULT_BORDER)
		_cord_cells.add_child(cell)


# ─── Inner class: one cord segment cell ──────────────────────────────────────

class _CordCell extends Control:
	var _virtue: String
	var _quality_tier: String  # "clean" | "compromised" | "broken" | "" (empty = not yet completed)
	var _palette: Dictionary
	var _default_border: Color

	func _init(virtue: String, quality_tier: String, w: float, h: float, palette: Dictionary, default_border: Color) -> void:
		_virtue = virtue
		_quality_tier = quality_tier
		_palette = palette
		_default_border = default_border
		custom_minimum_size = Vector2(w, h)

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		var r: float = minf(size.x, size.y) * 0.5
		var center: Vector2 = size * 0.5

		var virtue_pal_v: Variant = _palette.get(_virtue, {})
		var virtue_pal: Dictionary = virtue_pal_v if virtue_pal_v is Dictionary else {}
		var border_col: Color = virtue_pal.get("border", _default_border) if not virtue_pal.is_empty() else _default_border

		if _quality_tier.is_empty():
			# Empty future stage: dim border only
			draw_rect(rect, Color(border_col.r, border_col.g, border_col.b, 0.2))
			draw_rect(rect, Color(border_col.r, border_col.g, border_col.b, 0.4), false, 1.0)
			return

		# Filled cell: radial gradient approximated with layered draw_circle
		var fill_col: Color = virtue_pal.get(_quality_tier, _default_border) if not virtue_pal.is_empty() else _default_border
		var steps := 8
		for i in range(steps, 0, -1):
			var t_val := float(i) / float(steps)
			var col := fill_col.lerp(border_col, 1.0 - t_val)
			draw_circle(center, r * t_val, col)

		# Broken: cracked line over the cell
		if _quality_tier == "broken":
			draw_line(
				center + Vector2(-r * 0.4, -r * 0.5),
				center + Vector2(r * 0.3, r * 0.6),
				Color(0.0, 0.0, 0.0, 0.5),
				1.0
			)

class_name ThreadSlotItem
extends Control

# V2-WEAVE-001: Circular sigil disc for the Sanctum Thread Reserve Strip.
# Rendered via _draw() — radial gradient from disc center outward (depth/3D feel).
# Virtue drives the color palette; quality_tier drives the fill gradient.
# Confirmed palette from Art Direction Bible v2.

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
const DEFAULT_FILL: Color   = Color("#A67848")

var _virtue: String = ""
var _quality_tier: String = ""
var _filled: bool = false


func setup_filled(virtue: String, quality_tier: String) -> void:
	_virtue = virtue.to_lower()
	_quality_tier = quality_tier
	_filled = true
	tooltip_text = "%s — %s" % [virtue.capitalize(), quality_tier.capitalize()]
	queue_redraw()


func setup_empty() -> void:
	_filled = false
	tooltip_text = ""
	queue_redraw()


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5
	var center: Vector2 = size * 0.5

	var palette_v: Variant = VIRTUE_PALETTE.get(_virtue, {})
	var palette: Dictionary = palette_v if palette_v is Dictionary else {}
	var border_col: Color = palette.get("border", DEFAULT_BORDER) if not palette.is_empty() else DEFAULT_BORDER

	if not _filled:
		# Empty: dim border ring only
		draw_arc(center, r - 2.0, 0.0, TAU, 64, Color(border_col.r, border_col.g, border_col.b, 0.3), 2.0)
		return

	# Filled: radial gradient disc — inner = quality tier color, outer = border color.
	# Approximated with layered draw_circle() since Godot 4 has no native radial gradient.
	var fill_col: Color = palette.get(_quality_tier, DEFAULT_FILL) if not palette.is_empty() else DEFAULT_FILL
	var steps := 12
	for i in range(steps, 0, -1):
		var t_val := float(i) / float(steps)
		var col := fill_col.lerp(border_col, 1.0 - t_val)
		draw_circle(center, r * t_val, col)

	# Broken: cracked line drawn over the disc
	if _quality_tier == "broken":
		draw_line(
			center + Vector2(-r * 0.3, -r * 0.4),
			center + Vector2(r * 0.2, r * 0.5),
			Color(0.0, 0.0, 0.0, 0.5),
			1.5
		)

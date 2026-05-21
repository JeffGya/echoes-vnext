# res://ui/screens/sanctum/ContinuityFlameControl.gd
# V2-CONTINUITY-001: Household Fire indicator for TitleRow.
# Permanent driving layer (API + animation engine). Rendering layer swaps to
# assets when available — drop flame_{band}.png in ASSET_PATH and it auto-activates.

class_name ContinuityFlameControl
extends Control


# Band → base ember color. Deep/warm, not bright — distinct from the active Ase Flame.
# Can be replaced with balance.json config in a future story without changing the API.
const BAND_COLORS := {
	"awakening":         Color(0.9,  0.4,  0.1),
	"habit":             Color(0.95, 0.55, 0.1),
	"role":              Color(1.0,  0.65, 0.15),
	"governance":        Color(1.0,  0.75, 0.2),
	"differentiation":   Color(1.0,  0.85, 0.3),
	"cultural_maturity": Color(1.0,  0.95, 0.5),
}

const ASSET_PATH := "res://ui/assets/continuity/flame_%s.png"

var _band:         String      = "awakening"
var _settled:      float       = 0.0
var _tween:        Tween
var _texture_rect: TextureRect  # null when no asset exists for current band


# ── Public API (permanent — never changes when assets arrive) ─────────────

func set_band(band: String) -> void:
	_band = band
	_try_load_asset()
	_restart_animation()


func set_settled(t: float) -> void:
	_settled = clampf(t, 0.0, 1.0)
	_restart_animation()


# ── Rendering layer (swaps transparently) ────────────────────────────────

func _try_load_asset() -> void:
	var path := ASSET_PATH % _band
	if ResourceLoader.exists(path):
		if _texture_rect == null:
			_texture_rect = TextureRect.new()
			_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(_texture_rect)
		_texture_rect.texture = load(path)
		_texture_rect.visible = true
		queue_redraw()
	elif _texture_rect != null:
		_texture_rect.visible = false


func _draw() -> void:
	if _texture_rect != null and _texture_rect.visible:
		return  # asset is rendering
	var w := size.x
	var h := size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.5, 0.0),
		Vector2(0.0,     h),
		Vector2(w,       h),
	]), Color.WHITE)  # modulate drives the color


# ── Animation engine (permanent — drives both procedural and assets) ──────

func _restart_animation() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_loops()
	var base: Color = BAND_COLORS.get(_band, BAND_COLORS["awakening"])
	# Unsettled (0.0): fast cycle 0.3s, wide brightness swing.
	# Settled   (1.0): slow cycle 1.2s, narrow swing.
	var duration := lerpf(0.3, 1.2, _settled)
	var swing    := lerpf(0.30, 0.06, _settled)
	_tween.tween_property(self, "modulate", base.lightened(swing * 0.5), duration * 0.4)
	_tween.tween_property(self, "modulate", base.darkened(swing),        duration * 0.6)

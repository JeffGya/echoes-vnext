# res://tests/BarkPopupLayerTests.gd
# V2-PROG-012 playtest fix: the combat_divergence bark — the moment an Echo's
# own judgment out-votes the Directive — gets a visually distinct popup
# template (indigo panel, bright gold border) instead of reusing the ordinary
# "original" bark styling. These tests pin:
#   1. the three-way template selection in BarkPopupLayer._show_bark_popup()
#      (combat_divergence > is_response > plain original)
#   2. the BarkPopupDivergence node exists in the scene with the approved
#      colours, so it can't be silently dropped or recoloured
#
# BarkPopupLayer.gd's header states it "only sets text, position, modulate,
# and drives Tweens" — all StyleBoxFlat authoring lives in the .tscn, so test
# 2 reads colours straight off the scene's SubResources, the same approach
# FoundationUITests._effective_panel_color() uses for other panels.

extends RefCounted
class_name BarkPopupLayerTests

const BarkPopupLayerScene := preload("res://ui/screens/combat/BarkPopupLayer.tscn")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("bark_popup/divergence_context_selects_divergence_template", Callable(BarkPopupLayerTests, "_t_selects_divergence_template"))
	runner.register_test("bark_popup/plain_bark_selects_original_template", Callable(BarkPopupLayerTests, "_t_selects_original_template"))
	runner.register_test("bark_popup/reaction_selects_reaction_template", Callable(BarkPopupLayerTests, "_t_selects_reaction_template"))
	runner.register_test("bark_popup/divergence_takes_precedence_over_is_response", Callable(BarkPopupLayerTests, "_t_divergence_precedence_over_response"))
	runner.register_test("bark_popup/divergence_template_has_approved_colors", Callable(BarkPopupLayerTests, "_t_divergence_template_colors"))


# ── fixture helpers ─────────────────────────────────────────────────────────

# BarkPopupLayer's _show_bark_popup() calls create_tween(), which requires the
# node to be inside a live SceneTree — so (unlike plain instantiate()-only
# fixtures elsewhere in this suite) this layer must be parented under the
# running game's current_scene, mirroring FoundationUITests._ready_fixture_host().
static func _make_layer_in_tree() -> BarkPopupLayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	var layer := BarkPopupLayerScene.instantiate() as BarkPopupLayer
	tree.current_scene.add_child(layer)
	return layer


static func _free_layer(layer: BarkPopupLayer) -> void:
	if layer != null and is_instance_valid(layer):
		layer.free()


## Identifies which template a shown popup was duplicated from. Node names are
## NOT reliable here — Node.add_child() auto-renames a duplicate that collides
## with an existing sibling name (the template itself is a permanent sibling
## under BarkPopupLayer), so the popup's own `.name` no longer matches its
## source template. Node.duplicate()'s default flags copy resource PROPERTIES
## by reference rather than deep-copying them, so the duplicated BarkPanel's
## "panel" StyleBoxFlat override is still the exact same Resource object as
## the source template's — that identity is what this compares.
static func _popup_template_kind(layer: BarkPopupLayer, actor_id: String) -> String:
	var entry: Dictionary = layer._active_popups.get(actor_id, {})
	var node: Node = entry.get("node")
	if node == null:
		return ""
	var panel := node.get_node_or_null("BarkPanel") as PanelContainer
	if panel == null:
		return ""
	var style: StyleBox = panel.get_theme_stylebox("panel")

	var orig_panel := layer._original_template.get_node("BarkPanel") as PanelContainer
	var react_panel := layer._reaction_template.get_node("BarkPanel") as PanelContainer
	var diverge_panel := layer._divergence_template.get_node("BarkPanel") as PanelContainer
	if style == orig_panel.get_theme_stylebox("panel"):
		return "original"
	if style == react_panel.get_theme_stylebox("panel"):
		return "reaction"
	if style == diverge_panel.get_theme_stylebox("panel"):
		return "divergence"
	return "unknown"


# ── template selection ──────────────────────────────────────────────────────

# Test 1 — FALSIFIABLE: if the three-way selection in _show_bark_popup() ever
# collapsed back to the old `is_response ? reaction : original` ternary
# (dropping the bark_context == "combat_divergence" branch), a divergence
# event would duplicate the original template instead, and this test's
# stylebox-identity check would fail.
static func _t_selects_divergence_template() -> Dictionary:
	var layer := _make_layer_in_tree()
	if layer == null:
		return { "ok": false, "error": "No live scene tree host available for BarkPopupLayer fixture" }
	layer._show_bark_popup({
		"actor_id":     "echo.divergence.test",
		"bark_line":    "I will not.",
		"bark_context": "combat_divergence",
		"is_response":  false,
		"screen_pos":   Vector2.ZERO,
	})
	var kind := _popup_template_kind(layer, "echo.divergence.test")
	_free_layer(layer)
	if kind != "divergence":
		return { "ok": false, "error": "Expected combat_divergence event to duplicate the divergence template, got '%s'" % kind }
	return { "ok": true }


# Test 2 — FALSIFIABLE: if the divergence branch were made unconditional (e.g.
# checking `not is_response` instead of `bark_context == "combat_divergence"`),
# an ordinary non-response bark would incorrectly duplicate BarkPopupDivergence
# and this test would fail.
static func _t_selects_original_template() -> Dictionary:
	var layer := _make_layer_in_tree()
	if layer == null:
		return { "ok": false, "error": "No live scene tree host available for BarkPopupLayer fixture" }
	layer._show_bark_popup({
		"actor_id":     "echo.original.test",
		"bark_line":    "Hold the line.",
		"bark_context": "combat_attack",
		"is_response":  false,
		"screen_pos":   Vector2.ZERO,
	})
	var kind := _popup_template_kind(layer, "echo.original.test")
	_free_layer(layer)
	if kind != "original":
		return { "ok": false, "error": "Expected plain bark event to duplicate the original template, got '%s'" % kind }
	return { "ok": true }


# Test 3 — FALSIFIABLE: pins that reaction routing (is_response=true,
# bark_context="combat_rally_ally") still resolves to the reaction template
# after the ternary was restructured into a three-way choice — a regression
# here would mean the restructure broke the pre-existing reaction path.
static func _t_selects_reaction_template() -> Dictionary:
	var layer := _make_layer_in_tree()
	if layer == null:
		return { "ok": false, "error": "No live scene tree host available for BarkPopupLayer fixture" }
	layer._show_bark_popup({
		"actor_id":     "echo.reaction.test",
		"bark_line":    "With you!",
		"bark_context": "combat_rally_ally",
		"is_response":  true,
		"screen_pos":   Vector2.ZERO,
	})
	var kind := _popup_template_kind(layer, "echo.reaction.test")
	_free_layer(layer)
	if kind != "reaction":
		return { "ok": false, "error": "Expected reaction event to duplicate the reaction template, got '%s'" % kind }
	return { "ok": true }


# Test 4 — explicit precedence check requested by the design brief: if
# is_response were somehow true on the SAME event as bark_context ==
# "combat_divergence" (never happens today — ActorStateMachine._check_reactive_bark()
# always overwrites _bark_context to "combat_rally_ally" in the same assignment
# that sets _bark_is_response = true, so the two never coexist in practice —
# see the comment above the selection block in BarkPopupLayer.gd), the
# divergence template must still win. FALSIFIABLE: if the `elif is_response`
# branch were ever reordered ahead of the `if is_divergence` check, this event
# would incorrectly duplicate BarkPopupReaction and this test would fail.
static func _t_divergence_precedence_over_response() -> Dictionary:
	var layer := _make_layer_in_tree()
	if layer == null:
		return { "ok": false, "error": "No live scene tree host available for BarkPopupLayer fixture" }
	layer._show_bark_popup({
		"actor_id":     "echo.precedence.test",
		"bark_line":    "No. Not this time.",
		"bark_context": "combat_divergence",
		"is_response":  true,
		"screen_pos":   Vector2.ZERO,
	})
	var kind := _popup_template_kind(layer, "echo.precedence.test")
	_free_layer(layer)
	if kind != "divergence":
		return { "ok": false, "error": "Expected combat_divergence to win over is_response=true, got '%s'" % kind }
	return { "ok": true }


# ── scene authoring ─────────────────────────────────────────────────────────

# Test 5 — FALSIFIABLE: if the BarkPopupDivergence node were deleted from
# BarkPopupLayer.tscn, get_node_or_null() below returns null and this test
# fails outright. If its StyleBoxFlat's bg_color/border_color, the BarkLabel's
# font_color, or the BarkTail's color were ever changed away from the
# designer-approved values (indigo panel / bright gold border / warm cream
# text, tail matching the panel), any of the four checks below fails on the
# exact value that drifted.
static func _t_divergence_template_colors() -> Dictionary:
	var layer := BarkPopupLayerScene.instantiate() as BarkPopupLayer
	var panel := layer.get_node_or_null("BarkPopupDivergence/BarkPanel") as PanelContainer
	if panel == null:
		layer.free()
		return { "ok": false, "error": "BarkPopupDivergence/BarkPanel is missing from BarkPopupLayer.tscn" }

	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		layer.free()
		return { "ok": false, "error": "BarkPopupDivergence/BarkPanel has no StyleBoxFlat 'panel' override" }

	var expected_bg := Color(0.165, 0.180, 0.361, 0.88)
	var expected_border := Color(0.910, 0.765, 0.290, 1.0)
	if not style.bg_color.is_equal_approx(expected_bg):
		layer.free()
		return { "ok": false, "error": "Expected divergence panel bg_color %s, got %s" % [str(expected_bg), str(style.bg_color)] }
	if not style.border_color.is_equal_approx(expected_border):
		layer.free()
		return { "ok": false, "error": "Expected divergence panel border_color %s, got %s" % [str(expected_border), str(style.border_color)] }

	var label := layer.get_node_or_null("BarkPopupDivergence/BarkPanel/BarkLabel") as Label
	if label == null:
		layer.free()
		return { "ok": false, "error": "BarkPopupDivergence/BarkPanel/BarkLabel is missing" }
	var expected_text := Color(1.0, 0.973, 0.863, 1.0)
	var label_color: Color = label.get_theme_color("font_color")
	if not label_color.is_equal_approx(expected_text):
		layer.free()
		return { "ok": false, "error": "Expected divergence label font_color %s, got %s" % [str(expected_text), str(label_color)] }

	var tail := layer.get_node_or_null("BarkPopupDivergence/BarkTail") as BarkTail
	if tail == null:
		layer.free()
		return { "ok": false, "error": "BarkPopupDivergence/BarkTail is missing" }
	if not tail.color.is_equal_approx(expected_bg):
		layer.free()
		return { "ok": false, "error": "Expected divergence tail color %s (matching panel bg), got %s" % [str(expected_bg), str(tail.color)] }

	layer.free()
	return { "ok": true }

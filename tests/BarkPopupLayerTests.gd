# res://tests/BarkPopupLayerTests.gd
# V2-PROG-012 playtest fix: the combat_divergence bark — the moment an Echo's
# own judgment out-votes the Directive — gets a visually distinct popup
# template (indigo panel, bright gold border) instead of reusing the ordinary
# "original" bark styling. These tests pin:
#   1. the three-way template selection (combat_divergence > is_response >
#      plain original), exercised as PURE LOGIC via
#      BarkPopupLayer.resolve_template_kind() — no scene tree involved.
#   2. the three template root nodes (BarkPopupOriginal/Reaction/Divergence)
#      exist under BarkPopupLayer.tscn at the exact paths resolve_template_kind's
#      result gets mapped to ($BarkPopupOriginal etc. in _template_for_kind())
#   3. the BarkPopupDivergence node carries the approved colours, so it can't
#      be silently dropped or recoloured
#
# tests/AGENTS.md: "Tests are pure GDScript — no UI, no scene tree, no network,
# no OS time." This suite previously parented a live BarkPopupLayer under
# SceneTree.current_scene to call _show_bark_popup() (which needs create_tween()),
# and failed outright with no current_scene — the opposite of "no scene tree."
# V2-PROG-012 playtest fix review: the selection decision was extracted out of
# _show_bark_popup() into a static, input-only helper
# (BarkPopupLayer.resolve_template_kind(bark_context, is_response) -> String)
# specifically so it stays testable without a live tree. See that function's
# doc comment in ui/screens/combat/BarkPopupLayer.gd for why divergence must
# win precedence.
#
# Known gap (documented, not papered over): with the selection extracted to
# pure logic, this suite no longer exercises the full duplicate-and-animate
# path of _show_bark_popup() end to end (that still needs create_tween(), which
# needs a live SceneTree). Test 2 below closes most of that gap statically —
# it confirms the exact node paths _template_for_kind() maps each kind onto
# ($BarkPopupOriginal / $BarkPopupReaction / $BarkPopupDivergence) actually
# exist in the scene — but it cannot prove the @onready template vars are
# non-null at runtime, since @onready assignment only fires on _ready(), which
# only fires once a node enters a live SceneTree. That remaining sliver needs
# either an in-game/editor smoke check or a scene-tree-hosted integration test
# living outside this pure suite.
#
# BarkPopupLayer.gd's header states it "only sets text, position, modulate,
# and drives Tweens" — all StyleBoxFlat authoring lives in the .tscn, so the
# colour test reads colours straight off the scene's SubResources, the same
# approach FoundationUITests._effective_panel_color() uses for other panels.

extends RefCounted
class_name BarkPopupLayerTests

const BarkPopupLayerScene := preload("res://ui/screens/combat/BarkPopupLayer.tscn")


static func register(runner: CoreTestRunner) -> void:
	runner.register_test("bark_popup/divergence_context_selects_divergence_template", Callable(BarkPopupLayerTests, "_t_selects_divergence_template"))
	runner.register_test("bark_popup/plain_bark_selects_original_template", Callable(BarkPopupLayerTests, "_t_selects_original_template"))
	runner.register_test("bark_popup/reaction_selects_reaction_template", Callable(BarkPopupLayerTests, "_t_selects_reaction_template"))
	runner.register_test("bark_popup/divergence_takes_precedence_over_is_response", Callable(BarkPopupLayerTests, "_t_divergence_precedence_over_response"))
	runner.register_test("bark_popup/template_nodes_exist_at_expected_paths", Callable(BarkPopupLayerTests, "_t_template_nodes_exist_at_expected_paths"))
	runner.register_test("bark_popup/divergence_template_has_approved_colors", Callable(BarkPopupLayerTests, "_t_divergence_template_colors"))


# ── template selection (pure logic — no scene tree) ────────────────────────

# Test 1a — FALSIFIABLE: if the three-way selection ever collapsed back to the
# old `is_response ? reaction : original` ternary (dropping the
# bark_context == "combat_divergence" branch), this would return "original"
# instead of "divergence" and the assertion fails.
static func _t_selects_divergence_template() -> Dictionary:
	var kind := BarkPopupLayer.resolve_template_kind("combat_divergence", false)
	if kind != "divergence":
		return { "ok": false, "error": "Expected combat_divergence context to resolve to the divergence template, got '%s'" % kind }
	return { "ok": true }


# Test 1b — FALSIFIABLE: if the divergence branch were made unconditional (e.g.
# checking `not is_response` instead of `bark_context == "combat_divergence"`),
# an ordinary non-response bark would incorrectly resolve to "divergence" and
# this test would fail.
static func _t_selects_original_template() -> Dictionary:
	var kind := BarkPopupLayer.resolve_template_kind("combat_attack", false)
	if kind != "original":
		return { "ok": false, "error": "Expected plain bark context to resolve to the original template, got '%s'" % kind }
	return { "ok": true }


# Test 1c — FALSIFIABLE: pins that reaction routing (is_response=true,
# bark_context="combat_rally_ally") still resolves to "reaction" — a
# regression here would mean the three-way choice broke the pre-existing
# reaction path.
static func _t_selects_reaction_template() -> Dictionary:
	var kind := BarkPopupLayer.resolve_template_kind("combat_rally_ally", true)
	if kind != "reaction":
		return { "ok": false, "error": "Expected is_response=true to resolve to the reaction template, got '%s'" % kind }
	return { "ok": true }


# Test 1d — explicit precedence check requested by the design brief: if
# is_response were somehow true on the SAME event as bark_context ==
# "combat_divergence" (never happens today — ActorStateMachine._check_reactive_bark()
# always overwrites _bark_context to "combat_rally_ally" in the same assignment
# that sets _bark_is_response = true, so the two never coexist in practice —
# see resolve_template_kind()'s doc comment in BarkPopupLayer.gd), the
# divergence template must still win. FALSIFIABLE: if the `elif is_response`
# branch were ever reordered ahead of the `if bark_context == "combat_divergence"`
# check, this would resolve to "reaction" instead and the test fails.
static func _t_divergence_precedence_over_response() -> Dictionary:
	var kind := BarkPopupLayer.resolve_template_kind("combat_divergence", true)
	if kind != "divergence":
		return { "ok": false, "error": "Expected combat_divergence to win over is_response=true, got '%s'" % kind }
	return { "ok": true }


# ── scene authoring ─────────────────────────────────────────────────────────

# Test 2 — FALSIFIABLE: _template_for_kind() in BarkPopupLayer.gd maps
# resolve_template_kind()'s three possible return values onto the sibling
# nodes $BarkPopupOriginal / $BarkPopupReaction / $BarkPopupDivergence. If any
# of those three were ever renamed or removed from the .tscn, the
# corresponding @onready var would resolve to null at runtime and
# _show_bark_popup() would silently drop that event (early return). This test
# instantiates the scene (no add_child, no live tree — see BarkPopupLayerTests
# header for why @onready assignment can't be exercised here) and walks the
# node paths directly, so a rename/removal fails this test outright instead of
# surfacing only as a silently-missing popup in play.
static func _t_template_nodes_exist_at_expected_paths() -> Dictionary:
	var layer := BarkPopupLayerScene.instantiate() as BarkPopupLayer
	var missing: Array = []
	for path in ["BarkPopupOriginal", "BarkPopupReaction", "BarkPopupDivergence"]:
		if layer.get_node_or_null(path) == null:
			missing.append(path)
	layer.free()
	if not missing.is_empty():
		return { "ok": false, "error": "BarkPopupLayer.tscn is missing expected template node(s): %s" % str(missing) }
	return { "ok": true }


# Test 3 — FALSIFIABLE: if the BarkPopupDivergence node were deleted from
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

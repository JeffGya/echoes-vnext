extends RefCounted

## Maps a snapshot `pace_state` ("full", "partial", "none") to its text colour.
## The colours live in LivingTreeSystem.tres as the PaceState* Label variations.
## Colours approved by Jeff, 2026-09-25 (docs/stories/pace-reward/decisions.md D-25):
##   dark surface (combat HUD):  full #7EE3C0, partial #F28C28, none #E5533D
##   warm panel (result card):   full #1D6552, partial #7A4B00, none #9E2F28
## Any other value (absent key, "") means a no-pace fight: the caller keeps its normal colour.

const LIVING_TREE_THEME: Theme = preload("res://assets/theme/LivingTreeSystem.tres")
const STATES: Array[String] = ["full", "partial", "none"]


static func has_pace(pace_state: String) -> bool:
	return pace_state in STATES


## on_panel selects the variation for the light result card; false is the dark combat HUD.
static func color(pace_state: String, on_panel: bool) -> Color:
	return LIVING_TREE_THEME.get_color(&"font_color", theme_type(pace_state, on_panel))


static func theme_type(pace_state: String, on_panel: bool) -> StringName:
	return StringName("PaceState%s%s" % [pace_state.capitalize(), "Panel" if on_panel else ""])

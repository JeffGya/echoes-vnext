class_name StopGlyphs
extends RefCounted
## The six stop kinds and their glyph textures. A kind outside the set gives null (no glyph).

const KINDS: Array[String] = ["arrived_at", "capacity_spent", "interrupted", "spotted_ahead", "paused_to_read", "no_route"]


static func texture(kind: String) -> Texture2D:
	return load("res://assets/ui/stage_stop_glyphs/stop_%s.svg" % kind) as Texture2D if KINDS.has(kind) else null

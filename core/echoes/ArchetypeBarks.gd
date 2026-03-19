## ArchetypeBarks.gd
## Deterministic arrival bark lines for each archetype.
## Pure display helper — no state, no RNG, no side effects.
##
## One fixed line per archetype. Same archetype always returns the same line.
## Fallback for unknown archetype: "I'll do my part."
##
## Canon: archetypes_mvp.md §7, GDD §5 (Hero personality tone).
## Integration: FlowRuntime logs bark on summon; AppRoot hero_info command displays it.
class_name ArchetypeBarks

const _BARKS: Dictionary = {
	"loyal":      "I'll hold the line. Say the word.",
	"proud":      "Watch closely—this will be done right.",
	"reflective": "I have questions… but I will walk with you.",
	"valiant":    "For the cause—point me to the breach.",
	"canny":      "We'll take the smart path—fewer wounds, more wins.",
	"devout":     "Asé guides us. I will not falter.",
	"stoic":      "I've stood through worse. Let's move.",
	"empathic":   "I'll keep an eye on the others. We rise together.",
	"ambitious":  "Give me a challenge worth remembering.",
}

const _FALLBACK: String = "I'll do my part."


## Returns the fixed arrival bark for the given archetype.
## hero_name is accepted for future personalisation (currently unused).
static func arrival(arch: String, _hero_name: String = "") -> String:
	return _BARKS.get(arch, _FALLBACK)

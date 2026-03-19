## ShoutBank.gd
## Tiered bark/shout lines for all Echo vocal contexts.
##
## Usage:
##   var tier := ShoutBank.get_tier(courage, wisdom, faith)
##   var line  := ShoutBank.get_shout("arrival", arch, tier)
##
## Tiers reflect how strongly the echo fits their archetype:
##   "strong"   — max trait delta ≥ 15  (extreme, clearly dominant fit)
##   "moderate" — max trait delta ≥  5  (clear but not extreme)
##   "weak"     — max trait delta <  5  (balanced echo; archetype is a hint)
##
## Contexts:
##   "arrival"       — summon reveal bark (3 tiers × 9 archetypes, fully written)
##   "combat_attack" — stub, single line per archetype (expand in future story)
##   "combat_guard"  — stub
##   "combat_refuse" — stub (fear/refusal)
##   "sanctum_idle"  — stub
##
## Fallback for unknown context / archetype / tier: "I'll do my part."
##
## Canon: archetypes_mvp.md §7, GDD §5 (Hero personality tone).
class_name ShoutBank

const STRONG_THRESHOLD: float   = 15.0
const MODERATE_THRESHOLD: float = 5.0

const _FALLBACK: String = "I'll do my part."


## Derive a tier string from raw trait values.
## Mirrors the dominance delta logic in PersonalityArchetype — no RNG.
static func get_tier(courage: int, wisdom: int, faith: int) -> String:
	var c := float(courage)
	var w := float(wisdom)
	var f := float(faith)
	var mean: float = (c + w + f) / 3.0
	var max_delta: float = maxf(c - mean, maxf(w - mean, f - mean))
	if max_delta >= STRONG_THRESHOLD:
		return "strong"
	if max_delta >= MODERATE_THRESHOLD:
		return "moderate"
	return "weak"


## Returns a bark line for the given context, archetype, and tier.
## Fallback chain: requested tier → "moderate" → "weak" → _FALLBACK.
static func get_shout(context: String, arch: String, tier: String) -> String:
	var ctx_block: Variant = _SHOUTS.get(context)
	if not (ctx_block is Dictionary):
		return _FALLBACK
	var arch_block: Variant = (ctx_block as Dictionary).get(arch)
	if not (arch_block is Dictionary):
		return _FALLBACK
	var ab: Dictionary = arch_block as Dictionary
	for t in [tier, "moderate", "weak"]:
		var line: Variant = ab.get(t)
		if line is String and not (line as String).is_empty():
			return line as String
	return _FALLBACK


# ── Shout content ──────────────────────────────────────────────────────────────
# Structure: context → archetype → tier → line
# Stub contexts (combat_*) contain only "moderate" — expand per future story.

const _SHOUTS: Dictionary = {

	# ── Arrival — summoned echo speaks for the first time ──────────────────────
	"arrival": {
		"loyal": {
			"strong":   "I'll hold the line until the last breath. Say the word.",
			"moderate": "I'll hold the line. Say the word.",
			"weak":     "You can count on me. I'll do my part.",
		},
		"proud": {
			"strong":   "Watch closely — history remembers those who do things right.",
			"moderate": "Watch closely—this will be done right.",
			"weak":     "I'll handle it properly. Don't worry.",
		},
		"reflective": {
			"strong":   "So many questions… and yet I find myself walking beside you. Perhaps that's the answer.",
			"moderate": "I have questions… but I will walk with you.",
			"weak":     "I'm still working things out. But I'm here.",
		},
		"valiant": {
			"strong":   "For the cause — point me to the breach. I will not stop until it's done.",
			"moderate": "For the cause—point me to the breach.",
			"weak":     "Tell me where I'm needed. I'll be there.",
		},
		"canny": {
			"strong":   "I've already mapped three paths forward. We'll take the smart one — fewer wounds, more wins.",
			"moderate": "We'll take the smart path—fewer wounds, more wins.",
			"weak":     "Let's not rush this. There's probably a smarter way.",
		},
		"devout": {
			"strong":   "Asé flows through everything here. The ancestors walk with us — I will not falter.",
			"moderate": "Asé guides us. I will not falter.",
			"weak":     "I trust the path. It will become clear.",
		},
		"stoic": {
			"strong":   "I've stood through fire, flood, and silence. Whatever this is — it won't break me. Let's move.",
			"moderate": "I've stood through worse. Let's move.",
			"weak":     "It's fine. I'll manage.",
		},
		"empathic": {
			"strong":   "I feel every one of them — every fear, every hope. I won't let a single one fall. We rise together.",
			"moderate": "I'll keep an eye on the others. We rise together.",
			"weak":     "I'll watch out for people. That's what matters.",
		},
		"ambitious": {
			"strong":   "Give me a challenge worth remembering — something that will echo through time.",
			"moderate": "Give me a challenge worth remembering.",
			"weak":     "Let's see what this turns into. I'm curious.",
		},
	},

	# ── Combat attack — stub, expand in future combat-bark story ───────────────
	"combat_attack": {
		"loyal":      { "moderate": "Hold nothing back!" },
		"proud":      { "moderate": "This ends now." },
		"reflective": { "moderate": "It must be done." },
		"valiant":    { "moderate": "Forward!" },
		"canny":      { "moderate": "Calculated." },
		"devout":     { "moderate": "Asé protect me." },
		"stoic":      { "moderate": "…" },
		"empathic":   { "moderate": "For the others!" },
		"ambitious":  { "moderate": "Watch this." },
	},

	# ── Combat guard — stub ────────────────────────────────────────────────────
	"combat_guard": {
		"loyal":      { "moderate": "I won't let you through." },
		"proud":      { "moderate": "You'll have to earn that." },
		"reflective": { "moderate": "Patience." },
		"valiant":    { "moderate": "Come at me." },
		"canny":      { "moderate": "Not so fast." },
		"devout":     { "moderate": "The way is closed." },
		"stoic":      { "moderate": "Steady." },
		"empathic":   { "moderate": "Stay behind me." },
		"ambitious":  { "moderate": "Defend? Fine." },
	},

	# ── Combat refuse — stub (fear / unable to act) ────────────────────────────
	"combat_refuse": {
		"loyal":      { "moderate": "I… I can't move." },
		"proud":      { "moderate": "Something is wrong." },
		"reflective": { "moderate": "I need a moment." },
		"valiant":    { "moderate": "Not now…" },
		"canny":      { "moderate": "I'm frozen." },
		"devout":     { "moderate": "Forgive me." },
		"stoic":      { "moderate": "I'm slipping." },
		"empathic":   { "moderate": "Too much…" },
		"ambitious":  { "moderate": "No. Not yet." },
	},

	# ── Sanctum idle — stub ────────────────────────────────────────────────────
	"sanctum_idle": {
		"loyal":      { "moderate": "Whenever you're ready." },
		"proud":      { "moderate": "Don't keep me waiting long." },
		"reflective": { "moderate": "I find myself thinking…" },
		"valiant":    { "moderate": "Ready when you are." },
		"canny":      { "moderate": "I've been running the numbers." },
		"devout":     { "moderate": "The Sanctum feels alive today." },
		"stoic":      { "moderate": "…" },
		"empathic":   { "moderate": "How are the others holding up?" },
		"ambitious":  { "moderate": "What's the next move?" },
	},
}

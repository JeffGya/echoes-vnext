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


## PROG-010: Returns a bark line for the given context, archetype, and smartness tier.
## Voice lookup priority:
##   1. arch + "_" + calling_origin (most specific — e.g. "stoic_guardian")
##   2. arch (archetype-only)
##   3. _FALLBACK
## Tier fallback chain: smartness_tier → "adept" → "novice" → _FALLBACK
static func get_tier_shout(
	context: String,
	arch: String,
	smartness_tier: String,
	calling_origin: String = ""
) -> String:
	var ctx_block: Variant = _TIER_SHOUTS.get(context)
	if not (ctx_block is Dictionary):
		return _FALLBACK
	var cb: Dictionary = ctx_block as Dictionary

	# Try most-specific voice key first (arch_calling), fall back to arch
	var voice_keys: Array = []
	if not calling_origin.is_empty():
		voice_keys.append(arch + "_" + calling_origin)
	voice_keys.append(arch)

	for vk in voice_keys:
		var arch_block: Variant = cb.get(vk)
		if not (arch_block is Dictionary):
			continue
		var ab: Dictionary = arch_block as Dictionary
		for st in [smartness_tier, "adept", "novice"]:
			var line: Variant = ab.get(st)
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


# ── Tier shout content (PROG-010) ────────────────────────────────────────────
# Structure: context → voice_key (arch or arch_calling) → smartness_tier → line
# voice_key priority: "arch_calling" > "arch" (see get_tier_shout)
# Tier flavors: novice (raw/keeper-aware) → adept (earned confidence) →
#               veteran (directed/named) → elite (authority/command)

const _TIER_SHOUTS: Dictionary = {

	# ── combat_banter — low fear + high morale (universal mood indicator) ─────
	"combat_banter": {
		"loyal": {
			"novice":   "Is it supposed to feel this good?",
			"adept":    "This is what I'm here for.",
			"veteran":  "Right where I need to be.",
			"elite":    "I've waited a long time for a battle worth fighting.",
		},
		"proud": {
			"novice":   "Watch me—I'm doing this right.",
			"adept":    "Again? You never learn.",
			"veteran":  "Exactly as I planned.",
			"elite":    "Perfection takes practice. Observe.",
		},
		"reflective": {
			"novice":   "Wait—did I just do that?",
			"adept":    "There's a strange clarity in a fight like this.",
			"veteran":  "Even here, moments of quiet purpose.",
			"elite":    "Every battle teaches something. Today's lesson: I'm still standing.",
		},
		"valiant": {
			"novice":   "This is AMAZING.",
			"adept":    "THIS is what I train for! Come on!",
			"veteran":  "Forward — always forward!",
			"elite":    "Let them come. Every last one.",
		},
		"canny": {
			"novice":   "Oh. That actually worked.",
			"adept":    "Predictable.",
			"veteran":  "Three moves ahead, as always.",
			"elite":    "Outthought before they drew breath.",
		},
		"devout": {
			"novice":   "The Keeper is watching. I can feel it.",
			"adept":    "Asé is with us today.",
			"veteran":  "The ancestors approve.",
			"elite":    "We fight with the strength of every generation before us.",
		},
		"stoic": {
			"novice":   "Fine.",
			"adept":    "Proceeding as expected.",
			"veteran":  "The battle proceeds as expected.",
			"elite":    "I've fought worse. Much worse.",
		},
		"empathic": {
			"novice":   "Everyone's okay! We're really okay!",
			"adept":    "Together — that's how we do it.",
			"veteran":  "I'm glad to fight beside you. All of you.",
			"elite":    "Every one of you matters. Every single one.",
		},
		"ambitious": {
			"novice":   "This might be my moment.",
			"adept":    "Careful — I might actually enjoy this.",
			"veteran":  "Stories are written in moments like this.",
			"elite":    "History, being made. Right now.",
		},
	},

	# ── combat_inspired — morale inspired + aggressive action ─────────────────
	"combat_inspired": {
		"loyal": {
			"novice":   "For them!",
			"adept":    "Nothing can stop us now.",
			"veteran":  "This is what loyalty looks like.",
			"elite":    "I would burn the world for these people.",
		},
		"valiant": {
			"novice":   "YES!",
			"adept":    "Don't stop — keep pushing!",
			"veteran":  "Victory is in our hands!",
			"elite":    "We are the tide. We are unstoppable.",
		},
		"stoic": {
			"novice":   "…good.",
			"adept":    "Momentum noted.",
			"veteran":  "We have the advantage. Press it.",
			"elite":    "This is what preparation looks like.",
		},
		"empathic": {
			"novice":   "We're doing it!",
			"adept":    "I can feel everyone's spirit rising!",
			"veteran":  "This fire — hold onto it!",
			"elite":    "When we're together like this, nothing can break us.",
		},
		"ambitious": {
			"novice":   "I KNEW it!",
			"adept":    "And THAT'S how it's done.",
			"veteran":  "No hesitation. No mercy.",
			"elite":    "Greatness. Right here, right now.",
		},
	},

	# ── combat_fear_rising — fear just crossed 40 or 60 ──────────────────────
	"combat_fear_rising": {
		"loyal": {
			"novice":   "I… I'm trying.",
			"adept":    "Don't fall apart. Hold together.",
			"veteran":  "Fear is loud today. I hear it.",
			"elite":    "I know this feeling. I've beaten it before.",
		},
		"valiant": {
			"novice":   "Something doesn't feel right.",
			"adept":    "Something's trying to break me. It won't work.",
			"veteran":  "Fear wants me to stop. I won't.",
			"elite":    "Pressure like this only sharpens me.",
		},
		"reflective": {
			"novice":   "Something's… wrong.",
			"adept":    "The fear is speaking. I'm choosing not to listen.",
			"veteran":  "I feel it. I name it. I move past it.",
			"elite":    "Fear is a teacher. I've already learned this lesson.",
		},
		"stoic": {
			"novice":   "Focus. Stay focused.",
			"adept":    "Fear is data. Adjust and continue.",
			"veteran":  "Managing.",
			"elite":    "This changes nothing.",
		},
		"empathic": {
			"novice":   "I can feel the dread. Is everyone else—",
			"adept":    "I can feel the dread. Stay close — we face it together.",
			"veteran":  "The fear is rising in all of us. I feel it. We hold.",
			"elite":    "I carry your fear with me. We carry it together.",
		},
		"proud": {
			"novice":   "This… this is just pressure. Nothing more.",
			"adept":    "This is just pressure. Nothing more.",
			"veteran":  "I have stood through worse without flinching.",
			"elite":    "Fear does not suit me.",
		},
		"devout": {
			"novice":   "Keeper, don't abandon me now.",
			"adept":    "I trust the path. Even through this.",
			"veteran":  "The ancestors walked through worse. So will I.",
			"elite":    "Asé holds. Even now.",
		},
	},

	# ── combat_fear_extreme — fear crossed 80 (near refuse) ──────────────────
	"combat_fear_extreme": {
		"loyal": {
			"novice":   "I can't— I can't move.",
			"adept":    "For them. I have to do this for them.",
			"veteran":  "Hold. Just… hold.",
			"elite":    "I've been here before. I came back.",
		},
		"valiant": {
			"novice":   "Not now…",
			"adept":    "Fear wins this round. But not the war.",
			"veteran":  "Every wall has a door.",
			"elite":    "I will not break. Not here.",
		},
		"stoic": {
			"novice":   "…can't.",
			"adept":    "Impaired. Compensating.",
			"veteran":  "Functional. Barely.",
			"elite":    "Still here.",
		},
		"empathic": {
			"novice":   "Too much… too much…",
			"adept":    "I'm drowning in it. Someone… anyone.",
			"veteran":  "I feel all of it. Every wound. Every fear. Carrying it.",
			"elite":    "The weight of it all… but I carry it so they don't have to.",
		},
		"devout": {
			"novice":   "Keeper… please.",
			"adept":    "Asé… give me strength.",
			"veteran":  "I hear the ancestors. Not yet.",
			"elite":    "Even in the darkest fire, the path remains.",
		},
	},

	# ── combat_morale_falling — morale dropped a tier ─────────────────────────
	"combat_morale_falling": {
		"loyal": {
			"novice":   "I didn't think it would hurt like this.",
			"adept":    "We can still do this. Stay with me.",
			"veteran":  "Morale is slipping. I see it. I won't let it spread.",
			"elite":    "I've rallied from worse. We all have.",
		},
		"empathic": {
			"novice":   "I'm starting to feel us losing…",
			"adept":    "I'm starting to doubt us…",
			"veteran":  "The despair in the air is real. I feel it for each of you.",
			"elite":    "I carry their doubts so they don't have to.",
		},
		"stoic": {
			"novice":   "…not great.",
			"adept":    "Keep it together.",
			"veteran":  "Recalibrating.",
			"elite":    "Setback noted. Continuing.",
		},
		"proud": {
			"novice":   "This isn't how it's supposed to go.",
			"adept":    "This is NOT how I planned this.",
			"veteran":  "Unacceptable. We adjust.",
			"elite":    "Temporary. Only temporary.",
		},
		"reflective": {
			"novice":   "I thought we were doing better.",
			"adept":    "Something is slipping through my fingers.",
			"veteran":  "The tide is turning. I see it clearly.",
			"elite":    "Every fall teaches something. What does this one say?",
		},
	},

	# ── combat_resilient — resilience trait suppressed a fear/morale delta ────
	"combat_resilient": {
		"loyal": {
			"novice":   "I almost— but I didn't.",
			"adept":    "I won't break — not today.",
			"veteran":  "I thought I'd break. But for them — I held.",
			"elite":    "Unshakeable. That's what I am now.",
		},
		"valiant": {
			"novice":   "Ha. Is that all?",
			"adept":    "Fear tried. It lost.",
			"veteran":  "Come on, then. I won't fall.",
			"elite":    "Break me? You'll need something stronger than that.",
		},
		"stoic": {
			"novice":   "…still standing.",
			"adept":    "Absorbed.",
			"veteran":  "Expected. Managed.",
			"elite":    "Resilience is not a feeling. It's a decision.",
		},
		"devout": {
			"novice":   "Something is holding me up.",
			"adept":    "Asé holds me even when I'm shaking.",
			"veteran":  "The ancestors lend their strength.",
			"elite":    "Something greater than me holds steady here.",
		},
		"reflective": {
			"novice":   "I don't know how, but I'm still here.",
			"adept":    "The fear passed through me and left me standing.",
			"veteran":  "I've made peace with what I fear. That's why it can't stop me.",
			"elite":    "Resilience is earned through every wound taken.",
		},
	},

	# ── combat_last_stand — last echo standing ────────────────────────────────
	"combat_last_stand": {
		"loyal": {
			"novice":   "Just me, Keeper. I'll hold.",
			"adept":    "Alone now. But I won't stop.",
			"veteran":  "All of you are gone. I carry it from here.",
			"elite":    "This ends with me standing.",
		},
		"valiant": {
			"novice":   "Okay. Just me. Let's go.",
			"adept":    "One left. That's enough.",
			"veteran":  "Final stand. I choose it.",
			"elite":    "All of you, come then. ALL of you.",
		},
		"stoic": {
			"novice":   "…just me.",
			"adept":    "One remains.",
			"veteran":  "Last one. Holding.",
			"elite":    "This is fine.",
		},
		"devout": {
			"novice":   "Keeper… I'm still here.",
			"adept":    "Asé, guide my hands now.",
			"veteran":  "The ancestors walk with me. I am not alone.",
			"elite":    "The weight of all of them is on me now. I accept it.",
		},
		"reflective": {
			"novice":   "I didn't expect… this.",
			"adept":    "Last standing. What does that mean?",
			"veteran":  "Alone, but not without purpose.",
			"elite":    "Every story must have someone who remains. Today that's me.",
		},
		"empathic": {
			"novice":   "They're all… I have to.",
			"adept":    "I feel them all. Every one. I'll fight for every one.",
			"veteran":  "They fell so I wouldn't. I won't waste that.",
			"elite":    "Their sacrifice is my strength now.",
		},
		"ambitious": {
			"novice":   "This is my moment. This HAS to be my moment.",
			"adept":    "One person can turn this. That person is me.",
			"veteran":  "History doesn't remember the ones who survived. It remembers the ones who refused to fall.",
			"elite":    "I was made for exactly this.",
		},
	},

	# ── combat_taunt — Blade Veteran+, actor.taunt action ────────────────────
	"combat_taunt": {
		"loyal": {
			"veteran":  "Come at me. Leave the others alone.",
			"elite":    "You want a fight? Here I am. HERE I AM.",
		},
		"valiant": {
			"veteran":  "HERE! Fight ME!",
			"elite":    "Come on then — all of you. I'm the one you want.",
		},
		"proud": {
			"veteran":  "Ignore the others. I'm the real threat.",
			"elite":    "Your mistake is not focusing on me.",
		},
		"stoic": {
			"veteran":  "…over here.",
			"elite":    "Focus.",
		},
		"ambitious": {
			"veteran":  "You're wasting your time on them.",
			"elite":    "You want to win? You have to go through me.",
		},
	},

	# ── combat_rally_ally — Veteran+, directed at struggling ally ────────────
	"combat_rally_ally": {
		"loyal": {
			"veteran":  "Hold, friend! I'm coming!",
			"elite":    "You're not alone in this — I've got you.",
		},
		"empathic": {
			"veteran":  "I see you struggling. Hold on!",
			"elite":    "I feel your fear. Hold it together — we do this together.",
		},
		"proud": {
			"veteran":  "Pull yourself together.",
			"elite":    "We don't fall here. That is not an option.",
		},
		"valiant": {
			"veteran":  "Stay with us! We're not done yet!",
			"elite":    "Get up. Now. We end this.",
		},
		"stoic": {
			"veteran":  "Hold.",
			"elite":    "Regroup. Now.",
		},
	},

	# ── combat_address_keeper — Novice+, keeper-aware moment ─────────────────
	"combat_address_keeper": {
		"loyal": {
			"novice":   "Keeper — are you watching? I won't let you down.",
			"adept":    "You've trusted me with this. I won't waste it.",
			"veteran":  "Keeper — this one's for you.",
			"elite":    "The bond between us keeps me standing.",
		},
		"devout": {
			"novice":   "Keeper… Keeper, guide me.",
			"adept":    "Your vision, my hands. Asé willing.",
			"veteran":  "The Keeper's light hasn't left me yet.",
			"elite":    "I was chosen. I remember that now.",
		},
		"reflective": {
			"novice":   "Do you see this, Keeper? Do you understand what this costs?",
			"adept":    "I wonder sometimes if you feel what we feel.",
			"veteran":  "The gap between keeper and kept… it closes in moments like this.",
			"elite":    "We are bound, Keeper. Through everything.",
		},
	},

}

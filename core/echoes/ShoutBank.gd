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


## V2-PROG-006: Returns a bark line for the given context, archetype, and expression band.
## Voice lookup priority:
##   1. arch + "_" + calling_origin (most specific — e.g. "stoic_guardian")
##   2. arch (archetype-only)
##   3. _FALLBACK
## Band fallback chain: expression_band → "forming" → "nascent" → _FALLBACK
static func get_expression_shout(
	context: String,
	arch: String,
	expression_band: String,
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
		for st in [expression_band, "forming", "nascent"]:
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


# ── Expression shout content (V2-PROG-006) ───────────────────────────────────
# Structure: context → voice_key (arch or arch_calling) → expression_band → line
# voice_key priority: "arch_calling" > "arch" (see get_expression_shout)
# Band flavors: nascent (raw/keeper-aware) → forming (earned confidence) →
#               grounded (directed/named) → whole (authority/command)

const _TIER_SHOUTS: Dictionary = {

	# ── combat_banter — low fear + high morale (universal mood indicator) ─────
	"combat_banter": {
		"loyal": {
			"nascent":   "Is it supposed to feel this good?",
			"forming":    "This is what I'm here for.",
			"grounded":  "Right where I need to be.",
			"whole":    "I've waited a long time for a battle worth fighting.",
		},
		"proud": {
			"nascent":   "Watch me—I'm doing this right.",
			"forming":    "Again? You never learn.",
			"grounded":  "Exactly as I planned.",
			"whole":    "Perfection takes practice. Observe.",
		},
		"reflective": {
			"nascent":   "Wait—did I just do that?",
			"forming":    "There's a strange clarity in a fight like this.",
			"grounded":  "Even here, moments of quiet purpose.",
			"whole":    "Every battle teaches something. Today's lesson: I'm still standing.",
		},
		"valiant": {
			"nascent":   "This is AMAZING.",
			"forming":    "THIS is what I train for! Come on!",
			"grounded":  "Forward — always forward!",
			"whole":    "Let them come. Every last one.",
		},
		"canny": {
			"nascent":   "Oh. That actually worked.",
			"forming":    "Predictable.",
			"grounded":  "Three moves ahead, as always.",
			"whole":    "Outthought before they drew breath.",
		},
		"devout": {
			"nascent":   "The Keeper is watching. I can feel it.",
			"forming":    "Asé is with us today.",
			"grounded":  "The ancestors approve.",
			"whole":    "We fight with the strength of every generation before us.",
		},
		"stoic": {
			"nascent":   "Fine.",
			"forming":    "Proceeding as expected.",
			"grounded":  "The battle proceeds as expected.",
			"whole":    "I've fought worse. Much worse.",
		},
		"empathic": {
			"nascent":   "Everyone's okay! We're really okay!",
			"forming":    "Together — that's how we do it.",
			"grounded":  "I'm glad to fight beside you. All of you.",
			"whole":    "Every one of you matters. Every single one.",
		},
		"ambitious": {
			"nascent":   "This might be my moment.",
			"forming":    "Careful — I might actually enjoy this.",
			"grounded":  "Stories are written in moments like this.",
			"whole":    "History, being made. Right now.",
		},
	},

	# ── combat_inspired — morale inspired + aggressive action ─────────────────
	"combat_inspired": {
		"loyal": {
			"nascent":   "For them!",
			"forming":    "Nothing can stop us now.",
			"grounded":  "This is what loyalty looks like.",
			"whole":    "I would burn the world for these people.",
		},
		"valiant": {
			"nascent":   "YES!",
			"forming":    "Don't stop — keep pushing!",
			"grounded":  "Victory is in our hands!",
			"whole":    "We are the tide. We are unstoppable.",
		},
		"stoic": {
			"nascent":   "…good.",
			"forming":    "Momentum noted.",
			"grounded":  "We have the advantage. Press it.",
			"whole":    "This is what preparation looks like.",
		},
		"empathic": {
			"nascent":   "We're doing it!",
			"forming":    "I can feel everyone's spirit rising!",
			"grounded":  "This fire — hold onto it!",
			"whole":    "When we're together like this, nothing can break us.",
		},
		"ambitious": {
			"nascent":   "I KNEW it!",
			"forming":    "And THAT'S how it's done.",
			"grounded":  "No hesitation. No mercy.",
			"whole":    "Greatness. Right here, right now.",
		},
	},

	# ── combat_fear_rising — fear just crossed 40 or 60 ──────────────────────
	"combat_fear_rising": {
		"loyal": {
			"nascent":   "I… I'm trying.",
			"forming":    "Don't fall apart. Hold together.",
			"grounded":  "Fear is loud today. I hear it.",
			"whole":    "I know this feeling. I've beaten it before.",
		},
		"valiant": {
			"nascent":   "Something doesn't feel right.",
			"forming":    "Something's trying to break me. It won't work.",
			"grounded":  "Fear wants me to stop. I won't.",
			"whole":    "Pressure like this only sharpens me.",
		},
		"reflective": {
			"nascent":   "Something's… wrong.",
			"forming":    "The fear is speaking. I'm choosing not to listen.",
			"grounded":  "I feel it. I name it. I move past it.",
			"whole":    "Fear is a teacher. I've already learned this lesson.",
		},
		"stoic": {
			"nascent":   "Focus. Stay focused.",
			"forming":    "Fear is data. Adjust and continue.",
			"grounded":  "Managing.",
			"whole":    "This changes nothing.",
		},
		"empathic": {
			"nascent":   "I can feel the dread. Is everyone else—",
			"forming":    "I can feel the dread. Stay close — we face it together.",
			"grounded":  "The fear is rising in all of us. I feel it. We hold.",
			"whole":    "I carry your fear with me. We carry it together.",
		},
		"proud": {
			"nascent":   "This… this is just pressure. Nothing more.",
			"forming":    "This is just pressure. Nothing more.",
			"grounded":  "I have stood through worse without flinching.",
			"whole":    "Fear does not suit me.",
		},
		"devout": {
			"nascent":   "Keeper, don't abandon me now.",
			"forming":    "I trust the path. Even through this.",
			"grounded":  "The ancestors walked through worse. So will I.",
			"whole":    "Asé holds. Even now.",
		},
	},

	# ── combat_fear_extreme — fear crossed 80 (near refuse) ──────────────────
	"combat_fear_extreme": {
		"loyal": {
			"nascent":   "I can't— I can't move.",
			"forming":    "For them. I have to do this for them.",
			"grounded":  "Hold. Just… hold.",
			"whole":    "I've been here before. I came back.",
		},
		"valiant": {
			"nascent":   "Not now…",
			"forming":    "Fear wins this round. But not the war.",
			"grounded":  "Every wall has a door.",
			"whole":    "I will not break. Not here.",
		},
		"stoic": {
			"nascent":   "…can't.",
			"forming":    "Impaired. Compensating.",
			"grounded":  "Functional. Barely.",
			"whole":    "Still here.",
		},
		"empathic": {
			"nascent":   "Too much… too much…",
			"forming":    "I'm drowning in it. Someone… anyone.",
			"grounded":  "I feel all of it. Every wound. Every fear. Carrying it.",
			"whole":    "The weight of it all… but I carry it so they don't have to.",
		},
		"devout": {
			"nascent":   "Keeper… please.",
			"forming":    "Asé… give me strength.",
			"grounded":  "I hear the ancestors. Not yet.",
			"whole":    "Even in the darkest fire, the path remains.",
		},
	},

	# ── combat_morale_falling — morale dropped a tier ─────────────────────────
	"combat_morale_falling": {
		"loyal": {
			"nascent":   "I didn't think it would hurt like this.",
			"forming":    "We can still do this. Stay with me.",
			"grounded":  "Morale is slipping. I see it. I won't let it spread.",
			"whole":    "I've rallied from worse. We all have.",
		},
		"empathic": {
			"nascent":   "I'm starting to feel us losing…",
			"forming":    "I'm starting to doubt us…",
			"grounded":  "The despair in the air is real. I feel it for each of you.",
			"whole":    "I carry their doubts so they don't have to.",
		},
		"stoic": {
			"nascent":   "…not great.",
			"forming":    "Keep it together.",
			"grounded":  "Recalibrating.",
			"whole":    "Setback noted. Continuing.",
		},
		"proud": {
			"nascent":   "This isn't how it's supposed to go.",
			"forming":    "This is NOT how I planned this.",
			"grounded":  "Unacceptable. We adjust.",
			"whole":    "Temporary. Only temporary.",
		},
		"reflective": {
			"nascent":   "I thought we were doing better.",
			"forming":    "Something is slipping through my fingers.",
			"grounded":  "The tide is turning. I see it clearly.",
			"whole":    "Every fall teaches something. What does this one say?",
		},
	},

	# ── combat_resilient — resilience trait suppressed a fear/morale delta ────
	"combat_resilient": {
		"loyal": {
			"nascent":   "I almost— but I didn't.",
			"forming":    "I won't break — not today.",
			"grounded":  "I thought I'd break. But for them — I held.",
			"whole":    "Unshakeable. That's what I am now.",
		},
		"valiant": {
			"nascent":   "Ha. Is that all?",
			"forming":    "Fear tried. It lost.",
			"grounded":  "Come on, then. I won't fall.",
			"whole":    "Break me? You'll need something stronger than that.",
		},
		"stoic": {
			"nascent":   "…still standing.",
			"forming":    "Absorbed.",
			"grounded":  "Expected. Managed.",
			"whole":    "Resilience is not a feeling. It's a decision.",
		},
		"devout": {
			"nascent":   "Something is holding me up.",
			"forming":    "Asé holds me even when I'm shaking.",
			"grounded":  "The ancestors lend their strength.",
			"whole":    "Something greater than me holds steady here.",
		},
		"reflective": {
			"nascent":   "I don't know how, but I'm still here.",
			"forming":    "The fear passed through me and left me standing.",
			"grounded":  "I've made peace with what I fear. That's why it can't stop me.",
			"whole":    "Resilience is earned through every wound taken.",
		},
	},

	# ── combat_last_stand — last echo standing ────────────────────────────────
	"combat_last_stand": {
		"loyal": {
			"nascent":   "Just me, Keeper. I'll hold.",
			"forming":    "Alone now. But I won't stop.",
			"grounded":  "All of you are gone. I carry it from here.",
			"whole":    "This ends with me standing.",
		},
		"valiant": {
			"nascent":   "Okay. Just me. Let's go.",
			"forming":    "One left. That's enough.",
			"grounded":  "Final stand. I choose it.",
			"whole":    "All of you, come then. ALL of you.",
		},
		"stoic": {
			"nascent":   "…just me.",
			"forming":    "One remains.",
			"grounded":  "Last one. Holding.",
			"whole":    "This is fine.",
		},
		"devout": {
			"nascent":   "Keeper… I'm still here.",
			"forming":    "Asé, guide my hands now.",
			"grounded":  "The ancestors walk with me. I am not alone.",
			"whole":    "The weight of all of them is on me now. I accept it.",
		},
		"reflective": {
			"nascent":   "I didn't expect… this.",
			"forming":    "Last standing. What does that mean?",
			"grounded":  "Alone, but not without purpose.",
			"whole":    "Every story must have someone who remains. Today that's me.",
		},
		"empathic": {
			"nascent":   "They're all… I have to.",
			"forming":    "I feel them all. Every one. I'll fight for every one.",
			"grounded":  "They fell so I wouldn't. I won't waste that.",
			"whole":    "Their sacrifice is my strength now.",
		},
		"ambitious": {
			"nascent":   "This is my moment. This HAS to be my moment.",
			"forming":    "One person can turn this. That person is me.",
			"grounded":  "History doesn't remember the ones who survived. It remembers the ones who refused to fall.",
			"whole":    "I was made for exactly this.",
		},
	},

	# ── combat_taunt — Blade Veteran+, actor.taunt action ────────────────────
	"combat_taunt": {
		"loyal": {
			"grounded":  "Come at me. Leave the others alone.",
			"whole":    "You want a fight? Here I am. HERE I AM.",
		},
		"valiant": {
			"grounded":  "HERE! Fight ME!",
			"whole":    "Come on then — all of you. I'm the one you want.",
		},
		"proud": {
			"grounded":  "Ignore the others. I'm the real threat.",
			"whole":    "Your mistake is not focusing on me.",
		},
		"stoic": {
			"grounded":  "…over here.",
			"whole":    "Focus.",
		},
		"ambitious": {
			"grounded":  "You're wasting your time on them.",
			"whole":    "You want to win? You have to go through me.",
		},
	},

	# ── combat_rally_ally — Veteran+, directed at struggling ally ────────────
	"combat_rally_ally": {
		"loyal": {
			"grounded":  "Hold, friend! I'm coming!",
			"whole":    "You're not alone in this — I've got you.",
		},
		"empathic": {
			"grounded":  "I see you struggling. Hold on!",
			"whole":    "I feel your fear. Hold it together — we do this together.",
		},
		"proud": {
			"grounded":  "Pull yourself together.",
			"whole":    "We don't fall here. That is not an option.",
		},
		"valiant": {
			"grounded":  "Stay with us! We're not done yet!",
			"whole":    "Get up. Now. We end this.",
		},
		"stoic": {
			"grounded":  "Hold.",
			"whole":    "Regroup. Now.",
		},
	},

	# ── combat_address_keeper — Novice+, keeper-aware moment ─────────────────
	"combat_address_keeper": {
		"loyal": {
			"nascent":   "Keeper — are you watching? I won't let you down.",
			"forming":    "You've trusted me with this. I won't waste it.",
			"grounded":  "Keeper — this one's for you.",
			"whole":    "The bond between us keeps me standing.",
		},
		"devout": {
			"nascent":   "Keeper… Keeper, guide me.",
			"forming":    "Your vision, my hands. Asé willing.",
			"grounded":  "The Keeper's light hasn't left me yet.",
			"whole":    "I was chosen. I remember that now.",
		},
		"reflective": {
			"nascent":   "Do you see this, Keeper? Do you understand what this costs?",
			"forming":    "I wonder sometimes if you feel what we feel.",
			"grounded":  "The gap between keeper and kept… it closes in moments like this.",
			"whole":    "We are bound, Keeper. Through everything.",
		},
	},

}

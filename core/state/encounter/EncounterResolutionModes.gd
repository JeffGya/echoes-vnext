class_name EncounterResolutionModes

# Canonical seven resolution modes — one per encounter objective type.
# This file is constants + doc comments only. No mapping logic lives here.

const COMBAT       := "combat"        # Defeat all enemies to proceed. Not wave-based.
const PURIFY_SHRINE := "purify_shrine" # Protect and purify a hidden shrine through enemy waves; shrine HP must be > 0 and at least one echo alive.
const RECOVER      := "recover"       # Hold a named echo on a relic tile for a required number of rounds.
const PROTECT      := "protect"       # Keep a named entity (NPC, structure, or totem) alive for N rounds of enemy waves.
const ENDURE       := "endure"        # Survive N rounds of enemy waves — kill-all is NOT required; at least one echo alive wins.
const PURSUE       := "pursue"        # Contain a fleeing quarry before its escape window closes.
const GUIDE_SPIRIT := "guide_spirit"  # Escort a spirit NPC from point A to point B while keeping it alive.

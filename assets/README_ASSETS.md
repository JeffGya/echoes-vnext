For long-term sanity, asset folders that:
	•	scale from MVP → full game
	•	keep Sanctum vs Realms/Stages separated
	•	separate source (if you keep it in repo) from runtime (what Godot imports)
	•	make it obvious what is shared vs biome/realm-specific
	•	don’t mix UI with world art

Below is a structure that works well in Godot and won’t collapse later.

⸻

Recommended top-level layout

res://
  assets/                # Runtime art/audio used by the game
  ui/                    # Scenes + scripts (you already have this)
  core/                  # Simulation/core (you already have this)
  data/                  # JSON configs (you already have this)

Inside assets/:

res://assets/
  _shared/               # Cross-context reuse (used everywhere)
  sanctum/               # Sanctum-only visuals
  realms/                # Realm/stage visuals grouped by realm_id
  fx/                    # Global VFX primitives (glows, particles, masks)
  audio/                 # Music/SFX/ambience
  fonts/                 # If you ship fonts as files


⸻

_shared/ (global building blocks)

res://assets/_shared/
  palettes/              # palette images / reference swatches (optional)
  materials/             # shared shader materials
  icons/                 # general icons used across multiple screens
  decals/                # generic overlays (dirt, cracks, stains)
  ui/                    # shared UI textures (if shared across contexts)

Use _shared/ only if it’s truly used in more than one context.

⸻

sanctum/ (your new focus)

res://assets/sanctum/
  tiles/
    floor/               # 128x96 clay tiles, variants
    edges/               # cliffs, borders, ramps later (optional)
    debug/               # grid overlays, test tiles
    tilesets/            # .tres TileSet resources
  buildings/
    landmarks/           # ritual circle, great tree, great hall, king hall
    stalls/              # market stalls, small props
    placeholders/        # greybox / primitives
  props/
    nature/              # rocks, plants, roots
    decor/               # torches, banners, statues
  actors/
    echoes/              # echo visuals (sprites, portraits)
    silhouettes/         # placeholder silhouettes
  backgrounds/
    sky/                 # memory haze, gradient layers
    parallax/            # optional later
  vfx/
    webs/                # anansi web textures
    glows/               # torch glows, aura circles
    particles/           # dust, embers textures

Key rule: keep TileSet resources inside the same branch as their source images. It saves you later.

⸻

realms/ (future-proof now)

You’ll thank yourself later if you align folder names with realm_id.

res://assets/realms/
  _shared/               # shared realm tiles, UI, props used by multiple realms
  asante_forest/         # realm_id
    tiles/
    props/
    enemies/
    backgrounds/
  coastal_ruins/
    ...

This makes it trivial to load by realm_id later and keeps art packs modular.

⸻

fx/ (global VFX primitives)

Even though Sanctum has webs/glow, you’ll reuse some VFX everywhere.

res://assets/fx/
  glows/
  masks/
  particles/
  shaders/

Sanctum-specific VFX still lives in assets/sanctum/vfx/.

⸻

Asset naming conventions (don’t skip this)

Tiles

sanctum_tile_floor_clay_base_128x96.png
sanctum_tile_floor_clay_var01_128x96.png

Buildings

sanctum_bld_landmark_great_hall_v01.png
sanctum_bld_landmark_great_tree_v01.png

VFX

fx_glow_torch_soft_256.png
sanctum_fx_web_strand_01.png

TileSets

sanctum_tileset_floor_128x64.tres

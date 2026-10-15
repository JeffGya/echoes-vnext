# Real stage maps for the stop-marker mockup

Four real stage maps from the game. The artist can draw the HTML mockup from them.

## How the maps were made

- A throw-away runner started the game headless with a fresh save and a full party.
- It chose the realm and stage, then opened the explore state (`flow.stage_explore`).
- It read the terrain from the stage snapshot (`data.terrain`).
- It used `StageTerrain.walkable_set` for walkable cells and `StageTerrain.bridge_tile_cell_set` for bridge cells.
- It chose the directive `directive.scout_carefully`, then sent one `stage.advance_turn`.
- It stored the snapshot values `traveled_path`, `traveled_origin` and `explored_cells`.
- It read hidden situations from the saved explore map. The snapshot does not carry them (true fog).
- Same save seed each run, so the maps repeat. No save data is in the files.

## The four maps

| # | Realm and stage | Grid (cols x rows) | Walkable | Bridge cells | Revealed turn 0 | Revealed after Advance | First Advance |
|---|---|---|---|---|---|---|---|
| 1 | Vale of Dust, stage 0 | 43x35 | 191 | 0 | 20 | 39 | 3 cells, ends [10, 11] |
| 2 | Vale of Dust, stage 1 | 34x41 | 265 | 36 | 14 | 31 | 3 cells, ends [4, 10] |
| 3 | The Ashen Hollow, stage 3 | 59x59 | 444 | 176 | 16 | 28 | 3 cells, ends [19, 8] |
| 4 | The Ashen Hollow, stage 1 | 56x66 | 730 | 297 | 16 | 36 | 3 cells, ends [2, 61] on a structure |

Realm 1 maps are 34 to 43 cells wide. Realm 2 maps are 56 to 59 wide. Real maps are large. The party sees a small part at the start.

## Projection (col,row to screen)

Source: `ui/screens/venture/StageExploreScreen.tscn`, resource `TileSet_explore`.

- Tile shape isometric, layout DIAMOND_RIGHT, cell size 128x64.
- Cell centre x = 64 * (col + row) + 64.
- Cell centre y = 32 * (row - col) + 32.
- Col grows to the upper right. Row grows to the lower right.
- Checked with the engine: (0,0)=(64,32), (1,0)=(128,0), (0,1)=(128,64), (1,1)=(192,32), (10,3)=(896,-192).
- Tile art: `sanctum_tile_floor_clay_base_128x96.png`, 128x96 region, texture origin (0,-16).
- Every cell uses atlas coordinate (0,0). The code never places the other three variants.
- Tile art extends 64 left, 64 right, 64 up and 32 down from the cell centre.
- Bridge cells: same tile on a second layer, tinted (0.87,0.58,0.24,0.55).
- Fog: same tile, tinted black at 65%, on walkable cells that are not revealed.
- Cells outside the walkable list have no tile. They show the background.

## Sketches

Grid view, not iso. Col goes right, row goes down. One character is a 2x2 block of cells. Rows and columns with no cells are cut.

Key: `#` ground, `=` bridge, `o` situation, `O` objective, `S` start.

### Map 1: Vale of Dust stage 0

Compact. Two plateaus and two islands. No bridge. Small, so the party sees a lot early.

```
....#o######
....########
o##########o
######o#####
S#O#########....#
########
....#
```

Start [8, 13]. Objective [[12, 13]]. First Advance path: [[9, 12], [9, 11], [10, 11]] then ends at [10, 11]. Picture: `real-map-1.png`.

### Map 2: Vale of Dust stage 1

One bridge span links the start plateau to the middle plateau, and a long bridge runs to the objective plateau. Best map for the bridge look.

```
.#####
######
.###o#==
S#####o=#####
.......######
.......######
.......#=####
....#...=
....##..=
........=
........=
........=
.....=O==##
.....######
.....####o#
.....######
.....######
```

Start [3, 13]. Objective [[14, 31]]. First Advance path: [[4, 12], [4, 11], [4, 10]] then ends at [4, 10]. Picture: `real-map-2.png`.

### Map 3: The Ashen Hollow stage 3

Irregular. Six plateaus, four islands, long bridges. The objective is far from the start.

```
###
S##=======###
###=======###
..........#=
...........=
...........=
...........=....#o
........##.======##
........###....####
........##....==##
......#######.=.##
......#####=#O=
......#....=###
......======#o#
....#o#======
....###
....=##
....==
....==
....==
....==
....==
....======##
.........##=======o=
.........##=o=======##
.........###......##O#
...............##.####
...............##..###
```

Start [16, 7]. Objective [[56, 54], [42, 27]]. First Advance path: [[17, 8], [18, 8], [19, 8]] then ends at [19, 8]. Picture: `real-map-3.png`.

### Map 4: The Ashen Hollow stage 1

Long and tall. Bridge loop around empty space, many islands. The first Advance ends on a structure and stops there.

```
........#==o=====
.......###.....==
.......###.....==
.......###.....==##
....=====#.....=O##
...#=====#.....==##
..####...#.....==##.##
..####...#......====##
...#.....#......=..###
.........#......=
.........#......=
.........#......=
.........#...====
.........#..###==
.........#..###
.........#..###======
.........#.....=....=
.........#.....=....=
.........#.....=....=
.........#.....=....=
.........#.....=....=
.........#.....=###==##
.........#.....####==##
.........#.....####==##
.........#.....==##====
.........#.....###.====
.........#....####.====
.........#....####.====#
..=======o....####.==###
S#=======#.==========#o#
#o##.....###
####.....###
##
```

Start [0, 58]. Objective [[32, 8]]. First Advance path: [[1, 59], [2, 60], [2, 61]] then ends at [2, 61]. Picture: `real-map-4.png`.

## Pictures

`real-map-1.png` to `real-map-4.png` show the true silhouette. They use the real tile set, atlas pick and bridge tint. Blue dot is the start. Small blue dots are the first Advance path. Grey dots are situations. The gold ring is an objective. No fog and no UI are drawn. The tiles are the game's, but the camera is a fit-to-window zoom of 0.2 to 0.47, so tiles look small.

## Limits

- Situation kinds are model kinds (for example `loot`, `omen`). The player sees only a broad shape and letter after reveal. The mockup needs position and broad kind only.
- All situations are hidden at turn 0 except where `revealed_at_start` is true. After the first Advance, `visible_situations_after_advance` lists what the snapshot shows.
- The Advance path is what the automatic movement chose for this party. It is not a player choice.
- The real board is much larger than a mockup frame. Crop to the party area or draw a zoomed window. The artist may not shrink the map.

## How to reproduce

A throw-away runner is not in the repo. It lives in the session scratchpad. To repeat the work:

1. Boot `FlowRuntime` with a temp save path. Finish onboarding. Toggle the whole roster into the party.
2. Dispatch `flow.select_realm`, `flow.select_stage`, then `flow.go_state` to `flow.stage_explore`.
3. Read `data.terrain`, `data.explored_cells` and `data.party_pos`. Call `StageTerrain.walkable_set` and `StageTerrain.bridge_tile_cell_set`.
4. Dispatch `directive.select` with `directive.scout_carefully`, then `stage.advance_turn`. Read the new snapshot.
5. Run with `godot --headless --path <checkout> --script <runner> -- <out> export realm.01:0 realm.01:1 realm.02:3 realm.02:1`.

The specs used: `realm.01:0`, `realm.01:1`, `realm.02:3`, `realm.02:1`.

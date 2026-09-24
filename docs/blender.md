# Blender field authoring

Tested with Blender 5.2.1 LTS and
[blender-mcp 1.9.4](https://github.com/ahujasid/blender-mcp).
The editable source is [baseball_field.blend](../art/blender/baseball_field.blend).
Open the **Baseball Field** scene, select **Baseball Field**, then edit the
**Field Controls** Geometry Nodes modifier. The Geometry Nodes workspace exposes
`GN_BaseballField_v06`; labeled frames separate each part of the field.
The Layout and Geometry Nodes workspaces open in Material Preview so the field
textures appear while editing.
The same file has a **Buy Screen Preview** scene. Its field is a scaled instance
of the **Field** collection, so field edits appear in both Blender views. Switch
Blender scenes to inspect the match field or the buy-screen arrangement.

In **Buy Screen Preview**, move the named `Podium 1` through `Podium 6`, `Sell
Spot` and `Roster 1` through `Roster 9` empties to place the shop. The podium and
sell meshes follow those empties through `GN_ShopFixtures_v01`. The red roster
rings are preview geometry only; Godot draws and moves its interactive slots.
In Godot, a slot's existing ring turns gold on hover or an allowed drop, with no
separate highlight ring.
`Roster 1` starts on the mound; `Roster 3` and `Roster 5` start centered on first
and third base. The catcher stays behind home, while the other fielders retain
their fielding positions. These buy-screen anchors do not change the match
roster's fielding positions. If you later move a base control, move its roster
empty in the preview too before exporting. Move `Shop Camera` and `Camera Target`
to frame the shop. `Shop Field Preview` owns the field's shop scale and
translation. `Lineup Ground` is hidden in this Blender scene but exported for
the batting-order view. Player sprites, prices, highlights
and drag targets remain Godot nodes because they change during play.

## Controls

- Home, First, Second, Third and Mound: independent positions. Base markers,
  the dirt infield and base paths follow these positions. The dirt extends beyond
  the bases by **Infield Dirt Margin** (2.2 metres by default).
- Base Size: scales the three square bases and the pentagonal home plate.
- Fence Depth: distance from home's Y position to the flat center fence.
- Fence Flat Half Width, Fence Corner Radius and Fence Height: outfield shape.
  The fence has a flat center and curved corners trimmed where the sidelines meet
  them. Geometry Nodes raycasts find the joins against the actual outfield mesh.
- Backstop Height: height of the two panels meeting behind home (3.2 metres).
  Their meeting point comes from intersecting the extended dugout-front lines.
  There is no independent rectangular backstop-depth control.
- Sidelines extend along the dugout fronts to the outfield. Keep the dugout
  rotations parallel to their foul lines, as in the defaults. Moving or resizing
  a dugout updates its fence joins; the dugouts form recesses in the perimeter.
- Dugout Fence Height: guard height above the room rims and stair sides (1.1 metres
  by default). The front opening follows Stair Width and the two side guards
  follow Stair Run. No fence crosses the top of either stair entrance.
- Line Radius and Foul Line Length: line thickness and distance from home.
  Foul lines follow the directions from home through first and third. Their
  lengths are manual; after changing the fence, adjust them to meet it.
- Grass Tile Size, Dirt Tile Size and Chalk Tile Size: metres per image repeat.
  Defaults are 32, 20 and 10 metres for the full 8-by-8 varied images, keeping
  their source detail around 4, 2.5 and 1.25 metres. Smaller values repeat more
  often. These controls generate `UVMap` coordinates on the evaluated meshes,
  so Blender and the exported GLB use the same scale.
  Change UV projection in the `Texture UVs` Geometry Nodes frame; the source
  mesh is empty, so it has no direct UV Editor unwrap until the modifier is applied.
- Batter Dirt Radius: size of the circular dirt area around home plate.
  Batter Box Width, Length and Offset place the two chalk outlines beside the
  pentagonal plate. They follow the Home control.
- Ground Size: dimensions of the grass slab, defaulting to 1,000 by 1,000 metres
  so the overview cannot see its edges.
- Visitors Dugout / Home Team Dugout and rotations: placement of the excavations.
- Dugout Length, Width and Depth: recessed room dimensions, in metres. The default
  room is 13.6 by 3.6 metres, 1.2 metres below the playing surface.
- Dugout Stair Width / Stair Run: width and horizontal run of the six-step entrance.
  Stairs face local +Y (toward the field in the default layout). Retaining walls,
  the front opening and back bench follow these controls. The ground uses mesh
  booleans to cut actual holes for each room and stairwell.

Defaults match the current game's layout. Blender uses meters with Z up:
`(blender_x, blender_y, blender_z) = (sim_x, -sim_y, ball_height) * 0.04`.
Keep gameplay markers on Z = 0. Controls permit non-regulation layouts and do not
validate baseball dimensions. Changing Home moves the fence reference and line
origins; the other bases and dugouts keep their own independent positions.

The hidden **Field Sources (do not export)** collection provides infield topology
and fence/dugout vertex coefficients. Keep it: Geometry Nodes reads these meshes.
The visible field is evaluated by nodes; changing controls needs no Python rebuild.
The unchanged PNG conversions of the original BMPs are
`art/blender/textures/grass.png` and `dirt.png`. The active art sources are
`grass_contrast.png` (stronger light/dark grass detail) and `dirt_clay.png`
(fine reddish infield clay). `tools/blender/varied_textures.py` balances these
for the game's lighting and builds reproducible 2048-pixel `*_varied.png` images
from 8-by-8 rotated and shifted patches, blended across gently warped joins
with subtle broad color variation. `chalk_dirt_varied.png` is a lightened
version of the varied clay for base paths, foul lines and batter's boxes; the
bases and home plate stay solid white. The varied images are packed into Blender
and embedded in the shared field GLB. To change the active source art, replace
its PNG, then run
`blender --background art/blender/baseball_field.blend --python tools/blender/varied_textures.py`
to rebuild the varied images. Run
`blender --background art/blender/baseball_field.blend --python tools/blender/surface_textures.py`
to refresh the packed copies before re-exporting. Both dugouts use neutral grey;
team colors belong to the players. The backstop uses `assets/field/backstop_chainlink.png`,
a repeating grey crosshatch with transparent gaps. `tools/blender/chainlink.py`
creates it if absent and adds metre-scaled UVs to the barrier node group. The
texture is packed into the Blender file and GLB; glTF alpha masking preserves the
open gaps in Godot without changing collision height.

Run `python3 tools/blender/convert_textures.py --from-bmps` to convert replacement
BMPs from `~/Downloads` (requires ImageMagick). Replacing only these archived
conversions does not change the active edited source art.

## MCP setup

The project-local `.codex/config.toml` contains the working configuration on this
machine and stays gitignored. Codex supports
[project MCP configuration](https://developers.openai.com/codex/mcp).
For another machine, install uv and add this block using the absolute path to its
`uvx` executable if the desktop app cannot find it:

```toml
[mcp_servers.blender]
command = "uvx"
args = ["--from", "blender-mcp==1.9.4", "blender-mcp"]
startup_timeout_sec = 60
tool_timeout_sec = 180

[mcp_servers.blender.env]
BLENDER_HOST = "127.0.0.1"
BLENDER_PORT = "9876"
DISABLE_TELEMETRY = "true"
```

Install the matching add-on once:

```sh
uvx --from blender-mcp==1.9.4 blender-mcp install-addon
```

Then start Blender from the project root:

```sh
blender art/blender/baseball_field.blend --python tools/blender/start_mcp.py
```

The startup script enables the installed add-on, disables its telemetry consent,
saves that preference and starts the localhost bridge on port 9876. It preserves
the opened scene. Alternatively, enable **MCP for Blender** in Preferences and
start the server from the Blender MCP sidebar. Its button may say “Connect to
Claude”; it starts the same bridge used by Codex.

Codex launches the MCP process; it does **not** launch Blender. Keep one Blender
instance listening on this port. Restart Codex after adding its server config.
The server is verified with an MCP initialize handshake and calls that inspect,
modify and export the field, not just a socket connectivity check.

## Skills and current API

The local `blender-geometry-nodes` skill was installed from
[arjun988/blender-skills](https://github.com/arjun988/blender-skills/tree/main/.claude/skills/geometry-nodes).
It provides procedural modeling and export guidance and becomes available on the
next Codex turn. It is third-party guidance, not an authoritative API reference.
The field has no scatter, so density and random-seed controls are not applicable.

Blender 5.2 changed the
[modifier input API](https://developer.blender.org/docs/release_notes/5.2/python_api/).
Use the socket identifier from `node_group.interface.items_tree`:

```python
socket = modifier.node_group.interface.items_tree["Fence Depth"]
getattr(modifier.properties.inputs, socket.identifier).value = 42.0
field.update_tag()
bpy.context.view_layer.update()
```

Do not use older `modifier["Socket_..."] = value` examples on this version.

## Export and game integration

Save edits in Blender, then run from the project root:

```sh
blender --background art/blender/baseball_field.blend --python tools/blender/export_field.py
```

This writes `assets/field/baseball_field.glb`, `baseball_field.tres` and
`baseball_field.layout.json`, plus `shop_fixtures.glb`,
`shop_lineup_ground.glb` and `shop_stage.tres`. Both screens import the same
field GLB and layout through `match_ballpark.tscn`. The shop adds its fixture GLB
and places interactive nodes from the exported stage Resource. Restart the game
after exporting. The exporter evaluates the field and shop modifiers into
temporary meshes without applying them to the Blender source. The JSON records
all field controls and the coordinate convention. The `.tres` converts positions,
dimensions and rotations into simulation units. glTF converts the model to Y up
for Godot; the shop stage exports Blender empties as Godot 3D positions. The
default field has 602 evaluated vertices and 340 polygons, including
18 barrier panels. `GN_FieldBarrier_v01` creates the guard panels and marks
their faces with the boolean `field_barrier` attribute. Export reads their actual
evaluated ground endpoints and heights into the layout Resource, so rotated or
resized dugouts do not need hand-maintained collision coordinates. Keep that
attribute when editing the node group; fence materials may be replaced freely.
The trimmed outfield faces carry `field_outfield`. Export orders their ground
edges into a continuous left-to-right boundary for collision and home-run checks,
so the old rectangular side walls do not survive as invisible obstacles.

`art/.gdignore` keeps Blender source files outside Godot's import scan. Generated
files in `assets/field/` are committed together. Do not edit only the mesh or only
the `.tres`: they describe the same bases, fence, dugout openings and stair routes.
Likewise, move shop fixtures and their anchors in Blender and re-export rather
than adjusting copies of their positions in Godot.
The old `art/exports/` staging location is no longer used.

Keep marker Z coordinates and the field object's transform at zero/identity.
The exporter rejects elevated markers, non-identity field transforms and barrier
faces without two ground-level endpoints. Dugout depth is controlled separately.
The playing surface stays flat for baseball rules; downward rays position the
billboards on the recessed floors and treads. Godot's simulation uses explicit
entrance waypoints and planar walls, not a 3D navigation mesh. Exported guards
also create planar player collisions. Balls sweep against finite guard segments
and rebound below their heights; higher balls can clear them. Stair entrances
are actual openings, including for balls. Existing outfield home-run rules remain
in place. These fences do not add out-of-play awards or terrain physics inside
an excavation.

When changing field dimensions, keep dugouts outside the fair diamond and leave
space for their stairs. Foul-line length remains a manual visual control. The
simulation derives the foul directions from home, first and third, independently
of where the drawn lines end. Batting is still aimed generally into the current
field's forward (-Y) direction; rotating the whole diamond is not supported.

## Rebuilding and checking

`tools/blender/fences.py` installs or updates the perimeter while preserving the
rest of the field. It replaces the old rectangular closure and its depth control.
`tools/blender/surface_textures.py` adds tiled UVs, wider dirt and the home-plate
area to a v04 source. It upgrades v05 materials to the varied image tiles and
refreshes their packed images when run again. The saved source uses v06; normal
edits only need modifier changes and export.

`tools/blender/build_field.py` creates a fresh field scene, including the perimeter. It refuses to overwrite
the source unless `-- --overwrite` is supplied. Rebuilding discards saved field
and shop edits; normally edit the modifiers and anchors instead. If building a new
source from scratch, finish the field passes first, then run
`tools/blender/add_shop_stage.py` once to add the shop preview.

```sh
blender --background --python tools/blender/build_field.py -- --overwrite
```

The setup was checked through MCP on Blender 5.2.1: numeric control bounds,
independent marker movement, restoring defaults, finite evaluated geometry,
viewport inspection and GLB export. The dugout update also checks minimum and
maximum depth against floor/stair ray hits. Godot's simulation suite checks both
rooms' treads, players leaving through the entrance, and full games after importing
the field. When changing the node tree, repeat relevant
parameter variations and inspect the evaluated geometry, not just node creation.
The perimeter pass checks minimum/maximum guard dimensions and dugout/stair sizes,
finite geometry and 18 evaluated barrier faces. Godot checks swept rebounds and
height clearances for every panel, forecast agreement, both open stair entrances,
full-game replay, and sphere clearance over grass, dirt and base meshes.

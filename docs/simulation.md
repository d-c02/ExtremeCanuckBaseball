# Baseball simulation

Run `main.tscn` with F6, or the project with F5. The window starts maximized; the
1280x720 viewport scales to fill it, so a bigger window shows the same framing
larger, not more field.

| Key | Action |
| --- | --- |
| Space | Start the game. Pitches and side changes run automatically. |
| P | Pause or resume, including between-play movement. |
| B | Toggle the box score. It opens automatically at the final result. |
| R | Start over with a fresh seed (or the configured fixed seed). Press Space to play. |
| Shift+R | Replay the current seed. |
| H | Inspect both dugouts. |
| D | Show defensive movement targets. |
| C | Show the infield reference guide. |
| V | Toggle automatic broadcast cameras. |
| Q / E | Switch to manual camera and orbit. |
| Right-drag | Orbit and tilt the camera. |
| Mouse wheel | Zoom; framing keeps the bases and live ball visible. |

## Game loop

Each team has nine persistent players. They start in numbered dugout seats; a
label shows the current batting-order position. Players walk onto the field,
the batter heads to home, and the ball returns to the pitcher. The opening walk
runs at normal speed. Pitching starts once everyone is ready, the batter has their
bat, and the pitcher has received the ball. A 1.5-second set/windup precedes each
release, followed by the 0.85-second pitch flight. These are compressed game timings,
not regulation pitch speeds. Misses continue to the catcher before the strike call.

`random_seed = 0` chooses a new seed on startup and R. The HUD shows `active_seed`;
Shift+R replays it. Set `random_seed` to a nonzero value for repeatable development
runs. The seed controls baseball decisions, not the broadcast camera.

Players brake when a play ends and wait through a 2.2-second result beat at normal
speed. Retired players keep an OUT label during this time. Then safe runners stay
on base, out or scored players return to the dugout, and defenders return to
position. The on-deck hitter heads to home after the result beat. After three
outs, the incoming defense heads straight to its field positions while the outgoing
defense returns to its dugout. The next batter and on-deck hitter collect their bats from the dugout before
heading to their spots. A hitter already carrying a bat can go directly to home. The next pitch waits until everyone has
arrived and the ball is back at the mound. Each team's batting order continues.

The `Simulation` node's `innings` defaults to 3. The home team can win on a walk-off or
skip the last bottom half when ahead. Ties continue into extra innings until one
team wins, with empty bases at the start of each half. There is no automatic runner
or inning cap. A non-HR walk-off stops after a valid winning run, with no outstanding forced
advances; a home run lets everyone
complete their circuit.
`transition_speed` defaults to 3 for repositioning after the first pitch and side changes.
Set it to 1 for normal speed throughout. Live plays, windups and return throws
always run at normal speed. The pitcher must receive the return before the next
windup; repositioning can continue afterward.
`between_play_delay` controls the result beat. Transitions use the same 3D view
at the faster simulation speed, with VCR tracking bands, scanlines and a FF indicator.
The tape effect stays off during the opening walkout, windup, live play, return throw, result beat and pause,
and when transition speed is 1. Tune or disable it on `TapeTransition` in `main.tscn`.

## Players and decisions

The `Simulation` node's `visiting_team` and `home_team` are Resources from `data/teams/`.
Each needs nine player Resources, field positions and roles with matching indices.
Roster order is batting order. Edit the `.tres` files in the Inspector.
Startup rejects null player entries and requires exactly one of each field role:
P, C, 1B, 2B, 3B, SS, LF, CF and RF. Invalid rosters show an error before players
spawn; correct the Resources and restart the scene.
Resources hold stats; live objects hold movement and play state.

Each fielder predicts where they can reach the ball during flight or after it
rolls. `anticipation` ranges from 0 to 1 and controls error and read frequency:
0.6 to 0.12 seconds, checked at the defense's 0.15-second interval. Errors shrink
as the player watches. Bounces trigger a new read; nearby loose balls are observed
directly. Prediction includes the wall and its rebounds.

Pursuit uses arrival time and a cost for leaving the player's position. One
fielder intercepts. A catch that looks uncertain can draw one backup, at most
140 units from their station. That player can collect a loose ball nearby.
Other defenders cover bases or hold their stations. `idle_behavior` is Still or
Pace; pacing stays within eight units of the held position and never offsets
an interception or pickup. The sample rosters mix both traits.

Any fielder within reach can catch. A bobble delays that player, so a teammate
can still pick up the ball. With possession, the defense takes an immediate force,
retouch appeal or tag first. It then compares carrying with throwing, including
the windup and receiver's travel time. After an out, it reassesses the remaining
runners. Results report the number of outs made on the play.

## Baseball rules

- Three missed swings strike the batter out. Fouls add strikes up to two, fly
  visibly for 1.5 seconds, then bring the same batter back. Foul catches are absent.
- Fair contact sends the batter toward first. Existing runners use anticipation
  to run, take a short lead on an uncertain fly, or hold for a likely catch.
  With two outs they run on contact. Reaction time delays their first movement.
- A caught fly sends runners back through any passed bases to retouch their
  original base. The defense can throw there for an out before they return.
  Provisional runs from that fly are cancelled. Advances after tagging up are absent.
- On ground balls, contiguous occupied bases force advancement. Other advances
  compare running time with pickup and throw time, including close races. Runners
  reserve destinations so two players cannot settle on the same base.
- Retiring a trailing runner releases forces ahead. An unforced runner touching
  their base is safe from a tag. A third force out, or a batter out before first,
  cancels runs from the play. The scoreboard commits runs when the play resolves.
- Fair airborne fence clearances award a circuit of the bases. Low hits rebound.
  A grand slam scores four. Home runs are rare with the sample power/lift tuning.

Pitches have fixed height and throws aim accurately. The swing is resolved at the
plate using timing and aim errors. Hitting stats narrow those distributions;
misses now use a tighter contact window, so more pitches reach the catcher.
This tuning is not calibrated to an MLB strikeout percentage. There are no balls/walks,
steals, error accounting, player-to-player collisions, shop or upgrades yet.
Decisions and close races resolve at physics-tick precision.

## Scorekeeping

`BaseballMatch.box_score` holds the current game's record, separate from roster
Resources. B opens the box score; it opens automatically at the final result.
The final score remains visible until reset. Records are kept in memory; reset
clears them and closes the panel. B can reopen it before starting a game.
`box_score.to_dict()` returns a deep copy of plain data suitable for
JSON serialization, including a pitch-by-pitch result log. Disk saving is not wired up.

- Team line score: runs by inning, total runs (R), hits (H), and runners left on
  base (LOB). A dash means that half-inning has not been played. LOB accumulates
  runners remaining at the end of each half, including the final walk-off.
- Each batter: plate appearances (PA), at-bats (AB), runs (R), hits (H), doubles
  (2B), triples (3B), home runs (HR), runs batted in (RBI), and strikeouts (K).
- Team pitching: completed pitches (P), batters faced (BF), outs, hits allowed,
  runs allowed and strikeouts. IP displays outs as innings plus remaining outs:
  `2.1` means seven outs, not 2.1 decimal innings. Each team currently has one pitcher.
- Each fielder: putouts (PO) and bobbles. Catchers get strikeout putouts. A bobble
  counts a failed collection attempt, not an official error. Assists and earned
  runs are not adjudicated, so there is no E column or ERA.

Scoring uses play state, never result text or sound signals. Completed plate
appearances count as at-bats under the rules currently supported; a miss or foul
before strike three does not complete a PA. Runs and RBIs commit together after
resolution, so a third force out cannot leave phantom player runs or RBIs behind.
`run_scored` is a provisional presentation cue when a runner crosses home.
A ground double play earns no RBI. Fair fence home runs credit all valid runs and
RBIs, including every runner on a walk-off homer.

Hit classification is a simplified scorer: bases reached credit a hit, unless
the batter was caught on a fly. When the defense chooses another runner, the
batter's hit value is capped at the bases already reached at that decision.
A choice before first therefore records no hit; later advances on that choice
do not inflate a single into a double. A batter tagged stretching a hit keeps
the bases already earned. This approximation does not reconstruct whether an
ordinary-effort play could have retired the batter, or distinguish bases gained
on a bobble. It is not full official scoring.

The rules and terminology were checked against MLB's definitions of
[hits](https://www.mlb.com/glossary/standard-stats/hit),
[RBIs](https://www.mlb.com/glossary/standard-stats/runs-batted-in), and
[fielders' choices](https://img.mlbstatic.com/mlb-images/image/upload/mlb/atcjzj9j7wrgvsm8wnjq.pdf).
The simulation still omits balls/walks, HBP, steals, bunts, advances after tagging
up, sacrifice flies, infield fly, interference, balks, dropped third strikes,
substitutions and official error decisions. It is a shortened baseball auto-battler,
not a complete implementation of the official rulebook. Tick-order determines
races that happen within the same physics step.

## Field and presentation

The field comes from the Blender Geometry Nodes source. See
[Blender setup and export](blender.md). Exporting writes the mesh and a
`BaseballFieldLayout` Resource together into `assets/field/`. The match applies
that layout through `Field` before its child nodes build collision walls and spawn players.

`main.tscn` is a 3D scene. Its hidden `Simulation` child runs the original 2D
movement and ball-height rules. `BaseballWorld.world_position()` maps simulation
`(x, y)` and height to 3D `(x, height, y)`, at 0.04 world units per simulation unit.
Rendering, camera movement and sound do not advance the rules or consume randomness.

`game/field/match_ballpark.tscn` inherits the shared `ballpark.tscn` and adds
dugouts under `Field/Dugouts`. Its exported-layout option applies the Blender
layout before the park initializes. The shop uses the bare park with its authored
markers and a separate procedural preview renderer.

`game/presentation/field_3d.gd` loads the exported GLB and builds StaticBody3D
triangle collision on the Walkable field layer (3D layer 3). The matching layout Resource
sets base/mound positions, foul directions, fence dimensions and dugout geometry.
Fielding stations follow their associated bases; outfield stations scale with
fence width and depth. Team Resources remain unchanged. Edit the Blender controls
and re-export, then restart the game; edits to the old scene markers are overridden.

Dugouts are open excavations, 1.2 metres deep by default, with retaining walls,
a back bench and six steps facing the field. Length, width, depth, entrance width,
stair run, positions and rotations are configurable. Players walk along the room's
center aisle, through the stair opening and onto the field, reversing that route
when returning. Matching 2D collision walls prevent cutting through the room walls.
All nine roster players remain visible; positions are standing placeholders.

Player art is a replaceable `Sprite3D` in `game/presentation/player_3d.tscn`, using
`assets/sprites/player.svg`. Players stay upright and face the camera around the
vertical axis. They use team colors, short labels, a simple movement bob and a
separate persistent box-mesh bat. Each view has a downward RayCast3D that samples the exported
field during physics ticks. Only the view's height changes; the simulation retains
its planar coordinates. Small stair height changes are smoothed, while stationary
players snap to the sampled surface. Pause freezes the height update too. The
player's shadow moves with its feet. Additional StaticBody3D geometry on the
Walkable field layer is picked up by the same rays. The ball is a small sphere with a separate ground shadow; its
vertical position follows the simulation's height. Ground shadows are placeholders.

### Broadcast cameras

The center-field camera covers the set, pitch, catcher's reception and return
throw. After contact it holds for 0.35 seconds before cutting to high home for
ball coverage. Baseline shots require a stable throw/tag assignment for 0.35
seconds and at least two seconds on the current shot. Pitch setup and the cut
from contact to ball coverage can override that minimum. The result shot holds
through the 2.2-second beat, instead of chasing dead-ball activity.

Within a shot, an 8% screen dead zone ignores small movements. Damped tracking
limits pan to 24 degrees/second and lens changes to 12 degrees/second; the lens
can widen faster if action reaches the outer safety margin. Camera movement and
shot timers freeze while paused. The contact hold intentionally prioritizes seeing
the swing over immediately following a fast ball out of frame.

Camera positions are editable `Marker3D` nodes under `BroadcastPositions` in
`main.tscn`. Select `Camera` for contact hold, minimum shot time, pan/zoom rates,
dead zone and manual orbit tuning. `pitch_near_clip` excludes foreground fielders
from the tight center-field shot; retune it if moving that camera. V toggles broadcast mode. Q/E, right-drag or
the wheel switch to the manual orbit camera. H inspects both dugouts. Manual
camera movement remains available while paused. C draws an infield reference
rectangle; D draws defensive movement targets.

References informing this pass:
- [Kansas State camera-operator instructions](https://www.kstatesports.com/documents/download/2022/1/13/Baseball_camera_instructions_docx.pdf): smooth coverage and staying with the player who made the play.
- [A broadcast director's coverage assignments](https://www.tvtechnology.com/news/directing-baseball-covering-americas-pastimeagain): center-field pitcher/batter coverage and high-home ball follow.
- [Cinemachine Rotation Composer](https://docs.unity3d.com/Packages/com.unity.cinemachine@3.1/manual/CinemachineRotationComposer.html): dead zones, damping and hard framing limits. The implementation here uses Godot Camera3D.

### Equipment continuity

Each roster player has a persistent bat, initially at their dugout seat. The
hitter and on-deck player pick theirs up en route. Contact keeps the follow-through
visible, then drops the bat on the field. Two placeholder KIT attendants collect
loose bats after play and carry them back through the dugout stairs. A player who
keeps their bat after a strikeout carries it back to its seat. Changing to defense
also drops any carried bat for collection. These are deterministic equipment
actors, not rigid bodies, and the visual bat does not decide contact outcomes.

The catcher receives missed pitches before strikes/strikeouts are recorded.
Between plays the holder throws the ball back to the pitcher along a visible arc.
An outgoing fielder returns the ball before leaving the field. Loose in-play balls
are collected rather than teleported to a fielder. Fouls and home runs leave their
old ball in the scene; the catcher collects a replacement from a visible supply
behind home, then throws it to the pitcher. The supply contains 128 balls at reset;
exhausting it reports an error rather than silently inventing a new ball.
Ball positions continue advancing after fouls and home runs. Reset deliberately
restores all equipment to its starting positions.

This is 3D presentation with planar player movement, not a rigid-body simulation.
Players still use CharacterBody2D wall collisions and can pass through each other.
The ball uses swept fence crossings and its existing trajectory rules. AI forecasts
sample at 0.05 seconds; actual play uses the physics timestep. Player height
follows the terrain for presentation; ball height and baseball
rules still use the flat playing surface. There is no jumping, gravity-driven
player movement, or general 3D pathfinding. Dugout routes are explicit waypoints.

## Code layout

- `main.tscn`: 3D field, player views, ball, camera, light and sound.
- `game/match.gd` / `game/match.tscn`: hidden planar simulation, rosters, innings and HUD.
- `game/simulation/`: pitch/play rules, runners, defense, ball returns, equipment and box-score records.
- `game/actors/`: player, ball and bat simulation nodes and movement scripts.
- `game/field/`: simulation markers, dugout seats and outfield collision boundary.
- `game/presentation/`: 3D field/player views, camera, box-score panel and sound scene.
- `game/shop/`: buy-screen buyables, drop targets and drag handling. See [buy_screen.md](buy_screen.md).
- `assets/audio/`: placeholder WAVs and editable Bfxr presets.
- `data/`: Resource types and sample teams.
- `assets/field/`: generated field GLB, layout Resource and JSON control snapshot.

`BaseballMatch.step(delta)` advances the simulation. Godot calls it from
`_physics_process`; headless tests call it on physics frames. Players use
CharacterBody2D movement and wall collisions. Live rules use RefCounted objects
with no independent timers. The match exposes play events for presentation.

## Sound

Select the `Sounds` node in the main scene to replace individual clips or adjust
footstep, action, call and flight volumes. It covers dirt/grass footsteps, throws,
hits, catches, outs, strikes, strikeouts, fouls, side changes and home runs. A quiet
loop follows the ball's height in pitch. Footstep playback is capped so a whole
team moving together does not flood the mix. Pause and reset stop playback;
headless runs are silent. Details and regeneration steps are in
[assets/audio/README.md](../assets/audio/README.md).

## Checks

```sh
godot --headless --path . --editor --quit
godot --headless --path . --fixed-fps 60 --script tests/simulation_test.gd
```

The suite runs three complete games, including a same-seed replay. It checks
roster validation, pre-game box-score toggling/reset, roster/inning continuity,
extra innings, box-score totals and base occupancy, then exercises force/tag decisions,
consecutive outs, grand-slam RBIs, cancelled runs, fielder's choices, walk-offs, safe runners, pause/pacing, defensive handoffs and
bobble recovery, wall collisions, a live grand slam, contact starts, caught-fly
retreats, fouls, seed replay, catcher reception, bat availability at windup, contact-shot holds, 3D ball/actor mapping, dugout floor/stair heights, entrance routing and camera framing through different orbit angles. Repeatability assumes the same
resources, engine version and fixed timestep.

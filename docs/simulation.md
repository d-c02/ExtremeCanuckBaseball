# Baseball simulation

Run `main.tscn` with F6 to play the sample teams, or start from the buy screen
with F5 and hand it a team you signed. A match started from the shop takes both
teams from `BaseballSession`, pays $20 into the run when it finishes, takes a life
for a loss, and offers the way back to the shop; opened on its own it uses the
sample teams in `match.tscn` and banks nothing. The 1920x1080 viewport scales to
fill the window, so a bigger window shows the same framing larger, not more field.

| Key | Action |
| --- | --- |
| Space | Start the game. Pitches and side changes run automatically. |
| P | Pause or resume, including between-play movement. |
| B | Toggle the box score. It opens automatically at the final result. |
| R | Start over with a fresh seed (or the configured fixed seed). Press Space to play. |
| Shift+R | Replay the current seed. |
| D | Show defensive movement targets. |
| C | Show the infield reference guide. |

## Game loop

Each team has up to nine persistent players. They start in numbered dugout seats.
Players walk onto the field, the batter heads to home, and the ball returns to
the pitcher. The opening walk runs at normal speed. Pitching starts once everyone
is ready, the batter has their
bat, and the pitcher has received the ball. A 1.5-second set/windup precedes each
release, followed by the 0.85-second pitch flight. These are compressed game timings,
not regulation pitch speeds. One pitch settles a plate appearance. A pitch the hitter
cannot beat continues to the catcher before the strikeout call.

`random_seed = 0` chooses a new seed on startup and R. The HUD shows `active_seed`;
Shift+R replays it. Set `random_seed` to a nonzero value for repeatable development
runs. The seed controls baseball decisions, not the field camera.

Players brake when a play ends and wait through a 2.2-second result beat at normal
speed. Then safe runners stay on base, out or scored players return to the dugout,
and defenders return to position. The on-deck hitter heads to home after the
result beat. After three
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
at the faster simulation speed. VCR tracking bands, scanlines and a FF indicator
mark visible accelerated movement immediately, including equipment attendants.
Only offscreen movement accelerates silently. The effect uses completed fixed
simulation steps and actor movement, rather than predicting remaining travel or
waiting through an entry delay. This also covers a player's final step into
position, when they are no longer marked as moving. Rendering never chooses the
simulation speed. Pause and reset clear the effect.
Normal-speed steps have no tape effect, including the opening walkout, windup,
live play, return throw and result beat. A step that finishes accelerated
preparation retains its indicator for that movement even if it starts the next
phase. Setting transition speed to 1 disables acceleration and the effect. Tune
strength or disable the effect on `TapeTransition` in `main.tscn`.

## Players and decisions

The `Simulation` node's `visiting_team` and `home_team` are Resources from `data/teams/`.
Each has nine roster slots: field positions and roles with matching indices, and
up to nine player Resources. Roster order is batting order. Edit the `.tres` files
in the Inspector. Startup requires exactly one of each field role across the slots:
P, C, 1B, 2B, 3B, SS, LF, CF and RF. Invalid rosters show an error before players
spawn; correct the Resources and restart the scene.

A null or missing player leaves that slot open, so a team can start short-handed.
Open slots spawn nobody, take no turn at bat, and leave their fielding station empty.
When a half-inning starts, including the first, the batting team wins by forfeit
if the fielding team has no pitcher or catcher. A team with no players at all
forfeits when it is due to bat. So a home team without a battery loses before the
first pitch, while visitors without one bat the top of the first and lose when the
home team comes up. A forfeit keeps the score as it stood; `winner()` reports the
winning side. A short lineup skips hitters who are still on base. If every hitter
is on base, the side is retired and those runners are left on base.
Resources hold stats; live objects hold movement, play state and the pitcher's
remaining strength.

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

### Stats

Every player is bought with two stats, `strength` and `dexterity`, each from 0 to
`BaseballPlayerData.MAX_STAT`, which is 99 for now. The rest of the tuning is
derived from the pair, so a roster only authors those two numbers plus
`reaction_time`, `anticipation` and `idle_behavior`.

A player bought in the shop gets those two numbers from their kind
(`BaseballPlayerType`) and keeps whatever their levels have added since:
merging is a buy-phase idea, and the match only ever reads the stats it is
handed. The sample teams in `data/teams/` author the numbers directly and have
no kind at all.

A kind can also reach into the match. A Snowman freezes the whole defence the
moment they put the ball in play: every fielder takes a quarter second per Snowman
level on top of the reaction they would have had, added after the defence has read
the ball, so they lose the jump rather than the read. Pursuit, catching and the
runners all read the hold, so a frozen fielder cannot collect the ball and runners
treat the delay as a reason to go.

A Hockey Player takes that freeze as speed rather than a hold: for as long as it
would have lasted, `BaseballPlayer.speed_multiplier` scales their top speed by 1.5,
2 or 2.5 for levels one to three. Every arrival estimate on the field reads
`current_speed()` rather than the bought stat, so pursuit, cover and throw races all
see the skater coming. Acceleration is untouched, and the boost thaws on its own
whether or not they are moving.

A Driver carries the same sort of multiplier with them all game, 1.5 to 2.5 by
level, and pays for it at the moment of the catch: `catch_chance()` is what their
hands are worth less the share their kind throws away, and the fielding step rolls
against that rather than `catching`. Acceleration is untouched here too, so the
multiplier tells over a long chase and barely shows over a short one.

| Stat | Ability | Derived value |
| --- | --- | --- |
| STR | Batting | `batting_power`, 150 to 460 units per second before contact quality |
| STR | Pitching | the live strength the matchup is decided on |
| STR | Passing | `throwing_speed`, 240 to 480 units per second |
| DEX | Catching | `catching`, the share of reachable balls collected cleanly |
| DEX | Running | `speed`, 90 to 190, and `acceleration`, 260 to 460 |
| DEX | Fielding | the same running, which is the ground a fielder can cover |

Pitching is decided by strength alone. A pitcher carries a live strength that
starts at the value they were bought with in the buy phase. When it is greater
than the hitter's strength the hitter strikes out, and the pitcher loses the
hitter's strength from it. When it no longer beats the hitter, the ball is put in
play and the pitcher refreshes to their bought strength. An arm therefore mows
down weak hitters, tires as it does so, and eventually leaves something hittable.
The margin the hitter wins by drives both halves of the batted ball: it scales
contact quality, which multiplies `batting_power` by 0.65 to 1.6, and it scales
lift by 0.75 to 1.65 while drying up the topped-ball roll from 35% to 2%. A
mismatch therefore drives the ball and gets under it at the same time, so it
carries; a hitter who only just wins the matchup mostly tops it. Measured over
400 swings each: a 99 hitter against a spent arm clears the fence 94% of the
time, a 70 hitter 48%, and a 50 hitter 4%, while any hitter who wins by a single
point never does. Each player keeps their own live strength across half-innings
and games within a match; a reset restores every player's. The HUD shows the
matchup the next pitch turns on, and the arm on the mound counts its own strength
down at its feet.

## Baseball rules

- Strength alone settles the pitch. A pitcher with more strength left than the
  hitter strikes them out; otherwise the hitter puts the ball in play. There is no
  ball-strike count, and fouls, foul catches and called balls are absent.
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
  A grand slam scores four. Home runs come out of the strength gap rather than a
  flat power roll: the sample rosters average under two a game, and a lineup of
  strong hitters against a drained arm hits far more.

Pitches have fixed height and throws aim accurately. The swing is resolved at the
plate from the two strengths alone. Batted balls take a random fair direction,
and their speed and lift scale with the strength margin. Nothing here is
calibrated to MLB rates; the sample rosters put roughly a quarter of plate
appearances in the strikeout column and score about 1.3 runs an inning.
There are no balls/walks, steals, error accounting, player-to-player collisions,
or a shop feeding its bought rosters into a match yet.
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
- Each batter present, in lineup order (open slots have no row): plate
  appearances (PA), at-bats (AB), runs (R), hits (H), doubles
  (2B), triples (3B), home runs (HR), runs batted in (RBI), and strikeouts (K).
- Team pitching: completed pitches (P), batters faced (BF), outs, hits allowed,
  runs allowed and strikeouts. IP displays outs as innings plus remaining outs:
  `2.1` means seven outs, not 2.1 decimal innings. Each team currently has one pitcher.
- Each fielder: putouts (PO) and bobbles. Catchers get strikeout putouts. A bobble
  counts a failed collection attempt, not an official error. Assists and earned
  runs are not adjudicated, so there is no E column or ERA.

Scoring uses play state, never result text or sound signals. One pitch settles a
plate appearance, so every pitch is a completed at-bat under the rules currently
supported. Runs and RBIs commit together after
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
The simulation still omits balls/walks, HBP, steals, bunts, fouls, advances after
tagging up, sacrifice flies, infield fly, interference, balks, ball-strike counts,
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
The exported perimeter tapers to a point behind home. Its sidelines are parallel
to the foul lines, with the neutral-grey dugouts built into those sides. Guards
follow both room rims and stair sides, leaving gaps at the top of the stairs.
The backstop uses a transparent grey crosshatch texture, with the same collision
height. A 1,000-metre grass slab extends beyond the overview so its edges stay hidden.
The curved outfield is trimmed to the sideline joins and its evaluated outline
also supplies collision and home-run boundaries. Collision segments and heights come
from the evaluated Geometry Nodes panels, not separate hand-authored coordinates.
Players collide with the guards; every free ball uses swept segment collisions
below guard height, including return throws and discarded balls. Fielding
forecasts use the same guard tests. High balls can clear a guard, and the stair
openings remain open to balls as well as players. This does not implement
out-of-play awards or make the ball descend into excavations; its rules still
use the flat playing surface. Fair outfield home runs remain supported.

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
vertical axis. They use team colors, a simple movement bob and a separate
persistent box-mesh bat. Their stats stand at their feet as bare
numbers, strength on the left in orange and dexterity on the right in blue,
worded by `BaseballPlayerData.stat_text()` so the match and the buy screen read
the same. The pitcher's left-hand number is their live strength: it counts down
by the hitter's strength on every strikeout and fades toward red as the arm
empties, then snaps back to what they were bought with on contact. The same
player shows their bought strength again once they come up to bat, because
hitting spends nothing. A player inside their dugout hides both numbers, because
nine benched pairs overlap into one another. Nothing else is written over a
player: the stats at their feet are all a match shows.
Each view has a downward RayCast3D that samples the exported field during physics
ticks. Only the view's height changes; the simulation retains
its planar coordinates. Small stair height changes are smoothed, while stationary
players snap to the sampled surface. Pause freezes the height update too. The
player's shadow moves with its feet. Additional StaticBody3D geometry on the
Walkable field layer is picked up by the same rays. The ball is a small sphere with a separate ground shadow. A downward ray samples
the rendered surface for the active ball and discarded balls; the sphere's centre
is clamped to at least that surface plus its mesh radius. This keeps rolling balls
above grass, dirt and bases without changing their simulation trajectory. Airborne
height still follows the simulation. Ground shadows follow the sampled surface
and remain placeholders.

### Field camera

One elevated camera keeps the entire field and both dugouts in view throughout
the game. Its position is authored on `Camera` in `main.tscn`. It fits the field's
bases, exported fence edges and dugout seats on startup, reset and window resize.
`framing_margin` leaves room around the field and under the HUD. The near plane
stays at 0.05 so the foreground playing surface is not clipped.

The camera eases in by up to 6% during windup and pitching, then widens for play.
High or distant balls can widen the view by a further 8%. Exponential smoothing
keeps these changes gradual; pause and the result beat hold the current zoom.
`zoom_amount` and `zoom_speed` tune this on Camera. The close view still fits the
field and dugouts. There are no shot cuts, alternate angles or manual orbit controls. C draws an infield reference
rectangle; D draws defensive movement targets. The VCR effect still marks visible
accelerated movement in this same overview.

### Equipment continuity

Each roster player has a persistent bat, initially at their dugout seat. The
hitter and on-deck player pick theirs up en route. Contact keeps the follow-through
visible, then drops the bat on the field. Two placeholder KIT attendants collect
loose bats after play and carry them back through the dugout stairs. A player who
keeps their bat after a strikeout carries it back to its seat. Changing to defense
also drops any carried bat for collection. These are deterministic equipment
actors, not rigid bodies, and the visual bat does not decide contact outcomes.

The catcher receives the pitch before a strikeout is recorded.
Between plays the holder throws the ball back to the pitcher along a visible arc.
An outgoing fielder returns the ball before leaving the field. Loose in-play balls
are collected rather than teleported to a fielder. A home run leaves its old ball
in the scene; the catcher collects a replacement from a visible supply
behind home, inside the diagonal backstop, then throws it to the pitcher. The supply contains 128 balls at reset;
exhausting it reports an error rather than silently inventing a new ball.
Ball positions continue advancing after home runs. Reset deliberately
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
- `game/shop/`: buy-screen buyables, drop targets, drag handling and the rolls that
  stock it. See [buy_screen.md](buy_screen.md).
- `game/session.gd`: the run — money, lives, the round, and the teams the buy screen
  hands to the next match.
- `game/run_end.gd`: banks a finished match into the run and offers the way back.
- `assets/audio/`: placeholder WAVs and editable Bfxr presets.
- `data/`: Resource types, the kinds of player in `data/types/`, the snacks in
  `data/foods/`, the spawn pools in `data/pools/`, and sample teams.
- `assets/field/`: generated field GLB, layout Resource and JSON control snapshot.

`BaseballMatch.step(delta)` advances the simulation. Godot calls it from
`_physics_process`; headless tests call it on physics frames. Players use
CharacterBody2D movement and wall collisions. Live rules use RefCounted objects
with no independent timers. The match exposes play events and a
`simulation_stepped` signal with the actual number of fixed substeps completed.
Presentation uses that signal to mark accelerated actor movement; it does not
control the simulation. Settling and finished phases share ball possession/flight
handling, while only settling can advance to the next pitch or half.

## Sound

Select the `Sounds` node in the main scene to replace individual clips or adjust
footstep, action, call and flight volumes. It covers dirt/grass footsteps, throws,
hits, catches, outs, strikeouts, side changes and home runs. The strike and foul
clips are unused while a single pitch settles the at-bat. A quiet
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
retreats, the strength matchup that decides a pitch and the drain and refresh of
the pitcher's strength, the extra carry a strength mismatch buys, a Snowman freezing the whole defence for
a quarter second per level at contact while a hitter with no passive leaves them their
usual reaction and the hold thaws as it runs, a Hockey Player taking that freeze as
double speed at level two and losing it when the field thaws, a Driver covering
ground at double speed at level two and dropping balls a plain pair of hands holds, the STR and DEX
labels at a player's feet, the arm on the mound counting its strength down in
view and showing its bought strength again at bat, seed replay, catcher reception, bat availability at windup, 3D ball/actor mapping, dugout floor/stair heights, entrance routing and whole-field camera framing and window resizing. Transition
checks advance actual simulation steps and verify visible acceleration is marked,
including arrivals and equipment attendants, while offscreen movement stays silent.
Separate matches then check forfeits against a missing catcher or pitcher, a pair of
empty teams, and a four-player team with a battery completing a full game.
Repeatability assumes the same
resources, engine version and fixed timestep.

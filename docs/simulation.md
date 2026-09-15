# Baseball simulation

Run `main.tscn` with F6, or the project with F5.

| Key | Action |
| --- | --- |
| Space | Start the game. Pitches and side changes run automatically. |
| P | Pause or resume, including between-play movement. |
| B | Toggle the box score. It opens automatically at the final result. |
| R | Reset the game and random seed. Press Space to restart. |
| H | Inspect both dugouts. |
| D | Show defensive movement targets. |
| C | Show camera guides. |

## Game loop

Each team has nine persistent players. They start in numbered dugout seats; a
label shows the current batting-order position. Players walk onto the field,
the batter heads to home, and the ball returns to the pitcher. The opening walk
runs at normal speed. Pitching starts once everyone is ready.

Players brake when a play ends and wait through a 1.8-second result beat at normal
speed. Retired players keep an OUT label during this time. Then safe runners stay
on base, out or scored players return to the dugout, and defenders return to
position. The on-deck hitter heads to home after the result beat. After three
outs, runners clear the bases and both teams return to their dugouts before
changing sides. Each team's batting order continues.

The root node's `innings` defaults to 3. The home team can win on a walk-off or
skip the last bottom half when ahead. Ties continue into extra innings until one
team wins, with empty bases at the start of each half. There is no automatic runner
or inning cap. A non-HR walk-off stops after a valid winning run, with no outstanding forced
advances; a home run lets everyone
complete their circuit.
`transition_speed` defaults to 3 for repositioning after the first pitch and side changes.
Set it to 1 for normal speed throughout. Live plays always run at normal speed.
`between_play_delay` controls the result beat. `TransitionEffect.strength` controls
the glitch during fast-forward; 0 hides it. The effect does not cover the HUD.

## Players and decisions

The root's `visiting_team` and `home_team` are Resources from `data/teams/`.
Each needs nine player Resources, field positions and roles with matching indices.
Roster order is batting order. Edit the `.tres` files in the Inspector.
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

Pitches have fixed height and throws aim accurately. There are no balls/walks,
steals, error accounting, player-to-player collisions, shop or upgrades yet.
Decisions and close races resolve at physics-tick precision.

## Scorekeeping

`BaseballMatch.box_score` holds the current game's record, separate from roster
Resources. B opens the box score; it opens automatically at the final result.
The final score remains visible until reset. Records are kept in memory; reset
clears them. `box_score.to_dict()` returns a deep copy of plain data suitable for
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

`game/field/outfield.tscn` has a flat center wall, curved corners and side walls.
Its script generates polygon strips and StaticBody2D collision shapes from the
same boundary. `fence_distance` sets center depth; `flat_half_width`, `corner_radius`
and `fence_height` set the rest. Players collide with wall layer 2 and can pass
one another. Pursuit targets leave room for the player's collision radius.
The ball uses swept wall crossings. AI forecasts sample at 0.05 seconds; actual
play uses the physics timestep.

Player and ball art lives under `Visuals` in `game/actors/`. Bases and dugouts
are polygon placeholders in `game/field/`. Move or rotate `Dugouts/Visitors` and
`Dugouts/Home` to move their seats; edit each `OnDeck` marker for the waiting hitter.
Thin polygons mark foul lines.

The field camera keeps the bases visible and follows action outside its dead
zone. An inset shows the active runner farthest from the ball when offscreen.
H bypasses field constraints to inspect the dugouts. In the editor, drag the
markers under `Field/CameraZones`:

- `DeadZone/TopLeft, BottomRight` (cyan): no pan or zoom inside this rectangle.
- `KeepBasesVisible/TopLeft, BottomRight` (yellow): keep this area on screen.
- `BottomLimit` (red): the camera's lower edge. If constraints conflict, keeping
  the yellow rectangle visible takes precedence.

Guides appear in the editor and toggle with C during play. They have no collision.

## Code layout

- `game/match.gd`: rosters, batting order, score, innings, deployment and controls.
- `game/simulation/`: pitch/play rules, runners, defensive assignments, reads and box-score records.
- `game/actors/`: player and ball scenes with their movement scripts.
- `game/field/`: bases, dugouts and the outfield boundary.
- `game/presentation/`: camera, guides, box-score panel, transition shader and sound scene.
- `assets/audio/`: placeholder WAVs and editable Bfxr presets.
- `data/`: Resource types and sample teams.

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
godot --headless --path . --fixed-fps 60 --script tests/simulation_test.gd
```

The suite runs three complete games, including a same-seed replay. It checks
roster/inning continuity, extra innings, box-score totals and base occupancy, then exercises force/tag decisions,
consecutive outs, grand-slam RBIs, cancelled runs, fielder's choices, walk-offs, safe runners, pause/pacing, defensive handoffs and
bobble recovery, wall collisions, a live grand slam, contact starts, caught-fly
retreats, visible fouls and camera constraints. Repeatability assumes the same
resources, engine version and fixed timestep.

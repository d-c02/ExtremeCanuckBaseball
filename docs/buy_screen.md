# Buy screen

Run `game/buy_screen.tscn` with F6. It uses `game/field/ballpark.tscn` and the
procedural `game/presentation/shop_field_3d.gd` preview without dugouts. The match
inherits that park in `match_ballpark.tscn`, adds dugouts and applies the exported
Blender layout. Match rendering uses `field_3d.gd` and the Blender mesh.
The project starts here: F5 opens the buy screen, and Start game hands the team
you signed to `main.tscn` to play.

| Input | Action |
| --- | --- |
| Left-drag | Pick a player up and drop them on a roster slot or the sell spot. |
| Right-click while dragging | Cancel and send the player back where they started. |
| Batting order / Fielding | Toggle between the fielding layout and the lineup. |
| Refresh | Roll a new player onto every podium. |
| Start game | Play the signed team against a rolled opponent. |

Everybody is a kind of player, and a kind sets the stats a level one is bought
with and owns a passive that grows with every level. The only kind written so far
is the Baseball Player, whose passive is +2 strength and +2 dexterity a level.

Three players stand on podiums behind home plate, each podium showing what the
player on it costs. The shop rolls its own stock, one level one of a random kind
per podium, priced off the stats that kind starts with. Refresh rolls a new shelf,
including podiums that have already been sold.
Nine roster slots stand out on the field, each one where that fielder plays: the
shop reads the positions out of its roster Resource, so the
slots sit where the match would put the players. The park and the slots are both
drawn pulled in toward home by the shop's `park_scale`, so the whole field reads at
a glance; the roster itself keeps the real match positions. Every player, on a
podium or in a slot, carries the two stats they are bought on at their feet: the
strength number on the left in orange, the dexterity number on the right in blue.
They read as bare numbers, because the colour and the side already say which is
which. The match stands the same two numbers at a player's feet, worded by
`BaseballPlayerData.stat_texts()` on both screens so they cannot drift apart.
Nothing labels the positions, and no name shows until the cursor is on something:
hover a listing or a slot to read the card: what kind of player they are and what
their passive does, in as few words as it takes. Carrying a player puts every
card away, because the cursor is busy saying where they will land. A gold badge
stands over every player either way, reading
`Lv 2` for their level and `Lv 2½` when one more of their kind is all that stands
between them and the next one.
Dropping a player on an open slot signs them: the shop charges the asking price,
the player stands in the slot, and the podium reads sold. Dropping one on a player
of the same kind merges instead: two of a level is a level up on its own, and a
level below counts half, so two level ones take a level two up to three. Levels
stop at three. A slot holding another kind of player, a player already at the cap,
or a price above the current funds lights up red and refuses the drop.

Start game rolls the other team and goes to the match. The opponent is worth about
what the signed players are: the shop adds up what it sold you, rolls the same
number of level ones, and merges them up one at a time while that leaves the two
teams closer in worth. A pitcher and a catcher are always among them, so a match
always has the two players it cannot do without. `BaseballSession` carries both
teams across the scene change; `main.tscn` opened on its own finds nothing there
and uses the sample teams in `match.tscn` instead.

The button in the top right swaps the two layouts. The lineup view clears the
diamond, the lines and the wall off the grass and stands the nine spots on it in a
three by three grid, first hitter top left and reading across, each one numbered
with where it bats; the fielding view paints the park back in and sends them out
to their positions. Grid rows and columns are an even distance apart on the
ground, so the gap between neighbours looks the same next to the players standing
on them. Slots slide between the two, and a player standing in a slot rides along.

Signed players can be moved around the field for nothing: drag one onto an open
spot and they take it, or onto a spot somebody else holds and the two trade
places. A slot is one place in the batting order as well as one fielding spot, so
a player who moves takes over the order slot they land in. Dragging works the
same in either layout, so trading two players in the lineup view swaps their
fielding spots along with their turns at bat.

A player picked up hangs from the cursor by the head, and trails behind a yanked
mouse: sweep left and they tilt right, sweep right and they tilt left, then they
swing back upright when the cursor settles.

Signed players can be dragged back off the field and onto the sell spot, which
lights up green and shows what the sale pays. Selling empties the slot and adds the
player's sell value, which is set per listing and is lower than the asking price.
Listings on podiums cannot be sold; only signed players can.

## Classes

- `Buyable` (`game/shop/buyable.gd`): an `Area3D` that can be dragged and slid back
  home, names itself while the cursor is on it, stands a player's STR and DEX in its
  `stat_labels` through `show_stats()`, and dangles from its `hang` pivot
  on a spring while carried. Its `swing_body` is turned to face the camera by hand,
  because a billboard would throw the tilt away. It declares `fits()`,
  `apply_to()` and `price()`, so each kind of buyable decides which targets it
  works on, what the drop changes, and what it costs. A negative price pays the
  player instead of charging them, which is how selling works. `restocks` keeps the
  buyable in place after a trade, and `spent_on()` says whether a drop uses the
  buyable up at all, so a move can slide it to its new home instead.
- `BaseballPlayerType` (`data/player_type.gd`): a kind of player. It holds the
  stats a level one starts with, the words its passive is described in, and what
  that passive adds per level. Types are shared, never copied, which is how two
  players are told to be the same kind. `data/types/` holds them.
- `BaseballRecruit` (`game/shop/recruit.gd`): rolls players and whole teams. A
  rolled player is a level one of a random kind; a rolled team is levelled up
  until it is worth about what it will face.
- `BaseballSession` (`game/session.gd`): static holder for the two teams a match
  is about to play. Static rather than an autoload, so a match run on its own
  still compiles and falls back to its own sample teams.
- `ShopPodium` (`game/shop/podium.gd`): the stand a listing is sold from. It shows
  what the player on it costs and reads sold once they are bought, so the price
  stays put while the player is carried off. `stock()` puts a rolled listing on it
  and clears off whatever was there.
- `PlayerSlot` (`game/shop/player_slot.gd`): a buyable player on a podium. It fits
  an empty team slot, where it signs a copy of its `BaseballPlayerData`, and a
  slot holding the same kind, where it merges into them instead. The copy is
  shallow on purpose: the stats are its own, the type is shared. Its feet carry
  `stat_texts()`, and hovering adds the card above them.
- `SignedPlayer` (`game/shop/signed_player.gd`): the player standing in a filled
  slot. It fits the sell spot, where it prices itself at minus `sell_price()` and
  empties its slot; a slot holding the same kind, where it merges and leaves its
  own slot empty; and any other slot, where it moves or swaps for free.
- `BuyTarget` (`game/shop/buy_target.gd`): a place a buyable can be dropped. It holds
  the roster being built, names itself on hover, can narrow what it takes with
  `accepts()`, and can show what a hovering buyable would do with `preview()`.
- `TeamSlot` (`game/shop/team_slot.gd`): one roster spot. Its `slot_index` is the
  batting order and its `role` is the fielding position its place on the field
  already shows. Empty slots take player buyables and stand a `SignedPlayer` in
  the slot, and `swap_with()` trades players with another slot. A filled slot is
  also the target for buyables aimed at a single
  player; a buyable aimed at a whole team subclasses `BuyTarget` instead.
- `SellSpot` (`game/shop/sell_spot.gd`): the target that pays out. The buyable names
  its own sell price, so the spot only shows what the drop would pay.
- `Shop` (`game/shop/shop.gd`): the scene root. It duplicates its `team` Resource so
  trading never edits the file on disk, draws the ballpark, stands each slot at its
  `field_positions` entry scaled in by `park_scale`, hands the roster copy to every
  target it owns, holds the funds, and runs the drag.

Buyables sit on 3D physics layer 1 and targets on layer 2. The shop raycasts each
layer separately, so the held buyable never hides the target under the cursor.
Match terrain uses layer 3, separate from both shop layers.

`data/teams/shop_roster.tres` starts empty of players but carries the nine fielding
positions and roles, so any number of signings leaves a roster `BaseballMatch` would
accept. Open slots stay empty in the match, and a roster without a pitcher or
catcher loses by forfeit. Slots the roster has no position for keep the spot they
were given in the scene.

## Limits

Only one kind of player is written, so every listing is a Baseball Player and any
two of them can merge. That also means two players of the same level can no longer
be swapped: the drop merges them instead. There is no way back: the match has no
button to return to the shop, so a run is one visit and one game. Refresh
is free, and what it rolls pays no attention to what is left in the wallet. The
lineup view shows and rearranges the batting order, but moving a player there
changes their fielding position too, so the two cannot be set apart from each
other. A sold player is gone rather than back on their podium, there is no buyable
other than a player, and there is no way to earn funds.

## Checks

```sh
godot --headless --path . --editor --quit
godot --headless --path . --fixed-fps 60 --script tests/shop_test.gd
```

The suite drags a player onto an open slot and checks the signing, the charge, the
roster entry and the emptied podium; checks that a taken slot and an unaffordable
price refuse the drop; sells a signed player and checks the payout, the emptied slot
and roster entry, and that the sell spot refuses an unsigned listing; checks that
names stay hidden until the cursor is on a listing or a slot while the two numbers
and the level badge stay readable without it, that the card names the kind and its
passive, and that carrying a player puts the cards away while the slot under them
still lights up; merges
and the badge followed, that one level
below only counts half and the second finishes it, and that a player at the cap
refuses another; merges two signed players and checks the slot left behind is
empty and free; refreshes the shelf from the button and checks every podium came
back with a new player priced on their stats; rolls an opponent and checks it
fields as many players for about the same money, with a pitcher and a catcher
among them, and that the session carries the pair; toggles the lineup view and
checks the numbering, the grid rows and columns, the even spacing, the cleared
diamond, that no two spots crowd each other, and the slides back and forth; moves
a signed player to an open spot and swaps two of them, checking the roster and
that neither costs anything; sweeps a carried player left and right and checks
they hang from the cursor and tilt away from the yank before settling upright;
then fills every slot and checks the roster passes
`BaseballTeamData.validation_error()`.

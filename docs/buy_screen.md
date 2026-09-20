# Buy screen

Run `game/buy_screen.tscn` with F6. It uses `game/field/ballpark.tscn` and the
procedural `game/presentation/shop_field_3d.gd` preview without dugouts. The match
inherits that park in `match_ballpark.tscn`, adds dugouts and applies the exported
Blender layout. Match rendering uses `field_3d.gd` and the Blender mesh.
Nothing links the screen to a match yet.

| Input | Action |
| --- | --- |
| Left-drag | Pick a player up and drop them on a roster slot or the sell spot. |
| Right-click while dragging | Cancel and send the player back where they started. |

Three players stand on podiums behind home plate, each podium showing what the
player on it costs. Nine roster slots stand out on the field, each one where that
fielder plays: the shop reads the positions out of its roster Resource, so the
slots sit where the match would put the players. The park and the slots are both
drawn pulled in toward home by the shop's `park_scale`, so the whole field reads at
a glance; the roster itself keeps the real match positions. Nothing labels the
positions, and no name shows until the cursor is on something: hover a listing or a
slot to read who is there. Dropping a player on an open slot signs them: the shop
charges the asking price, the player stands in the slot, and the podium reads sold.
A slot that already has a player, or a price above the current funds, lights up red
and refuses the drop.

Signed players can be moved around the field for nothing: drag one onto an open
spot and they take it, or onto a spot somebody else holds and the two trade
places. A slot is one place in the batting order as well as one fielding spot, so
a player who moves takes over the order slot they land in.

A player picked up hangs from the cursor by the head, and trails behind a yanked
mouse: sweep left and they tilt right, sweep right and they tilt left, then they
swing back upright when the cursor settles.

Signed players can be dragged back off the field and onto the sell spot, which
lights up green and shows what the sale pays. Selling empties the slot and adds the
player's sell value, which is set per listing and is lower than the asking price.
Listings on podiums cannot be sold; only signed players can.

## Classes

- `Buyable` (`game/shop/buyable.gd`): an `Area3D` that can be dragged and slid back
  home, names itself while the cursor is on it, and dangles from its `hang` pivot
  on a spring while carried. Its `swing_body` is turned to face the camera by hand,
  because a billboard would throw the tilt away. It declares `fits()`,
  `apply_to()` and `price()`, so each kind of buyable decides which targets it
  works on, what the drop changes, and what it costs. A negative price pays the
  player instead of charging them, which is how selling works. `restocks` keeps the
  buyable in place after a trade, and `spent_on()` says whether a drop uses the
  buyable up at all, so a move can slide it to its new home instead.
- `ShopPodium` (`game/shop/podium.gd`): the stand a listing is sold from. It shows
  what the player on it costs and reads sold once they are bought, so the price
  stays put while the player is carried off.
- `PlayerSlot` (`game/shop/player_slot.gd`): a buyable player on a podium. It fits
  empty team slots and signs a duplicate of its `BaseballPlayerData`, so later
  changes to a signed player never reach the shop listing. Its `sell_value` travels
  with the signing.
- `SignedPlayer` (`game/shop/signed_player.gd`): the player standing in a filled
  slot. It fits the sell spot, where it prices itself at minus its sell value and
  empties its slot, and any other slot, where it moves or swaps for free.
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
positions and roles, so signing all nine leaves a roster `BaseballMatch` would
accept. Slots the roster has no position for keep the spot they were given in the
scene.

## Limits

Nothing hands a finished roster to a match. Moving a player changes their spot in
the batting order along with their fielding position, and there is no way to
reorder the lineup on its own. A sold player is gone rather than back on their
podium, there is no buyable other than a player, and there is no way to earn
funds.

## Checks

```sh
godot --headless --path . --editor --quit
godot --headless --path . --fixed-fps 60 --script tests/shop_test.gd
```

The suite drags a player onto an open slot and checks the signing, the charge, the
roster entry and the emptied podium; checks that a taken slot and an unaffordable
price refuse the drop; sells a signed player and checks the payout, the emptied slot
and roster entry, and that the sell spot refuses an unsigned listing; checks that
names stay hidden until the cursor is on a listing or a slot; moves a signed
player to an open spot and swaps two of them, checking the roster and that
neither costs anything; sweeps a carried player left and right and checks they
hang from the cursor and tilt away from the yank before settling upright; then
fills every slot and checks the roster passes
`BaseballTeamData.validation_error()`.

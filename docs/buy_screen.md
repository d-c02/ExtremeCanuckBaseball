# Buy screen

Run `game/buy_screen.tscn` with F6. It is a standalone scene: nothing links it to
the match yet.

| Input | Action |
| --- | --- |
| Left-drag | Pick a player up and drop them on a roster slot or the sell spot. |
| Right-click while dragging | Cancel and send the player back where they started. |

Three players stand on podiums with a name and an asking price. Nine roster slots
sit behind them, one per batting-order spot, labelled with the fielding role they
fill. Dropping a player on an open slot signs them: the shop charges the asking
price, the player stands in the slot, and the podium empties. A slot that already
has a player, or a price above the current funds, lights up red and refuses the
drop.

Signed players can be dragged back out of their slot and onto the sell spot, which
lights up green and shows what the sale pays. Selling empties the slot and adds the
player's sell value, which is set per listing and is lower than the asking price.
Listings on podiums cannot be sold; only signed players can.

## Classes

- `Buyable` (`game/shop/buyable.gd`): an `Area3D` that can be dragged and slid back
  home. It declares `fits()`, `apply_to()` and `price()`, so each kind of buyable
  decides which targets it works on, what the drop changes, and what it costs. A
  negative price pays the player instead of charging them, which is how selling
  works. `restocks` keeps the buyable in place after a trade.
- `PlayerSlot` (`game/shop/player_slot.gd`): a buyable player on a podium. It fits
  empty team slots and signs a duplicate of its `BaseballPlayerData`, so later
  changes to a signed player never reach the shop listing. Its `sell_value` travels
  with the signing.
- `SignedPlayer` (`game/shop/signed_player.gd`): the player standing in a filled
  slot. It fits only a sell spot, prices itself at minus its sell value, and empties
  its slot when sold.
- `BuyTarget` (`game/shop/buy_target.gd`): a place a buyable can be dropped. It holds
  the roster being built, can narrow what it takes with `accepts()`, and can show
  what a hovering buyable would do with `preview()`.
- `TeamSlot` (`game/shop/team_slot.gd`): one batting-order spot. Empty slots take
  player buyables and stand a `SignedPlayer` in the slot. A filled slot is also the
  target for buyables aimed at a single player; a buyable aimed at a whole team
  subclasses `BuyTarget` instead.
- `SellSpot` (`game/shop/sell_spot.gd`): the target that pays out. The buyable names
  its own sell price, so the spot only shows what the drop would pay.
- `Shop` (`game/shop/shop.gd`): the scene root. It duplicates its `team` Resource so
  trading never edits the file on disk, hands that copy to every target it owns,
  holds the funds, and runs the drag.

Buyables sit on 3D physics layer 1 and targets on layer 2. The shop raycasts each
layer separately, so the held buyable never hides the target under the cursor.

## Limits

The shop only fills `players` and `field_roles`. It does not set `field_positions`,
so a shop roster still fails `BaseballTeamData.validation_error()` and cannot be
handed to a match yet. Signed players cannot be moved between slots, a sold player
is gone rather than back on their podium, there is no buyable other than a player,
and there is no way to earn funds.

## Checks

```sh
godot --headless --path . --editor --quit
godot --headless --path . --fixed-fps 60 --script tests/shop_test.gd
```

The suite drags a player onto an open slot and checks the signing, the charge, the
roster entry and the emptied podium; checks that a taken slot and an unaffordable
price refuse the drop; then sells a signed player and checks the payout, the emptied
slot and roster entry, and that the sell spot refuses an unsigned listing.

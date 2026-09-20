class_name SellSpot
extends BuyTarget

## Where bought things go back for money. The buyable names its own sell price, so
## the spot only has to show what the drop would pay.

var label: Label3D


func _ready() -> void:
	label = $Label
	super()


func preview(buyable: Buyable) -> void:
	if buyable == null or not buyable.fits(self):
		label.text = "Sell"
		return
	label.text = "+$%d" % absi(buyable.price(self))

class_name ShopPodium
extends Node3D

## The stand a listing is sold from. It shows what the player on it costs, and
## keeps showing it while that player is carried off to a roster slot.

var listing: Buyable
var label: Label3D


func _ready() -> void:
	label = $Price
	for child in get_children():
		listing = child as Buyable
		if listing != null:
			break
	if listing == null:
		label.text = ""
		return
	listing.purchased.connect(_on_purchased)
	label.text = "$%d" % listing.cost


func _on_purchased(_target: BuyTarget) -> void:
	if not listing.restocks:
		label.text = "sold"

class_name ShopPodium
extends Node3D

## The stand a listing is sold from. Each one deals in a single kind of thing,
## refresh included. It shows what the thing on it costs, and keeps showing that
## while the thing is carried off to a slot.

## What this podium deals in. It never stocks anything else.
enum Sells { PLAYER, FOOD }

@export var sells: Sells = Sells.PLAYER

var listing: Buyable
var label: Label3D


func _ready() -> void:
	label = $Price
	for child in get_children():
		var found := child as Buyable
		if found != null:
			stock(found)
			break


## Put a listing on the podium, clearing off whatever was there.
func stock(new_listing: Buyable) -> void:
	if listing != null and listing != new_listing and is_instance_valid(listing):
		listing.queue_free()
	listing = new_listing
	if listing == null:
		label.text = ""
		return
	if listing.get_parent() != self:
		add_child(listing)
	if not listing.purchased.is_connected(_on_purchased):
		listing.purchased.connect(_on_purchased)
	label.text = "$%d" % listing.cost


func _on_purchased(_target: BuyTarget) -> void:
	if listing.restocks:
		return
	# The sold player frees itself, so the podium stands empty until a refresh.
	listing = null
	label.text = "sold"

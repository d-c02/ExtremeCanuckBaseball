class_name Food
extends Buyable

## A snack on a podium. Dropping it on a player feeds them a point of a stat for
## good; an empty slot has nobody to eat it. The gain stands on the snack in the
## colour of the stat it feeds, and hovering names it.

@export var food: BaseballFoodType

var mesh: MeshInstance3D
var gain_label: Label3D
var name_label: Label3D


func _ready() -> void:
	mesh = $Hang/Mesh
	hang = $Hang
	gain_label = $Hang/Gain
	name_label = $Name
	super()


func fits(target: BuyTarget) -> bool:
	var slot := target as TeamSlot
	return food != null and slot != null and not slot.is_empty()


func apply_to(target: BuyTarget) -> bool:
	if not fits(target):
		return false
	(target as TeamSlot).feed(food)
	return true


func set_hovered(on: bool) -> void:
	if name_label != null:
		name_label.visible = on


func refresh() -> void:
	if name_label == null:
		return
	if food == null:
		name_label.text = display_name
		return
	display_name = food.food_name
	name_label.text = food.card()
	gain_label.text = food.gain_text()
	gain_label.modulate = food.gain_color()
	var surface := StandardMaterial3D.new()
	surface.albedo_color = food.color
	surface.roughness = 1.0
	mesh.material_override = surface

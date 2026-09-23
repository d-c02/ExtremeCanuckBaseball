class_name BaseballShopFieldView
extends BaseballFieldView

## The complete Blender field is shown for fielding and hidden for the lineup.
var markings: Node3D


func build_shop(park: BaseballBallpark) -> void:
	build(park, false, false)
	markings = model

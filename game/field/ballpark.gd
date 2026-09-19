class_name BaseballBallpark
extends Node2D

## The ballpark itself: home, the mound, the bases, the outfield wall and both
## dugouts. The match plays on it and the buy screen stands its shop on it, so the
## two scenes always show the same park.

var base_positions: PackedVector2Array

@onready var home: Marker2D = $Home
@onready var mound: Marker2D = $Mound
@onready var outfield: BaseballOutfield = $Outfield
@onready var dugouts: Array[Node2D] = [$Dugouts/Visitors, $Dugouts/Home]


func _ready() -> void:
	base_positions = PackedVector2Array(
		[
			$FirstBase.position,
			$SecondBase.position,
			$ThirdBase.position,
			home.position
		]
	)

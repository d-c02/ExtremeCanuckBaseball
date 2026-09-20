class_name BaseballBallpark
extends Node2D

## A ballpark: home, the mound, the bases and the outfield wall, plus whatever
## dugouts the scene puts under a `Dugouts` child. `match_ballpark.tscn` inherits
## this one and adds the two dugouts a game needs; the buy screen uses the bare
## park, so both scenes share one definition of the field.

@export var use_exported_layout: bool = false

var base_positions: PackedVector2Array
var dugouts: Array[Node2D] = []

@onready var home: Marker2D = $Home
@onready var mound: Marker2D = $Mound
@onready var outfield: BaseballOutfield = $Outfield


func _enter_tree() -> void:
	if use_exported_layout:
		preload("res://assets/field/baseball_field.tres").apply_to(self)


func _ready() -> void:
	base_positions = PackedVector2Array(
		[$FirstBase.position, $SecondBase.position, $ThirdBase.position, home.position]
	)
	var benches := get_node_or_null("Dugouts")
	if benches == null:
		return
	for bench in benches.get_children():
		dugouts.append(bench)

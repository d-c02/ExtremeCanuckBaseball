class_name BaseballFieldLayout
extends Resource

@export var bases: PackedVector2Array
@export var mound: Vector2
@export var fence_distance: float
@export var fence_height: float
@export var flat_half_width: float
@export var corner_radius: float
@export var dugout_positions: PackedVector2Array
@export var dugout_rotations: PackedFloat32Array
@export var dugout_length: float
@export var dugout_width: float
@export var dugout_depth: float
@export var stair_width: float
@export var stair_run: float
@export var outfield_boundary: PackedVector2Array
@export var barrier_segments: PackedVector2Array
@export var barrier_heights: PackedFloat32Array


func apply_to(park: Node) -> void:
	for index in 4:
		var marker: Node2D = park.get_node(["FirstBase", "SecondBase", "ThirdBase", "Home"][index])
		marker.position = bases[index]
	park.get_node("Mound").position = mound
	var fence = park.get_node("Outfield")
	fence.home_position = bases[3]
	fence.first_direction = bases[0] - bases[3]
	fence.third_direction = bases[2] - bases[3]
	fence.fence_distance = fence_distance
	fence.fence_height = fence_height
	fence.flat_half_width = flat_half_width
	fence.corner_radius = corner_radius
	fence.boundary = outfield_boundary
	fence.barrier_segments = barrier_segments
	fence.barrier_heights = barrier_heights
	for side in 2:
		var dugout = park.get_node("Dugouts/" + ["Visitors", "Home"][side])
		dugout.position = dugout_positions[side]
		dugout.rotation = dugout_rotations[side]
		dugout.room_length = dugout_length
		dugout.room_width = dugout_width
		dugout.stair_run = stair_run
		dugout.stair_width = stair_width

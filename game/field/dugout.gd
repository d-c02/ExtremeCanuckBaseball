extends Node2D

var room_length: float = 340.0
var room_width: float = 90.0
var stair_run: float = 60.0
var stair_width: float = 50.0


func _ready() -> void:
	# Planar walls keep routes inside the same openings as the exported 3D room.
	var wall := StaticBody2D.new()
	wall.collision_layer = 2
	wall.collision_mask = 0
	add_child(wall)
	_add_wall(wall, Vector2(0, room_width / 2), Vector2(room_length, 4))
	for side in [-1, 1]:
		_add_wall(wall, Vector2(side * room_length / 2, 0), Vector2(4, room_width))
		_add_wall(
			wall,
			Vector2(side * (room_length + stair_width) / 4, -room_width / 2),
			Vector2((room_length - stair_width) / 2, 4)
		)
		_add_wall(
			wall,
			Vector2(side * (stair_width / 2 + 2), -room_width / 2 - stair_run / 2),
			Vector2(4, stair_run)
		)


func _add_wall(body: StaticBody2D, point: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	shape.position = point
	body.add_child(shape)


func seat_position(index: int) -> Vector2:
	return to_global(Vector2((index - 4) * (room_length - 68.0) / 8.0, 0))


func stair_bottom() -> Vector2:
	return to_global(Vector2(0, -room_width / 2 + 12.5))


func stair_top() -> Vector2:
	return to_global(Vector2(0, -room_width / 2 - stair_run - 12.5))


func contains(point: Vector2) -> bool:
	var local := to_local(point)
	return (
		Rect2(-Vector2(room_length, room_width) / 2, Vector2(room_length, room_width)).has_point(
			local
		)
		or (
			Rect2(
				Vector2(-stair_width / 2, -room_width / 2 - stair_run),
				Vector2(stair_width, stair_run)
			)
			. has_point(local)
		)
	)


func route_out(start: Vector2, destination: Vector2) -> PackedVector2Array:
	if not contains(start):
		return PackedVector2Array([destination])
	if to_local(start).y < -room_width / 2:
		return PackedVector2Array([stair_top(), destination])
	return PackedVector2Array([global_position, stair_bottom(), stair_top(), destination])


func route_in(start: Vector2, index: int) -> PackedVector2Array:
	if contains(start) and to_local(start).y >= -room_width / 2:
		return PackedVector2Array([seat_position(index)])
	return PackedVector2Array([stair_top(), stair_bottom(), global_position, seat_position(index)])


func on_deck_position() -> Vector2:
	return stair_top() + to_global(Vector2(50, 0)) - global_position

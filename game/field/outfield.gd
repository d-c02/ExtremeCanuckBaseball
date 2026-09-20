class_name BaseballOutfield
extends Node2D

@export var fence_distance: float = 950.0
@export var fence_height: float = 28.0
@export var flat_half_width: float = 300.0
@export var corner_radius: float = 500.0
@export var home_position: Vector2 = Vector2(0, 220)
var first_direction := Vector2(220, -220)
var third_direction := Vector2(-220, -220)
var boundary: PackedVector2Array
var barrier_segments: PackedVector2Array
var barrier_heights: PackedFloat32Array


func _ready() -> void:
	if boundary.is_empty():
		var top := home_position.y - fence_distance
		boundary.append(Vector2(-flat_half_width - corner_radius, home_position.y + 180.0))
		for index in 17:
			var angle := lerpf(PI, PI * 1.5, index / 16.0)
			boundary.append(
				(
					Vector2(-flat_half_width, top + corner_radius)
					+ Vector2.from_angle(angle) * corner_radius
				)
			)
		for index in 17:
			var angle := lerpf(-PI / 2.0, 0.0, index / 16.0)
			boundary.append(
				(
					Vector2(flat_half_width, top + corner_radius)
					+ Vector2.from_angle(angle) * corner_radius
				)
			)
		boundary.append(Vector2(flat_half_width + corner_radius, home_position.y + 180.0))
		for index in boundary.size():
			boundary[index].x += home_position.x
	var wall := StaticBody2D.new()
	wall.name = "WallCollision"
	wall.collision_layer = 2
	wall.collision_mask = 0
	add_child(wall)
	for index in boundary.size() - 1:
		var a := boundary[index]
		var b := boundary[index + 1]
		var outward := -inward_normal(index) * 12.0
		var points := PackedVector2Array([a, b, b + outward, a + outward])
		var shape := CollisionPolygon2D.new()
		shape.polygon = points
		wall.add_child(shape)
	for index in barrier_heights.size():
		var a := barrier_segments[index * 2]
		var b := barrier_segments[index * 2 + 1]
		var edge := (b - a).normalized()
		var side := Vector2(-edge.y, edge.x) * 2.0
		var shape := CollisionPolygon2D.new()
		shape.polygon = PackedVector2Array([a - side, b - side, b + side, a + side])
		wall.add_child(shape)


func inward_normal(index: int) -> Vector2:
	var edge := boundary[index + 1] - boundary[index]
	return Vector2(-edge.y, edge.x).normalized()


func clamp_inside(point: Vector2, margin: float = 14.0) -> Vector2:
	for pass_index in 3:
		for index in boundary.size() - 1:
			var normal := inward_normal(index)
			var distance := (point - boundary[index]).dot(normal)
			if distance < margin:
				point += normal * (margin - distance)
	return point


func boundary_hit(start: Vector2, finish: Vector2) -> Dictionary:
	var earliest := INF
	var hit: Dictionary = {}
	for index in boundary.size() - 1:
		var normal := inward_normal(index)
		var a := (start - boundary[index]).dot(normal)
		var b := (finish - boundary[index]).dot(normal)
		if a >= -0.01 and b < 0.0 and a - b > 0.0001:
			var fraction := clampf(a / (a - b), 0.0, 1.0)
			if fraction < earliest:
				earliest = fraction
				hit = {
					"point": start.lerp(finish, fraction), "normal": normal, "fraction": fraction
				}
	return hit


func barrier_hit(
	start: Vector2, finish: Vector2, start_height: float, finish_height: float
) -> Dictionary:
	var hit: Dictionary = {}
	var distance := start.distance_to(finish)
	if distance < 0.0001:
		return hit
	for index in barrier_heights.size():
		var a := barrier_segments[index * 2]
		var b := barrier_segments[index * 2 + 1]
		var crossing = Geometry2D.segment_intersects_segment(start, finish, a, b)
		if crossing == null:
			continue
		var fraction := start.distance_to(crossing) / distance
		if lerpf(start_height, finish_height, fraction) > barrier_heights[index]:
			continue
		if not hit.is_empty() and fraction >= hit.fraction:
			continue
		var edge := b - a
		var normal := Vector2(-edge.y, edge.x).normalized()
		if (start - crossing).dot(normal) < 0.0:
			normal = -normal
		hit = {"point": crossing, "normal": normal, "fraction": fraction}
	return hit


func check_barriers(ball: BaseballBall) -> void:
	var hit := barrier_hit(ball.previous_position, ball.position, ball.previous_height, ball.height)
	if not hit.is_empty():
		ball.position = hit.point + hit.normal * 2.6
		ball.velocity = ball.velocity.bounce(hit.normal) * 0.45
		ball.bounced = true


func is_fair(point: Vector2) -> bool:
	var offset := point - home_position
	return first_direction.cross(offset) <= 0.0 and third_direction.cross(offset) >= 0.0


func check_crossing(ball: BaseballBall) -> String:
	var hit := boundary_hit(ball.previous_position, ball.position)
	if hit.is_empty():
		return ""
	var crossing_height := lerpf(ball.previous_height, ball.height, hit.fraction)
	if not ball.bounced and crossing_height > fence_height and is_fair(hit.point):
		return "home_run"
	ball.position = hit.point + hit.normal * 2.0
	ball.velocity = ball.velocity.bounce(hit.normal) * 0.45
	ball.bounced = true
	return "wall"


func forecast(ball: BaseballBall, seconds: float) -> Dictionary:
	return forecast_path(ball, seconds).back()


func forecast_path(ball: BaseballBall, seconds: float) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	var point := ball.position
	var velocity := ball.velocity
	var height := ball.height
	var upward := ball.vertical_velocity
	var bounced := ball.bounced
	var remaining := seconds
	while remaining > 0.0001:
		var delta := minf(remaining, 0.05)
		var previous := point
		var previous_height := height
		point += velocity * delta
		if height > 0.0 or upward > 0.0:
			upward -= BaseballBall.GRAVITY * delta
			height += upward * delta
			if height <= 0.0:
				height = 0.0
				upward = 0.0
				bounced = true
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 85.0 * delta)
		var guard := barrier_hit(previous, point, previous_height, height)
		if not guard.is_empty():
			point = guard.point + guard.normal * 2.6
			velocity = velocity.bounce(guard.normal) * 0.45
			bounced = true
		var hit := boundary_hit(previous, point)
		if not hit.is_empty():
			var crossing_height := lerpf(previous_height, height, hit.fraction)
			if not bounced and crossing_height > fence_height and is_fair(hit.point):
				samples.append(
					{
						"point": clamp_inside(hit.point),
						"height": height,
						"home_run": true,
						"time": seconds - remaining + delta
					}
				)
				return samples
			point = hit.point + hit.normal * 2.0
			velocity = velocity.bounce(hit.normal) * 0.45
			bounced = true
		remaining -= delta
		samples.append(
			{"point": point, "height": height, "home_run": false, "time": seconds - remaining}
		)
	return samples

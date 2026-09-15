class_name BaseballOutfield
extends Node2D

@export var fence_distance: float = 950.0
@export var fence_height: float = 28.0
@export var flat_half_width: float = 300.0
@export var corner_radius: float = 500.0
@export var home_position: Vector2 = Vector2(0, 220)
var boundary: PackedVector2Array


func _ready() -> void:
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
		var strip := Polygon2D.new()
		strip.polygon = points
		strip.color = $Fence.color
		$Fence.add_child(strip)
	for side in [-1, 1]:
		var end := home_position + Vector2(side, -1) * 1500.0
		var hit := boundary_hit(home_position, end)
		if not hit.is_empty():
			end = hit.point
		var line := Polygon2D.new()
		var offset := Vector2(1.2, 1.2 * side)
		line.polygon = PackedVector2Array(
			[home_position - offset, end - offset, end + offset, home_position + offset]
		)
		line.color = Color(0.8, 0.8, 0.7, 0.55)
		add_child(line)


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


func is_fair(point: Vector2) -> bool:
	var offset := point - home_position
	return offset.y <= 0.0 and absf(offset.x) <= -offset.y


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
	ball.update_visuals()
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

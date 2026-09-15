@tool
class_name BaseballCameraZones
extends Node2D

var show_guides: bool = false


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or show_guides:
		queue_redraw()


func dead_zone() -> Rect2:
	return _marker_rect($DeadZone/TopLeft, $DeadZone/BottomRight)


func protected_bases() -> Rect2:
	return _marker_rect($KeepBasesVisible/TopLeft, $KeepBasesVisible/BottomRight)


func bottom_limit() -> float:
	return $BottomLimit.global_position.y


func _marker_rect(first: Marker2D, second: Marker2D) -> Rect2:
	return Rect2(first.global_position, second.global_position - first.global_position).abs()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		show_guides = not show_guides
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() and not show_guides:
		return
	if not has_node("BottomLimit"):
		return
	_draw_zone(dead_zone(), Color(0.25, 0.9, 1), "Dead zone: no pan / zoom inside")
	_draw_zone(protected_bases(), Color(1, 0.85, 0.25), "Keep bases visible")
	var y := to_local($BottomLimit.global_position).y
	draw_line(Vector2(-1100, y), Vector2(1100, y), Color(1, 0.35, 0.35), 3)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-500, y + 25),
		"Bottom of camera view",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color(1, 0.35, 0.35)
	)


func _draw_zone(rect: Rect2, color: Color, label: String) -> void:
	var local_rect := Rect2(to_local(rect.position), rect.size)
	draw_rect(local_rect, Color(color, 0.04))
	draw_rect(local_rect, color, false, 2)
	draw_string(
		ThemeDB.fallback_font,
		local_rect.position + Vector2(8, -8),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		color
	)

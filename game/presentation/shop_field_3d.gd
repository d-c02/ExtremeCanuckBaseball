class_name BaseballShopFieldView
extends Node3D

var dugout_labels: Array[Label3D] = []
## Everything painted on the grass: the diamond, the lines, the wall and the
## dugouts. The buy screen hides it to line players up on a plain field.
var markings: Node3D


## Draw [param park]. [param colors] tints its dugouts, visitors first, so a park
## with no dugouts needs none.
func build(park: BaseballBallpark, colors: Array[Color] = []) -> void:
	var grass := material(Color("4d7745"))
	var dirt := material(Color("b28a61"))
	var chalk := material(Color("eee9d8"))
	var fence := material(Color("365963"))
	box(Vector3(0, -0.22, -4), Vector3(110, 0.4, 100), grass)
	markings = Node3D.new()
	add_child(markings)
	var home := BaseballWorld.world_position(park.home.position)
	var bases: Array[Vector3] = []
	for point in park.base_positions:
		bases.append(BaseballWorld.world_position(point))
	var center := (bases[0] + bases[2]) / 2
	var edge := bases[1] - bases[0]
	var width := edge.length() + 1.3
	var infield := box(center + Vector3(0, 0.005, 0), Vector3(width, 0.03, width), dirt)
	infield.rotation.y = atan2(edge.x, edge.z)
	for index in 4:
		line(bases[index], bases[(index + 1) % 4], 0.07, chalk)
		var base := box(bases[index] + Vector3(0, 0.07, 0), Vector3(0.7, 0.12, 0.7), chalk)
		base.rotation.y = PI / 4
	disk(BaseballWorld.world_position(park.mound.position), 1.2, dirt)
	box(BaseballWorld.world_position(park.mound.position, 2), Vector3(0.6, 0.08, 0.2), chalk)
	for side in [-1, 1]:
		var end := park.home.position + Vector2(side, -1) * 1500
		var hit := park.outfield.boundary_hit(park.home.position, end)
		if not hit.is_empty():
			line(home, BaseballWorld.world_position(hit.point), 0.08, chalk)
	var boundary := park.outfield.boundary
	var height := park.outfield.fence_height * BaseballWorld.FIELD_SCALE
	for index in boundary.size() - 1:
		var start := BaseballWorld.world_position(boundary[index])
		var end := BaseballWorld.world_position(boundary[index + 1])
		var wall := box(
			(start + end) / 2 + Vector3.UP * height / 2,
			Vector3(0.35, height, start.distance_to(end)),
			fence
		)
		wall.look_at_from_position(wall.position, end + Vector3.UP * height / 2)
	for side in park.dugouts.size():
		var dugout: Node2D = park.dugouts[side]
		var bench := box(
			BaseballWorld.world_position(dugout.position, 10),
			Vector3(13.6, 0.8, 1.4),
			material(colors[side].darkened(0.3))
		)
		bench.rotation.y = -dugout.rotation
		var label := Label3D.new()
		label.position = BaseballWorld.world_position(dugout.position, 70)
		label.font_size = 40
		label.pixel_size = 0.013
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_attach(label)
		dugout_labels.append(label)
		disk(BaseballWorld.world_position(dugout.on_deck_position()), 0.8, dirt)


static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1.0
	return result


func box(point: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = surface
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = point
	_attach(node)
	return node


func line(start: Vector3, end: Vector3, width: float, surface: Material) -> void:
	var center := (start + end) / 2 + Vector3(0, 0.055, 0)
	var node := box(center, Vector3(width, 0.025, start.distance_to(end)), surface)
	node.look_at_from_position(center, end + Vector3(0, 0.055, 0))


func disk(point: Vector3, radius: float, surface: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.radial_segments = 24
	mesh.material = surface
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = point + Vector3(0, 0.04, 0)
	_attach(node)


## Park pieces go under [member markings] so they can be hidden together. The grass
## is added before there is a markings node, so it stays whatever the view shows.
func _attach(node: Node3D) -> void:
	if markings == null:
		add_child(node)
		return
	markings.add_child(node)

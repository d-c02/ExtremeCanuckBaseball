class_name BaseballFieldView
extends Node3D

const FIELD_SCENE = preload("res://assets/field/baseball_field.glb")
const GROUND_LAYER: int = 4
var dugout_labels: Array[Label3D] = []
var model: Node3D


func build(park: BaseballBallpark, with_collision: bool = true, with_labels: bool = true) -> void:
	model = FIELD_SCENE.instantiate()
	add_child(model)
	if with_collision:
		_add_ground_collision(model)
	if not with_labels:
		return
	for side in 2:
		var label := Label3D.new()
		label.position = BaseballWorld.world_position(park.dugouts[side].position, 70)
		label.font_size = 40
		label.pixel_size = 0.013
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		dugout_labels.append(label)


func _add_ground_collision(node: Node) -> void:
	if node is MeshInstance3D:
		var body := StaticBody3D.new()
		body.collision_layer = GROUND_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = node.mesh.create_trimesh_shape()
		body.add_child(shape)
		node.add_child(body)
	for child in node.get_children():
		_add_ground_collision(child)


static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1.0
	return result

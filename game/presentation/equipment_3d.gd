class_name BaseballEquipmentView
extends Node3D

var world: BaseballWorld
var bat_views: Array[MeshInstance3D] = []
var ball_views: Array[MeshInstance3D] = []
var attendants: Array[BaseballPlayerView] = []
var bat_ground: Array[float] = []


func configure(scene: BaseballWorld) -> void:
	world = scene
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.12, 0.12)
	mesh.material = BaseballFieldView.material(Color(0.8, 0.62, 0.35))
	for bat in world.game.equipment.bats:
		var view := MeshInstance3D.new()
		view.mesh = mesh
		add_child(view)
		bat_views.append(view)
		bat_ground.append(0.0)
	for ball in world.game.equipment.balls:
		var view := MeshInstance3D.new()
		view.mesh = world.ball.mesh
		add_child(view)
		ball_views.append(view)
	var supply := BaseballWorld.world_position(
		world.game.home.position + BaseballEquipment.SUPPLY_OFFSET
	)
	for offset in [
		Vector3(-0.98, 0.44, 0),
		Vector3(0.98, 0.44, 0),
		Vector3(0, 0.44, -0.5),
		Vector3(0, 0.44, 0.5)
	]:
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.88, 1.0) if offset.x != 0 else Vector3(2.0, 0.88, 0.08)
		box.material = BaseballFieldView.material(Color(0.25, 0.3, 0.32))
		wall.mesh = box
		wall.position = supply + offset
		add_child(wall)
	for actor in world.game.equipment.attendants:
		var view: BaseballPlayerView = world.PLAYER_VIEW.instantiate()
		add_child(view)
		view.configure(actor, Color(0.7, 0.7, 0.65), world.game)
		attendants.append(view)


func _physics_process(_delta: float) -> void:
	if world == null or world.game.paused:
		return
	for index in bat_views.size():
		var bat := world.game.equipment.bats[index]
		var point := BaseballWorld.world_position(bat.position)
		var ray := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 8, point - Vector3.UP * 8, BaseballFieldView.GROUND_LAYER
		)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		bat_ground[index] = hit.position.y if not hit.is_empty() else 0.0


func _process(delta: float) -> void:
	if world == null:
		return
	for index in bat_views.size():
		var bat := world.game.equipment.bats[index]
		var view := bat_views[index]
		view.position = BaseballWorld.world_position(bat.position, bat.height)
		view.position.y += bat_ground[index]
		view.rotation.y = bat.angle
		view.position += Vector3(cos(bat.angle), 0, -sin(bat.angle)) * 0.6
	for index in ball_views.size():
		var ball := world.game.equipment.balls[index]
		ball_views[index].visible = ball != world.game.ball
		ball_views[index].position = world.ball_position(ball)
	for view in attendants:
		view.sync(0.0 if world.game.paused else delta)

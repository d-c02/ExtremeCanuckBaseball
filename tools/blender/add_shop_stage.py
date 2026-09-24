"""Add the Blender-authored buy-screen preview and fixture anchors to the field."""

import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/blender/baseball_field.blend"
SHOP_SCALE = 0.6
PODIUM_X = (-9.5, -5.7, -1.9, 1.9, 5.7, 9.5)
FIELD_SPOTS = (
    (0, 0), (0, 265), (200, -25), (125, -190), (-205, -25),
    (-125, -190), (-440, -485), (0, -610), (440, -485),
)
LANDMARK_SLOTS = {0: "Mound", 2: "First", 4: "Third"}


def material(name, color):
    result = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = next(n for n in result.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = 0.85
    return result


def anchor(collection, name, position):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "CIRCLE"
    obj.empty_display_size = 0.8
    obj.location = position
    collection.objects.link(obj)
    return obj


def add_fixture_group(collection, anchors):
    group = bpy.data.node_groups.new("GN_ShopFixtures_v01", "GeometryNodeTree")
    group.interface.new_socket(name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    nodes, links = group.nodes, group.links
    join = nodes.new("GeometryNodeJoinGeometry")
    join.location = (3900, 0)
    output = nodes.new("NodeGroupOutput")
    output.location = (4200, 0)
    links.new(join.outputs[0], output.inputs["Geometry"])
    wood = material("Shop Stand", (0.33, 0.24, 0.17))
    gold = material("Shop Stand Trim", (0.75, 0.56, 0.25))
    blue = material("Shop Snack Trim", (0.25, 0.58, 0.67))
    red = material("Shop Sell Stand", (0.48, 0.16, 0.16))
    sell_top = material("Shop Sell Top", (0.28, 0.055, 0.06))
    branch_index = 0

    def cylinder(location, radius, depth, surface, height):
        nonlocal branch_index
        frame = nodes.new("NodeFrame")
        frame.label = location.name
        frame.location = ((branch_index % 4) * 900, -(branch_index // 4) * 600)
        branch_index += 1
        marker = nodes.new("GeometryNodeObjectInfo")
        marker.parent = frame
        marker.location = (-700, 0)
        marker.inputs["Object"].default_value = location
        mesh = nodes.new("GeometryNodeMeshCylinder")
        mesh.parent = frame
        mesh.location = (-700, -200)
        mesh.inputs["Vertices"].default_value = 24
        mesh.inputs["Radius"].default_value = radius
        mesh.inputs["Depth"].default_value = depth
        offset = nodes.new("ShaderNodeVectorMath")
        offset.parent = frame
        offset.location = (-450, 0)
        offset.operation = "ADD"
        offset.inputs[1].default_value = (0, 0, height)
        links.new(marker.outputs["Location"], offset.inputs[0])
        move = nodes.new("GeometryNodeTransform")
        move.parent = frame
        move.location = (-180, -100)
        links.new(mesh.outputs["Mesh"], move.inputs["Geometry"])
        links.new(offset.outputs[0], move.inputs["Translation"])
        shade = nodes.new("GeometryNodeSetMaterial")
        shade.parent = frame
        shade.location = (80, -100)
        shade.inputs["Material"].default_value = surface
        links.new(move.outputs[0], shade.inputs["Geometry"])
        links.new(shade.outputs[0], join.inputs[0])

    for index, point in enumerate(anchors[:6]):
        cylinder(point, 0.95, 1.12, wood, 0.56)
        cylinder(point, 0.88, 0.10, blue if index >= 4 else gold, 1.15)
    cylinder(anchors[6], 1.8, 0.12, red, 0.14)
    cylinder(anchors[6], 1.55, 0.04, sell_top, 0.22)
    mesh = bpy.data.meshes.new("Shop Fixtures Source")
    obj = bpy.data.objects.new("Shop Fixtures", mesh)
    collection.objects.link(obj)
    obj.modifiers.new("Shop Fixtures", "NODES").node_group = group


def add_lineup_ground(collection):
    mesh = bpy.data.meshes.new("Lineup Ground Source")
    obj = bpy.data.objects.new("Lineup Ground", mesh)
    collection.objects.link(obj)
    group = bpy.data.node_groups.new("GN_LineupGround_v01", "GeometryNodeTree")
    group.interface.new_socket(name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    cube = group.nodes.new("GeometryNodeMeshCube")
    cube.inputs["Size"].default_value = (110, 100, 0.4)
    move = group.nodes.new("GeometryNodeTransform")
    move.inputs["Translation"].default_value = (0, -4, -0.22)
    shade = group.nodes.new("GeometryNodeSetMaterial")
    shade.inputs["Material"].default_value = material("Shop Lineup Ground", (0.025, 0.055, 0.05))
    output = group.nodes.new("NodeGroupOutput")
    group.links.new(cube.outputs["Mesh"], move.inputs["Geometry"])
    group.links.new(move.outputs[0], shade.inputs["Geometry"])
    group.links.new(shade.outputs[0], output.inputs["Geometry"])
    obj.modifiers.new("Lineup Ground", "NODES").node_group = group
    obj.hide_set(True)


def add_slot_preview(collection):
    group = bpy.data.node_groups.new("GN_ShopSlotPreview_v01", "GeometryNodeTree")
    group.interface.new_socket(name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    nodes, links = group.nodes, group.links
    join = nodes.new("GeometryNodeJoinGeometry")
    output = nodes.new("NodeGroupOutput")
    circle = nodes.new("GeometryNodeCurvePrimitiveCircle")
    circle.inputs["Resolution"].default_value = 48
    circle.inputs["Radius"].default_value = 1.15
    profile = nodes.new("GeometryNodeCurvePrimitiveCircle")
    profile.inputs["Resolution"].default_value = 8
    profile.inputs["Radius"].default_value = 0.09
    ring = nodes.new("GeometryNodeCurveToMesh")
    links.new(circle.outputs["Curve"], ring.inputs["Curve"])
    links.new(profile.outputs["Curve"], ring.inputs["Profile Curve"])
    for index in range(1, 10):
        point = bpy.data.objects[f"Roster {index}"]
        marker = nodes.new("GeometryNodeObjectInfo")
        marker.inputs["Object"].default_value = point
        offset = nodes.new("ShaderNodeVectorMath")
        offset.operation = "ADD"
        offset.inputs[1].default_value = (0, 0, 0.12)
        links.new(marker.outputs["Location"], offset.inputs[0])
        move = nodes.new("GeometryNodeTransform")
        links.new(ring.outputs["Mesh"], move.inputs["Geometry"])
        links.new(offset.outputs[0], move.inputs["Translation"])
        links.new(move.outputs[0], join.inputs[0])
    shade = nodes.new("GeometryNodeSetMaterial")
    shade.inputs["Material"].default_value = material("Shop Slot Preview", (0.82, 0.14, 0.16))
    links.new(join.outputs[0], shade.inputs["Geometry"])
    links.new(shade.outputs[0], output.inputs["Geometry"])
    mesh = bpy.data.meshes.new("Shop Slot Preview Source")
    obj = bpy.data.objects.new("Shop Slot Preview (not exported)", mesh)
    collection.objects.link(obj)
    obj.modifiers.new("Slot Preview", "NODES").node_group = group


def add():
    if "Buy Screen Preview" in bpy.data.scenes:
        raise RuntimeError("The buy-screen preview is already installed")
    field_scene = bpy.data.scenes["Baseball Field"]
    field = bpy.data.objects["Baseball Field"]
    controls = field.modifiers["Field Controls"]

    def field_point(name):
        socket = controls.node_group.interface.items_tree[name]
        return Vector(getattr(controls.properties.inputs, socket.identifier).value)

    home = field_point("Home")
    scene = bpy.data.scenes.new("Buy Screen Preview")
    scene.unit_settings.system = "METRIC"
    bpy.context.window.scene = scene
    preview = bpy.data.objects.new("Shop Field Preview", None)
    preview.instance_type = "COLLECTION"
    preview.instance_collection = bpy.data.collections["Field"]
    preview.scale = (SHOP_SCALE,) * 3
    preview.location = home * (1 - SHOP_SCALE)
    scene.collection.objects.link(preview)

    dressing = bpy.data.collections.new("Shop Dressing")
    scene.collection.children.link(dressing)
    anchors = [anchor(dressing, f"Podium {i + 1}", (x, -14.8, 0)) for i, x in enumerate(PODIUM_X)]
    anchors.append(anchor(dressing, "Sell Spot", (-12, -7, 0)))
    for i, (x, y) in enumerate(FIELD_SPOTS):
        point = Vector((x * 0.04, -y * 0.04, 0))
        if i in LANDMARK_SLOTS:
            point = field_point(LANDMARK_SLOTS[i])
        elif i == 1:
            point = home + Vector((0, -1.8, 0))
        anchor(dressing, f"Roster {i + 1}", point * SHOP_SCALE + preview.location)
    add_fixture_group(dressing, anchors)
    add_slot_preview(dressing)
    add_lineup_ground(dressing)

    camera_data = bpy.data.cameras.new("Shop Camera")
    camera = bpy.data.objects.new("Shop Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0, -30.5, 20.5)
    target = anchor(dressing, "Camera Target", (0, -22.69, 14.25))
    tracking = camera.constraints.new("TRACK_TO")
    tracking.target = target
    tracking.track_axis = "TRACK_NEGATIVE_Z"
    tracking.up_axis = "UP_Y"
    camera_data.sensor_fit = "VERTICAL"
    camera_data.angle = math.radians(36)
    scene.camera = camera
    sun_data = bpy.data.lights.new("Shop Preview Sun", "SUN")
    sun_data.energy = 2.0
    sun = bpy.data.objects.new("Shop Preview Sun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(35), math.radians(-30), math.radians(-15))
    scene.world = bpy.data.worlds.new("Shop Preview World")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.53, 0.68, 0.74, 1)

    bpy.context.window.scene = field_scene
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    print("Added Buy Screen Preview, GN shop fixtures and placement anchors")


if __name__ == "__main__":
    add()

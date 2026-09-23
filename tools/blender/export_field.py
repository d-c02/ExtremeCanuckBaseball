"""Export the evaluated field and its controls, without applying its modifier."""

import json
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]


def export():
    initial_scene = bpy.context.window.scene
    bpy.context.window.scene = bpy.data.scenes["Baseball Field"]
    field = bpy.context.scene.objects.get("Baseball Field")
    if field is None:
        raise RuntimeError("Open the Baseball Field scene before exporting")
    if any(
        abs(field.matrix_world[i][j] - float(i == j)) > 0.0001
        for i in range(4)
        for j in range(4)
    ):
        raise ValueError(
            "Keep the field object transform at identity; edit its layout controls instead"
        )
    modifier = field.modifiers["Field Controls"]
    controls = {}
    for socket in modifier.node_group.interface.items_tree:
        if socket.item_type != "SOCKET" or socket.in_out != "INPUT":
            continue
        value = getattr(modifier.properties.inputs, socket.identifier).value
        controls[socket.name] = (
            list(value) if socket.socket_type == "NodeSocketVector" else value
        )
    if any(
        abs(controls[name][2]) > 0.0001
        for name in [
            "Home",
            "First",
            "Second",
            "Third",
            "Mound",
            "Visitors Dugout",
            "Home Team Dugout",
        ]
    ):
        raise ValueError(
            "Keep layout marker Z coordinates at zero; dugout depth has its own control"
        )
    output = ROOT / "assets/field"
    output.mkdir(parents=True, exist_ok=True)
    selected = list(bpy.context.selected_objects)
    active = bpy.context.view_layer.objects.active
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(field.evaluated_get(depsgraph))
    if not mesh.vertices or not mesh.polygons:
        raise RuntimeError("Field evaluated to an empty mesh")
    barriers, outfield_edges = [], []
    for attribute, destination in [
        ("field_barrier", barriers),
        ("field_outfield", outfield_edges),
    ]:
        tagged = mesh.attributes.get(attribute)
        if tagged is None:
            raise ValueError("Install the diamond perimeter before exporting")
        for polygon in mesh.polygons:
            if not tagged.data[polygon.index].value:
                continue
            vertices = [mesh.vertices[index].co for index in polygon.vertices]
            bottom = [v for v in vertices if abs(v.z) < 0.0001]
            if len(bottom) != 2:
                raise ValueError("Fence faces must have two ground-level endpoints")
            destination.append(
                (
                    [(round(v.x * 25, 4), round(-v.y * 25, 4)) for v in bottom],
                    round(max(v.z for v in vertices) * 25, 4),
                )
            )
    neighbors = {}
    for (a, b), _ in outfield_edges:
        neighbors.setdefault(a, []).append(b)
        neighbors.setdefault(b, []).append(a)
    ends = [p for p, adjacent in neighbors.items() if len(adjacent) == 1]
    if len(ends) != 2 or any(len(adjacent) > 2 for adjacent in neighbors.values()):
        raise ValueError("Outfield must be one open chain from left to right")
    boundary = [min(ends)]
    previous = None
    while True:
        following = [p for p in neighbors[boundary[-1]] if p != previous]
        if not following:
            break
        previous = boundary[-1]
        boundary.append(following[0])
    if len(boundary) != len(outfield_edges) + 1:
        raise ValueError("Disconnected outfield panels")
    baked = bpy.data.objects.new("BaseballField", mesh)
    bpy.context.scene.collection.objects.link(baked)
    baked.matrix_world = field.matrix_world
    try:
        bpy.ops.object.select_all(action="DESELECT")
        baked.select_set(True)
        bpy.context.view_layer.objects.active = baked
        bpy.ops.export_scene.gltf(
            filepath=str(output / "baseball_field.glb"),
            export_format="GLB",
            use_selection=True,
            use_active_scene=True,
            export_yup=True,
        )
        (output / "baseball_field.layout.json").write_text(
            json.dumps(
                {
                    "schema_version": 4,
                    "simulation_units_per_meter": 25,
                    "coordinates": "Blender Z-up; simulation (x, y) = (Blender x * 25, -Blender y * 25)",
                    "controls": controls,
                },
                indent=2,
            )
            + "\n"
        )

        def point(name):
            x, y, _ = controls[name]
            return (round(x * 25, 4), round(-y * 25, 4))

        def packed(points):
            return ", ".join(str(v) for p in points for v in p)

        layout = [
            '[gd_resource type="Resource" script_class="BaseballFieldLayout" load_steps=2 format=3]',
            '[ext_resource type="Script" path="res://data/field_layout.gd" id="layout"]',
            "[resource]",
            'script = ExtResource("layout")',
            "bases = PackedVector2Array("
            + packed([point(n) for n in ["First", "Second", "Third", "Home"]])
            + ")",
            "mound = Vector2(" + packed([point("Mound")]) + ")",
            "dugout_positions = PackedVector2Array("
            + packed([point("Visitors Dugout"), point("Home Team Dugout")])
            + ")",
            "dugout_rotations = PackedFloat32Array("
            + ", ".join(
                str(-controls[n]) for n in ["Visitors Rotation", "Home Team Rotation"]
            )
            + ")",
        ]
        layout.append(
            "outfield_boundary = PackedVector2Array(" + packed(boundary) + ")"
        )
        layout.append(
            "barrier_segments = PackedVector2Array("
            + packed([p for segment, _ in barriers for p in segment])
            + ")"
        )
        layout.append(
            "barrier_heights = PackedFloat32Array("
            + ", ".join(str(height) for _, height in barriers)
            + ")"
        )
        for property_name, control in {
            "fence_distance": "Fence Depth",
            "fence_height": "Fence Height",
            "flat_half_width": "Fence Flat Half Width",
            "corner_radius": "Fence Corner Radius",
            "dugout_length": "Dugout Length",
            "dugout_width": "Dugout Width",
            "dugout_depth": "Dugout Depth",
            "stair_width": "Dugout Stair Width",
            "stair_run": "Dugout Stair Run",
        }.items():
            layout.append(property_name + " = " + str(round(controls[control] * 25, 4)))
        (output / "baseball_field.tres").write_text("\n".join(layout) + "\n")
        print(
            {
                "output": str(output),
                "vertices": len(mesh.vertices),
                "faces": len(mesh.polygons),
            }
        )
    finally:
        bpy.data.objects.remove(baked, do_unlink=True)
        bpy.data.meshes.remove(mesh)
        for obj in selected:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = active
    export_shop(output)
    bpy.context.window.scene = initial_scene


def export_shop(output):
    """Bake optional shop art and its interactive placement from the same blend."""
    scene = bpy.data.scenes["Buy Screen Preview"]
    previous_scene = bpy.context.window.scene
    bpy.context.window.scene = scene
    bpy.context.view_layer.update()
    selected = list(bpy.context.selected_objects)
    active = bpy.context.view_layer.objects.active

    def bake(name, filename):
        source = bpy.data.objects[name]
        mesh = bpy.data.meshes.new_from_object(
            source.evaluated_get(bpy.context.evaluated_depsgraph_get())
        )
        if not mesh.vertices or not mesh.polygons:
            raise RuntimeError(f"{name} evaluated to an empty mesh")
        baked = bpy.data.objects.new(name + " Export", mesh)
        scene.collection.objects.link(baked)
        try:
            bpy.ops.object.select_all(action="DESELECT")
            baked.select_set(True)
            bpy.context.view_layer.objects.active = baked
            bpy.ops.export_scene.gltf(
                filepath=str(output / filename),
                export_format="GLB",
                use_selection=True,
                use_active_scene=True,
                export_yup=True,
            )
        finally:
            bpy.data.objects.remove(baked, do_unlink=True)
            bpy.data.meshes.remove(mesh)

    def components(name):
        point = bpy.data.objects[name].matrix_world.translation
        return f"{point.x:.5f}, {point.z:.5f}, {-point.y:.5f}"

    def world_point(name):
        return f"Vector3({components(name)})"

    try:
        preview = bpy.data.objects["Shop Field Preview"]
        if any(abs(axis - preview.scale.x) > 0.0001 for axis in preview.scale):
            raise ValueError("Keep the shop field preview uniformly scaled")
        if any(abs(axis) > 0.0001 for axis in preview.rotation_euler):
            raise ValueError("Keep the shop field preview unrotated")
        bake("Shop Fixtures", "shop_fixtures.glb")
        bake("Lineup Ground", "shop_lineup_ground.glb")
        camera = bpy.data.objects["Shop Camera"]
        scale = preview.scale.x
        resource = [
            '[gd_resource type="Resource" script_class="BaseballShopStage" load_steps=2 format=3]',
            '[ext_resource type="Script" path="res://data/shop_stage.gd" id="stage"]',
            '[resource]',
            'script = ExtResource("stage")',
            f"field_scale = {scale:.5f}",
            f"field_position = {world_point('Shop Field Preview')}",
            "podium_positions = PackedVector3Array("
            + ", ".join(components(f"Podium {index}") for index in range(1, 7))
            + ")",
            f"sell_position = {world_point('Sell Spot')}",
            "field_positions = PackedVector3Array("
            + ", ".join(components(f"Roster {index}") for index in range(1, 10))
            + ")",
            f"camera_position = {world_point('Shop Camera')}",
            f"camera_target = {world_point('Camera Target')}",
            f"camera_fov = {camera.data.angle * 180 / 3.141592653589793:.5f}",
        ]
        (output / "shop_stage.tres").write_text("\n".join(resource) + "\n")
    finally:
        for obj in selected:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = active
        bpy.context.window.scene = previous_scene


if __name__ == "__main__":
    export()

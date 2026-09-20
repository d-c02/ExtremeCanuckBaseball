"""Export the evaluated field and its controls, without applying its modifier."""

import json
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]


def export():
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
                    "schema_version": 2,
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


if __name__ == "__main__":
    export()

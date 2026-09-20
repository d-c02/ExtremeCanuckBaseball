"""Create the editable field in a new scene. Run inside Blender 5.2+."""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion

ROOT = Path(__file__).resolve().parents[2]


def build():
    path = ROOT / "art/blender/baseball_field.blend"
    if path.exists() and "--overwrite" not in sys.argv:
        raise FileExistsError(
            "Field already exists. Edit it in Blender, or pass -- --overwrite to rebuild."
        )
    scene = bpy.data.scenes.new("Baseball Field")
    bpy.context.window.scene = scene
    scene.unit_settings.system = "METRIC"
    collection = bpy.data.collections.new("Field")
    scene.collection.children.link(collection)
    sources = bpy.data.collections.new("Field Sources (do not export)")
    scene.collection.children.link(sources)

    def mesh_object(name, vertices, faces, target=collection):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        target.objects.link(obj)
        return obj

    field = mesh_object("Baseball Field", [], [])
    tree = bpy.data.node_groups.new("GN_BaseballField_v01", "GeometryNodeTree")
    tree.interface.new_socket(
        name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry"
    )
    modifier = field.modifiers.new("Field Controls", "NODES")
    modifier.node_group = tree
    nodes, links = tree.nodes, tree.links
    group_in = nodes.new("NodeGroupInput")
    group_in.location = (-1000, 300)
    group_out = nodes.new("NodeGroupOutput")
    group_out.location = (1800, 300)
    join = nodes.new("GeometryNodeJoinGeometry")
    join.location = (1550, 300)
    links.new(join.outputs[0], group_out.inputs[0])
    frame = None
    column = 0

    def branch(label):
        nonlocal frame, column
        frame = nodes.new("NodeFrame")
        frame.label = label
        frame.location = (0, -column * 600)
        column += 1

    def node(kind, label=""):
        result = nodes.new(kind)
        result.label = label
        result.parent = frame
        count = sum(n.parent == frame for n in nodes)
        result.location = ((count - 1) % 6 * 260, -((count - 1) // 6) * 400)
        return result

    def put(value, socket):
        if isinstance(value, bpy.types.NodeSocket):
            links.new(value, socket)
        else:
            socket.default_value = value

    def vector(operation, a, b):
        n = node("ShaderNodeVectorMath")
        n.operation = operation
        put(a, n.inputs[0])
        put(b, n.inputs["Scale"] if operation == "SCALE" else n.inputs[1])
        return n.outputs[0]

    def input_socket(panel, name, kind, default, minimum=None, maximum=None):
        socket = tree.interface.new_socket(
            name=name, in_out="INPUT", socket_type=kind, parent=panel
        )
        socket.default_value = default
        if minimum is not None:
            socket.min_value, socket.max_value = minimum, maximum
        socket.description = name + (
            " (Blender meters, Z up)" if kind == "NodeSocketVector" else ""
        )
        return group_in.outputs[name]

    panel = tree.interface.new_panel("Bases and mound")
    positions = {}
    for name, point in {
        "Home": (0, -8.8, 0),
        "First": (8.8, 0, 0),
        "Second": (0, 8.8, 0),
        "Third": (-8.8, 0, 0),
        "Mound": (0, 0, 0),
    }.items():
        positions[name] = input_socket(panel, name, "NodeSocketVector", point)
    base_size = input_socket(panel, "Base Size", "NodeSocketFloat", 0.7, 0.2, 1.5)
    panel = tree.interface.new_panel("Outfield")
    depth = input_socket(panel, "Fence Depth", "NodeSocketFloat", 38, 25, 65)
    flat = input_socket(panel, "Fence Flat Half Width", "NodeSocketFloat", 12, 5, 25)
    radius = input_socket(panel, "Fence Corner Radius", "NodeSocketFloat", 20, 8, 28)
    height = input_socket(panel, "Fence Height", "NodeSocketFloat", 1.12, 0.5, 5)
    panel = tree.interface.new_panel("Lines and ground")
    line_width = input_socket(
        panel, "Line Radius", "NodeSocketFloat", 0.035, 0.01, 0.15
    )
    foul_length = input_socket(
        panel, "Foul Line Length", "NodeSocketFloat", 40.8, 20, 70
    )
    ground_size = input_socket(
        panel, "Ground Size", "NodeSocketVector", (110, 100, 0.4)
    )
    panel = tree.interface.new_panel("Dugouts")
    dugouts = []
    for name, x, angle in [
        ("Visitors", -10.8, -math.pi / 4),
        ("Home Team", 10.8, math.pi / 4),
    ]:
        pos = input_socket(panel, name + " Dugout", "NodeSocketVector", (x, -7.2, 0))
        yaw = input_socket(
            panel, name + " Rotation", "NodeSocketFloat", angle, -math.pi, math.pi
        )
        tree.interface.items_tree[name + " Rotation"].subtype = "ANGLE"
        dugouts.append((pos, yaw))
    dugout_size = input_socket(
        panel, "Dugout Size", "NodeSocketVector", (13.6, 1.4, 0.8)
    )

    def material(name, color):
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = (*color, 1)
        shader = next(
            node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED"
        )
        linear = tuple(
            c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color
        )
        shader.inputs["Base Color"].default_value = (*linear, 1)
        shader.inputs["Roughness"].default_value = 1.0
        return mat

    grass = material("Field Grass", (0.22, 0.40, 0.16))
    dirt = material("Field Dirt", (0.48, 0.30, 0.15))
    chalk = material("Field Chalk", (0.9, 0.88, 0.8))
    fence_material = material("Field Fence", (0.10, 0.22, 0.25))
    benches = [
        material("Visitors Dugout", (0.65, 0.36, 0.05)),
        material("Home Dugout", (0.06, 0.28, 0.55)),
    ]

    def finish(geometry, mat):
        n = node("GeometryNodeSetMaterial")
        put(geometry, n.inputs["Geometry"])
        n.inputs["Material"].default_value = mat
        links.new(n.outputs[0], join.inputs[0])

    def box(size, position, mat, rotation=(0, 0, 0)):
        cube = node("GeometryNodeMeshCube")
        put(size, cube.inputs["Size"])
        transform = node("GeometryNodeTransform")
        put(cube.outputs["Mesh"], transform.inputs["Geometry"])
        put(position, transform.inputs["Translation"])
        put(rotation, transform.inputs["Rotation"])
        finish(transform.outputs[0], mat)

    branch("Ground")
    box(ground_size, (0, 4, -0.22), grass)
    branch("Bases")
    size = node("ShaderNodeCombineXYZ")
    put(base_size, size.inputs["X"])
    put(base_size, size.inputs["Y"])
    size.inputs["Z"].default_value = 0.12
    for name in ["Home", "First", "Second", "Third"]:
        box(
            size.outputs[0],
            vector("ADD", positions[name], (0, 0, 0.09)),
            chalk,
            (0, 0, math.pi / 4),
        )
    box((0.6, 0.2, 0.08), vector("ADD", positions["Mound"], (0, 0, 0.09)), chalk)

    def source_geometry(obj):
        obj.hide_render = True
        obj.hide_set(True)
        info = node("GeometryNodeObjectInfo")
        info.inputs["Object"].default_value = obj
        return info.outputs["Geometry"]

    branch("Dirt follows the four base positions")
    template = mesh_object("Infield Template", [(0, 0, 0)] * 4, [(0, 1, 2, 3)], sources)
    index = node("GeometryNodeInputIndex").outputs[0]
    point = positions["Home"]
    for i, name in enumerate(["First", "Second", "Third"], 1):
        compare = node("ShaderNodeMath")
        compare.operation = "COMPARE"
        put(index, compare.inputs[0])
        compare.inputs[1].default_value = i
        switch = node("GeometryNodeSwitch")
        switch.input_type = "VECTOR"
        put(compare.outputs[0], switch.inputs["Switch"])
        put(point, switch.inputs["False"])
        put(positions[name], switch.inputs["True"])
        point = switch.outputs[0]
    set_pos = node("GeometryNodeSetPosition")
    put(source_geometry(template), set_pos.inputs["Geometry"])
    put(point, set_pos.inputs["Position"])
    set_pos.inputs["Offset"].default_value = (0, 0, 0.015)
    finish(set_pos.outputs[0], dirt)

    branch("Base paths and foul lines")
    profile = node("GeometryNodeCurvePrimitiveCircle")
    profile.inputs["Resolution"].default_value = 4
    put(line_width, profile.inputs["Radius"])

    def line(start, end):
        curve = node("GeometryNodeCurvePrimitiveLine")
        put(vector("ADD", start, (0, 0, 0.055)), curve.inputs["Start"])
        put(vector("ADD", end, (0, 0, 0.055)), curve.inputs["End"])
        mesh = node("GeometryNodeCurveToMesh")
        put(curve.outputs[0], mesh.inputs["Curve"])
        put(profile.outputs["Curve"], mesh.inputs["Profile Curve"])
        finish(mesh.outputs["Mesh"], chalk)

    for a, b in [
        ("Home", "First"),
        ("First", "Second"),
        ("Second", "Third"),
        ("Third", "Home"),
    ]:
        line(positions[a], positions[b])
    for base in ["First", "Third"]:
        direction = vector(
            "NORMALIZE",
            vector("SUBTRACT", positions[base], positions["Home"]),
            (0, 0, 0),
        )
        end = vector("ADD", positions["Home"], vector("SCALE", direction, foul_length))
        line(positions["Home"], end)

    branch("Fence: flat center and round corners")
    # Each template vertex stores linear coefficients for the exposed dimensions.
    coefficients = [(-1, -1, 0, 0, -7.2)]
    for side in [-1, 1]:
        for i in range(17):
            angle = (
                (math.pi - i * math.pi / 32)
                if side == -1
                else (math.pi / 2 - i * math.pi / 32)
            )
            coefficients.append((side, math.cos(angle), math.sin(angle) - 1, 1, 0))
    coefficients.append((1, 1, 0, 0, -7.2))
    verts, faces = [], []
    attributes = {name: [] for name in ["flat", "radius", "depth", "height"]}
    for sign, rx, ry, dy, offset in coefficients:
        for z in [0, 1]:
            verts.append((0, offset, 0))
            for name, value in {
                "flat": (sign, 0, 0),
                "radius": (rx, ry, 0),
                "depth": (0, dy, 0),
                "height": (0, 0, z),
            }.items():
                attributes[name].append(value)
    for i in range(len(coefficients) - 1):
        j = i * 2
        faces.append((j, j + 2, j + 3, j + 1))
    template = mesh_object("Fence Template", verts, faces, sources)
    for name, values in attributes.items():
        attr = template.data.attributes.new(name, "FLOAT_VECTOR", "POINT")
        for item, value in zip(attr.data, values):
            item.vector = value
    point = vector(
        "ADD", node("GeometryNodeInputPosition").outputs[0], positions["Home"]
    )
    for name, control in [
        ("flat", flat),
        ("radius", radius),
        ("depth", depth),
        ("height", height),
    ]:
        attribute = node("GeometryNodeInputNamedAttribute", name)
        attribute.data_type = "FLOAT_VECTOR"
        attribute.inputs["Name"].default_value = name
        point = vector(
            "ADD", point, vector("SCALE", attribute.outputs["Attribute"], control)
        )
    set_pos = node("GeometryNodeSetPosition")
    put(source_geometry(template), set_pos.inputs["Geometry"])
    put(point, set_pos.inputs["Position"])
    finish(set_pos.outputs[0], fence_material)

    branch("Dugouts")
    for (pos, yaw), mat in zip(dugouts, benches):
        rotation = node("ShaderNodeCombineXYZ")
        put(yaw, rotation.inputs["Z"])
        box(dugout_size, vector("ADD", pos, (0, 0, 0.4)), mat, rotation.outputs[0])

    top = 0
    for group in [n for n in nodes if n.type == "FRAME"]:
        children = [n for n in nodes if n.parent == group]
        group.location = (0, top)
        for i, child in enumerate(children):
            child.location = ((i % 6) * 260, -(i // 6) * 400)
        top -= math.ceil(len(children) / 6) * 400 + 200

    # Blender 5.2 stores modifier inputs as RNA properties, not ID properties.
    for socket in tree.interface.items_tree:
        if socket.item_type == "SOCKET" and socket.in_out == "INPUT":
            getattr(
                modifier.properties.inputs, socket.identifier
            ).value = socket.default_value
    field.update_tag()
    bpy.context.view_layer.update()

    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    field.select_set(True)
    bpy.context.view_layer.objects.active = field
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_distance = 85
                area.spaces.active.region_3d.view_location = (0, 5, 0)
                area.spaces.active.region_3d.view_rotation = Quaternion(
                    (1, 0, 0), math.radians(30)
                )
                area.spaces.active.shading.color_type = "MATERIAL"
            elif area.type == "PROPERTIES":
                area.spaces.active.context = "MODIFIER"
    scene["field_coordinate_mapping"] = (
        "Blender (x, y, z) = simulation (x * .04, -y * .04, height * .04)"
    )
    sys.path.insert(0, str(Path(__file__).parent))
    from dugouts import install

    install(field)
    path = ROOT / "art/blender/baseball_field.blend"
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    evaluated = field.evaluated_get(bpy.context.evaluated_depsgraph_get())
    print(
        {
            "file": str(path),
            "nodes": len(nodes),
            "vertices": len(evaluated.data.vertices),
            "faces": len(evaluated.data.polygons),
        }
    )


if __name__ == "__main__":
    build()

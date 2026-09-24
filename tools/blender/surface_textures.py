"""Add tiled field textures and a proper home-plate area to the saved node field."""

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
TEXTURES = ROOT / "art/blender/textures"
UV_NAME = "UVMap"
ATLAS_PATCHES = 8
ATLAS_TILE_MAX = 240.0


def textured_material(name, image_name, color):
    path = TEXTURES / image_name
    if not path.is_file():
        raise FileNotFoundError(path)
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    for old in list(bpy.data.images):
        if old.name == image_name and old.users == 0:
            bpy.data.images.remove(old)
    image = bpy.data.images.load(str(path), check_existing=False)
    image.pack()
    image.filepath = f"//textures/{image_name}"
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = UV_NAME
    uv.location = (-560, 0)
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.extension = "REPEAT"
    texture.location = (-330, 0)
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Roughness"].default_value = 1.0
    shader.location = (-70, 0)
    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (240, 0)
    links.new(uv.outputs["UV"], texture.inputs["Vector"])
    links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    links.new(shader.outputs[0], output.inputs["Surface"])
    return material


def home_plate_template():
    name = "Home Plate Template"
    existing = bpy.data.objects.get(name)
    if existing is not None:
        return existing
    sources = bpy.data.collections["Field Sources (do not export)"]
    outline = [
        (-0.42, 0.4),
        (-0.42, -0.02),
        (0.0, -0.46),
        (0.42, -0.02),
        (0.42, 0.4),
    ]
    vertices = [(x, y, 0.11) for x, y in outline] + [
        (x, y, 0.025) for x, y in outline
    ]
    faces = [tuple(range(5)), tuple(range(9, 4, -1))]
    faces += [
        (index, index + 5, (index + 1) % 5 + 5, (index + 1) % 5)
        for index in range(5)
    ]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    sources.objects.link(obj)
    obj.hide_render = True
    obj.hide_set(True)
    return obj


def install(field):
    """Install on v04 or update the v05 materials to larger varied textures."""
    modifier = field.modifiers["Field Controls"]
    group = modifier.node_group
    version = group.get("surface_textures_version", 0)
    if version >= 1:
        for name, image_name, color in (
            ("Field Grass", "grass_varied.png", (0.29, 0.38, 0.18)),
            ("Field Dirt", "dirt_varied.png", (0.50, 0.46, 0.36)),
            ("Field Chalk Dirt", "chalk_dirt_varied.png", (0.92, 0.90, 0.84)),
        ):
            textured_material(name, image_name, color)
        if version >= 2:
            for name in ("Grass Tile Size", "Dirt Tile Size", "Chalk Tile Size"):
                group.interface.items_tree[name].max_value = ATLAS_TILE_MAX
            field.update_tag()
            bpy.context.view_layer.update()
            print("Refreshed packed field textures")
            return
        tile_names = ("Grass Tile Size", "Dirt Tile Size", "Chalk Tile Size")
        values = {
            name: getattr(modifier.properties.inputs, group.interface.items_tree[name].identifier).value
            for name in tile_names
        }
        for name in tile_names:
            socket = group.interface.items_tree[name]
            socket.max_value = ATLAS_TILE_MAX
            socket.default_value *= ATLAS_PATCHES
        bpy.context.view_layer.update()
        for name in tile_names:
            socket = group.interface.items_tree[name]
            getattr(modifier.properties.inputs, socket.identifier).value = values[name] * ATLAS_PATCHES
        for image in list(bpy.data.images):
            if image.name in {"grass.png", "dirt.png", "chalk_dirt.png"} and image.users == 0:
                bpy.data.images.remove(image)
        group["surface_textures_version"] = 2
        group.name = "GN_BaseballField_v06"
        field.update_tag()
        bpy.context.view_layer.update()
        print("Updated field textures to varied atlas images")
        return
    nodes, links = group.nodes, group.links
    input_node = next(node for node in nodes if node.type == "GROUP_INPUT")
    output_node = next(node for node in nodes if node.type == "GROUP_OUTPUT")
    join = output_node.inputs["Geometry"].links[0].from_node
    ground_frame = next(node for node in nodes if node.type == "FRAME" and node.label == "Ground")
    dirt_frame = next(
        node for node in nodes if node.type == "FRAME" and node.label == "Dirt follows the four base positions"
    )
    lines_frame = next(
        node for node in nodes if node.type == "FRAME" and node.label == "Base paths and foul lines"
    )
    bases_frame = next(node for node in nodes if node.type == "FRAME" and node.label == "Bases")

    grass = textured_material("Field Grass", "grass_varied.png", (0.29, 0.38, 0.18))
    dirt = textured_material("Field Dirt", "dirt_varied.png", (0.50, 0.46, 0.36))
    chalk_dirt = textured_material(
        "Field Chalk Dirt", "chalk_dirt_varied.png", (0.92, 0.90, 0.84)
    )

    ground_panel = next(
        item for item in group.interface.items_tree
        if item.item_type == "PANEL" and item.name == "Lines and ground"
    )
    batter_panel = group.interface.new_panel("Batter's area")
    defaults = {}

    def control(name, value, minimum, maximum, panel):
        socket = group.interface.new_socket(
            name=name, in_out="INPUT", socket_type="NodeSocketFloat", parent=panel
        )
        socket.default_value = value
        socket.min_value = minimum
        socket.max_value = maximum
        defaults[socket.identifier] = value
        return input_node.outputs[name]

    grass_tile = control("Grass Tile Size", 32.0, 0.25, ATLAS_TILE_MAX, ground_panel)
    dirt_tile = control("Dirt Tile Size", 20.0, 0.25, ATLAS_TILE_MAX, ground_panel)
    chalk_tile = control("Chalk Tile Size", 10.0, 0.25, ATLAS_TILE_MAX, ground_panel)
    margin = control("Infield Dirt Margin", 2.2, 0.0, 8.0, ground_panel)
    pad_radius = control("Batter Dirt Radius", 3.2, 1.5, 6.0, batter_panel)
    box_width = control("Batter Box Width", 1.1, 0.6, 2.0, batter_panel)
    box_length = control("Batter Box Length", 2.0, 1.0, 3.0, batter_panel)
    box_offset = control("Batter Box Offset", 1.2, 0.8, 2.5, batter_panel)

    def make(kind, frame, label, x, y):
        result = nodes.new(kind)
        result.parent = frame
        result.label = label
        result.location = (x, y)
        return result

    def put(value, socket):
        if isinstance(value, bpy.types.NodeSocket):
            links.new(value, socket)
        else:
            socket.default_value = value

    def vector(operation, first, second, frame, label, x, y):
        result = make("ShaderNodeVectorMath", frame, label, x, y)
        result.operation = operation
        put(first, result.inputs[0])
        put(second, result.inputs["Scale"] if operation == "SCALE" else result.inputs[1])
        return result.outputs[0]

    def plus(a, b, frame, label, x, y):
        return vector("ADD", a, b, frame, label, x, y)

    def uv_field(tile, name, y):
        reciprocal = make("ShaderNodeMath", uv_frame, name + " repeats", -600, y)
        reciprocal.operation = "DIVIDE"
        reciprocal.inputs[0].default_value = 1.0
        put(tile, reciprocal.inputs[1])
        scaled = make("ShaderNodeVectorMath", uv_frame, name + " XY UV", -280, y)
        scaled.operation = "SCALE"
        put(position.outputs[0], scaled.inputs[0])
        put(reciprocal.outputs[0], scaled.inputs["Scale"])
        return scaled.outputs[0]

    def store_uv(source, uv, frame, label, x, y):
        store = make("GeometryNodeStoreNamedAttribute", frame, label, x, y)
        store.data_type = "FLOAT2"
        store.domain = "CORNER"
        store.inputs["Name"].default_value = UV_NAME
        put(source, store.inputs["Geometry"])
        put(uv, store.inputs["Value"])
        return store.outputs["Geometry"]

    def insert_uv(surface, uv, label, x, y):
        incoming = surface.inputs["Geometry"].links[0]
        source = incoming.from_socket
        links.remove(incoming)
        links.new(store_uv(source, uv, surface.parent, label, x, y), surface.inputs["Geometry"])

    uv_frame = nodes.new("NodeFrame")
    uv_frame.label = "Texture UVs: XY metres per repeat"
    uv_frame.location = (0, min(node.location.y for node in nodes if node.type == "FRAME") - 900)
    position = make("GeometryNodeInputPosition", uv_frame, "Surface position", -850, 0)
    grass_uv = uv_field(grass_tile, "Grass", -120)
    dirt_uv = uv_field(dirt_tile, "Dirt", -420)
    chalk_uv = uv_field(chalk_tile, "Chalk", -720)

    grass_surface = next(
        node for node in nodes
        if node.parent == ground_frame and node.type == "SET_MATERIAL"
    )
    grass_surface.inputs["Material"].default_value = grass
    insert_uv(grass_surface, grass_uv, "Grass UVMap", 1800, -100)

    dirt_surface = next(
        node for node in nodes
        if node.parent == dirt_frame and node.type == "SET_MATERIAL"
    )
    dirt_surface.inputs["Material"].default_value = dirt
    set_position = next(
        node for node in nodes
        if node.parent == dirt_frame and node.type == "SET_POSITION"
    )
    old_link = set_position.inputs["Position"].links[0]
    base_point = old_link.from_socket
    links.remove(old_link)
    infield_sum = plus(
        input_node.outputs["Home"], input_node.outputs["First"],
        dirt_frame, "Home + first", 1500, -500
    )
    infield_sum_2 = plus(
        input_node.outputs["Second"], input_node.outputs["Third"],
        dirt_frame, "Second + third", 1500, -750
    )
    center = vector(
        "SCALE",
        plus(infield_sum, infield_sum_2, dirt_frame, "Infield sum", 1800, -550),
        0.25, dirt_frame, "Infield center", 2050, -550
    )
    outward = vector(
        "NORMALIZE",
        vector("SUBTRACT", base_point, center, dirt_frame, "From center", 2300, -550),
        (0, 0, 0), dirt_frame, "Outside bases", 2550, -550
    )
    extension = vector(
        "SCALE", outward, margin, dirt_frame, "Dirt margin", 2800, -550
    )
    put(plus(base_point, extension, dirt_frame, "Expanded dirt", 3050, -550),
        set_position.inputs["Position"])
    insert_uv(dirt_surface, dirt_uv, "Dirt UVMap", 1800, -100)

    profile = next(
        node for node in nodes
        if node.parent == lines_frame and node.type == "CURVE_PRIMITIVE_CIRCLE"
    )
    chalk_surfaces = [
        node for node in list(nodes)
        if node.parent == lines_frame and node.type == "SET_MATERIAL"
    ]
    for index, surface in enumerate(chalk_surfaces):
        surface.inputs["Material"].default_value = chalk_dirt
        insert_uv(surface, chalk_uv, f"Path {index + 1} UVMap", 2250, -index * 280)

    batter_frame = nodes.new("NodeFrame")
    batter_frame.label = "Batter's dirt, boxes and home plate"
    batter_frame.location = (0, uv_frame.location.y - 1200)
    circle = make("GeometryNodeMeshCircle", batter_frame, "Home dirt pad", 0, 0)
    circle.fill_type = "NGON"
    circle.inputs["Vertices"].default_value = 64
    put(pad_radius, circle.inputs["Radius"])
    pad = make("GeometryNodeTransform", batter_frame, "At home", 260, 0)
    put(circle.outputs["Mesh"], pad.inputs["Geometry"])
    put(plus(input_node.outputs["Home"], (0, 0, 0.024), batter_frame,
             "Pad height", 0, -270), pad.inputs["Translation"])
    pad_surface = make("GeometryNodeSetMaterial", batter_frame, "Dirt at home", 800, 0)
    put(store_uv(pad.outputs[0], dirt_uv, batter_frame, "Pad UVMap", 530, 0),
        pad_surface.inputs["Geometry"])
    pad_surface.inputs["Material"].default_value = dirt
    links.new(pad_surface.outputs[0], join.inputs[0])

    rectangle = make("GeometryNodeCurvePrimitiveQuadrilateral", batter_frame,
                     "Two batter boxes", 0, -650)
    rectangle.mode = "RECTANGLE"
    put(box_width, rectangle.inputs["Width"])
    put(box_length, rectangle.inputs["Height"])
    for side, row in [(-1, -600), (1, -1150)]:
        offset_x = make("ShaderNodeMath", batter_frame,
                        "Left" if side < 0 else "Right", 0, row - 250)
        offset_x.operation = "MULTIPLY"
        put(box_offset, offset_x.inputs[0])
        offset_x.inputs[1].default_value = float(side)
        offset = make("ShaderNodeCombineXYZ", batter_frame, "Box offset", 250, row - 250)
        put(offset_x.outputs[0], offset.inputs["X"])
        offset.inputs["Y"].default_value = -0.15
        offset.inputs["Z"].default_value = 0.07
        moved = make("GeometryNodeTransform", batter_frame, "At home plate", 550, row)
        put(rectangle.outputs[0], moved.inputs["Geometry"])
        put(plus(input_node.outputs["Home"], offset.outputs[0], batter_frame,
                 "Box center", 500, row - 250), moved.inputs["Translation"])
        outline = make("GeometryNodeCurveToMesh", batter_frame, "Chalk outline", 800, row)
        put(moved.outputs[0], outline.inputs["Curve"])
        put(profile.outputs["Curve"], outline.inputs["Profile Curve"])
        shade = make("GeometryNodeSetMaterial", batter_frame, "Chalky dirt", 1350, row)
        put(store_uv(outline.outputs["Mesh"], chalk_uv, batter_frame,
                     "Box UVMap", 1080, row), shade.inputs["Geometry"])
        shade.inputs["Material"].default_value = chalk_dirt
        links.new(shade.outputs[0], join.inputs[0])

    old_home = nodes.get("Set Material.001")
    if old_home is None or old_home.parent != bases_frame:
        raise RuntimeError("Expected the original home-base cube in the Bases frame")
    home_transform = old_home.inputs["Geometry"].links[0].from_node
    home_cube = home_transform.inputs["Geometry"].links[0].from_node
    home_position = home_transform.inputs["Translation"].links[0].from_node
    for node in [old_home, home_transform, home_cube, home_position]:
        nodes.remove(node)
    template = home_plate_template()
    info = make("GeometryNodeObjectInfo", batter_frame, "Pentagonal plate source", 0, -1800)
    info.inputs["Object"].default_value = template
    plate = make("GeometryNodeTransform", batter_frame, "Plate at home", 540, -1800)
    put(info.outputs["Geometry"], plate.inputs["Geometry"])
    put(input_node.outputs["Home"], plate.inputs["Translation"])
    relative_size = make("ShaderNodeMath", batter_frame, "Base size", 0, -2050)
    relative_size.operation = "DIVIDE"
    put(input_node.outputs["Base Size"], relative_size.inputs[0])
    relative_size.inputs[1].default_value = 0.7
    size = make("ShaderNodeCombineXYZ", batter_frame, "Plate scale", 270, -2050)
    for axis in "XYZ":
        put(relative_size.outputs[0], size.inputs[axis])
    put(size.outputs[0], plate.inputs["Scale"])
    plate_surface = make("GeometryNodeSetMaterial", batter_frame, "White home plate", 800, -1800)
    put(plate.outputs[0], plate_surface.inputs["Geometry"])
    plate_surface.inputs["Material"].default_value = bpy.data.materials["Field Chalk"]
    links.new(plate_surface.outputs[0], join.inputs[0])

    bpy.context.view_layer.update()
    for identifier, value in defaults.items():
        getattr(modifier.properties.inputs, identifier).value = value
    group["surface_textures_version"] = 2
    group.name = "GN_BaseballField_v06"
    field.update_tag()
    bpy.context.view_layer.update()
    evaluated = field.evaluated_get(bpy.context.evaluated_depsgraph_get())
    print(
        {"node_group": group.name, "vertices": len(evaluated.data.vertices),
         "faces": len(evaluated.data.polygons)}
    )


if __name__ == "__main__":
    bpy.context.preferences.filepaths.save_version = 0
    install(bpy.data.objects["Baseball Field"])
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)

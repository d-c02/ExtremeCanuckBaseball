"""A small replaceable cutout texture and metre-scaled UVs for the backstop."""

from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]


def material():
    path = ROOT / "assets/field/backstop_chainlink.png"
    if path.exists():
        image = bpy.data.images.load(str(path), check_existing=True)
    else:
        size = 128
        image = bpy.data.images.new(
            "Backstop Chainlink", width=size, height=size, alpha=True
        )
        pixels = []
        for y in range(size):
            for x in range(size):
                distance = min(
                    abs((x - y + size / 2) % size - size / 2),
                    abs((x + y + size / 2) % size - size / 2),
                )
                alpha = max(0.0, min(1.0, 8.0 - distance))
                grey = 0.32 + 0.26 * max(0.0, 1.0 - distance / 8.0)
                pixels.extend((grey, grey, grey, alpha))
        image.pixels.foreach_set(pixels)
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save()
    image.pack()
    result = bpy.data.materials.get("Backstop Chainlink") or bpy.data.materials.new(
        "Backstop Chainlink"
    )
    result.surface_render_method = "DITHERED"
    result.use_backface_culling = False
    nodes, links = result.node_tree.nodes, result.node_tree.links
    nodes.clear()
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.extension = "REPEAT"
    texture.location = (-500, 0)
    cutout = nodes.new("ShaderNodeMath")
    cutout.operation = "GREATER_THAN"
    cutout.inputs[1].default_value = 0.5
    cutout.location = (-250, -180)
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Metallic"].default_value = 0.65
    shader.inputs["Roughness"].default_value = 0.6
    shader.location = (0, 0)
    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (320, 0)
    links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    links.new(texture.outputs["Alpha"], cutout.inputs[0])
    links.new(cutout.outputs[0], shader.inputs["Alpha"])
    links.new(shader.outputs[0], output.inputs["Surface"])
    return result


def add_uvs(group):
    if any(
        n.type == "STORE_NAMED_ATTRIBUTE" and n.inputs["Name"].default_value == "UVMap"
        for n in group.nodes
    ):
        return
    nodes, links = group.nodes, group.links
    inputs = next(n for n in nodes if n.type == "GROUP_INPUT")
    surface = next(n for n in nodes if n.type == "SET_MATERIAL")
    source = surface.inputs["Geometry"].links[0].from_socket
    position = nodes.new("GeometryNodeInputPosition").outputs[0]

    def vector(operation, a, b):
        node = nodes.new("ShaderNodeVectorMath")
        node.operation = operation
        links.new(a, node.inputs[0])
        links.new(b, node.inputs[1])
        return node.outputs["Value"] if operation == "DOT_PRODUCT" else node.outputs[0]

    delta = vector("SUBTRACT", inputs.outputs["End"], inputs.outputs["Start"])
    normal = nodes.new("ShaderNodeVectorMath")
    normal.operation = "NORMALIZE"
    links.new(delta, normal.inputs[0])
    relative = vector("SUBTRACT", position, inputs.outputs["Start"])
    along = vector("DOT_PRODUCT", relative, normal.outputs[0])
    split = nodes.new("ShaderNodeSeparateXYZ")
    links.new(relative, split.inputs[0])
    uv = nodes.new("ShaderNodeCombineXYZ")
    for value, axis in [(along, "X"), (split.outputs["Z"], "Y")]:
        scale = nodes.new("ShaderNodeMath")
        scale.operation = "MULTIPLY"
        links.new(value, scale.inputs[0])
        scale.inputs[1].default_value = 1.0
        links.new(scale.outputs[0], uv.inputs[axis])
    store = nodes.new("GeometryNodeStoreNamedAttribute")
    store.data_type = "FLOAT2"
    store.domain = "CORNER"
    store.inputs["Name"].default_value = "UVMap"
    links.new(uv.outputs[0], store.inputs["Value"])
    links.new(source, store.inputs["Geometry"])
    links.new(store.outputs[0], surface.inputs["Geometry"])
    for index, node in enumerate(nodes):
        node.location = ((index % 5) * 220, -(index // 5) * 300)

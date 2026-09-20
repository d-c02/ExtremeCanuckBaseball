"""Add editable perimeter and dugout guards without rebuilding the existing field."""

import bpy
import chainlink

MATERIAL = "Field Barrier"


def barrier_group(sources):
    group = bpy.data.node_groups.new("GN_FieldBarrier_v01", "GeometryNodeTree")
    group.interface.new_socket(
        name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry"
    )
    for name, kind in [
        ("Start", "NodeSocketVector"),
        ("End", "NodeSocketVector"),
        ("Height", "NodeSocketFloat"),
    ]:
        group.interface.new_socket(name=name, in_out="INPUT", socket_type=kind)
    nodes, links = group.nodes, group.links
    inputs = nodes.new("NodeGroupInput")
    output = nodes.new("NodeGroupOutput")
    mesh = bpy.data.meshes.new("Barrier Template")
    mesh.from_pydata([(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)], [], [(0, 1, 2, 3)])
    template = bpy.data.objects.new("Barrier Template", mesh)
    sources.objects.link(template)
    template.hide_render = True
    template.hide_set(True)
    info = nodes.new("GeometryNodeObjectInfo")
    info.inputs["Object"].default_value = template
    position = nodes.new("GeometryNodeInputPosition")
    split = nodes.new("ShaderNodeSeparateXYZ")
    links.new(position.outputs[0], split.inputs[0])

    def vector(op, a, b):
        node = nodes.new("ShaderNodeVectorMath")
        node.operation = op
        links.new(a, node.inputs[0])
        links.new(b, node.inputs["Scale"] if op == "SCALE" else node.inputs[1])
        return node.outputs[0]

    height = nodes.new("ShaderNodeCombineXYZ")
    links.new(inputs.outputs["Height"], height.inputs["Z"])
    along = vector(
        "SCALE",
        vector("SUBTRACT", inputs.outputs["End"], inputs.outputs["Start"]),
        split.outputs["X"],
    )
    point = vector("ADD", inputs.outputs["Start"], along)
    point = vector("ADD", point, vector("SCALE", height.outputs[0], split.outputs["Z"]))
    set_position = nodes.new("GeometryNodeSetPosition")
    links.new(info.outputs["Geometry"], set_position.inputs["Geometry"])
    links.new(point, set_position.inputs["Position"])
    material = nodes.new("GeometryNodeSetMaterial")
    mat = bpy.data.materials.get(MATERIAL)
    if mat is None:
        mat = bpy.data.materials["Field Fence"].copy()
        mat.name = MATERIAL
    material.inputs["Material"].default_value = mat
    tag = nodes.new("GeometryNodeStoreNamedAttribute")
    tag.data_type = "BOOLEAN"
    tag.domain = "FACE"
    tag.inputs["Name"].default_value = "field_barrier"
    tag.inputs["Value"].default_value = True
    links.new(set_position.outputs[0], tag.inputs["Geometry"])
    links.new(tag.outputs[0], material.inputs["Geometry"])
    links.new(material.outputs[0], output.inputs[0])
    for index, node in enumerate(nodes):
        node.location = ((index % 5) * 220, -(index // 5) * 300)
    return group


def install(field):
    modifier = field.modifiers["Field Controls"]
    tree = modifier.node_group
    for old in [
        n
        for n in tree.nodes
        if n.type == "FRAME" and n.label.startswith("Perimeter and dugout")
    ]:
        for child in [n for n in tree.nodes if n.parent == old]:
            tree.nodes.remove(child)
        tree.nodes.remove(old)
    old_depth = tree.interface.items_tree.get("Backstop Depth")
    if old_depth:
        tree.interface.remove(old_depth)
    nodes, links = tree.nodes, tree.links
    inputs = next(n for n in nodes if n.type == "GROUP_INPUT")
    output = next(n for n in nodes if n.type == "GROUP_OUTPUT")
    join = output.inputs[0].links[0].from_node
    frame = nodes.new("NodeFrame")
    frame.label = "Perimeter and dugout guards: stair tops stay open"
    frame.location = (0, -16000)
    panel = tree.interface.items_tree.get(
        "Perimeter guards"
    ) or tree.interface.new_panel("Perimeter guards")
    for name, default, low, high in [
        ("Backstop Height", 3.2, 1.0, 6.0),
        ("Dugout Fence Height", 1.1, 0.5, 2.0),
    ]:
        if tree.interface.items_tree.get(name):
            continue
        socket = tree.interface.new_socket(
            name=name, in_out="INPUT", socket_type="NodeSocketFloat", parent=panel
        )
        socket.default_value = default
        socket.min_value, socket.max_value = low, high
        getattr(modifier.properties.inputs, socket.identifier).value = default
    sources = next(
        c
        for c in bpy.context.scene.collection.children
        if c.name.startswith("Field Sources")
    )
    group = bpy.data.node_groups.get("GN_FieldBarrier_v01") or barrier_group(sources)
    chainlink.add_uvs(group)
    backstop_material = chainlink.material()

    def node(kind):
        result = nodes.new(kind)
        result.parent = frame
        return result

    def put(value, socket):
        if isinstance(value, bpy.types.NodeSocket):
            links.new(value, socket)
        else:
            socket.default_value = value

    def scalar(op, a, b):
        result = node("ShaderNodeMath")
        result.operation = op
        put(a, result.inputs[0])
        put(b, result.inputs[1])
        return result.outputs[0]

    def point(x, y):
        result = node("ShaderNodeCombineXYZ")
        put(x, result.inputs["X"])
        put(y, result.inputs["Y"])
        return result.outputs[0]

    def fence(start, end, height, target, material=None):
        result = node("GeometryNodeGroup")
        result.node_tree = group
        put(start, result.inputs["Start"])
        put(end, result.inputs["End"])
        put(height, result.inputs["Height"])
        geometry = result.outputs[0]
        if material is not None:
            surface = node("GeometryNodeSetMaterial")
            surface.inputs["Material"].default_value = material
            links.new(geometry, surface.inputs["Geometry"])
            geometry = surface.outputs[0]
        links.new(geometry, target)

    half_length = scalar("MULTIPLY", inputs.outputs["Dugout Length"], 0.5)
    half_width = scalar("MULTIPLY", inputs.outputs["Dugout Width"], 0.5)
    half_stair = scalar("MULTIPLY", inputs.outputs["Dugout Stair Width"], 0.5)
    stair_side = scalar("ADD", half_stair, 0.08)
    stair_top = scalar("ADD", half_width, inputs.outputs["Dugout Stair Run"])
    negative_length = scalar("MULTIPLY", half_length, -1)
    negative_width = scalar("MULTIPLY", half_width, -1)
    room = node("GeometryNodeJoinGeometry")
    fence(
        point(negative_length, negative_width),
        point(half_length, negative_width),
        inputs.outputs["Dugout Fence Height"],
        room.inputs[0],
    )
    for sign in [-1, 1]:
        x = scalar("MULTIPLY", half_length, sign)
        opening = scalar("MULTIPLY", stair_side, sign)
        for a, b in [
            (point(x, negative_width), point(x, half_width)),
            (point(x, half_width), point(opening, half_width)),
            (point(opening, half_width), point(opening, stair_top)),
        ]:
            fence(a, b, inputs.outputs["Dugout Fence Height"], room.inputs[0])
    for prefix in ["Visitors", "Home Team"]:
        transform = node("GeometryNodeTransform")
        rotation = node("ShaderNodeCombineXYZ")
        links.new(inputs.outputs[prefix + " Rotation"], rotation.inputs["Z"])
        links.new(room.outputs[0], transform.inputs["Geometry"])
        links.new(rotation.outputs[0], transform.inputs["Rotation"])
        links.new(inputs.outputs[prefix + " Dugout"], transform.inputs["Translation"])
        links.new(transform.outputs[0], join.inputs[0])

    def vector(op, a, b):
        result = node("ShaderNodeVectorMath")
        result.operation = op
        put(a, result.inputs[0])
        put(b, result.inputs["Scale"] if op == "SCALE" else result.inputs[1])
        return result.outputs["Value"] if op == "DOT_PRODUCT" else result.outputs[0]

    def z(value):
        split = node("ShaderNodeSeparateXYZ")
        put(value, split.inputs[0])
        return split.outputs["Z"]

    outfield_frame = next(
        n for n in nodes if n.type == "FRAME" and n.label.startswith("Fence:")
    )
    original = next(
        n for n in nodes if n.parent == outfield_frame and n.type == "SET_POSITION"
    ).outputs[0]
    outfield_material = next(
        n for n in nodes if n.parent == outfield_frame and n.type == "SET_MATERIAL"
    )
    original_position = node("GeometryNodeInputPosition").outputs[0]
    clipped_position = original_position
    sides = []
    for prefix, sign in [("Visitors", -1), ("Home Team", 1)]:
        rotation = node("ShaderNodeCombineXYZ")
        put(inputs.outputs[prefix + " Rotation"], rotation.inputs["Z"])

        def rotate(value, rotation=rotation):
            result = node("ShaderNodeVectorRotate")
            result.rotation_type = "EULER_XYZ"
            put(value, result.inputs["Vector"])
            put(rotation.outputs[0], result.inputs["Rotation"])
            return result.outputs[0]

        def world_point(x, y, prefix=prefix):
            return vector(
                "ADD", inputs.outputs[prefix + " Dugout"], rotate(point(x, y))
            )

        direction = rotate((sign, 0, 0))
        normal = rotate((0, 1, 0))
        inner = world_point(scalar("MULTIPLY", half_length, -sign), half_width)
        outer = world_point(scalar("MULTIPLY", half_length, sign), half_width)
        ray = node("GeometryNodeRaycast")
        put(original, ray.inputs["Target Geometry"])
        put(vector("ADD", outer, (0, 0, 0.1)), ray.inputs["Source Position"])
        put(direction, ray.inputs["Ray Direction"])
        ray.inputs["Ray Length"].default_value = 1000
        hit = vector("SUBTRACT", ray.outputs["Hit Position"], (0, 0, 0.1))
        fence(outer, hit, inputs.outputs["Fence Height"], join.inputs[0])
        sides.append((inner, direction))
        outside = scalar(
            "LESS_THAN",
            vector("DOT_PRODUCT", vector("SUBTRACT", original_position, outer), normal),
            0,
        )
        switch = node("GeometryNodeSwitch")
        switch.input_type = "VECTOR"
        put(outside, switch.inputs["Switch"])
        put(clipped_position, switch.inputs["False"])
        put(
            vector("ADD", hit, vector("MULTIPLY", original_position, (0, 0, 1))),
            switch.inputs["True"],
        )
        clipped_position = switch.outputs[0]

    # Intersect the two dugout-front lines to form the point behind home.
    left, left_direction = sides[0]
    right, right_direction = sides[1]
    distance = scalar(
        "DIVIDE",
        z(vector("CROSS_PRODUCT", vector("SUBTRACT", right, left), right_direction)),
        z(vector("CROSS_PRODUCT", left_direction, right_direction)),
    )
    back = vector("ADD", left, vector("SCALE", left_direction, distance))
    for inner, _ in sides:
        fence(
            inner,
            back,
            inputs.outputs["Backstop Height"],
            join.inputs[0],
            backstop_material,
        )

    trim = node("GeometryNodeSetPosition")
    put(original, trim.inputs["Geometry"])
    put(clipped_position, trim.inputs["Position"])
    merge = node("GeometryNodeMergeByDistance")
    put(trim.outputs[0], merge.inputs["Geometry"])
    merge.inputs["Distance"].default_value = 0.001
    tag = node("GeometryNodeStoreNamedAttribute")
    tag.data_type = "BOOLEAN"
    tag.domain = "FACE"
    tag.inputs["Name"].default_value = "field_outfield"
    tag.inputs["Value"].default_value = True
    put(merge.outputs[0], tag.inputs["Geometry"])
    put(tag.outputs[0], outfield_material.inputs["Geometry"])
    for name in ["Visitors Dugout", "Home Dugout"]:
        material = bpy.data.materials[name]
        material.diffuse_color = (0.48, 0.48, 0.48, 1)
        shader = next(
            n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"
        )
        grey = ((0.48 + 0.055) / 1.055) ** 2.4
        shader.inputs["Base Color"].default_value = (grey, grey, grey, 1)
    for index, child in enumerate(n for n in nodes if n.parent == frame):
        child.location = ((index % 7) * 240, -(index // 7) * 350)
    tree.name = "GN_BaseballField_v04"
    field.update_tag()
    bpy.context.view_layer.update()

"""Parametric recessed rooms and six-step entrances for the field node tree."""

import bpy

CONTROLS = ("Length", "Width", "Depth", "Stair Width", "Stair Run")
DEFAULTS = (13.6, 3.6, 1.2, 2.0, 2.4)


def build_dugout_group(sources):
    group = bpy.data.node_groups.new("GN_SunkenDugout_v01", "GeometryNodeTree")
    for name in ("Geometry", "Excavation"):
        group.interface.new_socket(
            name=name, in_out="OUTPUT", socket_type="NodeSocketGeometry"
        )
    for name, value in zip(CONTROLS, DEFAULTS):
        socket = group.interface.new_socket(
            name=name, in_out="INPUT", socket_type="NodeSocketFloat"
        )
        socket.default_value = value
    inputs = group.nodes.new("NodeGroupInput")
    outputs = group.nodes.new("NodeGroupOutput")
    inputs.location = (-1000, 0)
    outputs.location = (1400, 0)

    def coefficient(const=0, length=0, width=0, depth=0, stair_width=0, stair_run=0):
        return (const, length, width, depth, stair_width, stair_run)

    c = coefficient
    boxes = []
    # Floors, back wall, end walls, front wall with an opening, then stairs.
    boxes.append(((c(), c(), c(-0.08, depth=-1)), (c(length=1), c(width=1), c(0.16))))
    boxes.append(
        (
            (c(), c(width=-0.5), c(0.06, depth=-0.5)),
            (c(length=1), c(0.16), c(0.12, depth=1)),
        )
    )
    for sign in (-1, 1):
        boxes.append(
            (
                (c(length=sign * 0.5), c(), c(0.06, depth=-0.5)),
                (c(0.16), c(width=1), c(0.12, depth=1)),
            )
        )
        boxes.append(
            (
                (
                    c(length=sign * 0.25, stair_width=sign * 0.25),
                    c(width=0.5),
                    c(0.06, depth=-0.5),
                ),
                (c(length=0.5, stair_width=-0.5), c(0.16), c(0.12, depth=1)),
            )
        )
        boxes.append(
            (
                (
                    c(0.08 * sign, stair_width=sign * 0.5),
                    c(width=0.5, stair_run=0.5),
                    c(depth=-0.5),
                ),
                (c(0.16), c(stair_run=1), c(depth=1)),
            )
        )
    for step in range(6):
        fraction = (step + 1) / 6
        boxes.append(
            (
                (
                    c(),
                    c(width=0.5, stair_run=(step + 0.5) / 6),
                    c(-0.08, depth=-1 + fraction / 2),
                ),
                (c(stair_width=1), c(0.002, stair_run=1 / 6), c(0.16, depth=fraction)),
            )
        )
    # A bench against the back wall, away from the walking aisle.
    boxes.append(
        (
            (c(), c(0.4, width=-0.5), c(0.4, depth=-1)),
            (c(-0.6, length=1), c(0.55), c(0.16)),
        )
    )
    cutters = [
        ((c(), c(), c(0.5, depth=-0.5)), (c(length=1), c(width=1), c(1, depth=1))),
        (
            (c(), c(-0.01, width=0.5, stair_run=0.5), c(0.5, depth=-0.5)),
            (c(stair_width=1), c(0.04, stair_run=1), c(1, depth=1)),
        ),
    ]

    def template(name, definitions, output, row):
        vertices, faces = [], []
        coefficients = [[] for _ in CONTROLS]
        for center, size in definitions:
            start = len(vertices)
            for x, y, z in [
                (-1, -1, -1),
                (1, -1, -1),
                (1, 1, -1),
                (-1, 1, -1),
                (-1, -1, 1),
                (1, -1, 1),
                (1, 1, 1),
                (-1, 1, 1),
            ]:
                values = [
                    [a + sign * b / 2 for a, b in zip(pos, extent)]
                    for pos, extent, sign in zip(center, size, (x, y, z))
                ]
                vertices.append(tuple(axis[0] for axis in values))
                for i in range(5):
                    coefficients[i].append(tuple(axis[i + 1] for axis in values))
            for face in [
                (0, 3, 2, 1),
                (4, 5, 6, 7),
                (0, 1, 5, 4),
                (1, 2, 6, 5),
                (2, 3, 7, 6),
                (3, 0, 4, 7),
            ]:
                faces.append(tuple(start + i for i in face))
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(vertices, [], faces)
        for control, values in zip(CONTROLS, coefficients):
            attr = mesh.attributes.new(control, "FLOAT_VECTOR", "POINT")
            for item, value in zip(attr.data, values):
                item.vector = value
        obj = bpy.data.objects.new(name, mesh)
        sources.objects.link(obj)
        obj.hide_render = True
        obj.hide_set(True)
        info = group.nodes.new("GeometryNodeObjectInfo")
        info.location = (-1000, row)
        info.inputs["Object"].default_value = obj
        position = group.nodes.new("GeometryNodeInputPosition").outputs[0]
        for i, control in enumerate(CONTROLS):
            attr = group.nodes.new("GeometryNodeInputNamedAttribute")
            attr.data_type = "FLOAT_VECTOR"
            attr.inputs["Name"].default_value = control
            attr.location = (-700 + i * 350, row)
            scale = group.nodes.new("ShaderNodeVectorMath")
            scale.operation = "SCALE"
            scale.location = (-700 + i * 350, row - 220)
            group.links.new(attr.outputs["Attribute"], scale.inputs[0])
            group.links.new(inputs.outputs[control], scale.inputs["Scale"])
            add = group.nodes.new("ShaderNodeVectorMath")
            add.operation = "ADD"
            add.location = (-700 + i * 350, row - 400)
            group.links.new(position, add.inputs[0])
            group.links.new(scale.outputs[0], add.inputs[1])
            position = add.outputs[0]
        set_pos = group.nodes.new("GeometryNodeSetPosition")
        set_pos.location = (1150, row)
        group.links.new(info.outputs["Geometry"], set_pos.inputs["Geometry"])
        group.links.new(position, set_pos.inputs["Position"])
        group.links.new(set_pos.outputs[0], outputs.inputs[output])

    template("Dugout Structure Template", boxes, "Geometry", -500)
    template("Dugout Excavation Template", cutters, "Excavation", -1300)
    return group


def install(field):
    modifier = field.modifiers["Field Controls"]
    tree = modifier.node_group
    tree.name = "GN_BaseballField_v02"
    nodes, links = tree.nodes, tree.links
    inputs = next(n for n in nodes if n.type == "GROUP_INPUT")
    join = next(n for n in nodes if n.type == "JOIN_GEOMETRY")
    frame = next(n for n in nodes if n.type == "FRAME" and n.label == "Dugouts")
    for child in [n for n in nodes if n.parent == frame]:
        nodes.remove(child)
    panel = tree.interface.items_tree["Dugouts"]
    old = tree.interface.items_tree.get("Dugout Size")
    if old:
        tree.interface.remove(old)
    limits = [(11, 20), (3, 6), (0.6, 2.4), (1.5, 3), (1.8, 4.8)]
    for name, value, (low, high) in zip(CONTROLS, DEFAULTS, limits):
        socket = tree.interface.new_socket(
            name="Dugout " + name,
            in_out="INPUT",
            socket_type="NodeSocketFloat",
            parent=panel,
        )
        socket.default_value = value
        socket.min_value, socket.max_value = low, high
        getattr(modifier.properties.inputs, socket.identifier).value = value
    sources = next(
        c
        for c in bpy.context.scene.collection.children
        if c.name.startswith("Field Sources")
    )
    group = build_dugout_group(sources)
    ground_frame = next(n for n in nodes if n.type == "FRAME" and n.label == "Ground")
    ground_material = next(
        n for n in nodes if n.parent == ground_frame and n.type == "SET_MATERIAL"
    )
    ground_link = ground_material.inputs["Geometry"].links[0]
    ground = ground_link.from_socket
    links.remove(ground_link)
    # Put the slab's top at zero, matching the staircase's top tread.
    ground_transform = ground.node
    ground_transform.inputs["Translation"].default_value = (0, 4, -0.2)
    for index, prefix in enumerate(["Visitors", "Home Team"]):
        instance = nodes.new("GeometryNodeGroup")
        instance.node_tree = group
        instance.parent = frame
        instance.location = (index * 750, 0)
        for name in CONTROLS:
            links.new(inputs.outputs["Dugout " + name], instance.inputs[name])
        rotation = nodes.new("ShaderNodeCombineXYZ")
        rotation.parent = frame
        rotation.location = (index * 750, -300)
        links.new(inputs.outputs[prefix + " Rotation"], rotation.inputs["Z"])
        transformed = []
        for row, output in enumerate(["Geometry", "Excavation"]):
            transform = nodes.new("GeometryNodeTransform")
            transform.parent = frame
            transform.location = (index * 750 + 250, -row * 400)
            links.new(instance.outputs[output], transform.inputs["Geometry"])
            links.new(
                inputs.outputs[prefix + " Dugout"], transform.inputs["Translation"]
            )
            links.new(rotation.outputs[0], transform.inputs["Rotation"])
            transformed.append(transform.outputs[0])
        material = nodes.new("GeometryNodeSetMaterial")
        material.parent = frame
        material.location = (index * 750 + 500, 0)
        material.inputs["Material"].default_value = bpy.data.materials[
            "Visitors Dugout" if index == 0 else "Home Dugout"
        ]
        links.new(transformed[0], material.inputs["Geometry"])
        links.new(material.outputs[0], join.inputs[0])
        boolean = nodes.new("GeometryNodeMeshBoolean")
        boolean.operation = "DIFFERENCE"
        boolean.solver = "EXACT"
        tree.interface_update(bpy.context)
        boolean.inputs["Self Intersection"].default_value = True
        boolean.parent = ground_frame
        boolean.location = (index * 240, -600)
        links.new(ground, boolean.inputs["Mesh 1"])
        links.new(transformed[1], boolean.inputs["Mesh 2"])
        ground = boolean.outputs["Mesh"]
    links.new(ground, ground_material.inputs["Geometry"])
    field.update_tag()
    bpy.context.view_layer.update()

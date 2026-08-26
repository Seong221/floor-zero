import bpy
import math
from pathlib import Path
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "blender"
OUTPUT.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name, color, metallic=0.0, roughness=0.75, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def cube(name, location, scale, mat, collection=None, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    if bevel > 0:
        modifier = obj.modifiers.new("Soft edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    if collection:
        for old_collection in list(obj.users_collection):
            old_collection.objects.unlink(obj)
        collection.objects.link(obj)
    return obj


def cylinder(name, location, radius, depth, mat, collection=None, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    if mat:
        obj.data.materials.append(mat)
    if collection:
        for old_collection in list(obj.users_collection):
            old_collection.objects.unlink(obj)
        collection.objects.link(obj)
    return obj


def text(name, body, location, size, mat, collection=None, align="CENTER"):
    curve = bpy.data.curves.new(name + "Curve", "FONT")
    curve.body = body
    curve.align_x = align
    curve.align_y = "CENTER"
    curve.size = size
    curve.extrude = 0.012
    obj = bpy.data.objects.new(name, curve)
    obj.location = location
    if mat:
        obj.data.materials.append(mat)
    (collection or bpy.context.scene.collection).objects.link(obj)
    return obj


def arrow(name, points, mat, collection=None, width=0.085):
    curve_data = bpy.data.curves.new(name + "Curve", "CURVE")
    curve_data.dimensions = "3D"
    curve_data.bevel_depth = width
    curve_data.bevel_resolution = 3
    spline = curve_data.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bezier_point, point in zip(spline.bezier_points, points):
        bezier_point.co = point
        bezier_point.handle_left_type = "AUTO"
        bezier_point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve_data)
    if mat:
        obj.data.materials.append(mat)
    (collection or bpy.context.scene.collection).objects.link(obj)

    end = Vector(points[-1])
    before = Vector(points[-2])
    direction = (end - before).normalized()
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=width * 2.8, radius2=0.0, depth=width * 6.0, location=end)
    cone = bpy.context.object
    cone.name = name + "Head"
    cone.data.materials.append(mat)
    cone.rotation_mode = "QUATERNION"
    cone.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction)
    if collection:
        for old_collection in list(cone.users_collection):
            old_collection.objects.unlink(cone)
        collection.objects.link(cone)
    return obj


def actor(name, xy, body_mat, label_mat, collection, facing_deg=0.0, label_offset=(0.0, 0.55)):
    root = bpy.data.objects.new(name, None)
    root.location = (xy[0], xy[1], 0)
    root.rotation_euler.z = math.radians(facing_deg)
    collection.objects.link(root)

    legs = cylinder(name + "_Legs", (0, 0, 0.42), 0.28, 0.84, body_mat, collection)
    torso = cylinder(name + "_Torso", (0, 0, 1.22), 0.39, 0.82, body_mat, collection)
    head = cylinder(name + "_Head", (0, 0, 1.84), 0.27, 0.40, label_mat, collection)
    for part in (legs, torso, head):
        part.parent = root
    # A short nose makes facing direction readable in both renders.
    nose = cube(name + "_Facing", (0, -0.30, 1.85), (0.16, 0.34, 0.14), body_mat, collection, 0.03)
    nose.parent = root
    text(
        name + "_Label",
        name,
        (xy[0] + label_offset[0], xy[1] + label_offset[1], 3.15),
        0.34,
        label_mat,
        collection,
    )
    return root


def setup_camera(name, location, target, lens=50.0, ortho=None):
    data = bpy.data.cameras.new(name + "Data")
    camera = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = location
    direction = Vector(target) - Vector(location)
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    data.lens = lens
    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    return camera


def render(scene, camera, filepath, resolution=(1600, 1200)):
    scene.camera = camera
    scene.render.resolution_x = resolution[0]
    scene.render.resolution_y = resolution[1]
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(filepath)
    bpy.ops.render.render(write_still=True)


clear_scene()

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = False
scene.world.color = (0.012, 0.017, 0.025)

# Collections keep the file useful as a real blockout, not only a render.
architecture = bpy.data.collections.new("01_ARCHITECTURE")
furniture = bpy.data.collections.new("02_RESIDENT_FURNITURE")
actors = bpy.data.collections.new("03_ACTORS")
markup = bpy.data.collections.new("04_TACTICAL_MARKUP")
for collection in (architecture, furniture, actors, markup):
    scene.collection.children.link(collection)

mat_wall = material("Wall", (0.16, 0.18, 0.21), roughness=0.92)
mat_floor = material("Floor", (0.09, 0.105, 0.125), roughness=0.88)
mat_corridor = material("CorridorFloor", (0.06, 0.075, 0.095), roughness=0.9)
mat_door = material("Door", (0.25, 0.07, 0.055), metallic=0.55, roughness=0.5)
mat_furniture = material("Furniture", (0.22, 0.15, 0.095), roughness=0.85)
mat_counter = material("Counter", (0.14, 0.18, 0.20), metallic=0.2, roughness=0.72)
mat_partition = material("Partition", (0.12, 0.135, 0.16), roughness=0.85)
mat_knife = material("Knife", (0.6, 0.64, 0.68), metallic=0.85, roughness=0.27)
mat_rusher = material("RusherRed", (0.72, 0.10, 0.075), roughness=0.55)
mat_anchor = material("AnchorOrange", (0.95, 0.38, 0.08), roughness=0.55)
mat_flanker = material("FlankerPurple", (0.48, 0.16, 0.75), roughness=0.55)
mat_player = material("PlayerBlue", (0.05, 0.42, 0.85), roughness=0.5)
mat_label = material("Labels", (0.95, 0.95, 0.92), emission=(0.95, 0.95, 0.92), emission_strength=0.7)
mat_path = material("RusherPath", (1.0, 0.12, 0.04), emission=(1.0, 0.08, 0.02), emission_strength=3.0)
mat_flank_path = material("FlankerPath", (0.66, 0.22, 1.0), emission=(0.45, 0.08, 1.0), emission_strength=2.2)
mat_sight = material("AnchorSight", (1.0, 0.52, 0.08), emission=(1.0, 0.32, 0.02), emission_strength=1.8)
mat_warm = material("UnderDoorLight", (1.0, 0.32, 0.08), emission=(1.0, 0.18, 0.03), emission_strength=5.0)

# Coordinate convention: X is left/right, Y is depth into the residence.
ROOM_W = 10.0
ROOM_D = 9.5
WALL_T = 0.22
WALL_H = 2.9
DOOR_W = 1.50

# Floors.
cube("ResidenceFloor", (0, ROOM_D / 2, -0.10), (ROOM_W, ROOM_D, 0.20), mat_floor, architecture)
cube("CorridorFloor", (0, -4.5, -0.10), (3.2, 9.0, 0.20), mat_corridor, architecture)

# Residence perimeter. The entry wall is split around a realistic 1.5 m door.
cube("EntryWallLeft", (-(ROOM_W + DOOR_W) / 4, 0, WALL_H / 2), ((ROOM_W - DOOR_W) / 2, WALL_T, WALL_H), mat_wall, architecture)
cube("EntryWallRight", ((ROOM_W + DOOR_W) / 4, 0, WALL_H / 2), ((ROOM_W - DOOR_W) / 2, WALL_T, WALL_H), mat_wall, architecture)
cube("LeftWall", (-ROOM_W / 2, ROOM_D / 2, WALL_H / 2), (WALL_T, ROOM_D, WALL_H), mat_wall, architecture)
cube("RightWall", (ROOM_W / 2, ROOM_D / 2, WALL_H / 2), (WALL_T, ROOM_D, WALL_H), mat_wall, architecture)
cube("RearWall", (0, ROOM_D, WALL_H / 2), (ROOM_W, WALL_T, WALL_H), mat_wall, architecture)

# Narrow exterior corridor. It intentionally gives the intruder no lateral preview.
cube("CorridorWallLeft", (-1.6, -4.5, WALL_H / 2), (WALL_T, 9.0, WALL_H), mat_wall, architecture)
cube("CorridorWallRight", (1.6, -4.5, WALL_H / 2), (WALL_T, 9.0, WALL_H), mat_wall, architecture)

# Door swings inward to the resident's right, so the left-hand Rusher pocket remains a blind side.
door = cube("SolidEntryDoor", (0.50, 0.52, 1.22), (DOOR_W, 0.10, 2.44), mat_door, architecture, 0.04)
door.rotation_euler.z = math.radians(-48)
cube("UnderDoorCue", (0, -0.03, 0.018), (DOOR_W, 0.26, 0.036), mat_warm, markup)

# Left-side resident storage: ordinary entrance furniture, never a display table.
cube("CoatShelf", (-2.20, 0.27, 1.34), (2.25, 0.46, 0.10), mat_furniture, furniture, 0.04)
cube("CoatRackBack", (-2.20, 0.10, 1.35), (2.45, 0.10, 2.55), mat_furniture, furniture, 0.03)
for x in (-2.95, -2.55, -2.15, -1.75, -1.35):
    cylinder("CoatHook", (x, 0.02, 1.82), 0.045, 0.24, mat_counter, furniture, vertices=12).rotation_euler.x = math.radians(90)
cube("UtilityKnife", (-1.55, 0.03, 1.48), (0.52, 0.10, 0.055), mat_knife, furniture, 0.02).rotation_euler.y = math.radians(-8)
cube("ShoeBench", (-3.65, 0.72, 0.42), (1.55, 0.56, 0.80), mat_furniture, furniture, 0.05)
cube("EntryBags", (-2.75, 0.68, 0.28), (0.62, 0.44, 0.56), mat_counter, furniture, 0.07)

# Main room furniture establishes daily use while keeping the central push lane empty.
cube("LivingRug", (-1.65, 5.10, 0.015), (4.25, 2.65, 0.03), material("Rug", (0.23, 0.09, 0.07), roughness=1.0), furniture)
cube("Sofa", (-3.60, 6.45, 0.52), (2.25, 0.95, 1.04), mat_furniture, furniture, 0.12)
cube("LowTable", (-1.55, 5.25, 0.38), (1.55, 0.78, 0.76), mat_furniture, furniture, 0.06)
cube("RearStorage", (-2.50, 8.85, 1.05), (4.20, 0.52, 2.10), mat_counter, furniture, 0.04)

# Anchor's work counter is resident furniture first and defender cover second.
cube("AnchorCounter", (2.20, 6.35, 0.72), (3.65, 0.95, 1.44), mat_counter, furniture, 0.07)
cube("CounterTop", (2.20, 6.35, 1.48), (3.85, 1.08, 0.12), mat_furniture, furniture, 0.04)
for x in (0.85, 1.75, 2.65, 3.55):
    cube("CounterDrawer", (x, 5.84, 0.82), (0.72, 0.08, 0.48), mat_furniture, furniture, 0.02)

# Right partition creates a genuine lateral route for the Flanker.
cube("FlankPartition", (3.62, 3.95, 1.25), (0.16, 4.65, 2.50), mat_partition, architecture, 0.03)
cube("SideStorage", (4.35, 7.70, 0.85), (1.05, 2.55, 1.70), mat_furniture, furniture, 0.05)

# Actors. Player faces +Y. Rusher is within one stride of both blade and door blind side.
actor("PLAYER", (0.0, -2.7), mat_player, mat_label, actors, facing_deg=180)
actor("RUSHER", (-1.42, 0.88), mat_rusher, mat_label, actors, facing_deg=-70, label_offset=(0.82, 0.0))
actor("ANCHOR", (2.25, 7.28), mat_anchor, mat_label, actors, facing_deg=180)
actor("FLANKER", (4.25, 5.15), mat_flanker, mat_label, actors, facing_deg=135, label_offset=(-0.58, -0.10))

# Tactical overlays are separate and can be hidden in Blender.
arrow("RusherToBlade", [(-1.42, 0.88, 0.12), (-1.55, 0.52, 0.12), (-1.55, 0.22, 0.12)], mat_path, markup, 0.06)
arrow("RusherCommit", [(-1.42, 0.88, 0.10), (-0.95, 1.20, 0.10), (-0.30, 0.65, 0.10), (0.0, -0.55, 0.10)], mat_path, markup, 0.10)
arrow("FlankerExit", [(4.25, 5.15, 0.10), (4.35, 6.55, 0.10), (4.15, 8.25, 0.10)], mat_flank_path, markup, 0.085)
arrow("AnchorLane", [(2.25, 6.85, 0.09), (1.50, 5.10, 0.09), (0.55, 2.75, 0.09), (0.10, 0.30, 0.09)], mat_sight, markup, 0.045)
text("PlanTitle", "FIRST ROOM / RESIDENT ADVANTAGE", (0, 10.35, 0.03), 0.46, mat_label, markup)
text("EntryLane", "CLEAR ENTRY LANE", (0.15, 3.20, 0.03), 0.33, mat_label, markup)
text("BlindSide", "DOOR-SIDE BLIND POCKET", (-2.65, 1.78, 0.03), 0.27, mat_label, markup)

# Practical lights for the perspective render.
for name, location, color, energy, size in (
    ("EntryWarm", (-1.6, 1.2, 2.55), (1.0, 0.27, 0.09), 650, 1.0),
    ("RoomWarm", (0.0, 5.4, 2.65), (1.0, 0.56, 0.28), 900, 2.0),
    ("CounterLight", (2.1, 6.0, 2.55), (1.0, 0.45, 0.18), 700, 1.2),
    ("CorridorCool", (0.0, -3.7, 2.45), (0.12, 0.42, 1.0), 750, 1.4),
):
    data = bpy.data.lights.new(name + "Data", "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    light = bpy.data.objects.new(name, data)
    light.location = location
    light.rotation_euler = (0, 0, 0)
    scene.collection.objects.link(light)

# Top view is the authoritative plan. Perspective is only a spatial sanity check.
top_camera = setup_camera("TopPlanCamera", (0, 1.6, 20.5), (0, 1.6, 0), ortho=22.0)
perspective_camera = setup_camera("PerspectiveCamera", (-12.8, -12.0, 13.6), (0.0, 3.3, 0.65), lens=52)

# Color management keeps role colors and dark materials readable.
scene.view_settings.look = "AgX - Medium High Contrast"
render(scene, top_camera, OUTPUT / "first_room_top.png", (1600, 1400))

# The perspective is a deliberate architectural cutaway from the Rusher side.
# Hide the near walls and every annotation label, while preserving route arrows.
cutaway_names = ("CorridorWallLeft", "EntryWallLeft", "LeftWall", "CoatRackBack")
for obj in bpy.data.objects:
    if obj.type == "FONT" or obj.name in cutaway_names:
        obj.hide_render = True
render(scene, perspective_camera, OUTPUT / "first_room_perspective.png", (1600, 1050))

# Restore everything in the saved working file; the cutaway only affects the render.
for obj in bpy.data.objects:
    obj.hide_render = False
scene.camera = top_camera
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "first_room_blockout.blend"))

print("Created:")
print(OUTPUT / "first_room_blockout.blend")
print(OUTPUT / "first_room_top.png")
print(OUTPUT / "first_room_perspective.png")

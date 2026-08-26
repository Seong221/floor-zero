"""Opening-floor blockout: player begins on a landing, walks a residential corridor,
passes four separate room doors on the right, and reaches the stair to the next floor."""

import bpy
from pathlib import Path
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "blender"
OUT.mkdir(parents=True, exist_ok=True)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def mat(name, color, emission=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1.0)
    p.inputs["Roughness"].default_value = 0.75
    if emission:
        p.inputs["Emission Color"].default_value = (*color, 1.0)
        p.inputs["Emission Strength"].default_value = emission
    return m


def box(name, location, size, material):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def light(name, location, color, energy):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "RECTANGLE"
    data.size = 1.3
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    bpy.context.collection.objects.link(obj)
    return obj


def camera(name, location, target, ortho=None):
    data = bpy.data.cameras.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    return obj


clear()
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_percentage = 100
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.055, 0.07, 0.10, 1.0)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45

wall = mat("Concrete", (0.12, 0.14, 0.17))
floor = mat("Floor", (0.07, 0.085, 0.11))
door = mat("RoomDoors", (0.24, 0.12, 0.08))
frame = mat("DoorFrames", (0.035, 0.045, 0.06))
step = mat("Stairs", (0.18, 0.22, 0.27))
sign = mat("EmergencyLight", (0.85, 0.24, 0.06), 3.0)

# Y is the long direction. The player starts at the lower landing and walks +Y.
LENGTH, WIDTH, HEIGHT = 42.0, 3.4, 3.1
box("CorridorFloor", (0, LENGTH / 2, -0.1), (WIDTH, LENGTH, 0.2), floor)
# The left wall begins after the turn-in landing and then stays continuous.
box("LeftContinuousWall", (-WIDTH / 2, 22.0, HEIGHT / 2), (0.22, 40.0, HEIGHT), wall)
box("RightBuildingWall", (WIDTH / 2, LENGTH / 2, HEIGHT / 2), (0.22, LENGTH, HEIGHT), wall)
box("Ceiling", (0, LENGTH / 2, HEIGHT), (WIDTH, LENGTH, 0.18), frame)

# The player has already climbed this stair. It comes in from the left, then turns
# right into the corridor, so its final landing does not point straight down the hall.
box("ArrivalLanding", (-2.8, 0.75, -0.1), (2.5, 2.5, 0.2), floor)
for i in range(6):
    box("ArrivalTurnStep%02d" % i, (-5.25 + i * 0.48, 0.75, 0.12 + i * 0.15), (0.48, 2.5, 0.24 + i * 0.30), step)

# Four separate doors, each implying a different occupied room on the right.
for i, y in enumerate((6.5, 16.0, 25.5, 35.0), start=1):
    box("RoomDoor%02d" % i, (WIDTH / 2 - 0.06, y, 1.42), (0.08, 1.36, 2.72), door)
    box("FrameTop%02d" % i, (WIDTH / 2 - 0.15, y, 2.86), (0.22, 1.62, 0.16), frame)
    box("FrameA%02d" % i, (WIDTH / 2 - 0.15, y - 0.77, 1.43), (0.22, 0.14, 2.90), frame)
    box("FrameB%02d" % i, (WIDTH / 2 - 0.15, y + 0.77, 1.43), (0.22, 0.14, 2.90), frame)

# The far stair rises to the next level; it is visible from the corridor before the player reaches it.
box("StairwellLeft", (-1.35, 40.25, HEIGHT / 2), (0.22, 3.5, HEIGHT), wall)
box("StairwellRight", (1.35, 40.25, HEIGHT / 2), (0.22, 3.5, HEIGHT), wall)
for i in range(7):
    box("NextFloorStep%02d" % i, (0, 39.15 + i * 0.34, 0.12 + i * 0.17), (2.48, 0.24 + i * 0.34, 0.34), step)
box("ExitLight", (0, 41.75, 2.8), (1.2, 0.08, 0.25), sign)
# Keep the roof in the .blend, but hide it in review renders so the interior reads.
bpy.data.objects["Ceiling"].hide_render = True

for i, y in enumerate((2.0, 10.0, 18.0, 26.0, 34.0, 39.3)):
    light("CeilingLight%02d" % i, (0, y, 2.82), (0.48, 0.66, 1.0) if i < 4 else (1.0, 0.5, 0.22), 1000)

sun_data = bpy.data.lights.new("ReviewSun", "SUN")
sun_data.energy = 1.2
sun = bpy.data.objects.new("ReviewSun", sun_data)
sun.rotation_euler = (0.45, -0.25, -0.35)
bpy.context.collection.objects.link(sun)

top = camera("TopPlan", (0, 21.0, 45), (0, 21.0, 0), ortho=48)
# A first-person-height check confirms that the doors read down the right side.
perspective = camera("PlayerDirection", (0.0, 1.4, 1.62), (0.0, 34.0, 1.62))

scene.camera = top
scene.render.resolution_x, scene.render.resolution_y = 1200, 1600
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUT / "building_corridor_top.png")
bpy.ops.render.render(write_still=True)

scene.camera = perspective
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
scene.render.filepath = str(OUT / "building_corridor_perspective.png")
bpy.ops.render.render(write_still=True)

scene.camera = top
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "building_corridor_blockout.blend"))
print("Building corridor blockout created")

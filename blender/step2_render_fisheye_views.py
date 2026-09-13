# ============================================================
# step2_render_fisheye_views.py
#
# Directly reads manikin_AreatoPoint.dat and manikin_Point_XYZ.dat
# (tab-delimited text) from data/manikin_model/, places a camera at each
# mesh's (triangular element, Area) centroid, and renders fisheye
# (equidistant-projection) images looking along the mesh's +/- normal
# direction (90 deg / 270 deg). A person compares the two images to judge
# "which direction faces the outside of the body (the room side)", and the
# result is used when compiling Mesh_direction.csv (Area,
# direction[90 or 270]).
#
# For an Area that already has a judgment recorded in Mesh_direction.csv,
# only the correct-direction image is rendered (the unneeded direction is
# not rendered), and any leftover image for the unneeded direction from a
# previous run is deleted.
# For an Area with no judgment yet recorded in Mesh_direction.csv, both
# 90 degrees and 270 degrees are rendered for judging.
#
# No external tools such as R are required; this is self-contained within
# Blender.
#
# Because this repository already includes a completed judgment file
# (blender/Mesh_direction.csv), you normally do not need to re-run this
# script (it is provided to document reproducibility / for applying the
# same process to a different model).
#
# How to use:
#   1. Paste the contents of this file into a new text block in Blender's
#      "Scripting" tab.
#   2. Check/update REPO_DIR (the path where this repository is placed) /
#      START_AREA / END_AREA below (the default for REPO_DIR assumes it is
#      placed directly under D:/github_code_RHF_publish; the defaults for
#      START_AREA/END_AREA are narrowed to 230-240 as a sample).
#   3. Click "Run". Areas whose image already exists are skipped, so you
#      can interrupt and resume the process.
#
# Note: this repository narrows START_AREA, END_AREA to 230-240 as a
#       sample. To process all meshes (1753 of them), change these to
#       START_AREA=1, END_AREA=1753
#       (if Mesh_direction.csv is empty (nothing judged yet), this means
#        1753 x 2 directions = 3506 renders, which takes a long time).
# ============================================================

import bpy
import csv
import math
import mathutils
import os
import time


# ============================================================
# Basic configuration (change to match your environment)
# ============================================================

# Path to the folder where this repository (github_code_RHF_publish) is
# placed. The default assumes it is placed directly under D:.
REPO_DIR = "D:/github_code_RHF_publish"

MANIKIN_MODEL_DIR = REPO_DIR + "/data/manikin_model"
AREA_TO_POINT_PATH = MANIKIN_MODEL_DIR + "/manikin_AreatoPoint.dat"
POINT_XYZ_PATH = MANIKIN_MODEL_DIR + "/manikin_Point_XYZ.dat"

OUTPUT_FOLDER = REPO_DIR + "/blender/fisheye_renders"
DIRECTION_CSV_PATH = REPO_DIR + "/blender/Mesh_direction.csv"

# Areas to process (narrowed to 230-240 as a sample. To process all
# meshes, change to START_AREA=1, END_AREA=1753)
START_AREA = 230
END_AREA = 240


# ============================================================
# Settings to reduce load
# ============================================================

# Number of CPU threads (lower this from 8 -> 6 -> 4 if the PC load is too high)
CPU_THREADS = 4

# Number of Cycles samples
CYCLES_SAMPLES = 16

# Output resolution
RESOLUTION_X = 500
RESOLUTION_Y = 500

# Pause (seconds) after each render
RENDER_INTERVAL = 0.5


def load_mesh_triangles(area_to_point_path, point_xyz_path):
    """Join manikin_AreatoPoint.dat and manikin_Point_XYZ.dat (both
    tab-delimited) and return a list of each Area's 3 vertex coordinates
    and centroid coordinates."""
    points = {}
    with open(point_xyz_path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            points[int(row['Point'])] = (
                float(row['x']), float(row['y']), float(row['z'])
            )

    triangles = []
    with open(area_to_point_path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            area = int(row['Area'])
            vertex_A = points[int(row['PointA'])]
            vertex_B = points[int(row['PointB'])]
            vertex_C = points[int(row['PointC'])]
            center = tuple((vertex_A[i] + vertex_B[i] + vertex_C[i]) / 3 for i in range(3))
            triangles.append({
                'Area': area, 'A': vertex_A, 'B': vertex_B, 'C': vertex_C, 'center': center
            })

    return triangles


def load_mesh_direction(direction_csv_path):
    """Load Mesh_direction.csv (Area, direction[90 or 270]) and return a
    dict mapping Area -> direction ('90'/'270'). An Area is not included
    in the dict if the file does not exist, or if that Area has no
    judgment row yet."""
    direction_data = {}
    if not os.path.exists(direction_csv_path):
        return direction_data

    with open(direction_csv_path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            direction_data[int(row['Area'])] = str(row['direction']).strip()

    return direction_data


# ============================================================
# Create the output folder
# ============================================================

if not os.path.exists(OUTPUT_FOLDER):
    os.makedirs(OUTPUT_FOLDER)


# ============================================================
# Prepare the camera
# ============================================================

if not bpy.data.objects.get("Camera"):
    camera_data = bpy.data.cameras.new("Camera")
    camera = bpy.data.objects.new("Camera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    bpy.context.scene.camera = camera
else:
    camera = bpy.data.objects["Camera"]


# ============================================================
# Scene settings
# ============================================================

scene = bpy.context.scene
scene.camera = camera
scene.render.engine = 'CYCLES'


# ============================================================
# Fisheye camera settings (equidistant projection, 180-degree field of view)
# ============================================================

camera.data.type = 'PANO'

if hasattr(camera.data, "panorama_type"):
    camera.data.panorama_type = 'FISHEYE_EQUIDISTANT'

if hasattr(camera.data, "fisheye_fov"):
    camera.data.fisheye_fov = math.radians(180)

camera.data.lens_unit = 'FOV'
camera.data.angle = math.radians(180)


# ============================================================
# Render settings
# ============================================================

scene.render.image_settings.file_format = 'PNG'
scene.render.resolution_x = RESOLUTION_X
scene.render.resolution_y = RESOLUTION_Y
scene.render.resolution_percentage = 100


# ============================================================
# Cycles load-reduction settings
# ============================================================

scene.cycles.samples = CYCLES_SAMPLES
scene.cycles.max_bounces = 4
scene.cycles.diffuse_bounces = 2
scene.cycles.glossy_bounces = 2
scene.cycles.transmission_bounces = 2
scene.cycles.use_denoising = True
scene.cycles.device = 'CPU'
scene.render.threads_mode = 'FIXED'
scene.render.threads = CPU_THREADS


# ============================================================
# Rendering function
# ============================================================

def render_image(area, center, direction, angle_label):
    output_path = os.path.join(
        OUTPUT_FOLDER,
        f"Area_{area}_fisheye_equidistant_view_{angle_label}.png"
    )

    if os.path.exists(output_path):
        print(f"[SKIP] Area {area} {angle_label} deg already exists")
        return

    camera.location = center

    direction = direction.normalized()
    rot_quat = direction.to_track_quat('Z', 'Y')
    camera.rotation_euler = rot_quat.to_euler()

    scene.render.filepath = output_path

    print(f"[RENDER] Area {area} {angle_label} deg")
    bpy.ops.render.render(write_still=True)
    print(f"[SAVE] {output_path}")

    if RENDER_INTERVAL > 0:
        time.sleep(RENDER_INTERVAL)


def remove_unneeded_image(area, angle_label):
    """Delete the image for a direction that has been determined to be
    unnecessary, if it is still present (e.g. left over from a previous
    run). Returns True if a file was actually deleted, False if there was
    no such file."""
    path = os.path.join(
        OUTPUT_FOLDER,
        f"Area_{area}_fisheye_equidistant_view_{angle_label}.png"
    )
    if os.path.exists(path):
        os.remove(path)
        print(f"[DELETE] Area {area}: removed the unneeded {angle_label}-degree image")
        return True
    return False


# ============================================================
# Load the .dat files and run the rendering
# ============================================================

processed_count = 0
error_count = 0
deleted_count = 0

triangles = load_mesh_triangles(AREA_TO_POINT_PATH, POINT_XYZ_PATH)
direction_data = load_mesh_direction(DIRECTION_CSV_PATH)

for tri in triangles:
    area_num = tri['Area']

    if area_num < START_AREA or area_num > END_AREA:
        continue

    try:
        print()
        print("=" * 60)
        print(f"Area {area_num}")
        print("=" * 60)

        vertex_A = mathutils.Vector(tri['A'])
        vertex_B = mathutils.Vector(tri['B'])
        vertex_C = mathutils.Vector(tri['C'])
        center = mathutils.Vector(tri['center'])

        # ---- Compute the normal vector ----
        edge1 = vertex_B - vertex_A
        edge2 = vertex_C - vertex_A
        normal = edge1.cross(edge2)

        if normal.length < 1e-8:
            print(f"[ERROR] Area {area_num}: normal vector is zero")
            error_count += 1
            continue

        normal.normalize()

        # ---- Canonicalize so the normal points away from the origin
        #      (keeps the 90/270 assignment consistent) ----
        if normal.dot(center) > 0:
            normal = -normal

        # ---- If Mesh_direction.csv already has a judgment, render only
        #      the correct direction, and delete any leftover image for
        #      the unneeded direction ----
        known_direction = direction_data.get(area_num)

        if known_direction in (None, "90"):
            render_image(area_num, center, normal.copy(), "90")
        if known_direction in (None, "270"):
            render_image(area_num, center, -normal, "270")

        if known_direction == "90":
            if remove_unneeded_image(area_num, "270"):
                deleted_count += 1
        elif known_direction == "270":
            if remove_unneeded_image(area_num, "90"):
                deleted_count += 1

        processed_count += 1

    except Exception as e:
        error_count += 1
        print(f"[Unexpected Error] Area {area_num}")
        print("Error:", e)


print()
print("=" * 60)
print("Image generation complete for all meshes")
print("Areas processed:", processed_count)
print("Unneeded images deleted for already-judged Areas:", deleted_count)
print("Errors:", error_count)
print("=" * 60)

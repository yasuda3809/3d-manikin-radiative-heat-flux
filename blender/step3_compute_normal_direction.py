# ============================================================
# step3_compute_normal_direction.py
#
# Directly reads manikin_AreatoPoint.dat and manikin_Point_XYZ.dat
# (tab-delimited text) from data/manikin_model/, and for each mesh
# (triangular element, Area), applies the normal direction judged by a
# human in Step2 (Mesh_direction.csv: 90 = keep the normal as-is, 270 =
# flip the normal), then computes the normal's azimuth (Azimuth) and
# elevation (Elevation).
#
# The output destination is data/manikin_model/Normal_Direction_Result.csv
# itself; this directly overwrites the file that
# 01_mesh_measurement_point_assignment.R reads (overwriting is fine, since
# it is the same file being regenerated).
#
# If you increase the number of corresponding meshes for a different
# model, simply running this script will also update
# data/manikin_model/Normal_Direction_Result.csv.
#
# How to use:
#   1. Paste the contents of this file into a new text block in Blender's
#      "Scripting" tab.
#   2. Check REPO_DIR (the path where this repository is placed) below
#      (the default assumes it is placed directly under
#      D:/github_code_RHF_publish).
#   3. Click "Run" (this script only performs lightweight calculations and
#      does no rendering, so it finishes in a few seconds).
# ============================================================

import bpy
import csv
import math
import mathutils

# ---- Configuration (change to match your environment) ----------------------
# Path to the folder where this repository (github_code_RHF_publish) is
# placed. The default assumes it is placed directly under D:.
REPO_DIR = "D:/github_code_RHF_publish"

MANIKIN_MODEL_DIR = REPO_DIR + "/data/manikin_model"
AREA_TO_POINT_PATH = MANIKIN_MODEL_DIR + "/manikin_AreatoPoint.dat"
POINT_XYZ_PATH = MANIKIN_MODEL_DIR + "/manikin_Point_XYZ.dat"

DIRECTION_CSV_PATH = REPO_DIR + "/blender/Mesh_direction.csv"

# Directly overwrite data/manikin_model/Normal_Direction_Result.csv
OUTPUT_CSV_PATH = MANIKIN_MODEL_DIR + "/Normal_Direction_Result.csv"


def load_mesh_triangles(area_to_point_path, point_xyz_path):
    """Join manikin_AreatoPoint.dat and manikin_Point_XYZ.dat (both
    tab-delimited) and return a list of the 3 vertex coordinates for each
    Area."""
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
            triangles.append({'Area': area, 'A': vertex_A, 'B': vertex_B, 'C': vertex_C})

    return triangles


# ---- Load Mesh_direction.csv (the 90/270 judgment made by a human in Step2) --
direction_data = {}
with open(DIRECTION_CSV_PATH, newline='', encoding='utf-8') as direction_file:
    reader = csv.DictReader(direction_file)
    for row in reader:
        direction_data[int(row['Area'])] = row['direction']

# ---- Load each mesh's 3 vertex coordinates from the .dat files --------------
triangles = load_mesh_triangles(AREA_TO_POINT_PATH, POINT_XYZ_PATH)

# ---- List used to hold the results --------------------------------------
output_data = [["Area", "Direction", "Normal_Z", "Result", "Azimuth", "Elevation"]]

# ---- For each mesh, compute the normal and find its azimuth/elevation -------
for tri in triangles:
    try:
        area_number = tri['Area']

        if area_number not in direction_data:
            continue

        vertex_A = mathutils.Vector(tri['A'])
        vertex_B = mathutils.Vector(tri['B'])
        vertex_C = mathutils.Vector(tri['C'])

        # Compute the normal vector (cross product of two edges)
        edge1 = vertex_B - vertex_A
        edge2 = vertex_C - vertex_A
        normal = edge1.cross(edge2).normalized()

        # Correct the normal's direction according to Mesh_direction.csv's judgment
        direction = direction_data[area_number]
        if direction == '270':
            normal = -normal

        # Determine up/down from the z component of the corrected normal
        if normal.z > 0:
            result = "UpDirection"
        elif normal.z < 0:
            result = "DownDirection"
        else:
            result = "Level"

        # Compute the azimuth (Azimuth) and elevation (Elevation)
        azimuth = math.degrees(math.atan2(normal.y, normal.x))
        elevation = math.degrees(math.asin(normal.z))

        output_data.append([
            area_number, direction, round(normal.z, 4),
            result, round(azimuth, 2), round(elevation, 2)
        ])

    except ValueError as e:
        print(f"Error parsing Area {tri.get('Area')}: {e}")

# ---- Write the results out to a CSV file -------------------------------------
with open(OUTPUT_CSV_PATH, mode='w', newline='', encoding='utf-8') as output_file:
    writer = csv.writer(output_file)
    writer.writerows(output_data)

print(f"Normal-direction judgment results and azimuth/elevation calculation results written to {OUTPUT_CSV_PATH}")

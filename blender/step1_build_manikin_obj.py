# ============================================================
# step1_build_manikin_obj.py
#
# Directly reads manikin_AreatoPoint.dat and manikin_Point_XYZ.dat
# (tab-delimited text) from data/manikin_model/, creates one Blender
# object per mesh (triangular element, Area), and rebuilds the whole 3D
# manikin model in the Blender scene. Finally exports everything as a
# single OBJ file for inspection.
#
# How to use:
#   1. Start Blender and delete the default Cube etc. shown at startup.
#   2. Open the "Scripting" tab in the top menu, and paste in the contents
#      of this file as a new text block.
#   3. Update REPO_DIR below to match the path where you placed this
#      repository (github_code_RHF_publish). (The default assumes it is
#      placed directly under D:/github_code_RHF_publish.)
#   4. Click "Run" - this builds the manikin model and writes out the OBJ file.
#
# Note: because a large number of meshes are each created as an
#       independent object, Blender may become temporarily unresponsive
#       while this runs. That is expected.
# ============================================================

import bpy
import csv

# ---- Configuration (change to match your environment) ----------------------
# Path to the folder where this repository (github_code_RHF_publish) is
# placed. The default assumes it is placed directly under D:.
REPO_DIR = "D:/github_code_RHF_publish"

MANIKIN_MODEL_DIR = REPO_DIR + "/data/manikin_model"
AREA_TO_POINT_PATH = MANIKIN_MODEL_DIR + "/manikin_AreatoPoint.dat"
POINT_XYZ_PATH = MANIKIN_MODEL_DIR + "/manikin_Point_XYZ.dat"

OUTPUT_OBJ_PATH = REPO_DIR + "/blender/manikin_model.obj"

MESH_BASE_NAME = "Mesh"
OBJECT_BASE_NAME = "Object"


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


# ---- Reset the scene ---------------------------------------------------------
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# ---- Load the .dat files and create one object per mesh ----------------------
triangles = load_mesh_triangles(AREA_TO_POINT_PATH, POINT_XYZ_PATH)

for tri in triangles:
    try:
        vertices = [tri['A'], tri['B'], tri['C']]
        faces = [(0, 1, 2)]

        mesh_name = f"{MESH_BASE_NAME}_{tri['Area']}"
        object_name = f"{OBJECT_BASE_NAME}_{tri['Area']}"
        mesh = bpy.data.meshes.new(mesh_name)
        obj = bpy.data.objects.new(object_name, mesh)

        mesh.from_pydata(vertices, [], faces)
        mesh.update()

        bpy.context.scene.collection.objects.link(obj)

    except Exception as e:
        print(f"Error building Area {tri['Area']}: {e}")

# ---- Export as an OBJ file -----------------------------------------------------
# The operator name differs depending on the Blender version.
# Blender 3.x and earlier (with the "Import-Export: Wavefront OBJ" add-on
# enabled): export_scene.obj
# Blender 4.x and later (the new built-in OBJ exporter): wm.obj_export
if hasattr(bpy.ops.export_scene, "obj"):
    bpy.ops.export_scene.obj(filepath=OUTPUT_OBJ_PATH, use_selection=False)
else:
    bpy.ops.wm.obj_export(filepath=OUTPUT_OBJ_PATH, export_selected_objects=False)

print(f"Number of meshes: {len(triangles)}")
print(f"OBJ file created: {OUTPUT_OBJ_PATH}")

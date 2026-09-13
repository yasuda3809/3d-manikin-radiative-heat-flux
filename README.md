# Mesh-based Radiant Heat Flux (RHF) Calculation

R code for computing the radiant heat flux (RHF) received at an arbitrary
mesh (body part) on a manikin's surface, using an all-sky thermal image
(panoramic thermal image) together with a 3D manikin model.

1. Assigning each mesh (triangular element) of the 3D manikin model to one
   of five measurement points (heights).
2. For a representative mesh, compositing a self-shielding image (the
   manikin's silhouette image) with a thermal image to calculate the RHF.

## Directory structure

```
github_code_RHF_publish_English/
├── github_code_RHF_publish_English.Rproj
├── R/
│   ├── 00_config.R                             # Shared configuration (target Area, temperature range, etc.)
│   ├── 01_mesh_measurement_point_assignment.R  # (1) Assigning meshes to the 5 measurement points
│   ├── 02_composite_and_calculate_RHF.R        # (2) Compositing the self-shielding image x thermal image and calculating RHF
│   └── utils_thermal_image.R                   # Shared functions for image loading / temperature conversion
├── blender/
│   ├── step1_build_manikin_obj.py       # Rebuild the 3D manikin model in Blender and export it as an OBJ
│   ├── step2_render_fisheye_views.py    # Fisheye renders along each mesh's +/- normal direction (for direction judging)
│   ├── step3_compute_normal_direction.py  # Compute each mesh's normal azimuth/elevation from the judged direction
│   └── Mesh_direction.csv               # Step2 judgment results (90/270 per Area, already judged by hand)
├── data/
│   ├── manikin_model/      # 3D manikin model mesh coordinates and normal-direction data
│   ├── self_shielding_mask/  # Self-shielding image (sample for the representative mesh Area=234)
│   ├── sample_case3_08/    # Real-world sample: orthographic-projection thermal image tiles from climate chamber experiment Case3, height 0.8 m
│   └── sample_panorama/    # Reference: the all-sky panoramic thermal image that sample_case3_08 was derived from (not used by the code)
└── output/                 # Destination for run outputs (empty initially)
```

## Requirements

- R (>= 4.2)
- Packages: `tidyverse`, `imager`

```r
install.packages(c("tidyverse", "imager"))
```

## How to run

Open `github_code_RHF_publish_English.Rproj` in RStudio (the working
directory is automatically set to the root of this repository). If you are
not using RStudio, set the repository root as your working directory (e.g.
with `setwd()`) before running.

Run the following in order (the sample data is included, so you can run
this as-is).

```r
# 1. Assign meshes to the 5 measurement points
source("R/01_mesh_measurement_point_assignment.R")

# 2. Composite the representative mesh's self-shielding image with the thermal image and calculate RHF
source("R/02_composite_and_calculate_RHF.R")
```

The target mesh (Area number) can be changed simply by editing `TARGET_AREA`
in `R/00_config.R` (the default is `234`). To compute a different Area,
provide the corresponding self-shielding image at
`data/self_shielding_mask/area_<Area number>.png`.

## About the sample data / real-world data

`data/sample_case3_08/` contains a full set of orthographic-projection
thermal image tiles (`make_1.bmp`-`make_684.bmp`, 684 files) spanning the
**entire sphere in 10-degree steps**, taken from climate chamber experiment
Case3 (height 0.8 m) described in the paper. The default `TARGET_AREA`
(234) corresponds to a mesh at this 0.8 m height.

The surrounding-environment thermal images (`sample_case3_08`) are assumed
to be 684 grayscale images — azimuth theta (-170 to 180 degrees, 10-degree
steps, 36 tiles) x elevation phi (-90 to 90 degrees, 10-degree steps, 19
tiles) — numbered sequentially with phi as the outer loop and theta as the
inner loop. Pixel grayscale values (0-255, R=G=B) must map linearly onto
the temperature range `ThermoLowSet`-`ThermoHighSet`. The file format /
extension is specified via `THERMAL_TILE_DIR` / `THERMAL_TILE_EXT` in
`R/00_config.R`.

`data/sample_panorama/` contains the all-sky panoramic thermal images that
`sample_case3_08` was derived from (`mono_08_panorama.jpg`: after
monochrome conversion, `shine_08_panorama.jpg`: before conversion), for
reference. They are not used by the R code in this repository (the
conversion from an all-sky panorama into orthographic-projection tiles is
done with an external tool such as Cube2DM).

To use your own real-world data, replace `THERMAL_TILE_DIR` /
`THERMAL_TILE_EXT` in `R/00_config.R` with your data's folder and
extension.

## How the azimuth/elevation of each thermal tile (make_N) is determined

The azimuth (theta) and elevation (phi) of each `make_N` tile are not
derived by analyzing the image content. Instead, they are recovered in
code from **the fixed ordering that Cube2DM (the external tool that
converts an all-sky panoramic thermal image into orthographic-projection
tiles; not included in this repository) uses when it writes out the
tiles.**

1. **The tile angle grid is a fixed set of values** (`THETA_SEQ`, `PHI_SEQ`
   in `R/00_config.R`). Cube2DM mechanically splits the all-sky panorama
   into 10-degree azimuth x 10-degree elevation steps — azimuth theta
   (-170 to 180 degrees, 36 values) x elevation phi (-90 to 90 degrees, 19
   values) — and always writes out the resulting 684 tiles in the same
   order.

2. **Mapping to file names** (`tile_grid` in
   `R/02_composite_and_calculate_RHF.R`). All combinations are laid out
   with `phi` as the outer loop (ascending, -90 to 90) and `theta` as the
   inner loop (ascending, -170 to 180), and numbered sequentially. For
   example: `make_1` = (theta=-170, phi=-90), `make_36` = (theta=180,
   phi=-90), `make_37` = (theta=-170, phi=-80), and so on. This rule
   matches Cube2DM's actual output order; it is not determined by
   inspecting the images.

3. **Correcting the offset between the thermal-image and manikin
   coordinate systems.** Cube2DM's theta (the panoramic camera's reference
   direction) and the manikin 3D model's theta (the line-of-sight
   direction computed geometrically in script 01) use different reference
   directions, because the camera's 0-degree direction and the manikin's
   front direction are determined independently. This correspondence is
   resolved via the lookup table
   `data/manikin_model/theta_thermal_to_manikin.csv`. This table was not
   derived by calculation; it was built by visually matching room
   landmarks between the thermal image and the manikin — e.g. "front =
   the waist-height window", "left side = the sliding door window". No
   such correction is needed for phi (elevation), since there is no
   ambiguity in the vertical reference direction.

In short, `R/02_composite_and_calculate_RHF.R` locates the thermal tile
for a given mesh by: (1) taking the mesh's line-of-sight direction (theta
in the manikin coordinate system), (2) converting it to Cube2DM's theta
via the lookup table, and (3) looking up the file name from the fixed grid
ordering.

## Generating the manikin normal-direction data (Blender pipeline)

`data/manikin_model/Normal_Direction_Result.csv` (each mesh's normal
direction) was produced using Blender, through the three steps below.
Scripts that reproduce and verify this process are included in the
`blender/` folder.

| Script | Description |
|---|---|
| `blender/step1_build_manikin_obj.py` | Reads `manikin_AreatoPoint.dat` and `manikin_Point_XYZ.dat`, rebuilds the whole manikin in Blender as one object per mesh (triangle), and exports it as an OBJ file |
| `blender/step2_render_fisheye_views.py` | Places a camera at each mesh's centroid and renders fisheye (equidistant-projection) images looking along the +/- normal direction (90 deg / 270 deg) |
| `blender/step3_compute_normal_direction.py` | Uses the human-judged result from comparing the Step2 images (`blender/Mesh_direction.csv`, i.e. which direction faces away from the body) to compute the normal's azimuth (Azimuth) and elevation (Elevation), and writes/overwrites `data/manikin_model/Normal_Direction_Result.csv` directly |

**Step2 requires a visual judgment call by a human.** The vertex order of a
triangular mesh (i.e. the sign of the cross product) alone cannot tell you
mechanically whether the normal points toward the outside or the inside of
the body. So, for any Area that has not yet been judged, both the 90-degree
and 270-degree directions are rendered, and a person visually checks each
mesh to decide which one faces outward, recording the result in
`blender/Mesh_direction.csv` (Area, direction). For an Area that already
has a judgment recorded in `Mesh_direction.csv`, only the correct-direction
image is rendered (the unneeded direction is not rendered, and any leftover
image for it from a previous run is deleted). Because this repository
already includes a fully judged `Mesh_direction.csv`, **you normally do not
need to re-run Step2** — Step1 and Step3 alone reproduce the same result as
`data/manikin_model/Normal_Direction_Result.csv`.

Execution order: in Blender's "Scripting" tab, paste in and run
`blender/step1_build_manikin_obj.py` -> (only if needed)
`step2_render_fisheye_views.py` -> `step3_compute_normal_direction.py`, in
that order, each as a new text block. Before running, update `REPO_DIR` at
the top of each script (the folder where this repository, i.e.
`github_code_RHF_publish_English`, is placed; the default is
`D:/github_code_RHF_publish`) to match your own environment. **Step3
overwrites `data/manikin_model/Normal_Direction_Result.csv` directly** —
this is fine, since it is the same file (just being regenerated).

While preparing this repository, the above procedure (vector calculations
equivalent to Step1/Step3, reproduced in R) was checked against
`data/manikin_model/Normal_Direction_Result.csv`. 1751 of 1753 meshes match
exactly (azimuth and elevation both agree to within 0.01 degrees of
rounding error); only 2 meshes (Area=1308, 1309, both borderline cases
where the normal is nearly straight up or nearly horizontal) show a small
discrepancy, likely due to a version difference in the source data rather
than a mismatch in the calculation logic itself.

## Input data

`data/manikin_model/` holds the mesh geometry data for the 3D manikin
model (a body model from a 3D scan).

| File | Contents |
|---|---|
| `manikin_Area.dat` | Area [m2] and body-part name (bui) for each mesh number (Area) |
| `manikin_AreatoPoint.dat` | The three vertex numbers making up each mesh (triangle) |
| `manikin_Point_XYZ.dat` | XYZ coordinates [m] of each vertex |
| `Normal_Direction_Result.csv` | Normal direction of each mesh (azimuth/elevation computed with Blender) |
| `theta_thermal_to_manikin.csv` | Lookup table between thermal-tile azimuth and manikin-coordinate-system azimuth |

### About creating the self-shielding image (self_shielding_mask)

The self-shielding image is created in two stages:

1. From the target mesh's line-of-sight direction (the azimuth/elevation in
   `Normal_Direction_Result.csv`), photograph the manikin in Blender to
   obtain a fisheye (equidistant-projection) image.
2. Convert that fisheye (equidistant-projection) image into an orthographic
   projection (line-of-sight) image using Cube2DM — the same external tool
   used to convert the surrounding-environment thermal images.

This is the same processing described in the revised paper:

> The captured equidistant projection image was converted into a
> line-of-sight image with orthographic projection.

`data/self_shielding_mask/area_234.png` is included as a sample for
computing the representative mesh (Area=234): the manikin's self-shielding
image, converted to orthographic projection with Cube2DM following the
procedure above. Body parts are drawn in a dark color and everything else
in a light color, and the image has been converted to the same resolution
(pixel count) as the thermal image tiles in `data/sample_case3_08/`.

Note that this "capture a fisheye image, then convert it to orthographic
projection with Cube2DM" process is separate from
`blender/step2_render_fisheye_views.py` (the 90-degree/270-degree renders
used to build `Mesh_direction.csv`). Because the Cube2DM conversion itself
is performed outside Blender, it is not included among this repository's
scripts.

## Calculation logic

### (1) Assigning meshes to the 5 measurement points

Each mesh centroid of the 3D manikin model is converted to polar
coordinates (azimuth theta, elevation phi, distance r) relative to each of
the five measurement points (heights 1.2, 1.0, 0.8, 0.5, 0.3 m, defined in
`measurement_points` in `R/00_config.R`), and each mesh is assigned to
whichever measurement point gives the smallest distance r. For the
line-of-sight direction (theta, phi), rather than using the angle of the
line connecting the mesh centroid to the measurement point directly, the
mesh's normal direction as computed in Blender is used instead.

### (2) Calculating RHF by compositing the self-shielding image with the thermal image

The orthographic-projection thermal tile corresponding to the
representative mesh's line-of-sight direction is composited with the
self-shielding image (the manikin's silhouette): pixels occluded by the
body are replaced with the manikin's surface temperature
(`ManikinSkinTemp`). The pixels of this composite image are classified as
either "environment (env)" or "self/body (human)", and RHF (`Qin_Wpm2`) is
calculated with the following formulas.

```
E_env   = sigma * mean( (T_env_pixel   + 273.15)^4 )
E_human = sigma * mean( (T_human_pixel + 273.15)^4 )
F_env   = (PixelCount_ThermoRender - PixelCount_meshonly) / PixelCount_ThermoRender
F_human =  PixelCount_meshonly / PixelCount_ThermoRender
Qin_Wpm2   = F_env * E_env + F_human * E_human
T_rad_degC = (Qin_Wpm2 / sigma)^0.25 - 273.15
```

`sigma` is the Stefan-Boltzmann constant (5.670374419e-8 W/m2K4).
`T_rad_degC` is the equivalent black-body temperature that would produce
the same radiant exitance as `Qin_Wpm2` (the inverse of the
Stefan-Boltzmann law) — equivalent to the mean radiant temperature (MRT)
at this measurement point.

**Key point of the revised paper**: rather than first averaging the pixel
temperatures and then raising the result to the 4th power, the radiant
exitance (E_env, E_human) is calculated by **raising each pixel's absolute
temperature [K] to the 4th power first, and then averaging** — the method
that is physically faithful to the Stefan-Boltzmann law. The formulas for
`F_env` and `F_human`, derived from `PixelCount_ThermoRender` (the number
of valid pixels in the composite image) and `PixelCount_meshonly` (the
number of self-shielded pixels), are unchanged from the original analysis
code.

## Output

- `output/mesh_measurement_point_assignment.csv`: measurement-point
  assignment results for all meshes
- `output/RHF_area_<Area number>.csv`: RHF calculation result for the
  target mesh
- `output/composite_area_<Area number>.png`: the composited self-shielding
  + thermal image (for visual inspection)

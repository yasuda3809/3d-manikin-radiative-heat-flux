# ============================================================
# 00_config.R
# Radiant Heat Flux (RHF) calculation program using an all-sky thermal
# image and a 3D manikin model - shared configuration file
# ============================================================
# Editing the values in this file is enough to change parameters such as
# the target mesh or the temperature range to match your experimental
# conditions.

suppressPackageStartupMessages({
  library(tibble)
})

# ---- Target mesh (Area number) ---------------------------------------------
# Serial number of a triangular mesh in the 3D manikin model.
# 234 is the representative mesh included as a sample (self-shielding image
# area_234.png).
# To compute RHF for a different mesh, just change this value
# (a matching self-shielding image area_<TARGET_AREA>.png must exist in
#  data/self_shielding_mask/).
TARGET_AREA <- 234

# ---- Temperature range of the thermal image (monochrome pseudo-color image) ----
# Monochrome-converted thermal images exported from tools such as ThermoFLEX
# are assumed to have grayscale values (0-255, R=G=B) that map linearly
# onto the temperature range below.
# Change this to match the temperature range set for your own thermal images.
ThermoLowSet  <- 10   # [degC] temperature corresponding to grayscale value 0
ThermoHighSet <- 40   # [degC] temperature corresponding to grayscale value 255

# ---- Manikin (body model) surface temperature -------------------------------
# Temperature [degC] assigned to the self-shielded region (the part covered
# by the body)
ManikinSkinTemp <- 32.6

# ---- Definition of the 5 measurement points (heights) -----------------------
# XYZ coordinates [m] of the reference point used for the polar-coordinate
# conversion (i.e. the location of the radiometer / measurement point).
# The chest (1.2 m), waist (1.0 m), and waist (0.8 m) points share the same
# XY location, while the thigh (0.5 m) and shin (0.3 m) points have a
# different Y_origin because the sensor mounting position is shifted
# forward (adjust this to match your own experimental setup).
measurement_points <- tibble(
  center_h = c(1.2, 1.0, 0.8, 0.5, 0.3),
  X_origin = c(1.3, 1.3, 1.3, 1.3, 1.3),
  Y_origin = c(1.0, 1.0, 1.0, 1.2, 1.6),
  Z_origin = c(1.2, 1.0, 0.8, 0.5, 0.3)
)

# ---- Grid definition for the orthographic-projection thermal tiles ----------
# Orthographic-projection tile images converted from an all-sky thermal
# image with a tool such as Cube2DM consist of 684 tiles - azimuth theta
# (-170~180 degrees, 10-degree steps, 36 tiles) x elevation phi (-90~90
# degrees, 10-degree steps, 19 tiles) - and are assumed to be saved as a
# sequential series make_1.jpg ~ make_684.jpg (numbered with phi as the
# outer loop and theta as the inner loop, ascending from -90 degrees).
THETA_SEQ <- seq(-170, 180, by = 10)
PHI_SEQ   <- seq(-90, 90, by = 10)

# ---- Mask threshold for the self-shielding image -----------------------------
# In the self-shielding image (the manikin silhouette rendered in Blender),
# a pixel is treated as "occluded by the body" when all of R, G, B are at
# or below this value.
SELF_SHIELDING_THRESHOLD <- 55

# ---- Stefan-Boltzmann constant -----------------------------------------------
STEFAN_BOLTZMANN <- 5.670374419e-8  # [W/m2K4]

# ---- Directory settings -------------------------------------------------------
# Relative paths, assuming this repository's root is the working directory.
# Change these to match your own real-world data.
DATA_DIR   <- "data"
OUTPUT_DIR <- "output"
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

MANIKIN_MODEL_DIR       <- file.path(DATA_DIR, "manikin_model")
SELF_SHIELDING_MASK_DIR <- file.path(DATA_DIR, "self_shielding_mask")

# Directory holding the real-world orthographic-projection thermal image
# tiles (Cube2DM output).
# As a sample, a full set of real-world data (make_1.bmp ~ make_684.bmp)
# from climate chamber experiment Case3 in the paper (height 0.8 m) is
# included in data/sample_case3_08/
# (the default TARGET_AREA=234 is a mesh corresponding to this 0.8 m data).
# Replace this path when using different real-world data.
THERMAL_TILE_DIR <- file.path(DATA_DIR, "sample_case3_08")

# File extension of the thermal image tiles (the sample data uses bmp)
THERMAL_TILE_EXT <- "bmp"

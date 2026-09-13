# ============================================================
# 02_composite_and_calculate_RHF.R
#
# For the representative mesh (TARGET_AREA), composite the self-shielding
# image (the manikin's silhouette image) with the orthographic-projection
# thermal tile, and calculate the radiant heat flux (RHF: Radiant Heat
# Flux).
#
# RHF calculation formulas (matching the revised paper's calculation logic):
#   E_env   = sigma * mean( (T_env_pixel   + 273.15)^4 )   radiant exitance from the environment [W/m2]
#   E_human = sigma * mean( (T_human_pixel + 273.15)^4 )   radiant exitance from self (the body) [W/m2]
#   F_env   = (PixelCount_ThermoRender - PixelCount_meshonly) / PixelCount_ThermoRender
#   F_human =  PixelCount_meshonly / PixelCount_ThermoRender
#   Qin_Wpm2 = F_env * E_env + F_human * E_human
#   T_rad_degC = (Qin_Wpm2 / sigma)^0.25 - 273.15   radiant temperature (equivalent black-body temperature) corresponding to Qin_Wpm2
#
# The change made in the revised paper is that, rather than first averaging
# the pixel temperatures and then raising the result to the 4th power, the
# temperature [K] of each pixel is raised to the 4th power first and then
# averaged (the method that is physically faithful to the Stefan-Boltzmann
# law).
#
# Run 01_mesh_measurement_point_assignment.R first.
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

source("R/00_config.R")
source("R/utils_thermal_image.R")

# ------------------------------------------------------------
# 1. Load the target mesh's measurement point and line-of-sight direction
#    (theta, phi in the manikin coordinate system)
# ------------------------------------------------------------
assignment_path <- file.path(OUTPUT_DIR, "mesh_measurement_point_assignment.csv")
if (!file.exists(assignment_path)) {
  stop("Please run 01_mesh_measurement_point_assignment.R first: ", assignment_path)
}

target_mesh <- read_csv(assignment_path, show_col_types = FALSE) %>%
  filter(Area == TARGET_AREA)

if (nrow(target_mesh) == 0) {
  stop(sprintf(
    "Area=%d does not exist in the mesh coordinate data. Check TARGET_AREA in R/00_config.R.",
    TARGET_AREA
  ))
}
target_mesh <- target_mesh %>% slice(1)

# ------------------------------------------------------------
# 2. Build the file-name grid for the orthographic-projection thermal
#    tiles, and identify the tile matching the target mesh's theta, phi,
#    center_h
# ------------------------------------------------------------
theta_map <- read_csv(
  file.path(MANIKIN_MODEL_DIR, "theta_thermal_to_manikin.csv"),
  show_col_types = FALSE
)

# The thermal tiles are assumed to be saved as a sequential series
# (make_1.<extension> ~ make_684.<extension>) with phi as the outer loop
# and theta as the inner loop
tile_grid <- expand_grid(theta_thermal = THETA_SEQ, phi = PHI_SEQ) %>%
  arrange(phi, theta_thermal) %>%
  mutate(filename = sprintf(paste0("make_%d.", THERMAL_TILE_EXT), row_number()))

matched_theta_thermal <- theta_map %>%
  filter(theta_manikin == target_mesh$theta) %>%
  pull(theta_thermal)

if (length(matched_theta_thermal) == 0) {
  stop(sprintf("No thermal-image-side theta was found matching theta=%s.", target_mesh$theta))
}

tile_row <- tile_grid %>%
  filter(theta_thermal == matched_theta_thermal[1], phi == target_mesh$phi)

if (nrow(tile_row) == 0) {
  stop("No thermal image tile was found matching the target mesh (check the theta, phi combination).")
}

thermal_tile_path <- file.path(THERMAL_TILE_DIR, tile_row$filename[1])
mask_path <- file.path(SELF_SHIELDING_MASK_DIR, sprintf("area_%d.png", TARGET_AREA))

if (!file.exists(thermal_tile_path)) {
  stop(
    "Thermal image tile not found: ", thermal_tile_path,
    "\n(Check THERMAL_TILE_DIR / THERMAL_TILE_EXT in R/00_config.R, or ",
    "change them to point at your real-world data folder)"
  )
}
if (!file.exists(mask_path)) {
  stop(sprintf(
    "Self-shielding image not found: %s\n(Provide a self-shielding image for TARGET_AREA=%d in data/self_shielding_mask/)",
    mask_path, TARGET_AREA
  ))
}

message(sprintf(
  "Area=%d : center_h=%.1fm, theta=%s, phi=%s -> %s",
  TARGET_AREA, target_mesh$center_h, target_mesh$theta, target_mesh$phi, tile_row$filename[1]
))

# ------------------------------------------------------------
# 3. Load the thermal tile and the self-shielding image, and determine
#    each pixel's temperature and whether it is occluded
# ------------------------------------------------------------
thermal_info <- get_pixel_temperatures(thermal_tile_path)
mask_info <- get_self_shielding_mask(
  mask_path,
  target_width  = thermal_info$width,
  target_height = thermal_info$height
)

# ------------------------------------------------------------
# 4. Use the self-shielding image to composite the manikin's surface
#    temperature onto the thermal image
#    (pixels occluded by the body are replaced with the manikin surface
#    temperature)
# ------------------------------------------------------------
composite_temperature <- thermal_info$temperature
composite_temperature[mask_info$is_body] <- ManikinSkinTemp

valid_pixel <- !is.na(composite_temperature)
env_pixel   <- valid_pixel & !mask_info$is_body
human_pixel <- valid_pixel &  mask_info$is_body

# ------------------------------------------------------------
# 5. Aggregate the pixel information (pixel_info)
#    PixelCount_ThermoRender: number of valid pixels in the composite image
#    PixelCount_meshonly    : number of self-shielded (body) pixels
# ------------------------------------------------------------
pixel_info <- tibble(
  Area = TARGET_AREA,
  PixelCount_ThermoRender = sum(valid_pixel),
  PixelCount_meshonly     = sum(mask_info$is_body),
  # The revised paper's calculation logic: raise each pixel's absolute
  # temperature [K] to the 4th power first, then average
  # (if there are 0 matching pixels, the corresponding weight (F_env/F_human)
  # is also 0, so 0 is returned)
  MeanT4_env_K4   = mean_temperature4_K4(composite_temperature[env_pixel]),
  MeanT4_human_K4 = mean_temperature4_K4(composite_temperature[human_pixel])
)

# ------------------------------------------------------------
# 6. Calculate F_env, F_human, E_env, E_human, RHF (Qin_Wpm2), and the
#    radiant temperature.
#    The radiant temperature (T_rad_degC) is the equivalent black-body
#    temperature that has the same radiant exitance as Qin_Wpm2 (the
#    inverse of the Stefan-Boltzmann law), corresponding to the mean
#    radiant temperature (MRT) at this measurement point.
# ------------------------------------------------------------
rhf_result <- pixel_info %>%
  mutate(
    F_env   = (PixelCount_ThermoRender - PixelCount_meshonly) / PixelCount_ThermoRender,
    F_human =  PixelCount_meshonly / PixelCount_ThermoRender,
    E_env_Wpm2   = STEFAN_BOLTZMANN * MeanT4_env_K4,
    E_human_Wpm2 = STEFAN_BOLTZMANN * MeanT4_human_K4,
    Qin_Wpm2   = F_env * E_env_Wpm2 + F_human * E_human_Wpm2,
    T_rad_degC = (Qin_Wpm2 / STEFAN_BOLTZMANN)^0.25 - 273.15
  )

print(rhf_result)

# ------------------------------------------------------------
# 7. Save the result
# ------------------------------------------------------------
write_csv(rhf_result, file.path(OUTPUT_DIR, sprintf("RHF_area_%d.csv", TARGET_AREA)))

save_composite_image(
  width  = thermal_info$width,
  height = thermal_info$height,
  composite_temperature = composite_temperature,
  output_path = file.path(OUTPUT_DIR, sprintf("composite_area_%d.png", TARGET_AREA))
)

message(sprintf(
  "RHF calculation complete for Area=%d -> %s",
  TARGET_AREA, file.path(OUTPUT_DIR, sprintf("RHF_area_%d.csv", TARGET_AREA))
))

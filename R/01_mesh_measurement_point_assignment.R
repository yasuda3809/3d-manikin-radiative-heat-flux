# ============================================================
# 01_mesh_measurement_point_assignment.R
#
# For each mesh (triangular element, Area) of the 3D manikin model, assign
# it to the nearest of the 5 measurement points (heights: 1.2, 1.0, 0.8,
# 0.5, 0.3 m), and also compute each mesh's line-of-sight direction
# (azimuth theta, elevation phi) in the manikin coordinate system.
#
# Output: output/mesh_measurement_point_assignment.csv
#   Area, bui, m2, center_h, theta, phi, r
#     Area     : mesh number
#     bui      : body-part name
#     m2       : mesh area [m2]
#     center_h : height [m] of the assigned measurement point
#     theta    : azimuth [degrees] in the manikin coordinate system (already rounded to the thermal tile's 10-degree grid)
#     phi      : elevation [degrees] in the manikin coordinate system (same as above)
#     r        : distance [m] from the mesh centroid to the measurement point
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

source("R/00_config.R")

# ------------------------------------------------------------
# 1. Compute the centroid coordinates of the 3D manikin mesh
# ------------------------------------------------------------
manikin_Area <- read_tsv(
  file.path(MANIKIN_MODEL_DIR, "manikin_Area.dat"),
  show_col_types = FALSE
)
manikin_AreaToPoint <- read_tsv(
  file.path(MANIKIN_MODEL_DIR, "manikin_AreatoPoint.dat"),
  show_col_types = FALSE
)
manikin_Point_XYZ <- read_tsv(
  file.path(MANIKIN_MODEL_DIR, "manikin_Point_XYZ.dat"),
  show_col_types = FALSE
)

# Join the 3 vertex coordinates of each mesh (triangle) and compute the centroid
mesh_centroids <- manikin_AreaToPoint %>%
  left_join(manikin_Point_XYZ, by = c("PointA" = "Point")) %>%
  rename(xA = x, yA = y, zA = z) %>%
  left_join(manikin_Point_XYZ, by = c("PointB" = "Point")) %>%
  rename(xB = x, yB = y, zB = z) %>%
  left_join(manikin_Point_XYZ, by = c("PointC" = "Point")) %>%
  rename(xC = x, yC = y, zC = z) %>%
  mutate(
    X_center = (xA + xB + xC) / 3,
    Y_center = (yA + yB + yC) / 3,
    Z_center = (zA + zB + zC) / 3
  ) %>%
  left_join(manikin_Area, by = "Area") %>%
  select(Area, bui, m2, X_center, Y_center, Z_center)

# ------------------------------------------------------------
# 2. Convert to polar coordinates (azimuth theta, elevation phi, distance r)
#    relative to each measurement point
# ------------------------------------------------------------
convert_to_polar <- function(data, X_origin, Y_origin, Z_origin) {
  data %>%
    mutate(
      r     = sqrt((X_center - X_origin)^2 + (Y_center - Y_origin)^2 + (Z_center - Z_origin)^2),
      theta = atan2(Y_center - Y_origin, X_center - X_origin) * (180 / pi),
      phi   = asin((Z_center - Z_origin) / r) * (180 / pi)
    )
}

polar_by_point <- purrr::pmap_dfr(
  measurement_points,
  function(center_h, X_origin, Y_origin, Z_origin) {
    convert_to_polar(mesh_centroids, X_origin, Y_origin, Z_origin) %>%
      mutate(center_h = center_h)
  }
)

# ------------------------------------------------------------
# 3. For each mesh, assign the measurement point (height) that gives the
#    smallest distance r
#    -> this is "assigning each mesh to the 5 measurement points"
# ------------------------------------------------------------
mesh_assigned_point <- polar_by_point %>%
  group_by(Area, bui, m2) %>%
  filter(r == min(r)) %>%
  ungroup()

# ------------------------------------------------------------
# 4. Correct theta and phi using the mesh's own orientation (normal direction)
#
#    Using the angle of the straight line connecting the mesh centroid to
#    the measurement point as the line-of-sight direction would be
#    offset from the direction actually seen on camera / in the thermal
#    image, because of the slope of the body surface. So it is replaced
#    with the mesh normal direction computed in Blender
#    (Normal_Direction_Result.csv).
# ------------------------------------------------------------
normal_direction <- read_csv(
  file.path(MANIKIN_MODEL_DIR, "Normal_Direction_Result.csv"),
  show_col_types = FALSE
) %>%
  mutate(
    # When Direction is 270 (a downward-facing normal), convert to the
    # angle as seen from the mirrored side
    theta = case_when(
      Direction == 270 & Azimuth > 0  & Azimuth < 90  ~ -(180 - Azimuth),
      Direction == 270 & Azimuth > 90                 ~ (180 - Azimuth),
      Direction == 270 & Azimuth < 0  & Azimuth > -90 ~ (180 + Azimuth),
      Direction == 270 & Azimuth < -90                ~ 180 - Azimuth,
      TRUE ~ Azimuth
    ),
    phi = if_else(Direction == 270, Elevation * -1, Elevation)
  ) %>%
  # Correct the mounting offset between the all-sky thermal image's
  # reference direction and the manikin model's orientation.
  # Each line below deliberately refers to theta as already updated by the
  # previous line ("sequentially applied" correction, so a theta value near
  # a boundary may be corrected more than once) - this is intentional, to
  # exactly match the correction logic used in the original analysis.
  mutate(
    theta = ifelse(theta > 0   & theta < 90,  theta - 20, theta),
    theta = ifelse(theta < 0   & theta > -90, theta - 20, theta),
    theta = ifelse(theta > 90,                theta + 20, theta),
    theta = ifelse(theta < -90,                theta + 20, theta),
    theta = ifelse(theta > 180,  theta - 360, theta),
    theta = ifelse(theta < -180, theta + 360, theta)
  ) %>%
  select(Area, theta, phi)

mesh_assignment_final <- mesh_assigned_point %>%
  select(-theta, -phi) %>%
  left_join(normal_direction, by = "Area") %>%
  mutate(
    # Round to the 10-degree grid of the orthographic-projection thermal tiles
    theta = round(theta, -1),
    phi   = round(phi, -1)
  ) %>%
  select(Area, bui, m2, center_h, theta, phi, r)

# ------------------------------------------------------------
# 5. Save the result
# ------------------------------------------------------------
write_csv(mesh_assignment_final, file.path(OUTPUT_DIR, "mesh_measurement_point_assignment.csv"))

message(sprintf(
  "Measurement-point assignment complete for %d meshes -> %s",
  nrow(mesh_assignment_final),
  file.path(OUTPUT_DIR, "mesh_measurement_point_assignment.csv")
))

print(mesh_assignment_final %>% filter(Area == TARGET_AREA))

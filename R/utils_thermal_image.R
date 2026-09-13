# ============================================================
# utils_thermal_image.R
# Shared functions for loading thermal images (monochrome pseudo-color
# images) and self-shielding images, and converting each pixel to a
# temperature
# ============================================================

suppressPackageStartupMessages({
  library(imager)
})

#' Compute the mean of each pixel's absolute temperature [K] raised to the
#' 4th power
#'
#' If there are no matching pixels at all (e.g. zero self-shielded pixels,
#' or the field of view is entirely environment), returns 0 instead of NA.
#' This is because, when the pixel count is 0, the corresponding weight
#' (F_env/F_human) is also 0 and so does not contribute to the calculation
#' anyway (this avoids 0 * NaN turning into NaN).
#'
#' @param temperature_pixels Vector of per-pixel temperatures [degC] (NAs already removed)
#' @return Mean of the absolute temperature [K] raised to the 4th power
mean_temperature4_K4 <- function(temperature_pixels) {
  if (length(temperature_pixels) == 0) {
    return(0)
  }
  mean((temperature_pixels + 273.15)^4)
}

#' Load a monochrome thermal image and compute each pixel's temperature [degC]
#'
#' Assumes the grayscale value (0-255, R=G=B) maps linearly onto the
#' temperature range low ~ high. R=0 (black) is treated as an invalid pixel
#' for the thermal image (outside the measurement range / background) and
#' NA is returned for it.
#'
#' @param image_path Path to the image file
#' @param low  Temperature [degC] corresponding to grayscale value 0
#' @param high Temperature [degC] corresponding to grayscale value 255
#' @return list(temperature=numeric vector, width=, height=)
get_pixel_temperatures <- function(image_path, low = ThermoLowSet, high = ThermoHighSet) {
  img <- load.image(image_path)

  gray <- round(as.numeric(img[, , 1, 1]) * 255)
  temperature <- low + (gray / 255) * (high - low)
  temperature[gray == 0] <- NA

  list(
    temperature = temperature,
    width  = dim(img)[1],
    height = dim(img)[2]
  )
}

#' From the self-shielding image (the manikin's silhouette image),
#' determine which pixels are occluded by the body
#'
#' Assumes the silhouette image rendered in Blender is drawn with the body
#' in black (a dark color) and everything else in a lighter color.
#' A pixel is treated as "occluded by the body" when all of R, G, B are at
#' or below threshold.
#'
#' @param image_path Path to the self-shielding image file
#' @param threshold  Threshold for the occlusion judgment (0-255)
#' @param target_width,target_height If given, resize to this resolution before
#'   judging (so the pixel count matches the thermal image tile)
#' @return list(is_body=logical vector, width=, height=)
get_self_shielding_mask <- function(image_path, threshold = SELF_SHIELDING_THRESHOLD,
                                     target_width = NULL, target_height = NULL) {
  img <- load.image(image_path)

  if (!is.null(target_width) && !is.null(target_height) &&
      (dim(img)[1] != target_width || dim(img)[2] != target_height)) {
    img <- resize(img, size_x = target_width, size_y = target_height)
  }

  th <- threshold / 255
  is_body <- (img[, , 1, 1] <= th) & (img[, , 1, 2] <= th) & (img[, , 1, 3] <= th)

  list(
    is_body = as.vector(is_body),
    width   = dim(img)[1],
    height  = dim(img)[2]
  )
}

#' Create an image compositing the thermal image with the self-shielding
#' mask (for visualization / inspection)
#'
#' Generates and saves a grayscale image in which pixels occluded by the
#' body have been replaced with the manikin's surface temperature. Not
#' needed for the RHF calculation itself, but provided so the composite
#' result can be checked visually.
#'
#' @param width,height Image size
#' @param composite_temperature Vector of per-pixel temperatures (after compositing)
#' @param low,high Temperature range (for converting back to grayscale)
#' @param output_path Destination path
save_composite_image <- function(width, height, composite_temperature,
                                  low = ThermoLowSet, high = ThermoHighSet,
                                  output_path) {
  gray <- (composite_temperature - low) / (high - low)
  gray[is.na(gray)] <- 0
  gray <- pmin(pmax(gray, 0), 1)

  arr <- array(rep(gray, 3), dim = c(width, height, 1, 3))
  img <- as.cimg(arr)
  save.image(img, output_path)
}

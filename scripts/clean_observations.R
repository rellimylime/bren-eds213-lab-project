#!/usr/bin/env Rscript

get_helper_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) > 0) {
    script_dir <- dirname(sub("^--file=", "", file_arg[1]))
    return(file.path(script_dir, "clean_helpers.R"))
  }

  file.path("scripts", "clean_helpers.R")
}

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
})

source(get_helper_path())

paths <- get_clean_paths()

message("Reading IDS data from: ", paths$ids_path)

ids <- st_read(paths$ids_path, layer = ids_layer_name, quiet = TRUE) |>
  st_drop_geometry()

stop_if_missing_columns(
  ids,
  c(
    "OBSERVATION_ID",
    "REGION_ID",
    "DCA_CODE",
    "SURVEY_YEAR",
    "ACRES",
    "OBSERVATION_COUNT",
    "PERCENT_MID"
  ),
  "IDS GeoPackage"
)

observations <- ids |>
  filter(DCA_CODE >= 11000, DCA_CODE <= 11999) |>
  filter(SURVEY_YEAR >= 2015) |>
  filter(REGION_ID %in% conus_region_ids) |>
  mutate(is_pancake = OBSERVATION_COUNT == "MULTIPLE") |>
  transmute(
    obs_id = OBSERVATION_ID,
    region_id = REGION_ID,
    agent_code = DCA_CODE,
    survey_year = SURVEY_YEAR,
    acres = ACRES,
    percent_mid = PERCENT_MID,
    is_pancake = is_pancake
  ) |>
  distinct()

conflicting_obs_ids <- observations |>
  count(obs_id, sort = TRUE) |>
  filter(n > 1) |>
  pull(obs_id)

if (length(conflicting_obs_ids) > 0) {
  warning(
    paste0(
      "Dropping ", length(conflicting_obs_ids),
      " OBSERVATION_ID values that still map to multiple distinct bark beetle records after deduplication."
    ),
    call. = FALSE
  )

  observations <- observations |>
    filter(!obs_id %in% conflicting_obs_ids)
}

observations <- observations |>
  arrange(survey_year, region_id, obs_id)

if (anyNA(observations$is_pancake)) {
  stop(
    "`is_pancake` contains NA values. Inspect OBSERVATION_COUNT in the IDS source data.",
    call. = FALSE
  )
}

if (anyDuplicated(observations$obs_id) > 0) {
  stop(
    "Duplicate `obs_id` values found after filtering. Ingestion would violate the primary key.",
    call. = FALSE
  )
}

write_csv(observations, paths$observations_csv, na = "")

message("Wrote: ", paths$observations_csv)
message("Rows written: ", nrow(observations))

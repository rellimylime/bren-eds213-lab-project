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
  library(dplyr)
  library(readr)
})

source(get_helper_path())

paths <- get_clean_paths()
stop_if_missing(paths$observations_csv, "clean observations CSV")

regions_raw <- read_csv(paths$regions_path)
observations <- read_csv(paths$observations_csv)

stop_if_missing_columns(regions_raw, c("REGION_ID", "REGION_NAME"), "Region lookup")
stop_if_missing_columns(observations, c("region_id"), "Observations CSV")

abbrev_column <- intersect(
  c("REGION_ABBREV", "REGION_SHORT", "ABBREV", "REGION_CODE"),
  names(regions_raw)
)

regions <- regions_raw |>
  filter(REGION_ID %in% conus_region_ids)

if ("US_AREA" %in% names(regions)) {
  regions <- regions |>
    filter(US_AREA == "CONUS")
}

regions <- regions |>
  mutate(
    region_abbrev = if (length(abbrev_column) > 0) {
      .data[[abbrev_column[1]]]
    } else {
      paste0("R", REGION_ID)
    }
  ) |>
  transmute(
    region_id = REGION_ID,
    region_name = REGION_NAME,
    region_abbrev = region_abbrev
  ) |>
  arrange(region_id)

if (anyDuplicated(regions$region_id) > 0) {
  stop(
    "Duplicate `region_id` values remain in the region lookup after filtering.",
    call. = FALSE
  )
}

missing_region_ids <- observations |>
  distinct(region_id) |>
  anti_join(regions, by = "region_id")

if (nrow(missing_region_ids) > 0) {
  stop(
    paste0(
      "Some region IDs in `observations.csv` are missing from `region_lookup.csv`: ",
      paste(missing_region_ids$region_id, collapse = ", ")
    ),
    call. = FALSE
  )
}

write_csv(regions, paths$regions_csv, na = "")

message("Wrote: ", paths$regions_csv)
message("Rows written: ", nrow(regions))

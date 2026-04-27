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
  library(DBI)
  library(duckdb)
  library(tibble)
})

source(get_helper_path())

paths <- get_clean_paths()
stop_if_missing(paths$observations_csv, "clean observations CSV")

observations <- read_csv(paths$observations_csv)
stop_if_missing_columns(observations, c("obs_id", "survey_year"), "Observations CSV")

obs_keys <- observations |>
  transmute(
    OBSERVATION_ID = obs_id,
    SURVEY_YEAR = survey_year
  )

climate_con <- dbConnect(duckdb(), dbdir = ":memory:")
on.exit(dbDisconnect(climate_con, shutdown = TRUE), add = TRUE)

dbWriteTable(
  climate_con,
  "obs_keys",
  obs_keys,
  temporary = TRUE,
  overwrite = TRUE
)

read_one_climate_variable <- function(var_name) {
  climate_path <- file.path(paths$climate_dir, paste0(var_name, ".parquet"))

  message("Reading climate variable from: ", climate_path)

  climate_sql <- paste0(
    "SELECT ",
    "  o.OBSERVATION_ID, ",
    "  o.SURVEY_YEAR, ",
    "  AVG(p.weighted_mean) AS ", sql_quote_ident(var_name), " ",
    "FROM read_parquet('", sql_quote_path(climate_path), "') AS p ",
    "INNER JOIN obs_keys AS o ",
    "  ON p.OBSERVATION_ID = o.OBSERVATION_ID ",
    "WHERE p.water_year = o.SURVEY_YEAR - 1 ",
    "GROUP BY o.OBSERVATION_ID, o.SURVEY_YEAR"
  )

  climate_var <- tryCatch(
    dbGetQuery(climate_con, climate_sql) |>
      as_tibble(),
    error = function(error) {
      stop(
        paste0(
          "Failed to read `", climate_path, "`. ",
          "If the climate files are still downloading, wait for them to finish and rerun the cleaning scripts.\n",
          "Original error: ", error$message
        ),
        call. = FALSE
      )
    }
  )

  stop_if_missing_columns(
    climate_var,
    c("OBSERVATION_ID", "SURVEY_YEAR", var_name),
    paste0("Climate file for `", var_name, "`")
  )

  climate_var <- climate_var |>
    transmute(
      obs_id = OBSERVATION_ID,
      survey_year = SURVEY_YEAR,
      !!var_name := .data[[var_name]]
    )

  if (anyDuplicated(climate_var[c("obs_id", "survey_year")]) > 0) {
    stop(
      paste0(
        "Duplicate obs_id / survey_year keys found in `", climate_path,
        "`. The climate table needs one row per observation."
      ),
      call. = FALSE
    )
  }

  climate_var
}

climate <- observations |>
  select(obs_id, survey_year)

for (var_name in climate_vars) {
  climate_var <- read_one_climate_variable(var_name)

  climate <- climate |>
    left_join(climate_var, by = c("obs_id", "survey_year"))
}

climate <- climate |>
  arrange(survey_year, obs_id)

if (anyDuplicated(climate$obs_id) > 0) {
  stop(
    "Duplicate `obs_id` values found in the climate table. Ingestion would violate the primary key.",
    call. = FALSE
  )
}

if (all(is.na(climate$pdsi))) {
  warning(
    "All `pdsi` values are NA. Verify the climate parquet files before ingestion.",
    call. = FALSE
  )
} else {
  pdsi_range <- range(climate$pdsi, na.rm = TRUE)

  message(
    "PDSI range after filtering: [",
    format(pdsi_range[1], digits = 4),
    ", ",
    format(pdsi_range[2], digits = 4),
    "]"
  )

  if (pdsi_range[1] < -10 || pdsi_range[2] > 10) {
    warning(
      "PDSI values fall outside the expected -10 to 10 range. Verify that scale factors were already applied upstream.",
      call. = FALSE
    )
  }
}

write_csv(climate, paths$climate_csv, na = "")

message("Wrote: ", paths$climate_csv)
message("Rows written: ", nrow(climate))

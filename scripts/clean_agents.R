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

agents_raw <- read_csv(paths$agents_path)
observations <- read_csv(paths$observations_csv)

stop_if_missing_columns(agents_raw, c("DCA_CODE", "DCA_COMMON_NAME"), "Damage agent lookup")
stop_if_missing_columns(observations, c("agent_code"), "Observations CSV")

agents <- agents_raw |>
  filter(DCA_CODE >= 11000, DCA_CODE <= 11999) |>
  transmute(
    agent_code = DCA_CODE,
    agent_name = DCA_COMMON_NAME
  ) |>
  distinct() |>
  arrange(agent_code)

missing_agent_codes <- observations |>
  distinct(agent_code) |>
  anti_join(agents, by = "agent_code")

if (nrow(missing_agent_codes) > 0) {
  stop(
    paste0(
      "Some bark beetle agent codes in `observations.csv` are missing from `dca_code_lookup.csv`: ",
      paste(missing_agent_codes$agent_code, collapse = ", ")
    ),
    call. = FALSE
  )
}

if (anyDuplicated(agents$agent_code) > 0) {
  stop("Duplicate `agent_code` values found in the bark beetle lookup.", call. = FALSE)
}

write_csv(agents, paths$agents_csv, na = "")

message("Wrote: ", paths$agents_csv)
message("Rows written: ", nrow(agents))

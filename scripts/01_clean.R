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

source(get_helper_path())

paths <- get_clean_paths()
rscript_path <- file.path(R.home("bin"), "Rscript")

scripts_to_run <- c(
  "clean_observations.R",
  "clean_climate.R",
  "clean_agents.R",
  "clean_regions.R",
  "write_clean_metadata.R"
)

for (script_name in scripts_to_run) {
  script_path <- file.path(paths$repo_root, "scripts", script_name)

  message("")
  message("Running ", script_name, " ...")

  exit_status <- system2(rscript_path, shQuote(script_path))

  if (exit_status != 0) {
    stop(paste0("`", script_name, "` failed with exit status ", exit_status, "."), call. = FALSE)
  }
}

message("")
message("Finished all cleaning steps.")
message("Outputs are in: ", paths$clean_dir)

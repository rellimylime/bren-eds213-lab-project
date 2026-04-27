options(readr.show_col_types = FALSE)

conus_region_ids <- c(1L, 2L, 3L, 4L, 5L, 6L, 8L, 9L)
climate_vars <- c("pdsi", "vpd", "def", "tmmx", "soil")
ids_layer_name <- "damage_areas"

get_repo_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg[1])
    return(normalizePath(file.path(dirname(script_path), ".."), winslash = "/", mustWork = TRUE))
  }

  normalizePath(".", winslash = "/", mustWork = TRUE)
}

stop_if_missing <- function(path, label) {
  if (!file.exists(path)) {
    stop(
      paste0(
        "Could not find ", label, " at `",
        normalizePath(path, winslash = "/", mustWork = FALSE),
        "`."
      ),
      call. = FALSE
    )
  }

  invisible(path)
}

stop_if_missing_columns <- function(data, needed_columns, label) {
  missing_columns <- setdiff(needed_columns, names(data))

  if (length(missing_columns) > 0) {
    stop(
      paste0(
        label, " is missing required columns: ",
        paste(missing_columns, collapse = ", ")
      ),
      call. = FALSE
    )
  }
}

stop_if_missing_climate_files <- function(climate_dir) {
  climate_files <- file.path(climate_dir, paste0(climate_vars, ".parquet"))
  missing_files <- climate_files[!file.exists(climate_files)]

  if (length(missing_files) > 0) {
    stop(
      paste0(
        "Missing required climate parquet files:\n- ",
        paste(normalizePath(missing_files, winslash = "/", mustWork = FALSE), collapse = "\n- ")
      ),
      call. = FALSE
    )
  }

  invisible(climate_dir)
}

sql_quote_path <- function(path) {
  normalized_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  gsub("'", "''", normalized_path, fixed = TRUE)
}

sql_quote_ident <- function(x) {
  paste0("\"", gsub("\"", "\"\"", x, fixed = TRUE), "\"")
}

get_clean_paths <- function() {
  repo_root <- get_repo_root()
  raw_dir <- file.path(repo_root, "data", "raw")
  clean_dir <- file.path(repo_root, "data", "processed", "clean")

  dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)

  list(
    repo_root = repo_root,
    raw_dir = raw_dir,
    clean_dir = clean_dir,
    ids_path = stop_if_missing(
      file.path(raw_dir, "ids", "ids_layers_cleaned.gpkg"),
      "IDS GeoPackage"
    ),
    climate_dir = stop_if_missing_climate_files(
      file.path(raw_dir, "climate", "terraclimate", "damage_areas_summaries")
    ),
    agents_path = stop_if_missing(
      file.path(raw_dir, "lookups", "dca_code_lookup.csv"),
      "damage agent lookup"
    ),
    regions_path = stop_if_missing(
      file.path(raw_dir, "lookups", "region_lookup.csv"),
      "region lookup"
    ),
    observations_csv = file.path(clean_dir, "observations.csv"),
    climate_csv = file.path(clean_dir, "climate.csv"),
    agents_csv = file.path(clean_dir, "agents.csv"),
    regions_csv = file.path(clean_dir, "regions.csv"),
    metadata_md = file.path(clean_dir, "metadata.md")
  )
}

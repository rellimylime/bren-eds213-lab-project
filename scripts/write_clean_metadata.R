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
  library(readr)
  library(tibble)
})

source(get_helper_path())

escape_md <- function(x) {
  x <- gsub("\\|", "\\\\|", x = x)
  gsub("\n", " ", x = x)
}

build_metadata_section <- function(name, description, row_count, sources, columns) {
  table_lines <- c(
    "| Column | Data type | Description | Units | Value range / allowed values | NULLs permitted |",
    "| --- | --- | --- | --- | --- | --- |"
  )

  for (i in seq_len(nrow(columns))) {
    table_lines <- c(
      table_lines,
      paste0(
        "| ", escape_md(columns$column[i]),
        " | ", escape_md(columns$data_type[i]),
        " | ", escape_md(columns$column_description[i]),
        " | ", escape_md(columns$units[i]),
        " | ", escape_md(columns$values[i]),
        " | ", escape_md(columns$nulls[i]),
        " |"
      )
    )
  }

  c(
    paste0("## ", name),
    "",
    description,
    "",
    paste0("Row count: ", format(row_count, big.mark = ",")),
    "",
    "Source file(s):",
    paste0("- `", sources, "`"),
    "",
    table_lines,
    ""
  )
}

paths <- get_clean_paths()

stop_if_missing(paths$observations_csv, "clean observations CSV")
stop_if_missing(paths$climate_csv, "clean climate CSV")
stop_if_missing(paths$agents_csv, "clean agents CSV")
stop_if_missing(paths$regions_csv, "clean regions CSV")

observations <- read_csv(paths$observations_csv)
climate <- read_csv(paths$climate_csv)
agents <- read_csv(paths$agents_csv)
regions <- read_csv(paths$regions_csv)

observations_columns <- tribble(
  ~column, ~data_type, ~column_description, ~units, ~values, ~nulls,
  "obs_id", "VARCHAR", "Unique IDS observation identifier from OBSERVATION_ID.", "None", "UUID string; unique per row.", "No",
  "region_id", "INTEGER", "USFS region code for the observation.", "None", "1-6, 8-9.", "No",
  "agent_code", "INTEGER", "Damage-causing agent code for bark beetles.", "None", "11000-11999.", "No",
  "survey_year", "INTEGER", "Year of the aerial survey observation.", "Year", "2015-2024.", "No",
  "acres", "REAL", "Area of the damage polygon.", "Acres", "Positive real values; verify observed range after ingestion.", "No",
  "percent_mid", "REAL", "Midpoint percent canopy affected. Some 2015 transition-year records remain missing.", "Percent canopy affected", "0-100 when present.", "Yes",
  "is_pancake", "BOOLEAN", "TRUE when OBSERVATION_COUNT equals MULTIPLE.", "None", "TRUE or FALSE.", "No"
)

climate_columns <- tribble(
  ~column, ~data_type, ~column_description, ~units, ~values, ~nulls,
  "obs_id", "VARCHAR", "Observation identifier matching observations.obs_id.", "None", "UUID string; one row per observation.", "No",
  "survey_year", "INTEGER", "Survey year from the IDS observation used to choose the prior water-year climate window.", "Year", "2015-2024.", "No",
  "pdsi", "REAL", "Mean of monthly weighted-mean Palmer Drought Severity Index values from the prior water year.", "Unitless index", "Expected approximately -10 to 10; verify after ingestion.", "Yes",
  "vpd", "REAL", "Mean of monthly weighted-mean TerraClimate vapor pressure deficit values from the prior water year.", "Upstream TerraClimate units; verify", "Unknown; verify after ingestion.", "Yes",
  "def", "REAL", "Mean of monthly weighted-mean TerraClimate climate water deficit values from the prior water year.", "Upstream TerraClimate units; verify", "Unknown; verify after ingestion.", "Yes",
  "tmmx", "REAL", "Mean of monthly weighted-mean TerraClimate maximum temperature values from the prior water year.", "Upstream TerraClimate units; verify", "Unknown; verify after ingestion.", "Yes",
  "soil", "REAL", "Mean of monthly weighted-mean TerraClimate soil moisture values from the prior water year.", "Upstream TerraClimate units; verify", "Unknown; verify after ingestion.", "Yes"
)

agents_columns <- tribble(
  ~column, ~data_type, ~column_description, ~units, ~values, ~nulls,
  "agent_code", "INTEGER", "Bark beetle damage agent lookup code.", "None", "11000-11999.", "No",
  "agent_name", "VARCHAR", "Common name for the damage-causing agent.", "None", "Lookup text values from the IDS code table.", "No"
)

regions_columns <- tribble(
  ~column, ~data_type, ~column_description, ~units, ~values, ~nulls,
  "region_id", "INTEGER", "USFS region identifier used in IDS.", "None", "1-6, 8-9.", "No",
  "region_name", "VARCHAR", "Human-readable USFS region name.", "None", "Northern, Rocky Mountain, Southwestern, Intermountain, Pacific Southwest (CA), Pacific Northwest, Southern, Eastern.", "No",
  "region_abbrev", "VARCHAR", "Standard region abbreviation. Derived as R{region_id} when the source lookup does not provide one.", "None", "R1, R2, R3, R4, R5, R6, R8, R9.", "No"
)

metadata_lines <- c(
  "# Clean Table Metadata",
  "",
  "This file documents the clean CSV outputs created by the cleaning scripts in `scripts/`.",
  "",
  build_metadata_section(
    name = "observations",
    description = "Filtered IDS bark beetle observations for post-2015 CONUS surveys.",
    row_count = nrow(observations),
    sources = "data/raw/ids/ids_layers_cleaned.gpkg (layer: damage_areas)",
    columns = observations_columns
  ),
  build_metadata_section(
    name = "climate",
    description = "Prior water-year means of monthly TerraClimate weighted-mean summaries joined to the filtered IDS observations.",
    row_count = nrow(climate),
    sources = paste0("data/raw/climate/terraclimate/damage_areas_summaries/", climate_vars, ".parquet"),
    columns = climate_columns
  ),
  build_metadata_section(
    name = "agents",
    description = "Lookup table of bark beetle damage agent codes and names.",
    row_count = nrow(agents),
    sources = "data/raw/lookups/dca_code_lookup.csv",
    columns = agents_columns
  ),
  build_metadata_section(
    name = "regions",
    description = "Lookup table of CONUS USFS regions used by the database.",
    row_count = nrow(regions),
    sources = "data/raw/lookups/region_lookup.csv",
    columns = regions_columns
  )
)

write_lines(metadata_lines, paths$metadata_md)

message("Wrote: ", paths$metadata_md)

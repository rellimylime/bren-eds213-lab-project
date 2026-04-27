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
  library(DBI)
  library(duckdb)
  library(readr)
  library(dplyr)
  library(ggplot2)
})

source(get_helper_path())

paths <- get_clean_paths()
fig_dir <- file.path(paths$repo_root, "output", "figures")
sql_path <- file.path(paths$repo_root, "scripts", "03_queries.sql")
db_path <- file.path(paths$repo_root, "data", "processed", "duckdb", "bark_beetle.duckdb")

dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

required_views <- c(
  "analysis_observations",
  "analysis_region_year",
  "analysis_region_relationships"
)

run_view_queries <- function(con, sql_file) {
  sql_lines <- readLines(sql_file, warn = FALSE)
  sql_text <- paste(sql_lines, collapse = "\n")
  sql_parts <- strsplit(sql_text, ";", fixed = TRUE)[[1]]

  for (part in sql_parts) {
    statement <- trimws(part)

    if (!nzchar(statement)) {
      next
    }

    if (grepl("^--", statement)) {
      statement <- gsub("(?m)^--.*$", "", statement, perl = TRUE)
      statement <- trimws(statement)
    }

    if (!nzchar(statement)) {
      next
    }

    if (grepl("^CREATE OR REPLACE VIEW", statement, ignore.case = TRUE)) {
      dbExecute(con, paste0(statement, ";"))
    }
  }
}

build_temp_analysis_db <- function() {
  message("Building analysis views in a temporary in-memory DuckDB.")

  con <- dbConnect(duckdb(), dbdir = ":memory:")

  dbWriteTable(con, "observations", read_csv(paths$observations_csv), overwrite = TRUE)
  dbWriteTable(con, "climate", read_csv(paths$climate_csv), overwrite = TRUE)
  dbWriteTable(con, "agents", read_csv(paths$agents_csv), overwrite = TRUE)
  dbWriteTable(con, "regions", read_csv(paths$regions_csv), overwrite = TRUE)

  run_view_queries(con, sql_path)

  con
}

connect_analysis_db <- function() {
  if (file.exists(db_path)) {
    con <- tryCatch(
      dbConnect(duckdb(), dbdir = db_path, read_only = TRUE),
      error = function(error) NULL
    )

    if (!is.null(con)) {
      available_tables <- dbListTables(con)

      if (all(required_views %in% available_tables)) {
        message("Using analysis views from: ", db_path)
        return(con)
      }

      dbDisconnect(con, shutdown = TRUE)
    }
  }

  build_temp_analysis_db()
}

set.seed(213)

con <- connect_analysis_db()
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

analysis_observations <- dbGetQuery(
  con,
  "
  SELECT
      obs_id,
      survey_year,
      region_name,
      region_abbrev,
      agent_name,
      acres,
      log_acres,
      is_pancake,
      pdsi
  FROM analysis_observations
  "
) |>
  as_tibble()

analysis_region_year <- dbGetQuery(
  con,
  "
  SELECT
      survey_year,
      region_name,
      region_abbrev,
      n_observations,
      mean_pdsi,
      mean_acres,
      median_acres,
      mean_log_acres,
      pancake_share
  FROM analysis_region_year
  ORDER BY survey_year, region_abbrev
  "
) |>
  as_tibble()

analysis_region_relationships <- dbGetQuery(
  con,
  "
  SELECT
      region_name,
      region_abbrev,
      n_observations,
      mean_pdsi,
      mean_acres,
      median_acres,
      corr_pdsi_acres,
      corr_pdsi_log_acres,
      slope_log_acres_on_pdsi
  FROM analysis_region_relationships
  ORDER BY region_abbrev
  "
) |>
  as_tibble()

plot_sample <- analysis_observations |>
  group_by(region_abbrev) |>
  group_modify(~ slice_sample(.x, n = min(nrow(.x), 5000))) |>
  ungroup()

scatter_plot <- ggplot(plot_sample, aes(x = pdsi, y = log_acres)) +
  geom_point(alpha = 0.12, size = 0.7, color = "#2B6CB0") +
  geom_smooth(method = "lm", se = FALSE, color = "#C05621", linewidth = 0.8) +
  facet_wrap(~region_abbrev) +
  labs(
    title = "Prior-Year PDSI vs Bark Beetle Damage by Region",
    subtitle = "Points are a random sample of up to 5,000 observations per region",
    x = "Prior water-year PDSI",
    y = "Log(acres + 1)"
  ) +
  theme_minimal(base_size = 12)

slope_plot <- analysis_region_relationships |>
  mutate(
    region_abbrev = reorder(region_abbrev, slope_log_acres_on_pdsi)
  ) |>
  ggplot(aes(x = region_abbrev, y = slope_log_acres_on_pdsi)) +
  geom_col(fill = "#2B6CB0") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  coord_flip() +
  labs(
    title = "Regional Slopes of Log Damage on Prior-Year PDSI",
    subtitle = "More negative slopes suggest higher bark beetle damage in drier prior years",
    x = NULL,
    y = "Slope of log(acres + 1) on PDSI"
  ) +
  theme_minimal(base_size = 12)

summary_plot <- ggplot(
  analysis_region_year,
  aes(x = mean_pdsi, y = mean_log_acres, group = region_abbrev)
) +
  geom_path(color = "grey65") +
  geom_point(size = 2.2, color = "#2B6CB0") +
  facet_wrap(~region_abbrev) +
  labs(
    title = "Region-Year Mean PDSI and Mean Damage",
    subtitle = "Each point is one region-year summary",
    x = "Mean prior water-year PDSI",
    y = "Mean log(acres + 1)"
  ) +
  theme_minimal(base_size = 12)

ggsave(
  filename = file.path(fig_dir, "pdsi_vs_log_acres_by_region.png"),
  plot = scatter_plot,
  width = 11,
  height = 8,
  dpi = 300
)

ggsave(
  filename = file.path(fig_dir, "regional_pdsi_slope.png"),
  plot = slope_plot,
  width = 8,
  height = 5,
  dpi = 300
)

ggsave(
  filename = file.path(fig_dir, "region_year_pdsi_damage_summary.png"),
  plot = summary_plot,
  width = 11,
  height = 8,
  dpi = 300
)

message("Wrote figures to: ", fig_dir)
message("  - pdsi_vs_log_acres_by_region.png")
message("  - regional_pdsi_slope.png")
message("  - region_year_pdsi_damage_summary.png")


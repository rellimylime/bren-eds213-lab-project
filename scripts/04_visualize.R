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
  library(tidyr)
  library(broom)
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

# === Panel regression: region FE on region-year data ===
# Pools temporal variation across regions while controlling for each region's
# baseline damage level — closer to the actual question than pooled OLS.
panel_model <- lm(mean_log_acres ~ mean_pdsi + region_abbrev, data = analysis_region_year)

message("\nPanel model (region FE, region-year level):")
print(summary(panel_model))

panel_coef <- tidy(panel_model, conf.int = TRUE) |>
  filter(term == "mean_pdsi") |>
  mutate(region_abbrev = "Panel (FE)", source = "Panel model (region FE)")

# Per-region OLS on region-year summaries: within-region temporal signal only
region_year_fits <- analysis_region_year |>
  group_by(region_abbrev) |>
  group_modify(~ tidy(lm(mean_log_acres ~ mean_pdsi, data = .x), conf.int = TRUE)) |>
  ungroup() |>
  filter(term == "mean_pdsi") |>
  mutate(source = "Per-region OLS (region-year)")

region_year_r2 <- analysis_region_year |>
  group_by(region_abbrev) |>
  group_modify(~ glance(lm(mean_log_acres ~ mean_pdsi, data = .x))) |>
  ungroup() |>
  select(region_abbrev, r.squared, p.value)

message("\nPer-region R² and p-value (region-year OLS):")
print(region_year_r2)

# Pancake sensitivity: per-region slopes on non-pancake observations only
nonpancake_slopes <- analysis_observations |>
  filter(!is_pancake) |>
  group_by(region_abbrev) |>
  group_modify(~ tidy(lm(log_acres ~ pdsi, data = .x), conf.int = TRUE)) |>
  ungroup() |>
  filter(term == "pdsi") |>
  select(region_abbrev, slope_nonpancake = estimate)

region_order <- analysis_region_relationships |>
  arrange(slope_log_acres_on_pdsi) |>
  pull(region_abbrev)

slope_comparison <- analysis_region_relationships |>
  select(region_abbrev, slope_all = slope_log_acres_on_pdsi) |>
  left_join(nonpancake_slopes, by = "region_abbrev") |>
  pivot_longer(
    cols = c(slope_all, slope_nonpancake),
    names_to = "dataset",
    values_to = "slope"
  ) |>
  mutate(
    dataset = ifelse(dataset == "slope_all", "All observations", "Non-pancake only"),
    region_abbrev = factor(region_abbrev, levels = region_order)
  )

# === Figures ===

set.seed(213)

plot_sample <- analysis_observations |>
  group_by(region_abbrev) |>
  group_modify(~ slice_sample(.x, n = min(nrow(.x), 5000))) |>
  ungroup()

# 1. Scatter: observation level, all observations
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

# 2. Slope bars: per-region OLS slopes, all observations
slope_plot <- analysis_region_relationships |>
  mutate(region_abbrev = reorder(region_abbrev, slope_log_acres_on_pdsi)) |>
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

# 3. Region-year scatter: within-region temporal trend with CI
region_year_scatter <- ggplot(
  analysis_region_year,
  aes(x = mean_pdsi, y = mean_log_acres)
) +
  geom_smooth(
    method = "lm", se = TRUE,
    color = "#C05621", fill = "#C05621", alpha = 0.15, linewidth = 0.8
  ) +
  geom_point(size = 2.5, color = "#2B6CB0") +
  geom_text(aes(label = survey_year), size = 2.5, vjust = -0.7, color = "grey30") +
  facet_wrap(~region_abbrev) +
  labs(
    title = "Prior-Year PDSI vs Bark Beetle Damage (Region-Year Level)",
    subtitle = "Each point is one region-year; OLS fit with 95% CI shows within-region temporal trend",
    x = "Mean prior water-year PDSI",
    y = "Mean log(acres + 1)"
  ) +
  theme_minimal(base_size = 12)

# 4. Coefficient plot: panel model vs per-region fits on region-year data
coef_plot_data <- bind_rows(region_year_fits, panel_coef) |>
  mutate(region_abbrev = reorder(region_abbrev, estimate))

panel_coef_plot <- ggplot(
  coef_plot_data,
  aes(x = estimate, y = region_abbrev, color = source)
) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.3) +
  geom_point(size = 3) +
  scale_color_manual(
    values = c(
      "Per-region OLS (region-year)" = "#2B6CB0",
      "Panel model (region FE)" = "#C05621"
    ),
    name = NULL
  ) +
  labs(
    title = "PDSI Slope Estimates with 95% Confidence Intervals",
    subtitle = "Region-year level; negative = more damage in drier prior years",
    x = "Slope of mean log(acres + 1) on mean prior-year PDSI",
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

# 5. Pancake sensitivity: all observations vs non-pancake only
slope_comparison_plot <- ggplot(
  slope_comparison,
  aes(x = slope, y = region_abbrev, fill = dataset)
) +
  geom_col(position = "dodge") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
  scale_fill_manual(
    values = c("All observations" = "#2B6CB0", "Non-pancake only" = "#C05621"),
    name = NULL
  ) +
  labs(
    title = "Pancake Sensitivity: All Observations vs Non-Pancake Only",
    subtitle = "Large differences indicate pancake features are driving the slope in that region",
    x = "Slope of log(acres + 1) on prior-year PDSI",
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

# === Save figures ===

ggsave(
  filename = file.path(fig_dir, "pdsi_vs_log_acres_by_region.png"),
  plot = scatter_plot,
  width = 11, height = 8, dpi = 300
)

ggsave(
  filename = file.path(fig_dir, "regional_pdsi_slope.png"),
  plot = slope_plot,
  width = 8, height = 5, dpi = 300
)

ggsave(
  filename = file.path(fig_dir, "region_year_pdsi_scatter.png"),
  plot = region_year_scatter,
  width = 11, height = 8, dpi = 300
)

ggsave(
  filename = file.path(fig_dir, "panel_model_coef.png"),
  plot = panel_coef_plot,
  width = 9, height = 6, dpi = 300
)

ggsave(
  filename = file.path(fig_dir, "regional_slope_pancake_comparison.png"),
  plot = slope_comparison_plot,
  width = 8, height = 5, dpi = 300
)

message("Wrote figures to: ", fig_dir)
message("  - pdsi_vs_log_acres_by_region.png")
message("  - regional_pdsi_slope.png")
message("  - region_year_pdsi_scatter.png  [new: within-region temporal trend]")
message("  - panel_model_coef.png          [new: panel regression + per-region CIs]")
message("  - regional_slope_pancake_comparison.png  [new: pancake sensitivity]")

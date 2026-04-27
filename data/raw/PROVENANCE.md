# Raw Data Provenance

This repo keeps a local copy of the upstream inputs used for the lab workflow. The authoritative upstream source is the `rellimylime/forest-data-compilation` project.

## Canonical Inputs Used By This Repo

- `data/raw/ids/ids_layers_cleaned.gpkg`
  - Source lineage: upstream `01_ids/scripts/03_clean_ids.R`
  - Layer used here: `damage_areas`
  - Why this file: it has documented lineage from the region geodatabases through the IDS cleaning pipeline.
- `data/raw/lookups/dca_code_lookup.csv`
  - Source lineage: upstream IDS lookup tables.
  - Generated upstream by `01_ids/scripts/02_inspect_ids.R` from all regional damage-area geodatabases.
  - This repo keeps a synced local copy of the corrected upstream lookup.
- `data/raw/lookups/region_lookup.csv`
  - Source lineage: upstream IDS lookup tables.
- `data/raw/climate/terraclimate/damage_areas_summaries/{pdsi,vpd,def,tmmx,soil}.parquet`
  - Source lineage: upstream TerraClimate extraction and summary pipeline.
  - These files store monthly summaries in long format with both `calendar_year`/`calendar_month` and `water_year`/`water_year_month`.

## Inputs Present But Not Used As The Canonical Starting Point

- `data/raw/ids/ids_damage_areas_cleaned.gpkg`
  - Kept for comparison and audit work.
  - Not used by `scripts/01_clean.R` because its lineage is less clearly documented in the upstream repo than `ids_layers_cleaned.gpkg`.

## Cleaning Choices In This Repo

- `scripts/01_clean.R` reads `ids_layers_cleaned.gpkg`, layer `damage_areas`.
- The script filters to bark beetles (`DCA_CODE` 11000-11999), post-2015 surveys, and CONUS regions (`1-6, 8-9`).
- The script keeps pancake features via `is_pancake = OBSERVATION_COUNT == "MULTIPLE"`.
- The climate tables are annualized inside cleaning by taking the mean of monthly `weighted_mean` values for the prior water year (`water_year == survey_year - 1`).

## Upstream Documentation To Cite

- `01_ids/cleaning_log.md`
- `01_ids/docs/ids_layers_overview.md`
- `01_ids/docs/IDS2_FlatFiles_Readme.pdf`
- `02_terraclimate/WORKFLOW.md`
- `docs/ARCHITECTURE.md`
- `Aerial Survey GIS Handbook Appendix E` (2014 damage-code list)

# Bark Beetle Disturbance and Climate Database

**EDS 213: Databases and Data Management**  
**Author:** Emily Miller  
**Institution:** UCSB Bren School of Environmental Science & Management

## Overview

This project builds a relational DuckDB database linking USDA Forest Service aerial insect and disease survey observations to TerraClimate summaries. The goal is to test whether prior-year drought stress helps explain bark beetle damage intensity in the following survey year, and whether that relationship varies by USFS region.

## Analytical Question

Does prior-year Palmer Drought Severity Index (PDSI) predict bark beetle damage intensity (acres affected) the following year, and does that relationship vary across USFS regions?

Project scope:
- Bark beetle agents only (`DCA_CODE` 11000 to 11999)
- Post-2015 IDS observations only
- CONUS USFS regions only (`1-6, 8-9`)

## Repository Structure

```text
bren-eds213-lab-project/
|-- README.md
|-- schema.md
|-- data/
|   |-- README.md
|   |-- raw/
|   |   |-- ids/
|   |   |-- lookups/
|   |   `-- climate/
|   `-- processed/
|       |-- clean/
|       `-- duckdb/
|-- scripts/
|   |-- 01_clean.R
|   |-- clean_helpers.R
|   |-- clean_observations.R
|   |-- clean_climate.R
|   |-- clean_agents.R
|   |-- clean_regions.R
|   |-- write_clean_metadata.R
|   |-- 03_queries.sql
|   |-- 04_visualize.R
|   `-- 02_load.sql
`-- output/
    `-- figures/
```

## Source Data

This repo now treats `data/` as the canonical home for both input files and derived outputs. Raw upstream files go under `data/raw/`, and anything created by this repo goes under `data/processed/`.

Key inputs:
- `data/raw/ids/ids_layers_cleaned.gpkg` (layer `damage_areas`)
- `data/raw/lookups/dca_code_lookup.csv`
- `data/raw/lookups/region_lookup.csv`
- `data/raw/climate/terraclimate/damage_areas_summaries/{pdsi,vpd,def,tmmx,soil}.parquet`

## Workflow

1. Put the upstream source files into the repo under `data/raw/`.
2. Run `scripts/01_clean.R` to build the four clean CSVs and metadata in `data/processed/clean/`.
3. Review `data/processed/clean/metadata.md`, which is generated automatically by the cleaning script.
4. Load the clean tables into DuckDB with `scripts/02_load.sql`.

Supporting raw-data notes live in:
- `data/raw/PROVENANCE.md`
- `data/raw/KNOWN_ISSUES.md`

Example commands:

```bash
Rscript scripts/01_clean.R
```

`scripts/01_clean.R` is a short wrapper that runs these smaller scripts in order:
- `scripts/clean_observations.R`
- `scripts/clean_climate.R`
- `scripts/clean_agents.R`
- `scripts/clean_regions.R`
- `scripts/write_clean_metadata.R`

Then load the database from R:

```r
library(duckdb)
library(DBI)

con <- dbConnect(duckdb(), dbdir = "data/processed/duckdb/bark_beetle.duckdb")
sql <- readLines("scripts/02_load.sql")
dbExecute(con, paste(sql, collapse = "\n"))
dbDisconnect(con, shutdown = TRUE)
```

Or from the command line:

```bash
duckdb data/processed/duckdb/bark_beetle.duckdb < scripts/02_load.sql
```

## Schema

The database contains four tables:
- `regions`
- `agents`
- `observations`
- `climate`

See [schema.md](schema.md) for the full table definitions and design notes.

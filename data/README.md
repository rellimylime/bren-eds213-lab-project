# Data Layout

This repository keeps both source data and derived outputs under `data/`.

Use `data/raw/` for upstream inputs that should not be edited.
Use `data/processed/` for files created by this repo.

Expected layout:

```text
data/
|-- raw/
|   |-- ids/
|   |   |-- ids_layers_cleaned.gpkg
|   |   `-- optional audit copies/
|   |-- lookups/
|   |   |-- dca_code_lookup.csv
|   |   `-- region_lookup.csv
|   `-- climate/terraclimate/damage_areas_summaries/
|       |-- pdsi.parquet
|       |-- vpd.parquet
|       |-- def.parquet
|       |-- tmmx.parquet
|       `-- soil.parquet
`-- processed/
    |-- clean/
    |   |-- observations.csv
    |   |-- climate.csv
    |   |-- agents.csv
    |   |-- regions.csv
    |   `-- metadata.md
    `-- duckdb/
        `-- bark_beetle.duckdb
```

Notes:
- Do not edit the raw source files in `data/raw/`.
- `scripts/01_clean.R` reads `data/raw/ids/ids_layers_cleaned.gpkg` layer `damage_areas`.
- `scripts/01_clean.R` runs several smaller cleaning scripts and writes the clean outputs there.
- `scripts/02_load.sql` reads from `data/processed/clean/`.
- `data/processed/duckdb/` is the recommended home for the DuckDB database file.

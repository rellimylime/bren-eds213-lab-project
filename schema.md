# Database Schema

This project uses four DuckDB tables to model bark beetle disturbance observations, lookup tables, and climate summaries.

## `regions`

Source: `data/raw/lookups/region_lookup.csv`

```sql
CREATE TABLE regions (
    region_id INTEGER PRIMARY KEY,
    region_name VARCHAR NOT NULL,
    region_abbrev VARCHAR NOT NULL
);
```

Notes:
- Limited to CONUS regions `1, 2, 3, 4, 5, 6, 8, 9`
- `region_abbrev` uses the source lookup when available; otherwise `scripts/01_clean.R` derives standard `R#` labels

## `agents`

Source: `data/raw/lookups/dca_code_lookup.csv`

```sql
CREATE TABLE agents (
    agent_code INTEGER PRIMARY KEY,
    agent_name VARCHAR NOT NULL
);
```

Notes:
- Only bark beetle agents are retained
- Bark beetles are defined as `DCA_CODE` values in the `11000` to `11999` range

## `observations`

Source: filtered IDS records from `data/raw/ids/ids_layers_cleaned.gpkg` layer `damage_areas`

```sql
CREATE TABLE observations (
    obs_id VARCHAR PRIMARY KEY,
    region_id INTEGER NOT NULL REFERENCES regions(region_id),
    agent_code INTEGER NOT NULL REFERENCES agents(agent_code),
    survey_year INTEGER NOT NULL,
    acres REAL NOT NULL,
    percent_mid REAL,
    is_pancake BOOLEAN NOT NULL
);
```

Notes:
- Includes post-2015 records only to avoid the pre-2015 intensity metric break
- Includes CONUS regions only
- `percent_mid` remains nullable because some 2015 transition-year records are missing it
- `is_pancake` is derived from `OBSERVATION_COUNT == "MULTIPLE"`
- Exact duplicate IDS rows are collapsed during cleaning; a small number of unresolved conflicting `OBSERVATION_ID` values are excluded so `obs_id` remains unique

## `climate`

Source: weighted-mean TerraClimate summaries from:
- `data/raw/climate/terraclimate/damage_areas_summaries/pdsi.parquet`
- `data/raw/climate/terraclimate/damage_areas_summaries/vpd.parquet`
- `data/raw/climate/terraclimate/damage_areas_summaries/def.parquet`
- `data/raw/climate/terraclimate/damage_areas_summaries/tmmx.parquet`
- `data/raw/climate/terraclimate/damage_areas_summaries/soil.parquet`

```sql
CREATE TABLE climate (
    obs_id VARCHAR PRIMARY KEY REFERENCES observations(obs_id),
    survey_year INTEGER NOT NULL,
    pdsi REAL,
    vpd REAL,
    def REAL,
    tmmx REAL,
    soil REAL
);
```

Notes:
- One row per observation
- Climate values are annualized inside cleaning as prior water-year means of monthly weighted summaries
- Climate values are stored in physical units exactly as provided by the upstream pipeline
- Missing climate values are preserved as `NULL`

## Design Decisions

- Lookup tables are loaded before fact tables so foreign keys resolve cleanly.
- `climate.obs_id` is the primary key because each observation should have at most one set of climate summaries.
- `survey_year` is stored in both `observations` and `climate` for easier validation and downstream analytical joins.
- The cleaning script writes four CSVs plus `data/processed/clean/metadata.md` for ingestion and documentation.

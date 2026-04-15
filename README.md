# Bark Beetle Disturbance & Climate Database

**EDS 213 — Databases and Data Management | Lab Project**  
**Author:** Emily Miller  
**Institution:** UCSB Bren School of Environmental Science & Management  

---

## Overview

This project builds a relational database linking USDA Forest Service aerial insect and disease survey observations to climate data, then uses it to ask: **does prior-year drought stress predict bark beetle damage intensity the following year, and does this vary by USFS region?**

The database is built from compiled datasets maintained in a separate data pipeline repository: [`rellimylime/forest-data-compilation`](https://github.com/rellimylime/forest-data-compilation). That repo handles all raw data downloads, cleaning, and climate extraction. This repo takes those outputs as inputs and focuses on the database design, ingestion, SQL analysis, and visualization.

---

## Analytical Question

> Does prior-year Palmer Drought Severity Index (PDSI) predict bark beetle damage intensity (acres affected) the following year? Does this relationship vary across USFS regions?

**Scope:**
- Post-2015 IDS observations only (avoids methodology break between legacy and DMSM intensity measures)
- Bark beetle damage agents only
- CONUS regions (1–6, 8–9)

---

## Database Schema

Four tables:

| Table | Description | Source |
|---|---|---|
| `observations` | IDS damage polygon records | `ids_terraclimate_merged.csv` |
| `climate` | TerraClimate variables at IDS observation locations | `ids_terraclimate_merged.csv` |
| `agents` | Lookup: damage agent codes and names | `dca_code_lookup.csv` |
| `regions` | Lookup: USFS region codes and names | `region_lookup.csv` |

See [`schema.md`](schema.md) for full table definitions, data types, and key design decisions.

---

## Repository Structure

```
bren-eds213-lab-project/
├── README.md               # This file
├── schema.md               # Week 1: table definitions, keys, design decisions
├── data/
│   └── README.md           # Notes on obtaining source data
├── scripts/
│   ├── 01_clean.R          # Week 2: filter, scale, and prep CSVs for ingestion
│   ├── 02_load.sql         # Week 3: DDL and COPY statements
│   ├── 03_queries.sql      # Weeks 4–5: analytical SQL queries
│   └── 04_visualize.R      # Week 5: ggplot2 figures
└── output/
    └── figures/            # Exported visualizations
```

---

## Source Data

Source data is not tracked in this repository. It is produced by the pipeline in [`rellimylime/forest-data-compilation`](https://github.com/rellimylime/forest-data-compilation) and should be placed in `data/` before running any scripts.

| File | Source location in pipeline repo |
|---|---|
| `ids_terraclimate_merged.csv` | `merged_data/ids_terraclimate_merged.csv` |
| `dca_code_lookup.csv` | `01_ids/lookups/dca_code_lookup.csv` |
| `region_lookup.csv` | `01_ids/lookups/region_lookup.csv` |

---

## Tools

- **Database:** DuckDB
- **Cleaning & visualization:** R (`dplyr`, `ggplot2`, `duckdb`)
- **SQL:** Standard SQL via DuckDB CLI and R `duckdb` package

---

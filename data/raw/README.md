# Raw Data

Place upstream source files here exactly once and treat them as read-only inputs.

Recommended locations:
- `data/raw/ids/ids_layers_cleaned.gpkg`
- `data/raw/lookups/dca_code_lookup.csv`
- `data/raw/lookups/region_lookup.csv`
- `data/raw/climate/terraclimate/damage_areas_summaries/*.parquet`

These files can be large, but this layout keeps the full project self-contained inside the repo.

See also:
- `data/raw/PROVENANCE.md`
- `data/raw/KNOWN_ISSUES.md`

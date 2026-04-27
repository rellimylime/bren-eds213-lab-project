# Clean Table Metadata

This file documents the clean CSV outputs created by the cleaning scripts in `scripts/`.

## observations

Filtered IDS bark beetle observations for post-2015 CONUS surveys.

Row count: 681,181

Source file(s):
- `data/raw/ids/ids_layers_cleaned.gpkg (layer: damage_areas)`

| Column | Data type | Description | Units | Value range / allowed values | NULLs permitted |
| --- | --- | --- | --- | --- | --- |
| obs_id | VARCHAR | Unique IDS observation identifier from OBSERVATION_ID. | None | UUID string; unique per row. | No |
| region_id | INTEGER | USFS region code for the observation. | None | 1-6, 8-9. | No |
| agent_code | INTEGER | Damage-causing agent code for bark beetles. | None | 11000-11999. | No |
| survey_year | INTEGER | Year of the aerial survey observation. | Year | 2015-2024. | No |
| acres | REAL | Area of the damage polygon. | Acres | Positive real values; verify observed range after ingestion. | No |
| percent_mid | REAL | Midpoint percent canopy affected. Some 2015 transition-year records remain missing. | Percent canopy affected | 0-100 when present. | Yes |
| is_pancake | BOOLEAN | TRUE when OBSERVATION_COUNT equals MULTIPLE. | None | TRUE or FALSE. | No |

## climate

Prior water-year means of monthly TerraClimate weighted-mean summaries joined to the filtered IDS observations.

Row count: 681,181

Source file(s):
- `data/raw/climate/terraclimate/damage_areas_summaries/pdsi.parquet`
- `data/raw/climate/terraclimate/damage_areas_summaries/vpd.parquet`
- `data/raw/climate/terraclimate/damage_areas_summaries/def.parquet`
- `data/raw/climate/terraclimate/damage_areas_summaries/tmmx.parquet`
- `data/raw/climate/terraclimate/damage_areas_summaries/soil.parquet`

| Column | Data type | Description | Units | Value range / allowed values | NULLs permitted |
| --- | --- | --- | --- | --- | --- |
| obs_id | VARCHAR | Observation identifier matching observations.obs_id. | None | UUID string; one row per observation. | No |
| survey_year | INTEGER | Survey year from the IDS observation used to choose the prior water-year climate window. | Year | 2015-2024. | No |
| pdsi | REAL | Mean of monthly weighted-mean Palmer Drought Severity Index values from the prior water year. | Unitless index | Expected approximately -10 to 10; verify after ingestion. | Yes |
| vpd | REAL | Mean of monthly weighted-mean TerraClimate vapor pressure deficit values from the prior water year. | Upstream TerraClimate units; verify | Unknown; verify after ingestion. | Yes |
| def | REAL | Mean of monthly weighted-mean TerraClimate climate water deficit values from the prior water year. | Upstream TerraClimate units; verify | Unknown; verify after ingestion. | Yes |
| tmmx | REAL | Mean of monthly weighted-mean TerraClimate maximum temperature values from the prior water year. | Upstream TerraClimate units; verify | Unknown; verify after ingestion. | Yes |
| soil | REAL | Mean of monthly weighted-mean TerraClimate soil moisture values from the prior water year. | Upstream TerraClimate units; verify | Unknown; verify after ingestion. | Yes |

## agents

Lookup table of bark beetle damage agent codes and names.

Row count: 40

Source file(s):
- `data/raw/lookups/dca_code_lookup.csv`

| Column | Data type | Description | Units | Value range / allowed values | NULLs permitted |
| --- | --- | --- | --- | --- | --- |
| agent_code | INTEGER | Bark beetle damage agent lookup code. | None | 11000-11999. | No |
| agent_name | VARCHAR | Common name for the damage-causing agent. | None | Lookup text values from the IDS code table. | No |

## regions

Lookup table of CONUS USFS regions used by the database.

Row count: 8

Source file(s):
- `data/raw/lookups/region_lookup.csv`

| Column | Data type | Description | Units | Value range / allowed values | NULLs permitted |
| --- | --- | --- | --- | --- | --- |
| region_id | INTEGER | USFS region identifier used in IDS. | None | 1-6, 8-9. | No |
| region_name | VARCHAR | Human-readable USFS region name. | None | Northern, Rocky Mountain, Southwestern, Intermountain, Pacific Southwest (CA), Pacific Northwest, Southern, Eastern. | No |
| region_abbrev | VARCHAR | Standard region abbreviation. Derived as R{region_id} when the source lookup does not provide one. | None | R1, R2, R3, R4, R5, R6, R8, R9. | No |


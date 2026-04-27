# Known Raw Data Issues

These notes explain the main upstream quirks that affect cleaning and interpretation in this repo.

## IDS Method Break Around 2015

Pre-2015 IDS records use legacy intensity fields, while 2015+ records use DMSM canopy-affected measures such as `PERCENT_MID`. This repo keeps `SURVEY_YEAR >= 2015` so intensity is more comparable across observations.

## Pancake Features

Upstream IDS documentation describes pancake features as multiple observations that share one geometry (`DAMAGE_AREA_ID`) but have distinct `OBSERVATION_ID` values and `OBSERVATION_COUNT = "MULTIPLE"`. These rows are kept because they represent distinct observations, but area should not be naively summed across them without accounting for shared geometry.

## Duplicated `OBSERVATION_ID` Values

The upstream climate extraction code explicitly notes that about 3,500 duplicated `OBSERVATION_ID` values appear in raw IDS data and are removed with `distinct()` when building the observation-to-geometry lookup.

For this lab repo:

- exact duplicate rows are collapsed during cleaning with `distinct()`
- a small set of remaining conflicting `OBSERVATION_ID` values is dropped so `obs_id` can remain the primary key in the assignment schema

## Region 6 / 2023 Conflict Cases

After collapsing exact duplicates, a small set of Region 6 records from survey year 2023 still reuse the same `OBSERVATION_ID` for different bark beetle agents. That pattern does not match the documented pancake definition, so these records are treated as unresolved source anomalies and are excluded from `observations.csv`.

## Climate Time Window Ambiguity

The TerraClimate summaries are monthly long-format outputs, not one annual row per observation. Upstream documentation says the appropriate join window should be chosen at analysis time. This repo resolves that ambiguity in cleaning by using prior water-year climate (`water_year == survey_year - 1`) and averaging monthly `weighted_mean` values within that window.

## Missing Climate Values

Some observations legitimately retain `NA` climate values because their centroids or intersecting pixels fall in TerraClimate NoData areas or otherwise fail to produce usable summaries. These rows are kept.

## Lookup Table Provenance

The IDS lookup CSVs come from `01_ids/scripts/02_inspect_ids.R` in the reference repo. Earlier versions of that workflow generated some lookups from a Region 5 sample only, which undercounted the full set of codes present across all regional geodatabases. The reference repo generator has now been corrected to build the lookup tables from all regions, and this lab repo uses the synced corrected DCA lookup output.

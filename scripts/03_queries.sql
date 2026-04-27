-- Analysis queries for bark beetle damage and prior-year drought stress.
-- Run after scripts/02_load.sql, for example:
-- duckdb data/processed/duckdb/bark_beetle.duckdb < scripts/03_queries.sql

-- Important note:
-- IDS pancake features can share the same geometry across multiple observations.
-- Because of that, this script summarizes acres with means and medians instead of
-- summing total acres across observations.

-- 1. Observation-level analysis view.
-- This is the main table to use in R for plotting and modeling.
CREATE OR REPLACE VIEW analysis_observations AS
SELECT
    o.obs_id,
    o.survey_year,
    o.region_id,
    r.region_name,
    r.region_abbrev,
    o.agent_code,
    a.agent_name,
    o.acres,
    LN(o.acres + 1) AS log_acres,
    o.percent_mid,
    o.is_pancake,
    c.pdsi,
    c.vpd,
    c.def,
    c.tmmx,
    c.soil
FROM observations AS o
INNER JOIN climate AS c
    ON o.obs_id = c.obs_id
    AND o.survey_year = c.survey_year
INNER JOIN regions AS r
    ON o.region_id = r.region_id
INNER JOIN agents AS a
    ON o.agent_code = a.agent_code
WHERE c.pdsi IS NOT NULL;

-- 2. Region-by-year summary.
-- This is useful for plotting average conditions over time by region.
CREATE OR REPLACE VIEW analysis_region_year AS
SELECT
    survey_year,
    region_id,
    region_name,
    region_abbrev,
    COUNT(*) AS n_observations,
    AVG(acres) AS mean_acres,
    MEDIAN(acres) AS median_acres,
    AVG(log_acres) AS mean_log_acres,
    AVG(pdsi) AS mean_pdsi,
    AVG(CASE WHEN is_pancake THEN 1.0 ELSE 0.0 END) AS pancake_share
FROM analysis_observations
GROUP BY
    survey_year,
    region_id,
    region_name,
    region_abbrev;

-- 3. Region-level relationship summary.
-- This gives one line per region with simple descriptive relationship metrics.
CREATE OR REPLACE VIEW analysis_region_relationships AS
SELECT
    region_id,
    region_name,
    region_abbrev,
    COUNT(*) AS n_observations,
    AVG(pdsi) AS mean_pdsi,
    AVG(acres) AS mean_acres,
    MEDIAN(acres) AS median_acres,
    CORR(pdsi, acres) AS corr_pdsi_acres,
    CORR(pdsi, log_acres) AS corr_pdsi_log_acres,
    REGR_SLOPE(log_acres, pdsi) AS slope_log_acres_on_pdsi,
    REGR_INTERCEPT(log_acres, pdsi) AS intercept_log_acres_on_pdsi,
    REGR_R2(log_acres, pdsi) AS r2_log_acres_on_pdsi
FROM analysis_observations
GROUP BY
    region_id,
    region_name,
    region_abbrev
ORDER BY region_abbrev;

-- Verification: number of usable observations in the analysis view.
SELECT
    COUNT(*) AS analysis_rows,
    MIN(survey_year) AS min_year,
    MAX(survey_year) AS max_year
FROM analysis_observations;

-- Quick look at the observation-level analysis table.
SELECT
    obs_id,
    survey_year,
    region_abbrev,
    agent_name,
    acres,
    log_acres,
    is_pancake,
    pdsi
FROM analysis_observations
ORDER BY survey_year, region_abbrev, obs_id
LIMIT 10;

-- Region-level relationship results.
SELECT
    region_abbrev,
    n_observations,
    mean_pdsi,
    mean_acres,
    median_acres,
    corr_pdsi_acres,
    corr_pdsi_log_acres,
    slope_log_acres_on_pdsi,
    r2_log_acres_on_pdsi
FROM analysis_region_relationships
ORDER BY region_abbrev;

-- Full region-by-year summary table.
SELECT
    survey_year,
    region_abbrev,
    n_observations,
    mean_pdsi,
    mean_acres,
    median_acres,
    mean_log_acres,
    pancake_share
FROM analysis_region_year
ORDER BY survey_year, region_abbrev;

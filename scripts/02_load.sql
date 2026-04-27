-- Load clean bark beetle tables into DuckDB.
-- Run from the repo root, for example:
-- duckdb data/processed/duckdb/bark_beetle.duckdb < scripts/02_load.sql

BEGIN TRANSACTION;

DROP TABLE IF EXISTS climate;
DROP TABLE IF EXISTS observations;
DROP TABLE IF EXISTS agents;
DROP TABLE IF EXISTS regions;

CREATE TABLE regions (
    region_id INTEGER PRIMARY KEY,
    region_name VARCHAR NOT NULL,
    region_abbrev VARCHAR NOT NULL
);

CREATE TABLE agents (
    agent_code INTEGER PRIMARY KEY,
    agent_name VARCHAR NOT NULL
);

CREATE TABLE observations (
    obs_id VARCHAR PRIMARY KEY,
    region_id INTEGER NOT NULL REFERENCES regions(region_id),
    agent_code INTEGER NOT NULL REFERENCES agents(agent_code),
    survey_year INTEGER NOT NULL,
    acres REAL NOT NULL,
    percent_mid REAL,
    is_pancake BOOLEAN NOT NULL
);

CREATE TABLE climate (
    obs_id VARCHAR PRIMARY KEY REFERENCES observations(obs_id),
    survey_year INTEGER NOT NULL,
    pdsi REAL,
    vpd REAL,
    def REAL,
    tmmx REAL,
    soil REAL
);

COPY regions (region_id, region_name, region_abbrev)
FROM 'data/processed/clean/regions.csv'
(HEADER, DELIMITER ',');

COPY agents (agent_code, agent_name)
FROM 'data/processed/clean/agents.csv'
(HEADER, DELIMITER ',');

COPY observations (obs_id, region_id, agent_code, survey_year, acres, percent_mid, is_pancake)
FROM 'data/processed/clean/observations.csv'
(HEADER, DELIMITER ',');

COPY climate (obs_id, survey_year, pdsi, vpd, def, tmmx, soil)
FROM 'data/processed/clean/climate.csv'
(HEADER, DELIMITER ',');

COMMIT;

-- Verification 1: row counts by table.
SELECT 'regions' AS table_name, COUNT(*) AS row_count FROM regions
UNION ALL
SELECT 'agents' AS table_name, COUNT(*) AS row_count FROM agents
UNION ALL
SELECT 'observations' AS table_name, COUNT(*) AS row_count FROM observations
UNION ALL
SELECT 'climate' AS table_name, COUNT(*) AS row_count FROM climate
ORDER BY table_name;

-- Verification 2: confirm PDSI values are in the expected scaled range.
SELECT
    MIN(pdsi) AS min_pdsi,
    MAX(pdsi) AS max_pdsi,
    COUNT(*) FILTER (WHERE pdsi IS NULL) AS pdsi_null_rows,
    COUNT(*) FILTER (WHERE pdsi < -10 OR pdsi > 10) AS pdsi_out_of_range_rows
FROM climate;

-- Verification 3: test a join across all four tables.
SELECT
    o.obs_id,
    o.survey_year,
    r.region_name,
    r.region_abbrev,
    a.agent_name,
    o.acres,
    o.percent_mid,
    o.is_pancake,
    c.pdsi,
    c.vpd,
    c.def,
    c.tmmx,
    c.soil
FROM observations AS o
INNER JOIN regions AS r
    ON o.region_id = r.region_id
INNER JOIN agents AS a
    ON o.agent_code = a.agent_code
INNER JOIN climate AS c
    ON o.obs_id = c.obs_id
LIMIT 10;

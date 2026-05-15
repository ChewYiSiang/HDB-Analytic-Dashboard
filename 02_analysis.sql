-- ═══════════════════════════════════════════════════════════════════════════
-- HDB Resale Price Analysis — SQL Queries
-- Database: hdb_resale  |  Table: resale_transactions
-- Run these in DBeaver, psql, or any PostgreSQL client.
-- Each query answers one business question for your Power BI dashboard.
-- ═══════════════════════════════════════════════════════════════════════════
SELECT COUNT(*) FROM resale_transactions;

-- ── SECTION 1: OVERVIEW ────────────────────────────────────────────────────

-- Q1. How many transactions and what is the total/average resale value?
SELECT
    COUNT(*)                                   AS total_transactions,
    MIN(month)                                 AS earliest_date,
    MAX(month)                                 AS latest_date,
    ROUND(AVG(resale_price))                   AS avg_price,
    ROUND(PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resale_price))  AS median_price,
    SUM(resale_price)                          AS total_value_sgd
FROM resale_transactions;


-- Q2. Annual transaction volume and average price trend (for a line chart)
SELECT
    year,
    COUNT(*)                                   AS transactions,
    ROUND(AVG(resale_price))                   AS avg_price,
    ROUND(PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resale_price))  AS median_price,
    ROUND(AVG(price_per_sqm))                  AS avg_price_per_sqm
FROM resale_transactions
GROUP BY year
ORDER BY year;


-- ── SECTION 2: TOWN ANALYSIS ───────────────────────────────────────────────

-- Q3. Top 10 most expensive towns by median resale price (for a bar chart)
SELECT
    town,
    COUNT(*)                                   AS transactions,
    ROUND(PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resale_price))  AS median_price,
    ROUND(AVG(price_per_sqm))                  AS avg_price_per_sqm
FROM resale_transactions
GROUP BY town
HAVING COUNT(*) >= 100          -- exclude towns with too few data points
ORDER BY median_price DESC
LIMIT 10;


-- Q4. Town price change: compare last 2 years vs previous 2 years
WITH base AS (
    SELECT
        town,
        AVG(CASE WHEN year >= 2023 THEN resale_price END)  AS avg_recent,
        AVG(CASE WHEN year BETWEEN 2021 AND 2022
                 THEN resale_price END)                     AS avg_prior
    FROM resale_transactions
    WHERE year >= 2021
    GROUP BY town
)
SELECT
    town,
    ROUND(avg_recent)                                  AS avg_price_recent,
    ROUND(avg_prior)                                   AS avg_price_prior,
    ROUND(((avg_recent - avg_prior) / avg_prior) * 100, 1) AS pct_change
FROM base
WHERE avg_prior IS NOT NULL
  AND avg_recent IS NOT NULL
ORDER BY pct_change DESC;


-- ── SECTION 3: FLAT TYPE ANALYSIS ─────────────────────────────────────────

-- Q5. Median price by flat type, for latest full year
SELECT
    flat_type,
    COUNT(*)                                   AS transactions,
    ROUND(PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resale_price))  AS median_price,
    ROUND(AVG(floor_area_sqm), 1)              AS avg_floor_area_sqm,
    ROUND(AVG(price_per_sqm))                  AS avg_price_per_sqm
FROM resale_transactions
WHERE year = (SELECT MAX(year) FROM resale_transactions)
GROUP BY flat_type
ORDER BY median_price DESC;


-- Q6. 5-room flat price trend by year (detailed segment for PowerBI slicer)
SELECT
    year,
    flat_type,
    ROUND(PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resale_price))  AS median_price,
    COUNT(*)                                   AS transactions
FROM resale_transactions
GROUP BY year, flat_type
ORDER BY flat_type, year;


-- ── SECTION 4: VALUE ANALYSIS ──────────────────────────────────────────────

-- Q7. Best-value towns: high floor area, low price per sqm, recent data
SELECT
    town,
    flat_type,
    ROUND(AVG(floor_area_sqm), 1)              AS avg_floor_area_sqm,
    ROUND(AVG(price_per_sqm))                  AS avg_price_per_sqm,
    ROUND(PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resale_price))  AS median_price,
    COUNT(*)                                   AS transactions
FROM resale_transactions
WHERE year >= 2023
  AND flat_type IN ('4 ROOM', '5 ROOM')
GROUP BY town, flat_type
HAVING COUNT(*) >= 20
ORDER BY avg_price_per_sqm ASC
LIMIT 15;


-- Q8. Impact of storey on price (are higher floors really worth more?)
SELECT
    storey_range,
    COUNT(*)                                   AS transactions,
    ROUND(AVG(resale_price))                   AS avg_price,
    ROUND(AVG(price_per_sqm))                  AS avg_price_per_sqm
FROM resale_transactions
WHERE year >= 2022
  AND flat_type = '4 ROOM'
GROUP BY storey_range
ORDER BY storey_range;


-- ── SECTION 5: LEASE AND MODEL ANALYSIS ───────────────────────────────────

-- Q9. Does remaining lease affect price? (group into buckets)
SELECT
    CASE
        WHEN remaining_lease_years >= 90 THEN '90+ years'
        WHEN remaining_lease_years >= 75 THEN '75–89 years'
        WHEN remaining_lease_years >= 60 THEN '60–74 years'
        WHEN remaining_lease_years >= 45 THEN '45–59 years'
        ELSE 'Under 45 years'
    END                                        AS lease_bucket,
    COUNT(*)                                   AS transactions,
    ROUND(AVG(resale_price))                   AS avg_price,
    ROUND(AVG(price_per_sqm))                  AS avg_price_per_sqm
FROM resale_transactions
WHERE year >= 2022
GROUP BY lease_bucket
ORDER BY avg_price DESC;


-- ── SECTION 6: EXPORT VIEWS FOR POWER BI ──────────────────────────────────
-- Create these views; Power BI connects directly to them via DirectQuery
-- or you can export each as a CSV with: \copy (SELECT ...) TO 'file.csv' CSV HEADER

CREATE OR REPLACE VIEW vw_annual_trend AS
SELECT
    year,
    COUNT(*)                                    AS transactions,
    ROUND(AVG(resale_price))                    AS avg_price,
    ROUND(PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resale_price))   AS median_price,
    ROUND(AVG(price_per_sqm))                   AS avg_price_per_sqm
FROM resale_transactions
GROUP BY year
ORDER BY year;

CREATE OR REPLACE VIEW vw_town_summary AS
SELECT
    town,
    year,
    flat_type,
    COUNT(*)                                    AS transactions,
    ROUND(AVG(resale_price))                    AS avg_price,
    ROUND(PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resale_price))   AS median_price,
    ROUND(AVG(price_per_sqm))                   AS avg_price_per_sqm,
    ROUND(AVG(floor_area_sqm), 1)               AS avg_floor_area_sqm
FROM resale_transactions
GROUP BY town, year, flat_type;

CREATE OR REPLACE VIEW vw_full_detail AS
SELECT
    month,
    year,
    qtr,
    town,
    flat_type,
    storey_range,
    floor_area_sqm,
    flat_model,
    remaining_lease_years,
    resale_price,
    price_per_sqm
FROM resale_transactions;

SELECT inet_server_addr(), inet_server_port();
-- ═══════════════════════════════════════════════════════════════════════════
-- Export each view to CSV (run in psql terminal):
--   \copy (SELECT * FROM vw_annual_trend)  TO 'annual_trend.csv'  CSV HEADER
--   \copy (SELECT * FROM vw_town_summary)  TO 'town_summary.csv'  CSV HEADER
--   \copy (SELECT * FROM vw_full_detail)   TO 'full_detail.csv'   CSV HEADER
-- ═══════════════════════════════════════════════════════════════════════════

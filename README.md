# HDB Resale Price Analysis 🏠📊

End-to-end data analytics project using **PostgreSQL**, **Python**, and **Power BI** to analyse Singapore HDB resale flat transactions from 2017 to 2026.

Built as a portfolio project demonstrating SQL proficiency, data pipeline engineering, and business intelligence visualisation.

---

## Project Overview

Singapore's public housing resale market is one of the most data-rich and socially significant housing markets in Asia. This project answers five key business questions:

1. How have HDB resale prices trended over time?
2. Which towns command the highest (and best-value) prices?
3. Does flat type, storey, or remaining lease significantly affect price?
4. Where are prices rising fastest right now?
5. What is the best value for a 4-room or 5-room flat in 2024–2025?

---

## Tech Stack

| Layer | Tool |
|---|---|
| Data source | [data.gov.sg API](https://data.gov.sg/datasets/d_8b84c4ee58e3cfc0ece0d773c8ca6abc/view) |
| Ingestion | Python 3.11 (requests, pandas, sqlalchemy) |
| Storage | PostgreSQL (pgAdmin4) |
| Analysis | SQL (DBeaver) |
| Dashboard | Power BI Desktop |

---

## Dataset

- **Source:** Housing & Development Board via data.gov.sg
- **Coverage:** January 2017 – 2026 (present) (~231,000 transactions)
- **Columns:** month, town, flat\_type, block, street\_name, storey\_range, floor\_area\_sqm, flat\_model, lease\_commence\_date, resale\_price
- **Derived columns added in SQL:** year, quarter, remaining\_lease\_years, price\_per\_sqm
- **Derived columns/measures in Power BI:** lease\_bucket, town\_coordinates, price\_growth\_%, median\_price

---

## Project Structure

```
hdb-resale-project/
├── 01_ingest.py             # Fetch from API → clean → load to PostgreSQL
├── 02_analysis.sql          # SQL queries + views for all 5 business questions
├── powerbi/
│   ├── HDB_Dashboard.pbix   # Power BI dashboard file
│   └── HDB_Dashboard.pdf    # Exported PDF of all 5 dashboard pages
├── requirements.txt
└── README.md
```

---

## Setup

### 1. Prerequisites

```bash
# Install Python dependencies
pip install -r requirements.txt

# PostgreSQL must be running locally (or via Docker)
```

### 2. Create the database

```sql
-- In psql or DBeaver:
CREATE DATABASE hdb_resale;
```

### 3. Run the ingestion pipeline

```bash
python 01_ingest.py
# Expected output:
# Fetching data from data.gov.sg …
# Fetched 231,000 / 231,000 records …
# Loaded 231,000 rows into resale_transactions.
```

### 4. Run SQL analysis

Open `02_analysis.sql` in DBeaver (or any PostgreSQL client) and run each section. The final section creates three views used directly by Power BI:

```sql
vw_annual_trend    -- year-level aggregates for KPIs and trend line
vw_town_summary    -- town × year × flat_type aggregates for town and value pages
vw_full_detail     -- row-level view for storey and lease analysis
```

### 5. Open the Power BI dashboard

Open `powerbi/HDB_Dashboard.pbix` and connect to your local PostgreSQL instance, or import the exported CSVs as flat files if PostgreSQL is not available.

---

## Key SQL Techniques Demonstrated

- **Percentile aggregates** — `PERCENTILE_CONT(0.5)` for true median prices rather than averages
- **CTEs** — multi-step comparisons between recent and prior time periods
- **Conditional aggregation** — comparing 2023–2024 vs 2021–2022 prices in a single query
- **CASE WHEN bucketing** — grouping remaining lease years into readable segments
- **View creation** — three reusable query layers consumed by Power BI via DirectQuery

---

## Dashboard Pages

### Page 1 — Overview

![overview](powerbi\screenshots\[overview].png)

**Visuals:** 3 KPI cards (total transactions, median resale price, avg price/sqm) · dual-axis line chart (median price and avg price/sqm by year)

**Key figures:** 231K total transactions · $504.9K median resale price · $5,573 avg price/sqm

The trend line tracking both median resale price and average price per sqm tells a consistent upward story. Crucially, both lines move together — meaning the price increase isn't an artefact of larger flats dominating recent sales. The price per square metre is going up too, which points to genuine market-wide appreciation.

When median price and price/sqm rise in parallel, it signals real demand pressure and not a composition effect. Buyers are paying more for the same space year after year.

---

### Page 2 — Town Analysis

![town](powerbi/screenshots/[town].png)

**Visuals:** Top 10 towns bar chart (by median price) · choropleth map (colour = median price) · price growth % table

**Top towns by median price:** Bukit Timah ($810K) · Bishan ($780K) · Queenstown ($710K) · Central Area ($700K) · Clementi ($620K)

The top-10 town bar chart reveals a clear split between mature central estates (Bishan, Queenstown, Toa Payoh) and fringe towns (Woodlands, Yishun). The price gap between the most expensive and cheapest towns in the top 10 exceeds 60% for flats of the same type and size.

The choropleth map makes this geographic clustering immediately visible. Prices are densest in the central corridor and thin out towards the north and west, closely mirroring Singapore's urban planning hierarchy and MRT network maturity.

Crossing from a fringe town to a central estate can add $150,000–$250,000 to the price for a comparable flat. That premium reflects MRT proximity, school catchment zones, and amenity density, which are factors that don't change quickly.

---

### Page 3 — Flat Type Deep Dive

![flat type](powerbi/screenshots/[flat_type].png)

**Visuals:** Median price by flat type (bar) · remaining lease by flat type (bar) · storey range vs resale price (line)

**Median prices by type:** 1-Room $219K · 2-Room $285K · 3-Room $376K · 4-Room $568K · 5-Room $711K · Executive $817K · Multi-Generation $922K

The median price by flat type chart shows that the jump from 4-room to 5-room is proportionally larger than from 3-room to 4-room. Buyers are paying a premium not just for the extra floor area, but for the extra bedroom itself. This shows a pattern driven by family formation demand.

The storey range line tells a clear story: every storey band commands a measurable premium, with the effect steepening above the 20th floor. High floor units in popular estates can fetch significantly more than comparable low floor units in the same block.

The remaining lease chart adds an important counterpoint: larger flat types tend to have shorter remaining leases, because executive and 5-room flats were predominantly built in the 1980s–90s. Buyers drawn to larger flats for the space need to weigh the lease depreciation carefully.

---

### Page 4 — Value Finder

![value finder](powerbi/screenshots/[value_finder].png)

**Visuals:** Two price/sqm matrices — top 5 highest and top 5 lowest towns by avg price/sqm, broken down by flat type, with conditional colour formatting (green = best value, red = most expensive)

**Most expensive (price/sqm):** Central Area 4-Room at $10,117/sqm · Central Area 5-Room at $9,390/sqm · Queenstown 3-Room at $8,932/sqm

**Best value (price/sqm):** Woodlands 5-Room at $4,430/sqm · Woodlands Executive at $4,779/sqm · Yishun 5-Room at $4,897/sqm

A 5-room flat in Yishun or Woodlands offers significantly more floor area per dollar than a 3-room flat in Bukit Merah or Queenstown, while still being a newer, well-maintained town. For buyers prioritising space over address, the fringe towns dominate the value matrix.

---

### Page 5 — Lease Analysis

![lease](powerbi/screenshots/[lease].png)

**Visuals:** Median price by lease bucket (bar) · transaction share by lease bucket (donut)

**Median price by lease bucket:** 90+ yrs $563.9K · 70–89 yrs $540K · 50–69 yrs $428K · <50 yrs $330K

**Transaction share:** 90+ yrs 23.76% (137K) · 70–89 yrs 34.2% (197K) · 50–69 yrs 39.46% (227K) · <50 yrs 2.58% (15K)

The lease analysis page makes the depreciation effect concrete. Flats with 90+ years remaining have the highest median prices, while those with under 50 years are significantly cheaper, but come with real constraints on financing and future resale value.

The transaction volume donut shows that the market is dominated by flats with longer leases, reflecting both new supply (flats sold in the last 30 years) and buyer preference. The '<50' year segment is thin in volume, which can make pricing erratic and exits harder.

---

## Key Insights

- **Prices are rising genuinely, not just compositionally.** Both median price and price/sqm have risen in parallel from 2017 to 2026, ruling out a flat-size mix effect and confirming real market-wide appreciation.
- **Location is the single biggest price driver.** Bukit Timah and Bishan command medians above $780K, while fringe towns sit below $500K, with a gap of over 60% for comparable flat types.
- **Bigger flats carry a hidden lease risk.** Executive and 5-room flats average only 65–71 years remaining lease, versus 77–81 years for 4-room and 2-room flats, because the larger stock is older.
- **The storey premium is real and accelerating.** Price rises consistently with each storey band, steepening noticeably above the 20th floor.
- **Best space-for-money:** Woodlands and Yishun 5-room flats at ~$4,430–$4,897/sqm versus Central Area at $9,390–$10,117/sqm, more than double the cost per sqm for a central address.

---

## What I Learned

- Designing a reproducible ETL pipeline using Python + PostgreSQL, including pagination handling for large API datasets
- Writing analytical SQL beyond basic SELECT (CTEs, window functions, percentile aggregates, conditional aggregation)
- Translating raw transactional data into business-readable insights across five distinct analytical angles
- Building a multi-page Power BI report with DAX measures, cross-filtering, dual-axis charts, coordinate-based choropleth maps, and conditional formatting matrices

---

## Data Source

Housing & Development Board. (2021). *Resale flat prices based on registration date from Jan-2017 onwards* (2025) [Dataset]. data.gov.sg. Retrieved from https://data.gov.sg/datasets/d_8b84c4ee58e3cfc0ece0d773c8ca6abc/view

Licensed under the [Singapore Open Data Licence](https://data.gov.sg/open-data-licence).

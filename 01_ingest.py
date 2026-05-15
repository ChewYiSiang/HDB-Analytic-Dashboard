"""
HDB Resale Price Analysis — Step 1: Data Ingestion
Fetches data from data.gov.sg API and loads it into PostgreSQL.

Dataset: Resale flat prices from Jan 2017 onwards
Source:  https://data.gov.sg/datasets/d_8b84c4ee58e3cfc0ece0d773c8ca6abc/view
"""

import requests
import pandas as pd
from sqlalchemy import create_engine, text
import time

# ── CONFIG ────────────────────────────────────────────────────────────────────
DATASET_ID = "d_8b84c4ee58e3cfc0ece0d773c8ca6abc"
API_BASE   = "https://data.gov.sg/api/action/datastore_search"
PAGE_LIMIT = 10000          # records per request (max allowed)
DB_URL     = "postgresql://postgres:4321@localhost:5432/hdb_resale"
# DB_URL Format: postgresql://<user>:<password>@<host>:<port>/<database>
# ─────────────────────────────────────────────────────────────────────────────


def fetch_all_records() -> pd.DataFrame:
    """Page through the API until all records are fetched."""
    all_records = []
    offset = 0

    print("Fetching data from data.gov.sg …")
    while True:
        params = {
            "resource_id": DATASET_ID,
            "limit":       PAGE_LIMIT,
            "offset":      offset,
        }
        resp = requests.get(API_BASE, params=params, timeout=30)
        resp.raise_for_status()

        data    = resp.json()["result"]
        records = data["records"]
        total   = data["total"]

        if not records:
            break

        all_records.extend(records)
        offset += len(records)
        print(f"  Fetched {offset:,} / {total:,} records …", end="\r")

        if offset >= total:
            break

        time.sleep(0.2)

    print(f"\nDone — {len(all_records):,} records fetched.")
    return pd.DataFrame(all_records)


def clean(df: pd.DataFrame) -> pd.DataFrame:
    """Type-cast and add derived columns."""
    # Drop internal API columns (_id = rank, remaining_lease = raw string duplicate)
    df = df.drop(columns=["_id", "remaining_lease"], errors="ignore")

    # Parse month as a proper date (first day of the month)
    df["month"] = pd.to_datetime(df["month"], format="%Y-%m")
    df["year"]  = df["month"].dt.year
    df["qtr"]   = df["month"].dt.quarter

    # Numeric columns
    df["resale_price"]     = pd.to_numeric(df["resale_price"],     errors="coerce")
    df["floor_area_sqm"]   = pd.to_numeric(df["floor_area_sqm"],   errors="coerce")
    df["lease_commence_date"] = pd.to_numeric(df["lease_commence_date"], errors="coerce")

    # Derived: remaining lease years (approximate)
    df["remaining_lease_years"] = (
        df["lease_commence_date"] + 99 - df["year"]
    ).clip(lower=0)

    # Derived: price per sqm
    df["price_per_sqm"] = (df["resale_price"] / df["floor_area_sqm"]).round(2)

    # Standardise strings
    for col in ["town", "flat_type", "storey_range", "flat_model", "street_name"]:
        if col in df.columns:
            df[col] = df[col].str.strip().str.upper()

    return df


def load_to_postgres(df: pd.DataFrame, engine) -> None:
    """Create schema and insert data."""
    with engine.connect() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS resale_transactions (
                month                   DATE,
                year                    SMALLINT,
                qtr                     SMALLINT,
                town                    VARCHAR(50),
                flat_type               VARCHAR(20),
                block                   VARCHAR(10),
                street_name             VARCHAR(100),
                storey_range            VARCHAR(20),
                floor_area_sqm          NUMERIC(8,2),
                flat_model              VARCHAR(50),
                lease_commence_date     SMALLINT,
                remaining_lease_years   SMALLINT,
                resale_price            NUMERIC(12,2),
                price_per_sqm           NUMERIC(10,2)
            );
        """))
        conn.execute(text("TRUNCATE resale_transactions;"))
        conn.commit()

    df.to_sql(
        "resale_transactions",
        engine,
        if_exists="append",
        index=False,
        chunksize=5000,
        method="multi",
    )
    print(f"Loaded {len(df):,} rows into resale_transactions.")


if __name__ == "__main__":
    raw = fetch_all_records()
    cleaned = clean(raw)
    print(cleaned.head())
    print(cleaned.dtypes)

    engine = create_engine(DB_URL)
    load_to_postgres(cleaned, engine)
    print("Ingestion complete.")

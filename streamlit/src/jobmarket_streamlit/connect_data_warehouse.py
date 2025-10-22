from pathlib import Path
import duckdb

import streamlit as st
from dotenv import load_dotenv
from pandas import DataFrame

# data warehouse directory
db_path = str(Path(__file__).parents[3] / "data/job_ads.duckdb")

def query_job_listings(mart_table: str) -> DataFrame:
    """Queries a job listings table and returns the data as a pandas DataFrame."""
    with duckdb.connect(db_path, read_only=True) as conn:
        query = f"SELECT * FROM {mart_table}"

        print(f"Executing query and fetching data for '{mart_table}'...")

        cursor = conn.cursor()
        cursor.execute(query)
        df = cursor.fetch_pandas_all()

        print(f"Successfully fetched {len(df)} rows into a Pandas DataFrame.")

        return df


@st.cache_data
def get_job_listings(mart_table: str) -> DataFrame:
    return query_job_listings(mart_table)


def get_ddb_conn(
    mart_tables: list[str] | None = None,
    schema: str | None = None,
    ddb_table_name_prefix: str | None = None,
) -> duckdb.DuckDBPyConnection:
     with duckdb.connect(db_path, read_only=True) as conn:
        return conn


@st.cache_resource
def get_db_connection(
    mart_tables: list[str],
    schema: str | None = None,
    ddb_table_name_prefix: str | None = None,
) -> duckdb.DuckDBPyConnection:
    return get_ddb_conn(mart_tables, ddb_table_name_prefix, schema)

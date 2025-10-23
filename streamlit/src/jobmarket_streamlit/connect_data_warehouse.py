from pathlib import Path
from dotenv import load_dotenv
import duckdb
from pandas import DataFrame
import os
import streamlit as st

load_dotenv()
DUCKDB_PATH = os.getenv("DUCKDB_PATH")
STREAMLIT_DEFAULT_SCHEMA = "marts"  # MARTS_SCHEMA


@st.cache_resource
def get_cached_ddb_conn(read_only: bool = True):
    """Returns a cached Streamlit-resource DuckDBPyConnection."""
    return duckdb.connect(str(DUCKDB_PATH), read_only=read_only)


def get_ddb_df(conn: duckdb.DuckDBPyConnection, table: str, schema: str, uppercase_columns: bool = False) -> DataFrame:
    """Fetches a table and returns the data as a pandas DataFrame."""
    print(f"Fetching data from '{schema}.{table}'...")

    df = conn.sql(f"SELECT * FROM {schema}.{table}").to_df()

    if uppercase_columns:
        df.columns = [str(col).upper() for col in df.columns]

    print(f"Successfully fetched {len(df)} rows into a Pandas DataFrame.")
    return df


@st.cache_data
def get_cached_ddb_df(table: str, schema: str | None = None, uppercase_columns: bool = False) -> DataFrame:
    """Fetches a table and returns the data as a cached Streamlit-dataset pandas DataFrame."""
    if schema is None:
        schema = STREAMLIT_DEFAULT_SCHEMA

    return get_ddb_df(get_cached_ddb_conn(), table, schema, uppercase_columns)

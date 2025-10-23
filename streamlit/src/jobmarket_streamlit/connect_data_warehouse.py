import os

import duckdb
from dotenv import load_dotenv
from pandas import DataFrame

import streamlit as st

# Load environment variables from .env file
load_dotenv()

# Path to DuckDB database file
DUCKDB_PATH = os.getenv("DUCKDB_PATH")

# Default schema to query (marts contains transformed/aggregated data)
STREAMLIT_DEFAULT_SCHEMA = "marts"


@st.cache_resource
def get_cached_ddb_conn(read_only: bool = True):
    """
    Returns a cached Streamlit-resource DuckDBPyConnection.

    Cached as a resource (not data) because connections are stateful objects.
    Read-only mode prevents accidental writes from the dashboard.
    """
    return duckdb.connect(str(DUCKDB_PATH), read_only=read_only)


def get_ddb_df(conn: duckdb.DuckDBPyConnection, table: str, schema: str, uppercase_columns: bool = False) -> DataFrame:
    """
    Fetches a table and returns the data as a pandas DataFrame.

    Args:
        conn: Active DuckDB connection
        table: Table name to query
        schema: Schema name containing the table
        uppercase_columns: Whether to convert column names to uppercase
    """
    print(f"Fetching data from '{schema}.{table}'...")

    # Execute SQL query and convert to pandas DataFrame
    df = conn.sql(f"SELECT * FROM {schema}.{table}").to_df()

    # Optionally uppercase column names for consistency
    if uppercase_columns:
        df.columns = [str(col).upper() for col in df.columns]

    print(f"Successfully fetched {len(df)} rows into a Pandas DataFrame.")
    return df


@st.cache_data
def get_cached_ddb_df(table: str, schema: str | None = None, uppercase_columns: bool = False) -> DataFrame:
    """
    Fetches a table and returns the data as a cached Streamlit-dataset pandas DataFrame.

    Cached as data (not resource) because DataFrames are immutable/serializable.
    Uses default schema if none provided.

    Args:
        table: Table name to query
        schema: Schema name (defaults to STREAMLIT_DEFAULT_SCHEMA)
        uppercase_columns: Whether to convert column names to uppercase
    """
    # Use default schema if not specified
    if schema is None:
        schema = STREAMLIT_DEFAULT_SCHEMA

    return get_ddb_df(get_cached_ddb_conn(), table, schema, uppercase_columns)

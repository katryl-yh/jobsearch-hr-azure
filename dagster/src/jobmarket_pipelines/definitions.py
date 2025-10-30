# ==================== #
#       Imports        #
# ==================== #

import os
from pathlib import Path

import dlt
from dagster_dbt import DbtCliResource, DbtProject, dbt_assets
from dagster_dlt import DagsterDltResource, dlt_assets
from dagster_duckdb import DuckDBResource
from dotenv import load_dotenv

import dagster as dg

from .defs.dlt_sources.jobsearch_source import jobsearch_source

# Load environment variables from .env file
load_dotenv()

# Path to DuckDB database file
DUCKDB_PATH = os.getenv("DUCKDB_PATH")

# Path to DBT profiles directory (contains connection configs)
DBT_PROFILES_DIR = os.getenv("DBT_PROFILES_DIR")


# ==================== #
#       DLT Asset      #
# ==================== #

# DLT resource for executing data pipeline loads
dlt_resource = DagsterDltResource()


@dlt_assets(
    # Source: Jobsearch API configuration
    dlt_source=jobsearch_source(),
    # Pipeline: Extract from API and load into DuckDB staging schema
    dlt_pipeline=dlt.pipeline(
        pipeline_name="jobsearch",
        # Target schema for raw/staging data
        dataset_name="staging",
        # Destination: DuckDB warehouse
        destination=dlt.destinations.duckdb(str(DUCKDB_PATH)),
    ),
)
def dlt_load(context: dg.AssetExecutionContext, dlt: DagsterDltResource):
    """
    Asset: Extract job ads from Jobsearch API and load into DuckDB.

    Creates asset: dlt_jobsearch_source_search
    Data flows to: staging.job_ads_raw table
    """
    yield from dlt.run(context=context)


# ==================== #
#       DBT Asset      #
# ==================== #

# Path to DBT project directory (3 levels up from this file)
dbt_project_directory = Path(__file__).parents[3] / "dbt/jobmarket_dbt"

# DBT project instance with project and profiles paths
dbt_project = DbtProject(project_dir=dbt_project_directory, profiles_dir=DBT_PROFILES_DIR)

# DBT CLI resource for executing DBT commands
dbt_resource = DbtCliResource(project_dir=dbt_project)

# Generate manifest.json in development mode
# Manifest defines model dependencies for Dagster's lineage graph
dbt_project.prepare_if_dev()


@dbt_assets(
    # Path to manifest.json (defines all DBT models and dependencies)
    manifest=dbt_project.manifest_path,
)
def dbt_models(context: dg.AssetExecutionContext, dbt: DbtCliResource):
    """
    Asset: Transform raw data using DBT models.

    Creates assets: All models in warehouse and marts schemas
    Data flows from: staging schema (loaded by DLT)
    """
    # Execute 'dbt build' command and stream progress to Dagster UI
    yield from dbt.cli(["build"], context=context).stream()


# ==================== #
#         Jobs         #
# ==================== #

# Job: Extract and load job ads from API
jobstream_stream_job = dg.define_asset_job(
    name="jobstream_stream_job",
    # Only run the DLT asset
    selection=[
        dg.AssetKey("dlt_jobsearch_source_search"),
    ],
)

# Job: Transform data using DBT models
job_dbt = dg.define_asset_job(
    name="job_dbt",
    # Run all DBT models in warehouse and marts schemas
    selection=dg.AssetSelection.key_prefixes("warehouse", "marts"),
)


# ==================== #
#       Schedule       #
# ==================== #

# Schedule: Run data extraction 3 times daily on weekdays
jobstream_stream_schedule = dg.ScheduleDefinition(
    name="jobstream_stream_schedule",
    job=jobstream_stream_job,
    cron_schedule="0 8 * * *",
)


# ==================== #
#        Sensor        #
# ==================== #


# Sensor: Automatically trigger DBT job when new data is loaded
@dg.asset_sensor(
    # Watch for materialization of DLT asset
    asset_key=dg.AssetKey("dlt_jobsearch_source_search"),
    # Trigger the DBT transformation job
    job_name="job_dbt",
)
def dlt_load_sensor():
    """
    Sensor: Triggers DBT transformations after DLT load completes.

    Data flow: DLT loads raw data -> Sensor detects -> DBT transforms
    """
    yield dg.RunRequest()


# ==================== #
#     Definitions      #
# ==================== #

# Main Dagster definitions object
# Wires together all resources, assets, jobs, sensors, and schedules
defs = dg.Definitions(
    # Shared resources available to all assets
    resources={
        # DLT for data ingestion
        "dlt": DagsterDltResource(),
        # DBT for data transformation
        "dbt": dbt_resource,
        # DuckDB connection
        "duckdb": DuckDBResource(database=DUCKDB_PATH),
    },
    # Data assets to materialize
    assets=[
        dlt_load,  # Raw data extraction
        dbt_models,  # Data transformation
    ],
    # Jobs that can be executed
    jobs=[
        jobstream_stream_job,  # Extract job
        job_dbt,  # Transform job
    ],
    # Event-driven automation
    sensors=[
        dlt_load_sensor  # Auto-trigger DBT after DLT
    ],
    # Time-based automation
    schedules=[
        jobstream_stream_schedule,  # 3x daily extraction
    ],
)

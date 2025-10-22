# ==================== #
#       imports        #
# ==================== #
import dagster as dg
from dagster_dlt import DagsterDltResource, dlt_assets
from dagster_duckdb import DuckDBResource
from .defs.dlt_sources.jobsearch_source import jobsearch_source
import dlt

# data warehouse directory
from pathlib import Path
db_path = str(Path(__file__).parents[3] / "data/job_ads.duckdb")
print(db_path)

# ==================== #
#       dlt Asset      #
# ==================== #

dlt_resource = DagsterDltResource() 

@dlt_assets(
    dlt_source = jobsearch_source(),
    dlt_pipeline = dlt.pipeline(
        pipeline_name="jobsearch",
        dataset_name="staging",
        destination=dlt.destinations.duckdb(db_path),
    ),
)

def dlt_load(context: dg.AssetExecutionContext, dlt: DagsterDltResource): 
    yield from dlt.run(context=context)

# ==================== #
#         Job          #
# ==================== #

jobstream_stream_job = dg.define_asset_job(
    name="jobstream_stream_job",
    selection=[
        dg.AssetKey("dlt_jobsearch_source_search"),
    ],
)

# ==================== #
#       Schedule       #
# ==================== #

jobstream_stream_schedule = dg.ScheduleDefinition(
    name="jobstream_stream_schedule",
    job=jobstream_stream_job,
    cron_schedule="0 7,12,17 * * 1-5",
)

# ==================== #
#     Definitions      #
# ==================== #

defs = dg.Definitions(
    resources={
        "dlt": DagsterDltResource(),
        "duckdb": DuckDBResource(database=db_path),
    },
    assets=[dlt_load],
    jobs=[
        jobstream_stream_job,
    ],
    sensors=[],
    schedules=[
        jobstream_stream_schedule,
    ],
)
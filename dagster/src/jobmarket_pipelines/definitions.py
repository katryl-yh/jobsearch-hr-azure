# ==================== #
#       imports        #
# ==================== #
import dagster as dg
from dagster_dlt import DagsterDltResource, dlt_assets
from dagster_dbt import DbtCliResource, DbtProject, dbt_assets
from dagster_duckdb import DuckDBResource
from .defs.dlt_sources.jobsearch_source import jobsearch_source
import dlt

# data warehouse directory
from pathlib import Path
db_path = str(Path(__file__).parents[3] / "data/job_ads.duckdb")

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
#       dbt Asset      #
# ==================== #

# Points to the dbt project path
dbt_project_directory = Path(__file__).parents[3] / "dbt/jobmarket_dbt"
# Define the path to your profiles.yml file (in your home directory)
profiles_dir = Path.home() / ".dbt"  

# instance of DbtProject with all necessary paths
dbt_project = DbtProject(project_dir=dbt_project_directory,
                         profiles_dir=profiles_dir)

# an instance from the dbt resource class to run dbt codes
dbt_resource = DbtCliResource(project_dir=dbt_project)

# produce the manifest file
# the manifest file let dagster understand the dependency between models
dbt_project.prepare_if_dev()

# create dbt asset
@dbt_assets(manifest=dbt_project.manifest_path,) # path to the dbt manifest.json
# note the dependency injection similar to that in dlt asset
def dbt_models(context: dg.AssetExecutionContext, dbt: DbtCliResource):
    yield from dbt.cli(["build"], context=context).stream() # stream() is for showing the progress realtime in dagster UI


# ==================== #
#         Job          #
# ==================== #

jobstream_stream_job = dg.define_asset_job(
    name="jobstream_stream_job",
    selection=[
        dg.AssetKey("dlt_jobsearch_source_search"),
    ],
)

job_dbt = dg.define_asset_job(
    name="job_dbt", 
    selection=dg.AssetSelection.key_prefixes("warehouse", "marts"),
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
#        Sensor        #
# ==================== #

#sensor for the second job
@dg.asset_sensor(asset_key=dg.AssetKey("dlt_jobsearch_source_search"),
                 job_name="job_dbt")
def dlt_load_sensor():
    yield dg.RunRequest()

# ==================== #
#     Definitions      #
# ==================== #

defs = dg.Definitions(
    resources={
        "dlt": DagsterDltResource(),
        "dbt": dbt_resource,
        "duckdb": DuckDBResource(database=db_path),
    },
    assets=[
        dlt_load, 
        dbt_models
        ],
    jobs=[
        jobstream_stream_job,
        job_dbt
    ],
    sensors=[
        dlt_load_sensor
        ],
    schedules=[
        jobstream_stream_schedule,
    ],
)
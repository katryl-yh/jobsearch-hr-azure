"""
Run with:
uv run -m jobmarket_pipelines.defs.dlt_sources.jobsearch.jobsearch_rest_source
"""

from dataclasses import field

import dlt
import duckdb
from dlt.sources.config import configspec
from dlt.sources.helpers.rest_client.paginators import OffsetPaginator
from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources


@configspec
class JobsearchConfig:
    table_name: str = "job_ads_data"
    schema_name: str = "job_ads_schema"

    base_url: str = "https://jobsearch.api.jobtechdev.se"
    limit: int = 100
    offset: int = 0
    max_offset: int = 2000  # jobsearch limitation

    query: str = ""
    occupation_fields: list[str] = field(default_factory=lambda: [""])  # "concept_id"


@dlt.source()
def jobsearch_source(config: JobsearchConfig = dlt.config.value):
    config: RESTAPIConfig = {
        "client": {
            "base_url": config.base_url,
            "paginator": OffsetPaginator(
                limit=config.limit,
                offset=config.offset,
                total_path="$.total.value",
                maximum_offset=config.max_offset,
            ),
        },
        "resources": [
            {
                "name": "search",
                "endpoint": {
                    "path": "search",
                    "params": {
                        "limit": config.limit,
                        "sort": "pubdate-desc",
                        "published-after": "{incremental.start_value}",
                        "q": config.query,
                        "occupation-field": config.occupation_fields,
                    },
                    "data_selector": "$.hits",
                    "incremental": {
                        "cursor_path": "publication_date",
                        "row_order": "desc",
                        "initial_value": "1970-01-01T00:00:00",
                    },
                },
                "processing_steps": [
                    {"filter": lambda x: not x["removed"]},
                ],
                "table_name": config.table_name,
                "write_disposition": "append",
            }
        ],
    }

    yield from rest_api_resources(RESTAPIConfig(**config))


def main():
    config = JobsearchConfig()
    conn = duckdb.connect("janus.duckdb")
    p = dlt.pipeline(
        destination=dlt.destinations.duckdb(conn),
        dataset_name=config.schema_name,
        # dev_mode=True,
    )

    dlt_loadinfo = p.run(jobsearch_source())

    print(dlt_loadinfo)

    print(p.state)

    print(conn.sql("select occupation_field__concept_id, removed, publication_date, timestamp from job_ads;"))


if __name__ == "__main__":
    main()

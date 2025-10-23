from dataclasses import field

import dlt
from dlt.sources.config import configspec
from dlt.sources.helpers.rest_client.paginators import OffsetPaginator
from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources


@configspec
class JobsearchConfig:
    """
    Configuration class for Jobsearch API source.

    Decorated with @configspec to enable DLT configuration management
    (values can be overridden via config files or environment variables).
    """

    # Target table name in the data warehouse
    table_name: str = "job_ads_raw"

    # API base URL
    base_url: str = "https://jobsearch.api.jobtechdev.se"

    # Number of results per API request
    limit: int = 100

    # Starting offset for pagination
    offset: int = 0

    # Maximum offset allowed by the API (API limitation)
    max_offset: int = 2000

    # Search query string (empty = all jobs)
    query: str = ""

    # Filter by occupation field concept IDs
    occupation_fields: list[str] = field(default_factory=lambda: [""])


@dlt.source()
def jobsearch_source(config: JobsearchConfig = dlt.config.value):
    """
    DLT source for fetching job ads from Jobsearch API.

    Uses incremental loading based on publication_date to avoid re-fetching old data.
    Filters out removed job ads during processing.
    """

    # REST API configuration for DLT
    config: RESTAPIConfig = {
        # HTTP client configuration
        "client": {
            "base_url": config.base_url,
            # Pagination strategy: offset-based with dynamic total from API response
            "paginator": OffsetPaginator(
                limit=config.limit,
                offset=config.offset,
                # JSONPath to total results count in API response
                total_path="$.total.value",
                maximum_offset=config.max_offset,
            ),
        },
        # API resources to extract
        "resources": [
            {
                # Resource name (used internally by DLT)
                "name": "search",
                # API endpoint configuration
                "endpoint": {
                    # Endpoint path
                    "path": "search",
                    # Query parameters sent with each request
                    "params": {
                        "limit": config.limit,
                        # Sort by publication date (newest first)
                        "sort": "pubdate-desc",
                        # Incremental loading: only fetch jobs published after cursor value
                        "published-after": "{incremental.start_value}",
                        # Search query
                        "q": config.query,
                        # Filter by occupation fields
                        "occupation-field": config.occupation_fields,
                    },
                    # JSONPath to extract job ads array from API response
                    "data_selector": "$.hits",
                    # Incremental loading configuration
                    "incremental": {
                        # Field to use as cursor for incremental loading
                        "cursor_path": "publication_date",
                        # Newest-first ordering matches our sort
                        "row_order": "desc",
                        # Start from Unix epoch on first run
                        "initial_value": "1970-01-01T00:00:00",
                    },
                },
                # Data transformation steps
                "processing_steps": [
                    # Filter out removed job ads
                    {"filter": lambda x: not x["removed"]},
                ],
                # Target table name in warehouse
                "table_name": config.table_name,
                # Append new records (don't replace existing data)
                "write_disposition": "append",
            }
        ],
    }

    # Generate and yield DLT resources from configuration
    yield from rest_api_resources(RESTAPIConfig(**config))

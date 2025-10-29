dbt_duckdb:
  outputs:
    dev:
      type: duckdb
      path: ${duckdb_path}
  target: dev
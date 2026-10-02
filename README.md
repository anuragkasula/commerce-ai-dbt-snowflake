# Commerce Intelligence Mini

A small learning project: structured commerce data (orders) and unstructured support
case notes land in S3, load into Snowflake, are modeled with dbt, and enriched with
Snowflake Cortex AI functions. Built to get hands-on with dbt materializations,
incremental strategies, macros, and Cortex.

```
generate_data.py -> S3 (commerce-ai-raw) -> Snowflake RAW (COPY INTO via storage integration)
                 -> dbt: staging (views) -> intermediate (ephemeral / Cortex) -> marts (incremental, tables)
                 -> Semantic View + Cortex Analyst, Cortex Search
```

## Run order
1. `snowflake/01_setup.sql` - warehouse, database, TRANSFORMER role, resource monitor
2. `snowflake/02_cortex_function_check.sql` - which Cortex functions this account allows
3. `aws/` + `snowflake/03_s3_integration.sql` - storage integration (no AWS keys stored)
4. `python scripts/generate_data.py` then `aws s3 cp data/batch_1/ s3://commerce-ai-raw/ --recursive`
5. `snowflake/04_raw_tables_and_load.sql` - raw tables + COPY INTO
6. dbt project (next step)

Batch 2 (`data/batch_2/`) holds new orders, status updates, late-arriving orders and
customer segment changes, to exercise incremental models and snapshots.

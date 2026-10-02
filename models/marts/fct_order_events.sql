{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'append'
  )
}}
-- INCREMENTAL: APPEND. Just INSERTs new rows: no unique_key, no MERGE, fastest option.
-- Right for immutable event logs. The RISK: reprocess the same rows and you get duplicates.
-- Try it deliberately:  dbt run -s fct_order_events --vars '{reprocess_all: true}'
-- then watch the unique test on event_id fail. Fix with: dbt run -s fct_order_events --full-refresh

select
    event_id,
    order_id,
    event_type,
    event_ts,
    _loaded_at,
    current_timestamp() as _dbt_inserted_at
from {{ ref('stg_commerce__order_events') }}
{% if is_incremental() and not var('reprocess_all', false) %}
where _loaded_at > (select max(_loaded_at) from {{ this }})
{% endif %}

{{
  config(
    materialized = 'incremental',
    unique_key = 'order_id',
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns'
  )
}}
-- INCREMENTAL: MERGE on unique_key.
-- First run (table doesn't exist): is_incremental() is false, so the whole query runs
-- and creates the table. Later runs: only rows loaded since the last run are processed,
-- then MERGEd: existing order_id -> UPDATE, new order_id -> INSERT. No duplicates.
--
-- WATERMARK CHOICE: we filter on _loaded_at (when the row ARRIVED), not updated_at
-- (business time). Batch 2 contains 25 late-arriving orders whose updated_at is OLDER
-- than batch 1's newest updated_at. An updated_at watermark would silently skip them.

with orders as (
    select * from {{ ref('stg_commerce__orders') }}
    {% if is_incremental() %}
    where _loaded_at > (select max(_loaded_at) from {{ this }})
    {% endif %}
),

-- Aggregate lines to ORDER grain BEFORE joining, so the join can't fan out.
lines as (
    select
        order_id,
        count(*)                                  as line_count,
        sum(quantity)                             as total_quantity,
        sum(line_amount_usd)                      as order_amount_usd,
        listagg(distinct product_family, ', ')
            within group (order by product_family) as product_families
    from {{ ref('int_order_lines_enriched') }}
    where order_id in (select order_id from orders)
    group by order_id
),

customers as (
    -- current customer attributes (Type 1). For as-of-order-date segment, join the snapshot.
    select customer_id, region, segment from {{ ref('stg_commerce__customers') }}
)

select
    o.order_id,
    o.customer_id,
    c.region,
    c.segment                                     as customer_segment,
    o.order_date,
    o.status,
    o.status = 'CANCELLED'                        as is_cancelled,
    o.currency,
    coalesce(l.line_count, 0)                     as line_count,
    coalesce(l.total_quantity, 0)                 as total_quantity,
    coalesce(l.order_amount_usd, 0)               as order_amount_usd,
    l.product_families,
    o.updated_at,
    o._loaded_at,
    current_timestamp()                           as _dbt_updated_at
from orders o
left join lines l     on o.order_id = l.order_id
left join customers c on o.customer_id = c.customer_id

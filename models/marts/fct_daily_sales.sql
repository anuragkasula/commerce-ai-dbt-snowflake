{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'delete+insert',
    unique_key = 'order_date'
  )
}}
-- INCREMENTAL: DELETE+INSERT. For aggregates, you can't MERGE "a few new orders" into a
-- daily total. Instead: find the DATES touched by newly loaded orders, DELETE those dates
-- from the target, and INSERT freshly recomputed totals for them. Untouched dates stay.
-- Late-arriving orders dated 5-14 Sep make dbt recompute those OLD days only.
-- Known edge case: if every order on a date becomes cancelled, no new row is produced
-- for that date, so its old row is not deleted. A full refresh fixes it.

with orders as (
    select * from {{ ref('fct_orders') }}
),

{% if is_incremental() %}
affected_dates as (
    select distinct order_date
    from orders
    where _loaded_at > (select max(_last_loaded_at) from {{ this }})
),
{% endif %}

final as (
    select
        order_date,
        region,
        count(*)                          as order_count,
        sum(order_amount_usd)             as revenue_usd,
        max(_loaded_at)                   as _last_loaded_at
    from orders
    where not is_cancelled
    {% if is_incremental() %}
      and order_date in (select order_date from affected_dates)
    {% endif %}
    group by order_date, region
)

select * from final

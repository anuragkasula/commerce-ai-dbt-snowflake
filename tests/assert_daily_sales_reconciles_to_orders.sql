-- SINGULAR TEST: a one-off SQL check. Returns rows only when the two totals disagree.
-- Proves the incremental aggregate stayed in sync with the order-level fact.
with daily as (
    select sum(revenue_usd) as revenue from {{ ref('fct_daily_sales') }}
),
orders as (
    select sum(order_amount_usd) as revenue from {{ ref('fct_orders') }} where not is_cancelled
)
select daily.revenue as daily_revenue, orders.revenue as order_revenue
from daily cross join orders
where abs(daily.revenue - orders.revenue) > 0.01

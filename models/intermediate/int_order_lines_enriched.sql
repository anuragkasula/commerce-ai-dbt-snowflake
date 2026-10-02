-- EPHEMERAL (set for the whole intermediate/ folder in dbt_project.yml).
-- CONCEPT: an ephemeral model is never built in Snowflake. dbt pastes this SQL as a
-- CTE into every model that ref()s it. Good for light, reusable logic; bad for heavy
-- logic used in many places (it re-runs each time) and you can't query or test it directly.
-- After `dbt run`, open target/compiled/.../fct_orders.sql and find it inlined as
-- "__dbt__cte__int_order_lines_enriched".
select
    l.order_line_id,
    l.order_id,
    l.product_id,
    p.product_name,
    p.product_family,
    l.quantity,
    l.unit_price_usd,
    l.line_amount_usd
from {{ ref('stg_commerce__order_lines') }} l
left join {{ ref('stg_commerce__products') }} p
    on l.product_id = p.product_id

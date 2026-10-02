with source as (
    select * from {{ source('commerce', 'order_lines') }}
)

select
    order_line_id,
    order_id,
    product_id,
    quantity::int                                         as quantity,
    {{ cents_to_dollars('unit_price_cents') }}            as unit_price_usd,
    quantity::int * {{ cents_to_dollars('unit_price_cents') }} as line_amount_usd,
    _loaded_at
from source

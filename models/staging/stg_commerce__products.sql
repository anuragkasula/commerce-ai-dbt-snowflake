with source as (
    select * from {{ source('commerce', 'products') }}
)

select
    product_id,
    product_name,
    product_family,
    {{ cents_to_dollars('list_price_cents') }} as list_price_usd,   -- macro: see macros/cents_to_dollars.sql
    _loaded_at
from source

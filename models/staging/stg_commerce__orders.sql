-- Batch 2 re-sends some orders with a newer status. Raw keeps both versions;
-- staging exposes only the latest one per order_id.
with source as (
    select * from {{ source('commerce', 'orders') }}
)

select
    order_id,
    customer_id,
    to_date(order_date)                    as order_date,
    upper(status)                          as status,
    currency,
    to_timestamp_ntz(updated_at)           as updated_at,
    _loaded_at
from source
qualify row_number() over (partition by order_id order by to_timestamp_ntz(updated_at) desc) = 1

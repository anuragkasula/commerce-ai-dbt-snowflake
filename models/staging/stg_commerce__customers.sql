-- Staging: 1:1 with the source. Rename, cast, clean. No business logic, no joins.
-- Raw holds every version of a customer (batch 2 re-sends changed customers),
-- so keep only the latest version per customer_id.
with source as (
    select * from {{ source('commerce', 'customers') }}
)

select
    customer_id,
    trim(customer_name)                    as customer_name,
    upper(region)                          as region,
    country,
    segment,
    to_timestamp_ntz(updated_at)           as updated_at,
    _loaded_at
from source
qualify row_number() over (partition by customer_id order by to_timestamp_ntz(updated_at) desc) = 1

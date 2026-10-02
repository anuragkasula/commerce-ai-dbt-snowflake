with source as (
    select * from {{ source('commerce', 'order_events') }}
)

select
    event_id,
    order_id,
    upper(event_type)                      as event_type,
    to_timestamp_ntz(event_ts)             as event_ts,
    _loaded_at
from source

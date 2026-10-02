-- TABLE, current state (Type 1). History lives in the snap_customers snapshot.
select customer_id, customer_name, region, country, segment, updated_at
from {{ ref('stg_commerce__customers') }}

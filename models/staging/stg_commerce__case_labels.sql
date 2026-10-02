with source as (
    select * from {{ source('commerce', 'case_labels') }}
)

select
    case_id,
    true_issue_type,
    nullif(true_order_id, '')              as true_order_id
from source

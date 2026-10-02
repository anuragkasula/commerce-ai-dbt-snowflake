-- Semi-structured JSON -> columns. CONCEPT: schema-on-read.
--   payload:key           top-level field
--   payload:case.notes    nested field
--   ::string              cast; without it you get a VARIANT (quoted JSON value)
-- tags is an ARRAY; it stays an array here and is FLATTENed where it's needed.
with source as (
    select * from {{ source('commerce', 'support_cases') }}
)

select
    payload:case_id::string                as case_id,
    payload:customer_id::string            as customer_id,
    to_timestamp_ntz(payload:created_at::string) as created_at,
    payload:channel::string                as channel,
    payload:language::string               as language,
    payload:case.subject::string           as subject,
    payload:case.notes::string             as notes,
    payload:case.priority::string          as priority,
    payload:tags                           as tags,
    array_size(payload:tags)               as tag_count,
    _source_file,
    _loaded_at
from source

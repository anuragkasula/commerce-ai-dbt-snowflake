-- =====================================================================
-- 04_raw_tables_and_load.sql  |  Raw landing tables + COPY INTO
--
-- CONCEPTS
-- * Land raw data LOOSELY: everything as strings (or VARIANT for JSON). Typing happens
--   in dbt staging, so a bad value never breaks the load.
-- * Capture lineage on every row: which file it came from and when it loaded.
-- * COPY INTO keeps LOAD HISTORY (64 days, per table). Re-running the same COPY skips
--   files already loaded. So for batch 2 you just upload the new files and re-run
--   section 2 unchanged: only the new files load. That's idempotent loading.
-- =====================================================================
use role transformer;
use warehouse commerce_wh;
use schema commerce_ai.raw;

-- ---------- 1. Raw tables (run once) ----------
create table if not exists customers (
  customer_id string, customer_name string, region string, country string,
  segment string, updated_at string,
  _source_file string, _loaded_at timestamp_ntz);

create table if not exists products (
  product_id string, product_name string, product_family string, list_price_cents string,
  _source_file string, _loaded_at timestamp_ntz);

create table if not exists orders (
  order_id string, customer_id string, order_date string, status string,
  currency string, updated_at string,
  _source_file string, _loaded_at timestamp_ntz);

create table if not exists order_lines (
  order_line_id string, order_id string, product_id string, quantity string,
  unit_price_cents string,
  _source_file string, _loaded_at timestamp_ntz);

create table if not exists order_events (
  event_id string, order_id string, event_type string, event_ts string,
  _source_file string, _loaded_at timestamp_ntz);

create table if not exists case_labels (
  case_id string, true_issue_type string, true_order_id string,
  _source_file string, _loaded_at timestamp_ntz);

create table if not exists support_cases (
  payload variant,                         -- the whole JSON object, schema-on-read
  _source_file string, _loaded_at timestamp_ntz);

-- ---------- 2. Load (re-run unchanged after each new batch is uploaded) ----------
copy into customers from (
  select $1, $2, $3, $4, $5, $6, metadata$filename, current_timestamp()
  from @s3_stage/customers/) file_format = ff_csv on_error = 'ABORT_STATEMENT';

copy into products from (
  select $1, $2, $3, $4, metadata$filename, current_timestamp()
  from @s3_stage/products/) file_format = ff_csv on_error = 'ABORT_STATEMENT';

copy into orders from (
  select $1, $2, $3, $4, $5, $6, metadata$filename, current_timestamp()
  from @s3_stage/orders/) file_format = ff_csv on_error = 'ABORT_STATEMENT';

copy into order_lines from (
  select $1, $2, $3, $4, $5, metadata$filename, current_timestamp()
  from @s3_stage/order_lines/) file_format = ff_csv on_error = 'ABORT_STATEMENT';

copy into order_events from (
  select $1, $2, $3, $4, metadata$filename, current_timestamp()
  from @s3_stage/order_events/) file_format = ff_csv on_error = 'ABORT_STATEMENT';

copy into case_labels from (
  select $1, $2, $3, metadata$filename, current_timestamp()
  from @s3_stage/case_labels/) file_format = ff_csv on_error = 'ABORT_STATEMENT';

copy into support_cases from (
  select $1, metadata$filename, current_timestamp()
  from @s3_stage/support_cases/) file_format = ff_json on_error = 'SKIP_FILE';

-- ---------- 3. Observe ----------
-- Row counts per table and per source file
select 'orders' t, _source_file, count(*) from orders group by 1, 2
union all select 'support_cases', _source_file, count(*) from support_cases group by 1, 2
order by 1, 2;

-- Load history: what COPY remembers (this is why re-running doesn't duplicate)
select file_name, status, row_count, first_error_message, last_load_time
from table(information_schema.copy_history(
  table_name => 'ORDERS', start_time => dateadd(day, -1, current_timestamp())));

-- VARIANT path notation on the JSON (preview of dbt staging)
select payload:case_id::string        as case_id,
       payload:case.notes::string     as notes,
       payload:case.priority::string  as priority,
       payload:tags                   as tags_array
from support_cases limit 5;

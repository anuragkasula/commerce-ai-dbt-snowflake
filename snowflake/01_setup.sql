-- =====================================================================
-- 01_setup.sql  |  Warehouse, database, functional role, cost guardrail
-- Run once in a Snowsight worksheet, section by section.
-- CONCEPT: never build as ACCOUNTADMIN. SYSADMIN owns objects,
-- SECURITYADMIN manages roles/grants, work runs as a functional role.
-- =====================================================================

-- 0. Where am I?  (account identifier for dbt + region)
use role accountadmin;
select current_organization_name() || '-' || current_account_name() as account_identifier_for_dbt,
       current_region() as region;

-- 1. Compute + storage (SYSADMIN owns objects)
use role sysadmin;
create warehouse if not exists commerce_wh
  warehouse_size = 'XSMALL'
  auto_suspend = 60                 -- pay only while running
  auto_resume = true
  initially_suspended = true;

create database if not exists commerce_ai;
create schema if not exists commerce_ai.raw;   -- landing zone; dbt creates the rest

-- 2. Functional role (SECURITYADMIN manages roles and grants)
use role securityadmin;
create role if not exists transformer;
grant role transformer to role sysadmin;              -- roll up so admins can manage its objects
grant role transformer to user anuragkasula10;

grant usage on warehouse commerce_wh to role transformer;
grant usage, create schema on database commerce_ai to role transformer;
grant all on schema commerce_ai.raw to role transformer;
grant select on future tables in schema commerce_ai.raw to role transformer;
-- In a real team: a separate LOADER role writes RAW, TRANSFORMER only reads it.

grant database role snowflake.cortex_user to role transformer;   -- Cortex access

-- 3. Cost guardrail (ACCOUNTADMIN only)
use role accountadmin;
create resource monitor if not exists commerce_rm with
  credit_quota = 20
  frequency = monthly
  start_timestamp = immediately
  triggers on 75 percent do notify
           on 100 percent do suspend;
alter warehouse commerce_wh set resource_monitor = commerce_rm;

-- 4. Verify
use role transformer;
use warehouse commerce_wh;
show grants to role transformer;

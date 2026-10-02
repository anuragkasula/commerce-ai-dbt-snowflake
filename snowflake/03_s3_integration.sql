-- =====================================================================
-- 03_s3_integration.sql  |  Let Snowflake read s3://commerce-ai-raw WITHOUT storing AWS keys
--
-- CONCEPT: a STORAGE INTEGRATION is a Snowflake object that holds an IAM ROLE ARN.
-- Snowflake has its own AWS IAM user; your role trusts that user ONLY when it presents
-- your account's unique EXTERNAL ID. No access keys exist anywhere, so nothing can leak,
-- and access is revoked by editing one IAM role. This is the "confused deputy" protection.
--
-- ORDER OF OPERATIONS (it's a handshake):
--   AWS 1  create IAM policy  (aws/s3_read_policy.json)
--   AWS 2  create IAM role with a TEMPORARY trust policy, attach the policy, copy the role ARN
--   SF  3  create the integration with that ARN               (below)
--   SF  4  DESC INTEGRATION -> copy STORAGE_AWS_IAM_USER_ARN + STORAGE_AWS_EXTERNAL_ID
--   AWS 5  replace the role's trust policy using aws/trust_policy_template.json
--   SF  6  grant, create file formats + stage, LIST the stage to prove it works
-- =====================================================================

-- ---------- Step 3: the integration (needs ACCOUNTADMIN) ----------
use role accountadmin;

create storage integration if not exists s3_commerce_int
  type = external_stage
  storage_provider = 'S3'
  enabled = true
  storage_aws_role_arn = 'arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/snowflake-commerce-ai-role'
  storage_allowed_locations = ('s3://commerce-ai-raw/');   -- can never read outside this bucket

-- ---------- Step 4: get Snowflake's side of the handshake ----------
desc integration s3_commerce_int;
-- Copy two values into aws/trust_policy_template.json:
--   STORAGE_AWS_IAM_USER_ARN  -> Principal.AWS
--   STORAGE_AWS_EXTERNAL_ID   -> Condition sts:ExternalId
-- Then paste that JSON as the role's trust policy in AWS (Step 5).

-- ---------- Step 6: hand it to the working role ----------
grant usage on integration s3_commerce_int to role transformer;

use role transformer;
use warehouse commerce_wh;
use schema commerce_ai.raw;

create file format if not exists ff_csv
  type = csv
  skip_header = 1
  field_optionally_enclosed_by = '"'
  null_if = ('', 'NULL')
  empty_field_as_null = true;

create file format if not exists ff_json
  type = json
  strip_outer_array = false;      -- our files are newline-delimited JSON, one object per line

create stage if not exists s3_stage
  storage_integration = s3_commerce_int
  url = 's3://commerce-ai-raw/';

-- Proof it works (after you upload batch 1):
list @s3_stage;

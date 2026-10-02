-- =====================================================================
-- 05_dbt_keypair.sql  |  Key-pair authentication for dbt (and later GitHub Actions)
--
-- CONCEPT: instead of a password (which now triggers MFA prompts for human users),
-- dbt signs a token with a PRIVATE key that stays on your laptop. Snowflake holds
-- only the matching PUBLIC key. Nothing secret is ever stored in Snowflake or Git.
--
-- 1) On your laptop, OUTSIDE the repo folder (e.g. ~/.snowflake/):
--      mkdir -p ~/.snowflake && cd ~/.snowflake
--      openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_dbt_key.p8 -nocrypt
--      openssl rsa -in snowflake_dbt_key.p8 -pubout -out snowflake_dbt_key.pub
--    Windows: run the same commands in Git Bash (installed with Git).
--
-- 2) Open snowflake_dbt_key.pub, copy everything BETWEEN the BEGIN/END lines
--    (no header lines, no line breaks), and paste it below.
-- =====================================================================
use role securityadmin;

alter user anuragkasula10 set rsa_public_key = '<PASTE_PUBLIC_KEY_BODY_HERE>';

-- 3) Verify: RSA_PUBLIC_KEY_FP should now show a fingerprint
desc user anuragkasula10;

-- 4) In profiles.yml set private_key_path to the full path of snowflake_dbt_key.p8,
--    then from the repo folder run:  dbt debug
--    "All checks passed!" = dbt can log in as TRANSFORMER.

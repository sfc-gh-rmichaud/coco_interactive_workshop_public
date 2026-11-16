-- Read-only readiness checks. Run statements separately: some fail by design.
-- A chat response or a model listing does NOT prove execution privileges.
SELECT CURRENT_ACCOUNT_NAME() AS ACCOUNT, CURRENT_REGION() AS REGION,
       CURRENT_USER() AS USER_NAME, CURRENT_ROLE() AS ACTIVE_ROLE,
       CURRENT_WAREHOUSE() AS WAREHOUSE, CURRENT_SECONDARY_ROLES() AS SECONDARY_ROLES;
SHOW PARAMETERS LIKE 'CORTEX_ENABLED_CROSS_REGION' IN ACCOUNT;
SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS;
-- Confirm surface limits with your administrator; 0 blocks that surface.
SHOW PARAMETERS LIKE 'CORTEX_CODE%DAILY_EST_CREDIT_LIMIT_PER_USER' IN ACCOUNT;

-- B2: optional live warehouse usage (Lab 62), requires MONITOR USAGE.
SELECT COUNT(*) AS METERING_ROWS_LAST_DAY
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
  DATEADD('day', -1, CURRENT_DATE())));
-- B3: optional account usage (Labs 43/62), normally USAGE_VIEWER.
SELECT COUNT(*) AS METERING_ROWS_LAST_DAY
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE USAGE_DATE >= DATEADD('day', -1, CURRENT_DATE());
SELECT COUNT(*) AS COCO_ROWS_LAST_DAY
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY
WHERE USAGE_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP());
-- B4: access to DMF metadata is NOT proof of Enterprise edition or execution.
SELECT COUNT(*) AS DMF_REFERENCES
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_METRIC_FUNCTION_REFERENCES;
-- B5: run 01_role_smoke_test.sql separately with your attendee role selected.
-- That test creates/drops a unique database and warehouse and disables secondary
-- roles. It is intentionally not included in this read-only script.
-- Next: send all results/errors to your facilitator. Confirm CoCo responds on
-- the surface you will use. Grant optional bundles only for selected labs.
-- A permission error, unavailable feature, and empty result mean different things.

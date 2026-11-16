-- ============================================================
-- cleanup.sql -- Lab 42
--
-- Drops everything this lab can create, in dependency order, and it
-- is deliberately thorough because two of these objects bill while
-- they sit idle:
--
--   * a Snowflake Postgres instance has NO auto-suspend and bills
--     compute continuously from Ready until it is dropped
--   * an application service bills until suspended, and AUTO_SUSPEND_SECS
--     defaults to 0, which means auto-suspend is off
--
-- So run this even if the lab did not work. Especially if the lab did
-- not work. Every DROP is IF EXISTS, so it is safe to run at any point
-- of partial progress.
--
-- Statement order note, and it matters: the drops come FIRST and the
-- LAB_RUN_LOG insert comes last. `snow sql -f` aborts on the first
-- failing statement, and that insert is the one statement here that can
-- fail -- if the shared database is already gone, or if the session has
-- no warehouse. Logging before dropping would mean a missing warehouse
-- silently left a Postgres instance billing. Losing a log row is
-- cheaper than that.
--
-- The application service is created by `snow app deploy` rather than
-- by SQL, so the cleanest way to remove it is:
--
--     snow app teardown --force
--
-- from the app directory. The DROP below is the belt-and-braces version
-- for when the project directory is already gone. It assumes the app
-- went into the lab database; if this account left
-- DEFAULT_SNOWFLAKE_APPS_DESTINATION_DATABASE empty, the app is in your
-- personal database instead, which is why the last statement lists every
-- application service in the account for you to check.
--
-- The shared warehouse and shared metadata are left alone.
-- ============================================================

-- ------------------------------------------------------------
-- Per-user namespace
--
-- Lab 42 is the one lab that creates ACCOUNT-level objects beyond a
-- database -- a Postgres instance, a compute pool, an external access
-- integration and a network policy. All of them are suffixed with your
-- user name, so two people can run this lab in one account and neither
-- teardown touches the other's running app.
--
-- The application service is the exception, and needs no suffix: unless
-- an ACCOUNTADMIN has set DEFAULT_SNOWFLAKE_APPS_DESTINATION_DATABASE,
-- Snowflake creates it in your personal database USER$<login_name>,
-- which is already per-user. That is also why this file finishes with
-- SHOW APPLICATION SERVICES IN ACCOUNT -- no COCO_WS_* drop can reach it.
-- ------------------------------------------------------------
SET NS        = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET SHARED_DB = 'COCO_WS_SHARED_DB_' || $NS;
SET RUN_LOG   = $SHARED_DB || '.WORKSHOP.LAB_RUN_LOG';
SET LAB_DB    = 'COCO_WS_LAB42_DB_' || $NS;
SET PG        = 'COCO_WS_LAB42_PG_' || $NS;
SET PG_EAI    = 'COCO_WS_LAB42_PG_EAI_' || $NS;
SET PG_INGR   = 'COCO_WS_LAB42_PG_INGRESS_' || $NS;
SET POOL      = 'COCO_WS_LAB42_POOL_' || $NS;
-- Fully qualified on purpose. The app is created in your personal database,
-- not in the lab database, so a bare name fails outright with "Cannot perform
-- DROP. This session does not have a current database" -- and it fails BEFORE
-- anything else in this file has run. The `$` in USER$<login> needs no quoting:
-- it is legal in an unquoted identifier after the first character, and
-- IDENTIFIER() accepts the whole three-part name.
SET APP       = 'USER$' || CURRENT_USER() || '.PUBLIC.COCO_WS_LAB42_APP_' || $NS;

-- ------------------------------------------------------------
-- 1. The application service, before the database that holds it
-- ------------------------------------------------------------
-- The app lands in your personal database unless an ACCOUNTADMIN set a
-- default destination, so try the lab database first and then check the
-- SHOW at the end of this file.
DROP APPLICATION SERVICE IF EXISTS IDENTIFIER($APP);

-- ------------------------------------------------------------
-- 2. The Postgres instance -- the expensive one. Dropped, not
--    suspended: a suspended instance still bills for storage and
--    keeps ten days of backups.
-- ------------------------------------------------------------
DROP POSTGRES INSTANCE IF EXISTS IDENTIFIER($PG);

-- ------------------------------------------------------------
-- 3. Account-level networking and credentials. The integration goes
--    before the network rule it references, or the rule drop is
--    refused for still being in use.
-- ------------------------------------------------------------
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS IDENTIFIER($PG_EAI);
DROP NETWORK POLICY IF EXISTS IDENTIFIER($PG_INGR);
DROP COMPUTE POOL IF EXISTS IDENTIFIER($POOL);

-- ------------------------------------------------------------
-- 4. Objects inside the lab database. DROP DATABASE would take
--    these anyway; naming them makes the teardown auditable, and
--    means a partially-built lab still cleans up if the database
--    was created under a different name.
-- ------------------------------------------------------------

-- Takes the secret COCO_WS_LAB42_PG_CREDS_<you> and the network rule
-- COCO_WS_LAB42_PG_EGRESS_<you> with it -- both live in schema LAB.
DROP DATABASE IF EXISTS IDENTIFIER($LAB_DB);

-- ------------------------------------------------------------
-- 5. Confirm. The first three should return zero rows.
--
--    The fourth is the one to actually read. It lists application
--    services anywhere in the account, including your personal
--    database USER$<login_name>, which is where the app lands on an
--    account that never set DEFAULT_SNOWFLAKE_APPS_DESTINATION_DATABASE.
--    If COCO_WS_LAB42_APP_<you> appears here, it survived step 1 and is
--    still billing. Drop it by its fully qualified name.
-- ------------------------------------------------------------
SHOW DATABASES LIKE 'COCO_WS_LAB42_DB\_%';

SHOW POSTGRES INSTANCES LIKE 'COCO_WS_LAB42_PG\_%';

SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'COCO_WS_LAB42_PG_EAI\_%';

SHOW APPLICATION SERVICES IN ACCOUNT;

-- ------------------------------------------------------------
-- 6. Register the teardown. Last on purpose -- see the header.
--    QUERY_TAG is set so this row matches the SETUP row in the
--    Lab 62 capstone.
-- ------------------------------------------------------------
ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB42';

INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB42', 'Full-stack app on SPCS over Snowflake Postgres', 'CLEANUP',
       CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ============================================================
-- cleanup.sql -- Lab 22
--
-- Drops the whole lab database rather than naming individual objects.
-- That is deliberate: dbt creates the models, and their names depend on
-- what you and CoCo called them, so an explicit DROP list would miss
-- them. The dbt project object lives in the lab database too, so it
-- goes with it.
--
-- What this canNOT drop, because it is not in Snowflake: the dbt project
-- files on your machine. They are just files -- delete the directory if
-- you want the disk space back. Nothing bills for them.
--
-- The shared warehouse (COCO_WS_WH_<you>) and shared metadata
-- (COCO_WS_SHARED_DB_<you>) are left alone for the other labs and the
-- Lab 62 capstone.
--
-- Statement order note: the drops come FIRST and the LAB_RUN_LOG insert
-- comes last. `snow sql -f` aborts on the first failing statement, and that
-- insert is the one statement here that can fail -- it needs the shared
-- database to still exist and the session to have a warehouse. Logging first
-- would mean a session with no default warehouse silently skipped every drop.
-- Losing a log row is cheaper than leaving objects behind.
-- ============================================================

-- ------------------------------------------------------------
-- Per-user namespace
--
-- Every object this lab creates at ACCOUNT level -- the database and
-- the warehouse -- is suffixed with your user name, so a whole room
-- can run this lab in one Snowflake account without colliding.
-- Everything INSIDE the database (schemas LAB and LAB_DBT, and every
-- table, view and dbt project object) keeps its usual name, so the SQL
-- below reads identically for everyone.
--
-- Two things worth knowing:
--   * Session variables live only for this session, so every file in
--     the workshop sets its own. Run the file top to bottom.
--   * This drops YOUR objects only. It cannot remove anyone else's
--     work, and equally will not clean up after them.
-- ------------------------------------------------------------
SET NS            = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET SHARED_DB     = 'COCO_WS_SHARED_DB_' || $NS;
SET RUN_LOG       = $SHARED_DB || '.WORKSHOP.LAB_RUN_LOG';
SET LAB_DB        = 'COCO_WS_LAB22_DB_' || $NS;

-- Dropping the database removes the dbt project object, every model dbt
-- built, and any task scheduling it, all in one statement.
DROP DATABASE IF EXISTS IDENTIFIER($LAB_DB);

-- Should return zero rows.
--
-- Deliberately NOT using SHOW DBT PROJECTS ... IN ACCOUNT here: on a real
-- account that matches unrelated objects and buries the answer. The
-- database is gone, so anything that lived inside it is gone with it.
SHOW DATABASES LIKE 'COCO_WS_LAB22_DB\_%';

-- ------------------------------------------------------------
-- Register the teardown. Last on purpose -- see the header.
-- QUERY_TAG is set so this row matches the SETUP row in the
-- Lab 62 capstone.
-- ------------------------------------------------------------
ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB22';

INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB22', 'Build a pipeline with dbt', 'CLEANUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ============================================================
-- cleanup.sql -- Lab 33
--
-- Drops the whole lab database rather than naming individual objects.
-- That is deliberate: this lab creates agents, a semantic view, a search
-- service, a dataset and a stage, and you will have created at least one
-- more agent during the lab under a name of your own choosing. Dropping
-- the database takes all of it.
--
-- Evaluation RUNS and their traces live with the agent, so they go when
-- the agent's database goes. There is no separate teardown for them, and
-- nothing keeps billing once the agents are gone.
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
SET LAB_DB        = 'COCO_WS_LAB33_DB_' || $NS;

-- Takes the agents, the semantic view, the search service, the evaluation
-- dataset, the config stage and every evaluation run's traces with it.
DROP DATABASE IF EXISTS IDENTIFIER($LAB_DB);

-- Should return zero rows.
--
-- Deliberately NOT using SHOW AGENTS ... IN ACCOUNT here: on a real account
-- that matches unrelated agents and buries the answer. The database is gone,
-- so anything that lived inside it is gone with it.
SHOW DATABASES LIKE 'COCO_WS_LAB33_DB\_%';

-- ------------------------------------------------------------
-- Register the teardown. Last on purpose -- see the header.
-- QUERY_TAG is set so this row matches the SETUP row in the
-- Lab 62 capstone.
-- ------------------------------------------------------------
ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB33';

INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB33', 'Evaluate a Cortex Agent', 'CLEANUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

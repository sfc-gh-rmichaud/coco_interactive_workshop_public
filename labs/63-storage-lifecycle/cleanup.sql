-- ============================================================
-- cleanup.sql -- Lab 63
--
-- Drops the whole lab database, which takes the event table, the retention
-- rules and any storage lifecycle policies you created with it.
--
-- Why this matters more here than in most labs: a storage lifecycle policy
-- is a SCHEDULED operation that bills per execution. Left attached, it keeps
-- running daily whether or not anyone is looking, and keeps charging for it.
-- Dropping the database removes the policies along with the table they were
-- attached to, so nothing is left on a schedule.
--
-- If you attached a policy to a table OUTSIDE this lab's database while
-- experimenting, this file will not find it. Check with
-- SHOW STORAGE LIFECYCLE POLICIES IN ACCOUNT and detach it with
-- ALTER TABLE <t> DROP STORAGE LIFECYCLE POLICY.
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
SET LAB_DB        = 'COCO_WS_LAB63_DB_' || $NS;

-- Takes the event table, the retention rules and any attached lifecycle
-- policies -- and therefore their daily executions -- with it.
DROP DATABASE IF EXISTS IDENTIFIER($LAB_DB);

-- Should return zero rows.
--
-- The database is gone, so the table and its policies are gone with it.
SHOW DATABASES LIKE 'COCO_WS_LAB63_DB\_%';

-- ------------------------------------------------------------
-- Register the teardown. Last on purpose -- see the header.
-- QUERY_TAG is set so this row matches the SETUP row in the
-- Lab 62 capstone.
-- ------------------------------------------------------------
ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB63';

INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB63', 'Storage lifecycle policies', 'CLEANUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

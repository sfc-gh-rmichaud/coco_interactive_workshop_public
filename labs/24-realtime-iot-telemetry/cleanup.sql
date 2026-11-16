-- ============================================================
-- cleanup.sql -- Lab 24
--
-- Drops the whole lab database, which takes the landing table, the
-- streaming pipe, the three views and any interactive table you created
-- during the optional section with it.
--
-- Two things this file deliberately also does:
--
--   1. Drops the optional INTERACTIVE WAREHOUSE if you made one. That
--      matters more than it looks: an interactive warehouse has a
--      minimum AUTO_SUSPEND of 86400 seconds (24 hours) and bills a
--      minimum of one hour per resume, so one left running is the most
--      expensive thing this workshop can leave behind. It lives at
--      ACCOUNT level, so dropping the database does NOT remove it.
--
--   2. Says nothing about the local Node.js projects. The simulator and
--      the dashboard are files on your machine -- delete the folders if
--      you want the disk space. Nothing bills for them. Do remember
--      that queries/simulator/profile.json and
--      queries/dashboard/.env.local hold your account details; they are
--      gitignored, but they are still on your disk.
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
-- Losing a log row is cheaper than leaving a billing interactive warehouse up.
-- ============================================================

-- ------------------------------------------------------------
-- Per-user namespace
--
-- Every object this lab creates at ACCOUNT level -- the database and the
-- warehouses -- is suffixed with your user name, so a whole room can run
-- this lab in one Snowflake account without colliding.
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
SET LAB_DB        = 'COCO_WS_LAB24_DB_' || $NS;
SET IW            = 'COCO_WS_LAB24_IW_' || $NS;

-- Takes the landing table, the pipe, the views and any interactive table.
DROP DATABASE IF EXISTS IDENTIFIER($LAB_DB);

-- The optional interactive warehouse from the stretch section. Account-level,
-- so it survives the database drop, and it is the one object here that can
-- still cost money. IF EXISTS, because most people will not have made one.
DROP WAREHOUSE IF EXISTS IDENTIFIER($IW);

-- Both should return zero rows.
SHOW DATABASES LIKE 'COCO_WS_LAB24_DB\_%';
SHOW WAREHOUSES LIKE 'COCO_WS_LAB24_IW\_%';

-- ------------------------------------------------------------
-- Register the teardown. Last on purpose -- see the header.
-- QUERY_TAG is set so this row matches the SETUP row in the
-- Lab 62 capstone.
-- ------------------------------------------------------------
ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB24';

INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB24', 'Realtime IoT telemetry', 'CLEANUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

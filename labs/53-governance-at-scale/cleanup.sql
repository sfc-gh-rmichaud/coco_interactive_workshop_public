-- ============================================================
-- cleanup.sql -- Lab 53
--
-- Drops the whole lab database, which takes the four tables, every tag you
-- created, every masking policy, and all the tag-to-column attachments with
-- it. Tags and masking policies are schema-level objects, so they go with
-- the schema -- there is nothing left dangling at account level.
--
-- Two things this does NOT clean up, both deliberate:
--
--   1. Any ROLE you created to test masking (a PII_READER or similar).
--      Roles live at account level and survive the database. Drop it
--      yourself if you made one -- this file will not guess its name.
--
--   2. Any tag you attached to an object OUTSIDE this database while
--      experimenting. Find those with
--      SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES, which lists every
--      attachment account-wide, and unset them with
--      ALTER TABLE <t> MODIFY COLUMN <c> UNSET TAG <tag>.
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
SET LAB_DB        = 'COCO_WS_LAB53_DB_' || $NS;

-- Takes the tables, the tags, the masking policies and every tag-to-column
-- attachment with it.
DROP DATABASE IF EXISTS IDENTIFIER($LAB_DB);

-- Should return zero rows.
--
-- The database is gone, so the tags and policies are gone with it.
SHOW DATABASES LIKE 'COCO_WS_LAB53_DB\_%';

-- ------------------------------------------------------------
-- Register the teardown. Last on purpose -- see the header.
-- QUERY_TAG is set so this row matches the SETUP row in the
-- Lab 62 capstone.
-- ------------------------------------------------------------
ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB53';

INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB53', 'Governance at scale', 'CLEANUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

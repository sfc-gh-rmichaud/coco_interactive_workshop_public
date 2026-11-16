-- ============================================================
-- cleanup.sql -- Lab 51
--
-- Order matters here. A masking policy cannot be dropped while it is
-- still attached to a column, so the policy must be unset from every
-- column before the policy itself is dropped.
--
-- Dropping the database does all of this in one step, which is why it
-- is the primary action. The explicit UNSET statements are kept above
-- it as documentation of the manual order you would need on a real
-- table you were not dropping.
--
-- The shared warehouse and shared metadata are left alone.
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
-- Everything INSIDE the database (schema LAB, and every table and
-- view) keeps its usual name, so the SQL below reads identically for
-- everyone.
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
SET LAB_DB        = 'COCO_WS_LAB51_DB_' || $NS;

-- Dropping the database removes the table, the view, every masking
-- policy defined in it and every policy attachment, together.
DROP DATABASE IF EXISTS IDENTIFIER($LAB_DB);

-- Any role the lab created for testing masked versus unmasked reads.
-- Suffixed like the database, even though roles are otherwise shared across
-- the workshop: this one gets DROPPED, and dropping a shared role would pull
-- it out from under anyone else still working through this lab.
SET PII_ROLE = 'COCO_WS_PII_READER_' || $NS;
DROP ROLE IF EXISTS IDENTIFIER($PII_ROLE);

-- Your database should be gone. Other attendees' may still be listed --
-- SHOW ... LIKE takes a literal, so it cannot be scoped to just you.
SHOW DATABASES LIKE 'COCO_WS_LAB51_DB\_%';

-- ------------------------------------------------------------
-- Register the teardown. Last on purpose -- see the header.
-- QUERY_TAG is set so this row matches the SETUP row in the
-- Lab 62 capstone.
-- ------------------------------------------------------------
ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB51';

INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB51', 'Find PII and mask it', 'CLEANUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ============================================================
-- 00_workshop_setup.sql -- CoCo Interactive Workshop (shared objects)
--
-- Run this ONCE before any lab. It creates the small amount of
-- shared infrastructure every lab relies on:
--
--   COCO_WS_WH_<you>                          shared XSMALL warehouse
--   COCO_WS_SHARED_DB_<you>.WORKSHOP          shared schema
--   ...LAB_RUN_LOG                      timeline of which labs you ran, when
-- Run as the attendee's workshop role. Admin role setup is separate:
--   shared/00_admin_role_setup.sql (admin runs before attendee setup).
--
-- You do NOT strictly need to run this: every lab's setup.sql
-- creates these same shared objects with IF NOT EXISTS, so any lab
-- can be run standalone. Running it up front just makes the
-- Lab 62 cost capstone tidier.
--
-- Shared objects use CREATE ... IF NOT EXISTS rather than
-- CREATE OR REPLACE on purpose: LAB_RUN_LOG must ACCUMULATE across
-- labs, and replacing it would erase the session timeline the
-- capstone depends on. Per-lab objects use CREATE OR REPLACE.
--
-- Teardown: shared/99_workshop_cleanup.sql
-- ============================================================

-- ------------------------------------------------------------
-- Per-user namespace
--
-- Every account-level object the workshop creates is suffixed with
-- your user name, so a whole room can share one Snowflake account
-- without colliding. Names inside each database are unchanged.
--
-- The suffix strips anything that is not a letter or digit, because
-- an SSO login like first.last@example.com is not a legal identifier
-- and IDENTIFIER() misreads the dots as database.schema.object.
--
-- Session variables are per-session and are NOT visible to CoCo,
-- which runs its own. The final query prints your real names.
-- ------------------------------------------------------------
SET NS            = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET WH            = 'COCO_WS_WH_' || $NS;
SET SHARED_DB     = 'COCO_WS_SHARED_DB_' || $NS;
SET SHARED_SCHEMA = $SHARED_DB || '.WORKSHOP';
SET RUN_LOG       = $SHARED_DB || '.WORKSHOP.LAB_RUN_LOG';
SET TIMELINE      = $SHARED_DB || '.WORKSHOP.V_LAB_TIMELINE';

-- ------------------------------------------------------------
-- 1. Shared warehouse
--    All lab compute lands here on purpose, so Lab 62 can
--    attribute credits to the workshop rather than guessing.
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($WH)
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'CoCo Interactive Workshop -- shared compute for all labs';

USE WAREHOUSE IDENTIFIER($WH);

-- ------------------------------------------------------------
-- 2. Shared database and schema
-- ------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS IDENTIFIER($SHARED_DB)
  COMMENT = 'CoCo Interactive Workshop -- shared workshop metadata';

CREATE SCHEMA IF NOT EXISTS IDENTIFIER($SHARED_SCHEMA)
  COMMENT = 'Cross-lab workshop metadata (lab run log)';

-- ------------------------------------------------------------
-- 3. LAB_RUN_LOG -- the spine of Lab 62 cost attribution
--
--    Every lab appends a row here when its setup runs. Lab 62
--    uses these timestamps to bound the time windows it reports
--    credits for, because query tags alone cannot capture
--    everything (see note below).
--
--    IMPORTANT and deliberately taught in Lab 62: CoCo runs its
--    own SQL in its own sessions, so a QUERY_TAG you set in a
--    worksheet does NOT appear on CoCo-issued queries. Lab 62
--    therefore attributes on three signals -- query tag, lab
--    database name, and these time windows.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS IDENTIFIER($RUN_LOG) (
  LAB_ID          VARCHAR(16),      -- e.g. 'LAB11'
  LAB_NAME         VARCHAR(200),
  EVENT_TYPE       VARCHAR(20),     -- SETUP | CLEANUP
  EVENT_TS         TIMESTAMP_LTZ,
  USER_NAME        VARCHAR(200),
  ROLE_NAME        VARCHAR(200),
  WAREHOUSE_NAME   VARCHAR(200),
  SESSION_ID       VARCHAR(50),
  QUERY_TAG        VARCHAR(200)
)
COMMENT = 'Append-only timeline of workshop lab runs. Consumed by Lab 62.';

-- Convenience view: one row per lab with first setup and last event.
CREATE OR REPLACE VIEW IDENTIFIER($TIMELINE)
  COMMENT = 'Per-lab run window, used by the Lab 62 cost capstone.'
AS
SELECT
  LAB_ID,
  MAX(LAB_NAME)                                            AS LAB_NAME,
  MIN(CASE WHEN EVENT_TYPE = 'SETUP' THEN EVENT_TS END)     AS FIRST_SETUP_AT,
  MAX(EVENT_TS)                                            AS LAST_EVENT_AT,
  COUNT(*)                                                 AS EVENT_COUNT,
  MAX(WAREHOUSE_NAME)                                      AS WAREHOUSE_NAME
FROM IDENTIFIER($RUN_LOG)
GROUP BY LAB_ID;

-- Role creation/grants belong to 00_admin_role_setup.sql, not attendee setup.
-- Run this script as the role that will run all subsequent lab scripts.
-- IF NOT EXISTS does not transfer ownership of previously created objects.

-- ------------------------------------------------------------
-- 5. Confirm
-- ------------------------------------------------------------
SELECT
  'Workshop shared objects ready'                    AS STATUS,
  $WH                                                AS YOUR_WAREHOUSE,
  $SHARED_DB                                         AS YOUR_SHARED_DATABASE,
  CURRENT_ACCOUNT()                                  AS ACCOUNT,
  CURRENT_REGION()                                   AS REGION,
  (SELECT COUNT(*) FROM IDENTIFIER($RUN_LOG)) AS LABS_LOGGED_SO_FAR,
  CURRENT_ROLE() AS OBJECT_OWNER_ROLE;

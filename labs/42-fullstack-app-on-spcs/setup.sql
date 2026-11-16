-- ============================================================
-- Lab 42 -- A full-stack React app on SPCS, backed by Snowflake Postgres
--
-- STRETCH LAB. Not part of the timed workshop. This script is the
-- cheap half: it creates a Snowflake database with a small, app-shaped
-- source dataset, and then runs a preflight report so you find out
-- BEFORE you start whether this account can actually finish the lab.
--
-- It deliberately does NOT create the Snowflake Postgres instance or
-- the application service. Two reasons:
--   1. A Postgres instance has no auto-suspend. It bills from the
--      moment it is Ready until you drop it, so it should only ever
--      be created by a human who is about to use it.
--   2. The Postgres admin password is displayed exactly once, at
--      create time. A script that swallows it is worse than useless.
--
-- You create those two objects yourself, with CoCo, in Steps 2 and 4
-- of the README -- using the fixed names listed below so that
-- cleanup.sql can find and drop every one of them.
--
--   COCO_WS_LAB42_PG              Postgres instance      (account level)
--   COCO_WS_LAB42_PG_INGRESS      network policy         (account level)
--   COCO_WS_LAB42_PG_EAI          external access integ. (account level)
--   COCO_WS_LAB42_PG_EGRESS       network rule           (in the lab DB)
--   COCO_WS_LAB42_PG_CREDS        secret                 (in the lab DB)
--   COCO_WS_LAB42_APP             application service
--
-- Re-runnable: per-lab objects use CREATE OR REPLACE.
-- Teardown: labs/42-fullstack-app-on-spcs/cleanup.sql
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
--   * CoCo runs its SQL in its own session, so it does NOT see these
--     variables. The last query in this file prints your real object
--     names -- paste those into a prompt rather than $LAB_DB.
-- ------------------------------------------------------------
SET NS            = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET WH            = 'COCO_WS_WH_' || $NS;
SET SHARED_DB     = 'COCO_WS_SHARED_DB_' || $NS;
SET SHARED_SCHEMA = $SHARED_DB || '.WORKSHOP';
SET RUN_LOG       = $SHARED_DB || '.WORKSHOP.LAB_RUN_LOG';
SET LAB_DB        = 'COCO_WS_LAB42_DB_' || $NS;

-- ------------------------------------------------------------
-- Shared bootstrap (safe to re-run, safe if another lab did it)
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($WH)
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'CoCo Interactive Workshop -- shared compute for all labs';
USE WAREHOUSE IDENTIFIER($WH);

CREATE DATABASE IF NOT EXISTS IDENTIFIER($SHARED_DB)
  COMMENT = 'CoCo Interactive Workshop -- shared workshop metadata';
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($SHARED_SCHEMA);
CREATE TABLE IF NOT EXISTS IDENTIFIER($RUN_LOG) (
  LAB_ID VARCHAR(16), LAB_NAME VARCHAR(200), EVENT_TYPE VARCHAR(20),
  EVENT_TS TIMESTAMP_LTZ, USER_NAME VARCHAR(200), ROLE_NAME VARCHAR(200),
  WAREHOUSE_NAME VARCHAR(200), SESSION_ID VARCHAR(50), QUERY_TAG VARCHAR(200)
);

ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB42';

-- ------------------------------------------------------------
-- Lab database and the source dataset
-- ------------------------------------------------------------
CREATE OR REPLACE DATABASE IDENTIFIER($LAB_DB)
  COMMENT = 'CoCo Workshop Lab 42 -- full-stack app on SPCS over Snowflake Postgres';
USE DATABASE IDENTIFIER($LAB_DB);
CREATE OR REPLACE SCHEMA LAB;
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

-- Small on purpose. The lab is about the stack, not the data volume:
-- 24 rows migrate into Postgres in seconds and are easy to eyeball in
-- a browser, which is exactly what you want when you are debugging a
-- deployment rather than a query.
CREATE OR REPLACE TABLE SERVICE_REQUESTS (
  REQUEST_ID   NUMBER(9,0)   NOT NULL COMMENT 'Public-facing ticket number',
  CATEGORY     VARCHAR(40)   NOT NULL COMMENT 'Type of request',
  DISTRICT     VARCHAR(40)   NOT NULL COMMENT 'Reporting district',
  STATUS       VARCHAR(20)   NOT NULL COMMENT 'OPEN, IN_PROGRESS, RESOLVED or REJECTED',
  PRIORITY     NUMBER(1,0)   NOT NULL COMMENT '1 highest to 4 lowest',
  OPENED_AT    TIMESTAMP_NTZ NOT NULL COMMENT 'When the request was filed',
  RESOLVED_AT  TIMESTAMP_NTZ          COMMENT 'Null while still open',
  SUMMARY      VARCHAR(200)  NOT NULL COMMENT 'One-line description',
  CONSTRAINT PK_SERVICE_REQUESTS PRIMARY KEY (REQUEST_ID)
) COMMENT = 'A municipal service-request queue. List, filter, detail and update -- an honest shape for a CRUD app.';

INSERT INTO SERVICE_REQUESTS
  (REQUEST_ID, CATEGORY, DISTRICT, STATUS, PRIORITY, OPENED_AT, RESOLVED_AT, SUMMARY) VALUES
  (100201, 'Street lighting',  'Harbour West',  'OPEN',        2, '2026-07-02 08:14:00', NULL,                  'Three consecutive lamps out on Wharf Road'),
  (100202, 'Waste collection', 'Harbour West',  'RESOLVED',    3, '2026-07-02 09:41:00', '2026-07-04 11:05:00', 'Missed commercial collection, Tuesday route'),
  (100203, 'Road surface',     'Old Quarter',   'IN_PROGRESS', 1, '2026-07-03 07:02:00', NULL,                  'Sinkhole forming at the Mill Street junction'),
  (100204, 'Graffiti',         'Old Quarter',   'OPEN',        4, '2026-07-03 16:20:00', NULL,                  'Tagging on the underpass retaining wall'),
  (100205, 'Street lighting',  'Northfield',    'RESOLVED',    2, '2026-07-04 20:55:00', '2026-07-08 09:30:00', 'Flickering lamp outside the primary school'),
  (100206, 'Drainage',         'Northfield',    'IN_PROGRESS', 1, '2026-07-05 06:35:00', NULL,                  'Storm drain backing up onto the carriageway'),
  (100207, 'Waste collection', 'Northfield',    'REJECTED',    4, '2026-07-05 13:12:00', '2026-07-06 08:45:00', 'Bin request for a property outside the district'),
  (100208, 'Parks',            'Riverside',     'OPEN',        3, '2026-07-06 10:08:00', NULL,                  'Broken swing frame in the playground'),
  (100209, 'Road surface',     'Riverside',     'RESOLVED',    2, '2026-07-06 11:50:00', '2026-07-12 15:20:00', 'Pothole cluster on the approach to the bridge'),
  (100210, 'Drainage',         'Harbour West',  'OPEN',        2, '2026-07-07 05:47:00', NULL,                  'Gully cover missing beside the ferry terminal'),
  (100211, 'Graffiti',         'Riverside',     'RESOLVED',    4, '2026-07-08 14:03:00', '2026-07-09 10:10:00', 'Tagging on three benches along the towpath'),
  (100212, 'Street lighting',  'Old Quarter',   'OPEN',        3, '2026-07-09 21:31:00', NULL,                  'Lamp column leaning after the storm'),
  (100213, 'Parks',            'Northfield',    'IN_PROGRESS', 3, '2026-07-10 08:22:00', NULL,                  'Fallen tree blocking the north footpath'),
  (100214, 'Waste collection', 'Old Quarter',   'OPEN',        3, '2026-07-11 07:15:00', NULL,                  'Overflowing public bins on market day'),
  (100215, 'Road surface',     'Harbour West',  'OPEN',        1, '2026-07-12 06:58:00', NULL,                  'Carriageway cracking outside the freight depot'),
  (100216, 'Drainage',         'Riverside',     'RESOLVED',    2, '2026-07-13 09:44:00', '2026-07-17 16:00:00', 'Standing water at the car park entrance'),
  (100217, 'Parks',            'Harbour West',  'OPEN',        4, '2026-07-14 12:26:00', NULL,                  'Hedge overgrowing the shared cycle path'),
  (100218, 'Street lighting',  'Riverside',     'IN_PROGRESS', 2, '2026-07-15 19:09:00', NULL,                  'Whole street unlit after cable fault'),
  (100219, 'Graffiti',         'Northfield',    'OPEN',        4, '2026-07-16 15:37:00', NULL,                  'Tagging on the library service door'),
  (100220, 'Road surface',     'Northfield',    'REJECTED',    3, '2026-07-17 08:01:00', '2026-07-18 09:12:00', 'Private access road, not adopted by the council'),
  (100221, 'Waste collection', 'Riverside',     'IN_PROGRESS', 2, '2026-07-18 06:44:00', NULL,                  'Fly-tipping behind the recycling point'),
  (100222, 'Drainage',         'Old Quarter',   'OPEN',        1, '2026-07-19 05:29:00', NULL,                  'Sewer smell reported by four adjacent properties'),
  (100223, 'Parks',            'Old Quarter',   'RESOLVED',    4, '2026-07-20 11:18:00', '2026-07-22 13:40:00', 'Bench slats split on the green'),
  (100224, 'Street lighting',  'Harbour West',  'OPEN',        3, '2026-07-21 20:12:00', NULL,                  'Photocell failure, lamps on during daylight');

-- A view the app can use directly, so "what should the API return" has
-- an obvious first answer rather than being another design decision.
--
-- OPENED_AT is TIMESTAMP_NTZ, so CURRENT_TIMESTAMP() is pinned to UTC
-- and cast to NTZ before the DATEDIFF. Diffing an NTZ against an LTZ
-- works, but it silently resolves in the session timezone, so two
-- attendees in different regions would read different ages off the
-- same rows. That is a support question, not a feature.
CREATE OR REPLACE VIEW OPEN_REQUEST_SUMMARY
  COMMENT = 'Open and in-progress counts by district and priority. The default screen of the app.' AS
SELECT DISTRICT,
       PRIORITY,
       COUNT(*)       AS OPEN_REQUESTS,
       MIN(OPENED_AT) AS OLDEST_OPENED_AT,
       DATEDIFF('day', MIN(OPENED_AT),
                CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ) AS OLDEST_AGE_DAYS
FROM SERVICE_REQUESTS
WHERE STATUS IN ('OPEN', 'IN_PROGRESS')
GROUP BY DISTRICT, PRIORITY;

-- ------------------------------------------------------------
-- Register this run for the Lab 62 cost capstone
-- ------------------------------------------------------------
INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB42', 'Full-stack app on SPCS over Snowflake Postgres', 'SETUP',
       CURRENT_TIMESTAMP(), CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ------------------------------------------------------------
-- Confirm the data landed
-- ------------------------------------------------------------
SELECT COUNT(*) AS ROWS_LOADED FROM SERVICE_REQUESTS;

SELECT DISTRICT, SUM(OPEN_REQUESTS) AS STILL_OPEN
FROM OPEN_REQUEST_SUMMARY
GROUP BY DISTRICT
ORDER BY STILL_OPEN DESC, DISTRICT;

-- ------------------------------------------------------------
-- Preflight. Read these three results before you start Step 1.
-- ------------------------------------------------------------

-- 1. Can this account run Snowflake Postgres at all?
--    Success with zero rows is the expected answer on a clean account.
--    An error here means Postgres is not enabled and the lab stops now.
SHOW POSTGRES INSTANCES;

-- 2. Where will a deployed app land?
--    All six values empty is normal and workable: the app is created in
--    your personal database USER$<login_name> on a Snowflake-managed
--    pool. Apps in a personal database cannot be shared with other
--    roles, which is fine for a solo stretch lab. If you want a
--    shareable app, an ACCOUNTADMIN sets DESTINATION_DATABASE first.
SHOW PARAMETERS LIKE 'DEFAULT_SNOWFLAKE_APPS%' IN ACCOUNT;

-- 3. Do you hold the privileges the rest of the lab needs?
--    CREATE POSTGRES INSTANCE is ACCOUNTADMIN by default, and the
--    application service, network rule and secret all need CREATE
--    rights in the target schema.
SELECT CURRENT_ROLE()                                  AS CURRENT_ROLE,
       CURRENT_ACCOUNT()                               AS ACCOUNT,
       CURRENT_REGION()                                AS REGION,
       ARRAY_CONTAINS('ACCOUNTADMIN'::VARIANT,
         PARSE_JSON(CURRENT_AVAILABLE_ROLES()))        AS HAS_ACCOUNTADMIN;

-- ------------------------------------------------------------
-- Your object names, for pasting into CoCo
--
-- CoCo runs in its own session and cannot see the variables above,
-- so give it the real names. Copy the value, not the variable.
-- ------------------------------------------------------------
SELECT $LAB_DB            AS YOUR_LAB_DATABASE,
       $LAB_DB || '.LAB'  AS YOUR_LAB_SCHEMA,
       $WH                AS YOUR_WAREHOUSE,
       $SHARED_DB         AS YOUR_SHARED_DATABASE;

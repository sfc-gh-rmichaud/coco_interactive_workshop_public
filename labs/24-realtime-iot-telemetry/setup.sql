-- ============================================================
-- Lab 24 -- Stream IoT telemetry in, and watch it live
--
-- Creates COCO_WS_LAB24_DB_<you>.LAB with the Snowflake side of a
-- realtime pipeline: a landing table, a PIPE that accepts a stream,
-- and the aggregates a dashboard reads. What it deliberately does NOT
-- create is any data -- the rows arrive from a Node.js simulator you
-- run yourself, over the Snowpipe Streaming SDK, because the point of
-- this lab is data arriving while you watch.
--
-- The trap this lab is built around:
--
--   Streaming ingest is not synchronous, and nothing tells you that.
--   `appendRows()` returns immediately and reports no error, the SDK
--   logs look healthy, and a SELECT run one second later returns zero
--   rows. Measured on a real run: rows appended and flushed at t+7s
--   were not visible until t+16s. Every "my streaming pipeline is
--   broken" report starts here, and the fix is to wait rather than to
--   change anything.
--
--   So the lab makes you measure that lag rather than describing it.
--
-- Two further things that bite, both verified:
--   * A VARIANT column must be handed a native JavaScript object. Pass
--     a JSON string and it lands as VARCHAR -- TYPEOF() is how you
--     find out, and it is worth checking every time.
--   * An interactive table's WAREHOUSE is its REFRESH warehouse and
--     must NOT be an interactive one. Passing an interactive warehouse
--     fails with `010425 ... must not be an interactive warehouse`.
--     The interactive warehouse is what you QUERY it with.
--
-- Re-runnable: per-lab objects use CREATE OR REPLACE.
-- Teardown: labs/24-realtime-iot-telemetry/cleanup.sql
-- ============================================================

-- ------------------------------------------------------------
-- Per-user namespace
--
-- Every object this lab creates at ACCOUNT level -- the database and
-- the warehouse -- is suffixed with your user name, so a whole room
-- can run this lab in one Snowflake account without colliding.
-- Everything INSIDE the database keeps its usual name, so the SQL
-- below reads identically for everyone.
--
-- Two things worth knowing:
--   * Session variables live only for this session, so every file in
--     the workshop sets its own. Run the file top to bottom.
--   * CoCo runs its SQL in its own session, so it does NOT see these
--     variables. The last query in this file prints your real object
--     names -- paste those into a prompt, and into the simulator's
--     config, rather than $LAB_DB.
-- ------------------------------------------------------------
SET NS            = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET WH            = 'COCO_WS_WH_' || $NS;
SET SHARED_DB     = 'COCO_WS_SHARED_DB_' || $NS;
SET SHARED_SCHEMA = $SHARED_DB || '.WORKSHOP';
SET RUN_LOG       = $SHARED_DB || '.WORKSHOP.LAB_RUN_LOG';
SET LAB_DB        = 'COCO_WS_LAB24_DB_' || $NS;

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

ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB24';

-- ------------------------------------------------------------
-- Preflight. Read this before running the rest of the file.
--
-- Deliberately a REPORT rather than a probe. Two reasons:
--
--   * There is no free, reliable way to test for interactive warehouse
--     support without creating one, and creating one is the single most
--     expensive object in this workshop (one-hour minimum billing per
--     resume, 24-hour minimum AUTO_SUSPEND). A preflight must not create
--     that on your behalf to satisfy its own curiosity.
--
--   * `snow sql -f` aborts on the first failing statement, and the CLI
--     splits on semicolons, so a Snowflake Scripting block with an
--     EXCEPTION handler cannot be used here to make a failed probe
--     non-fatal. A failing probe would take the whole setup down with it.
--
-- So: the MAIN path of this lab needs nothing unusual, and the statements
-- below it are their own privilege test -- if you cannot CREATE DATABASE
-- or CREATE PIPE, setup fails immediately with a clear error rather than
-- halfway through. What genuinely catches people out later is listed here.
-- ------------------------------------------------------------
SELECT
  CURRENT_REGION()                     AS YOUR_REGION,
  CURRENT_ROLE()                       AS YOUR_ROLE,
  -- The main path needs neither of these; the OPTIONAL interactive table
  -- section at the end of the README needs both.
  'Interactive warehouses are GA in selected regions only. If the optional '
    || 'section fails with an unsupported-feature error, that is why -- the '
    || 'main lab is unaffected.'       AS OPTIONAL_SECTION_REGION_NOTE,
  'The optional section also needs CREATE WAREHOUSE. Skip it if you do not '
    || 'have that; nothing else in the lab depends on it.'
                                       AS OPTIONAL_SECTION_PRIVILEGE_NOTE,
  -- This is the one that actually wastes people's time: the SDK authenticates
  -- with a key pair, and a missing or mismatched key fails at step 1 with a
  -- generic JWT error that names no cause. The README's Before-you-start
  -- section has the fingerprint comparison that confirms it.
  'Before running the simulator, confirm your RSA public key fingerprint '
    || 'matches RSA_PUBLIC_KEY_FP in DESCRIBE USER. See Before you start.'
                                       AS SDK_AUTH_REMINDER;

-- ------------------------------------------------------------
-- Lab database
-- ------------------------------------------------------------
CREATE OR REPLACE DATABASE IDENTIFIER($LAB_DB)
  COMMENT = 'CoCo Workshop Lab 24 -- realtime IoT telemetry';
USE DATABASE IDENTIFIER($LAB_DB);
CREATE OR REPLACE SCHEMA LAB;
USE SCHEMA LAB;

-- ------------------------------------------------------------
-- The landing table.
--
-- Column names matter here: the PIPE below uses
-- MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE, so the keys in each
-- streamed row have to match these names. A typo in a key does not
-- error -- the column simply arrives NULL, which is the second most
-- common "streaming is broken" report after the latency one.
--
-- PAYLOAD is VARIANT on purpose, so the lab can show the difference
-- between passing a native object and passing a JSON string.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE SENSOR_READINGS (
  DEVICE_ID    VARCHAR(40)   NOT NULL COMMENT 'Device that produced the reading',
  SITE_NAME    VARCHAR(40)   NOT NULL COMMENT 'Physical site the device sits at',
  READING_TS   TIMESTAMP_NTZ NOT NULL COMMENT 'When the device took the reading',
  TEMP_C       FLOAT                  COMMENT 'Temperature in degrees Celsius',
  HUMIDITY_PCT FLOAT                  COMMENT 'Relative humidity, per cent',
  VIBRATION_MM FLOAT                  COMMENT 'Vibration amplitude in millimetres',
  PAYLOAD      VARIANT                COMMENT 'Whole reading as sent, for anything not modelled'
) COMMENT = 'Landing table for streamed sensor readings. Written only by the Snowpipe Streaming pipe.';

-- ------------------------------------------------------------
-- The pipe. This is what the high-performance architecture requires:
-- the client binds to a PIPE, not to a table.
--
-- `FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))` is the whole
-- difference from a stage-based COPY. There is no stage, no file and
-- no notification -- the rows arrive over the SDK.
-- ------------------------------------------------------------
CREATE OR REPLACE PIPE SENSOR_PIPE
  COMMENT = 'Accepts streamed sensor readings from the Node.js simulator.'
  AS COPY INTO SENSOR_READINGS
     FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))
     MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ------------------------------------------------------------
-- A timezone trap that is worth reading before the views below.
--
-- The devices send UTC, and READING_TS is TIMESTAMP_NTZ -- a wall-clock
-- with no zone attached. So the values in that column are UTC.
--
-- CURRENT_TIMESTAMP() is NOT UTC. It returns a zone-aware timestamp in
-- the SESSION's timezone, so `READING_TS >= DATEADD('minute', -15,
-- CURRENT_TIMESTAMP())` compares UTC against local time and is wrong by
-- your UTC offset. Measured on this account (America/Los_Angeles): the
-- dashboard's "behind live" figure came out at -24,970 seconds, about
-- minus seven hours. Rows appeared to arrive from the future.
--
-- Worse, it fails in different directions depending on where you are.
-- West of UTC the readings look like the future and pass a "last 15
-- minutes" filter regardless of age; east of UTC they look old and the
-- filter throws away perfectly fresh data, so the dashboard is simply
-- empty and nothing looks broken.
--
-- SYSDATE() is the right counterpart: it returns the current UTC time as
-- TIMESTAMP_NTZ, so it compares like with like. Every view below uses it.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- What the dashboard reads.
--
-- A plain view, not a dynamic table, and that choice is the lab's
-- central trade-off rather than an accident:
--
--   A view is always exactly as fresh as the landing table, which for
--   a dashboard watching live telemetry is the entire requirement. It
--   costs a query each time it is read.
--
--   A dynamic table would cost less per read and would be at most
--   TARGET_LAG stale -- and the minimum TARGET_LAG is 60 seconds,
--   which is longer than the ingest lag you are about to measure. For
--   a live view, that is the wrong trade.
--
-- Step 5 asks you to make this decision deliberately rather than
-- inheriting it.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW V_LIVE_READINGS
  COMMENT = 'Last 15 minutes of readings, newest first. What the dashboard polls.'
AS
SELECT DEVICE_ID, SITE_NAME, READING_TS, TEMP_C, HUMIDITY_PCT, VIBRATION_MM
FROM SENSOR_READINGS
WHERE READING_TS >= DATEADD('minute', -15, SYSDATE())
ORDER BY READING_TS DESC;

-- Per-site rollup on a 10-second grain, which is what the chart plots.
-- TIME_SLICE is the readable way to bucket a timestamp; date_trunc cannot
-- do sub-minute buckets.
CREATE OR REPLACE VIEW V_SITE_TELEMETRY
  COMMENT = 'Ten-second buckets per site. The dashboard chart reads this.'
AS
SELECT
  SITE_NAME,
  TIME_SLICE(READING_TS, 10, 'SECOND')          AS BUCKET_TS,
  COUNT(*)                                      AS READINGS,
  ROUND(AVG(TEMP_C), 2)                         AS AVG_TEMP_C,
  ROUND(MAX(VIBRATION_MM), 2)                   AS MAX_VIBRATION_MM,
  ROUND(AVG(HUMIDITY_PCT), 1)                   AS AVG_HUMIDITY_PCT
FROM SENSOR_READINGS
WHERE READING_TS >= DATEADD('minute', -15, SYSDATE())
GROUP BY 1, 2;

-- The alert condition the dashboard highlights. Vibration above 8mm is the
-- fault the simulator injects into one device after about 90 seconds, so this
-- view is empty at first and fills up later -- which is what makes the
-- dashboard worth watching rather than screenshotting.
CREATE OR REPLACE VIEW V_VIBRATION_ALERTS
  COMMENT = 'Readings above the 8mm vibration threshold.'
AS
SELECT DEVICE_ID, SITE_NAME, READING_TS, VIBRATION_MM
FROM SENSOR_READINGS
WHERE VIBRATION_MM > 8.0
  AND READING_TS >= DATEADD('minute', -15, SYSDATE());

-- ------------------------------------------------------------
-- Register this run for the Lab 62 cost capstone
-- ------------------------------------------------------------
INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB24', 'Realtime IoT telemetry', 'SETUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ------------------------------------------------------------
-- Confirm. Everything should exist and the table should be EMPTY --
-- setup creates no rows, because the rows are the lab.
-- ------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM SENSOR_READINGS) AS ROWS_NOW,
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS
    WHERE TABLE_SCHEMA = 'LAB'
      AND TABLE_NAME IN ('V_LIVE_READINGS','V_SITE_TELEMETRY','V_VIBRATION_ALERTS')) AS VIEWS_CREATED;

SHOW PIPES LIKE 'SENSOR_PIPE' IN SCHEMA;

-- ------------------------------------------------------------
-- Your object names, for the simulator config and for CoCo.
--
-- ACCOUNT_IDENTIFIER is the one people get wrong: the SDK wants the
-- ORGNAME-ACCOUNTNAME form, not the account locator.
-- ------------------------------------------------------------
SELECT $LAB_DB                                       AS YOUR_LAB_DATABASE,
       'LAB'                                         AS YOUR_SCHEMA,
       'SENSOR_PIPE'                                 AS YOUR_PIPE,
       CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() AS YOUR_ACCOUNT_IDENTIFIER,
       CURRENT_USER()                                AS YOUR_USER,
       CURRENT_ROLE()                                AS YOUR_ROLE,
       $WH                                           AS YOUR_WAREHOUSE;

-- ============================================================
-- Lab 62 -- What did today actually cost? (capstone)
--
-- Best run LAST, after two or more other labs, because it analyses
-- the credits and queries THOSE labs just generated. It also works
-- standalone, using the seeded snapshot this script creates.
--
-- Three tiers of data, and the lab uses all three on purpose:
--
--   Tier A  INFORMATION_SCHEMA table functions       zero latency
--           Live warehouse credits and query history. Works the
--           moment a lab finishes.
--
--   Tier B  ACCOUNT_USAGE.CORTEX_CODE_*_USAGE_HISTORY   ~1 hour lag
--           What CoCo itself cost, per surface. May not have landed
--           yet for labs you ran minutes ago. That is expected.
--
--   Tier C  the seeded tables created below              no latency
--           A synthetic but realistic workshop session, so the
--           analysis always works even on a brand-new account with
--           no history at all.
--
-- Re-runnable: per-lab objects use CREATE OR REPLACE.
-- Teardown: labs/62-cost-and-usage-capstone/cleanup.sql
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
SET LAB_DB        = 'COCO_WS_LAB62_DB_' || $NS;

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

ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB62';

-- ------------------------------------------------------------
-- Lab database
-- ------------------------------------------------------------
CREATE OR REPLACE DATABASE IDENTIFIER($LAB_DB)
  COMMENT = 'CoCo Workshop Lab 62 -- cost and usage capstone';
USE DATABASE IDENTIFIER($LAB_DB);
CREATE OR REPLACE SCHEMA LAB;
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

-- ============================================================
-- TIER C -- the seeded fallback session
--
-- Shaped like the real ACCOUNT_USAGE views so the same analysis
-- works against either. Represents a five-lab workshop with three
-- findings deliberately planted in it:
--
--   1. LAB21 is by far the most expensive lab.
--   2. One runaway query accounts for a large share of LAB21.
--   3. The warehouse sat idle and awake for the most recent metered
--      hour -- credits burned with no queries in them at all.
--
-- The CoCo usage seed below carries a fourth, separate point: spend is
-- concentrated in Desktop, and opus costs ~3x more PER TOKEN than sonnet
-- (1.5 vs 0.5 credits per million). Note the priciest hour is the one with
-- the MOST requests on the CHEAPER model -- so request count is the wrong
-- denominator. These three numbered findings must stay in step with the
-- list in README.md; they are what step 5 grades against.
-- ============================================================

CREATE OR REPLACE TABLE USAGE_SNAPSHOT_METERING (
  START_TIME                  TIMESTAMP_LTZ,
  END_TIME                    TIMESTAMP_LTZ,
  WAREHOUSE_NAME              VARCHAR(100),
  CREDITS_USED                NUMBER(12,9),
  CREDITS_USED_COMPUTE        NUMBER(12,9),
  CREDITS_USED_CLOUD_SERVICES NUMBER(12,9)
) COMMENT = 'Seeded. Same shape as ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY.';

INSERT INTO USAGE_SNAPSHOT_METERING
  (START_TIME, END_TIME, WAREHOUSE_NAME, CREDITS_USED, CREDITS_USED_COMPUTE, CREDITS_USED_CLOUD_SERVICES)
SELECT
  DATEADD('hour', -1 * H, DATE_TRUNC('hour', CURRENT_TIMESTAMP())),
  DATEADD('hour', -1 * H + 1, DATE_TRUNC('hour', CURRENT_TIMESTAMP())),
  $WH,
  C, ROUND(C * 0.96, 9), ROUND(C * 0.04, 9)
FROM (
  SELECT 3 AS H, 0.412000000 AS C UNION ALL
  SELECT 2,      0.986000000 UNION ALL   -- the expensive hour
  SELECT 1,      0.324000000 UNION ALL
  SELECT 0,      0.178000000
);

CREATE OR REPLACE TABLE USAGE_SNAPSHOT_QUERIES (
  QUERY_ID                       VARCHAR(64),
  START_TIME                     TIMESTAMP_LTZ,
  USER_NAME                      VARCHAR(100),
  ROLE_NAME                      VARCHAR(100),
  WAREHOUSE_NAME                 VARCHAR(100),
  DATABASE_NAME                  VARCHAR(100),
  QUERY_TAG                      VARCHAR(2000),
  QUERY_TYPE                     VARCHAR(40),
  TOTAL_ELAPSED_TIME             NUMBER(38,0),  -- milliseconds
  BYTES_SCANNED                  NUMBER(38,0),
  BYTES_SPILLED_TO_LOCAL_STORAGE NUMBER(38,0),
  PARTITIONS_SCANNED             NUMBER(38,0),
  PARTITIONS_TOTAL               NUMBER(38,0)
) COMMENT = 'Seeded. Same shape as ACCOUNT_USAGE.QUERY_HISTORY, trimmed to the useful columns.';

-- Ordinary lab traffic across five labs. Volume and cost per lab differ
-- so that "which lab cost the most" has a real answer.
INSERT INTO USAGE_SNAPSHOT_QUERIES
  (QUERY_ID, START_TIME, USER_NAME, ROLE_NAME, WAREHOUSE_NAME, DATABASE_NAME,
   QUERY_TAG, QUERY_TYPE, TOTAL_ELAPSED_TIME, BYTES_SCANNED,
   BYTES_SPILLED_TO_LOCAL_STORAGE, PARTITIONS_SCANNED, PARTITIONS_TOTAL)
WITH labs AS (
  SELECT 'LAB11' AS LAB, 1 AS DB_N, 60 AS QUERIES, 900   AS AVG_MS, 12000000  AS AVG_BYTES, 3 AS HOURS_AGO UNION ALL
  SELECT 'LAB21',        2,         140,           2600,          95000000,             2 UNION ALL
  SELECT 'LAB23',        3,         45,            700,           1800000,              2 UNION ALL
  SELECT 'LAB12',        4,         30,            800,           4200000,              1 UNION ALL
  SELECT 'LAB61',        9,         55,            3100,          140000000,            1
),
nums AS (
  -- A plain numbers list, joined per lab below. Using SEQ4() directly in a
  -- cross join against `labs` would NOT work: SEQ4() numbers the whole
  -- generator output once, globally, so a `SEQ4() < QUERIES` filter keeps
  -- only the first few rows overall instead of per lab.
  SELECT SEQ4() AS N FROM TABLE(GENERATOR(ROWCOUNT => 140))
),
g AS (
  SELECT l.LAB, l.DB_N, l.AVG_MS, l.AVG_BYTES, l.HOURS_AGO, n.N
  FROM labs l
  JOIN nums n ON n.N < l.QUERIES
)
SELECT
  'seed-' || g.LAB || '-' || LPAD(g.N, 4, '0'),
  DATEADD('second',
          MOD(ABS(HASH(g.LAB, g.N)), 3000),
          DATEADD('hour', -1 * g.HOURS_AGO, DATE_TRUNC('hour', CURRENT_TIMESTAMP()))),
  'WORKSHOP_ATTENDEE',
  'COCO_WS_USER',
  $WH,
  'COCO_WS_' || g.LAB || '_DB_' || $NS,
  -- Deliberately mixed, because this is what really happens: some queries
  -- carry the lab tag, some carry CoCo's own tag, some carry nothing.
  CASE MOD(ABS(HASH(g.N, 7)), 10)
    WHEN 0 THEN '{"app":"cortex_code_desktop","query_source":"agent_tool"}'
    WHEN 1 THEN '{"app":"cortex_code_cli","query_source":"agent_tool"}'
    WHEN 2 THEN NULL
    ELSE 'COCO_WS_' || g.LAB
  END,
  DECODE(MOD(ABS(HASH(g.N, 11)), 8), 0,'CREATE_TABLE_AS_SELECT', 1,'INSERT', 'SELECT'),
  GREATEST(50, g.AVG_MS + MOD(ABS(HASH(g.N, 13)), g.AVG_MS) - g.AVG_MS / 2),
  GREATEST(0, g.AVG_BYTES + MOD(ABS(HASH(g.N, 17)), g.AVG_BYTES) - g.AVG_BYTES / 2),
  0,
  1 + MOD(ABS(HASH(g.N, 19)), 40),
  64
FROM g;

-- The runaway query: one statement, a large share of the expensive hour.
-- Spills to local storage and scans every partition, so it is findable
-- by more than just duration.
INSERT INTO USAGE_SNAPSHOT_QUERIES
  (QUERY_ID, START_TIME, USER_NAME, ROLE_NAME, WAREHOUSE_NAME, DATABASE_NAME,
   QUERY_TAG, QUERY_TYPE, TOTAL_ELAPSED_TIME, BYTES_SCANNED,
   BYTES_SPILLED_TO_LOCAL_STORAGE, PARTITIONS_SCANNED, PARTITIONS_TOTAL)
SELECT
  'seed-LAB21-RUNAWAY',
  DATEADD('minute', 12, DATEADD('hour', -2, DATE_TRUNC('hour', CURRENT_TIMESTAMP()))),
  'WORKSHOP_ATTENDEE', 'COCO_WS_USER', $WH, 'COCO_WS_LAB21_DB_' || $NS,
  'COCO_WS_LAB21', 'SELECT',
  641000,          -- ten and a half minutes
  -- Byte counts are stored as exact binary multiples, because the analysis
  -- query reports them as BYTES / POWER(1024, 3). Seeding a decimal 84e9 here
  -- would render as 78.23, and the lab guide would be wrong by 7% on its
  -- headline finding for every attendee, every run.
  90194313216,     -- 84 GiB scanned          (84 * 1024^3)
  12884901888,     -- 12 GiB spilled to local storage (12 * 1024^3)
  64, 64;          -- every partition scanned: no pruning at all

CREATE OR REPLACE TABLE USAGE_SNAPSHOT_COCO (
  SURFACE       VARCHAR(20),
  USAGE_TIME    TIMESTAMP_LTZ,
  USER_NAME     VARCHAR(100),
  MODEL_NAME    VARCHAR(60),
  REQUESTS      NUMBER(38,0),
  TOKENS        NUMBER(38,0),
  TOKEN_CREDITS NUMBER(18,9)
) COMMENT = 'Seeded. Same shape as the three ACCOUNT_USAGE.CORTEX_CODE_*_USAGE_HISTORY views, unioned with a SURFACE column.';

INSERT INTO USAGE_SNAPSHOT_COCO
  (SURFACE, USAGE_TIME, USER_NAME, MODEL_NAME, REQUESTS, TOKENS, TOKEN_CREDITS)
SELECT
  S, DATEADD('hour', -1 * H, DATE_TRUNC('hour', CURRENT_TIMESTAMP())),
  'WORKSHOP_ATTENDEE', M, R, T, TC
FROM (
  SELECT 'DESKTOP'   AS S, 3 AS H, 'claude-sonnet-5' AS M, 41 AS R, 486000 AS T, 0.243000000 AS TC UNION ALL
  SELECT 'DESKTOP',        2,      'claude-sonnet-5',       88,     1240000,      0.620000000 UNION ALL
  SELECT 'DESKTOP',        1,      'claude-opus-4-8',       23,     390000,       0.585000000 UNION ALL
  SELECT 'SNOWSIGHT',      3,      'claude-sonnet-5',       18,     142000,      0.071000000 UNION ALL
  SELECT 'SNOWSIGHT',      2,      'claude-sonnet-5',       12,     96000,       0.048000000 UNION ALL
  SELECT 'CLI',            2,      'claude-sonnet-5',       26,     205000,      0.102000000 UNION ALL
  SELECT 'CLI',            1,      'claude-sonnet-5',       9,      74000,       0.037000000
);

-- ------------------------------------------------------------
-- Register this run for the capstone itself
-- ------------------------------------------------------------
INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB62', 'Cost and usage capstone', 'SETUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ------------------------------------------------------------
-- Confirm, and report what each tier can tell you right now.
-- ------------------------------------------------------------
SELECT 'Tier C seeded queries'  AS ITEM, TO_VARCHAR(COUNT(*)) AS VALUE FROM USAGE_SNAPSHOT_QUERIES
UNION ALL SELECT 'Tier C seeded metering hours', TO_VARCHAR(COUNT(*)) FROM USAGE_SNAPSHOT_METERING
UNION ALL SELECT 'Tier C seeded CoCo usage rows', TO_VARCHAR(COUNT(*)) FROM USAGE_SNAPSHOT_COCO
UNION ALL SELECT 'Labs logged in this account so far',
                 TO_VARCHAR(COUNT(DISTINCT LAB_ID)) FROM IDENTIFIER($RUN_LOG)
UNION ALL SELECT 'Earliest lab run',
                 TO_VARCHAR(MIN(EVENT_TS)) FROM IDENTIFIER($RUN_LOG);

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

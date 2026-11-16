-- ============================================================
-- Lab 63 -- Make old data cost less, on purpose
--
-- Creates COCO_WS_LAB63_DB_<you>.LAB with a large, deliberately
-- long-tailed event table and the storage-cost picture that goes with
-- it. You and CoCo decide what should expire, what should be archived,
-- and what must stay -- then express that as storage lifecycle policies.
--
-- The trap this lab is built around:
--
--   A storage lifecycle policy is not a retention SETTING, it is a
--   scheduled DELETE with a cost of its own. It runs daily, bills per
--   execution, and scans the table to decide what to remove. So a
--   policy attached to a table it cannot prune efficiently costs more
--   to run than the storage it saves -- and a one-off backfill left
--   attached forever bills every day for work it finished on day one.
--
--   Nothing warns you about either. The policy just quietly runs.
--
-- Three further things that bite, all verified against this account:
--
--   * The syntax is a boolean EXPRESSION, not a retention property.
--     `SCHEDULE = ...` and `EXPIRE_AFTER_DAYS = ...` do not exist and
--     fail with a bare `syntax error ... unexpected 'SCHEDULE'`.
--
--   * ARCHIVE_TIER has minimum retentions that are enforced at CREATE:
--     COOL needs ARCHIVE_FOR_DAYS >= 90 and COLD >= 180. Asking for
--     COOL with 30 days fails with 510827.
--
--   * Comparing a TIMESTAMP without TO_DATE() makes the policy's
--     behaviour depend on the time of day it happens to run, so the
--     same policy deletes a different number of rows each day.
--
-- Re-runnable: per-lab objects use CREATE OR REPLACE.
-- Teardown: labs/63-storage-lifecycle/cleanup.sql
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
--   * CoCo runs its SQL in its own session, so it does NOT see these
--     variables. The last query in this file prints your real object
--     names -- paste those into a prompt rather than $LAB_DB.
-- ------------------------------------------------------------
SET NS            = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET WH            = 'COCO_WS_WH_' || $NS;
SET SHARED_DB     = 'COCO_WS_SHARED_DB_' || $NS;
SET SHARED_SCHEMA = $SHARED_DB || '.WORKSHOP';
SET RUN_LOG       = $SHARED_DB || '.WORKSHOP.LAB_RUN_LOG';
SET LAB_DB        = 'COCO_WS_LAB63_DB_' || $NS;

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

ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB63';

-- ------------------------------------------------------------
-- Lab database
-- ------------------------------------------------------------
CREATE OR REPLACE DATABASE IDENTIFIER($LAB_DB)
  COMMENT = 'CoCo Workshop Lab 63 -- storage lifecycle policies';
USE DATABASE IDENTIFIER($LAB_DB);
CREATE OR REPLACE SCHEMA LAB;
USE SCHEMA LAB;

-- ------------------------------------------------------------
-- The event table. Three years of history, front-loaded so that most
-- of the ROWS are old and most of the QUERIES are recent -- which is
-- exactly the shape that makes lifecycle management worth doing, and
-- exactly the shape people fail to notice they have.
--
-- Clustered on EVENT_DATE deliberately: a lifecycle policy is passed
-- the attachment column and prunes on it, so a table not clustered on
-- that column makes every daily execution scan far more than it needs.
-- That is the difference between a policy that saves money and one
-- that costs money.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE APP_EVENTS (
  EVENT_ID     NUMBER(38,0)  NOT NULL COMMENT 'Event identifier',
  EVENT_DATE   DATE          NOT NULL COMMENT 'Date the event occurred. The lifecycle attachment column.',
  EVENT_TS     TIMESTAMP_NTZ NOT NULL COMMENT 'Full timestamp of the event',
  ACCOUNT_ID   NUMBER(38,0)  NOT NULL COMMENT 'Customer account the event belongs to',
  EVENT_TYPE   VARCHAR(30)   NOT NULL COMMENT 'page_view, api_call, export or admin_action',
  IS_BILLABLE  BOOLEAN       NOT NULL COMMENT 'TRUE if the event feeds invoicing',
  PAYLOAD_TEXT VARCHAR(400)           COMMENT 'Padding, so the table has realistic width'
)
  CLUSTER BY (EVENT_DATE)
  COMMENT = 'Three years of application events. Deliberately long-tailed: old rows dominate the row count.';

-- 3,000,000 rows over 1,095 days. The date skew is quadratic in the day
-- offset, so roughly two thirds of rows land in the oldest third of the
-- window -- a long tail rather than a uniform spread.
INSERT INTO APP_EVENTS
  (EVENT_ID, EVENT_DATE, EVENT_TS, ACCOUNT_ID, EVENT_TYPE, IS_BILLABLE, PAYLOAD_TEXT)
WITH base AS (
  SELECT
    SEQ8() + 1 AS EVENT_ID,
    -- MOD over a squared hash biases the draw towards larger day offsets,
    -- i.e. towards older dates.
    LEAST(1094,
      FLOOR(SQRT(MOD(ABS(HASH(SEQ8(), 3)), 1095 * 1095))))  AS DAYS_AGO,
    SEQ8() AS S
  FROM TABLE(GENERATOR(ROWCOUNT => 3000000))
)
SELECT
  b.EVENT_ID,
  DATEADD('day', -1 * b.DAYS_AGO, CURRENT_DATE())                       AS EVENT_DATE,
  DATEADD('second', MOD(ABS(HASH(b.S, 5)), 86400),
          DATEADD('day', -1 * b.DAYS_AGO, CURRENT_DATE())::TIMESTAMP_NTZ) AS EVENT_TS,
  1 + MOD(ABS(HASH(b.S, 7)), 400)                                       AS ACCOUNT_ID,
  DECODE(MOD(ABS(HASH(b.S, 11)), 20),
         0, 'admin_action', 1, 'export', 2, 'api_call', 3, 'api_call', 'page_view') AS EVENT_TYPE,
  -- Billable events must never be silently expired, which is what makes the
  -- lab's policy design a judgement rather than a one-liner.
  MOD(ABS(HASH(b.S, 13)), 10) = 0                                       AS IS_BILLABLE,
  RPAD('evt', 380, 'x')                                                 AS PAYLOAD_TEXT
FROM base b;

-- ------------------------------------------------------------
-- What the retention decision has to respect.
--
-- Seeded rather than described, because "we have to keep billing data
-- for seven years" is the kind of requirement that lives in somebody's
-- head until a policy deletes it.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE RETENTION_RULES (
  RULE_NAME     VARCHAR(60) NOT NULL,
  APPLIES_TO    VARCHAR(60) NOT NULL COMMENT 'Which events the rule covers',
  MIN_KEEP_DAYS NUMBER(10,0) NOT NULL COMMENT 'Minimum days the data must be retained',
  RATIONALE     VARCHAR(200) NOT NULL,
  CONSTRAINT PK_RETENTION_RULES PRIMARY KEY (RULE_NAME)
) COMMENT = 'The retention obligations a lifecycle policy must not violate.';

INSERT INTO RETENTION_RULES (RULE_NAME, APPLIES_TO, MIN_KEEP_DAYS, RATIONALE) VALUES
  ('billing_events',   'IS_BILLABLE = TRUE',            2555,
   'Invoicing evidence. Seven years, contractual. Must be retrievable, not necessarily fast.'),
  ('admin_audit',      'EVENT_TYPE = ''admin_action''', 1095,
   'Security audit trail. Three years, and queried during incidents so it should stay queryable.'),
  ('export_records',   'EVENT_TYPE = ''export''',        365,
   'Data-egress record. One year, for DSAR responses.'),
  ('product_analytics','EVENT_TYPE IN (''page_view'',''api_call'')', 180,
   'Product analytics only. Nobody has asked a question older than six months in two years.');

-- ------------------------------------------------------------
-- Register this run for the Lab 62 cost capstone
-- ------------------------------------------------------------
INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB63', 'Storage lifecycle policies', 'SETUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ------------------------------------------------------------
-- Confirm, and show the shape that makes this lab worth doing.
--
-- Look at the ratio: what fraction of rows are older than six months,
-- and what fraction of those are safe to expire under the rules above.
-- ------------------------------------------------------------
SELECT
  COUNT(*)                                                        AS TOTAL_ROWS,
  COUNT(DISTINCT EVENT_DATE)                                      AS DISTINCT_DAYS,
  MIN(EVENT_DATE)                                                 AS OLDEST,
  MAX(EVENT_DATE)                                                 AS NEWEST,
  ROUND(100.0 * COUNT_IF(EVENT_DATE < DATEADD('day', -180, CURRENT_DATE())) / COUNT(*), 1)
                                                                  AS PCT_OLDER_THAN_180D,
  ROUND(100.0 * COUNT_IF(IS_BILLABLE) / COUNT(*), 1)              AS PCT_BILLABLE
FROM APP_EVENTS;

-- Rows an analytics-only expiry would remove, and -- the number that matters --
-- how many of those are protected by a rule. A policy written from the first
-- number alone deletes invoicing evidence.
SELECT
  COUNT_IF(EVENT_DATE < DATEADD('day', -180, CURRENT_DATE()))     AS OLDER_THAN_180D,
  COUNT_IF(EVENT_DATE < DATEADD('day', -180, CURRENT_DATE())
           AND EVENT_TYPE IN ('page_view','api_call')
           AND NOT IS_BILLABLE)                                   AS SAFE_TO_EXPIRE,
  COUNT_IF(EVENT_DATE < DATEADD('day', -180, CURRENT_DATE())
           AND (IS_BILLABLE OR EVENT_TYPE IN ('admin_action','export')))
                                                                  AS PROTECTED_BY_A_RULE
FROM APP_EVENTS;

SELECT * FROM RETENTION_RULES ORDER BY MIN_KEEP_DAYS DESC;

-- ------------------------------------------------------------
-- Your object names, for pasting into CoCo
-- ------------------------------------------------------------
SELECT $LAB_DB            AS YOUR_LAB_DATABASE,
       $LAB_DB || '.LAB'  AS YOUR_LAB_SCHEMA,
       $WH                AS YOUR_WAREHOUSE;

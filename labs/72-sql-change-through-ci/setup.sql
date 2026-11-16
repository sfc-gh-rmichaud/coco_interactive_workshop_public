-- ============================================================
-- Lab 72 -- Put a SQL change through CI (CoCo CLI)
--
-- Creates COCO_WS_LAB72_DB_<you>.LAB with a small dependency chain:
--
--   ORDERS (table)
--     -> V_DAILY_REVENUE (view)        <- the object a migration changes
--          -> V_EXEC_SUMMARY (view)    <- the object that breaks
--
-- The lab applies a proposed migration that looks harmless in
-- isolation and breaks the downstream view. Reviewing the diff alone
-- cannot catch it; you have to look at what depends on the object.
-- That is the argument for putting an agent in CI rather than only in
-- a pull request comment.
--
-- Re-runnable: per-lab objects use CREATE OR REPLACE.
-- Teardown: labs/72-sql-change-through-ci/cleanup.sql
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
SET LAB_DB        = 'COCO_WS_LAB72_DB_' || $NS;

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

ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB72';

-- ------------------------------------------------------------
-- Lab database
-- ------------------------------------------------------------
CREATE OR REPLACE DATABASE IDENTIFIER($LAB_DB)
  COMMENT = 'CoCo Workshop Lab 72 -- SQL change through CI';
USE DATABASE IDENTIFIER($LAB_DB);
CREATE OR REPLACE SCHEMA LAB;
USE SCHEMA LAB;

CREATE OR REPLACE TABLE ORDERS (
  ORDER_ID     NUMBER(38,0)  NOT NULL COMMENT 'Order surrogate key',
  ORDER_DATE   DATE          NOT NULL COMMENT 'Date the order was placed',
  REGION_CD    VARCHAR(4)    NOT NULL COMMENT 'Sales region code',
  ORDER_STATUS VARCHAR(12)   NOT NULL COMMENT 'COMPLETE, PENDING or CANCELLED',
  ORDER_TOTAL  NUMBER(12,2)  NOT NULL COMMENT 'Order total in USD',
  CONSTRAINT PK_ORDERS PRIMARY KEY (ORDER_ID)
) COMMENT = 'Orders. Source of truth for revenue reporting.';

INSERT INTO ORDERS (ORDER_ID, ORDER_DATE, REGION_CD, ORDER_STATUS, ORDER_TOTAL)
SELECT
  SEQ4() + 1,
  DATEADD('day', -1 * MOD(ABS(HASH(SEQ4(), 3)), 120), CURRENT_DATE()),
  DECODE(MOD(ABS(HASH(SEQ4(), 5)), 4), 0,'NA',1,'NA',2,'EMEA','APJ'),
  DECODE(MOD(ABS(HASH(SEQ4(), 7)), 10), 0,'CANCELLED', 1,'PENDING', 'COMPLETE'),
  ROUND(25 + MOD(ABS(HASH(SEQ4(), 11)), 1200) + 0.99, 2)
FROM TABLE(GENERATOR(ROWCOUNT => 20000));

-- ------------------------------------------------------------
-- Current production views. This is the state a migration changes.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW V_DAILY_REVENUE
  COMMENT = 'Daily completed revenue by region. Consumed by V_EXEC_SUMMARY and by BI.'
AS
SELECT
  ORDER_DATE,
  REGION_CD,
  COUNT(*)          AS ORDER_COUNT,
  SUM(ORDER_TOTAL)  AS REVENUE_USD
FROM ORDERS
WHERE ORDER_STATUS = 'COMPLETE'
GROUP BY ORDER_DATE, REGION_CD;

-- The downstream consumer. It references REVENUE_USD by name, which
-- is what the proposed migration renames.
CREATE OR REPLACE VIEW V_EXEC_SUMMARY
  COMMENT = 'Executive rollup. Depends on V_DAILY_REVENUE.REVENUE_USD.'
AS
SELECT
  REGION_CD,
  SUM(REVENUE_USD)                  AS TOTAL_REVENUE_USD,
  SUM(ORDER_COUNT)                  AS TOTAL_ORDERS,
  ROUND(AVG(REVENUE_USD), 2)        AS AVG_DAILY_REVENUE_USD
FROM V_DAILY_REVENUE
GROUP BY REGION_CD;

-- ------------------------------------------------------------
-- Register this run for the Lab 62 cost capstone
-- ------------------------------------------------------------
INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB72', 'Put a SQL change through CI', 'SETUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ------------------------------------------------------------
-- Confirm. Both views must work before the lab starts.
-- ------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM ORDERS)                                AS ORDER_ROWS,
  (SELECT COUNT(*) FROM V_DAILY_REVENUE)                       AS DAILY_ROWS,
  (SELECT COUNT(*) FROM V_EXEC_SUMMARY)                        AS EXEC_ROWS,
  (SELECT ROUND(SUM(TOTAL_REVENUE_USD)) FROM V_EXEC_SUMMARY)   AS TOTAL_REVENUE;

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

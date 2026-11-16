-- ============================================================
-- Lab 73 -- CoCo in your IDE (Desktop / local)
--
-- Creates COCO_WS_LAB73_DB_<you>.LAB with one small, obviously-named table.
--
-- The Snowflake side of this lab is deliberately trivial. The lab is
-- about connecting CoCo to the tools you already use, and the table
-- exists only so you have something unambiguous to ask for from
-- inside those tools. If your IDE can tell you the revenue of the
-- top region here, the connection genuinely works -- it could not
-- have guessed the number.
--
-- Re-runnable: per-lab objects use CREATE OR REPLACE.
-- Teardown: labs/73-coco-in-your-ide/cleanup.sql
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
SET LAB_DB        = 'COCO_WS_LAB73_DB_' || $NS;

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

ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB73';

-- ------------------------------------------------------------
-- Lab database
-- ------------------------------------------------------------
CREATE OR REPLACE DATABASE IDENTIFIER($LAB_DB)
  COMMENT = 'CoCo Workshop Lab 73 -- IDE and MCP integration';
USE DATABASE IDENTIFIER($LAB_DB);
CREATE OR REPLACE SCHEMA LAB;
USE SCHEMA LAB;

CREATE OR REPLACE TABLE REGIONAL_REVENUE (
  REGION_NAME  VARCHAR(40)  NOT NULL COMMENT 'Sales region',
  FISCAL_YEAR  NUMBER(4,0)  NOT NULL COMMENT 'Fiscal year',
  REVENUE_USD  NUMBER(14,2) NOT NULL COMMENT 'Recognised revenue in USD',
  HEADCOUNT    NUMBER(38,0) NOT NULL COMMENT 'Sales headcount in region',
  CONSTRAINT PK_REGIONAL_REVENUE PRIMARY KEY (REGION_NAME, FISCAL_YEAR)
) COMMENT = 'Revenue by region and fiscal year. Small, fixed, and easy to verify by eye.';

-- Fixed values on purpose. The answer to "which region earned most in
-- 2026" is Northern Europe with 41,880,500.00, and no model could
-- guess that -- which is what makes it a real connectivity test.
INSERT INTO REGIONAL_REVENUE (REGION_NAME, FISCAL_YEAR, REVENUE_USD, HEADCOUNT) VALUES
  ('Northern Europe', 2026, 41880500.00, 214),
  ('Northern Europe', 2025, 36204100.00, 198),
  ('Iberia',          2026, 12335750.00,  61),
  ('Iberia',          2025, 11890200.00,  58),
  ('Great Lakes',     2026, 28470900.00, 152),
  ('Great Lakes',     2025, 30115600.00, 161),
  ('Pacific Rim',     2026, 19662300.00, 103),
  ('Pacific Rim',     2025, 15003450.00,  88),
  ('Gulf States',     2026,  7418250.00,  39),
  ('Gulf States',     2025,  6102900.00,  34);

-- ------------------------------------------------------------
-- Register this run for the Lab 62 cost capstone
-- ------------------------------------------------------------
INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB73', 'CoCo in your IDE', 'SETUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ------------------------------------------------------------
-- Confirm, and print the answer you will verify from your IDE.
-- ------------------------------------------------------------
SELECT COUNT(*) AS ROWS_LOADED FROM REGIONAL_REVENUE;

SELECT REGION_NAME AS TOP_REGION_2026, REVENUE_USD AS TOP_REVENUE_2026
FROM REGIONAL_REVENUE
WHERE FISCAL_YEAR = 2026
ORDER BY REVENUE_USD DESC
LIMIT 1;

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

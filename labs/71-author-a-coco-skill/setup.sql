-- ============================================================
-- Lab 71 -- Turn a recurring task into a reusable skill (Desktop)
--
-- Creates COCO_WS_LAB71_DB_<you>.LAB with four tables that between them
-- break every rule in a small, realistic set of table standards.
--
-- The lab is not really about these tables. It is about the fact that
-- reviewing new tables against house standards is a job someone does
-- by hand every week, badly and inconsistently. That is exactly the
-- shape of work worth encoding as a CoCo skill.
--
-- Known violations, so the skill can be tested rather than admired:
--
--   ORDER_HEADER      compliant. A good audit must NOT flag it.
--   order_line_items  lower-case name; no table comment; no primary key
--   CUSTOMER_DATA_TMP temp-looking name; no comment; no primary key
--   SHIPMENT_FACT     has a comment and a PK, but every column is
--                     uncommented and one column is a bare VARCHAR
--                     with no length, which defaults to maximum
--
-- Re-runnable: per-lab objects use CREATE OR REPLACE.
-- Teardown: labs/71-author-a-coco-skill/cleanup.sql
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
SET LAB_DB        = 'COCO_WS_LAB71_DB_' || $NS;

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

ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB71';

-- ------------------------------------------------------------
-- Lab database
-- ------------------------------------------------------------
CREATE OR REPLACE DATABASE IDENTIFIER($LAB_DB)
  COMMENT = 'CoCo Workshop Lab 71 -- authoring a reusable skill';
CREATE OR REPLACE SCHEMA LAB
  COMMENT = 'Tables submitted for standards review';
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

-- ------------------------------------------------------------
-- 1. The compliant table. A correct audit leaves this alone.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE ORDER_HEADER (
  ORDER_ID    NUMBER(38,0)  NOT NULL COMMENT 'Surrogate key for the order',
  CUSTOMER_ID NUMBER(38,0)  NOT NULL COMMENT 'FK to the customer dimension',
  ORDER_TS    TIMESTAMP_NTZ NOT NULL COMMENT 'When the order was placed',
  ORDER_TOTAL NUMBER(12,2)  NOT NULL COMMENT 'Order total in account currency',
  CONSTRAINT PK_ORDER_HEADER PRIMARY KEY (ORDER_ID)
) COMMENT = 'Order headers. One row per order.';

INSERT INTO ORDER_HEADER (ORDER_ID, CUSTOMER_ID, ORDER_TS, ORDER_TOTAL)
SELECT SEQ4() + 1, 1 + MOD(ABS(HASH(SEQ4(), 3)), 500),
       DATEADD('hour', -1 * MOD(ABS(HASH(SEQ4(), 5)), 2000), CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
       ROUND(20 + MOD(ABS(HASH(SEQ4(), 7)), 900) + 0.99, 2)
FROM TABLE(GENERATOR(ROWCOUNT => 500));

-- ------------------------------------------------------------
-- 2. Lower-case name, no comment, no primary key.
--    Quoted identifier so the lower case actually persists.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE "order_line_items" (
  ORDER_ID  NUMBER(38,0),
  LINE_NO   NUMBER(38,0),
  SKU       VARCHAR(20),
  QTY       NUMBER(38,0),
  LINE_AMT  NUMBER(12,2)
);

INSERT INTO "order_line_items" (ORDER_ID, LINE_NO, SKU, QTY, LINE_AMT)
SELECT 1 + MOD(SEQ4(), 500), 1 + MOD(SEQ4(), 3),
       'SKU-' || LPAD(MOD(ABS(HASH(SEQ4(), 11)), 200), 5, '0'),
       1 + MOD(ABS(HASH(SEQ4(), 13)), 5),
       ROUND(5 + MOD(ABS(HASH(SEQ4(), 17)), 300) + 0.5, 2)
FROM TABLE(GENERATOR(ROWCOUNT => 1200));

-- ------------------------------------------------------------
-- 3. Temp-looking name that has quietly become permanent.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE CUSTOMER_DATA_TMP (
  CUSTOMER_ID NUMBER(38,0),
  CUST_NAME   VARCHAR(120),
  EMAIL       VARCHAR(200),
  LOADED_AT   TIMESTAMP_LTZ
);

INSERT INTO CUSTOMER_DATA_TMP (CUSTOMER_ID, CUST_NAME, EMAIL, LOADED_AT)
SELECT SEQ4() + 1, 'Customer ' || LPAD(SEQ4() + 1, 5, '0'),
       'cust' || LPAD(SEQ4() + 1, 5, '0') || '@example.com', CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 500));

-- ------------------------------------------------------------
-- 4. Superficially fine: has a comment and a PK. But no column
--    comments at all, and NOTES is an unbounded VARCHAR.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE SHIPMENT_FACT (
  SHIPMENT_ID NUMBER(38,0) NOT NULL,
  ORDER_ID    NUMBER(38,0) NOT NULL,
  SHIPPED_AT  TIMESTAMP_NTZ,
  CARRIER     VARCHAR(40),
  NOTES       VARCHAR,
  CONSTRAINT PK_SHIPMENT_FACT PRIMARY KEY (SHIPMENT_ID)
) COMMENT = 'Shipments, one row per parcel.';

INSERT INTO SHIPMENT_FACT (SHIPMENT_ID, ORDER_ID, SHIPPED_AT, CARRIER, NOTES)
SELECT SEQ4() + 1, 1 + MOD(SEQ4(), 500),
       DATEADD('hour', -1 * MOD(ABS(HASH(SEQ4(), 19)), 1500), CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
       DECODE(MOD(SEQ4(), 3), 0,'DHL', 1,'UPS', 'Royal Mail'),
       'Left with neighbour'
FROM TABLE(GENERATOR(ROWCOUNT => 400));

-- ------------------------------------------------------------
-- Register this run for the Lab 62 cost capstone
-- ------------------------------------------------------------
INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB71', 'Turn a recurring task into a skill', 'SETUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ------------------------------------------------------------
-- The expected audit result, so the skill can be scored.
--
-- This is the answer key. A correct skill should reach the same
-- verdict from the metadata, without being shown this query.
-- ------------------------------------------------------------
SELECT
  t.TABLE_NAME,
  IFF(t.COMMENT IS NULL OR t.COMMENT = '', 'FAIL', 'pass')             AS HAS_TABLE_COMMENT,
  IFF(pk.PK_COUNT IS NULL, 'FAIL', 'pass')                             AS HAS_PRIMARY_KEY,
  IFF(t.TABLE_NAME <> UPPER(t.TABLE_NAME), 'FAIL', 'pass')            AS NAME_IS_UPPERCASE,
  -- ENDSWITH rather than LIKE '%\_TMP': backslash escaping inside a SQL
  -- string literal makes the LIKE pattern match a literal backslash, so the
  -- check silently passes for CUSTOMER_DATA_TMP. ENDSWITH has no escaping.
  IFF(ENDSWITH(t.TABLE_NAME, '_TMP') OR ENDSWITH(t.TABLE_NAME, '_TEMP'), 'FAIL', 'pass') AS NAME_NOT_TEMP,
  IFF(c.UNCOMMENTED_COLS > 0, 'FAIL', 'pass')                         AS ALL_COLUMNS_COMMENTED,
  IFF(c.UNBOUNDED_VARCHARS > 0, 'FAIL', 'pass')                       AS NO_UNBOUNDED_VARCHAR
FROM INFORMATION_SCHEMA.TABLES t
LEFT JOIN (
  SELECT TABLE_NAME,
         COUNT_IF(COMMENT IS NULL OR COMMENT = '')                     AS UNCOMMENTED_COLS,
         COUNT_IF(DATA_TYPE = 'TEXT' AND CHARACTER_MAXIMUM_LENGTH >= 16777216) AS UNBOUNDED_VARCHARS
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = 'LAB'
  GROUP BY TABLE_NAME
) c ON c.TABLE_NAME = t.TABLE_NAME
LEFT JOIN (
  -- Snowflake has no INFORMATION_SCHEMA.KEY_COLUMN_USAGE, so primary keys
  -- are detected from TABLE_CONSTRAINTS alone. Referencing
  -- KEY_COLUMN_USAGE fails with "does not exist or not authorized".
  SELECT TABLE_NAME, COUNT(*) AS PK_COUNT
  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_TYPE = 'PRIMARY KEY' AND TABLE_SCHEMA = 'LAB'
  GROUP BY TABLE_NAME
) pk ON pk.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_SCHEMA = 'LAB' AND t.TABLE_TYPE = 'BASE TABLE'
ORDER BY t.TABLE_NAME;

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

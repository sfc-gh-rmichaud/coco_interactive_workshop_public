-- ============================================================
-- Lab 53 -- Govern a hundred columns without touching a hundred columns
--
-- Creates COCO_WS_LAB53_DB_<you>.LAB with a realistically messy schema:
-- several tables, sensitive columns scattered through them under
-- inconsistent names, and no governance at all. You and CoCo classify
-- it and protect it with TAGS rather than per-column policies.
--
-- The trap this lab is built around, and it is a nasty one:
--
--   A masking policy protects a QUERY, not a VALUE. So a pipeline that
--   reads a masked column and writes the result somewhere else does not
--   fail, and does not copy the protection -- it copies the PLACEHOLDER,
--   as real data, permanently.
--
--   Verified on this account: with a mask returning '***MASKED***' to
--   unauthorised roles, `CREATE TABLE copy AS SELECT * FROM original`
--   run by an unauthorised role produced a table whose EMAIL column
--   literally contains the string '***MASKED***'. Reading the ORIGINAL
--   as an authorised role returns 'a@b.com'. Reading the COPY as that
--   same authorised role still returns '***MASKED***', because the real
--   value is gone. Nothing errored at any point.
--
--   Every derived table, every CTAS, every dbt model materialised by a
--   service role is exposed to this.
--
-- Two more things this lab establishes by measurement rather than
-- assertion:
--   * A VIEW does inherit the mask -- selecting through a view returns
--     the masked value, so views are safe in a way CTAS is not.
--   * Tagging a column is what applies the policy. One
--     ALTER TAG ... SET MASKING POLICY governs every column carrying
--     that tag, present and future, which is the entire point.
--
-- Re-runnable: per-lab objects use CREATE OR REPLACE.
-- Teardown: labs/53-governance-at-scale/cleanup.sql
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
SET LAB_DB        = 'COCO_WS_LAB53_DB_' || $NS;

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

ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB53';

-- ------------------------------------------------------------
-- Lab database
-- ------------------------------------------------------------
CREATE OR REPLACE DATABASE IDENTIFIER($LAB_DB)
  COMMENT = 'CoCo Workshop Lab 53 -- governance at scale with tags';
USE DATABASE IDENTIFIER($LAB_DB);
CREATE OR REPLACE SCHEMA LAB;
USE SCHEMA LAB;

-- ------------------------------------------------------------
-- The schema, deliberately inconsistent.
--
-- Sensitive columns appear under names that no single LIKE pattern
-- catches: EMAIL, EMAIL_ADDRESS, CONTACT_EMAIL, WORK_EMAIL. Some
-- obviously-sensitive-sounding columns are not sensitive at all
-- (SUPPORT_EMAIL is a shared inbox), and some innocuous-sounding ones
-- are (REF_CODE holds a national insurance number).
--
-- That mix is the point: classification is a judgement that needs the
-- data looked at, not a regex over column names.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE CUSTOMERS (
  CUSTOMER_ID   NUMBER(38,0) NOT NULL,
  FULL_NAME     VARCHAR(120)          COMMENT 'Customer name',
  EMAIL_ADDRESS VARCHAR(120)          COMMENT 'Primary contact email',
  PHONE         VARCHAR(40)           COMMENT 'Mobile number',
  POSTCODE      VARCHAR(12)           COMMENT 'Billing postcode',
  REF_CODE      VARCHAR(20)           COMMENT 'National insurance number. Sensitive despite the vague name.',
  SIGNED_UP_ON  DATE,
  CONSTRAINT PK_CUSTOMERS PRIMARY KEY (CUSTOMER_ID)
) COMMENT = 'Customer master. Several sensitive columns under inconsistent names.';

CREATE OR REPLACE TABLE ORDERS (
  ORDER_ID      NUMBER(38,0) NOT NULL,
  CUSTOMER_ID   NUMBER(38,0) NOT NULL,
  CONTACT_EMAIL VARCHAR(120)          COMMENT 'Email captured at checkout, often differs from the master record',
  SHIP_ADDRESS  VARCHAR(200)          COMMENT 'Delivery address',
  ORDER_TOTAL   NUMBER(12,2),
  ORDERED_ON    DATE,
  CONSTRAINT PK_ORDERS PRIMARY KEY (ORDER_ID)
) COMMENT = 'Orders. CONTACT_EMAIL is the same class of data as CUSTOMERS.EMAIL_ADDRESS under a different name.';

CREATE OR REPLACE TABLE SUPPORT_TICKETS (
  TICKET_ID     NUMBER(38,0) NOT NULL,
  CUSTOMER_ID   NUMBER(38,0),
  SUPPORT_EMAIL VARCHAR(120)          COMMENT 'Shared support inbox. NOT personal data -- a deliberate false positive.',
  REPORTER_EMAIL VARCHAR(120)         COMMENT 'The customer who raised it. Personal data.',
  BODY_TEXT     VARCHAR(600)          COMMENT 'Free text. May contain anything, which is its own governance problem.',
  RAISED_ON     DATE,
  CONSTRAINT PK_SUPPORT_TICKETS PRIMARY KEY (TICKET_ID)
) COMMENT = 'Support tickets. Contains one email column that is NOT personal data and one that is.';

CREATE OR REPLACE TABLE EMPLOYEES (
  EMPLOYEE_ID   NUMBER(38,0) NOT NULL,
  FULL_NAME     VARCHAR(120),
  WORK_EMAIL    VARCHAR(120)          COMMENT 'Corporate email',
  SALARY_GBP    NUMBER(12,2)          COMMENT 'Sensitive, but not personally identifying -- a different protection class',
  MANAGER_ID    NUMBER(38,0),
  CONSTRAINT PK_EMPLOYEES PRIMARY KEY (EMPLOYEE_ID)
) COMMENT = 'Employees. SALARY_GBP is confidential without being PII, which needs a different policy.';

-- ------------------------------------------------------------
-- Data. Small on purpose -- this lab is about metadata, and 400 rows
-- makes the masking obvious at a glance.
-- ------------------------------------------------------------
INSERT INTO CUSTOMERS (CUSTOMER_ID, FULL_NAME, EMAIL_ADDRESS, PHONE, POSTCODE, REF_CODE, SIGNED_UP_ON)
SELECT
  SEQ4() + 1,
  DECODE(MOD(SEQ4(), 8), 0,'Ama Boateng', 1,'Ravi Iyer', 2,'Lena Fischer', 3,'Tomas Novak',
                         4,'Sofia Rossi', 5,'Kwame Mensah', 6,'Yuki Tanaka', 'Elena Petrova'),
  'user' || (SEQ4() + 1) || '@example.com',
  '+44 7700 ' || LPAD((900000 + MOD(ABS(HASH(SEQ4(), 3)), 99999))::VARCHAR, 6, '0'),
  DECODE(MOD(SEQ4(), 5), 0,'M1 4WP', 1,'EC2A 3AY', 2,'BS1 5TR', 3,'LS2 7EY', 'EH3 9DR'),
  'QQ' || LPAD((100000 + MOD(ABS(HASH(SEQ4(), 5)), 899999))::VARCHAR, 6, '0') || 'C',
  DATEADD('day', -1 * MOD(ABS(HASH(SEQ4(), 7)), 900), CURRENT_DATE())
FROM TABLE(GENERATOR(ROWCOUNT => 200));

INSERT INTO ORDERS (ORDER_ID, CUSTOMER_ID, CONTACT_EMAIL, SHIP_ADDRESS, ORDER_TOTAL, ORDERED_ON)
SELECT
  SEQ4() + 1,
  1 + MOD(ABS(HASH(SEQ4(), 11)), 200),
  'user' || (1 + MOD(ABS(HASH(SEQ4(), 11)), 200)) || '@example.com',
  (10 + MOD(ABS(HASH(SEQ4(), 13)), 90)) || ' Example Street, Manchester',
  ROUND(15 + MOD(ABS(HASH(SEQ4(), 17)), 40000) / 100.0, 2),
  DATEADD('day', -1 * MOD(ABS(HASH(SEQ4(), 19)), 400), CURRENT_DATE())
FROM TABLE(GENERATOR(ROWCOUNT => 500));

INSERT INTO SUPPORT_TICKETS (TICKET_ID, CUSTOMER_ID, SUPPORT_EMAIL, REPORTER_EMAIL, BODY_TEXT, RAISED_ON)
SELECT
  SEQ4() + 1,
  1 + MOD(ABS(HASH(SEQ4(), 23)), 200),
  'support@example.com',
  'user' || (1 + MOD(ABS(HASH(SEQ4(), 23)), 200)) || '@example.com',
  'Customer reports an issue with order ' || (1 + MOD(ABS(HASH(SEQ4(), 29)), 500)),
  DATEADD('day', -1 * MOD(ABS(HASH(SEQ4(), 31)), 200), CURRENT_DATE())
FROM TABLE(GENERATOR(ROWCOUNT => 150));

INSERT INTO EMPLOYEES (EMPLOYEE_ID, FULL_NAME, WORK_EMAIL, SALARY_GBP, MANAGER_ID)
SELECT
  SEQ4() + 1,
  DECODE(MOD(SEQ4(), 6), 0,'Priya Shah', 1,'Daniel Okoro', 2,'Marta Kaminska',
                         3,'Sam Whitfield', 4,'Chen Wei', 'Nadia Haddad'),
  'employee' || (SEQ4() + 1) || '@corp.example.com',
  32000 + MOD(ABS(HASH(SEQ4(), 37)), 68000),
  IFF(SEQ4() = 0, NULL, 1 + MOD(ABS(HASH(SEQ4(), 41)), 5))
FROM TABLE(GENERATOR(ROWCOUNT => 40));

-- ------------------------------------------------------------
-- Register this run for the Lab 62 cost capstone
-- ------------------------------------------------------------
INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB53', 'Governance at scale', 'SETUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ------------------------------------------------------------
-- Confirm. Note what is NOT here: no tags, no policies, no governance
-- of any kind. That is the starting position.
--
-- The column count is the number that makes the argument: protecting
-- these one policy at a time does not scale, and this is four tables.
-- ------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM CUSTOMERS)                                AS CUSTOMER_ROWS,
  (SELECT COUNT(*) FROM ORDERS)                                   AS ORDER_ROWS,
  (SELECT COUNT(*) FROM SUPPORT_TICKETS)                          AS TICKET_ROWS,
  (SELECT COUNT(*) FROM EMPLOYEES)                                AS EMPLOYEE_ROWS,
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'LAB')                                   AS TOTAL_COLUMNS,
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'LAB' AND COLUMN_NAME ILIKE '%EMAIL%')   AS COLUMNS_MATCHING_EMAIL;

-- How far a name-based search gets you, which is the question step 1 asks.
-- Five columns match '%EMAIL%'. One of them (SUPPORT_EMAIL) is a shared inbox
-- and must NOT be masked, and REF_CODE -- a national insurance number -- does
-- not match at all.
SELECT TABLE_NAME, COLUMN_NAME, COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'LAB'
  AND (COLUMN_NAME ILIKE '%EMAIL%' OR COLUMN_NAME IN ('REF_CODE','PHONE','FULL_NAME','SALARY_GBP'))
ORDER BY TABLE_NAME, COLUMN_NAME;

-- ------------------------------------------------------------
-- Your object names, for pasting into CoCo
-- ------------------------------------------------------------
SELECT $LAB_DB            AS YOUR_LAB_DATABASE,
       $LAB_DB || '.LAB'  AS YOUR_LAB_SCHEMA,
       $WH                AS YOUR_WAREHOUSE;

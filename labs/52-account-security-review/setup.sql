-- ============================================================
-- Lab 52 -- Review an account against security best practice
--
-- Creates COCO_WS_LAB52_DB_<you>.LAB with a seeded, synthetic copy of
-- the ACCOUNT_USAGE views a security review reads, carrying planted
-- problems whose answers are known exactly.
--
-- This lab is READ-ONLY against your real account. It creates nothing
-- outside its own database, changes no user, grants nothing, revokes
-- nothing and attaches no policy. The second half points the review
-- queries you build at SNOWFLAKE.ACCOUNT_USAGE to look at your actual
-- posture -- looking only. Any remediation is a conversation to have
-- with your account team afterwards, not something a workshop should
-- do to a live account.
--
-- Why seeded data first, when the real views are right there: a review
-- you cannot check is not a review. On seeded data the right answer is
-- known, so you find out whether your query is correct. Then you point
-- the same query at reality, where nobody knows the answer.
--
-- The traps this lab is built around, in the order they bite:
--
--   1. DELETED_ON. ACCOUNT_USAGE keeps dropped objects. A review that
--      forgets `DELETED_ON IS NULL` reports long-gone users and
--      already-revoked grants as live findings. This is not a corner
--      case: on the account this lab was written against,
--      ACCOUNT_USAGE.USERS held 101 rows of which only 18 were live.
--      A naive user audit there would have been 82% noise.
--
--   2. Inherited privilege. Checking who was granted ACCOUNTADMIN
--      *directly* misses everyone who holds it through a role
--      hierarchy. The seed plants both, and the direct-only answer is
--      deliberately less than half the true one.
--
--   3. Judging service users by human rules. A SERVICE user cannot
--      enrol in MFA, so flagging it for not having MFA is a false
--      positive that trains people to ignore the report. The right
--      finding for a service identity is a password where a key pair
--      should be.
--
--   4. Latency. ACCOUNT_USAGE is not live. A fix made ten minutes ago
--      will not show, so "I already fixed that" and "the report is
--      wrong" are indistinguishable without knowing the lag.
--
-- Re-runnable: per-lab objects use CREATE OR REPLACE.
-- Teardown: labs/52-account-security-review/cleanup.sql
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
SET LAB_DB        = 'COCO_WS_LAB52_DB_' || $NS;

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

ALTER SESSION SET QUERY_TAG = 'COCO_WS_LAB52';

-- ------------------------------------------------------------
-- Lab database
-- ------------------------------------------------------------
CREATE OR REPLACE DATABASE IDENTIFIER($LAB_DB)
  COMMENT = 'CoCo Workshop Lab 52 -- read-only account security review';
USE DATABASE IDENTIFIER($LAB_DB);
CREATE OR REPLACE SCHEMA LAB;
USE SCHEMA LAB;

-- ------------------------------------------------------------
-- AUDIT_USERS -- the shape of SNOWFLAKE.ACCOUNT_USAGE.USERS, trimmed to
-- the columns a review actually reads, with the same semantics.
--
-- Deliberate: DELETED_ON exists and is populated, TYPE distinguishes
-- PERSON from SERVICE, and HAS_MFA is NULL rather than FALSE for
-- service identities -- because that is what the real view does, and a
-- query written against a friendlier fake would not survive contact
-- with the real one.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE AUDIT_USERS (
  NAME                 VARCHAR(80)  NOT NULL COMMENT 'Login name',
  TYPE                 VARCHAR(20)  NOT NULL COMMENT 'PERSON, SERVICE or LEGACY_SERVICE',
  DISABLED             BOOLEAN      NOT NULL COMMENT 'TRUE if the user cannot log in',
  HAS_PASSWORD         BOOLEAN      NOT NULL COMMENT 'TRUE if a password is set',
  HAS_RSA_PUBLIC_KEY   BOOLEAN      NOT NULL COMMENT 'TRUE if key-pair auth is configured',
  HAS_MFA              BOOLEAN               COMMENT 'TRUE if enrolled in MFA. NULL for service users, which cannot enrol.',
  DEFAULT_ROLE         VARCHAR(80)           COMMENT 'Role assumed on connect',
  LAST_SUCCESS_LOGIN   TIMESTAMP_LTZ         COMMENT 'Last successful login, NULL if never',
  DELETED_ON           TIMESTAMP_LTZ         COMMENT 'When the user was dropped. NULL means the user still exists.',
  CONSTRAINT PK_AUDIT_USERS PRIMARY KEY (NAME)
) COMMENT = 'Synthetic copy of ACCOUNT_USAGE.USERS with planted findings. Mirrors the real view''s semantics, including retained deleted rows.';

-- 27 rows: 21 live, 6 deleted. All counts below are measured from a real run,
-- not from reading the list.
--
-- Planted findings among the LIVE rows only:
--   5 PERSON users with a password and no MFA        -> the MFA finding
--   2 service identities with a password, no keypair -> the service-auth finding
--   1 PERSON user DISABLED but still holding a role  -> the offboarding finding
--   4 PERSON users dormant (3 over 90 days, 1 never) -> the dormant finding
--
-- Note PVASILIEV is deliberately BOTH an MFA finding and a dormant one, because
-- real findings overlap and a report that assumes they are disjoint double-counts
-- the people it is asking someone to chase.
--
-- The 6 deleted rows include 2 that would ALSO match the MFA finding, so a query
-- that forgets DELETED_ON returns 7 instead of 5 -- 40% over.
INSERT INTO AUDIT_USERS
  (NAME, TYPE, DISABLED, HAS_PASSWORD, HAS_RSA_PUBLIC_KEY, HAS_MFA, DEFAULT_ROLE, LAST_SUCCESS_LOGIN, DELETED_ON)
SELECT * FROM VALUES
  -- Live PERSON users, healthy: MFA on, recent logins.
  ('AWHITFIELD',   'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ANALYST',      DATEADD('day',  -1, CURRENT_TIMESTAMP()), NULL),
  ('BNAKAMURA',    'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ANALYST',      DATEADD('day',  -2, CURRENT_TIMESTAMP()), NULL),
  ('COKONKWO',     'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ENGINEER',     DATEADD('day',  -1, CURRENT_TIMESTAMP()), NULL),
  ('DLINDQVIST',   'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ENGINEER',     DATEADD('day',  -4, CURRENT_TIMESTAMP()), NULL),
  ('EMARCHETTI',   'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ANALYST',      DATEADD('day',  -3, CURRENT_TIMESTAMP()), NULL),
  ('FBOATENG',     'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'DATA_ADMIN',   DATEADD('day',  -1, CURRENT_TIMESTAMP()), NULL),
  ('GPETROVA',     'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ANALYST',      DATEADD('day',  -6, CURRENT_TIMESTAMP()), NULL),
  ('HRAMIREZ',     'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ENGINEER',     DATEADD('day',  -2, CURRENT_TIMESTAMP()), NULL),
  -- FINDING: live people, password only, no MFA. Four of them.
  ('IKOVACS',      'PERSON',  FALSE, TRUE,  FALSE, FALSE, 'ANALYST',      DATEADD('day',  -5, CURRENT_TIMESTAMP()), NULL),
  ('JDUBOIS',      'PERSON',  FALSE, TRUE,  FALSE, FALSE, 'ENGINEER',     DATEADD('day',  -8, CURRENT_TIMESTAMP()), NULL),
  ('KOYELARAN',    'PERSON',  FALSE, TRUE,  FALSE, FALSE, 'DATA_ADMIN',   DATEADD('day',  -2, CURRENT_TIMESTAMP()), NULL),
  ('LSCHNEIDER',   'PERSON',  FALSE, TRUE,  FALSE, FALSE, 'ACCOUNTADMIN', DATEADD('day', -11, CURRENT_TIMESTAMP()), NULL),
  -- FINDING: dormant. Three over 90 days, one that never logged in.
  ('MTHORVALDSEN', 'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ANALYST',      DATEADD('day',-104, CURRENT_TIMESTAMP()), NULL),
  ('NABARIKWU',    'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ANALYST',      DATEADD('day',-158, CURRENT_TIMESTAMP()), NULL),
  ('OKALLIO',      'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ENGINEER',     DATEADD('day',-212, CURRENT_TIMESTAMP()), NULL),
  ('PVASILIEV',    'PERSON',  FALSE, TRUE,  FALSE, FALSE, 'ANALYST',      NULL,                                     NULL),
  -- FINDING: disabled but never de-provisioned. Still holds a role grant.
  ('QMENSAH',      'PERSON',  TRUE,  TRUE,  FALSE, TRUE,  'ENGINEER',     DATEADD('day', -63, CURRENT_TIMESTAMP()), NULL),
  -- Service identities. HAS_MFA is NULL because a service user cannot enrol.
  ('SVC_ETL_PROD', 'SERVICE', FALSE, FALSE, TRUE,  NULL,  'ETL_ROLE',     DATEADD('hour', -1, CURRENT_TIMESTAMP()), NULL),
  ('SVC_BI_TOOL',  'SERVICE', FALSE, FALSE, TRUE,  NULL,  'BI_ROLE',      DATEADD('hour', -2, CURRENT_TIMESTAMP()), NULL),
  -- FINDING: service identities authenticating by password. Two of them.
  ('SVC_LEGACY_RPT','LEGACY_SERVICE', FALSE, TRUE, FALSE, NULL, 'BI_ROLE', DATEADD('day', -1, CURRENT_TIMESTAMP()), NULL),
  ('SVC_ADHOC',    'SERVICE', FALSE, TRUE,  FALSE, NULL,  'ETL_ROLE',     DATEADD('day',  -9, CURRENT_TIMESTAMP()), NULL),
  -- Deleted. Retained by ACCOUNT_USAGE, and NOT findings. Two of these would
  -- look exactly like the MFA finding above if DELETED_ON were ignored.
  ('RGONZALEZ',    'PERSON',  FALSE, TRUE,  FALSE, FALSE, 'ANALYST',      DATEADD('day', -95, CURRENT_TIMESTAMP()), DATEADD('day', -90, CURRENT_TIMESTAMP())),
  ('TIBRAHIM',     'PERSON',  FALSE, TRUE,  FALSE, FALSE, 'ENGINEER',     DATEADD('day',-140, CURRENT_TIMESTAMP()), DATEADD('day',-132, CURRENT_TIMESTAMP())),
  ('UNGUYEN',      'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ANALYST',      DATEADD('day',-180, CURRENT_TIMESTAMP()), DATEADD('day',-175, CURRENT_TIMESTAMP())),
  ('VSANTOS',      'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ANALYST',      DATEADD('day',-210, CURRENT_TIMESTAMP()), DATEADD('day',-200, CURRENT_TIMESTAMP())),
  ('WCHEN',        'PERSON',  FALSE, TRUE,  FALSE, TRUE,  'ENGINEER',     DATEADD('day',-260, CURRENT_TIMESTAMP()), DATEADD('day',-250, CURRENT_TIMESTAMP())),
  ('SVC_OLD_SYNC', 'SERVICE', FALSE, TRUE,  FALSE, NULL,  'ETL_ROLE',     DATEADD('day',-300, CURRENT_TIMESTAMP()), DATEADD('day',-290, CURRENT_TIMESTAMP()));

-- ------------------------------------------------------------
-- AUDIT_ROLE_GRANTS -- role granted TO a user, mirroring
-- ACCOUNT_USAGE.GRANTS_TO_USERS.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE AUDIT_ROLE_GRANTS (
  ROLE       VARCHAR(80) NOT NULL COMMENT 'Role being granted',
  GRANTEE_NAME VARCHAR(80) NOT NULL COMMENT 'User receiving it',
  GRANTED_BY VARCHAR(80)           COMMENT 'Who granted it',
  DELETED_ON TIMESTAMP_LTZ         COMMENT 'When the grant was revoked. NULL means still in force.'
) COMMENT = 'Synthetic copy of ACCOUNT_USAGE.GRANTS_TO_USERS.';

-- ACCOUNTADMIN held DIRECTLY by 2 live users, plus 1 revoked grant that a
-- DELETED_ON-blind query counts as a third. FBOATENG additionally holds it
-- through DATA_ADMIN, so direct (2) + inherited (4) = 6 while the true
-- deduplicated answer is 5.
INSERT INTO AUDIT_ROLE_GRANTS (ROLE, GRANTEE_NAME, GRANTED_BY, DELETED_ON)
SELECT * FROM VALUES
  ('ACCOUNTADMIN', 'FBOATENG',    'SECURITYADMIN', NULL),
  ('ACCOUNTADMIN', 'LSCHNEIDER',  'SECURITYADMIN', NULL),
  ('ACCOUNTADMIN', 'TIBRAHIM',    'SECURITYADMIN', DATEADD('day', -132, CURRENT_TIMESTAMP())),
  ('DATA_ADMIN',   'KOYELARAN',   'SECURITYADMIN', NULL),
  -- FBOATENG holds ACCOUNTADMIN directly AND through DATA_ADMIN. One person,
  -- two paths: this is what makes UNION rather than UNION ALL necessary.
  ('DATA_ADMIN',   'FBOATENG',    'SECURITYADMIN', NULL),
  ('DATA_ADMIN',   'AWHITFIELD',  'SECURITYADMIN', NULL),
  ('DATA_ADMIN',   'BNAKAMURA',   'SECURITYADMIN', NULL),
  ('ENGINEER',     'COKONKWO',    'SECURITYADMIN', NULL),
  ('ENGINEER',     'DLINDQVIST',  'SECURITYADMIN', NULL),
  ('ENGINEER',     'HRAMIREZ',    'SECURITYADMIN', NULL),
  ('ENGINEER',     'JDUBOIS',     'SECURITYADMIN', NULL),
  ('ENGINEER',     'QMENSAH',     'SECURITYADMIN', NULL),
  ('ANALYST',      'EMARCHETTI',  'SECURITYADMIN', NULL),
  ('ANALYST',      'GPETROVA',    'SECURITYADMIN', NULL),
  ('ANALYST',      'IKOVACS',     'SECURITYADMIN', NULL),
  ('ANALYST',      'PVASILIEV',   'SECURITYADMIN', NULL),
  ('ETL_ROLE',     'SVC_ETL_PROD','SECURITYADMIN', NULL),
  ('ETL_ROLE',     'SVC_ADHOC',   'SECURITYADMIN', NULL),
  ('BI_ROLE',      'SVC_BI_TOOL', 'SECURITYADMIN', NULL),
  ('BI_ROLE',      'SVC_LEGACY_RPT','SECURITYADMIN', NULL);

-- ------------------------------------------------------------
-- AUDIT_ROLE_HIERARCHY -- role granted TO another role. This is where
-- inherited privilege hides.
--
-- DATA_ADMIN has ACCOUNTADMIN granted to it. So every user with
-- DATA_ADMIN holds ACCOUNTADMIN too, without ever appearing in a
-- direct-grant query. Three live users have DATA_ADMIN.
--
-- Live users holding ACCOUNTADMIN: 2 directly, 4 through DATA_ADMIN, and
-- FBOATENG is in both sets. So the deduplicated answer is 5, while adding
-- the two lists together gives 6. UNION, not UNION ALL.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE AUDIT_ROLE_HIERARCHY (
  ROLE         VARCHAR(80) NOT NULL COMMENT 'Role being granted',
  GRANTEE_ROLE VARCHAR(80) NOT NULL COMMENT 'Role receiving it',
  DELETED_ON   TIMESTAMP_LTZ        COMMENT 'When revoked. NULL means still in force.'
) COMMENT = 'Synthetic copy of the role-to-role edges in ACCOUNT_USAGE.GRANTS_TO_ROLES.';

INSERT INTO AUDIT_ROLE_HIERARCHY (ROLE, GRANTEE_ROLE, DELETED_ON)
SELECT * FROM VALUES
  ('ACCOUNTADMIN', 'DATA_ADMIN', NULL),   -- the inheritance path that matters
  ('ENGINEER',     'DATA_ADMIN', NULL),
  ('ANALYST',      'ENGINEER',   NULL),
  ('BI_ROLE',      'ANALYST',    NULL),
  ('ACCOUNTADMIN', 'ETL_ROLE',   DATEADD('day', -40, CURRENT_TIMESTAMP()));

-- ------------------------------------------------------------
-- AUDIT_LOGIN_HISTORY -- mirroring ACCOUNT_USAGE.LOGIN_HISTORY.
--
-- Planted: one user with a burst of failed logins from a single IP,
-- and one service account authenticating from an unusually wide set of
-- addresses.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE AUDIT_LOGIN_HISTORY (
  EVENT_TIMESTAMP TIMESTAMP_LTZ NOT NULL,
  USER_NAME       VARCHAR(80)   NOT NULL,
  CLIENT_IP       VARCHAR(40),
  REPORTED_CLIENT_TYPE VARCHAR(40),
  IS_SUCCESS      VARCHAR(3)    NOT NULL COMMENT 'YES or NO, as the real view reports it',
  ERROR_MESSAGE   VARCHAR(200),
  SECOND_AUTHENTICATION_FACTOR VARCHAR(40) COMMENT 'NULL when MFA was not used'
) COMMENT = 'Synthetic copy of ACCOUNT_USAGE.LOGIN_HISTORY.';

-- 40 failed attempts against one account from one address, inside an hour.
INSERT INTO AUDIT_LOGIN_HISTORY
  (EVENT_TIMESTAMP, USER_NAME, CLIENT_IP, REPORTED_CLIENT_TYPE, IS_SUCCESS, ERROR_MESSAGE, SECOND_AUTHENTICATION_FACTOR)
SELECT
  DATEADD('minute', -1 * MOD(SEQ4(), 60), DATEADD('hour', -3, CURRENT_TIMESTAMP())),
  'IKOVACS', '203.0.113.77', 'OTHER', 'NO', 'INCORRECT_USERNAME_PASSWORD', NULL
FROM TABLE(GENERATOR(ROWCOUNT => 40));

-- One service account seen from 12 distinct addresses in a day.
INSERT INTO AUDIT_LOGIN_HISTORY
  (EVENT_TIMESTAMP, USER_NAME, CLIENT_IP, REPORTED_CLIENT_TYPE, IS_SUCCESS, ERROR_MESSAGE, SECOND_AUTHENTICATION_FACTOR)
SELECT
  DATEADD('hour', -1 * MOD(SEQ4(), 24), CURRENT_TIMESTAMP()),
  'SVC_ADHOC',
  '198.51.100.' || (10 + MOD(SEQ4(), 12)),
  'JDBC', 'YES', NULL, NULL
FROM TABLE(GENERATOR(ROWCOUNT => 36));

-- Ordinary successful logins, so the two patterns above have to be found
-- rather than being the only thing present.
INSERT INTO AUDIT_LOGIN_HISTORY
  (EVENT_TIMESTAMP, USER_NAME, CLIENT_IP, REPORTED_CLIENT_TYPE, IS_SUCCESS, ERROR_MESSAGE, SECOND_AUTHENTICATION_FACTOR)
SELECT
  DATEADD('hour', -1 * MOD(SEQ4(), 72), CURRENT_TIMESTAMP()),
  DECODE(MOD(SEQ4(), 6), 0,'AWHITFIELD', 1,'BNAKAMURA', 2,'COKONKWO',
                         3,'DLINDQVIST', 4,'EMARCHETTI', 'GPETROVA'),
  '10.20.30.' || (40 + MOD(SEQ4(), 6)),
  'SNOWFLAKE_UI', 'YES', NULL,
  IFF(MOD(SEQ4(), 6) IN (0,1,2,3,4), 'DUO_PUSH', NULL)
FROM TABLE(GENERATOR(ROWCOUNT => 120));

-- ------------------------------------------------------------
-- Register this run for the Lab 62 cost capstone
-- ------------------------------------------------------------
INSERT INTO IDENTIFIER($RUN_LOG)
  (LAB_ID, LAB_NAME, EVENT_TYPE, EVENT_TS, USER_NAME, ROLE_NAME,
   WAREHOUSE_NAME, SESSION_ID, QUERY_TAG)
SELECT 'LAB52', 'Account security review', 'SETUP', CURRENT_TIMESTAMP(),
       CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE(),
       CURRENT_SESSION(), CURRENT_QUERY_TAG();

-- ------------------------------------------------------------
-- Confirm, and print the answer key for the seeded data.
--
-- Compare these to the table in README.md. The gap between the "live"
-- and "all rows" columns is trap 1, and it is the whole reason this
-- lab starts on seeded data.
-- ------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM AUDIT_USERS)                              AS USER_ROWS_ALL,
  (SELECT COUNT_IF(DELETED_ON IS NULL) FROM AUDIT_USERS)          AS USER_ROWS_LIVE,
  (SELECT COUNT(*) FROM AUDIT_ROLE_GRANTS)                        AS ROLE_GRANTS_ALL,
  (SELECT COUNT_IF(DELETED_ON IS NULL) FROM AUDIT_ROLE_GRANTS)    AS ROLE_GRANTS_LIVE,
  (SELECT COUNT(*) FROM AUDIT_LOGIN_HISTORY)                      AS LOGIN_EVENTS;

SELECT
  -- Trap 1, both ways round.
  (SELECT COUNT(*) FROM AUDIT_USERS
    WHERE TYPE = 'PERSON' AND NOT DISABLED AND HAS_PASSWORD
      AND NOT COALESCE(HAS_MFA, FALSE) AND DELETED_ON IS NULL)     AS MFA_FINDINGS_CORRECT,
  (SELECT COUNT(*) FROM AUDIT_USERS
    WHERE TYPE = 'PERSON' AND NOT DISABLED AND HAS_PASSWORD
      AND NOT COALESCE(HAS_MFA, FALSE))                            AS MFA_FINDINGS_IF_DELETED_IGNORED,
  -- Trap 3: service identities on passwords.
  (SELECT COUNT(*) FROM AUDIT_USERS
    WHERE TYPE IN ('SERVICE','LEGACY_SERVICE') AND HAS_PASSWORD
      AND NOT HAS_RSA_PUBLIC_KEY AND DELETED_ON IS NULL)           AS SERVICE_PASSWORD_FINDINGS,
  (SELECT COUNT(*) FROM AUDIT_USERS
    WHERE DISABLED AND DELETED_ON IS NULL)                         AS DISABLED_NOT_REMOVED,
  (SELECT COUNT(*) FROM AUDIT_USERS
    WHERE TYPE = 'PERSON' AND DELETED_ON IS NULL AND NOT DISABLED
      AND (LAST_SUCCESS_LOGIN IS NULL
           OR LAST_SUCCESS_LOGIN < DATEADD('day', -90, CURRENT_TIMESTAMP()))) AS DORMANT_FINDINGS;

-- Trap 2: direct versus effective ACCOUNTADMIN. The two numbers differ, and
-- the second one is the answer to the question anybody actually asked.
WITH direct AS (
  SELECT GRANTEE_NAME FROM AUDIT_ROLE_GRANTS
  WHERE ROLE = 'ACCOUNTADMIN' AND DELETED_ON IS NULL
),
roles_with_aa AS (
  SELECT GRANTEE_ROLE FROM AUDIT_ROLE_HIERARCHY
  WHERE ROLE = 'ACCOUNTADMIN' AND DELETED_ON IS NULL
),
inherited AS (
  SELECT g.GRANTEE_NAME
  FROM AUDIT_ROLE_GRANTS g
  JOIN roles_with_aa r ON r.GRANTEE_ROLE = g.ROLE
  WHERE g.DELETED_ON IS NULL
)
SELECT
  (SELECT COUNT(*) FROM direct)                                   AS ACCOUNTADMIN_DIRECT,
  (SELECT COUNT(*) FROM inherited)                                AS ACCOUNTADMIN_INHERITED,
  (SELECT COUNT(*) FROM (
      SELECT GRANTEE_NAME FROM direct
      UNION
      SELECT GRANTEE_NAME FROM inherited))                        AS ACCOUNTADMIN_EFFECTIVE;

-- ------------------------------------------------------------
-- Your object names, for pasting into CoCo
-- ------------------------------------------------------------
SELECT $LAB_DB            AS YOUR_LAB_DATABASE,
       $LAB_DB || '.LAB'  AS YOUR_LAB_SCHEMA,
       $WH                AS YOUR_WAREHOUSE;

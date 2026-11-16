-- ADMIN ONLY. Review before running in a NON-PRODUCTION account.
-- Change both values. ATTENDEE is the actual Snowflake user name (case-sensitive
-- names may require embedded double quotes). Never substitute the admin's user.
USE ROLE ACCOUNTADMIN;
SET WORKSHOP_ROLE = 'COCO_WS_USER';
SET ATTENDEE = 'REPLACE_WITH_ATTENDEE_USER';

CREATE ROLE IF NOT EXISTS IDENTIFIER($WORKSHOP_ROLE)
  COMMENT = 'Workshop sandbox author; not a production least-privilege role';
GRANT CREATE DATABASE ON ACCOUNT TO ROLE IDENTIFIER($WORKSHOP_ROLE);
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE IDENTIFIER($WORKSHOP_ROLE);
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE IDENTIFIER($WORKSHOP_ROLE);
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE IDENTIFIER($WORKSHOP_ROLE);
GRANT USE AI FUNCTIONS ON ACCOUNT TO ROLE IDENTIFIER($WORKSHOP_ROLE);
GRANT ROLE IDENTIFIER($WORKSHOP_ROLE) TO USER IDENTIFIER($ATTENDEE);

-- STOP HERE for the base role. The attendee now selects this role in BOTH
-- CoCo and their SQL/CLI connection, then runs 00_workshop_setup.sql themselves.
-- They own the databases/warehouse they create. Schema ownership permits
-- creating lab tables, stages, formats, views, agents and Streamlit objects.
-- No account settings, default roles, or PUBLIC grants are changed here.

-- OPTIONAL BUNDLES: select/uncomment only the grants your lab selection needs.
-- Live usage: Labs 43 and 62. USAGE_VIEWER exposes account-wide usage, not just
-- the attendee's resources. MONITOR USAGE enables the INFORMATION_SCHEMA tier.
-- GRANT DATABASE ROLE SNOWFLAKE.USAGE_VIEWER TO ROLE IDENTIFIER($WORKSHOP_ROLE);
-- GRANT MONITOR USAGE ON ACCOUNT TO ROLE IDENTIFIER($WORKSHOP_ROLE);

-- Lineage / query investigations: Labs 12, 61, 62 and 72.
-- GRANT VIEW LINEAGE ON ACCOUNT TO ROLE IDENTIFIER($WORKSHOP_ROLE);
-- GRANT DATABASE ROLE SNOWFLAKE.OBJECT_VIEWER TO ROLE IDENTIFIER($WORKSHOP_ROLE);
-- GRANT DATABASE ROLE SNOWFLAKE.GOVERNANCE_VIEWER TO ROLE IDENTIFIER($WORKSHOP_ROLE);

-- Data quality: Lab 23 (Enterprise). May start billable background monitoring.
-- GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT TO ROLE IDENTIFIER($WORKSHOP_ROLE);

-- Task execution: Lab 33 and task extensions to other labs.
-- GRANT EXECUTE TASK ON ACCOUNT TO ROLE IDENTIFIER($WORKSHOP_ROLE);
-- Serverless tasks only, if explicitly selected:
-- GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE IDENTIFIER($WORKSHOP_ROLE);

-- Security review: Lab 52. Reveals account security metadata.
-- GRANT DATABASE ROLE SNOWFLAKE.SECURITY_VIEWER TO ROLE IDENTIFIER($WORKSHOP_ROLE);

-- Classification: Labs 51 / 53, if using classification profiles.
-- GRANT DATABASE ROLE SNOWFLAKE.CLASSIFICATION_ADMIN TO ROLE IDENTIFIER($WORKSHOP_ROLE);

-- Role-management steps in Labs 51/53 and account integrations in Lab 42
-- remain admin-led. Do not give attendees MANAGE GRANTS or CREATE ROLE merely
-- to bypass an error. Policies on lab-owned tables do not require a blanket
-- APPLY MASKING POLICY grant across the entire account.
SHOW GRANTS TO ROLE IDENTIFIER($WORKSHOP_ROLE);

-- Run as the ATTENDEE with the workshop role selected in the connection/UI.
-- Do not run as ACCOUNTADMIN. This script deliberately does not switch roles.
USE SECONDARY ROLES NONE;
SELECT CURRENT_ACCOUNT_NAME(), CURRENT_USER(), CURRENT_ROLE(), CURRENT_SECONDARY_ROLES();
-- Unique names: never replace or drop an existing attendee resource.
SET SMOKE_SUFFIX = (SELECT CURRENT_SESSION()::VARCHAR);
SET SMOKE_DB = 'COCO_WS_SMOKE_DB_' || $SMOKE_SUFFIX;
SET SMOKE_WH = 'COCO_WS_SMOKE_WH_' || $SMOKE_SUFFIX;
CREATE WAREHOUSE IDENTIFIER($SMOKE_WH)
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 INITIALLY_SUSPENDED = TRUE;
USE WAREHOUSE IDENTIFIER($SMOKE_WH);
CREATE DATABASE IDENTIFIER($SMOKE_DB);
USE DATABASE IDENTIFIER($SMOKE_DB);
CREATE SCHEMA LAB;
CREATE TABLE LAB.SMOKE (MESSAGE VARCHAR);
INSERT INTO LAB.SMOKE VALUES ('role can create and load lab objects');
CREATE STAGE LAB.FILES ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
CREATE FILE FORMAT LAB.CSV_FORMAT TYPE = CSV;
SELECT * FROM LAB.SMOKE;
DROP DATABASE IDENTIFIER($SMOKE_DB);
DROP WAREHOUSE IDENTIFIER($SMOKE_WH);
-- If a statement failed, retain the error and resolved names and have the
-- administrator remove only these two SMOKE objects. Do not run broad cleanup.
-- This tests base SQL privileges, not CoCo/model access or optional bundles.

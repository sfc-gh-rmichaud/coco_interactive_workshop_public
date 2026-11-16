-- ADMIN ONLY, after ALL attendees have finished and owned objects are removed.
-- Inspect grants/ownership first. Do not run while another attendee uses the role.
USE ROLE ACCOUNTADMIN;
SET WORKSHOP_ROLE = 'COCO_WS_USER';
SHOW GRANTS TO ROLE IDENTIFIER($WORKSHOP_ROLE);
SHOW GRANTS OF ROLE IDENTIFIER($WORKSHOP_ROLE);
-- Review the SHOW results; execute the next statement separately only when ready.
-- DROP ROLE IDENTIFIER($WORKSHOP_ROLE);
-- Role-management objects from Labs 51/53 and optional Lab 42 resources must
-- be reviewed and removed using those labs' cleanup instructions by their owner.

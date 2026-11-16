-- Drops only your Lab 75 database, including the agent, procedure and synthetic orders.
SET NS = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB75_DB_' || $NS;
DROP DATABASE IF EXISTS IDENTIFIER($LAB_DB);
-- Stop the local mock. Review generated clients/results before deleting local files.
-- Shared warehouse and run log are intentionally preserved.

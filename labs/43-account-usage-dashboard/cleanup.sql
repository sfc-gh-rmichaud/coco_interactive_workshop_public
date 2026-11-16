SET NS = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB43_DB_' || $NS;
DROP DATABASE IF EXISTS IDENTIFIER($LAB_DB);
-- Do not drop or suspend an existing shared/system compute pool.
-- Delete exported telemetry files separately; they may contain account data.

SET NS = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB25_DB_' || $NS;
DROP DATABASE IF EXISTS IDENTIFIER($LAB_DB);
-- Shared compute/log remain. Local fixtures and generated exports remain.

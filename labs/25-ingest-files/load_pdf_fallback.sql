-- Explicit fallback ONLY: this is not evidence of a successful AI extraction.
SET NS = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB25_DB_' || $NS;
SET WH = 'COCO_WS_WH_' || $NS;
USE WAREHOUSE IDENTIFIER($WH);
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;
INSERT INTO RAW_DOCUMENTS (SOURCE_FILE, EXTRACTION_METHOD, PAYLOAD)
SELECT 'orders.pdf', 'MANUAL_FIXTURE_FALLBACK', $1
FROM @FILES/pdf-fallback.json (FILE_FORMAT => JSON_FORMAT)
WHERE NOT EXISTS (SELECT 1 FROM RAW_DOCUMENTS WHERE SOURCE_FILE = 'orders.pdf');
-- If a failed live response already exists, keep it and investigate rather than
-- overwrite its provenance. Rerun setup in your disposable lab to reset if needed.

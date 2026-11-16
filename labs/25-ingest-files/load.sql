-- Run after setup/upload, in one session. Upload originals at stage root.
SET NS = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB25_DB_' || $NS;
SET WH = 'COCO_WS_WH_' || $NS;
USE WAREHOUSE IDENTIFIER($WH);
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;
COPY INTO RAW_CSV (ORDER_ID, ITEM, AMOUNT_TEXT, SOURCE_FILE, SOURCE_ROW)
FROM (SELECT $1, $2, $3, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER FROM @FILES)
FILES = ('orders.csv') FILE_FORMAT = (FORMAT_NAME = CSV_FORMAT) ON_ERROR = ABORT_STATEMENT;
COPY INTO RAW_JSON (PAYLOAD, SOURCE_FILE, SOURCE_ROW)
FROM (SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER FROM @FILES)
FILES = ('orders.json') FILE_FORMAT = (FORMAT_NAME = JSON_FORMAT) ON_ERROR = ABORT_STATEMENT;
COPY INTO RAW_XML (PAYLOAD, SOURCE_FILE, SOURCE_ROW)
FROM (SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER FROM @FILES)
FILES = ('orders.xml') FILE_FORMAT = (FORMAT_NAME = XML_FORMAT) ON_ERROR = ABORT_STATEMENT;
-- HTML is loaded by the Python stored procedure you build live, not by COPY.
SELECT 'CSV' AS SOURCE, COUNT(*) AS RAW_RECORDS FROM RAW_CSV
UNION ALL SELECT 'JSON', COUNT(*) FROM RAW_JSON
UNION ALL SELECT 'XML document', COUNT(*) FROM RAW_XML
UNION ALL SELECT 'HTML table', COUNT(*) FROM RAW_HTML;
-- Repeat this file without FORCE: recently loaded unchanged files are skipped.
-- COPY history is time-limited and tied to the table. Recreating the table,
-- changed names/content and FORCE can cause duplicate ingestion; use an explicit
-- file-content ledger/business key in a production design.

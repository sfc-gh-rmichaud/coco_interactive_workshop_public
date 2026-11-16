-- One paid document extraction; review current AI Functions pricing first:
-- https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-cost
SET NS = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB25_DB_' || $NS;
SET WH = 'COCO_WS_WH_' || $NS;
SET FILE_STAGE = '@' || $LAB_DB || '.LAB.FILES';
USE WAREHOUSE IDENTIFIER($WH);
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;
-- A single workshop session only: NOT EXISTS is not concurrency-safe uniqueness.
INSERT INTO RAW_DOCUMENTS (SOURCE_FILE, EXTRACTION_METHOD, PAYLOAD)
SELECT 'orders.pdf', 'AI_EXTRACT', AI_EXTRACT(
  file => TO_FILE($FILE_STAGE, 'orders.pdf'),
  responseFormat => {'schema': {'type': 'object', 'properties': {
    'orders': {'type': 'object', 'description': 'Synthetic orders table',
      'column_ordering': ['order_id', 'item', 'amount'], 'properties': {
        'order_id': {'type': 'array', 'description': 'order_id'},
        'item': {'type': 'array', 'description': 'item'},
        'amount': {'type': 'array', 'description': 'amount'}
      }}
  }}})
WHERE NOT EXISTS (SELECT 1 FROM RAW_DOCUMENTS WHERE SOURCE_FILE = 'orders.pdf');
SELECT SOURCE_FILE, EXTRACTION_METHOD, PAYLOAD:error AS ERROR,
       ARRAY_SIZE(PAYLOAD:response:orders:order_id) AS IDS,
       ARRAY_SIZE(PAYLOAD:response:orders:item) AS ITEMS,
       ARRAY_SIZE(PAYLOAD:response:orders:amount) AS AMOUNTS
FROM RAW_DOCUMENTS;
SELECT *, TRY_TO_DECIMAL(AMOUNT_TEXT, 12, 2) AS AMOUNT FROM RAW_PDF_LINES;
-- Review original PDF, errors, equal array lengths, numeric casts and row values.
-- Retain failed raw responses for inspection; do not silently accept partial data.

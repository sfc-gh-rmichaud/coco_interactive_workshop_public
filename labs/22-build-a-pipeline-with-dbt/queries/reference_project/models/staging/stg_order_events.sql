{{
  config(
    materialized = 'incremental',
    unique_key = 'event_id',
    incremental_strategy = 'merge',
  )
}}

-- Typed and deduplicated order events, one row per event_id.
--
-- Two things here are load-bearing, and both are what the lab is about:
--
-- 1. `unique_key = 'event_id'` in the config above. Without it, dbt's
--    incremental materialisation APPENDS, so the re-delivered events land a
--    second time and the model's row count drifts upward on every run. The
--    build succeeds either way; nothing warns you. The schema.yml `unique`
--    test on event_id is what actually catches it, and only on the second run.
--
-- 2. Both timestamp branches use TRY_ functions. Snowflake may evaluate BOTH
--    arms of a CASE regardless of the condition, so a plain TO_TIMESTAMP_LTZ
--    in the ELSE arm fails the whole model on the numeric rows, and a plain
--    ::NUMBER in the THEN arm fails on the ISO rows.

SELECT
  RAW_ID                       AS raw_id,
  PAYLOAD:event_id::STRING     AS event_id,
  PAYLOAD:event_type::STRING   AS event_type,
  CASE
    WHEN PAYLOAD:occurred_at::STRING RLIKE '^[0-9]+$'
      THEN TO_TIMESTAMP_LTZ(TRY_TO_NUMBER(PAYLOAD:occurred_at::STRING), 3)
    ELSE TRY_TO_TIMESTAMP_LTZ(PAYLOAD:occurred_at::STRING)
  END                          AS occurred_at,
  -- The cast is what turns the stored JSON null into a SQL NULL. Selecting
  -- PAYLOAD:customer_id without it gives a VARIANT null, which is a value:
  -- a not_null test on that column would pass for every row.
  PAYLOAD:customer_id::STRING  AS customer_id,
  PAYLOAD:currency::STRING     AS currency,
  PAYLOAD:channel::STRING      AS channel,
  PAYLOAD:items                AS items,
  INGESTED_AT                  AS ingested_at,
  SOURCE_FILE                  AS source_file
FROM {{ source('lab', 'raw_order_events') }}

{% if is_incremental() %}
  -- Only look at rows that arrived after the highest raw_id already in the
  -- model. On the first run this branch is skipped and the whole table is read.
  --
  -- The watermark is RAW_ID, not INGESTED_AT, and that is not a style choice.
  -- The re-delivery pass in setup.sql stamps duplicates 90 minutes AFTER the
  -- row they copy, so the newest ingested_at in this table can sit in the
  -- future relative to a batch that genuinely just arrived. Filtering on
  -- `ingested_at > max(ingested_at)` therefore matches nothing, the run
  -- reports SUCCESS, and the model silently stops seeing new data. Verified:
  -- it stuck at 40,000 rows after 4,000 new events had landed.
  --
  -- A watermark has to be monotonic in the order rows arrive. RAW_ID is;
  -- a business timestamp usually is not.
  WHERE RAW_ID > (SELECT COALESCE(MAX(raw_id), -1) FROM {{ this }})
{% endif %}

-- Keep the most recently ingested copy of each event. This runs INSIDE the
-- incremental batch, so it dedupes within a run; `unique_key` is what dedupes
-- ACROSS runs. Both are needed, and that is the part people get wrong.
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY PAYLOAD:event_id::STRING
  ORDER BY INGESTED_AT DESC, RAW_ID DESC
) = 1

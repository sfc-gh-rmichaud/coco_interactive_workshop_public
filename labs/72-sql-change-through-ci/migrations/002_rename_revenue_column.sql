-- ============================================================
-- 002_rename_revenue_column.sql
--
-- PROPOSED MIGRATION -- do not apply blindly. This is the change the
-- lab reviews.
--
-- Ticket: DATA-4471
-- "Rename REVENUE_USD to REVENUE in V_DAILY_REVENUE. The _USD suffix
--  is redundant now that everything is reported in USD, and it makes
--  the BI field names ugly."
--
-- Reviewed in isolation this is a tidy-up: one column, renamed, no
-- logic change. The diff looks completely safe.
-- ============================================================

-- Per-user namespace: this lab's database is suffixed with your user name so a
-- room can share one account. Set here rather than inherited, because a
-- migration applied by `snow sql -f` gets its own session.
SET NS     = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB72_DB_' || $NS;
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

CREATE OR REPLACE VIEW V_DAILY_REVENUE
  COMMENT = 'Daily completed revenue by region. Consumed by V_EXEC_SUMMARY and by BI.'
AS
SELECT
  ORDER_DATE,
  REGION_CD,
  COUNT(*)          AS ORDER_COUNT,
  SUM(ORDER_TOTAL)  AS REVENUE          -- renamed from REVENUE_USD
FROM ORDERS
WHERE ORDER_STATUS = 'COMPLETE'
GROUP BY ORDER_DATE, REGION_CD;

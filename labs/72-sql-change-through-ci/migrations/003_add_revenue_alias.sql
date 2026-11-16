-- ============================================================
-- 003_add_revenue_alias.sql
--
-- The safe version of DATA-4471.
--
-- Same goal -- expose a REVENUE column without the redundant _USD
-- suffix -- but additive rather than a rename. The old name keeps
-- working, so V_EXEC_SUMMARY and any BI report referencing
-- REVENUE_USD are unaffected.
--
-- The old column can be dropped later, once every consumer has been
-- migrated and the lineage confirms nothing still reads it. That is a
-- separate change, made deliberately, rather than a surprise.
-- ============================================================

-- Per-user namespace: this lab's database is suffixed with your user name so a
-- room can share one account. Set here rather than inherited, because a
-- migration applied by `snow sql -f` gets its own session.
SET NS     = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB72_DB_' || $NS;
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

CREATE OR REPLACE VIEW V_DAILY_REVENUE
  COMMENT = 'Daily completed revenue by region. REVENUE is the preferred column; REVENUE_USD is retained for existing consumers and will be removed once V_EXEC_SUMMARY and BI have migrated.'
AS
SELECT
  ORDER_DATE,
  REGION_CD,
  COUNT(*)          AS ORDER_COUNT,
  SUM(ORDER_TOTAL)  AS REVENUE,
  SUM(ORDER_TOTAL)  AS REVENUE_USD   -- deprecated alias, retained on purpose
FROM ORDERS
WHERE ORDER_STATUS = 'COMPLETE'
GROUP BY ORDER_DATE, REGION_CD;

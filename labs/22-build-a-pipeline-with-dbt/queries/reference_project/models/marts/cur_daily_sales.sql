-- Daily sales by channel and currency, with non-revenue events tracked
-- separately rather than netted into the total.
--
-- This is the model to compare against Lab 21's CUR_DAILY_SALES dynamic table.
-- The SELECT is deliberately identical, so any difference in the output is a
-- difference in what the two pipelines did upstream -- which is the comparison
-- worth making.
--
-- Materialised as a table (from dbt_project.yml). There is no TARGET_LAG
-- equivalent here: freshness is whenever something runs `dbt build`, which is
-- the trade this lab asks you to think about. Lab 21's leaf pulls its own chain
-- on a schedule Snowflake enforces; this one does nothing until told.

SELECT
  occurred_at::DATE                                                    AS sales_date,
  channel,
  currency,
  COUNT(DISTINCT CASE WHEN event_type = 'order_placed'    THEN event_id END) AS orders,
  SUM(CASE WHEN event_type = 'order_placed' THEN line_amount ELSE 0 END)     AS gross_sales,
  COUNT(DISTINCT CASE WHEN event_type = 'order_cancelled' THEN event_id END) AS cancelled_orders,
  COUNT(DISTINCT CASE WHEN event_type = 'order_refunded'  THEN event_id END) AS refunded_orders,
  COUNT_IF(customer_id IS NULL)                                        AS lines_missing_customer
FROM {{ ref('stg_order_lines') }}
GROUP BY 1, 2, 3

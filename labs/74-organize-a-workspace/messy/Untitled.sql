-- Saved investigation: weekly order volume. Do not execute during organization.
SELECT DATE_TRUNC('week', ORDER_DATE) AS WEEK, COUNT(*) AS ORDERS
FROM WORKSHOP_EXAMPLE.PUBLIC.ORDERS GROUP BY 1;

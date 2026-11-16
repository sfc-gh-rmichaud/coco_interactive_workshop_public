-- Similar name, different purpose: find duplicate IDs.
SELECT ORDER_ID, COUNT(*) FROM WORKSHOP_EXAMPLE.PUBLIC.ORDERS
GROUP BY ORDER_ID HAVING COUNT(*) > 1;
